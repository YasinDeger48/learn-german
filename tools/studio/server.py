"""Deschly Studio: a local tool to review the daily texts and their cover pictures, and the ChatGPT inbox
(requests, answers, checks, imports, unit and word pictures, publishing): see inbox.py.

    python -I -X utf8 tools/studio/server.py          (opens http://127.0.0.1:8765)

Only listens on this computer. Writes:
    Resources/Covers/<id>.jpg              cover pictures (960×640)
    ../icerik/gorseller/<id>.<ext>         the original picture (so covers.py import gives the same result)
    tools/studio/review.json               review state per text (ok / fix + note)
"""
import datetime
import glob
import io
import json
import os
import re
import subprocess
import sys
import threading
import webbrowser
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import parse_qs, urlparse

STUDIO = os.path.dirname(os.path.abspath(__file__))
TOOLS = os.path.dirname(STUDIO)
REPO = os.path.dirname(TOOLS)
sys.path.insert(0, TOOLS)
import covers  # noqa: E402
sys.path.insert(0, STUDIO)
import inbox  # noqa: E402

CONTENT = os.path.join(REPO, 'Resources', 'content')
COVERS = os.path.join(REPO, 'Resources', 'Covers')
ORIGINALS = os.path.normpath(os.path.join(REPO, '..', 'icerik', 'gorseller'))
REVIEW = os.path.join(STUDIO, 'review.json')
# Covers the Studio wrote and has not committed yet. Only these are saved: other tools and agents keep their own
# (untracked) covers in the same folder, and those must not end up in a Studio commit.
WRITTEN = os.path.join(STUDIO, '.written-covers.json')
LEVELS = ['A1', 'A2', 'B1', 'B2']
WORDS = {'A1': (60, 160), 'A2': (100, 170), 'B1': (180, 230), 'B2': (250, 280)}
PORT = 8765
lock = threading.Lock()


def load_texts():
    out = {}
    for level in LEVELS:
        path = os.path.join(CONTENT, f'daily_{level.lower()}.json')
        if os.path.exists(path):
            out[level] = json.load(open(path, encoding='utf-8'))['texts']
    return out


def load_review():
    try:
        return json.load(open(REVIEW, encoding='utf-8'))
    except (OSError, ValueError):
        return {}


def save_review(data):
    with open(REVIEW, 'w', encoding='utf-8', newline='\n') as f:
        json.dump(data, f, ensure_ascii=False, indent=1, sort_keys=True)
        f.write('\n')


def has_cover(text_id):
    return os.path.exists(os.path.join(COVERS, f'{text_id}.jpg'))


def issues(t, level):
    """Automatic checks, short English labels."""
    found = []
    words = sum(len(p.split()) for p in t['paragraphs'])
    lo, hi = WORDS[level]
    if not lo <= words <= hi:
        found.append(f'{words} words (expected {lo}–{hi})')
    trans = t.get('trans') or [{}]
    for lang in ('tr', 'en'):
        missing = sum(1 for part in trans if not part.get(lang))
        if missing:
            found.append(f'no {lang.upper()} translation' + (f' for {missing} of {len(trans)} paragraphs' if len(trans) > 1 else ''))
    mc = [q for q in t['questions'] if q['type'] == 'mc']
    tf = [q for q in t['questions'] if q['type'] == 'tf']
    if len(mc) < (2 if level == 'A1' else 3) or len(tf) < 2:
        found.append(f'{len(mc)} multiple choice + {len(tf)} true/false')
    if tf and all(q['answer'] == 0 for q in tf):
        found.append('no "false" answer')
    if mc and len({q['answer'] for q in mc}) == 1:
        found.append('all correct answers in the same place')
    no_en = [g['lemma'] for g in t['glossary'] if not g['mean'].get('en')]
    if no_en:
        found.append(f'glossary without EN: {", ".join(no_en[:3])}')
    if len(t['glossary']) < 5:
        found.append(f'only {len(t["glossary"])} glossary words')
    if not has_cover(t['id']):
        found.append('no cover')
    return found


def summary():
    review = load_review()
    out = []
    for level, items in load_texts().items():
        out.append({
            'level': level, 'texts': len(items),
            'covers': sum(1 for t in items if has_cover(t['id'])),
            'ok': sum(1 for t in items if review.get(t['id'], {}).get('status') == 'ok'),
            'fix': sum(1 for t in items if review.get(t['id'], {}).get('status') == 'fix'),
        })
    return out


def text_list(level):
    review = load_review()
    out = []
    for t in load_texts().get(level, []):
        out.append({'id': t['id'], 'title': t['title'], 'topic': t.get('topic', ''),
                    'cover': has_cover(t['id']), 'review': review.get(t['id'], {}),
                    'issues': [i for i in issues(t, level) if i != 'no cover']})
    return out


def text_detail(text_id):
    for level, items in load_texts().items():
        for t in items:
            if t['id'] == text_id:
                return {'level': level, 'text': t, 'cover': has_cover(text_id),
                        'review': load_review().get(text_id, {}), 'issues': issues(t, level),
                        'prompt': covers.prompt_for(t)}
    return None


def image_ext(data):
    if data[:8] == b'\x89PNG\r\n\x1a\n':
        return '.png'
    if data[:3] == b'\xff\xd8\xff':
        return '.jpg'
    if data[:4] == b'RIFF' and data[8:12] == b'WEBP':
        return '.webp'
    return None


def written():
    try:
        return set(json.load(open(WRITTEN, encoding='utf-8')))
    except (OSError, ValueError):
        return set()


def remember(text_id):
    names = written() | {text_id}
    with open(WRITTEN, 'w', encoding='utf-8', newline='\n') as f:
        json.dump(sorted(names), f)


def put_cover(text_id, data, crop_top):
    from PIL import Image
    ext = image_ext(data)
    if not ext:
        return 'not a PNG, JPEG or WebP picture'
    reason = covers.save_cover(Image.open(io.BytesIO(data)), text_id, crop_top)
    if reason:
        return reason
    os.makedirs(ORIGINALS, exist_ok=True)
    for old in glob.glob(os.path.join(ORIGINALS, f'{text_id}.*')):
        os.remove(old)
    if crop_top:  # keep the cleaned picture as the original, so a later covers.py import gives the same result
        data = open(os.path.join(COVERS, f'{text_id}.jpg'), 'rb').read()
        ext = '.jpg'
    open(os.path.join(ORIGINALS, text_id + ext), 'wb').write(data)
    remember(text_id)
    return None


def remove_cover(text_id):
    path = os.path.join(COVERS, f'{text_id}.jpg')
    if os.path.exists(path):
        os.remove(path)
    remember(text_id)
    removed = os.path.join(ORIGINALS, '_removed')
    for old in glob.glob(os.path.join(ORIGINALS, f'{text_id}.*')):
        os.makedirs(removed, exist_ok=True)
        os.replace(old, os.path.join(removed, os.path.basename(old)))


def git(*args):
    return subprocess.run(['git', '-c', f'safe.directory={REPO.replace(os.sep, "/")}', *args], cwd=REPO,
                          capture_output=True, text=True, encoding='utf-8')


def changes():
    """Changed files the Studio is responsible for: the covers it wrote and the review state."""
    paths = ['tools/studio/review.json'] + [f'Resources/Covers/{name}.jpg' for name in sorted(written())]
    out = git('status', '--porcelain', '--', *paths).stdout
    return [line[3:] for line in out.splitlines() if line.strip()]


def commit():
    files = changes()
    if not files:
        return {'ok': True, 'message': 'Nothing to save.'}
    covers_n = sum(1 for f in files if f.startswith('Resources/Covers'))
    parts = []
    if covers_n:
        parts.append(f'{covers_n} cover file(s)')
    if any(f.endswith('review.json') for f in files):
        parts.append('review state')
    git('add', '-A', '--', *files)
    result = git('commit', '-q', '-m', f'Studio: {" and ".join(parts)}', '--', *files)
    if result.returncode != 0:
        return {'ok': False, 'message': (result.stderr or result.stdout).strip()[:300]}
    os.remove(WRITTEN) if os.path.exists(WRITTEN) else None
    head = git('log', '--oneline', '-1').stdout.strip()
    return {'ok': True, 'message': f'Saved: {head}'}


class Handler(BaseHTTPRequestHandler):
    def log_message(self, *args):
        pass

    def send(self, code, body, ctype='application/json; charset=utf-8'):
        if not isinstance(body, (bytes, bytearray)):
            body = json.dumps(body, ensure_ascii=False).encode('utf-8')
        self.send_response(code)
        self.send_header('Content-Type', ctype)
        self.send_header('Content-Length', str(len(body)))
        self.send_header('Cache-Control', 'no-store')
        self.end_headers()
        self.wfile.write(body)

    def body(self):
        n = int(self.headers.get('Content-Length') or 0)
        return self.rfile.read(n) if n else b''

    def text_id(self, path, prefix):
        tid = path[len(prefix):]
        return tid if re.fullmatch(r'[a-z][0-9]-\d{3}', tid) else None

    def query(self, url):
        q = parse_qs(url.query)
        job = q.get('job', [''])[0]
        n = int(q.get('n', ['0'])[0] or 0)
        return job, n

    def inbox_get(self, url):
        path = url.path
        job, n = self.query(url)
        try:
            if path == '/api/inbox':
                return self.send(200, {'jobs': inbox.jobs(), 'units': inbox.unit_status(),
                                       'changes': inbox.content_changes()})
            if path == '/api/inbox/request':
                return self.send(200, {'text': inbox.request_text(job, n)})
            if path == '/api/inbox/check':
                return self.send(200, inbox.check(job, n))
        except (ValueError, KeyError) as e:
            return self.send(400, {'error': str(e) or 'bad request'})
        return None

    def inbox_post(self, url):
        path = url.path
        job, n = self.query(url)
        try:
            with lock:
                if path == '/api/inbox/answer':
                    return self.send(200, inbox.save_answer(job, n, self.body().decode('utf-8')))
                if path == '/api/inbox/import':
                    return self.send(200, {'output': inbox.import_job(job)})
                if path == '/api/inbox/open':
                    inbox.open_folder(job)
                    return self.send(200, {'ok': True})
                if path == '/api/picture':
                    name = parse_qs(url.query).get('name', [''])[0]
                    return self.send(200, inbox.put_picture(name, self.body()))
                if path == '/api/publish':
                    return self.send(200, {'output': inbox.publish()})
                if path == '/api/save-content':
                    return self.send(200, inbox.save_content())
        except (ValueError, KeyError) as e:
            return self.send(400, {'error': str(e) or 'bad request'})
        return None

    def do_GET(self):
        url = urlparse(self.path)
        path = url.path
        if path in ('/', '/index.html'):
            return self.send(200, open(os.path.join(STUDIO, 'index.html'), 'rb').read(), 'text/html; charset=utf-8')
        if path in ('/inbox', '/inbox.html'):
            return self.send(200, open(os.path.join(STUDIO, 'inbox.html'), 'rb').read(), 'text/html; charset=utf-8')
        if path.startswith('/api/inbox'):
            if self.inbox_get(url) is None:
                self.send(404, {'error': 'not found'})
            return
        if path.startswith('/img/') and path.endswith('.jpg'):
            name = path[5:-4]
            file = os.path.join(COVERS, f'{name}.jpg')
            if re.fullmatch(r'[a-z0-9-]+', name) and os.path.exists(file):
                return self.send(200, open(file, 'rb').read(), 'image/jpeg')
            return self.send(404, {'error': 'no picture'})
        if path == '/api/summary':
            return self.send(200, {'levels': summary(), 'changes': len(changes())})
        if path.startswith('/api/texts/'):
            return self.send(200, text_list(path.rsplit('/', 1)[1].upper()))
        if path.startswith('/api/text/'):
            tid = self.text_id(path, '/api/text/')
            detail = text_detail(tid) if tid else None
            return self.send(200 if detail else 404, detail or {'error': 'not found'})
        if path.startswith('/api/prompts/'):
            level = path.rsplit('/', 1)[1].upper()
            missing = [t for t in load_texts().get(level, []) if not has_cover(t['id'])]
            lines = [covers.STYLE, ''] + [covers.prompt_for(t).split('\n\n', 1)[1] for t in missing]
            return self.send(200, {'count': len(missing), 'text': '\n'.join(lines)})
        if path.startswith('/cover/') and path.endswith('.jpg'):
            tid = self.text_id(path[:-4], '/cover/')
            file = os.path.join(COVERS, f'{tid}.jpg') if tid else ''
            if tid and os.path.exists(file):
                return self.send(200, open(file, 'rb').read(), 'image/jpeg')
            return self.send(404, {'error': 'no cover'})
        self.send(404, {'error': 'not found'})

    def do_POST(self):
        url = urlparse(self.path)
        path = url.path
        if path.startswith(('/api/inbox', '/api/picture', '/api/publish', '/api/save-content')):
            if self.inbox_post(url) is None:
                self.send(404, {'error': 'not found'})
            return
        if path.startswith('/api/cover/'):
            tid = self.text_id(path, '/api/cover/')
            if not tid or not text_detail(tid):
                return self.send(404, {'error': 'unknown text'})
            crop = float(parse_qs(url.query).get('crop_top', ['0'])[0] or 0)
            with lock:
                reason = put_cover(tid, self.body(), max(0.0, min(crop, 0.3)))
            return self.send(400 if reason else 200, {'error': reason} if reason else {'ok': True})
        if path.startswith('/api/review/'):
            tid = self.text_id(path, '/api/review/')
            if not tid:
                return self.send(404, {'error': 'unknown text'})
            data = json.loads(self.body() or b'{}')
            with lock:
                review = load_review()
                if data.get('status') in ('ok', 'fix'):
                    review[tid] = {'status': data['status'], 'note': (data.get('note') or '').strip(),
                                   'at': datetime.date.today().isoformat()}
                else:
                    review.pop(tid, None)
                save_review(review)
            return self.send(200, {'ok': True})
        if path == '/api/commit':
            with lock:
                return self.send(200, commit())
        self.send(404, {'error': 'not found'})

    def do_DELETE(self):
        path = urlparse(self.path).path
        if path.startswith('/api/cover/'):
            tid = self.text_id(path, '/api/cover/')
            if not tid:
                return self.send(404, {'error': 'unknown text'})
            with lock:
                remove_cover(tid)
            return self.send(200, {'ok': True})
        self.send(404, {'error': 'not found'})


def main():
    port = int(sys.argv[sys.argv.index('--port') + 1]) if '--port' in sys.argv else PORT
    server = ThreadingHTTPServer(('127.0.0.1', port), Handler)
    url = f'http://127.0.0.1:{port}/'
    print(f'Deschly Studio: {url}  (close this window to stop)')
    if '--no-browser' not in sys.argv:
        threading.Timer(0.5, lambda: webbrowser.open(url)).start()
    server.serve_forever()


if __name__ == '__main__':
    main()

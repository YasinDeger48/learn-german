"""Deschly Studio (admin panel): FastAPI backend + React frontend (tools/studio/web, built into web/dist).

    Deschly-Studio.cmd                                   (creates tools/studio/.venv on first run, then starts)
    tools/studio/.venv/Scripts/python tools/studio/app.py [--port 8765] [--no-browser]

API docs while it runs: http://127.0.0.1:8765/docs
The classic pages stay at /classic (texts) and /classic/inbox; they use the same endpoints as before.
Frontend development: cd tools/studio/web && npm run dev  (proxies /api to this server), npm run build before commit.
"""
import datetime
import glob
import json
import os
import subprocess
import sys
import threading
import webbrowser

from fastapi import FastAPI, HTTPException, Query, Request
from fastapi.responses import FileResponse, JSONResponse, Response

STUDIO = os.path.dirname(os.path.abspath(__file__))
TOOLS = os.path.dirname(STUDIO)
REPO = os.path.dirname(TOOLS)
SITE = os.path.normpath(os.path.join(REPO, '..', 'deschly-site'))
DIST = os.path.join(STUDIO, 'web', 'dist')
sys.path.insert(0, STUDIO)
sys.path.insert(0, TOOLS)

import inbox  # noqa: E402
import server as classic  # noqa: E402  (text review helpers of the classic Studio)
import translate  # noqa: E402
import verblab  # noqa: E402
import word_pictures  # noqa: E402

CONTENT = os.path.join(REPO, 'Resources', 'content')
COVERS = os.path.join(REPO, 'Resources', 'Covers')
LEVELS = ['A1', 'A2', 'B1', 'B2']
lock = threading.Lock()

app = FastAPI(title='Deschly Studio', version='2.0')


def load(name):
    return json.load(open(os.path.join(CONTENT, name), encoding='utf-8'))


def bad(e):
    raise HTTPException(400, str(e) or 'bad request')


# ---------------------------------------------------------------- overview

def ui_progress():
    en = json.load(open(os.path.join(REPO, 'Resources', 'i18n', 'strings_en.json'), encoding='utf-8'))
    out = [{'code': 'tr', 'name': 'Türkçe', 'percent': 100}, {'code': 'en', 'name': 'English', 'percent': 100}]
    names = {'es': 'Español', 'fr': 'Français', 'it': 'Italiano', 'ku': 'Kurmancî', 'ar': 'العربية'}
    for code, name in names.items():
        left = len(translate.ui_missing(code))
        out.append({'code': code, 'name': name, 'percent': round(100 * (len(en) - left) / max(1, len(en))), 'left': left})
    return out


def audio_counts():
    folder = os.path.join(SITE, 'audio')
    count = lambda sub: len(glob.glob(os.path.join(folder, sub, '*.mp3')))  # noqa: E731
    try:
        ambience = len(json.load(open(os.path.join(folder, 'ambience.json'), encoding='utf-8')).get('sounds', {}))
    except (OSError, ValueError):
        ambience = 0
    return {'female': count('f'), 'male': count('m'), 'words': count('w'), 'ambience': ambience}


def level_rows():
    writing = load('writing.json')['tasks']
    speaking = load('speaking.json')['tasks']
    units = load('units.json')['units']
    review = classic.load_review()
    rows = []
    for level in LEVELS:
        lv = level.lower()
        data = load(f'{lv}.json')
        texts = load(f'daily_{lv}.json')['texts']
        rows.append({
            'level': level,
            'texts': len(texts),
            'covers': sum(1 for t in texts if classic.has_cover(t['id'])),
            'reviewed': sum(1 for t in texts if review.get(t['id'], {}).get('status') == 'ok'),
            'words': len(data['words']),
            'grammarTopics': len(data['grammar']),
            'grammarItems': len(data.get('grammarItems', [])),
            'units': sum(1 for u in units if u['level'] == level),
            'verbsReady': len(verblab.load(lv)),
            'verbsTotal': len(verblab.verbs_by_level()[lv]),
            'writing': sum(1 for t in writing if t['level'] == level),
            'speaking': sum(1 for t in speaking if t['id'].startswith(lv)),
        })
    return rows


def commits(n=6):
    out = inbox.git('log', f'-{n}', '--pretty=format:%h%x09%cs%x09%s').stdout
    return [dict(zip(('id', 'date', 'message'), line.split('\t', 2))) for line in out.splitlines() if line.strip()]


def job_summary():
    """Everything that waits for ChatGPT, one row per kind of work."""
    rows = []
    for job in inbox.jobs():
        rows.append({'id': job['id'], 'group': job['group'], 'title': job['title'],
                     'requests': len(job['requests']), 'answers': len(job['answers']),
                     'progress': job['progress']})
    units = inbox.unit_status()
    rows.append({'id': 'pictures:units', 'group': 'Pictures', 'title': 'Unit pictures', 'requests': len(units),
                 'answers': sum(1 for u in units if u['hasCover']), 'progress': None})
    grids = [u for u in units if u['grid']]
    rows.append({'id': 'pictures:grids', 'group': 'Pictures', 'title': 'Word grids', 'requests': len(grids),
                 'answers': sum(1 for u in grids if u['gridDone'] >= u['gridTotal'] > 0), 'progress': None})
    return rows


@app.get('/api/overview')
def overview():
    units = inbox.unit_status()
    levels = level_rows()
    audio = audio_counts()
    jobs = job_summary()
    return {
        'levels': levels,
        'units': {'total': len(units), 'pictures': sum(1 for u in units if u['hasCover']),
                  'cards': sum(u['gridDone'] for u in units), 'cardsTotal': sum(u['gridTotal'] for u in units)},
        'verbs': {'ready': sum(r['verbsReady'] for r in levels), 'total': sum(r['verbsTotal'] for r in levels)},
        'audio': audio,
        'jobs': jobs,
        'waiting': sum(j['requests'] - j['answers'] for j in jobs),
        'languages': ui_progress(),
        'commits': commits(),
        # Only what the Studio saves itself (other agents keep untracked text covers in Resources/Covers).
        'unsaved': len(inbox.content_changes()),
        'today': datetime.date.today().isoformat(),
    }


# ---------------------------------------------------------------- ChatGPT inbox (same paths as the classic Studio)

@app.get('/api/inbox')
def inbox_list():
    return {'jobs': inbox.jobs(), 'units': inbox.unit_status(), 'changes': inbox.content_changes()}


@app.get('/api/inbox/request')
def inbox_request(job: str, n: int):
    try:
        return {'text': inbox.request_text(job, n)}
    except (ValueError, KeyError) as e:
        bad(e)


@app.get('/api/inbox/check')
def inbox_check(job: str, n: int):
    try:
        return inbox.check(job, n)
    except (ValueError, KeyError) as e:
        bad(e)


@app.post('/api/inbox/answer')
async def inbox_answer(request: Request, job: str, n: int):
    text = (await request.body()).decode('utf-8')
    try:
        with lock:
            return inbox.save_answer(job, n, text)
    except (ValueError, KeyError) as e:
        bad(e)


@app.post('/api/inbox/import')
def inbox_import(job: str):
    try:
        with lock:
            return {'output': inbox.import_job(job)}
    except (ValueError, KeyError) as e:
        bad(e)


@app.post('/api/inbox/open')
def inbox_open(job: str):
    try:
        inbox.open_folder(job)
        return {'ok': True}
    except (ValueError, KeyError) as e:
        bad(e)


@app.post('/api/picture')
async def picture(request: Request, name: str = Query(...)):
    """A dropped picture: unit-a1-03 (unit), words-a1-03 (word grid) or a text id like a2-014 (text cover)."""
    import re
    data = await request.body()
    base = os.path.splitext(os.path.basename(name))[0].lower().strip()
    try:
        with lock:
            if re.fullmatch(r'[a-z][0-9]-\d{3}', base):
                if not classic.text_detail(base):
                    raise ValueError(f'{base}: no text with this id')
                reason = classic.put_cover(base, data, 0.0)
                if reason:
                    raise ValueError(f'{base}: {reason}')
                return {'message': f'{base}: text cover saved', 'pictures': [base]}
            return inbox.put_picture(name, data)
    except (ValueError, KeyError) as e:
        bad(e)


# ---------------------------------------------------------------- media

@app.get('/api/media/covers')
def media_covers():
    review = classic.load_review()
    out = []
    for level, items in classic.load_texts().items():
        for t in items:
            out.append({'id': t['id'], 'level': level, 'title': t['title'], 'topic': t.get('topic', ''),
                        'cover': classic.has_cover(t['id']), 'review': review.get(t['id'], {}).get('status')})
    return out


@app.get('/api/media/wordcards')
def media_wordcards():
    """The picture words of each unit (A1 for now) and whether their card exists."""
    words = {w['id']: w for w in load('a1.json')['words']}
    units = {u['id']: u for u in load('units.json')['units']}
    out = []
    for uid, ids in word_pictures.PICTURE_WORDS.items():
        cards = []
        for wid in ids:
            w = words.get(wid, {})
            article = w.get('type') if w.get('type') in ('der', 'die', 'das') else None
            cards.append({'id': wid, 'de': w.get('de', ''), 'article': article, 'meaning': (w.get('mean') or {}).get('en', ''),
                          'file': f'wp-a1-{wid}', 'exists': os.path.exists(os.path.join(COVERS, f'wp-a1-{wid}.jpg'))})
        unit = units.get(uid, {})
        out.append({'unit': uid, 'title': (unit.get('title') or {}).get('tr', uid), 'grid': f'words-{uid}', 'cards': cards})
    return out


@app.get('/api/media/audio')
def media_audio():
    folder = os.path.join(SITE, 'audio')
    try:
        index = json.load(open(os.path.join(folder, 'index.json'), encoding='utf-8'))
    except (OSError, ValueError):
        index = {}
    try:
        sounds = json.load(open(os.path.join(folder, 'ambience.json'), encoding='utf-8')).get('sounds', {})
    except (OSError, ValueError):
        sounds = {}
    titles = {t['id']: t['title'] for items in classic.load_texts().values() for t in items}
    texts = [{'id': tid, 'title': titles.get(tid, tid), 'voices': [v for v in ('f', 'm') if v in voices]}
             for tid, voices in sorted(index.items())]
    ambience = [{'kind': kind, 'name': info.get('name', ''), 'by': info.get('by', ''), 'license': info.get('license', ''),
                 'source': info.get('source', '')} for kind, info in sorted(sounds.items())]
    return {'counts': audio_counts(), 'texts': texts, 'ambience': ambience}


@app.get('/audio/{voice}/{tid}.mp3')
def audio_file(voice: str, tid: str):
    if voice not in ('f', 'm'):
        raise HTTPException(404, 'no audio')
    path = os.path.join(SITE, 'audio', voice, f'{text_id(tid)}.mp3')
    if not os.path.exists(path):
        raise HTTPException(404, 'no audio')
    return FileResponse(path, media_type='audio/mpeg')


@app.get('/audio/ambience/{kind}.m4a')
def ambience_file(kind: str):
    path = os.path.join(SITE, 'audio', 'ambience', f'{kind}.m4a')
    if not kind.isalpha() or not os.path.exists(path):
        raise HTTPException(404, 'no audio')
    return FileResponse(path, media_type='audio/mp4')


@app.post('/api/publish')
def publish():
    with lock:
        return {'output': inbox.publish()}


@app.post('/api/save-content')
def save_content():
    with lock:
        return inbox.save_content()


@app.get('/api/changes')
def changes():
    return {'content': inbox.content_changes(), 'texts': classic.changes()}


@app.get('/img/{name}.jpg')
def image(name: str):
    path = os.path.join(COVERS, f'{name}.jpg')
    if not name.replace('-', '').isalnum() or not os.path.exists(path):
        raise HTTPException(404, 'no picture')
    return FileResponse(path, media_type='image/jpeg', headers={'Cache-Control': 'no-store'})


# ---------------------------------------------------------------- classic text review endpoints

def text_id(tid):
    import re
    if not re.fullmatch(r'[a-z][0-9]-\d{3}', tid or ''):
        raise HTTPException(404, 'unknown text')
    return tid


@app.get('/api/summary')
def summary():
    return {'levels': classic.summary(), 'changes': len(classic.changes())}


@app.get('/api/texts/{level}')
def texts(level: str):
    return classic.text_list(level.upper())


@app.get('/api/text/{tid}')
def text(tid: str):
    detail = classic.text_detail(text_id(tid))
    if not detail:
        raise HTTPException(404, 'not found')
    return detail


@app.get('/api/prompts/{level}')
def prompts(level: str):
    missing = [t for t in classic.load_texts().get(level.upper(), []) if not classic.has_cover(t['id'])]
    lines = [classic.covers.STYLE, ''] + [classic.covers.prompt_for(t).split('\n\n', 1)[1] for t in missing]
    return {'count': len(missing), 'text': '\n'.join(lines)}


@app.get('/cover/{tid}.jpg')
def cover(tid: str):
    path = os.path.join(COVERS, f'{text_id(tid)}.jpg')
    if not os.path.exists(path):
        raise HTTPException(404, 'no cover')
    return FileResponse(path, media_type='image/jpeg', headers={'Cache-Control': 'no-store'})


@app.post('/api/cover/{tid}')
async def put_cover(tid: str, request: Request, crop_top: float = 0.0):
    tid = text_id(tid)
    if not classic.text_detail(tid):
        raise HTTPException(404, 'unknown text')
    data = await request.body()
    with lock:
        reason = classic.put_cover(tid, data, max(0.0, min(crop_top, 0.3)))
    if reason:
        raise HTTPException(400, reason)
    return {'ok': True}


@app.delete('/api/cover/{tid}')
def delete_cover(tid: str):
    with lock:
        classic.remove_cover(text_id(tid))
    return {'ok': True}


@app.post('/api/review/{tid}')
async def review(tid: str, request: Request):
    tid = text_id(tid)
    data = json.loads((await request.body()) or b'{}')
    with lock:
        state = classic.load_review()
        if data.get('status') in ('ok', 'fix'):
            state[tid] = {'status': data['status'], 'note': (data.get('note') or '').strip(),
                          'at': datetime.date.today().isoformat()}
        else:
            state.pop(tid, None)
        classic.save_review(state)
    return {'ok': True}


@app.post('/api/commit')
def commit():
    with lock:
        return classic.commit()


# ---------------------------------------------------------------- pages

@app.get('/classic')
def classic_texts():
    return FileResponse(os.path.join(STUDIO, 'index.html'), headers={'Cache-Control': 'no-store'})


@app.get('/classic/inbox')
def classic_inbox():
    return FileResponse(os.path.join(STUDIO, 'inbox.html'), headers={'Cache-Control': 'no-store'})


@app.get('/{path:path}')
def spa(path: str):
    """The React app: real files from web/dist, every other path gets index.html (client-side routes)."""
    if path.startswith('api/'):
        return JSONResponse({'detail': 'not found'}, status_code=404)
    file = os.path.normpath(os.path.join(DIST, path))
    if path and file.startswith(DIST) and os.path.isfile(file):
        return FileResponse(file)
    index = os.path.join(DIST, 'index.html')
    if not os.path.exists(index):
        return Response('The admin panel is not built yet: cd tools/studio/web && npm install && npm run build. '
                        'The classic Studio is at /classic.', media_type='text/plain', status_code=503)
    return FileResponse(index, headers={'Cache-Control': 'no-store'})


def main():
    import uvicorn
    import socket
    port = int(sys.argv[sys.argv.index('--port') + 1]) if '--port' in sys.argv else 8765
    # Another Studio (e.g. the classic one) may still hold the port: take the next free one.
    for candidate in range(port, port + 20):
        with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as probe:
            if probe.connect_ex(('127.0.0.1', candidate)) != 0:
                if candidate != port:
                    print(f'Port {port} is busy (another Studio window still open?), using {candidate}.')
                port = candidate
                break
    url = f'http://127.0.0.1:{port}/'
    print(f'Deschly Studio: {url}  (close this window to stop)')
    if '--no-browser' not in sys.argv:
        threading.Timer(1.0, lambda: webbrowser.open(url)).start()
    uvicorn.run(app, host='127.0.0.1', port=port, log_level='warning')


if __name__ == '__main__':
    main()

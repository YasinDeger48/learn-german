"""ChatGPT inbox for Deschly Studio: requests to copy, answers to paste, checks before import, pictures to drop,
publishing and saving.

Jobs come from the content tools, so the Studio and the command line use the same rules:
    verbs:<LEVEL>        tools/verblab.py     ../icerik/fiil/<LEVEL>_fiil_istek_NN.txt → <LEVEL>_fiil_cevap_NN.txt
    tr:<lang>:<set>      tools/translate.py   ../icerik/ceviri/<lang>/<set>_istek_NN.txt → <set>_cevap_NN.txt
Pictures (dropped files, named like ChatGPT was asked to):
    unit-a1-03.*         unit picture → Resources/Covers/unit-a1-03.jpg (960×640)
    words-a1-03.*        4×4 word grid → cut into Resources/Covers/wp-a1-<id>.jpg (tools/word_pictures.py)
"""
import contextlib
import glob
import io
import json
import os
import re
import subprocess
import sys

STUDIO = os.path.dirname(os.path.abspath(__file__))
TOOLS = os.path.dirname(STUDIO)
REPO = os.path.dirname(TOOLS)
ICERIK = os.path.normpath(os.path.join(REPO, '..', 'icerik'))
COVERS = os.path.join(REPO, 'Resources', 'Covers')
sys.path.insert(0, TOOLS)
import covers  # noqa: E402
import translate  # noqa: E402
import verblab  # noqa: E402
import word_pictures  # noqa: E402

FIIL = os.path.join(ICERIK, 'fiil')
CEVIRI = os.path.join(ICERIK, 'ceviri')
LANG_NAMES = {'es': 'Spanish', 'fr': 'French', 'it': 'Italian', 'ku': 'Kurmancî', 'ar': 'Arabic'}
SET_NAMES = {'ui': 'app texts', 'a1': 'A1 content', 'a2': 'A2 content', 'b1': 'B1 content', 'b2': 'B2 content'}


def quiet(fn, *args):
    """Runs a tool function and returns what it printed."""
    out = io.StringIO()
    with contextlib.redirect_stdout(out):
        fn(*args)
    return out.getvalue().strip()


def numbers(pattern):
    found = {}
    for path in glob.glob(pattern):
        m = re.search(r'_(\d{2})\.txt$', path)
        if m:
            found[int(m.group(1))] = path
    return found


# ---- jobs

def job_files(job):
    """(requests {n: path}, answers {n: path}, answer path for n) of a job id."""
    kind, _, rest = job.partition(':')
    if kind == 'verbs' and rest in ('A1', 'A2', 'B1', 'B2'):
        req = numbers(os.path.join(FIIL, f'{rest}_fiil_istek_*.txt'))
        ans = numbers(os.path.join(FIIL, f'{rest}_fiil_cevap_*.txt'))
        return req, ans, lambda n: os.path.join(FIIL, f'{rest}_fiil_cevap_{n:02d}.txt')
    if kind == 'tr':
        lang, _, set_name = rest.partition(':')
        if lang in LANG_NAMES and set_name in SET_NAMES:
            folder = os.path.join(CEVIRI, lang)
            req = numbers(os.path.join(folder, f'{set_name}_istek_*.txt'))
            ans = numbers(os.path.join(folder, f'{set_name}_cevap_*.txt'))
            return req, ans, lambda n: os.path.join(folder, f'{set_name}_cevap_{n:02d}.txt')
    raise ValueError('unknown job')


def jobs():
    out = []
    for level in ('A1', 'A2', 'B1', 'B2'):
        req, ans, _ = job_files(f'verbs:{level}')
        done = len(verblab.load(level.lower()))
        total = len(verblab.verbs_by_level()[level.lower()])
        if req or ans or done:
            out.append({'id': f'verbs:{level}', 'group': 'Verb lab', 'title': f'{level} verbs',
                        'requests': sorted(req), 'answers': sorted(ans), 'progress': [done, total],
                        'guide': os.path.join(FIIL, 'GOREV.txt')})
    for lang in LANG_NAMES:
        for set_name in SET_NAMES:
            req, ans, _ = job_files(f'tr:{lang}:{set_name}')
            if req or ans:
                out.append({'id': f'tr:{lang}:{set_name}', 'group': 'Translations',
                            'title': f'{LANG_NAMES[lang]} · {SET_NAMES[set_name]}',
                            'requests': sorted(req), 'answers': sorted(ans), 'progress': None,
                            'guide': os.path.join(CEVIRI, 'GOREV_CHATGPT.txt')})
    return out


def request_text(job, n):
    req, _, _ = job_files(job)
    return open(req[n], encoding='utf-8').read()


def check(job, n):
    _, ans, _ = job_files(job)
    if n not in ans:
        return {'lines': 0, 'ok': 0, 'problems': ['no answer saved yet']}
    kind, _, rest = job.partition(':')
    if kind == 'verbs':
        return verblab.check_file(rest, ans[n])
    lang = rest.partition(':')[0]
    out = io.StringIO()
    with contextlib.redirect_stdout(out):
        result = translate.check_answer(lang, ans[n])
    note = out.getvalue().strip()
    if note:
        result['problems'].insert(0, note)
    return result


def save_answer(job, n, text):
    req, _, path_for = job_files(job)
    if n not in req:
        raise ValueError('no request with this number')
    text = text.strip()
    # ChatGPT often wraps the answer in a code block.
    text = re.sub(r'^```[a-zA-Z]*\s*', '', text)
    text = re.sub(r'\s*```$', '', text)
    if not text:
        raise ValueError('empty answer')
    with open(path_for(n), 'w', encoding='utf-8', newline='\n') as f:
        f.write(text + '\n')
    return check(job, n)


def import_job(job):
    kind, _, rest = job.partition(':')
    if kind == 'verbs':
        return quiet(verblab.import_answers, rest)
    lang = rest.partition(':')[0]
    return quiet(translate.import_, lang)


def open_folder(job):
    req, _, path_for = job_files(job)
    folder = os.path.dirname(path_for(1))
    if hasattr(os, 'startfile'):
        os.startfile(folder)  # Windows
    else:
        subprocess.Popen(['open' if sys.platform == 'darwin' else 'xdg-open', folder])


# ---- pictures

def unit_status():
    units = json.load(open(os.path.join(REPO, 'Resources', 'content', 'units.json'), encoding='utf-8'))['units']
    out = []
    for u in units:
        level = u['level'].lower()
        pictures = u.get('pictures') or []
        out.append({'id': u['id'], 'level': u['level'], 'number': u['number'], 'title': u['title']['en'],
                    'titleTr': u['title']['tr'], 'cover': u['cover'],
                    'hasCover': os.path.exists(os.path.join(COVERS, u['cover'] + '.jpg')),
                    'grid': f'words-{u["id"]}' if pictures else None,
                    'gridDone': sum(1 for w in pictures if os.path.exists(os.path.join(COVERS, f'wp-{level}-{w}.jpg'))),
                    'gridTotal': len(pictures)})
    return out


def put_picture(filename, data):
    """A dropped picture, recognised by its name. Returns a short message and the pictures it made."""
    from PIL import Image
    base = os.path.splitext(os.path.basename(filename))[0].lower().strip()
    m = re.fullmatch(r'unit-(a1|a2|b1|b2)-(\d{2})', base)
    if m:
        reason = covers.save_cover(Image.open(io.BytesIO(data)), base, 0.0)
        if reason:
            raise ValueError(f'{base}: {reason}')
        keep = os.path.join(ICERIK, 'gorseller')
        os.makedirs(keep, exist_ok=True)
        open(os.path.join(keep, os.path.basename(filename)), 'wb').write(data)
        return {'message': f'{base}: unit picture saved', 'pictures': [base]}
    m = re.fullmatch(r'words-(a1-\d{2})', base)
    if m:
        uid = m.group(1)
        if uid not in word_pictures.PICTURE_WORDS:
            raise ValueError(f'{base}: no word list for unit {uid}')
        keep = os.path.join(ICERIK, 'gorseller', os.path.basename(filename))
        open(keep, 'wb').write(data)
        note = quiet(word_pictures.cut, uid, keep)
        made = [f'wp-a1-{w}' for w in word_pictures.PICTURE_WORDS[uid] if os.path.exists(os.path.join(COVERS, f'wp-a1-{w}.jpg'))]
        return {'message': note or f'{base}: cut', 'pictures': made}
    raise ValueError(f'"{filename}": name it unit-a1-03.jpg (unit picture) or words-a1-03.jpg (word grid)')


# ---- publish and save

def publish():
    run = subprocess.run([sys.executable, '-I', '-X', 'utf8', os.path.join(TOOLS, 'publish_content.py')], cwd=REPO,
                         capture_output=True, text=True, encoding='utf-8')
    return (run.stdout + run.stderr).strip()


def git(*args):
    return subprocess.run(['git', '-c', f'safe.directory={REPO.replace(os.sep, "/")}', *args], cwd=REPO,
                          capture_output=True, text=True, encoding='utf-8')


# Only what the Studio and the content tools write. Covers: only unit and word pictures (other agents may have
# unsaved text covers in the same folder; those are saved from the Texts page).
SAVE_PATHS = ['Resources/content', 'Resources/i18n', 'tools/i18n', 'tools/content_edits.json',
              ':(glob)Resources/Covers/unit-*.jpg', ':(glob)Resources/Covers/wp-*.jpg']


def content_changes():
    out = git('status', '--porcelain', '--untracked-files=all', '--', *SAVE_PATHS).stdout
    return [line[3:] for line in out.splitlines() if line.strip()]


def save_content():
    files = content_changes()
    if not files:
        return {'ok': True, 'message': 'Nothing to save.'}
    groups = []
    for label, test in (('content', lambda f: f.startswith('Resources/content')),
                        ('translations', lambda f: f.startswith(('Resources/i18n', 'tools/i18n'))),
                        ('pictures', lambda f: f.startswith('Resources/Covers'))):
        n = sum(1 for f in files if test(f))
        if n:
            groups.append(f'{label} ({n})')
    add = git('add', '--', *files)
    if add.returncode != 0:
        return {'ok': False, 'message': add.stderr.strip()[:300]}
    result = git('commit', '-q', '-m', 'Studio: ' + ', '.join(groups), '--', *files)
    if result.returncode != 0:
        return {'ok': False, 'message': (result.stderr or result.stdout).strip()[:300]}
    return {'ok': True, 'message': 'Saved: ' + git('log', '--oneline', '-1').stdout.strip()}

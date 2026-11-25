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

LOOPBACK = ('127.0.0.1', 'localhost', '[::1]', '::1')


def allowed(method, headers):
    """Only the Studio's own pages may use it. A web page the owner happens to visit while the Studio runs could
otherwise send it requests (it listens on a fixed local port): every request must name a loopback host (stops DNS
rebinding), and a request that changes something must come from a loopback page (Origin / Sec-Fetch-Site)."""
    host = (headers.get('host') or '').rsplit(':', 1)[0] if not (headers.get('host') or '').startswith('[') \
        else (headers.get('host') or '').split(']')[0] + ']'
    if host not in LOOPBACK:
        return False
    if method in ('GET', 'HEAD', 'OPTIONS'):
        return True
    origin = headers.get('origin')
    if origin:
        from urllib.parse import urlparse
        return (urlparse(origin).hostname or '') in LOOPBACK
    return headers.get('sec-fetch-site') in (None, 'same-origin', 'none')


@app.middleware('http')
async def local_only(request: Request, call_next):
    if not allowed(request.method, request.headers):
        return JSONResponse({'detail': 'Deschly Studio accepts requests only from its own page.'}, status_code=403)
    return await call_next(request)


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


# ---------------------------------------------------------------- path units and verb lab

@app.get('/api/units')
def units_full():
    """Every unit with what its steps point at, resolved to titles (read-only view of units.json)."""
    units = load('units.json')['units']
    added_phrases = set(added_ids('units.json', 'phrases'))
    speaking = {t['id']: t for t in load('speaking.json')['tasks']}
    writing = {t['id']: t for t in load('writing.json')['tasks']}
    texts = {t['id']: t for items in classic.load_texts().values() for t in items}
    by_level = {}
    out = []
    for u in units:
        lv = u['level'].lower()
        if lv not in by_level:
            data = load(f'{lv}.json')
            by_level[lv] = {'grammar': {g['id']: g for g in data['grammar']},
                            'themes': {t['id']: t for t in data.get('themes', [])},
                            'words': {w['id']: w for w in data['words']}}
        ref = by_level[lv]
        words = []
        if u.get('vocab'):
            words = [{'de': w['de'], 'article': w.get('art'), 'meaning': w['tr'], 'picture': None} for w in u['vocab']]
        else:
            for wid in u.get('pictures') or []:
                w = ref['words'].get(wid)
                if not w:
                    continue
                article = w['type'] if w['type'] in ('der', 'die', 'das') else None
                file = f'wp-{lv}-{wid}'
                words.append({'de': w['de'], 'article': article, 'meaning': w['mean'].get('tr', ''),
                              'picture': file if os.path.exists(os.path.join(COVERS, file + '.jpg')) else None})
        out.append({
            'id': u['id'], 'level': u['level'], 'number': u['number'], 'title': u['title'], 'goal': u['goal'],
            'cover': u['cover'], 'hasCover': os.path.exists(os.path.join(COVERS, u['cover'] + '.jpg')),
            'themes': [ref['themes'][t]['name']['tr'] for t in u['themes'] if t in ref['themes']],
            'grammar': [{'id': g, 'de': ref['grammar'][g]['de'], 'name': ref['grammar'][g]['name'].get('tr', '')}
                        for g in u['grammar'] if g in ref['grammar']],
            'texts': [{'id': t, 'title': texts[t]['title'] if t in texts else t, 'cover': classic.has_cover(t)} for t in u['texts']],
            'speaking': [{'id': t, 'title': speaking[t]['title']['tr'] if t in speaking else t} for t in u['speaking']],
            'writing': [{'id': t, 'title': writing[t]['title']['tr'] if t in writing else t} for t in u['writing']],
            'phrases': [dict(p, added=(p['de'],) in added_phrases) for p in u['phrases']],
            'words': words,
        })
    return out


@app.get('/api/verbs/{level}')
def verbs(level: str):
    lv = level.lower()
    if lv not in ('a1', 'a2', 'b1', 'b2'):
        raise HTTPException(404, 'unknown level')
    ready = {v['v'].lower(): v for v in verblab.load(lv)}
    out = []
    for w in verblab.verbs_by_level()[lv]:
        entry = ready.get(w['de'].lower())
        out.append({'v': w['de'], 'meaning': (w.get('mean') or {}).get('tr', ''), 'entry': entry})
    return {'level': level.upper(), 'ready': len(ready), 'verbs': out}


# ---------------------------------------------------------------- words, grammar, tasks, translations

def broken(text):
    """Text damaged by a wrong encoding somewhere on the way (ü → ??)."""
    return isinstance(text, str) and ('??' in text or '\ufffd' in text)


def level_file(level):
    lv = level.lower()
    if lv not in ('a1', 'a2', 'b1', 'b2'):
        raise HTTPException(404, 'unknown level')
    return lv, load(f'{lv}.json')


@app.get('/api/words/{level}')
def words(level: str):
    lv, data = level_file(level)
    themes = {t['id']: t['name'].get('tr', t['de']) for t in data.get('themes', [])}
    out = []
    for w in data['words']:
        mean = w.get('mean') or {}
        out.append({'id': w['id'], 'de': w['de'], 'type': w['type'], 'theme': themes.get(w.get('theme'), ''),
                    'plural': w.get('plural'), 'pron': w.get('pron', ''), 'tr': mean.get('tr', ''), 'en': mean.get('en', ''),
                    'mean': mean,
                    'examples': [{'de': e['de'], 'tr': e['mean'].get('tr', ''), 'en': e['mean'].get('en', ''), 'mean': e['mean']}
                                 for e in w.get('ex', [])],
                    'broken': any(broken(x) for x in [mean.get('tr'), mean.get('en')] + [e['mean'].get('en') for e in w.get('ex', [])])})
    mine = set(added_ids(f'{lv}.json', 'words'))
    for w in out:
        w['added'] = (w['de'], w['type']) in mine
    return {'level': lv.upper(), 'themes': sorted(set(themes.values())),
            'themeList': [{'id': k, 'name': v} for k, v in themes.items()], 'words': out}


@app.get('/api/grammar/{level}')
def grammar(level: str):
    lv, data = level_file(level)
    items = data.get('grammarItems', [])
    out = []
    for g in data['grammar']:
        mine = [i for i in items if i['topic'] == g['id']]
        out.append({
            'id': g['id'], 'de': g['de'], 'name': g['name'], 'rule': g['rule'],
            'examples': [{'de': e['de'], 'tr': e['mean'].get('tr', ''), 'en': e['mean'].get('en', ''), 'mean': e['mean']}
                         for e in g.get('examples', [])],
            'items': [{'q': i['q'], 'answer': i['options'][0] if i['options'] else '', 'options': i['options'],
                       'why': i.get('why', {}), 'broken': broken((i.get('why') or {}).get('en')) or broken((i.get('why') or {}).get('tr'))}
                      for i in mine],
        })
    mine = {k[0] for k in added_ids(f'{lv}.json', 'grammarItems')}
    for t in out:
        for i in t['items']:
            i['added'] = i['q'] in mine
    return {'level': lv.upper(), 'topics': out, 'broken': sum(1 for t in out for i in t['items'] if i['broken'])}


@app.get('/api/tasks')
def tasks():
    return {'writing': load('writing.json')['tasks'], 'speaking': load('speaking.json')['tasks'],
            'pattern': load('writing.json').get('pattern')}


def content_totals():
    """Unique English source texts per content set (what each language has to translate)."""
    totals = {}
    for set_name, files in translate.SETS.items():
        seen = set()
        for name in files:
            found = []
            translate.walk(translate.load_content(name)[2], found)
            seen.update(o['en'] for o in found if o['en'].strip())
        totals[set_name] = seen
    return totals


@app.get('/api/translations')
def translations(sample: str = ''):
    totals = content_totals()
    en_ui = json.load(open(os.path.join(REPO, 'Resources', 'i18n', 'strings_en.json'), encoding='utf-8'))
    langs = []
    for code, name in (('es', 'Español'), ('fr', 'Français'), ('it', 'Italiano'), ('ku', 'Kurmancî'), ('ar', 'العربية')):
        known = translate.memory(code)[1]
        sets = [{'set': k, 'total': len(v), 'done': sum(1 for t in v if t in known)} for k, v in totals.items()]
        ui_left = len(translate.ui_missing(code))
        langs.append({'code': code, 'name': name, 'ui': {'total': len(en_ui), 'done': len(en_ui) - ui_left}, 'sets': sets})
    out = {'languages': langs}
    if sample in LANG_CODES:
        import random
        known = translate.memory(sample)[1]
        tr_of = {}
        for files in translate.SETS.values():
            for name in files:
                found = []
                translate.walk(translate.load_content(name)[2], found)
                for o in found:
                    tr_of.setdefault(o['en'], o['tr'])
        own = json.load(open(os.path.join(REPO, 'Resources', 'i18n', f'strings_{sample}.json'), encoding='utf-8'))
        tr_ui = json.load(open(os.path.join(REPO, 'Resources', 'i18n', 'strings_tr.json'), encoding='utf-8'))
        ui_pairs = [{'en': en_ui[k], 'tr': tr_ui.get(k, ''), 'text': own[k], 'where': 'app'} for k in en_ui if own.get(k) and own[k] != en_ui[k]]
        content_pairs = [{'en': en, 'tr': tr_of.get(en, ''), 'text': text, 'where': 'content'} for en, text in known.items()]
        rng = random.Random()
        out['sample'] = rng.sample(ui_pairs, min(12, len(ui_pairs))) + rng.sample(content_pairs, min(18, len(content_pairs)))
    return out


LANG_CODES = ('es', 'fr', 'it', 'ku', 'ar')


# ---------------------------------------------------------------- editing

import content_edits  # noqa: E402


@app.post('/api/edit')
async def edit_text(request: Request):
    """One text field: {file, collection, keyField, key, path, value}. Recorded in tools/content_edits.json."""
    body = json.loads(await request.body() or b'{}')
    try:
        with lock:
            old = content_edits.edit(str(body.get('file', '')), str(body.get('collection', '')), str(body.get('keyField', '')),
                                     body.get('key'), str(body.get('path', '')), str(body.get('value', '')))
            remember_translation(body)
        return {'ok': True, 'old': old}
    except (OSError, ValueError, KeyError, IndexError) as e:
        bad(e)


def remember_translation(body):
    """A Studio edit of es/fr/it/ku/ar also goes into tools/i18n/content_<lang>.json (English → translation),
    so importing ChatGPT answers later does not bring the old translation back."""
    path = str(body.get('path', ''))
    lang = path.rsplit('.', 1)[-1]
    if lang not in LANG_CODES:
        return
    _, _, data = content_edits.read_file(str(body.get('file', '')))
    node, _ = content_edits.locate(data, str(body.get('collection', '')), str(body.get('keyField', '')), body.get('key'), path)
    english = node.get('en') if isinstance(node, dict) else None
    if not isinstance(english, str) or not english.strip():
        return
    memory = os.path.join(TOOLS, 'i18n', f'content_{lang}.json')
    known = json.load(open(memory, encoding='utf-8')) if os.path.exists(memory) else {}
    known[english] = str(body.get('value', '')).strip()
    with open(memory, 'w', encoding='utf-8', newline='\n') as f:
        json.dump(known, f, ensure_ascii=False, indent=0)


@app.get('/api/edits')
def edits():
    return list(reversed(content_edits.load_edits()))


def required(value, name):
    value = str(value or '').strip()
    if not value:
        raise ValueError(f'{name} is empty')
    return value


def new_item(kind, body, data):
    """Checks a new word / exercise / phrase from the Studio and builds it in the content file's shape."""
    if kind == 'word':
        word_type = required(body.get('type'), 'type')
        if word_type not in ('der', 'die', 'das', 'verb', 'word'):
            raise ValueError('type must be der, die, das, verb or word')
        theme = int(body.get('theme'))
        if theme not in {t['id'] for t in data.get('themes', [])}:
            raise ValueError('unknown theme')
        item = {'theme': theme, 'type': word_type, 'de': required(body.get('de'), 'German'), 'pron': '',
                'mean': {'tr': required(body.get('tr'), 'Turkish'), 'en': required(body.get('en'), 'English')}, 'ex': []}
        if word_type in ('der', 'die', 'das') and str(body.get('plural') or '').strip():
            item['plural'] = str(body['plural']).strip()
        if str(body.get('exDe') or '').strip():
            item['ex'] = [{'de': required(body.get('exDe'), 'example'), 'pron': '',
                           'mean': {'tr': required(body.get('exTr'), 'example (Turkish)'), 'en': required(body.get('exEn'), 'example (English)')}}]
        return 'words', item, None
    if kind == 'exercise':
        topic = int(body.get('topic'))
        if topic not in {g['id'] for g in data.get('grammar', [])}:
            raise ValueError('unknown grammar topic')
        q = required(body.get('q'), 'sentence')
        if '___' not in q:
            raise ValueError('mark the gap with ___')
        options = [required(body.get('answer'), 'correct answer')] + [o.strip() for o in str(body.get('wrong') or '').split(',') if o.strip()]
        if len(options) < 2 or len(set(options)) != len(options):
            raise ValueError('give at least one wrong option, all different from the answer')
        item = {'topic': topic, 'q': q, 'options': options,
                'why': {'tr': required(body.get('whyTr'), 'explanation (Turkish)'), 'en': required(body.get('whyEn'), 'explanation (English)')}}
        return 'grammarItems', item, None
    if kind == 'phrase':
        unit = required(body.get('unit'), 'unit')
        item = {'de': required(body.get('de'), 'German'), 'tr': required(body.get('tr'), 'Turkish'), 'en': required(body.get('en'), 'English')}
        return 'units', item, {'keyField': 'id', 'key': unit, 'path': 'phrases'}
    raise ValueError('unknown kind')


@app.post('/api/add')
async def add_item(request: Request):
    """{kind: word|exercise|phrase, file, ...fields}. Recorded in tools/content_edits.json like an edit."""
    body = json.loads(await request.body() or b'{}')
    try:
        file = str(body.get('file', ''))
        data = content_edits.read_file(file)[2]
        collection, item, parent = new_item(str(body.get('kind', '')), body, data)
        with lock:
            stored = content_edits.add(file, collection, item, parent)
        return {'ok': True, 'item': stored}
    except (OSError, ValueError, TypeError, KeyError) as e:
        bad(e)


@app.post('/api/remove')
async def remove_item(request: Request):
    """Removes an item added in the Studio: {file, collection, item, parent}."""
    body = json.loads(await request.body() or b'{}')
    try:
        with lock:
            content_edits.remove(str(body.get('file', '')), str(body.get('collection', '')), body.get('item') or {}, body.get('parent'))
        return {'ok': True}
    except (OSError, ValueError, KeyError) as e:
        bad(e)


def added_ids(file, kind):
    """Identities of items added in the Studio, to mark them (and allow removing them)."""
    fields = content_edits.IDENTITY[kind]
    return [tuple(e['item'].get(f) for f in fields) for e in content_edits.added(file)
            if (e.get('parent') or {}).get('path', e['collection']) == kind]


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

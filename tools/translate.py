"""Translations into the other learner languages (es, fr, it, ku = Kurmancî, ar = Arabic) with ChatGPT.

    python -I -X utf8 tools/translate.py status
    python -I -X utf8 tools/translate.py export es ui          UI texts (Resources/i18n) still in English
    python -I -X utf8 tools/translate.py export es a1          A1 content (a1, daily_a1, lexicon, units, writing, speaking, memorize)
    python -I -X utf8 tools/translate.py export es a2|b1|b2    content of that level
    python -I -X utf8 tools/translate.py import es             reads every answer file of that language

Requests go to ../icerik/ceviri/<lang>/<set>_istek_NN.txt, ChatGPT's answers are saved next to them as
<set>_cevap_NN.txt (one JSON object per line: {"id": "tab.path", "t": "..."}).
Ids are the UI key, or "c" + a hash of the English text for content, so an answer still lands on the right text
when it was made from another language's request. Old numbered answers are matched to the request they fit best.

Content: every {"tr": …, "en": …} object in Resources/content/*.json is a learner-language text. The English text is
the source (Turkish is given as context); translations are remembered in tools/i18n/content_<lang>.json
(English → translation), so a regenerated content file gets them back with `import`. Missing translations fall
back to English in the app (LocText).
"""
import glob
import hashlib
import json
import os
import re
import sys

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CONTENT = os.path.join(REPO, 'Resources', 'content')
I18N = os.path.join(REPO, 'Resources', 'i18n')
MEMORY = os.path.join(REPO, 'tools', 'i18n')
OUTDIR = os.path.join(os.path.dirname(REPO), 'icerik', 'ceviri')
LANGS = {'es': 'Spanish', 'fr': 'French', 'it': 'Italian', 'ku': 'Kurmanji Kurdish (Kurmancî, Latin script, Hawar alphabet)',
         'ar': 'Arabic (Modern Standard Arabic)'}
ALL_LANGS = {'tr', 'en', *LANGS}
INFORMAL = {'es': 'tú', 'fr': 'tu', 'it': 'tu', 'ku': 'tu', 'ar': 'أنت'}
SETS = {
    'a1': ['a1.json', 'daily_a1.json', 'lexicon.json', 'units.json', 'writing.json', 'speaking.json', 'memorize.json'],
    'a2': ['a2.json', 'daily_a2.json'],
    'b1': ['b1.json', 'daily_b1.json'],
    'b2': ['b2.json', 'daily_b2.json'],
}
BATCH_CHARS = 9000
BATCH_MAX = 160


def is_loc(o):
    return isinstance(o, dict) and isinstance(o.get('en'), str) and isinstance(o.get('tr'), str) and set(o) <= ALL_LANGS


def walk(o, found):
    if is_loc(o):
        found.append(o)
    elif isinstance(o, dict):
        for v in o.values():
            walk(v, found)
    elif isinstance(o, list):
        for v in o:
            walk(v, found)


def load_content(name):
    path = os.path.join(CONTENT, name)
    raw = open(path, encoding='utf-8').read()
    return path, raw, json.loads(raw)


def save_content(path, raw, data):
    with open(path, 'w', encoding='utf-8', newline='\n') as f:
        if raw.startswith('{"'):
            json.dump(data, f, ensure_ascii=False, separators=(',', ':'))
        else:
            indent = 1 if raw.startswith('{\n "') else 2
            json.dump(data, f, ensure_ascii=False, indent=indent)
            f.write('\n')


def memory(lang):
    path = os.path.join(MEMORY, f'content_{lang}.json')
    return path, (json.load(open(path, encoding='utf-8')) if os.path.exists(path) else {})


def ui_tables(lang):
    en = json.load(open(os.path.join(I18N, 'strings_en.json'), encoding='utf-8'))
    tr = json.load(open(os.path.join(I18N, 'strings_tr.json'), encoding='utf-8'))
    path = os.path.join(I18N, f'strings_{lang}.json')
    own = json.load(open(path, encoding='utf-8')) if os.path.exists(path) else {}
    return en, tr, path, own


def ui_missing(lang):
    en, tr, _, own = ui_tables(lang)
    # Untranslated = still the English text (brand names and the like are fine to keep: ChatGPT returns them unchanged).
    return [(k, en[k], tr.get(k, '')) for k in sorted(en) if own.get(k, en[k]) == en[k] and re.search('[A-Za-z]{3}', en[k])]


def content_missing(lang, set_name):
    _, known = memory(lang)
    seen, out = set(), []
    for name in SETS[set_name]:
        found = []
        walk(load_content(name)[2], found)
        for o in found:
            if o.get(lang) or o['en'] in known or o['en'] in seen or not o['en'].strip():
                continue
            seen.add(o['en'])
            out.append((None, o['en'], o['tr']))
    return out


def rules(lang, set_name):
    target = LANGS[lang]
    lines = [
        f'TASK: Translate the English texts below into {target}. They are from Deschly, an app for learning German.',
        'The Turkish text ("tr") is the same meaning, only for context. Do not translate from it.',
        'RULES:',
        '- Answer ONLY with JSON lines, one per input line, same order: {"id": <same id>, "t": "<translation>"}',
        '- No other text, no code fences, no comments, no numbering.',
        '- Keep placeholders exactly: {0}, {1}, …; keep emoji, line breaks (\\n), punctuation marks like … and %.',
        '- Keep German words and sentences unchanged (anything in German, words in quotes or after "=", grammar terms '
        'like Akkusativ, Perfekt, der/die/das). Translate only the explanation around them.',
        '- Keep the brand name Deschly and the mascot name Lina.',
        '- Short and natural, like a modern app. Address the learner informally (' + INFORMAL[lang] + ').',
    ]
    if set_name == 'ui':
        lines.append('- These are interface texts (buttons, titles): keep them as short as the English.')
    if lang == 'ku':
        lines.append('- Kurmancî in Latin script (Hawar: ç, ê, î, ş, û). Not Sorani, not Arabic script.')
    if lang == 'ar':
        lines.append('- Modern Standard Arabic, without diacritics except where needed. Keep numbers as 0-9.')
    lines.append('')
    lines.append('INPUT:')
    return lines


def export(lang, set_name):
    assert lang in LANGS, f'language: {", ".join(LANGS)}'
    items = ui_missing(lang) if set_name == 'ui' else content_missing(lang, set_name)
    folder = os.path.join(OUTDIR, lang)
    os.makedirs(folder, exist_ok=True)
    for old in glob.glob(os.path.join(folder, f'{set_name}_istek_*.*')):
        os.remove(old)
    batches, current, size = [], [], 0
    for item in items:
        length = len(item[1]) + len(item[2])
        if current and (size + length > BATCH_CHARS or len(current) >= BATCH_MAX):
            batches.append(current)
            current, size = [], 0
        current.append(item)
        size += length
    if current:
        batches.append(current)
    for n, batch in enumerate(batches, 1):
        manifest = {}
        lines = rules(lang, set_name)
        for key, en, tr in batch:
            ident = key if set_name == 'ui' else content_id(en)
            manifest[ident] = key if set_name == 'ui' else en
            lines.append(json.dumps({'id': ident, 'en': en, 'tr': tr}, ensure_ascii=False))
        base = os.path.join(folder, f'{set_name}_istek_{n:02d}')
        open(base + '.txt', 'w', encoding='utf-8', newline='\r\n').write('\n'.join(lines) + '\n')
        json.dump(manifest, open(base + '.json', 'w', encoding='utf-8', newline='\n'), ensure_ascii=False)
    print(f'{lang} {set_name}: {len(items)} texts in {len(batches)} requests -> {folder}')


def content_id(en):
    return 'c' + hashlib.sha1(en.encode('utf-8')).hexdigest()[:9]


def fits(source, text):
    """Rough sign that `text` translates `source`: same placeholders, similar length."""
    return check(source, text) and 0.35 < len(text) / max(1, len(source)) < 3.2


def pick_manifest(set_name, answers, own_path, en):
    """Numbered answers: the request (of any language, same set) whose texts they fit best; own request on a tie."""
    def source(manifest, i):
        value = manifest.get(i)
        return None if value is None else (en.get(value, '') if set_name == 'ui' else value)

    def score(manifest):
        hits = sum(1 for i, t in answers.items() if source(manifest, i) is not None and fits(source(manifest, i), t))
        return hits / max(1, len(answers))

    own = json.load(open(own_path, encoding='utf-8'))
    best, best_score, best_path = own, score(own), own_path
    for path in glob.glob(os.path.join(OUTDIR, '*', f'{set_name}_istek_*.json')):
        manifest = json.load(open(path, encoding='utf-8'))
        value = score(manifest)
        if value > best_score + 0.05:
            best, best_score, best_path = manifest, value, path
    if best_path != own_path:
        print(f'  {os.path.basename(own_path)[:-5]}: answers follow {os.path.relpath(best_path, OUTDIR)} (fit {best_score:.0%})')
    return best


def check(source, text):
    """Placeholders must survive."""
    return sorted(re.findall(r'\{\d\}', source)) == sorted(re.findall(r'\{\d\}', text))


def read_answers(path):
    out = {}
    for line in open(path, encoding='utf-8-sig'):
        line = line.strip().strip(',')
        if not line.startswith('{'):
            continue
        try:
            obj = json.loads(line)
        except json.JSONDecodeError:
            print(f'  skipped (not JSON): {line[:60]}')
            continue
        if isinstance(obj.get('t'), str) and obj['t'].strip():
            out[str(obj.get('id'))] = obj['t'].strip()
    return out


def import_(lang):
    folder = os.path.join(OUTDIR, lang)
    mem_path, known = memory(lang)
    en, tr, ui_path, own = ui_tables(lang)
    ui_new = content_new = bad = 0
    for answer in sorted(glob.glob(os.path.join(folder, '*_cevap_*.txt'))):
        set_name, _, n = os.path.basename(answer)[:-4].partition('_cevap_')
        manifest_path = os.path.join(folder, f'{set_name}_istek_{n}.json')
        if not os.path.exists(manifest_path):
            print(f'  no request for {os.path.basename(answer)}')
            continue
        answers = read_answers(answer)
        if all(i.isdigit() for i in answers):
            manifest = pick_manifest(set_name, answers, manifest_path, en)
            missing = [i for i in manifest if i not in answers]
            if missing:
                print(f'  {os.path.basename(answer)}: {len(missing)} of {len(manifest)} lines missing')
        else:
            # Key / hash ids: valid for any request of this set.
            manifest = {}
            for path in glob.glob(os.path.join(OUTDIR, '*', f'{set_name}_istek_*.json')):
                manifest.update(json.load(open(path, encoding='utf-8')))
            if set_name == 'ui':
                manifest.update({k: k for k in en})
            unknown = [i for i in answers if i not in manifest]
            if unknown:
                print(f'  {os.path.basename(answer)}: {len(unknown)} unknown ids, e.g. {unknown[0]}')
        for i, text in answers.items():
            if i not in manifest:
                continue
            source = en.get(manifest[i], '') if set_name == 'ui' else manifest[i]
            if not check(source, text):
                bad += 1
                print(f'  placeholder mismatch, skipped: {source[:50]} -> {text[:50]}')
                continue
            if set_name == 'ui':
                if own.get(manifest[i]) != text:
                    own[manifest[i]] = text
                    ui_new += 1
            elif known.get(source) != text:
                known[source] = text
                content_new += 1
    # UI file: every English key, translated where we have it.
    table = {k: own.get(k, v) for k, v in en.items()}
    raw = open(os.path.join(I18N, 'strings_en.json'), encoding='utf-8').read()
    indent = 1 if raw.startswith('{\n "') else 2
    open(ui_path, 'w', encoding='utf-8', newline='\n').write(json.dumps(table, ensure_ascii=False, indent=indent) + '\n')
    os.makedirs(MEMORY, exist_ok=True)
    json.dump(known, open(mem_path, 'w', encoding='utf-8', newline='\n'), ensure_ascii=False, indent=0)
    applied = apply(lang, known)
    print(f'{lang}: UI +{ui_new}, content +{content_new} (memory {len(known)}), written into content {applied}, rejected {bad}')


def apply(lang, known):
    total = 0
    for path in sorted(glob.glob(os.path.join(CONTENT, '*.json'))):
        name = os.path.basename(path)
        _, raw, data = load_content(name)
        found = []
        walk(data, found)
        changed = 0
        for o in found:
            text = known.get(o['en'])
            if text and o.get(lang) != text:
                o[lang] = text
                changed += 1
        if changed:
            save_content(path, raw, data)
            total += changed
    return total


def status():
    for lang in LANGS:
        _, known = memory(lang)
        parts = [f'ui {len(ui_missing(lang))} left']
        for set_name in SETS:
            parts.append(f'{set_name} {len(content_missing(lang, set_name))} left')
        print(f'{lang}: ' + ', '.join(parts) + f'  (memory {len(known)})')


if __name__ == '__main__':
    cmd = sys.argv[1] if len(sys.argv) > 1 else 'status'
    if cmd == 'export':
        export(sys.argv[2], sys.argv[3])
    elif cmd == 'import':
        import_(sys.argv[2])
    else:
        status()

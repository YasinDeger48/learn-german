"""Writes translation packs for a learner language, and checks packs that come back.

Export (English source, 400 lines per file):
    python -I -X utf8 tools/i18n_export.py export es ../icerik/ceviri

Check and import translated files (same "key :: text" format) into tools/i18n/<lang>/:
    python -I -X utf8 tools/i18n_export.py import es ../icerik/ceviri/es_geri

Then rebuild: python -I -X utf8 tools/pack_content.py tools/data/a1_raw.json Resources/content/a1.json
"""
import glob
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
LANG_NAMES = {'es': 'Spanish', 'fr': 'French', 'it': 'Italian'}


def read_pairs(path):
    pairs = {}
    for line in open(path, encoding='utf-8'):
        key, sep, text = line.rstrip('\n').partition(' :: ')
        if sep and text.strip():
            pairs[key.strip()] = text.strip()
    return pairs


def english():
    table = {}
    for path in sorted(glob.glob(os.path.join(HERE, 'i18n', 'en', '*.txt'))):
        table.update(read_pairs(path))
    return table


def done(lang):
    table = {}
    for path in sorted(glob.glob(os.path.join(HERE, 'i18n', lang, '*.txt'))):
        table.update(read_pairs(path))
    return table


def export(lang, out_dir):
    src = english()
    have = done(lang)
    todo = [(k, v) for k, v in src.items() if k not in have]
    os.makedirs(out_dir, exist_ok=True)
    size = 400
    for n in range(0, len(todo), size):
        part = todo[n:n + size]
        path = os.path.join(out_dir, f'{lang}_part_{n // size + 1:02d}.txt')
        with open(path, 'w', encoding='utf-8', newline='\n') as f:
            for k, v in part:
                f.write(f'{k} :: {v}\n')
    prompt = os.path.join(out_dir, f'{lang}_PROMPT.txt')
    with open(prompt, 'w', encoding='utf-8', newline='\n') as f:
        f.write(f'''Translate this file from English into {LANG_NAMES[lang]} for a German-learning app.
Rules:
- Keep every line as "key :: text". Do not change, drop, merge or reorder keys.
- Translate only the text after " :: ".
- Keep German words, articles (der/die/das), grammar terms, numbers, names and symbols (→ · / „ “) exactly as they are.
- Word meanings stay short (like a dictionary entry). Sentences stay natural and simple.
- Answer with the complete file only, nothing else.
''')
    print(f'{len(todo)} lines → {(len(todo) + size - 1) // size} files in {out_dir}')


def import_(lang, in_dir):
    src = english()
    dest = os.path.join(HERE, 'i18n', lang)
    os.makedirs(dest, exist_ok=True)
    total = 0
    for path in sorted(glob.glob(os.path.join(in_dir, '*.txt'))):
        if path.endswith('_PROMPT.txt'):
            continue
        pairs = read_pairs(path)
        unknown = [k for k in pairs if k not in src]
        if unknown:
            raise SystemExit(f'{os.path.basename(path)}: unknown keys, e.g. {unknown[:3]}')
        same = [k for k, v in pairs.items() if v == src[k] and any(c.isalpha() for c in v) and len(v) > 12]
        if len(same) > len(pairs) * 0.2:
            print(f'warning {os.path.basename(path)}: {len(same)} lines look untranslated')
        name = os.path.join(dest, os.path.basename(path))
        with open(name, 'w', encoding='utf-8', newline='\n') as f:
            for k, v in pairs.items():
                f.write(f'{k} :: {v}\n')
        total += len(pairs)
    missing = len(src) - len(done(lang))
    print(f'imported {total} lines; {missing} still missing for {lang}')


if __name__ == '__main__':
    action, lang, folder = sys.argv[1], sys.argv[2], sys.argv[3]
    if lang not in LANG_NAMES:
        raise SystemExit('lang must be es, fr or it')
    export(lang, folder) if action == 'export' else import_(lang, folder)

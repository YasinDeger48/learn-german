"""English packs for a level whose source text is Turkish (B1, B2 …), with the German as context.

Export (500 lines per file, only keys without English yet):
    python -I -X utf8 tools/en_export.py export b1 ../icerik/ceviri_en

Check and import the translated files ("key :: English", same keys) into tools/i18n/en/:
    python -I -X utf8 tools/en_export.py import b1 ../icerik/ceviri_en/geri

Then rebuild: python -I -X utf8 tools/pack_content.py tools/data/b1_raw.json Resources/content/b1.json --prefix b1.
"""
import glob
import json
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
PART = 500

PROMPT = """Translate this file from Turkish into English for a German-learning app (level {level}).
Each line is: key :: Turkish text ⟦DE: German original⟧
Rules:
- Answer with lines "key :: English" only: same keys, same order, one line per key, nothing else.
- Drop the ⟦DE: …⟧ part; use it only to get the meaning right.
- Word meanings (keys like {p}w.12): short dictionary style, verbs with "to …" (to cancel, to put up with).
- Example sentences and grammar notes: natural, simple English that matches the German.
- Keep German words, articles (der/die/das), grammar terms (Konjunktiv II, Passiv, Dativ …), names and symbols (→ · / „ “ ___) exactly as they are.
"""


def english_done():
    table = {}
    for path in glob.glob(os.path.join(HERE, 'i18n', 'en', '*.txt')):
        for line in open(path, encoding='utf-8'):
            k, sep, v = line.rstrip('\n').partition(' :: ')
            if sep and v.strip():
                table[k.strip()] = v.strip()
    return table


def source(level):
    """key → (Turkish, German context) in the same keys pack_content.py uses."""
    raw = json.load(open(os.path.join(HERE, 'data', f'{level}_raw.json'), encoding='utf-8'))
    p = f'{level}.'
    out = {}
    for t in raw['themes']:
        out[f'{p}theme.{t["id"]}'] = (t['tr'], t['de'])
    for w in raw['words']:
        out[f'{p}w.{w["id"]}'] = (w['tr'], w['de'])
        for i, e in enumerate(w['ex']):
            out[f'{p}w.{w["id"]}.ex.{i}'] = (e['tr'], e['de'])
    for g in raw['grammar']:
        out[f'{p}g.{g["id"]}.name'] = (g['tr'], g['de'])
        out[f'{p}g.{g["id"]}.rule'] = (g['rule'], '')
        for i, e in enumerate(g['examples']):
            de, _, tr = e.partition(' – ')
            out[f'{p}g.{g["id"]}.ex.{i}'] = (tr.strip() or de.strip(), de.strip())
    for i, it in enumerate(raw['grammarItems']):
        out[f'{p}gi.{i}'] = (it['why'], it['q'].replace('___', it['options'][0]))
    return out


def clean(text):
    return ' '.join(text.replace('⟦', '(').replace('⟧', ')').split())


def export(level, folder):
    os.makedirs(folder, exist_ok=True)
    for old in glob.glob(os.path.join(folder, f'{level}_en_part_*.txt')):
        os.remove(old)
    done = english_done()
    lines = []
    for key, (tr, de) in source(level).items():
        if key in done:
            continue
        lines.append(f'{key} :: {clean(tr)}' + (f' ⟦DE: {clean(de)}⟧' if de else ''))
    parts = [lines[i:i + PART] for i in range(0, len(lines), PART)]
    for n, part in enumerate(parts, 1):
        open(os.path.join(folder, f'{level}_en_part_{n:02d}.txt'), 'w', encoding='utf-8', newline='\n').write('\n'.join(part) + '\n')
    open(os.path.join(folder, 'PROMPT.txt'), 'w', encoding='utf-8', newline='\n').write(PROMPT.format(level=level.upper(), p=f'{level}.'))
    print(f'{level}: {len(lines)} lines → {len(parts)} files in {folder}')


def import_(level, folder):
    src = source(level)
    os.makedirs(os.path.join(HERE, 'i18n', 'en'), exist_ok=True)
    total, problems = 0, []
    for path in sorted(glob.glob(os.path.join(folder, f'{level}_en_part_*.txt'))):
        got = {}
        for n, line in enumerate(open(path, encoding='utf-8'), 1):
            if not line.strip():
                continue
            k, sep, v = line.rstrip('\n').partition(' :: ')
            k, v = k.strip(), v.strip()
            if not sep or not v:
                problems.append(f'{os.path.basename(path)}:{n} no text')
                continue
            if k not in src:
                problems.append(f'{os.path.basename(path)}:{n} unknown key {k}')
                continue
            if '⟦' in v or re.search(r'[ğışĞİŞ]', v):
                problems.append(f'{os.path.basename(path)}:{n} still Turkish or has ⟦DE⟧: {v[:60]}')
                continue
            got[k] = v
        name = f'{level}_' + os.path.basename(path).split('_part_')[1]
        dest = os.path.join(HERE, 'i18n', 'en', name)
        open(dest, 'w', encoding='utf-8', newline='\n').write(''.join(f'{k} :: {v}\n' for k, v in got.items()))
        total += len(got)
    done = english_done()
    left = sum(1 for k in src if k not in done)
    print(f'{level}: imported {total}; still without English: {left}')
    for p in problems[:30]:
        print('  ', p)
    if len(problems) > 30:
        print(f'   … {len(problems) - 30} more')


if __name__ == '__main__':
    action, level, folder = sys.argv[1], sys.argv[2].lower(), sys.argv[3]
    export(level, folder) if action == 'export' else import_(level, folder)

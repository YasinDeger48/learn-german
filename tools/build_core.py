"""Adds the extra frequent words (tools/words/*.txt) to a1.json as theme 15.

Usage: python -X utf8 tools/build_core.py a1.json
Line format: type|word|plural or verb forms|Türkçe|Beispielsatz|Türkçesi
type: der / die / das / pl / v (verb) / w (other word). Lines whose example is "-" are skipped
(they repeat a word that is already in the A1 PDF list).
"""
import glob, json, os, sys

sys.path.insert(0, os.path.dirname(__file__))
from pron import pron  # noqa: E402

CORE_THEME = 15
path = sys.argv[1]
d = json.load(open(path, encoding='utf-8'))
d['words'] = [w for w in d['words'] if w['theme'] != CORE_THEME]
d['themes'] = [t for t in d['themes'] if t['id'] != CORE_THEME]
d['themes'].append({'id': CORE_THEME, 'de': 'Grundwortschatz', 'tr': 'En sık kullanılan kelimeler (ek liste)'})

seen = {w['de'].lower() for w in d['words']}
next_id = max(w['id'] for w in d['words']) + 1
added, skipped = 0, 0
for file in sorted(glob.glob(os.path.join(os.path.dirname(__file__), 'words', '*.txt'))):
    for n, line in enumerate(open(file, encoding='utf-8'), 1):
        line = line.strip()
        if not line or line.startswith('#'):
            continue
        parts = line.split('|')
        assert len(parts) == 6, (file, n, line)
        typ, word, meta, tr, ex, ex_tr = (p.strip() for p in parts)
        if ex == '-' or word.lower() in seen:
            skipped += 1
            continue
        seen.add(word.lower())
        assert typ in ('der', 'die', 'das', 'pl', 'v', 'w'), (file, n)
        entry = {'id': next_id, 'theme': CORE_THEME, 'type': {'v': 'verb', 'w': 'word'}.get(typ, typ),
                 'de': word, 'tr': tr, 'ex': [{'de': ex, 'pron': pron(ex), 'tr': ex_tr}]}
        if typ in ('der', 'die', 'das'):
            entry['pron'] = pron(f'{typ} {word}')
            entry['plural'] = None if meta in ('', '-') else meta
        elif typ == 'pl':
            entry['pron'] = pron(f'die {word}')
        else:
            entry['pron'] = pron(word)
        if typ == 'v':
            assert ' · ' in meta, (file, n, meta)
            er, perfekt = meta.split(' · ', 1)
            entry['er'] = er
            entry['perfekt'] = perfekt
        d['words'].append(entry)
        next_id += 1
        added += 1

json.dump(d, open(path, 'w', encoding='utf-8', newline='\n'), ensure_ascii=False, separators=(',', ':'))
print('added', added, 'skipped', skipped, 'total words', len(d['words']))

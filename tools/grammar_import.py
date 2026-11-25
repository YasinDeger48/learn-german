"""Adds grammar exercises (from ChatGPT, one per line) straight into a level's content file.

    python -I -X utf8 tools/grammar_import.py a1 ../icerik/a1_gramer_cevap_01.txt [more files…]
    python -I -X utf8 tools/grammar_import.py a1 --status        exercises per topic

Line format (7 fields, separated by |):
    topic | sentence with ___ | right answer | wrong1;wrong2;wrong3 | why (Turkish) | why (English) | sentence in Turkish
"topic" is the topic's German name exactly as in the level file (e.g. "Modalverben").
Lines that are broken, have no ___, repeat an existing sentence or offer the answer twice are skipped and listed.
Resources/content/<level>.json is the source of truth; publish it with tools/publish_content.py.
"""
import json
import os
import sys

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def path_of(level):
    return os.path.join(REPO, 'Resources', 'content', f'{level}.json')


def status(level):
    d = json.load(open(path_of(level), encoding='utf-8'))
    counts = {}
    for it in d['grammarItems']:
        counts[it['topic']] = counts.get(it['topic'], 0) + 1
    for t in d['grammar']:
        print(f"{t['id']:3} {counts.get(t['id'], 0):4}  {t['de']}")
    print(f"total {len(d['grammarItems'])}")


def main():
    level = sys.argv[1].lower()
    if '--status' in sys.argv:
        status(level)
        return
    path = path_of(level)
    d = json.load(open(path, encoding='utf-8'))
    topics = {t['de'].strip().lower(): t['id'] for t in d['grammar']}
    known = {' '.join(it['q'].split()).lower() for it in d['grammarItems']}
    added, skipped = 0, []
    for source in sys.argv[2:]:
        for n, raw in enumerate(open(source, encoding='utf-8-sig'), 1):
            line = raw.strip().strip('`')
            if not line or line.startswith('#') or line.count('|') != 6:
                if line and not line.startswith('#') and '|' in line:
                    skipped.append((source, n, 'not 7 fields'))
                continue
            topic, q, answer, wrong, why_tr, why_en, q_tr = [p.strip() for p in line.split('|')]
            options = [answer] + [w.strip() for w in wrong.split(';') if w.strip()]
            key = ' '.join(q.split()).lower()
            reason = None
            if topic.lower() not in topics:
                reason = f'unknown topic "{topic}"'
            elif '___' not in q:
                reason = 'no ___'
            elif len(options) < 3 or len({o.lower() for o in options}) != len(options):
                reason = 'options missing or repeated'
            elif key in known:
                reason = 'sentence already there'
            if reason:
                skipped.append((source, n, reason))
                continue
            known.add(key)
            d['grammarItems'].append({'topic': topics[topic.lower()], 'q': q, 'options': options,
                                      'why': {'tr': f'{why_tr} ({q_tr})', 'en': why_en}})
            added += 1
    with open(path, 'w', encoding='utf-8', newline='\n') as f:
        json.dump(d, f, ensure_ascii=False, separators=(',', ':'))
    print(f'added {added}, skipped {len(skipped)}')
    for source, n, reason in skipped[:30]:
        print(f'  {os.path.basename(source)}:{n} {reason}')
    status(level)


if __name__ == '__main__':
    main()

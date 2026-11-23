"""Converts daily texts delivered as JSONL (one text per line) into Resources/content/daily_<level>.json.

Input line: {"id","level","topic","title","text","tr","en","glossary":[{"de":"die Besprechung","tr":"..."}],
             "questions":[{"type":"mc","q","options","answer":0} | {"type":"tf","q","answer":true}]}
Optional English glossary meanings: tools/daily/<level>_glossary_en.txt, lines "die Besprechung :: meeting".
Optional plurals / verb forms are taken from a word list in tools/words format (type|word|plural|...).

    python -I -X utf8 tools/import_daily_jsonl.py a2 ../icerik/a2_metinler_0*.jsonl --words ../icerik/a2_kelimeler.txt
"""
import glob
import json
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import pron  # noqa: E402

PUNCT = '.,!?;:„“"()–…’\''


def core(token):
    return token.strip(PUNCT).lower()


def find_form(text, lemma):
    """The spelling of the glossary word in the text (exact, plural or inflected), or None."""
    tokens = [t.strip(PUNCT) for t in text.split()]
    low = lemma.lower()
    for t in tokens:
        if t.lower() == low:
            return t
    for t in tokens:  # plural / inflection: same start, at most 3 more letters
        tl = t.lower()
        stem = low[:-1] if low.endswith('e') and len(low) > 4 else low
        if tl.startswith(stem) and 0 < len(tl) - len(stem) <= 3:
            return t
    return None


def main():
    args = sys.argv[1:]
    level = args.pop(0).lower()
    words_path = None
    if '--words' in args:
        i = args.index('--words')
        words_path = args[i + 1]
        del args[i:i + 2]
    files = sorted(p for pattern in args for p in glob.glob(pattern))
    extras = {}
    if words_path:
        for line in open(words_path, encoding='utf-8'):
            p = line.rstrip('\n').split('|')
            if len(p) >= 3 and p[2] not in ('', '-'):
                key = (f'{p[0]} {p[1]}' if p[0] in ('der', 'die', 'das') else p[1]).lower()
                extras[key] = ('Pl. ' + p[2]) if p[0] in ('der', 'die', 'das') else p[2]
    en_path = os.path.join(HERE, 'daily', f'{level}_glossary_en.txt')
    en = {}
    if os.path.exists(en_path):
        for line in open(en_path, encoding='utf-8'):
            k, sep, v = line.rstrip('\n').partition(' :: ')
            if sep:
                en[k.strip()] = v.strip()

    out, dropped, missing_en, seen = [], 0, set(), set()
    for path in files:
        for line in open(path, encoding='utf-8'):
            if not line.strip():
                continue
            t = json.loads(line)
            if t['id'] in seen:
                raise SystemExit(f"duplicate id {t['id']}")
            seen.add(t['id'])
            text = ' '.join(t['text'].split())
            glossary = []
            for g in t['glossary']:
                parts = g['de'].split(' ', 1)
                art = parts[0] if parts[0] in ('der', 'die', 'das') and len(parts) == 2 else None
                lemma = parts[1] if art else g['de']
                form = find_form(text, lemma)
                if not form:
                    dropped += 1
                    continue
                mean = {'tr': g['tr']}
                if g['de'] in en:
                    mean['en'] = en[g['de']]
                else:
                    missing_en.add(g['de'])
                item = {'form': form, 'lemma': lemma, 'mean': mean, 'pron': pron.pron(g['de'])}
                if art:
                    item['art'] = art
                extra = extras.get(g['de'].lower())
                if extra:
                    item['extra'] = extra
                glossary.append(item)
            questions = []
            for q in t['questions']:
                if q['type'] == 'tf':
                    questions.append({'type': 'tf', 'q': q['q'], 'answer': 0 if q['answer'] else 1})
                else:
                    questions.append({'type': 'mc', 'q': q['q'], 'options': q['options'], 'answer': q['answer']})
            trans = {'tr': ' '.join(t['tr'].split())}
            if t.get('en'):
                trans['en'] = ' '.join(t['en'].split())
            out.append({'id': t['id'], 'level': level.upper(), 'topic': t['topic'], 'title': t['title'],
                        'paragraphs': [text], 'trans': [trans], 'glossary': glossary, 'questions': questions})

    dest = os.path.join(HERE, '..', 'Resources', 'content', f'daily_{level}.json')
    json.dump({'level': level.upper(), 'texts': out}, open(dest, 'w', encoding='utf-8', newline='\n'),
              ensure_ascii=False, separators=(',', ':'))
    print(f'{len(out)} texts → {os.path.normpath(dest)}; glossary words not found in text: {dropped}; '
          f'without English: {len(missing_en)}')
    if missing_en:
        todo = os.path.join(HERE, 'daily', f'{level}_glossary_en_missing.txt')
        open(todo, 'w', encoding='utf-8', newline='\n').write(''.join(f'{k} :: \n' for k in sorted(missing_en)))
        print(f'list to translate: {todo}')


if __name__ == '__main__':
    main()

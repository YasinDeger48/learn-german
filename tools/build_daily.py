"""Builds Resources/content/daily_<level>.json from the plain-text sources in tools/daily/<level>_*.txt.

Source format, one text per block:

    # a1-001 | Alltag | Mein neues E-Bike
    DE: first paragraph ||| second paragraph
    TR: Turkish translation, same paragraphs ||| ...
    EN: English translation ||| ...
    ES: / FR: / IT: (optional)
    G: form | art | lemma | extra | tr | en        (art: der/die/das or -, extra may be -)
    Q: tf | Statement about the text. | 0          (0 = Richtig, 1 = Falsch)
    Q: mc | Question? | option A ; option B ; option C | 1   (index of the right option)

Pronunciations are generated with tools/pron.py.

    python -I -X utf8 tools/build_daily.py a1
"""
import glob
import json
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import pron  # noqa: E402

LANGS = ['TR', 'EN', 'ES', 'FR', 'IT']


def parse(path):
    texts, cur = [], None
    for n, raw in enumerate(open(path, encoding='utf-8'), 1):
        line = raw.strip()
        if not line or line.startswith('//'):
            continue
        if line.startswith('# '):
            tid, topic, title = [p.strip() for p in line[2:].split('|')]
            cur = {'id': tid, 'topic': topic, 'title': title, 'paragraphs': [], 'trans': {}, 'glossary': [], 'questions': []}
            texts.append(cur)
            continue
        key, _, value = line.partition(':')
        value = value.strip()
        if key == 'DE':
            cur['paragraphs'] = [p.strip() for p in value.split('|||')]
        elif key in LANGS:
            cur['trans'][key.lower()] = [p.strip() for p in value.split('|||')]
        elif key == 'G':
            form, art, lemma, extra, tr, en = [p.strip() for p in value.split('|')]
            art = None if art == '-' else art
            item = {'form': form, 'lemma': lemma, 'mean': {'tr': tr, 'en': en},
                    'pron': pron.pron(f'{art} {lemma}' if art else lemma)}
            if art:
                item['art'] = art
            if extra != '-':
                item['extra'] = extra
            cur['glossary'].append(item)
        elif key == 'Q':
            parts = [p.strip() for p in value.split('|')]
            if parts[0] == 'tf':
                cur['questions'].append({'type': 'tf', 'q': parts[1], 'answer': int(parts[2])})
            else:
                options = [o.strip() for o in parts[2].split(';')]
                cur['questions'].append({'type': 'mc', 'q': parts[1], 'options': options, 'answer': int(parts[3])})
        else:
            raise SystemExit(f'{path}:{n}: unknown line {line[:40]}')
    return texts


def check(t, level):
    full = ' '.join(t['paragraphs']).lower()
    words = {w.strip('.,!?;:„“"()–…').lower() for w in full.split()}
    for g in t['glossary']:
        if g['form'].lower() not in words:
            raise SystemExit(f"{t['id']}: glossary form '{g['form']}' is not in the text")
    for lang, paras in t['trans'].items():
        if len(paras) != len(t['paragraphs']):
            raise SystemExit(f"{t['id']}: {lang} has {len(paras)} paragraphs, DE has {len(t['paragraphs'])}")
    for q in t['questions']:
        if q['type'] == 'mc' and not 0 <= q['answer'] < len(q['options']):
            raise SystemExit(f"{t['id']}: bad answer index in '{q['q']}'")


def main():
    level = sys.argv[1].lower()
    texts = []
    for path in sorted(glob.glob(os.path.join(HERE, 'daily', f'{level}_*.txt'))):
        texts += parse(path)
    out = []
    seen = set()
    for t in texts:
        check(t, level)
        if t['id'] in seen:
            raise SystemExit(f"duplicate id {t['id']}")
        seen.add(t['id'])
        trans = [{lang: paras[i] for lang, paras in t['trans'].items()} for i in range(len(t['paragraphs']))]
        out.append({'id': t['id'], 'level': level.upper(), 'topic': t['topic'], 'title': t['title'],
                    'paragraphs': t['paragraphs'], 'trans': trans, 'glossary': t['glossary'], 'questions': t['questions']})
    dest = os.path.join(HERE, '..', 'Resources', 'content', f'daily_{level}.json')
    json.dump({'level': level.upper(), 'texts': out}, open(dest, 'w', encoding='utf-8', newline='\n'),
              ensure_ascii=False, separators=(',', ':'))
    words = sum(len(' '.join(t['paragraphs']).split()) for t in out)
    print(f'{len(out)} texts, {words} words → {os.path.normpath(dest)}')


if __name__ == '__main__':
    main()

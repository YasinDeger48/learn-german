"""Turns the raw A1 data (Turkish only) into the multi-language app content.

Every learner-language text becomes an object like {"tr": "...", "en": "..."}.
Translations live in tools/i18n/<lang>.json, keyed by a stable content key
(see `keys` below). Missing translations are simply left out; the apps fall
back to English, then Turkish.

    python -I -X utf8 tools/pack_content.py tools/data/a1_raw.json Resources/content/a1.json
    python -I -X utf8 tools/pack_content.py tools/data/a1_raw.json Resources/content/a1.json --missing en

`--missing en` also writes tools/i18n/missing_en.json: every key without an
English text, with the Turkish source, ready to be translated.
"""
import glob
import json
import os
import sys

LANGS = ['tr', 'en', 'es', 'fr', 'it']
HERE = os.path.dirname(os.path.abspath(__file__))


def load_translations():
    table = {}
    for lang in LANGS[1:]:
        path = os.path.join(HERE, 'i18n', f'{lang}.json')
        table[lang] = json.load(open(path, encoding='utf-8')) if os.path.exists(path) else {}
        # Hand-written translations: tools/i18n/<lang>/*.txt, one "key :: text" per line.
        for src in sorted(glob.glob(os.path.join(HERE, 'i18n', lang, '*.txt'))):
            for line in open(src, encoding='utf-8'):
                key, sep, text = line.rstrip('\n').partition(' :: ')
                if sep and text.strip():
                    table[lang][key.strip()] = text.strip()
    return table


def main():
    src, out = sys.argv[1], sys.argv[2]
    missing_lang = sys.argv[sys.argv.index('--missing') + 1] if '--missing' in sys.argv else None
    prefix = sys.argv[sys.argv.index('--prefix') + 1] if '--prefix' in sys.argv else ''
    raw = json.load(open(src, encoding='utf-8'))
    trans = load_translations()
    source = {}

    def loc(key, tr_text):
        key = prefix + key
        source[key] = tr_text
        obj = {'tr': tr_text}
        for lang in LANGS[1:]:
            text = trans[lang].get(key)
            if text:
                obj[lang] = text
        return obj

    themes = [{'id': t['id'], 'de': t['de'], 'name': loc(f'theme.{t["id"]}', t['tr'])} for t in raw['themes']]

    words = []
    for w in raw['words']:
        item = {k: w[k] for k in ('id', 'theme', 'type', 'de', 'pron') if k in w}
        for k in ('plural', 'er', 'perfekt'):
            if w.get(k):
                item[k] = w[k]
        item['mean'] = loc(f'w.{w["id"]}', w['tr'])
        item['ex'] = [{'de': e['de'], 'pron': e['pron'], 'mean': loc(f'w.{w["id"]}.ex.{i}', e['tr'])}
                      for i, e in enumerate(w['ex'])]
        words.append(item)

    texts = []
    for t in raw['texts']:
        texts.append({
            'id': t['id'], 'title': t['title'], 'de': t['de'],
            'titleL': loc(f'text.{t["id"]}.title', t['titleTr']),
            'trans': loc(f'text.{t["id"]}.trans', t['tr']),
            'questions': t['questions'],
        })

    hoeren = []
    for i, h in enumerate(raw['hoeren']):
        hoeren.append({'part': h['part'], 'lines': h['lines'], 'q': h['q'], 'options': h['options'],
                       'trans': loc(f'h.{i}', h['tr'])})

    grammar = []
    for g in raw['grammar']:
        examples = []
        for i, e in enumerate(g['examples']):
            de, _, tr = e.partition(' – ')
            examples.append({'de': de.strip(), 'mean': loc(f'g.{g["id"]}.ex.{i}', tr.strip() or de.strip())})
        grammar.append({'id': g['id'], 'de': g['de'], 'name': loc(f'g.{g["id"]}.name', g['tr']),
                        'rule': loc(f'g.{g["id"]}.rule', g['rule']), 'examples': examples})

    items = [{'topic': it['topic'], 'q': it['q'], 'options': it['options'], 'why': loc(f'gi.{i}', it['why'])}
             for i, it in enumerate(raw['grammarItems'])]
    mistakes = [{'wrong': m['wrong'], 'right': m['right'], 'why': loc(f'mis.{i}', m['why'])}
                for i, m in enumerate(raw['mistakes'])]
    situations = [{'q': loc(f'sit.{i}', s['q']), 'options': s['options']} for i, s in enumerate(raw['situations'])]

    packed = {'version': 2, 'level': (prefix.rstrip('.') or 'a1').upper(), 'themes': themes, 'words': words, 'texts': texts, 'hoeren': hoeren,
              'grammar': grammar, 'grammarItems': items, 'mistakes': mistakes, 'situations': situations}
    json.dump(packed, open(out, 'w', encoding='utf-8', newline='\n'), ensure_ascii=False, separators=(',', ':'))

    done = {lang: sum(1 for k in source if trans[lang].get(k)) for lang in LANGS[1:]}
    print(f'{len(source)} texts; translated: ' + ', '.join(f'{k} {v}' for k, v in done.items()))
    if missing_lang:
        missing = {k: v for k, v in source.items() if not trans[missing_lang].get(k)}
        path = os.path.join(HERE, 'i18n', f'missing_{prefix}{missing_lang}.json')
        json.dump(missing, open(path, 'w', encoding='utf-8', newline='\n'), ensure_ascii=False, indent=0)
        print(f'{len(missing)} missing → {path}')


if __name__ == '__main__':
    main()

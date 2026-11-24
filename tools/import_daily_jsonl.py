"""Converts daily texts delivered as JSONL (one text per line) into Resources/content/daily_<level>.json.

Input line: {"id","level","topic","title","text","tr","en","glossary":[{"de":"die Besprechung","tr":"..."}],
             "questions":[{"type":"mc","q","options","answer":0} | {"type":"tf","q","answer":true}]}
Optional English glossary meanings: tools/daily/<level>_glossary_en.txt, lines "die Besprechung :: meeting".
Optional plurals / verb forms are taken from --words PATH or a glob of word lists (type|word|plural|...).

    python -I -X utf8 tools/import_daily_jsonl.py a2 ../icerik/a2_metinler_0*.jsonl --words ../icerik/a2_kelimeler.txt
"""
import glob
import json
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import pron  # noqa: E402

PUNCT = '.,!?;:„“"()–…’\''


def core(token):
    return token.strip(PUNCT).lower()


SEP = sorted(['ab', 'an', 'auf', 'aus', 'bei', 'ein', 'mit', 'nach', 'vor', 'weg', 'zu', 'zurück', 'zusammen',
               'durcheinander', 'fest', 'her', 'hin', 'los', 'um', 'weiter', 'dazu', 'teil', 'statt', 'kennen',
               'herein', 'heraus', 'hinaus', 'vorbei', 'wieder', 'fort', 'heim', 'bereit', 'frei'], key=len, reverse=True)
INSEP = ('be', 'ge', 'er', 'ver', 'zer', 'ent', 'emp', 'miss', 'wider', 'über', 'unter', 'hinter')


def _common(a, b):
    n = 0
    while n < min(len(a), len(b)) and a[n] == b[n]:
        n += 1
    return n


def _find_single(text, lemma):
    tokens = [t.strip(PUNCT) for t in text.split()]
    low = lemma.lower()
    for t in tokens:
        if t.lower() == low:
            return t
    plain = str.maketrans('äöü', 'aou')
    for t in tokens:  # plural / inflection: same start, at most 3 more letters (Stellplatz → Stellplätze)
        tl = t.lower().translate(plain)
        stem = low.translate(plain)
        stem = stem[:-1] if stem.endswith('e') and len(stem) > 4 else stem
        if tl.startswith(stem) and 0 < len(tl) - len(stem) <= 3:
            return t
    if not (low.endswith('en') or low.endswith('ern') or low.endswith('eln')) or lemma[:1].isupper():
        return None
    for t in tokens:  # participle without prefix: ernten → geerntet, kennzeichnen → gekennzeichnet
        if t.lower().startswith('ge' + low[:-3]) and len(low) > 5:
            return t
    for t in tokens:  # weak past: ernten → ernteten, vermuten → vermutete
        tl = t.lower()
        if len(low) > 5 and tl.startswith(low[:-2]) and 0 < len(tl) - len(low) + 2 <= 4:
            return t
    # Verbs: separable prefix forms (eingerichtet, aufzuschreiben, ablief, sprang … ein)
    for p in SEP:
        if not low.startswith(p) or len(low) - len(p) < 4:
            continue
        rest = low[len(p):]
        for t in tokens:
            tl = t.lower()
            if tl == p + 'zu' + rest or tl.startswith(p + 'ge' + rest[0]) and len(tl) > len(p) + 4:
                return t
        for t in tokens:
            tl = t.lower()
            if tl.startswith(p + rest[0]) and len(tl) >= len(p) + 3 and _common(tl, low) >= len(p) + 1:
                return t
        for sentence in re.split(r'(?<=[.!?;:])\s+', text):
            words = [w.strip(PUNCT) for w in re.split(r'[\s,]+', sentence) if w.strip(PUNCT)]
            if p not in [w.lower() for w in words[1:]]:
                continue
            best = max((w for w in words if w.lower() != p and _common(w.lower(), rest) >= 3),
                       key=lambda w: (w[:1].islower(), _common(w.lower(), rest)), default=None)
            if best:
                return best
        break
    # Strong past forms (widersprach, versprach): long shared start with the infinitive
    need = max(6, len(low) - 5)
    for t in tokens:
        if t[:1].islower() and _common(t.lower(), low) >= need:
            return t
    for p in INSEP:  # strong participle with vowel change: verhelfen → verholfen
        if low.startswith(p):
            for t in tokens:
                tl = t.lower()
                if t[:1].islower() and _common(tl, low) >= len(p) + 1 and tl[-3:] == low[-3:] and abs(len(tl) - len(low)) <= 1:
                    return t
    return None


def find_form(text, lemma):
    """The spelling of the glossary word in the text (exact, plural, inflected, separable verb), or None.
    Multi-word entries (sich absprechen, eine Rechnung ausstellen, bei Bedarf) are found by one of their words."""
    words = lemma.split()
    if words and words[0] == 'sich':
        words = words[1:]
    if len(words) == 1:
        return _find_single(text, words[0])
    small = ('ein', 'eine', 'einen', 'der', 'die', 'das', 'dem', 'den', 'bei', 'mit', 'von', 'zu', 'in', 'auf', 'aus')
    for w in sorted(words, key=len, reverse=True):
        if w.lower() in small:
            continue
        form = _find_single(text, w)
        if form:
            return form
    return None


def split_paragraphs(text):
    return [' '.join(part.split()) for part in re.split(r'\n\s*\n', text.strip())]


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
    word_files = sorted(glob.glob(words_path)) if words_path else []
    if words_path and not word_files:
        raise SystemExit(f'No word lists match {words_path}')
    for path in word_files:
        for line in open(path, encoding='utf-8'):
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
                elif g.get('en'):  # delivered with the text: {"de","tr","en"}
                    mean['en'] = g['en']
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
            translations = {lang: t[lang] for lang in ('tr', 'en') if t.get(lang)}
            paragraphs = split_paragraphs(t['text'])
            translated = {lang: split_paragraphs(value) for lang, value in translations.items()}
            if any(len(parts) != len(paragraphs) for parts in translated.values()):
                paragraphs = [text]
                translated = {lang: [' '.join(value.split())] for lang, value in translations.items()}
            trans = [{lang: parts[i] for lang, parts in translated.items()} for i in range(len(paragraphs))]
            out.append({'id': t['id'], 'level': level.upper(), 'topic': t['topic'], 'title': t['title'],
                        'paragraphs': paragraphs, 'trans': trans, 'glossary': glossary, 'questions': questions})

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

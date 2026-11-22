"""Approximate Turkish-letter pronunciation of German, following the PDF's "Okunuş rehberi"."""
import re

VOW = 'aeiouäöüy'

# Loanwords and other words the rules get wrong (lowercase key, without punctuation).
OVERRIDES = {
    'chance': 'şanse', 'chancen': 'şansen', 'wlan': 'velan', 'okay': 'okey', 'laptop': 'leptop', 'job': 'cop',
    'toast': 'tost', 'ketchup': 'keçap', 'jeans': 'cins', 'app': 'ep', 'band': 'bent', 'serie': 'zeriye',
    'cousin': 'kuzen', 'cousine': 'kuzine', 'garage': 'garaje', 'etage': 'etaje', 'creme': 'krem', 'föhn': 'fön',
    'campingplatz': 'kempingplats', 'campen': 'kempen', 'chatten': 'çeten', 'chatte': 'çete', 'surfen': 'sörfen',
    'surfe': 'sörfe', 'joggen': 'cogen', 'jogge': 'coge', 'pommes': 'pomes', 'portemonnaie': 'portmone',
    'shampoo': 'şampu', 'pizza': 'pitsa', 'pizzen': 'pitsen', 'toilettenpapier': 'toaletenpapir',
    'programmierer': 'programira', 'journalist': 'jurnalist', 'mailbox': 'meylboks', 'tourist': 'turist',
    'touristen': 'turisten', 'zoo': 'tso', 'handy': 'hendi', 'café': 'kafe', 'cafés': 'kafes', 'baby': 'bebi',
    'computer': 'kompyuta', 'restaurant': 'restoran', 'restaurants': 'restorans', 'email': 'imeyl', 'e-mail': 'imeyl',
    'toilette': 'toalete', 'museum': 'muzeum', 'party': 'parti', 'ingenieur': 'injenyör', 'team': 'tim',
    'interview': 'intavyu', 'fitnessstudio': 'fitnesştudyo', 'video': 'video', 'radio': 'radyo', 'cola': 'kola',
    'dollar': 'dolar', 'show': 'şov', 'pullover': 'pulova', 'jugendherberge': 'yugenthaberge', 'gymnasium': 'gümnazyum',
    'friseur': 'frizör', 'parfüm': 'parfüm', 'sandale': 'zandale', 'tunnel': 'tunel', 'hobby': 'hobi', 'hobbys': 'hobis',
}


def word_pron(w):
    key = w.lower().strip('.,!?;:„“"()–…')
    if key in OVERRIDES:
        return w.lower().replace(key, OVERRIDES[key])
    w = w.lower()
    out = []
    i = 0
    n = len(w)

    def at(k, s):
        return w.startswith(s, k)

    while i < n:
        c = w[i]
        prev = w[i - 1] if i > 0 else ''
        start = i == 0
        if not c.isalpha():
            out.append(c)
            i += 1
            continue
        if at(i, 'tsch'):
            out.append('ç'); i += 4; continue
        if at(i, 'sch'):
            out.append('ş'); i += 3; continue
        if start and (at(i, 'sp') or at(i, 'st')):
            out.append('ş'); i += 1; continue
        if at(i, 'chs'):
            out.append('ks'); i += 3; continue
        if at(i, 'ch'):
            out.append('h'); i += 2; continue
        if at(i, 'ck'):
            out.append('k'); i += 2; continue
        if at(i, 'ph'):
            out.append('f'); i += 2; continue
        if at(i, 'th'):
            out.append('t'); i += 2; continue
        if at(i, 'qu'):
            out.append('kv'); i += 2; continue
        if at(i, 'tz'):
            out.append('ts'); i += 2; continue
        if at(i, 'ei') or at(i, 'ai') or at(i, 'ey') or at(i, 'ay'):
            out.append('ay'); i += 2; continue
        if at(i, 'tion'):
            out.append('tsyon'); i += 4; continue
        if at(i, 'dt'):
            out.append('t'); i += 2; continue
        if at(i, 'ern') and i > 1 and (i + 3 >= n or not w[i + 3].isalpha()):
            out.append('an'); i += 3; continue
        if at(i, 'ien') and i > 2 and (i + 3 >= n or not w[i + 3].isalpha()) and w[i - 1] in 'lnr':
            out.append('iyen'); i += 3; continue
        if at(i, 'ie'):
            out.append('i'); i += 2; continue
        if at(i, 'eu') or at(i, 'äu'):
            out.append('oy'); i += 2; continue
        if at(i, 'au'):
            out.append('au'); i += 2; continue
        if at(i, 'ng'):
            out.append('ng'); i += 2; continue
        if c == 'h' and prev and prev in VOW:
            i += 1; continue
        # doubled vowels / consonants collapse
        if i + 1 < n and w[i + 1] == c and c in 'aeoufmnlprtkbdgsz':
            if c in 'aeo':
                out.append(c); i += 2; continue
            out.append(c); i += 2; continue
        rest = w[i + 1:]
        end = i + 1 >= n or not w[i + 1].isalpha()
        if c == 'e' and at(i, 'er') and (i + 2 >= n or not w[i + 2].isalpha()) and i > 1 and w[:i + 2] not in ('der', 'wer', 'mehr', 'sehr', 'her'):
            out.append('a'); i += 2; continue
        if c == 'i' and at(i, 'ig') and (i + 2 >= n or not w[i + 2].isalpha()) and i > 0:
            out.append('ih'); i += 2; continue
        if c in 'bdg' and i > 0 and (end or (rest[:1] in ('t', 's') and (len(rest) == 1 or not rest[1:2].isalpha() or rest[1:2] == 't'))):
            out.append({'b': 'p', 'd': 't', 'g': 'k'}[c]); i += 1; continue
        m = {'ä': 'e', 'z': 'ts', 'v': 'f', 'w': 'v', 'j': 'y', 'ß': 's', 'y': 'ü', 'c': 'k', 'x': 'ks'}
        if c == 's' and i + 1 < n and w[i + 1] in VOW and (start or prev in VOW or prev in 'lnmr'):
            out.append('z'); i += 1; continue
        out.append(m.get(c, c))
        i += 1
    return ''.join(out)


def pron(text):
    return ' '.join(word_pron(t) for t in text.split())


if __name__ == '__main__':
    import json, sys
    d = json.load(open(sys.argv[1], encoding='utf-8'))
    ok = tot = 0
    bad = []
    for w in d['words']:
        for e in w['ex']:
            for a, b in zip(e['de'].split(), e['pron'].split()):
                a2 = re.sub(r'[^\wäöüß]', '', a.lower()); b2 = re.sub(r'[^\wçğışöüâ]', '', b)
                if not a2 or any(ch.isdigit() for ch in a2):
                    continue
                tot += 1
                if word_pron(a2) == b2:
                    ok += 1
                else:
                    bad.append((a2, word_pron(a2), b2))
    print(ok, tot, round(ok / tot * 100, 1))
    from collections import Counter
    for x, c in Counter(bad).most_common(60):
        print(c, x)

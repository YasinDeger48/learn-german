import json, re, sys

src, out = sys.argv[1], sys.argv[2]
t = open(src, encoding='utf-8').read().split('\n')

THEMES = [
    (183, "Begrüßung & Kommunikation", "Selamlaşma ve iletişim"),
    (620, "Personen & Familie", "Kişiler ve aile"),
    (1036, "Herkunft & Wohnort", "Memleket ve adres"),
    (1375, "Zahlen, Uhrzeit & Kalender", "Sayılar, saat ve takvim"),
    (2672, "Essen & Trinken", "Yiyecek ve içecek"),
    (3299, "Einkaufen & Kleidung", "Alışveriş ve giyim"),
    (3796, "Wohnen", "Ev ve barınma"),
    (4252, "Stadt, Verkehr & Reisen", "Şehir, ulaşım ve seyahat"),
    (4930, "Arbeit, Schule & Medien", "İş, okul ve iletişim araçları"),
    (5483, "Freizeit & Hobbys", "Boş zaman ve hobiler"),
    (5903, "Körper & Gesundheit", "Vücut ve sağlık"),
    (6310, "Wetter, Natur & Tiere", "Hava, doğa ve hayvanlar"),
    (6620, "Wichtige Verben", "Önemli fiiller"),
    (7132, "Wichtige Adjektive", "Önemli sıfatlar"),
    (7601, "Fragewörter & kleine Wörter", "Soru kelimeleri ve küçük kelimeler"),
]
END = 8100
HEAD = re.compile(r'^(der|die|das|Plural|Verb|Wort) (.+?) \[(.+?)\]\s*$')
SENT = re.compile(r'^([12]) (.+)$')
TYPES = {'der': 'der', 'die': 'die', 'das': 'das', 'Plural': 'pl', 'Verb': 'verb', 'Wort': 'word'}

def theme_of(i):
    k = 0
    for n, (start, _, _) in enumerate(THEMES):
        if i >= start:
            k = n
    return k

def junk(line):
    s = line.strip()
    return (not s or s.startswith('Deutsch A1 ·') or re.fullmatch(r'\d{1,3}', s) is not None
            or re.search(r'· \d+/\d+$', s) is not None or any(s == th[1] for th in THEMES))

def split_pron(de, rest):
    """rest = '<pron> <turkish>'. The pronunciation mirrors the German word by word."""
    n = len(de.split())
    toks = rest.split()
    if len(toks) <= n:
        return None
    pron, tr = ' '.join(toks[:n]), ' '.join(toks[n:])
    end_de, end_pr = de.rstrip()[-1], pron.rstrip()[-1]
    if end_de in '.?!' and end_pr != end_de:
        return None
    return pron, tr

def split_pron_fallback(de, rest):
    end = de.rstrip()[-1]
    if end not in '.?!“"':
        return None
    # Turkish starts after the last copy of the German sentence-end punctuation that is followed by a capital.
    m = None
    for mm in re.finditer(r'([.?!“"])\s+(?=[A-ZÇĞİÖŞÜ„“"\'0-9–])', rest):
        m = mm
        break
    if not m:
        return None
    return rest[:m.end(1)].strip(), rest[m.end():].strip()

words, bad = [], []
i = THEMES[0][0]
while i < END:
    m = HEAD.match(t[i])
    if not m:
        i += 1
        continue
    typ, rest_head, pron = m.group(1), m.group(2), m.group(3)
    de = rest_head
    if typ in ('der', 'die', 'das'):
        if de.startswith(typ + ' '):
            de = de[len(typ) + 1:]
    if typ == 'Plural' and de.startswith('die '):
        de = de[4:]
    j = i + 1
    while j < END and junk(t[j]):
        j += 1
    meaning = t[j].strip()
    j += 1
    entry = {'id': len(words) + 1, 'theme': theme_of(i), 'type': TYPES[typ], 'de': de.strip(), 'pron': pron.strip()}
    if typ in ('der', 'die', 'das'):
        mm = re.search(r'\s*Çoğul: (.+)$', meaning)
        if mm:
            pl = mm.group(1).strip()
            meaning = meaning[:mm.start()].strip()
            entry['plural'] = None if pl in ('–', '-', 'yok') else re.sub(r'^die ', '', pl)
        mm = re.search(r'\s*sadece tekil$', meaning)
        if mm:
            meaning = meaning[:mm.start()].strip()
    elif typ == 'Plural':
        meaning = re.sub(r'\s*sadece çoğul$', '', meaning).strip()
    elif typ == 'Verb':
        mm = re.search(r'\s+((?:er|es|sie|man) .+?) · ((?:hat|ist|hat/ist) .+)$', meaning)
        if mm:
            entry['er'] = mm.group(1).strip()
            entry['perfekt'] = mm.group(2).strip()
            meaning = meaning[:mm.start()].strip()
        else:
            bad.append(('verbmeta', i, meaning))
    meaning = re.sub(r'\s+der \w+tag \(am \w+tag\)$', '', meaning)
    if typ == 'Verb' and 'er' not in entry and de == 'möchten':
        entry['er'] = 'er möchte'
        meaning = 'istemek (kibarca)'
    entry['tr'] = meaning
    sents = []
    while j < END and not HEAD.match(t[j]) and len(sents) < 2:
        sm = SENT.match(t[j])
        if sm:
            de_s = sm.group(2).strip()
            k = j + 1
            while k < END and junk(t[k]):
                k += 1
            line2 = t[k].strip() if k < END else ''
            # German sentence may wrap onto a second line
            sp = split_pron(de_s, line2) or split_pron_fallback(de_s, line2)
            if sp is None and k + 1 < END:
                sp2 = split_pron(de_s + ' ' + line2, t[k + 1].strip())
                if sp2:
                    de_s = de_s + ' ' + line2
                    k += 1
                    sp = sp2
            if sp:
                sents.append({'de': de_s, 'pron': sp[0], 'tr': sp[1]})
            else:
                bad.append(('sent', j, de_s, line2))
            j = k + 1
        else:
            j += 1
    entry['ex'] = sents
    words.append(entry)
    i = j

# ---- Reading texts ----
texts = []
k = 11000
while k < 12000:
    m = re.match(r'^Text (\d+): (.+)$', t[k].strip())
    if m:
        title_tr = ''
        for back in (1, 2):
            mb = re.match(r'^(.+) · \d+ kelime$', t[k - back].strip())
            if mb:
                title_tr = mb.group(1)
        mf = re.match(r'^(.+) · \d+ kelime$', t[k + 1].strip())
        j = k + 1
        if mf:
            title_tr = mf.group(1)
            j += 1
        lines = []
        while j < len(t) and not t[j].strip().startswith('Türkçesi'):
            if not junk(t[j]):
                lines.append(t[j].strip())
            j += 1
        tr = t[j].strip()[len('Türkçesi'):].strip() or t[j + 1].strip()
        de_lines = [ln for n, ln in enumerate([x for x in lines if x]) if n % 2 == 0]
        texts.append({'id': int(m.group(1)), 'title': m.group(2).strip(), 'titleTr': title_tr,
                      'de': de_lines, 'tr': tr})
        k = j
    k += 1

themes = [{'id': n, 'de': d, 'tr': tr} for n, (_, d, tr) in enumerate(THEMES)]
json.dump({'themes': themes, 'words': words, 'texts': texts}, open(out, 'w', encoding='utf-8'),
          ensure_ascii=False, indent=0)
from collections import Counter
print('words', len(words), Counter(w['type'] for w in words))
print('per theme', Counter(w['theme'] for w in words))
print('sentences', sum(len(w['ex']) for w in words), 'texts', len(texts))
print('bad', len(bad))
for b in bad[:40]:
    print(b)

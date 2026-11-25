"""Meanings for every word of the daily texts (the long-press bubble in the reader).

The app finds a pressed word in this order: the text's glossary, the level word lists (also plural, "er" form,
participle), then Resources/content/lexicon.json, then a guess by common endings. This tool fills lexicon.json
with the forms that are still not found, using ChatGPT:

    python -I -X utf8 tools/lexicon.py export     writes icerik/sozluk/liste_01.txt … (prompt + words for ChatGPT)
    python -I -X utf8 tools/lexicon.py import     reads icerik/sozluk/cevap_*.txt (ChatGPT's JSONL answers)
                                                  and merges them into Resources/content/lexicon.json
    python -I -X utf8 tools/lexicon.py status     how many text words have a meaning, per level

Run export again after new texts: it only lists the forms that are still missing.
lexicon.json goes to installed apps with tools/publish_content.py like the other content files.
"""
import glob
import json
import os
import re
import sys

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(REPO, 'tools'))
from pron import pron  # noqa: E402

CONTENT = os.path.join(REPO, 'Resources', 'content')
LEXICON = os.path.join(CONTENT, 'lexicon.json')
FOLDER = os.path.join(os.path.dirname(REPO), 'icerik', 'sozluk')
LEVELS = ['a1', 'a2', 'b1', 'b2']
PUNCT = '.,!?;:„“"()–…‚‘\'»«'
BATCH = 200


def load_lexicon():
    if not os.path.exists(LEXICON):
        return {}
    return {g['form'].lower(): g for g in json.load(open(LEXICON, encoding='utf-8'))['forms']}


def word_table():
    """Same keys as WordLookup.keys(for:) in the app."""
    table = set()
    for lv in LEVELS:
        for w in json.load(open(os.path.join(CONTENT, f'{lv}.json'), encoding='utf-8'))['words']:
            table.add(w['de'].lower())
            if w.get('plural'):
                table.add(w['plural'].lower())
            if w.get('er'):
                table.add(w['er'].split(' ')[-1].lower())
            if w.get('perfekt'):
                table.add(w['perfekt'].split(' ')[-1].lower())
    return table


def stem_found(core, table):
    """Same as WordLookup.stemMatch in the app."""
    for e in ['en', 'em', 'er', 'es', 'e', 'n', 's', 'st', 't']:
        if core.endswith(e) and len(core) > len(e) + 2:
            s = core[:-len(e)]
            if s in table or s + 'en' in table or s + 'n' in table:
                return True
    return False


def scan():
    """Per level: (word tokens, tokens with a meaning, missing forms in order: form -> (as written, sentence))."""
    table, lexicon = word_table(), load_lexicon()
    result = {}
    for lv in LEVELS:
        texts = json.load(open(os.path.join(CONTENT, f'daily_{lv}.json'), encoding='utf-8'))['texts']
        tokens = found = 0
        missing = {}
        for t in texts:
            glossary = {g['form'].lower() for g in t['glossary']}
            for p in t['paragraphs']:
                for raw in p.split(' '):
                    core = raw.strip(PUNCT).lower()
                    if not core or re.fullmatch(r'[\d.,:%/-]+', core):
                        continue
                    tokens += 1
                    if core in glossary or core in table or core in lexicon or stem_found(core, table):
                        found += 1
                        continue
                    if core not in missing:
                        sentence = next((s for s in re.split(r'(?<=[.!?])\s+', p) if raw in s.split(' ')), p)
                        missing[core] = (raw.strip(PUNCT), sentence)
        result[lv] = (tokens, found, missing)
    return result


PROMPT = '''Sen deneyimli bir Almanca–Türkçe–İngilizce sözlük editörüsün. Aşağıdaki liste, Deschly adlı Almanca öğrenme uygulamasının okuma metinlerinden alınmış kelime biçimleri. Öğrenci metinde bir kelimeye basılı tutunca senin yazdığın anlamı görecek.

Her satır şu biçimde:  kelime | seviye | kelimenin geçtiği cümle

Her kelime için TEK satırlık bir JSON yaz (JSONL). Başka hiçbir açıklama yazma:
{"f":"ging","lemma":"gehen","art":"","tr":"gitti","en":"went","note":"Präteritum"}

Alanlar:
- f: listedeki kelimenin aynısı (büyük/küçük harf dahil, değiştirme).
- lemma: sözlükteki temel biçim. Fiil → mastar (ging → gehen, wurde → werden), isim → tekil (Kindern → Kind), sıfat → yalın (kleinen → klein), artikel/zamir → temel biçim (dem → der, ihn → er).
- art: lemma bir isimse "der", "die" veya "das"; değilse "".
- tr: kelimenin O CÜMLEDEKİ Türkçe anlamı, kısa (1–4 kelime), çekimiyle birlikte (ging → "gitti", Kindern → "çocuklara", schöneren → "daha güzel"). Artikel/zamir gibi küçük kelimelerde görevini kısaca yaz (dem → "-e/-a (eril/nötr, Dativ)", sie → "o (kadın) / onlar", es → "o (nötr)", zur → "-e/-a doğru (zu der)").
- en: aynı anlamın İngilizcesi, kısa (ging → "went", sie → "she / they").
- note: çok kısa Almanca dilbilgisi notu, gerekmiyorsa "". Örnekler: "Präteritum", "Partizip II", "Plural", "Dativ", "Akkusativ", "Genitiv", "Komparativ", "Superlativ", "Konjunktiv II", "zu + dem", "trennbar: anrufen", "Name", "Stadt", "Land", "Zahl".

Özel durumlar:
- Kişi adı (Lena, Murat): lemma = ad, art "", tr "kişi adı", en "first name", note "Name".
- Şehir, ülke, kurum (Köln, Kanada, ICE): tr "şehir (Almanya)", "ülke: Kanada", "hızlı tren (ICE)" gibi; note "Stadt" / "Land" / "".
- Sayılar ve günler: normal anlamı (zwanzig → "yirmi" / "twenty", note "Zahl").
- Ayrılabilen fiilin cümle sonundaki parçası ("Er ruft morgen an." içindeki "an"): lemma tam fiil ("anrufen"), tr/en tam fiilin anlamı, note "trennbar: anrufen".

Önemli:
- Listedeki HER satır için bir JSON satırı yaz, sırayı koru, hiçbirini atlama ve yeni kelime ekleme.
- Bütün cevabı tek bir kod bloğu içinde ver.
- Cevap yarıda kesilirse "devam" yazdığımda kaldığın satırdan devam et.

'''


def export():
    result = scan()
    seen, rows = set(), []
    for lv in LEVELS:
        for core, (written, sentence) in result[lv][2].items():
            if core not in seen:
                seen.add(core)
                rows.append(f'{written} | {lv.upper()} | {sentence}')
    os.makedirs(FOLDER, exist_ok=True)
    for old in glob.glob(os.path.join(FOLDER, 'liste_*.txt')):
        os.remove(old)
    batches = [rows[i:i + BATCH] for i in range(0, len(rows), BATCH)]
    for n, batch in enumerate(batches, 1):
        head = f'LİSTE {n:02d} / {len(batches):02d} · {len(batch)} kelime\n\n'
        with open(os.path.join(FOLDER, f'liste_{n:02d}.txt'), 'w', encoding='utf-8', newline='\r\n') as f:
            f.write(PROMPT + head + '\n'.join(batch) + '\n')
    print(f'{len(rows)} forms without a meaning -> {len(batches)} lists in {FOLDER}')


def parse_answers():
    entries, bad = {}, []
    for path in sorted(glob.glob(os.path.join(FOLDER, 'cevap_*.*'))):
        for line in open(path, encoding='utf-8-sig'):
            line = line.strip().rstrip(',')
            if not line.startswith('{'):
                continue
            try:
                e = json.loads(line)
            except json.JSONDecodeError:
                bad.append((os.path.basename(path), line[:60]))
                continue
            f, lemma = str(e.get('f', '')).strip(), str(e.get('lemma', '')).strip()
            tr, en = str(e.get('tr', '')).strip(), str(e.get('en', '')).strip()
            art = str(e.get('art', '') or '').strip().lower()
            note = str(e.get('note', '') or '').strip()
            if art in ('der/die', 'die/der'):  # nouns made from adjectives or participles (der/die Mitarbeitende)
                note = ' · '.join(x for x in ['der/die', note] if x)
                art = ''
            if not f or not lemma or not tr or not en or art not in ('', 'der', 'die', 'das'):
                bad.append((os.path.basename(path), line[:60]))
                continue
            entries[f.lower()] = {
                'form': f, 'lemma': lemma, 'art': art or None,
                'pron': pron(f'{art} {lemma}' if art else lemma),
                'extra': note or None, 'mean': {'tr': tr, 'en': en},
            }
    return entries, bad


def import_answers():
    entries, bad = parse_answers()
    lexicon = load_lexicon()
    before = len(lexicon)
    lexicon.update(entries)
    forms = sorted(lexicon.values(), key=lambda g: g['form'].lower())
    for g in forms:
        for k in [k for k, v in g.items() if v is None]:
            del g[k]
    with open(LEXICON, 'w', encoding='utf-8', newline='\n') as f:
        json.dump({'forms': forms}, f, ensure_ascii=False, indent=1)
        f.write('\n')
    print(f'read {len(entries)} answers, lexicon {before} -> {len(lexicon)} forms')
    for name, line in bad[:20]:
        print(f'  skipped ({name}): {line}')
    if len(bad) > 20:
        print(f'  … {len(bad) - 20} more skipped lines')
    status()


def status():
    result = scan()
    total_missing = set()
    for lv in LEVELS:
        tokens, found, missing = result[lv]
        total_missing |= set(missing)
        print(f'{lv.upper()}: {found}/{tokens} words in the texts have a meaning ({found * 100 // max(tokens, 1)}%), '
              f'{len(missing)} different forms missing')
    print(f'all levels: {len(total_missing)} different forms missing')


if __name__ == '__main__':
    command = sys.argv[1] if len(sys.argv) > 1 else 'status'
    {'export': export, 'import': import_answers, 'status': status}[command]()

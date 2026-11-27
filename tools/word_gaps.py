"""Every word a learner needs up to B2: Codex compares each level's word list with the official lists (Goethe-Institut
word lists for A1, A2 and B1; Profile Deutsch for B2) and writes the missing words in the level files' own format.

    python -I -X utf8 tools/word_gaps.py export     ../icerik/kelime/<LV>_mevcut.txt (the words we have, this level and
                                                    the levels below) and <LV>_eksik_istek.txt (the request)
    python -I -X utf8 tools/word_gaps.py check      checks ../icerik/kelime/<LV>_eksik_cevap_NN.txt: format, duplicates,
                                                    words we already have; prints what can be imported
    python -I -X utf8 tools/word_gaps.py status

Answer line (same as tools/levels/<level>/words_*.txt, read by tools/build_level.py):
    type|word|forms|tr|example|example_tr
    type: der / die / das (nouns), v (verbs), w (other words)
    forms: nouns "die <plural>" or "-"; verbs "er <3rd person> · hat/ist <Partizip II>"; others "-"
"""
import glob
import json
import os
import re
import sys

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CONTENT = os.path.join(REPO, 'Resources', 'content')
FOLDER = os.path.join(os.path.dirname(REPO), 'icerik', 'kelime')
LEVELS = ['A1', 'A2', 'B1', 'B2']
SOURCE = {
    'A1': 'Goethe-Institut, Goethe-Zertifikat A1: Start Deutsch 1, Wortliste',
    'A2': 'Goethe-Institut, Goethe-Zertifikat A2, Wortliste',
    'B1': 'Goethe-Institut, Goethe-Zertifikat B1, Wortliste',
    'B2': 'Profile Deutsch, Niveau B2 (Goethe B2 has no official list: use the B2 vocabulary of Profile Deutsch and '
          'of the B2 exam topics: work, education, health, environment, media, society, politics, consumption)',
}
PER_FILE = 200


def norm(word):
    w = word.lower().strip()
    w = re.sub(r'^(der|die|das|sich)\s+', '', w)
    return re.sub(r'[^a-zäöüß]', '', w)


def have(level):
    """Normalised words of this level and every level below."""
    out = set()
    for lv in LEVELS[:LEVELS.index(level) + 1]:
        for w in json.load(open(os.path.join(CONTENT, f'{lv.lower()}.json'), encoding='utf-8'))['words']:
            out.add(norm(w['de']))
    return out


def export():
    os.makedirs(FOLDER, exist_ok=True)
    for level in LEVELS:
        words = []
        for lv in LEVELS[:LEVELS.index(level) + 1]:
            for w in json.load(open(os.path.join(CONTENT, f'{lv.lower()}.json'), encoding='utf-8'))['words']:
                art = w['type'] + ' ' if w['type'] in ('der', 'die', 'das') else ''
                words.append(f"{lv}  {art}{w['de']}")
        open(os.path.join(FOLDER, f'{level}_mevcut.txt'), 'w', encoding='utf-8', newline='\r\n').write(
            f'{level} ve alt seviyelerde UYGULAMADA OLAN kelimeler ({len(words)}). Bunları tekrar yazma.\n\n' + '\n'.join(words) + '\n')
        request = f'''{level} EKSİK KELİMELER — Deschly (B2'ye kadar gereken bütün kelimeler uygulamada olsun)

KAYNAK: {SOURCE[level]}
MEVCUT: icerik\\kelime\\{level}_mevcut.txt  ({level} ve alt seviyelerde uygulamada olan bütün kelimeler)

GÖREV:
1. Kaynaktaki {level} kelimelerini mevcut listeyle karşılaştır.
2. Mevcut listede OLMAYAN her kelimeyi aşağıdaki formatta yaz. Alt seviyede olan bir kelimeyi tekrar yazma.
3. Kaynakta olup çok özel/eskimiş olanları atlayabilirsin; günlük hayatta ve sınavda gereken kelimeyi atlama.
4. Kelimeler {level} seviyesine uygun olsun: örnek cümle {level} öğrencisinin anlayacağı kadar basit, 6–14 kelime,
   doğal ve gündelik; tek anlamı göster (en sık kullanılan anlam).

FORMAT (her satır bir kelime, başka bir şey yazma):
tür|kelime|biçimler|türkçe|örnek|örnek_türkçe
  tür:      der / die / das (isim), v (fiil), w (diğer: sıfat, zarf, edat, bağlaç, kalıp)
  kelime:   isimde artikelsiz ve büyük harfle (Fahrkarte); fiilde mastar (abholen; dönüşlüyse "sich freuen")
  biçimler: isim → "die <çoğul>" (die Fahrkarten), çoğulu yoksa "-"; fiil → "er <şimdiki> · hat/ist <Partizip II>"
            (er holt ab · hat abgeholt); diğer → "-"
  türkçe:   kısa, doğal Türkçe anlam
  örnek:    Almanca örnek cümle
  örnek_türkçe: örneğin doğal Türkçesi
Örnekler:
der|Fahrkartenautomat|die Fahrkartenautomaten|bilet otomatı|Der Fahrkartenautomat am Bahnhof nimmt keine Karten.|İstasyondaki bilet otomatı kart kabul etmiyor.
v|abholen|er holt ab · hat abgeholt|almak (gidip)|Ich hole dich um sechs Uhr vom Bahnhof ab.|Seni saat altıda istasyondan alırım.
w|pünktlich|-|dakik, zamanında|Der Zug ist heute pünktlich.|Tren bugün zamanında.

KAYDET: icerik\\kelime\\{level}_eksik_cevap_01.txt, _02.txt … (her dosyada en fazla {PER_FILE} satır)
Bitince listedeki işin altına "Durum: [HAZIR] {level}: N kelime" yaz. Claude kontrol eder ve uygulamaya ekler.
'''
        open(os.path.join(FOLDER, f'{level}_eksik_istek.txt'), 'w', encoding='utf-8', newline='\r\n').write(request)
        print(level, len(words), 'words listed')


LINE = re.compile(r'^(der|die|das|v|w)\|([^|]+)\|([^|]*)\|([^|]+)\|([^|]+)\|([^|]+)$')


def check():
    for level in LEVELS:
        known = have(level)
        rows, bad, dup = [], [], []
        seen = set()
        for path in sorted(glob.glob(os.path.join(FOLDER, f'{level}_eksik_cevap_*.txt'))):
            for n, line in enumerate(open(path, encoding='utf-8-sig'), 1):
                line = line.strip()
                if not line:
                    continue
                m = LINE.match(line)
                if not m:
                    bad.append(f'{os.path.basename(path)}:{n}: {line[:60]}')
                    continue
                key = norm(m.group(2))
                if key in known or key in seen:
                    dup.append(m.group(2))
                    continue
                seen.add(key)
                rows.append(line)
        if rows or bad or dup:
            print(f'{level}: {len(rows)} new, {len(dup)} already there or repeated, {len(bad)} bad lines')
            for b in bad[:10]:
                print('   bad', b)


def status():
    for level in LEVELS:
        answers = glob.glob(os.path.join(FOLDER, f'{level}_eksik_cevap_*.txt'))
        print(level, 'answers:', len(answers))


if __name__ == '__main__':
    {'export': export, 'check': check}.get(sys.argv[1] if len(sys.argv) > 1 else '', status)()

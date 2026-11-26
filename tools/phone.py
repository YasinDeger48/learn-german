"""Phone calls (Telefonda): real-life phone conversations and voicemail messages (like Goethe Hören, Teil 3).

    python -I -X utf8 tools/phone.py export A1     ../icerik/telefon/A1_telefon_istek_01..NN.txt (one per call / message)
    python -I -X utf8 tools/phone.py import A1     reads ../icerik/telefon/A1_telefon_cevap_*.txt -> Resources/content/phone_a1.json
    python -I -X utf8 tools/phone.py status

The file keeps the answers as written ("items", used by tools/audio.py for the phone sound: the other side
sounds like a phone line with its background, Elif's side is clear) and "texts" in the DailyText shape, so the
reading screen, its quiz and the word bubble work as for the stories.
"""
import glob
import json
import os
import sys

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CONTENT = os.path.join(REPO, 'Resources', 'content')
FOLDER = os.path.join(os.path.dirname(REPO), 'icerik', 'telefon')
PLACES = ['office', 'cafe', 'home', 'shop', 'street', 'train', 'bus', 'school', 'nature', 'rain', '']
NEAR = 'Elif'
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from audio import is_name  # noqa: E402  same speaker-name rule as the audio and the app (Dialogue in Speech.swift)

# (id, kind, situation in Turkish, place of the OTHER side for the background sound)
TOPICS = {
    'a1': [
        ('t01', 'call', 'Elif doktor muayenehanesini arar ve randevu alır (gün, saat, sigorta kartı).', 'office'),
        ('t02', 'call', 'Elif doktor randevusunu iptal eder ve yeni bir gün ister.', 'office'),
        ('t03', 'call', 'Elif işyerini arar: hasta olduğunu, bugün gelemeyeceğini söyler.', 'office'),
        ('t04', 'call', 'Elif bir restoranı arar ve cumartesi akşamı için masa ayırtır (kaç kişi, saat, isim).', 'cafe'),
        ('t05', 'call', 'Elif taksi çağırır: adres, saat, nereye gideceği.', 'street'),
        ('t06', 'call', 'Elif ev sahibi Herr Brandt\'ı arar: kalorifer bozuk; ne zaman gelebileceğini sorar.', 'home'),
        ('t07', 'call', 'Elif dil okulunu arar: yeni kurs ne zaman başlıyor, kaç para, nerede.', 'school'),
        ('t08', 'call', 'Lina Elif\'i arar; hafta sonu buluşmak için gün, saat ve yer konuşurlar (Elif telefonu açar).', 'street'),
        ('t09', 'call', 'Elif pizzacıyı arar ve eve pizza sipariş eder (ne, kaç tane, adres, fiyat).', 'cafe'),
        ('t10', 'call', 'Kargo şirketinden biri Elif\'i arar: paket bugün gelemiyor, yarın mı, komşuya mı (Elif telefonu açar).', 'street'),
        ('m01', 'message', 'Telesekreter: doktor muayenehanesi Elif\'in randevusunu başka bir güne alıyor.', 'office'),
        ('m02', 'message', 'Telesekreter: Lina buluşma yerini değiştiriyor (kafe yerine tren istasyonu).', 'street'),
        ('m03', 'message', 'Telesekreter: dil okulu, yarın ders başka bir odada ve saat değişti.', 'school'),
        ('m04', 'message', 'Telesekreter: kütüphane, Elif\'in kitabı geldi, ne zamana kadar alabileceği.', 'office'),
        ('m05', 'message', 'Telesekreter: Frau Schmidt (komşu) Elif\'in paketini aldı, akşam getirebilir.', 'home'),
        ('m06', 'message', 'Telesekreter: bisiklet tamircisi, bisiklet hazır, fiyat ve açılış saatleri.', 'street'),
    ],
    'a2': [
        ('t01', 'call', 'Elif Bürgeramt\'ı arar: adres kaydı için randevu, hangi belgeleri getirmeli.', 'office'),
        ('t02', 'call', 'Elif bankayı arar: kartını kaybetti, kartı kapattırır ve yeni kart ister.', 'office'),
        ('t03', 'call', 'Elif telefon şirketini arar: internet çalışmıyor; teknisyen ne zaman gelir.', 'office'),
        ('t04', 'call', 'Elif bir ilandaki daireyi görmek için ev sahibini arar (kira, oda sayısı, görme günü).', 'home'),
        ('t05', 'call', 'Elif internetten aldığı ayakkabı yanlış geldi; online mağazayı arar, değişim ister.', 'office'),
        ('t06', 'call', 'Elif eczaneyi arar: ilacı geldi mi, reçete lazım mı, ne zaman açık.', 'shop'),
        ('t07', 'call', 'Elif şefini arar: gelecek hafta vardiya değiştirmek ister, sebebini söyler.', 'office'),
        ('t08', 'call', 'Elif sigorta şirketini arar: bisikleti çalındı, ne yapması gerekiyor.', 'office'),
        ('t09', 'call', 'Okul Elif\'in komşusunun çocuğu için Elif\'i arar (acil kişi): çocuk hasta, alınması gerek (Elif telefonu açar).', 'school'),
        ('t10', 'call', 'Elif bir dil okulunu arar: sınav (Goethe A2) kaydı, tarih, ücret, son başvuru günü.', 'school'),
        ('m01', 'message', 'Telesekreter: Bürgeramt, randevu iptal oldu; yeni randevu için internetten başvurmalı.', 'office'),
        ('m02', 'message', 'Telesekreter: teknisyen yarın 8–12 arası geliyor; evde biri olmalı.', 'street'),
        ('m03', 'message', 'Telesekreter: iş görüşmesi davet; tarih, adres, getirmesi gerekenler.', 'office'),
        ('m04', 'message', 'Telesekreter: doktor muayenehanesi, kan tahlili sonuçları geldi; aç karnına yeniden gelmeli.', 'office'),
        ('m05', 'message', 'Telesekreter: Lina\'nın doğum günü partisi; ne getirmeli, adres, saat.', 'home'),
        ('m06', 'message', 'Telesekreter: tren şirketi, tren iptal; yedek otobüs nereden kalkıyor.', 'train'),
    ],
}

LEVEL_RULES = {
    'a1': 'Seviye A1 (Goethe A1): kısa cümleler (en fazla 10 kelime), Präsens; gerekirse Perfekt ve modal fiiller '
          '(können, möchten, müssen). Yan cümle kullanma. Telefon kalıpları: "Praxis Dr. Wolf, guten Tag.", '
          '"Hier ist …", "Ich möchte einen Termin.", "Auf Wiederhören!".',
    'a2': 'Seviye A2 (Goethe A2): cümleler en fazla 14 kelime; Präsens, Perfekt, Präteritum (war/hatte), modal fiiller, '
          'weil/dass/wenn yan cümleleri. Resmî telefon dili (Sie) ve günlük dil (du) duruma göre.',
}

PROMPT = '''Sen deneyimli bir Almanca (DaF) ders kitabı yazarısın ve Goethe sınavının Hören bölümünü iyi biliyorsun.
Deschly uygulamasının "Telefonda" bölümü için {WHAT} yaz. Ses dosyası bundan yapılacak: karşı tarafın sesi gerçek
telefon gibi süzülecek, arkasında ortam sesi olacak; Elif'in sesi temiz.

Durum: {SITUATION}
{LEVEL_RULES}

KİŞİLER
- Elif: Türkiye'den gelip Köln'de yaşayan genç kadın (24). Lina: arkadaşı. Frau Schmidt: komşusu. Tom: Lina'nın arkadaşı.
- Diğer kişiler (resepsiyon, ev sahibi, banka …) HER ZAMAN "Frau Soyad" veya "Herr Soyad" olsun (Frau Wolf, Herr Brandt).
- "who" alanı: 1–2 kelime, her kelime büyük harfle başlar, nokta yok ("Dr." yazma; "Frau Wolf" yaz).
  Kurum adı "who" olmaz; kurum adını repliğin içinde söyle ("Praxis Dr. Wolf, Frau Kaya am Apparat.").

{KIND_RULES}
- Gerçekçi ol: telefon açılış/kapanış kalıpları, heceleme (Name buchstabieren), numara/saat/tarih tekrarı,
  "Wie bitte?", "Können Sie das bitte wiederholen?" gibi gerçek hayattan anlar. Şablon kullanma.
- Her satırın Türkçe ("tr") ve İngilizce ("en") çevirisi doğal olsun.
- "glossary": seviyenin üstünde kalan en fazla 4 kelime (form, lemma, art: der/die/das ya da null, tr, en).

BİÇİM: Sadece 1 satır JSON, başka hiçbir şey yazma, kod bloğu kullanma:
{{"id":"{ID}","level":"{LEVEL}","kind":"{KIND}","place":"{PLACE}","title":"(Almanca başlık)","title_tr":"…","title_en":"…","lines":[{EXAMPLE}],"glossary":[],"questions":[{{"type":"mc","q":"…","options":["…","…","…"],"answer":0}},{{"type":"tf","q":"…","answer":1}}]}}
("answer": mc'de doğru seçeneğin sırası 0/1/2; tf'de 0 = Richtig, 1 = Falsch.)
'''

CALL_RULES = '''- Telefon görüşmesi: 10–16 replik, iki kişi; biri Elif. Kim önce konuşuyorsa onu yaz (arayan Elif ise önce karşı taraf açar:
  "Praxis Dr. Wolf, Frau Kaya, guten Tag."; Elif aranıyorsa önce Elif açar: "Hallo?" ya da "Elif Yılmaz, hallo?").
- 4 soru: 2 çoktan seçmeli (3 seçenek) ve 2 doğru/yanlış; cevaplar görüşmede duyulan bilgi (gün, saat, yer, sebep).'''
MESSAGE_RULES = '''- Telesekreter mesajı (Goethe Hören Teil 3 gibi): TEK kişi konuşur, 4–7 satır, 40–80 kelime. Kendini tanıtır,
  Elif'e hitap eder, bilgiyi verir (saat, gün, yer, numara), gerekiyorsa numarayı ya da saati tekrar eder, vedalaşır.
  Her satırda "who" aynı kişi.
- 2 soru: 1 çoktan seçmeli (3 seçenek; sınavdaki gibi tek önemli bilgi: "Wann soll Elif kommen?") ve 1 doğru/yanlış.'''
CALL_EXAMPLE = '{"who":"Frau Kaya","de":"Praxis Dr. Wolf, Frau Kaya am Apparat. Guten Tag!","tr":"Dr. Wolf muayenehanesi, ben Frau Kaya. İyi günler!","en":"Dr Wolf\'s practice, Ms Kaya speaking. Good afternoon!"},{"who":"Elif","de":"Guten Tag, hier ist Elif Yılmaz.","tr":"İyi günler, ben Elif Yılmaz.","en":"Hello, this is Elif Yılmaz."}'
MESSAGE_EXAMPLE = '{"who":"Frau Kaya","de":"Guten Tag, Frau Yılmaz, hier ist die Praxis Dr. Wolf.","tr":"İyi günler Frau Yılmaz, Dr. Wolf muayenehanesinden arıyoruz.","en":"Hello Ms Yılmaz, this is Dr Wolf\'s practice."}'


def out_path(level):
    return os.path.join(CONTENT, f'phone_{level}.json')


def export(level):
    level = level.lower()
    os.makedirs(FOLDER, exist_ok=True)
    for n, (short, kind, situation, place) in enumerate(TOPICS[level], 1):
        call = kind == 'call'
        body = PROMPT.format(WHAT='bir telefon görüşmesi' if call else 'bir telesekreter mesajı', SITUATION=situation,
                             LEVEL_RULES=LEVEL_RULES[level], KIND_RULES=CALL_RULES if call else MESSAGE_RULES,
                             ID=f'{level}-{short}', LEVEL=level.upper(), KIND=kind, PLACE=place,
                             EXAMPLE=CALL_EXAMPLE if call else MESSAGE_EXAMPLE)
        path = os.path.join(FOLDER, f'{level.upper()}_telefon_istek_{n:02d}.txt')
        open(path, 'w', encoding='utf-8', newline='\r\n').write(body)
    print(f'{len(TOPICS[level])} requests -> {FOLDER}')


def problems_of(item, level):
    out = []
    if item.get('kind') not in ('call', 'message') or not item.get('lines') or item.get('level', '').lower() != level:
        return ['wrong kind/level/lines']
    if item.get('place', '') not in PLACES:
        out.append(f"unknown place {item.get('place')}")
    for line in item['lines']:
        if not all(isinstance(line.get(k), str) and line.get(k).strip() for k in ('who', 'de', 'tr', 'en')):
            return ['a line misses who/de/tr/en']
        who = line['who'].strip()
        if not is_name(who):
            out.append(f'bad speaker name "{who}" (1-2 capitalized words, no dots)')
    speakers = {l['who'].strip() for l in item['lines']}
    if item['kind'] == 'call' and (len(speakers) != 2 or NEAR not in speakers):
        out.append(f'a call needs Elif and one other person, got {sorted(speakers)}')
    if item['kind'] == 'message' and len(speakers) != 1:
        out.append(f'a message has one speaker, got {sorted(speakers)}')
    questions = item.get('questions') or []
    bad = [q for q in questions if q.get('type') not in ('mc', 'tf') or
           (q['type'] == 'mc' and not (0 <= q.get('answer', -1) < len(q.get('options') or []))) or
           (q['type'] == 'tf' and q.get('answer') not in (0, 1))]
    if bad or len(questions) < 2:
        out.append('questions wrong')
    return out


def as_daily_text(item):
    """DailyText shape. Calls: "Name: text" paragraphs (the reader shows who speaks); messages: the words only."""
    call = item['kind'] == 'call'
    def para(line, key):
        return f"{line['who'].strip()}: {line[key]}" if call else line[key]
    return {
        'id': 't-' + item['id'], 'level': item['level'].upper(), 'topic': item['kind'], 'title': item['title'],
        'paragraphs': [para(l, 'de') for l in item['lines']],
        'trans': [{'tr': para(l, 'tr'), 'en': para(l, 'en')} for l in item['lines']],
        'glossary': [{'form': g.get('form', ''), 'lemma': g.get('lemma') or g.get('form', ''), 'art': g.get('art') or None,
                      'pron': None, 'extra': None, 'mean': {'tr': g.get('tr', ''), 'en': g.get('en', '')}}
                     for g in item.get('glossary', []) if g.get('form')],
        'questions': [{'type': q['type'], 'q': q['q'], 'options': q.get('options'), 'answer': q['answer']}
                      for q in item['questions']],
    }


def import_answers(level):
    level = level.lower()
    path = out_path(level)
    items = {i['id']: i for i in json.load(open(path, encoding='utf-8'))['items']} if os.path.exists(path) else {}
    problems = []
    for answer in sorted(glob.glob(os.path.join(FOLDER, f'{level.upper()}_telefon_cevap_*.txt'))):
        for n, line in enumerate(open(answer, encoding='utf-8-sig'), 1):
            line = line.strip().strip(',')
            if not line.startswith('{'):
                continue
            name = f'{os.path.basename(answer)}:{n}'
            try:
                item = json.loads(line)
            except json.JSONDecodeError:
                problems.append(f'{name} not JSON')
                continue
            found = problems_of(item, level)
            if found:
                problems.append(f"{name} {item.get('id')}: " + '; '.join(found))
                continue
            items[item['id']] = item
    order = {f'{level}-{t[0]}': i for i, t in enumerate(TOPICS[level])}
    ordered = sorted(items.values(), key=lambda i: (order.get(i['id'], 99), i['id']))
    with open(path, 'w', encoding='utf-8', newline='\n') as f:
        json.dump({'level': level.upper(), 'items': ordered, 'texts': [as_daily_text(i) for i in ordered]},
                  f, ensure_ascii=False, indent=1)
        f.write('\n')
    print(f'{level.upper()}: {len(ordered)}/{len(TOPICS[level])} phone items in {path}')
    for p in problems:
        print('  ', p)


def status():
    for level in TOPICS:
        path = out_path(level)
        have = {i['id'] for i in json.load(open(path, encoding='utf-8'))['items']} if os.path.exists(path) else set()
        print(f'{level.upper()}: {len(have)}/{len(TOPICS[level])}')


if __name__ == '__main__':
    command = sys.argv[1] if len(sys.argv) > 1 else 'status'
    if command == 'export':
        export(sys.argv[2])
    elif command == 'import':
        import_answers(sys.argv[2])
    else:
        status()

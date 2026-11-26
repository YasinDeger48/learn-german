"""Path stories: for each A1 unit two short stories (a dialogue and a narrative) written ONLY with the words the
learner has met by that unit and the grammar taught so far — the "teach, then use" input most courses give per
lesson. One running storyline (Elif's first months in Köln, with Lina).

    python -I -X utf8 tools/stories.py export      ../icerik/hikaye/A1_hikaye_istek_01..12.txt (one per unit)
    python -I -X utf8 tools/stories.py import      reads ../icerik/hikaye/A1_hikaye_cevap_*.txt -> Resources/content/stories_a1.json
    python -I -X utf8 tools/stories.py status

Import checks the shape and reports words that are neither allowed for the unit nor in the story's glossary.
"""
import glob
import json
import os
import re
import sys

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CONTENT = os.path.join(REPO, 'Resources', 'content')
FOLDER = os.path.join(os.path.dirname(REPO), 'icerik', 'hikaye')
OUT = os.path.join(CONTENT, 'stories_a1.json')
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

STORYLINE = {
    'a1-01': 'Elif Türkiye\'den Köln\'e yeni geldi. Dil kursunun ilk günü Lina ile tanışır: adlar, nereden geldikleri, nerede oturdukları.',
    'a1-02': 'Elif Lina\'ya telefonundan aile fotoğraflarını gösterir; Lina da kendi ailesini anlatır.',
    'a1-03': 'Elif ve Lina kurstan sonra bir kafeye gider; sonra Lina\'nın evinde birlikte kahvaltı hazırlarlar.',
    'a1-04': 'Elif markette ve haftalık pazarda alışveriş yapar; fiyat sorar, beden ve renk seçer.',
    'a1-05': 'Elif bir WG\'de oda bulur ve taşınır; Lina evi gezer, eşyaları yerleştirirler.',
    'a1-06': 'Elif\'in bir günü: kalkış, kurs, randevular; saatleri ve günleri konuşurlar.',
    'a1-07': 'Elif şehirde kaybolur; yol sorar, otobüs ve tramvayla eczaneyi bulur.',
    'a1-08': 'Elif hastalanır; doktordan randevu alır ve muayene olur.',
    'a1-09': 'Kurs sınavı yaklaşır; Elif bir yarı zamanlı iş için görüşmeye gider.',
    'a1-10': 'Hafta sonu Lina ve arkadaşlarıyla göle gezi; pazartesi Elif hafta sonunu anlatır (geçmiş zaman).',
    'a1-11': 'Elif trenle Berlin\'e gider: bilet, aktarma, otel.',
    'a1-12': 'Elif Bürgeramt\'ta adres kaydı yaptırır, bankada hesap açar; formlar, randevu, sorular.',
}
CAST = ('Kişiler: Elif (Türkiye\'den yeni gelen, 24 yaşında), Lina (Deschly\'nin maskotu, Köln\'de dil kursuna giden neşeli '
        'bir genç kadın, Elif\'in arkadaşı), Herr Weber (kurs öğretmeni), Tom (Lina\'nın arkadaşı), Frau Schmidt (komşu). '
        'Her ünitede bu kişiler; hikayeler birbirinin devamı.')

PROMPT = '''Sen deneyimli bir Almanca (DaF) ders kitabı yazarısın. Deschly uygulamasının A1 yolunda, ünite "{TITLE}" için
2 kısa hikaye yaz. Öğrenci Almancaya sıfırdan başladı; bu üniteye kadar SADECE aşağıdaki kelimeleri ve gramer konularını gördü.

{CAST}
Bu ünitenin hikayesi: {STORY}

KURALLAR
- Hikaye 1: diyalog, 8–12 replik, 2–3 kişi ("kind":"dialog"). Hikaye 2: kısa anlatım, 6–9 cümle, 60–90 kelime ("kind":"story").
- SADECE izin verilen kelimeleri kullan (fiillerin çekimli hâlleri, artikellerin ve zamirlerin hâlleri, sayılar ve
  ünitenin kalıp cümlelerindeki kelimeler serbest; kişi ve şehir adları serbest).
  Listede olmayan bir kelime şart ise hikaye başına EN FAZLA 3 tane kullan ve hepsini "glossary"ye yaz.
- Gramer: yalnızca aşağıdaki konuların izin verdiği yapılar. Cümleler kısa (en fazla 10 kelime), doğal, günlük hayattan.
  Yan cümle (weil, dass, wenn) kullanma. {TENSE}
- Ünitenin kalıp cümlelerinden en az 2'sini doğal biçimde kullan.
- Her hikayeye 4 soru: 2 çoktan seçmeli ("type":"mc", 3 seçenek, "answer": doğru seçeneğin sırası 0/1/2) ve
  2 doğru/yanlış ("type":"tf", "answer": 0 = Richtig, 1 = Falsch). Sorular basit Almanca.
- Her satırın Türkçe ("tr") ve İngilizce ("en") çevirisi doğal olsun.
- Şablon kullanma; her cümleyi bu hikaye için düşün.

BİÇİM: Sadece 2 satır JSON (JSONL), başka hiçbir şey yazma, kod bloğu kullanma:
{{"id":"{UNIT}-1","unit":"{UNIT}","kind":"dialog","title":"(Almanca başlık)","title_tr":"…","title_en":"…","lines":[{{"who":"Lina","de":"Hallo! Ich bin Lina.","tr":"Merhaba! Ben Lina.","en":"Hello! I'm Lina."}}],"glossary":[{{"form":"Kurs","lemma":"Kurs","art":"der","tr":"kurs","en":"course"}}],"questions":[{{"type":"mc","q":"Wer ist neu im Kurs?","options":["Lina","Elif","Tom"],"answer":1}},{{"type":"tf","q":"Elif kommt aus Berlin.","answer":1}}]}}
{{"id":"{UNIT}-2","unit":"{UNIT}","kind":"story","title":"…","title_tr":"…","title_en":"…","lines":[{{"who":"","de":"(bir ya da iki cümle)","tr":"…","en":"…"}}],"glossary":[],"questions":[…]}}
(Anlatımda "who" boş kalır; her "lines" ögesi bir ya da iki cümle.)

ÜNİTENİN KALIP CÜMLELERİ:
{PHRASES}

İZİN VERİLEN GRAMER (bu üniteye kadar):
{GRAMMAR}

İZİN VERİLEN KELİMELER (bu ünite ve öncekiler; ayrıca bütün zamirler, artikeller, sayılar, ja/nein/nicht/kein, und/oder/aber/denn):
{WORDS}
'''


def load(name):
    return json.load(open(os.path.join(CONTENT, name), encoding='utf-8'))


def units():
    return [u for u in load('units.json')['units'] if u['level'] == 'A1']


def unit_words(unit, words):
    return [words[i] for i in (unit.get('pictures') or []) + (unit.get('extra') or []) if i in words]


def allowed_words(index, all_units, a1):
    """Words of this unit and the earlier ones, plus the basic A1 lists (important verbs, adjectives, small words)."""
    words = {w['id']: w for w in a1['words']}
    chosen, seen = [], set()
    for u in all_units[:index + 1]:
        # The unit's cards and extra words, and the verbs of its themes (heißen, kommen, wohnen … in unit 1).
        theme_verbs = [w for w in a1['words'] if w['theme'] in u['themes'] and w['type'] == 'verb']
        for w in unit_words(u, words) + theme_verbs:
            if w['id'] not in seen:
                seen.add(w['id'])
                chosen.append(w)
    basics = [w for w in a1['words'] if w['theme'] in (12, 13, 14) and w['id'] not in seen]
    return chosen, basics


def label(w):
    return f"{w['type']} {w['de']}" if w['type'] in ('der', 'die', 'das') else w['de']


def export():
    a1 = load('a1.json')
    grammar = {g['id']: g for g in a1['grammar']}
    all_units = units()
    os.makedirs(FOLDER, exist_ok=True)
    for index, unit in enumerate(all_units):
        chosen, basics = allowed_words(index, all_units, a1)
        topics = []
        for u in all_units[:index + 1]:
            for g in u['grammar']:
                if g not in topics:
                    topics.append(g)
        grammar_lines = '\n'.join(f"- {grammar[g]['de']} ({grammar[g]['name']['tr']})" for g in topics)
        tense = ('Geçmiş için Perfekt (habe … gemacht, bin … gefahren) ve war/hatte kullanabilirsin.'
                 if 15 in topics else 'Sadece şimdiki zaman (Präsens) kullan; geçmiş zaman henüz öğretilmedi.')
        body = PROMPT.format(TITLE=f"{unit['number']}. {unit['title']['tr']}", CAST=CAST, STORY=STORYLINE[unit['id']],
                             TENSE=tense, UNIT=unit['id'],
                             PHRASES='\n'.join(f"- {p['de']} ({p['tr']})" for p in unit['phrases']),
                             GRAMMAR=grammar_lines,
                             WORDS='Bu ve önceki ünitelerin kelimeleri: ' + ', '.join(label(w) for w in chosen) +
                                   '\nTemel listeler: ' + ', '.join(label(w) for w in basics))
        path = os.path.join(FOLDER, f'A1_hikaye_istek_{index + 1:02d}.txt')
        open(path, 'w', encoding='utf-8', newline='\r\n').write(body)
    print(f'{len(all_units)} requests -> {FOLDER}')


FUNCTION = set('''ich du er sie es wir ihr mich dich mir dir ihn ihm uns euch ihnen sich man der die das den dem des ein eine
einen einem einer eines kein keine keinen keinem keiner mein meine meinen meinem meiner dein deine deinen deinem sein seine
seinen seinem ihr ihre ihren ihrem unser unsere euer eure ja nein nicht und oder aber denn auch noch schon sehr so hier da dort
in im ins an am auf aus bei mit nach von vom zu zum zur für um ohne bis seit über unter vor hinter neben zwischen'''.split())


def stems(word):
    w = word.lower()
    out = {w}
    if w.endswith('en') and len(w) > 4:
        out.add(w[:-2])
    elif w.endswith('n') and len(w) > 3:
        out.add(w[:-1])
    return out


def import_answers():
    a1 = load('a1.json')
    all_units = units()
    by_unit = {u['id']: i for i, u in enumerate(all_units)}
    stories, problems = {}, []
    if os.path.exists(OUT):
        stories = {s['id']: s for s in json.load(open(OUT, encoding='utf-8'))['stories']}
    for path in sorted(glob.glob(os.path.join(FOLDER, 'A1_hikaye_cevap_*.txt'))):
        for n, line in enumerate(open(path, encoding='utf-8-sig'), 1):
            line = line.strip().strip(',')
            if not line.startswith('{'):
                continue
            try:
                s = json.loads(line)
            except json.JSONDecodeError:
                problems.append(f'{os.path.basename(path)}:{n} not JSON')
                continue
            name = f"{os.path.basename(path)}:{n} {s.get('id')}"
            if s.get('unit') not in by_unit or s.get('kind') not in ('dialog', 'story') or not s.get('lines'):
                problems.append(f'{name} wrong unit/kind/lines')
                continue
            if any(not all(isinstance(l.get(k), str) for k in ('who', 'de', 'tr', 'en')) for l in s['lines']):
                problems.append(f'{name} a line misses who/de/tr/en')
                continue
            bad_q = [q for q in s.get('questions', []) if q.get('type') not in ('mc', 'tf') or
                     (q['type'] == 'mc' and not (0 <= q.get('answer', -1) < len(q.get('options', [])))) or
                     (q['type'] == 'tf' and q.get('answer') not in (0, 1))]
            if bad_q or len(s.get('questions', [])) < 2:
                problems.append(f'{name} questions wrong')
                continue
            # Words outside the unit's list and the glossary (a report only; names and forms make false alarms).
            chosen, basics = allowed_words(by_unit[s['unit']], all_units, a1)
            known = set(FUNCTION)
            for w in chosen + basics:
                known |= stems(w['de'])
                if w.get('plural'):
                    known.add(w['plural'].lower())
            for u in all_units[:by_unit[s['unit']] + 1]:
                for p in u['phrases']:
                    known |= {t.lower() for t in re.findall(r"[A-Za-zÄÖÜäöüß]+", p['de'])}
            for g in s.get('glossary', []):
                known |= stems(g.get('form', '')) | stems(g.get('lemma', ''))
            unknown = sorted({t for l in s['lines'] for t in re.findall(r"[A-Za-zÄÖÜäöüß]+", l['de'])
                              if t[0].islower() and len(t) > 3 and not any(t.lower().startswith(k) for k in known if len(k) > 3)})
            if unknown:
                problems.append(f'{name} words not in the lists (check): {", ".join(unknown[:12])}')
            stories[s['id']] = s
    ordered = sorted(stories.values(), key=lambda s: (by_unit.get(s['unit'], 99), s['id']))
    with open(OUT, 'w', encoding='utf-8', newline='\n') as f:
        json.dump({'stories': ordered}, f, ensure_ascii=False, indent=1)
        f.write('\n')
    print(f'{len(ordered)} stories in {OUT}')
    for p in problems[:40]:
        print('  ', p)


def status():
    have = {s['unit'] for s in json.load(open(OUT, encoding='utf-8'))['stories']} if os.path.exists(OUT) else set()
    for u in units():
        print(u['id'], 'ok' if u['id'] in have else '-')


if __name__ == '__main__':
    command = sys.argv[1] if len(sys.argv) > 1 else 'status'
    {'export': export, 'import': import_answers}.get(command, status)()

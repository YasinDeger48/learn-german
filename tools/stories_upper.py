"""Path stories for A2 and up: per unit a dialogue and a short narrative, with the unit's words, phrases and grammar.
The A1 stories have their own tool with a strict word list (tools/stories.py); from A2 on the learner knows the
A1 words, so the request lists the unit's words and grammar and the import checks the shape only.

    python -I -X utf8 tools/stories_upper.py export A2     ../icerik/hikaye/A2_hikaye_istek_01..NN.txt (one per unit)
    python -I -X utf8 tools/stories_upper.py import A2     reads ../icerik/hikaye/A2_hikaye_cevap_*.txt -> Resources/content/stories_a2.json
    python -I -X utf8 tools/stories_upper.py status

Same file shape as stories_a1.json ("stories" as written, "texts" in the DailyText shape, "units": unit -> text ids),
so the app (StoryBank), tools/audio.py (one voice per speaker) and tools/ambience.py read it the same way.
"""
import glob
import json
import os
import sys

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CONTENT = os.path.join(REPO, 'Resources', 'content')
FOLDER = os.path.join(os.path.dirname(REPO), 'icerik', 'hikaye')
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from audio import is_name  # noqa: E402  speaker names: same rule as the audio and the app

# Elif's second year in Köln, one step per unit.
STORYLINE = {
    'a2-01': 'Elif bir yıldır Köln\'de; bir kitapçıda yarı zamanlı çalışıyor. Pazartesi Lina\'ya hafta sonu ne yaptığını '
             'Perfekt ile anlatır; sonra günlük rutinini (ayrılabilen fiiller: aufstehen, einkaufen …) anlatır.',
    'a2-02': 'Elif\'in yeni komşusu Herr Brandt gece müzik dinliyor; Elif kibarca konuşur. Frau Schmidt\'in eşyalarını '
             'yerleştirmesine yardım eder (Wo? / Wohin? edatları).',
    'a2-03': 'Elif internetten aldığı ceket yanlış renkte geldi; mağazada değiştirir. Sıfat çekimi: "die rote Jacke", '
             '"einen warmen Pullover".',
    'a2-04': 'Elif ve Lina trenle Hamburg\'a gider; tren gecikir, aktarmayı kaçırırlar, yol sorarlar. Emir kipi '
             '(Nehmen Sie …, Geh …) ve Dativ.',
    'a2-05': 'Elif\'in sırtı ağrıyor; doktora gider, eczaneden ilaç alır. Lina ona tavsiye verir: "Du musst …", '
             '"Du musst nicht …"; dönüşlü fiiller (sich ausruhen, sich fühlen).',
    'a2-06': 'Elif bir ofiste iş görüşmesine gider, ilk iş günü şefi Frau Wolf ile tanışır. weil ve dass yan cümleleri.',
    'a2-07': 'Lina ve Elif eski fotoğraflara bakar; çocukluk anıları (Präteritum: war, hatte, konnte) ve '
             'wenn/als yan cümleleri.',
    'a2-08': 'Elif\'in telefonu bozulur; Tom yardım eder, online randevu alırlar. dass yan cümlesi ve Akkusativ.',
    'a2-09': 'Elif Goethe A2 sınavına hazırlanır; Lina ile çalışma planı yaparlar, sınav günü. zu + Infinitiv '
             '("Ich habe vor, jeden Tag zu lernen").',
    'a2-10': 'Mahallede çevre günü: çöp toplama, geri dönüşüm, enerji tasarrufu. Karşılaştırma (besser, am besten).',
}
CAST = ('Kişiler: Elif (Türkiye\'den, 25 yaşında, Köln\'de bir yıldır), Lina (Deschly\'nin maskotu, Elif\'in neşeli '
        'arkadaşı), Tom (Lina\'nın arkadaşı), Frau Schmidt (komşu), Herr Brandt (yeni komşu), Frau Wolf (şef). '
        'Hikayeler A1 hikayelerinin devamı; her ünite bir sonrakine bağlanır.')
LEVEL_RULES = {
    'A2': 'Seviye A2 (Goethe A2): cümleler en fazla 14 kelime; A1 kelimelerini öğrenci biliyor. Ünitenin kelimelerinden '
          'en az 5\'ini ve gramer konularını doğal biçimde kullan. Listede ve A1\'de olmayan zor kelime gerekiyorsa '
          'hikaye başına EN FAZLA 4 tane, hepsi "glossary"de.',
}

PROMPT = '''Sen deneyimli bir Almanca (DaF) ders kitabı yazarısın. Deschly uygulamasının {LEVEL} yolunda, ünite
"{TITLE}" için 2 kısa hikaye yaz.

{CAST}
Bu ünitenin hikayesi: {STORY}
{RULES}

KURALLAR
- Hikaye 1: diyalog, 10–14 replik, 2–3 kişi ("kind":"dialog"). Hikaye 2: kısa anlatım, 8–11 cümle, 100–140 kelime ("kind":"story").
- Diyalogda "who": 1–2 kelime, her kelime büyük harfle başlar, nokta yok (Elif, Lina, Frau Wolf, Herr Brandt).
  Anlatımda "who" boş kalır; her "lines" ögesi bir ya da iki cümle.
- Ünitenin kalıp cümlelerinden en az 2'sini doğal biçimde kullan.
- Her hikayeye 4 soru: 2 çoktan seçmeli ("type":"mc", 3 seçenek, "answer": doğru seçeneğin sırası 0/1/2) ve
  2 doğru/yanlış ("type":"tf", "answer": 0 = Richtig, 1 = Falsch). Sorular basit Almanca.
- Her satırın Türkçe ("tr") ve İngilizce ("en") çevirisi doğal olsun. Şablon kullanma.

BİÇİM: Sadece 2 satır JSON (JSONL), başka hiçbir şey yazma, kod bloğu kullanma:
{{"id":"{UNIT}-1","unit":"{UNIT}","kind":"dialog","title":"(Almanca başlık)","title_tr":"…","title_en":"…","lines":[{{"who":"Lina","de":"…","tr":"…","en":"…"}}],"glossary":[{{"form":"…","lemma":"…","art":"der","tr":"…","en":"…"}}],"questions":[{{"type":"mc","q":"…","options":["…","…","…"],"answer":1}},{{"type":"tf","q":"…","answer":1}}]}}
{{"id":"{UNIT}-2","unit":"{UNIT}","kind":"story","title":"…","title_tr":"…","title_en":"…","lines":[{{"who":"","de":"…","tr":"…","en":"…"}}],"glossary":[],"questions":[…]}}

ÜNİTENİN KALIP CÜMLELERİ:
{PHRASES}

ÜNİTENİN GRAMER KONULARI:
{GRAMMAR}

ÜNİTENİN KELİMELERİ:
{WORDS}
'''


def load(name):
    return json.load(open(os.path.join(CONTENT, name), encoding='utf-8'))


def units(level):
    return [u for u in load('units.json')['units'] if u['level'] == level.upper()]


def out_path(level):
    return os.path.join(CONTENT, f'stories_{level.lower()}.json')


def export(level):
    level = level.upper()
    grammar = {g['id']: g for g in load(f'{level.lower()}.json')['grammar']}
    os.makedirs(FOLDER, exist_ok=True)
    level_units = units(level)
    for index, unit in enumerate(level_units):
        words = ', '.join(f"{w['art']} {w['de']}" if w.get('art') else w['de'] for w in unit.get('vocab') or [])
        body = PROMPT.format(LEVEL=level, TITLE=f"{unit['number']}. {unit['title']['tr']}", CAST=CAST,
                             STORY=STORYLINE[unit['id']], RULES=LEVEL_RULES[level], UNIT=unit['id'],
                             PHRASES='\n'.join(f"- {p['de']} ({p['tr']})" for p in unit.get('phrases') or []),
                             GRAMMAR='\n'.join(f"- {grammar[g]['de']} ({grammar[g]['name']['tr']})" for g in unit['grammar']),
                             WORDS=words)
        path = os.path.join(FOLDER, f'{level}_hikaye_istek_{index + 1:02d}.txt')
        open(path, 'w', encoding='utf-8', newline='\r\n').write(body)
    print(f'{len(level_units)} requests -> {FOLDER}')


def problems_of(s, unit_ids):
    if s.get('unit') not in unit_ids or s.get('kind') not in ('dialog', 'story') or not s.get('lines'):
        return ['wrong unit/kind/lines']
    if any(not all(isinstance(l.get(k), str) for k in ('who', 'de', 'tr', 'en')) for l in s['lines']):
        return ['a line misses who/de/tr/en']
    out = []
    if s['kind'] == 'dialog':
        bad = sorted({l['who'] for l in s['lines'] if not is_name(l['who'].strip())})
        if bad:
            out.append(f'bad speaker names {bad} (1-2 capitalized words, no dots)')
    elif any(l['who'].strip() for l in s['lines']):
        out.append('a story line has a "who"')
    questions = s.get('questions') or []
    if len(questions) < 2 or any(q.get('type') not in ('mc', 'tf') or
                                 (q['type'] == 'mc' and not (0 <= q.get('answer', -1) < len(q.get('options') or []))) or
                                 (q['type'] == 'tf' and q.get('answer') not in (0, 1)) for q in questions):
        out.append('questions wrong')
    return out


def as_daily_text(s, level, unit_title):
    """DailyText shape (as in tools/stories.py): dialogue lines become "Name: text" paragraphs."""
    def line(l, key):
        return f"{l['who'].strip()}: {l[key]}" if l['who'].strip() else l[key]
    return {
        'id': 's-' + s['id'], 'level': level, 'topic': unit_title, 'title': s['title'],
        'paragraphs': [line(l, 'de') for l in s['lines']],
        'trans': [{'tr': line(l, 'tr'), 'en': line(l, 'en')} for l in s['lines']],
        'glossary': [{'form': g.get('form', ''), 'lemma': g.get('lemma') or g.get('form', ''), 'art': g.get('art') or None,
                      'pron': None, 'extra': None, 'mean': {'tr': g.get('tr', ''), 'en': g.get('en', '')}}
                     for g in s.get('glossary', []) if g.get('form')],
        'questions': [{'type': q['type'], 'q': q['q'], 'options': q.get('options'), 'answer': q['answer']}
                      for q in s['questions']],
    }


def import_answers(level):
    level = level.upper()
    level_units = units(level)
    order = {u['id']: i for i, u in enumerate(level_units)}
    path = out_path(level)
    stories = {s['id']: s for s in json.load(open(path, encoding='utf-8'))['stories']} if os.path.exists(path) else {}
    problems = []
    for answer in sorted(glob.glob(os.path.join(FOLDER, f'{level}_hikaye_cevap_*.txt'))):
        for n, raw in enumerate(open(answer, encoding='utf-8-sig'), 1):
            raw = raw.strip().strip(',')
            if not raw.startswith('{'):
                continue
            name = f'{os.path.basename(answer)}:{n}'
            try:
                s = json.loads(raw)
            except json.JSONDecodeError:
                problems.append(f'{name} not JSON')
                continue
            found = problems_of(s, order)
            if found:
                problems.append(f"{name} {s.get('id')}: " + '; '.join(found))
                continue
            stories[s['id']] = s
    ordered = sorted(stories.values(), key=lambda s: (order.get(s['unit'], 99), s['id']))
    titles = {u['id']: u['title']['tr'] for u in level_units}
    texts, per_unit = [], {}
    for s in ordered:
        text = as_daily_text(s, level, titles.get(s['unit'], ''))
        texts.append(text)
        per_unit.setdefault(s['unit'], []).append(text['id'])
    with open(path, 'w', encoding='utf-8', newline='\n') as f:
        json.dump({'stories': ordered, 'texts': texts, 'units': per_unit}, f, ensure_ascii=False, indent=1)
        f.write('\n')
    print(f'{level}: {len(ordered)} stories for {len(per_unit)}/{len(level_units)} units in {path}')
    for p in problems:
        print('  ', p)


def status():
    for level in STORY_LEVELS:
        path = out_path(level)
        have = {s['unit'] for s in json.load(open(path, encoding='utf-8'))['stories']} if os.path.exists(path) else set()
        print(f'{level}: {len(have)}/{len(units(level))} units')


STORY_LEVELS = ['A2']

if __name__ == '__main__':
    command = sys.argv[1] if len(sys.argv) > 1 else 'status'
    if command == 'export':
        export(sys.argv[2])
    elif command == 'import':
        import_answers(sys.argv[2])
    else:
        status()

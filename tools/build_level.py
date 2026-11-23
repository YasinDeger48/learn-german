"""Builds the raw (Turkish) content of a higher level, in the same shape as tools/data/a1_raw.json.

Sources (checked batches only):
    tools/levels/<level>/words_*.txt   type|word|plural or "er X · hat Y"|tr|example|example_tr
    tools/levels/<level>/grammar.txt   topic|sentence with ___|answer|wrong1;wrong2;wrong3|why (tr)|sentence (tr)

    python -I -X utf8 tools/build_level.py a2
    python -I -X utf8 tools/pack_content.py tools/data/a2_raw.json Resources/content/a2.json --prefix a2.
"""
import glob
import json
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
from pron import pron  # noqa: E402

THEMES = [
    {'id': 0, 'de': 'Nomen', 'tr': 'İsimler'},
    {'id': 1, 'de': 'Verben', 'tr': 'Fiiller'},
    {'id': 2, 'de': 'Adjektive und kleine Wörter', 'tr': 'Sıfatlar ve küçük kelimeler'},
]

# Topic name (Turkish) and the rule shown on the topic page.
TOPICS = {
    'Akkusativ': ('Akkusativ (-i hali)', 'der → den, ein → einen, kein → keinen, mein → meinen. die, das ve çoğul değişmez. Akkusativ isteyen fiiller: haben, brauchen, kaufen, sehen, besuchen, finden; edatlar: für, ohne, durch, gegen, um.'),
    'Dativ': ('Dativ (-e hali)', 'der/das → dem, die → der, çoğul → den + -n. Kime? sorusunun cevabı: Ich gebe dem Kind ein Buch. Dativ edatları: mit, bei, von, zu, aus, nach, seit. Dativ fiilleri: helfen, danken, gefallen, gehören, schmecken.'),
    'Wechselpräpositionen – Ort': ('İki yönlü edatlar: Nerede? (Dativ)', 'in, an, auf, unter, über, vor, hinter, neben, zwischen. Durum/yer bildirirken (wo?) Dativ: Das Buch liegt auf dem Tisch. Fiiller: liegen, stehen, sitzen, hängen.'),
    'Wechselpräpositionen – Richtung': ('İki yönlü edatlar: Nereye? (Akkusativ)', 'Aynı edatlar, yön bildirirken (wohin?) Akkusativ alır: Ich lege das Buch auf den Tisch. Fiiller: legen, stellen, setzen, hängen.'),
    'Perfekt': ('Perfekt (konuşmada geçmiş)', 'haben/sein + Partizip II (sonda). ge-…-t: gemacht · ge-…-en: gefahren · ayrılan: eingekauft · -ieren: telefoniert. Hareket/değişim fiilleri ve bleiben, passieren → sein.'),
    'Präteritum': ('Präteritum: war, hatte, modal fiiller', 'sein → war, haben → hatte, können → konnte, müssen → musste, wollen → wollte, dürfen → durfte. ich ve er aynıdır: ich war, er war. Konuşmada bu fiiller Perfekt yerine Präteritum ile kullanılır.'),
    'Nebensatz mit weil': ('Yan cümle: weil (çünkü)', 'weil yan cümle başlatır, çekimli fiil en sona gider: Ich bleibe zu Hause, weil ich krank bin. denn ile fark: denn sonrası fiil 2. sırada kalır.'),
    'Nebensatz mit dass': ('Yan cümle: dass (-dığı)', 'Ich weiß, dass … / Ich glaube, dass … / Es ist wichtig, dass … Çekimli fiil sona gider: Ich hoffe, dass du morgen kommst.'),
    'Nebensatz mit wenn/als': ('Yan cümle: wenn ve als', 'als: geçmişte bir kez olan olay (Als ich Kind war, …). wenn: şimdi/gelecek, koşul ve geçmişte tekrar eden olaylar (Wenn es regnet, …; Immer wenn …). Fiil sona gider.'),
    'Trennbare Verben': ('Ayrılabilen fiiller', 'Ana cümlede ön ek sona gider: Ich rufe dich an. Yan cümlede birleşik ve sonda: …, weil ich dich anrufe. Perfekt: an-ge-rufen. Modal fiille: Ich muss dich anrufen.'),
    'Reflexivpronomen': ('Dönüşlü zamirler', 'mich, dich, sich, uns, euch, sich: Ich freue mich. Du ärgerst dich. Dativ ile (nesne varsa): Ich wasche mir die Hände.'),
    'Modalverben – müssen': ('Kip fiilleri: müssen, nicht müssen', 'müssen = zorunda olmak; nicht müssen = gerek yok (nicht dürfen = yasak). ich muss, du musst, er muss. Asıl fiil mastar halinde sonda.'),
    'Komparativ/Superlativ': ('Karşılaştırma ve en üstünlük', 'Komparativ: -er (+ als): schneller als. Superlativ: am …sten / der …ste: am schnellsten. Düzensiz: gut – besser – am besten, viel – mehr – am meisten, gern – lieber – am liebsten. Tek heceli: alt → älter.'),
    'Adjektivdeklination': ('Sıfat çekimi', 'der/die/das sonrası: -e (der neue Mantel), Akkusativ eril ve Dativ/çoğul: -en. ein sonrası sıfat, artikelin göstermediği cinsiyeti gösterir: ein neuer Mantel, ein neues Auto, eine neue Jacke.'),
    'Imperativ': ('Emir kipi', 'du: Komm! Nimm! Fahr! · ihr: Kommt! · Sie: Kommen Sie! Ayrılan fiil: Ruf an! sein: Sei! Seid! Seien Sie! bitte cümleyi kibarlaştırır.'),
    'zu + Infinitiv': ('zu + mastar', 'Ich habe keine Zeit, … zu kommen. Es ist schwer, … zu lernen. Ich versuche, … zu schlafen. Ayrılan fiilde zu araya girer: anzurufen. Modal fiillerden sonra zu yok.'),
}


def main():
    level = sys.argv[1].lower()
    src = os.path.join(HERE, 'levels', level)
    words, seen, wid = [], set(), 1
    a1 = json.load(open(os.path.join(HERE, 'data', 'a1_raw.json'), encoding='utf-8'))
    a1_words = {w['de'].lower() for w in a1['words']}
    skipped_a1 = 0
    for path in sorted(glob.glob(os.path.join(src, 'words_*.txt'))):
        for n, line in enumerate(open(path, encoding='utf-8'), 1):
            if not line.strip():
                continue
            parts = [p.strip() for p in line.rstrip('\n').split('|')]
            assert len(parts) == 6, (path, n)
            typ, word, meta, tr, ex, ex_tr = parts
            if word.lower() in seen:
                continue
            if word.lower() in a1_words:
                skipped_a1 += 1
                continue
            seen.add(word.lower())
            theme = 0 if typ in ('der', 'die', 'das', 'pl') else (1 if typ == 'v' else 2)
            entry = {'id': wid, 'theme': theme, 'type': {'v': 'verb', 'w': 'word'}.get(typ, typ), 'de': word, 'tr': tr,
                     'ex': [{'de': ex, 'pron': pron(ex), 'tr': ex_tr}]}
            if typ in ('der', 'die', 'das'):
                entry['pron'] = pron(f'{typ} {word}')
                plural = meta[4:] if meta.startswith('die ') else meta
                entry['plural'] = None if plural in ('', '-') else plural
            elif typ == 'pl':
                entry['pron'] = pron(f'die {word}')
            else:
                entry['pron'] = pron(word)
            if typ == 'v' and ' · ' in meta:
                er, perfekt = meta.split(' · ', 1)
                entry['er'], entry['perfekt'] = er, perfekt
            words.append(entry)
            wid += 1

    grammar, items, ids = [], [], {}
    gpath = os.path.join(src, 'grammar.txt')
    for line in open(gpath, encoding='utf-8'):
        if not line.strip():
            continue
        topic, q, answer, wrong, why, q_tr = [p.strip() for p in line.rstrip('\n').split('|')]
        if topic not in ids:
            ids[topic] = len(ids) + 1
            name, rule = TOPICS.get(topic, (topic, ''))
            grammar.append({'id': ids[topic], 'de': topic, 'tr': name, 'rule': rule, 'examples': []})
        g = grammar[ids[topic] - 1]
        if len(g['examples']) < 3:
            g['examples'].append(f"{q.replace('___', answer)} – {q_tr}")
        items.append({'topic': ids[topic], 'q': q, 'options': [answer] + wrong.split(';'), 'why': f'{why} {q_tr}'})

    raw = {'themes': THEMES, 'words': words, 'texts': [], 'hoeren': [], 'grammar': grammar,
           'grammarItems': items, 'mistakes': [], 'situations': []}
    dest = os.path.join(HERE, 'data', f'{level}_raw.json')
    json.dump(raw, open(dest, 'w', encoding='utf-8', newline='\n'), ensure_ascii=False, separators=(',', ':'))
    print(f'{level}: {len(words)} words ({skipped_a1} already in A1), {len(grammar)} topics, {len(items)} grammar items')


if __name__ == '__main__':
    main()

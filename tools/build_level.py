"""Builds the raw (Turkish) content of a higher level, in the same shape as tools/data/a1_raw.json.

Sources (checked batches only):
    tools/levels/<level>/words_*.txt   type|word|plural or "er X · hat Y"|tr|example|example_tr
    tools/levels/<level>/grammar.txt   topic|sentence with ___|answer|wrong1;wrong2;wrong3|why (tr)|sentence (tr)

    python -I -X utf8 tools/build_level.py a2
    python -I -X utf8 tools/pack_content.py tools/data/a2_raw.json Resources/content/a2.json --prefix a2.
"""
import glob
import json
import re
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
    # B1
    'Konjunktiv II – Wünsche/Ratschläge': ('Konjunktiv II: dilek, rica, tavsiye', 'Kibar rica: Könnten Sie …? Würden Sie …? Dilek: Ich hätte gern … / Ich wäre gern … Tavsiye: Du solltest … / An deiner Stelle würde ich … Çekim: ich/er würde, hätte, wäre, könnte, sollte · du würdest, hättest, wärst · wir/sie/Sie würden, hätten, wären · ihr würdet, hättet, wärt.'),
    'Konjunktiv II – irreale Bedingung': ('Konjunktiv II: gerçek dışı koşul', 'Wenn ich Zeit hätte, würde ich kommen. (Zamanım yok.) Wenn-cümlesinde fiil sonda; wenn olmadan fiil başa gelir: Hätte ich Zeit, würde ich kommen. sein → wäre, haben → hätte, können → könnte, müssen → müsste; diğer fiiller çoğunlukla würde + mastar.'),
    'Passiv Präsens': ('Edilgen (şimdiki zaman)', 'werden + Partizip II: Das Paket wird heute geliefert. Yapan önemli değilse kullanılır; söylenecekse von + Dativ: Die Briefe werden von der Post gebracht. ich werde, du wirst, er wird, wir/sie werden.'),
    'Passiv Präteritum und Perfekt': ('Edilgen: geçmiş zaman', 'Präteritum: wurde + Partizip II: Das Haus wurde 1990 gebaut. Perfekt: ist + Partizip II + worden: Der Brief ist gestern verschickt worden. (geworden değil, worden!)'),
    'Passiv mit Modalverben': ('Kip fiilleriyle edilgen', 'Modalverb + Partizip II + werden (sonda): Der Antrag muss bis Freitag abgegeben werden. Das Fenster kann nicht geöffnet werden. Geçmiş: Der Antrag musste … abgegeben werden.'),
    'Relativsätze (der/die/das, Akk./Dat.)': ('İlgi cümleleri (der, die, das)', 'İlgi zamiri cinsiyet ve sayıyı isimden, hali yan cümledeki görevinden alır; fiil sonda. Nominativ: der/die/das/die · Akkusativ: den/die/das/die · Dativ: dem/der/dem/denen · Genitiv: dessen/deren. Der Mann, dem ich helfe, …'),
    'Relativsätze mit Präposition / wo / was': ('Edatlı ilgi cümleleri, wo ve was', 'Edat ilgi zamirinin önüne gelir: die Kollegin, mit der ich arbeite · das Thema, über das wir sprechen. Yer için wo: die Stadt, wo ich wohne. alles, etwas, nichts, das sonrası was: Alles, was du sagst, …'),
    'Präteritum (regelmäßig und unregelmäßig)': ('Präteritum (yazı dilinde geçmiş)', 'Düzenli: kök + -te: machte, wohnte, arbeitete. Düzensiz: ünlü değişir: gehen → ging, kommen → kam, sehen → sah, finden → fand. ich ve er/sie aynı, ek almaz: ich ging, er ging · du gingst, wir gingen.'),
    'Plusquamperfekt und nachdem': ('Plusquamperfekt ve nachdem', 'hatte/war + Partizip II: geçmişteki bir olaydan daha önce olan olay. Nachdem ich gegessen hatte, ging ich spazieren. nachdem-cümlesi Plusquamperfekt, ana cümle Präteritum (veya Perfekt).'),
    'Genitiv und Präpositionen (wegen, trotz, während, innerhalb)': ('Genitiv ve Genitiv edatları', 'des + -s/-es (eril, nötr), der (dişil, çoğul): das Auto des Nachbarn, die Tasche der Lehrerin. Genitiv edatları: wegen des Regens, trotz der Kälte, während des Kurses, innerhalb einer Woche, statt eines Briefes.'),
    'Zweiteilige Konnektoren': ('İki parçalı bağlaçlar', 'sowohl … als auch (hem … hem de) · weder … noch (ne … ne de) · entweder … oder (ya … ya da) · nicht nur … sondern auch (sadece … değil … de) · zwar … aber (gerçi … ama) · je … desto (ne kadar … o kadar): Je früher wir fahren, desto weniger Verkehr gibt es.'),
    'Nebensätze (obwohl, bevor, seitdem, bis, damit, falls, sodass)': ('Yan cümleler: obwohl, bevor, seitdem, bis, damit, falls, sodass', 'obwohl: -e rağmen · bevor: -den önce · seitdem: -den beri · bis: -e kadar · damit: -sın diye (amaç, iki farklı özne) · falls: eğer, olur da · sodass: böylece, o yüzden (sonuç). Çekimli fiil sona gider.'),
    'um … zu / ohne … zu / statt … zu': ('um … zu, ohne … zu, statt … zu', 'um … zu: amaç, özne aynı: Ich lerne, um die Prüfung zu bestehen. ohne … zu: -meden: Er ging, ohne zu grüßen. statt … zu: -mek yerine: Statt zu arbeiten, schläft er. Ayrılan fiilde zu araya girer: anzurufen.'),
    'Verben mit Präpositionen + da(r)-/wo(r)-': ('Edatlı fiiller, da(r)- ve wo(r)-', 'warten auf, sich freuen über/auf, denken an, sich kümmern um, sprechen über, Angst haben vor … Şey için: darauf, daran, darüber; soru: worauf? woran? worüber? Kişi için edat + zamir: auf ihn, mit ihr, an wen? Ünlüyle başlayan edatta -r- eklenir: dar-auf, wor-an.'),
    'Indirekte Fragen (ob, wann, warum …)': ('Dolaylı sorular', 'Evet/hayır sorusu → ob: Ich weiß nicht, ob er kommt. Soru kelimesi kalır: Können Sie mir sagen, wann der Zug fährt? Çekimli fiil sona gider.'),
    'lassen': ('lassen', 'Bir işi başkasına yaptırmak: Ich lasse mein Auto reparieren. İzin vermek: Lass mich bitte ausreden! Bırakmak: Ich habe den Schirm im Bus gelassen. ich lasse, du lässt, er lässt · Präteritum ließ.'),
    'n-Deklination': ('n-çekimi', 'Bazı eril isimler Nominativ dışında -(e)n alır: der Kunde → den/dem/des Kunden, der Kollege, der Nachbar, der Student, der Mensch, der Junge, der Herr (dem Herrn). Ich helfe dem Nachbarn.'),
    'Futur I': ('Futur I (gelecek zaman)', 'werden + mastar (sonda): Ich werde morgen anrufen. Tahmin için de kullanılır: Er wird wohl krank sein. Günlük konuşmada çoğu zaman şimdiki zaman + zaman zarfı yeterli: Morgen rufe ich an.'),
    'Adjektivdeklination nach Artikel und ohne Artikel': ('Sıfat çekimi: artikelli ve artikelsiz', 'der/die/das sonrası çoğunlukla -e/-en; ein/kein/mein sonrası sıfat cinsiyeti gösterir: ein neuer Tisch, ein neues Bett. Artikelsiz sıfat artikelin ekini alır: frischer Kaffee, mit frischem Brot, kalte Milch, frische Eier.'),
    'Reflexive Verben mit Dativ': ('Dativ ile dönüşlü fiiller', 'Cümlede ayrıca bir nesne varsa dönüşlü zamir Dativ olur: Ich wasche mir die Hände. Ich merke mir die Nummer. Ich stelle mir das vor. Du kaufst dir ein Buch. mir/dir sadece ich ve du için farklıdır; diğerleri: sich, uns, euch, sich.'),
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
    seen_items = set()
    glines = []
    for gpath in sorted(glob.glob(os.path.join(src, 'grammar*.txt'))):  # grammar.txt or grammar_01.txt, grammar_02.txt …
        glines += open(gpath, encoding='utf-8').readlines()
    for line in glines:
        if not line.strip():
            continue
        topic, q, answer, wrong, why, q_tr = [p.strip() for p in line.rstrip('\n').split('|')]
        if topic not in TOPICS and topic.split(' (')[0] in TOPICS:  # "Zweiteilige Konnektoren (sowohl …)" → known name
            topic = topic.split(' (')[0]
        # Some sentences came wrapped in a frame ("Im Chat steht: „…“"): keep only the sentence itself.
        m = re.match(r'^.{3,60}?: „(.*)“$', q)
        if m:
            q = m.group(1)
            mt = re.match(r'^.{3,60}?: [“"](.*)[”"]$', q_tr)
            q_tr = mt.group(1) if mt else q_tr
        if (q, answer) in seen_items:
            continue
        seen_items.add((q, answer))
        if topic not in ids:
            ids[topic] = len(ids) + 1
            name, rule = TOPICS.get(topic, (topic, ''))
            grammar.append({'id': ids[topic], 'de': topic, 'tr': name, 'rule': rule, 'examples': []})
        items.append({'topic': ids[topic], 'q': q, 'options': [answer] + wrong.split(';'), 'why': f'{why} {q_tr}', 'tr': q_tr})

    # Three examples per topic, spread over the topic and from different sentence frames.
    for g in grammar:
        mine = [it for it in items if it['topic'] == g['id']]
        picked, frames = [], set()
        for idx in [0, len(mine) // 3, 2 * len(mine) // 3] + list(range(len(mine))):
            it = mine[idx]
            frame = ' '.join(it['q'].split()[:2])
            if frame in frames or it in picked:
                continue
            frames.add(frame)
            picked.append(it)
            if len(picked) == 3:
                break
        g['examples'] = [f"{it['q'].replace('___', it['options'][0])} – {it['tr']}" for it in picked]
        for it in mine:
            del it['tr']

    raw = {'themes': THEMES, 'words': words, 'texts': [], 'hoeren': [], 'grammar': grammar,
           'grammarItems': items, 'mistakes': [], 'situations': []}
    dest = os.path.join(HERE, 'data', f'{level}_raw.json')
    json.dump(raw, open(dest, 'w', encoding='utf-8', newline='\n'), ensure_ascii=False, separators=(',', ':'))
    print(f'{level}: {len(words)} words ({skipped_a1} already in A1), {len(grammar)} topics, {len(items)} grammar items')


if __name__ == '__main__':
    main()

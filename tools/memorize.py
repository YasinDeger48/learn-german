"""Builds Resources/content/memorize.json: the "must know by heart" sheets (Mutlaka bil) with a drill each.

    python -I -X utf8 tools/memorize.py              rebuilds the file (drops content translations: re-apply them)
    python -I -X utf8 tools/memorize.py meanings     only adds the example meanings (xm) to the existing file

A sheet has rows q → a (q may be {"tr","en"} or plain German) and an optional example x. The drill asks
`ask` with {q} filled in and offers the sheet's other answers as wrong options. kind "rules" sheets are
read-only (no drill).
"""
import json
import os

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(REPO, 'Resources', 'content', 'memorize.json')

P6 = ['ich', 'du', 'er/sie/es', 'wir', 'ihr', 'sie/Sie']


def sheet(id, level, icon, title, intro, ask, rows, kind='drill'):
    return {'id': id, 'level': level, 'icon': icon, 'kind': kind, 'title': {'tr': title[0], 'en': title[1]},
            'intro': {'tr': intro[0], 'en': intro[1]}, 'ask': ask, 'rows': rows}


def row(q, a, x=None):
    r = {'q': q, 'a': a}
    if x:
        r['x'] = x
        if x in EXAMPLE_MEANINGS:
            r['xm'] = tr(*EXAMPLE_MEANINGS[x])
    return r


# The meaning of every example x (shown under it in the learner's language; es/fr/it/ku/ar come from the content
# translations, tools/translate.py).
EXAMPLE_MEANINGS = {
    'Ich bin müde.': ('Yorgunum.', 'I am tired.'),
    'Bist du zu Hause?': ('Evde misin?', 'Are you at home?'),
    'Er ist Lehrer.': ('O öğretmen.', 'He is a teacher.'),
    'Wir sind aus der Türkei.': ('Türkiyeliyiz.', 'We are from Turkey.'),
    'Ihr seid nett.': ('Siz çok naziksiniz.', 'You are nice.'),
    'Sind Sie Frau Kaya?': ('Siz Kaya Hanım mısınız?', 'Are you Ms Kaya?'),
    'Ich habe Hunger.': ('Acıktım.', 'I am hungry.'),
    'Hast du Zeit?': ('Vaktin var mı?', 'Do you have time?'),
    'Sie hat zwei Kinder.': ('Onun iki çocuğu var.', 'She has two children.'),
    'Wir haben ein Auto.': ('Bir arabamız var.', 'We have a car.'),
    'Habt ihr Fragen?': ('Sorunuz var mı?', 'Do you have questions?'),
    'Haben Sie Wasser?': ('Suyunuz var mı?', 'Do you have water?'),
    'Ich kann schwimmen.': ('Yüzebilirim.', 'I can swim.'),
    'Ich muss arbeiten.': ('Çalışmam lazım.', 'I have to work.'),
    'Ich will nach Hause.': ('Eve gitmek istiyorum.', 'I want to go home.'),
    'Ich möchte einen Kaffee.': ('Bir kahve istiyorum.', 'I would like a coffee.'),
    'Darf ich fragen?': ('Sorabilir miyim?', 'May I ask?'),
    'Der Mann ist hier.': ('Adam burada.', 'The man is here.'),
    'Ich sehe den Mann.': ('Adamı görüyorum.', 'I see the man.'),
    'Ich helfe dem Mann.': ('Adama yardım ediyorum.', 'I help the man.'),
    'Die Frau ist hier.': ('Kadın burada.', 'The woman is here.'),
    'Ich sehe die Frau.': ('Kadını görüyorum.', 'I see the woman.'),
    'Ich helfe der Frau.': ('Kadına yardım ediyorum.', 'I help the woman.'),
    'Das Kind ist hier.': ('Çocuk burada.', 'The child is here.'),
    'Ich sehe das Kind.': ('Çocuğu görüyorum.', 'I see the child.'),
    'Ich helfe dem Kind.': ('Çocuğa yardım ediyorum.', 'I help the child.'),
    'Die Kinder sind hier.': ('Çocuklar burada.', 'The children are here.'),
    'Ich sehe die Kinder.': ('Çocukları görüyorum.', 'I see the children.'),
    'Ich helfe den Kindern.': ('Çocuklara yardım ediyorum.', 'I help the children.'),
    'Das ist ein Tisch.': ('Bu bir masa.', 'This is a table.'),
    'Ich habe einen Bruder.': ('Bir erkek kardeşim var.', 'I have a brother.'),
    'mit einem Freund': ('bir arkadaşla (erkek)', 'with a friend (male)'),
    'Das ist eine Lampe.': ('Bu bir lamba.', 'This is a lamp.'),
    'Ich kaufe eine Jacke.': ('Bir ceket alıyorum.', 'I am buying a jacket.'),
    'mit einer Freundin': ('bir arkadaşla (kadın)', 'with a friend (female)'),
    'Das ist ein Haus.': ('Bu bir ev.', 'This is a house.'),
    'Ich habe ein Auto.': ('Bir arabam var.', 'I have a car.'),
    'Ich habe keine Kinder.': ('Çocuğum yok.', 'I have no children.'),
    'Ich habe keinen Hunger.': ('Aç değilim.', 'I am not hungry.'),
    'mein Vater': ('babam', 'my father'),
    'dein Handy': ('senin telefonun', 'your phone'),
    'sein Auto': ('onun arabası (erkek)', 'his car'),
    'ihr Bruder': ('onun erkek kardeşi (kadın)', 'her brother'),
    'sein Spielzeug': ('onun oyuncağı (çocuk)', 'its toy'),
    'unser Haus': ('bizim evimiz', 'our house'),
    'euer Garten': ('sizin bahçeniz', 'your garden (you all)'),
    'ihr Hund': ('onların köpeği', 'their dog'),
    'Ihr Pass': ('sizin pasaportunuz (resmî)', 'your passport (formal)'),
    'aus der Türkei': ('Türkiye\'den', 'from Turkey'),
    'beim Arzt': ('doktorda', 'at the doctor\'s'),
    'mit dem Bus': ('otobüsle', 'by bus'),
    'nach der Arbeit': ('işten sonra', 'after work'),
    'seit einem Jahr': ('bir yıldır', 'for a year'),
    'vom Bahnhof': ('istasyondan', 'from the station'),
    'zum Supermarkt': ('süpermarkete', 'to the supermarket'),
    'durch den Park': ('parkın içinden', 'through the park'),
    'für dich': ('senin için', 'for you'),
    'gegen den Baum': ('ağaca (çarpmak)', 'against the tree'),
    'ohne Zucker': ('şekersiz', 'without sugar'),
    'um den Tisch': ('masanın etrafında', 'around the table'),
    'im Kino / ins Kino': ('sinemada / sinemaya', 'at the cinema / to the cinema'),
    'am Fenster / ans Fenster': ('pencerede / pencereye', 'at the window / to the window'),
    'auf dem Tisch / auf den Tisch': ('masanın üstünde / masanın üstüne', 'on the table / onto the table'),
    'neben dem Bett': ('yatağın yanında', 'next to the bed'),
    'unter dem Stuhl': ('sandalyenin altında', 'under the chair'),
    'über dem Sofa': ('kanepenin üstünde (yukarıda)', 'above the sofa'),
    'vor dem Haus': ('evin önünde', 'in front of the house'),
    'hinter der Tür': ('kapının arkasında', 'behind the door'),
    'zwischen den Häusern': ('evlerin arasında', 'between the houses'),
    'Wer ist das?': ('Bu kim?', 'Who is that?'),
    'Was machst du?': ('Ne yapıyorsun?', 'What are you doing?'),
    'Wo wohnst du?': ('Nerede oturuyorsun?', 'Where do you live?'),
    'Wohin fährst du?': ('Nereye gidiyorsun?', 'Where are you going?'),
    'Woher kommst du?': ('Nerelisin?', 'Where are you from?'),
    'Wann beginnt der Kurs?': ('Kurs ne zaman başlıyor?', 'When does the course start?'),
    'Wie heißt du?': ('Adın ne?', 'What is your name?'),
    'Warum lernst du Deutsch?': ('Neden Almanca öğreniyorsun?', 'Why are you learning German?'),
    'Wie viele Kinder hast du?': ('Kaç çocuğun var?', 'How many children do you have?'),
    'Wie viel kostet das?': ('Bu ne kadar?', 'How much is it?'),
    'Welche Farbe magst du?': ('Hangi rengi seversin?', 'Which colour do you like?'),
    'Wen besuchst du?': ('Kimi ziyaret ediyorsun?', 'Whom are you visiting?'),
    'Wem gehört das?': ('Bu kimin?', 'Whose is this?'),
}


def add_meanings(path):
    """Puts the meanings into the existing memorize.json without rebuilding it (keeps the content translations)."""
    data = json.load(open(path, encoding='utf-8'))
    added = 0
    for s in data['sheets']:
        for r in s['rows']:
            x = r.get('x')
            if x in EXAMPLE_MEANINGS:
                old = r.get('xm') or {}
                r['xm'] = {**old, **tr(*EXAMPLE_MEANINGS[x])}
                added += 1
    with open(path, 'w', encoding='utf-8', newline='\n') as f:
        json.dump(data, f, ensure_ascii=False, indent=1)
        f.write('\n')
    missing = sorted({r['x'] for s in data['sheets'] for r in s['rows'] if r.get('x') and r['x'] not in EXAMPLE_MEANINGS})
    print(f'{added} example meanings in {path}; without a meaning: {missing}')


def conj(verb, forms, examples=()):
    return [row(f'{verb} · {p}', f, examples[i] if i < len(examples) else None) for i, (p, f) in enumerate(zip(P6, forms))]


def tr(t, e):
    return {'tr': t, 'en': e}


IRREGULAR = [
    ('fahren', 'er fährt', 'ist gefahren'), ('essen', 'er isst', 'hat gegessen'), ('sprechen', 'er spricht', 'hat gesprochen'),
    ('sehen', 'er sieht', 'hat gesehen'), ('lesen', 'er liest', 'hat gelesen'), ('nehmen', 'er nimmt', 'hat genommen'),
    ('geben', 'er gibt', 'hat gegeben'), ('schlafen', 'er schläft', 'hat geschlafen'), ('laufen', 'er läuft', 'ist gelaufen'),
    ('helfen', 'er hilft', 'hat geholfen'), ('treffen', 'er trifft', 'hat getroffen'), ('vergessen', 'er vergisst', 'hat vergessen'),
    ('wissen', 'er weiß', 'hat gewusst'), ('gefallen', 'es gefällt', 'hat gefallen'), ('tragen', 'er trägt', 'hat getragen'),
    ('waschen', 'er wäscht', 'hat gewaschen'), ('halten', 'er hält', 'hat gehalten'), ('werden', 'er wird', 'ist geworden'),
    ('kommen', 'er kommt', 'ist gekommen'), ('gehen', 'er geht', 'ist gegangen'), ('bleiben', 'er bleibt', 'ist geblieben'),
    ('trinken', 'er trinkt', 'hat getrunken'), ('finden', 'er findet', 'hat gefunden'), ('schreiben', 'er schreibt', 'hat geschrieben'),
]

SHEETS = [
    sheet('sein', 'A1', 'person.fill', ('sein (olmak)', 'sein (to be)'),
          ('En önemli fiil; düzensizdir, mutlaka ezberle.', 'The most important verb; irregular, learn it by heart.'),
          'sein: {q} ___',
          conj('sein', ['bin', 'bist', 'ist', 'sind', 'seid', 'sind'],
               ['Ich bin müde.', 'Bist du zu Hause?', 'Er ist Lehrer.', 'Wir sind aus der Türkei.', 'Ihr seid nett.', 'Sind Sie Frau Kaya?'])),
    sheet('haben', 'A1', 'hand.raised.fill', ('haben (sahip olmak)', 'haben (to have)'),
          ('Perfekt için de gerekir (hat gemacht).', 'Also needed for the Perfekt (hat gemacht).'),
          'haben: {q} ___',
          conj('haben', ['habe', 'hast', 'hat', 'haben', 'habt', 'haben'],
               ['Ich habe Hunger.', 'Hast du Zeit?', 'Sie hat zwei Kinder.', 'Wir haben ein Auto.', 'Habt ihr Fragen?', 'Haben Sie Wasser?'])),
    sheet('modal', 'A1', 'slider.horizontal.3', ('Modal fiiller', 'Modal verbs'),
          ('ich ve er aynı: ich kann, er kann. İkinci fiil cümle sonuna gider.',
           'ich and er are the same: ich kann, er kann. The second verb goes to the end.'),
          '{q} ___',
          conj('können', ['kann', 'kannst', 'kann', 'können', 'könnt', 'können'], ['Ich kann schwimmen.'])
          + conj('müssen', ['muss', 'musst', 'muss', 'müssen', 'müsst', 'müssen'], ['Ich muss arbeiten.'])
          + conj('wollen', ['will', 'willst', 'will', 'wollen', 'wollt', 'wollen'], ['Ich will nach Hause.'])
          + conj('möchten', ['möchte', 'möchtest', 'möchte', 'möchten', 'möchtet', 'möchten'], ['Ich möchte einen Kaffee.'])
          + conj('dürfen', ['darf', 'darfst', 'darf', 'dürfen', 'dürft', 'dürfen'], ['Darf ich fragen?'])),
    sheet('irregular', 'A1', 'exclamationmark.triangle.fill', ('Düzensiz fiiller', 'Irregular verbs'),
          ('er-biçimi ve Perfekt birlikte ezberlenir.', 'Learn the er-form and the Perfekt together.'),
          '{q}: er … / Perfekt?',
          [row(v, f'{er} · {pf}') for v, er, pf in IRREGULAR]),
    sheet('articles', 'A1', 'textformat', ('Artikel tablosu (der/die/das)', 'Article table (der/die/das)'),
          ('Akkusativ\'te sadece eril değişir (der → den). Dativ: dem, der, dem, den.',
           'In the Akkusativ only the masculine changes (der → den). Dativ: dem, der, dem, den.'),
          '{q}: ?',
          [row('maskulin · Nominativ', 'der', 'Der Mann ist hier.'), row('maskulin · Akkusativ', 'den', 'Ich sehe den Mann.'),
           row('maskulin · Dativ', 'dem', 'Ich helfe dem Mann.'), row('feminin · Nominativ', 'die', 'Die Frau ist hier.'),
           row('feminin · Akkusativ', 'die', 'Ich sehe die Frau.'), row('feminin · Dativ', 'der', 'Ich helfe der Frau.'),
           row('neutral · Nominativ', 'das', 'Das Kind ist hier.'), row('neutral · Akkusativ', 'das', 'Ich sehe das Kind.'),
           row('neutral · Dativ', 'dem', 'Ich helfe dem Kind.'), row('Plural · Nominativ', 'die', 'Die Kinder sind hier.'),
           row('Plural · Akkusativ', 'die', 'Ich sehe die Kinder.'), row('Plural · Dativ', 'den', 'Ich helfe den Kindern.')]),
    sheet('ein', 'A1', 'textformat.abc', ('ein / kein', 'ein / kein'),
          ('kein, ein gibi çekilir; çoğulu da vardır: keine.', 'kein works like ein and also has a plural: keine.'),
          '{q}: ?',
          [row('maskulin · Nominativ', 'ein', 'Das ist ein Tisch.'), row('maskulin · Akkusativ', 'einen', 'Ich habe einen Bruder.'),
           row('maskulin · Dativ', 'einem', 'mit einem Freund'), row('feminin · Nominativ', 'eine', 'Das ist eine Lampe.'),
           row('feminin · Akkusativ', 'eine', 'Ich kaufe eine Jacke.'), row('feminin · Dativ', 'einer', 'mit einer Freundin'),
           row('neutral · Nominativ', 'ein', 'Das ist ein Haus.'), row('neutral · Akkusativ', 'ein', 'Ich habe ein Auto.'),
           row('Plural · Akkusativ (kein)', 'keine', 'Ich habe keine Kinder.'), row('maskulin · Akkusativ (kein)', 'keinen', 'Ich habe keinen Hunger.')]),
    sheet('pronouns', 'A1', 'person.2.fill', ('Şahıs zamirleri', 'Personal pronouns'),
          ('Nominativ → Akkusativ → Dativ: ich → mich → mir.', 'Nominativ → Akkusativ → Dativ: ich → mich → mir.'),
          '{q}: ?',
          [row(f'{p} · Akkusativ', a) for p, a in [('ich', 'mich'), ('du', 'dich'), ('er', 'ihn'), ('sie', 'sie'), ('es', 'es'),
                                                    ('wir', 'uns'), ('ihr', 'euch'), ('Sie', 'Sie')]]
          + [row(f'{p} · Dativ', d) for p, d in [('ich', 'mir'), ('du', 'dir'), ('er', 'ihm'), ('sie', 'ihr'), ('es', 'ihm'),
                                                  ('wir', 'uns'), ('ihr', 'euch'), ('sie (Plural)', 'ihnen'), ('Sie', 'Ihnen')]]),
    sheet('possessive', 'A1', 'key.fill', ('İyelik (mein, dein …)', 'Possessives (mein, dein …)'),
          ('Dişil ve çoğulda -e: meine Mutter, meine Eltern.', 'Feminine and plural add -e: meine Mutter, meine Eltern.'),
          '{q} → ?',
          [row(p, a, x) for p, a, x in [('ich', 'mein', 'mein Vater'), ('du', 'dein', 'dein Handy'), ('er', 'sein', 'sein Auto'),
                                         ('sie', 'ihr', 'ihr Bruder'), ('es', 'sein', 'sein Spielzeug'), ('wir', 'unser', 'unser Haus'),
                                         ('ihr', 'euer', 'euer Garten'), ('sie (Plural)', 'ihr', 'ihr Hund'), ('Sie', 'Ihr', 'Ihr Pass')]]),
    sheet('prepositions', 'A1', 'arrow.triangle.branch', ('Edatlar: hangi hal?', 'Prepositions: which case?'),
          ('Dativ: aus, bei, mit, nach, seit, von, zu. Akkusativ: durch, für, gegen, ohne, um. İkili: Wo? Dativ / Wohin? Akkusativ.',
           'Dativ: aus, bei, mit, nach, seit, von, zu. Akkusativ: durch, für, gegen, ohne, um. Two-way: Wo? Dativ / Wohin? Akkusativ.'),
          '{q} + ?',
          [row(p, 'Dativ', x) for p, x in [('aus', 'aus der Türkei'), ('bei', 'beim Arzt'), ('mit', 'mit dem Bus'), ('nach', 'nach der Arbeit'),
                                           ('seit', 'seit einem Jahr'), ('von', 'vom Bahnhof'), ('zu', 'zum Supermarkt')]]
          + [row(p, 'Akkusativ', x) for p, x in [('durch', 'durch den Park'), ('für', 'für dich'), ('gegen', 'gegen den Baum'),
                                                ('ohne', 'ohne Zucker'), ('um', 'um den Tisch')]]
          + [row(p, 'Wo? Dativ · Wohin? Akkusativ', x) for p, x in [('in', 'im Kino / ins Kino'), ('an', 'am Fenster / ans Fenster'),
                                                                     ('auf', 'auf dem Tisch / auf den Tisch'), ('neben', 'neben dem Bett'),
                                                                     ('unter', 'unter dem Stuhl'), ('über', 'über dem Sofa'),
                                                                     ('vor', 'vor dem Haus'), ('hinter', 'hinter der Tür'),
                                                                     ('zwischen', 'zwischen den Häusern')]]),
    sheet('questions', 'A1', 'questionmark.circle.fill', ('Soru kelimeleri', 'Question words'),
          ('W-sorularında fiil ikinci sırada: Wo wohnst du?', 'In W-questions the verb comes second: Wo wohnst du?'),
          '{q}',
          [row(tr(t, e), a, x) for t, e, a, x in [
              ('Kim?', 'Who?', 'Wer?', 'Wer ist das?'), ('Ne?', 'What?', 'Was?', 'Was machst du?'), ('Nerede?', 'Where?', 'Wo?', 'Wo wohnst du?'),
              ('Nereye?', 'Where to?', 'Wohin?', 'Wohin fährst du?'), ('Nereden?', 'Where from?', 'Woher?', 'Woher kommst du?'),
              ('Ne zaman?', 'When?', 'Wann?', 'Wann beginnt der Kurs?'), ('Nasıl?', 'How?', 'Wie?', 'Wie heißt du?'),
              ('Neden?', 'Why?', 'Warum?', 'Warum lernst du Deutsch?'), ('Kaç tane?', 'How many?', 'Wie viele?', 'Wie viele Kinder hast du?'),
              ('Ne kadar?', 'How much?', 'Wie viel?', 'Wie viel kostet das?'), ('Hangi?', 'Which?', 'Welcher / Welche / Welches?', 'Welche Farbe magst du?'),
              ('Kimi?', 'Whom?', 'Wen?', 'Wen besuchst du?'), ('Kime?', 'To whom?', 'Wem?', 'Wem gehört das?')]]),
    sheet('days', 'A1', 'calendar', ('Günler ve aylar', 'Days and months'),
          ('Günlerde "am", aylarda "im": am Montag, im Mai.', 'Days take "am", months "im": am Montag, im Mai.'),
          '{q}',
          [row(tr(t, e), a) for t, e, a in [
              ('Pazartesi', 'Monday', 'Montag'), ('Salı', 'Tuesday', 'Dienstag'), ('Çarşamba', 'Wednesday', 'Mittwoch'),
              ('Perşembe', 'Thursday', 'Donnerstag'), ('Cuma', 'Friday', 'Freitag'), ('Cumartesi', 'Saturday', 'Samstag'),
              ('Pazar', 'Sunday', 'Sonntag'), ('Ocak', 'January', 'Januar'), ('Şubat', 'February', 'Februar'), ('Mart', 'March', 'März'),
              ('Nisan', 'April', 'April'), ('Mayıs', 'May', 'Mai'), ('Haziran', 'June', 'Juni'), ('Temmuz', 'July', 'Juli'),
              ('Ağustos', 'August', 'August'), ('Eylül', 'September', 'September'), ('Ekim', 'October', 'Oktober'),
              ('Kasım', 'November', 'November'), ('Aralık', 'December', 'Dezember')]]),
    sheet('time', 'A1', 'clock.fill', ('Saat söyleme', 'Telling the time'),
          ('"halb neun" = 8:30 (dokuza yarım var)! Resmî: acht Uhr dreißig.', '"halb neun" = 8:30 (half to nine)! Formal: acht Uhr dreißig.'),
          '{q} → ?',
          [row(q, a) for q, a in [('8:00', 'acht Uhr'), ('8:15', 'Viertel nach acht'), ('8:30', 'halb neun'), ('8:45', 'Viertel vor neun'),
                                  ('8:10', 'zehn nach acht'), ('8:50', 'zehn vor neun'), ('8:25', 'fünf vor halb neun'),
                                  ('8:35', 'fünf nach halb neun'), ('12:00', 'zwölf Uhr / Mittag'), ('0:00', 'Mitternacht')]]),
    sheet('numbers', 'A1', 'number', ('Sayılar (tuzaklı olanlar)', 'Numbers (the tricky ones)'),
          ('Birler önce okunur: 21 = einundzwanzig (bir-ve-yirmi).', 'Units come first: 21 = einundzwanzig (one-and-twenty).'),
          '{q} = ?',
          [row(q, a) for q, a in [('13', 'dreizehn'), ('16', 'sechzehn'), ('17', 'siebzehn'), ('20', 'zwanzig'), ('21', 'einundzwanzig'),
                                  ('30', 'dreißig'), ('45', 'fünfundvierzig'), ('67', 'siebenundsechzig'), ('99', 'neunundneunzig'),
                                  ('100', 'hundert'), ('101', 'hunderteins'), ('1000', 'tausend'), ('2026', 'zweitausendsechsundzwanzig')]]),
    sheet('survival', 'A1', 'lifepreserver.fill', ('Kurtarıcı cümleler', 'Survival phrases'),
          ('İlk gün işine yarayacak cümleler.', 'Phrases you will need on day one.'),
          '{q}',
          [row(tr(t, e), a) for t, e, a in [
              ('Anlamadım.', "I don't understand.", 'Ich verstehe das nicht.'),
              ('Tekrar eder misiniz?', 'Can you repeat that?', 'Können Sie das bitte wiederholen?'),
              ('Daha yavaş konuşur musunuz?', 'Can you speak more slowly?', 'Können Sie bitte langsamer sprechen?'),
              ('Bu Almancada ne demek?', 'What is that in German?', 'Was heißt das auf Deutsch?'),
              ('Nasıl yazılır?', 'How do you spell it?', 'Wie schreibt man das?'),
              ('Affedersiniz!', 'Excuse me!', 'Entschuldigung!'),
              ('Rica ederim.', "You're welcome.", 'Gern geschehen.'),
              ('Bu ne kadar?', 'How much is it?', 'Wie viel kostet das?'),
              ('Tuvalet nerede?', 'Where is the toilet?', 'Wo ist die Toilette?'),
              ('Bilmiyorum.', "I don't know.", 'Ich weiß es nicht.'),
              ('Bana yardım edebilir misiniz?', 'Can you help me?', 'Können Sie mir helfen?'),
              ('Biraz Almanca konuşuyorum.', 'I speak a little German.', 'Ich spreche ein bisschen Deutsch.')]]),
    sheet('email', 'A1', 'envelope.fill', ('E-posta kalıbı', 'E-mail pattern'),
          ('Kısa mesaj hep aynı sırayla yazılır. Arkadaşa du, öğretmene / otele Sie.',
           'A short message always has the same order. du to friends, Sie to a teacher or a hotel.'),
          '{q}',
          [row(tr(t, e), a) for t, e, a in [
              ('1. Hitap (samimi)', '1. Greeting (informal)', 'Liebe Sara, / Lieber Tom, / Hallo Murat,'),
              ('1. Hitap (resmî)', '1. Greeting (formal)', 'Sehr geehrte Frau Weber, / Sehr geehrter Herr Braun,'),
              ('2. Giriş', '2. Opening', 'wie geht es dir? / ich schreibe Ihnen, weil …'),
              ('3. Konu', '3. The reason', 'Leider kann ich morgen nicht kommen.'),
              ('4. Rica / soru', '4. Request / question', 'Kannst du …? / Können Sie bitte …?'),
              ('5. Zaman ve yer', '5. Time and place', 'am Samstag um 19 Uhr bei mir zu Hause'),
              ('6. Kapanış', '6. Closing', 'Ich freue mich auf dich! / Ich freue mich auf Ihre Antwort.'),
              ('7. Selam (samimi)', '7. Sign-off (informal)', 'Viele Grüße / Liebe Grüße, Elif'),
              ('7. Selam (resmî)', '7. Sign-off (formal)', 'Mit freundlichen Grüßen, Elif Yılmaz'),
              ('Dikkat', 'Watch out', 'Hitaptan sonra virgül, ilk kelime küçük harfle: "Liebe Sara, wie geht es dir?"')]],
          kind='rules'),
    sheet('wordorder', 'A1', 'list.number', ('Cümle kuralları', 'Word order rules'),
          ('Bu kuralları bilen cümlelerin çoğunu doğru kurar.', 'Know these and most of your sentences will be right.'),
          '{q}',
          [row(tr(t, e), a) for t, e, a in [
              ('Fiil hep 2. sırada', 'The verb is always second', 'Heute gehe ich ins Kino.'),
              ('Evet/hayır sorusunda fiil başta', 'Yes/no question: verb first', 'Kommst du mit?'),
              ('Modal fiil: ikinci fiil sonda', 'Modal verb: the other verb at the end', 'Ich kann sehr gut schwimmen.'),
              ('Ayrılabilen fiil: ön ek sonda', 'Separable verb: prefix at the end', 'Ich stehe um sieben Uhr auf.'),
              ('Perfekt: Partizip sonda', 'Perfekt: participle at the end', 'Ich habe gestern Pizza gegessen.'),
              ('weil / dass / wenn: fiil sonda', 'weil / dass / wenn: verb at the end', 'Ich bleibe zu Hause, weil ich krank bin.'),
              ('nicht → fiil/sıfat, kein → isim', 'nicht → verb/adjective, kein → noun', 'Ich komme nicht. Ich habe kein Auto.'),
              ('Zaman – sebep – nasıl – yer', 'Time – reason – manner – place', 'Ich fahre morgen wegen der Arbeit mit dem Zug nach Berlin.')]],
          kind='rules'),
]


def main():
    import sys
    if 'meanings' in sys.argv:
        add_meanings(OUT)
        return
    ids = [s['id'] for s in SHEETS]
    assert len(ids) == len(set(ids))
    with open(OUT, 'w', encoding='utf-8', newline='\n') as f:
        json.dump({'sheets': SHEETS}, f, ensure_ascii=False, indent=1)
        f.write('\n')
    print(f'{len(SHEETS)} sheets, {sum(len(s["rows"]) for s in SHEETS)} rows -> {OUT}')
    sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
    import content_edits  # hand edits made in Deschly Studio survive the rewrite
    content_edits.apply_all(quiet=True)


if __name__ == '__main__':
    main()

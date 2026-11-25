"""Builds Resources/content/writing.json: Schreiben tasks like the Goethe A1 exam.

    python -I -X utf8 tools/writing.py

kind "form"    (Teil 1): read a short text, fill in a form; each field has the accepted answers.
kind "message" (Teil 2): write a short message (about 30 words) on three points; the app checks the points
                         (phrases matched like in speaking), a greeting, a closing and the length, then shows the sample.
"""
import json
import os

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(REPO, 'Resources', 'content', 'writing.json')


def field(label, *answers):
    return {'label': label, 'answers': list(answers)}


def form(id, title, text, fields):
    return {'id': id, 'level': 'A1', 'kind': 'form', 'title': {'tr': title[0], 'en': title[1]}, 'text': text, 'fields': fields}


def point(tr, en, say, *keys):
    return {'label': {'tr': tr, 'en': en}, 'say': say, 'keys': list(keys)}


def message(id, title, prompt, help, points, sample, min_words=25):
    # Formal (Sie) when writing to a teacher, a caretaker, a hotel …; informal (du) to friends and family.
    formal = any(w in prompt for w in ('Frau', 'Herr', 'Hotel', 'Hausmeister'))
    return {'id': id, 'level': 'A1', 'kind': 'message', 'title': {'tr': title[0], 'en': title[1]}, 'prompt': prompt,
            'help': {'tr': help[0], 'en': help[1]}, 'points': points, 'minWords': min_words, 'sample': sample,
            'formal': formal}


TASKS = [
    form('a1-f1', ('Form: Dil kursu kaydı', 'Form: language course'),
         'Maria López kommt aus Spanien. Sie ist 34 Jahre alt und wohnt in der Gartenstraße 5 in 80331 München. '
         'Sie möchte einen Deutschkurs am Abend machen, weil sie am Tag arbeitet. Sie bezahlt bar.',
         [field('Familienname', 'López', 'Lopez'),
          field('Herkunftsland', 'Spanien'),
          field('Alter', '34', 'vierunddreißig'),
          field('PLZ, Wohnort', '80331 München', '80331', 'München'),
          field('Kurszeit (morgens / abends)', 'abends', 'am Abend', 'Abend'),
          field('Zahlung (bar / Karte)', 'bar')]),
    form('a1-f2', ('Form: Otel rezervasyonu', 'Form: hotel booking'),
         'Peter Wagner und seine Frau möchten vom 12. bis 15. Mai im Hotel Sonne übernachten. Sie brauchen ein '
         'Doppelzimmer mit Frühstück. Ihre Kinder kommen nicht mit. Herr Wagner hat die Telefonnummer 0171 2345678.',
         [field('Name', 'Wagner', 'Peter Wagner'),
          field('Anreise', '12. Mai', '12.5.', '12.05.', '12. 5.', '12 Mai', '12.5', '12.05'),
          field('Abreise', '15. Mai', '15.5.', '15.05.', '15. 5.', '15 Mai', '15.5', '15.05'),
          field('Zimmer (Einzel / Doppel)', 'Doppelzimmer', 'Doppel'),
          field('Personen', '2', 'zwei'),
          field('Frühstück (ja / nein)', 'ja')]),
    form('a1-f3', ('Form: Spor salonu üyeliği', 'Form: gym membership'),
         'Lea Schmidt ist Studentin. Sie ist am 3. April 2001 geboren. Sie möchte zweimal pro Woche trainieren, am '
         'liebsten am Morgen. Ihre E-Mail-Adresse ist lea.schmidt@web.de.',
         [field('Vorname', 'Lea'),
          field('Geburtsdatum', '03.04.2001', '3.4.2001', '3. April 2001', '03.04.01', '3.4.01'),
          field('Beruf', 'Studentin', 'Student'),
          field('Wie oft pro Woche?', '2', 'zweimal', 'zwei', '2 mal', '2x'),
          field('Tageszeit', 'morgens', 'am Morgen', 'Morgen'),
          field('E-Mail', 'lea.schmidt@web.de')]),
    form('a1-f4', ('Form: Kütüphane kartı', 'Form: library card'),
         'Ahmet Demir ist 27 Jahre alt. Er wohnt in der Lindenallee 8 in 50667 Köln und arbeitet als Koch. '
         'Er hat keine Kinder. Er möchte die Bibliothek am Wochenende besuchen.',
         [field('Familienname', 'Demir'),
          field('Straße, Hausnummer', 'Lindenallee 8'),
          field('Wohnort', 'Köln', '50667 Köln'),
          field('Beruf', 'Koch'),
          field('Kinder (Anzahl)', '0', 'keine', 'null', 'kein'),
          field('Alter', '27', 'siebenundzwanzig')]),

    message('a1-m1', ('E-posta: Kursa gelemiyorum', 'E-mail: I cannot come to class'),
            'Sie können morgen nicht zum Deutschkurs kommen. Schreiben Sie Ihrer Lehrerin, Frau Weber, eine E-Mail.',
            ('Neden gelemediğini yaz, ödevi sor, ne zaman tekrar geleceğini söyle.',
             'Say why you cannot come, ask about the homework, say when you come again.'),
            [point('Neden gelemiyorsun', 'Why not', 'Ich bin leider krank. / Ich habe einen Termin.', 'krank', 'arzt', 'termin', 'weil', 'leider', 'muss'),
             point('Ödevi sor', 'Ask about homework', 'Was sind die Hausaufgaben?', 'hausaufgabe'),
             point('Ne zaman geliyorsun', 'When you come back', 'Am Donnerstag komme ich wieder.', 'wieder', 'nächste', 'montag', 'dienstag', 'mittwoch', 'donnerstag', 'freitag')],
            'Liebe Frau Weber, leider kann ich morgen nicht zum Kurs kommen. Ich bin krank und muss zum Arzt. '
            'Was sind die Hausaufgaben? Am Donnerstag komme ich wieder. Viele Grüße, Elif'),
    message('a1-m2', ('Mesaj: Doğum günü daveti', 'Message: birthday invitation'),
            'Sie haben am Samstag Geburtstag und machen eine Party. Schreiben Sie Ihrem Freund Tom eine Einladung.',
            ('Ne zaman, nerede olduğunu ve ne getirmesi gerektiğini yaz.', 'Say when, where and what he should bring.'),
            [point('Ne zaman', 'When', 'am Samstag um 19 Uhr', 'samstag', 'uhr', 'abend'),
             point('Nerede', 'Where', 'bei mir zu Hause / im Garten', 'bei mir', 'zu hause', 'garten', 'wohnung', 'in der', 'im'),
             point('Ne getirsin', 'What to bring', 'Kannst du einen Salat mitbringen?', 'mitbringen', 'bringst', 'bring', 'salat', 'kuchen', 'getränke')],
            'Hallo Tom, am Samstag habe ich Geburtstag und mache eine Party. Sie beginnt um 19 Uhr bei mir zu Hause. '
            'Kannst du bitte einen Salat mitbringen? Ich freue mich auf dich! Viele Grüße, Murat'),
    message('a1-m3', ('E-posta: Kalorifer bozuk', 'E-mail: the heating is broken'),
            'Die Heizung in Ihrer Wohnung ist kaputt. Schreiben Sie dem Hausmeister, Herrn Braun, eine E-Mail.',
            ('Sorunu yaz, ne zamandan beri olduğunu söyle, ne zaman evde olduğunu yaz.',
             'Describe the problem, since when, and when you are at home.'),
            [point('Sorun', 'The problem', 'Die Heizung ist kaputt.', 'heizung', 'kaputt', 'funktioniert nicht', 'kalt'),
             point('Ne zamandan beri', 'Since when', 'seit Montag', 'seit'),
             point('Ne zaman evdesin', 'When you are at home', 'Ich bin am Nachmittag zu Hause.', 'zu hause', 'da', 'nachmittag', 'vormittag', 'abend', 'uhr')],
            'Sehr geehrter Herr Braun, in meiner Wohnung ist die Heizung kaputt. Das Problem gibt es seit Montag und es ist sehr kalt. '
            'Ich bin jeden Tag ab 16 Uhr zu Hause. Können Sie bitte kommen? Mit freundlichen Grüßen, Anna Kaya'),
    message('a1-m4', ('Mesaj: Sinemaya gidelim', "Message: let's go to the cinema"),
            'Sie möchten am Wochenende mit Ihrer Freundin Sara ins Kino gehen. Schreiben Sie ihr eine Nachricht.',
            ('Hangi filmi, ne zaman ve nerede buluşacağınızı yaz.', 'Say which film, when, and where you meet.'),
            [point('Film / sinema', 'Film or cinema', 'Möchtest du den neuen Film sehen?', 'film', 'kino'),
             point('Ne zaman', 'When', 'am Sonntag um 18 Uhr', 'samstag', 'sonntag', 'uhr', 'wochenende'),
             point('Buluşma yeri', 'Where to meet', 'Wir treffen uns vor dem Kino.', 'treffen', 'vor dem', 'am bahnhof', 'bei mir', 'haltestelle')],
            'Hallo Sara, hast du am Sonntag Zeit? Ich möchte den neuen Film im Kino sehen. Er beginnt um 18 Uhr. '
            'Wir treffen uns um Viertel vor sechs vor dem Kino. Schreib mir bitte! Liebe Grüße, Ece'),
    message('a1-m5', ('Kart: Hediye için teşekkür', 'Card: thanks for a present'),
            'Ihre Tante hat Ihnen ein Geschenk geschickt. Schreiben Sie ihr eine kurze Karte.',
            ('Teşekkür et, hediyenin neden hoşuna gittiğini yaz, onu yemeğe davet et.',
             'Thank her, say why you like the present, invite her for a meal.'),
            [point('Teşekkür', 'Thank you', 'Vielen Dank für das Geschenk!', 'danke', 'vielen dank'),
             point('Neden beğendin', 'Why you like it', 'Der Schal ist sehr schön und warm.', 'schön', 'gefällt', 'toll', 'super', 'praktisch', 'warm'),
             point('Davet', 'Invitation', 'Kommst du am Sonntag zum Essen?', 'essen', 'einladen', 'kommst du', 'besuch')],
            'Liebe Tante Ayşe, vielen Dank für das Geschenk! Der Schal ist sehr schön und warm, er gefällt mir sehr. '
            'Möchtest du am Sonntag zum Essen kommen? Ich koche für dich. Viele Grüße, deine Selin'),
    message('a1-m6', ('E-posta: Otelden bilgi iste', 'E-mail: ask a hotel'),
            'Sie möchten im Juli drei Nächte in Hamburg bleiben. Schreiben Sie dem Hotel Hafenblick eine E-Mail.',
            ('Boş oda olup olmadığını, fiyatı ve kahvaltıyı sor.', 'Ask if there is a free room, the price and about breakfast.'),
            [point('Boş oda', 'Free room', 'Haben Sie vom 3. bis 6. Juli ein Zimmer frei?', 'zimmer', 'frei'),
             point('Fiyat', 'Price', 'Was kostet das Zimmer pro Nacht?', 'kostet', 'preis', 'wie viel'),
             point('Kahvaltı', 'Breakfast', 'Ist das Frühstück inklusive?', 'frühstück')],
            'Sehr geehrte Damen und Herren, haben Sie vom 3. bis 6. Juli ein Einzelzimmer frei? Was kostet das Zimmer pro Nacht? '
            'Ist das Frühstück inklusive? Vielen Dank für Ihre Antwort. Mit freundlichen Grüßen, Can Öztürk'),
]

# A greeting and a closing are checked for every message as well.
GREETING = ['liebe', 'lieber', 'hallo', 'hi', 'sehr geehrte', 'sehr geehrter', 'guten tag']
CLOSING = ['grüße', 'gruß', 'bis bald', 'tschüss', 'bis dann', 'bis morgen']


def block(tr, en, *phrases):
    return {'title': {'tr': tr, 'en': en}, 'phrases': list(phrases)}


# The e-mail pattern: the order of a short message and ready phrases for each step (… = fill in).
PATTERN = {
    'informal': [
        block('1 · Hitap', '1 · Greeting', 'Liebe …,', 'Lieber …,', 'Hallo …,'),
        block('2 · Giriş', '2 · Opening', 'wie geht es dir?', 'danke für deine Nachricht.', 'ich schreibe dir, weil …'),
        block('3 · Konu', '3 · The reason', 'Leider kann ich am … nicht kommen.', 'Ich bin krank.', 'Am Samstag habe ich Geburtstag.', 'Ich mache eine Party.'),
        block('4 · Rica / soru', '4 · Request / question', 'Kannst du …?', 'Hast du am … Zeit?', 'Kannst du bitte … mitbringen?', 'Möchtest du mitkommen?'),
        block('5 · Zaman ve yer', '5 · Time and place', 'am Samstag um … Uhr', 'bei mir zu Hause', 'Wir treffen uns vor dem …'),
        block('6 · Kapanış', '6 · Closing', 'Ich freue mich auf dich!', 'Schreib mir bitte.', 'Bis bald!'),
        block('7 · Selam', '7 · Sign-off', 'Viele Grüße', 'Liebe Grüße', 'Bis dann'),
    ],
    'formal': [
        block('1 · Hitap', '1 · Greeting', 'Sehr geehrte Frau …,', 'Sehr geehrter Herr …,', 'Sehr geehrte Damen und Herren,'),
        block('2 · Giriş', '2 · Opening', 'ich schreibe Ihnen, weil …', 'vielen Dank für Ihre E-Mail.'),
        block('3 · Konu', '3 · The reason', 'Leider kann ich morgen nicht kommen.', 'Ich habe ein Problem mit …', 'Ich möchte vom … bis … in Hamburg bleiben.'),
        block('4 · Rica / soru', '4 · Request / question', 'Können Sie bitte …?', 'Haben Sie noch ein Zimmer frei?', 'Was kostet …?', 'Ich möchte gern wissen, …'),
        block('5 · Zaman ve yer', '5 · Time and place', 'am … um … Uhr', 'Ich bin ab … Uhr zu Hause.', 'seit Montag'),
        block('6 · Kapanış', '6 · Closing', 'Vielen Dank im Voraus.', 'Ich freue mich auf Ihre Antwort.'),
        block('7 · Selam', '7 · Sign-off', 'Mit freundlichen Grüßen', 'Viele Grüße'),
    ],
}


def main():
    ids = [t['id'] for t in TASKS]
    assert len(ids) == len(set(ids))
    with open(OUT, 'w', encoding='utf-8', newline='\n') as f:
        json.dump({'greeting': GREETING, 'closing': CLOSING, 'pattern': PATTERN, 'tasks': TASKS}, f, ensure_ascii=False, indent=1)
        f.write('\n')
    print(f'{len(TASKS)} writing tasks -> {OUT}')


if __name__ == '__main__':
    main()

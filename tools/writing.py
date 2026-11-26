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


def message(id, title, prompt, help, points, sample, min_words=25, level='A1', formal=None):
    # Formal (Sie) when writing to a teacher, a caretaker, a hotel …; informal (du) to friends and family.
    if formal is None:
        formal = any(w in prompt for w in ('Frau', 'Herr', 'Hotel', 'Hausmeister'))
    return {'id': id, 'level': level, 'kind': 'message', 'title': {'tr': title[0], 'en': title[1]}, 'prompt': prompt,
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
    message('a1-m7', ('Mesaj: Marketten ne alalım?', 'Message: what shall we buy?'),
            'Sie gehen heute einkaufen. Schreiben Sie Ihrem Mitbewohner Jonas eine Nachricht.',
            ('Ne alacağını yaz, ona bir şey isteyip istemediğini sor ve ne zaman eve döneceğini söyle.',
             'Say what you will buy, ask if he wants something and say when you are back.'),
            [point('Ne alacaksın', 'What you buy', 'Ich kaufe Brot, Milch und Käse.', 'kaufe', 'brot', 'milch', 'käse', 'äpfel', 'eier', 'supermarkt'),
             point('Ona soru', 'Ask him', 'Brauchst du auch etwas?', 'brauchst', 'möchtest', 'willst', 'etwas'),
             point('Ne zaman dönüyorsun', 'When you are back', 'Ich bin um 18 Uhr zu Hause.', 'uhr', 'zu hause', 'zurück', 'später')],
            'Hallo Jonas, ich gehe heute in den Supermarkt. Ich kaufe Brot, Milch und Käse. Brauchst du auch etwas? '
            'Vielleicht Äpfel oder Kaffee? Ich bin um 18 Uhr wieder zu Hause. Viele Grüße, Elif'),
    message('a1-m6', ('E-posta: Otelden bilgi iste', 'E-mail: ask a hotel'),
            'Sie möchten im Juli drei Nächte in Hamburg bleiben. Schreiben Sie dem Hotel Hafenblick eine E-Mail.',
            ('Boş oda olup olmadığını, fiyatı ve kahvaltıyı sor.', 'Ask if there is a free room, the price and about breakfast.'),
            [point('Boş oda', 'Free room', 'Haben Sie vom 3. bis 6. Juli ein Zimmer frei?', 'zimmer', 'frei'),
             point('Fiyat', 'Price', 'Was kostet das Zimmer pro Nacht?', 'kostet', 'preis', 'wie viel'),
             point('Kahvaltı', 'Breakfast', 'Ist das Frühstück inklusive?', 'frühstück')],
            'Sehr geehrte Damen und Herren, haben Sie vom 3. bis 6. Juli ein Einzelzimmer frei? Was kostet das Zimmer pro Nacht? '
            'Ist das Frühstück inklusive? Vielen Dank für Ihre Antwort. Mit freundlichen Grüßen, Can Öztürk'),
]

# A2 (Goethe A2 Schreiben): Teil 1 a short message to a friend (about 30 words),
# Teil 2 an e-mail to someone you say "Sie" to (about 40 words). Three points each.
TASKS_A2 = [
    message('a2-m1', ('Mesaj: Akşam yemeğine geç kalıyorum', "Message: I'm late for dinner"),
            'Sie sind heute Abend bei Ihrer Freundin Julia zum Essen eingeladen, aber Sie kommen später. Schreiben Sie Julia eine Nachricht.',
            ('Neden geç kaldığını, ne zaman geleceğini yaz ve bir şey getirip getirmeyeceğini sor.',
             'Say why you are late and when you will come, and ask if you should bring something.'),
            [point('Neden geç', 'Why late', 'Ich komme später, weil ich länger arbeiten muss.', 'weil', 'leider', 'später', 'muss'),
             point('Ne zaman', 'When', 'Ich bin um halb acht bei dir.', 'uhr', 'halb', 'viertel', 'minuten'),
             point('Bir şey getireyim mi', 'Shall I bring something', 'Soll ich etwas mitbringen?', 'mitbringen', 'soll ich', 'brauchst du')],
            'Hallo Julia, es tut mir leid, aber ich komme heute später, weil ich länger arbeiten muss. Ich bin um halb acht bei dir. '
            'Soll ich noch etwas mitbringen, vielleicht Brot oder einen Nachtisch? Liebe Grüße, Deniz',
            min_words=30, level='A2', formal=False),
    message('a2-m2', ('E-posta: Komşulara parti haberi', 'E-mail: telling the neighbours about a party'),
            'Sie machen am Samstag eine Party in Ihrer Wohnung. Schreiben Sie Ihrer Nachbarin, Frau Klein, eine E-Mail.',
            ('Partiyi haber ver, gürültü için özür dile ve onu da davet et.',
             'Tell her about the party, apologise for the noise and invite her too.'),
            [point('Parti', 'The party', 'Am Samstag mache ich eine Party.', 'party', 'feier', 'feiern', 'geburtstag'),
             point('Özür', 'Apology', 'Es tut mir leid, wenn es laut wird.', 'tut mir leid', 'entschuldigung', 'laut', 'lärm'),
             point('Davet', 'Invitation', 'Möchten Sie auch kommen?', 'möchten sie', 'kommen sie', 'einladen', 'eingeladen', 'herzlich willkommen')],
            'Sehr geehrte Frau Klein, am Samstag feiere ich meinen Geburtstag und mache ab 19 Uhr eine kleine Party in meiner Wohnung. '
            'Es tut mir leid, wenn es etwas laut wird. Um 23 Uhr machen wir die Musik leiser. Möchten Sie auch kommen? '
            'Sie sind herzlich eingeladen. Mit freundlichen Grüßen, Emre Yıldız',
            min_words=40, level='A2', formal=True),
    message('a2-m3', ('E-posta: Yanlış ürün geldi', 'E-mail: the wrong product arrived'),
            'Sie haben im Online-Shop „Modehaus Berg“ eine blaue Jacke bestellt, aber eine rote bekommen. Schreiben Sie dem Kundenservice eine E-Mail.',
            ('Ne sipariş ettiğini, ne geldiğini yaz ve ne istediğini söyle (değişim ya da para iadesi).',
             'Say what you ordered and what arrived, and what you want (an exchange or your money back).'),
            [point('Sipariş', 'Your order', 'Ich habe eine blaue Jacke bestellt.', 'bestellt', 'bestellung'),
             point('Sorun', 'The problem', 'Ich habe aber eine rote Jacke bekommen.', 'bekommen', 'falsch', 'geliefert', 'rote'),
             point('İsteğin', 'What you want', 'Ich möchte die Jacke umtauschen.', 'umtauschen', 'zurückschicken', 'geld zurück', 'zurück')],
            'Sehr geehrte Damen und Herren, am 4. März habe ich bei Ihnen eine blaue Jacke in Größe M bestellt. '
            'Leider habe ich gestern eine rote Jacke bekommen. Ich möchte die Jacke gern umtauschen. '
            'Können Sie mir bitte die blaue Jacke schicken? Mit freundlichen Grüßen, Aylin Koç',
            min_words=40, level='A2', formal=True),
    message('a2-m4', ('Mesaj: Tren rötar yaptı', 'Message: the train is late'),
            'Sie sind mit Ihrem Kollegen Jonas zu einem Termin verabredet. Ihr Zug hat Verspätung. Schreiben Sie Jonas eine Nachricht.',
            ('Ne olduğunu, ne zaman varacağını yaz ve ondan bir rica et.',
             'Say what happened and when you will arrive, and ask him for a favour.'),
            [point('Ne oldu', 'What happened', 'Mein Zug hat Verspätung.', 'verspätung', 'verpasst', 'zug', 'bus', 'später'),
             point('Ne zaman varıyorsun', 'When you arrive', 'Ich bin gegen zehn Uhr da.', 'uhr', 'minuten', 'gegen'),
             point('Rica', 'A favour', 'Kannst du bitte schon anfangen?', 'kannst du', 'bitte', 'sag')],
            'Hallo Jonas, mein Zug hat leider zwanzig Minuten Verspätung und ich habe den Anschluss verpasst. '
            'Ich bin gegen zehn Uhr da. Kannst du bitte schon mit dem Kunden anfangen? Bis gleich, Kerem',
            min_words=30, level='A2', formal=False),
    message('a2-m5', ('E-posta: Hastayım, işe gelemiyorum', "E-mail: I'm ill and can't come to work"),
            'Sie sind krank und können nicht zur Arbeit gehen. Schreiben Sie Ihrem Chef, Herrn Hoffmann, eine E-Mail.',
            ('Neyin olduğunu, doktorun ne dediğini ve ne zaman döneceğini yaz.',
             'Say what is wrong, what the doctor said and when you will be back.'),
            [point('Neyin var', "What's wrong", 'Ich habe Fieber und Halsschmerzen.', 'krank', 'fieber', 'schmerzen', 'erkältet', 'grippe'),
             point('Doktor', 'The doctor', 'Der Arzt hat gesagt, dass ich zu Hause bleiben muss.', 'arzt', 'ärztin', 'krankschreibung', 'krankgeschrieben'),
             point('Dönüş', 'When you are back', 'Ich komme am Montag wieder.', 'wieder', 'montag', 'dienstag', 'mittwoch', 'donnerstag', 'freitag', 'nächste woche')],
            'Sehr geehrter Herr Hoffmann, leider bin ich krank. Ich habe Fieber und starke Halsschmerzen. '
            'Ich war heute beim Arzt und er hat gesagt, dass ich bis Freitag zu Hause bleiben muss. '
            'Am Montag komme ich wieder zur Arbeit. Die Krankschreibung schicke ich Ihnen per Post. Mit freundlichen Grüßen, Selin Arslan',
            min_words=40, level='A2', formal=True),
    message('a2-m6', ('E-posta: Staj hakkında bilgi', 'E-mail: asking about an internship'),
            'Sie haben eine Anzeige für ein Praktikum in einem Hotel gelesen. Schreiben Sie Frau Schulz von der Firma eine E-Mail.',
            ('Kendini kısaca tanıt, çalışma saatlerini sor ve neden ilgilendiğini yaz.',
             'Introduce yourself briefly, ask about the working hours and say why you are interested.'),
            [point('Tanıtım', 'About you', 'Ich bin 22 Jahre alt und lerne Deutsch.', 'ich bin', 'ich heiße', 'jahre alt', 'ich komme aus'),
             point('Saatler', 'Working hours', 'Wie sind die Arbeitszeiten?', 'arbeitszeit', 'stunden', 'wann'),
             point('Neden', 'Why', 'Ich interessiere mich für das Praktikum, weil ich gern mit Menschen arbeite.', 'weil', 'interessiere', 'gern')],
            'Sehr geehrte Frau Schulz, ich habe Ihre Anzeige gelesen und interessiere mich für das Praktikum. '
            'Ich bin 22 Jahre alt, komme aus der Türkei und lerne seit einem Jahr Deutsch. Ich möchte im Hotel arbeiten, weil ich gern mit Menschen arbeite. '
            'Wie sind die Arbeitszeiten? Mit freundlichen Grüßen, Baran Çelik',
            min_words=40, level='A2', formal=True),
    message('a2-m7', ('E-posta: Hafta sonu konserdeydim', 'E-mail: I was at a concert at the weekend'),
            'Sie waren am Wochenende auf einem Konzert. Schreiben Sie Ihrem Freund Max eine E-Mail.',
            ('Nerede olduğunu, nasıl geçtiğini anlat ve onu bir sonraki konsere davet et.',
             'Say where you were and how it was, and invite him to the next concert.'),
            [point('Nerede', 'Where', 'Am Samstag war ich auf einem Konzert im Park.', 'war ich', 'bin ich', 'konzert', 'gewesen'),
             point('Nasıl geçti', 'How it was', 'Die Musik war super und es hat viel Spaß gemacht.', 'war super', 'toll', 'spaß', 'gefallen', 'schön'),
             point('Davet', 'Invitation', 'Hast du Lust, nächsten Monat mitzukommen?', 'lust', 'mitkommen', 'mitzukommen', 'kommst du')],
            'Lieber Max, wie geht es dir? Am Samstag war ich mit Lena auf einem Konzert im Stadtpark. '
            'Die Band war super und wir haben viel getanzt. Es hat wirklich Spaß gemacht! Im nächsten Monat spielt die Band wieder. '
            'Hast du Lust mitzukommen? Viele Grüße, Ece',
            min_words=40, level='A2', formal=False),
    message('a2-m8', ('Mesaj: Telefonum bozuldu', 'Message: my phone is broken'),
            'Ihr Handy ist kaputt und Sie haben jetzt eine neue Nummer. Schreiben Sie Ihrer Freundin Mia eine Nachricht.',
            ('Ne olduğunu yaz, yeni numaranı ver ve fotoğrafları tekrar göndermesini rica et.',
             'Say what happened, give your new number and ask her to send the photos again.'),
            [point('Ne oldu', 'What happened', 'Mein Handy ist kaputt.', 'kaputt', 'funktioniert nicht', 'runtergefallen', 'heruntergefallen'),
             point('Yeni numara', 'New number', 'Meine neue Nummer ist 0176 …', 'nummer'),
             point('Fotoğraflar', 'The photos', 'Kannst du mir die Fotos noch einmal schicken?', 'foto', 'bilder', 'schicken')],
            'Hallo Mia, mein Handy ist gestern runtergefallen und jetzt ist es kaputt. Meine neue Nummer ist 0176 5523190. '
            'Kannst du mir bitte die Fotos vom Ausflug noch einmal schicken? Danke! Liebe Grüße, Zeynep',
            min_words=30, level='A2', formal=False),
    message('a2-m9', ('E-posta: Dil kursu hakkında soru', 'E-mail: asking about a language course'),
            'Sie möchten einen B1-Kurs an der Sprachschule „Lingua“ machen. Schreiben Sie der Sprachschule eine E-Mail.',
            ('Hangi kursu istediğini yaz, saatleri ve fiyatı sor.', 'Say which course you want and ask about the times and the price.'),
            [point('Hangi kurs', 'Which course', 'Ich möchte gern einen B1-Kurs machen.', 'kurs', 'b1'),
             point('Saatler', 'Times', 'Wann findet der Kurs statt?', 'wann', 'uhrzeit', 'abends', 'morgens', 'beginnt', 'findet'),
             point('Fiyat', 'Price', 'Was kostet der Kurs?', 'kostet', 'preis', 'wie viel', 'gebühr')],
            'Sehr geehrte Damen und Herren, ich habe einen A2-Kurs gemacht und möchte gern im Herbst einen B1-Kurs bei Ihnen besuchen. '
            'Ich arbeite am Tag, deshalb suche ich einen Kurs am Abend. Wann findet der Kurs statt und was kostet er? '
            'Vielen Dank für Ihre Antwort. Mit freundlichen Grüßen, Mert Aydın',
            min_words=40, level='A2', formal=True),
    message('a2-m10', ('Mesaj: Parkı birlikte temizleyelim', "Message: let's clean the park together"),
            'In Ihrem Viertel gibt es am Samstag einen Aufräumtag im Park. Schreiben Sie Ihrem Freund Paul eine Nachricht.',
            ('Ne olduğunu, ne zaman başladığını yaz ve ne getirmesi gerektiğini söyle.',
             'Say what it is and when it starts, and what he should bring.'),
            [point('Ne', 'What', 'Am Samstag räumen wir den Park auf.', 'aufräum', 'park', 'müll', 'sammeln'),
             point('Ne zaman', 'When', 'Wir treffen uns um zehn Uhr am Eingang.', 'uhr', 'samstag', 'treffen'),
             point('Ne getirsin', 'What to bring', 'Bring bitte Handschuhe mit.', 'mitbringen', 'bring', 'handschuhe', 'tüten')],
            'Hallo Paul, am Samstag gibt es in unserem Viertel einen Aufräumtag. Wir sammeln Müll im Park. '
            'Wir treffen uns um zehn Uhr am Eingang. Kommst du mit? Bring bitte Handschuhe mit! Viele Grüße, Lara',
            min_words=30, level='A2', formal=False),
]

TASKS += TASKS_A2


# B1 (Goethe B1 Schreiben): Teil 1 e-mail to a friend (about 80 words), Teil 2 opinion in an online forum
# (about 80 words), Teil 3 polite e-mail to someone you say "Sie" to (about 40 words).
TASKS_B1 = [
    message('b1-m1', ('E-posta: Yeni evime taşındım', 'E-mail: I have moved'),
            'Sie sind vor kurzem umgezogen. Schreiben Sie Ihrer Freundin Hanna eine E-Mail.',
            ('Yeni evini anlat, taşınmanın nasıl geçtiğini yaz ve onu ziyarete davet et; bir tarih öner.',
             'Describe your new home, say how the move went and invite her to visit; suggest a date.'),
            [point('Yeni ev', 'The new home', 'Die Wohnung, die ich gefunden habe, ist hell und hat einen Balkon.', 'wohnung', 'zimmer', 'balkon', 'haus'),
             point('Taşınma', 'The move', 'Der Umzug war anstrengend, aber meine Freunde haben mir geholfen.', 'umzug', 'umgezogen', 'kartons', 'geholfen'),
             point('Davet ve tarih', 'Invitation and date', 'Hättest du am Samstag, dem 12., Zeit?', 'besuch', 'kommen', 'zeit', 'samstag', 'sonntag', 'wochenende')],
            'Liebe Hanna, wie geht es dir? Stell dir vor, ich bin endlich umgezogen! Die Wohnung, die ich gefunden habe, liegt im Zentrum. '
            'Sie ist hell, hat drei Zimmer und einen kleinen Balkon, auf dem ich morgens Kaffee trinke. Der Umzug war ziemlich anstrengend, '
            'weil wir keinen Aufzug haben, aber zum Glück haben mir zwei Freunde geholfen. Jetzt stehen nur noch ein paar Kartons im Flur. '
            'Hättest du Lust, mich zu besuchen? Wie wäre es mit Samstag, dem 12.? Ich koche für uns. Liebe Grüße, Ayla',
            min_words=80, level='B1', formal=False),
    message('b1-m2', ('E-posta: Tatilden selamlar', 'E-mail: greetings from my holiday'),
            'Sie haben eine Reise gemacht, aber nicht alles hat geklappt. Schreiben Sie Ihrem Freund Lukas eine E-Mail.',
            ('Nereye gittiğini, neyin iyi neyin kötü gittiğini yaz ve bir sonraki yolculuk için öneride bulun.',
             'Say where you went, what went well and what went wrong, and suggest the next trip together.'),
            [point('Nereye', 'Where', 'Letzte Woche war ich in Wien.', 'war ich', 'bin', 'gefahren', 'gereist', 'reise'),
             point('İyi ve kötü', 'Good and bad', 'Obwohl der Zug Verspätung hatte, war die Stadt wunderschön.', 'obwohl', 'leider', 'verspätung', 'aber', 'schön'),
             point('Öneri', 'Suggestion', 'Nächstes Mal könnten wir zusammen fahren.', 'nächstes mal', 'zusammen', 'könnten wir', 'hast du lust')],
            'Hallo Lukas, ich bin gerade aus Wien zurückgekommen und muss dir unbedingt erzählen, wie es war. Die Stadt ist wunderschön: '
            'Wir haben viele Museen besucht und jeden Tag in einem anderen Café gesessen. Leider hatte unser Zug auf der Hinfahrt drei Stunden '
            'Verspätung, und am zweiten Tag hat es nur geregnet. Obwohl nicht alles geklappt hat, möchte ich unbedingt noch einmal hinfahren. '
            'Nächstes Mal könnten wir zusammen fahren, vielleicht im Frühling, wenn es wärmer ist? Hast du Lust? Viele Grüße, Burak',
            min_words=80, level='B1', formal=False),
    message('b1-m3', ('Forum: Evden çalışmak', 'Forum: working from home'),
            'In einem Online-Forum wird gefragt: „Ist Homeoffice besser als Arbeiten im Büro?“ Schreiben Sie Ihre Meinung.',
            ('Görüşünü söyle, gerekçe ver ve kendi deneyiminden bir örnek ekle.', 'Give your opinion, give reasons and add an example from your own experience.'),
            [point('Görüş', 'Opinion', 'Meiner Meinung nach ist eine Mischung am besten.', 'meiner meinung', 'ich finde', 'ich denke', 'ich bin der meinung', 'meines erachtens'),
             point('Gerekçe', 'Reasons', 'Einerseits spart man Zeit, andererseits fehlt der Kontakt.', 'weil', 'denn', 'einerseits', 'andererseits', 'vorteil', 'nachteil'),
             point('Deneyim', 'Your experience', 'Ich selbst arbeite zweimal pro Woche zu Hause.', 'ich selbst', 'bei mir', 'meine erfahrung', 'ich arbeite')],
            'Hallo zusammen, meiner Meinung nach ist eine Mischung aus Homeoffice und Büro am besten. Einerseits spart man im Homeoffice viel Zeit, '
            'weil man nicht pendeln muss, und man kann sich besser konzentrieren. Andererseits fehlt der Kontakt zu den Kollegen, und manche Probleme '
            'lassen sich im Gespräch schneller lösen. Ich selbst arbeite zweimal pro Woche zu Hause und an den anderen Tagen im Büro. '
            'So habe ich Ruhe für schwierige Aufgaben und trotzdem genug Austausch im Team. Das funktioniert für mich sehr gut. Viele Grüße, Elif',
            min_words=80, level='B1', formal=False),
    message('b1-m4', ('Forum: Çocuklar ve akıllı telefon', 'Forum: children and smartphones'),
            'In einem Online-Forum wird diskutiert: „Sollten Kinder unter zwölf Jahren ein eigenes Smartphone haben?“ Schreiben Sie Ihre Meinung.',
            ('Görüşünü söyle, avantaj ve dezavantaj say, bir öneride bulun.', 'Give your opinion, name advantages and disadvantages, make a suggestion.'),
            [point('Görüş', 'Opinion', 'Ich finde, dass Kinder erst später ein Smartphone brauchen.', 'meiner meinung', 'ich finde', 'ich denke', 'ich bin der meinung'),
             point('Artı ve eksi', 'Pros and cons', 'Ein Vorteil ist …, ein Nachteil ist …', 'vorteil', 'nachteil', 'einerseits', 'andererseits', 'gefahr'),
             point('Öneri', 'Suggestion', 'Eltern sollten klare Regeln machen.', 'sollten', 'regeln', 'vorschlag', 'am besten')],
            'Hallo zusammen, ich finde, dass Kinder unter zwölf Jahren noch kein eigenes Smartphone brauchen. Ein Vorteil ist natürlich, '
            'dass Eltern ihre Kinder immer erreichen können. Ein großer Nachteil ist aber, dass viele Kinder zu viel Zeit am Bildschirm verbringen '
            'und weniger draußen spielen. Außerdem gibt es im Internet Gefahren, die Kinder noch nicht verstehen. Am besten wäre ein einfaches Handy '
            'zum Telefonieren. Wenn Kinder doch ein Smartphone bekommen, sollten Eltern klare Regeln machen, zum Beispiel kein Handy beim Essen und am Abend. Viele Grüße, Murat',
            min_words=80, level='B1', formal=False),
    message('b1-m5', ('E-posta: Toplantıya katılamıyorum', "E-mail: I can't come to the meeting"),
            'Sie können nicht zu einem wichtigen Termin mit Ihrer Kursleiterin, Frau Dr. Neumann, kommen. Schreiben Sie ihr eine E-Mail.',
            ('Kibarca özür dile, nedenini yaz ve yeni bir tarih öner.', 'Apologise politely, give the reason and suggest a new date.'),
            [point('Özür', 'Apology', 'Leider kann ich am Donnerstag nicht kommen.', 'leider', 'entschuldigung', 'tut mir leid', 'entschuldigen'),
             point('Neden', 'Reason', 'Ich muss an dem Tag arbeiten.', 'weil', 'da ich', 'muss', 'termin'),
             point('Yeni tarih', 'New date', 'Wäre es möglich, das Gespräch zu verschieben?', 'verschieben', 'anderen termin', 'möglich', 'nächste woche')],
            'Sehr geehrte Frau Dr. Neumann, leider kann ich am Donnerstag nicht zu unserem Gespräch kommen, weil ich an diesem Tag kurzfristig arbeiten muss. '
            'Das tut mir sehr leid. Wäre es möglich, den Termin auf nächste Woche zu verschieben? Mit freundlichen Grüßen, Can Yılmaz',
            min_words=40, level='B1', formal=True),
    message('b1-m6', ('E-posta: Gönüllü olmak istiyorum', 'E-mail: I would like to volunteer'),
            'Ein Verein sucht Freiwillige für ein Stadtfest. Schreiben Sie Herrn Becker vom Verein eine E-Mail.',
            ('Kendini tanıt, neden katılmak istediğini yaz ve bir şey sor.', 'Introduce yourself, say why you want to take part and ask a question.'),
            [point('Tanıtım', 'About you', 'Ich heiße … und wohne seit zwei Jahren in der Stadt.', 'ich heiße', 'mein name', 'ich bin', 'ich wohne'),
             point('Neden', 'Why', 'Ich möchte mithelfen, weil ich neue Leute kennenlernen will.', 'weil', 'möchte', 'gern', 'interessiere'),
             point('Soru', 'Question', 'Könnten Sie mir sagen, wann die Helfer da sein müssen?', 'könnten sie', 'ob', 'wann', 'wie viele', 'frage')],
            'Sehr geehrter Herr Becker, mein Name ist Selin Kaya und ich wohne seit zwei Jahren in der Stadt. Ich möchte beim Stadtfest gern mithelfen, '
            'weil ich neue Leute kennenlernen will. Könnten Sie mir sagen, wann die Helfer da sein müssen? Mit freundlichen Grüßen, Selin Kaya',
            min_words=40, level='B1', formal=True),
]
TASKS += TASKS_B1


# B2 (Goethe B2 Schreiben): Teil 1 opinion in a forum (about 150 words), Teil 2 formal message (about 100 words).
TASKS_B2 = [
    message('b2-m1', ('Forum: Şehir merkezinde araba yasağı', 'Forum: a car ban in the city centre'),
            'In einem Online-Forum wird diskutiert: „Sollten Autos aus den Innenstädten verbannt werden?“ Schreiben Sie einen Beitrag.',
            ('Görüşünü gerekçelendir, avantaj ve dezavantajları tartış, başka şehirlerden örnek ver ve bir sonuç yaz.',
             'Argue your view, weigh pros and cons, give an example from other cities and write a conclusion.'),
            [point('Görüş', 'Opinion', 'Ich bin der Meinung, dass …', 'meiner meinung', 'ich bin der meinung', 'meines erachtens', 'ich halte', 'ich finde'),
             point('Artı / eksi', 'Pros and cons', 'Einerseits …, andererseits …', 'einerseits', 'andererseits', 'vorteil', 'nachteil', 'dagegen'),
             point('Örnek', 'Example', 'In Kopenhagen zum Beispiel …', 'zum beispiel', 'beispielsweise', 'etwa'),
             point('Sonuç', 'Conclusion', 'Alles in allem …', 'alles in allem', 'zusammenfassend', 'abschließend', 'insgesamt')],
            'Hallo zusammen, ich bin der Meinung, dass Autos nicht komplett aus den Innenstädten verbannt werden sollten, aber deutlich weniger Platz bekommen müssen. '
            'Einerseits wären autofreie Zentren leiser, sauberer und sicherer. Kinder könnten freier spielen, und Cafés und Geschäfte hätten mehr Platz im Freien. '
            'Andererseits sind viele Menschen auf das Auto angewiesen, etwa ältere Leute, Handwerker oder Familien, die außerhalb wohnen und schlechte Busverbindungen haben. '
            'Ein komplettes Verbot würde diese Gruppen benachteiligen. In Kopenhagen zum Beispiel wurde der Autoverkehr schrittweise reduziert, während gleichzeitig '
            'Radwege und der Nahverkehr ausgebaut wurden. Dadurch fahren heute viel mehr Menschen freiwillig Fahrrad, und die Geschäfte in der Innenstadt haben keine Kunden verloren, wie viele Händler anfangs befürchtet hatten. Auch in meiner eigenen Stadt wurde vor zwei Jahren eine Straße für Autos gesperrt; seitdem ist sie ein beliebter Treffpunkt. Alles in allem halte ich einen solchen Mittelweg '
            'für sinnvoller als ein striktes Verbot: weniger Parkplätze, bessere Alternativen und Ausnahmen für diejenigen, die wirklich ein Auto brauchen. Viele Grüße, Deniz',
            min_words=150, level='B2', formal=False),
    message('b2-m2', ('Forum: Dört günlük çalışma haftası', 'Forum: the four-day week'),
            'In einem Forum wird gefragt: „Ist die Vier-Tage-Woche ein Modell für die Zukunft?“ Schreiben Sie einen Beitrag.',
            ('Görüşünü gerekçelendir, çalışanlar ve şirketler açısından tartış, kendi deneyimini ekle ve bir sonuç yaz.',
             'Argue your view, discuss it for employees and companies, add your experience and write a conclusion.'),
            [point('Görüş', 'Opinion', 'Meiner Meinung nach …', 'meiner meinung', 'ich bin der meinung', 'meines erachtens', 'ich halte', 'ich finde'),
             point('Çalışanlar / şirketler', 'Employees and companies', 'Für Arbeitnehmer bedeutet das …, für Unternehmen …', 'arbeitnehmer', 'unternehmen', 'firmen', 'beschäftigte', 'arbeitgeber'),
             point('Deneyim', 'Experience', 'In meiner Firma haben wir …', 'in meiner firma', 'ich selbst', 'meine erfahrung', 'bei uns'),
             point('Sonuç', 'Conclusion', 'Zusammenfassend …', 'alles in allem', 'zusammenfassend', 'abschließend', 'insgesamt')],
            'Hallo zusammen, meiner Meinung nach ist die Vier-Tage-Woche ein spannendes Modell, das aber nicht für jede Branche passt. Für Arbeitnehmer bedeutet ein '
            'zusätzlicher freier Tag mehr Zeit für Familie, Erholung und Hobbys. Studien zeigen, dass ausgeruhte Beschäftigte oft konzentrierter arbeiten und seltener krank sind. '
            'Für Unternehmen kann das ein Vorteil sein, zumal sie im Wettbewerb um Fachkräfte attraktiver werden. Allerdings lässt sich das Modell nicht überall umsetzen: '
            'In Krankenhäusern, Schulen oder im Handel müssen Menschen jeden Tag da sein, sodass zusätzliches Personal nötig wäre. In meiner Firma haben wir es ein halbes Jahr '
            'getestet. Die meisten Kollegen waren zufriedener und motivierter, aber manche Projekte haben länger gedauert, weil Absprachen schwieriger waren und Kunden uns freitags nicht erreichen konnten. Wir haben das schließlich gelöst, indem sich die Teams abwechseln, sodass immer jemand ansprechbar ist. Alles in allem finde ich, dass '
            'Unternehmen die Vier-Tage-Woche ausprobieren sollten, sofern sie gut geplant wird. Viele Grüße, Aylin',
            min_words=150, level='B2', formal=False),
    message('b2-m3', ('Resmî: Fatura hatası şikâyeti', 'Formal: complaint about a wrong bill'),
            'Ihr Internetanbieter hat Ihnen im letzten Monat einen zu hohen Betrag berechnet. Schreiben Sie dem Kundenservice.',
            ('Sorunu açıkla, ne beklediğini yaz, bir süre belirt ve kibar ama kararlı ol.',
             'Explain the problem, say what you expect, set a deadline; be polite but firm.'),
            [point('Sorun', 'The problem', 'Für den Monat März wurden mir 89 Euro statt 39 Euro berechnet.', 'berechnet', 'rechnung', 'abgebucht', 'betrag'),
             point('Beklenti', 'What you expect', 'Ich bitte Sie, mir die Differenz zu erstatten.', 'erstatten', 'zurücküberweisen', 'gutschrift', 'korrigieren'),
             point('Süre', 'Deadline', 'Bitte bis zum 15. April.', 'bis zum', 'innerhalb', 'frist')],
            'Sehr geehrte Damen und Herren, aufgrund eines Fehlers wurden mir für den Monat März 89 Euro statt der vereinbarten 39 Euro berechnet und von meinem Konto abgebucht. '
            'Laut meinem Vertrag habe ich einen Tarif zum festen Monatspreis, und ich habe keine zusätzlichen Leistungen bestellt. Ich bitte Sie daher, die Rechnung zu korrigieren '
            'und mir die Differenz von 50 Euro bis zum 15. April zu erstatten. Außerdem bitte ich um eine schriftliche Bestätigung, dass der Fehler in den nächsten Rechnungen nicht '
            'mehr auftritt. Die Rechnung und meinen Kontoauszug finden Sie im Anhang. Sollte ich bis dahin nichts von Ihnen hören, werde ich mich an die Verbraucherzentrale wenden. Mit freundlichen Grüßen, Kerem Aydın',
            min_words=100, level='B2', formal=True),
    message('b2-m4', ('Resmî: Eğitim talebi', 'Formal: asking for further training'),
            'Sie möchten an einer Weiterbildung teilnehmen. Schreiben Sie Ihrer Vorgesetzten, Frau Lorenz, eine E-Mail.',
            ('Eğitimi tanıt, şirkete faydasını açıkla, işlerin nasıl aksamayacağını yaz ve bir görüşme iste.',
             'Describe the course, explain the benefit for the company, say how your work will be covered and ask for a meeting.'),
            [point('Eğitim', 'The course', 'Ich möchte an einem Kurs zum Projektmanagement teilnehmen.', 'weiterbildung', 'kurs', 'seminar', 'fortbildung'),
             point('Fayda', 'Benefit', 'Davon würde auch unser Team profitieren.', 'profitieren', 'nutzen', 'vorteil', 'dadurch'),
             point('İşler', 'Your work', 'Während meiner Abwesenheit übernimmt Herr Weber meine Aufgaben.', 'vertret', 'übernimmt', 'abwesenheit', 'aufgaben'),
             point('Görüşme', 'Meeting', 'Hätten Sie diese Woche Zeit für ein kurzes Gespräch?', 'gespräch', 'termin', 'besprechen')],
            'Sehr geehrte Frau Lorenz, ich möchte im Mai an einer zweitägigen Weiterbildung zum Thema Projektmanagement teilnehmen, die von der IHK angeboten wird. '
            'In den letzten Monaten habe ich zunehmend Projekte koordiniert, und der Kurs würde mir helfen, Termine und Budgets besser zu planen. Davon würde auch unser Team '
            'profitieren, da wir mehrere neue Kunden betreuen. Während meiner Abwesenheit übernimmt Herr Weber meine dringenden Aufgaben; das haben wir bereits abgesprochen. '
            'Die Kursgebühr beträgt 480 Euro; ich wäre auch bereit, einen Teil davon selbst zu übernehmen, falls das Budget begrenzt ist. Hätten Sie diese Woche Zeit für ein kurzes Gespräch, um die Details zu besprechen? Mit freundlichen Grüßen, Selin Arslan',
            min_words=100, level='B2', formal=True),
]
TASKS += TASKS_B2

# A greeting and a closing are checked for every message as well.
GREETING = ['liebe', 'lieber', 'hallo', 'hi', 'sehr geehrte', 'sehr geehrter', 'guten tag']
CLOSING = ['grüße', 'gruß', 'bis bald', 'tschüss', 'bis dann', 'bis morgen', 'bis gleich']


def block(tr, en, *phrases):
    return {'title': {'tr': tr, 'en': en}, 'phrases': list(phrases)}


# The e-mail pattern: the order of a short message and ready phrases for each step (… = fill in).
PATTERN = {
    'informal': [
        block('1 · Hitap', '1 · Greeting', 'Liebe …,', 'Lieber …,', 'Hallo …,'),
        block('2 · Giriş', '2 · Opening', 'wie geht es dir?', 'danke für deine Nachricht.', 'ich schreibe dir, weil …'),
        block('3 · Konu', '3 · The reason', 'Leider kann ich am … nicht kommen.', 'Ich bin krank.', 'Am Samstag habe ich Geburtstag.', 'Ich mache eine Party.', 'Es tut mir leid, aber …', 'Am Wochenende war ich …'),
        block('4 · Rica / soru', '4 · Request / question', 'Kannst du …?', 'Hast du am … Zeit?', 'Kannst du bitte … mitbringen?', 'Möchtest du mitkommen?'),
        block('5 · Zaman ve yer', '5 · Time and place', 'am Samstag um … Uhr', 'bei mir zu Hause', 'Wir treffen uns vor dem …'),
        block('6 · Kapanış', '6 · Closing', 'Ich freue mich auf dich!', 'Schreib mir bitte.', 'Bis bald!'),
        block('7 · Selam', '7 · Sign-off', 'Viele Grüße', 'Liebe Grüße', 'Bis dann'),
    ],
    'formal': [
        block('1 · Hitap', '1 · Greeting', 'Sehr geehrte Frau …,', 'Sehr geehrter Herr …,', 'Sehr geehrte Damen und Herren,'),
        block('2 · Giriş', '2 · Opening', 'ich schreibe Ihnen, weil …', 'vielen Dank für Ihre E-Mail.'),
        block('3 · Konu', '3 · The reason', 'Leider kann ich morgen nicht kommen.', 'Ich habe ein Problem mit …', 'Ich möchte vom … bis … in Hamburg bleiben.', 'Ich habe Ihre Anzeige gelesen.', 'Am … habe ich bei Ihnen … bestellt.'),
        block('4 · Rica / soru', '4 · Request / question', 'Können Sie bitte …?', 'Könnten Sie mir bitte … schicken?', 'Haben Sie noch ein Zimmer frei?', 'Was kostet …?', 'Ich möchte gern wissen, …'),
        block('5 · Zaman ve yer', '5 · Time and place', 'am … um … Uhr', 'Ich bin ab … Uhr zu Hause.', 'seit Montag'),
        block('6 · Kapanış', '6 · Closing', 'Vielen Dank im Voraus.', 'Ich freue mich auf Ihre Antwort.'),
        block('7 · Selam', '7 · Sign-off', 'Mit freundlichen Grüßen', 'Viele Grüße'),
    ],
}


def main():
    ids = [t['id'] for t in TASKS]
    assert len(ids) == len(set(ids))
    for t in TASKS:
        if t['kind'] != 'message':
            continue
        sample = t['sample'].lower()
        assert len(t['sample'].split()) >= t['minWords'], (t['id'], len(t['sample'].split()))
        for p in t['points']:
            assert any(k in sample for k in p['keys']), (t['id'], p['label']['en'])
        assert any(g in sample for g in GREETING) and any(c in sample for c in CLOSING), t['id']
    with open(OUT, 'w', encoding='utf-8', newline='\n') as f:
        json.dump({'greeting': GREETING, 'closing': CLOSING, 'pattern': PATTERN, 'tasks': TASKS}, f, ensure_ascii=False, indent=1)
        f.write('\n')
    print(f'{len(TASKS)} writing tasks -> {OUT}')


if __name__ == '__main__':
    main()

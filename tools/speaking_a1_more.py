"""14 more A1 speaking tasks in the three parts of Goethe-Zertifikat A1 Sprechen (imported by tools/speaking.py).

Teil 1: introduce yourself, spell. Teil 2: a topic card, ask questions and answer them. Teil 3: ask for something.
"""


def p(tr, en, say, *keys):
    return {'label': {'tr': tr, 'en': en}, 'say': say, 'keys': list(keys)}


def task(id, seconds, title, prompt, help, points, sample):
    return {'id': id, 'level': 'A1', 'seconds': seconds, 'title': {'tr': title[0], 'en': title[1]},
            'prompt': prompt, 'help': {'tr': help[0], 'en': help[1]}, 'points': points, 'sample': sample}


ASK = p('Soru sor', 'Ask a question', 'Was …? Wo …? Hast du …?', 'was', 'wo', 'wann', 'wie', 'hast du', 'magst du', 'bist du',
        'gehst du', 'isst du', 'trinkst du', 'arbeitest du', 'wohnst du', 'fährst du', 'machst du', 'kaufst du')
ANSWER = p('Cevap ver', 'Answer it', 'Ich … / Ja, … / Nein, …', 'ich', 'ja', 'nein')
PLEASE = p('Kibarca rica et', 'Ask politely', 'Können Sie bitte …? / Kannst du bitte …?', 'können sie', 'könnten sie',
           'kannst du', 'bitte', 'darf ich', 'ich möchte', 'ich hätte gern')
REACT = p('Cevap ver / teşekkür et', 'React or thank', 'Ja, gern. / Natürlich. / Danke!', 'danke', 'gern', 'natürlich',
          'ja klar', 'kein problem', 'hier bitte', 'leider')


def card(word_tr, word_en, say, *keys):
    return p(f'Kart: {word_tr}', f'Card: {word_en}', say, *keys)


def topic(id, title, theme, cards, sample):
    return task(id, 60, title, f'Thema: {theme}. Stellen Sie zu jeder Karte eine Frage und antworten Sie.',
                ('Goethe A1 Sprechen Teil 2: her kart için bir soru sor, sonra soruyu kendin cevapla.',
                 'Goethe A1 Sprechen part 2: ask one question for each card, then answer it yourself.'),
                [ASK, ANSWER] + cards, sample)


def request(id, title, place, cards, sample):
    return task(id, 45, title, f'{place}: Bitten Sie um diese Dinge und reagieren Sie.',
                ('Goethe A1 Sprechen Teil 3: her şey için kibarca rica et, sonra cevap ver.',
                 'Goethe A1 Sprechen part 3: ask politely for each thing, then react.'),
                [PLEASE, REACT] + cards, sample)


TASKS = [
    task('a1-7', 40, ('Adını hecele, numaranı söyle', 'Spell your name, say your number'),
         'Buchstabieren Sie Ihren Namen und sagen Sie Ihre Telefonnummer.',
         ('Adını ve soyadını harf harf söyle, telefon numaranı ve adresini söyle.',
          'Spell your first and last name, say your phone number and address.'),
         [p('Ad ve soyad', 'Name', 'Mein Name ist … Mein Nachname ist …', 'mein name', 'ich heiße', 'nachname', 'vorname'),
          p('Heceleme', 'Spelling', 'Ich buchstabiere: E – L – I – F', 'buchstabiere', 'buchstabieren'),
          p('Telefon', 'Phone number', 'Meine Telefonnummer ist …', 'telefonnummer', 'handynummer', 'nummer'),
          p('Adres', 'Address', 'Ich wohne in der …straße …', 'straße', 'adresse', 'ich wohne')],
         'Mein Name ist Elif Yılmaz. Ich buchstabiere: E – L – I – F. Mein Nachname ist Y – I – L – M – A – Z. '
         'Meine Telefonnummer ist null eins sieben sechs, zwei drei vier, fünf sechs sieben. '
         'Ich wohne in der Bergstraße zwölf in Köln.'),
    topic('a1-8', ('Kartlar: Yemek ve içecek', 'Cards: food and drink'), 'Essen und Trinken',
          [card('Kahvaltı', 'Breakfast', 'Was isst du zum Frühstück?', 'frühstück'),
           card('Et', 'Meat', 'Isst du gern Fleisch?', 'fleisch'),
           card('Kahve', 'Coffee', 'Trinkst du Kaffee?', 'kaffee'),
           card('Akşam yemeği', 'Dinner', 'Wann isst du zu Abend?', 'abend', 'abendessen')],
          'Was isst du zum Frühstück? Ich esse Brot mit Käse. Isst du gern Fleisch? Nein, ich esse lieber Gemüse. '
          'Trinkst du Kaffee? Ja, ich trinke jeden Morgen zwei Tassen Kaffee. Wann isst du zu Abend? Ich esse um sieben Uhr.'),
    topic('a1-9', ('Kartlar: Ev', 'Cards: home'), 'Wohnen',
          [card('Oda', 'Room', 'Wie viele Zimmer hat deine Wohnung?', 'zimmer'),
           card('Mutfak', 'Kitchen', 'Ist deine Küche groß?', 'küche'),
           card('Kira', 'Rent', 'Wie hoch ist die Miete?', 'miete'),
           card('Balkon', 'Balcony', 'Hast du einen Balkon?', 'balkon')],
          'Wie viele Zimmer hat deine Wohnung? Meine Wohnung hat drei Zimmer. Ist deine Küche groß? Nein, sie ist klein. '
          'Wie hoch ist die Miete? Die Miete ist achthundert Euro. Hast du einen Balkon? Ja, ich habe einen kleinen Balkon.'),
    topic('a1-10', ('Kartlar: Boş zaman', 'Cards: free time'), 'Freizeit',
          [card('Spor', 'Sport', 'Machst du Sport?', 'sport'),
           card('Sinema', 'Cinema', 'Gehst du gern ins Kino?', 'kino'),
           card('Müzik', 'Music', 'Welche Musik hörst du?', 'musik'),
           card('Hafta sonu', 'Weekend', 'Was machst du am Wochenende?', 'wochenende')],
          'Machst du Sport? Ja, ich spiele zweimal pro Woche Fußball. Gehst du gern ins Kino? Ja, sehr gern. '
          'Welche Musik hörst du? Ich höre Popmusik. Was machst du am Wochenende? Am Wochenende treffe ich Freunde.'),
    topic('a1-11', ('Kartlar: Alışveriş', 'Cards: shopping'), 'Einkaufen',
          [card('Süpermarket', 'Supermarket', 'Wo kaufst du ein?', 'supermarkt', 'einkaufen', 'kaufst'),
           card('Fiyat', 'Price', 'Was kostet ein Kilo Äpfel?', 'kostet', 'preis'),
           card('Giysi', 'Clothes', 'Wo kaufst du Kleidung?', 'kleidung', 'hose', 'jacke'),
           card('Gün', 'Day', 'Wann gehst du einkaufen?', 'wann')],
          'Wo kaufst du ein? Ich kaufe im Supermarkt ein. Was kostet ein Kilo Äpfel? Ein Kilo kostet zwei Euro. '
          'Wo kaufst du Kleidung? Ich kaufe Kleidung online. Wann gehst du einkaufen? Ich gehe am Samstag einkaufen.'),
    topic('a1-12', ('Kartlar: İş ve okul', 'Cards: work and school'), 'Arbeit und Schule',
          [card('Meslek', 'Job', 'Was bist du von Beruf?', 'beruf'),
           card('İş saati', 'Working hours', 'Wann beginnt deine Arbeit?', 'arbeit', 'beginnt'),
           card('Meslektaş', 'Colleagues', 'Wie sind deine Kollegen?', 'kollegen', 'kollege', 'kollegin'),
           card('Kurs', 'Course', 'Wann hast du Deutschkurs?', 'kurs')],
          'Was bist du von Beruf? Ich bin Krankenpfleger. Wann beginnt deine Arbeit? Meine Arbeit beginnt um sieben Uhr. '
          'Wie sind deine Kollegen? Meine Kollegen sind sehr nett. Wann hast du Deutschkurs? Ich habe am Montag und Mittwoch Kurs.'),
    topic('a1-13', ('Kartlar: Yolculuk', 'Cards: travel'), 'Reisen und Verkehr',
          [card('Otobüs', 'Bus', 'Fährst du mit dem Bus?', 'bus'),
           card('Bilet', 'Ticket', 'Wo kaufst du die Fahrkarte?', 'fahrkarte', 'ticket'),
           card('Tatil', 'Holiday', 'Wohin fährst du im Urlaub?', 'urlaub'),
           card('Tren', 'Train', 'Fährst du gern Zug?', 'zug')],
          'Fährst du mit dem Bus zur Arbeit? Nein, ich fahre mit dem Fahrrad. Wo kaufst du die Fahrkarte? Am Automaten. '
          'Wohin fährst du im Urlaub? Ich fahre in die Türkei. Fährst du gern Zug? Ja, Zug fahren ist bequem.'),
    topic('a1-14', ('Kartlar: Aile ve arkadaşlar', 'Cards: family and friends'), 'Familie und Freunde',
          [card('Kardeş', 'Siblings', 'Hast du Geschwister?', 'geschwister', 'bruder', 'schwester'),
           card('Ebeveynler', 'Parents', 'Wo wohnen deine Eltern?', 'eltern'),
           card('Doğum günü', 'Birthday', 'Wann hast du Geburtstag?', 'geburtstag'),
           card('Arkadaş', 'Friend', 'Wer ist dein bester Freund?', 'freund', 'freundin')],
          'Hast du Geschwister? Ja, ich habe eine Schwester. Wo wohnen deine Eltern? Meine Eltern wohnen in Izmir. '
          'Wann hast du Geburtstag? Ich habe im Mai Geburtstag. Wer ist dein bester Freund? Mein bester Freund heißt Murat.'),
    topic('a1-15', ('Kartlar: Sağlık', 'Cards: health'), 'Gesundheit',
          [card('Doktor', 'Doctor', 'Wann gehst du zum Arzt?', 'arzt', 'ärztin', 'doktor'),
           card('Baş ağrısı', 'Headache', 'Was machst du bei Kopfschmerzen?', 'kopfschmerzen', 'kopf'),
           card('Uyku', 'Sleep', 'Wie lange schläfst du?', 'schläfst', 'schlafen', 'schlafe'),
           card('Meyve', 'Fruit', 'Isst du viel Obst?', 'obst')],
          'Wann gehst du zum Arzt? Ich gehe zum Arzt, wenn ich krank bin. Was machst du bei Kopfschmerzen? Ich trinke Wasser und schlafe. '
          'Wie lange schläfst du? Ich schlafe sieben Stunden. Isst du viel Obst? Ja, ich esse jeden Tag einen Apfel.'),
    request('a1-16', ('Rica: Ofiste', 'Requests: at the office'), 'Im Büro',
            [p('Kalem', 'A pen', 'Können Sie mir bitte einen Stift geben?', 'stift', 'kuli', 'kugelschreiber'),
             p('Pencere', 'The window', 'Können Sie bitte das Fenster öffnen?', 'fenster'),
             p('Kahve', 'Coffee', 'Ich hätte gern einen Kaffee, bitte.', 'kaffee'),
             p('Telefon', 'Telephone', 'Darf ich kurz Ihr Telefon benutzen?', 'telefon')],
            'Entschuldigung, können Sie mir bitte einen Stift geben? Danke! Es ist so warm hier. Können Sie bitte das Fenster öffnen? '
            'Ich hätte gern einen Kaffee, bitte. Und darf ich kurz Ihr Telefon benutzen? – Ja, natürlich. – Vielen Dank!'),
    request('a1-17', ('Rica: Restoranda', 'Requests: at the restaurant'), 'Im Restaurant',
            [p('Menü', 'The menu', 'Kann ich bitte die Speisekarte haben?', 'speisekarte', 'karte'),
             p('Su', 'Water', 'Ich möchte ein Glas Wasser, bitte.', 'wasser'),
             p('Hesap', 'The bill', 'Die Rechnung, bitte.', 'rechnung', 'bezahlen', 'zahlen'),
             p('Peçete', 'A napkin', 'Haben Sie eine Serviette?', 'serviette')],
            'Guten Abend! Kann ich bitte die Speisekarte haben? Ich möchte ein Glas Wasser und eine Suppe, bitte. '
            'Haben Sie noch eine Serviette? Danke! … Die Rechnung, bitte. Ich möchte mit Karte bezahlen.'),
    request('a1-18', ('Rica: İstasyonda', 'Requests: at the station'), 'Am Bahnhof',
            [p('Bilet', 'A ticket', 'Eine Fahrkarte nach Berlin, bitte.', 'fahrkarte', 'ticket'),
             p('Peron', 'The platform', 'Von welchem Gleis fährt der Zug?', 'gleis'),
             p('Saat', 'The time', 'Wann fährt der nächste Zug?', 'wann', 'zug'),
             p('Yardım', 'Help with a bag', 'Können Sie mir bitte mit dem Koffer helfen?', 'koffer', 'helfen')],
            'Guten Tag, eine Fahrkarte nach Berlin, bitte. Wann fährt der nächste Zug? Und von welchem Gleis fährt er? '
            'Können Sie mir bitte mit dem Koffer helfen? Er ist sehr schwer. – Ja, gern. – Danke schön!'),
    request('a1-19', ('Rica: Komşuya', 'Requests: to a neighbour'), 'Beim Nachbarn',
            [p('Tuz', 'Salt', 'Hast du vielleicht Salz für mich?', 'salz'),
             p('Merdiven', 'A ladder', 'Kannst du mir deine Leiter leihen?', 'leiter'),
             p('Paket', 'A parcel', 'Kannst du mein Paket annehmen?', 'paket'),
             p('Çiçekler', 'The flowers', 'Kannst du am Wochenende meine Blumen gießen?', 'blumen', 'gießen')],
            'Hallo, ich koche gerade. Hast du vielleicht Salz für mich? Danke! Kannst du mir morgen deine Leiter leihen? '
            'Und kannst du mein Paket annehmen? Ich bin am Freitag nicht da. Kannst du am Wochenende meine Blumen gießen? – Ja klar, kein Problem!'),
    request('a1-20', ('Rica: Kursta', 'Requests: in class'), 'Im Deutschkurs',
            [p('Tekrar', 'Repeat', 'Können Sie das bitte wiederholen?', 'wiederholen', 'noch einmal', 'nochmal'),
             p('Yavaş', 'Slowly', 'Können Sie bitte langsamer sprechen?', 'langsam'),
             p('Sözlük', 'A dictionary', 'Darf ich Ihr Wörterbuch benutzen?', 'wörterbuch'),
             p('Yazmak', 'Write it', 'Können Sie das Wort an die Tafel schreiben?', 'schreiben', 'tafel')],
            'Entschuldigung, können Sie das bitte wiederholen? Und können Sie bitte langsamer sprechen? '
            'Darf ich Ihr Wörterbuch benutzen? Können Sie das Wort an die Tafel schreiben? – Natürlich, gern. – Vielen Dank!'),
]

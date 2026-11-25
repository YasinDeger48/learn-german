"""The learning path (Yol): units per level, each a real-life situation in six steps.

    python -I -X utf8 tools/units.py          -> Resources/content/units.json

A unit points at content that already exists: word themes (a1.json), grammar topics, daily texts,
speaking and writing tasks. Only the five key phrases per unit are written here.
cover: picture name (Resources/Covers or the website's covers/, e.g. unit-a1-03); until it exists the app
uses the cover of the unit's first text.
"""
import json
import os

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(REPO, 'Resources', 'content', 'units.json')


def ph(de, tr, en):
    return {'de': de, 'tr': tr, 'en': en}


def unit(n, title, goal, themes, grammar, texts, speaking, writing, phrases):
    return {'id': f'a1-{n:02d}', 'level': 'A1', 'number': n, 'title': {'tr': title[0], 'en': title[1]},
            'goal': {'tr': goal[0], 'en': goal[1]}, 'cover': f'unit-a1-{n:02d}', 'themes': themes, 'grammar': grammar,
            'texts': [f'a1-{t:03d}' for t in texts], 'speaking': speaking, 'writing': writing, 'phrases': phrases}


UNITS = [
    unit(1, ('Merhaba, ben …', 'Hello, I am …'),
         ('Kendini tanıtır, adını heceler, nereden geldiğini söylersin.', 'Introduce yourself, spell your name, say where you are from.'),
         [0, 2], [1, 2], [10, 29, 60], ['a1-1', 'a1-7'], ['a1-f1'],
         [ph('Hallo, ich heiße Elif.', 'Merhaba, benim adım Elif.', 'Hello, my name is Elif.'),
          ph('Ich komme aus der Türkei.', 'Türkiye\'denim.', 'I come from Turkey.'),
          ph('Ich wohne in Köln.', 'Köln\'de oturuyorum.', 'I live in Cologne.'),
          ph('Wie heißen Sie?', 'Adınız ne?', 'What is your name?'),
          ph('Freut mich!', 'Memnun oldum!', 'Nice to meet you!')]),
    unit(2, ('Ailem', 'My family'),
         ('Aileni anlatır, yaşları ve meslekleri söylersin.', 'Talk about your family, ages and jobs.'),
         [1], [9, 4], [8, 34, 47], ['a1-2', 'a1-14'], ['a1-m2'],
         [ph('Das ist meine Mutter.', 'Bu benim annem.', 'This is my mother.'),
          ph('Ich habe einen Bruder und eine Schwester.', 'Bir erkek ve bir kız kardeşim var.', 'I have a brother and a sister.'),
          ph('Mein Vater ist 58 Jahre alt.', 'Babam 58 yaşında.', 'My father is 58 years old.'),
          ph('Bist du verheiratet?', 'Evli misin?', 'Are you married?'),
          ph('Wir haben zwei Kinder.', 'İki çocuğumuz var.', 'We have two children.')]),
    unit(3, ('Yemek ve içmek', 'Food and drink'),
         ('Restoranda sipariş verir, ne sevdiğini söylersin.', 'Order in a restaurant and say what you like.'),
         [4], [6, 21], [14, 7, 23, 39], ['a1-8', 'a1-17'], ['a1-m5'],
         [ph('Ich hätte gern einen Kaffee.', 'Bir kahve alabilir miyim?', "I'd like a coffee."),
          ph('Was möchten Sie trinken?', 'Ne içmek istersiniz?', 'What would you like to drink?'),
          ph('Ich esse gern Fisch.', 'Balık yemeyi severim.', 'I like eating fish.'),
          ph('Die Rechnung, bitte.', 'Hesap, lütfen.', 'The bill, please.'),
          ph('Guten Appetit!', 'Afiyet olsun!', 'Enjoy your meal!')]),
    unit(4, ('Alışveriş', 'Shopping'),
         ('Fiyat sorar, beden ve renk söyler, alışveriş yaparsın.', 'Ask prices, say sizes and colours, buy things.'),
         [5], [5, 11], [4, 20, 31, 45, 49], ['a1-4', 'a1-11'], [],
         [ph('Was kostet das?', 'Bu ne kadar?', 'How much is this?'),
          ph('Haben Sie das in Größe M?', 'Bunun M bedeni var mı?', 'Do you have this in size M?'),
          ph('Ich nehme die blaue Jacke.', 'Mavi ceketi alıyorum.', "I'll take the blue jacket."),
          ph('Kann ich mit Karte bezahlen?', 'Kartla ödeyebilir miyim?', 'Can I pay by card?'),
          ph('Ich brauche keine Tüte.', 'Poşete ihtiyacım yok.', "I don't need a bag.")]),
    unit(5, ('Evim', 'My home'),
         ('Evini ve odalarını anlatır, bir sorunu bildirirsin.', 'Describe your home and rooms, report a problem.'),
         [6], [18, 7], [2, 25, 38, 55, 18], ['a1-6', 'a1-9', 'a1-19'], ['a1-m3'],
         [ph('Meine Wohnung hat drei Zimmer.', 'Evim üç odalı.', 'My flat has three rooms.'),
          ph('Die Küche ist klein, aber hell.', 'Mutfak küçük ama aydınlık.', 'The kitchen is small but bright.'),
          ph('Das Sofa steht im Wohnzimmer.', 'Kanepe oturma odasında duruyor.', 'The sofa is in the living room.'),
          ph('Die Heizung ist kaputt.', 'Kalorifer bozuk.', 'The heating is broken.'),
          ph('Wie hoch ist die Miete?', 'Kira ne kadar?', 'How much is the rent?')]),
    unit(6, ('Günüm ve saatler', 'My day and the time'),
         ('Saati söyler, günlük rutinini ve randevularını anlatırsın.', 'Tell the time, talk about your day and appointments.'),
         [3], [19, 13, 17], [32, 53, 3], ['a1-3'], ['a1-f3'],
         [ph('Wie spät ist es?', 'Saat kaç?', 'What time is it?'),
          ph('Es ist halb acht.', 'Saat yedi buçuk.', "It's half past seven."),
          ph('Ich stehe um sechs Uhr auf.', 'Saat altıda kalkıyorum.', 'I get up at six.'),
          ph('Am Montag habe ich einen Termin.', 'Pazartesi bir randevum var.', 'I have an appointment on Monday.'),
          ph('Hast du heute Abend Zeit?', 'Bu akşam vaktin var mı?', 'Are you free tonight?')]),
    unit(7, ('Şehirde yol bulmak', 'Finding your way in town'),
         ('Yol sorar, yön tarif eder, toplu taşımayı kullanırsın.', 'Ask the way, give directions, use public transport.'),
         [7], [14, 18], [35, 22, 1], ['a1-13'], ['a1-m4'],
         [ph('Entschuldigung, wo ist der Bahnhof?', 'Affedersiniz, tren istasyonu nerede?', 'Excuse me, where is the station?'),
          ph('Gehen Sie geradeaus und dann links.', 'Düz gidin, sonra sola dönün.', 'Go straight on and then left.'),
          ph('Die Apotheke ist neben der Bank.', 'Eczane bankanın yanında.', 'The pharmacy is next to the bank.'),
          ph('Ich nehme die U-Bahn.', 'Metroya biniyorum.', "I'm taking the underground."),
          ph('Wie weit ist es?', 'Ne kadar uzak?', 'How far is it?')]),
    unit(8, ('Doktorda', 'At the doctor'),
         ('Nerenin ağrıdığını söyler, randevu alırsın.', 'Say what hurts and make an appointment.'),
         [10], [12], [6, 43, 26, 57], ['a1-15'], ['a1-m1'],
         [ph('Ich habe Kopfschmerzen.', 'Başım ağrıyor.', 'I have a headache.'),
          ph('Mir ist schlecht.', 'Midem bulanıyor.', 'I feel sick.'),
          ph('Ich brauche einen Termin.', 'Bir randevuya ihtiyacım var.', 'I need an appointment.'),
          ph('Sie müssen im Bett bleiben.', 'Yatakta kalmanız gerekiyor.', 'You have to stay in bed.'),
          ph('Gute Besserung!', 'Geçmiş olsun!', 'Get well soon!')]),
    unit(9, ('İş ve kurs', 'Work and class'),
         ('Mesleğini ve çalışma saatlerini anlatır, kursta yardım istersin.', 'Talk about your job and hours, ask for help in class.'),
         [8], [10, 20], [19, 44, 36, 40, 16], ['a1-12', 'a1-16', 'a1-20'], ['a1-f4'],
         [ph('Ich arbeite als Krankenpfleger.', 'Hemşire olarak çalışıyorum.', 'I work as a nurse.'),
          ph('Meine Arbeit beginnt um acht.', 'İşim sekizde başlıyor.', 'My work starts at eight.'),
          ph('Können Sie das bitte wiederholen?', 'Tekrar edebilir misiniz?', 'Could you repeat that, please?'),
          ph('Ich habe heute frei.', 'Bugün izinliyim.', "I'm off today."),
          ph('Wie schreibt man das?', 'Bu nasıl yazılır?', 'How do you spell that?')]),
    unit(10, ('Boş zaman', 'Free time'),
         ('Hobilerini anlatır, hafta sonu için plan yaparsın.', 'Talk about hobbies and make weekend plans.'),
         [9, 11], [15], [5, 13, 27, 37, 30, 21, 52, 33], ['a1-10', 'a1-5'], ['a1-m4'],
         [ph('Am Wochenende spiele ich Fußball.', 'Hafta sonu futbol oynuyorum.', 'At the weekend I play football.'),
          ph('Ich lese gern Bücher.', 'Kitap okumayı severim.', 'I like reading books.'),
          ph('Wollen wir ins Kino gehen?', 'Sinemaya gidelim mi?', 'Shall we go to the cinema?'),
          ph('Gestern habe ich einen Film gesehen.', 'Dün bir film izledim.', 'Yesterday I watched a film.'),
          ph('Das Wetter ist heute schön.', 'Bugün hava güzel.', 'The weather is nice today.')]),
    unit(11, ('Yolculuk', 'Travelling'),
         ('Bilet alır, otel ayırtır, yolculuğunu anlatırsın.', 'Buy a ticket, book a hotel, talk about your trip.'),
         [7], [16], [9, 17, 42, 46, 58], ['a1-18'], ['a1-m6', 'a1-f2'],
         [ph('Eine Fahrkarte nach Berlin, bitte.', 'Berlin\'e bir bilet, lütfen.', 'A ticket to Berlin, please.'),
          ph('Wann fährt der nächste Zug?', 'Sonraki tren ne zaman kalkıyor?', 'When does the next train leave?'),
          ph('Ich habe ein Zimmer reserviert.', 'Bir oda ayırttım.', 'I have booked a room.'),
          ph('Der Urlaub war super.', 'Tatil harikaydı.', 'The holiday was great.'),
          ph('Von welchem Gleis fährt der Zug?', 'Tren hangi perondan kalkıyor?', 'Which platform does the train leave from?')]),
    unit(12, ('Resmî işler', 'Offices and services'),
         ('Belediyede, bankada ve postanede işini halledersin.', 'Get things done at the town hall, the bank and the post office.'),
         [14], [22, 8], [28, 41, 11, 15, 56, 50, 51, 48], ['a1-7'], ['a1-f1'],
         [ph('Ich möchte mich anmelden.', 'Adres kaydı yaptırmak istiyorum.', 'I would like to register.'),
          ph('Welche Unterlagen brauche ich?', 'Hangi belgelere ihtiyacım var?', 'Which documents do I need?'),
          ph('Wo muss ich unterschreiben?', 'Nereyi imzalamam gerekiyor?', 'Where do I have to sign?'),
          ph('Ich möchte ein Paket abholen.', 'Bir paket almak istiyorum.', 'I would like to pick up a parcel.'),
          ph('Haben Sie einen Termin?', 'Randevunuz var mı?', 'Do you have an appointment?')]),
]


# A2: one unit per text topic of daily_a2.json (6 texts each). A2 words are not grouped by situation,
# so a unit's words come from the glossaries of its texts ("vocab").
def unit2(n, topic, title, goal, grammar, speaking, phrases):
    return {'id': f'a2-{n:02d}', 'level': 'A2', 'number': n, 'title': {'tr': title[0], 'en': title[1]},
            'goal': {'tr': goal[0], 'en': goal[1]}, 'cover': f'unit-a2-{n:02d}', 'themes': [], 'grammar': grammar,
            'topic': topic, 'texts': [], 'speaking': speaking, 'writing': [f'a2-m{n}'], 'phrases': phrases}


UNITS_A2 = [
    unit2(1, 'Alltag', ('Günlük hayat', 'Everyday life'),
          ('Dün ne yaptığını Perfekt ile anlatır, günlük işlerini sıralarsın.', 'Tell what you did yesterday in the Perfekt and describe your routine.'),
          [4, 6], ['a2-3'],
          [ph('Gestern bin ich früh aufgestanden.', 'Dün erken kalktım.', 'Yesterday I got up early.'),
           ph('Ich habe den ganzen Tag gearbeitet.', 'Bütün gün çalıştım.', 'I worked all day.'),
           ph('Am Abend räume ich die Küche auf.', 'Akşam mutfağı topluyorum.', 'In the evening I tidy up the kitchen.'),
           ph('Was hast du am Wochenende gemacht?', 'Hafta sonu ne yaptın?', 'What did you do at the weekend?'),
           ph('Ich kaufe noch schnell Brot ein.', 'Bir de hızlıca ekmek alıyorum.', "I'll just quickly buy some bread.")]),
    unit2(2, 'Wohnen', ('Evde ve komşularla', 'At home and with neighbours'),
          ('Eşyaların nerede durduğunu ve nereye koyduğunu söyler, komşunla konuşursun.', 'Say where things are and where you put them, talk to your neighbours.'),
          [2, 3], ['a2-6'],
          [ph('Das Bild hängt über dem Sofa.', 'Resim kanepenin üstünde asılı.', 'The picture hangs above the sofa.'),
           ph('Ich stelle den Tisch ans Fenster.', 'Masayı pencerenin önüne koyuyorum.', "I'm putting the table by the window."),
           ph('Unsere Nachbarn sind sehr nett.', 'Komşularımız çok iyi.', 'Our neighbours are very nice.'),
           ph('Kannst du bitte leiser sein?', 'Biraz daha sessiz olabilir misin?', 'Can you be a bit quieter, please?'),
           ph('Die Wohnung liegt im dritten Stock.', 'Daire üçüncü katta.', 'The flat is on the third floor.')]),
    unit2(3, 'Einkaufen', ('Alışveriş ve değişim', 'Shopping and returns'),
          ('Ne istediğini sıfatlarla anlatır, bir ürünü değiştirir ya da iade edersin.', 'Describe what you want with adjectives, exchange or return a product.'),
          [8, 13], ['a2-2'],
          [ph('Ich suche einen warmen Pullover.', 'Sıcak bir kazak arıyorum.', "I'm looking for a warm jumper."),
           ph('Kann ich das umtauschen?', 'Bunu değiştirebilir miyim?', 'Can I exchange this?'),
           ph('Die Hose ist leider zu klein.', 'Pantolon maalesef çok küçük.', 'Unfortunately the trousers are too small.'),
           ph('Haben Sie den Kassenbon noch?', 'Fişiniz duruyor mu?', 'Do you still have the receipt?'),
           ph('Ich nehme die rote Tasche.', 'Kırmızı çantayı alıyorum.', "I'll take the red bag.")]),
    unit2(4, 'Mobilität', ('Yolda', 'On the move'),
          ('Ulaşımla ilgili sorunu anlatır, yol tarif eder ve sorarsın.', 'Explain a problem on the way, ask for and give directions.'),
          [1, 15], ['a2-1'],
          [ph('Der Zug hat zwanzig Minuten Verspätung.', 'Trenin yirmi dakika rötarı var.', 'The train is twenty minutes late.'),
           ph('Ich fahre mit dem Fahrrad zur Arbeit.', 'İşe bisikletle gidiyorum.', 'I cycle to work.'),
           ph('Steigen Sie an der nächsten Haltestelle aus.', 'Bir sonraki durakta inin.', 'Get off at the next stop.'),
           ph('Ich habe meinen Anschluss verpasst.', 'Aktarmamı kaçırdım.', 'I missed my connection.'),
           ph('Fahr bitte langsamer!', 'Lütfen daha yavaş sür!', 'Please drive more slowly!')]),
    unit2(5, 'Gesundheit', ('Sağlık', 'Health'),
          ('Nasıl hissettiğini anlatır, doktorun tavsiyelerini anlar ve aktarırsın.', 'Say how you feel, understand and pass on the doctor\'s advice.'),
          [10, 7], ['a2-4'],
          [ph('Ich fühle mich nicht gut.', 'Kendimi iyi hissetmiyorum.', "I don't feel well."),
           ph('Sie müssen dreimal am Tag eine Tablette nehmen.', 'Günde üç kez bir tablet almanız gerekiyor.', 'You have to take one tablet three times a day.'),
           ph('Ich muss mich ausruhen.', 'Dinlenmem gerekiyor.', 'I have to rest.'),
           ph('Seit wann haben Sie Fieber?', 'Ne zamandan beri ateşiniz var?', 'How long have you had a temperature?'),
           ph('Trinken Sie viel Wasser!', 'Bol su için!', 'Drink lots of water!')]),
    unit2(6, 'Arbeit', ('İş hayatı', 'Working life'),
          ('İşini ve nedenlerini anlatır, iş yerinde rica ve öneride bulunursun.', 'Talk about your job and give reasons, make requests and suggestions at work.'),
          [5, 9], ['a2-5'],
          [ph('Ich komme später, weil der Bus nicht fährt.', 'Otobüs çalışmadığı için geç geleceğim.', "I'll be late because the bus isn't running."),
           ph('Die Besprechung beginnt um zehn.', 'Toplantı onda başlıyor.', 'The meeting starts at ten.'),
           ph('Ich glaube, dass wir mehr Zeit brauchen.', 'Bence daha fazla zamana ihtiyacımız var.', 'I think that we need more time.'),
           ph('Könnten Sie mir bitte helfen?', 'Bana yardım edebilir misiniz lütfen?', 'Could you help me, please?'),
           ph('Ich arbeite gern im Team.', 'Ekipte çalışmayı severim.', 'I like working in a team.')]),
    unit2(7, 'Freizeit', ('Boş zaman ve anılar', 'Free time and memories'),
          ('Hobilerini ve çocukluğunu anlatır, wenn ve als ile ne zaman olduğunu söylersin.', 'Talk about hobbies and your childhood, say when with wenn and als.'),
          [14, 11], ['a2-1'],
          [ph('Als ich Kind war, habe ich viel gemalt.', 'Çocukken çok resim yapardım.', 'When I was a child I painted a lot.'),
           ph('Wenn das Wetter schön ist, gehen wir wandern.', 'Hava güzel olunca yürüyüşe gidiyoruz.', "When the weather is nice we go hiking."),
           ph('Ich spiele seit drei Jahren Gitarre.', 'Üç yıldır gitar çalıyorum.', "I've been playing the guitar for three years."),
           ph('Hast du Lust, mitzukommen?', 'Bizimle gelmek ister misin?', 'Do you feel like coming along?'),
           ph('Das Konzert war toll.', 'Konser harikaydı.', 'The concert was great.')]),
    unit2(8, 'Digitales', ('Dijital hayat', 'Digital life'),
          ('Telefon ve internetle ilgili sorunları anlatır, bir şeyi nasıl yapacağını sorarsın.', 'Describe problems with your phone and the internet, ask how to do something.'),
          [9, 8], ['a2-5'],
          [ph('Mein Handy funktioniert nicht mehr.', 'Telefonum artık çalışmıyor.', "My phone doesn't work any more."),
           ph('Ich schicke dir das Foto per Nachricht.', 'Fotoğrafı sana mesajla gönderiyorum.', "I'll send you the photo in a message."),
           ph('Weißt du, wie das WLAN-Passwort lautet?', 'Wi-Fi şifresinin ne olduğunu biliyor musun?', 'Do you know what the Wi-Fi password is?'),
           ph('Ich habe die App heruntergeladen.', 'Uygulamayı indirdim.', 'I have downloaded the app.'),
           ph('Der Akku ist fast leer.', 'Şarj neredeyse bitti.', 'The battery is almost empty.')]),
    unit2(9, 'Lernen', ('Öğrenmek', 'Learning'),
          ('Nasıl öğrendiğini ve planlarını anlatır, zu + mastar ile niyetini söylersin.', 'Talk about how you learn and your plans, say what you intend with zu + infinitive.'),
          [16], ['a2-5'],
          [ph('Ich versuche, jeden Tag zu lernen.', 'Her gün çalışmaya çalışıyorum.', 'I try to study every day.'),
           ph('Ich habe vergessen, die Hausaufgaben zu machen.', 'Ödevleri yapmayı unuttum.', 'I forgot to do the homework.'),
           ph('Was bedeutet dieses Wort?', 'Bu kelime ne demek?', 'What does this word mean?'),
           ph('Ich mache im Mai eine Prüfung.', 'Mayısta bir sınava gireceğim.', "I'm taking an exam in May."),
           ph('Es macht Spaß, neue Leute kennenzulernen.', 'Yeni insanlarla tanışmak eğlenceli.', 'It is fun to meet new people.')]),
    unit2(10, 'Umwelt', ('Çevre', 'The environment'),
          ('Çevre için ne yaptığını anlatır, şeyleri karşılaştırırsın.', 'Say what you do for the environment and compare things.'),
          [12], ['a2-6'],
          [ph('Ich trenne den Müll.', 'Çöpleri ayırıyorum.', 'I separate the rubbish.'),
           ph('Das Fahrrad ist besser als das Auto.', 'Bisiklet arabadan daha iyi.', 'The bike is better than the car.'),
           ph('Wir kaufen am liebsten regionales Gemüse.', 'En çok yöresel sebze almayı seviyoruz.', 'We prefer to buy local vegetables.'),
           ph('Bring die Flaschen bitte zum Container.', 'Şişeleri lütfen konteynere götür.', 'Please take the bottles to the container.'),
           ph('Im Park ist es am ruhigsten.', 'En sakin yer park.', 'It is quietest in the park.')]),
]


B1_WRITING = {1: 'b1-m1', 2: 'b1-m3', 3: 'b1-m2', 4: 'b1-m4', 5: 'b1-m5', 6: 'b1-m5', 7: 'b1-m4', 8: 'b1-m2', 9: 'b1-m5', 10: 'b1-m3', 11: 'b1-m6'}


# B1: daily_b1.json has many small topics, so a unit takes one or more of them.
def unit_b1(n, topics, title, goal, grammar, speaking, phrases):
    return {'id': f'b1-{n:02d}', 'level': 'B1', 'number': n, 'title': {'tr': title[0], 'en': title[1]},
            'goal': {'tr': goal[0], 'en': goal[1]}, 'cover': f'unit-b1-{n:02d}', 'themes': [], 'grammar': grammar,
            'topic': topics, 'texts': [], 'speaking': speaking, 'writing': [B1_WRITING[n]], 'phrases': phrases}


UNITS_B1 = [
    unit_b1(1, ['Wohnen', 'Nachbarschaft'], ('Ev ve mahalle', 'Home and neighbourhood'),
            ('Evini ve mahalleni ayrıntılı anlatır, komşularla sorunları çözersin.', 'Describe your home and area in detail, solve problems with neighbours.'),
            [6, 7], ['b1-6'],
            [ph('Das ist die Wohnung, die ich gemietet habe.', 'Bu, kiraladığım daire.', 'This is the flat that I rented.'),
             ph('Der Stadtteil, in dem ich wohne, ist sehr lebendig.', 'Oturduğum semt çok canlı.', 'The district I live in is very lively.'),
             ph('Könnten wir eine Lösung finden?', 'Bir çözüm bulabilir miyiz?', 'Could we find a solution?'),
             ph('Die Nebenkosten sind im letzten Jahr gestiegen.', 'Yan giderler geçen yıl arttı.', 'The extra costs went up last year.'),
             ph('Alles, was ich brauche, ist in der Nähe.', 'İhtiyacım olan her şey yakında.', 'Everything I need is nearby.')]),
    unit_b1(2, ['Arbeit'], ('İş ve kariyer', 'Work and career'),
            ('İş isteklerini nazikçe söyler, toplantıda soru sorar, görüş bildirirsin.', 'Make polite requests at work, ask questions in meetings, give your opinion.'),
            [1, 15], ['b1-5'],
            [ph('Ich würde gern im Homeoffice arbeiten.', 'Evden çalışmak isterdim.', 'I would like to work from home.'),
             ph('Könnten Sie mir sagen, wann das Meeting beginnt?', 'Toplantının ne zaman başladığını söyleyebilir misiniz?', 'Could you tell me when the meeting starts?'),
             ph('An Ihrer Stelle würde ich nachfragen.', 'Yerinizde olsam sorardım.', 'If I were you I would ask.'),
             ph('Ich weiß nicht, ob ich die Stelle bekomme.', 'İşi alıp alamayacağımı bilmiyorum.', "I don't know whether I'll get the job."),
             ph('Meiner Meinung nach ist das eine gute Idee.', 'Bence bu iyi bir fikir.', 'In my opinion that is a good idea.')]),
    unit_b1(3, ['Familie', 'Alltag'], ('Aile ve geçmiş', 'Family and the past'),
            ('Aileni ve geçmişte olanları sırayla anlatırsın.', 'Talk about your family and tell past events in order.'),
            [8, 9], ['b1-4'],
            [ph('Als Kind wohnte ich bei meinen Großeltern.', 'Çocukken büyükannemlerde otururdum.', 'As a child I lived with my grandparents.'),
             ph('Nachdem wir gegessen hatten, gingen wir spazieren.', 'Yemek yedikten sonra yürüyüşe çıktık.', 'After we had eaten we went for a walk.'),
             ph('Meine Schwester und ich verstehen uns gut.', 'Kız kardeşimle iyi anlaşırız.', 'My sister and I get on well.'),
             ph('Früher hatten wir keinen Fernseher.', 'Eskiden televizyonumuz yoktu.', "We didn't use to have a TV."),
             ph('Damals war alles ganz anders.', 'O zamanlar her şey bambaşkaydı.', 'Back then everything was very different.')]),
    unit_b1(4, ['Einkaufen', 'Konsum'], ('Alışveriş ve tüketim', 'Shopping and consumption'),
            ('Ürünleri karşılaştırır, şikâyet eder, tüketim üzerine görüş bildirirsin.', 'Compare products, complain, discuss consumption.'),
            [19, 11], ['b1-1'],
            [ph('Ich suche ein günstiges, aber gutes Handy.', 'Ucuz ama iyi bir telefon arıyorum.', "I'm looking for a cheap but good phone."),
             ph('Das Gerät ist nicht nur teuer, sondern auch schwer.', 'Cihaz hem pahalı hem de ağır.', 'The device is not only expensive but also heavy.'),
             ph('Entweder ich repariere es oder ich kaufe ein neues.', 'Ya tamir ettireceğim ya da yenisini alacağım.', 'Either I repair it or I buy a new one.'),
             ph('Ich möchte mich beschweren.', 'Şikâyette bulunmak istiyorum.', "I'd like to make a complaint."),
             ph('Online einzukaufen ist bequem, aber riskant.', 'İnternetten alışveriş rahat ama riskli.', 'Shopping online is convenient but risky.')]),
    unit_b1(5, ['Gesundheit'], ('Sağlık ve iyi yaşam', 'Health and well-being'),
            ('Şikâyetlerini ayrıntılı anlatır, tavsiye verir ve alırsın.', 'Describe symptoms in detail, give and take advice.'),
            [20, 16], ['b1-4'],
            [ph('Ich habe mir den Fuß verletzt.', 'Ayağımı incittim.', 'I have hurt my foot.'),
             ph('Ich lasse mich nächste Woche untersuchen.', 'Gelecek hafta muayene olacağım.', "I'm having a check-up next week."),
             ph('Du solltest mehr schlafen.', 'Daha çok uyumalısın.', 'You should sleep more.'),
             ph('Ich putze mir dreimal am Tag die Zähne.', 'Günde üç kez dişlerimi fırçalarım.', 'I brush my teeth three times a day.'),
             ph('Seitdem ich Sport mache, geht es mir besser.', 'Spor yaptığımdan beri daha iyiyim.', 'Since I started doing sport I feel better.')]),
    unit_b1(6, ['Behörden', 'Gesellschaft'], ('Resmî işler ve toplum', 'Offices and society'),
            ('Resmî süreçleri anlar ve anlatır, toplumsal konularda konuşursun.', 'Understand and explain official procedures, talk about society.'),
            [3, 4], ['b1-4'],
            [ph('Der Antrag wird in zwei Wochen bearbeitet.', 'Başvuru iki hafta içinde işleme alınır.', 'The application will be processed in two weeks.'),
             ph('Mein Pass wurde letztes Jahr verlängert.', 'Pasaportum geçen yıl uzatıldı.', 'My passport was renewed last year.'),
             ph('Welche Unterlagen muss ich einreichen?', 'Hangi belgeleri teslim etmem gerekiyor?', 'Which documents do I have to submit?'),
             ph('Das Formular ist schon ausgefüllt worden.', 'Form zaten doldurulmuş.', 'The form has already been filled in.'),
             ph('Ich hätte gern einen Termin beim Bürgeramt.', 'Vatandaşlık dairesinden bir randevu almak istiyorum.', "I'd like an appointment at the citizens' office.")]),
    unit_b1(7, ['Medien'], ('Medya', 'Media'),
            ('Haberleri ve sosyal medyayı tartışır, avantaj ve dezavantaj sayarsın.', 'Discuss news and social media, list pros and cons.'),
            [5, 10], ['b1-2'],
            [ph('Wegen des Streiks fallen viele Züge aus.', 'Grev yüzünden birçok tren iptal.', 'Because of the strike many trains are cancelled.'),
             ph('Die Nachrichten müssen kritisch gelesen werden.', 'Haberler eleştirel okunmalı.', 'The news must be read critically.'),
             ph('Trotz der Kritik nutzen viele soziale Medien.', 'Eleştirilere rağmen birçok kişi sosyal medya kullanıyor.', 'Despite the criticism many people use social media.'),
             ph('Ein Vorteil ist, dass man schnell informiert ist.', 'Bir avantajı, insanın hızlı bilgilenmesi.', 'One advantage is that you are informed quickly.'),
             ph('Während der Pause lese ich die Zeitung.', 'Mola sırasında gazete okurum.', 'During the break I read the newspaper.')]),
    unit_b1(8, ['Reisen', 'Verkehr'], ('Seyahat ve ulaşım', 'Travel and transport'),
            ('Bir yolculuğu planlar, sorunları anlatır, gelecek planlarını söylersin.', 'Plan a trip, explain problems, say what you will do.'),
            [12, 18], ['b1-3'],
            [ph('Obwohl es geregnet hat, war die Reise schön.', 'Yağmur yağmasına rağmen yolculuk güzeldi.', 'Although it rained the trip was nice.'),
             ph('Falls der Zug ausfällt, nehmen wir den Bus.', 'Tren iptal olursa otobüse bineriz.', 'If the train is cancelled we will take the bus.'),
             ph('Nächstes Jahr werde ich nach Portugal fahren.', 'Seneye Portekiz\'e gideceğim.', 'Next year I will go to Portugal.'),
             ph('Bevor wir losfahren, tanken wir.', 'Yola çıkmadan önce benzin alırız.', 'Before we set off we fill up.'),
             ph('Ich habe meinen Anschlusszug verpasst.', 'Aktarma trenimi kaçırdım.', 'I missed my connecting train.')]),
    unit_b1(9, ['Bildung'], ('Eğitim', 'Education'),
            ('Eğitim yolunu ve hedeflerini anlatır, amaç bildirirsin.', 'Talk about your education and goals, express purpose.'),
            [13, 14], ['b1-2'],
            [ph('Ich lerne Deutsch, um in Deutschland zu studieren.', 'Almanya\'da okumak için Almanca öğreniyorum.', "I'm learning German in order to study in Germany."),
             ph('Ich interessiere mich für Informatik.', 'Bilgisayar bilimine ilgi duyuyorum.', "I'm interested in computer science."),
             ph('Worauf freust du dich am meisten?', 'En çok neyi dört gözle bekliyorsun?', 'What are you looking forward to most?'),
             ph('Statt zu lernen, habe ich ferngesehen.', 'Ders çalışmak yerine televizyon izledim.', 'Instead of studying I watched TV.'),
             ph('Ich bereite mich auf die Prüfung vor.', 'Sınava hazırlanıyorum.', "I'm preparing for the exam.")]),
    unit_b1(10, ['Umwelt'], ('Çevre ve gelecek', 'Environment and the future'),
            ('Çevre sorunlarını tartışır, gerçek dışı durumlar hakkında konuşursun.', 'Discuss environmental problems and talk about unreal situations.'),
            [2, 17], ['b1-6'],
            [ph('Wenn alle weniger fliegen würden, wäre die Luft sauberer.', 'Herkes daha az uçsa hava daha temiz olurdu.', 'If everyone flew less the air would be cleaner.'),
             ph('Ich hätte gern ein Elektroauto.', 'Bir elektrikli arabam olsun isterdim.', "I'd like to have an electric car."),
             ph('Wir sollten mehr Energie sparen.', 'Daha çok enerji tasarrufu yapmalıyız.', 'We should save more energy.'),
             ph('Der Klimawandel betrifft uns alle.', 'İklim değişikliği hepimizi etkiliyor.', 'Climate change affects all of us.'),
             ph('Ich habe mit dem Nachbarn darüber gesprochen.', 'Komşuyla bunun hakkında konuştum.', 'I talked to the neighbour about it.')]),
    unit_b1(11, ['Freizeit', 'Kultur', 'Ehrenamt'], ('Boş zaman, kültür ve gönüllülük', 'Free time, culture and volunteering'),
            ('Etkinlikleri anlatır, birlikte plan yapar, gönüllülük üzerine konuşursun.', 'Talk about events, plan together and discuss volunteering.'),
            [8, 14], ['b1-3'],
            [ph('Am Wochenende helfe ich im Tierheim.', 'Hafta sonu hayvan barınağında yardım ediyorum.', 'At the weekend I help at the animal shelter.'),
             ph('Hast du Lust, mit ins Theater zu kommen?', 'Tiyatroya gelmek ister misin?', 'Do you feel like coming to the theatre?'),
             ph('Die Ausstellung hat mir sehr gut gefallen.', 'Sergi çok hoşuma gitti.', 'I liked the exhibition very much.'),
             ph('Wie wäre es mit Samstagabend?', 'Cumartesi akşamına ne dersin?', 'How about Saturday evening?'),
             ph('Ich engagiere mich im Sportverein.', 'Spor kulübünde gönüllü çalışıyorum.', "I'm involved in the sports club.")]),
]


B2_WRITING = {1: 'b2-m2', 2: 'b2-m1', 3: 'b2-m3', 4: 'b2-m1', 5: 'b2-m2', 6: 'b2-m1', 7: 'b2-m3', 8: 'b2-m3', 9: 'b2-m4', 10: 'b2-m4'}


def unit_b2(n, topics, title, goal, grammar, speaking, phrases):
    return {'id': f'b2-{n:02d}', 'level': 'B2', 'number': n, 'title': {'tr': title[0], 'en': title[1]},
            'goal': {'tr': goal[0], 'en': goal[1]}, 'cover': f'unit-b2-{n:02d}', 'themes': [], 'grammar': grammar,
            'topic': topics, 'texts': [], 'speaking': speaking, 'writing': [B2_WRITING[n]], 'phrases': phrases}


UNITS_B2 = [
    unit_b2(1, ['Arbeit', 'Arbeitswelt', 'Beruf'], ('Çalışma dünyası', 'The world of work'),
            ('Çalışma koşullarını tartışır, gerekçeli görüş bildirir, resmî dille konuşursun.', 'Discuss working conditions, argue your view and use formal language.'),
            [10, 12], ['b2-4'],
            [ph('Wir müssen eine Entscheidung treffen.', 'Bir karar vermemiz gerekiyor.', 'We have to make a decision.'),
             ph('Da die Aufträge zunehmen, brauchen wir mehr Personal.', 'Siparişler arttığı için daha fazla personele ihtiyacımız var.', 'As orders are increasing we need more staff.'),
             ph('Ich möchte das Thema zur Sprache bringen.', 'Bu konuyu gündeme getirmek istiyorum.', 'I would like to raise the subject.'),
             ph('Dennoch bin ich mit dem Ergebnis zufrieden.', 'Yine de sonuçtan memnunum.', "Nevertheless I'm happy with the result."),
             ph('Die Vier-Tage-Woche steht zur Diskussion.', 'Dört günlük çalışma haftası tartışılıyor.', 'The four-day week is under discussion.')]),
    unit_b2(2, ['Wohnen', 'Stadtentwicklung', 'Verkehr'], ('Şehir ve ulaşım', 'City and transport'),
            ('Şehir planlamasını ve ulaşımı tartışır, durumları ve olanakları anlatırsın.', 'Discuss urban planning and transport, describe states and possibilities.'),
            [3, 4], ['b2-1'],
            [ph('Die Straße ist seit Montag gesperrt.', 'Yol pazartesiden beri kapalı.', 'The road has been closed since Monday.'),
             ph('Das Problem lässt sich leicht lösen.', 'Sorun kolayca çözülebilir.', 'The problem can be solved easily.'),
             ph('Die Mieten sind kaum noch bezahlbar.', 'Kiralar artık neredeyse ödenemez halde.', 'Rents are hardly affordable any more.'),
             ph('Der Antrag ist bis Freitag einzureichen.', 'Başvuru cuma gününe kadar teslim edilmeli.', 'The application must be submitted by Friday.'),
             ph('Eine autofreie Innenstadt wäre lebenswerter.', 'Arabasız bir şehir merkezi daha yaşanabilir olurdu.', 'A car-free city centre would be more liveable.')]),
    unit_b2(3, ['Digitales', 'Technik'], ('Dijital dünya ve teknoloji', 'Digital world and technology'),
            ('Teknolojiyi ve etkilerini tartışır, bir şeyin nasıl yapıldığını açıklarsın.', 'Discuss technology and its effects, explain how something is done.'),
            [13, 5], ['b2-2'],
            [ph('Indem man Updates installiert, schützt man seine Daten.', 'Güncellemeleri yükleyerek verilerini korursun.', 'By installing updates you protect your data.'),
             ph('Die neu entwickelte App spart viel Zeit.', 'Yeni geliştirilen uygulama çok zaman kazandırıyor.', 'The newly developed app saves a lot of time.'),
             ph('Dadurch, dass alles digital ist, geht es schneller.', 'Her şey dijital olduğu için daha hızlı gidiyor.', 'Because everything is digital it is faster.'),
             ph('Künstliche Intelligenz verändert viele Berufe.', 'Yapay zekâ birçok mesleği değiştiriyor.', 'Artificial intelligence is changing many jobs.'),
             ph('Der Datenschutz wird oft unterschätzt.', 'Veri koruma çoğu zaman hafife alınıyor.', 'Data protection is often underestimated.')]),
    unit_b2(4, ['Medien'], ('Medya ve haberler', 'Media and news'),
            ('Haberleri dolaylı anlatımla aktarır, kaynakları eleştirel değerlendirirsin.', 'Report news in indirect speech and judge sources critically.'),
            [2], ['b2-2'],
            [ph('Der Minister sagte, er habe davon nichts gewusst.', 'Bakan bundan haberi olmadığını söyledi.', 'The minister said he had known nothing about it.'),
             ph('Laut Bericht sei die Lage stabil.', 'Rapora göre durum istikrarlıymış.', 'According to the report the situation is stable.'),
             ph('Man sollte Quellen immer überprüfen.', 'Kaynaklar her zaman kontrol edilmeli.', 'You should always check sources.'),
             ph('Die Zeitung berichtet ausführlich über den Streik.', 'Gazete grevi ayrıntılı haberleştiriyor.', 'The newspaper reports on the strike in detail.'),
             ph('Falschmeldungen verbreiten sich schnell.', 'Yalan haberler hızla yayılıyor.', 'Fake news spreads quickly.')]),
    unit_b2(5, ['Gesundheit', 'Familie'], ('Sağlık ve aile', 'Health and family'),
            ('Tahminde bulunur, olasılıkları dile getirir, sağlık konularını tartışırsın.', 'Make assumptions, express probability and discuss health topics.'),
            [6, 7], ['b2-4'],
            [ph('Er dürfte inzwischen zu Hause sein.', 'Şimdiye kadar evde olmalı.', 'He should be at home by now.'),
             ph('Sie muss sehr müde gewesen sein.', 'Çok yorgun olmuş olmalı.', 'She must have been very tired.'),
             ph('Bis nächstes Jahr wird sie ihr Studium abgeschlossen haben.', 'Seneye kadar okulunu bitirmiş olacak.', 'By next year she will have finished her studies.'),
             ph('Stress wirkt sich auf die Gesundheit aus.', 'Stres sağlığı etkiler.', 'Stress affects your health.'),
             ph('Familie und Beruf zu vereinbaren ist nicht leicht.', 'Aile ve işi bir arada yürütmek kolay değil.', 'Combining family and work is not easy.')]),
    unit_b2(6, ['Umwelt', 'Verbrauch', 'Konsum'], ('Çevre ve tüketim', 'Environment and consumption'),
            ('Tüketim alışkanlıklarını tartışır, koşul ve karşıtlık bildirirsin.', 'Discuss consumer habits and express conditions and contrasts.'),
            [14, 16], ['b2-1'],
            [ph('Sofern alle mitmachen, können wir viel erreichen.', 'Herkes katılırsa çok şey başarabiliriz.', 'Provided everyone joins in we can achieve a lot.'),
             ph('Während ich wenig kaufe, kauft mein Bruder ständig Neues.', 'Ben az alırken kardeşim sürekli yeni şeyler alıyor.', 'While I buy little, my brother keeps buying new things.'),
             ph('Statt neu zu kaufen, lasse ich Dinge reparieren.', 'Yenisini almak yerine eşyaları tamir ettiriyorum.', 'Instead of buying new I have things repaired.'),
             ph('Er fährt Auto, ohne dass es nötig ist.', 'Gerek olmadan araba kullanıyor.', 'He drives without it being necessary.'),
             ph('Nachhaltigkeit beginnt beim Einkaufen.', 'Sürdürülebilirlik alışverişte başlar.', 'Sustainability starts with shopping.')]),
    unit_b2(7, ['Gesellschaft', 'Ehrenamt', 'Recht und Alltag'], ('Toplum ve haklar', 'Society and rights'),
            ('Toplumsal konuları ve hakları tartışır, karmaşık cümleler kurarsın.', 'Discuss social issues and rights, build complex sentences.'),
            [19, 20], ['b2-2'],
            [ph('Wer sich engagiert, lernt viele Menschen kennen.', 'Gönüllü çalışan, birçok insanla tanışır.', 'Whoever gets involved meets lots of people.'),
             ph('Es ist wichtig, dass jeder seine Rechte kennt.', 'Herkesin haklarını bilmesi önemli.', 'It is important that everyone knows their rights.'),
             ph('Das ist etwas, worüber man sprechen sollte.', 'Bu, konuşulması gereken bir şey.', 'That is something one should talk about.'),
             ph('Die Frau, deren Auto beschädigt wurde, rief die Polizei.', 'Arabası hasar gören kadın polisi aradı.', 'The woman whose car was damaged called the police.'),
             ph('Ehrenamt stärkt den Zusammenhalt.', 'Gönüllülük dayanışmayı güçlendirir.', 'Volunteering strengthens cohesion.')]),
    unit_b2(8, ['Finanzen', 'Wirtschaft', 'Service', 'Verwaltung'], ('Para, hizmetler ve kurumlar', 'Money, services and institutions'),
            ('Bankada, kurumlarda ve müşteri hizmetlerinde resmî dille işini halledersin.', 'Deal with banks, offices and customer service in formal language.'),
            [11, 8], ['b2-6'],
            [ph('Aufgrund eines Fehlers wurde der Betrag doppelt abgebucht.', 'Bir hata nedeniyle tutar iki kez çekildi.', 'Due to an error the amount was debited twice.'),
             ph('Ich bitte um eine schriftliche Bestätigung.', 'Yazılı bir onay rica ediyorum.', 'I request written confirmation.'),
             ph('Hinsichtlich der Kosten habe ich noch eine Frage.', 'Masraflarla ilgili bir sorum daha var.', 'I have another question regarding the costs.'),
             ph('Die Bearbeitung dauert etwa zwei Wochen.', 'İşlem yaklaşık iki hafta sürer.', 'Processing takes about two weeks.'),
             ph('Ich möchte mein Konto kündigen.', 'Hesabımı kapatmak istiyorum.', 'I would like to close my account.')]),
    unit_b2(9, ['Bildung', 'Wissenschaft'], ('Eğitim ve bilim', 'Education and science'),
            ('Bilimsel sonuçları aktarır, eğitim üzerine tartışır, sunum yaparsın.', 'Report scientific results, discuss education and give presentations.'),
            [9, 18], ['b2-3'],
            [ph('Die Studie zeigt, dass Schlaf das Lernen verbessert.', 'Araştırma uykunun öğrenmeyi iyileştirdiğini gösteriyor.', 'The study shows that sleep improves learning.'),
             ph('Ich beschäftige mich seit Jahren mit diesem Thema.', 'Yıllardır bu konuyla ilgileniyorum.', "I have been working on this topic for years."),
             ph('Man ist nie zu alt, um etwas Neues zu lernen.', 'Yeni bir şey öğrenmek için asla çok yaşlı değilsin.', "You're never too old to learn something new."),
             ph('Die Ergebnisse hängen von vielen Faktoren ab.', 'Sonuçlar birçok faktöre bağlı.', 'The results depend on many factors.'),
             ph('Zusammenfassend lässt sich sagen, dass …', 'Özetle şunu söyleyebiliriz: …', 'In summary one can say that …')]),
    unit_b2(10, ['Kultur', 'Freizeit', 'Reisen', 'Alltag'], ('Kültür ve deneyimler', 'Culture and experiences'),
            ('Deneyimlerini ve pişmanlıklarını anlatır, karşılaştırmalar yaparsın.', 'Talk about experiences and regrets and make comparisons.'),
            [1, 15, 17], ['b2-5'],
            [ph('Hätte ich das gewusst, wäre ich früher gekommen.', 'Bunu bilseydim daha erken gelirdim.', 'If I had known that I would have come earlier.'),
             ph('Er tut so, als ob er alles wüsste.', 'Her şeyi biliyormuş gibi davranıyor.', 'He acts as if he knew everything.'),
             ph('Ich bin froh, die Reise gemacht zu haben.', 'Bu yolculuğu yapmış olduğuma seviniyorum.', "I'm glad to have made the trip."),
             ph('Die Ausstellung hat mich tief beeindruckt.', 'Sergi beni derinden etkiledi.', 'The exhibition impressed me deeply.'),
             ph('Das hätten wir besser planen sollen.', 'Bunu daha iyi planlamamız gerekirdi.', 'We should have planned that better.')]),
]


def fill_a2(units, level='a2'):
    """Texts of each unit's topic(s), and up to 18 words from their glossaries (nouns first)."""
    daily = json.load(open(os.path.join(REPO, 'Resources', 'content', f'daily_{level}.json'), encoding='utf-8'))['texts']
    for u in units:
        topic = u.pop('topic')
        topics = topic if isinstance(topic, list) else [topic]
        texts = [t for t in daily if t['topic'] in topics]
        assert len(texts) >= 3, (u['id'], topic)
        u['texts'] = [t['id'] for t in texts]
        seen, nouns, others = set(), [], []
        for t in texts:
            for g in t['glossary']:
                key = g['lemma'].lower()
                if key in seen or len(g['lemma']) > 24:
                    continue
                seen.add(key)
                item = {'de': g['lemma'], 'tr': g['mean']['tr'], 'en': g['mean']['en']}
                if g.get('art') in ('der', 'die', 'das'):
                    item = {'de': g['lemma'], 'art': g['art'], 'tr': g['mean']['tr'], 'en': g['mean']['en']}
                    nouns.append(item)
                else:
                    others.append(item)
        u['vocab'] = (nouns[:12] + others)[:18]
        assert len(u['vocab']) >= 12, u['id']


def main():
    import sys
    sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
    from word_pictures import PICTURE_WORDS
    for u in UNITS:
        u['pictures'] = PICTURE_WORDS.get(u['id'], [])
    a1 = json.load(open(os.path.join(REPO, 'Resources', 'content', 'a1.json'), encoding='utf-8'))
    themes = {t['id'] for t in a1['themes']}
    topics = {t['id'] for t in a1['grammar']}
    texts = {t['id'] for t in json.load(open(os.path.join(REPO, 'Resources', 'content', 'daily_a1.json'), encoding='utf-8'))['texts']}
    speaking = {t['id'] for t in json.load(open(os.path.join(REPO, 'Resources', 'content', 'speaking.json'), encoding='utf-8'))['tasks']}
    writing = {t['id'] for t in json.load(open(os.path.join(REPO, 'Resources', 'content', 'writing.json'), encoding='utf-8'))['tasks']}
    for u in UNITS:
        assert set(u['themes']) <= themes, u['id']
        assert set(u['grammar']) <= topics, u['id']
        assert set(u['texts']) <= texts, (u['id'], set(u['texts']) - texts)
        assert set(u['speaking']) <= speaking, u['id']
        assert set(u['writing']) <= writing, u['id']
        assert len(u['phrases']) == 5
        words = {w['id'] for w in a1['words']}
        assert set(u['pictures']) <= words, u['id']
    fill_a2(UNITS_A2)
    a2 = json.load(open(os.path.join(REPO, 'Resources', 'content', 'a2.json'), encoding='utf-8'))
    a2_topics = {t['id'] for t in a2['grammar']}
    for u in UNITS_A2:
        assert set(u['grammar']) <= a2_topics, u['id']
        assert set(u['writing']) <= writing, u['id']
        assert set(u['speaking']) <= speaking, u['id']
        assert len(u['phrases']) == 5
    fill_a2(UNITS_B1, 'b1')
    b1 = json.load(open(os.path.join(REPO, 'Resources', 'content', 'b1.json'), encoding='utf-8'))
    b1_topics = {t['id'] for t in b1['grammar']}
    for u in UNITS_B1:
        assert set(u['grammar']) <= b1_topics, u['id']
        assert set(u['writing']) <= writing, u['id']
        assert set(u['speaking']) <= speaking, u['id']
        assert len(u['phrases']) == 5
    fill_a2(UNITS_B2, 'b2')
    b2 = json.load(open(os.path.join(REPO, 'Resources', 'content', 'b2.json'), encoding='utf-8'))
    b2_topics = {t['id'] for t in b2['grammar']}
    for u in UNITS_B2:
        assert set(u['grammar']) <= b2_topics, u['id']
        assert set(u['writing']) <= writing, u['id']
        assert set(u['speaking']) <= speaking, u['id']
        assert len(u['phrases']) == 5
    with open(OUT, 'w', encoding='utf-8', newline='\n') as f:
        json.dump({'units': UNITS + UNITS_A2 + UNITS_B1 + UNITS_B2}, f, ensure_ascii=False, indent=1)
        f.write('\n')
    print(f'{len(UNITS)} A1 + {len(UNITS_A2)} A2 + {len(UNITS_B1)} B1 + {len(UNITS_B2)} B2 units -> {OUT}')


if __name__ == '__main__':
    main()

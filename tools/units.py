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


def main():
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
    with open(OUT, 'w', encoding='utf-8', newline='\n') as f:
        json.dump({'units': UNITS}, f, ensure_ascii=False, indent=1)
        f.write('\n')
    print(f'{len(UNITS)} units -> {OUT}')


if __name__ == '__main__':
    main()

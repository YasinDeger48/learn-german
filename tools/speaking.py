"""Builds Resources/content/speaking.json: the speaking tasks (Sprechen) for A1–B2.

    python -I -X utf8 tools/speaking.py

Each task: a prompt in German, a short help text, the points to talk about (with an example phrase and the
phrases the app listens for) and a sample answer the learner can listen to afterwards.
Point keys are matched after lower-casing, ß → ss and removing accents, at the start of a word.
"""
import json
import os
import sys

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(REPO, 'Resources', 'content', 'speaking.json')


def p(tr, en, say, *keys):
    return {'label': {'tr': tr, 'en': en}, 'say': say, 'keys': list(keys)}


def task(id, level, seconds, title, prompt, help, points, sample):
    return {'id': id, 'level': level, 'seconds': seconds, 'title': {'tr': title[0], 'en': title[1]},
            'prompt': prompt, 'help': {'tr': help[0], 'en': help[1]}, 'points': points, 'sample': sample}


# Reused points for B1/B2 presentations and opinions.
INTRO = p('Konuyu tanıt', 'Introduce the topic', 'Mein Thema ist …', 'mein thema', 'ich möchte', 'ich spreche über', 'heute spreche', 'in meinem vortrag', 'es geht um')
OWN = p('Kendi deneyimin', 'Your own experience', 'Ich persönlich habe …', 'ich persönlich', 'meine erfahrung', 'meiner erfahrung', 'ich selbst', 'bei mir', 'ich habe schon')
HOME = p('Ülkendeki durum', 'The situation in your country', 'In meinem Heimatland …', 'in meinem heimatland', 'in meinem land', 'in der türkei', 'bei uns', 'in meiner heimat')
PRO = p('Avantajlar', 'Advantages', 'Ein Vorteil ist, dass …', 'vorteil', 'positiv', 'dafür spricht', 'einerseits', 'gut ist')
CONTRA = p('Dezavantajlar', 'Disadvantages', 'Ein Nachteil ist, dass …', 'nachteil', 'negativ', 'dagegen spricht', 'andererseits', 'problem', 'schlecht ist')
OPINION = p('Görüşün ve sonuç', 'Your opinion and conclusion', 'Meiner Meinung nach …', 'meiner meinung', 'ich finde', 'ich bin der meinung', 'ich denke', 'zum schluss', 'abschließend', 'zusammenfassend')
EXAMPLE = p('Bir örnek ver', 'Give an example', 'Zum Beispiel …', 'zum beispiel', 'beispielsweise', 'etwa', 'ein beispiel')
REASON = p('Gerekçe söyle', 'Give a reason', '…, weil …', 'weil', 'denn', 'da ', 'deshalb', 'deswegen', 'aus diesem grund')

TASKS = [
    # ---------------- A1 ----------------
    task('a1-1', 'A1', 45, ('Kendini tanıt', 'Introduce yourself'), 'Stellen Sie sich bitte vor.',
         ('Adın, yaşın, nereden geldiğin, nerede yaşadığın, dillerin, mesleğin ve hobin.',
          'Your name, age, where you come from and live, languages, job and hobby.'),
         [p('Adın', 'Name', 'Ich heiße …', 'ich heiße', 'mein name ist', 'ich bin'),
          p('Yaşın', 'Age', 'Ich bin … Jahre alt.', 'jahre alt', 'jahre'),
          p('Nereden geldiğin', 'Country', 'Ich komme aus …', 'ich komme aus', 'komme aus'),
          p('Nerede yaşadığın', 'Where you live', 'Ich wohne in …', 'ich wohne', 'wohne in', 'lebe in'),
          p('Diller', 'Languages', 'Ich spreche …', 'ich spreche', 'spreche'),
          p('Meslek', 'Job', 'Ich arbeite als …', 'ich arbeite', 'von beruf', 'ich studiere', 'ich bin schüler', 'ich bin student', 'ich lerne'),
          p('Hobi', 'Hobby', 'Mein Hobby ist …', 'hobby', 'gern', 'spiele', 'lese', 'mag')],
         'Hallo! Ich heiße Elif. Ich bin achtundzwanzig Jahre alt. Ich komme aus der Türkei, aus Izmir. '
         'Jetzt wohne ich in Köln. Ich spreche Türkisch, Englisch und ein bisschen Deutsch. '
         'Ich arbeite als Krankenschwester. Mein Hobby ist Lesen, und ich koche sehr gern.'),
    task('a1-2', 'A1', 45, ('Ailem', 'My family'), 'Erzählen Sie über Ihre Familie.',
         ('Ailende kimler var, adları, yaşları, nerede yaşıyorlar, ne iş yapıyorlar?',
          'Who is in your family, their names, ages, where they live and what they do.'),
         [p('Aile üyeleri', 'Family members', 'Ich habe einen Bruder und …', 'ich habe', 'bruder', 'schwester', 'geschwister', 'eltern', 'mutter', 'vater', 'kinder'),
          p('İsimler', 'Names', 'Meine Mutter heißt …', 'heißt', 'heißen'),
          p('Yaşlar', 'Ages', 'Er ist … Jahre alt.', 'jahre alt', 'jahre'),
          p('Nerede yaşıyorlar', 'Where they live', 'Sie wohnen in …', 'wohnt', 'wohnen', 'lebt', 'leben'),
          p('Ne iş yapıyorlar', 'What they do', 'Mein Vater arbeitet als …', 'arbeitet', 'arbeiten', 'von beruf', 'studiert', 'geht zur schule', 'ist rentner', 'ist rentnerin')],
         'Meine Familie ist nicht groß. Meine Mutter heißt Ayşe, sie ist fünfundfünfzig Jahre alt. '
         'Mein Vater heißt Mehmet, er ist Rentner. Ich habe einen Bruder. Er heißt Can und ist zweiundzwanzig. '
         'Er studiert in Ankara. Meine Eltern wohnen in Bursa.'),
    task('a1-3', 'A1', 45, ('Günüm', 'My day'), 'Wie sieht Ihr Tag aus?',
         ('Kaçta kalkarsın, kahvaltı, iş/okul, öğle, akşam ne yaparsın?',
          'When you get up, breakfast, work or school, lunch and evening.'),
         [p('Kalkış saati', 'Getting up', 'Ich stehe um sieben Uhr auf.', 'stehe', 'aufstehen', 'auf'),
          p('Kahvaltı', 'Breakfast', 'Ich frühstücke …', 'frühstück', 'frühstücke'),
          p('Saat', 'Times', 'Um acht Uhr …', 'uhr'),
          p('İş veya okul', 'Work or school', 'Dann gehe ich zur Arbeit.', 'arbeit', 'arbeite', 'schule', 'kurs', 'uni', 'büro'),
          p('Akşam', 'Evening', 'Am Abend …', 'abend', 'abends')],
         'Ich stehe um halb sieben auf. Ich frühstücke Brot mit Käse und trinke Tee. '
         'Um acht Uhr fahre ich mit dem Bus zur Arbeit. Mittags esse ich in der Kantine. '
         'Um fünf Uhr gehe ich nach Hause. Am Abend koche ich, und dann sehe ich fern.'),
    task('a1-4', 'A1', 40, ('Alışverişte', 'Shopping'), 'Sie sind im Supermarkt. Fragen Sie nach Produkten und Preisen.',
         ('Bir şey iste, fiyatını sor, teşekkür et.', 'Ask for something, ask the price, say thank you.'),
         [p('Kibarca selam', 'Greet politely', 'Guten Tag!', 'guten tag', 'hallo', 'entschuldigung', 'guten morgen'),
          p('Bir şey iste', 'Ask for something', 'Ich möchte …', 'ich möchte', 'ich hätte gern', 'ich brauche', 'haben sie'),
          p('Fiyat sor', 'Ask the price', 'Was kostet …?', 'kostet', 'wie viel', 'wie teuer'),
          p('Miktar', 'Amount', 'ein Kilo, zwei Flaschen …', 'kilo', 'gramm', 'flasche', 'stück', 'packung', 'liter'),
          p('Teşekkür et', 'Say thank you', 'Danke schön!', 'danke', 'vielen dank')],
         'Guten Tag! Entschuldigung, haben Sie Tomaten? Ich möchte ein Kilo Tomaten und zwei Flaschen Wasser. '
         'Was kostet das Brot? Zwei Euro fünfzig? Gut, das nehme ich auch. Vielen Dank! Auf Wiedersehen!'),
    task('a1-5', 'A1', 45, ('Hafta sonum', 'My weekend'), 'Was machen Sie am Wochenende?',
         ('Cumartesi ve pazar ne yaparsın, kiminle, nerede?', 'What you do on Saturday and Sunday, with whom, where.'),
         [p('Cumartesi/Pazar', 'Saturday or Sunday', 'Am Samstag …', 'samstag', 'sonntag', 'wochenende'),
          p('Ne yapıyorsun', 'Activities', 'Ich gehe einkaufen / spazieren.', 'gehe', 'spiele', 'besuche', 'koche', 'schlafe', 'treffe', 'mache'),
          p('Kiminle', 'With whom', 'mit meiner Familie / mit Freunden', 'mit meiner', 'mit meinem', 'mit freunden', 'mit der familie', 'allein'),
          p('Ne seviyorsun', 'What you like', 'Ich … gern.', 'gern', 'mag', 'liebe')],
         'Am Samstag schlafe ich lange. Dann gehe ich mit meiner Freundin einkaufen. '
         'Am Abend treffe ich Freunde im Café. Am Sonntag besuche ich meine Familie. '
         'Wir essen zusammen und gehen im Park spazieren. Ich mag das Wochenende sehr.'),
    task('a1-6', 'A1', 40, ('Evim', 'My home'), 'Beschreiben Sie Ihre Wohnung.',
         ('Kaç oda var, nasıl, en sevdiğin yer neresi?', 'How many rooms, what they are like, your favourite place.'),
         [p('Ev / daire', 'Flat or house', 'Ich wohne in einer Wohnung.', 'wohnung', 'haus', 'zimmer'),
          p('Odalar', 'Rooms', 'Sie hat drei Zimmer.', 'zimmer', 'küche', 'bad', 'balkon', 'schlafzimmer', 'wohnzimmer'),
          p('Nasıl', 'What it is like', 'Die Küche ist klein, aber hell.', 'groß', 'klein', 'hell', 'schön', 'neu', 'alt', 'gemütlich'),
          p('En sevdiğin yer', 'Favourite place', 'Mein Lieblingsplatz ist …', 'lieblings', 'gefällt', 'mag')],
         'Ich wohne in einer kleinen Wohnung im zweiten Stock. Sie hat zwei Zimmer, eine Küche und ein Bad. '
         'Das Wohnzimmer ist hell und gemütlich. Die Küche ist klein, aber neu. '
         'Mein Lieblingsplatz ist der Balkon. Dort trinke ich morgens Kaffee.'),

    # ---------------- A2 ----------------
    task('a2-1', 'A2', 60, ('Son tatilim', 'My last holiday'), 'Erzählen Sie von Ihrem letzten Urlaub.',
         ('Nereye gittin, kiminle, ne yaptın, hava nasıldı, nasıl buldun? (Perfekt)',
          'Where you went, with whom, what you did, the weather, how you liked it. (Perfekt)'),
         [p('Nereye', 'Where', 'Ich bin nach … gefahren.', 'bin nach', 'gefahren', 'geflogen', 'war in', 'waren in'),
          p('Kiminle', 'With whom', 'mit meiner Familie', 'mit meiner', 'mit meinem', 'mit freunden', 'allein'),
          p('Ne yaptın', 'What you did', 'Wir haben … besucht.', 'besucht', 'gesehen', 'gemacht', 'gegessen', 'gebadet', 'geschwommen', 'gewandert'),
          p('Hava', 'Weather', 'Das Wetter war …', 'wetter', 'sonne', 'warm', 'heiß', 'regen', 'kalt'),
          p('Nasıl buldun', 'How you liked it', 'Es hat mir gut gefallen.', 'gefallen', 'war schön', 'war toll', 'super', 'wunderbar', 'nicht so gut')],
         'Letzten Sommer bin ich mit meiner Familie nach Antalya geflogen. Wir waren zehn Tage dort. '
         'Wir haben in einem kleinen Hotel am Meer gewohnt. Jeden Tag sind wir geschwommen, und abends haben wir Fisch gegessen. '
         'Das Wetter war sehr heiß, fast vierzig Grad. Einmal haben wir eine Bootstour gemacht. Der Urlaub hat mir sehr gut gefallen.'),
    task('a2-2', 'A2', 60, ('Yemek ve içecek', 'Food and drink'), 'Was essen und trinken Sie gern? Wie ist das in Ihrem Land?',
         ('Kahvaltı, en sevdiğin yemek, yemek yapıyor musun, ülkende ne yenir?',
          'Breakfast, your favourite dish, do you cook, what people eat in your country.'),
         [p('Kahvaltı', 'Breakfast', 'Zum Frühstück esse ich …', 'frühstück'),
          p('En sevdiğin yemek', 'Favourite food', 'Mein Lieblingsessen ist …', 'lieblingsessen', 'esse gern', 'mag', 'liebe'),
          p('Yemek yapmak', 'Cooking', 'Ich koche oft / selten.', 'koche', 'kochen', 'gekocht'),
          p('Ülkende', 'In your country', 'In meinem Land isst man …', 'in meinem land', 'bei uns', 'in der türkei', 'man isst', 'in meiner heimat'),
          p('Ne sıklıkla', 'How often', 'oft, manchmal, nie', 'oft', 'manchmal', 'selten', 'nie', 'jeden tag', 'immer')],
         'Zum Frühstück esse ich gern Brot, Oliven, Käse und Tomaten, und ich trinke schwarzen Tee. '
         'Mein Lieblingsessen ist Linsensuppe. Ich koche fast jeden Abend, am Wochenende auch für Freunde. '
         'In meinem Land isst man oft zusammen mit der ganzen Familie. Fast Food esse ich nur selten.'),
    task('a2-3', 'A2', 60, ('Birlikte plan yapın: doğum günü', 'Plan together: a birthday'), 'Ihr Freund hat Geburtstag. Planen Sie zusammen eine kleine Party.',
         ('Öneri yap, gün ve saat, yemek ve içecek, kabul et veya başka bir şey öner.',
          'Make suggestions, day and time, food and drinks, agree or suggest something else.'),
         [p('Öneri yap', 'Make a suggestion', 'Wollen wir …? / Wie wäre es mit …?', 'wollen wir', 'wie wäre es', 'sollen wir', 'lass uns', 'wir können', 'wir könnten'),
          p('Gün ve saat', 'Day and time', 'am Samstag um sieben Uhr', 'am samstag', 'am freitag', 'am sonntag', 'uhr', 'wann'),
          p('Yer', 'Place', 'bei mir / im Restaurant', 'bei mir', 'bei dir', 'im restaurant', 'im park', 'zu hause', 'im café'),
          p('Yemek ve içecek', 'Food and drinks', 'Ich mache einen Kuchen.', 'kuchen', 'essen', 'getränke', 'pizza', 'salat', 'saft'),
          p('Kabul / ret', 'Agree or disagree', 'Gute Idee! / Leider …', 'gute idee', 'einverstanden', 'okay', 'ja gern', 'leider', 'lieber')],
         'Nächste Woche hat Tom Geburtstag. Wollen wir eine kleine Party machen? Wie wäre es mit Samstag um sieben Uhr? '
         'Wir können die Party bei mir machen, meine Wohnung ist groß genug. Ich backe einen Schokoladenkuchen. '
         'Kannst du die Getränke kaufen? Und wir laden auch seine Kollegen ein. Gute Idee, oder?'),
    task('a2-4', 'A2', 60, ('Sağlık ve spor', 'Health and sport'), 'Was machen Sie für Ihre Gesundheit?',
         ('Spor, ne sıklıkla, sağlıklı beslenme, hastayken ne yaparsın?',
          'Sport, how often, healthy food, what you do when you are ill.'),
         [p('Spor', 'Sport', 'Ich gehe joggen / schwimmen.', 'sport', 'jogge', 'joggen', 'schwimme', 'fitness', 'fahrrad', 'laufe', 'yoga'),
          p('Ne sıklıkla', 'How often', 'zweimal pro Woche', 'pro woche', 'jeden tag', 'einmal', 'zweimal', 'dreimal', 'oft', 'selten'),
          p('Beslenme', 'Food', 'Ich esse viel Obst und Gemüse.', 'gesund', 'obst', 'gemüse', 'wasser', 'zucker'),
          p('Hastayken', 'When ill', 'Wenn ich krank bin, …', 'krank', 'arzt', 'ärztin', 'tee', 'im bett', 'medikament', 'tabletten')],
         'Ich mache dreimal pro Woche Sport. Am Montag und Mittwoch gehe ich ins Fitnessstudio, und am Samstag fahre ich Fahrrad. '
         'Ich esse viel Obst und Gemüse und trinke jeden Tag zwei Liter Wasser. '
         'Wenn ich krank bin, bleibe ich im Bett und trinke Tee mit Honig. Wenn es nicht besser wird, gehe ich zum Arzt.'),
    task('a2-5', 'A2', 60, ('İş ya da okul', 'Work or school'), 'Erzählen Sie von Ihrer Arbeit oder Ihrer Schule.',
         ('Nerede, ne yapıyorsun, arkadaşların, neyi seviyorsun, gelecek planın.',
          'Where, what you do, colleagues or classmates, what you like, future plans.'),
         [p('Nerede', 'Where', 'Ich arbeite bei … / Ich gehe zur …', 'arbeite bei', 'arbeite als', 'arbeite in', 'gehe zur', 'studiere', 'besuche'),
          p('Ne yapıyorsun', 'What you do', 'Ich muss jeden Tag …', 'muss', 'mache', 'schreibe', 'helfe', 'lerne'),
          p('İş/okul arkadaşları', 'Colleagues', 'Meine Kollegen sind …', 'kollegen', 'kollegin', 'mitschüler', 'team', 'lehrer', 'chef'),
          p('Ne düşünüyorsun', 'What you think', 'Die Arbeit gefällt mir, weil …', 'gefällt', 'mag', 'interessant', 'stressig', 'anstrengend', 'langweilig'),
          p('Gelecek', 'Future', 'Später möchte ich …', 'später', 'in zukunft', 'möchte', 'will', 'plane')],
         'Ich arbeite seit zwei Jahren als Verkäuferin in einem Modegeschäft. Ich berate Kunden und räume die Kleidung ein. '
         'Meine Kolleginnen sind sehr nett, wir machen oft zusammen Pause. Die Arbeit gefällt mir, aber am Samstag ist es sehr stressig. '
         'Später möchte ich eine Ausbildung als Kauffrau machen.'),
    task('a2-6', 'A2', 60, ('Yaşadığın yer', 'Where you live'), 'Wo wohnen Sie und wie gefällt es Ihnen dort?',
         ('Şehir/mahalle, ev, komşular, sevdiğin ve sevmediğin şeyler.',
          'Town or area, your home, neighbours, what you like and do not like.'),
         [p('Şehir / mahalle', 'Town or area', 'Ich wohne in … im Zentrum / am Stadtrand.', 'wohne in', 'zentrum', 'stadtrand', 'stadtteil', 'dorf', 'stadt'),
          p('Ev', 'Home', 'Meine Wohnung hat …', 'wohnung', 'haus', 'zimmer', 'miete'),
          p('Komşular', 'Neighbours', 'Meine Nachbarn sind …', 'nachbar', 'nachbarin', 'nachbarn'),
          p('Sevdiğin', 'What you like', 'Mir gefällt, dass …', 'gefällt', 'gut finde', 'schön', 'praktisch', 'ruhig', 'nah'),
          p('Sevmediğin', 'What you do not like', 'Leider ist es …', 'leider', 'zu laut', 'zu teuer', 'nicht so gut', 'nicht gefällt', 'weit')],
         'Ich wohne in Frankfurt, in einem Stadtteil im Norden. Meine Wohnung hat drei Zimmer und einen kleinen Balkon. '
         'Die Nachbarn sind freundlich, eine alte Dame gießt meine Blumen, wenn ich weg bin. '
         'Mir gefällt, dass der Supermarkt und die U-Bahn ganz nah sind. Leider ist die Miete sehr teuer, und die Straße ist laut.'),

    # ---------------- B1 ----------------
    task('b1-1', 'B1', 90, ('Sunum: İnternetten alışveriş', 'Presentation: online shopping'), 'Präsentieren Sie das Thema „Online einkaufen“.',
         ('Goethe B1 Teil 2 gibi: konuyu tanıt, deneyimin, ülkendeki durum, artılar/eksiler, görüşün.',
          'Like Goethe B1 part 2: introduce the topic, your experience, your country, pros and cons, your opinion.'),
         [INTRO, OWN, HOME, PRO, CONTRA, OPINION],
         'Mein Thema heute ist „Online einkaufen“. Ich persönlich kaufe fast alle Bücher und Elektronik im Internet. '
         'Letztes Jahr habe ich zum Beispiel meinen Laptop online bestellt, das war günstiger als im Geschäft. '
         'In meinem Heimatland kaufen vor allem junge Leute online ein, ältere Menschen gehen lieber in die Läden. '
         'Ein Vorteil ist, dass man rund um die Uhr bestellen und Preise leicht vergleichen kann. '
         'Ein Nachteil ist, dass man die Sachen vorher nicht anprobieren kann, und es gibt viel Verpackungsmüll. '
         'Meiner Meinung nach ist Online-Shopping praktisch, aber für Kleidung gehe ich lieber selbst ins Geschäft. Vielen Dank fürs Zuhören.'),
    task('b1-2', 'B1', 90, ('Sunum: Çocuklar ve akıllı telefon', 'Presentation: children and smartphones'), 'Präsentieren Sie das Thema „Brauchen Kinder ein eigenes Smartphone?“.',
         ('Konuyu tanıt, deneyimin, ülkendeki durum, artılar/eksiler, görüşün.',
          'Introduce the topic, your experience, your country, pros and cons, your opinion.'),
         [INTRO, OWN, HOME, PRO, CONTRA, OPINION],
         'Ich möchte heute über die Frage sprechen, ob Kinder ein eigenes Smartphone brauchen. '
         'Meine Erfahrung ist, dass mein Neffe schon mit neun Jahren ein Handy bekommen hat. '
         'In meinem Heimatland haben viele Kinder ab der Grundschule ein Smartphone. '
         'Ein Vorteil ist, dass die Eltern ihre Kinder jederzeit erreichen können. '
         'Ein Nachteil ist aber, dass Kinder zu viel Zeit mit Spielen und Videos verbringen und weniger draußen spielen. '
         'Ich finde, ein einfaches Handy reicht für kleine Kinder. Ein Smartphone sollten sie erst ab zwölf bekommen.'),
    task('b1-3', 'B1', 90, ('Birlikte plan yapın: veda partisi', 'Plan together: a farewell party'), 'Eine Kollegin verlässt die Firma. Planen Sie zusammen eine Abschiedsfeier.',
         ('Goethe B1 Teil 1 gibi: öneri yap, zaman, yer, hediye, kabul et veya itiraz et.',
          'Like Goethe B1 part 1: suggest, time, place, present, agree or disagree.'),
         [p('Öneri yap', 'Make a suggestion', 'Wir könnten … / Ich schlage vor, …', 'wir könnten', 'wie wäre es', 'ich schlage vor', 'sollen wir', 'was hältst du'),
          p('Zaman', 'Time', 'am Freitagnachmittag', 'am freitag', 'nachmittag', 'nach der arbeit', 'uhr', 'wann', 'termin'),
          p('Yer', 'Place', 'im Besprechungsraum / in einem Restaurant', 'im büro', 'raum', 'restaurant', 'café', 'kantine', 'garten'),
          p('Hediye', 'Present', 'Wir sammeln Geld für ein Geschenk.', 'geschenk', 'sammeln', 'blumen', 'gutschein', 'karte'),
          p('Kabul et', 'Agree', 'Das ist eine gute Idee.', 'gute idee', 'einverstanden', 'das passt', 'genau', 'finde ich gut'),
          p('İtiraz et', 'Disagree', 'Ich bin nicht sicher, ob …', 'nicht sicher', 'lieber', 'ich weiß nicht', 'aber', 'ich glaube nicht')],
         'Frau Berger verlässt nächsten Monat die Firma. Wir könnten am letzten Freitag eine kleine Feier machen, was meinst du? '
         'Ich schlage vor, dass wir um vier Uhr anfangen, dann können alle kommen. Der Besprechungsraum ist groß genug, oder wir gehen in das Café gegenüber. '
         'Für ein Geschenk könnten wir Geld sammeln, vielleicht einen Gutschein für ein Wellness-Wochenende. '
         'Einen großen Kuchen bestellen? Ich bin nicht sicher, ob das nötig ist, lieber bringt jeder etwas mit. Einverstanden?'),
    task('b1-4', 'B1', 90, ('Zor bir durum', 'A difficult situation'), 'Erzählen Sie von einer schwierigen Situation in Ihrem Leben.',
         ('Ne zaman, ne oldu, nasıl hissettin, nasıl çözdün, ne öğrendin? (geçmiş zaman)',
          'When, what happened, how you felt, how you solved it, what you learned. (past tense)'),
         [p('Ne zaman', 'When', 'Vor zwei Jahren … / Als ich …', 'vor ', 'als ich', 'letztes jahr', 'damals'),
          p('Ne oldu', 'What happened', 'Es ist … passiert.', 'passiert', 'war', 'hatte', 'musste', 'konnte'),
          p('Duygular', 'Feelings', 'Ich war sehr nervös.', 'nervös', 'traurig', 'angst', 'aufgeregt', 'gefühlt', 'wütend', 'sorgen'),
          p('Çözüm', 'Solution', 'Zum Glück … / Am Ende …', 'zum glück', 'am ende', 'schließlich', 'geholfen', 'gelöst'),
          p('Ne öğrendin', 'What you learned', 'Seitdem … / Ich habe gelernt, …', 'gelernt', 'seitdem', 'heute weiß ich', 'jetzt')],
         'Vor drei Jahren bin ich allein nach Deutschland gekommen. Am ersten Tag habe ich am Bahnhof meinen Geldbeutel verloren. '
         'Ich war sehr nervös, weil ich niemanden kannte und kaum Deutsch sprechen konnte. '
         'Zum Glück hat mir eine Frau geholfen. Wir sind zusammen zum Fundbüro gegangen, und am Ende war der Geldbeutel wirklich dort. '
         'Seitdem frage ich schneller um Hilfe, und ich habe gelernt, dass die Leute oft hilfsbereiter sind, als man denkt.'),
    task('b1-5', 'B1', 90, ('Görüş: Evden çalışma', 'Opinion: working from home'), 'Ist Homeoffice besser als Arbeiten im Büro? Sagen Sie Ihre Meinung.',
         ('Görüşünü söyle, gerekçe ve örnek ver, karşı görüşü de an, sonuç çıkar.',
          'Give your opinion, reasons and an example, mention the other side, conclude.'),
         [p('Görüşün', 'Your opinion', 'Meiner Meinung nach …', 'meiner meinung', 'ich finde', 'ich bin der meinung', 'ich denke', 'ich glaube'),
          REASON, EXAMPLE,
          p('Karşı görüş', 'The other side', 'Andererseits …', 'andererseits', 'allerdings', 'aber', 'trotzdem', 'auf der anderen seite'),
          p('Sonuç', 'Conclusion', 'Insgesamt …', 'insgesamt', 'zum schluss', 'deshalb', 'also', 'alles in allem')],
         'Meiner Meinung nach ist eine Mischung aus Homeoffice und Büro am besten. Zu Hause kann ich mich besser konzentrieren, weil es ruhiger ist. '
         'Außerdem spare ich jeden Tag eine Stunde Fahrzeit. Zum Beispiel schreibe ich lange Berichte immer im Homeoffice. '
         'Andererseits fehlt mir zu Hause der Kontakt zu den Kollegen, und manche Probleme kann man im Büro schneller lösen. '
         'Insgesamt finde ich zwei oder drei Tage Homeoffice pro Woche ideal.'),
    task('b1-6', 'B1', 90, ('Sunum: Şehirde mi köyde mi?', 'Presentation: city or countryside?'), 'Präsentieren Sie das Thema „Leben in der Stadt oder auf dem Land?“.',
         ('Konuyu tanıt, deneyimin, ülkendeki durum, artılar/eksiler, görüşün.',
          'Introduce the topic, your experience, your country, pros and cons, your opinion.'),
         [INTRO, OWN, HOME, PRO, CONTRA, OPINION],
         'In meinem Vortrag geht es um die Frage: Lebt man besser in der Stadt oder auf dem Land? '
         'Ich selbst bin in einem Dorf aufgewachsen und wohne jetzt in Hamburg. '
         'In meinem Heimatland ziehen viele junge Leute in die großen Städte, weil es dort mehr Arbeit gibt. '
         'Ein Vorteil der Stadt ist, dass man Kinos, Ärzte und Geschäfte in der Nähe hat. '
         'Ein Nachteil ist, dass die Mieten hoch sind und es oft laut ist. '
         'Ich finde, für junge Menschen ist die Stadt besser, aber später möchte ich mit meiner Familie lieber auf dem Land leben.'),

    # ---------------- B2 ----------------
    task('b2-1', 'B2', 120, ('Sunum: Şehir merkezinde otomobil yasağı', 'Presentation: banning cars from city centres'), 'Halten Sie einen kurzen Vortrag: „Sollten Autos aus den Innenstädten verbannt werden?“',
         ('Goethe B2 gibi: giriş, artılar, eksiler, örnek, ülkendeki durum, sonuç.',
          'Like Goethe B2: introduction, pros, cons, an example, your country, conclusion.'),
         [INTRO, PRO, CONTRA, EXAMPLE, HOME, OPINION],
         'In meinem Vortrag möchte ich mich mit der Frage beschäftigen, ob Autos aus den Innenstädten verbannt werden sollten. '
         'Für ein Verbot spricht vor allem die bessere Luftqualität. Außerdem würden Fußgänger und Radfahrer mehr Platz bekommen. '
         'Dagegen spricht, dass Lieferanten, Handwerker und Menschen mit eingeschränkter Mobilität auf das Auto angewiesen sind. '
         'Ein gutes Beispiel ist Kopenhagen, wo der Ausbau der Radwege die Innenstadt deutlich lebenswerter gemacht hat. '
         'In meinem Heimatland ist das Auto dagegen noch ein Statussymbol, und der Nahverkehr ist vielerorts unzureichend. '
         'Zusammenfassend bin ich der Ansicht, dass ein schrittweiser Umbau sinnvoller ist als ein abruptes Verbot.'),
    task('b2-2', 'B2', 120, ('Tartışma: Gençler ve sosyal medya', 'Discussion: teenagers and social media'), 'Diskutieren Sie: „Soziale Medien sollten erst ab 16 Jahren erlaubt sein.“',
         ('Görüşünü savun, gerekçe ver, karşı argümanı kabul et ve çürüt, uzlaşma öner.',
          'Defend your view, give reasons, acknowledge and answer the counter-argument, suggest a compromise.'),
         [p('Tutumun', 'Your position', 'Ich vertrete die Ansicht, dass …', 'ich vertrete', 'meiner ansicht', 'ich bin überzeugt', 'meiner meinung', 'ich bin der meinung'),
          REASON,
          p('Karşı argümanı kabul et', 'Acknowledge the other side', 'Da haben Sie zwar recht, aber …', 'zwar', 'das stimmt', 'recht', 'ich verstehe', 'nachvollziehen'),
          p('İtiraz et', 'Disagree', 'Da muss ich widersprechen.', 'widersprechen', 'sehe das anders', 'allerdings', 'jedoch', 'dennoch'),
          p('Uzlaşma öner', 'Suggest a compromise', 'Ein Kompromiss wäre …', 'kompromiss', 'einigen', 'vielleicht wäre', 'man könnte', 'mittelweg')],
         'Ich vertrete die Ansicht, dass eine Altersgrenze von sechzehn Jahren sinnvoll wäre, weil viele Jüngere den Druck durch Likes und Vergleiche kaum verarbeiten können. '
         'Studien zeigen, dass intensive Nutzung mit Schlafproblemen zusammenhängt. '
         'Sie haben zwar recht, dass soziale Medien auch Kontakte und Informationen bieten. Dennoch muss ich widersprechen, wenn Sie sagen, ein Verbot sei unrealistisch: '
         'Bei Alkohol akzeptieren wir Altersgrenzen ja auch. Ein Kompromiss wäre vielleicht, dass Jüngere spezielle Konten mit begrenzten Funktionen nutzen dürfen.'),
    task('b2-3', 'B2', 120, ('Sunum: Hayat boyu öğrenme', 'Presentation: lifelong learning'), 'Halten Sie einen kurzen Vortrag zum Thema „Lebenslanges Lernen“.',
         ('Giriş, artılar, zorluklar, örnek, ülkendeki durum, sonuç.',
          'Introduction, advantages, difficulties, an example, your country, conclusion.'),
         [INTRO, PRO, CONTRA, EXAMPLE, HOME, OPINION],
         'Heute spreche ich über lebenslanges Lernen. Einerseits ist es in einer Arbeitswelt, die sich ständig verändert, kaum noch verzichtbar. '
         'Wer sich regelmäßig weiterbildet, bleibt flexibel und hat bessere Chancen auf dem Arbeitsmarkt. '
         'Andererseits fehlt vielen Berufstätigen neben Arbeit und Familie schlicht die Zeit, und gute Kurse sind oft teuer. '
         'Meine Mutter hat zum Beispiel mit fünfzig noch einen Computerkurs gemacht und danach eine neue Stelle gefunden. '
         'In meinem Heimatland wird Weiterbildung zunehmend online angeboten, was den Zugang erleichtert. '
         'Abschließend möchte ich betonen, dass Arbeitgeber und Staat das Lernen stärker unterstützen sollten.'),
    task('b2-4', 'B2', 120, ('Tartışma: Dört günlük çalışma haftası', 'Discussion: the four-day week'), 'Diskutieren Sie: „Die Vier-Tage-Woche sollte für alle eingeführt werden.“',
         ('Görüşünü savun, gerekçe ve örnek ver, karşı argümanı ele al, uzlaşma öner.',
          'Defend your view, reasons and an example, deal with the counter-argument, suggest a compromise.'),
         [p('Tutumun', 'Your position', 'Ich bin davon überzeugt, dass …', 'überzeugt', 'meiner ansicht', 'ich vertrete', 'meiner meinung', 'ich halte'),
          REASON, EXAMPLE,
          p('Karşı argüman', 'Counter-argument', 'Man könnte einwenden, dass …', 'einwenden', 'zwar', 'kritiker', 'allerdings', 'jedoch'),
          p('Uzlaşma öner', 'Suggest a compromise', 'Ein Mittelweg wäre …', 'kompromiss', 'mittelweg', 'einigen', 'man könnte', 'zunächst')],
         'Ich halte die Vier-Tage-Woche grundsätzlich für eine gute Idee, denn ausgeruhte Mitarbeiter arbeiten konzentrierter und sind seltener krank. '
         'In Island zum Beispiel ist die Produktivität in Testprojekten gleich geblieben oder sogar gestiegen. '
         'Man könnte allerdings einwenden, dass das in Krankenhäusern, Schulen oder im Handel kaum umsetzbar ist, weil dort Personal fehlt. '
         'Deshalb wäre ein Mittelweg sinnvoll: Man könnte zunächst in Branchen beginnen, in denen es organisatorisch möglich ist, und die Ergebnisse auswerten.'),
    task('b2-5', 'B2', 120, ('Başarısız bir proje', 'A project that went wrong'), 'Berichten Sie von einem Projekt oder Plan, der nicht geklappt hat. Was würden Sie heute anders machen?',
         ('Ne oldu, neden, sonuçları, bugün ne farklı yapardın (Konjunktiv II), ne öğrendin.',
          'What happened, why, the consequences, what you would do differently (Konjunktiv II), what you learned.'),
         [p('Ne oldu', 'What happened', 'Vor einem Jahr wollte ich …', 'wollte', 'hatte', 'geplant', 'projekt', 'vorgenommen'),
          p('Neden', 'Why', 'Das lag vor allem daran, dass …', 'lag daran', 'weil', 'aufgrund', 'wegen', 'der grund'),
          p('Sonuçlar', 'Consequences', 'Dadurch / Folglich …', 'dadurch', 'folglich', 'deshalb', 'sodass', 'die folge'),
          p('Farklı yapardın', 'What you would change', 'Heute würde ich … / hätte ich …', 'würde', 'hätte', 'wäre', 'anders machen'),
          p('Ders', 'Lesson', 'Rückblickend habe ich gelernt, …', 'rückblickend', 'im nachhinein', 'gelernt', 'erkenntnis')],
         'Vor einem Jahr wollte ich mit zwei Freunden einen kleinen Online-Shop für handgemachten Schmuck aufbauen. '
         'Das Projekt ist gescheitert, was vor allem daran lag, dass wir keinen klaren Plan für das Marketing hatten. '
         'Dadurch haben wir kaum Kunden erreicht und nach sechs Monaten aufgegeben. '
         'Heute würde ich zuerst eine Marktanalyse machen, und ich hätte von Anfang an Aufgaben klarer verteilt. '
         'Rückblickend habe ich gelernt, dass eine gute Idee allein nicht reicht.'),
    task('b2-6', 'B2', 90, ('Telefonda şikâyet', 'A complaint on the phone'), 'Rufen Sie die Hausverwaltung an: Die Heizung ist seit einer Woche kaputt.',
         ('Kendini tanıt, sorunu anlat, ne zamandır olduğunu söyle, kibarca rica et, süre iste, teşekkür et.',
          'Introduce yourself, describe the problem and since when, ask politely, ask for a deadline, thank them.'),
         [p('Kendini tanıt', 'Introduce yourself', 'Guten Tag, mein Name ist …', 'guten tag', 'mein name ist', 'hier spricht', 'ich wohne'),
          p('Sorun', 'The problem', 'Die Heizung funktioniert nicht.', 'funktioniert nicht', 'kaputt', 'defekt', 'problem', 'kalt'),
          p('Ne zamandan beri', 'Since when', 'seit einer Woche', 'seit'),
          p('Kibar rica', 'Polite request', 'Könnten Sie bitte …?', 'könnten sie', 'würden sie', 'ich möchte sie bitten', 'wäre es möglich'),
          p('Süre', 'Deadline', 'bis spätestens Freitag', 'bis ', 'spätestens', 'so schnell wie möglich', 'wann'),
          p('Teşekkür', 'Thank them', 'Vielen Dank für Ihre Hilfe.', 'vielen dank', 'danke', 'ich bedanke mich')],
         'Guten Tag, mein Name ist Deniz Kaya, ich wohne in der Lindenstraße zwölf im dritten Stock. '
         'Ich rufe an, weil unsere Heizung seit einer Woche nicht funktioniert. Die Wohnung ist inzwischen sehr kalt, und wir haben ein kleines Kind. '
         'Ich habe schon zweimal eine E-Mail geschrieben, aber leider keine Antwort bekommen. '
         'Könnten Sie bitte so schnell wie möglich einen Techniker schicken, spätestens bis Freitag? '
         'Sonst müsste ich mich an den Mieterverein wenden. Vielen Dank für Ihre Hilfe.'),
]


def main():
    sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
    import speaking_a1_more
    # A1 tasks first (the original six, then the exam-part tasks), then the other levels.
    a1 = [t for t in TASKS if t['level'] == 'A1'] + speaking_a1_more.TASKS
    TASKS[:] = a1 + [t for t in TASKS if t['level'] != 'A1']
    # The B2 tasks Codex wrote (tools/tasks_upper.py import keeps them in tools/tasks_extra.json).
    extra = os.path.join(REPO, 'tools', 'tasks_extra.json')
    if os.path.exists(extra):
        TASKS.extend(t for t in json.load(open(extra, encoding='utf-8'))['speaking'] if t['id'] not in {x['id'] for x in TASKS})
    ids = [t['id'] for t in TASKS]
    assert len(ids) == len(set(ids))
    for t in TASKS:
        assert t['points'] and t['sample'] and t['prompt']
    with open(OUT, 'w', encoding='utf-8', newline='\n') as f:
        json.dump({'tasks': TASKS}, f, ensure_ascii=False, indent=1)
        f.write('\n')
    print(f'{len(TASKS)} tasks -> {OUT}')


if __name__ == '__main__':
    main()

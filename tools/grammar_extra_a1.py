"""Two A1 grammar topics the original list lacked (Goethe A1 has them): prepositions with the accusative and
"es gibt / man". Added through tools/content_edits.py (op "add"), so they survive a regenerated a1.json.

    python -I -X utf8 tools/grammar_extra_a1.py      adds what is missing (safe to run again)
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import content_edits  # noqa: E402


def ex(de, tr, en):
    return {'de': de, 'mean': {'tr': tr, 'en': en}}


TOPICS = [
    {'id': 23, 'de': 'Präpositionen mit Akkusativ',
     'name': {'tr': 'Akkusativ alan edatlar', 'en': 'Prepositions with the accusative'},
     'rule': {'tr': 'Bu edatlardan sonra hep Akkusativ gelir:\n'
                    'für (için) · ohne (-sız, olmadan) · durch (içinden) · um (etrafında; saatle: -de) · gegen (karşı)\n'
                    'Eril kelimelerde artikel değişir: für den Vater · ohne meinen Bruder · durch den Park\n'
                    'Zamirler de Akkusativ olur: für dich · ohne mich · für Sie',
              'en': 'These prepositions always take the accusative:\n'
                    'für (for) · ohne (without) · durch (through) · um (around; with time: at) · gegen (against)\n'
                    'Masculine words change: für den Vater · ohne meinen Bruder · durch den Park\n'
                    'Pronouns are accusative too: für dich · ohne mich · für Sie'},
     'examples': [ex('Das Geschenk ist für dich.', 'Hediye senin için.', 'The present is for you.'),
                  ex('Ich trinke Kaffee ohne Zucker.', 'Kahveyi şekersiz içerim.', 'I drink coffee without sugar.'),
                  ex('Wir gehen durch den Park.', 'Parkın içinden geçiyoruz.', 'We walk through the park.')]},
    {'id': 24, 'de': 'es gibt & man',
     'name': {'tr': 'es gibt (var) ve man (insan, biri)', 'en': 'es gibt (there is) and man (one, people)'},
     'rule': {'tr': 'es gibt = var. Ardından gelen isim Akkusativ olur:\n'
                    'es gibt einen Tisch · eine Lampe · ein Bett · keine Toilette\n'
                    'Soru için fiil başa geçer: Gibt es hier eine Apotheke?\n'
                    'man = insan, biri, genel olarak herkes. Fiil er/sie/es gibi çekimlenir:\n'
                    'man kann · man muss · man darf · man spricht\n'
                    'Hier darf man nicht rauchen. = Burada sigara içilmez.',
              'en': 'es gibt = there is / there are. The noun after it is in the accusative:\n'
                    'es gibt einen Tisch · eine Lampe · ein Bett · keine Toilette\n'
                    'For a question the verb goes first: Gibt es hier eine Apotheke?\n'
                    'man = one, people, you in general. The verb is like er/sie/es:\n'
                    'man kann · man muss · man darf · man spricht\n'
                    'Hier darf man nicht rauchen. = You may not smoke here.'},
     'examples': [ex('In der Küche gibt es einen Tisch.', 'Mutfakta bir masa var.', 'There is a table in the kitchen.'),
                  ex('Gibt es hier eine Bank?', 'Burada banka var mı?', 'Is there a bank here?'),
                  ex('Hier darf man nicht parken.', 'Buraya park edilmez.', "You can't park here.")]},
]


def item(topic, q, options, tr, en):
    return {'topic': topic, 'q': q, 'options': options, 'why': {'tr': tr, 'en': en}}


ITEMS = [
    item(23, 'Das Geschenk ist ___ meine Mutter.', ['für', 'mit', 'von'], 'für = için; für + Akkusativ.', 'für = for; für + accusative.'),
    item(23, 'Ich trinke Kaffee ___ Zucker.', ['ohne', 'mit', 'für'], 'ohne = -sız: şekersiz.', 'ohne = without.'),
    item(23, 'Wir gehen ___ den Park.', ['durch', 'ohne', 'für'], 'durch = içinden (geçmek).', 'durch = through.'),
    item(23, 'Der Kurs beginnt ___ 9 Uhr.', ['um', 'am', 'im'], 'Saatle um: um 9 Uhr.', 'Clock time takes um: um 9 Uhr.'),
    item(23, 'Das ist für ___ Bruder.', ['meinen', 'mein', 'meinem'], 'für + Akkusativ; der Bruder → meinen Bruder.', 'für + accusative; der Bruder → meinen Bruder.'),
    item(23, 'Ohne ___ Jacke ist es kalt.', ['meine', 'meiner', 'meinen'], 'ohne + Akkusativ; die Jacke → meine Jacke (dişil değişmez).', 'ohne + accusative; die Jacke stays meine Jacke.'),
    item(23, 'Er fährt mit dem Rad ___ die Stadt.', ['durch', 'für', 'ohne'], 'durch die Stadt = şehrin içinden.', 'durch die Stadt = through the town.'),
    item(23, 'Ich habe ein Buch für ___.', ['dich', 'dir', 'du'], 'für + Akkusativ: du → dich.', 'für + accusative: du → dich.'),
    item(23, 'Heute spielt Köln ___ Berlin.', ['gegen', 'für', 'durch'], 'gegen = karşı (maçta).', 'gegen = against (in a match).'),
    item(23, 'Gehen Sie hier ___ die Ecke.', ['um', 'durch', 'für'], 'um die Ecke = köşeyi dönünce.', 'um die Ecke = round the corner.'),
    item(23, 'Ohne ___ Handy kann ich nicht arbeiten.', ['mein', 'meinen', 'meine'], 'das Handy nötr: ohne mein Handy.', 'das Handy is neuter: ohne mein Handy.'),
    item(23, 'Der Brief ist für ___, Frau Weber.', ['Sie', 'Ihnen', 'Ihr'], 'für + Akkusativ: Sie → Sie.', 'für + accusative: Sie stays Sie.'),
    item(23, 'Sie geht ohne ___ Mann ins Kino.', ['ihren', 'ihr', 'ihrem'], 'ohne + Akkusativ; der Mann → ihren Mann.', 'ohne + accusative; der Mann → ihren Mann.'),
    item(23, 'Wir laufen jeden Morgen ___ den Wald.', ['durch', 'um', 'ohne'], 'durch den Wald = ormanın içinden.', 'durch den Wald = through the forest.'),
    item(23, 'Das ist ein Tisch ___ die Küche.', ['für', 'ohne', 'gegen'], 'für die Küche = mutfak için.', 'für die Küche = for the kitchen.'),
    item(23, 'Ich warte ___ dich nicht.', ['ohne', 'für', 'um'], 'Hmm: „ohne dich“ = sensiz; burada „ohne dich nicht“ değil, cümle: Ich warte nicht ohne dich? Kullanma.', ''),
    item(24, 'In der Küche ___ es einen Tisch.', ['gibt', 'ist', 'hat'], 'es gibt = var.', 'es gibt = there is.'),
    item(24, 'Gibt es hier ___ Bank?', ['eine', 'ein', 'einen'], 'es gibt + Akkusativ; die Bank → eine Bank.', 'es gibt + accusative; die Bank → eine Bank.'),
    item(24, 'Hier ___ man nicht rauchen.', ['darf', 'dürfen', 'darfst'], 'man + er/sie/es çekimi: man darf.', 'man takes the er/sie/es form: man darf.'),
    item(24, 'Im Café ___ es heute keinen Kuchen.', ['gibt', 'hat', 'ist'], 'es gibt keinen … = hiç … yok.', 'es gibt keinen … = there is no …'),
    item(24, 'Wie sagt ___ das auf Deutsch?', ['man', 'es', 'er'], 'man = genel olarak biri: Almancada bu nasıl denir?', 'man = one: how do you say that in German?'),
    item(24, 'Es gibt ___ Supermarkt in der Straße.', ['einen', 'ein', 'eine'], 'es gibt + Akkusativ; der Supermarkt → einen Supermarkt.', 'es gibt + accusative; der Supermarkt → einen Supermarkt.'),
    item(24, 'Hier ___ man gut essen.', ['kann', 'können', 'kannst'], 'man + er/sie/es çekimi: man kann.', 'man takes the er/sie/es form: man kann.'),
    item(24, '___ es hier ein Café?', ['Gibt', 'Ist', 'Hat'], 'Soru: Gibt es …? = … var mı?', 'Question: Gibt es …? = Is there …?'),
    item(24, 'In Deutschland ___ man viel Brot.', ['isst', 'essen', 'esst'], 'man + er/sie/es çekimi: man isst.', 'man takes the er/sie/es form: man isst.'),
    item(24, 'Heute ___ es Fisch und Salat.', ['gibt', 'ist', 'hat'], 'es gibt = var (yemekte).', 'es gibt = there is (on the menu).'),
    item(24, 'Wo kann ___ hier Fahrkarten kaufen?', ['man', 'es', 'wir'], 'man = biri, insan: bilet nereden alınır?', 'man = one: where can you buy tickets here?'),
    item(24, 'Es gibt zwei Zimmer und ___ Bad.', ['ein', 'einen', 'eine'], 'das Bad nötr: ein Bad (Akkusativ’ta değişmez).', 'das Bad is neuter: ein Bad.'),
    item(24, 'Am Samstag ___ es ein Konzert im Park.', ['gibt', 'hat', 'ist'], 'es gibt = var (etkinlik).', 'es gibt = there is (an event).'),
    item(24, 'Hier ___ man links fahren.', ['muss', 'müssen', 'musst'], 'man + er/sie/es çekimi: man muss.', 'man takes the er/sie/es form: man muss.'),
    item(24, 'Gibt es hier ___ Toilette?', ['eine', 'ein', 'einen'], 'die Toilette → eine Toilette.', 'die Toilette → eine Toilette.'),
    item(24, 'Was ___ es heute zum Essen?', ['gibt', 'ist', 'hat'], 'Was gibt es …? = … ne var?', 'Was gibt es …? = What is there …?'),
]
ITEMS = [i for i in ITEMS if i['why']['en']]  # one draft line above was not good enough: left out


def main():
    data = content_edits.read_file('a1.json')[2]
    have_topics = {t['id'] for t in data['grammar']}
    have_items = {i['q'] for i in data['grammarItems']}
    added = 0
    for topic in TOPICS:
        if topic['id'] not in have_topics:
            content_edits.add('a1.json', 'grammar', topic)
            added += 1
    for it in ITEMS:
        if it['q'] not in have_items:
            content_edits.add('a1.json', 'grammarItems', it)
            added += 1
    print(f'added {added} (topics 23, 24; {len(ITEMS)} questions)')


if __name__ == '__main__':
    main()

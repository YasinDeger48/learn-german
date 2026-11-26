"""Pictures for the A2–B2 unit words (units.json "vocab"), drawn by ChatGPT as 4×4 sticker grids like the A1 ones.

    python -I -X utf8 tools/vocab_pictures.py prompts    ../icerik/gorseller/KELIME_IZGARALARI_A2_B2.txt
    python -I -X utf8 tools/vocab_pictures.py cut-all    cuts every ../icerik/gorseller/words-<grid>.(jpg|png|webp)
    python -I -X utf8 tools/vocab_pictures.py status

Only nouns that a small picture can show; abstract ones (SKIP) stay letter cards in the app.
Pictures are saved as Resources/Covers/wv-<slug>.jpg; the app builds the same name in UnitWord.picture
(lower case, ä→ae ö→oe ü→ue ß→ss, other characters "-"). A noun used in several units shares one picture.
"""
import glob
import json
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from word_pictures import CONTENT, COVERS, GORSELLER, STYLE, cut_grid  # noqa: E402

LEVELS = ('A2', 'B1', 'B2')

# Abstract or unclear nouns: no picture (a letter card is clearer than a misleading drawing).
SKIP = {
    'Rückseite', 'Stelle', 'Bestätigung', 'Fehler', 'Rand', 'Stichwort', 'Schrift', 'Anbieter', 'Hausverwaltung',
    'Verwechslung', 'Zielraum', 'Zusage', 'Fassung', 'Spalte', 'Betrag', 'Zustimmung', 'Strophe', 'Veranstalter',
    'Frist', 'Postleitzahl', 'Sorte', 'Kante', 'Gebühr', 'Überschrift', 'Beitrag', 'Hintergrund', 'Begleittext',
    'Verbindung', 'Alternative', 'Rückgabedatum', 'Vergleich', 'Ausfall', 'Marktleitung', 'Stimme', 'Übergang',
    'Bestellung', 'Modellversuch', 'Aussicht', 'Verteilung', 'Arbeitsablauf', 'Ausnahme', 'Einarbeitung',
    'Abschrift', 'Vorbehalt', 'Verteiler', 'Doppelbuchung', 'Wortlaut', 'Terminvergabe', 'Antrag', 'Auswertung',
    'Tempo', 'Suchanfrage', 'Fachbegriff', 'Treffer', 'Einweisung', 'Vermutung', 'Erscheinen', 'Überweisung',
    'Rückfrage', 'Anforderung', 'Weitergabe', 'Abschnitt', 'Abschlussbesprechung', 'Anliegen', 'Genossenschaft',
    'Aufwand', 'Betriebsleitung', 'Pflege', 'Verpflichtung', 'Ortschaft', 'Höchstzahl', 'Mengenbegrenzung',
    'Warteliste', 'Zuordnung', 'Abrechnungszeitraum', 'Aufstellung', 'Übergabeprotokoll', 'Ursache', 'Anzeichen',
    'Abweichung', 'Standpunkt', 'Einwand', 'Rückmeldung', 'Behauptung', 'Ablauf', 'Vorgehensweise', 'Orientierung',
    'Weganweisung', 'Abdunkeln', 'Vergabe', 'Anfahrtsweg', 'Überstunde', 'Zeitfenster', 'Advent',
}

# What to draw when the English meaning alone is unclear (keyed by the German word without article).
HINT = {
    'Abdruck': 'a muddy paw print', 'Glasur': 'a cake with white icing', 'Enkel': 'a grandfather with his grandson',
    'Gemüsestand': 'a market stall with vegetables', 'Leine': 'a dog lead', 'Halsband': 'a dog collar', 'Anhänger': 'a small round pet tag',
    'Band': 'a roll of ribbon', 'Hausmeister': 'a caretaker with a toolbox', 'Bank': 'a park bench',
    'Hof': 'a courtyard with a tree', 'Glas': 'a glass jar', 'Anzeige': 'a small digital display',
    'Kilo': 'a kitchen weight', 'Verpackung': 'a cardboard packaging box', 'Stoff': 'a roll of fabric',
    'Akku': 'a battery', 'Leihrad': 'a rental bike at a docking station', 'Griff': 'a handle',
    'Schoß': 'a cat sitting on a lap', 'Pfiff': 'a whistle with sound lines', 'Untersuchung': 'a doctor examining a patient',
    'Praxis': "a doctor's practice door with a medical cross", 'Physiotherapie': 'a physiotherapist helping with a knee exercise',
    'Empfang': 'a reception desk with a bell', 'Schritt': 'a row of footprints', 'Besprechung': 'people meeting around a table',
    'Geräusch': 'a speaker with sound waves', 'Zutat': 'baking ingredients: flour, eggs, butter',
    'Jugendzentrum': 'a youth centre building with a basketball hoop', 'Leiterin': 'a woman leading a meeting',
    'Reinigungskraft': 'a cleaner with a mop and bucket', 'Helferin': 'a female helper in a vest',
    'Taschentuch': 'a paper tissue', 'Drachen': 'a kite in the sky', 'Stock': 'a wooden stick',
    'Bogen': 'a blank sheet of paper', 'Trikot': 'a football shirt', 'Rezeption': 'a hotel reception desk',
    'Nachricht': 'a phone with a message bubble', 'Taste': 'a keyboard key', 'Wetter-App': 'a phone with a sun and cloud icon',
    'Schatten': 'a tree casting a shadow', 'Untertitel': 'a TV with short bars of subtitles',
    'Umleitung': 'a yellow detour road sign with an arrow', 'Haltestelle': 'a bus stop', 'Kursbuch': 'a course book',
    'Ersatzverkehr': 'a replacement bus next to a train track', 'Arbeitsweg': 'a person cycling to an office building',
    'Zeichen': 'a road sign', 'Rezept': 'a recipe card with a bowl', 'Prise': 'a pinch of salt between two fingers',
    'Erde': 'a pile of soil with a small plant', 'Innenhof': 'an inner courtyard between buildings',
    'Schnur': 'a ball of string', 'Dichtung': 'a rubber gasket ring', 'Fluchtweg': 'a green emergency exit sign with a running figure',
    'Etage': 'a building with one floor highlighted', 'Wartung': 'a technician with a wrench at a machine',
    'Fach': 'a shelf compartment', 'Mieterin': 'a woman holding apartment keys', 'Sendung': 'a parcel',
    'Frühschicht': 'a worker arriving at sunrise', 'Nachtschicht': 'a worker under the moon',
    'Abschlussfeier': 'graduates throwing their caps', 'Großhändler': 'a warehouse with stacked boxes',
    'Strauß': 'a bouquet of flowers', 'Wäscherei': 'washing machines in a laundry', 'Warnung': 'a warning triangle sign',
    'Druckerei': 'a large printing machine', 'Kassengerät': 'a cash register', 'Stadtrand': 'houses at the edge of a city with fields',
    'Bargeld': 'banknotes and coins', 'Rollator': 'a rolling walker', 'Aufnahme': 'a microphone recording with a red dot',
    'Datei': 'a computer file icon', 'Kuchenform': 'a cake tin', 'Innentasche': 'a jacket with its inside pocket shown',
    'Außentasche': 'a backpack with a front pocket', 'Führung': 'a guide leading a small group',
    'Kragen': 'a shirt collar', 'Rückgabe': 'a returns counter with a box', 'Lesegerät': 'a card reader',
    'Etikett': 'a label tag', 'Mine': 'a pen refill', 'Ausdruck': 'a printed sheet coming out of a printer',
    'Strecke': 'a route line on a map', 'Steigung': 'a steep road going uphill', 'Zahnarztpraxis': "a dentist's chair",
    'Kirschkern': 'a cherry next to its stone', 'Abholschein': 'a small paper slip', 'Schalter': 'a service counter window',
    'Sachbearbeiterin': 'a female clerk at a desk with files', 'Zeugnis': 'a certificate with a ribbon seal',
    'Abholnummer': 'a waiting ticket from a machine', 'Ablage': 'a filing tray with papers', 'Unterlagen': 'a stack of documents',
    'Mappe': 'a document folder', 'Bürgerbüro': 'a public office counter', 'Automat': 'a ticket machine',
    'Schülerzeitung': 'a school newspaper', 'Redaktion': 'a small newsroom with desks', 'Renovierung': 'a paint roller and a ladder',
    'Ausleihe': 'a library lending desk', 'Verzögerung': 'a clock with a snail', 'Lesesaal': 'a library reading room',
    'Ordner': 'a ring binder', 'Stellplatz': 'a parking space', 'Unterkunft': 'a small guesthouse',
    'Ehepaar': 'a married couple', 'Stempel': 'a rubber stamp', 'Gepäckablage': 'a luggage rack in a train',
    'Schloss': 'a padlock', 'Vortrag': 'a person giving a talk', 'Abkürzung': 'a short path across a park',
    'Folie': 'a presentation slide on a screen', 'Aufkleber': 'a sticker', 'Referat': 'a student presenting to a class',
    'öffentliche Verkehr': 'a bus and a tram', 'Interview': 'two people and a microphone', 'Hochbeet': 'a raised garden bed',
    'Freiwillige': 'a volunteer in a vest', 'Steckdosenleiste': 'a power strip', 'Imkerin': 'a female beekeeper',
    'Preisnachlass': 'a red discount tag with a percent sign', 'Chip': 'a shopping trolley token', 'Setzling': 'a seedling',
    'Hahn': 'a water tap', 'Generalprobe': 'actors rehearsing on a stage', 'Dirigent': 'an orchestra conductor',
    'Auftritt': 'a singer performing on a stage', 'Pfeife': "a referee's whistle", 'Verein': 'a club team in matching shirts',
    'Probe': 'musicians rehearsing', 'Bühne': 'a theatre stage', 'Ansprechpartner': 'a person with a headset',
    'Handbuch': 'a handbook', 'Pflanzkübel': 'a planter with a plant', 'Leitstelle': 'a control room with screens',
    'Unterführung': 'a pedestrian underpass', 'Durchsage': 'a loudspeaker on a pole', 'Zugang': 'a turnstile entrance',
    'Bucht': 'a bus stopping in a bus bay', 'Begehung': 'people inspecting a building with a clipboard',
    'Befragung': 'a person with a clipboard asking a passer-by', 'Fehlermeldung': 'a screen with a warning triangle',
    'Flugmodus': 'a phone with a plane icon', 'Jubiläum': 'an anniversary cake with a ribbon', 'Abzug': 'a photo print',
    'Bildunterschrift': 'a photo with a short line below it', 'Zeitungsarchiv': 'shelves of old newspapers',
    'Sammelstelle': 'a collection point with bins', 'Schülerredaktion': 'students around a newspaper layout',
    'Ausgabe': 'a soup bowl being handed out', 'Fotostrecke': 'a row of photos', 'Durchgang': 'an archway passage',
    'Baumaterial': 'bricks and wooden planks', 'Krankenkasse': 'a health insurance card', 'Folgetermin': 'a calendar with a second day circled',
    'Tonband': 'a reel-to-reel audio tape', 'Schrittzähler': 'a pedometer on a wrist', 'Wettbewerb': 'a trophy',
    'Zufahrt': 'a driveway to a house', 'Mulde': 'a shallow grassy basin with water', 'Wasserstand': 'a water level gauge',
    'Kundschaft': 'customers in a shop', 'Rundbrief': 'a newsletter in an envelope', 'Naht': 'a stitched seam',
    'Wasserdichtigkeit': 'water drops rolling off a jacket', 'Gebrauchsspur': 'a bag with scratches',
    'Andrang': 'a crowd queueing', 'Eigentümerin': 'a woman with a house key in front of a house',
    'Zählerstand': 'an electricity meter', 'Anlage': 'a paperclip on a document', 'Bremsbelag': 'a brake pad',
    'Sichtprüfung': 'a mechanic looking at a car with a torch', 'Halterung': 'a wall bracket holding a phone',
    'Vorgang': 'a case file folder', 'Messpunkt': 'a measuring stake in the ground', 'Unterstand': 'a small wooden shelter',
    'Standort': 'a map pin', 'Versuchsgelände': 'a fenced field with measuring poles', 'Geräteschuppen': 'a garden tool shed',
    'Audioguide': 'an audio guide device with headphones', 'Bodenbelag': 'floor tiles', 'Vitrine': 'a museum display case',
    'Ladenlokal': 'an empty shop front', 'Einlass': 'an entrance with a ticket check', 'Ladenschluss': 'a shop door locked at night',
    'Laufkundin': 'a woman walking into a shop', 'Bahnsteig': 'a train platform', 'Wochenmarkt': 'a weekly market with stalls',
    'Fensterbrett': 'a windowsill with a plant', 'Treppenhaus': 'a stairwell', 'Waage': 'kitchen scales',
    'Fundbüro': 'a lost property box with an umbrella and a glove', 'Gehstock': 'a walking stick',
    'Gießkanne': 'a watering can', 'Regentonne': 'a rain barrel', 'Regenrinne': 'a gutter on a roof',
    'Lichterkette': 'fairy lights', 'Abfluss': 'a drain in a sink', 'Klebeband': 'a roll of adhesive tape',
    'Armbanduhr': 'a wristwatch', 'Wecker': 'an alarm clock', 'Kreide': 'pieces of chalk',
    'Physiotherapeutin': 'a female physiotherapist', 'Wartezimmer': 'a waiting room with chairs',
}


def slug(word):
    s = word.lower()
    for a, b in (('ä', 'ae'), ('ö', 'oe'), ('ü', 'ue'), ('ß', 'ss')):
        s = s.replace(a, b)
    return 'wv-' + '-'.join(p for p in re.split(r'[^a-z0-9]+', s) if p)


def grids():
    """{'a2-01': [(name, what, label), …16], …}: drawable nouns in unit order, each picture once."""
    units = json.load(open(os.path.join(CONTENT, 'units.json'), encoding='utf-8'))['units']
    out, seen = {}, set()
    for level in LEVELS:
        items = []
        for u in sorted((u for u in units if u['level'] == level), key=lambda u: u['number']):
            for v in u.get('vocab') or []:
                name = slug(v['de'])
                if not v.get('art') or v['de'] in SKIP or name in seen:
                    continue
                seen.add(name)
                meaning = re.split(r'[;,(]', v['en'])[0].strip()
                what = HINT.get(v['de']) or (('an ' if meaning[:1] in 'aeiou' else 'a ') + meaning)
                items.append((name, what, f"{v['art']} {v['de']}"))
        for i in range(0, len(items), 16):
            out[f'{level.lower()}-{i // 16 + 1:02d}'] = items[i:i + 16]
    return out


def prompts():
    lines = ['A2–B2 ÜNİTE KELİMELERİ — kelime resimleri (A1 ızgaralarıyla aynı üslup)',
             'Her istek: aşağıdaki ÜSLUP paragrafı + o resmin listesi (en fazla 16 madde).',
             'Listede 16\'dan az madde varsa: kalan kutuları boş bırak (sadece arka plan).',
             'Kaydet: words-a2-01.jpg … (başlıktaki ad, bu klasöre). Sonra Claude\'a "A2-B2 kelime resimleri hazır" de.',
             'Not: €, % gibi simgeler serbest; yazı ve rakam yine olmasın.', '',
             'ÜSLUP:', STYLE, '']
    for gid, items in grids().items():
        lines.append(f'--- words-{gid}.jpg ---')
        for n, (_, what, label) in enumerate(items, 1):
            lines.append(f'{n}. {what}   [{label}]')
        lines.append('')
    out = os.path.join(GORSELLER, 'KELIME_IZGARALARI_A2_B2.txt')
    open(out, 'w', encoding='utf-8', newline='\r\n').write('\n'.join(lines))
    print('->', out)


def cut_all():
    for gid, items in grids().items():
        found = [p for ext in ('jpg', 'jpeg', 'png', 'webp') for p in glob.glob(os.path.join(GORSELLER, f'words-{gid}.{ext}'))]
        if found:
            cut_grid(gid, found[0], [name for name, _, _ in items])


def status():
    for gid, items in grids().items():
        have = sum(1 for name, _, _ in items if os.path.exists(os.path.join(COVERS, name + '.jpg')))
        print(f'{gid}: {have}/{len(items)}')


if __name__ == '__main__':
    command = sys.argv[1] if len(sys.argv) > 1 else 'status'
    {'prompts': prompts, 'cut-all': cut_all}.get(command, status)()

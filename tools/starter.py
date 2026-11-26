"""Unit 0 of the A1 path ("Başlangıç"): the alphabet, the sounds that differ from Turkish/English spelling and the
first greetings. Numbers use the existing numbers page.

    python -I -X utf8 tools/starter.py      -> Resources/content/starter_a1.json

Texts are {tr, en}; tools/translate.py fills the other learner languages like any content file.
"""
import json
import os

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(REPO, 'Resources', 'content', 'starter_a1.json')

# letter, German name of the letter (what the voice says), an example word
LETTERS = [
    ('A', 'a', 'Apfel'), ('B', 'be', 'Ball'), ('C', 'ce', 'Computer'), ('D', 'de', 'Dach'), ('E', 'e', 'Esel'),
    ('F', 'ef', 'Fisch'), ('G', 'ge', 'Garten'), ('H', 'ha', 'Haus'), ('I', 'i', 'Igel'), ('J', 'jott', 'Jacke'),
    ('K', 'ka', 'Katze'), ('L', 'el', 'Lampe'), ('M', 'em', 'Mutter'), ('N', 'en', 'Name'), ('O', 'o', 'Oma'),
    ('P', 'pe', 'Pizza'), ('Q', 'ku', 'Quiz'), ('R', 'er', 'Rad'), ('S', 'es', 'Sonne'), ('T', 'te', 'Tisch'),
    ('U', 'u', 'Uhr'), ('V', 'fau', 'Vogel'), ('W', 'we', 'Wasser'), ('X', 'iks', 'Taxi'), ('Y', 'üpsilon', 'Yoga'),
    ('Z', 'zett', 'Zug'), ('Ä', 'ä', 'Käse'), ('Ö', 'ö', 'Öl'), ('Ü', 'ü', 'Tür'), ('ß', 'eszett', 'Straße'),
]

# spelling, how to say it (tr, en), example words
SOUNDS = [
    ('ä', 'Açık bir „e“ gibi.', 'Like the "e" in "bed".', ['Käse', 'Mädchen']),
    ('ö', 'Türkçedeki „ö“ gibi.', 'Round your lips and say "e".', ['schön', 'hören']),
    ('ü', 'Türkçedeki „ü“ gibi.', 'Round your lips and say "i".', ['Tür', 'müde']),
    ('ß', 'Çift „s“ gibi: ss.', 'A sharp "ss".', ['Straße', 'groß']),
    ('ei', '„ay“ diye okunur: drei → dray.', 'Says "eye": drei → "dry".', ['drei', 'mein', 'Ei']),
    ('ie', 'Uzun „i“: Liebe → liibe.', 'A long "ee": Liebe.', ['Liebe', 'vier', 'sie']),
    ('eu / äu', '„oy“ diye okunur: heute → hoyte.', 'Says "oy": heute → "hoy-te".', ['heute', 'neu', 'Häuser']),
    ('au', '„av“ diye okunur: Haus → havs.', 'Says "ow" as in "house".', ['Haus', 'Frau']),
    ('sch', '„ş“ diye okunur.', 'Says "sh".', ['Schule', 'Tisch']),
    ('ch', 'a, o, u’dan sonra boğazdan hırıltılı „h“ (Buch); başka yerlerde yumuşak „h“ (ich).',
     'After a, o, u a throaty sound (Buch); elsewhere a soft hiss (ich).', ['Buch', 'ich', 'Milch']),
    ('st / sp', 'Kelime başında „şt / şp“: Straße → ştrase.', 'At the start of a word "sht / shp".', ['Straße', 'sprechen']),
    ('z', '„ts“ diye okunur: Zug → tsuk.', 'Says "ts": Zug → "tsook".', ['Zug', 'zehn']),
    ('v', 'Çoğunlukla „f“ diye okunur: Vater → fater.', 'Usually says "f": Vater.', ['Vater', 'viel']),
    ('w', '„v“ diye okunur: Wasser → vasser.', 'Says "v": Wasser.', ['Wasser', 'wo']),
    ('j', '„y“ diye okunur: ja → ya.', 'Says "y": ja → "yah".', ['ja', 'Jahr']),
    ('h', 'Ünlüden sonra okunmaz, ünlüyü uzatır: Uhr → uur.', 'After a vowel it is silent and makes the vowel long.', ['Uhr', 'gehen']),
    ('-er', 'Kelime sonunda hafif bir „a“ gibi: Mutter → mutta.', 'At the end of a word like a soft "a".', ['Mutter', 'Lehrer']),
    ('-ig', 'Kelime sonunda „-iş“ gibi (ich’teki ses).', 'At the end like the "ch" in ich.', ['zwanzig', 'richtig']),
    ('e', 'Kelime sonundaki „e“ de okunur: Name → naame.', 'A final "e" is spoken too: Name.', ['Name', 'bitte']),
]

GREETINGS = [
    ('Hallo!', 'Merhaba!', 'Hello!'), ('Guten Morgen!', 'Günaydın!', 'Good morning!'),
    ('Guten Tag!', 'İyi günler! / Merhaba!', 'Good day! / Hello!'), ('Guten Abend!', 'İyi akşamlar!', 'Good evening!'),
    ('Gute Nacht!', 'İyi geceler!', 'Good night!'), ('Tschüss!', 'Hoşça kal!', 'Bye!'),
    ('Auf Wiedersehen!', 'Görüşmek üzere! (resmî)', 'Goodbye! (formal)'), ('Danke!', 'Teşekkürler!', 'Thank you!'),
    ('Bitte!', 'Lütfen! / Rica ederim!', 'Please! / You are welcome!'), ('Entschuldigung!', 'Affedersiniz!', 'Excuse me!'),
    ('Wie geht’s?', 'Nasılsın?', 'How are you?'), ('Gut, danke. Und dir?', 'İyiyim, teşekkürler. Ya sen?', 'Fine, thanks. And you?'),
    ('Ja. / Nein.', 'Evet. / Hayır.', 'Yes. / No.'), ('Ich verstehe nicht.', 'Anlamıyorum.', "I don't understand."),
    ('Noch einmal, bitte.', 'Bir kez daha, lütfen.', 'Once more, please.'),
]


def main():
    data = {
        'letters': [{'letter': l, 'name': n, 'word': w} for l, n, w in LETTERS],
        'sounds': [{'spelling': sp, 'say': {'tr': tr, 'en': en}, 'examples': ex} for sp, tr, en, ex in SOUNDS],
        'greetings': [{'de': de, 'mean': {'tr': tr, 'en': en}} for de, tr, en in GREETINGS],
    }
    with open(OUT, 'w', encoding='utf-8', newline='\n') as f:
        json.dump(data, f, ensure_ascii=False, indent=1)
        f.write('\n')
    print(f'{len(LETTERS)} letters, {len(SOUNDS)} sounds, {len(GREETINGS)} greetings -> {OUT}')


if __name__ == '__main__':
    main()

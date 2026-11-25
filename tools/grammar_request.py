"""Writes ChatGPT request files for missing grammar exercises of a level (default A1), so every topic reaches
TARGET exercises. Answers go back in with tools/grammar_import.py.

    python -I -X utf8 tools/grammar_request.py a1        -> ../icerik/A1_gramer_istek_1.txt …
"""
import json
import os
import sys

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ICERIK = os.path.join(os.path.dirname(REPO), 'icerik')
TARGET = 25
PER_FILE = 150

# What each A1 topic should practise (German topic name → hint for ChatGPT).
FOCUS_A1 = {
    'Personalpronomen & sein / haben': 'ich/du/er/sie/es/wir/ihr/sie/Sie ile bin, bist, ist, sind, seid, habe, hast, hat, haben, habt',
    'Verben im Präsens': 'düzenli fiil çekimi: wohne, wohnst, wohnt, wohnen, wohnt; arbeiten (arbeitest), heißen (heißt)',
    'Unregelmäßige Verben': 'fahren/fährt, essen/isst, sprechen/spricht, sehen/sieht, lesen/liest, nehmen/nimmt, schlafen/schläft, geben/gibt',
    'Artikel: der, die, das': 'A1 kelimelerinde doğru belirli artikel; ein/eine; Nominativ',
    'Pluralformen': 'çoğul biçimleri: das Kind → die Kinder, der Tisch → die Tische, die Lampe → die Lampen, das Auto → die Autos',
    'Nominativ & Akkusativ': 'den/einen/keinen (eril Akkusativ), haben/brauchen/kaufen/sehen + Akkusativ',
    'Dativ': 'mit/bei/nach/von/zu + dem/der/den; zum/zur',
    'Pronomen im Akkusativ & Dativ': 'mich/dich/ihn/sie/uns/euch; mir/dir/ihm/ihr/uns/euch/Ihnen',
    'Possessivartikel': 'mein/meine, dein/deine, sein/seine, ihr/ihre, unser/unsere, euer/eure, Ihr/Ihre (Nominativ ve Akkusativ: meinen)',
    'Satzbau: Verb auf Position 2': 'fiil ikinci sırada; zaman/yer başta olunca devrik cümle; W-Fragen',
    'Negation: nicht oder kein?': 'nicht / kein / keine / keinen',
    'Modalverben': 'können, müssen, wollen, möchten, dürfen, sollen çekimi (kann, kannst, muss, will, möchte, darf, soll)',
    'Trennbare Verben': 'aufstehen, einkaufen, anrufen, mitkommen, fernsehen, abholen, ankommen: ayrılan ön ek cümle sonunda',
    'Imperativ': 'Sie-, du- ve ihr-Imperativ: Kommen Sie!, Komm!, Kommt!, Nimm!, Sei!',
    'Perfekt': 'haben/sein + Partizip II: habe gemacht, bin gefahren, ist gekommen, hat gegessen, gelernt, geschlafen',
    'Präteritum: war & hatte': 'war, warst, war, waren, wart; hatte, hattest, hatten',
    'Präpositionen der Zeit': 'am (Montag), um (8 Uhr), im (Juli), von … bis, seit, vor, nach',
    'Präpositionen des Ortes': 'in, an, auf, neben, unter, über, vor, hinter, zwischen (Wo? + Dativ)',
    'Uhrzeit & Datum': 'halb, Viertel nach/vor, um … Uhr, am ersten/zweiten/dritten …, im Januar',
    'Konjunktionen & Antworten': 'und, aber, oder, denn, sondern; ja/nein/doch',
    'gern, lieber, am liebsten': 'gern / lieber / am liebsten; mögen (mag, magst)',
    'Nützliche Strukturen': 'es gibt, ich möchte, wie viel kostet, ich hätte gern, wie geht es, wie spät ist es',
}

PROMPT = '''Sen deneyimli bir Almanca öğretmenisin (Goethe-Zertifikat {LEVEL} seviyesi). Deschly adlı uygulama için boşluk doldurma gramer alıştırmaları yazıyorsun. Öğrenciler Türkçe ve İngilizce konuşuyor.

Her alıştırma TEK satır, alanlar | ile ayrılır (7 alan):
konu | ___ içeren Almanca cümle | doğru cevap | yanlış1;yanlış2;yanlış3 | Türkçe kısa açıklama | English short explanation | cümlenin Türkçesi

Örnek:
Modalverben|Ich ___ heute nicht kommen, ich bin krank.|kann|kannst;können;könnt|ich ile können → kann.|With ich, können becomes kann.|Bugün gelemem, hastayım.

Kurallar:
- "konu" alanına aşağıdaki konu adını AYNEN yaz (Almanca, büyük/küçük harf dahil).
- Cümleler {LEVEL} seviyesinde, günlük hayattan, kısa (4–12 kelime) ve doğal olsun. Sadece {LEVEL} kelimeleri kullan.
- Her cümlede tam olarak bir ___ olsun. Doğru cevap tek bir kelime ya da kısa bir öbek olsun.
- 3 yanlış seçenek gerçekçi olsun (öğrencinin gerçekten karıştırdığı biçimler) ama kesinlikle yanlış olsun.
- HER CÜMLE FARKLI OLSUN: aynı cümleyi sadece isim ya da kişi değiştirerek tekrar YAZMA. Farklı durumlar, farklı fiiller, farklı kelimeler kullan.
- Açıklamalar en fazla 12 kelime, kuralı söylesin.
- Satır dışında hiçbir şey yazma; tüm cevabı tek bir kod bloğunda ver. Cevap yarıda kalırsa "devam" yazdığımda kaldığın yerden devam et.

İstenen konular ve sayılar:
'''


def main():
    level = (sys.argv[1] if len(sys.argv) > 1 else 'a1').lower()
    d = json.load(open(os.path.join(REPO, 'Resources', 'content', f'{level}.json'), encoding='utf-8'))
    counts = {}
    for it in d['grammarItems']:
        counts[it['topic']] = counts.get(it['topic'], 0) + 1
    needs = [(t['de'], TARGET - counts.get(t['id'], 0)) for t in d['grammar'] if counts.get(t['id'], 0) < TARGET]
    files, current, size = [], [], 0
    for name, n in needs:
        if size + n > PER_FILE and current:
            files.append(current)
            current, size = [], 0
        current.append((name, n))
        size += n
    if current:
        files.append(current)
    os.makedirs(ICERIK, exist_ok=True)
    for i, group in enumerate(files, 1):
        lines = [f'- {name}: {n} alıştırma' + (f'  (odak: {FOCUS_A1[name]})' if level == 'a1' and name in FOCUS_A1 else '')
                 for name, n in group]
        body = PROMPT.replace('{LEVEL}', level.upper()) + '\n'.join(lines) + '\n'
        out = os.path.join(ICERIK, f'{level.upper()}_gramer_istek_{i}.txt')
        open(out, 'w', encoding='utf-8', newline='\r\n').write(body)
        print(f'{out}: {sum(n for _, n in group)} exercises, {len(group)} topics')


if __name__ == '__main__':
    main()

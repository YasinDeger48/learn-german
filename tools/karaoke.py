"""Karaoke songs (Şarkılar): traditional German children's songs (public domain: anonymous or authors dead for
more than 70 years), our own instrumental made here from the notes, every syllable timed to its note.

    python -I -X utf8 tools/karaoke.py            makes Resources/content/songs_a1.json and
                                                  ../deschly-site/audio/songs/<id>.mp3 (only changed songs)

The melodies were copied by hand from the scores in the German Wikipedia articles of the songs (the melodies and the
old texts are public domain); harmony, sound and translations are ours. No recording by anyone else is used.

Note format, one lyric line per string:  PITCH/BEATS SYLLABLE …
  PITCH   C4 … B5, with # for sharp and b for flat (Bb4), or R for a rest (syllable "-").
  BEATS   length in quarter notes (0.5 = eighth, 1.5 = dotted quarter).
  SYLLABLE  "Al-" joins the next syllable without a space ("Al-" + "le" = "Alle"); "_" holds the previous syllable
            over this note (a melisma).
"""
import array
import hashlib
import json
import math
import os
import random
import subprocess
import sys
import tempfile
import wave

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import audio_pad  # noqa: E402

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ROOT = os.path.dirname(REPO)
OUT_JSON = os.path.join(REPO, 'Resources', 'content', 'songs_a1.json')
OUT_AUDIO = os.path.join(ROOT, 'deschly-site', 'audio', 'songs')
RATE = 22050
VERSION = 3

KEYS = {'C': 0, 'D': 2, 'F': 5, 'G': 7}

SONGS = [
    {'id': 'a1-lied-01', 'title': 'Alle meine Entchen', 'tr': 'Bütün ördekçiklerim', 'en': 'All my little ducklings',
     'key': 'C', 'bpm': 108, 'meter': 4, 'pickup': 0,
     'lines': [
         ('C4/0.5 Al- D4/0.5 le E4/0.5 mei- F4/0.5 ne G4/1 Ent- G4/1 chen', 'Bütün ördekçiklerim', 'All my little ducklings'),
         ('A4/0.5 schwim- A4/0.5 men A4/0.5 auf A4/0.5 dem G4/2 See,', 'gölde yüzüyor,', 'swim on the lake,'),
         ('A4/0.5 schwim- A4/0.5 men A4/0.5 auf A4/0.5 dem G4/2 See,', 'gölde yüzüyor,', 'swim on the lake,'),
         ('F4/0.5 Köpf- F4/0.5 chen F4/0.5 in F4/0.5 das E4/1 Was- E4/1 ser,', 'başları suyun içinde,', 'little heads in the water,'),
         ('D4/0.5 Schwänz- D4/0.5 chen D4/0.5 in D4/0.5 die C4/2 Höh.', 'kuyrukları havada.', 'little tails up high.'),
     ],
     'questions': [
         {'type': 'mc', 'q': 'Wo schwimmen die Entchen?', 'options': ['Auf dem See', 'Im Haus', 'Im Bus'], 'answer': 0},
         {'type': 'mc', 'q': 'Was ist im Wasser?', 'options': ['Die Köpfchen', 'Die Schwänzchen', 'Die Füße'], 'answer': 0},
         {'type': 'tf', 'q': 'Die Schwänzchen sind in der Höh.', 'answer': 0}]},
    {'id': 'a1-lied-02', 'title': 'Bruder Jakob', 'tr': 'Yakup kardeş', 'en': 'Brother Jacob',
     'key': 'D', 'bpm': 108, 'meter': 4, 'pickup': 0,
     'lines': [
         ('D4/1 Bru- E4/1 der F#4/1 Ja- D4/1 kob,', 'Yakup kardeş,', 'Brother Jacob,'),
         ('D4/1 Bru- E4/1 der F#4/1 Ja- D4/1 kob,', 'Yakup kardeş,', 'Brother Jacob,'),
         ('F#4/1 schläfst G4/1 du A4/2 noch?', 'hâlâ uyuyor musun?', 'are you still asleep?'),
         ('F#4/1 schläfst G4/1 du A4/2 noch?', 'hâlâ uyuyor musun?', 'are you still asleep?'),
         ('A4/0.75 Hörst B4/0.25 du A4/0.5 nicht G4/0.5 die F#4/1 Glo- D4/1 cken?', 'Çanları duymuyor musun?', "Don't you hear the bells?"),
         ('A4/0.75 Hörst B4/0.25 du A4/0.5 nicht G4/0.5 die F#4/1 Glo- D4/1 cken?', 'Çanları duymuyor musun?', "Don't you hear the bells?"),
         ('D4/1 Ding, A3/1 dang, D4/2 dong.', 'Ding, dang, dong.', 'Ding, dang, dong.'),
         ('D4/1 Ding, A3/1 dang, D4/2 dong.', 'Ding, dang, dong.', 'Ding, dang, dong.'),
     ],
     'questions': [
         {'type': 'mc', 'q': 'Was macht Bruder Jakob?', 'options': ['Er schläft.', 'Er isst.', 'Er singt.'], 'answer': 0},
         {'type': 'mc', 'q': 'Was hört man?', 'options': ['Die Glocken', 'Den Hund', 'Das Auto'], 'answer': 0},
         {'type': 'tf', 'q': 'Die Glocken machen „ding, dang, dong“.', 'answer': 0}]},
    {'id': 'a1-lied-03', 'title': 'Hänschen klein', 'tr': 'Küçük Hans', 'en': 'Little Hans',
     'key': 'F', 'bpm': 100, 'meter': 2, 'pickup': 0,
     'lines': [
         ('C5/0.5 Häns- A4/0.5 chen A4/1 klein Bb4/0.5 ging G4/0.5 al- G4/1 lein', 'Küçük Hans tek başına', 'Little Hans went off alone'),
         ('F4/0.5 in G4/0.5 die A4/0.5 wei- Bb4/0.5 te C5/0.5 Welt C5/0.5 hi- C5/1 nein.', 'geniş dünyaya gitti.', 'into the wide world.'),
         ('C5/0.5 Stock A4/0.5 und A4/1 Hut Bb4/0.5 stehn G4/0.5 ihm G4/1 gut,', 'Bastonu ve şapkası ona yakışıyor,', 'Stick and hat suit him well,'),
         ('F4/0.5 ist A4/0.5 gar C5/0.5 wohl- C5/0.5 ge- F4/1 mut. R/1 -', 'keyfi pek yerinde.', 'he is in a good mood.'),
         ('G4/0.5 A- G4/0.5 ber G4/0.5 Mut- G4/0.5 ter G4/0.5 wei- A4/0.5 net Bb4/1 sehr,', 'Ama annesi çok ağlıyor,', 'But mother cries a lot,'),
         ('A4/0.5 hat A4/0.5 ja A4/0.5 nun A4/0.5 kein A4/0.5 Häns- Bb4/0.5 chen C5/1 mehr!', 'artık Hans’ı yok!', 'she has no Hans any more!'),
         ('C5/0.5 Da A4/0.5 be- A4/1 sinnt Bb4/0.5 sich G4/0.5 das G4/1 Kind,', 'Çocuk düşünüyor,', 'The child thinks it over,'),
         ('F4/0.5 läuft A4/0.5 nach C5/0.5 Haus C5/0.5 ge- F4/2 schwind.', 'hemen eve koşuyor.', 'and runs home quickly.'),
     ],
     'questions': [
         {'type': 'mc', 'q': 'Wohin geht Hänschen?', 'options': ['In die weite Welt', 'In die Schule', 'In den Park'], 'answer': 0},
         {'type': 'mc', 'q': 'Wer weint?', 'options': ['Die Mutter', 'Der Vater', 'Hänschen'], 'answer': 0},
         {'type': 'tf', 'q': 'Am Ende läuft das Kind nach Haus.', 'answer': 0}]},
    {'id': 'a1-lied-04', 'title': 'Summ, summ, summ', 'tr': 'Vız, vız, vız', 'en': 'Buzz, buzz, buzz',
     'key': 'G', 'bpm': 100, 'meter': 2, 'pickup': 0,
     'lines': [
         ('D5/1 Summ, C5/1 summ, B4/1 summ! R/1 -', 'Vız, vız, vız!', 'Buzz, buzz, buzz!'),
         ('A4/0.5 Bien- B4/0.5 chen C5/0.5 summ A4/0.5 her- G4/1 um! R/1 -', 'Arıcık, vızılda dur!', 'Little bee, buzz around!'),
         ('B4/0.5 Ei, C5/0.5 wir D5/0.5 tun B4/0.5 dir A4/0.5 nichts B4/0.5 zu- C5/0.5 lei- A4/0.5 de,', 'Ey, sana bir şey yapmayız,', "Hey, we won't hurt you,"),
         ('B4/0.5 flieg C5/0.5 nur D5/0.5 aus B4/0.5 in A4/0.5 Wald B4/0.5 und C5/0.5 Hei- A4/0.5 de!', 'ormana ve kıra uç git!', 'fly out to the woods and the heath!'),
         ('D5/1 Summ, C5/1 summ, B4/1 summ! R/1 -', 'Vız, vız, vız!', 'Buzz, buzz, buzz!'),
         ('A4/0.5 Bien- B4/0.5 chen C5/0.5 summ A4/0.5 her- G4/1 um! R/1 -', 'Arıcık, vızılda dur!', 'Little bee, buzz around!'),
     ],
     'questions': [
         {'type': 'mc', 'q': 'Wer summt?', 'options': ['Das Bienchen', 'Der Hund', 'Die Katze'], 'answer': 0},
         {'type': 'mc', 'q': 'Wohin fliegt das Bienchen?', 'options': ['In Wald und Heide', 'In die Stadt', 'Ins Haus'], 'answer': 0},
         {'type': 'tf', 'q': 'Wir tun dem Bienchen nichts.', 'answer': 0}]},
    {'id': 'a1-lied-05', 'title': 'Auf der Mauer, auf der Lauer', 'tr': 'Duvarın üstünde, pusuda', 'en': 'On the wall, lying in wait',
     'key': 'F', 'bpm': 92, 'meter': 2, 'pickup': 0,
     'lines': [
         ('F4/0.5 Auf F4/0.5 der F4/0.5 Mau- G4/0.5 er, A4/0.5 auf A4/0.5 der A4/0.5 Lau- A4/0.5 er', 'Duvarın üstünde, pusuda', 'On the wall, lying in wait'),
         ('G4/0.5 sitzt F4/0.5 ’ne G4/0.5 klei- A4/0.5 ne F4/1 Wan- F4/1 ze.', 'küçük bir tahtakurusu oturuyor.', 'sits a little bug.'),
         ('A4/0.5 Auf A4/0.5 der A4/0.5 Mau- Bb4/0.5 er, C5/0.5 auf C5/0.5 der C5/0.5 Lau- C5/0.5 er', 'Duvarın üstünde, pusuda', 'On the wall, lying in wait'),
         ('Bb4/0.5 sitzt A4/0.5 ’ne Bb4/0.5 klei- C5/0.5 ne A4/1 Wan- A4/1 ze.', 'küçük bir tahtakurusu oturuyor.', 'sits a little bug.'),
         ('C5/0.5 Seht C5/0.5 euch C5/0.5 nur C5/0.5 die D5/0.5 Wan- D5/0.5 ze D5/1 an,', 'Şu böceğe bir bakın,', 'Just look at the bug,'),
         ('Bb4/0.5 wie Bb4/0.5 die Bb4/0.5 Wan- Bb4/0.5 ze C5/0.5 tan- C5/0.5 zen C5/1 kann!', 'nasıl da dans edebiliyor!', 'how the bug can dance!'),
         ('F4/0.5 Auf F4/0.5 der F4/0.5 Mau- G4/0.5 er, A4/0.5 auf A4/0.5 der A4/0.5 Lau- A4/0.5 er', 'Duvarın üstünde, pusuda', 'On the wall, lying in wait'),
         ('G4/0.5 sitzt F4/0.5 ’ne G4/0.5 klei- A4/0.5 ne F4/1 Wan- F4/1 ze.', 'küçük bir tahtakurusu oturuyor.', 'sits a little bug.'),
     ],
     'questions': [
         {'type': 'mc', 'q': 'Wo sitzt die Wanze?', 'options': ['Auf der Mauer', 'Auf dem Tisch', 'Im Bett'], 'answer': 0},
         {'type': 'mc', 'q': 'Was kann die Wanze?', 'options': ['Tanzen', 'Schwimmen', 'Lesen'], 'answer': 0},
         {'type': 'tf', 'q': 'Die Wanze ist groß.', 'answer': 1}]},
    {'id': 'a1-lied-06', 'title': 'Häschen in der Grube', 'tr': 'Çukurdaki tavşancık', 'en': 'Little bunny in the hollow',
     'key': 'D', 'bpm': 92, 'meter': 2, 'pickup': 0,
     'lines': [
         ('D4/0.5 Häs- E4/0.5 chen F#4/0.5 in G4/0.5 der A4/1 Gru- A4/1 be', 'Tavşancık çukurda', 'Little bunny in the hollow'),
         ('B4/0.5 saß G4/0.5 _ D5/0.5 und B4/0.5 _ A4/1 schlief, R/1 -', 'oturup uyudu,', 'sat and slept,'),
         ('B4/0.5 saß G4/0.5 _ D5/0.5 und B4/0.5 _ A4/1 schlief. R/1 -', 'oturup uyudu.', 'sat and slept.'),
         ('A4/0.5 Ar- G4/0.5 mes G4/0.5 Häs- G4/0.5 chen, G4/0.5 bist F#4/0.5 du F#4/1 krank,', 'Zavallı tavşancık, hasta mısın,', 'Poor little bunny, are you ill,'),
         ('F#4/0.5 dass E4/0.5 du F#4/0.5 nicht E4/0.5 mehr D4/0.5 hüp- F#4/0.5 fen A4/1 kannst?', 'artık zıplayamıyor musun?', "that you can't hop any more?"),
         ('A4/0.5 Häs- A4/0.5 chen, D5/1 hüpf! A4/0.5 Häs- A4/0.5 chen, D5/1 hüpf!', 'Tavşancık, zıpla! Tavşancık, zıpla!', 'Little bunny, hop! Little bunny, hop!'),
         ('A4/1 Häs- A4/1 chen, D4/1 hüpf! R/1 -', 'Tavşancık, zıpla!', 'Little bunny, hop!'),
     ],
     'questions': [
         {'type': 'mc', 'q': 'Wo sitzt das Häschen?', 'options': ['In der Grube', 'Auf dem Baum', 'Im Auto'], 'answer': 0},
         {'type': 'mc', 'q': 'Was macht das Häschen zuerst?', 'options': ['Es schläft.', 'Es singt.', 'Es isst.'], 'answer': 0},
         {'type': 'tf', 'q': 'Am Ende hüpft das Häschen.', 'answer': 0}]},
    {'id': 'a1-lied-07', 'title': 'Kommt ein Vogel geflogen', 'tr': 'Bir kuş uçarak geliyor', 'en': 'A little bird comes flying',
     'key': 'F', 'bpm': 120, 'meter': 3, 'pickup': 1,
     'lines': [
         ('A4/0.5 Kommt Bb4/0.5 ein C5/1 Vo- A4/1 gel A4/1 ge- A4/1 flo- G4/1 gen,', 'Bir kuş uçarak geliyor,', 'A little bird comes flying,'),
         ('G4/0.5 setzt A4/0.5 sich Bb4/1 nie- G4/1 der G4/0.5 auf D5/0.5 mein C5/1 Fuß, R/1 -', 'ayağıma konuyor,', 'and sits down on my foot,'),
         ('A4/0.5 hat Bb4/0.5 ein C5/1 Zet- A4/1 tel A4/1 im A4/1 Schna- G4/1 bel,', 'gagasında bir not var,', 'it has a note in its beak,'),
         ('G4/0.5 von A4/0.5 der Bb4/1 Mut- E4/1 ter E4/1 ein F4/1 Gruß. R/1 -', 'annemden bir selam.', 'a greeting from mother.'),
     ],
     'questions': [
         {'type': 'mc', 'q': 'Wer kommt geflogen?', 'options': ['Ein Vogel', 'Ein Flugzeug', 'Eine Biene'], 'answer': 0},
         {'type': 'mc', 'q': 'Was hat der Vogel im Schnabel?', 'options': ['Einen Zettel', 'Ein Brot', 'Einen Apfel'], 'answer': 0},
         {'type': 'tf', 'q': 'Der Gruß ist vom Vater.', 'answer': 1}]},
    {'id': 'a1-lied-08', 'title': 'Schneeflöckchen, Weißröckchen', 'tr': 'Kar tanesi, beyaz etekli', 'en': 'Little snowflake, little white skirt',
     'key': 'C', 'bpm': 112, 'meter': 3, 'pickup': 1,
     'lines': [
         ('E4/0.5 Schnee- F4/0.5 _ G4/1 flöck- G4/1 chen, A4/1 Weiß- D4/1 röck- D4/1 chen,', 'Kar tanesi, beyaz etekli,', 'Little snowflake, little white skirt,'),
         ('D4/0.5 wann E4/0.5 _ F4/1 kommst F4/1 du G4/1 ge- E4/2 schneit?', 'ne zaman yağacaksın?', 'when will you come snowing down?'),
         ('E4/0.5 Du F4/0.5 _ G4/1 wohnst G4/1 in C5/1 den B4/1 Wol- A4/1 ken,', 'Bulutlarda yaşıyorsun,', 'You live up in the clouds,'),
         ('G4/0.5 dein F4/0.5 _ E4/1 Weg F4/1 ist D4/1 so C4/2 weit.', 'yolun çok uzun.', 'your way is so far.'),
     ],
     'questions': [
         {'type': 'mc', 'q': 'Wo wohnt das Schneeflöckchen?', 'options': ['In den Wolken', 'Im Meer', 'Im Wald'], 'answer': 0},
         {'type': 'mc', 'q': 'Welche Farbe hat das Röckchen?', 'options': ['Weiß', 'Rot', 'Grün'], 'answer': 0},
         {'type': 'tf', 'q': 'Der Weg ist kurz.', 'answer': 1}]},
    {'id': 'a1-lied-09', 'title': 'Grün, grün, grün', 'tr': 'Yeşil, yeşil, yeşil', 'en': 'Green, green, green',
     'key': 'G', 'bpm': 96, 'meter': 2, 'pickup': 0,
     'lines': [
         ('G4/1 Grün, G4/1 grün, A4/1 grün A4/1 sind F#4/0.5 al- F#4/0.5 le E4/0.5 mei- F#4/0.5 ne G4/1 Klei- D4/1 der;', 'Yeşil, yeşil, yeşil bütün elbiselerim;', 'Green, green, green are all my clothes;'),
         ('G4/1 grün, G4/1 grün, A4/1 grün A4/1 ist F#4/0.5 al- F#4/0.5 les, E4/0.5 was F#4/0.5 ich G4/1 hab. R/1 -', 'yeşil, yeşil, yeşil her şeyim.', 'green, green, green is all I have.'),
         ('B4/1 Da- B4/0.5 rum D5/0.5 _ C5/1 lieb C5/1 ich A4/0.5 al- A4/0.5 les, A4/0.5 was C5/0.5 so B4/1 grün B4/1 ist,', 'Bu yüzden yeşil olan her şeyi severim,', "That's why I love everything that's green,"),
         ('G4/1 weil G4/1 mein A4/1 Schatz A4/1 ein F#4/1 Jä- E4/0.5 ger F#4/0.5 _ G4/1 ist. R/1 -', 'çünkü sevgilim bir avcı.', 'because my sweetheart is a hunter.'),
     ],
     'questions': [
         {'type': 'mc', 'q': 'Welche Farbe haben die Kleider?', 'options': ['Grün', 'Blau', 'Gelb'], 'answer': 0},
         {'type': 'mc', 'q': 'Was ist der Schatz?', 'options': ['Ein Jäger', 'Ein Bäcker', 'Ein Lehrer'], 'answer': 0},
         {'type': 'tf', 'q': 'Ich liebe alles, was grün ist.', 'answer': 0}]},
    {'id': 'a1-lied-10', 'title': 'Kuckuck, Kuckuck', 'tr': 'Guguk, guguk', 'en': 'Cuckoo, cuckoo',
     'key': 'G', 'bpm': 138, 'meter': 3, 'pickup': 0,
     'lines': [
         ('D5/1 Kuk- B4/1 kuck, R/1 - D5/1 Kuk- B4/1 kuck, R/1 -', 'Guguk, guguk,', 'Cuckoo, cuckoo,'),
         ('A4/1 ruft’s G4/1 aus A4/1 dem G4/3 Wald.', 'ormandan sesleniyor.', 'it calls from the woods.'),
         ('A4/1 Las- A4/1 set B4/1 uns C5/2 sin- A4/1 gen,', 'Haydi şarkı söyleyelim,', "Let's sing,"),
         ('B4/1 tan- B4/1 zen C5/1 und D5/2 sprin- B4/1 gen,', 'dans edip zıplayalım,', 'dance and jump,'),
         ('D5/2 Früh- B4/1 ling, D5/2 Früh- B4/1 ling', 'Bahar, bahar', 'Spring, spring'),
         ('C5/1 wird B4/1 es A4/1 nun G4/3 bald.', 'yakında geliyor.', 'will soon be here.'),
     ],
     'questions': [
         {'type': 'mc', 'q': 'Wer ruft aus dem Wald?', 'options': ['Der Kuckuck', 'Der Hund', 'Die Kuh'], 'answer': 0},
         {'type': 'mc', 'q': 'Was wird es bald?', 'options': ['Frühling', 'Winter', 'Nacht'], 'answer': 0},
         {'type': 'tf', 'q': 'Wir singen, tanzen und springen.', 'answer': 0}]},
    {'id': 'a1-lied-11', 'title': 'Alle Vögel sind schon da', 'tr': 'Bütün kuşlar geldi bile', 'en': 'All the birds are already here',
     'key': 'D', 'bpm': 112, 'meter': 4, 'pickup': 0,
     'lines': [
         ('D4/1.5 Al- F#4/0.5 le A4/1 Vö- D5/1 gel B4/1 sind D5/0.5 schon B4/0.5 _ A4/2 da,', 'Bütün kuşlar geldi bile,', 'All the birds are already here,'),
         ('G4/1.5 al- A4/0.5 le F#4/1 Vö- D4/1 gel, E4/2 al- D4/1 le. R/1 -', 'bütün kuşlar, hepsi.', 'all the birds, all of them.'),
         ('A4/1 Welch A4/1 ein G4/1 Sin- G4/1 gen, F#4/1 Mu- A4/0.5 si- F#4/0.5 _ E4/2 ziern,', 'Ne şarkılar, ne müzik,', 'What singing, what music,'),
         ('A4/1 Pfei- A4/1 fen, G4/1 Zwit- G4/1 schern, F#4/1 Ti- A4/0.5 ri- F#4/0.5 _ E4/2 liern!', 'ıslık, cıvıltı, şakıma!', 'whistling, chirping, trilling!'),
         ('D4/1.5 Früh- F#4/0.5 ling A4/1 will D5/1 nun B4/1 ein- D5/0.5 mar- B4/0.5 _ A4/2 schiern,', 'Bahar içeri girmek istiyor,', 'Spring wants to march in,'),
         ('G4/1.5 kommt A4/0.5 mit F#4/1 Sang D4/1 und E4/2 Schal- D4/1 le. R/1 -', 'şarkıyla, neşeyle geliyor.', 'it comes with song and sound.'),
     ],
     'questions': [
         {'type': 'mc', 'q': 'Wer ist schon da?', 'options': ['Alle Vögel', 'Alle Katzen', 'Alle Kinder'], 'answer': 0},
         {'type': 'mc', 'q': 'Wer will einmarschieren?', 'options': ['Der Frühling', 'Der Winter', 'Der Herbst'], 'answer': 0},
         {'type': 'tf', 'q': 'Die Vögel singen und pfeifen.', 'answer': 0}]},
]

NAMES = {'C': 0, 'D': 2, 'E': 4, 'F': 5, 'G': 7, 'A': 9, 'B': 11}


def midi(pitch):
    note, rest = pitch[0], pitch[1:]
    shift = 0
    while rest and rest[0] in '#b':
        shift += 1 if rest[0] == '#' else -1
        rest = rest[1:]
    return 12 * (int(rest) + 1) + NAMES[note] + shift


def freq(m):
    return 440.0 * 2 ** ((m - 69) / 12)


def parse(song):
    """Notes with absolute beats, and per lyric line its syllables (text, join, start beat, end beat)."""
    beat = 0.0
    notes, lines = [], []
    for text, tr, en in song['lines']:
        syllables = []
        tokens = text.split()
        for i in range(0, len(tokens), 2):
            pitch, length = tokens[i].split('/')
            length = float(length)
            word = tokens[i + 1]
            if pitch != 'R':
                notes.append((beat, length, midi(pitch)))
                if word == '_' and syllables:
                    syllables[-1]['end'] = beat + length
                elif word != '-':
                    join = word.endswith('-')
                    syllables.append({'text': word[:-1] if join else word, 'join': join, 'start': beat, 'end': beat + length})
            beat += length
        lines.append({'syllables': syllables, 'tr': tr, 'en': en})
    return notes, lines, beat


def chords_for(song, notes, total):
    """One chord per bar (I, IV or V7 of the key), the one whose notes the melody uses most in that bar."""
    key = KEYS[song['key']]
    meter = song['meter']
    options = {'I': [0, 4, 7], 'IV': [5, 9, 0], 'V': [7, 11, 2, 5]}
    start = -song['pickup']
    bars = []
    while start < total:
        weights = {name: 0.0 for name in options}
        for beat, length, m in notes:
            overlap = max(0.0, min(beat + length, start + meter) - max(beat, start))
            if overlap <= 0:
                continue
            pc = (m - key) % 12
            for name, tones in options.items():
                if pc in tones:
                    weights[name] += overlap * (1.2 if beat == max(start, beat) and pc == tones[0] else 1.0)
        best = max(weights, key=lambda n: (weights[n], n == 'I'))
        bars.append((start, best))
        start += meter
    if bars:
        bars[-1] = (bars[-1][0], 'I')
    return [(max(0.0, s), [key + t for t in options[name]]) for s, name in bars]


# MARK: sound

_pluck_cache = {}


def pluck(m, seconds):
    """A plucked string (Karplus-Strong), cached per pitch."""
    k = (m, round(seconds, 2))
    if k in _pluck_cache:
        return _pluck_cache[k]
    f = freq(m)
    n = max(2, int(RATE / f))
    rnd = random.Random(m)
    buf = [rnd.uniform(-1, 1) for _ in range(n)]
    out = []
    total = int(seconds * RATE)
    i = 0
    for _ in range(total):
        a = buf[i % n]
        b = buf[(i + 1) % n]
        v = 0.996 * 0.5 * (a + b)
        buf[i % n] = v
        out.append(a)
        i += 1
    _pluck_cache[k] = out
    return out


def keys_tone(m, seconds):
    """The melody: a soft celesta-like tone (FM with a fast-decaying index)."""
    f = freq(m)
    total = int((seconds + 0.35) * RATE)
    out = []
    for i in range(total):
        t = i / RATE
        env = math.exp(-t * 2.6) * min(1.0, t / 0.008)
        if t > seconds:
            env *= max(0.0, 1 - (t - seconds) / 0.35)
        index = 1.4 * math.exp(-t * 6)
        out.append(env * (math.sin(2 * math.pi * f * t + index * math.sin(2 * math.pi * f * t))
                          + 0.22 * math.sin(4 * math.pi * f * t) * math.exp(-t * 5)))
    return out


def add(track, samples, at, gain):
    start = int(at * RATE)
    for j, s in enumerate(samples):
        i = start + j
        if i >= len(track):
            break
        track[i] += s * gain


def render(song, notes, total_beats, path):
    spb = 60.0 / song['bpm']
    meter = song['meter']
    intro = meter * spb  # one bar of chords before the singing starts
    seconds = intro + total_beats * spb + 2.5
    track = [0.0] * int(seconds * RATE)
    chords = chords_for(song, notes, total_beats)
    # Count-in bar and accompaniment: bass on 1, strummed chord on the other beats (waltz in 3/4).
    intro_chord = chords[0][1] if chords else [KEYS[song['key']] + 60]
    for b in range(meter):
        add(track, pluck(intro_chord[0] + 36 - 12, 0.6), b * spb, 0.30 if b == 0 else 0.0)
        for j, pc in enumerate(intro_chord[:3]):
            add(track, pluck(48 + (pc % 12) + 12, 0.7), b * spb + j * 0.012, 0.10)
    for index, (bar_start, tones) in enumerate(chords):
        bar_end = chords[index + 1][0] if index + 1 < len(chords) else total_beats
        b = bar_start
        while b < bar_end - 1e-6:
            at = intro + b * spb
            first = abs((b - bar_start)) < 1e-6
            if first:
                add(track, pluck(36 + (tones[0] % 12), 1.2), at, 0.32)
            if not first or meter == 2:
                for j, pc in enumerate(tones[:3]):
                    add(track, pluck(55 + ((pc - 55) % 12), 0.7), at + j * 0.014, 0.11)
            b += 1
    # Shaker on the off-beats: a short noise tick.
    rnd = random.Random(7)
    tick = [rnd.uniform(-1, 1) * math.exp(-i / (RATE * 0.012)) for i in range(int(RATE * 0.05))]
    b = 0.5
    while b < total_beats:
        add(track, tick, intro + b * spb, 0.05)
        b += 1
    # The melody on top.
    for beat, length, m in notes:
        add(track, keys_tone(m + 12, length * spb * 0.95), intro + beat * spb, 0.30)
    peak = max(1e-6, max(abs(x) for x in track))
    scale = 0.89 / peak
    pcm = array.array('h', (int(max(-1, min(1, x * scale)) * 32767) for x in track))
    with tempfile.TemporaryDirectory() as folder:
        wav = os.path.join(folder, 'song.wav')
        with wave.open(wav, 'wb') as w:
            w.setnchannels(1)
            w.setsampwidth(2)
            w.setframerate(RATE)
            w.writeframes(pcm.tobytes())
        os.makedirs(os.path.dirname(path), exist_ok=True)
        subprocess.run([audio_pad.ffmpeg(), '-y', '-loglevel', 'error', '-i', wav,
                        '-af', 'aecho=0.8:0.7:40:0.12,loudnorm=I=-18:TP=-2', '-ac', '1', '-ar', '24000',
                        '-c:a', 'libmp3lame', '-b:a', '96k', path], check=True)
    return intro, seconds


def song_hash(song):
    return hashlib.sha256(json.dumps([VERSION, song], ensure_ascii=False, sort_keys=True).encode('utf-8')).hexdigest()[:16]


def main():
    old = {}
    if os.path.exists(OUT_JSON):
        for s in json.load(open(OUT_JSON, encoding='utf-8')).get('songs', []):
            old[s['id']] = s
    out = []
    for song in SONGS:
        notes, lines, total = parse(song)
        spb = 60.0 / song['bpm']
        digest = song_hash(song)
        mp3 = os.path.join(OUT_AUDIO, song['id'] + '.mp3')
        previous = old.get(song['id'])
        if previous and previous.get('hash') == digest and os.path.exists(mp3):
            out.append(previous)
            continue
        intro, seconds = render(song, notes, total, mp3)
        entry_lines, timeline = [], []
        for line in lines:
            syl = [{'text': s['text'], 'join': s['join'],
                    'start': round(intro + s['start'] * spb, 3), 'end': round(intro + s['end'] * spb, 3)}
                   for s in line['syllables']]
            text = ''
            for s in line['syllables']:
                text += s['text'] + ('' if s['join'] else ' ')
            entry_lines.append({'part': 'verse', 'who': 'Alle', 'de': text.strip(), 'tr': line['tr'], 'en': line['en'], 'syl': syl})
            timeline.append({'start': syl[0]['start'] if syl else 0, 'end': syl[-1]['end'] if syl else 0})
        out.append({'id': song['id'], 'title': song['title'], 'title_tr': song['tr'], 'title_en': song['en'],
                    'bpm': song['bpm'], 'lines': entry_lines, 'questions': song['questions'], 'timeline': timeline,
                    'duration': round(seconds, 2), 'audio': f"songs/{song['id']}.mp3", 'hash': digest})
        print(f"  {song['id']} {song['title']}: {seconds:.0f} s")
    with open(OUT_JSON, 'w', encoding='utf-8', newline='\n') as f:
        json.dump({'level': 'A1', 'songs': out}, f, ensure_ascii=False, indent=1)
        f.write('\n')
    print(f'{len(out)} songs in {OUT_JSON}')


if __name__ == '__main__':
    main()

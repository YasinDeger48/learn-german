"""Pictures for every unit word card that still shows a letter: A1 cards without a sticker, and in A2–B2 the abstract
nouns, verbs, adjectives and small words (tools/vocab_pictures.py drew only concrete nouns). Codex draws them as
4×4 sticker grids; an abstract word gets a clear symbol (Frist: a calendar with a clock), an action a small scene.

    python -I -X utf8 tools/unit_pictures_rest.py prompts   ../icerik/gorseller/KELIME_IZGARALARI_UNITE_KALAN.txt and
                                                           tools/unit_pictures_rest.json (the order of every grid)
    python -I -X utf8 tools/unit_pictures_rest.py cut-all  cuts every words-unite-kalan-NN.(jpg|png|webp) into
                                                           Resources/Covers/<name>.jpg (wp-a1-<id> or wv-<slug>)
    python -I -X utf8 tools/unit_pictures_rest.py status

The app finds the files by name: A1 cards use wp-a1-<word id>, A2–B2 cards wv-<slug> (UnitWord.picture).
"""
import glob
import json
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from word_pictures import CONTENT, COVERS, GORSELLER, cut_grid  # noqa: E402

TOOLS = os.path.dirname(os.path.abspath(__file__))
GRIDS = os.path.join(TOOLS, 'unit_pictures_rest.json')
PROMPTS = os.path.join(GORSELLER, 'KELIME_IZGARALARI_UNITE_KALAN.txt')
SITE_COVERS = os.path.join(os.path.dirname(os.path.dirname(TOOLS)), 'deschly-site', 'covers')

STYLE = ('A 4×4 grid of 16 separate square stickers on a plain warm off-white background (#F7F7F4), all the same size, '
         'with equal wide gaps between them. Each sticker shows ONE simple idea, centred, flat minimal style matching '
         'the Deschly app icon, soft colours from the palette ink #0E0F0C, gold #F2C230, blue #2F5BEA, red #C8323A, '
         'green #157A41. For an abstract word draw a clear everyday symbol of its meaning (deadline: a calendar page '
         'with a clock; agreement: two hands shaking; exception: one red apple among green ones). For a verb draw a '
         'small person doing it; for an adjective an object that shows it; for a time word a clock, sun or calendar. '
         'Simple symbols like € % ? ! arrows and ticks are fine. No words, no letters, no numbers. '
         'Square image 2048×2048. Order, row by row, left to right:')


def slug(de):
    s = de.lower()
    for a, b in [('ä', 'ae'), ('ö', 'oe'), ('ü', 'ue'), ('ß', 'ss')]:
        s = s.replace(a, b)
    return 'wv-' + '-'.join(p for p in re.split(r'[^a-z0-9]+', s) if p)


def has_picture(name):
    return (os.path.exists(os.path.join(COVERS, name + '.jpg'))
            or os.path.exists(os.path.join(SITE_COVERS, name + '.jpg')))


def missing():
    """[(file name, German as shown, English meaning, unit id)] of every unit card without a picture, unit by unit."""
    units = json.load(open(os.path.join(CONTENT, 'units.json'), encoding='utf-8'))['units']
    a1 = {w['id']: w for w in json.load(open(os.path.join(CONTENT, 'a1.json'), encoding='utf-8'))['words']}
    out, seen = [], set()
    for u in units:
        if u.get('vocab'):
            cards = [(slug(w['de']), (w['art'] + ' ' if w.get('art') else '') + w['de'], w['en']) for w in u['vocab']]
        else:
            cards = []
            for wid in (u.get('pictures') or []) + (u.get('extra') or []):
                w = a1.get(wid)
                if w:
                    noun = w.get('type') in ('der', 'die', 'das')
                    cards.append((f'wp-a1-{wid}', (w['type'] + ' ' if noun else '') + w['de'], w['mean']['en']))
        for name, de, en in cards:
            if name not in seen and not has_picture(name):
                seen.add(name)
                out.append((name, de, en, u['id']))
    return out


def prompts():
    items = missing()
    grids = {}
    for n in range(0, len(items), 16):
        grids[f'unite-kalan-{n // 16 + 1:02d}'] = [i[0] for i in items[n:n + 16]]
    json.dump(grids, open(GRIDS, 'w', encoding='utf-8', newline='\n'), indent=1)
    by_name = {i[0]: i for i in items}
    lines = [f'ÜNİTE KARTLARI — resmi olmayan {len(items)} kelime, {len(grids)} resim (her biri 16 çıkartma)',
             'Ünitelerdeki kelime kartlarının hepsinin resmi olsun: soyut kelimeler, fiiller, sıfatlar ve küçük kelimeler.',
             'Her istek: aşağıdaki ÜSLUP paragrafı + o resmin 16 maddelik listesi (Almanca ve İngilizce anlamı).',
             f'Kaydet: words-unite-kalan-01.jpg … words-unite-kalan-{len(grids):02d}.jpg (bu klasöre).',
             'Son resimde 16\'dan az madde varsa kalan kareleri boş bırak.', '', 'ÜSLUP:', STYLE, '']
    for gid, names in grids.items():
        lines.append(f'--- words-{gid}.jpg ---')
        for k, name in enumerate(names, 1):
            _, de, en, unit = by_name[name]
            lines.append(f'{k}. {de} — {en}   ({unit})')
        lines.append('')
    open(PROMPTS, 'w', encoding='utf-8', newline='\r\n').write('\n'.join(lines))
    print('->', PROMPTS, len(items), 'cards in', len(grids), 'grids')


def cut_all():
    grids = json.load(open(GRIDS, encoding='utf-8'))
    for gid, names in grids.items():
        found = [p for ext in ('jpg', 'jpeg', 'png', 'webp') for p in glob.glob(os.path.join(GORSELLER, f'words-{gid}.{ext}'))]
        if found:
            cut_grid(gid, found[0], names)


def status():
    print(len(missing()), 'unit cards without a picture')
    if os.path.exists(GRIDS):
        grids = json.load(open(GRIDS, encoding='utf-8'))
        done = sum(1 for g in grids if glob.glob(os.path.join(GORSELLER, f'words-{g}.*')))
        print(f'{len(grids)} grids planned, {done} drawn')


if __name__ == '__main__':
    {'prompts': prompts, 'cut-all': cut_all}.get(sys.argv[1] if len(sys.argv) > 1 else '', status)()

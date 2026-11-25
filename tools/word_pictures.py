"""Word pictures for the path units: 16 concrete nouns per unit, drawn by ChatGPT as one 4×4 sticker grid.

    python -I -X utf8 tools/word_pictures.py prompts          ../icerik/gorseller/KELIME_IZGARALARI_A1.txt
    python -I -X utf8 tools/word_pictures.py cut a1-03 PATH   cuts a 4×4 grid image into 16 pictures
    python -I -X utf8 tools/word_pictures.py cut-all          cuts every ../icerik/gorseller/words-a1-NN.(jpg|png)
    python -I -X utf8 tools/word_pictures.py status

Pictures are saved as Resources/Covers/wp-<level>-<word id>.jpg (square, 360 px), so Covers.image() finds them
in the app and tools/publish_content.py can publish them like the covers.
The grid is cut into equal cells; each cell is trimmed to the sticker (pixels that differ from the background)
and centred on the background colour.
"""
import glob
import json
import os
import sys

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CONTENT = os.path.join(REPO, 'Resources', 'content')
COVERS = os.path.join(REPO, 'Resources', 'Covers')
GORSELLER = os.path.join(os.path.dirname(REPO), 'icerik', 'gorseller')
SIZE = 360

# 16 word ids per unit (A1). Duplicates across units are fine: the picture is shared.
PICTURE_WORDS = {
    'a1-01': [16, 28, 31, 80, 81, 82, 83, 84, 85, 87, 88, 89, 381, 421, 969, 417],
    'a1-02': [41, 42, 43, 44, 45, 47, 48, 49, 50, 51, 52, 55, 56, 57, 69, 58],
    'a1-03': [178, 186, 181, 189, 197, 198, 204, 205, 203, 202, 206, 194, 184, 215, 218, 438],
    'a1-04': [238, 240, 239, 246, 254, 255, 257, 258, 266, 267, 269, 271, 272, 273, 275, 735],
    'a1-05': [280, 281, 283, 284, 286, 287, 288, 289, 291, 293, 294, 295, 297, 298, 299, 302],
    'a1-06': [113, 730, 145, 172, 123, 125, 127, 128, 139, 140, 141, 142, 713, 131, 523, 861],
    'a1-07': [327, 328, 329, 331, 332, 333, 334, 355, 357, 363, 364, 365, 366, 371, 373, 390],
    'a1-08': [487, 488, 489, 490, 491, 492, 493, 495, 496, 497, 399, 510, 511, 1846, 1844, 1014],
    'a1-09': [395, 396, 397, 402, 404, 413, 414, 415, 416, 420, 1701, 430, 410, 411, 394, 401],
    'a1-10': [450, 455, 459, 460, 461, 463, 468, 475, 477, 479, 483, 1710, 541, 542, 538, 1755],
    'a1-11': [324, 326, 335, 336, 344, 346, 347, 370, 379, 734, 380, 838, 852, 348, 350, 351],
    'a1-12': [368, 1032, 827, 365, 366, 803, 802, 728, 428, 1715, 92, 95, 144, 317, 381, 246],
}

# What to draw when the English meaning alone is unclear or abstract.
DRAW = {
    16: 'a blank name tag badge', 28: 'two speech bubbles', 31: 'a big question mark', 80: 'green countryside with a farmhouse',
    81: 'a city skyline', 82: 'a small village with a church', 83: 'a house with a letterbox', 84: 'a street with houses',
    85: 'a front door with a small blank number plate', 87: 'a classic telephone handset', 88: 'an envelope with an @ sign',
    89: 'a globe with a small plane', 381: 'an ID card with a photo', 421: 'a smartphone', 969: 'a thick dictionary', 417: 'a pencil',
    57: 'a family of four', 69: 'a birthday cake with candles', 58: 'two friends waving', 215: 'a restaurant menu card',
    218: 'a restaurant bill on a small plate', 438: 'a waiter with a tray', 246: 'banknotes and coins', 254: 'a supermarket checkout',
    255: 'a bank card', 258: 'a paper shopping bag', 123: 'a sunrise', 125: 'the sun high at noon', 127: 'a sunset', 128: 'a moon and stars',
    139: 'spring blossom on a branch', 140: 'summer sun over a beach', 141: 'autumn leaves', 142: 'a snowman in winter',
    131: 'a hammock between two trees', 145: 'a wall calendar', 172: 'breakfast: coffee, bread roll, egg', 357: 'a town square with a fountain',
    399: 'a doctor with a stethoscope', 1032: 'a public office building', 827: 'a service counter with a bell', 803: 'a cash machine',
    802: 'a bank book', 144: 'a calendar page with one day circled', 368: 'a town hall with a clock tower', 410: 'an exam paper with ticks',
    411: 'a schoolbag with an exercise book', 394: 'an office building', 401: 'a shop assistant behind a counter', 396: 'a boss at a desk',
    348: 'a departure board without letters', 350: 'a clock next to a train', 351: 'a footpath through a meadow', 838: 'a passport with a stamp',
    92: 'a paper form with lines and boxes', 95: 'a pen signing a line', 1844: 'a sticking plaster', 1014: 'an ambulance',
}

STYLE = ('A 4×4 grid of 16 separate square stickers on a plain warm off-white background (#F7F7F4), all the same size, '
         'with equal wide gaps between them. Each sticker shows ONE simple object, centred, flat minimal style matching the '
         'Deschly app icon, soft colours from the palette ink #0E0F0C, gold #F2C230, blue #2F5BEA, red #C8323A, green #157A41. '
         'No text, no letters, no numbers. Square image 2048×2048. Order, row by row, left to right:')


def words():
    return {w['id']: w for w in json.load(open(os.path.join(CONTENT, 'a1.json'), encoding='utf-8'))['words']}


def prompts():
    lookup = words()
    units = {u['id']: u for u in json.load(open(os.path.join(CONTENT, 'units.json'), encoding='utf-8'))['units']}
    lines = ['A1 KELİME IZGARALARI — her ünite için ChatGPT\'den bir resim iste',
             'Her istek: aşağıdaki ÜSLUP paragrafı + o ünitenin 16 maddelik listesi.',
             'Kaydet: words-a1-01.jpg … words-a1-12.jpg (bu klasöre). Sonra Claude\'a "kelime ızgaraları hazır" de.', '',
             'ÜSLUP:', STYLE, '']
    for uid, ids in PICTURE_WORDS.items():
        title = units[uid]['title']['tr'] if uid in units else uid
        lines.append(f'--- words-{uid}.jpg · {title} ---')
        for n, wid in enumerate(ids, 1):
            w = lookup[wid]
            what = DRAW.get(wid) or ('a ' + w['mean']['en'].split(';')[0].split(',')[0].strip())
            lines.append(f'{n}. {what}   [{w["type"]} {w["de"]}]')
        lines.append('')
    os.makedirs(GORSELLER, exist_ok=True)
    out = os.path.join(GORSELLER, 'KELIME_IZGARALARI_A1.txt')
    open(out, 'w', encoding='utf-8', newline='\r\n').write('\n'.join(lines))
    print('->', out)


def cut(unit_id, path):
    from PIL import Image, ImageChops
    ids = PICTURE_WORDS[unit_id]
    img = Image.open(path).convert('RGB')
    w, h = img.size
    background = img.getpixel((3, 3))
    os.makedirs(COVERS, exist_ok=True)
    saved = 0
    for i, wid in enumerate(ids):
        row, col = divmod(i, 4)
        cell = img.crop((col * w // 4, row * h // 4, (col + 1) * w // 4, (row + 1) * h // 4))
        # Trim to what differs from the background, then centre on a square with a small margin.
        diff = ImageChops.difference(cell, Image.new('RGB', cell.size, background)).convert('L').point(lambda v: 255 if v > 24 else 0)
        box = diff.getbbox()
        if not box:
            print(f'  {unit_id} #{i + 1}: empty cell')
            continue
        sticker = cell.crop(box)
        side = int(max(sticker.size) * 1.12)
        square = Image.new('RGB', (side, side), background)
        square.paste(sticker, ((side - sticker.width) // 2, (side - sticker.height) // 2))
        square.resize((SIZE, SIZE), Image.LANCZOS).save(os.path.join(COVERS, f'wp-a1-{wid}.jpg'), quality=85)
        saved += 1
    print(f'{unit_id}: {saved}/16 pictures saved')


def cut_all():
    for uid in PICTURE_WORDS:
        found = [p for ext in ('jpg', 'jpeg', 'png', 'webp') for p in glob.glob(os.path.join(GORSELLER, f'words-{uid}.{ext}'))]
        if found:
            cut(uid, found[0])


def status():
    for uid, ids in PICTURE_WORDS.items():
        have = sum(1 for wid in ids if os.path.exists(os.path.join(COVERS, f'wp-a1-{wid}.jpg')))
        print(f'{uid}: {have}/16')


if __name__ == '__main__':
    command = sys.argv[1] if len(sys.argv) > 1 else 'status'
    if command == 'prompts':
        prompts()
    elif command == 'cut':
        cut(sys.argv[2], sys.argv[3])
    elif command == 'cut-all':
        cut_all()
    else:
        status()

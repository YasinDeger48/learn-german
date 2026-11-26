"""Word pictures for the path units: 16 concrete nouns per unit, drawn by ChatGPT as one 4×4 sticker grid.

    python -I -X utf8 tools/word_pictures.py prompts          ../icerik/gorseller/KELIME_IZGARALARI_A1.txt
    python -I -X utf8 tools/word_pictures.py cut a1-03 PATH   cuts a 4×4 grid image into 16 pictures
    python -I -X utf8 tools/word_pictures.py cut-all          cuts every ../icerik/gorseller/words-a1-NN.(jpg|png)
    python -I -X utf8 tools/word_pictures.py status

Pictures are saved as Resources/Covers/wp-<level>-<word id>.jpg (square, 360 px), so Covers.image() finds them
in the app and tools/publish_content.py can publish them like the covers.
The stickers are found by the empty background between them (rows first, then four per row); each one is
trimmed to what differs from the background and centred on the background colour with a wide margin.
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

# The 12 extra words per A1 unit (tools/units.py fill_a1_extra), 16 per grid, in unit order. Left out on purpose
# (no picture can show them without misleading): the question words of unit 12, heute / morgen / gestern, das Alter.
EXTRA_GRIDS = {
    'a1-ek-01': [17, 18, 29, 30, 32, 86, 90, 91, 1, 2, 3, 4, 59, 60, 62, 71],
    'a1-ek-02': [72, 73, 74, 46, 53, 54, 61, 169, 174, 175, 176, 177, 179, 180, 182, 170],
    'a1-ek-03': [171, 173, 196, 236, 237, 241, 242, 244, 245, 249, 259, 233, 234, 235, 243, 282],
    'a1-ek-04': [285, 290, 292, 300, 301, 303, 304, 296, 307, 308, 309, 110, 111, 114, 115, 116],
    'a1-ek-05': [118, 119, 124, 117, 325, 330, 345, 349, 356, 362, 367, 369, 337, 338, 339, 340],
    'a1-ek-06': [486, 494, 498, 499, 502, 505, 506, 507, 500, 501, 503, 504, 391, 393, 398, 400],
    'a1-ek-07': [403, 405, 406, 409, 392, 407, 408, 424, 447, 448, 449, 465, 466, 471, 472, 478],
    'a1-ek-08': [451, 452, 453, 454, 372, 374, 375, 377, 378, 382, 383, 384, 341, 342, 343, 352],
}

DRAW_EXTRA = {
    17: 'a name badge with a small smiling face and one short blank line', 18: 'a door name plate on a family house',
    29: 'a speech bubble with one short bar', 30: 'a speech bubble with a long row of small bars',
    32: 'a speech bubble with a big check mark', 86: 'an envelope with a row of five small empty boxes',
    90: 'a traveller with a suitcase and a passport', 91: 'a small house with a red heart above it',
    1: 'a hand waving hello', 2: 'two people shaking hands in daylight', 3: 'a rising sun next to a cup of coffee',
    4: 'a moon and stars over a lit window', 59: 'a smiling young woman (a female friend)',
    60: 'two people holding hands', 62: 'one simple standing person', 71: 'a man working at a desk with a laptop',
    72: 'a woman working at a desk with a laptop', 73: 'a man waving over a garden fence',
    74: 'an aunt hugging a small child', 46: 'a mother and a father together', 53: 'a brother and a sister',
    54: 'a grandmother and a grandfather', 61: 'a small group of different people', 169: 'a plate with a warm meal',
    174: 'a lunch plate with the sun high above', 175: 'a dinner plate with a candle',
    176: 'a person holding their stomach next to an empty plate', 177: 'an empty glass and a thirsty face',
    179: 'a bread roll', 180: 'a butter dish with butter', 182: 'sausages', 170: 'a person eating with a fork',
    171: 'a person drinking a glass of water', 173: 'a person eating breakfast at a table', 196: 'a bowl of pasta',
    236: 'a small shop front', 237: 'a little corner store with an open door', 241: 'a street kiosk with newspapers',
    242: 'a price tag', 244: 'a coin with the euro sign', 245: 'small copper coins',
    249: 'a red sale tag with a percent sign', 259: 'a customer with a shopping basket',
    233: 'a hand paying with a card at a till', 234: 'a person pushing a shopping cart',
    235: 'a seller handing a bag over a counter', 243: 'a price tag next to a few coins',
    282: 'a simple room with a bed and a window', 285: 'a toilet', 290: 'stairs going down into a cellar with boxes',
    292: 'a building with one floor highlighted', 300: 'a wardrobe', 301: 'a sofa', 303: 'a fridge',
    304: 'a kitchen stove', 296: 'a chair, a table and a lamp together', 307: 'a person in a shower',
    308: 'washing hands with soap', 309: 'a person cleaning the floor with a mop', 110: 'an abacus',
    111: 'a waiting ticket coming out of a ticket machine', 114: 'a wall clock', 115: 'an hourglass',
    116: 'a stopwatch', 118: 'a clock face with one quarter coloured in', 119: 'a clock next to a calendar',
    124: 'the sun halfway up the morning sky over a house', 117: 'a clock showing half past (long hand pointing down)',
    325: 'a train on a railway track', 330: 'a green suburban train at a platform', 345: 'a ticket',
    349: 'a train arriving at a platform and a person waving', 356: 'a street corner',
    362: 'a town centre seen from above', 367: 'a hospital building with a red cross', 369: 'a police car',
    337: 'a plane flying', 338: 'a person driving a car', 339: 'a train leaving with motion lines',
    340: 'a traveller with a suitcase arriving at a door', 486: 'a simple human body outline', 494: 'an arm',
    498: "a person's back", 499: 'long hair', 502: 'a green heart with a plus sign',
    505: 'a thermometer next to a hot red face', 506: 'a person sneezing into a tissue',
    507: "a doctor's practice door with a medical cross", 500: 'a person in bed with a thermometer',
    501: 'a happy person jogging with an apple', 503: 'a person holding their head in pain',
    504: 'a hurting knee with a plaster', 391: 'a person working at a desk', 393: 'a briefcase',
    398: 'a female teacher at a board', 400: 'a female doctor with a stethoscope',
    403: 'a schoolboy with a backpack', 405: 'a small group class around a table',
    406: 'a teacher pointing at a board for pupils', 409: 'a university building',
    392: 'hands typing on a laptop', 407: 'a person reading with a notebook',
    408: 'a student with books and a graduation cap', 424: 'a person talking on a phone',
    447: 'a paint palette and a guitar', 448: 'a person reading in a garden chair', 449: 'sports balls',
    465: 'a festive table with garlands', 466: 'an invitation card with a balloon', 471: 'two friends laughing',
    472: 'a family with backpacks on a trip', 478: 'a lake with trees', 451: 'children playing with a ball',
    452: 'a person swimming', 453: 'a dancing couple', 454: 'a person singing with music notes',
    372: 'a swimming pool', 374: 'a theatre stage with red curtains', 375: 'a suitcase with a map',
    377: 'a beach chair under an umbrella', 378: 'several suitcases', 382: 'an info desk with an information symbol',
    383: 'an open door with a green arrow pointing in', 384: 'a door with a green exit sign',
    341: 'a person walking from one train to another', 342: 'a person stepping into a bus',
    343: 'a person stepping out of a train', 352: 'a road sign arrow pointing left',
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


def runs(profile, minimum=3):
    """(start, end) of the stretches where the profile has content."""
    out, start = [], None
    for i, v in enumerate(list(profile) + [0]):
        if v >= minimum and start is None:
            start = i
        elif v < minimum and start is not None:
            out.append((start, i))
            start = None
    return out


def four(parts, length):
    """Merges stretches until there are four (closest neighbours first); None when there are fewer."""
    parts = [p for p in parts if p[1] - p[0] > length * 0.01]  # specks
    if len(parts) < 4:
        return None
    while len(parts) > 4:
        gaps = [parts[i + 1][0] - parts[i][1] for i in range(len(parts) - 1)]
        i = gaps.index(min(gaps))
        parts[i:i + 2] = [(parts[i][0], parts[i + 1][1])]
    return parts


def prompts_extra():
    lookup = words()
    lines = ['A1 EK KELİMELER — 8 resim (ünite başına eklenen 12 kelimenin resmi)',
             'Her istek: aşağıdaki ÜSLUP paragrafı + o resmin 16 maddelik listesi.',
             'Kaydet: words-a1-ek-01.jpg … words-a1-ek-08.jpg (bu klasöre). Sonra Claude\'a "ek kelime resimleri hazır" de.',
             'Not: €, % ve bilgi (i) gibi simgeler serbest; yazı ve rakam yine olmasın.', '',
             'ÜSLUP:', STYLE, '']
    for gid, ids in EXTRA_GRIDS.items():
        lines.append(f'--- words-{gid}.jpg ---')
        for n, wid in enumerate(ids, 1):
            w = lookup[wid]
            what = DRAW_EXTRA.get(wid) or ('a ' + w['mean']['en'].split(';')[0].split(',')[0].strip())
            lines.append(f'{n}. {what}   [{w["type"]} {w["de"]}]')
        lines.append('')
    os.makedirs(GORSELLER, exist_ok=True)
    out = os.path.join(GORSELLER, 'KELIME_IZGARALARI_A1_EK.txt')
    open(out, 'w', encoding='utf-8', newline='\r\n').write('\n'.join(lines))
    print('->', out)


def cut(unit_id, path):
    """Finds the 16 stickers by the empty background between them (ChatGPT's grids are not exactly even),
    so no sticker is cut off and no piece of a neighbour comes along; falls back to equal cells."""
    from PIL import Image, ImageChops
    ids = PICTURE_WORDS.get(unit_id) or EXTRA_GRIDS[unit_id]
    img = Image.open(path).convert('RGB')
    w, h = img.size
    background = img.getpixel((3, 3))
    mask = ImageChops.difference(img, Image.new('RGB', img.size, background)).convert('L').point(lambda v: 255 if v > 24 else 0)
    pixels = mask.load()

    def profile(box, axis):
        x0, y0, x1, y1 = box
        if axis == 'y':
            return [sum(1 for x in range(x0, x1, 2) if pixels[x, y]) for y in range(y0, y1)]
        return [sum(1 for y in range(y0, y1, 2) if pixels[x, y]) for x in range(x0, x1)]

    cells = []
    rows = four(runs(profile((0, 0, w, h), 'y')), h)
    if rows:
        for y0, y1 in rows:
            cols = four(runs(profile((0, y0, w, y1), 'x')), w)
            if not cols:
                cells = []
                break
            cells += [(x0, y0, x1, y1) for x0, x1 in cols]
    if len(cells) != 16:
        print(f'  {unit_id}: no clear gaps, cutting equal cells')
        cells = [(c * w // 4, r * h // 4, (c + 1) * w // 4, (r + 1) * h // 4) for r in range(4) for c in range(4)]

    os.makedirs(COVERS, exist_ok=True)
    saved = 0
    for i, wid in enumerate(ids):
        box = mask.crop(cells[i]).getbbox()
        if not box:
            print(f'  {unit_id} #{i + 1}: empty cell')
            continue
        x0, y0 = cells[i][:2]
        sticker = img.crop((x0 + box[0], y0 + box[1], x0 + box[2], y0 + box[3]))
        # Centre on a square with a generous margin, so the picture fits the rounded card.
        side = int(max(sticker.size) * 1.3)
        square = Image.new('RGB', (side, side), background)
        square.paste(sticker, ((side - sticker.width) // 2, (side - sticker.height) // 2))
        square.resize((SIZE, SIZE), Image.LANCZOS).save(os.path.join(COVERS, f'wp-a1-{wid}.jpg'), quality=85)
        saved += 1
    print(f'{unit_id}: {saved}/16 pictures saved')


def cut_all():
    for uid in list(PICTURE_WORDS) + list(EXTRA_GRIDS):
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
    elif command == 'prompts-extra':
        prompts_extra()
    elif command == 'cut':
        cut(sys.argv[2], sys.argv[3])
    elif command == 'cut-all':
        cut_all()
    else:
        status()

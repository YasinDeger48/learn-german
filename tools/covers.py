"""Cover illustrations for the daily texts.

Write the image prompts (one per text, with Lina and the house style):
    python -I -X utf8 tools/covers.py prompts ../icerik/gorseller

Import finished images (a1-001.png / .jpg / .webp …) into Resources/Covers as 960×640 JPEG:
    python -X utf8 tools/covers.py import ../icerik/gorseller
"""
import glob
import json
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
COVERS = os.path.join(HERE, '..', 'Resources', 'Covers')

STYLE = ('Draw Lina, the Deschly mascot (the girl from the app icon: long wavy brown hair, small gold hoop earrings, '
         'cream jumper, friendly smile), in the same flat, modern, minimal illustration style as the app icon. '
         'Clean shapes, soft light, no text, no logos, no letters in the picture. Landscape 3:2, 1200×800. '
         'Palette: warm off-white #F7F7F4, ink #0E0F0C, gold #F2C230, with small touches of blue #2F5BEA, '
         'red #C8323A and green #157A41. Lina plays the main person of the story.')


def texts():
    out = []
    for path in sorted(glob.glob(os.path.join(HERE, '..', 'Resources', 'content', 'daily_*.json'))):
        out += json.load(open(path, encoding='utf-8'))['texts']
    return out


def prompts(folder):
    os.makedirs(folder, exist_ok=True)
    have = {os.path.splitext(os.path.basename(p))[0] for p in glob.glob(os.path.join(COVERS, '*.jpg'))}
    lines = [STYLE, '', 'Save each picture with the id as its file name, e.g. a1-001.png.', '']
    todo = 0
    for t in texts():
        if t['id'] in have:
            continue
        lines.append(prompt_for(t).split('\n\n', 1)[1])
        todo += 1
    path = os.path.join(folder, 'PROMPTS.txt')
    open(path, 'w', encoding='utf-8', newline='\n').write('\n'.join(lines) + '\n')
    print(f'{todo} prompts → {path}')


def prompt_for(t):
    """The image prompt for one daily text (same text as in PROMPTS.txt)."""
    en = t['trans'][0].get('en', '')
    sentences = [x.strip() for x in en.replace('! ', '. ').replace('? ', '. ').split('. ') if x.strip()]
    scene = '. '.join(sentences[:3]).rstrip('.') + '.'
    return f"{STYLE}\n\n{t['id']} | {t['title']} | Scene: {scene}"


def save_cover(img, name, crop_top=0.0):
    """Checks one picture and saves it as Resources/Covers/<name>.jpg (960×640).
    Returns None when saved, or the reason it was rejected. crop_top cuts a share of the height first
    (for pictures with a caption strip at the top)."""
    from PIL import Image
    img = img.convert('RGB')
    if crop_top:
        img = img.crop((0, int(img.height * crop_top), img.width, img.height))
    # Reject collages / strips: many empty rows mean the picture is not one full scene.
    small = img.convert('L').resize((120, 80))
    rows = [[small.getpixel((x, y)) for x in range(120)] for y in range(80)]
    blank = sum(1 for r in rows if max(r) - min(r) < 12)
    if blank > 16:
        return f'{blank}/80 empty rows (collage or strip, please make it again)'
    w, h = img.size
    target = 3 / 2
    if w / h > target:  # crop to 3:2 around the centre
        nw = int(h * target)
        img = img.crop(((w - nw) // 2, 0, (w - nw) // 2 + nw, h))
    else:
        nh = int(w / target)
        img = img.crop((0, (h - nh) // 2, w, (h - nh) // 2 + nh))
    os.makedirs(COVERS, exist_ok=True)
    img.resize((960, 640), Image.LANCZOS).save(os.path.join(COVERS, f'{name}.jpg'), 'JPEG', quality=80, optimize=True)
    return None


def import_(folder):
    from PIL import Image
    ids = {t['id'] for t in texts()}
    done = 0
    for path in sorted(glob.glob(os.path.join(folder, '*'))):
        name, ext = os.path.splitext(os.path.basename(path))
        if ext.lower() not in ('.png', '.jpg', '.jpeg', '.webp') or name not in ids:
            continue
        reason = save_cover(Image.open(path), name)
        if reason:
            print(f'skipped {name}: {reason}')
            continue
        done += 1
    total = len(glob.glob(os.path.join(COVERS, '*.jpg')))
    print(f'imported {done}; covers in app: {total} of {len(ids)}')


if __name__ == '__main__':
    action, folder = sys.argv[1], sys.argv[2]
    prompts(folder) if action == 'prompts' else import_(folder)

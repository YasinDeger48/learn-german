"""Prepares the word-run game pictures (Codex: icerik/gorseller/LINA_KOSU.txt) for the app.

    python -I tools/images/runner_assets.py

- Originals are kept in ../icerik/gorseller/_orijinal/kosu/ (first run only).
- Lina poses, the box and the flag: 512×512 PNG, same square for every pose so the frames line up.
- kosu-uzak (far layer, opaque): JPEG.
- kosu-orta / kosu-yakin: the flat sky (#00FF00 or plain) is cut away (cutout.py), PNG with alpha.
"""
import os
import shutil
import subprocess
import sys

from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.dirname(os.path.dirname(HERE))
IMAGES = os.path.join(REPO, 'Resources', 'Images')
KEEP = os.path.join(os.path.dirname(REPO), 'icerik', 'gorseller', '_orijinal', 'kosu')
SQUARES = ['lina-run-1', 'lina-run-2', 'lina-run-3', 'lina-run-4', 'lina-jump', 'lina-stumble', 'lina-finish',
           'kosu-kutu', 'kosu-bayrak',
           # Song dance frames (icerik/gorseller/LINA_DANS.txt), same square so the frames line up.
           'lina-dance-1', 'lina-dance-2', 'lina-dance-3', 'lina-dance-4', 'lina-dance-5', 'lina-dance-6']


def backup(name):
    os.makedirs(KEEP, exist_ok=True)
    src = os.path.join(IMAGES, name)
    dst = os.path.join(KEEP, name)
    if os.path.exists(src) and not os.path.exists(dst):
        shutil.copy2(src, dst)
    return dst


def main():
    for name in SQUARES:
        original = backup(name + '.png')
        img = Image.open(original).convert('RGBA')
        if img.getpixel((2, 2))[3] == 255:  # not transparent: cut the flat background away first
            subprocess.run([sys.executable, '-I', os.path.join(HERE, 'cutout.py'), original, original + '.cut.png', '--keep-size'], check=True)
            img = Image.open(original + '.cut.png').convert('RGBA')
            os.remove(original + '.cut.png')
        img = img.resize((512, 512), Image.LANCZOS)
        img.save(os.path.join(IMAGES, name + '.png'), optimize=True)
    far = backup('kosu-uzak.png')
    Image.open(far).convert('RGB').resize((1600, 800), Image.LANCZOS).save(os.path.join(IMAGES, 'kosu-uzak.jpg'), quality=84)
    if os.path.exists(os.path.join(IMAGES, 'kosu-uzak.png')):
        os.remove(os.path.join(IMAGES, 'kosu-uzak.png'))
    for name in ('kosu-orta', 'kosu-yakin'):
        original = backup(name + '.png')
        out = os.path.join(IMAGES, name + '.png')
        subprocess.run([sys.executable, '-I', os.path.join(HERE, 'cutout.py'), original, out, '--keep-size'], check=True)
        Image.open(out).resize((1600, 400), Image.LANCZOS).save(out, optimize=True)
    total = sum(os.path.getsize(os.path.join(IMAGES, f)) for f in os.listdir(IMAGES)
                if f.startswith(('lina-run', 'lina-jump', 'lina-stumble', 'lina-finish', 'kosu-')))
    print(f'runner pictures ready: {total / 1e6:.1f} MB')


if __name__ == '__main__':
    main()

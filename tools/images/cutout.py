"""Removes the flat light background around Lina: flood fill from the edges over near-background pixels,
then a soft one-pixel edge. Usage: cutout.py <in.png> <out.png>"""
import sys
from collections import deque

from PIL import Image, ImageFilter

src, dst = sys.argv[1], sys.argv[2]
img = Image.open(src).convert('RGBA')
w, h = img.size
px = img.load()
bg = px[2, 2][:3]


def near(c, tol=26):
    return all(abs(c[i] - bg[i]) <= tol for i in range(3))


mask = Image.new('L', (w, h), 255)
m = mask.load()
seen = bytearray(w * h)
queue = deque()
for x in range(w):
    queue.append((x, 0)); queue.append((x, h - 1))
for y in range(h):
    queue.append((0, y)); queue.append((w - 1, y))
while queue:
    x, y = queue.popleft()
    if x < 0 or y < 0 or x >= w or y >= h or seen[y * w + x]:
        continue
    seen[y * w + x] = 1
    if not near(px[x, y]):
        continue
    m[x, y] = 0
    queue.extend(((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)))
mask = mask.filter(ImageFilter.GaussianBlur(0.8))
img.putalpha(mask)
img = img.crop(img.getbbox())
img.save(dst)
print('saved', dst, img.size)

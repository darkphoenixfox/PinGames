"""Turns an AI-generated sprite on a plain (white) background into a trimmed RGBA PNG.

Usage: python scripts/tools/sprite_cutout.py <in.png> <out.png> [--max-width N] [--flip]
- Background is removed by flood-filling from the image border (interior whites such as
  headlights are kept), with a soft edge to hide the anti-aliased fringe.
- The result is cropped to the sprite plus a 2 px margin, optionally downscaled
  (nearest-neighbour keeps the pixel-art look) and/or mirrored horizontally.
"""
import argparse
from collections import deque
from PIL import Image

TOL = 38  # max per-channel distance from the background colour


def cutout(img: Image.Image) -> Image.Image:
    img = img.convert("RGBA")
    w, h = img.size
    px = img.load()
    bg = px[0, 0][:3]
    def is_bg(c):
        return all(abs(c[i] - bg[i]) <= TOL for i in range(3))
    seen = bytearray(w * h)
    q = deque()
    for x in range(w):
        q.append((x, 0)); q.append((x, h - 1))
    for y in range(h):
        q.append((0, y)); q.append((w - 1, y))
    while q:
        x, y = q.popleft()
        i = y * w + x
        if seen[i]:
            continue
        seen[i] = 1
        c = px[x, y]
        if not is_bg(c):
            continue
        px[x, y] = (c[0], c[1], c[2], 0)
        if x > 0: q.append((x - 1, y))
        if x < w - 1: q.append((x + 1, y))
        if y > 0: q.append((x, y - 1))
        if y < h - 1: q.append((x, y + 1))
    return img


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("src"); ap.add_argument("dst")
    ap.add_argument("--max-width", type=int, default=0)
    ap.add_argument("--flip", action="store_true")
    a = ap.parse_args()
    img = cutout(Image.open(a.src))
    bbox = img.getbbox()
    if bbox:
        l, t, r, b = bbox
        img = img.crop((max(0, l - 2), max(0, t - 2), min(img.width, r + 2), min(img.height, b + 2)))
    if a.flip:
        img = img.transpose(Image.FLIP_LEFT_RIGHT)
    if a.max_width and img.width > a.max_width:
        img = img.resize((a.max_width, round(img.height * a.max_width / img.width)), Image.LANCZOS)
    img.save(a.dst, optimize=True)
    print(f"{a.dst}  {img.size[0]}x{img.size[1]}")


if __name__ == "__main__":
    main()

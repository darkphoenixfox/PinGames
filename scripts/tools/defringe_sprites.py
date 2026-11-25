"""Removes the pale rim left on a cut-out sprite by its white background (D-392).

Pixels within BAND px of the cut-out's edge that are pale and colourless (the
background showing through) take the colour of the nearest proper pixel of
the art; the shape itself does not change. Pixels that are mostly clear are
handled the same way, so smooth filtering can't pull the white back in.
Usage: python scripts/tools/defringe_sprites.py pine_1 pine_2
"""
import os
import sys

import numpy as np
from PIL import Image, ImageFilter

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
DIR = os.path.join(ROOT, "assets", "sprites", "racer", "hd")
BAND = 5          # px in from the edge that are checked
PALE = 120        # brightness (0-255) above which a colourless pixel is rim
GREY = 70         # max - min channel below which a pixel is colourless


def defringe(name):
    path = os.path.join(DIR, name + ".png")
    a = np.array(Image.open(path).convert("RGBA")).astype(np.int32)
    alpha = a[..., 3]
    solid = alpha >= 128
    mask = Image.fromarray((solid * 255).astype(np.uint8))
    core = np.array(mask.filter(ImageFilter.MinFilter(2 * BAND + 1))) > 0
    rgb = a[..., :3]
    lum = rgb.mean(axis=2)
    sat = rgb.max(axis=2) - rgb.min(axis=2)
    pale = (lum > PALE) & (sat < GREY)
    bad = (alpha > 0) & ((~core & pale) | ~solid)
    good = (alpha > 0) & ~bad
    out = rgb.astype(np.float64)
    known = good.copy()
    for _ in range(64):   # spread the art's colours outwards into the rim
        todo = bad & ~known
        if not todo.any():
            break
        acc = np.zeros_like(out)
        cnt = np.zeros(alpha.shape)
        for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1), (1, 1), (1, -1), (-1, 1), (-1, -1)):
            k = np.roll(np.roll(known, dy, 0), dx, 1)
            acc += np.roll(np.roll(out, dy, 0), dx, 1) * k[..., None]
            cnt += k
        hit = todo & (cnt > 0)
        out[hit] = acc[hit] / cnt[hit][:, None]
        known |= hit
    a[..., :3] = np.clip(out, 0, 255).astype(np.int32)
    Image.fromarray(a.astype(np.uint8), "RGBA").save(path)
    print(name, "rim pixels recoloured:", int((bad & solid).sum()))


if __name__ == "__main__":
    for n in sys.argv[1:]:
        defringe(n)

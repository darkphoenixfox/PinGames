"""Turbo Run's broadleaf forest tree (D-396) from the director's painting.

Reads  assets/source/racer/tree_forest.png (already cut out, with a soft pale
       glow round it).
Writes assets/sprites/racer/hd/tree_forest.png: trimmed, 1000 px tall, the
       glow removed (only pixels at least 70 % solid are kept, as fully solid),
       then the pale rim cleaned like the other trees (defringe_sprites.py).
Usage: python scripts/tools/prepare_forest_tree.py
"""
import os

import numpy as np
from PIL import Image

import defringe_sprites

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
SRC = os.path.join(ROOT, "assets", "source", "racer", "tree_forest.png")
OUT = os.path.join(ROOT, "assets", "sprites", "racer", "hd", "tree_forest.png")
HEIGHT = 1000


def main():
    a = np.array(Image.open(SRC).convert("RGBA")).astype(np.float64)
    ys, xs = np.where(a[..., 3] >= 128)
    a = a[ys.min():ys.max() + 1, xs.min():xs.max() + 1]
    a[..., :3] *= a[..., 3:4] / 255.0   # premultiplied: clear pixels add no colour
    h = HEIGHT
    w = round(a.shape[1] * h / a.shape[0])
    small = np.array(Image.fromarray(a.astype(np.uint8), "RGBA").resize((w, h), Image.LANCZOS)).astype(np.float64)
    alpha = small[..., 3]
    rgb = np.where(alpha[..., None] > 0, small[..., :3] * 255.0 / np.maximum(alpha[..., None], 1.0), 0.0)
    solid = alpha >= 0.7 * 255
    out = np.dstack([np.clip(rgb, 0, 255), np.where(solid, 255.0, 0.0)])
    out[~solid] = 0
    Image.fromarray(out.astype(np.uint8), "RGBA").save(OUT)
    defringe_sprites.defringe("tree_forest")
    print("wrote", OUT, (w, h))


if __name__ == "__main__":
    main()

"""Turbo Run desert (D-437): the director's two mesa paintings as sprites.
Copies the originals from the asset folder to assets/source/racer/ (if given),
trims them to their visible outline (D-444) and scales them (Lanczos, premultiplied alpha) to
at most 1024 px wide, like the first mesa's HD cut-out, into
assets/sprites/racer/hd/mesa_2.png and mesa_3.png.
Usage: python scripts/tools/prepare_mesas.py [asset_folder]
"""
import os
import shutil
import sys

from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
SRC = os.path.join(ROOT, "assets", "source", "racer")
DST = os.path.join(ROOT, "assets", "sprites", "racer", "hd")
MAX_W = 1024

for src_name, out_name in (("mesa2.png", "mesa_2.png"), ("mesa3.png", "mesa_3.png")):
    if len(sys.argv) > 1:
        shutil.copyfile(os.path.join(sys.argv[1], src_name), os.path.join(SRC, src_name))
    im = Image.open(os.path.join(SRC, src_name)).convert("RGBA")
    # D-444: trimmed to the visible outline (alpha above half: the game cuts
    # there), not to the faint halo round it, or the rock's base floated.
    solid = im.getchannel("A").point(lambda v: 255 if v > 128 else 0)
    l, t, r, b = solid.getbbox()
    im = im.crop((max(0, l - 2), max(0, t - 2), min(im.width, r + 2), min(im.height, b + 2)))
    k = min(1.0, MAX_W / im.width)
    size = (round(im.width * k), round(im.height * k))
    im = im.convert("RGBa").resize(size, Image.LANCZOS).convert("RGBA")
    im.save(os.path.join(DST, out_name))
    print(out_name, size)

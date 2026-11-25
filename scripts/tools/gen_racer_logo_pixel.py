"""Turbo Run's logo as pixel art for the 8-BIT and 16-BIT modes (D-390).

Reads  assets/textures/racer/logo.png (the painted logo).
Writes assets/textures/racer/logo_16.png   400 px wide, 24 colours
       assets/textures/racer/logo_8.png    225 px wide, 8 colours

The logo is shown 900 UI pixels wide; those widths are that many of the UI's
own pixels in each mode (1080 drawn 480 / 270 high), so one image pixel is one
screen pixel of the mode. Hard edge, no half-transparent pixels.

These are first drafts for the director to finish by hand: once edited, do not
run this again (it refuses without --force).
Usage: python scripts/tools/gen_racer_logo_pixel.py --force
"""
import os
import sys

import numpy as np
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
DIR = os.path.join(ROOT, "assets", "textures", "racer")


def pixel(width, colours):
    im = Image.open(os.path.join(DIR, "logo.png")).convert("RGBA")
    h = round(im.height * width / im.width)
    a = np.array(im).astype(np.float64)
    a[..., :3] *= a[..., 3:4] / 255.0          # premultiplied, so edges don't darken
    small = np.array(Image.fromarray(a.astype(np.uint8), "RGBA").resize((width, h), Image.BOX)).astype(np.float64)
    alpha = small[..., 3]
    solid = alpha >= 128
    rgb = np.where(alpha[..., None] > 0, small[..., :3] * 255.0 / np.maximum(alpha[..., None], 1.0), 0.0)
    rgb = np.clip(rgb, 0, 255).astype(np.uint8)
    q = Image.fromarray(rgb, "RGB").quantize(colours, method=Image.MEDIANCUT, dither=Image.NONE).convert("RGB")
    out = np.dstack([np.array(q), np.where(solid, 255, 0).astype(np.uint8)])
    out[~solid] = 0
    return Image.fromarray(out, "RGBA")


def main():
    if "--force" not in sys.argv:
        raise SystemExit("The pixel logos may have been edited by hand (D-390); --force overwrites them.")
    pixel(400, 24).save(os.path.join(DIR, "logo_16.png"))
    pixel(225, 8).save(os.path.join(DIR, "logo_8.png"))
    print("wrote logo_16.png, logo_8.png")


if __name__ == "__main__":
    main()

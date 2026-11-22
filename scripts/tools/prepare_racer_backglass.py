"""Turbo Run backglass (D-109): lit/unlit pair -> textures for the light shader.

Input (director's art, same framing), from the asset inbox:
  turborun-backglass_off.png, turborun-backglass_on.png
Output in assets/textures/racer/ (originals kept in assets/source/racer/):
  backglass_off.png, backglass_on.png   1920x1080
  backglass_mask.png                    RGB groups, soft-edged: R = headlights
                                        (every lit area outside the logo)
  backglass_mask_logo.png               greyscale: the logo (top-right box)
The lit areas are found by differencing the two images (masks never go in alpha).
Usage: python scripts/tools/prepare_racer_backglass.py <inbox_dir>
"""
import os
import shutil
import sys

from PIL import Image, ImageChops, ImageFilter

sys.path.insert(0, os.path.dirname(__file__))
from prepare_backglass_lights import components  # noqa: E402

ROOT = os.path.normpath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT = (1920, 1080)
WORK = (640, 360)
THRESHOLD = 30
LOGO_BOX = (0.52, 0.0, 1.0, 0.42)   # x0, y0, x1, y1 as fractions


def main():
    inbox = sys.argv[1]
    src = os.path.join(ROOT, "assets", "source", "racer")
    out = os.path.join(ROOT, "assets", "textures", "racer")
    os.makedirs(src, exist_ok=True)
    os.makedirs(out, exist_ok=True)
    imgs = {}
    for state in ("off", "on"):
        name = f"turborun-backglass_{state}.png"
        kept = os.path.join(src, name)
        shutil.copyfile(os.path.join(inbox, name), kept)
        img = Image.open(kept).convert("RGB").resize(OUT, Image.LANCZOS)
        img.save(os.path.join(out, f"backglass_{state}.png"), optimize=True)
        imgs[state] = img
    diff = ImageChops.difference(imgs["off"].resize(WORK), imgs["on"].resize(WORK)).convert("L")
    lit = diff.point(lambda v: 255 if v > THRESHOLD else 0).filter(ImageFilter.MaxFilter(3))
    lights = Image.new("L", WORK, 0)
    logo = Image.new("L", WORK, 0)
    lp, gp = lights.load(), logo.load()
    n_lights = n_logo = 0
    w, h = WORK
    for pts in components(lit):
        if len(pts) < 6:
            continue
        cx = sum(p[0] for p in pts) / len(pts) / w
        cy = sum(p[1] for p in pts) / len(pts) / h
        in_logo = LOGO_BOX[0] < cx < LOGO_BOX[2] and LOGO_BOX[1] <= cy < LOGO_BOX[3]
        target = gp if in_logo else lp
        if in_logo:
            n_logo += 1
        else:
            n_lights += 1
        for x, y in pts:
            target[x, y] = 255

    def soft(m):
        return m.resize(OUT, Image.BILINEAR).filter(ImageFilter.MaxFilter(5)).filter(ImageFilter.GaussianBlur(6))

    zero = Image.new("L", OUT, 0)
    Image.merge("RGB", (soft(lights), zero, zero)).save(os.path.join(out, "backglass_mask.png"), optimize=True)
    soft(logo).save(os.path.join(out, "backglass_mask_logo.png"), optimize=True)
    print(f"regions: lights={n_lights} logo={n_logo}")


if __name__ == "__main__":
    main()

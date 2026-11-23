"""Turbo Run loading screen (D-241): the director's yellow car picture, turned into
a small DMD dot sprite. Masks out the white background and the grey ground
shadow, crops to the car, and shrinks it to WIDTH dots with an area filter so
each dot is the average colour of its patch; dots that are mostly background
stay off. Writes assets/textures/racer/loading_car_dmd.png (transparent).
Usage: python scripts/tools/gen_loading_car.py [src out width [--flip]]
  (no arguments: the loading screen's car; D-243: also the small DMD sprites of
  the player cars, e.g. 16 dots wide, --flip for a picture facing left)
"""
import sys
import os
import numpy as np
from PIL import Image

ROOT = os.path.normpath(os.path.join(os.path.dirname(__file__), "..", ".."))
SRC = os.path.join(ROOT, "assets", "source", "racer", "loading_car.png")
OUT = os.path.join(ROOT, "assets", "textures", "racer", "loading_car_dmd.png")
WIDTH = 46
FLIP = "--flip" in sys.argv
_args = [a for a in sys.argv[1:] if not a.startswith("--")]
if len(_args) >= 3:
    SRC = os.path.join(ROOT, _args[0])
    OUT = os.path.join(ROOT, _args[1])
    WIDTH = int(_args[2])

_src = Image.open(SRC)
im = np.asarray(_src.convert("RGB")).astype(float) / 255.0
mx = im.max(axis=2)
mn = im.min(axis=2)
sat = (mx - mn) / np.maximum(mx, 1e-6)
if _src.mode == "RGBA" and np.asarray(_src)[..., 3].min() < 128:
    # D-245: a render with a transparent background (white car panels survive).
    mask = np.asarray(_src)[..., 3] > 128
else:
    # Background: near white. Shadow: light, unsaturated grey under the car.
    bg = (mn > 0.86) | ((sat < 0.12) & (mx > 0.55) & (mx < 0.9))
    mask = ~bg
ys, xs = np.nonzero(mask)
y0, y1, x0, x1 = ys.min(), ys.max() + 1, xs.min(), xs.max() + 1
# The ground shadow under the car: unsaturated mid greys in the bottom strip.
rows = np.arange(im.shape[0])[:, None]
strip = rows > y1 - (y1 - y0) * 0.14
mask &= ~(strip & (sat < 0.18) & (mx > 0.2))
ys, xs = np.nonzero(mask)
y0, y1, x0, x1 = ys.min(), ys.max() + 1, xs.min(), xs.max() + 1
crop = im[y0:y1, x0:x1]
cm = mask[y0:y1, x0:x1].astype(float)
h = max(1, round(WIDTH * (y1 - y0) / (x1 - x0)))
# Area-average colour over the car only, and coverage per dot.
rgb = Image.fromarray((crop * cm[..., None] * 255).astype(np.uint8)).resize((WIDTH, h), Image.BOX)
cov = Image.fromarray((cm * 255).astype(np.uint8)).resize((WIDTH, h), Image.BOX)
rgb = np.asarray(rgb).astype(float) / 255.0
cov = np.asarray(cov).astype(float) / 255.0
col = rgb / np.maximum(cov[..., None], 1e-6)
out = np.zeros((h, WIDTH, 4))
on = cov > 0.45
out[..., :3] = np.clip(col * 1.15, 0, 1)   # LEDs: a little brighter
if "--contrast" in sys.argv:
    # D-245: two-tone liveries (the police car) snap towards black and white.
    c3 = out[..., :3]
    lum = c3 @ np.array([0.3, 0.59, 0.11])
    cs = (c3.max(axis=2) - c3.min(axis=2)) / np.maximum(c3.max(axis=2), 1e-6)
    grey = cs < 0.25
    c3[grey & (lum > 0.74)] = [0.95, 0.95, 0.97]
    c3[grey & (lum <= 0.74)] = [0.32, 0.32, 0.37]   # dark, but visible on the black DMD
    out[..., :3] = c3
out[..., 3] = on.astype(float)
img = Image.fromarray((out * 255).astype(np.uint8), "RGBA")
if FLIP:
    img = img.transpose(Image.FLIP_LEFT_RIGHT)   # nose to the right, like the others
img.save(OUT)
print(OUT, WIDTH, "x", h)

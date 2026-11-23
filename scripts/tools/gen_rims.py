"""Turbo Run rims (D-250): cuts the rim (inside the tyre) out of the director's
side pictures as square textures with a round alpha mask, for the turning
wheel faces drawn by car.gdshader. The hub centre and rim radius were read off
the pictures (in their 1024x576 pixels).
Usage: python scripts/tools/gen_rims.py
"""
import os
import numpy as np
from PIL import Image

ROOT = os.path.normpath(os.path.join(os.path.dirname(__file__), "..", ".."))
RIMS = {
    # name: (source picture, hub x, hub y, rim radius px)
    "rim_9spoke": ("assets/source/racer/loading_car.png", 260, 370, 48),   # the yellow supercar
    "rim_5spoke": ("assets/source/racer/dmd_red_car.png", 265, 390, 52),   # the red sports car
    "rim_police": ("assets/source/racer/rim_police_src.png", 512, 512, 285),   # director's wheel picture
}
SIZE = 128

for name, (src, cx, cy, r) in RIMS.items():
    im = Image.open(os.path.join(ROOT, src)).convert("RGB")
    crop = im.crop((cx - r, cy - r, cx + r, cy + r)).resize((SIZE, SIZE), Image.LANCZOS)
    a = np.asarray(crop).astype(np.uint8)
    yy, xx = np.mgrid[0:SIZE, 0:SIZE]
    d = np.hypot(xx - (SIZE - 1) / 2, yy - (SIZE - 1) / 2) / (SIZE / 2)
    alpha = np.clip((1.0 - d) * 24.0, 0, 1)   # a soft 1-2 px edge
    out = np.dstack([a, (alpha * 255).astype(np.uint8)])
    path = os.path.join(ROOT, "assets", "textures", "racer", name + ".png")
    Image.fromarray(out, "RGBA").save(path)
    print(path)

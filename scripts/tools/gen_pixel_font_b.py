"""Turbo Run's second 8-BIT title font (D-539, D-540): the glyph boxes for the
director's own pixel images assets/fonts/title_sunset_8_b.png and
title_cops_8_b.png (the police colours, D-541) (336x67; rows
A-N, O-Z and "-", then 0-9 ! ? & . , ;).

The images are the director's and are not changed: this only writes each
one's .json beside it (styled-font format, D-062, "pixel": true).
Each glyph is a run of columns in its row; every row sits on one baseline
(the bottom of its plain letters or digits).

Usage: python scripts/tools/gen_pixel_font_b.py
"""
import json
import os

import numpy as np
from PIL import Image

ROOT = os.path.normpath(os.path.join(os.path.dirname(__file__), "..", ".."))
## The glyphs in each image, row by row. The police image (D-541) is upright,
## has no "-" and ends in a ":".
FONTS = {
    "sunset_8_b": ["ABCDEFGHIJKLMN", "OPQRSTUVWXYZ-", "0123456789!?&.,;"],
    "cops_8_b": ["ABCDEFGHIJKLMN", "OPQRSTUVWXYZ", "0123456789!?&.,;:"],
}
PLAIN = ["A", "O", "0"]   # the glyph whose bottom is each row's baseline
GAP = 0                   # px between letters (the shadow already spaces them)
SPACE = 8
DESCENT = 3


def runs(v):
    out, s = [], None
    for i in range(len(v) + 1):
        on = i < len(v) and v[i]
        if on and s is None:
            s = i
        if not on and s is not None:
            out.append((s, i))
            s = None
    return out


def main():
    for name in FONTS:
        make(os.path.join(ROOT, "assets", "fonts", "title_" + name), FONTS[name])


def make(OUT, ROWS):
    im = Image.open(OUT + ".png").convert("RGBA")
    print(os.path.basename(OUT), im.size)
    on = np.array(im)[:, :, 3] > 128
    gh = on.shape[0]
    bands = runs(on.any(axis=1))
    assert len(bands) == len(ROWS), bands
    found = []
    tall = 0
    for (y0, y1), row, plain in zip(bands, ROWS, PLAIN):
        cols = runs(on[y0:y1].any(axis=0))
        assert len(cols) == len(row), (row, len(cols))
        ink = {}
        for (x0, x1), ch in zip(cols, row):
            ys = np.where(on[y0:y1, x0:x1].any(axis=1))[0] + y0
            ink[ch] = (x0, x1, int(ys.min()), int(ys.max()))
        base = ink[plain][3]
        tall = max(tall, base - min(v[2] for v in ink.values()) + 1)
        found.append((ink, base))
        print(" ".join("%s:%d-%d" % (c, v[2] - base, v[3] - base) for c, v in ink.items()))
    ascent = tall + 1   # the baseline row is the first under the plain glyphs
    glyphs = []
    for ink, base in found:
        for ch, (x0, x1, top, bottom) in ink.items():
            y = base - tall + 1 - 1
            g = {"x": x0, "w": x1 - x0, "adv": x1 - x0 + GAP}
            dy = 0
            if y < 0:
                dy = -y
                y = 0
            g["y"] = y
            g["h"] = min(ascent + DESCENT - dy, gh - y)
            if dy:
                g["dy"] = dy
            assert y + g["h"] > bottom, ch
            for code in sorted({ord(ch), ord(ch.lower())}):
                glyphs.append(dict(g, code=code))
    meta = {"size": ascent + DESCENT, "ascent": ascent, "descent": DESCENT, "space": SPACE, "pixel": True,
            "fallback": "sunset", "glyphs": glyphs}
    with open(OUT + ".json", "w", newline="") as f:
        f.write(json.dumps(meta))
    print("size", meta["size"], "ascent", ascent, "bands", bands)


if __name__ == "__main__":
    main()

"""Tilt Breaker's metallic blue title font (D-354), cut from the director's
sheet (assets/source/breakout/metallic_blue_font.png: A-M, N-Z, then 0-9 ! ? &).

Each glyph is cut at its transparent gaps, all glyphs of a row share the row's
top and bottom (so they sit on one baseline), and everything is scaled so a
row is GLYPH_H atlas pixels tall. Lower case maps to the capitals. A few marks
the sheet lacks are made from its own pieces: . , : from the "!" dot, - from
the "!" bar turned on its side. Anything else falls back to the old font.

Writes assets/fonts/title_metal.png + .json in the styled-font format (D-062),
with "smooth": true (scaled freely, not by whole multiples) and
"display_size" (the size that matches the old pixel fonts at scale 1).
Usage: python scripts/tools/gen_metal_font.py
"""
import json
import os

from PIL import Image

ROOT = os.path.normpath(os.path.join(os.path.dirname(__file__), "..", ".."))
SRC = os.path.join(ROOT, "assets", "source", "breakout", "metallic_blue_font.png")
OUT = os.path.join(ROOT, "assets", "fonts")
ROWS = ["ABCDEFGHIJKLM", "NOPQRSTUVWXYZ", "0123456789!?&"]
GLYPH_H = 132        # atlas px per row (capitals + their outline)
CELL = 150           # font size in atlas px (ascent + descent)
ASCENT = 132
GAP = 6              # extra advance between letters
SPACE = 46
ALPHA = 40


def bands(mask_rows, n_min=20):
    """Runs of True in a list -> [(start, end_exclusive)]."""
    out, start = [], None
    for i, v in enumerate(mask_rows + [False]):
        if v and start is None:
            start = i
        elif not v and start is not None:
            if i - start >= n_min:
                out.append((start, i))
            start = None
    return out


def main():
    im = Image.open(SRC).convert("RGBA")
    a = im.getchannel("A").point(lambda v: 255 if v > ALPHA else 0)
    w, h = im.size
    px = a.load()
    row_has = [any(px[x, y] for x in range(0, w, 2)) for y in range(h)]
    row_bands = bands(row_has, 40)
    assert len(row_bands) == 3, row_bands
    glyphs = {}
    for (y0, y1), chars in zip(row_bands, ROWS):
        col_has = [any(px[x, y] for y in range(y0, y1, 2)) for x in range(w)]
        segs = bands(col_has, 4)
        # merge pieces closer than 6 px (none expected, but safe)
        merged = []
        for s in segs:
            if merged and s[0] - merged[-1][1] < 6:
                merged[-1] = (merged[-1][0], s[1])
            else:
                merged.append(s)
        assert len(merged) == len(chars), (chars, len(merged))
        for (x0, x1), ch in zip(merged, chars):
            glyphs[ch] = im.crop((x0, y0, x1, y1))
    k = GLYPH_H / glyphs["A"].height
    scaled = {c: g.resize((max(1, round(g.width * k)), GLYPH_H), Image.LANCZOS) for c, g in glyphs.items()}
    # Extra marks from the "!": its bar and its dot (split at the empty rows).
    ex = scaled["!"]
    ea = ex.getchannel("A")
    rows = [any(ea.getpixel((x, y)) > ALPHA for x in range(ex.width)) for y in range(ex.height)]
    parts = bands(rows, 3)
    bar = ex.crop((0, parts[0][0], ex.width, parts[0][1]))
    dot = ex.crop((0, parts[-1][0], ex.width, parts[-1][1]))
    dot = dot.crop(dot.getchannel("A").point(lambda v: 255 if v > ALPHA else 0).getbbox())
    def on_cell(img, y_bottom, width=None):
        c = Image.new("RGBA", (width or img.width, GLYPH_H), (0, 0, 0, 0))
        c.alpha_composite(img, ((c.width - img.width) // 2, y_bottom - img.height))
        return c
    scaled["."] = on_cell(dot, GLYPH_H - 4)
    # Comma: the dot with a slanted tail under it (the dot stretched down and leaned).
    tail = dot.resize((max(4, dot.width * 2 // 3), dot.height * 2), Image.LANCZOS).rotate(-18, expand=True, resample=Image.BICUBIC)
    cm = Image.new("RGBA", (max(dot.width, tail.width) + 4, GLYPH_H + 16), (0, 0, 0, 0))
    cm.alpha_composite(tail, (0, GLYPH_H - 4 - dot.height // 2))
    cm.alpha_composite(dot, (cm.width - dot.width, GLYPH_H - 4 - dot.height))
    scaled[","] = cm.crop((0, 0, cm.width, GLYPH_H + 16))
    colon = Image.new("RGBA", (dot.width, GLYPH_H), (0, 0, 0, 0))
    colon.alpha_composite(dot, (0, GLYPH_H - 4 - dot.height))
    colon.alpha_composite(dot, (0, GLYPH_H // 2 - dot.height // 2 - 6))
    scaled[":"] = colon
    hb = bar.crop(bar.getchannel("A").point(lambda v: 255 if v > ALPHA else 0).getbbox()).rotate(90, expand=True)
    hb = hb.resize((round(GLYPH_H * 0.42), max(8, round(hb.height * 0.8))), Image.LANCZOS)
    hy = Image.new("RGBA", (hb.width, GLYPH_H), (0, 0, 0, 0))
    hy.alpha_composite(hb, (0, GLYPH_H // 2 - hb.height // 2 + 6))
    scaled["-"] = hy
    # Atlas: one row per 16 glyphs.
    order = list(scaled)
    per = 16
    cw = max(g.width for g in scaled.values()) + 2
    atlas = Image.new("RGBA", (cw * per, (CELL + 2) * ((len(order) + per - 1) // per)), (0, 0, 0, 0))
    # Display size: letters about as wide as the old pixel font's (22 px advance at 47).
    caps = [scaled[c].width + GAP for c in "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"]
    display = round(CELL * 22.0 / (sum(caps) / len(caps)))
    meta = {"size": CELL, "ascent": ASCENT, "descent": CELL - ASCENT, "space": SPACE,
            "smooth": True, "display_size": display, "fallback": "nano", "glyphs": []}
    for i, ch in enumerate(order):
        g = scaled[ch]
        x = (i % per) * cw
        y = (i // per) * (CELL + 2)
        atlas.alpha_composite(g, (x, y))
        for code in {ord(ch), ord(ch.lower())}:
            meta["glyphs"].append({"code": code, "x": x, "y": y, "w": g.width, "h": CELL, "adv": g.width + GAP})
    atlas.save(os.path.join(OUT, "title_metal.png"), optimize=True)
    with open(os.path.join(OUT, "title_metal.json"), "w", encoding="utf-8", newline="\n") as f:
        json.dump(meta, f)
    print("glyphs", len(order), "atlas", atlas.size, "display", display)


if __name__ == "__main__":
    main()

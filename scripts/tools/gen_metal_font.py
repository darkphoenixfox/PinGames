"""Tilt Breaker's metallic blue title font (D-354), cut from the director's
sheet (assets/source/breakout/metallic_blue_font2.png: A-M, N-Z, then
0-9 ! ? & . , -; D-358).

Each glyph is cut at its transparent gaps, all glyphs of a row share the row's
top and bottom (so they sit on one baseline), and everything is scaled so a
row is GLYPH_H atlas pixels tall. Lower case maps to the capitals. A few marks
the sheet lacks: ":" from two of its periods. Anything else falls back to the
old font.

Writes assets/fonts/title_metal.png + .json in the styled-font format (D-062),
with "smooth": true (scaled freely, not by whole multiples) and
"display_size" (the size that matches the old pixel fonts at scale 1).
Usage: python scripts/tools/gen_metal_font.py
"""
import json
import os

from PIL import Image

ROOT = os.path.normpath(os.path.join(os.path.dirname(__file__), "..", ".."))
SRC = os.path.join(ROOT, "assets", "source", "breakout", "metallic_blue_font2.png")   # D-358: with . , -
OUT = os.path.join(ROOT, "assets", "fonts")
ROWS = ["ABCDEFGHIJKLM", "NOPQRSTUVWXYZ", "0123456789!?&.,-"]
GLYPH_H = 132        # atlas px per row (capitals + their outline)
CELL = 162           # font size in atlas px (ascent + descent: room for Q and comma tails)
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
            if merged and s[0] - merged[-1][1] < 3:
                merged[-1] = (merged[-1][0], s[1])
            else:
                merged.append(s)
        assert len(merged) == len(chars), (chars, len(merged))
        for (x0, x1), ch in zip(merged, chars):
            glyphs[ch] = im.crop((x0, y0, x1, y1))
    k = GLYPH_H / glyphs["A"].height
    # D-357: one scale for every glyph (rows differ in height: N-Z holds Q's
    # tail), all top-aligned, so capitals are equal and Q's tail hangs below.
    scaled = {c: g.resize((max(1, round(g.width * k)), max(1, round(g.height * k))), Image.LANCZOS) for c, g in glyphs.items()}
    # Colon (not on the sheet): two of the sheet's own periods, one on the
    # baseline (where "." sits) and one at mid-height.
    per_img = scaled["."]
    pbb = per_img.getchannel("A").point(lambda v: 255 if v > ALPHA else 0).getbbox()
    dot = per_img.crop(pbb)
    colon = Image.new("RGBA", (dot.width + 4, per_img.height), (0, 0, 0, 0))
    colon.alpha_composite(dot, (2, pbb[1]))
    colon.alpha_composite(dot, (2, GLYPH_H // 2 - dot.height // 2 + 4))
    scaled[":"] = colon
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

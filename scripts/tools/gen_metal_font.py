"""Title fonts cut from the director's painted sheets (A-M, N-Z, then
0-9 ! ? & . , -): Tilt Breaker's metallic blue (D-354, D-358; "metal"),
Turbo Run's sunset chrome (D-366; "sunset_metal") and its blue/red police
version (D-371; "cops_metal"). See FONTS.

Each glyph is cut at its transparent gaps, all glyphs of a row share the row's
top and bottom (so they sit on one baseline), and everything is scaled so a
row is GLYPH_H atlas pixels tall. An italic sheet ("slant") has no clear
columns between its letters, so its glyphs are cut as connected shapes. Lower case maps to the capitals. A few marks
the sheet lacks: ":" from two of its periods. Anything else falls back to the
old font.

Writes assets/fonts/title_<name>.png + .json in the styled-font format (D-062),
with "smooth": true (scaled freely, not by whole multiples) and
"display_size" (the size that matches the old pixel fonts at scale 1).
Usage: python scripts/tools/gen_metal_font.py [name ...]   (default: all)
"""
import json
import os
import sys

from PIL import Image

ROOT = os.path.normpath(os.path.join(os.path.dirname(__file__), "..", ".."))
# name: the sheet, the pixel font used for glyphs the sheet lacks, and the
# extra advance between letters (the sunset sheet is italic, so its letters'
# boxes sit closer).
FONTS = {
    "metal": {"src": ("breakout", "metallic_blue_font2.png"), "fallback": "nano", "gap": 6},   # D-358: with . , -
    "sunset_metal": {"src": ("racer", "sunset_font.png"), "fallback": "sunset", "gap": 0, "slant": 0.17},   # D-366
    "cops_metal": {"src": ("racer", "cops_font.png"), "fallback": "sunset", "gap": 0, "slant": 0.17},       # D-371
}
OUT = os.path.join(ROOT, "assets", "fonts")
ROWS = ["ABCDEFGHIJKLM", "NOPQRSTUVWXYZ", "0123456789!?&.,-"]
GLYPH_H = 132        # atlas px per row (capitals + their outline)
CELL = 162           # font size in atlas px (ascent + descent: room for Q and comma tails)
ASCENT = 132
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


def shapes(im, y0, y1, slant):
    """The glyphs of one row of an italic sheet (D-366), left to right.

    Letters lean into each other's columns, so each is cut as a connected
    shape. Specks are dropped. A small shape that sits within a bigger one's
    span along the slant is part of it (the dots of ! and ?). Each glyph keeps
    its place within the row.
    """
    w = im.width
    a = im.getchannel("A")
    px = a.load()
    hh = y1 - y0
    label = [[0] * w for _ in range(hh)]
    comps = []   # [x0, x1, y0, y1, area]
    for sy in range(hh):
        for sx in range(w):
            if label[sy][sx] or px[sx, y0 + sy] <= ALPHA:
                continue
            n = len(comps) + 1
            box = [sx, sx, sy, sy, 0]
            stack = [(sx, sy)]
            label[sy][sx] = n
            while stack:
                x, y = stack.pop()
                box[0] = min(box[0], x)
                box[1] = max(box[1], x)
                box[2] = min(box[2], y)
                box[3] = max(box[3], y)
                box[4] += 1
                for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1), (1, 1), (1, -1), (-1, 1), (-1, -1)):
                    nx, ny = x + dx, y + dy
                    if 0 <= nx < w and 0 <= ny < hh and not label[ny][nx] and px[nx, y0 + ny] > ALPHA:
                        label[ny][nx] = n
                        stack.append((nx, ny))
            comps.append(box)
    # Each shape's span along the slant (x where its pixels would meet the baseline).
    spans = {}
    for sy in range(hh):
        row = label[sy]
        shift = slant * (sy - hh)
        for sx in range(w):
            n = row[sx]
            if n:
                v = sx + shift
                lo, hi = spans.get(n, (v, v))
                spans[n] = (min(lo, v), max(hi, v))
    keep = [n for n in range(1, len(comps) + 1) if comps[n - 1][4] >= 150]
    keep.sort(key=lambda n: -comps[n - 1][4])
    groups = []   # [[shape ids], lo, hi], biggest shapes first
    for n in keep:
        lo, hi = spans[n]
        for g in groups:
            inside = min(hi, g[2]) - max(lo, g[1])
            if inside >= 0.7 * (hi - lo):
                g[0].append(n)
                break
        else:
            groups.append([[n], lo, hi])
    groups.sort(key=lambda g: g[1])
    out = []
    src = im.load()
    for ids, _lo, _hi in groups:
        x0 = min(comps[n - 1][0] for n in ids)
        x1 = max(comps[n - 1][1] for n in ids) + 1
        ids = set(ids)
        g = Image.new("RGBA", (x1 - x0 + 4, hh), (0, 0, 0, 0))
        gp = g.load()
        # Its own pixels, plus the soft edge within 2 px of them.
        for sy in range(hh):
            for sx in range(max(0, x0 - 2), min(w, x1 + 2)):
                if label[sy][sx] in ids:
                    gp[sx - x0 + 2, sy] = src[sx, y0 + sy]
                elif not label[sy][sx] and src[sx, y0 + sy][3] > 0:
                    near = False
                    for dy in (-2, -1, 0, 1, 2):
                        for dx in (-2, -1, 0, 1, 2):
                            nx, ny = sx + dx, sy + dy
                            if 0 <= nx < w and 0 <= ny < hh and label[ny][nx] in ids:
                                near = True
                    if near:
                        gp[sx - x0 + 2, sy] = src[sx, y0 + sy]
        out.append(g)
    return out


def build(name):
    cfg = FONTS[name]
    gap = cfg["gap"]
    im = Image.open(os.path.join(ROOT, "assets", "source", *cfg["src"])).convert("RGBA")
    a = im.getchannel("A").point(lambda v: 255 if v > ALPHA else 0)
    w, h = im.size
    px = a.load()
    row_has = [any(px[x, y] for x in range(0, w, 2)) for y in range(h)]
    row_bands = bands(row_has, 40)
    assert len(row_bands) == 3, row_bands
    glyphs = {}
    for (y0, y1), chars in zip(row_bands, ROWS):
        if "slant" in cfg:
            cut = shapes(im, y0, y1, cfg["slant"])
            assert len(cut) == len(chars), (chars, len(cut))
            for g, ch in zip(cut, chars):
                glyphs[ch] = g
            continue
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
    caps = [scaled[c].width + gap for c in "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"]
    display = round(CELL * 22.0 / (sum(caps) / len(caps)))
    meta = {"size": CELL, "ascent": ASCENT, "descent": CELL - ASCENT, "space": SPACE,
            "smooth": True, "display_size": display, "fallback": cfg["fallback"], "glyphs": []}
    for i, ch in enumerate(order):
        g = scaled[ch]
        x = (i % per) * cw
        y = (i // per) * (CELL + 2)
        atlas.alpha_composite(g, (x, y))
        for code in {ord(ch), ord(ch.lower())}:
            meta["glyphs"].append({"code": code, "x": x, "y": y, "w": g.width, "h": CELL, "adv": g.width + gap})
    atlas.save(os.path.join(OUT, "title_%s.png" % name), optimize=True)
    with open(os.path.join(OUT, "title_%s.json" % name), "w", encoding="utf-8", newline="\n") as f:
        json.dump(meta, f)
    print(name, "glyphs", len(order), "atlas", atlas.size, "display", display)


if __name__ == "__main__":
    for font_name in (sys.argv[1:] or list(FONTS)):
        build(font_name)

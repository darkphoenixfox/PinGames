"""Generates the per-game styled pixel title fonts (D-062): colourful bitmap fonts
in the "retro pixel" style — gradient fill, 1px highlight on top/left edges,
darker bottom edges, dithered lower shading, a 3D extruded drop and a dark
outline — rendered from PinPixel's glyph shapes (gen_pixel_font.py).

Each style writes, in assets/fonts/:
  title_<style>.png   RGBA glyph atlas (colours baked in)
  title_<style>.json  metrics: cell size, ascent, descent, glyph rects/advances
Godot builds a fixed-size FontFile from them (core/ui/styled_fonts.gd) that
only scales by whole multiples, so pixels stay crisp.

Usage: python scripts/tools/gen_title_fonts.py
"""
import importlib.util
import json
import os

from PIL import Image

HERE = os.path.dirname(__file__)
ROOT = os.path.normpath(os.path.join(HERE, "..", ".."))
OUT_DIR = os.path.join(ROOT, "assets", "fonts")

spec = importlib.util.spec_from_file_location("pinpixel", os.path.join(HERE, "gen_pixel_font.py"))
pinpixel = importlib.util.module_from_spec(spec)
spec.loader.exec_module(pinpixel)

S = 3          # atlas pixels per font pixel
EXT = 3        # 3D extrusion depth (atlas px, down-right)
OUT = 1        # outline thickness
ROW_MIN, ROW_MAX = -3, 10   # accents above .. cedilla below

STYLES = {
    # Tilt Breaker: spaceship / alien nanotech
    "nano": {
        "stops": [(0.0, (255, 255, 255)), (0.18, (150, 245, 255)), (0.5, (40, 170, 255)),
                  (0.8, (110, 60, 230)), (1.0, (70, 20, 150))],
        "highlight": (255, 255, 255), "shade": (30, 10, 80), "ext": [(70, 30, 150), (40, 15, 95), (25, 8, 60)],
        "outline": (6, 3, 18), "band": (0.42, (210, 255, 255)),
    },
    # Sky Striker: military arcade (like the classic retro-pixel look)
    "squadron": {
        "stops": [(0.0, (255, 250, 170)), (0.3, (255, 205, 60)), (0.65, (255, 120, 30)), (1.0, (220, 50, 30))],
        "highlight": (255, 255, 220), "shade": (130, 30, 15), "ext": [(190, 80, 20), (130, 45, 15), (80, 25, 10)],
        "outline": (20, 8, 5), "band": None,
    },
    # Shell (D-186): gold marquee for the bundle's big titles and prompts
    "marquee": {
        "stops": [(0.0, (255, 255, 235)), (0.22, (255, 236, 120)), (0.5, (255, 190, 40)),
                  (0.78, (235, 120, 20)), (1.0, (170, 60, 15))],
        "highlight": (255, 255, 245), "shade": (110, 35, 10), "ext": [(150, 40, 25), (100, 22, 18), (60, 12, 12)],
        "outline": (18, 6, 4), "band": (0.46, (255, 250, 210)),
    },
    # Shell (D-186): cool silver chrome for headings, scores and status lines
    "chrome": {
        "stops": [(0.0, (255, 255, 255)), (0.4, (215, 225, 245)), (0.5, (140, 155, 200)),
                  (0.501, (95, 105, 160)), (0.75, (170, 190, 235)), (1.0, (235, 245, 255))],
        "highlight": (255, 255, 255), "shade": (40, 45, 90), "ext": [(60, 55, 130), (40, 35, 95), (22, 20, 60)],
        "outline": (8, 6, 20), "band": None,
    },
    # Turbo Run: 80s sunset chrome (hard horizon split)
    "sunset": {
        "stops": [(0.0, (255, 255, 255)), (0.35, (255, 170, 230)), (0.5, (230, 70, 180)),
                  (0.501, (40, 30, 120)), (0.7, (60, 120, 255)), (1.0, (150, 240, 255))],
        "highlight": (255, 255, 255), "shade": (30, 20, 90), "ext": [(110, 30, 140), (70, 15, 100), (40, 8, 60)],
        "outline": (10, 4, 22), "band": None,
    },
}


def lerp(a, b, t):
    return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(3))


def gradient(stops, t):
    t = min(max(t, 0.0), 1.0)
    for (t0, c0), (t1, c1) in zip(stops, stops[1:]):
        if t <= t1:
            return lerp(c0, c1, 0.0 if t1 == t0 else (t - t0) / (t1 - t0))
    return stops[-1][1]


def render(rows: dict, style: dict) -> Image.Image:
    w = max(len(line) for line in rows.values())
    n_rows = ROW_MAX - ROW_MIN + 1
    cw, ch = w * S + EXT + 2 * OUT, n_rows * S + EXT + 2 * OUT
    body = set()
    for r, line in rows.items():
        for c, cell in enumerate(line):
            if cell == "#":
                for dy in range(S):
                    for dx in range(S):
                        body.add((OUT + c * S + dx, OUT + (r - ROW_MIN) * S + dy))
    img = Image.new("RGBA", (cw, ch), (0, 0, 0, 0))
    px = img.load()
    # Extrusion (drawn far -> near) and outline around body + extrusion
    solid = set(body)
    for k in range(EXT, 0, -1):
        col = style["ext"][min(k - 1, len(style["ext"]) - 1)]
        for (x, y) in body:
            p = (x + k, y + k)
            if p not in body:
                px[p] = (*col, 255)
                solid.add(p)
    for (x, y) in list(solid):
        for dx in (-1, 0, 1):
            for dy in (-1, 0, 1):
                q = (x + dx, y + dy)
                if q not in solid and 0 <= q[0] < cw and 0 <= q[1] < ch:
                    px[q] = (*style["outline"], 255)
    # Body: vertical gradient over the cap height, highlight, shading, dither
    cap_top = OUT + (0 - ROW_MIN) * S
    cap_h = 9 * S
    band = style.get("band")
    for (x, y) in body:
        t = (y - cap_top) / max(1, cap_h - 1)
        c = gradient(style["stops"], t)
        if band and abs(t - band[0]) < 0.5 / 9:
            c = lerp(c, band[1], 0.6)
        if t > 0.55 and (x + y) % 2 == 0:
            c = lerp(c, style["shade"], 0.35)
        if (x, y - 1) not in body:
            c = style["highlight"]
        elif (x - 1, y) not in body:
            c = lerp(c, style["highlight"], 0.45)
        elif (x, y + 1) not in body or (x + 1, y) not in body:
            c = lerp(c, style["shade"], 0.45)
        px[x, y] = (*c, 255)
    return img


def build(style_name: str):
    style = STYLES[style_name]
    chars = list(pinpixel.G.keys()) + list(pinpixel.ACCENTED.keys()) + ["Ç"]
    glyph_imgs = {ch: render(pinpixel.glyph_rows(ch), style) for ch in chars}
    cell_h = next(iter(glyph_imgs.values())).height
    # Pack into rows of an atlas
    atlas_w = 1024
    x = y = 0
    row_h = cell_h + 1
    placed = {}
    for ch in chars:
        im = glyph_imgs[ch]
        if x + im.width > atlas_w:
            x = 0
            y += row_h
        placed[ch] = (x, y, im)
        x += im.width + 1
    atlas = Image.new("RGBA", (atlas_w, y + row_h), (0, 0, 0, 0))
    glyphs = []
    baseline = OUT + (9 - ROW_MIN) * S
    for ch, (gx, gy, im) in placed.items():
        atlas.paste(im, (gx, gy))
        w = max(len(line) for line in pinpixel.glyph_rows(ch).values())
        entry = {"x": gx, "y": gy, "w": im.width, "h": im.height, "adv": (w + 1) * S + 1}
        codes = [ord(ch)]
        low = ch.lower()
        if low != ch and len(low) == 1:
            codes.append(ord(low))
        for code in codes:
            glyphs.append({"code": code, **entry})
    meta = {"size": cell_h, "ascent": baseline, "descent": cell_h - baseline,
            "space": 4 * S, "glyphs": glyphs}
    os.makedirs(OUT_DIR, exist_ok=True)
    atlas.save(os.path.join(OUT_DIR, f"title_{style_name}.png"), optimize=True)
    with open(os.path.join(OUT_DIR, f"title_{style_name}.json"), "w", encoding="utf-8") as f:
        json.dump(meta, f)
    print(f"title_{style_name}: {len(chars)} glyphs, cell height {cell_h}px, atlas {atlas.size}")


if __name__ == "__main__":
    for name in STYLES:
        build(name)

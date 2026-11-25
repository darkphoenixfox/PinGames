"""Turbo Run's 8-BIT and 16-BIT title fonts (D-384) from the director's
pixel-art sheets (A-M, N-Z, then 0-9 ! ? & . , -), and their police recolours.

The sheets are pixel art blown up on a grey card (2730x1536: one art pixel is
10.66 px on the 8-bit sheet, 5.33 px on the 16-bit one). Each art pixel is
read back from the middle of its cell, the grey is removed, the colours are
snapped to a small palette, and the glyphs are cut as connected shapes (the
letters are italic). ":" is two of the sheet's periods.

Writes assets/fonts/title_<name>.png + .json for
  sunset_8, sunset_16    the sheets as drawn
  sunset_16s             the 16-bit art at half size, for smaller text
  cops_8, cops_16, cops_16s   the same glyphs in police blue over red
in the styled-font format (D-062) with "pixel": true: drawn 1:1 on the
low-resolution UI, never smoothed.
The director has since cleaned the six images by hand (stray pixels, missing
pixels; D-385). Running this again would overwrite that work, so it refuses
unless --force is given.
Usage: python scripts/tools/gen_pixel_font.py --force
       python scripts/tools/gen_pixel_font.py --police   (only re-make the
           three police images from the current sunset images)
"""
import colorsys
import json
import os

import numpy as np
from PIL import Image

ROOT = os.path.normpath(os.path.join(os.path.dirname(__file__), "..", ".."))
SRC = os.path.join(ROOT, "assets", "source", "racer")
OUT = os.path.join(ROOT, "assets", "fonts")
ROWS = ["ABCDEFGHIJKLM", "NOPQRSTUVWXYZ", "0123456789!?&.,-"]
SHEETS = {
    "8": {"file": "sunset_font_8bit.png", "grid": (256, 144), "colours": 4},
    "16": {"file": "sunset_font_16bit.png", "grid": (512, 288), "colours": 14},
}
SLANT = 0.17


def art_pixels(path, grid, colours):
    """The sheet's own pixels: RGBA array at `grid` size, grey card cleared."""
    a = np.array(Image.open(path).convert("RGB")).astype(np.float32)
    h, w, _ = a.shape
    gw, gh = grid
    cw, ch = w / gw, h / gh
    bg = np.median(a.reshape(-1, 3), axis=0)
    out = np.zeros((gh, gw, 4), np.uint8)
    for gy in range(gh):
        y0, y1 = int((gy + 0.3) * ch), max(int((gy + 0.7) * ch), int((gy + 0.3) * ch) + 1)
        for gx in range(gw):
            x0, x1 = int((gx + 0.3) * cw), max(int((gx + 0.7) * cw), int((gx + 0.3) * cw) + 1)
            c = np.median(a[y0:y1, x0:x1].reshape(-1, 3), axis=0)
            if np.abs(c - bg).sum() <= 75:
                continue
            # The soft dark glow round each letter on the card: dull and
            # mid-dark (the letters' own dark line is a strong purple).
            hi, lo = float(c.max()), float(c.min())
            if hi < 153 and (hi - lo) / max(hi, 1.0) < 0.35 and hi > 56:
                continue
            out[gy, gx] = (int(c[0]), int(c[1]), int(c[2]), 255)
    solid = out[..., 3] > 0
    # Snap the colours to a small palette (solid pixels only).
    # The most used colours (in steps of 24, so near-identical ones count
    # together) are the art's palette; every pixel takes the nearest.
    cols = out[solid][:, :3].astype(np.int32)
    keys, inv, counts = np.unique(cols // 24, axis=0, return_inverse=True, return_counts=True)
    inv = inv.reshape(-1)
    top = np.argsort(-counts)[:colours]
    pal = np.array([np.median(cols[inv == k], axis=0) for k in top])
    near = np.argmin(((cols[:, None, :] - pal[None, :, :]) ** 2).sum(axis=2), axis=1)
    out[solid, :3] = pal[near].astype(np.uint8)
    return out


def bands(flags, n_min):
    res, start = [], None
    for i, v in enumerate(list(flags) + [False]):
        if v and start is None:
            start = i
        elif not v and start is not None:
            if i - start >= n_min:
                res.append((start, i))
            start = None
    return res


def shapes(px, y0, y1, min_area):
    """One row's glyphs, left to right, each [x0, x1) with its own pixels only.

    Neighbours touch through their dark lines and shadows, so the letters are
    found by their bright fill (which never touches), a small piece within a
    bigger one's span along the slant joining it (the dots of ! and ?). Every
    dark pixel then goes to the letter whose fill it is nearest to.
    """
    solid = px[y0:y1, :, 3] > 0
    fill = solid & (px[y0:y1, :, :3].max(axis=2) > 110)
    hh, w = solid.shape
    label = np.zeros((hh, w), np.int32)
    comps = []
    for sy in range(hh):
        for sx in range(w):
            if label[sy, sx] or not fill[sy, sx]:
                continue
            n = len(comps) + 1
            area = 0
            stack = [(sx, sy)]
            label[sy, sx] = n
            while stack:
                x, y = stack.pop()
                area += 1
                for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1), (1, 1), (1, -1), (-1, 1), (-1, -1)):
                    nx, ny = x + dx, y + dy
                    if 0 <= nx < w and 0 <= ny < hh and not label[ny, nx] and fill[ny, nx]:
                        label[ny, nx] = n
                        stack.append((nx, ny))
            comps.append(area)
    spans = {}
    for sy in range(hh):
        shift = SLANT * (sy - hh)
        for sx in np.nonzero(label[sy])[0]:
            n = int(label[sy, sx])
            v = sx + shift
            lo, hi = spans.get(n, (v, v))
            spans[n] = (min(lo, v), max(hi, v))
    keep = sorted([n for n in range(1, len(comps) + 1) if comps[n - 1] >= min_area], key=lambda n: -comps[n - 1])
    groups = []
    for n in keep:
        lo, hi = spans[n]
        for g in groups:
            if min(hi, g[2]) - max(lo, g[1]) >= 0.7 * (hi - lo):
                g[0].append(n)
                break
        else:
            groups.append([[n], lo, hi])
    groups.sort(key=lambda g: g[1])
    # Letter number per pixel: the fills first, then outwards through the dark.
    owner = np.zeros((hh, w), np.int32)
    for k, g in enumerate(groups):
        owner[np.isin(label, g[0])] = k + 1
    frontier = list(zip(*np.nonzero(owner)))
    while frontier:
        nxt = []
        for y, x in frontier:
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1), (1, 1), (1, -1), (-1, 1), (-1, -1)):
                nx, ny = x + dx, y + dy
                if 0 <= nx < w and 0 <= ny < hh and solid[ny, nx] and not owner[ny, nx]:
                    owner[ny, nx] = owner[y, x]
                    nxt.append((ny, nx))
        frontier = nxt
    out = []
    for k in range(1, len(groups) + 1):
        xs = np.nonzero((owner == k).any(axis=0))[0]
        x0, x1 = int(xs.min()), int(xs.max()) + 1
        g = px[y0:y1, x0:x1].copy()
        g[owner[:, x0:x1] != k] = 0
        out.append(g)
    return out


def halved(px):
    """The 16-bit art at half size, for smaller text: each 2x2 block becomes
    one pixel. A block that is mostly empty is clear; one with two or more
    dark pixels keeps the dark line; otherwise its most used colour."""
    h, w, _ = px.shape
    out = np.zeros((h // 2, w // 2, 4), np.uint8)
    for y in range(h // 2):
        for x in range(w // 2):
            blk = px[y * 2:y * 2 + 2, x * 2:x * 2 + 2].reshape(4, 4)
            sol = blk[blk[:, 3] > 0]
            if len(sol) < 2:
                continue
            dark = sol[sol[:, :3].max(axis=1) <= 110]
            pick = dark if len(dark) >= 2 else sol[sol[:, :3].max(axis=1) > 110]
            cols, counts = np.unique(pick, axis=0, return_counts=True)
            out[y, x] = cols[np.argmax(counts)]
    return out


def police(px):
    """The sunset colours as police blue (top) over red: yellows and oranges
    turn blue, the reds and pinks turn pure red, the dark line stays."""
    out = px.copy()
    seen = {}
    for y, x in zip(*np.nonzero(px[..., 3])):
        c = tuple(int(v) for v in px[y, x, :3])
        if c not in seen:
            h, s, v = colorsys.rgb_to_hsv(c[0] / 255, c[1] / 255, c[2] / 255)
            deg = h * 360
            if v < 0.4:
                n = c
            elif 26 <= deg <= 75:      # yellow, light orange -> blue, paler where it was lighter
                n = colorsys.hsv_to_rgb(0.60, max(0.35, min(1.0, 1.25 - s * 0.55 + (1.0 - v))), min(1.0, v + 0.05))
            else:                      # deep orange, red, pink, magenta -> red
                n = colorsys.hsv_to_rgb(0.99, min(1.0, s + 0.25), v)
            seen[c] = tuple(int(round(k * 255)) for k in n) if not isinstance(n[0], int) else n
        out[y, x, :3] = seen[c]
    return out


def build(tag, px, name, half=False):
    solid = px[..., 3] > 0
    rows = bands(solid.sum(axis=1) > 0, 6)
    assert len(rows) == 3, rows
    cell = max(y1 - y0 for y0, y1 in rows)
    ascent = rows[0][1] - rows[0][0]
    glyphs = {}
    for (y0, y1), chars in zip(rows, ROWS):
        cut = shapes(px, y0, y1, 14 if tag == "16" else 3)
        assert len(cut) == len(chars), (name, chars, len(cut))
        for g, ch in zip(cut, chars):
            if half:   # each letter on its own, so none merge
                pad = np.zeros((g.shape[0] + g.shape[0] % 2, g.shape[1] + g.shape[1] % 2, 4), np.uint8)
                pad[:g.shape[0], :g.shape[1]] = g
                g = halved(pad)
            glyphs[ch] = g
    if half:
        cell = (cell + 1) // 2
        ascent = (ascent + 1) // 2
    dot = glyphs["."]
    ys = np.nonzero(dot[..., 3].sum(axis=1))[0]
    d = dot[ys.min():ys.max() + 1]
    colon = np.zeros((cell, dot.shape[1], 4), np.uint8)
    colon[ys.min():ys.max() + 1] = d
    mid = ascent // 2 - d.shape[0] // 2
    colon[mid:mid + d.shape[0]] = d
    glyphs[":"] = colon
    order = list(glyphs)
    per = 16
    cw = max(g.shape[1] for g in glyphs.values()) + 2
    atlas = np.zeros(((cell + 2) * ((len(order) + per - 1) // per), cw * per, 4), np.uint8)
    caps = [glyphs[c].shape[1] for c in "ABCDEFGHIJKLMNOPQRSTUVWXYZ"]
    meta = {"size": cell, "ascent": ascent, "descent": cell - ascent, "space": round(sum(caps) / len(caps) * 0.45),
            "pixel": True, "fallback": "sunset", "glyphs": []}
    for i, ch in enumerate(order):
        g = glyphs[ch]
        x, y = (i % per) * cw, (i // per) * (cell + 2)
        atlas[y:y + g.shape[0], x:x + g.shape[1]] = g
        for code in {ord(ch), ord(ch.lower())}:
            meta["glyphs"].append({"code": code, "x": x, "y": y, "w": int(g.shape[1]), "h": cell, "adv": int(g.shape[1])})
    Image.fromarray(atlas, "RGBA").save(os.path.join(OUT, "title_%s.png" % name))
    with open(os.path.join(OUT, "title_%s.json" % name), "w", encoding="utf-8", newline="\n") as f:
        json.dump(meta, f)
    print(name, "glyphs", len(order), "cell", cell, "ascent", ascent, "atlas", atlas.shape[1], atlas.shape[0])


def recolour_police():
    """The police images again from the hand-finished sunset ones (D-386)."""
    for t in ("8", "16s", "16"):
        a = np.array(Image.open(os.path.join(OUT, "title_sunset_%s.png" % t)).convert("RGBA"))
        Image.fromarray(police(a), "RGBA").save(os.path.join(OUT, "title_cops_%s.png" % t))
    print("police fonts recoloured from the sunset images")


def main():
    import sys
    if "--police" in sys.argv:
        recolour_police()
        return
    if "--force" not in sys.argv:
        raise SystemExit("The font images were edited by hand (D-385); --force overwrites them.")
    for tag, cfg in SHEETS.items():
        px = art_pixels(os.path.join(SRC, cfg["file"]), cfg["grid"], cfg["colours"])
        build(tag, px, "sunset_%s" % tag)
        build(tag, police(px), "cops_%s" % tag)
        if tag == "16":
            build(tag, px, "sunset_16s", True)
            build(tag, police(px), "cops_16s", True)


if __name__ == "__main__":
    main()

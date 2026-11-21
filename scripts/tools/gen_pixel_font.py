"""Generates PinPixel, the bundle's pixel-art UI font (D-060), as a TrueType file.

Style: 16-bit sci-fi arcade — chunky 2-pixel strokes, squared letters with
chamfered corners, 9-pixel cap height, uppercase design (lowercase maps to the
same glyphs). Covers A-Z, 0-9, common punctuation and Latin accents for
translations (accents sit in 3 rows above the caps; cedilla below).

Each glyph is drawn on a pixel grid: rows top->bottom, '#' = on. Row 0 is the
cap top; negative rows (accents) and rows 9-10 (cedilla) are handled by the
accent tables. One font pixel = 100 font units; UPM 1200, so at font size N px
one font pixel = N/12 screen pixels (use multiples of 12 for crisp pixels).

Output: assets/fonts/pinpixel.ttf
Usage:  python scripts/tools/gen_pixel_font.py
"""
import os

from fontTools.fontBuilder import FontBuilder
from fontTools.pens.ttGlyphPen import TTGlyphPen

ROOT = os.path.normpath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT = os.path.join(ROOT, "assets", "fonts", "pinpixel.ttf")
PX = 100
UPM = 1200
CAP = 9          # rows 0..8
ASCENT = 1200    # room for accents (3 rows above caps)
DESCENT = 200    # room for the cedilla (2 rows below)

G = {
    "A": [".####.", "##..##", "##..##", "##..##", "######", "##..##", "##..##", "##..##", "##..##"],
    "B": ["#####.", "##..##", "##..##", "##..##", "#####.", "##..##", "##..##", "##..##", "#####."],
    "C": [".#####", "##....", "##....", "##....", "##....", "##....", "##....", "##....", ".#####"],
    "D": ["#####.", "##..##", "##..##", "##..##", "##..##", "##..##", "##..##", "##..##", "#####."],
    "E": ["######", "##....", "##....", "##....", "#####.", "##....", "##....", "##....", "######"],
    "F": ["######", "##....", "##....", "##....", "#####.", "##....", "##....", "##....", "##...."],
    "G": [".#####", "##....", "##....", "##....", "##.###", "##..##", "##..##", "##..##", ".#####"],
    "H": ["##..##", "##..##", "##..##", "##..##", "######", "##..##", "##..##", "##..##", "##..##"],
    "I": ["######", "..##..", "..##..", "..##..", "..##..", "..##..", "..##..", "..##..", "######"],
    "J": ["....##", "....##", "....##", "....##", "....##", "....##", "....##", "##..##", ".####."],
    "K": ["##..##", "##.##.", "####..", "###...", "###...", "####..", "##.##.", "##..##", "##..##"],
    "L": ["##....", "##....", "##....", "##....", "##....", "##....", "##....", "##....", "######"],
    "M": ["##...##", "###.###", "#######", "##.#.##", "##...##", "##...##", "##...##", "##...##", "##...##"],
    "N": ["##..##", "###.##", "###.##", "######", "##.###", "##.###", "##..##", "##..##", "##..##"],
    "O": [".####.", "##..##", "##..##", "##..##", "##..##", "##..##", "##..##", "##..##", ".####."],
    "P": ["#####.", "##..##", "##..##", "##..##", "#####.", "##....", "##....", "##....", "##...."],
    "Q": [".####.", "##..##", "##..##", "##..##", "##..##", "##..##", "##..##", "##.###", ".#####"],
    "R": ["#####.", "##..##", "##..##", "##..##", "#####.", "####..", "##.##.", "##..##", "##..##"],
    "S": [".#####", "##....", "##....", "##....", ".####.", "....##", "....##", "....##", "#####."],
    "T": ["######", "..##..", "..##..", "..##..", "..##..", "..##..", "..##..", "..##..", "..##.."],
    "U": ["##..##", "##..##", "##..##", "##..##", "##..##", "##..##", "##..##", "##..##", ".####."],
    "V": ["##..##", "##..##", "##..##", "##..##", "##..##", "##..##", "##..##", ".####.", "..##.."],
    "W": ["##...##", "##...##", "##...##", "##...##", "##...##", "##.#.##", "#######", "###.###", "##...##"],
    "X": ["##..##", "##..##", ".####.", "..##..", "..##..", "..##..", ".####.", "##..##", "##..##"],
    "Y": ["##..##", "##..##", "##..##", ".####.", "..##..", "..##..", "..##..", "..##..", "..##.."],
    "Z": ["######", "....##", "...###", "..###.", ".###..", "###...", "##....", "##....", "######"],
    "0": [".####.", "##..##", "##.###", "##.###", "###.##", "###.##", "##..##", "##..##", ".####."],
    "1": ["..##..", ".###..", "####..", "..##..", "..##..", "..##..", "..##..", "..##..", "######"],
    "2": [".####.", "##..##", "....##", "....##", ".####.", "##....", "##....", "##....", "######"],
    "3": ["#####.", "....##", "....##", "....##", ".####.", "....##", "....##", "....##", "#####."],
    "4": ["##..##", "##..##", "##..##", "##..##", "######", "....##", "....##", "....##", "....##"],
    "5": ["######", "##....", "##....", "##....", "#####.", "....##", "....##", "....##", "#####."],
    "6": [".#####", "##....", "##....", "##....", "#####.", "##..##", "##..##", "##..##", ".####."],
    "7": ["######", "....##", "....##", "...##.", "..##..", "..##..", "..##..", "..##..", "..##.."],
    "8": [".####.", "##..##", "##..##", "##..##", ".####.", "##..##", "##..##", "##..##", ".####."],
    "9": [".####.", "##..##", "##..##", "##..##", ".#####", "....##", "....##", "....##", "#####."],
    ".": ["..", "..", "..", "..", "..", "..", "..", "##", "##"],
    ",": ["..", "..", "..", "..", "..", "..", "..", "##", "##", ".#", "#."],  # tail below the baseline
    ":": ["..", "..", "##", "##", "..", "..", "##", "##", ".."],
    ";": ["..", "..", "##", "##", "..", "..", "..", "##", "##", ".#", "#."],
    "!": ["##", "##", "##", "##", "##", "##", "..", "##", "##"],
    "?": [".####.", "##..##", "....##", "...##.", "..##..", "..##..", "......", "..##..", "..##.."],
    "-": ["....", "....", "....", "....", "####", "....", "....", "....", "...."],
    "+": ["......", "......", "..##..", "..##..", "######", "######", "..##..", "..##..", "......"],
    "'": ["##", "##", "#.", "..", "..", "..", "..", "..", ".."],
    "\"": ["##.##", "##.##", "#..#.", ".....", ".....", ".....", ".....", ".....", "....."],
    "/": ["....##", "....##", "...##.", "...##.", "..##..", ".##...", ".##...", "##....", "##...."],
    "%": ["##...##", "##..##.", "...##..", "..##...", ".##....", "##.....", ".....##", "....###", "....###"],
    "#": [".......", ".##.##.", "#######", ".##.##.", ".##.##.", "#######", ".##.##.", ".......", "......."],
    "(": [".##", "##.", "##.", "##.", "##.", "##.", "##.", "##.", ".##"],
    ")": ["##.", ".##", ".##", ".##", ".##", ".##", ".##", ".##", "##."],
    "<": [".....", "...##", "..##.", ".##..", "##...", ".##..", "..##.", "...##", "....."],
    ">": [".....", "##...", ".##..", "..##.", "...##", "..##.", ".##..", "##...", "....."],
    "=": ["......", "......", "######", "######", "......", "######", "######", "......", "......"],
    "_": ["......", "......", "......", "......", "......", "......", "......", "......", "######"],
    "*": ["......", "#.##.#", ".####.", "######", ".####.", "#.##.#", "......", "......", "......"],
    "&": [".###...", "##.##..", "##.##..", ".###...", ".####.#", "##.####", "##..##.", "##..###", ".####.#"],
    "¡": ["##", "##", "..", "##", "##", "##", "##", "##", "##"],
    "¿": ["..##..", "..##..", "......", "..##..", "..##..", ".##...", "##....", "##..##", ".####."],
}

# Accent marks: (rows above the cap top, as list from top), width matches base.
ACCENTS = {
    "acute": ["...##.", "..##.."],
    "grave": [".##...", "..##.."],
    "diaeresis": ["##..##", "##..##"],
    "circumflex": [".####.", "##..##"],
    "tilde": [".###.#", "#.###."],
}
ACCENTED = {
    "Á": ("A", "acute"), "É": ("E", "acute"), "Í": ("I", "acute"), "Ó": ("O", "acute"), "Ú": ("U", "acute"),
    "À": ("A", "grave"), "È": ("E", "grave"), "Ì": ("I", "grave"), "Ò": ("O", "grave"), "Ù": ("U", "grave"),
    "Ä": ("A", "diaeresis"), "Ë": ("E", "diaeresis"), "Ï": ("I", "diaeresis"), "Ö": ("O", "diaeresis"),
    "Ü": ("U", "diaeresis"), "Â": ("A", "circumflex"), "Ê": ("E", "circumflex"), "Î": ("I", "circumflex"),
    "Ô": ("O", "circumflex"), "Û": ("U", "circumflex"), "Ñ": ("N", "tilde"), "Ã": ("A", "tilde"),
    "Õ": ("O", "tilde"),
}
CEDILLA = ["..##..", ".##..."]  # rows 9..10 below the cap baseline


def glyph_rows(ch: str):
    """Returns {row: pattern} with row 0 = cap top (negative = above)."""
    if ch in G:
        return {r: line for r, line in enumerate(G[ch])}
    if ch in ACCENTED:
        base, mark = ACCENTED[ch]
        rows = {r: line for r, line in enumerate(G[base])}
        acc = ACCENTS[mark]
        w = len(G[base][0])
        for i, line in enumerate(acc):  # rows -3, -2 (row -1 left blank)
            pad = (w - len(line)) // 2
            rows[-3 + i] = ("." * pad + line).ljust(w, ".")[:w]
        return rows
    if ch == "Ç":
        rows = {r: line for r, line in enumerate(G["C"])}
        rows[9], rows[10] = CEDILLA
        return rows
    return None


def draw(rows: dict):
    pen = TTGlyphPen(None)
    for r, line in rows.items():
        y_top = (CAP - r) * PX  # baseline at the bottom of row 8
        for c, cell in enumerate(line):
            if cell != "#":
                continue
            x0, x1 = c * PX, (c + 1) * PX
            y1, y0 = y_top, y_top - PX
            pen.moveTo((x0, y0))  # clockwise (TrueType outer contour)
            pen.lineTo((x0, y1))
            pen.lineTo((x1, y1))
            pen.lineTo((x1, y0))
            pen.closePath()
    return pen.glyph()


def main():
    chars = list(G.keys()) + list(ACCENTED.keys()) + ["Ç"]
    names = {ch: f"uni{ord(ch):04X}" for ch in chars}
    glyph_order = [".notdef", "space"] + [names[c] for c in chars]
    cmap = {32: "space", 0xA0: "space"}
    glyphs = {}
    metrics = {}
    empty = TTGlyphPen(None).glyph()
    # .notdef: hollow box
    nd = {r: ("######" if r in (0, 8) else "##..##") for r in range(9)}
    glyphs[".notdef"] = draw(nd)
    metrics[".notdef"] = (7 * PX, 0)
    glyphs["space"] = empty
    metrics["space"] = (4 * PX, 0)
    for ch in chars:
        rows = glyph_rows(ch)
        w = max(len(line) for line in rows.values())
        glyphs[names[ch]] = draw(rows)
        metrics[names[ch]] = ((w + 1) * PX, 0)
        cmap[ord(ch)] = names[ch]
        low = ch.lower()
        if low != ch and len(low) == 1:
            cmap[ord(low)] = names[ch]  # lowercase -> same (uppercase) design
    fb = FontBuilder(UPM, isTTF=True)
    fb.setupGlyphOrder(glyph_order)
    fb.setupCharacterMap(cmap)
    fb.setupGlyf(glyphs)
    fb.setupHorizontalMetrics(metrics)
    fb.setupHorizontalHeader(ascent=ASCENT, descent=-DESCENT)
    fb.setupNameTable({"familyName": "PinPixel", "styleName": "Regular",
                       "uniqueFontIdentifier": "PinPixel-Regular", "fullName": "PinPixel Regular",
                       "psName": "PinPixel-Regular", "version": "Version 1.0",
                       "copyright": "PinGames project (in-house)"})
    fb.setupOS2(sTypoAscender=ASCENT, sTypoDescender=-DESCENT, usWinAscent=ASCENT, usWinDescent=DESCENT,
                sCapHeight=CAP * PX, sxHeight=CAP * PX)
    fb.setupPost()
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    fb.save(OUT)
    print(f"wrote {OUT} ({len(chars)} glyphs)")


if __name__ == "__main__":
    main()

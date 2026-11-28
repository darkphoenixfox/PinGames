"""TURBO RUN: window light masks for the house sprites (D-529).

For each house sprite, writes <name>_lights.png next to it: greyscale, white
where a lit window's glass (or a lamp) is. Kept as its own texture, never in
the sprite's alpha. Each window is a box around its glass; inside the box only
the pixels close to the box's most common colour (the glass) are lit, so the
frames and glazing bars stay dark.

Run from the repo root:  python scripts/tools/gen_house_lights.py
"""
from PIL import Image, ImageDraw, ImageFilter
import numpy as np

DIR = "assets/sprites/racer/hd/"
# name -> (windows [x0, y0, x1, y1], lamps [x, y, radius])
HOUSES = {
    "house_1": ([[225, 150, 317, 279], [467, 152, 542, 250]], []),
    "house_2": ([[408, 186, 543, 264], [408, 394, 543, 486], [177, 403, 275, 467]], []),
    "house_3": ([[278, 358, 346, 444], [270, 315, 346, 343]], [[82, 402, 13]]),
    "chalet_1": ([[320, 182, 386, 265], [149, 367, 204, 435], [502, 367, 560, 435]], [[270, 375, 9], [439, 375, 9]]),
    "chalet_2": ([[472, 94, 521, 132], [361, 187, 389, 215], [637, 187, 668, 215],
                  [328, 317, 378, 355], [483, 317, 521, 355],
                  [317, 452, 380, 502], [634, 452, 698, 502]], [[435, 461, 9], [573, 458, 9]]),
    "townhouse": ([[77, 284, 118, 380], [375, 284, 415, 380], [228, 488, 269, 582], [77, 488, 118, 582],
                   [233, 99, 267, 165], [382, 123, 412, 171],
                   [57, 689, 178, 854], [297, 689, 443, 854]], []),
}
NEAR = 70.0   # how far from the box's glass colour still counts as glass


def main() -> None:
    for name, (windows, lamps) in HOUSES.items():
        im = Image.open(DIR + name + ".png").convert("RGBA")
        a = np.asarray(im).astype(np.float32)
        mask = np.zeros(a.shape[:2], np.float32)
        for x0, y0, x1, y1 in windows:
            box = a[y0:y1, x0:x1, :3]
            glass = np.median(box.reshape(-1, 3), axis=0)
            d = np.sqrt(((box - glass) ** 2).sum(axis=2))
            mask[y0:y1, x0:x1] = np.maximum(mask[y0:y1, x0:x1], (d < NEAR).astype(np.float32))
        out = Image.fromarray((mask * 255).astype(np.uint8), "L")
        draw = ImageDraw.Draw(out)
        for x, y, r in lamps:
            draw.ellipse([x - r, y - r, x + r, y + r], fill=255)
        out = out.filter(ImageFilter.GaussianBlur(0.8))
        # Nothing outside the sprite itself.
        out = Image.fromarray((np.asarray(out) * (a[:, :, 3] > 128)).astype(np.uint8), "L")
        out.convert("RGB").save(DIR + name + "_lights.png")
        print(name, im.size)


if __name__ == "__main__":
    main()

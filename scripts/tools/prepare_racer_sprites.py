"""Turbo Run art (D-107): turns the Qwen-Image sources in assets/source/racer/gen/
into game sprites in assets/sprites/racer/.

- Sprites: white background removed (flood fill from the border, sprite_cutout.py),
  cropped, the soft ground shadow some generations add is kept, then scaled down
  with nearest-neighbour by a whole factor so the pixel-art grid stays crisp.
  Alpha is cut hard (0/255) because the game draws them with alpha scissor.
- Sky: scaled to 1024 wide; the game wraps it around a cylinder behind the world.
Run: python scripts/tools/prepare_racer_sprites.py
"""
import os
import sys
from PIL import Image

sys.path.insert(0, os.path.dirname(__file__))
from sprite_cutout import cutout  # noqa: E402

ROOT = os.path.join(os.path.dirname(__file__), "..", "..")
SRC = os.path.join(ROOT, "assets", "source", "racer", "gen")
DST = os.path.join(ROOT, "assets", "sprites", "racer")

# name -> target height in pixels (world size is set in the game)
SPRITES = {
    "palm_1": 256, "palm_2": 256,
    "bush_1": 96, "bush_2": 72,
    "sign_curve": 128, "sign_green": 112,
    "gantry": 144,
    "nitro": 128,
    "speedtrap": 128,
}


# Sprites whose enclosed background holes (e.g. the gantry truss) must go too.
HOLES = {"gantry"}


def remove_grey_framed_holes(img):
    """Clears near-white regions enclosed by grey (low-saturation) pixels, such
    as the gaps in a steel truss, but keeps white enclosed by colour (arrows)."""
    w, h = img.size
    px = img.load()
    seen = bytearray(w * h)
    for sy in range(h):
        for sx in range(w):
            c = px[sx, sy]
            if seen[sy * w + sx] or c[3] == 0 or min(c[:3]) < 235:
                continue
            comp, ring, stack = [], [], [(sx, sy)]
            seen[sy * w + sx] = 1
            while stack:
                x, y = stack.pop()
                comp.append((x, y))
                for nx, ny in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)):
                    if not (0 <= nx < w and 0 <= ny < h):
                        continue
                    n = px[nx, ny]
                    if n[3] != 0 and min(n[:3]) >= 235:
                        if not seen[ny * w + nx]:
                            seen[ny * w + nx] = 1
                            stack.append((nx, ny))
                    elif n[3] != 0:
                        ring.append(n)
            if not ring:
                continue
            sat = sum((max(c[:3]) - min(c[:3])) / max(1, max(c[:3])) for c in ring) / len(ring)
            if sat < 0.25:
                for x, y in comp:
                    q = px[x, y]
                    px[x, y] = (q[0], q[1], q[2], 0)
    return img


def sprite(name, height):
    img = cutout(Image.open(os.path.join(SRC, name + ".png")))
    if name in HOLES:
        img = remove_grey_framed_holes(img)
    l, t, r, b = img.getbbox()
    img = img.crop((l, t, r, b))
    k = max(1, round(img.height / height))
    img = img.resize((max(1, img.width // k), max(1, img.height // k)), Image.NEAREST)
    a = img.getchannel("A").point(lambda v: 255 if v >= 128 else 0)
    img.putalpha(a)
    out = os.path.join(DST, name + ".png")
    img.save(out, optimize=True)
    print(f"{out}  {img.width}x{img.height}")


def sky():
    img = Image.open(os.path.join(SRC, "sky_1.png")).convert("RGB")
    img = img.resize((1024, round(img.height * 1024 / img.width)), Image.NEAREST)
    out = os.path.join(DST, "sky.png")
    img.save(out, optimize=True)
    print(f"{out}  {img.width}x{img.height}")


if __name__ == "__main__":
    os.makedirs(DST, exist_ok=True)
    for n, h in SPRITES.items():
        sprite(n, h)
    sky()

"""Placeholder app icon for the browser build's install-as-app (D-177).
Writes assets/textures/shell/app_icon_{512,180,144}.png: "PIN" over "GAMES"
in PinPixel, yellow with a dark outline, on a rounded dark tile with a
pink/cyan neon border. Replace with director art when there is some.
Usage: python scripts/tools/gen_app_icon.py
"""
from PIL import Image, ImageDraw, ImageFont
import os

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
FONT = os.path.join(ROOT, "assets", "fonts", "pinpixel.ttf")
OUT = os.path.join(ROOT, "assets", "textures", "shell")

S = 512
im = Image.new("RGBA", (S, S), (0, 0, 0, 0))
d = ImageDraw.Draw(im)
d.rounded_rectangle([0, 0, S - 1, S - 1], radius=96, fill=(14, 14, 24, 255))
d.rounded_rectangle([18, 18, S - 19, S - 19], radius=80, outline=(255, 60, 200, 255), width=10)
d.rounded_rectangle([36, 36, S - 37, S - 37], radius=64, outline=(60, 220, 255, 255), width=6)


def centred(text, px, y, fill):
    f = ImageFont.truetype(FONT, px)
    w = d.textlength(text, font=f)
    x = (S - w) / 2
    for dx in (-8, 0, 8):
        for dy in (-8, 0, 8):
            d.text((x + dx, y + dy), text, font=f, fill=(0, 0, 0, 255))
    d.text((x, y), text, font=f, fill=fill)


centred("PIN", 168, 96, (255, 214, 40, 255))
centred("GAMES", 108, 300, (255, 255, 255, 255))
os.makedirs(OUT, exist_ok=True)
for size in (512, 180, 144):
    im.resize((size, size), Image.NEAREST if size == 512 else Image.LANCZOS).save(
        os.path.join(OUT, "app_icon_%d.png" % size))
print("wrote", OUT)

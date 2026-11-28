"""The shell's logo (D-490): the director's VPin Games logo, cropped to its
picture and scaled for the title screens, plus the app icons made from it.
Writes assets/textures/shell/logo.png (1280 px wide) and
assets/textures/shell/app_icon_{512,180,144}.png (the logo on a dark rounded
tile), and keeps the original in assets/source/shell/.
Usage: python scripts/tools/prepare_shell_logo.py [path to vpingames.png]
"""
from PIL import Image, ImageDraw
import os
import shutil
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
SRC = sys.argv[1] if len(sys.argv) > 1 else r"C:\Users\Phoenixfox\Dev\PinGamesAssets\vpingames.png"
OUT = os.path.join(ROOT, "assets", "textures", "shell")
KEEP = os.path.join(ROOT, "assets", "source", "shell")

os.makedirs(KEEP, exist_ok=True)
shutil.copyfile(SRC, os.path.join(KEEP, "vpingames.png"))
im = Image.open(SRC).convert("RGBA")
# Crop to what is really there (the faint glow's edge counts from alpha 8).
box = im.getchannel("A").point(lambda v: 255 if v > 8 else 0).getbbox()
im = im.crop(box)
W = 1280
logo = im.resize((W, round(im.height * W / im.width)), Image.LANCZOS)
logo.save(os.path.join(OUT, "logo.png"))

S = 512
tile = Image.new("RGBA", (S, S), (0, 0, 0, 0))
ImageDraw.Draw(tile).rounded_rectangle([0, 0, S - 1, S - 1], radius=96, fill=(14, 14, 24, 255))
small = im.resize((S - 32, round(im.height * (S - 32) / im.width)), Image.LANCZOS)
tile.alpha_composite(small, (16, (S - small.height) // 2))
for size in (512, 180, 144):
    tile.resize((size, size), Image.LANCZOS).save(os.path.join(OUT, "app_icon_%d.png" % size))
print("wrote", OUT, logo.size)

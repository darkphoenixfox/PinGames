"""The roadblock barrier's plank (D-521): red and white slanted stripes, 64x16.
Writes assets/textures/racer/barrier.png (the plank's texture, and its
splinters when it breaks).
Usage: python scripts/tools/gen_barrier.py
"""
from PIL import Image
import os

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
OUT = os.path.join(ROOT, "assets", "textures", "racer", "barrier.png")
W, H, BAND = 64, 16, 8
RED = (214, 32, 28)
WHITE = (240, 238, 228)
img = Image.new("RGB", (W, H))
for y in range(H):
    for x in range(W):
        img.putpixel((x, y), RED if ((x + y) // BAND) % 2 == 0 else WHITE)
img.save(OUT)
print("wrote", OUT)

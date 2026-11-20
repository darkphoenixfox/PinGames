"""Prepares the director's circuit textures for Tilt Breaker bricks (D-045).

Copies circuit_<colour>.png (2048x2048 originals) from the asset inbox into
assets/source/breakout/ and writes 512x512 box-downsampled versions to
assets/textures/breakout/. At 512 px one brick covers ~64x31 texels, which gives
the chunky low-pixel look; the brick shader crops a random rectangle per brick.

Usage: python scripts/tools/prepare_circuit_textures.py [inbox_dir]
"""
import os
import shutil
import sys

from PIL import Image

ROOT = os.path.normpath(os.path.join(os.path.dirname(__file__), "..", ".."))
COLOURS = ["red", "yellow", "green", "blue"]
SIZE = 512


def main():
    inbox = sys.argv[1] if len(sys.argv) > 1 else r"C:\Users\Phoenixfox\Dev\PinGamesAssets"
    src_dir = os.path.join(ROOT, "assets", "source", "breakout")
    out_dir = os.path.join(ROOT, "assets", "textures", "breakout")
    os.makedirs(src_dir, exist_ok=True)
    os.makedirs(out_dir, exist_ok=True)
    for c in COLOURS:
        name = f"circuit_{c}.png"
        src = os.path.join(inbox, name)
        kept = os.path.join(src_dir, name)
        shutil.copyfile(src, kept)
        img = Image.open(kept).convert("RGB").resize((SIZE, SIZE), Image.BOX)
        img.save(os.path.join(out_dir, name), optimize=True)
        print(f"{name}: kept original, wrote {SIZE}x{SIZE}")


if __name__ == "__main__":
    main()

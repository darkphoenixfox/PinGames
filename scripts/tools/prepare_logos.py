"""Prepares a game's logos (D-063).

  <inbox>/<game_logo>.png        -> assets/textures/<game>/logo.png (picker/backglass,
                                    max 1200 px wide, alpha kept)
  <inbox>/<horizontal logo>.png  -> assets/textures/<game>/dmd_logo.png: pixel art for
                                    the DMD, trimmed, fitted to `dmd_h` dots high,
                                    saturation/contrast boosted, hard alpha
Originals are kept in assets/source/<game>/.

Usage: python scripts/tools/prepare_logos.py <inbox> <game> <logo.png> <horiz_logo.png> [dmd_h] [dmd_w]
"""
import os
import shutil
import sys

from PIL import Image, ImageEnhance, ImageFilter

ROOT = os.path.normpath(os.path.join(os.path.dirname(__file__), "..", ".."))


def main():
    inbox, game, logo_name, horiz_name = sys.argv[1:5]
    dmd_h = int(sys.argv[5]) if len(sys.argv) > 5 else 32
    dmd_w = int(sys.argv[6]) if len(sys.argv) > 6 else 128
    src_dir = os.path.join(ROOT, "assets", "source", game)
    out_dir = os.path.join(ROOT, "assets", "textures", game)
    os.makedirs(src_dir, exist_ok=True)
    os.makedirs(out_dir, exist_ok=True)
    for name in (logo_name, horiz_name):
        shutil.copyfile(os.path.join(inbox, name), os.path.join(src_dir, name))

    logo = Image.open(os.path.join(src_dir, logo_name)).convert("RGBA")
    logo = logo.crop(logo.getbbox())
    if logo.width > 1200:
        logo = logo.resize((1200, round(logo.height * 1200 / logo.width)), Image.LANCZOS)
    logo.save(os.path.join(out_dir, "logo.png"), optimize=True)

    h = Image.open(os.path.join(src_dir, horiz_name)).convert("RGBA")
    h = h.crop(h.getbbox())
    scale = min(dmd_h / h.height, dmd_w / h.width)
    size = (max(1, round(h.width * scale)), max(1, round(h.height * scale)))
    # Two-step downscale keeps strokes readable; sharpen before the final step.
    mid = h.resize((size[0] * 4, size[1] * 4), Image.LANCZOS).filter(ImageFilter.UnsharpMask(2, 120, 2))
    small = mid.resize(size, Image.LANCZOS)
    rgb = small.convert("RGB")
    rgb = ImageEnhance.Color(rgb).enhance(1.5)
    rgb = ImageEnhance.Contrast(rgb).enhance(1.35)
    rgb = ImageEnhance.Brightness(rgb).enhance(1.1)
    alpha = small.getchannel("A").point(lambda a: 255 if a > 110 else 0)
    out = rgb.convert("RGBA")
    out.putalpha(alpha)
    out.save(os.path.join(out_dir, "dmd_logo.png"), optimize=True)
    print(f"logo.png {logo.size}, dmd_logo.png {out.size}")


if __name__ == "__main__":
    main()

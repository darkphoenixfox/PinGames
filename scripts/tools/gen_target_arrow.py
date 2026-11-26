"""Turbo Run pursuit target arrow (D-464): a smooth red arrow pointing down,
with a dark outline, a lighter top face and a soft highlight. Drawn at 4x and
scaled down for clean edges. The game shows it over the speeder as the chase
starts; replace the PNG to restyle it (keep the tip at the bottom centre).
Usage: python scripts/tools/gen_target_arrow.py [out.png] [size]
"""
import sys

from PIL import Image, ImageDraw, ImageFilter

out = sys.argv[1] if len(sys.argv) > 1 else "assets/textures/racer/target_arrow.png"
size = int(sys.argv[2]) if len(sys.argv) > 2 else 128
S = size * 4
img = Image.new("RGBA", (S, S), (0, 0, 0, 0))
d = ImageDraw.Draw(img)


def arrow(scale: float, dy: float = 0.0):
    """The arrow's outline: a shaft on top, a wide head below, tip at the bottom."""
    cx = S / 2
    pts = [(-0.17, 0.04), (0.17, 0.04), (0.17, 0.42), (0.40, 0.42), (0.0, 0.94), (-0.40, 0.42), (-0.17, 0.42)]
    return [(cx + x * S * scale, (y * S - S * 0.5) * scale + S * 0.5 + dy) for x, y in pts]


# Soft shadow, outline, body, then a lighter left half and a highlight.
shadow = Image.new("RGBA", (S, S), (0, 0, 0, 0))
ImageDraw.Draw(shadow).polygon(arrow(1.0, S * 0.02), fill=(0, 0, 0, 110))
shadow = shadow.filter(ImageFilter.GaussianBlur(S * 0.02))
img.alpha_composite(shadow)
d.polygon(arrow(1.0), fill=(40, 4, 8, 255))
d.polygon(arrow(0.86), fill=(214, 22, 34, 255))
cx = S / 2
inner = arrow(0.86)
d.polygon([inner[0], (cx, inner[0][1]), (cx, inner[4][1]), inner[5], inner[6]], fill=(255, 64, 70, 255))
hl = [(cx - S * 0.12, S * 0.10), (cx - S * 0.05, S * 0.10), (cx - S * 0.05, S * 0.40), (cx - S * 0.12, S * 0.40)]
d.polygon(hl, fill=(255, 170, 170, 200))
img = img.resize((size, size), Image.LANCZOS)
img.save(out)
print(out, size)

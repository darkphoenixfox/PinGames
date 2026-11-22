"""Turbo Run REV! hint hand (D-197): a pointing hand (after the director's line
icon), pointing left, filled with the "sunset" title-font gradient and outlined
like that font, so it matches the REV! text. Drawn big, then reduced to a pixel
grid with nearest so it sits with the game's pixel HUD.
Writes assets/textures/racer/rev_hand.png.
Usage: python scripts/tools/gen_rev_hand.py
"""
import os

from PIL import Image, ImageDraw, ImageFilter

ROOT = os.path.normpath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT = os.path.join(ROOT, "assets", "textures", "racer", "rev_hand.png")

# The "sunset" title font's gradient (gen_title_fonts.py), top to bottom.
STOPS = [(0.0, (255, 255, 255)), (0.35, (255, 170, 230)), (0.5, (230, 70, 180)),
         (0.501, (40, 30, 120)), (0.7, (60, 120, 255)), (1.0, (150, 240, 255))]
OUTLINE = (10, 4, 22)
SHADE = (110, 30, 140)

W, H = 640, 400      # drawing size (pointing right, mirrored at the end)
PIX = 5              # one output pixel per PIX drawing pixels


def gradient(t):
    for (t0, c0), (t1, c1) in zip(STOPS, STOPS[1:]):
        if t <= t1:
            k = 0.0 if t1 == t0 else (t - t0) / (t1 - t0)
            return tuple(int(c0[i] + (c1[i] - c0[i]) * k) for i in range(3))
    return STOPS[-1][1]


def shape(d, fill):
    """The hand, pointing right: cuff, palm, index finger, three curled fingers, thumb."""
    d.rounded_rectangle([60, 120, 130, 330], 18, fill=fill)                 # cuff
    d.rounded_rectangle([120, 135, 360, 340], 60, fill=fill)                # palm
    d.rounded_rectangle([300, 150, 590, 215], 32, fill=fill)                # index finger
    for i, y in enumerate((215, 262, 305)):                                 # curled fingers
        d.rounded_rectangle([300, y, 410 - i * 12, y + 48], 24, fill=fill)
    d.polygon([(170, 150), (330, 60), (375, 85), (360, 140), (250, 175)], fill=fill)   # thumb
    d.ellipse([320, 45, 385, 110], fill=fill)                               # thumb tip


def main():
    mask = Image.new("L", (W, H), 0)
    shape(ImageDraw.Draw(mask), 255)
    # Outline: the mask grown; a 3D drop down-right like the title fonts.
    outline = mask.filter(ImageFilter.MaxFilter(25))
    drop = Image.new("L", (W, H), 0)
    drop.paste(mask, (12, 12))
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    img.paste(Image.new("RGBA", (W, H), OUTLINE + (255,)), (0, 0), outline)
    img.paste(Image.new("RGBA", (W, H), SHADE + (255,)), (0, 0), drop)
    top, bottom = 45, 340
    grad = Image.new("RGBA", (W, H))
    gd = ImageDraw.Draw(grad)
    for y in range(H):
        gd.line([(0, y), (W, y)], fill=gradient(min(1.0, max(0.0, (y - top) / (bottom - top)))) + (255,))
    img.paste(grad, (0, 0), mask)
    # Finger lines like the icon: dark grooves between the curled fingers.
    d = ImageDraw.Draw(img)
    for y in (215, 262, 305):
        d.line([(300, y), (395, y)], fill=OUTLINE + (255,), width=8)
    d.line([(300, 215), (590, 215)], fill=OUTLINE + (255,), width=8)
    d.line([(118, 140), (118, 330)], fill=OUTLINE + (255,), width=8)      # cuff seam
    img = img.crop(img.getbbox())
    small = img.resize((img.width // PIX, img.height // PIX), Image.NEAREST)
    small = small.transpose(Image.FLIP_LEFT_RIGHT)   # point left
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    small.save(OUT, optimize=True)
    print(OUT, small.size)


if __name__ == "__main__":
    main()

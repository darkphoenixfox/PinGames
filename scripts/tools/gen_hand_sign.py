"""Turbo Run's REV! pointing hand (D-381) from the director's painting.

Reads  assets/source/racer/hand_sign.png (2048x2048, pointing left).
Writes assets/textures/racer/rev_hand_hd.png   216x216, smooth
       assets/textures/racer/rev_hand_16.png    48x48, pixel art (16-BIT)
       assets/textures/racer/rev_hand_8.png     27x27, pixel art (8-BIT)

All three are square with the fingertip at the left edge, half-way down, and
are shown at 108x108 UI pixels. The pixel versions match the UI's own pixels
in their mode (1080 high UI drawn 480 / 270 high), so nothing resamples them:
fewer colours, a hard edge and a dark 1 px outline.
Usage: python scripts/tools/gen_hand_sign.py
"""
import os

import numpy as np
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
SRC = os.path.join(ROOT, "assets", "source", "racer", "hand_sign.png")
OUT = os.path.join(ROOT, "assets", "textures", "racer")
OUTLINE = (38, 10, 34, 255)


def cropped():
    im = Image.open(SRC).convert("RGBA")
    a = np.array(im)[..., 3] > 128
    ys, xs = np.where(a)
    x0, x1, y0, y1 = xs.min(), xs.max() + 1, ys.min(), ys.max() + 1
    # The fingertip: the opaque rows in the leftmost 3 % of the hand.
    tip_cols = a[:, x0:x0 + max(1, (x1 - x0) * 3 // 100)]
    tip_y = float(np.where(tip_cols.any(axis=1))[0].mean())
    return im.crop((x0, y0, x1, y1)), tip_y - y0


def square(size, inner, pixel, colours=0):
    """The hand `inner` px wide on a size x size canvas, fingertip at mid-height."""
    hand, tip = cropped()
    k = inner / hand.width
    h = max(1, round(hand.height * k))
    small = hand.resize((inner, h), Image.LANCZOS if not pixel else Image.BOX)
    top = round(size / 2 - tip * k)
    left = (size - inner) // 2
    out = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    if not pixel:
        out.alpha_composite(small, (left, top))
        return out
    arr = np.array(small)
    solid = arr[..., 3] >= 128
    rgb = Image.fromarray(arr[..., :3], "RGB").quantize(colours, method=Image.MEDIANCUT, dither=Image.NONE).convert("RGB")
    px = np.dstack([np.array(rgb), np.where(solid, 255, 0).astype(np.uint8)])
    px[~solid] = 0
    out.alpha_composite(Image.fromarray(px, "RGBA"), (left, top))
    # Dark outline: every clear pixel that touches the hand.
    o = np.array(out)
    s = o[..., 3] > 0
    near = np.zeros_like(s)
    near[1:, :] |= s[:-1, :]
    near[:-1, :] |= s[1:, :]
    near[:, 1:] |= s[:, :-1]
    near[:, :-1] |= s[:, 1:]
    o[near & ~s] = OUTLINE
    return Image.fromarray(o, "RGBA")


def main():
    square(216, 216, False).save(os.path.join(OUT, "rev_hand_hd.png"))
    square(48, 46, True, 20).save(os.path.join(OUT, "rev_hand_16.png"))
    square(27, 25, True, 6).save(os.path.join(OUT, "rev_hand_8.png"))
    print("wrote rev_hand_hd / _16 / _8")


if __name__ == "__main__":
    main()

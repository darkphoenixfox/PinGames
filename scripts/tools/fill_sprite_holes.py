"""Fills see-through holes inside a cut-out sprite (D-395).

Removing the white background also removed white parts of the art itself (the
snow on the snow spruce). Every clear or half-clear pixel that the outside
can't reach (enclosed by the art) becomes solid, laid over the fill colour.
The outline does not change.
--gap N also fills areas whose outline has breaks up to about 2N px wide (the
snow cap of the snowy rock was left as a thin, broken line): the outline is
thickened by N px while the outside is traced, so it can't leak in.
Usage: python scripts/tools/fill_sprite_holes.py pine_snow [--gap N]
"""
import os
import sys

import numpy as np
from PIL import Image, ImageFilter

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
DIR = os.path.join(ROOT, "assets", "sprites", "racer", "hd")


def fill(name, colour, gap=0):
    path = os.path.join(DIR, name + ".png")
    a = np.array(Image.open(path).convert("RGBA")).astype(np.float64)
    pad = gap + 3   # clear margin, so the outside is traced all the way round
    a = np.pad(a, ((pad, pad), (pad, pad), (0, 0)))
    alpha = a[..., 3]
    clear = alpha < 128
    h, w = clear.shape
    really_clear = clear
    if gap > 0:   # trace the outside past a thickened outline (faint pixels count)
        wall = np.array(Image.fromarray(((alpha >= 24) * 255).astype(np.uint8)).filter(ImageFilter.MaxFilter(2 * gap + 1))) > 0
        clear = ~wall
    outside = np.zeros_like(clear)
    stack = [(y, x) for y in range(h) for x in (0, w - 1)] + [(y, x) for x in range(w) for y in (0, h - 1)]
    while stack:
        y, x = stack.pop()
        if 0 <= y < h and 0 <= x < w and clear[y, x] and not outside[y, x]:
            outside[y, x] = True
            stack += [(y + 1, x), (y - 1, x), (y, x + 1), (y, x - 1)]
    if gap > 0:   # the outside reaches right up to the real outline
        outside = (np.array(Image.fromarray((outside * 255).astype(np.uint8)).filter(ImageFilter.MaxFilter(2 * gap + 3))) > 0) & really_clear
    # Half-clear pixels on the outline itself (next to the outside) stay as they are.
    near_out = np.array(Image.fromarray((outside * 255).astype(np.uint8)).filter(ImageFilter.MaxFilter(5))) > 0
    todo = (alpha < 255) & ~near_out
    k = (alpha / 255.0)[..., None]
    a[..., :3] = np.where(todo[..., None], a[..., :3] * k + np.array(colour) * (1.0 - k), a[..., :3])
    a[..., 3] = np.where(todo, 255.0, alpha)
    a = a[pad:-pad, pad:-pad]
    Image.fromarray(np.clip(a, 0, 255).astype(np.uint8), "RGBA").save(path)
    print(name, "pixels filled:", int(todo.sum()))


if __name__ == "__main__":
    gap = int(sys.argv[sys.argv.index("--gap") + 1]) if "--gap" in sys.argv else 0
    fill(sys.argv[1], [244.0, 248.0, 255.0], gap)

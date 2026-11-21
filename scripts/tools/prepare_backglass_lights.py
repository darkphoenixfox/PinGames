"""Prepares a lit/unlit backglass pair for in-game light effects (D-058).

Input (director's art, same framing): <name>_off.png and <name>_on.png, where
"on" has some areas lit. Output, in assets/textures/<game>/:
  backglass_off.png, backglass_on.png   1920x1080 (backglass base resolution)
  backglass_mask.png                    RGB light groups, soft-edged:
                                        R = engines, G = shots, B = impacts
  backglass_mask_logo.png               greyscale: the title logo group
                                        (separate file: never store masks in alpha)
Originals are kept in assets/source/<game>/.

Lit areas are found by differencing the two images; connected lit regions are
assigned to a group by where their centre is (tuned for Tilt Breaker's art):
  centre in the top-centre (y < 30%, 25-70% x) -> logo (title marquee)
  centre x > 66% width                      -> impacts (top-right hits/lightning)
  centre x < 25% width or y > 66% height    -> engines (exhaust flames)
  otherwise                                 -> shots (plasma comets)

Usage: python scripts/tools/prepare_backglass_lights.py <inbox_dir> <base_name> <game> [suffix]
  e.g. ... "C:/Users/Phoenixfox/Dev/PinGamesAssets" breaker_lights breakout
  The optional suffix (e.g. _2screen, D-080) reads <base>_off<suffix>.png and
  writes every output with the same suffix (backglass_off_2screen.png, ...).
  The 2-screen art is framed higher, so its engine flames sit mid-height:
  for it, regions centred below 42% height (outside the impact zone) are engines,
  and the logo zone ends at 22% height (a plasma comet sits just below it).
"""
import os
import shutil
import sys
from collections import deque

from PIL import Image, ImageChops, ImageFilter

ROOT = os.path.normpath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT_SIZE = (1920, 1080)
WORK = (640, 360)  # component analysis resolution
THRESHOLD = 30


def components(mask: Image.Image):
    w, h = mask.size
    px = mask.load()
    seen = bytearray(w * h)
    comps = []
    for y in range(h):
        for x in range(w):
            if px[x, y] == 0 or seen[y * w + x]:
                continue
            q = deque([(x, y)])
            seen[y * w + x] = 1
            pts = []
            while q:
                cx, cy = q.popleft()
                pts.append((cx, cy))
                for nx, ny in ((cx + 1, cy), (cx - 1, cy), (cx, cy + 1), (cx, cy - 1)):
                    if 0 <= nx < w and 0 <= ny < h and px[nx, ny] and not seen[ny * w + nx]:
                        seen[ny * w + nx] = 1
                        q.append((nx, ny))
            comps.append(pts)
    return comps


def group_of(cx: float, cy: float, w: int, h: int, engine_y: float = 0.66, logo_y: float = 0.3) -> int:
    if cy < logo_y * h and 0.25 * w < cx < 0.7 * w:
        return 3  # logo
    if cx > 0.66 * w:
        return 2  # impacts
    if cx < 0.25 * w or cy > engine_y * h:
        return 0  # engines
    return 1  # shots


def main():
    inbox, base, game = sys.argv[1], sys.argv[2], sys.argv[3]
    suffix = sys.argv[4] if len(sys.argv) > 4 else ""
    engine_y = 0.42 if suffix == "_2screen" else 0.66
    logo_y = 0.22 if suffix == "_2screen" else 0.3
    src_dir = os.path.join(ROOT, "assets", "source", game)
    out_dir = os.path.join(ROOT, "assets", "textures", game)
    os.makedirs(src_dir, exist_ok=True)
    os.makedirs(out_dir, exist_ok=True)
    imgs = {}
    for state in ("off", "on"):
        name = f"{base}_{state}{suffix}.png"
        kept = os.path.join(src_dir, name)
        shutil.copyfile(os.path.join(inbox, name), kept)
        img = Image.open(kept).convert("RGB").resize(OUT_SIZE, Image.LANCZOS)
        img.save(os.path.join(out_dir, f"backglass_{state}{suffix}.png"), optimize=True)
        imgs[state] = img
    diff = ImageChops.difference(imgs["off"].resize(WORK), imgs["on"].resize(WORK)).convert("L")
    lit = diff.point(lambda v: 255 if v > THRESHOLD else 0).filter(ImageFilter.MaxFilter(3))
    groups = [Image.new("L", WORK, 0) for _ in range(4)]
    gpx = [g.load() for g in groups]
    counts = [0, 0, 0, 0]
    for pts in components(lit):
        if len(pts) < 6:
            continue
        cx = sum(p[0] for p in pts) / len(pts)
        cy = sum(p[1] for p in pts) / len(pts)
        g = group_of(cx, cy, *WORK, engine_y, logo_y)
        counts[g] += 1
        for x, y in pts:
            # A comet touching the logo joins its region: split it off by height.
            gpx[1 if g == 3 and y > logo_y * WORK[1] else g][x, y] = 255
    channels = [g.resize(OUT_SIZE, Image.BILINEAR).filter(ImageFilter.MaxFilter(5)).filter(ImageFilter.GaussianBlur(6))
                for g in groups]
    Image.merge("RGB", channels[:3]).save(os.path.join(out_dir, f"backglass_mask{suffix}.png"), optimize=True)
    channels[3].save(os.path.join(out_dir, f"backglass_mask_logo{suffix}.png"), optimize=True)
    print(f"regions: engines={counts[0]} shots={counts[1]} impacts={counts[2]} logo={counts[3]}")


if __name__ == "__main__":
    main()

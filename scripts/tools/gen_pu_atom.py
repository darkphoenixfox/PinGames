"""Draws the Nuclear power-up's atom symbol (D-326): three orbits at 0/60/120
degrees and a nucleus, white with a dark rim, 64x64 pixel art.
Writes assets/textures/breakout/pu_atom.png. Run from the repo root."""
import math
from PIL import Image, ImageFilter

N = 64
im = Image.new("L", (N, N), 0)
px = im.load()
c = N / 2 - 0.5
for rot in (0, 60, 120):
    r = math.radians(rot)
    for i in range(2000):
        t = 2 * math.pi * i / 2000
        x, y = 26 * math.cos(t), 9.5 * math.sin(t)
        X = c + x * math.cos(r) - y * math.sin(r)
        Y = c + x * math.sin(r) + y * math.cos(r)
        for dx, dy in ((0, 0), (1, 0), (-1, 0), (0, 1), (0, -1)):
            xi, yi = int(round(X)) + dx, int(round(Y)) + dy
            if 0 <= xi < N and 0 <= yi < N:
                px[xi, yi] = 255
for x in range(N):
    for y in range(N):
        if (x - c) ** 2 + (y - c) ** 2 <= 5.2 ** 2:
            px[x, y] = 255
rim = im.filter(ImageFilter.MaxFilter(5))
out = Image.new("RGBA", (N, N), (0, 0, 0, 0))
op, a, o = out.load(), im.load(), rim.load()
for x in range(N):
    for y in range(N):
        if a[x, y]:
            op[x, y] = (255, 255, 255, 255)
        elif o[x, y]:
            op[x, y] = (10, 10, 20, 200)
out.save("assets/textures/breakout/pu_atom.png")

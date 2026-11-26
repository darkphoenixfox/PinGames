"""Turbo Run helicopter rotor (D-436): a round, mostly transparent picture of
two blades turning fast, motion-blurred into a disc. Each blade is a dark
streak that trails off behind it (counter-clockwise turning), over a faint
disc, with a dark hub. The game spins it on the rotor hubs.
Usage: python scripts/tools/gen_rotor_blur.py [out.png] [size]
"""
import math
import sys

from PIL import Image

out = sys.argv[1] if len(sys.argv) > 1 else "assets/textures/racer/rotor_blur.png"
size = int(sys.argv[2]) if len(sys.argv) > 2 else 256
BLADES = 2
TRAIL = 0.9          # radians a blade's blur trails behind it
COLOR = (38, 40, 46)
img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
px = img.load()
c = (size - 1) / 2.0
for y in range(size):
    for x in range(size):
        dx = (x - c) / c
        dy = (y - c) / c
        r = math.hypot(dx, dy)
        if r > 1.0:
            continue
        a = math.atan2(dy, dx)
        blade = 0.0
        for b in range(BLADES):
            # Angle behind blade b, 0..2pi (the blade leads, its blur follows).
            d = (a - b * 2.0 * math.pi / BLADES) % (2.0 * math.pi)
            blade = max(blade, math.exp(-d / TRAIL) * (1.0 if d > 0.02 else 1.0))
        # Blades thin out towards the tip; a faint disc everywhere.
        reach = min(1.0, max(0.0, (r - 0.1) / 0.1)) * min(1.0, (1.0 - r) / 0.06)
        alpha = (0.10 + 0.55 * blade * (1.0 - 0.35 * r)) * reach
        if r < 0.09:
            alpha = 0.95   # the hub
        px[x, y] = COLOR + (int(max(0.0, min(1.0, alpha)) * 255),)
img.save(out)
print(out, size)

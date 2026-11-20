"""Generates Tilt Breaker brick textures: 16-bit style circuit boards / chips for the
sentient nanomachine swarm (D-041). In-house procedural art, no licensing.

Output (64x32 each), in assets/textures/breakout/bricks/:
  <family>_<variant>.png       opaque RGB albedo (limited palette, bevelled edges,
                               traces, pads, IC chips, LEDs)
  <family>_<variant>_glow.png  greyscale glow mask for the brick shader
                               (LED/eye = 255, traces ~70, rest dark).
The mask is a separate file on purpose: Godot's "fix alpha border" import step
bleeds colour into low-alpha pixels, so masks must never live in alpha.

Usage: python scripts/tools/gen_circuit_bricks.py [variants_per_family]
"""
import os
import random
import sys

from PIL import Image

W, H = 64, 32
OUT = os.path.join(os.path.dirname(__file__), "..", "..", "assets", "textures", "breakout", "bricks")
FAMILIES = {  # must match ROW_COLORS order in games/breakout/game.gd
    "crimson": (0xFF, 0x4F, 0x6D),
    "amber": (0xFF, 0x9A, 0x3E),
    "gold": (0xFF, 0xD2, 0x3E),
    "verdant": (0x4F, 0xFF, 0x7A),
    "azure": (0x3E, 0xC7, 0xFF),
    "violet": (0xB3, 0x6B, 0xFF),
}
SUBSTRATE = (16, 20, 30)
PAD = (214, 172, 74)
PAD_HI = (255, 230, 150)
CHIP = (22, 22, 28)
CHIP_HI = (52, 54, 66)
PIN = (160, 164, 176)
BASE_A, TRACE_A, LED_A = 6, 70, 255


def mix(a, b, t):
    return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(3))


def shade(c, k):
    return tuple(max(0, min(255, int(v * k))) for v in c)


def gen(fam_rgb, seed):
    rnd = random.Random(seed)
    img = Image.new("RGBA", (W, H))
    px = img.load()
    base = mix(SUBSTRATE, fam_rgb, 0.22)
    base2 = mix(SUBSTRATE, fam_rgb, 0.30)
    for y in range(H):
        for x in range(W):
            # 16-bit style ordered dither in diagonal bands
            c = base2 if ((x + y) % 4 == 0 and (x // 8 + y // 8) % 2 == 0) else base
            px[x, y] = (*c, BASE_A)

    def put(x, y, c, a):
        if 2 <= x < W - 2 and 2 <= y < H - 2:
            px[x, y] = (*c, a)

    trace = shade(fam_rgb, 0.62)
    trace_hi = mix(fam_rgb, (255, 255, 255), 0.25)
    occupied = set()

    # Traces: orthogonal random walks ending in gold pads.
    for _ in range(rnd.randint(6, 9)):
        x, y = rnd.randrange(4, W - 4, 2), rnd.randrange(4, H - 4, 2)
        dx, dy = rnd.choice([(1, 0), (-1, 0), (0, 1), (0, -1)])
        path = []
        for _step in range(rnd.randint(8, 22)):
            path.append((x, y))
            if rnd.random() < 0.18:
                dx, dy = (dy, dx) if rnd.random() < 0.5 else (-dy, -dx)
            nx, ny = x + dx, y + dy
            if not (3 <= nx < W - 3 and 3 <= ny < H - 3):
                break
            x, y = nx, ny
        for i, (tx, ty) in enumerate(path):
            put(tx, ty, trace_hi if i % 5 == 0 else trace, TRACE_A)
            occupied.add((tx, ty))
        for (ex, ey) in (path[0], path[-1]):
            for ox, oy in ((0, 0), (1, 0), (0, 1), (1, 1)):
                put(ex + ox, ey + oy, PAD_HI if (ox, oy) == (0, 0) else PAD, 40)

    # IC chips with pins and a glowing "eye" (the sentient core).
    eye = mix(fam_rgb, (255, 255, 255), 0.55)
    chips = []
    for _ in range(rnd.choice([1, 1, 2])):
        for _try in range(30):  # keep chips (incl. pins) apart
            cw, ch = rnd.randint(12, 18), rnd.randint(7, 10)
            cx, cy = rnd.randint(5, W - cw - 5), rnd.randint(5, H - ch - 5)
            if all(cx + cw + 2 < ox or ox + ow + 2 < cx or cy + ch + 2 < oy or oy + oh + 2 < cy
                   for ox, oy, ow, oh in chips):
                break
        else:
            continue
        chips.append((cx, cy, cw, ch))
        for y in range(cy, cy + ch):
            for x in range(cx, cx + cw):
                put(x, y, CHIP_HI if y == cy else CHIP, BASE_A)
        for x in range(cx + 1, cx + cw - 1, 2):  # pins top/bottom
            put(x, cy - 1, PIN, BASE_A)
            put(x, cy + ch, PIN, BASE_A)
        put(cx + 1, cy + 1, PIN, BASE_A)  # orientation notch
        ex, ey = cx + cw // 2 - 1, cy + ch // 2 - 1
        for ox, oy in ((0, 0), (1, 0), (0, 1), (1, 1)):
            put(ex + ox, ey + oy, eye if (ox, oy) != (0, 0) else (255, 255, 255), LED_A)
        for x in range(cx + 3, cx + cw - 3):  # faint die markings
            if rnd.random() < 0.35:
                put(x, cy + ch - 2, CHIP_HI, BASE_A)

    # Loose LEDs
    for _ in range(rnd.randint(2, 4)):
        lx, ly = rnd.randint(4, W - 5), rnd.randint(4, H - 5)
        put(lx, ly, eye, LED_A)

    # Bevel: light top/left, dark bottom/right (classic 16-bit block)
    light, mid, dark, darker = shade(fam_rgb, 1.0), shade(fam_rgb, 0.75), shade(fam_rgb, 0.4), shade(fam_rgb, 0.25)
    for x in range(W):
        px[x, 0] = (*light, 30)
        px[x, 1] = (*mid, BASE_A)
        px[x, H - 1] = (*darker, BASE_A)
        px[x, H - 2] = (*dark, BASE_A)
    for y in range(H):
        px[0, y] = (*light, 30)
        px[1, y] = (*mid, BASE_A)
        px[W - 1, y] = (*darker, BASE_A)
        px[W - 2, y] = (*dark, BASE_A)
    return img


def main():
    variants = int(sys.argv[1]) if len(sys.argv) > 1 else 4
    os.makedirs(OUT, exist_ok=True)
    for fi, (name, rgb) in enumerate(FAMILIES.items()):
        for v in range(variants):
            img = gen(rgb, seed=fi * 1000 + v)
            img.convert("RGB").save(os.path.join(OUT, f"{name}_{v}.png"))
            img.getchannel("A").save(os.path.join(OUT, f"{name}_{v}_glow.png"))
    print(f"wrote {len(FAMILIES) * variants} albedo + glow pairs to {os.path.normpath(OUT)}")


if __name__ == "__main__":
    main()

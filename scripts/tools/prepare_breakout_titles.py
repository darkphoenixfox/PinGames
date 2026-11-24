"""Tilt Breaker's title art (D-348, D-349): trims the director's READY!,
GAME OVER, PRESS START and EASY/NORMAL/HARD images (D-350) to their opaque area (plus a margin) and
scales them to 1200 px wide.
Sources: assets/source/breakout/{ready,game_over,press_start,easy,normal,hard}.png
-> assets/textures/breakout/{same names}."""
from PIL import Image

for name in ("ready", "game_over", "press_start", "easy", "normal", "hard"):
    im = Image.open(f"assets/source/breakout/{name}.png").convert("RGBA")
    bb = im.getchannel("A").point(lambda v: 255 if v > 8 else 0).getbbox()
    m = 16
    im = im.crop((max(0, bb[0] - m), max(0, bb[1] - m), min(im.width, bb[2] + m), min(im.height, bb[3] + m)))
    w = 1200
    im = im.resize((w, round(im.height * w / im.width)), Image.LANCZOS)
    im.save(f"assets/textures/breakout/{name}.png", optimize=True)
    print(name, im.size)

"""The Android TV banner (D-515): the shell's logo on the app icon's dark tile,
320x180 (what Android TV asks for, as an xhdpi drawable).
Writes scripts/android/res/drawable-xhdpi/tv_banner.png, which
scripts/build_android.ps1 copies into the Android build template.
Usage: python scripts/tools/prepare_tv_banner.py
"""
from PIL import Image
import os

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
LOGO = os.path.join(ROOT, "assets", "textures", "shell", "logo.png")
OUT = os.path.join(ROOT, "scripts", "android", "res", "drawable-xhdpi")
SIZE = (320, 180)
PAD = 8

os.makedirs(OUT, exist_ok=True)
logo = Image.open(LOGO).convert("RGBA")
k = min((SIZE[0] - PAD * 2) / logo.width, (SIZE[1] - PAD * 2) / logo.height)
logo = logo.resize((round(logo.width * k), round(logo.height * k)), Image.LANCZOS)
banner = Image.new("RGBA", SIZE, (14, 14, 24, 255))
banner.alpha_composite(logo, ((SIZE[0] - logo.width) // 2, (SIZE[1] - logo.height) // 2))
banner.convert("RGB").save(os.path.join(OUT, "tv_banner.png"))
print("wrote", os.path.join(OUT, "tv_banner.png"))

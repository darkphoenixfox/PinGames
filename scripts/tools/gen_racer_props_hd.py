"""Turbo Run roadside props, painted HD versions (D-196): plants and signs in a
clean hand-painted style (not pixel art), on white for the cut-out. Writes
candidates to assets/source/racer/gen_hd/<name>_<n>.png with the local
ComfyUI's Qwen-Image 2.1 (approved, D-035) through comfy_qwen.py.
Usage: python scripts/tools/gen_racer_props_hd.py [name ...] [--n 2]
"""
import os
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "..", "..", "assets", "source", "racer", "gen_hd")

STYLE = ("detailed hand-painted 2D game art, smooth painterly shading, clean crisp edges, high resolution, "
         "isolated single object centered on a plain pure white background, whole object in frame, front view, "
         "no ground, no shadow on the background")
NEG = ("pixel art, pixelated, 8-bit, 16-bit, low resolution, blurry, photo, photograph, text, letters, words, numbers, "
       "watermark, signature, landscape, scenery, sky, grass field, road")

PROPS = {
    "palm_1": ("a tall tropical coconut palm tree with a gently curved trunk and a lush crown of green fronds", 768, 1024),
    "palm_2": ("a tall slender palm tree with a straight thin ringed trunk and a fan of fronds at the top", 768, 1024),
    "bush_1": ("a round dense green flowering shrub with a few small pink flowers", 1024, 768),
    "bush_2": ("a long low wide hedge of lush tropical fern bushes", 1024, 768),
    "sign_curve": ("a yellow diamond-shaped road warning sign with a bold black arrow curving to the right, "
                   "on a single grey metal pole", 768, 1024),
    "sign_green": ("a wide rectangular green highway direction sign with a white border and two white arrows "
                   "pointing down and to the left, on two grey metal posts, no text", 1024, 768),
    "gantry": ("an overhead highway sign gantry: a grey steel truss beam on two tall steel posts holding two "
               "square green highway signs, each with a white arrow pointing up, no text", 1024, 768),
}


def main():
    names = [a for a in sys.argv[1:] if not a.startswith("--") and not a.isdigit()]
    n = int(sys.argv[sys.argv.index("--n") + 1]) if "--n" in sys.argv else 2
    os.makedirs(OUT, exist_ok=True)
    for name in names or list(PROPS):
        desc, w, h = PROPS[name]
        for i in range(1, n + 1):
            out = os.path.join(OUT, f"{name}_{i}.png")
            subprocess.run([sys.executable, os.path.join(HERE, "comfy_qwen.py"), f"{desc}. {STYLE}", out,
                            "--w", str(w), "--h", str(h), "--neg", NEG], check=True)


if __name__ == "__main__":
    main()

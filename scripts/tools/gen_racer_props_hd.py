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
    # Beach stage (D-204): small buildings along the road, a lifeguard tower on the sand.
    "house_1": ("a small pastel blue single-storey beach house with a flat roof, a wooden porch and white "
                "window frames, seen from the front", 1024, 768),
    "house_2": ("a small pastel pink and white two-storey beach villa with a red tiled roof and a balcony, "
                "seen from the front", 1024, 768),
    "house_3": ("a small colourful wooden surf shop shack with surfboards leaning against the front wall and a "
                "striped awning, no text, seen from the front", 1024, 768),
    "lifeguard": ("a wooden lifeguard tower on tall stilts with a small hut, red and white, a ramp up to it, "
                  "seen from the front", 768, 1024),
    # Grass-fields stage 2 trees (D-204): instead of palms.
    "tree_oak": ("a big round leafy green deciduous oak tree with a thick brown trunk and a full rounded crown", 768, 1024),
    "tree_cypress": ("a tall slim dark green italian cypress tree, narrow and pointed, with a short trunk", 768, 1024),
    # Areas (D-216): desert, forest, snowy mountain.
    "cactus_1": ("a tall green saguaro cactus with two upturned arms", 768, 1024),
    "cactus_2": ("a wide clump of prickly pear cactus with flat round green pads and a few yellow flowers", 1024, 768),
    "desert_bush": ("a dry round desert shrub, tangled pale brown twigs with a few grey-green leaves", 1024, 768),
    "mesa": ("a tall red sandstone desert butte rock formation with flat top and steep layered cliffs", 1024, 1024),
    "pine_1": ("a tall slender dark green pine tree with a straight brown trunk, branches only on the upper half", 768, 1024),
    "pine_2": ("a full dense conical dark green spruce fir tree reaching the ground", 768, 1024),
    "fern": ("a lush low clump of green forest ferns", 1024, 768),
    "pine_snow": ("a conical dark green spruce tree heavily covered with white snow on its branches", 768, 1024),
    "snow_rock": ("a large grey granite boulder with thick white snow on top", 1024, 768),
    # Finish town (D-229): a small snowy mountain town and the spectators.
    "chalet_1": ("a small wooden alpine chalet house with a steep roof covered in thick snow, warm lit windows, "
                 "seen from the front", 1024, 768),
    "chalet_2": ("a two-storey alpine mountain house with white walls, dark wooden balconies and a snowy roof, "
                 "seen from the front", 1024, 768),
    "townhouse": ("a narrow tall old european town house with a pastel facade, shop on the ground floor and a "
                  "snowy roof, seen from the front, no text", 768, 1024),
    "crowd_1": ("a small group of five cheering spectators in colourful winter jackets and hats, waving and "
                "raising their arms, full bodies, standing side by side, seen from the front", 1024, 768),
    "crowd_2": ("a group of four excited racing fans in winter coats and scarves waving a checkered flag and "
                "clapping, full bodies, seen from the front", 1024, 768),
    "crowd_3": ("a family of spectators in warm winter clothes cheering, a child on a parent's shoulders, full "
                "bodies, seen from the front", 1024, 768),
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

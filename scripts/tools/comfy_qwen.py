"""Generate one image with the local ComfyUI's Qwen-Image 2.1 (approved model, D-035).

Usage:
  python scripts/tools/comfy_qwen.py "<prompt>" <out.png> [--w 1024] [--h 1024]
         [--seed N] [--steps 25] [--ref ref.png] [--neg "<negative>"]

- `--ref` passes a reference image to the text encoder (style/content guide).
- Talks to http://127.0.0.1:8188 (queue, poll history, download the result).
- Prints the seed so a good result can be reproduced; record model + prompt in
  assets/CREDITS.md for anything that ships.
"""
import argparse
import json
import random
import time
import urllib.request
import uuid

HOST = "http://127.0.0.1:8188"


def _post(path, data, ctype="application/json"):
    req = urllib.request.Request(HOST + path, data=data, headers={"Content-Type": ctype})
    with urllib.request.urlopen(req, timeout=60) as r:
        return json.loads(r.read())


def _get(path):
    with urllib.request.urlopen(HOST + path, timeout=60) as r:
        return r.read()


def upload(path):
    boundary = uuid.uuid4().hex
    name = "pg_ref_" + uuid.uuid4().hex[:8] + ".png"
    with open(path, "rb") as f:
        body = (f"--{boundary}\r\nContent-Disposition: form-data; name=\"image\"; filename=\"{name}\"\r\n"
                f"Content-Type: image/png\r\n\r\n").encode() + f.read() + f"\r\n--{boundary}--\r\n".encode()
    res = _post("/upload/image", body, "multipart/form-data; boundary=" + boundary)
    return res["name"]


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("prompt")
    ap.add_argument("out")
    ap.add_argument("--w", type=int, default=1024)
    ap.add_argument("--h", type=int, default=1024)
    ap.add_argument("--seed", type=int, default=None)
    ap.add_argument("--steps", type=int, default=25)
    ap.add_argument("--ref", default=None)
    ap.add_argument("--neg", default="blurry, photo, realistic, 3d render, text, letters, words, watermark, signature")
    a = ap.parse_args()
    seed = a.seed if a.seed is not None else random.randint(1, 2**48)
    enc = {"clip": ["3", 0], "prompt": a.prompt, "negative_prompt": a.neg, "resolution": 1024}
    g = {
        "1": {"class_type": "UNETLoader", "inputs": {"unet_name": "qwen_image_2.1_int8_convrot.safetensors", "weight_dtype": "default"}},
        "2": {"class_type": "QwenImage21Cache", "inputs": {"model": ["1", 0], "device": "auto", "dtype": "default"}},
        "3": {"class_type": "CLIPLoader", "inputs": {"clip_name": "qwen3vl_8b_int8_convrot.safetensors", "type": "qwen_image", "device": "default"}},
        "4": {"class_type": "VAELoader", "inputs": {"vae_name": "qwen_image_2.1_vae_bf16.safetensors"}},
        "5": {"class_type": "TextEncodeQwenImage21", "inputs": enc},
        "6": {"class_type": "EmptyLatentImage", "inputs": {"width": a.w, "height": a.h, "batch_size": 1}},
        "7": {"class_type": "KSampler", "inputs": {"model": ["2", 0], "positive": ["5", 0], "negative": ["5", 1],
              "latent_image": ["6", 0], "seed": seed, "steps": a.steps, "cfg": 1.0,
              "sampler_name": "euler", "scheduler": "simple", "denoise": 1.0}},
        "8": {"class_type": "VAEDecode", "inputs": {"samples": ["7", 0], "vae": ["4", 0]}},
        "9": {"class_type": "SaveImage", "inputs": {"images": ["8", 0], "filename_prefix": "pingames"}},
    }
    if a.ref:
        g["10"] = {"class_type": "LoadImage", "inputs": {"image": upload(a.ref)}}
        enc["images.image_1"] = ["10", 0]
    pid = _post("/prompt", json.dumps({"prompt": g, "client_id": uuid.uuid4().hex}).encode())["prompt_id"]
    while True:
        time.sleep(2)
        h = json.loads(_get("/history/" + pid))
        if pid in h:
            st = h[pid].get("status", {})
            if st.get("status_str") == "error":
                raise SystemExit("ComfyUI error: " + json.dumps(st)[:2000])
            outs = h[pid]["outputs"].get("9", {}).get("images", [])
            if outs:
                im = outs[0]
                data = _get(f"/view?filename={im['filename']}&subfolder={im['subfolder']}&type={im['type']}")
                with open(a.out, "wb") as f:
                    f.write(data)
                print("seed", seed, "->", a.out)
                return


if __name__ == "__main__":
    main()

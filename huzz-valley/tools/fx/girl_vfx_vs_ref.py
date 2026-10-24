"""The girls' effects next to the references, same size and framing (cropped to the character, 16:9 each).

Top row: the pro references (design/vfx/vysvex-green-reference.mp4 twice, the owner's violet ref3, and the other
game's Soul Reaper stand when its upload is there). Bottom row: ours from docs/previews/girl-vfx.mp4
(tools/preview/motion3d/girl_vfx_scene.luau). Writes docs/previews/girl-vfx-vs-ref.jpg.
Usage (from huzz-valley/): python3 tools/fx/girl_vfx_vs_ref.py
"""
import os
import subprocess
import tempfile

from PIL import Image, ImageDraw, ImageFont

W, H = 480, 270
SOUL = "/mnt/project-files/uploads/hearth/d5670b97-ca8f-4243-962f-d6ae3b0a782e"
# (file, second, crop x, y, w, h in the file's pixels, label)
TOP = [
    ("design/vfx/vysvex-green-reference.mp4", 5.9, 192, 110, 640, 360, "VysVEX: layered swirl hugging the body"),
    ("design/vfx/vysvex-green-reference.mp4", 9.1, 192, 150, 640, 360, "VysVEX: ground impact, dark flecks"),
    ("design/vfx/ref3/vfx-reference-oct17.mp4", 3.5, 60, 200, 640, 360, "ref3: glow at the body, slash"),
    (SOUL, 5.0, 560, 250, 1280, 720, "Soul Reaper stand (other game)"),
]
OURS = "docs/previews/girl-vfx.mp4"
BOTTOM = [
    (OURS, 14.0, 50, 40, 900, 506, "Ours: Legendary idle (Yuno)"),
    (OURS, 16.05, 50, 40, 900, 506, "Ours: Mythic walking (Megumin)"),
    (OURS, 24.0, 50, 40, 900, 506, "Ours: Secret idle (C.C.)"),
    (OURS, 30.5, 32, 36, 960, 540, "Ours: Secret prize, her level"),
]


def grab(path, t, x, y, w, h, tmp):
    out = os.path.join(tmp, f"{abs(hash((path, t)))}.png")
    subprocess.run(["ffmpeg", "-v", "error", "-y", "-ss", str(t), "-i", path, "-frames:v", "1",
                    "-vf", f"crop={w}:{h}:{x}:{y},scale={W}:{H}", out], check=True)
    return Image.open(out).convert("RGB")


def main():
    font = None
    for f in ("/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf",):
        if os.path.exists(f):
            font = ImageFont.truetype(f, 15)
    font = font or ImageFont.load_default()
    sheet = Image.new("RGB", (W * 4, H * 2), "#111")
    with tempfile.TemporaryDirectory() as tmp:
        for row, items in enumerate((TOP, BOTTOM)):
            for col, (path, t, x, y, w, h, label) in enumerate(items):
                if not os.path.exists(path):
                    continue
                img = grab(path, t, x, y, w, h, tmp)
                d = ImageDraw.Draw(img)
                d.rectangle([0, 0, W, 24], fill=(0, 0, 0))
                d.text((8, 4), label, fill=(255, 255, 255), font=font)
                sheet.paste(img, (col * W, row * H))
    sheet.save("docs/previews/girl-vfx-vs-ref.jpg", quality=88)
    print("docs/previews/girl-vfx-vs-ref.jpg")


if __name__ == "__main__":
    main()

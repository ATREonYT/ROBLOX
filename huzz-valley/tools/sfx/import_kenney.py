"""Copies the 4 picked Kenney "Interface Sounds" (CC0) into assets/sfx as mono OGG, sound unchanged, and makes the
listening file docs/previews/ui-sounds-oct19.ogg (click x3, hover x2, open, close, at the in-game levels of
Gameplay/Sfx LEVEL). Why these 4: docs/sound-picks.md section 2.

    git clone --depth 1 https://github.com/Calinou/kenney-interface-sounds /tmp/kenney
    python3 -I tools/sfx/import_kenney.py /tmp/kenney/addons/kenney_interface_sounds     (from huzz-valley/)

Mono is the AVERAGE of the two channels (pan 0.5 + 0.5). Oct 19 audit: the first copies were made with ffmpeg's
plain "-ac 1", which mixes stereo down 3 dB louder, so ui_click and ui_hover peaked at +2 dBFS and clipped (Kenney's
own files peak at -1 dBFS). Needs ffmpeg with libvorbis.
"""
import os
import subprocess
import sys

PICKS = {"ui_click": "drop_002", "ui_hover": "select_002", "ui_open": "maximize_009", "ui_close": "minimize_009"}
LEVEL = {"ui_click": 0.28, "ui_hover": 0.10, "ui_open": 0.15, "ui_close": 0.13}  # Gameplay/Sfx LEVEL
# the listening order: (slot, seconds of silence after it)
PREVIEW = [("ui_click", 0.5), ("ui_click", 0.5), ("ui_click", 0.8), ("ui_hover", 0.4), ("ui_hover", 0.8),
           ("ui_open", 0.8), ("ui_close", 0.8)]


def run(args):
    subprocess.run(args, check=True, capture_output=True)


def main():
    src = sys.argv[1]
    here = os.path.dirname(os.path.abspath(__file__))
    game = os.path.dirname(os.path.dirname(here))
    out = os.path.join(game, "assets", "sfx")
    for slot, name in PICKS.items():
        wav = os.path.join(src, name + ".wav")
        # "pan" averages the channels of a stereo file (a mono file passes through unchanged)
        run(["ffmpeg", "-y", "-loglevel", "error", "-i", wav, "-af", "pan=mono|c0=0.5*c0+0.5*c1" if stereo(wav) else "anull",
             "-ac", "1", "-c:a", "libvorbis", "-q:a", "4", os.path.join(out, slot + ".ogg")])
        print("wrote", slot, "from", name)
    # the listening file: each sound at its in-game level, then a gap
    inputs, parts = [], []
    for i, (slot, gap) in enumerate(PREVIEW):
        inputs += ["-i", os.path.join(out, slot + ".ogg")]
        parts.append(f"[{i}:a]volume={LEVEL[slot]},apad=pad_dur={gap}[a{i}]")
    graph = ";".join(parts) + ";" + "".join(f"[a{i}]" for i in range(len(PREVIEW))) + f"concat=n={len(PREVIEW)}:v=0:a=1[o]"
    preview = os.path.join(game, "docs", "previews", "ui-sounds-oct19.ogg")
    run(["ffmpeg", "-y", "-loglevel", "error", *inputs, "-filter_complex", graph, "-map", "[o]", "-c:a", "libvorbis",
         "-q:a", "4", preview])
    print("wrote", preview)


def stereo(path):
    r = subprocess.run(["ffprobe", "-v", "error", "-show_entries", "stream=channels", "-of", "csv=p=0", path],
                       capture_output=True, text=True)
    return r.stdout.strip() == "2"


if __name__ == "__main__":
    main()

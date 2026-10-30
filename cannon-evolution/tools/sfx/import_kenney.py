"""Copies the picked Kenney "Interface Sounds" (CC0) into cannon-evolution/assets/sfx as mono OGG, sound unchanged,
and makes the listening file previews/ui-sounds.ogg (each sound at its in-game level from GameClient/Sfx LEVEL).

    git clone --depth 1 https://github.com/Calinou/kenney-interface-sounds /tmp/kenney
    python3 -I cannon-evolution/tools/sfx/import_kenney.py /tmp/kenney/addons/kenney_interface_sounds

Why these files (measured with huzz-valley/tools/sfx/measure_sfx.py, the same rules the owner approved for Huzz
Valley's buttons: short, soft front, mid pitch, almost nothing above 4 kHz):
  Click   drop_002          83 ms, centroid  817 Hz, 0% hiss  (the Huzz Valley click)
  Hover   select_002        45 ms, centroid 1164 Hz, 2% hiss  (the same voice, very quiet)
  Open    maximize_009     205 ms, a soft swell rising        (positive = up)
  Close   minimize_009     206 ms, the same swell falling     (its mirror)
  Confirm confirmation_001 284 ms, centroid  660 Hz, 0% hiss  (buy / claim / equip: warm two-note "yes")
  Error   error_007        194 ms, centroid  446 Hz, 2% hiss  (can't afford: low and soft, never a buzzer)
  Tab     switch_002       135 ms, centroid  972 Hz, 1% hiss  (tabs and toggles)
Rejected: confirmation_002/003 (16-48% hiss), error_001/002 (27-51% hiss, harsh), toggle_00x (16-72% hiss).
Mono is the AVERAGE of the two channels, so nothing clips. Needs ffmpeg with libvorbis.
"""
import os
import subprocess
import sys

PICKS = {
    "Click": "drop_002",
    "Hover": "select_002",
    "Open": "maximize_009",
    "Close": "minimize_009",
    "Confirm": "confirmation_001",
    "Error": "error_007",
    "Tab": "switch_002",
}
# GameClient/Sfx LEVEL (keep in step)
LEVEL = {"Click": 0.3, "Hover": 0.1, "Open": 0.16, "Close": 0.14, "Confirm": 0.3, "Error": 0.3, "Tab": 0.25}
PREVIEW = [("Hover", 0.3), ("Click", 0.5), ("Open", 0.7), ("Tab", 0.4), ("Tab", 0.6), ("Confirm", 0.8),
           ("Error", 0.8), ("Close", 0.8)]


def run(args):
    subprocess.run(args, check=True, capture_output=True)


def stereo(path):
    r = subprocess.run(["ffprobe", "-v", "error", "-show_entries", "stream=channels", "-of", "csv=p=0", path],
                       capture_output=True, text=True)
    return r.stdout.strip() == "2"


def main():
    src = sys.argv[1]
    game = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
    out = os.path.join(game, "assets", "sfx")
    os.makedirs(out, exist_ok=True)
    for slot, name in PICKS.items():
        wav = os.path.join(src, name + ".wav")
        run(["ffmpeg", "-y", "-loglevel", "error", "-i", wav, "-af", "pan=mono|c0=0.5*c0+0.5*c1" if stereo(wav) else "anull",
             "-ac", "1", "-c:a", "libvorbis", "-q:a", "4", os.path.join(out, "UI_" + slot + ".ogg")])
        print("wrote UI_" + slot, "from", name)
    inputs, parts = [], []
    for i, (slot, gap) in enumerate(PREVIEW):
        inputs += ["-i", os.path.join(out, "UI_" + slot + ".ogg")]
        parts.append(f"[{i}:a]volume={LEVEL[slot]},apad=pad_dur={gap}[a{i}]")
    graph = ";".join(parts) + ";" + "".join(f"[a{i}]" for i in range(len(PREVIEW))) + f"concat=n={len(PREVIEW)}:v=0:a=1[o]"
    preview = os.path.join(game, "previews", "ui-sounds.ogg")
    run(["ffmpeg", "-y", "-loglevel", "error", *inputs, "-filter_complex", graph, "-map", "[o]", "-c:a", "libvorbis",
         "-q:a", "4", preview])
    print("wrote", preview)


if __name__ == "__main__":
    main()

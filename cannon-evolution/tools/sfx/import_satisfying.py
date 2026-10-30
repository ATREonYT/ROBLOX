"""The "satisfying" sound set (Alex, Oct 30: "make all of the sounds satisfying, right now they are mid, search the
internet for smooth sort of asmr sounds"). Copies the picked files into cannon-evolution/assets/sfx as mono OGG,
sound unchanged, and writes two listening files:
  previews/sounds-satisfying.ogg   the picked set, in game order, at in-game levels
  previews/sounds-packs-compare.ogg  the same cues in the three candidate packs (rubber, then organic, then soft)

    git clone --depth 1 https://github.com/romainsimon/uisfx /tmp/uisfx        (CC0 audio, see LICENSE-AUDIO)
    git clone --depth 1 https://github.com/kapishdima/soundcn /tmp/soundcn    (Kenney packs, CC0; NOT its wow/ folder)
    python3 -I cannon-evolution/tools/sfx/import_satisfying.py /tmp/uisfx /tmp/soundcn

Sources (both free for commercial games, no credit needed):
  * UI SFX by Yuki Capital (github.com/romainsimon/uisfx): 12 designed UI packs, audio CC0 1.0. We use the "rubber"
    pack: "tactile elastic taps with a quick friendly rebound", made for kids, playful mobile and casual games.
    Measured (huzz-valley/tools/sfx/measure_sfx.py): soft 4 ms attacks, centroid 300-1000 Hz, almost nothing above
    4 kHz, every file the same loudness (-19 dB RMS) - warm and round, no hiss.
  * Kenney (CC0) via soundcn: casino chips-collide-1 for Coin (a short real chip clink, 85 ms).
  * Shot (Alex, Oct 30: "make the shooting sound way better, like an actual cannon"): two Kenney sci-fi CC0 files
    layered, like a real cannon: explosionCrunch_000 is the sharp "crack" at the front (2 ms attack), with its
    hiss cut above 3.5 kHz; lowFrequency_explosion_001 is the deep "boom" body (91 Hz), with a small bass lift.
    Cut to 0.8 s and faded from 0.35 s, so it's a quick punch and not a long rumble. Measured: 0% above 4 kHz,
    centroid 117 Hz, peak under 0 dB. (The old soft impactSoft_heavy_000 thump didn't sound like a cannon.)
"""
import os
import subprocess
import sys

# slot -> (source, path inside it)
PICKS = {
    "Click": ("uisfx", "rubber/press"),
    "Hover": ("uisfx", "rubber/hover"),
    "Open": ("uisfx", "rubber/open"),
    "Close": ("uisfx", "rubber/close"),
    "Confirm": ("uisfx", "rubber/purchase"),
    "Error": ("uisfx", "rubber/error"),
    "Tab": ("uisfx", "rubber/select"),
    "Reward": ("uisfx", "rubber/reward"),
    "Rebirth": ("uisfx", "rubber/level-up"),
    "Unlock": ("uisfx", "rubber/unlock"),
    "Coin": ("kenney", "kenney_casino-audio/chips-collide-1"),
}
SHOT = [("kenney_sci-fi-sounds/explosionCrunch_000", "lowpass=f=3500,volume=0.6"),
        ("kenney_sci-fi-sounds/lowFrequency_explosion_001", "bass=g=3:f=90,volume=0.36")]
# GameClient/Sfx LEVEL (keep in step); the uisfx files sit ~6 dB under Kenney's, so their levels are higher
LEVEL = {"Click": 0.6, "Hover": 0.25, "Open": 0.45, "Close": 0.4, "Confirm": 0.55, "Error": 0.5, "Tab": 0.5,
         "Reward": 0.6, "Rebirth": 0.6, "Unlock": 0.6, "Coin": 0.35, "Shot": 0.6}
ORDER = [("Hover", 0.3), ("Click", 0.5), ("Open", 0.6), ("Tab", 0.4), ("Click", 0.4), ("Confirm", 0.9),
         ("Coin", 0.25), ("Coin", 0.25), ("Coin", 0.6), ("Error", 0.8), ("Close", 0.8), ("Shot", 0.9),
         ("Reward", 0.9), ("Unlock", 0.9), ("Rebirth", 1.0)]
COMPARE = ["press", "open", "select", "purchase", "error", "close", "reward", "level-up"]


def run(args):
    subprocess.run(args, check=True, capture_output=True)


def src_path(roots, kind, rel):
    if kind == "uisfx":
        return os.path.join(roots["uisfx"], "packages", "uisfx", "sounds", rel + ".ogg")
    return os.path.join(roots["kenney"], "assets", rel + ".ogg")


def concat(items, out):
    """items: list of (file, volume, gap seconds)"""
    inputs, parts = [], []
    for i, (f, vol, gap) in enumerate(items):
        inputs += ["-i", f]
        parts.append(f"[{i}:a]aformat=channel_layouts=mono:sample_rates=44100,volume={vol},apad=pad_dur={gap}[a{i}]")
    graph = ";".join(parts) + ";" + "".join(f"[a{i}]" for i in range(len(items))) + f"concat=n={len(items)}:v=0:a=1[o]"
    run(["ffmpeg", "-y", "-loglevel", "error", *inputs, "-filter_complex", graph, "-map", "[o]", "-c:a", "libvorbis",
         "-q:a", "5", out])


def main():
    roots = {"uisfx": sys.argv[1], "kenney": sys.argv[2]}
    game = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
    out = os.path.join(game, "assets", "sfx")
    os.makedirs(out, exist_ok=True)
    for slot, (kind, rel) in PICKS.items():
        run(["ffmpeg", "-y", "-loglevel", "error", "-i", src_path(roots, kind, rel), "-af",
             "aformat=channel_layouts=mono", "-c:a", "libvorbis", "-q:a", "6", os.path.join(out, slot + ".ogg")])
        print("wrote", slot, "from", kind, rel)
    inputs, parts = [], []
    for i, (rel, af) in enumerate(SHOT):
        inputs += ["-i", src_path(roots, "kenney", rel)]
        parts.append(f"[{i}:a]aformat=channel_layouts=mono,{af}[s{i}]")
    graph = ";".join(parts) + ";[s0][s1]amix=inputs=2:normalize=0,atrim=0:0.8,afade=t=out:st=0.35:d=0.45[o]"
    run(["ffmpeg", "-y", "-loglevel", "error", *inputs, "-filter_complex", graph, "-map", "[o]", "-c:a", "libvorbis",
         "-q:a", "6", os.path.join(out, "Shot.ogg")])
    print("wrote Shot (crack + boom)")
    concat([(os.path.join(out, s + ".ogg"), LEVEL[s], g) for s, g in ORDER],
           os.path.join(game, "previews", "sounds-satisfying.ogg"))
    items = []
    for pack in ("rubber", "organic", "soft"):
        items += [(src_path(roots, "uisfx", f"{pack}/{c}"), 0.8, 0.45) for c in COMPARE]
        items[-1] = (items[-1][0], 0.8, 1.5)
    concat(items, os.path.join(game, "previews", "sounds-packs-compare.ogg"))
    print("wrote previews")


if __name__ == "__main__":
    main()

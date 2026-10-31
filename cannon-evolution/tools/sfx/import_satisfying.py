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
    "Reward": ("kenney", "kenney_digital-audio/twoTone1"),
    "Rebirth": ("uisfx", "rubber/level-up"),
    "Unlock": ("uisfx", "rubber/unlock"),
    "Coin": ("kenney", "kenney_casino-audio/chips-collide-1"),
}
# Alex, Oct 30 (evening): "make the launching sound actually like a launch, make the training sound better ...
# make the reward sound just quick ... very quick and understandable". So:
#   Launch: the cannon crack + deep boom, with a soft air whoosh (pink noise, 400-2500 Hz) flying away, 0.9 s
#   Shot (the training cannon, fired again and again): a light crack + punch, 0.4 s, gone by 0.4
#   Reward: Kenney digital-audio twoTone1, a warm 2-note "collect" (0.37 s, 354 Hz, no hiss)
MIXES = {
    "Launch": ([("kenney_sci-fi-sounds/explosionCrunch_000", "lowpass=f=3500,volume=0.55"),
                ("kenney_sci-fi-sounds/lowFrequency_explosion_001", "bass=g=3:f=90,volume=0.33"),
                ("noise", "highpass=f=400,lowpass=f=2500,afade=t=in:st=0:d=0.1,afade=t=out:st=0.2:d=0.9,volume=0.75,adelay=40")],
               "atrim=0:1.1,afade=t=out:st=0.6:d=0.5"),
    "Shot": ([("kenney_sci-fi-sounds/explosionCrunch_000", "lowpass=f=3000,volume=0.55"),
              ("kenney_impact-sounds/impactPunch_heavy_000", "volume=0.7")],
             "atrim=0:0.4,afade=t=out:st=0.12:d=0.28"),
}
# GameClient/Sfx LEVEL (keep in step); the uisfx files sit ~6 dB under Kenney's, so their levels are higher
LEVEL = {"Launch": 0.6, "Click": 0.6, "Hover": 0.25, "Open": 0.45, "Close": 0.4, "Confirm": 0.55, "Error": 0.5, "Tab": 0.5,
         "Reward": 0.35, "Rebirth": 0.6, "Unlock": 0.6, "Coin": 0.35, "Shot": 0.6}
ORDER = [("Hover", 0.3), ("Click", 0.5), ("Open", 0.6), ("Tab", 0.4), ("Click", 0.4), ("Confirm", 0.9),
         ("Coin", 0.25), ("Coin", 0.25), ("Coin", 0.6), ("Error", 0.8), ("Close", 0.8), ("Shot", 0.5), ("Shot", 0.5), ("Launch", 1.0),
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
    for slot, (layers, tail) in MIXES.items():
        inputs, parts = [], []
        for i, (rel, af) in enumerate(layers):
            if rel == "noise":
                inputs += ["-f", "lavfi", "-t", "1.1", "-i", "anoisesrc=color=pink:amplitude=0.6:seed=7"]
            else:
                inputs += ["-i", src_path(roots, "kenney", rel)]
            parts.append(f"[{i}:a]aformat=channel_layouts=mono:sample_rates=44100,{af}[s{i}]")
        graph = ";".join(parts) + ";" + "".join(f"[s{i}]" for i in range(len(layers))) + \
            f"amix=inputs={len(layers)}:normalize=0,{tail}[o]"
        run(["ffmpeg", "-y", "-loglevel", "error", *inputs, "-filter_complex", graph, "-map", "[o]", "-c:a", "libvorbis",
             "-q:a", "6", os.path.join(out, slot + ".ogg")])
        print("wrote", slot, "(mix)")
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

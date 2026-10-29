#!/usr/bin/env python3
"""A short listen file: the old click, a gap, the new click, four times; then four quick taps of the new one.
    python3 -I huzz-valley/tools/sfx/before_after.py <old.ogg> <new.ogg> <out.ogg>
(Oct 18: old = the Oct 18 bubbly pop, assets/sfx/ui_click.ogg before the "premium" remake, from git history;
new = today's assets/sfx/ui_click.ogg.) Needs numpy + ffmpeg. Both at the same level."""
import subprocess
import sys
import tempfile
import wave
import os

import numpy as np

SR = 44100


def decode(path):
    raw = subprocess.run(["ffmpeg", "-loglevel", "error", "-i", path, "-f", "f32le", "-ac", "1", "-ar", str(SR), "-"],
                         check=True, capture_output=True).stdout
    return np.frombuffer(raw, dtype="<f4").astype(float)


def main(old_path, new_path, out):
    old, new = decode(old_path), decode(new_path)
    gap = lambda s: np.zeros(int(s * SR))
    parts = [gap(0.4)]
    for _ in range(4):
        parts += [old, gap(0.55), new, gap(1.0)]
    for _ in range(4):  # quick taps, the way a kid clicks through a menu (8 a second)
        parts += [new, gap(0.125 - len(new) / SR)]
    parts.append(gap(0.4))
    x = np.concatenate(parts) * 0.8
    with tempfile.TemporaryDirectory() as tmp:
        wav = os.path.join(tmp, "x.wav")
        with wave.open(wav, "wb") as w:
            w.setnchannels(1)
            w.setsampwidth(2)
            w.setframerate(SR)
            w.writeframes((np.clip(x, -1, 1) * 32767).astype("<i2").tobytes())
        subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", wav, "-c:a", "libvorbis", "-q:a", "6", out], check=True)
    print(f"{out}: {len(x) / SR:.1f} s")


if __name__ == "__main__":
    main(*sys.argv[1:4])

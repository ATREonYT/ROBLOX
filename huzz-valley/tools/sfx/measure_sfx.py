"""Measures short sound files so UI sounds can be picked by numbers, not by guessing (owner, Oct 19: "do a research
of what sounds good and not, and then logically select the best sounds"). Used for docs/sound-picks.md.

    python3 -I tools/sfx/measure_sfx.py path/to/*.wav

Per file (WAV, any bit depth, mono or stereo):
  dur ms    how long it rings, from first to last moment within 40 dB of its loudest (UI clicks: 40-150 ms)
  atk ms    attack: 10% to 90% of its peak loudness on a 5 ms envelope (0-1 ms = a hard "tick", 2-8 ms = soft)
  peak dB   loudest sample (dBFS)
  rms dB    average level over the ringing part (the even-loudness check: a family should sit within ~3 dB)
  centroid  spectral centroid in Hz ("brightness"; harsh UI sounds sit above ~4 kHz)
  >4k %     share of the energy above 4 kHz (the hissy, tiring part on phone speakers)
Needs only numpy.
"""
import os
import sys
import wave

import numpy as np


def load(path):
    w = wave.open(path)
    n, ch, sw, sr = w.getnframes(), w.getnchannels(), w.getsampwidth(), w.getframerate()
    raw = w.readframes(n)
    x = np.frombuffer(raw, {1: np.uint8, 2: np.int16, 4: np.int32}[sw]).astype(np.float64)
    if sw == 1:
        x = x - 128
    x /= float(2 ** (8 * sw - 1))
    return x.reshape(-1, ch).mean(axis=1), sr


def measure(path):
    x, sr = load(path)
    peak = np.max(np.abs(x)) + 1e-12
    k = max(1, int(sr * 0.005))
    e = np.convolve(np.abs(x), np.ones(k) / k, "same")
    top = e[int(np.argmax(e))]
    attack = (np.argmax(e >= 0.9 * top) - np.argmax(e >= 0.1 * top)) / sr * 1000
    ring = np.where(e >= top * 10 ** (-40 / 20))[0]
    seg = x[ring[0]:ring[-1] + 1] if len(ring) else x
    dur = len(seg) / sr * 1000
    rms = np.sqrt(np.mean(seg ** 2)) + 1e-12
    spec = np.abs(np.fft.rfft(seg * np.hanning(len(seg)))) ** 2
    f = np.fft.rfftfreq(len(seg), 1 / sr)
    centroid = (spec * f).sum() / spec.sum()
    high = spec[f > 4000].sum() / spec.sum() * 100
    return dur, attack, 20 * np.log10(peak), 20 * np.log10(rms), centroid, high


def main(paths):
    print(f"{'file':22s} {'dur ms':>7s} {'atk ms':>7s} {'peak dB':>8s} {'rms dB':>7s} {'centroid':>9s} {'>4k %':>6s}")
    for p in sorted(paths):
        d, a, pk, r, c, h = measure(p)
        print(f"{os.path.basename(p):22s} {d:7.0f} {a:7.1f} {pk:8.1f} {r:7.1f} {c:9.0f} {h:6.1f}")


if __name__ == "__main__":
    main(sys.argv[1:])

#!/usr/bin/env python3
"""Huzz Valley sound effects generator.

Every sound is synthesized here from scratch (no samples, nobody else's audio),
so the whole set can be rebuilt or tweaked any time.

    python3 huzz-valley/tools/sfx/make_sfx.py            # build all sounds + check
    python3 huzz-valley/tools/sfx/make_sfx.py coin dash  # build only these
    python3 huzz-valley/tools/sfx/make_sfx.py --sheet out.png   # also draw spectrograms

Needs: python3 + numpy, and ffmpeg/ffprobe on PATH. matplotlib only for --sheet.
Output: huzz-valley/assets/sfx/<name>.ogg (mono, 44.1 kHz, Vorbis q6) + README.md

Family rules (keep new sounds in the same family):
  * Notes come from C major pentatonic (C D E G A); sad sounds lean on A minor.
  * Tones are soft bells (FM), marimba, brassy additive "stabs", warm sines.
  * One shared reverb room (ROOM_IR), mixed 5-25 % wet.
  * Gentle tanh saturation, 25 Hz high-pass (no DC), peak normalized to -1 dBFS.
"""
import os
import subprocess
import sys
import tempfile
import wave

import numpy as np

SR = 44100
HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.normpath(os.path.join(HERE, "..", "..", "assets", "sfx"))
PEAK_DB = -1.0

# ---------------------------------------------------------------- notes
_NAMES = {"C": 0, "D": 2, "E": 4, "F": 5, "G": 7, "A": 9, "B": 11}


def hz(name):
    """'C5' -> 523.25 Hz, 'G#4' works too."""
    letter, rest = name[0], name[1:]
    semi = _NAMES[letter]
    if rest.startswith("#"):
        semi, rest = semi + 1, rest[1:]
    midi = 12 * (int(rest) + 1) + semi
    return 440.0 * 2 ** ((midi - 69) / 12)


# ---------------------------------------------------------------- basics
def tt(dur):
    return np.arange(int(round(dur * SR))) / SR


def buf(dur):
    return np.zeros(int(round(dur * SR)))


def add(dst, src, at=0.0, gain=1.0):
    i = int(round(at * SR))
    n = min(len(src), len(dst) - i)
    if n > 0:
        seg = gain * src[:n]
        k = min(n, int(0.003 * SR))  # never cut a layer off mid-wave (that clicks)
        seg[n - k:] *= np.cos(np.linspace(0, np.pi / 2, k)) ** 2
        dst[i:i + n] += seg
    return dst


def phase(freq):
    """Phase from a frequency curve (array or scalar)."""
    return 2 * np.pi * np.cumsum(freq) / SR


def glide(f0, f1, dur, curve=1.0):
    """Exponential pitch glide f0 -> f1 over dur (curve>1 = faster start)."""
    x = np.linspace(0, 1, int(round(dur * SR))) ** (1 / curve)
    return f0 * (f1 / f0) ** x


def env(dur, attack=0.002, decay=0.2, hold=0.0):
    """Attack (smooth) -> optional hold -> exponential decay with time constant `decay`."""
    t = tt(dur)
    a = np.clip(t / max(attack, 1e-5), 0, 1)
    a = np.sin(a * np.pi / 2) ** 2
    d = np.exp(-np.clip(t - attack - hold, 0, None) / decay)
    return a * d


def fade(x, fin=0.0008, fout=0.012):
    x = x.copy()
    ni, no = int(fin * SR), int(fout * SR)
    if ni:
        x[:ni] *= np.linspace(0, 1, ni)
    if no:
        x[-no:] *= np.cos(np.linspace(0, np.pi / 2, no)) ** 2
    return x


# ---------------------------------------------------------------- filters (numpy FFT, zero phase)
def _fft_filter(x, gain_fn):
    n = len(x)
    pad = 1 << int(np.ceil(np.log2(n + 4096)))
    X = np.fft.rfft(x, pad)
    f = np.fft.rfftfreq(pad, 1 / SR)
    return np.fft.irfft(X * gain_fn(f), pad)[:n]


def lowpass(x, fc, order=2):
    return _fft_filter(x, lambda f: 1 / np.sqrt(1 + (f / fc) ** (2 * order)))


def highpass(x, fc, order=2):
    return _fft_filter(x, lambda f: 1 / np.sqrt(1 + (fc / np.maximum(f, 1e-3)) ** (2 * order)))


def bandpass(x, fc, octaves=1.0):
    def g(f):
        lf = np.log2(np.maximum(f, 1) / fc)
        return np.exp(-0.5 * (lf / (octaves / 2.355)) ** 2)
    return _fft_filter(x, g)


def stft_shape(x, gain_fn, n=1024, hop=256):
    """Time-varying filter: gain_fn(freqs, t_sec) -> gain per bin for that frame."""
    win = np.hanning(n)
    pad = np.concatenate([np.zeros(n), x, np.zeros(n)])
    frames = (len(pad) - n) // hop + 1
    out = np.zeros(len(pad))
    norm = np.zeros(len(pad))
    f = np.fft.rfftfreq(n, 1 / SR)
    for k in range(frames):
        s = k * hop
        seg = pad[s:s + n] * win
        tc = (s + n / 2 - n) / SR
        y = np.fft.irfft(np.fft.rfft(seg) * gain_fn(f, tc), n) * win
        out[s:s + n] += y
        norm[s:s + n] += win ** 2
    out /= np.maximum(norm, 1e-6)
    return out[n:n + len(x)]


def sweep_noise(dur, f_curve, octaves=1.2, seed=0):
    """Noise through a band-pass whose centre follows f_curve(t_normalized 0..1)."""
    rng = np.random.default_rng(seed)
    x = rng.standard_normal(int(round(dur * SR)))

    def g(f, tc):
        fc = f_curve(np.clip(tc / dur, 0, 1))
        lf = np.log2(np.maximum(f, 1) / fc)
        return np.exp(-0.5 * (lf / (octaves / 2.355)) ** 2)
    return stft_shape(x, g)


# ---------------------------------------------------------------- the shared room
def _make_room(seconds=1.4, seed=7):
    rng = np.random.default_rng(seed)
    t = tt(seconds)
    n = rng.standard_normal(len(t))
    lo = lowpass(n, 2500) * np.exp(-t / 0.34)       # warm body lasts longer
    hi = highpass(n, 2500) * np.exp(-t / 0.13)      # air dies quickly (no harsh hiss)
    ir = lo + 0.45 * hi
    ir *= np.clip(t / 0.012, 0, 1)                  # small pre-delay swell
    for d, g in [(0.011, 0.5), (0.019, 0.35), (0.027, 0.3), (0.041, 0.2)]:
        ir[int(d * SR)] += g * 6                     # early reflections
    return ir / np.sqrt(np.sum(ir ** 2))


ROOM_IR = _make_room()


def reverb(x, wet=0.15, tail=0.0):
    """Add the shared room. tail = seconds of extra length to keep."""
    y = np.concatenate([x, np.zeros(int(tail * SR))])
    n = len(y) + len(ROOM_IR)
    pad = 1 << int(np.ceil(np.log2(n)))
    w = np.fft.irfft(np.fft.rfft(y, pad) * np.fft.rfft(ROOM_IR, pad), pad)[:len(y)]
    w = highpass(w, 180)  # keep the room out of the low end (no mud)
    dry_rms = np.sqrt(np.mean(y ** 2)) + 1e-9
    wet_rms = np.sqrt(np.mean(w ** 2)) + 1e-9
    return y + wet * w * dry_rms / wet_rms


# ---------------------------------------------------------------- instruments
def sine(freq, dur):
    f = np.full(int(round(dur * SR)), float(freq)) if np.isscalar(freq) else freq
    return np.sin(phase(f))


def bell(freq, dur, decay=0.35, ratio=3.5, index=2.2, idecay=0.08, attack=0.0015, bright=1.0):
    """FM bell: bright strike that mellows quickly."""
    t = tt(dur)
    pc = phase(np.full(len(t), freq))
    I = bright * index * np.exp(-t / idecay)
    y = np.sin(pc + I * np.sin(ratio * pc))
    y += 0.25 * np.sin(2 * pc) * np.exp(-t / (decay * 0.5))
    return y * env(dur, attack, decay)


def glass(freq, dur, decay=0.03):
    """Glassy tick: fundamental + inharmonic partials."""
    t = tt(dur)
    y = (np.sin(2 * np.pi * freq * t)
         + 0.5 * np.sin(2 * np.pi * freq * 2.76 * t) * np.exp(-t / (decay * 0.5))
         + 0.25 * np.sin(2 * np.pi * freq * 5.40 * t) * np.exp(-t / (decay * 0.3)))
    return y * env(dur, 0.0008, decay)


def marimba(freq, dur, decay=0.09):
    t = tt(dur)
    y = (np.sin(2 * np.pi * freq * t)
         + 0.45 * np.sin(2 * np.pi * freq * 3.93 * t) * np.exp(-t / (decay * 0.25))
         + 0.12 * np.sin(2 * np.pi * freq * 9.2 * t) * np.exp(-t / (decay * 0.1)))
    return y * env(dur, 0.0012, decay)


def brass(freq, dur, attack=0.025, decay=0.5, hold=0.0, bright=(2.0, 9.0), scoop=0.03,
          vib=0.0, harmonics=24):
    """Additive brass: harmonics open up with the attack, slight pitch scoop + vibrato."""
    t = tt(dur)
    e = env(dur, attack, decay, hold)
    f = np.full(len(t), freq) if np.isscalar(freq) else np.asarray(freq, float)
    f = f * 2 ** (-scoop * np.exp(-t / 0.03))                       # scoop up into the note
    f = f * (1 + vib * np.sin(2 * np.pi * 5.5 * t) * np.clip(t / 0.25, 0, 1))
    b = bright[0] + (bright[1] - bright[0]) * (e / (e.max() + 1e-9)) ** 0.6
    pc = phase(f)
    y = np.zeros(len(t))
    for k in range(1, harmonics + 1):
        if freq * k > 15000 if np.isscalar(freq) else f.max() * k > 15000:
            break
        y += (1 / k) * np.exp(-(k - 1) / b) * np.sin(k * pc)
    return y * e


def warm(freq, dur, attack=0.01, decay=0.3, hold=0.0, vib=0.0):
    """Soft mellow tone (sine + a little 2nd/3rd)."""
    t = tt(dur)
    f = np.full(len(t), freq) if np.isscalar(freq) else np.asarray(freq, float)
    f = f * (1 + vib * np.sin(2 * np.pi * 5 * t) * np.clip((t - 0.1) / 0.3, 0, 1))
    pc = phase(f)
    y = np.sin(pc) + 0.3 * np.sin(2 * pc) + 0.08 * np.sin(3 * pc)
    return y * env(dur, attack, decay, hold)


def click(dur=0.004, fc=4000, octaves=2.0, seed=1):
    rng = np.random.default_rng(seed)
    x = bandpass(rng.standard_normal(int(dur * SR) + 64), fc, octaves)
    return x * env(len(x) / SR, 0.0003, dur / 4)


def thump(f0=140, f1=50, dur=0.25, decay=0.08):
    return sine(glide(f0, f1, dur, 2.0), dur) * env(dur, 0.001, decay)


def sparkles(dur, count, notes, seed=3, start=0.0, level=0.3, decay=0.12):
    """Scatter tiny high bell pings (the 'shimmer')."""
    rng = np.random.default_rng(seed)
    out = buf(dur)
    for _ in range(count):
        at = rng.uniform(start, max(start, dur - 0.15))
        n = notes[rng.integers(len(notes))]
        add(out, bell(hz(n), 0.25, decay=decay, ratio=4.0, index=1.2, idecay=0.02),
            at, level * rng.uniform(0.4, 1.0))
    return out


def shimmer_noise(dur, f0=5000, f1=9000, level=0.08, seed=5):
    x = sweep_noise(dur, lambda u: f0 * (f1 / f0) ** u, octaves=1.0, seed=seed)
    return x / (np.abs(x).max() + 1e-9) * level


def saturate(x, drive=1.5):
    m = np.abs(x).max() + 1e-12
    x = x / m
    return np.tanh(drive * x) / np.tanh(drive)


def finish(x, dur, drive=1.3, fout=0.015, hp=25):
    """Trim/pad to dur, clean, soften, normalize."""
    n = int(round(dur * SR))
    x = np.concatenate([x, np.zeros(max(0, n - len(x)))])[:n]
    x = highpass(x, hp, order=2)
    x = lowpass(x, 15000, order=2)
    x = saturate(x, drive)
    x = x - np.mean(x)
    x = fade(x, 0.0008, fout)
    return x / (np.abs(x).max() + 1e-12) * 10 ** (PEAK_DB / 20)


def norm(x, peak=1.0):
    return x / (np.abs(x).max() + 1e-12) * peak


# ================================================================== the sounds
SOUNDS = {}


def sound(name, desc):
    def deco(fn):
        SOUNDS[name] = (fn, desc)
        return fn
    return deco


# ---------------- UI
@sound("ui_click", "Tiny soft pop for button presses.")
def ui_click():
    d = 0.06
    x = sine(glide(1500, 650, d, 3.0), d) * env(d, 0.0008, 0.016)
    x += 0.25 * sine(glide(3000, 1300, d, 3.0), d) * env(d, 0.0005, 0.006)
    add(x, norm(click(0.003, 5000)), 0.0, 0.15)
    return finish(reverb(x, 0.05), d, drive=1.2, fout=0.01)


@sound("ui_hover", "Very soft high tick for hovering over buttons.")
def ui_hover():
    d = 0.04
    x = glass(hz("E7"), d, decay=0.007)
    add(x, norm(click(0.002, 7000)), 0.0, 0.1)
    return finish(x, d, drive=1.0, fout=0.008)


@sound("ui_open", "Soft upward swoosh with a two-note sparkle as a panel opens.")
def ui_open():
    d = 0.25
    w = sweep_noise(d, lambda u: 700 * (3800 / 700) ** u, octaves=1.4, seed=11)
    w = norm(w) * env(d, 0.09, 0.05) * 0.6
    x = w + 0.35 * sine(glide(hz("C5"), hz("C6"), d, 1.5), d) * env(d, 0.06, 0.05)
    add(x, bell(hz("G6"), 0.2, decay=0.07, index=1.5), 0.10, 0.45)
    add(x, bell(hz("C7"), 0.15, decay=0.06, index=1.5), 0.15, 0.4)
    return finish(reverb(x, 0.15), d, drive=1.2, fout=0.03)


@sound("ui_close", "Soft downward swoosh as a panel closes.")
def ui_close():
    d = 0.2
    w = sweep_noise(d, lambda u: 3200 * (600 / 3200) ** u, octaves=1.4, seed=12)
    w = norm(w) * env(d, 0.03, 0.06) * 0.6
    x = w + 0.4 * sine(glide(hz("G5"), hz("G4"), d, 1.5), d) * env(d, 0.01, 0.06)
    return finish(reverb(x, 0.12), d, drive=1.2, fout=0.03)


@sound("ui_error", "Gentle low double boop (\"nope\") for a blocked action.")
def ui_error():
    d = 0.34
    x = buf(d)
    for at, n in [(0.0, "A3"), (0.14, "F3")]:
        nd = 0.13
        f = glide(hz(n) * 1.02, hz(n), nd, 2.0)
        add(x, warm(f, nd, attack=0.006, decay=0.035, hold=0.02), at, 1.0)
    x = lowpass(x, 1800)
    return finish(reverb(x, 0.08), d, drive=1.6, fout=0.05)


# ---------------- rewards
@sound("coin", "Bright two-note coin chime (E6 then A6).")
def coin():
    d = 0.5
    x = buf(d)
    add(x, bell(hz("E6"), 0.08, decay=0.05, ratio=2.0, index=1.4), 0.0, 0.8)
    add(x, bell(hz("A6"), 0.42, decay=0.13, ratio=2.0, index=1.6, idecay=0.05), 0.065, 1.0)
    add(x, np.pad(norm(click(0.002, 6000)), (0, 10)), 0.0, 0.15)
    return finish(reverb(x, 0.12), d, drive=1.3, fout=0.06)


@sound("reward", "Sparkly rising arpeggio with a shimmer tail for unlocks and prizes.")
def reward():
    d = 0.9
    x = buf(d)
    notes = ["C6", "E6", "G6", "A6", "C7", "E7"]
    for i, n in enumerate(notes):
        last = i == len(notes) - 1
        add(x, bell(hz(n), 0.6 if last else 0.3, decay=0.28 if last else 0.12, index=1.6),
            i * 0.065, 0.75 if not last else 0.9)
    add(x, warm(hz("C5"), 0.8, attack=0.04, decay=0.3), 0.0, 0.25)
    add(x, sparkles(0.9, 10, ["C7", "E7", "G7", "A7"], seed=21, start=0.25, level=0.22), 0.0)
    sh = shimmer_noise(0.7, 5000, 10000, level=0.06, seed=22) * env(0.7, 0.2, 0.2)
    add(x, sh, 0.15)
    return finish(reverb(x, 0.25), d, drive=1.3, fout=0.12)


@sound("level_up", "Short triumphant 3-note brass fanfare (G-C-E onto a C major chord).")
def level_up():
    d = 1.2
    x = buf(d)
    add(x, brass(hz("G4"), 0.14, attack=0.012, decay=0.06, hold=0.05), 0.0, 0.85)
    add(x, brass(hz("C5"), 0.14, attack=0.012, decay=0.06, hold=0.05), 0.12, 0.85)
    for n, g in [("E5", 0.6), ("C5", 0.45), ("G4", 0.4), ("C4", 0.35)]:
        add(x, brass(hz(n), 0.95, attack=0.02, decay=0.35, hold=0.15, vib=0.004), 0.24, g)
    add(x, bell(hz("E6"), 0.6, decay=0.25), 0.24, 0.25)
    add(x, sparkles(0.9, 8, ["C7", "E7", "G7"], seed=31, start=0.3, level=0.15), 0.25)
    add(x, thump(110, 45, 0.3, 0.09), 0.24, 0.5)
    return finish(reverb(x, 0.22), d, drive=1.6, fout=0.15)


# ---------------- round start
@sound("countdown_tick", "Punchy wooden marimba tick for 3-2-1.")
def countdown_tick():
    d = 0.15
    x = marimba(hz("G5"), d, decay=0.05)
    add(x, marimba(hz("G4"), d, decay=0.045), 0.0, 0.5)
    add(x, np.pad(norm(click(0.003, 3000, 1.5)), (0, 10)), 0.0, 0.3)
    return finish(reverb(x, 0.08), d, drive=1.5, fout=0.03)


@sound("countdown_go", "Big bright chord hit with a whoosh for GO!")
def countdown_go():
    d = 0.6
    x = buf(d)
    for n, g in [("C5", 0.6), ("E5", 0.5), ("G5", 0.5), ("C6", 0.4), ("C4", 0.4)]:
        add(x, brass(hz(n), d, attack=0.008, decay=0.16, bright=(4, 12), scoop=0.0), 0.0, g)
    add(x, marimba(hz("C6"), 0.3, decay=0.08), 0.0, 0.5)
    add(x, thump(160, 50, 0.3, 0.07), 0.0, 0.9)
    w = sweep_noise(0.5, lambda u: 4000 * (900 / 4000) ** u, octaves=1.6, seed=41)
    add(x, norm(w) * env(0.5, 0.01, 0.12), 0.0, 0.35)
    add(x, np.pad(norm(click(0.004, 3500, 2.0)), (0, 10)), 0.0, 0.4)
    return finish(reverb(x, 0.2), d, drive=1.8, fout=0.1)


# ---------------- pick roulette
@sound("roulette_tick", "Light glassy tick for the hopping pick highlight (fine at 6+ per second).")
def roulette_tick():
    d = 0.05
    x = glass(hz("C7"), d, decay=0.012)
    add(x, glass(hz("G6"), d, decay=0.01), 0.0, 0.4)
    return finish(reverb(x, 0.05), d, drive=1.1, fout=0.012)


@sound("pick_land", "Satisfying bell ding with a soft low boom when the pick lands.")
def pick_land():
    d = 0.7
    x = buf(d)
    add(x, bell(hz("C6"), d, decay=0.25, ratio=3.5, index=2.4, idecay=0.06), 0.0, 1.0)
    add(x, bell(hz("G6"), d, decay=0.18, ratio=3.5, index=1.4, idecay=0.04), 0.0, 0.3)
    add(x, lowpass(thump(120, 45, 0.45, 0.14), 400), 0.0, 1.1)
    add(x, np.pad(norm(click(0.003, 4500)), (0, 10)), 0.0, 0.25)
    return finish(reverb(x, 0.2), d, drive=1.4, fout=0.12)


@sound("hero_chosen", "Heroic brass stab (da-DAAA) with a sparkle shimmer when you are the Hero.")
def hero_chosen():
    d = 1.0
    x = buf(d)
    add(x, brass(hz("G4"), 0.12, attack=0.01, decay=0.04, hold=0.04), 0.0, 0.8)
    for n, g in [("G5", 0.5), ("E5", 0.5), ("C5", 0.6), ("G4", 0.45), ("C4", 0.45), ("C3", 0.3)]:
        add(x, brass(hz(n), 0.85, attack=0.015, decay=0.3, hold=0.08, vib=0.003, bright=(3, 11)),
            0.11, g)
    add(x, thump(120, 40, 0.4, 0.12), 0.11, 0.7)
    add(x, sparkles(0.85, 10, ["E7", "G7", "C8"], seed=51, start=0.2, level=0.15), 0.12)
    sh = shimmer_noise(0.7, 6000, 10000, level=0.05, seed=52) * env(0.7, 0.15, 0.2)
    add(x, sh, 0.15)
    return finish(reverb(x, 0.22), d, drive=1.7, fout=0.15)


@sound("chicken_chosen", "Cute cartoon \"bawk!\" cluck followed by a bouncy boing (you are the Chicken).")
def chicken_chosen():
    d = 0.6
    x = buf(d)

    def bawk(f0, fpk, f1, dur, seed):
        t = tt(dur)
        n = len(t)
        k = int(n * 0.3)
        f = np.concatenate([glide(f0, fpk, k / SR, 1.5), glide(fpk, f1, (n - k) / SR)])[:n]
        f = np.pad(f, (0, n - len(f)), mode="edge")
        pc = phase(f)
        saw = sum((1 / h) * np.sin(h * pc) for h in range(1, 30) if f.max() * h < 16000)
        # vowel "aw": formants ~ 750 / 1150 / 2600 Hz, opening then closing
        def g(fr, tc):
            u = np.clip(tc / dur, 0, 1)
            o = np.sin(np.pi * u)
            out = np.zeros_like(fr)
            for fc, a, bw in [(500 + 300 * o, 1.0, 0.7), (900 + 300 * o, 0.7, 0.6), (2600, 0.25, 0.5)]:
                out += a * np.exp(-0.5 * (np.log2(np.maximum(fr, 1) / fc) / (bw / 2.355)) ** 2)
            return out
        y = stft_shape(saw, g, n=512, hop=128)
        return norm(y) * env(dur, 0.006, dur * 0.4, hold=dur * 0.3)

    add(x, bawk(hz("C5"), hz("G5"), hz("E5"), 0.07, 1), 0.0, 0.55)
    add(x, bawk(hz("D5"), hz("A5"), hz("E5"), 0.13, 2), 0.085, 0.75)
    # boing: springy wobble that glides up
    bd = 0.38
    t = tt(bd)
    f = glide(hz("G4"), hz("C5"), bd) * (1 + 0.12 * np.exp(-t / 0.15) * np.sin(2 * np.pi * 18 * t))
    pc = phase(f)
    boing = (np.sin(pc) + 0.35 * np.sin(2 * pc) + 0.1 * np.sin(3 * pc)) * env(bd, 0.004, 0.12)
    add(x, boing, 0.22, 0.8)
    add(x, lowpass(thump(200, 90, 0.12, 0.03), 600), 0.22, 0.4)
    return finish(reverb(x, 0.12), d, drive=1.4, fout=0.08)


# ---------------- moves
@sound("dash", "Fast airy whoosh for the dash.")
def dash():
    d = 0.25
    w = sweep_noise(d, lambda u: 900 * (3500 / 900) ** np.sin(np.pi * u * 0.8), octaves=1.6, seed=61)
    e = np.exp(-0.5 * ((tt(d) - 0.08) / 0.045) ** 2)
    x = norm(w) * e
    x += 0.25 * norm(sweep_noise(d, lambda u: 350 + 300 * u, octaves=1.2, seed=62)) * e
    return finish(reverb(x, 0.08), d, drive=1.2, fout=0.03)


@sound("stab", "Quick blade swish with a tiny soft shing.")
def stab():
    d = 0.18
    w = sweep_noise(d, lambda u: 1800 * (6500 / 1800) ** (u ** 0.6), octaves=1.0, seed=71)
    e = np.exp(-0.5 * ((tt(d) - 0.045) / 0.025) ** 2)
    x = norm(w) * e
    t = tt(d)
    ring = sum(a * np.sin(2 * np.pi * f * t) for f, a in [(hz("E7"), 1.0), (hz("A7") * 1.01, 0.6), (5900, 0.3)])
    add(x, ring * env(d, 0.002, 0.04), 0.04, 0.12)
    return finish(reverb(x, 0.08), d, drive=1.2, fout=0.03)


@sound("caught", "Cartoon thud and a descending \"bwomp\" (silly, not scary).")
def caught():
    d = 0.6
    x = buf(d)
    add(x, thump(150, 55, 0.2, 0.06), 0.0, 1.0)
    rng = np.random.default_rng(81)
    puff = lowpass(rng.standard_normal(int(0.08 * SR)), 700) * env(0.08, 0.002, 0.02)
    add(x, norm(puff), 0.0, 0.35)
    bd = 0.48
    f = glide(hz("E4"), hz("A3"), bd, 0.8)
    add(x, brass(f, bd, attack=0.02, decay=0.14, hold=0.08, bright=(1.5, 4.0), scoop=0.0, vib=0.012),
        0.07, 0.5)
    x = lowpass(x, 3500)
    return finish(reverb(x, 0.12), d, drive=1.5, fout=0.1)


@sound("rescue", "Warm uplifting sparkle rise for freeing a teammate.")
def rescue():
    d = 0.8
    x = buf(d)
    for n, g in [("C4", 0.35), ("G4", 0.25), ("E5", 0.2)]:
        add(x, warm(hz(n), 0.8, attack=0.25, decay=0.18, hold=0.15), 0.0, g)
    for i, n in enumerate(["C5", "E5", "G5", "C6", "E6", "G6"]):
        add(x, bell(hz(n), 0.4, decay=0.14, index=1.3), 0.05 + i * 0.055, 0.45 + 0.05 * i)
    r = sweep_noise(0.55, lambda u: 1500 * (8000 / 1500) ** u, octaves=1.0, seed=91)
    add(x, norm(r) * env(0.55, 0.35, 0.06), 0.0, 0.12)
    add(x, sparkles(0.5, 8, ["C7", "E7", "G7", "A7"], seed=92, level=0.18), 0.32)
    return finish(reverb(x, 0.25), d, drive=1.3, fout=0.12)


@sound("safe", "Happy bright success chime for reaching the safe side.")
def safe():
    d = 0.7
    x = buf(d)
    add(x, marimba(hz("C6"), 0.3, decay=0.08), 0.0, 0.6)
    add(x, bell(hz("C6"), 0.3, decay=0.1, index=1.4), 0.0, 0.4)
    for n, g in [("E6", 0.6), ("G6", 0.55), ("C7", 0.35)]:
        add(x, bell(hz(n), 0.6, decay=0.22, index=1.6, ratio=2.0), 0.09, g)
    add(x, marimba(hz("G5"), 0.3, decay=0.1), 0.09, 0.4)
    add(x, sparkles(0.4, 5, ["E7", "G7", "C8"], seed=101, level=0.12), 0.2)
    return finish(reverb(x, 0.2), d, drive=1.3, fout=0.12)


# ---------------- round end
@sound("round_win", "Joyful little victory jingle ending on a bright C major chord.")
def round_win():
    d = 1.8
    x = buf(d)
    mel = [("C6", 0.00, 0.12), ("E6", 0.12, 0.12), ("G6", 0.24, 0.12), ("E6", 0.36, 0.10),
           ("G6", 0.46, 0.14), ("C7", 0.62, 1.1)]
    for n, at, ln in mel:
        long = ln > 0.5
        add(x, bell(hz(n), ln + 0.25, decay=0.45 if long else 0.1, index=1.5, ratio=2.0), at, 0.6)
        add(x, marimba(hz(n) / 2, 0.25, decay=0.07), at, 0.35)
    for n, at in [("C4", 0.0), ("G4", 0.24), ("C4", 0.46)]:
        add(x, marimba(hz(n), 0.25, decay=0.08), at, 0.4)
    for n, g in [("C5", 0.3), ("E5", 0.25), ("G5", 0.25), ("C4", 0.3)]:
        add(x, brass(hz(n), 1.15, attack=0.03, decay=0.4, hold=0.2, vib=0.003, bright=(2, 7)), 0.62, g)
    add(x, thump(120, 45, 0.3, 0.09), 0.62, 0.5)
    add(x, sparkles(1.1, 12, ["C7", "E7", "G7", "A7", "C8"], seed=111, start=0.1, level=0.14), 0.65)
    return finish(reverb(x, 0.25), d, drive=1.5, fout=0.25)


@sound("round_lose", "Soft, sympathetic three-note fall (E-C-A), gentle and warm.")
def round_lose():
    d = 1.2
    x = buf(d)
    for n, at, ln in [("E5", 0.0, 0.3), ("C5", 0.22, 0.3), ("A4", 0.44, 0.76)]:
        last = ln > 0.5
        f = np.full(int(ln * SR), hz(n))
        if last:  # small sigh: droop a few cents at the end
            f = f * 2 ** (-0.04 * np.clip((tt(ln) - 0.25) / 0.4, 0, 1))
        add(x, warm(f, ln, attack=0.02, decay=0.3 if last else 0.09, hold=0.1 if last else 0.06,
                    vib=0.006 if last else 0.0), at, 0.7)
        add(x, bell(hz(n), ln, decay=0.12, index=0.8, ratio=2.0), at, 0.15)
    add(x, warm(hz("A3"), 0.75, attack=0.05, decay=0.3, hold=0.1), 0.44, 0.3)
    x = lowpass(x, 4000)
    return finish(reverb(x, 0.25), d, drive=1.2, fout=0.25)


# ---------------- misc
@sound("step", "Very soft footstep / dust puff (play often, at low volume).")
def step():
    d = 0.08
    rng = np.random.default_rng(121)
    n = bandpass(rng.standard_normal(int(d * SR)), 700, 2.2) * env(d, 0.004, 0.018)
    x = norm(n) * 0.7
    add(x, thump(110, 70, d, 0.02), 0.0, 0.6)
    return finish(x, d, drive=1.2, fout=0.02, hp=40)


@sound("heart_shield", "Bubbly pop and a soft shimmering shield bloom.")
def heart_shield():
    d = 0.6
    x = buf(d)
    rng = np.random.default_rng(131)
    for i, n in enumerate(["G5", "C6", "E6", "A5", "D6"]):
        bd = 0.06
        f = glide(hz(n) * 0.7, hz(n) * 1.25, bd, 0.6)
        add(x, sine(f, bd) * env(bd, 0.002, 0.025), i * 0.035 + rng.uniform(0, 0.01), 0.45)
    add(x, np.pad(norm(click(0.003, 2500, 1.5)), (0, 10)), 0.17, 0.35)
    add(x, thump(260, 120, 0.1, 0.03), 0.17, 0.45)
    t = tt(0.42)
    trem = 1 + 0.3 * np.sin(2 * np.pi * 9 * t)
    for n, g in [("C6", 0.3), ("E6", 0.25), ("G6", 0.22), ("C7", 0.12)]:
        add(x, warm(hz(n), 0.42, attack=0.05, decay=0.14, hold=0.05) * trem, 0.17, g)
    add(x, sparkles(0.4, 5, ["E7", "G7", "C8"], seed=132, level=0.12), 0.2)
    return finish(reverb(x, 0.18), d, drive=1.3, fout=0.1)


@sound("power_rush", "Whoosh plus a rising zip for a speed boost.")
def power_rush():
    d = 0.6
    x = buf(d)
    w = sweep_noise(d, lambda u: 500 * (5000 / 500) ** u, octaves=1.3, seed=141)
    add(x, norm(w) * env(d, 0.3, 0.1), 0.0, 0.5)
    zd = 0.42
    f = glide(hz("C4"), hz("C7"), zd, 0.7)
    t = tt(zd)
    pc = phase(f)
    zip_ = (np.sin(pc) + 0.4 * np.sin(2 * pc) + 0.2 * np.sin(3 * pc))
    zip_ *= (0.6 + 0.4 * np.sin(2 * np.pi * 32 * t)) * env(zd, 0.03, 0.12, hold=0.2)
    add(x, lowpass(zip_, 5000), 0.05, 0.5)
    add(x, bell(hz("C7"), 0.15, decay=0.06, index=1.2), 0.45, 0.3)
    return finish(reverb(x, 0.15), d, drive=1.4, fout=0.06)


# ================================================================== output + checks
def write_wav(path, x):
    pcm = np.clip(np.round(x * 32767), -32768, 32767).astype("<i2")
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(pcm.tobytes())


def to_ogg(wav, ogg):
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", wav, "-ac", "1", "-ar", str(SR),
                    "-c:a", "libvorbis", "-q:a", "6", ogg], check=True)


def decode(path):
    raw = subprocess.run(["ffmpeg", "-loglevel", "error", "-i", path, "-f", "f32le", "-ac", "1",
                          "-ar", str(SR), "-"], check=True, capture_output=True).stdout
    return np.frombuffer(raw, dtype="<f4")


def probe_duration(path):
    out = subprocess.run(["ffprobe", "-v", "error", "-show_entries", "format=duration",
                          "-of", "default=nw=1:nk=1", path], capture_output=True, text=True).stdout
    return float(out.strip())


def check(names):
    """Decode every OGG and assert: no clipping, not silent, no DC offset, sensible length."""
    print(f"{'file':<20}{'sec':>7}{'peak dB':>9}{'rms dB':>8}{'dc':>9}  status")
    bad = 0
    for name in names:
        p = os.path.join(OUT, name + ".ogg")
        dur = probe_duration(p)
        y = decode(p)[:int(round(dur * SR))]  # ffmpeg's raw decode can run past the end mark
        peak = 20 * np.log10(np.abs(y).max() + 1e-12)
        rms = 20 * np.log10(np.sqrt(np.mean(y ** 2)) + 1e-12)
        dc = float(np.mean(y))
        problems = []
        if peak > -0.1:
            problems.append("CLIPPING")
        if peak < -20:
            problems.append("SILENT")
        if abs(dc) > 0.005:
            problems.append("DC")
        if abs(y[-1]) > 0.01:
            problems.append("CLICK-AT-END")
        bad += bool(problems)
        print(f"{name:<20}{dur:>7.3f}{peak:>9.2f}{rms:>8.1f}{dc:>9.5f}  {', '.join(problems) or 'ok'}")
    return bad


def sheet(names, path):
    import matplotlib
    matplotlib.use("Agg")
    import matplotlib.pyplot as plt
    cols = 4
    rows = int(np.ceil(len(names) / cols))
    fig, axes = plt.subplots(rows, cols, figsize=(cols * 4.2, rows * 2.6))
    for ax, name in zip(axes.flat, names):
        p = os.path.join(OUT, name + ".ogg")
        y = decode(p)[:int(round(probe_duration(p) * SR))]
        n, hop = 1024, 128
        win = np.hanning(n)
        y2 = np.concatenate([np.zeros(n // 2), y, np.zeros(n)])
        fr = [np.abs(np.fft.rfft(y2[i:i + n] * win)) for i in range(0, len(y2) - n, hop)]
        S = 20 * np.log10(np.array(fr).T + 1e-9)
        S -= S.max()
        ax.imshow(np.clip(S, -80, 0), origin="lower", aspect="auto", cmap="magma",
                  extent=[0, len(y) / SR, 0, SR / 2000])
        tw = np.arange(len(y)) / SR
        ax.plot(tw, 11 + 10 * y, color="cyan", lw=0.4)  # waveform overlay
        ax.set_ylim(0, 22)
        ax.set_title(f"{name}  ({len(y) / SR:.2f}s)", fontsize=9)
        ax.tick_params(labelsize=6)
    for ax in list(axes.flat)[len(names):]:
        ax.axis("off")
    fig.supylabel("kHz (waveform overlaid in cyan)")
    fig.tight_layout()
    fig.savefig(path, dpi=110)
    print("sheet:", path)


def write_readme():
    lines = ["# Huzz Valley sound effects", "",
             "Made from scratch by `tools/sfx/make_sfx.py` (pure synthesis, no samples, no one else's audio).",
             "Rebuild: `python3 huzz-valley/tools/sfx/make_sfx.py` (needs numpy + ffmpeg).", "",
             "All files: mono OGG, 44.1 kHz, peak about -1 dBFS. One family: C major pentatonic,",
             "same soft bell/marimba/brass voices, same small room reverb.", "",
             "To use in Roblox: upload each .ogg (Creator Hub or Studio Asset Manager), then put the",
             "`rbxassetid://` number in the game's sound list. Quiet ones (`ui_hover`, `step`,",
             "`roulette_tick`) are meant for Volume about 0.2-0.4.", "",
             "| File | Seconds | What it is |", "|---|---|---|"]
    for name, (_, desc) in SOUNDS.items():
        p = os.path.join(OUT, name + ".ogg")
        if os.path.exists(p):
            lines.append(f"| `{name}.ogg` | {probe_duration(p):.2f} | {desc} |")
    with open(os.path.join(OUT, "README.md"), "w") as f:
        f.write("\n".join(lines) + "\n")


def main(argv):
    sheet_path = None
    if "--sheet" in argv:
        i = argv.index("--sheet")
        sheet_path = argv[i + 1]
        argv = argv[:i] + argv[i + 2:]
    names = argv or list(SOUNDS)
    os.makedirs(OUT, exist_ok=True)
    with tempfile.TemporaryDirectory() as tmp:
        for name in names:
            fn, _ = SOUNDS[name]
            x = fn()
            wav = os.path.join(tmp, name + ".wav")
            write_wav(wav, x)
            to_ogg(wav, os.path.join(OUT, name + ".ogg"))
    write_readme()
    bad = check(list(SOUNDS))
    if sheet_path:
        sheet(list(SOUNDS), sheet_path)
    sys.exit(1 if bad else 0)


if __name__ == "__main__":
    main(sys.argv[1:])

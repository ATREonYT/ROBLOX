#!/usr/bin/env python3
"""Huzz Valley sound effects generator.

Every sound is synthesized here from scratch (no samples, nobody else's audio),
so the whole set can be rebuilt or tweaked any time.

    python3 huzz-valley/tools/sfx/make_sfx.py            # build all sounds + preview + check
    python3 huzz-valley/tools/sfx/make_sfx.py coin dash  # build only these (preview + check still cover all)
    python3 huzz-valley/tools/sfx/make_sfx.py --sheet out.png   # also draw spectrograms

Needs: python3 + numpy, and ffmpeg/ffprobe on PATH. matplotlib only for --sheet.
Output: huzz-valley/assets/sfx/<name>.ogg (mono, 44.1 kHz, Vorbis q6) + README.md,
        huzz-valley/docs/previews/sfx-preview.ogg (every sound in a row, at its in-game level).

Family rules (owner: "not some random high pitch sounds"; keep new sounds in this family):
  * Warm and musical, like a polished simulator game. Most energy between 150 Hz and 2 kHz;
    nothing piercing: no square waves, no bare sine pings above ~2.5 kHz as the main tone.
  * Notes come from C major pentatonic (C D E G A), mostly C4-G5; sparkles go up to G6.
  * Voices: soft pluck (kalimba), mallet (marimba), e-piano bell, soft horn, warm pad,
    woody tick, felt thunk, filtered-noise whoosh. One shared small room reverb.
  * Soft attacks (2-6 ms, never a click), short tails, gentle low-pass on everything.
  * Peak -3 dBFS, and the loudest 50 ms of every sound is capped at the same level
    (LOUD_DB) so nothing jumps out; Gameplay/Sfx LEVEL sets the in-game mix.
  * check() prints peak, RMS, loudness and spectral centroid (the "brightness") per file.
"""
import os
import re
import subprocess
import sys
import tempfile
import wave

import numpy as np

SR = 44100
HERE = os.path.dirname(os.path.abspath(__file__))
GAME = os.path.normpath(os.path.join(HERE, "..", ".."))
OUT = os.path.join(GAME, "assets", "sfx")
PREVIEW = os.path.join(GAME, "docs", "previews", "sfx-preview.ogg")
SFX_LUA = os.path.join(GAME, "src", "StarterPlayer", "StarterPlayerScripts", "HuzzClient", "Gameplay", "Sfx.lua")
PEAK_DB = -3.0      # every file peaks here
LOUD_DB = -14.0     # cap on the loudest 50 ms (rough ear-weighted RMS), keeps the set even
BRIGHT_HZ = 2500    # centroid above this gets flagged "bright"

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


def _f(n):
    return hz(n) if isinstance(n, str) else float(n)


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
        k = min(n, int(0.004 * SR))  # never cut a layer off mid-wave (that clicks)
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


def env(dur, attack=0.004, decay=0.2, hold=0.0):
    """Smooth attack -> optional hold -> exponential decay with time constant `decay`."""
    t = tt(dur)
    a = np.clip(t / max(attack, 1e-5), 0, 1)
    a = np.sin(a * np.pi / 2) ** 2
    d = np.exp(-np.clip(t - attack - hold, 0, None) / decay)
    return a * d


def fade(x, fin=0.002, fout=0.02):
    x = x.copy()
    ni, no = int(fin * SR), int(fout * SR)
    if ni:
        x[:ni] *= np.sin(np.linspace(0, np.pi / 2, ni)) ** 2
    if no:
        x[-no:] *= np.cos(np.linspace(0, np.pi / 2, no)) ** 2
    return x


def norm(x, peak=1.0):
    return x / (np.abs(x).max() + 1e-12) * peak


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


def _band(f, fc, octaves):
    lf = np.log2(np.maximum(f, 1) / fc)
    return np.exp(-0.5 * (lf / (octaves / 2.355)) ** 2)


def bandpass(x, fc, octaves=1.0):
    return _fft_filter(x, lambda f: _band(f, fc, octaves))


def stft_shape(x, gain_fn, n=1024, hop=256):
    """Time-varying filter: gain_fn(freqs, t_sec) -> gain per bin for that frame."""
    win = np.hanning(n)
    pad = np.concatenate([np.zeros(n), x, np.zeros(n)])
    frames = (len(pad) - n) // hop + 1
    out = np.zeros(len(pad))
    nrm = np.zeros(len(pad))
    f = np.fft.rfftfreq(n, 1 / SR)
    for k in range(frames):
        s = k * hop
        seg = pad[s:s + n] * win
        tc = (s + n / 2 - n) / SR
        y = np.fft.irfft(np.fft.rfft(seg) * gain_fn(f, tc), n) * win
        out[s:s + n] += y
        nrm[s:s + n] += win ** 2
    out /= np.maximum(nrm, 1e-6)
    return out[n:n + len(x)]


def sweep_noise(dur, f_curve, octaves=1.2, seed=0):
    """Noise through a band-pass whose centre follows f_curve(t_normalized 0..1)."""
    rng = np.random.default_rng(seed)
    x = rng.standard_normal(int(round(dur * SR)))
    return stft_shape(x, lambda f, tc: _band(f, f_curve(np.clip(tc / dur, 0, 1)), octaves))


# ---------------------------------------------------------------- the shared room
def _make_room(seconds=1.0, seed=7):
    rng = np.random.default_rng(seed)
    t = tt(seconds)
    n = rng.standard_normal(len(t))
    lo = lowpass(n, 2200) * np.exp(-t / 0.22)       # warm body
    hi = highpass(n, 2200) * np.exp(-t / 0.07)      # air dies quickly (no hiss)
    ir = lo + 0.3 * hi
    ir *= np.clip(t / 0.01, 0, 1)
    for d, g in [(0.011, 0.5), (0.019, 0.35), (0.027, 0.3), (0.041, 0.2)]:
        ir[int(d * SR)] += g * 6                     # early reflections
    return ir / np.sqrt(np.sum(ir ** 2))


ROOM_IR = _make_room()


def reverb(x, wet=0.12, tail=0.0):
    """Add the shared room. tail = seconds of extra length to keep."""
    y = np.concatenate([x, np.zeros(int(tail * SR))])
    n = len(y) + len(ROOM_IR)
    pad = 1 << int(np.ceil(np.log2(n)))
    w = np.fft.irfft(np.fft.rfft(y, pad) * np.fft.rfft(ROOM_IR, pad), pad)[:len(y)]
    w = lowpass(highpass(w, 200), 4000)  # no mud, no fizz
    dry_rms = np.sqrt(np.mean(y ** 2)) + 1e-9
    wet_rms = np.sqrt(np.mean(w ** 2)) + 1e-9
    return y + wet * w * dry_rms / wet_rms


# ---------------------------------------------------------------- instruments (all soft-edged)
def sine(freq, dur):
    f = np.full(int(round(dur * SR)), float(freq)) if np.isscalar(freq) else freq
    return np.sin(phase(f))


def pluck(freq, dur=0.6, decay=0.22, attack=0.004, bright=0.4):
    """Kalimba / music-box pluck: round sine body, a little 2nd/3rd that fades fast."""
    t = tt(dur)
    pc = 2 * np.pi * _f(freq) * t
    y = (np.sin(pc)
         + bright * np.sin(2 * pc) * np.exp(-t / (decay * 0.35))
         + 0.35 * bright * np.sin(3 * pc) * np.exp(-t / (decay * 0.15)))
    return y * env(dur, attack, decay)


def mallet(freq, dur=0.4, decay=0.12, attack=0.003):
    """Marimba: sine bar with its 3.93x overtone that is gone within ~20 ms."""
    t = tt(dur)
    pc = 2 * np.pi * _f(freq) * t
    y = np.sin(pc) + 0.22 * np.sin(3.93 * pc) * np.exp(-t / (decay * 0.18))
    return y * env(dur, attack, decay)


def ebell(freq, dur=0.8, decay=0.35, attack=0.004, index=1.1):
    """Electric-piano bell: harmonic FM (ratio 1) whose brightness fades fast -> round, not piercing."""
    t = tt(dur)
    pc = 2 * np.pi * _f(freq) * t
    I = index * np.exp(-t / 0.05) + 0.12
    return np.sin(pc + I * np.sin(pc)) * env(dur, attack, decay)


def warm(freq, dur, attack=0.01, decay=0.3, hold=0.0, vib=0.0):
    """Soft mellow tone (sine + a little 2nd/3rd). freq may be a curve."""
    t = tt(dur)
    f = np.full(len(t), _f(freq)) if np.isscalar(freq) or isinstance(freq, str) else np.asarray(freq, float)
    f = f * (1 + vib * np.sin(2 * np.pi * 5 * t) * np.clip((t - 0.08) / 0.25, 0, 1))
    pc = phase(f)
    y = np.sin(pc) + 0.3 * np.sin(2 * pc) + 0.08 * np.sin(3 * pc)
    return y * env(dur, attack, decay, hold)


def horn(freq, dur, attack=0.03, decay=0.4, hold=0.0, scoop=0.02):
    """Soft brass: few harmonics, they open a little with the attack, slight scoop into the note."""
    t = tt(dur)
    e = env(dur, attack, decay, hold)
    f = _f(freq) * 2 ** (-scoop * np.exp(-t / 0.03))
    pc = phase(f)
    b = 1.2 + 2.3 * (e / (e.max() + 1e-9)) ** 0.7
    y = np.zeros(len(t))
    for k in range(1, 9):
        y += (1 / k) * np.exp(-(k - 1) / b) * np.sin(k * pc)
    return lowpass(y * e, 2600)


def pad(notes, dur, attack=0.06, decay=0.5, hold=0.0, detune=0.003):
    """Warm chord, each note two slightly detuned voices (a gentle chorus)."""
    out = buf(dur)
    for n in notes:
        for d in (-detune, detune):
            out += warm(_f(n) * (1 + d), dur, attack, decay, hold)
    return out / (2 * len(notes))


def woodtick(freq=850, dur=0.07, decay=0.018, seed=11):
    """Woodblock tick: a short wooden 'tok' with a pitch, plus a soft felt contact."""
    t = tt(dur)
    y = (np.sin(2 * np.pi * freq * t)
         + 0.45 * np.sin(2 * np.pi * freq * 2.57 * t) * np.exp(-t / (decay * 0.4)))
    y *= env(dur, 0.0015, decay)
    rng = np.random.default_rng(seed)
    n = bandpass(rng.standard_normal(len(t)), freq * 1.5, 1.5) * env(dur, 0.0006, 0.004)
    return y + 0.3 * norm(n)


def thunk(f0=180, f1=75, dur=0.2, decay=0.06, seed=12):
    """Felt thunk: a short low drop in pitch with a muffled contact."""
    t = tt(dur)
    pc = phase(glide(f0, f1, dur, 3.0))
    y = (np.sin(pc) + 0.3 * np.sin(2 * pc) * np.exp(-t / 0.02)) * env(dur, 0.002, decay)
    rng = np.random.default_rng(seed)
    n = lowpass(rng.standard_normal(len(t)), 1100) * env(dur, 0.0008, 0.007)
    return y + 0.25 * norm(n)


def whoosh(dur, f0, f1, peak=0.45, octaves=1.3, seed=0, lp=4000):
    """Filtered-noise whoosh: band sweeps f0 -> f1 (or follows f0 when it's a function), swells then fades."""
    curve = f0 if callable(f0) else (lambda u: f0 * (f1 / f0) ** u)
    x = sweep_noise(dur, curve, octaves, seed)
    u = np.linspace(0, 1, len(x))
    rise = np.sin(np.pi / 2 * np.clip(u / peak, 0, 1)) ** 2
    v = np.clip((u - peak) / (1 - peak), 0, 1)
    e = rise * (1 - v) ** 1.6
    return norm(lowpass(x * e, lp))


def twinkle(dst, notes, at, gap=0.06, level=0.25, decay=0.13):
    """A little run of soft bell notes on top (the 'sparkle')."""
    for i, n in enumerate(notes):
        add(dst, ebell(n, decay * 5, decay=decay, index=0.8, attack=0.003), at + i * gap, level * 0.88 ** i)
    return dst


def boing(f0, f1, dur, wobble=0.22, rate=13, decay=0.15):
    """Cartoon spring: a warm tone gliding f0 -> f1 with a wobble that settles."""
    t = tt(dur)
    f = glide(f0, f1, dur, 1.5) * (1 + wobble * np.sin(2 * np.pi * rate * t) * np.exp(-t / 0.1))
    return warm(f, dur, 0.004, decay)


def saturate(x, drive=1.2):
    m = np.abs(x).max() + 1e-12
    return np.tanh(drive * x / m) / np.tanh(drive)


def loudness_db(x):
    """Loudest 50 ms, RMS after a rough ear weighting (lows count less)."""
    w = highpass(x, 200, order=1)
    n = int(0.05 * SR)
    if len(w) < n:
        w = np.concatenate([w, np.zeros(n - len(w))])
    c = np.convolve(w ** 2, np.ones(n) / n, "valid")
    return 10 * np.log10(c.max() + 1e-12)


def level(x):
    """Peak to PEAK_DB, then pull down if the loudest 50 ms is over LOUD_DB."""
    x = x / (np.abs(x).max() + 1e-12) * 10 ** (PEAK_DB / 20)
    over = loudness_db(x) - LOUD_DB
    return x * 10 ** (-over / 20) if over > 0 else x


def finish(x, dur, lp=6000, drive=1.2, fout=0.02):
    """Trim/pad to dur, gentle low-pass, soften, no DC, smooth ends, level."""
    n = int(round(dur * SR))
    x = np.concatenate([x, np.zeros(max(0, n - len(x)))])[:n]
    x = highpass(x, 40, order=2)
    x = lowpass(x, lp, order=2)
    x = saturate(x, drive)
    x = x - np.mean(x)
    return level(fade(x, 0.002, fout))


# ================================================================== the sounds
SOUNDS = {}
LOOPS = set()


def sound(name, desc, loop=False):
    def deco(fn):
        SOUNDS[name] = (fn, desc)
        if loop:
            LOOPS.add(name)
        return fn
    return deco


# ---------------- UI
def tock(f0, f1, dur, decay=0.014, sub=0.5, partial=0.1):
    """Soft rounded 'tock' (the premium UI family, Oct 18): a round sine body that drops a little in pitch as it
    sounds (a felt mallet on wood / a soft bubble pop), a low body underneath and a faint 2nd partial that is gone in
    ~5 ms so the press reads clearly without any noise or tick. Clean 2 ms attack, nothing above ~3 kHz."""
    x = sine(glide(f0, f1, dur, 3.0), dur) * env(dur, 0.002, decay)
    if sub:
        add(x, sine(glide(f0 * 0.32, f1 * 0.27, dur, 2.0), dur) * env(dur, 0.002, decay * 1.4), 0, sub)
    if partial:
        add(x, sine(glide(f0 * 2.01, f1 * 2.0, dur, 3.0), dur) * env(dur, 0.0015, 0.005), 0, partial)
    return x


@sound("ui_click", "Soft rounded 'tock' for button presses: short, clean, no harsh highs (owner, Oct 18: \"the clicking sounds ... sound glitchy, and dont feel too premium\").")
def ui_click():
    d = 0.075
    x = tock(760, 560, d, decay=0.014, sub=0.5, partial=0.1)
    return finish(x, d, lp=3000, drive=1.0, fout=0.022)


@sound("ui_hover", "The click's little sister: a tiny, very soft higher tock for hovering over buttons.")
def ui_hover():
    d = 0.05
    x = tock(940, 760, d, decay=0.008, sub=0.0, partial=0.06)
    return finish(x, d, lp=2800, drive=1.0, fout=0.018)


@sound("ui_open", "Two soft tocks stepping up (C5 then G5) as a panel opens; same voice as the click.")
def ui_open():
    d = 0.17
    x = buf(d)
    add(x, tock(hz("C5") * 1.12, hz("C5"), 0.08, decay=0.014, sub=0.35), 0.0, 0.75)
    add(x, tock(hz("G5") * 1.12, hz("G5"), 0.1, decay=0.018, sub=0.3), 0.055, 0.9)
    return finish(reverb(x, 0.06), d, lp=3000, drive=1.0, fout=0.05)


@sound("ui_close", "Two soft tocks stepping down (G5 then C5) as a panel closes; same voice as the click.")
def ui_close():
    d = 0.16
    x = buf(d)
    add(x, tock(hz("G5") * 1.12, hz("G5"), 0.08, decay=0.012, sub=0.3), 0.0, 0.8)
    add(x, tock(hz("C5") * 1.12, hz("C5"), 0.1, decay=0.016, sub=0.35), 0.05, 0.8)
    return finish(reverb(x, 0.05), d, lp=2800, drive=1.0, fout=0.05)


@sound("ui_error", "Gentle low two-note 'nuh-uh' for a blocked action.")
def ui_error():
    d = 0.34
    x = buf(d)
    add(x, warm("D4", 0.12, attack=0.006, decay=0.045), 0.0, 0.8)
    add(x, warm(glide(hz("A3"), hz("A3") * 0.97, 0.2), 0.2, attack=0.006, decay=0.07), 0.12, 0.9)
    return finish(reverb(x, 0.08), d, lp=1800, fout=0.06)


# ---------------- rewards
@sound("coin", "Warm two-note coin chime (G5 then C6) on a soft kalimba body.")
def coin():
    d = 0.5
    x = buf(d)
    add(x, ebell("G5", 0.2, decay=0.05, index=0.9), 0.0, 0.7)
    add(x, ebell("C6", 0.45, decay=0.16, index=0.9), 0.065, 0.7)
    add(x, pluck("C5", 0.4, decay=0.14), 0.065, 0.45)
    return finish(reverb(x, 0.1), d, lp=5000, fout=0.08)


@sound("reward", "Rising kalimba arpeggio over a warm C major swell, with a soft sparkle.")
def reward():
    d = 1.0
    x = 0.4 * pad(["C4", "E4", "G4"], d, attack=0.08, decay=0.4)
    for i, n in enumerate(["C5", "E5", "G5", "C6"]):
        add(x, pluck(n, 0.6, decay=0.22), i * 0.07, 0.6)
    twinkle(x, ["E6", "G6"], 0.32, gap=0.08, level=0.22)
    return finish(reverb(x, 0.16), d, lp=5000, fout=0.2)


@sound("level_up", "Soft horn fanfare C-E-G onto a full C major chord, bells and a sparkle.")
def level_up():
    d = 1.35
    x = buf(d)
    for i, n in enumerate(["C4", "E4", "G4"]):
        add(x, horn(n, 0.16, attack=0.02, decay=0.07), i * 0.11, 0.6)
        add(x, ebell(n.replace("4", "5"), 0.3, decay=0.1), i * 0.11, 0.3)
    for n in ["C4", "E4", "G4", "C5"]:
        add(x, horn(n, 1.0, attack=0.03, decay=0.45, hold=0.18), 0.34, 0.35)
    add(x, 0.5 * pad(["C3", "G3"], 1.0, attack=0.04, decay=0.5), 0.34)
    add(x, ebell("C6", 0.8, decay=0.3), 0.34, 0.3)
    twinkle(x, ["E6", "G6", "C6", "E6"], 0.5, gap=0.07, level=0.18)
    return finish(reverb(x, 0.16), d, lp=5000, fout=0.25)


# ---------------- round flow
@sound("countdown_tick", "Woody marimba tick for 3-2-1.")
def countdown_tick():
    d = 0.18
    x = woodtick(880, d, decay=0.02)
    add(x, mallet("A4", d, decay=0.05), 0, 0.7)
    return finish(reverb(x, 0.06), d, lp=4500, fout=0.04)


@sound("countdown_go", "Warm horn chord with a soft thunk and whoosh for GO!")
def countdown_go():
    d = 0.8
    x = 0.25 * whoosh(0.35, 380, 1400, peak=0.7, seed=21, lp=3000)
    add(x, thunk(160, 70, 0.25), 0.3, 0.7)
    for n in ["C4", "E4", "G4", "C5"]:
        add(x, horn(n, 0.5, attack=0.015, decay=0.25, hold=0.08), 0.3, 0.45)
    add(x, ebell("G5", 0.5, decay=0.2), 0.3, 0.3)
    twinkle(x, ["C6", "E6"], 0.38, level=0.15)
    return finish(reverb(x, 0.14), d, lp=5000, fout=0.15)


@sound("roulette_tick", "Light woody tick for the hopping pick highlight (fine at 6+ per second).")
def roulette_tick():
    d = 0.06
    x = woodtick(1050, d, decay=0.012, seed=13)
    return finish(x, d, lp=4500, drive=1.0, fout=0.015)


@sound("pick_land", "Felt thunk with a warm two-bell chord when the pick lands.")
def pick_land():
    d = 0.8
    x = thunk(170, 70, 0.3)
    add(x, ebell("C5", 0.7, decay=0.3), 0.01, 0.5)
    add(x, ebell("G5", 0.7, decay=0.28), 0.01, 0.4)
    add(x, pluck("E5", 0.5, decay=0.18), 0.06, 0.35)
    twinkle(x, ["C6"], 0.13, level=0.15)
    return finish(reverb(x, 0.14), d, lp=5000, fout=0.15)


@sound("hero_chosen", "Soft heroic horn 'da-DAAA' onto a C major chord with a sparkle.")
def hero_chosen():
    d = 1.1
    x = buf(d)
    add(x, horn("G3", 0.15, attack=0.02, decay=0.07), 0.0, 0.6)
    add(x, thunk(150, 65, 0.25), 0.15, 0.45)
    for n in ["C4", "E4", "G4"]:
        add(x, horn(n, 0.9, attack=0.03, decay=0.4, hold=0.22), 0.15, 0.45)
    add(x, warm("C3", 0.9, attack=0.03, decay=0.4, hold=0.15), 0.15, 0.3)
    twinkle(x, ["C6", "E6", "G6"], 0.32, gap=0.08, level=0.16)
    return finish(reverb(x, 0.16), d, lp=4800, fout=0.2)


@sound("chicken_chosen", "Playful two-note bounce and a cartoon spring 'boing' (you are the Chicken).")
def chicken_chosen():
    d = 0.7
    x = buf(d)
    add(x, mallet("A4", 0.15, decay=0.05), 0.0, 0.7)
    add(x, mallet("E4", 0.15, decay=0.05), 0.1, 0.7)
    add(x, boing(200, 300, 0.45, wobble=0.18, rate=12, decay=0.14), 0.2, 0.8)
    return finish(reverb(x, 0.1), d, lp=3500, fout=0.12)


# ---------------- moves and hits
@sound("dash", "Airy filtered-noise whoosh for the dash.")
def dash():
    d = 0.32
    x = whoosh(0.3, lambda u: 650 * 2.6 ** np.sin(np.pi * 0.85 * u), None, peak=0.35, octaves=1.5, seed=31,
               lp=3800)
    add(x, whoosh(0.3, 260, 420, peak=0.3, octaves=1.2, seed=32, lp=1200), 0, 0.35)
    return finish(x, d, lp=4000, fout=0.04)


@sound("stab", "Quick soft swish with a light woody tap.")
def stab():
    d = 0.2
    x = whoosh(0.16, 800, 2200, peak=0.55, octaves=1.0, seed=33, lp=4000)
    add(x, woodtick(700, 0.06, decay=0.014, seed=34), 0.11, 0.45)
    return finish(x, d, lp=4500, fout=0.03)


@sound("caught", "Cartoon thud and a sliding-down 'bwomp' (silly, not scary).")
def caught():
    d = 0.65
    x = thunk(150, 60, 0.3, decay=0.08)
    add(x, warm(glide(196, 118, 0.5, 1.2), 0.5, attack=0.01, decay=0.2, vib=0.02), 0.05, 0.7)
    return finish(reverb(x, 0.1), d, lp=1800, fout=0.12)


@sound("rescue", "Warm rising kalimba run over a soft chord for freeing a teammate.")
def rescue():
    d = 0.9
    x = 0.35 * pad(["C4", "E4", "G4"], d, attack=0.1, decay=0.35)
    for i, n in enumerate(["G4", "A4", "C5", "E5", "G5"]):
        add(x, pluck(n, 0.5, decay=0.2), i * 0.05, 0.55)
    twinkle(x, ["C6", "E6"], 0.3, level=0.16)
    return finish(reverb(x, 0.16), d, lp=5000, fout=0.2)


@sound("safe", "Happy two-step bell chime with a soft chord for reaching the safe side.")
def safe():
    d = 0.8
    x = 0.3 * pad(["C4", "G4"], d, attack=0.04, decay=0.35)
    add(x, ebell("C5", 0.6, decay=0.22), 0.0, 0.5)
    add(x, ebell("E5", 0.6, decay=0.22), 0.0, 0.4)
    add(x, ebell("G5", 0.7, decay=0.28), 0.1, 0.55)
    twinkle(x, ["C6"], 0.2, level=0.15)
    return finish(reverb(x, 0.14), d, lp=5000, fout=0.18)


@sound("round_win", "Bouncy little victory tune ending on a warm C major chord with sparkles.")
def round_win():
    d = 1.9
    x = buf(d)
    tune = [("G4", 0.0), ("C5", 0.1), ("E5", 0.2), ("G5", 0.3), ("E5", 0.42), ("G5", 0.52)]
    for n, at in tune:
        add(x, ebell(n, 0.4, decay=0.14), at, 0.45)
        add(x, pluck(n, 0.4, decay=0.12), at, 0.35)
    add(x, pad(["C4", "E4", "G4", "C5"], 1.2, attack=0.03, decay=0.55, hold=0.25), 0.7, 0.9)
    for n in ["C4", "E4", "G4"]:
        add(x, horn(n, 1.1, attack=0.02, decay=0.5, hold=0.25), 0.7, 0.3)
    add(x, ebell("C6", 0.9, decay=0.35), 0.7, 0.25)
    twinkle(x, ["E6", "G6", "C6", "E6", "G6"], 0.82, gap=0.09, level=0.14)
    return finish(reverb(x, 0.18), d, lp=5000, fout=0.3)


@sound("round_lose", "Soft, sympathetic four-note fall (E-D-C-A), gentle and warm.")
def round_lose():
    d = 1.3
    x = buf(d)
    for i, n in enumerate(["E4", "D4", "C4"]):
        add(x, warm(n, 0.3, attack=0.012, decay=0.12), i * 0.2, 0.6)
    add(x, warm("A3", 0.7, attack=0.015, decay=0.3, hold=0.1, vib=0.006), 0.6, 0.7)
    add(x, 0.5 * pad(["A2", "E3"], 0.7, attack=0.05, decay=0.35), 0.6)
    return finish(reverb(x, 0.16), d, lp=2000, fout=0.25)


@sound("step", "Very soft footstep puff (plays often, at low volume).")
def step():
    d = 0.09
    rng = np.random.default_rng(41)
    x = lowpass(rng.standard_normal(int(d * SR)), 700) * env(d, 0.003, 0.02)
    x = norm(x)
    add(x, thunk(110, 60, d, decay=0.02), 0, 0.5)
    return finish(x, d, lp=1800, drive=1.0, fout=0.02)


@sound("heart_shield", "Bubbly pop and a soft, gently pulsing shield chord.")
def heart_shield():
    d = 0.8
    x = buf(d)
    add(x, sine(glide(300, 700, 0.07, 1.5), 0.07) * env(0.07, 0.003, 0.03), 0, 0.7)
    t = tt(0.72)
    trem = 1 - 0.25 * (0.5 - 0.5 * np.cos(2 * np.pi * 7 * t))
    add(x, pad(["C5", "E5", "G5"], 0.72, attack=0.06, decay=0.3) * trem, 0.05, 1.2)
    twinkle(x, ["C6", "G6"], 0.12, gap=0.1, level=0.18)
    return finish(reverb(x, 0.16), d, lp=5000, fout=0.18)


@sound("power_rush", "Rising whoosh with a warm upward glide for a speed boost.")
def power_rush():
    d = 0.65
    x = 0.6 * whoosh(0.55, 400, 1800, peak=0.75, seed=51, lp=3500)
    add(x, warm(glide(hz("C4"), hz("C5"), 0.45, 1.0), 0.45, attack=0.04, decay=0.25, hold=0.2), 0.05, 0.5)
    add(x, ebell("G5", 0.3, decay=0.12), 0.45, 0.35)
    return finish(reverb(x, 0.1), d, lp=4500, fout=0.12)


# ---------------- spin wheel, Aura, traps, knock-downs
@sound("spin_tick", "Wooden peg click for the spin wheel (fine at 10+ per second).")
def spin_tick():
    d = 0.06
    x = woodtick(720, d, decay=0.014, seed=61)
    add(x, thunk(300, 200, d, decay=0.01), 0, 0.3)
    return finish(x, d, lp=4000, drive=1.0, fout=0.015)


@sound("spin_win", "Bright-but-warm kalimba arpeggio and bell for a spin prize.")
def spin_win():
    d = 0.9
    x = 0.3 * pad(["C4", "E4", "G4"], d, attack=0.04, decay=0.3)
    for i, n in enumerate(["C5", "E5", "G5"]):
        add(x, pluck(n, 0.5, decay=0.18), i * 0.06, 0.55)
    add(x, ebell("C6", 0.6, decay=0.25), 0.18, 0.4)
    twinkle(x, ["E6", "G6"], 0.26, gap=0.06, level=0.15)
    return finish(reverb(x, 0.15), d, lp=5000, fout=0.2)


@sound("spin_big_win", "Big prize: thunk, rising run, full warm chord and a shower of soft sparkles.")
def spin_big_win():
    d = 1.75
    x = 0.3 * whoosh(0.42, 300, 1500, peak=0.85, seed=71, lp=3000)
    add(x, thunk(170, 60, 0.3), 0.38, 0.7)
    for i, n in enumerate(["C4", "E4", "G4", "C5", "E5", "G5"]):
        add(x, pluck(n, 0.5, decay=0.18), i * 0.055, 0.45)
    add(x, pad(["C4", "E4", "G4", "C5"], 1.3, attack=0.03, decay=0.55, hold=0.3), 0.38, 0.9)
    for n in ["C4", "G4", "C5"]:
        add(x, horn(n, 1.2, attack=0.02, decay=0.5, hold=0.3), 0.38, 0.3)
    twinkle(x, ["C6", "E6", "G6", "E6", "G6", "C6", "E6", "G6"], 0.46, gap=0.085, level=0.14)
    return finish(reverb(x, 0.2), d, lp=5000, fout=0.3)


@sound("lunge", "Heavier, deeper whoosh with a low push for the catcher's lunge.")
def lunge():
    d = 0.42
    x = whoosh(0.4, 380, 1200, peak=0.3, octaves=1.6, seed=81, lp=3200)
    add(x, thunk(120, 60, 0.25, decay=0.07), 0.0, 0.45)
    return finish(x, d, lp=3500, fout=0.05)


@sound("trap_set", "Soft wooden click-clack as a trap is set down.")
def trap_set():
    d = 0.32
    x = buf(d)
    add(x, woodtick(620, 0.08, decay=0.016, seed=91), 0.0, 0.8)
    add(x, woodtick(900, 0.08, decay=0.014, seed=92), 0.085, 0.7)
    add(x, thunk(200, 110, 0.15, decay=0.035), 0.085, 0.5)
    return finish(reverb(x, 0.08), d, lp=4000, fout=0.06)


@sound("trap_snap", "Woody snap with a low thump and a springy wobble when a trap catches someone.")
def trap_snap():
    d = 0.5
    x = woodtick(950, 0.1, decay=0.022, seed=93)
    add(x, thunk(200, 70, 0.25, decay=0.06), 0.0, 0.8)
    add(x, boing(330, 210, 0.35, wobble=0.15, rate=16, decay=0.1), 0.03, 0.4)
    return finish(reverb(x, 0.1), d, lp=4000, fout=0.1)


@sound("knock_down", "Cartoon fall: soft heavy thud, dust puff and a sliding-down tone.")
def knock_down():
    d = 0.65
    x = thunk(130, 45, 0.4, decay=0.11)
    rng = np.random.default_rng(101)
    puff = norm(lowpass(rng.standard_normal(int(0.3 * SR)), 600)) * env(0.3, 0.004, 0.07)
    add(x, puff, 0.0, 0.35)
    add(x, warm(glide(330, 160, 0.35, 1.3), 0.35, attack=0.008, decay=0.12), 0.04, 0.35)
    return finish(reverb(x, 0.1), d, lp=2000, fout=0.12)


@sound("revive", "Gentle rising swell into a warm chord and kalimba run when someone gets back up.")
def revive():
    d = 1.05
    x = 0.25 * whoosh(0.5, 300, 1200, peak=0.85, seed=111, lp=2800)
    add(x, pad(["C4", "E4", "G4", "A4"], 0.9, attack=0.25, decay=0.3), 0.05, 0.9)
    for i, n in enumerate(["C5", "E5", "G5", "C6"]):
        add(x, pluck(n, 0.45, decay=0.18), 0.35 + i * 0.06, 0.45)
    twinkle(x, ["E6", "G6"], 0.6, level=0.13)
    return finish(reverb(x, 0.18), d, lp=5000, fout=0.2)


@sound("aura_pickup", "Satisfying thunk plus a bell and sparkle run for grabbing Aura.")
def aura_pickup():
    d = 0.8
    x = thunk(190, 80, 0.25)
    add(x, ebell("G5", 0.5, decay=0.2), 0.02, 0.5)
    add(x, ebell("C6", 0.6, decay=0.24), 0.08, 0.45)
    add(x, pluck("C5", 0.4, decay=0.15), 0.02, 0.4)
    twinkle(x, ["E6", "G6", "C7"], 0.14, gap=0.06, level=0.14)
    return finish(reverb(x, 0.14), d, lp=5000, fout=0.18)


@sound("speed_wind", "Soft wind bed for running fast (2 s, loops seamlessly; play it with Sfx.loop).", loop=True)
def speed_wind():
    # Everything here is periodic over exactly 2 s (circular FFT filters, LFOs with whole cycles),
    # so the end flows straight back into the start.
    n = 2 * SR
    rng = np.random.default_rng(121)
    f = np.fft.rfftfreq(n, 1 / SR)
    tilt = 1 / np.sqrt(np.maximum(f, 20) / 100)                     # pink-ish: softer highs

    def band(fc, octaves, seed):
        X = np.fft.rfft(np.random.default_rng(seed).standard_normal(n))
        return norm(np.fft.irfft(X * _band(f, fc, octaves) * tilt, n))
    t = np.arange(n) / SR
    lfo = 0.5 - 0.5 * np.cos(2 * np.pi * 1.0 * t / 2.0)              # one slow gust per loop
    lfo2 = 0.5 - 0.5 * np.cos(2 * np.pi * 3.0 * t / 2.0)
    x = band(420, 2.2, 122) * (0.75 + 0.25 * lfo)
    x += 0.5 * band(950, 1.4, 123) * (0.4 + 0.6 * lfo2 * lfo)        # a faint whistle that comes and goes
    x += 0.2 * band(1800, 1.2, 124) * lfo
    del rng
    x = x - np.mean(x)
    return level(norm(x))


@sound("secret_riser", "The Secret girl's build-up: a dark hum and an airy whoosh rising together for 2.3 s into silence.")
def secret_riser():
    d = 2.3
    x = 0.5 * whoosh(d, 180, 3200, peak=0.92, octaves=1.1, seed=131, lp=5000)
    t = tt(d)
    hum = warm(glide(55, 110, d, 2.2), d, attack=0.4, decay=0.05, hold=d - 0.5, vib=0.004)
    add(x, hum * (0.6 + 0.4 * t / d), 0, 0.6)
    add(x, pad(["C4", "G4", "C5"], d, attack=1.6, decay=0.1, hold=0.4, detune=0.006), 0, 0.5)
    return finish(reverb(x, 0.2), d, lp=6000, fout=0.04)


@sound("secret_impact", "The Secret girl bursts out: a deep soft boom, a bright bell chord and sparkles (not harsh).")
def secret_impact():
    d = 2.2
    x = thunk(140, 38, 0.7, decay=0.25)
    add(x, 0.35 * whoosh(0.5, 2400, 300, peak=0.15, seed=132, lp=4000), 0, 1)
    for n in ["C5", "E5", "G5", "C6"]:
        add(x, ebell(n, 1.6, decay=0.6), 0.01, 0.3)
    add(x, pad(["C3", "G3", "C4", "E4"], 1.8, attack=0.02, decay=0.9, hold=0.2), 0.0, 0.7)
    twinkle(x, ["G6", "C7", "E6", "G6", "C7"], 0.1, gap=0.07, level=0.15)
    return finish(reverb(x, 0.28, tail=0.6), d, lp=6000, drive=1.1, fout=0.4)


@sound("secret_land", "She lands: a soft heavy thump with a shimmering ring spreading out.")
def secret_land():
    d = 1.2
    x = thunk(110, 40, 0.45, decay=0.14)
    add(x, 0.3 * whoosh(0.6, 900, 200, peak=0.1, seed=133, lp=2500), 0, 1)
    add(x, ebell("G5", 1.0, decay=0.4), 0.03, 0.25)
    twinkle(x, ["C6", "E6", "G6"], 0.1, gap=0.08, level=0.12)
    return finish(reverb(x, 0.22), d, lp=5000, fout=0.3)


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


def load(name):
    p = os.path.join(OUT, name + ".ogg")
    return decode(p)[:int(round(probe_duration(p) * SR))]  # ffmpeg's raw decode can run past the end mark


def centroid(y):
    X = np.abs(np.fft.rfft(y))
    f = np.fft.rfftfreq(len(y), 1 / SR)
    return float((X * f).sum() / (X.sum() + 1e-12))


def check(names):
    """Decode every OGG: no clipping, not silent, no DC, clean ends (or a clean loop seam); print brightness."""
    print(f"{'file':<16}{'sec':>6}{'peak':>7}{'rms':>7}{'loud':>7}{'centroid':>10}  status")
    bad = 0
    for name in names:
        y = load(name)
        peak = 20 * np.log10(np.abs(y).max() + 1e-12)
        rms = 20 * np.log10(np.sqrt(np.mean(y ** 2)) + 1e-12)
        cen = centroid(y)
        problems, notes = [], []
        if peak > -1.0:
            problems.append("TOO-HOT")
        if peak < -20:
            problems.append("SILENT")
        if abs(float(np.mean(y))) > 0.005:
            problems.append("DC")
        if name in LOOPS:
            step_ = np.abs(np.diff(y)).mean()
            if abs(float(y[-1] - y[0])) > 6 * step_:
                problems.append("LOOP-SEAM")
        elif abs(y[-1]) > 0.01:
            problems.append("CLICK-AT-END")
        if cen > BRIGHT_HZ:
            notes.append("bright")
        bad += bool(problems)
        print(f"{name:<16}{len(y) / SR:>6.2f}{peak:>7.1f}{rms:>7.1f}{loudness_db(y):>7.1f}{cen:>10.0f}  "
              f"{', '.join(problems + notes) or 'ok'}")
    return bad


def game_levels():
    """Each sound's in-game volume from Gameplay/Sfx.lua's LEVEL table (so the preview is the real mix)."""
    try:
        src = open(SFX_LUA).read()
        body = src[src.index("local LEVEL = {"):]
        body = body[:body.index("\n}")]
        return {k: float(v) for k, v in re.findall(r"(\w+)\s*=\s*\{\s*([\d.]+)", body)}
    except (OSError, ValueError):
        return {}


def make_preview(names, gap=0.45):
    """All sounds in a row at their in-game levels; returns {name: start second}."""
    lv = game_levels()
    top = max([lv.get(n, 0.5) for n in names] or [1])
    parts, starts, at = [np.zeros(int(0.3 * SR))], {}, 0.3
    for name in names:
        y = load(name).astype(float)
        if name in LOOPS:   # loop it twice, fade in/out so the preview shows it's seamless
            y = fade(np.tile(y, 2), 0.3, 0.3)
        y = y * lv.get(name, 0.5) / top
        starts[name] = at
        parts += [y, np.zeros(int(gap * SR))]
        at += len(y) / SR + gap
    x = np.concatenate(parts)
    os.makedirs(os.path.dirname(PREVIEW), exist_ok=True)
    with tempfile.TemporaryDirectory() as tmp:
        wav = os.path.join(tmp, "preview.wav")
        write_wav(wav, x)
        to_ogg(wav, PREVIEW)
    print(f"preview: {os.path.relpath(PREVIEW, GAME)} ({len(x) / SR:.1f} s)")
    return starts


def sheet(names, path):
    import matplotlib
    matplotlib.use("Agg")
    import matplotlib.pyplot as plt
    cols = 4
    rows = int(np.ceil(len(names) / cols))
    fig, axes = plt.subplots(rows, cols, figsize=(cols * 4.2, rows * 2.6))
    for ax, name in zip(axes.flat, names):
        y = load(name)
        n, hop = 1024, 128
        win = np.hanning(n)
        y2 = np.concatenate([np.zeros(n // 2), y, np.zeros(n)])
        fr = [np.abs(np.fft.rfft(y2[i:i + n] * win)) for i in range(0, len(y2) - n, hop)]
        S = 20 * np.log10(np.array(fr).T + 1e-9)
        S -= S.max()
        ax.imshow(np.clip(S, -80, 0), origin="lower", aspect="auto", cmap="magma",
                  extent=[0, len(y) / SR, 0, SR / 2000])
        ax.plot(np.arange(len(y)) / SR, 11 + 10 * y, color="cyan", lw=0.4)  # waveform overlay
        ax.set_ylim(0, 22)
        ax.set_title(f"{name}  ({len(y) / SR:.2f}s)", fontsize=9)
        ax.tick_params(labelsize=6)
    for ax in list(axes.flat)[len(names):]:
        ax.axis("off")
    fig.supylabel("kHz (waveform overlaid in cyan)")
    fig.tight_layout()
    fig.savefig(path, dpi=110)
    print("sheet:", path)


def write_readme(starts):
    lines = ["# Huzz Valley sound effects", "",
             "Made from scratch by `tools/sfx/make_sfx.py` (pure synthesis, no samples, no one else's audio).",
             "Rebuild: `python3 huzz-valley/tools/sfx/make_sfx.py` (needs numpy + ffmpeg).", "",
             "All files: mono OGG, 44.1 kHz, peak -3 dBFS, even loudness. One warm family: C major pentatonic,",
             "soft kalimba / marimba / bell / horn / pad voices, woody ticks, filtered-noise whooshes, one small room.",
             "", "Listen to all of them in one go: `docs/previews/sfx-preview.ogg` (in this order, at in-game",
             "volume; the \"Preview at\" column says where each one starts).", "",
             "To use in Roblox: upload them (steps in the game's README), then the IDs go in",
             "`Shared/Config/SoundIds.lua`. The game plays them through `Gameplay/Sfx`, which sets each one's",
             "volume. `speed_wind` is a loop: play it with `Sfx.loop`.", "",
             "| File | Seconds | Preview at | What it is |", "|---|---|---|---|"]
    for name, (_, desc) in SOUNDS.items():
        p = os.path.join(OUT, name + ".ogg")
        if os.path.exists(p):
            s = starts.get(name, 0)
            lines.append(f"| `{name}.ogg` | {probe_duration(p):.2f} | {int(s // 60)}:{s % 60:04.1f} | {desc} |")
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
            wav = os.path.join(tmp, name + ".wav")
            write_wav(wav, fn())
            to_ogg(wav, os.path.join(OUT, name + ".ogg"))
    every = list(SOUNDS)
    write_readme(make_preview(every))
    bad = check(every)
    if sheet_path:
        sheet(every, sheet_path)
    sys.exit(1 if bad else 0)


if __name__ == "__main__":
    main(sys.argv[1:])

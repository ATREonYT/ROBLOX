#!/usr/bin/env python3
"""Make the game's own footstep sounds (Oct 27, the owner: "make custom walking sounds or find them, so they actually
sound nice, not the original Roblox ones"). Synthesised here, so they are ours to upload: no licence questions.

  python3 hood/tools/sounds/make_footsteps.py            # writes hood/art/sounds/Step*.ogg and walk_demo.mp3

Two sets, three takes each (the game picks one at random and nudges its pitch, so no two steps sound the same):
  StepHard1-3  a sneaker on a hard floor (the lobby's painted plastic, streets, stages): a soft rounded "tock" with a
               light rubbery tap on top, warm (nothing above about 6 kHz), short (0.15 s);
  StepSoft1-3  a sneaker on grass, dirt or sand: a muffled thump and a short dry rustle.
walk_demo.mp3 is a few seconds of walking then running on each set, to judge them by ear.
Upload with hood/tools/upload_assets.py (it writes the ids into Shared/Config/Sound). Needs numpy, scipy and ffmpeg.
"""
import os
import subprocess
import sys
import tempfile
import wave

import numpy as np
from scipy import signal

RATE = 44100
HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.abspath(os.path.join(HERE, '..', '..', 'art', 'sounds'))


def env(n, attack, decay):
	t = np.arange(n) / RATE
	return np.minimum(t / attack, 1.0) * np.exp(-np.maximum(t - attack, 0) / decay)


def band(x, lo, hi):
	sos = signal.butter(2, [lo, hi], btype='band', fs=RATE, output='sos')
	return signal.sosfilt(sos, x)


def low(x, hz):
	return signal.sosfilt(signal.butter(2, hz, fs=RATE, output='sos'), x)


def hard(rng, k):
	n = int(0.15 * RATE)
	t = np.arange(n) / RATE
	f0 = 170 + 20 * k + rng.uniform(-8, 8)
	sweep = f0 * (0.55 + 0.45 * np.exp(-t / 0.02))  # the pitch drops as the sole settles: a rounded "tock"
	body = np.sin(2 * np.pi * np.cumsum(sweep) / RATE) * env(n, 0.002, 0.028)
	tap = np.sin(2 * np.pi * (430 + 30 * k) * t) * env(n, 0.001, 0.008) * 0.35
	grit = band(rng.standard_normal(n), 900, 3200) * env(n, 0.001, 0.012) * 0.18
	heel = np.zeros(n)  # the heel lands a hair before the toe
	d = int((0.022 + 0.004 * k) * RATE)
	heel[d:] = body[:n - d] * 0.35
	return low(body + tap + grit + heel, 6000)


def soft(rng, k):
	n = int(0.17 * RATE)
	thump = np.sin(2 * np.pi * (95 + 10 * k) * np.arange(n) / RATE) * env(n, 0.004, 0.03) * 0.8
	rustle = np.zeros(n)
	for _ in range(7):  # grass blades: a few tiny dry crackles over 60 ms
		s = int(rng.uniform(0.0, 0.06) * RATE)
		m = int(0.03 * RATE)
		burst = band(rng.standard_normal(m), 1200, 4500) * env(m, 0.001, 0.006) * rng.uniform(0.15, 0.35)
		rustle[s:s + m] += burst[:n - s]
	rustle += band(rng.standard_normal(n), 400, 2200) * env(n, 0.003, 0.03) * 0.25
	return low(thump + rustle, 5500)


def finish(x, peak=0.5):
	x = x - x.mean()
	fade = int(0.01 * RATE)
	x[-fade:] *= np.linspace(1, 0, fade)
	return x / np.abs(x).max() * peak


def write_wav(path, x):
	with wave.open(path, 'wb') as w:
		w.setnchannels(1)
		w.setsampwidth(2)
		w.setframerate(RATE)
		w.writeframes((np.clip(x, -1, 1) * 32767).astype('<i2').tobytes())


def encode(x, path, codec):
	with tempfile.TemporaryDirectory() as d:
		src = os.path.join(d, 'in.wav')
		write_wav(src, x)
		subprocess.run(['ffmpeg', '-v', 'error', '-y', '-i', src] + codec + [path], check=True)


def demo(sets):
	"""Walk (2 steps a second) then run (3.2 a second) on each set, each step a random take with a nudged pitch."""
	rng = np.random.default_rng(7)
	parts = []
	for takes in sets:
		for rate, count in ((2.0, 8), (3.2, 10)):
			gap = int(RATE / rate)
			track = np.zeros(gap * count + RATE // 4)
			for i in range(count):
				x = takes[rng.integers(len(takes))]
				speed = rng.uniform(0.92, 1.08)
				x = signal.resample(x, int(len(x) / speed))
				track[i * gap:i * gap + len(x)] += x * (0.8 if i % 2 else 1.0)
			parts.append(track)
		parts.append(np.zeros(RATE // 2))
	return np.concatenate(parts)


def main():
	os.makedirs(OUT, exist_ok=True)
	rng = np.random.default_rng(1027)
	sets = []
	for name, make in (('StepHard', hard), ('StepSoft', soft)):
		takes = [finish(make(rng, k)) for k in range(3)]
		for k, x in enumerate(takes):
			encode(x, os.path.join(OUT, '%s%d.ogg' % (name, k + 1)), ['-c:a', 'libvorbis', '-q:a', '6'])
		sets.append(takes)
	encode(demo(sets), os.path.join(OUT, 'walk_demo.mp3'), ['-c:a', 'libmp3lame', '-q:a', '3'])
	print('wrote', ' '.join(sorted(os.listdir(OUT))), 'in', OUT)


if __name__ == '__main__':
	sys.exit(main())

"""Estimate how a Config/Look change moves the colour stats of frames from the owner's recording.

A rough model, not a render (only Studio shows the real thing):
  1. undo the old colour grade (ColorCorrection brightness, contrast, saturation),
  2. go to linear light; pixels that were clipped are assumed to have been CLIP_OVER x brighter,
  3. scale the light by (new Brightness * sun * shift + ambient) / (old ...) and by the exposure change
     (2 ^ (new - old)), with a soft shoulder like a filmic tone curve,
  4. back to sRGB and apply the new grade.
Usage: python3 look_estimate.py <frames dir> [out.jpg]   (frames named like stats.py: our_17.5.png ...)
"""
import sys
import numpy as np
from PIL import Image

OLD = dict(bright=2.8, expo=0.15, cc_b=0.02, cc_c=0.14, cc_s=0.28, shift=(255, 246, 228))
NEW = dict(bright=2.0, expo=-0.1, cc_b=0.0, cc_c=0.12, cc_s=0.35, shift=(255, 250, 240))
SUN = 0.85   # cos of the sun angle on flat ground at ClockTime 14.2, latitude 28
AMB = 0.27   # OutdoorAmbient (138,140,156) in linear light
CLIP_OVER = 1.25
BOX = (0.08, 0.22, 0.94, 0.9)


def lin(c):
	return np.where(c <= 0.04045, c / 12.92, ((c + 0.055) / 1.055) ** 2.4)


def srgb(c):
	c = np.clip(c, 0, 1)
	return np.where(c <= 0.0031308, c * 12.92, 1.055 * c ** (1 / 2.4) - 0.055)


def luma(a):
	return (0.2126 * a[..., 0] + 0.7152 * a[..., 1] + 0.0722 * a[..., 2])[..., None]


def grade(a, p, inverse=False):
	if not inverse:
		a = a + p["cc_b"]
		a = (a - 0.5) * (1 + p["cc_c"]) + 0.5
		return luma(a) + (a - luma(a)) * (1 + p["cc_s"])
	a = luma(a) + (a - luma(a)) / (1 + p["cc_s"])
	a = (a - 0.5) / (1 + p["cc_c"]) + 0.5
	return a - p["cc_b"]


def relight(a, old, new):
	clipped = a.max(2, keepdims=True) > 0.98
	x = lin(np.clip(grade(a, old, True), 0, 1))
	x = np.where(clipped, x * CLIP_OVER, x)
	so, sn = np.array(old["shift"]) / 255, np.array(new["shift"]) / 255
	f = (new["bright"] * SUN * sn + AMB) / (old["bright"] * SUN * so + AMB) * 2 ** (new["expo"] - old["expo"])
	x = x * f
	x = np.where(x > 0.8, 0.8 + (x - 0.8) / (1 + (x - 0.8) * 2.5), x)  # soft shoulder
	return np.clip(grade(srgb(x), new), 0, 1)


def stats(a):
	mx, mn = a.max(2), a.min(2)
	return dict(sat=np.where(mx > 0, (mx - mn) / np.maximum(mx, 1e-6), 0).mean(), val=mx.mean(),
		contrast=luma(a).std(), clip=(mx > 0.98).mean())


def crop(p):
	a = np.asarray(Image.open(p).convert("RGB")).astype(float) / 255
	h, w, _ = a.shape
	return a[int(BOX[1] * h):int(BOX[3] * h), int(BOX[0] * w):int(BOX[2] * w)]


if __name__ == "__main__":
	d = sys.argv[1]
	groups = {"lobby": ["our_3", "our_5", "our_7"], "round": ["our_17.5", "our_18.5", "our_19.5", "our_21", "our_22"]}
	tiles = []
	for g, fs in groups.items():
		before, after = [], []
		for f in fs:
			a = crop(f"{d}/{f}.png")
			b = relight(a, OLD, NEW)
			before.append(stats(a))
			after.append(stats(b))
			if f in ("our_5", "our_18.5"):
				tiles.append(np.concatenate([a, b], 1))
		for name, ss in (("before", before), ("after", after)):
			m = {k: np.mean([s[k] for s in ss]) for k in ss[0]}
			print(f"{g:6s} {name:6s} " + " ".join(f"{k}={v:.3f}" for k, v in m.items()))
	if len(sys.argv) > 2:
		w = min(t.shape[1] for t in tiles)
		img = np.concatenate([t[:, :w] for t in tiles], 0)
		Image.fromarray((img * 255).astype(np.uint8)).resize((w // 2, img.shape[0] // 2)).save(sys.argv[2], quality=85)

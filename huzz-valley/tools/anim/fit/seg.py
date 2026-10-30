"""Colour labels for the reference clips (labels as r6fit: 0 nothing, 1 skin, 2 shoe, 3 backpack, 4 shirt, 5 other)."""
import numpy as np
from PIL import Image

def hsv(a):
    r, g, b = a[..., 0], a[..., 1], a[..., 2]
    mx = a.max(2); mn = a.min(2); d = np.maximum(mx - mn, 1e-6)
    h = np.where(mx == r, ((g - b) / d) % 6, np.where(mx == g, (b - r) / d + 2, (r - g) / d + 4)) * 60
    return h, mx - mn, mx

def balenci_catalog(path, W, H):
    """The catalog clip: grey room; brown skin, red shoes, pink backpack, teal shirt."""
    a = np.asarray(Image.open(path).convert("RGB").resize((W, H), Image.BILINEAR), float) / 255
    h, sat, v = hsv(a)
    fg = (sat > 0.10) | (v < 0.10) | (v > 0.80)
    lab = np.where(fg, 5, 0).astype(np.int8)
    lab[fg & (h > 5) & (h < 45) & (v < 0.62) & (sat > 0.10)] = 1
    lab[fg & ((h < 12) | (h > 340)) & (v > 0.45) & (sat > 0.35)] = 2
    lab[fg & (h > 280) & (h < 335) & (sat > 0.3)] = 3
    lab[fg & (h > 150) & (h < 200) & (sat > 0.10)] = 4
    return lab, a

def dark_preview(path, W, H):
    """The in-game shop previews: a black-clothed body (brown hands, grey hair) on a bright coloured card."""
    a = np.asarray(Image.open(path).convert("RGB").resize((W, H), Image.BILINEAR), float) / 255
    h, sat, v = hsv(a)
    body = (v < 0.22) | ((h > 10) & (h < 40) & (sat > 0.12) & (v < 0.6)) | ((sat < 0.08) & (v > 0.3) & (v < 0.75))
    lab = np.where(body, 5, 0).astype(np.int8)
    lab[body & (h > 10) & (h < 40) & (sat > 0.15) & (v > 0.25) & (v < 0.7)] = 1  # (skin: the hands and face)
    lab[: int(H * 0.11)] = 0  # (the card's LIVE badge and sound button)
    return lab, a

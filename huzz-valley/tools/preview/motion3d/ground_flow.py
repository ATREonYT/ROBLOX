"""How fast the ground slides under a followed character, frame by frame, from a screen recording.

The camera follows the player, so the floor's studs slide past at the player's speed (in screen pixels, perspective
and all). Phase correlation between consecutive frames on floor patches gives that shift; normalised to the steady
run it shows how quickly a set-off builds up and how quickly a stop stops (owner, Oct 19: "add some velocity into
the game, and add animations for when you stop running ... check the huss valley references").

  python3 ground_flow.py <video> <start s> <seconds> [fps=60] [patches]
patches: "x,y,w,h;x,y,w,h" in the video's pixels (default: two floor patches low left and low right of a 3020x1882
recording, clear of the character and the HUD). Prints t, the shift in px/frame of each patch and their median.
Needs ffmpeg and numpy. Huss Valley's recording: the starts at 30.7 s and the stops at 52.3 s (docs/notes/movement-and-camera.md).
"""
import subprocess
import sys

import numpy as np


def frames(video, start, seconds, fps, w, h):
    cmd = ["ffmpeg", "-v", "error", "-ss", str(start), "-t", str(seconds), "-i", video,
           "-vf", f"fps={fps},format=gray", "-f", "rawvideo", "-"]
    raw = subprocess.run(cmd, capture_output=True, check=True).stdout
    n = len(raw) // (w * h)
    return np.frombuffer(raw[: n * w * h], dtype=np.uint8).reshape(n, h, w).astype(np.float32)


def shift(a, b):
    """Sub-pixel shift between two patches (phase correlation with a Hann window)."""
    win = np.outer(np.hanning(a.shape[0]), np.hanning(a.shape[1]))
    A = np.fft.fft2((a - a.mean()) * win)
    B = np.fft.fft2((b - b.mean()) * win)
    r = A * np.conj(B)
    r /= np.abs(r) + 1e-9
    c = np.fft.ifft2(r).real
    y, x = np.unravel_index(np.argmax(c), c.shape)
    if y > c.shape[0] // 2:
        y -= c.shape[0]
    if x > c.shape[1] // 2:
        x -= c.shape[1]
    return float(np.hypot(x, y))


def size(video):
    out = subprocess.run(["ffprobe", "-v", "error", "-select_streams", "v:0", "-show_entries", "stream=width,height",
                          "-of", "csv=p=0", video], capture_output=True, text=True, check=True).stdout.strip()
    w, h = out.split(",")[:2]
    return int(w), int(h)


def main():
    video, start, seconds = sys.argv[1], float(sys.argv[2]), float(sys.argv[3])
    fps = int(sys.argv[4]) if len(sys.argv) > 4 else 60
    w, h = size(video)
    if len(sys.argv) > 5:
        patches = [tuple(int(v) for v in p.split(",")) for p in sys.argv[5].split(";")]
    else:
        patches = [(250, 1250, 512, 384), (2250, 1250, 512, 384)]
    f = frames(video, start, seconds, fps, w, h)
    print("t        " + "  ".join(f"p{i}" for i in range(len(patches))) + "   median (px/frame)")
    for i in range(1, len(f)):
        s = [shift(f[i - 1][y:y + ph, x:x + pw], f[i][y:y + ph, x:x + pw]) for (x, y, pw, ph) in patches]
        print(f"{start + i / fps:7.3f}  " + "  ".join(f"{v:5.1f}" for v in s) + f"   {np.median(s):5.1f}")


if __name__ == "__main__":
    main()

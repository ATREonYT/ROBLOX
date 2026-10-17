"""Kid-safe flash check on a film: at most one big brightness jump a second.

Usage (from huzz-valley/): python3 tools/preview/flash_check.py <film.mp4>
Reads the film's frames small (ffmpeg), takes each frame's mean brightness (0..255) and lists every flash: a
brightness peak more than JUMP over the frames a third of a second before it AND after it (up and back down; a
slow sunrise or a cut to a brighter shot is not a flash). Two flashes less than a second apart fail the check.
"""
import subprocess
import sys

JUMP = 20  # brightness levels (0..255) that count as a flash going up
W, H = 64, 36

def main(path):
    raw = subprocess.run(["ffmpeg", "-v", "error", "-i", path, "-vf", f"scale={W}:{H}", "-f", "rawvideo", "-pix_fmt", "gray", "-"],
                         capture_output=True, check=True).stdout
    n = len(raw) // (W * H)
    luma = [sum(raw[i * W * H:(i + 1) * W * H]) / (W * H) for i in range(n)]
    fps = 30
    flashes = []
    for i in range(n):
        before = min(luma[max(0, i - fps // 3):i + 1])
        after = min(luma[i:i + fps // 3 + 1])
        rise = min(luma[i] - before, luma[i] - after)
        if rise > JUMP and luma[i] == max(luma[max(0, i - fps // 3):i + fps // 3 + 1]):
            if not flashes or i - flashes[-1][0] > fps // 3:
                flashes.append((i, rise))
    print(f"{n} frames, brightness {min(luma):.0f}..{max(luma):.0f}, biggest frame-to-frame step "
          f"{max(abs(luma[i] - luma[i - 1]) for i in range(1, n)):.0f}")
    for i, d in flashes:
        print(f"  flash at {i / fps:.2f} s (up {d:.0f})")
    bad = [(a, b) for (a, _), (b, _) in zip(flashes, flashes[1:]) if (b - a) / fps < 1]
    print("FAIL: two flashes within a second" if bad else "ok: at most one flash a second")
    return 1 if bad else 0

if __name__ == "__main__":
    sys.exit(main(sys.argv[1]))

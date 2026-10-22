"""
The owner's song clips, made ready to upload as dance songs (owner, Oct 22 16:17: "match up the songs to the dances"):
measures each clip's beat (kick onsets, autocorrelation, refined over 8 beats) and where its first beat falls, then
cuts it from that beat to 1, 2, 4 or 8 bars (as many as fit), so a looped Sound stays on the beat (Start = 0). Writes .ogg (an
mp3 adds a short silence at each end, which knocks a loop off the beat).
  python3 song_loops.py <out dir> <name>=<clip> ...      prints name, BPM, beat, first beat, bars kept
His clips and the cut files stay out of git (design/owner-oct22/audio/, gitignored).
"""
import subprocess, sys, json
import numpy as np

SR, HOP = 11025, 64


def load(path):
    raw = subprocess.run(["ffmpeg", "-v", "error", "-i", path, "-ac", "1", "-ar", str(SR), "-f", "f32le", "-"],
                         capture_output=True, check=True).stdout
    return np.frombuffer(raw, np.float32)


def onsets(x, n=1024):
    frames = np.lib.stride_tricks.sliding_window_view(x, n)[::HOP] * np.hanning(n)
    L = np.log1p(np.abs(np.fft.rfft(frames, axis=1)))
    d = np.maximum(L[1:] - L[:-1], 0).sum(1)
    d -= np.convolve(d, np.ones(64) / 64, "same")
    return np.maximum(d, 0)


def beat_of(o):
    fps = SR / HOP
    a = o - o.mean()
    ac = np.correlate(a, a, "full")[len(a) - 1:]
    ac /= ac[0]

    def score(bpm):
        lag = fps * 60 / bpm
        return sum(np.interp(k * lag, np.arange(len(ac)), ac) for k in (1, 2, 4, 8) if k * lag < len(ac) - 1)
    bpms = np.arange(70, 200, 0.05)
    s = np.array([score(b) for b in bpms])
    bpm = bpms[int(np.argmax(s))]
    if bpm < 95 and score(bpm * 2) > 0.8 * s.max():  # (a half-time pick: count the real beat)
        bpm *= 2
    period = fps * 60 / bpm
    # the first beat: the phase whose beats land on the most onset
    phases = np.arange(0, period, 0.25)
    hits = [np.interp(p + period * np.arange(int((len(o) - 1 - p) / period)), np.arange(len(o)), o).sum() for p in phases]
    return bpm, phases[int(np.argmax(hits))] / fps


if __name__ == "__main__":
    out = sys.argv[1]
    report = {}
    for arg in sys.argv[2:]:
        name, path = arg.split("=", 1)
        x = load(path)
        bpm, first = beat_of(onsets(x))
        beat = 60 / bpm
        bars = int((len(x) / SR - first) / (4 * beat))
        bars = max(b for b in (1, 2, 4, 8) if b <= max(bars, 1))
        length = bars * 4 * beat
        subprocess.run(["ffmpeg", "-v", "error", "-y", "-ss", f"{first:.4f}", "-t", f"{length:.4f}", "-i", path,
                        "-af", "afade=t=in:d=0.005,areverse,afade=t=in:d=0.005,areverse", "-c:a", "libvorbis",
                        "-q:a", "6", f"{out}/{name}.ogg"], check=True)
        report[name] = {"bpm": round(bpm, 2), "beat": round(beat, 4), "first": round(first, 3), "bars": bars,
                        "seconds": round(length, 3)}
        print(f"{name:16s} {bpm:6.2f} BPM  beat {beat:.4f} s  first beat {first:.3f} s  {bars} bars = {length:.2f} s")
    json.dump(report, open(f"{out}/songs.json", "w"), indent=1)

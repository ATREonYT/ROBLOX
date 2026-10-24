"""
Turns a fit (fit_video.py) into one clean loop of joint Transforms for the game:
  python3 make_dance.py <fit.json> <period frames> <out.dance.json> [first frame] [seconds] [front]
Folds every repeat of the loop in the clip onto one (an average: steadier than any single pass), unwraps the turn
(a dance that spins all the way round ends one turn on from where it began), keeps the hop but not any drift, and
smooths each number over a frame either side. [seconds] stretches the loop to a whole number of beats of its song
(so the moves land on the music).
[front]: the dancer faces the camera all through (Sweet Dancin). A dark body's outline looks the same from the front
and the back, so the fit sometimes stands it back to front; those frames are turned round (seen in a mirror through
the camera's depth, left and right swapped), which looks the same in the clip but faces the right way. Writes { fps, length, frames = { { [part] = 12 CFrame numbers } } }.
"""
import json, math, sys
import numpy as np
from r6fit import transforms, JOINTS, LIMBS

fit = json.load(open(sys.argv[1])); P = float(sys.argv[2]); out = sys.argv[3]
start = int(sys.argv[4]) if len(sys.argv) > 4 else 0
X = np.array(fit["frames"])[start:]
SWAP = {"Neck": "Neck", "Right Shoulder": "Left Shoulder", "Left Shoulder": "Right Shoulder", "Right Hip": "Left Hip",
        "Left Hip": "Right Hip"}


def turned_round(x):
    """The same outline from the camera, the body facing the other way (see [front])."""
    D, M = np.diag([1.0, 1, -1, 1]), np.diag([-1.0, 1, 1, 1])
    T = transforms(x)
    rot = {j: np.block([[JOINTS[j][2][:3, :3], np.zeros((3, 1))], [np.zeros((1, 3)), np.ones((1, 1))]]) for j in JOINTS}
    out = np.array(x, dtype=float)
    Q = rot["RootJoint"] @ T["RootJoint"] @ rot["RootJoint"].T
    R = rot["RootJoint"].T @ (D @ Q @ M) @ rot["RootJoint"]
    out[0:3] = R[:3, 3]
    out[3] = math.atan2(R[1, 0], R[0, 0]); out[4] = -math.asin(max(-1, min(1, R[2, 0]))); out[5] = math.atan2(R[2, 1], R[2, 2])
    for i, j in enumerate(LIMBS):
        k = SWAP[j]
        Q = rot[j] @ T[j] @ rot[j].T
        R = rot[k].T @ (M @ Q @ M) @ rot[k]
        n = LIMBS.index(k)
        out[6 + 3 * n] = math.atan2(-R[1, 2], R[2, 2]); out[7 + 3 * n] = math.asin(max(-1, min(1, R[0, 2])))
        out[8 + 3 * n] = math.atan2(-R[0, 1], R[0, 0])
    return out


if len(sys.argv) > 6 and sys.argv[6] == "front":
    flipped = 0
    for i in range(len(X)):
        if math.cos(X[i, 3]) < 0:
            X[i] = turned_round(X[i]); flipped += 1
    print(f"{flipped} of {len(X)} frames were back to front: turned round")
X[:, 3] = np.unwrap(X[:, 3])
n = len(X)
cycles = (n - 1) / P
# the turn per loop: a whole number of turns (0 for a dance that faces front, 1 for one that spins round)
turn = (X[-1, 3] - X[0, 3]) / cycles if cycles >= 1 else 0
turns = round(turn / (2 * math.pi))
drift = (X[-1, 3] - X[0, 3] - turns * 2 * math.pi * cycles) / max(n - 1, 1)  # (a preview turning slowly on its own)
X[:, 3] -= drift * np.arange(n)
# the head is a cube: turned half round about its own up it looks the same, so the fit can't tell which way it faces.
# Keep it facing the way the body does (a head never looks more than 90 degrees aside in these dances).
X[:, 8] -= np.pi * np.round(X[:, 8] / np.pi)
N = int(round(P))
# the joint angles (all but the move and the turn) are averaged round the circle: a raised arm sits near +-180
# degrees, and a plain average of +179 and -179 would drop it to 0 (hanging down)
ANG = np.arange(4, X.shape[1])
loop = np.zeros((N, X.shape[1])); count = np.zeros(N)
sines, cosines = np.zeros((N, len(ANG))), np.zeros((N, len(ANG)))
for i in range(n):
    c = i / P
    k = int(round((c - math.floor(c)) * P)) % N
    y = X[i].copy()
    y[3] -= math.floor(c) * turns * 2 * math.pi
    loop[k] += y; count[k] += 1
    sines[k] += np.sin(y[ANG]); cosines[k] += np.cos(y[ANG])
loop /= np.maximum(count, 1)[:, None]
loop[:, ANG] = np.unwrap(np.arctan2(sines, cosines), axis=0)
# no drift across the loop: what's left over at the end is spread back across it
end = loop[-1] + (loop[1] - loop[0]) if N > 2 else loop[-1]
gap = (loop[0] + np.r_[0, 0, 0, turns * 2 * math.pi, np.zeros(X.shape[1] - 4)]) - end
gap[ANG] = (gap[ANG] + math.pi) % (2 * math.pi) - math.pi
loop += np.outer(np.arange(N) / N, gap)
# smooth over a frame either side, round the loop
k = np.array([0.25, 0.5, 0.25])
step = np.r_[0, 0, 0, turns * 2 * math.pi, np.zeros(X.shape[1] - 4)]
step[ANG] = np.round((loop[-1, ANG] - loop[0, ANG]) / (2 * math.pi)) * 2 * math.pi  # whole turns the angles went round
wrapped = np.concatenate([loop[-1:] - step, loop, loop[:1] + step])
loop = k[0] * wrapped[:-2] + k[1] * wrapped[1:-1] + k[2] * wrapped[2:]
# stretched to fit its song's beats
if len(sys.argv) > 5:
    M = int(round(float(sys.argv[5]) * 30))
    ext = np.vstack([loop, loop[:1] + np.r_[0, 0, 0, turns * 2 * math.pi, np.zeros(X.shape[1] - 4)]])
    t = np.arange(M) * N / M
    loop = np.stack([np.interp(t, np.arange(N + 1), ext[:, c]) for c in range(X.shape[1])], 1)
    N = M
# stand on the floor: the root moves round its own middle
loop[:, 0:3] -= loop[:, 0:3].mean(0) * np.array([1, 1, 0])

fps = N / float(sys.argv[5]) if len(sys.argv) > 5 else 30  # (exactly on the beat)
frames = []
for x in loop:
    T = transforms(x)
    f = {}
    for j, m in T.items():
        part = JOINTS[j][1]
        f[part] = [float(v) for v in (m[0, 3], m[1, 3], m[2, 3], *m[:3, :3].reshape(-1))]
    frames.append(f)
json.dump({"fps": fps, "length": N / fps, "turns": turns, "frames": frames}, open(out, "w"))
print(f"{out}: {N} frames ({N / fps:.2f} s), {cycles:.1f} passes folded, {turns} turn(s) a loop")

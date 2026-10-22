"""
The hardtekk dances (owner, Oct 22 16:00: "for the shorter ones ... make them into dances that fit the beats, more
hardtekk dances to match with the sounds"), made beat by beat for his three tracks. Each is 16 beats (two bars of
eight) at its track's measured tempo, so it loops in time with the song: every punch, stomp and jump lands on a kick.
  python3 author_dances.py   -> dances/<name>.json (as make_dance.py), for tools/anim/extract_anims.luau
Tempos measured off his files (kick onsets, autocorrelation; tools/sfx/song_loops.py): 150.9, 199.75 and 179.75 BPM.
A limb is set by where it points: (forward, out) = swing it forward by `forward` (pi = straight up), after tilting
it away from the body by `out` (both arms and legs; pi/2 = straight out to the side), in the torso's own frame, and
turned into its joint's Transform. Root and neck (r6fit's numbers, checked): up, lean forward, roll left, turn left;
nod down, tilt left, look left.
"""
import json, math
import numpy as np
from r6fit import transforms, JOINTS, rx, rz

PI = math.pi

def ease(u):
    u = min(max(u, 0.0), 1.0)
    return u * u * (3 - 2 * u)

def hit(ph, attack=0.16):
    """A punch on the beat: snaps up in `attack` of a beat, eases back over the rest."""
    ph %= 1.0
    return ease(ph / attack) if ph < attack else 1 - ease((ph - attack) / (1 - attack))

def pump(ph):
    """A fist pump: up on the beat, held, pulled back down before the next."""
    ph %= 1.0
    if ph < 0.14:
        return ease(ph / 0.14)
    if ph < 0.42:
        return 1.0
    return 1 - ease((ph - 0.42) / 0.58)

def hop(ph):
    """Up between kicks, down on the beat (R6 has no knees: the body lifts instead of dipping)."""
    return math.sin(PI * (ph % 1.0)) ** 2

def section(b, start, end, fade=0.5):
    """1 inside beats [start, end), easing over `fade` beats either side (b in 0..16, wrapping)."""
    def w(x):
        return ease((x - start + fade) / fade) * ease((end - x + fade) / fade) if True else 0
    return max(w(b), w(b - 16), w(b + 16))

KEYS = ["up", "lean", "roll", "turn", "side", "nod", "tilt", "look", "raf", "rao", "laf", "lao", "rlf", "rlo", "llf", "llo"]

def X(up=0.0, lean=0.0, roll=0.0, turn=0.0, side=0.0, nod=0.0, look=0.0, tilt=0.0,
      ra=(0.0, 0.0), la=(0.0, 0.0), rl=(0.0, 0.0), ll=(0.0, 0.0)):
    """A pose as numbers (they blend): ra/la/rl/ll = (forward, out) per limb, in radians."""
    return np.array([up, lean, roll, turn, side, nod, tilt, look, *ra, *la, *rl, *ll], float)

def limb(joint, forward, out):
    """A limb pointing (forward, out) from the torso -> its joint's Transform (C0 * T * C1:Inverse() = the turn)."""
    side = 1 if joint.startswith("Right") else -1
    rel = rx(forward) @ rz(side * out)
    R = JOINTS[joint][2][:3, :3]  # (C0's turn = C1's for every R6 limb joint)
    T = np.eye(4)
    T[:3, :3] = R.T @ rel[:3, :3] @ R
    return T

def joints_of(p):
    x = np.zeros(21)
    up, lean, roll, turn, side, nod, tilt, look = p[:8]
    x[0], x[2], x[3], x[4], x[5] = side, up, turn, roll, lean
    x[6], x[7], x[8] = nod, tilt, look
    T = transforms(x)
    T["Right Shoulder"] = limb("Right Shoulder", p[8], p[9])
    T["Left Shoulder"] = limb("Left Shoulder", p[10], p[11])
    T["Right Hip"] = limb("Right Hip", p[12], p[13])
    T["Left Hip"] = limb("Left Hip", p[14], p[15])
    return T

def tekk_pump(b):
    """150 BPM. Bar 1: right fist pumps the sky on every beat, left hand low, feet tapping forward in turn, a hop
    between beats, the head banging on the kick. Bar 2: both fists together, the body turning side to side."""
    ph = b % 1.0; beat = int(b) % 16
    k = pump(ph)
    side = 1 if beat % 2 == 0 else -1
    tap = 0.32 * hit(ph, 0.22)
    A = X(up=0.16 * hop(ph), lean=0.08, nod=0.3 * k - 0.05,
          ra=(1.45 + 1.5 * k, 0.2), la=(0.35, 0.3),
          rl=(tap if side > 0 else 0.0, 0.08), ll=(tap if side < 0 else 0.0, 0.08))
    sway = math.sin(PI * b / 2)  # (a turn every two beats)
    B = X(up=0.18 * hop(ph), lean=0.14, turn=0.35 * sway, nod=0.32 * k - 0.05,
          ra=(1.3 + 1.6 * k, 0.35), la=(1.3 + 1.6 * k, 0.35),
          rl=(0.25 * hit(ph, 0.22) if side > 0 else -0.1, 0.12), ll=(0.25 * hit(ph, 0.22) if side < 0 else -0.1, 0.12))
    w = section(b, 8, 16)
    return A * (1 - w) + B * w

def hakken(b):
    """200 BPM. Bar 1: the hakken stomp, a kick forward and out on every beat (left, right), leaning in, fists
    swinging low against the legs. Bar 2: kicks behind like a running man, arms swinging big, turned to one side
    for four beats, then the other."""
    ph = b % 1.0; beat = int(b) % 16
    side = 1 if beat % 2 == 0 else -1
    k = hit(ph, 0.2)
    kick = 0.75 * k
    A = X(up=0.14 * hop(ph), lean=0.22, nod=0.25 * k, roll=0.05 * side * k,
          rl=(kick if side > 0 else -0.08, 0.22 * (k if side > 0 else 0)),
          ll=(kick if side < 0 else -0.08, 0.22 * (k if side < 0 else 0)),
          ra=(0.95 * (k if side < 0 else 0.25), 0.15), la=(0.95 * (k if side > 0 else 0.25), 0.15))
    turn = 0.6 if (int(b) % 16) < 12 else -0.6
    back = -0.7 * k
    B = X(up=0.16 * hop(ph), lean=0.18, turn=turn, nod=0.25 * k,
          rl=(back if side > 0 else 0.25, 0.05), ll=(back if side < 0 else 0.25, 0.05),
          ra=(1.7 * (k if side < 0 else 0) - 0.5 * (k if side > 0 else 0), 0.2),
          la=(1.7 * (k if side > 0 else 0) - 0.5 * (k if side < 0 else 0), 0.2))
    # (the turn eases over half a beat at bar 2's middle and ends)
    tb = b % 16
    if 8 <= tb < 16:
        u = ease((tb - 11.75) / 0.5)
        B[KEYS.index("turn")] = 0.6 * (1 - u) - 0.6 * u
    w = section(b, 8, 16)
    return A * (1 - w) + B * w

def jumpstyle(b):
    """180 BPM. Jumpstyle: a jump on the beat with one leg kicked out in front, land feet together on the next,
    then the other leg. Bar 1: rave hands, both arms up in a V swaying with the jumps. Bar 2: arms out wide, and a
    full spin round over the last four beats, still kicking."""
    ph = b % 1.0; beat = int(b) % 16
    first = beat % 2 == 0  # (the jump beat; the next beat lands)
    pair = (beat // 2) % 2 == 0  # (right leg kicks, then left)
    j = hop(ph) if first else 0.25 * hop(ph)
    kick = 1.0 * hit(ph, 0.25) if first else 0.0
    rl = (kick if pair else -0.25 * kick, 0.1)
    ll = (kick if not pair else -0.25 * kick, 0.1)
    swayA = math.sin(PI * b / 2)
    A = X(up=0.42 * j, lean=-0.05, roll=0.18 * swayA, nod=0.2 * hit(ph) - 0.1, tilt=-0.15 * swayA,
          ra=(2.85, 0.55 + 0.15 * swayA), la=(2.85, 0.55 - 0.15 * swayA), rl=rl, ll=ll)
    tb = b % 16
    spin = 2 * PI * ease((tb - 12) / 4) if tb >= 12 else 0.0
    B = X(up=0.42 * j, lean=0.05, turn=spin, nod=0.2 * hit(ph) - 0.1,
          ra=(0.2 + 0.3 * hit(ph), 1.45), la=(0.2 + 0.3 * hit(ph), 1.45), rl=rl, ll=ll)
    w = section(b, 8, 16)
    x = A * (1 - w) + B * w
    if tb >= 12:  # (the spin itself never blends: it ends a whole turn round, where the loop starts)
        x[KEYS.index("turn")] = spin
    return x

DANCES = [("tekkpump", tekk_pump, 150.9), ("hakken", hakken, 199.75), ("jumpstyle", jumpstyle, 179.75)]

def main():
    for name, fn, bpm in DANCES:
        length = 16 * 60 / bpm
        n = int(round(length * 30))
        frames = []
        for i in range(n):
            T = joints_of(fn(16 * i / n))
            frames.append({JOINTS[j][1]: [float(v) for v in (m[0, 3], m[1, 3], m[2, 3], *m[:3, :3].reshape(-1))] for j, m in T.items()})
        json.dump({"fps": n / length, "length": length,  # (exactly 16 beats: stays on the song)
                   "bpm": bpm, "beats": 16, "frames": frames}, open(f"dances/{name}.json", "w"))
        print(f"dances/{name}.json: {n} frames, {length:.3f} s, {bpm} BPM")

if __name__ == "__main__":
    main()

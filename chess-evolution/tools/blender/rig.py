# +1 Chess Evolution: shared R15 rig + rival outfits (all sizes in studs, Roblox axes: Y up, faces -Z).
# Used by rivals.py (Blender build, animation, renders, JSON export). Original characters only.
import math

def C(r, g, b):
    return (r, g, b)

SKIN = [C(255, 214, 170), C(234, 184, 140), C(198, 140, 100), C(141, 92, 62), C(250, 205, 180)]

# limb: (size, center relative to HumanoidRootPart centre, parent limb, joint motor name, joint position)
LIMBS = {
    "HumanoidRootPart": ((2, 2, 1), (0, 0, 0), None, None, None),
    "LowerTorso": ((2, 0.4, 1), (0, -0.8, 0), "HumanoidRootPart", "Root", (0, -0.6, 0)),
    "UpperTorso": ((2, 1.6, 1), (0, 0.2, 0), "LowerTorso", "Waist", (0, -0.6, 0)),
    "Head": ((1.7, 1.6, 1.6), (0, 1.8, 0), "UpperTorso", "Neck", (0, 1.0, 0)),
    "LeftUpperArm": ((1, 1.15, 1), (-1.5, 0.43, 0), "UpperTorso", "LeftShoulder", (-1.5, 0.75, 0)),
    "LeftLowerArm": ((1, 1.0, 1), (-1.5, -0.65, 0), "LeftUpperArm", "LeftElbow", (-1.5, -0.15, 0)),
    "LeftHand": ((1, 0.45, 1), (-1.5, -1.37, 0), "LeftLowerArm", "LeftWrist", (-1.5, -1.15, 0)),
    "RightUpperArm": ((1, 1.15, 1), (1.5, 0.43, 0), "UpperTorso", "RightShoulder", (1.5, 0.75, 0)),
    "RightLowerArm": ((1, 1.0, 1), (1.5, -0.65, 0), "RightUpperArm", "RightElbow", (1.5, -0.15, 0)),
    "RightHand": ((1, 0.45, 1), (1.5, -1.37, 0), "RightLowerArm", "RightWrist", (1.5, -1.15, 0)),
    "LeftUpperLeg": ((1, 0.9, 1), (-0.5, -1.45, 0), "LowerTorso", "LeftHip", (-0.5, -1.0, 0)),
    "LeftLowerLeg": ((1, 0.8, 1), (-0.5, -2.3, 0), "LeftUpperLeg", "LeftKnee", (-0.5, -1.9, 0)),
    "LeftFoot": ((1, 0.3, 1.2), (-0.5, -2.85, -0.1), "LeftLowerLeg", "LeftAnkle", (-0.5, -2.7, 0)),
    "RightUpperLeg": ((1, 0.9, 1), (0.5, -1.45, 0), "LowerTorso", "RightHip", (0.5, -1.0, 0)),
    "RightLowerLeg": ((1, 0.8, 1), (0.5, -2.3, 0), "RightUpperLeg", "RightKnee", (0.5, -1.9, 0)),
    "RightFoot": ((1, 0.3, 1.2), (0.5, -2.85, -0.1), "RightLowerLeg", "RightAnkle", (0.5, -2.7, 0)),
}
ORDER = list(LIMBS.keys())
HIP_HEIGHT = 2.0  # HRP centre sits 3 studs above the ground (feet bottom at -3)

def limb_colors(o):
    skin, shirt, pants, shoe = o["skin"], o["shirt"], o["pants"], o.get("shoes", C(40, 40, 46))
    sleeve = o.get("sleeve", shirt)
    return {
        "HumanoidRootPart": shirt, "LowerTorso": o.get("belt", pants), "UpperTorso": shirt, "Head": skin,
        "LeftUpperArm": sleeve, "RightUpperArm": sleeve,
        "LeftLowerArm": o.get("forearm", skin), "RightLowerArm": o.get("forearm", skin),
        "LeftHand": skin, "RightHand": skin,
        "LeftUpperLeg": pants, "RightUpperLeg": pants, "LeftLowerLeg": pants, "RightLowerLeg": pants,
        "LeftFoot": shoe, "RightFoot": shoe,
    }

# accessory part: (name, limb, size, centre (HRP space at rest), colour, material, shape, rot deg xyz)
def A(name, limb, size, pos, color, mat="SmoothPlastic", shape="Block", rot=(0, 0, 0)):
    return dict(name=name, limb=limb, size=size, pos=pos, color=color, mat=mat, shape=shape, rot=rot)

HY = 1.8   # head centre y
HF = -0.8  # head front face z
def face(eye=C(30, 30, 40), brows=None, mouth="smile", glasses=None):
    out = []
    for s in (-1, 1):
        out.append(A("Eye", "Head", (0.26, 0.38, 0.06), (0.36 * s, HY + 0.05, HF - 0.02), eye))
        out.append(A("EyeShine", "Head", (0.1, 0.12, 0.04), (0.36 * s + 0.05, HY + 0.15, HF - 0.05), C(255, 255, 255)))
        if brows:
            tilt = brows * s
            out.append(A("Brow", "Head", (0.42, 0.1, 0.06), (0.38 * s, HY + 0.37, HF - 0.03), C(40, 30, 25), rot=(0, 0, tilt)))
    if mouth == "smile":
        out.append(A("Mouth", "Head", (0.5, 0.1, 0.05), (0, HY - 0.38, HF - 0.02), C(120, 40, 40)))
        for s in (-1, 1):
            out.append(A("MouthCorner", "Head", (0.1, 0.1, 0.05), (0.27 * s, HY - 0.32, HF - 0.02), C(120, 40, 40)))
    elif mouth == "smirk":
        out.append(A("Mouth", "Head", (0.46, 0.1, 0.05), (0.06, HY - 0.37, HF - 0.02), C(120, 40, 40), rot=(0, 0, 8)))
    if glasses:
        for s in (-1, 1):
            out.append(A("Lens", "Head", (0.52, 0.48, 0.05), (0.36 * s, HY + 0.05, HF - 0.06), glasses, "Glass" if glasses != C(20, 20, 26) else "SmoothPlastic"))
        out.append(A("Bridge", "Head", (0.22, 0.08, 0.05), (0, HY + 0.12, HF - 0.06), C(30, 30, 36)))
    return out

def hair_block(color, top=0.35, back=0.45, sides=0.25, fringe=0.3):
    return [
        A("HairTop", "Head", (1.86, top, 1.76), (0, HY + 0.8 + top / 2 - 0.05, 0.02), color),
        A("HairBack", "Head", (1.86, 1.2, back), (0, HY + 0.25, 0.8 + back / 2 - 0.12), color),
        A("HairSideL", "Head", (sides, 0.9, 1.5), (-0.85 - sides / 2 + 0.08, HY + 0.4, 0.1), color),
        A("HairSideR", "Head", (sides, 0.9, 1.5), (0.85 + sides / 2 - 0.08, HY + 0.4, 0.1), color),
        A("Fringe", "Head", (1.86, fringe, 0.3), (0, HY + 0.8 - fringe / 2 + 0.05, -0.72), color),
    ]

def collar(color):
    return [A("Collar", "UpperTorso", (1.3, 0.25, 1.1), (0, 0.98, 0), color)]

RIVALS = []

def rival(rid, display, stage, scale, outfit, extras):
    RIVALS.append(dict(id=rid, display=display, stage=stage, scale=scale, outfit=outfit, extras=extras))

# 1. Pawn Pete: green hoodie kid, backwards cap
G = C(80, 200, 90)
rival("PawnPete", "Pawn Pete", 1, 1.0,
      dict(skin=SKIN[0], shirt=G, pants=C(60, 70, 110), shoes=C(240, 240, 240)),
      face() + hair_block(C(120, 72, 36), top=0.2, fringe=0.2) + [
          A("CapCrown", "Head", (1.9, 0.45, 1.8), (0, HY + 0.95, 0.02), G),
          A("CapBrim", "Head", (1.3, 0.14, 0.8), (0, HY + 0.78, 1.15), G),
          A("CapButton", "Head", (0.3, 0.12, 0.3), (0, HY + 1.23, 0.02), C(246, 238, 220)),
          A("HoodieHood", "UpperTorso", (1.9, 0.5, 0.5), (0, 0.85, 0.55), C(60, 170, 70)),
          A("Pocket", "UpperTorso", (1.2, 0.45, 0.06), (0, -0.25, -0.53), C(60, 170, 70)),
          A("PawnBadge", "UpperTorso", (0.36, 0.5, 0.06), (0.5, 0.45, -0.53), C(246, 238, 220)),
      ])
# 2. Knight Nadia: cobalt jacket, ponytail, headband
B = C(40, 90, 220)
rival("KnightNadia", "Knight Nadia", 2, 1.0,
      dict(skin=SKIN[2], shirt=B, pants=C(35, 40, 60), shoes=C(250, 250, 250), sleeve=B, forearm=B),
      face(brows=-6) + hair_block(C(30, 22, 20)) + [
          A("Headband", "Head", (1.9, 0.25, 1.8), (0, HY + 0.6, 0.0), C(255, 200, 50)),
          A("Ponytail", "Head", (0.6, 1.2, 0.5), (0, HY + 0.05, 1.15), C(30, 22, 20), rot=(-20, 0, 0)),
          A("Zip", "UpperTorso", (0.12, 1.5, 0.06), (0, 0.2, -0.53), C(255, 200, 50)),
          A("KnightBadge", "UpperTorso", (0.42, 0.5, 0.06), (-0.55, 0.45, -0.53), C(246, 238, 220)),
      ] + collar(C(30, 70, 180)))
# 3. Rook Rocco: red tracksuit, flat-top, shades
R = C(220, 50, 50)
rival("RookRocco", "Rook Rocco", 3, 1.05,
      dict(skin=SKIN[1], shirt=R, pants=R, shoes=C(46, 48, 56), sleeve=R),
      face(brows=4, mouth="smirk", glasses=C(20, 20, 26)) + [
          A("FlatTop", "Head", (1.8, 0.7, 1.7), (0, HY + 1.1, 0.0), C(25, 20, 18)),
          A("Stripe", "UpperTorso", (0.12, 1.6, 0.06), (-0.4, 0.2, -0.53), C(250, 250, 250)),
          A("Stripe", "UpperTorso", (0.12, 1.6, 0.06), (0.4, 0.2, -0.53), C(250, 250, 250)),
          A("LegStripe", "LeftUpperLeg", (0.1, 0.9, 0.06), (-0.98, -1.45, 0), C(250, 250, 250)),
          A("LegStripe", "RightUpperLeg", (0.1, 0.9, 0.06), (0.98, -1.45, 0), C(250, 250, 250)),
      ] + collar(C(180, 30, 30)))
# 4. Bishop Bea: plum sweater, bun, round glasses
P = C(140, 70, 170)
rival("BishopBea", "Bishop Bea", 4, 1.0,
      dict(skin=SKIN[4], shirt=P, pants=C(246, 238, 220), shoes=C(140, 70, 170)),
      face(glasses=C(190, 225, 255)) + hair_block(C(200, 110, 60)) + [
          A("Bun", "Head", (0.8, 0.8, 0.8), (0, HY + 1.25, 0.35), C(200, 110, 60)),
          A("Diagonal", "UpperTorso", (0.2, 2.0, 0.06), (0, 0.2, -0.53), C(246, 238, 220), rot=(0, 0, 40)),
      ] + collar(C(246, 238, 220)))
# 5. Queen Quinn: ivory and gold, long hair, tiara
I = C(246, 238, 220)
rival("QueenQuinn", "Queen Quinn", 5, 1.05,
      dict(skin=SKIN[3], shirt=I, pants=C(255, 200, 50), shoes=C(255, 200, 50), belt=C(255, 200, 50)),
      face(brows=-4) + hair_block(C(20, 16, 14), back=0.5, sides=0.35) + [
          A("LongHair", "Head", (1.9, 1.7, 0.5), (0, HY - 0.3, 0.95), C(20, 16, 14)),
          A("TiaraBand", "Head", (1.7, 0.2, 0.2), (0, HY + 1.12, -0.82), C(255, 200, 50), "Neon"),
          A("TiaraGem", "Head", (0.34, 0.34, 0.2), (0, HY + 1.38, -0.82), C(255, 80, 160), "Neon", rot=(0, 0, 45)),
          A("Sash", "UpperTorso", (0.3, 2.1, 0.06), (0, 0.2, -0.53), C(255, 200, 50), rot=(0, 0, -35)),
      ])
# 6. King Kai: charcoal suit, gold tie, spiky hair, headphones
K = C(46, 48, 56)
rival("KingKai", "King Kai", 6, 1.1,
      dict(skin=SKIN[1], shirt=K, pants=K, shoes=C(20, 20, 24), sleeve=K),
      face(brows=6, mouth="smirk") + [
          A("HairBase", "Head", (1.86, 0.35, 1.76), (0, HY + 0.9, 0.02), C(250, 220, 90)),
          A("Spike", "Head", (0.5, 0.6, 0.5), (-0.5, HY + 1.25, 0), C(250, 220, 90), rot=(0, 0, 20)),
          A("Spike", "Head", (0.5, 0.7, 0.5), (0, HY + 1.3, -0.2), C(250, 220, 90)),
          A("Spike", "Head", (0.5, 0.6, 0.5), (0.5, HY + 1.25, 0), C(250, 220, 90), rot=(0, 0, -20)),
          A("PhoneBand", "Head", (2.1, 0.2, 0.3), (0, HY + 1.05, 0.1), C(30, 30, 36)),
          A("EarCup", "Head", (0.35, 0.8, 0.8), (-1.0, HY, 0.05), C(255, 200, 50)),
          A("EarCup", "Head", (0.35, 0.8, 0.8), (1.0, HY, 0.05), C(255, 200, 50)),
          A("Shirt", "UpperTorso", (0.7, 1.5, 0.06), (0, 0.22, -0.53), C(246, 238, 220)),
          A("Tie", "UpperTorso", (0.3, 1.2, 0.08), (0, 0.3, -0.57), C(255, 200, 50)),
      ])
# 7. Grandmaster Orion (final boss, original): purple blazer, silver hair, goatee, floating crown, cape
O = C(90, 40, 150)
rival("GrandmasterOrion", "Grandmaster Orion", 7, 1.3,
      dict(skin=SKIN[0], shirt=O, pants=C(30, 28, 40), shoes=C(20, 20, 24), sleeve=O, belt=C(255, 200, 50)),
      face(brows=10, mouth="smirk") + hair_block(C(215, 220, 230), top=0.45, fringe=0.25) + [
          A("Goatee", "Head", (0.6, 0.4, 0.14), (0, HY - 0.62, HF - 0.03), C(215, 220, 230)),
          A("Mustache", "Head", (0.8, 0.14, 0.1), (0, HY - 0.25, HF - 0.05), C(215, 220, 230)),
          A("CrownBand", "Head", (1.5, 0.35, 1.5), (0, HY + 1.55, 0), C(255, 200, 50), "Metal"),
          A("CrownPoint", "Head", (0.32, 0.45, 0.32), (-0.55, HY + 1.9, -0.55), C(255, 200, 50), "Metal"),
          A("CrownPoint", "Head", (0.32, 0.45, 0.32), (0.55, HY + 1.9, -0.55), C(255, 200, 50), "Metal"),
          A("CrownPoint", "Head", (0.32, 0.45, 0.32), (-0.55, HY + 1.9, 0.55), C(255, 200, 50), "Metal"),
          A("CrownPoint", "Head", (0.32, 0.45, 0.32), (0.55, HY + 1.9, 0.55), C(255, 200, 50), "Metal"),
          A("CrownCross", "Head", (0.2, 0.7, 0.2), (0, HY + 2.05, -0.55), C(255, 200, 50), "Metal"),
          A("CrownCrossBar", "Head", (0.5, 0.18, 0.2), (0, HY + 2.15, -0.55), C(255, 200, 50), "Metal"),
          A("CrownJewel", "Head", (0.3, 0.3, 0.12), (0, HY + 1.55, -0.78), C(70, 200, 255), "Neon", rot=(0, 0, 45)),
          A("Lapel", "UpperTorso", (0.35, 1.3, 0.08), (-0.4, 0.35, -0.55), C(255, 200, 50), rot=(0, 0, -15)),
          A("Lapel", "UpperTorso", (0.35, 1.3, 0.08), (0.4, 0.35, -0.55), C(255, 200, 50), rot=(0, 0, 15)),
          A("Shirt", "UpperTorso", (0.5, 1.4, 0.06), (0, 0.3, -0.53), C(20, 20, 26)),
          A("KingPin", "UpperTorso", (0.3, 0.42, 0.1), (-0.6, 0.6, -0.6), C(255, 200, 50), "Neon"),
          A("Cape", "UpperTorso", (2.3, 2.9, 0.18), (0, -0.4, 0.62), C(150, 20, 40), "Fabric"),
          A("CapeCollar", "UpperTorso", (2.4, 0.45, 0.6), (0, 1.0, 0.45), C(255, 200, 50)),
      ])

# ---------- duel table (stand-up blitz table with a chess clock) ----------
# local space: table centre at origin on the ground; seat A at +Z (player, hub side), seat B at -Z (rival)
DUEL = []
def T(name, size, pos, color, mat="SmoothPlastic", shape="Block", rot=(0, 0, 0)):
    DUEL.append(dict(name=name, size=size, pos=pos, color=color, mat=mat, shape=shape, rot=rot))
WOOD, DARK = C(150, 95, 50), C(46, 48, 56)
TOP = 2.1
T("Leg", (0.8, TOP - 0.4, 0.8), (-2.6, (TOP - 0.4) / 2, -1.6), DARK)
T("Leg", (0.8, TOP - 0.4, 0.8), (2.6, (TOP - 0.4) / 2, -1.6), DARK)
T("Leg", (0.8, TOP - 0.4, 0.8), (-2.6, (TOP - 0.4) / 2, 1.6), DARK)
T("Leg", (0.8, TOP - 0.4, 0.8), (2.6, (TOP - 0.4) / 2, 1.6), DARK)
T("Foot", (6.6, 0.3, 4.4), (0, 0.15, 0), DARK)
T("Top", (6.8, 0.4, 4.6), (0, TOP - 0.2, 0), WOOD, "Wood")
T("TopTrim", (7.0, 0.16, 4.8), (0, TOP - 0.42, 0), C(255, 200, 50))
for i in range(8):
    for j in range(8):
        light = (i + j) % 2 == 0
        T("Square", (0.42, 0.06, 0.42), (-1.47 + i * 0.42, TOP + 0.03, -1.47 + j * 0.42), C(246, 238, 220) if light else C(60, 62, 72))
T("BoardRim", (3.6, 0.08, 3.6), (0, TOP + 0.0, 0), C(110, 70, 36), "Wood")
# a few chunky pieces mid-game (ivory near the player at +Z, charcoal near the rival)
def piece(x, z, h, col, crown=False):
    T("PieceBase", (0.34, 0.12, 0.34), (x, TOP + 0.12, z), col)
    T("PieceBody", (0.22, h, 0.22), (x, TOP + 0.18 + h / 2, z), col)
    T("PieceHead", (0.3, 0.22, 0.3) if not crown else (0.34, 0.3, 0.34), (x, TOP + 0.18 + h + 0.11, z), col)
IV, CH = C(246, 238, 220), C(46, 48, 56)
for (x, z, h, c, cr) in [(-1.05, 1.05, 0.3, IV, False), (-0.21, 1.05, 0.3, IV, False), (0.63, 0.63, 0.3, IV, False), (0.21, 1.47, 0.6, IV, True),
                         (-0.63, -1.05, 0.3, CH, False), (0.21, -0.63, 0.3, CH, False), (1.05, -1.05, 0.3, CH, False), (-0.21, -1.47, 0.6, CH, True)]:
    piece(x, z, h, c, cr)
# chess clock on the right side (x = +), buttons face each player
T("ClockBody", (1.8, 0.8, 0.8), (2.6, TOP + 0.4, 0), DARK)
T("ClockFaceA", (0.6, 0.5, 0.06), (2.2, TOP + 0.45, -0.42), C(246, 238, 220))
T("ClockFaceB", (0.6, 0.5, 0.06), (3.0, TOP + 0.45, 0.42), C(246, 238, 220))
T("ClockButtonA", (0.5, 0.25, 0.5), (2.2, TOP + 0.92, 0), C(80, 200, 90), "Neon")
T("ClockButtonB", (0.5, 0.25, 0.5), (3.0, TOP + 0.92, 0), C(220, 50, 50), "Neon")
# anchors (invisible): stand points face the table centre
ANCHORS = {
    # ground-level stand points; rival Models pivot at their feet, so Model:PivotTo(SeatB.CFrame) works at any scale
    "SeatA": ((0, 0, 4.4), (0, 0, 0)),      # player stands at +Z (hub side) looking -Z
    "SeatB": ((0, 0, -4.6), (0, 180, 0)),   # rival stands at -Z looking +Z
    "BoardTop": ((0, TOP + 0.06, 0), (0, 0, 0)),
}

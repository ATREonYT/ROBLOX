"""+1 Chess Evolution hub map, laid out like Alex's reference screenshot (Nov 8).

One source of truth for the map shell. Units are Roblox studs, Roblox axes
(X right, Y up, Z toward spawn's back; stages are at -Z).
  python3 hub_layout.py            -> writes hub_layout.json
Blender (build_blender.py) and Studio (apply_hub_layout.lua) both read the JSON.
Only the map: no treadmills, displays or reference props. Existing game models
(Stations, SetDisplays, Stages, trees) are moved by the "moves" list.
"""
import json, os

# Colours: the reference's lit colours, measured from the screenshot (7x7 px averages).
REF = {
    "grass": "6EE946", "grass_top": "83F34A", "path": "EA9237", "path_edge": "D9792A",
    "brick": "BD532D", "brick_dark": "A04939", "stone": "AAB7BA", "stone_dark": "8E9A9E",
    "water": "50C8F0", "river_bed": "2F86C8", "wood": "A8582A",
}

parts = []
def box(group, name, x0, x1, y0, y1, z0, z1, col, mat="Plastic", **kw):
    parts.append(dict(group=group, name=name, pos=[(x0+x1)/2, (y0+y1)/2, (z0+z1)/2],
                      size=[x1-x0, y1-y0, z1-z0], color=col, material=mat, **kw))

# --- ground and river (the river replaces the old front wall, like the reference) ---
box("Ground", "Grass", -210, 210, -2, 0, -50, 62, "grass")
box("Ground", "GrassFar", -210, 210, -2, 0, 78, 210, "grass")
box("Ground", "RiverBed", -210, 210, -5, -4, 62, 78, "river_bed")
box("Ground", "RiverBankL", -210, 210, -4, 0, 61, 62, "brick_dark")
box("Ground", "RiverBankR", -210, 210, -4, 0, 78, 79, "brick_dark")
box("Ground", "Water", -210, 210, -4, -1.2, 62, 78, "water", mat="SmoothPlastic", transparency=0.15, collide=False)

# --- bridge over the river where the main path meets it ---
box("Bridge", "Deck", -6, 6, -0.6, 0.4, 60, 80, "wood", mat="WoodPlanks")
for sx in (-6.5, 6.5):
    box("Bridge", "Rail", sx-0.4, sx+0.4, 2.4, 3.0, 60, 80, "wood")
    for z in (61, 70, 79):
        box("Bridge", "Post", sx-0.5, sx+0.5, 0.4, 3.0, z-0.5, z+0.5, "wood")

# --- paths: main path spawn->stages, cross arm to the treadmill pad ---
box("Paths", "PathMain", -6, 6, 0, 0.4, -44, 60, "path")
box("Paths", "PathCross", -22, -6, 0, 0.4, -6, 6, "path")
for sx in (-6.5, 6.5):   # darker edge strips, cut where the cross arm joins
    if sx > 0:
        box("Paths", "PathEdge", sx-0.5, sx+0.5, 0, 0.5, -44, 60, "path_edge")
    else:
        box("Paths", "PathEdge", sx-0.5, sx+0.5, 0, 0.5, -44, -6, "path_edge")
        box("Paths", "PathEdge", sx-0.5, sx+0.5, 0, 0.5, 6, 60, "path_edge")
box("Paths", "PathEdge", -22, -7, 0, 0.5, -7, -6, "path_edge")
box("Paths", "PathEdge", -22, -7, 0, 0.5, 6, 7, "path_edge")

# --- treadmill pad: grey stone along the left wall, raised back tier with steps ---
box("TreadmillPad", "Floor", -62, -22, 0, 1, -44, 32, "stone")
box("TreadmillPad", "RearTier", -62, -44, 1, 4.5, -38, 26, "stone")
box("TreadmillPad", "TierStep", -44, -42, 1, 2.75, -38, 26, "stone_dark")
for z0, z1, top in ((-40, -38, 3.3), (-42, -40, 2.2), (26, 28, 3.3), (28, 30, 2.2)):
    box("TreadmillPad", "EndStep", -62, -44, 1, top, z0, z1, "stone_dark")
box("TreadmillPad", "Rim", -22.6, -22, 0, 1.6, -44, -7, "stone_dark")
box("TreadmillPad", "Rim", -22.6, -22, 0, 1.6, 7, 32, "stone_dark")

# --- display rectangle: grey stone on the right, long across, two rows (back row raised) ---
box("DisplayPad", "Base", 10, 64, 0, 1, -8, 26, "stone")
box("DisplayPad", "Ledge", 10, 64, 1, 4.5, -8, 5, "stone")
box("DisplayPad", "Step", 10, 64, 1, 3.3, 5, 7, "stone_dark")
box("DisplayPad", "Step", 10, 64, 1, 2.2, 7, 9, "stone_dark")
box("DisplayPad", "BackWall", 10, 64, 4.5, 6.5, -9, -8, "stone_dark")
box("DisplayPad", "Rim", 10, 64, 0, 1.6, 26, 26.6, "stone_dark")
box("DisplayPad", "Rim", 64, 64.6, 0, 1.6, -9, 26.6, "stone_dark")

# --- walls: red-brown brick with grass tops, two tiers like the reference ---
def wall(name, x0, x1, h, z0, z1, top="grass_top"):
    box("Walls", name, x0, x1, 0, h, z0, z1, "brick")
    box("Walls", name + "Top", x0-0.6, x1+0.6, h, h+1.2, z0-0.6, z1+0.6, top)
wall("LeftWall", -80, -62, 15, -60, 61)
wall("LeftWallUpper", -180, -80, 28, -60, 61)
wall("RightWall", 66, 84, 15, -60, 61)
wall("RightWallUpper", 84, 180, 28, -60, 61)
wall("BackWallL", -80, -36, 20.2, -60, -44)
wall("BackWallR", 36, 66, 20.2, -60, -44)
wall("FrontBank", -210, 210, 28, 79, 140)
box("Walls", "RightWallCorner", 64, 66, 0, 15, -44, 61, "brick_dark")

# --- stage corridor: 14 stages (existing Stage1..Stage14 models stay, recoloured lane) ---
STAGE_Z0, STAGE_STEP = -67, 40
STAGE_COL = ["b0b6be","50c846","326eeb","9646e6","fac828","f58228","e13237",
             "f05abe","28c8d2","8ce646","5a78ff","ffaa3c","be5aff","ffd750"]
for i in range(14):
    z = STAGE_Z0 - STAGE_STEP*i
    # gate proxy for the Blender preview only (Studio keeps the real Stage models)
    box("StageGates", f"Stage{i+1}_L", -18, -15, 0, 21, z-15, z-12, STAGE_COL[i], preview_only=True)
    box("StageGates", f"Stage{i+1}_R", 15, 18, 0, 21, z-15, z-12, STAGE_COL[i], preview_only=True)
    box("StageGates", f"Stage{i+1}_Top", -18, 18, 17, 21, z-15, z-12, STAGE_COL[i], preview_only=True)
box("Lane", "LaneFloor", -18, 18, 0, 1, -612, -44, "stone", preview_only=True)
box("Lane", "LaneWallL", -36, -18, 0, 19.5, -620, -60, "brick", preview_only=True)
box("Lane", "LaneWallR", 18, 36, 0, 19.5, -620, -60, "brick", preview_only=True)

# --- voxel trees on the wall tops and in the yard corners (preview; Studio keeps its trees) ---
def tree(x, y, z, s=1.0):
    box("Trees", "Trunk", x-1*s, x+1*s, y, y+5*s, z-1*s, z+1*s, "wood", preview_only=True)
    for i, w in enumerate((12, 9, 6)):
        w *= s
        box("Trees", "Leaves", x-w/2, x+w/2, y+(4+3.2*i)*s, y+(7.4+3.2*i)*s, z-w/2, z+w/2, "grass_top", preview_only=True)
for (x, y, z) in [(-70,16.2,-20),(-70,16.2,20),(-72,16.2,50),(-100,29.2,-30),(-120,29.2,10),(-110,29.2,45),
                  (75,16.2,-30),(75,16.2,30),(100,29.2,0),(120,29.2,-35),(-58,20.7,-52),(50,20.7,-52),
                  (38,0,-34),(46,0,-42),(44,0,50),(-18,0,34),(-50,0,50),(-30,0,46),(-14,0,-36),(-40,29.2,100),(30,29.2,100)]:
    tree(x, y, z)

# --- moves for existing Studio models (pivot positions; ry = yaw in degrees) ---
moves = {
    "Stations": {   # same rows as now, shifted 6 studs toward the back wall like the reference
        "KingsEndgame": [-52.4, None, -30], "CastleClimb": [-52.1, None, -14],
        "GrandmasterGlide": [-52.6, None, 2], "QueenDash": [-52.4, None, 18],
        "RookRig": [-30.9, None, -33], "KnightSprint": [-31, None, -15],
        "PawnMill": [-32.1, None, 3], "BishopRun": [-30.9, None, 21],
    },
    "SetDisplays": {}, "Scenery.Trees": {"Tree@-34,-41": [-30, None, 46], "HubTree3": [-14, None, -36]},
    "Scenery": {"Bush@64,18": [58, None, 44], "Bush@67,19": [60, None, 44], "Bush@60,-30": [58, None, -30], "Bush@62,-30": [60, None, -30]},
}
low = ["Wooden", "Marble", "Jade", "Ruby", "Sapphire"]
high = ["Gold", "Obsidian", "Royal", "Crystal", "Cosmic", "Champion"]
for i, n in enumerate(low):
    moves["SetDisplays"][n] = [19 + 8.8*i, None, 17, "faceZ"]
for i, n in enumerate(high):
    moves["SetDisplays"][n] = [14.5 + 8.8*i, None, -1.5, "faceZ"]
shopzone = {"pos": [37, 6, 9], "size": [54, 12, 34]}

out = dict(note=__doc__.strip().splitlines()[0], ref_colors=REF, parts=parts, moves=moves, shopzone=shopzone)
here = os.path.dirname(os.path.abspath(__file__))
with open(os.path.join(here, "hub_layout.json"), "w") as f:
    json.dump(out, f, indent=1)
print(len(parts), "parts;", sum(1 for p in parts if not p.get("preview_only")), "go to Studio")

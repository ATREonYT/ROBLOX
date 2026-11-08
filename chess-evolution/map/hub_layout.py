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
    "brick": "BD532D", "brick_dark": "A04939", "stone": "AAB7BA", "stone_dark": "8E9A9E", "stone_bay": "98A3A7",
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

def wedge(group, name, x0, x1, y0, y1, z0, z1, col, low, mat="Plastic"):
    """Slope part. low = side the slope runs down to: '+x', '-x', '+z' or '-z'."""
    parts.append(dict(group=group, name=name, kind="Wedge", low=low, pos=[(x0+x1)/2, (y0+y1)/2, (z0+z1)/2],
                      size=[x1-x0, y1-y0, z1-z0], color=col, material=mat))

# --- paths: main path spawn->stages, a left arm to the middle of the treadmill pad,
#     and a right arm that turns and runs straight up to the middle of the display pad ---
box("Paths", "PathMain", -6, 6, 0, 0.4, -44, 60, "path")
box("Paths", "PathCross", -22, -6, 0, 0.4, -8, 4, "path")
box("Paths", "PathRight", 6, 43, 0, 0.4, 33, 43, "path")
box("Paths", "PathToDisplays", 31, 43, 0, 0.4, 28, 33, "path")
box("Paths", "PathEdge", 6.0, 7.0, 0, 0.5, -44, 33, "path_edge")
box("Paths", "PathEdge", 6.0, 7.0, 0, 0.5, 43, 60, "path_edge")
box("Paths", "PathEdge", -7.0, -6.0, 0, 0.5, -44, -8, "path_edge")
box("Paths", "PathEdge", -7.0, -6.0, 0, 0.5, 4, 60, "path_edge")
box("Paths", "PathEdge", -22, -7, 0, 0.5, -9, -8, "path_edge")
box("Paths", "PathEdge", -22, -7, 0, 0.5, 4, 5, "path_edge")
box("Paths", "PathEdge", 7, 44, 0, 0.5, 43, 44, "path_edge")
box("Paths", "PathEdge", 7, 31, 0, 0.5, 32, 33, "path_edge")
box("Paths", "PathEdge", 43, 44, 0, 0.5, 28, 43, "path_edge")
box("Paths", "PathEdge", 30, 31, 0, 0.5, 28, 32, "path_edge")

# --- treadmill pad (close-up ref 2): wide stone platform, raised back tier,
#     two sunken bays in the front row either side of where the path arrives ---
S, SD = "stone", "stone_dark"
box("TreadmillPad", "Platform", -62, -39, 0, 2, -42, 38, S)
box("TreadmillPad", "Platform", -39, -25, 0, 2, -42, -19.5, S)
box("TreadmillPad", "Platform", -39, -25, 0, 2, -4.5, 0.5, S)
box("TreadmillPad", "Platform", -39, -25, 0, 2, 15.5, 38, S)
box("TreadmillPad", "FrontLip", -25, -24, 0, 2, -42, 38, SD)
box("TreadmillPad", "FrontStep", -24, -22, 0, 1, -42, 38, SD)
box("TreadmillPad", "BayFloor", -39, -25, 0, 0.5, -19.5, -4.5, "stone_bay")
box("TreadmillPad", "BayFloor", -39, -25, 0, 0.5, 0.5, 15.5, "stone_bay")
box("TreadmillPad", "RearTier", -62, -44, 2, 5.5, -36, 32, S)
box("TreadmillPad", "TierStep", -44, -42, 2, 3.75, -36, 32, SD)
for z0, z1, top in ((-38, -36, 4.6), (-40, -38, 3.3), (32, 34, 4.6), (34, 36, 3.3)):
    box("TreadmillPad", "EndStep", -62, -44, 2, top, z0, z1, SD)
wedge("TreadmillPad", "EndSlope", -62, -24, 0, 2, -44, -42, SD, "-z")
wedge("TreadmillPad", "EndSlope", -62, -24, 0, 2, 38, 41, SD, "+z")

# --- display pad (close-up ref 1): against the wall, raised back row of 6 cases,
#     sunken front bay with 5 cases, sloped ends, a step down to the grass ---
box("DisplayPad", "BackTier", 12, 62, 0, 4.5, -8, 5, S)
box("DisplayPad", "Platform", 12, 62, 0, 2, 5, 9, S)
box("DisplayPad", "Platform", 12, 16, 0, 2, 9, 23, S)
box("DisplayPad", "Platform", 58, 62, 0, 2, 9, 23, S)
box("DisplayPad", "Platform", 12, 62, 0, 2, 23, 26, S)
box("DisplayPad", "FrontStep", 12, 62, 0, 1, 26, 28, SD)
box("DisplayPad", "BayFloor", 16, 58, 0, 0.5, 9, 23, "stone_bay")
wedge("DisplayPad", "BaySlope", 16, 19, 0.5, 2, 9, 23, SD, "+x")
wedge("DisplayPad", "BaySlope", 55, 58, 0.5, 2, 9, 23, SD, "-x")
wedge("DisplayPad", "EndSlope", 7.5, 12, 0, 2, -8, 28, SD, "-x")
wedge("DisplayPad", "EndSlope", 62, 66, 0, 2, -8, 28, SD, "+x")
box("DisplayPad", "BackWall", 12, 62, 4.5, 6.5, -9, -8, SD)

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
moves = {   # [x, height change, z, flag]: x/z are footprint centres
    "Stations": {
        "KingsEndgame": [-52.4, 0.95, -26], "CastleClimb": [-52.1, 0.95, -10],
        "GrandmasterGlide": [-52.6, 0.95, 6], "QueenDash": [-52.4, 0.95, 22],
        "RookRig": [-30.9, 1.0, -32], "KnightSprint": [-31, -0.5, -12],
        "PawnMill": [-32.1, -0.5, 8], "BishopRun": [-30.9, 1.0, 28],
    },
    "SetDisplays": {}, "Scenery.Trees": {"Tree@-30,46": [-30, 0, 48], "HubTree3": [-14, 0, -36], "Shrub@13,40": [13, 0, 52], "HubTree1": [-14.5, 0, 36]},
    "Scenery": {},
}
low = ["Wooden", "Marble", "Jade", "Ruby", "Sapphire"]
high = ["Gold", "Obsidian", "Royal", "Crystal", "Cosmic", "Champion"]
for i, n in enumerate(low):
    moves["SetDisplays"][n] = [round(20.4 + 8.3*i, 2), -0.5, 16, "faceZ"]
for i, n in enumerate(high):
    moves["SetDisplays"][n] = [round(16.2 + 8.3*i, 2), 0, -1.5, "faceZ"]
shopzone = {"pos": [37, 6, 10], "size": [58, 12, 38]}

out = dict(note=__doc__.strip().splitlines()[0], ref_colors=REF, parts=parts, moves=moves, shopzone=shopzone)
here = os.path.dirname(os.path.abspath(__file__))
with open(os.path.join(here, "hub_layout.json"), "w") as f:
    json.dump(out, f, indent=1)
print(len(parts), "parts;", sum(1 for p in parts if not p.get("preview_only")), "go to Studio")

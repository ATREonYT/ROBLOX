"""Draws the Halloween lobby layout plan for the owner (he builds it himself in Studio).

    python3 huzz-valley/tools/world/halloween_layout.py      (from the repo root; needs Pillow)

Writes huzz-valley/docs/previews/halloween-lobby-layout.png: a top-down map, to scale, of the bigger Halloween lobby
copied from Huss Valley's Halloween lobby (design/references/hv-halloween/*.jpg). His own pieces are drawn at their
real positions, measured from places/HUSSANIME.rbxl with tools/world/measure_halloween_lobby.luau (Oct 18). Prints
the numbered object list as a Markdown table for docs/HALLOWEEN-LOBBY-PLAN.md, so the two never disagree.

World axes: X goes right (east), Z goes down the picture (south). North (-Z) is up, toward the Halloween field.
Every box is (x0, z0, x1, z1) in studs, world coordinates, so he can type them into Studio's Position boxes.
"""
import math
import os
from PIL import Image, ImageDraw, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
GAME = os.path.normpath(os.path.join(HERE, "..", ".."))
OUT = os.path.join(GAME, "docs", "previews", "halloween-lobby-layout.png")
FONT = os.path.join(GAME, "tools", "preview", "fonts", "Montserrat-Variable.ttf")

# ---------------------------------------------------------------- measured (his place, Oct 18) --------------
FLOOR = (353.9, -615.9, 453.9, -503.4)  # Maps.Spawn.SpawnBaseplate, top Y 16.9
FIELD = (256.1, -780.8, 576.1, -615.9)  # Halloween_Map.GrassBaseplate, top Y 16.9 (loads here each game)
KEEP = [  # scripts look these up: never move or rename
    ("K1", "Lobby floor (SpawnBaseplate)", FLOOR, "100 x 112 x 13"),
    ("K2", "SpawnLocation", (398.1, -534.8, 410.1, -522.8), "12 x 12 x 1"),
    ("K3", "Spin Wheel", (361.7, -545.4, 365.9, -531.4), "4 x 14 x 14"),
    ("K4", "Small Spin Wheel", (386.4, -547.3, 389.7, -546.3), "3 x 1 x 3"),
]
GIRLS = ("G", "Girl stand (4 girls, fence, roof light)", (394.1, -564.4, 414.6, -541.7), "20 x 23 x 18")
HIS = [  # his decorations: fine where they are, he may move them
    ("Pumpkin", (369.8, -516.6, 382.7, -503.8)), ("Pumpkin", (354.8, -523.5, 373.9, -504.4)),
    ("Pumpkin", (355.5, -530.6, 366.6, -519.6)), ("Pumpkin", (438.4, -604.2, 457.5, -585.1)),
    ("Lantern", (420.2, -514.1, 422.2, -512.1)), ("Lantern", (370.4, -569.7, 372.0, -568.1)),
    ("Grave", (427.6, -519.9, 434.8, -509.4)), ("Grave", (366.1, -590.1, 375.9, -579.6)),
    ("Tree", (435.7, -524.8, 456.8, -503.7)), ("Tree", (350.0, -607.1, 371.1, -586.0)),
    ("Podium", (440.1, -546.5, 450.0, -528.5)), ("Podium", (441.6, -565.2, 449.7, -548.0)),
    ("Podium", (439.6, -584.9, 450.0, -566.7)),
    ("Block", (359.7, -576.5, 365.2, -570.8)), ("Block", (359.5, -559.7, 364.7, -554.3)),
    ("Pad", (370.2, -602.1, 376.7, -596.1)), ("Pad", (379.7, -602.1, 386.2, -596.1)),
    ("Pad", (415.9, -602.1, 422.4, -596.1)), ("Pad", (422.9, -602.1, 429.4, -596.1)),
    ("Pad", (429.9, -602.1, 436.4, -596.1)),
]
# his plank path (loose Workspace parts): the loop round the girls and the line north onto the field
PLANKS = [(402.0, -621.8), (402.0, -613.8), (402.0, -605.8), (402.0, -597.8), (401.7, -594.6), (400.7, -591.6),
          (399.1, -588.8), (396.9, -586.4), (394.4, -584.6), (391.4, -583.3), (388.1, -582.0), (385.0, -580.3),
          (382.8, -578.5), (381.2, -576.1), (380.4, -573.4), (380.0, -569.7), (380.0, -566.0), (380.1, -562.0),
          (380.1, -558.3), (379.9, -554.6), (379.4, -550.9), (378.6, -547.2), (378.2, -544.2), (378.6, -541.2),
          (379.7, -538.3), (381.4, -535.8), (383.7, -533.8), (387.0, -531.7), (390.3, -529.7), (393.7, -527.8),
          (397.1, -526.1), (400.6, -524.4), (404.2, -522.9), (407.3, -522.0), (410.6, -521.7), (413.8, -522.0),
          (416.9, -522.9), (419.8, -524.4), (422.4, -526.5), (424.5, -528.9), (426.1, -531.8), (427.2, -534.9),
          (427.6, -538.1), (427.6, -541.9), (427.7, -545.6), (428.1, -549.2), (428.9, -552.8), (429.9, -556.3),
          (430.8, -559.7), (431.2, -563.1), (431.2, -566.6), (430.6, -570.0), (429.6, -573.3), (428.1, -576.5),
          (426.3, -579.4), (424.0, -582.0), (421.4, -584.3), (418.5, -586.2), (415.3, -587.6), (412.2, -589.1),
          (409.3, -591.0), (406.6, -593.3), (404.4, -595.9), (402.5, -598.8), (402.0, -601.8)]

# ---------------------------------------------------------------- the new lobby ----------------------------
G = 16.9  # ground top height (his floor and the field)
X0, X1, Z0, Z1 = 303.9, 503.9, -615.9, -433.4  # new walkable lobby (200 x 182.5): about 3x his island

# Each new object: number, name, zone, boxes, size text (W x D x H), Roblox colour, material, how to build it.
# zone picks the plan colour. boxes: list of (x0, z0, x1, z1); shape "rect" | "oval" | "dots".
OBJ = [
    dict(n=1, name="Lobby ground West", zone="ground", boxes=[(303.9, -615.9, 353.9, -433.4)], size="50 x 182.5 x 13",
         color="105, 45, 42 (dark red-brown)", mat="Plastic, TopSurface = Studs", note="Position 328.9, 10.4, -524.65. Top at 16.9, level with your floor."),
    dict(n=2, name="Lobby ground East", zone="ground", boxes=[(453.9, -615.9, 503.9, -433.4)], size="50 x 182.5 x 13",
         color="105, 45, 42", mat="Plastic, TopSurface = Studs", note="Position 478.9, 10.4, -524.65."),
    dict(n=3, name="Lobby ground South", zone="ground", boxes=[(353.9, -503.4, 453.9, -433.4)], size="100 x 70 x 13",
         color="105, 45, 42", mat="Plastic, TopSurface = Studs", note="Position 403.9, 10.4, -468.4."),
    dict(n=4, name="Orange lane inside the fence", zone="lane",
         boxes=[(306.9, -600.0, 314.9, -436.4), (314.9, -444.4, 492.9, -436.4), (492.9, -600.0, 500.9, -436.4)],
         size="8 wide x 0.2 thick", color="230, 95, 30 (orange)", mat="Plastic, Studs on top", note="Plates lying on the ground (bottom at 16.9)."),
    dict(n=5, name="Gothic fence (W, S, E edges)", zone="fence", boxes=[], size="pillars 3 x 3 x 8 every 12; rails 9 x 1 x 5",
         color="pillars 170, 110, 140 (mauve stone); rails 95, 55, 75; diamonds 70, 140, 60", mat="Plastic (pillars Slate if you like)",
         note="On the outer edge. North side stays open to the field. About 48 pillars."),
    dict(n=6, name="Fence lamps", zone="light", boxes=[], size="1 x 1 x 2 on every 3rd pillar",
         color="frame 30, 25, 35; glow 255, 150, 60", mat="Neon glow cube + PointLight (orange, Range 14, Brightness 1.2)",
         note="About 16 lamps; a light in every other one (8 lights)."),
    dict(n=7, name="Haunted house", zone="house", boxes=[(374.0, -476.0, 434.0, -446.0)], size="60 x 30 x 30 (roof peak 42)",
         color="walls 215, 150, 140 (pink brick); trim 130, 70, 65; roof 70, 68, 75; door 120, 25, 30",
         mat="Brick walls, Wood trim, Slate roof; windows Neon 255, 140, 40", note="Front faces north, toward the spawn. 6 lit windows, 2 SurfaceLights."),
    dict(n=8, name="Porch with steps", zone="house", boxes=[(389.0, -484.0, 419.0, -476.0)], size="30 x 8 x 12",
         color="deck 130, 70, 65; posts 110, 60, 55", mat="Wood", note="4 posts, small roof, 2 steps, a lantern each side."),
    dict(n=9, name="Stone path to the house", zone="path", boxes=[(396.0, -503.4, 412.0, -484.0)], size="16 x 19 x 0.2",
         color="150, 105, 125 (pink-grey stone); bone tiles 225, 215, 220", mat="Slate", note="Keep it empty."),
    dict(n=10, name="Pond", zone="water", shape="oval", boxes=[(315.0, -474.0, 345.0, -450.0)], size="30 x 24 (rim 2 wide, 1 tall)",
         color="water 110, 130, 210; rim 150, 140, 165", mat="Water: Glass, Transparency 0.25; rim Slate", note="Lies on the ground; a purple PointLight in the middle."),
    dict(n=11, name="Willow trees (x5)", zone="tree", shape="oval",
         boxes=[(348.0, -458.0, 364.0, -442.0), (314.0, -502.0, 330.0, -486.0), (444.0, -458.0, 460.0, -442.0),
                (466.0, -500.0, 482.0, -484.0), (322.0, -536.0, 338.0, -520.0)],
         size="16 x 16 x 26", color="trunk 100, 40, 80 (purple-brown); leaves 55, 95, 60", mat="Wood trunk; leaves Grass or Plastic",
         note="Trunk 4 x 4, canopy blocks, 12 hanging leaf strips 1 x 1 x 10. Leaves CanCollide off."),
    dict(n=12, name="Gravestone patch", zone="grave", boxes=[(318.0, -588.0, 348.0, -556.0)], size="30 x 32; stones 3 x 1 x 4",
         color="dirt 70, 40, 40; stones 150, 140, 165; crosses 120, 110, 130", mat="Slate stones, Plastic dirt",
         note="12 stones, 2 crosses, a low broken fence, 6 candles, 2 lanterns (purple light)."),
    dict(n=13, name="Pumpkin patch", zone="pumpkin", boxes=[(460.0, -548.0, 490.0, -504.0)], size="30 x 44; pumpkins 3 x 3 x 3",
         color="dirt 80, 45, 30; pumpkins 230, 110, 30; stems 40, 110, 40", mat="Plastic; faces Neon 255, 170, 40",
         note="10 small pumpkins, 4 with glowing faces."),
    dict(n=14, name="Giant pumpkin (Pumpkin Hunt)", zone="pumpkin", boxes=[(466.0, -536.0, 486.0, -516.0)], size="20 x 20 x 16",
         color="230, 110, 30; pad 120, 50, 170 (purple)", mat="Plastic blocks stacked round; face Neon",
         note="On a 24 x 24 purple pad, one orange PointLight. Decoration only for now."),
    dict(n=15, name="Shop stall", zone="shop", boxes=[(466.0, -464.0, 484.0, -454.0)], size="18 x 10 x 12",
         color="counter 150, 90, 55; awning stripes 120, 200, 240 and white", mat="Wood counter, Plastic awning",
         note="Decoration only: it sells nothing."),
    dict(n=16, name="Gift box", zone="shop", boxes=[(486.0, -462.0, 491.0, -457.0)], size="5 x 5 x 5",
         color="box 220, 30, 30; ribbon 250, 210, 40", mat="Plastic", note="Decoration only."),
    dict(n=17, name="Coffin crates (x2)", zone="crate", boxes=[(470.0, -578.0, 475.0, -575.0), (479.0, -578.0, 484.0, -575.0)],
         size="5 x 3 x 9 each", color="30, 25, 35 (black); faces and edges Neon 255, 130, 30", mat="Plastic + Neon strips",
         note="Standing up, faces toward the girls (west). One orange PointLight between them."),
    dict(n=18, name="Treat chest", zone="crate", boxes=[(470.0, -593.0, 477.0, -589.0)], size="7 x 4 x 5",
         color="body 240, 140, 190 (pink); trim white", mat="Plastic", note="Decoration only."),
    dict(n=19, name="Candles and lanterns", zone="light", shape="dots",
         boxes=[(326, -552, 1, 1), (340, -552, 1, 1), (384, -486, 1, 1), (424, -486, 1, 1), (462, -540, 1, 1), (488, -512, 1, 1),
                (468, -571, 1, 1), (486, -571, 1, 1), (318, -446, 1, 1), (346, -478, 1, 1)],
         size="candle 0.6 x 0.6 x 1.5; lantern 1.5 x 1.5 x 2.5", color="wax 235, 230, 220; flame Neon 255, 170, 60",
         mat="Plastic + Neon", note="Groups of 3 to 5 next to the attractions, never on a path."),
    dict(n=20, name="Floor tile patches (x14)", zone="tile", boxes=[
        (322, -612, 330, -604), (338, -520, 346, -512), (458, -606, 468, -600), (470, -482, 480, -476),
        (360, -496, 366, -482), (442, -496, 448, -482), (318, -538, 324, -524), (484, -560, 490, -546),
        (330, -500, 340, -494), (416, -496, 426, -490), (382, -500, 390, -492), (494, -520, 500, -510),
        (308, -470, 312, -462), (456, -566, 462, -556)],
        size="4 x 8 to 10 x 10, 0.2 thick", color="orange 230, 95, 30; purple 95, 30, 80; green 60, 70, 25; stone 160, 110, 135",
        mat="Plastic, Studs on top", note="Scatter them; mix the four colours like Huss Valley."),
    dict(n=21, name="Back yard ring (behind the fence)", zone="yard",
         boxes=[(263.9, -615.9, 303.9, -393.4), (503.9, -615.9, 543.9, -393.4), (303.9, -433.4, 503.9, -393.4)],
         size="40 wide x 11 thick", color="60, 32, 48 (dark plum)", mat="Plastic",
         note="Top at 14.9 (2 lower than the lobby). Hides the water right behind the fence."),
    dict(n=22, name="Dead trees (x10)", zone="dead", shape="dots",
         boxes=[(280, -600, 1, 1), (290, -560, 1, 1), (276, -470, 1, 1), (292, -420, 1, 1), (340, -410, 1, 1),
                (470, -405, 1, 1), (522, -425, 1, 1), (530, -480, 1, 1), (516, -575, 1, 1), (534, -608, 1, 1)],
         size="trunk 2 x 2 x 18, 3 crooked branches", color="50, 30, 50", mat="Wood", note="CanCollide off."),
    dict(n=23, name="Crooked houses (x5, far)", zone="far",
         boxes=[(272, -528, 292, -512), (300, -418, 320, -402), (420, -414, 444, -398), (516, -540, 536, -522),
                (512, -430, 532, -410)],
         size="20 x 16 x 26 to 34", color="70, 50, 95 (dark purple); 2 or 3 windows Neon 255, 150, 60", mat="Plastic",
         note="Simple blocks with a pointed roof. No inside, CanCollide off."),
    dict(n=24, name="Far hills", zone="hill",
         boxes=[(228.0, -393.4, 580.0, -358.0), (228.0, -615.9, 263.9, -393.4), (543.9, -615.9, 580.0, -393.4)],
         size="20 to 36 tall, 3 blocks a side", color="40, 35, 80 (night blue)", mat="Plastic, CanCollide off",
         note="Stand on the water (bottom at 3.5). From the lobby they make the horizon."),
]
CLEAR = [  # keep empty (players walk or watch here)
    ("Watch edge: keep low", (303.9, -615.9, 503.9, -600.0)),
    ("Spin wheel front", (348.0, -550.0, 361.0, -527.0)),
    ("", (366.0, -550.0, 378.0, -527.0)),
    ("Spawn", (392.0, -541.0, 416.0, -516.0)),
]

ZONES = {  # plan colours (soft), border colours
    "ground": ((228, 196, 190), (160, 110, 104)), "lane": ((250, 196, 150), (220, 120, 60)),
    "fence": ((150, 110, 135), (90, 60, 80)), "light": ((255, 214, 120), (200, 130, 20)),
    "house": ((236, 190, 210), (170, 90, 130)), "path": ((218, 210, 226), (150, 130, 160)),
    "water": ((176, 200, 245), (90, 120, 200)), "tree": ((176, 216, 170), (70, 130, 80)),
    "grave": ((206, 202, 222), (120, 110, 150)), "pumpkin": ((255, 210, 150), (210, 120, 40)),
    "shop": ((178, 220, 244), (60, 140, 190)), "crate": ((214, 196, 240), (120, 90, 180)),
    "tile": ((230, 210, 235), (150, 110, 160)), "yard": ((205, 192, 214), (140, 120, 160)),
    "dead": ((170, 150, 170), (90, 70, 90)), "far": ((190, 180, 220), (110, 95, 150)),
    "hill": ((180, 182, 214), (110, 112, 160)),
}
TILE_COLOURS = [(250, 180, 130), (205, 160, 200), (190, 205, 150), (225, 200, 210)]

# ---------------------------------------------------------------- drawing ----------------------------------
W = 1600
WX0, WX1, WZ0, WZ1 = 224.0, 584.0, -630.0, -366.0  # world window
ML, MT, MR = 64, 120, 36
S = (W - ML - MR) / (WX1 - WX0)  # pixels per stud
MAPH = int((WZ1 - WZ0) * S)


def font(size, weight="Medium"):
    f = ImageFont.truetype(FONT, size)
    try:
        f.set_variation_by_name(weight)
    except Exception:
        pass
    return f


def px(x, z):
    return (ML + (x - WX0) * S, MT + (z - WZ0) * S)


def rect_px(b):
    a, c = px(b[0], b[1]), px(b[2], b[3])
    return [min(a[0], c[0]), min(a[1], c[1]), max(a[0], c[0]), max(a[1], c[1])]


def hatch(img, box, color, step=10):
    layer = Image.new("RGBA", img.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    x0, y0, x1, y1 = [int(v) for v in rect_px(box)]
    for k in range(x0 - (y1 - y0), x1, step):
        d.line([(k, y1), (k + (y1 - y0), y0)], fill=color, width=2)
    mask = Image.new("L", img.size, 0)
    ImageDraw.Draw(mask).rectangle([x0, y0, x1, y1], fill=255)
    img.paste(layer, (0, 0), Image.composite(layer, Image.new("RGBA", img.size, (0, 0, 0, 0)), mask))


def dashed_rect(d, box, color, width=3, dash=10):
    x0, y0, x1, y1 = rect_px(box)
    for (a, b) in [((x0, y0), (x1, y0)), ((x1, y0), (x1, y1)), ((x1, y1), (x0, y1)), ((x0, y1), (x0, y0))]:
        length = math.dist(a, b)
        n = max(1, int(length // (dash * 2)))
        for i in range(n + 1):
            t0, t1 = (i * 2 * dash) / length, min(1, (i * 2 * dash + dash) / length)
            if t0 >= 1:
                break
            d.line([(a[0] + (b[0] - a[0]) * t0, a[1] + (b[1] - a[1]) * t0), (a[0] + (b[0] - a[0]) * t1, a[1] + (b[1] - a[1]) * t1)], fill=color, width=width)


def badge(d, cx, cy, text, fill=(40, 30, 50), fg=(255, 255, 255), r=13):
    d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=fill, outline=(255, 255, 255), width=2)
    f = font(14 if len(text) < 3 else 12, "Bold")
    d.text((cx, cy), text, font=f, fill=fg, anchor="mm")


def label(d, x, y, text, size=13, weight="SemiBold", fill=(40, 30, 50), anchor="mm"):
    f = font(size, weight)
    bb = d.textbbox((x, y), text, font=f, anchor=anchor)
    d.rounded_rectangle([bb[0] - 4, bb[1] - 2, bb[2] + 4, bb[3] + 2], radius=4, fill=(255, 255, 255, 215))
    d.text((x, y), text, font=f, fill=fill, anchor=anchor)


def draw():
    legend_rows = len(OBJ) + 6
    H = MT + MAPH + 60 + (legend_rows // 2 + 2) * 46 + 250
    img = Image.new("RGBA", (W, H), (250, 248, 252, 255))
    d = ImageDraw.Draw(img, "RGBA")

    # title
    d.text((ML, 30), "Halloween lobby: the new, bigger layout (seen from above)", font=font(34, "ExtraBold"), fill=(40, 30, 50))
    d.text((ML, 76), "To scale, 1 square = 10 studs. Numbers are world X / Z for Studio's Position. North (up) is the Halloween field. "
           "Ground top height 16.9 everywhere.", font=font(17, "Medium"), fill=(90, 80, 100))

    # map background = water (the ocean part)
    d.rectangle([ML, MT, ML + (WX1 - WX0) * S, MT + MAPH], fill=(196, 214, 236))
    # field (north)
    f = rect_px((max(FIELD[0], WX0), WZ0, min(FIELD[2], WX1), FIELD[3]))
    d.rectangle(f, fill=(246, 222, 190), outline=(200, 150, 90), width=2)
    label(d, (f[0] + f[2]) / 2, (f[1] + f[3]) / 2 - 2, "HALLOWEEN FIELD (loads here each game: keep the lobby's north edge touching it)", 14, "Bold", (150, 90, 30))

    order = ["hill", "far", "yard", "dead", "ground"]
    for z in order:  # background first
        for o in OBJ:
            if o["zone"] == z and o.get("shape") != "dots":
                fill, edge = ZONES[z]
                for b in o["boxes"]:
                    d.rectangle(rect_px(b), fill=fill, outline=edge, width=1)
    # his floor
    d.rectangle(rect_px(FLOOR), fill=(250, 214, 168), outline=(210, 140, 70), width=2)
    # tiles
    tiles = next(o for o in OBJ if o["n"] == 20)
    for i, b in enumerate(tiles["boxes"]):
        d.rectangle(rect_px(b), fill=TILE_COLOURS[i % 4], outline=(150, 110, 160), width=1)
    # the rest
    for o in OBJ:
        if o["zone"] in order or o["n"] in (5, 6, 19, 20, 22):
            continue
        fill, edge = ZONES[o["zone"]]
        for b in o["boxes"]:
            r = rect_px(b)
            if o.get("shape") == "oval":
                d.ellipse(r, fill=fill, outline=edge, width=2)
            else:
                d.rectangle(r, fill=fill, outline=edge, width=2)
    # pumpkins inside the patch (small dots)
    for (x, z) in [(463, -545), (469, -544), (482, -546), (488, -541), (463, -509), (470, -507), (484, -508), (489, -514), (462, -528), (489, -530)]:
        cx, cy = px(x, z)
        d.ellipse([cx - 6, cy - 6, cx + 6, cy + 6], fill=(240, 140, 40), outline=(160, 80, 20))
    # gravestones inside the patch
    for i in range(12):
        x, z = 321 + (i % 4) * 7.5, -584 + (i // 4) * 10
        a, b = px(x, z), px(x + 3, z + 1)
        d.rectangle([a[0], a[1], b[0], b[1] + 2], fill=(130, 120, 150))
    # dead trees, candles
    for o in OBJ:
        if o["n"] in (19, 22):
            fill, edge = ZONES[o["zone"]]
            for b in o["boxes"]:
                cx, cy = px(b[0], b[1])
                rr = 7 if o["n"] == 22 else 5
                d.ellipse([cx - rr, cy - rr, cx + rr, cy + rr], fill=fill, outline=edge, width=2)
    # his plank path
    pts = [px(x, z) for (x, z) in PLANKS]
    d.line(pts, fill=(205, 180, 130), width=int(4 * S), joint="curve")
    d.line(pts, fill=(170, 140, 90), width=1)
    # his decorations
    for name, b in HIS:
        r = rect_px(b)
        if name in ("Tree", "Pumpkin"):
            d.ellipse(r, fill=(205, 205, 205, 200), outline=(130, 130, 130), width=1)
        else:
            d.rectangle(r, fill=(205, 205, 205, 220), outline=(130, 130, 130), width=1)
    # keep-clear hatching
    for name, b in CLEAR:
        hatch(img, b, (60, 160, 90, 150))
        dashed_rect(d, b, (40, 140, 70), 2, 6)
    # fence along W, S, E
    fill, edge = ZONES["fence"]
    pillars = []
    z = Z0
    while z <= Z1 - 1.5:
        pillars.append((X0 + 1.5, z)); pillars.append((X1 - 1.5, z)); z += 12
    x = X0 + 1.5
    while x <= X1 - 1.5:
        pillars.append((x, Z1 - 1.5)); x += 12
    pillars.append((X1 - 1.5, Z1 - 1.5))
    a, b, c, e = px(X0 + 1.5, Z0), px(X0 + 1.5, Z1 - 1.5), px(X1 - 1.5, Z1 - 1.5), px(X1 - 1.5, Z0)
    d.line([a, b, c, e], fill=edge, width=4)
    for i, (x, z) in enumerate(pillars):
        r = rect_px((x - 1.5, z - 1.5, x + 1.5, z + 1.5))
        lamp = i % 3 == 0
        d.rectangle(r, fill=(255, 190, 90) if lamp else fill, outline=edge, width=1)
    # KEEP pieces
    red = (210, 40, 50)
    for k, name, b, size in KEEP:
        if k == "K1":
            dashed_rect(d, b, red, 3, 12)
            continue
        r = rect_px(b)
        d.rectangle(r, fill=(255, 120, 120, 200), outline=red, width=3)
    dashed_rect(d, GIRLS[2], (220, 110, 40), 3, 8)
    d.rectangle(rect_px(GIRLS[2]), fill=(255, 200, 150, 120))

    # labels for new objects
    spots = {
        1: (329, -540, "1"), 2: (466, -560, "2"), 3: (370, -495, "3"), 4: (310.9, -580, "4"), 5: (305.4, -520, "5"),
        6: (305.4, -436, "6"), 7: (404, -462, "7"), 8: (404, -480, "8"), 9: (404, -495, "9"), 10: (330, -462, "10"),
        11: (356, -450, "11"), 12: (333, -572, "12"), 13: (468, -512, "13"), 14: (476, -526, "14"), 15: (475, -459, "15"),
        16: (488.5, -459.5, "16"), 17: (477, -576.5, "17"), 18: (473.5, -591, "18"), 19: (340, -552, "19"), 20: (342, -516, "20"),
        21: (284, -440, "21"), 22: (290, -420, "22"), 23: (282, -520, "23"), 24: (246, -500, "24"),
    }
    names = {
        7: "Haunted house 60x30x30", 10: "Pond 30x24", 12: "Graves 30x32", 14: "Giant pumpkin 20x20x16", 13: "Pumpkin patch",
        15: "Shop stall 18x10x12", 21: "Back yard (lower)", 24: "Hills", 17: "Coffins 5x3x9", 11: "Willow 16x16x26",
        3: "New ground", 1: "New ground", 2: "New ground",
    }
    for n, (x, z, t) in spots.items():
        cx, cy = px(x, z)
        badge(d, cx, cy, t)
        if n in names:
            label(d, cx, cy + 24, names[n], 12, "Bold")
    # the other willows get the badge too
    for b in next(o for o in OBJ if o["n"] == 11)["boxes"][1:]:
        cx, cy = px((b[0] + b[2]) / 2, (b[1] + b[3]) / 2)
        badge(d, cx, cy, "11")
    for b in next(o for o in OBJ if o["n"] == 23)["boxes"][1:]:
        cx, cy = px((b[0] + b[2]) / 2, (b[1] + b[3]) / 2)
        badge(d, cx, cy, "23")
    # KEEP labels
    for k, name, b, size in KEEP:
        cx, cy = px((b[0] + b[2]) / 2, (b[1] + b[3]) / 2)
        if k == "K1":
            cx, cy = px(392, -509)
        badge(d, cx, cy, k, fill=red)
    cx, cy = px(404, -553)
    badge(d, cx, cy, "G", fill=(220, 110, 40))
    label(d, *px(404, -538.5), "KEEP: spawn", 12, "Bold", red)
    label(d, *px(346, -548), "KEEP: spin wheel", 12, "Bold", red, anchor="rm")
    label(d, *px(404, -568), "girls stay here", 12, "Bold", (200, 90, 20))
    label(d, *px(406, -611), "Your plank path to the field: keep it clear", 12, "Bold", (130, 100, 50), anchor="lm")
    label(d, *px(308, -606), "Watch edge: nothing tall (people watch here)", 12, "Bold", (40, 120, 60), anchor="lm")

    # grid + labels
    gx = math.ceil(WX0 / 10) * 10
    while gx <= WX1:
        x = ML + (gx - WX0) * S
        major = int(gx) % 20 == 0
        d.line([(x, MT), (x, MT + MAPH)], fill=(80, 70, 110, 70 if major else 30), width=1)
        if major:
            d.text((x, MT + MAPH + 8), f"{int(gx)}", font=font(13, "SemiBold"), fill=(80, 70, 100), anchor="mt")
            d.text((x, MT - 6), f"{int(gx)}", font=font(13, "SemiBold"), fill=(80, 70, 100), anchor="mb")
        gx += 10
    gz = math.ceil(WZ0 / 10) * 10
    while gz <= WZ1:
        y = MT + (gz - WZ0) * S
        major = int(gz) % 20 == 0
        d.line([(ML, y), (ML + (WX1 - WX0) * S, y)], fill=(80, 70, 110, 70 if major else 30), width=1)
        if major:
            d.text((ML - 6, y), f"{int(gz)}", font=font(13, "SemiBold"), fill=(80, 70, 100), anchor="rm")
        gz += 10
    d.text((ML + (WX1 - WX0) * S / 2, MT + MAPH + 28), "X (studs)  →  east", font=font(13, "Bold"), fill=(80, 70, 100), anchor="mt")
    d.text((14, MT + MAPH / 2), "Z", font=font(15, "Bold"), fill=(80, 70, 100), anchor="mm")
    d.rectangle([ML, MT, ML + (WX1 - WX0) * S, MT + MAPH], outline=(60, 50, 80), width=2)

    # north arrow + scale bar
    nx, ny = ML + (WX1 - WX0) * S - 50, MT + 140
    d.ellipse([nx - 34, ny - 34, nx + 34, ny + 34], fill=(255, 255, 255, 230), outline=(60, 50, 80), width=2)
    d.polygon([(nx, ny - 28), (nx - 12, ny + 8), (nx, ny), (nx + 12, ny + 8)], fill=(210, 40, 50))
    d.text((nx, ny + 20), "N", font=font(16, "ExtraBold"), fill=(60, 50, 80), anchor="mm")
    d.text((nx, ny + 46), "-Z, to the field", font=font(12, "SemiBold"), fill=(60, 50, 80), anchor="mm")
    sx, sy = ML + 20, MT + MAPH - 24
    d.rectangle([sx - 8, sy - 26, sx + 50 * S + 8, sy + 12], fill=(255, 255, 255, 220))
    for i in range(5):
        d.rectangle([sx + i * 10 * S, sy - 6, sx + (i + 1) * 10 * S, sy], fill=(60, 50, 80) if i % 2 == 0 else (255, 255, 255), outline=(60, 50, 80))
    d.text((sx, sy - 10), "0", font=font(12, "SemiBold"), fill=(60, 50, 80), anchor="mb")
    d.text((sx + 50 * S, sy - 10), "50 studs", font=font(12, "SemiBold"), fill=(60, 50, 80), anchor="mb")
    label(d, ML + 60, MT + 20, "water (the Ocean part)", 12, "SemiBold", (60, 90, 140))

    # legend
    y = MT + MAPH + 60
    d.text((ML, y), "Key", font=font(24, "ExtraBold"), fill=(40, 30, 50))
    y += 40
    keyitems = [((255, 120, 120), red, "K1 to K4: KEEP HERE (scripts use it). Don't move, rename or resize."),
                ((255, 200, 150), (220, 110, 40), "G: your girl stand. Keep it where it is (it's the centre of the lobby)."),
                ((205, 205, 205), (130, 130, 130), "Grey: your decorations. Fine where they are; move them if you like."),
                ((230, 250, 235), (40, 140, 70), "Green stripes: keep empty (spawn, spin wheel front, watch edge, paths)."),
                ((250, 214, 168), (210, 140, 70), "Your orange floor (K1). It turns the map's colour after each vote."),
                ((255, 190, 90), ZONES["fence"][1], "Fence pillars; the light ones carry a lamp (6).")]
    for i, (fill, edge, text) in enumerate(keyitems):
        col, row = i % 2, i // 2
        x0, y0 = ML + col * 760, y + row * 34
        d.rectangle([x0, y0, x0 + 26, y0 + 22], fill=fill, outline=edge, width=2)
        d.text((x0 + 36, y0 + 11), text, font=font(15, "Medium"), fill=(40, 30, 50), anchor="lm")
    y += 3 * 34 + 16
    half = (len(OBJ) + 1) // 2
    for i, o in enumerate(OBJ):
        col, row = i // half, i % half
        x0, y0 = ML + col * 760, y + row * 40
        fill, edge = ZONES[o["zone"]]
        d.rectangle([x0, y0 + 4, x0 + 26, y0 + 26], fill=fill, outline=edge, width=2)
        badge(d, x0 + 44, y0 + 15, str(o["n"]))
        d.text((x0 + 64, y0 + 2), o["name"], font=font(15, "Bold"), fill=(40, 30, 50))
        d.text((x0 + 64, y0 + 21), o["size"], font=font(13, "Medium"), fill=(100, 90, 110))
    y += half * 40 + 10
    d.text((ML, y), "Kept pieces (measured in your place):  K1 lobby floor x 353.9 to 453.9, z -615.9 to -503.4 (top 16.9)  ·  K2 SpawnLocation at 404.1, -528.8",
           font=font(14, "SemiBold"), fill=(150, 40, 50))
    d.text((ML, y + 24), "K3 Spin Wheel at 363.8, -538.4  ·  K4 small Spin Wheel at 388.0, -546.8  ·  G girl stand at 404.3, -553.0  ·  Field edge at z -615.9",
           font=font(14, "SemiBold"), fill=(150, 40, 50))
    y += 24
    d.text((ML, y + 26), "Full list with colours, materials and the build order: docs/HALLOWEEN-LOBBY-PLAN.md", font=font(14, "SemiBold"), fill=(90, 80, 100))
    img = img.crop((0, 0, W, y + 60))
    img.convert("RGB").save(OUT, optimize=True)
    print("saved", OUT, img.size, f"{S:.2f} px per stud")


def table():
    print("| # | What | Size in studs (W x D x H) | Colour (RGB) | Material | Where / how |")
    print("|---|---|---|---|---|---|")
    for o in OBJ:
        where = "; ".join(f"x {b[0]:g} to {b[2]:g}, z {b[1]:g} to {b[3]:g}" for b in o["boxes"][:3]) if o.get("shape") != "dots" else ""
        if len(o["boxes"]) > 3 and o.get("shape") != "dots":
            where += f" (+{len(o['boxes']) - 3} more, see the map)"
        if o.get("shape") == "dots":
            where = "the dots on the map"
        where = (where + ". ") if where else ""
        print(f"| {o['n']} | {o['name']} | {o['size']} | {o['color']} | {o['mat']} | {where}{o['note']} |")


if __name__ == "__main__":
    draw()
    table()

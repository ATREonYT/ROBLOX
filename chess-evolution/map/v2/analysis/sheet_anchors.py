"""Alex's anchors (Nov 9 prompt) are in a 1204x1320 comparison sheet; convert them to full-res ref pixels."""
CROPS = {"hub": ((23, 14, 610, 348), "ref/hub_overview.png"), "tread": ((23, 374, 610, 711), "ref/terraceA_closeup.png"),
         "phone": ((23, 737, 610, 968), "ref/terraceB_closeup.png"), "lane": ((23, 994, 610, 1320), "ref/lane_view.png")}
FULLW = {"hub": 3014, "tread": 3024, "phone": 2024, "lane": 3016}
def to_full(view, x, y):
    (l, t, r, b), _ = CROPS[view]; s = FULLW[view] / (r - l)
    return ((x - l) * s, (y - t) * s)
ANCHORS = {
 "hub": {"junction": (327, 156), "branch_tread": (284, 135), "branch_phone": (373, 180), "lane_mouth": (377, 105),
         "cyan_upright": (333, 125), "shore_rock": (160, 266), "phone_far_corner": (404, 141)},
 "tread": {"approach_apron": (311, 554), "shelf_edge_y483": (311, 483), "fp_mid_L": (282, 512), "fp_mid_R": (340, 512),
           "fp_out_L": (145, 511), "fp_out_R": (470, 511), "ramp_L": (209, 500), "ramp_R": (405, 500), "wall_band_y418": (311, 418)},
 "phone": {"approach_front": (308, 916), "pad1": (196, 883), "pad2": (253, 883), "pad3": (310, 883), "pad4": (369, 883), "pad5": (429, 883),
           "pl1": (155, 815), "pl2": (215, 815), "pl3": (276, 815), "pl4": (339, 815), "pl5": (403, 815), "pl6": (468, 815), "wall_base": (311, 800)},
 "lane": {"vanish": (349, 1047), "gate4_topL": (309, 1090), "gate4_topR": (366, 1090), "gate4_base": (337, 1116),
          "pad_c1": (308, 1171), "pad_c2": (356, 1175), "pad_c3": (356, 1204), "pad_c4": (298, 1198),
          "div_L": (250, 1208), "div_R": (366, 1219), "pad_mid": (336, 1148), "pad_far": (342, 1125)}}
if __name__ == "__main__":
    import sys
    from PIL import Image, ImageDraw, ImageFont
    F = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf", 22)
    out = sys.argv[1]
    for v, pts in ANCHORS.items():
        im = Image.open(CROPS[v][1]).convert("RGB"); d = ImageDraw.Draw(im)
        for k, (x, y) in pts.items():
            u, w = to_full(v, x, y); d.ellipse((u-9, w-9, u+9, w+9), outline=(255, 0, 255), width=4)
            d.text((u+12, w-12), k, fill=(255, 255, 255), font=F, stroke_width=3, stroke_fill=(0, 0, 0))
            print(v, k, round(u), round(w))
        im.thumbnail((1500, 1500)); im.save(f"{out}/anch_{v}.jpg", quality=82)

# CRITIC: B31 look (A, B, reference)

L-std = luminance spread of a lit patch.

1. **Dead floor** (spawn, dais, pads). A/B floor L-std **0.4**, a solid fill. Ref path 17-22, training floor 34, grass 19-26: studs plainly visible. The recipe's "5-10" target is wrong. Fix: StudBevel Transparency ~0.15 (check in Studio for L-std 15-25), 4x4 two-tone path tiles, a 1-stud dark curb, studs on grass too.
2. **Camera/forecourt** (spawn, dais). No avatar, eye-level camera, horizon at ~45 %, about 30 studs of empty slab. Ref: avatar centred, camera ~12 studs back and ~9 up, pitched ~30 degrees down, horizon at 15-20 %. Fix: shoot that way. Cut the forecourt to ~10 studs so the first pads sit 12-20 studs ahead.
3. **Label soup** (spawn B: ~16 billboards against 3 in ref W01; overlaps at "Locked/LIKE THE GAME", "2x Po/Auto Fight", "World/Giant Boss"). Fine print like "GOLD TAG + 1.5x CASH" is unreadable. Fix: MaxDistance 30, at most 2 lines, text height at least 1 stud.
4. **Lanes are neon arcade booths** with 8-10-stud backboards (lanes, lane_zoom). Ref: flat stepped mats, one chunky prop, a low sandbag wall behind. Fix: no backboard; a 12x8 mat, 1-stud step, dark border, one 5-stud dummy or bag.
5. **Items too small**. On the dais, boxes are ~3 studs and about 7 % of frame height. Ref eggs and phoenix are 4-6 studs on grey pedestals and fill 15-20 %. Fix: items at 5 studs, on a 7-wide pedestal 1 stud tall.
6. **Icons, not toys** (pads: "Auto Fight" is a flat red target disc; the crown and boxes are Part stacks). Fix: show a real object (a toy gun or fist).
7. **Wrong saturation on big fields.** B grass S 0.97 (#3AC605, highlighter green) against ref 0.78 (#5ACB2E). A's lanes have median S 0.81 against ref 0.48. Fix: grass #5ACB2E; big surfaces S 0.55-0.75; above 0.9 only on pad tops.
8. **Silhouette**. A has flat orange walls; B has 50-stud realistic brick blocks with windows. Ref: terraced clay cliffs, 8-12 studs per step, with grass caps and blocky trees. Fix (B): terraces at the edge, lower hood buildings behind as landmarks.
9. **Layout scatter** (overview B). Loose crates, leaning leaderboard slabs, a diagonal pole, and yellow-and-blue parking-lot outlines on the grass. Ref: a plus-shaped spine, zones on raised grey curbed plinths, about 50 % empty grass, rows of 4-5. Fix: put every zone on a plinth, delete the strays and the painted outlines.
10. **Effects blow out** (pads). Pad tops bloom to white and lose their colour; the haze reads as fire. The ref pad stays solid red; its effects sit on the training mats (embers, slime drips, rain). Fix: Neon lerp 10 %, bloom threshold above 1.3, one themed emitter per lane.
11. **Prop scale** (lane_zoom: bottles, cans, cones under 1 stud). Fix: nothing under 1.5 studs; use few chunky props (2x1x1 sandbags, 3-stud barrels).
12. **Light**. The A dais sits in the wall shadow (V 0.67), and items float with no contact. Fix: open sun, dais on the sun side, a grey pedestal disc under every floating item.

## Verdict
- **B is closer**: its spawn and pad views match the ref on saturation, and it has sky. That puts it about 1.5 points ahead of A.
- Front-page score: **before 3/10, A 4/10, B 5.5/10.** Items 1-5 outweigh the rest.
- **Meshes: yes, for 6-8 showcased items only, after items 1-5.** At 3 studs (~60 px) the bevel barely shows; at 5 studs it reads clearly as a toy (hero_pair). Never for the map.

# Halloween lobby plan (you build it in Studio)

The map to build from: **`docs/previews/halloween-lobby-layout.png`** (seen from above, to scale, 1 square = 10 studs).
It copies Huss Valley's Halloween lobby (`design/references/hv-halloween/`): dark red-brown studded ground with
orange, purple and green tiles, an orange lane along a stone fence with lamps, a haunted house with lit windows,
willow trees, gravestones, a giant pumpkin, coffin crates, a chest, a shop stall and a gift box, and dark hills,
dead trees and houses behind the fence so you never see the water.

Your lobby today is 100 x 112 studs. The new one is 200 x 182 studs (about 3 times bigger), with your island in the
middle and the Halloween field still touching its north side.

**How to read the numbers.** Every position is the world X and Z you type into Studio's Properties > Position. X
grows to the east (right on the map), Z grows to the south (down on the map). North (up) is the field. The
ground's top is at height **16.9** everywhere, the same as your floor and the field.

## Keep these where they are (scripts use them)

Measured in your place (`places/HUSSANIME.rbxl`). Don't move, rename or resize them.

| Mark | What | Where now | Why |
|---|---|---|---|
| K1 | Your lobby floor, `Maps > Spawn > SpawnBaseplate` (orange, 100 x 13 x 112) | x 353.9 to 453.9, z -615.9 to -503.4, top 16.9 | The game finds the lobby by this name, pairs it with the nearest map, and repaints it in the map's colour after each vote. |
| K2 | `SpawnLocation` (12 x 1 x 12) | centre 404.1, -528.8 | The game uses the spawn nearest this lobby and turns it on and off. |
| K3 | `SpinWheel` (14 tall) | centre 363.8, -538.4 | Anything named with "spin" and "wheel" gets the Spin button prompt. |
| K4 | small `SpinWheel` (3 tall) | centre 388.0, -546.8 | Same: it also gets a prompt (did you mean to keep this small one?). |
| G | Your girl stand (4 girls, small fence, roof light) | x 394 to 415, z -564 to -542 | No script needs it, but it's the centre of the lobby: build round it. |
| Field | The Halloween map | its south edge is at z -615.9, x 256 to 576 | It loads exactly where you built it, so the lobby's north edge must keep touching it. |

Also keep your plank path (the loop round the girls and the line north onto the field) clear.
There are no shop, vote or map pads in the world: those open from buttons on the screen.

## Rules that matter

1. **Make the new ground as new parts.** Don't stretch your SpawnBaseplate. After every vote the game paints that
   one part in the map's colour, so a stretched floor would turn all orange and lose the dark red-brown look.
2. **Names to avoid on new parts:** `SpawnBaseplate`, `Lobby`, `MapSpot`, `Zone A`, `Zone B`, `Middle`, and anything
   with both "spin" and "wheel" in it (a "Spin Wheel Sign" would get a Spin prompt). Don't add a second
   SpawnLocation near this lobby.
3. **Ground top height 16.9.** The ground parts are 13 tall, so their Position Y is **10.4**. Flat tiles and lanes
   are 0.2 thick, lying on top (Position Y 17.0).
4. **Fence where players could fall off:** the west, south and east edges, on the very edge of the new ground
   (pillar centres at x 305.4 on the west, x 502.4 on the east, z -434.9 on the south, every 12 studs). The north
   side stays open: it touches the field, people walk onto it between games and watch the game from it. Nobody can
   jump in this game, so a fence 5 to 8 studs tall is enough.
5. **Anchor everything.** CanCollide on only for what people walk on or bump into: the ground, the fence, the house
   and porch, the big pumpkin, crates and stall. Turn it off for leaves, candles, lamps, tiles you don't need,
   and everything behind the fence. CastShadow off on small bits. CanTouch off on all of it.
6. **Keep the walking areas empty** (green stripes on the map): round the spawn, both sides of the spin wheel,
   your plank path, the house path, and the watch edge along the field (flat tiles only there, nothing tall).
7. **Group it** in one model, for example `Workspace > HalloweenLobby` with folders Ground, Fence, House, Props,
   Background, so you can hide or move it all at once.
8. **Keep it light:** about 1,000 parts is plenty (the whole plan fits in that), no more than about 20 lights,
   Neon only for small glowing bits (windows, faces, flames). Your place streams parts in as people walk, so big
   simple background blocks are fine.

## Build order

1. **Ground (1, 2, 3):** the three dark red-brown slabs round your floor. Then the back yard ring (21) behind
   where the fence will go, 2 studs lower.
2. **Paths and lanes:** the orange lane (4), the stone path to the house (9), the floor tile patches (20).
3. **Fence (5) and lamps (6):** pillars every 12 studs, rails between them, a lamp on every third pillar.
4. **Big pieces:** the haunted house and porch (7, 8), the willows (11), the pond (10), the giant pumpkin (14).
5. **Attractions:** gravestone patch (12), pumpkin patch (13), coffin crates (17), treat chest (18), shop stall (15),
   gift box (16).
6. **Small decorations:** candles and lanterns (19) in groups of 3 to 5 next to the attractions.
7. **Background:** dead trees (22), crooked houses (23), far hills (24). Walk round the lobby in Play and fill any
   spot where you still see water.

## The numbered list

| # | What | Size in studs (W x D x H) | Colour (RGB) | Material | Where / how |
|---|---|---|---|---|---|
| 1 | Lobby ground West | 50 x 182.5 x 13 | 105, 45, 42 (dark red-brown) | Plastic, TopSurface = Studs | x 303.9 to 353.9, z -615.9 to -433.4. Position 328.9, 10.4, -524.65. Top at 16.9, level with your floor. |
| 2 | Lobby ground East | 50 x 182.5 x 13 | 105, 45, 42 | Plastic, TopSurface = Studs | x 453.9 to 503.9, z -615.9 to -433.4. Position 478.9, 10.4, -524.65. |
| 3 | Lobby ground South | 100 x 70 x 13 | 105, 45, 42 | Plastic, TopSurface = Studs | x 353.9 to 453.9, z -503.4 to -433.4. Position 403.9, 10.4, -468.4. |
| 4 | Orange lane inside the fence | 8 wide x 0.2 thick | 230, 95, 30 (orange) | Plastic, Studs on top | x 306.9 to 314.9, z -600 to -436.4; x 314.9 to 492.9, z -444.4 to -436.4; x 492.9 to 500.9, z -600 to -436.4. Plates lying on the ground (bottom at 16.9). |
| 5 | Gothic fence (W, S, E edges) | pillars 3 x 3 x 8 every 12; rails 9 x 1 x 5 | pillars 170, 110, 140 (mauve stone); rails 95, 55, 75; diamonds 70, 140, 60 | Plastic (pillars Slate if you like) | On the outer edge. North side stays open to the field. About 48 pillars. |
| 6 | Fence lamps | 1 x 1 x 2 on every 3rd pillar | frame 30, 25, 35; glow 255, 150, 60 | Neon glow cube + PointLight (orange, Range 14, Brightness 1.2) | About 16 lamps; a light in every other one (8 lights). |
| 7 | Haunted house | 60 x 30 x 30 (roof peak 42) | walls 215, 150, 140 (pink brick); trim 130, 70, 65; roof 70, 68, 75; door 120, 25, 30 | Brick walls, Wood trim, Slate roof; windows Neon 255, 140, 40 | x 374 to 434, z -476 to -446. Front faces north, toward the spawn. 6 lit windows, 2 SurfaceLights. |
| 8 | Porch with steps | 30 x 8 x 12 | deck 130, 70, 65; posts 110, 60, 55 | Wood | x 389 to 419, z -484 to -476. 4 posts, small roof, 2 steps, a lantern each side. |
| 9 | Stone path to the house | 16 x 19 x 0.2 | 150, 105, 125 (pink-grey stone); bone tiles 225, 215, 220 | Slate | x 396 to 412, z -503.4 to -484. Keep it empty. |
| 10 | Pond | 30 x 24 (rim 2 wide, 1 tall) | water 110, 130, 210; rim 150, 140, 165 | Water: Glass, Transparency 0.25; rim Slate | x 315 to 345, z -474 to -450. Lies on the ground; a purple PointLight in the middle. |
| 11 | Willow trees (x5) | 16 x 16 x 26 | trunk 100, 40, 80 (purple-brown); leaves 55, 95, 60 | Wood trunk; leaves Grass or Plastic | x 348 to 364, z -458 to -442; x 314 to 330, z -502 to -486; x 444 to 460, z -458 to -442 (+2 more, see the map). Trunk 4 x 4, canopy blocks, 12 hanging leaf strips 1 x 1 x 10. Leaves CanCollide off. |
| 12 | Gravestone patch | 30 x 32; stones 3 x 1 x 4 | dirt 70, 40, 40; stones 150, 140, 165; crosses 120, 110, 130 | Slate stones, Plastic dirt | x 318 to 348, z -588 to -556. 12 stones, 2 crosses, a low broken fence, 6 candles, 2 lanterns (purple light). |
| 13 | Pumpkin patch | 30 x 44; pumpkins 3 x 3 x 3 | dirt 80, 45, 30; pumpkins 230, 110, 30; stems 40, 110, 40 | Plastic; faces Neon 255, 170, 40 | x 460 to 490, z -548 to -504. 10 small pumpkins, 4 with glowing faces. |
| 14 | Giant pumpkin (Pumpkin Hunt) | 20 x 20 x 16 | 230, 110, 30; pad 120, 50, 170 (purple) | Plastic blocks stacked round; face Neon | x 466 to 486, z -536 to -516. On a 24 x 24 purple pad, one orange PointLight. Decoration only for now. |
| 15 | Shop stall | 18 x 10 x 12 | counter 150, 90, 55; awning stripes 120, 200, 240 and white | Wood counter, Plastic awning | x 466 to 484, z -464 to -454. Decoration only: it sells nothing. |
| 16 | Gift box | 5 x 5 x 5 | box 220, 30, 30; ribbon 250, 210, 40 | Plastic | x 486 to 491, z -462 to -457. Decoration only. |
| 17 | Coffin crates (x2) | 5 x 3 x 9 each | 30, 25, 35 (black); faces and edges Neon 255, 130, 30 | Plastic + Neon strips | x 470 to 475, z -578 to -575; x 479 to 484, z -578 to -575. Standing up, faces toward the girls (west). One orange PointLight between them. |
| 18 | Treat chest | 7 x 4 x 5 | body 240, 140, 190 (pink); trim white | Plastic | x 470 to 477, z -593 to -589. Decoration only. |
| 19 | Candles and lanterns | candle 0.6 x 0.6 x 1.5; lantern 1.5 x 1.5 x 2.5 | wax 235, 230, 220; flame Neon 255, 170, 60 | Plastic + Neon | the dots on the map. Groups of 3 to 5 next to the attractions, never on a path. |
| 20 | Floor tile patches (x14) | 4 x 8 to 10 x 10, 0.2 thick | orange 230, 95, 30; purple 95, 30, 80; green 60, 70, 25; stone 160, 110, 135 | Plastic, Studs on top | x 322 to 330, z -612 to -604; x 338 to 346, z -520 to -512; x 458 to 468, z -606 to -600 (+11 more, see the map). Scatter them; mix the four colours like Huss Valley. |
| 21 | Back yard ring (behind the fence) | 40 wide x 11 thick | 60, 32, 48 (dark plum) | Plastic | x 263.9 to 303.9, z -615.9 to -393.4; x 503.9 to 543.9, z -615.9 to -393.4; x 303.9 to 503.9, z -433.4 to -393.4. Top at 14.9 (2 lower than the lobby). Hides the water right behind the fence. |
| 22 | Dead trees (x10) | trunk 2 x 2 x 18, 3 crooked branches | 50, 30, 50 | Wood | the dots on the map. CanCollide off. |
| 23 | Crooked houses (x5, far) | 20 x 16 x 26 to 34 | 70, 50, 95 (dark purple); 2 or 3 windows Neon 255, 150, 60 | Plastic | x 272 to 292, z -528 to -512; x 300 to 320, z -418 to -402; x 420 to 444, z -414 to -398 (+2 more, see the map). Simple blocks with a pointed roof. No inside, CanCollide off. |
| 24 | Far hills | 20 to 36 tall, 3 blocks a side | 40, 35, 80 (night blue) | Plastic, CanCollide off | x 228 to 580, z -393.4 to -358; x 228 to 263.9, z -615.9 to -393.4; x 543.9 to 580, z -615.9 to -393.4. Stand on the water (bottom at 3.5). From the lobby they make the horizon. |

How to make the shapes with plain blocks:
- **Studs:** select the part, Properties > Surface > TopSurface = Studs (Huss Valley's ground and tiles are studded).
- **Willow:** a 4 x 4 trunk 14 tall, leaning a little, two crooked branch blocks, a canopy of 3 or 4 green blocks
  (about 16 x 6 x 16 together) and 12 thin strips (1 x 1 x 10) hanging from its edges.
- **Giant pumpkin:** stack blocks so it looks round from far away: 14 x 4 x 20, 20 x 8 x 20, 14 x 4 x 20 (and the
  same turned 90 degrees), a green stem 3 x 4 x 3 on top, and Neon triangles or blocks for the eyes and mouth.
- **Coffin crate:** a black box 5 x 9 x 3 standing up, a thin Neon orange frame round its front, and two glowing
  jack-o'-lantern faces on the front.
- **Haunted house:** one big box for the walls, a slightly wider wedge roof, a smaller tower box at one corner,
  6 Neon window panes (4 x 6) with dark frames, a dark red door, and the porch in front.

## Sky and lighting (the purple night look)

Honest note first: the lighting is shared by the whole game (all 3 lobbies and maps), and our script
(`Config/Look`, run when the game starts) sets a bright afternoon look. So values you type into Lighting in Studio
show in the editor but get replaced when you press Play. To keep the night look, tell us and we switch
`Config/Look` to these numbers (or turn it off there). A night look only in this lobby is possible later with a
small script.

Values (estimated from the Huss Valley frames: sky blue-purple with a pink glow near the horizon, the ground
still easy to see):

| Where | Setting | Value |
|---|---|---|
| Lighting | ClockTime | 0 (midnight, moon up) |
| Lighting | Brightness | 1 |
| Lighting | Ambient | 110, 80, 150 |
| Lighting | OutdoorAmbient | 140, 110, 190 |
| Lighting | ColorShift_Top | 190, 160, 255 |
| Lighting | ExposureCompensation | 0.3 |
| Lighting | EnvironmentDiffuseScale / EnvironmentSpecularScale | 0.4 / 0.3 |
| Lighting | GlobalShadows | on |
| Atmosphere | Density / Offset | 0.32 / 0.2 |
| Atmosphere | Color | 140, 110, 220 |
| Atmosphere | Decay | 70, 50, 140 |
| Atmosphere | Glare / Haze | 0 / 1.2 (the purple fog on far trees) |
| ColorCorrection | Brightness / Contrast / Saturation | 0.03 / 0.15 / 0.3 |
| ColorCorrection | TintColor | 235, 225, 255 |
| Bloom | Intensity / Size / Threshold | 0.8 / 24 / 1.2 (windows, faces and flames glow) |
| Sky | StarCount / MoonAngularSize | 3000 / 18, CelestialBodiesShown on |
| Sky | the six sky pictures | pick a free purple night skybox in the Toolbox (we never make up IDs) |

Lights in the lobby: orange **255, 150, 60** for lamps, windows and pumpkins; purple **170, 90, 255** for the graves
and the pond. PointLight Range 12 to 20, Brightness 1 to 2.

## Compared with Huss Valley (checked against the frames)

- Same pieces and colours: ground, tile patches, orange lane by the fence, stone fence with lamps, house with lit
  windows and porch, willows, graves, giant pumpkin on a purple pad, coffin crates, chest, shop stall, gift box.
- Different on purpose: Huss Valley's pond sits just behind the fence (you see it through the rails). Ours is inside
  so players can walk up to it; if you prefer theirs, put it in the back yard ring at x 268 to 300, z -500 to -470
  and use rails with gaps.
- Not in this plan yet: Huss Valley's leaderboard boards and event sign. We can add real leaderboards later; a board
  with no data would only be a placeholder.
- Colours are the part colours to type in. Huss Valley's screen looks darker and more purple because of its night
  light, so check them under the night look before changing them.

The plan picture and the list both come from `tools/world/halloween_layout.py`; your real positions were measured
with `tools/world/measure_halloween_lobby.luau`. If you move something, tell us and we redraw the map.

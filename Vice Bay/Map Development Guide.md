# Map development guide: roads, buildings, detail

How Vice Bay builds a city that full-size cars can actually drive in. These are the rules the generators follow; keep to them when adding districts.

## 1. Scale comes from the car
- The reference car is the user's Urus: about **22.7 long, 10.1 wide, 7 tall**. Every road, lane, parking slot and garage is sized from it.
- **Lane ≈ 1.5 × car width ≈ 14–16 studs.** Parking lane ≈ 10–11. Alley (one way) ≈ 24.
- Parked prop cars use the same scale: `SedanLite` scaled to 21.5 long, supercars to 21. A prop car smaller than the drivable car makes the drivable car look like a bus.

| Style | Width | Sidewalk | Use |
|---|---|---|---|
| ALLEY | 24 | 0 | hood back alleys, one lane |
| HOOD / RES | 36 | 7–8 | local 2-lane streets |
| HAB / WYN | 38 | 10–12 | local streets in Habana / Wynwood |
| HOODA / HABA / WYNA | 56 | 10–12 | 4-lane avenues |
| DTS | 44 | 12 | downtown side streets |
| DT | 60 | 12 | downtown avenues |
| BLVD | 76 | 12 | boulevards with a 12-stud palm median |
| PORT | 52 | 6 | truck roads |
| I-95 | 84 | — | 3 lanes each way + median, elevated |

## 2. Pavement markings (scaled from MUTCD, 1 stud ≈ 1.1 ft)
- Lane / centre lines are 0.4–0.5 wide.
- Broken lines: **9-stud dash, 27-stud gap** (MUTCD 10 ft / 30 ft).
- Stop line 1.4 wide, about 6 studs before the crosswalk.
- Continental crosswalk bars are 2 wide with 2-stud gaps, and the crosswalk is about 8–9 deep.
- **Yellow** separates opposing traffic; **white** separates same-direction lanes and marks the right edge.
- Box junction: a yellow border plus 45° stripes, aligned with the main road and clipped to the box (`Roads.lua`).
- Sources: [MUTCD markings summary](https://open-exam-prep.com/study-guides/ptoe/signing-markings-work-zones/pavement-markings-delineation), [MUTCD Part 3 (FHWA)](https://mutcd.fhwa.dot.gov/htm/2003r1r2/part3/part3b2.htm)

## 3. Clean road geometry (the "no overlapping" rules)
1. **Every carriageway has one height** (`ROAD_Y`). No per-segment offsets, so there are no steps for wheels.
2. **Slabs stop at the junction edge.** Each segment is trimmed by `trimRoad`, which ignores the straight-through continuation. The junction plate fills the box and sits 0.02 lower, so where they meet the slab always wins and nothing z-fights.
3. **Decals live above the surface and away from paint.** Tar patches and wear stay at least 16–22 studs from junctions and off the centre-line band. The pale "outline" rectangles were removed.
4. **No pole forests.** Utility poles and street lights start at least 14 studs past a junction, so the signal mast stands alone at the corner.
5. **Round plates only block by their bounding box.** Lot filling ignores Junction / Bend / CulDeSac parts, otherwise whole blocks stay empty.
6. **Landmarks win.** After any width change, run `20_fit_landmarks`. It nudges or scales hand-placed landmarks off the roads and deletes filler buildings under them. Then run the audit (roads vs everything, and footprint vs footprint) and expect 0.

## 4. Making it look real (environment art)
- **Modular kit, varied use.** Build a small kit of pieces, then avoid back-to-back repeats: alternate variants, randomise brightness per instance, and hand-place hero spots.
- **Wear tells a story.** Everything is aged, including signs. Damage needs a cause: debris under a broken wall, a maintenance sign where the road is torn up, boarded windows on an abandoned house, ivy on an old traffic cabinet.
- **Decals blend seams.** Use cracks, stains and splash bands where walls meet the ground, and grime under roof edges and windows.
- **Lighting drives mood.** Use contrast between sun and shade sides, point lights to fake bounce, and a light at the end of a street to pull the player forward.
- **Reuse well before adding more.** "Be creative with what you have": recolour and retune the same assets per district.
- Sources: [80.lv: Making a street scene, modularity and attention to details](https://80.lv/articles/making-a-street-scene-in-ue4-modularity-and-attention-to-details), DevForum threads on city/road building ([1](https://devforum.roblox.com/t/what-is-the-best-way-to-make-city-streets/357468), [2](https://devforum.roblox.com/t/how-to-go-about-building-a-city-map/2469466), [3](https://devforum.roblox.com/t/devs-how-do-you-make-your-roads-help-needed/2496394))

## 5. Roblox-specific
- **Textures.** User-uploaded images are blocked in a group-owned game until access is shared, and a blocked variant renders flat dark grey. `15_textures` swaps in public maps; `R.run("15_textures","restore")` brings back your own.
- **Water.** `FillBlock(Water)` won't replace solid voxels, so fill Air over the full depth first.
- **Part budget.** About 168k parts with StreamingEnabled. Strip Creator Store meshes (`YachtMotorLite` 226, `SedanLite` 64) and strip brands/plates.
- **Drivable water.** Canals need 30+ studs of clear fairway, docks parallel to the bank, and empty tagged berths (`HouseBerth`, `MarinaBerth`).

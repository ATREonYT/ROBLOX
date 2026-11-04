---
tags: [build-playbooks, realistic, roads, city-layout, modular-kit, set-dressing, roleplay]
updated: 2026-11-01
---

# 36 Roads, Blocks and City Layout Kit

Back to [[33 Realistic World Building Playbook]] · [[00 Build Router]] · RP town systems: [[Blueprint - Roleplay Town]] · Street research with real-world sources: `research_notes/Front page feel and gamey stages/hood_games_maps.md` §2 · Deep reference: `LihFolk/LihFolk Vault V2/06 World Building and Art/` (House Construction Method - Modular Kit Workflow, Roads, Rivers and Paths Carved Along Curves in Terrain, World Composition and Set Dressing - Designed, Not Scattered, Level Design for Roblox)

> **TL;DR**
> - **Plan the city like a real one, then shrink the empty parts.** Road hierarchy (highway, avenue, street, alley), districts with a reason (downtown, hood, strip mall, port, coast), and every job within ~30 s of driving.
> - **Vertical scale stays real, horizontal shrinks to ~60–70%.** Doors, storeys, kerbs and cars at true size; blocks and distances compressed (from the vault's hood street research).
> - **Everything snaps to a 4-stud grid** (it also matches terrain voxels). Road pieces in 20/40-stud lengths, kerb returns in fixed radii.
> - **Markings are crisp, the road under them is dirty.** That contrast reads "real".
> - **Power lines are Beams with sag**, nearly free. Every realistic street needs them.

---

## 1. Scale sheet for an RP city with cars

1 stud = 0.28 m (Roblox's conversion). Avatars are about 5 studs tall. These are **game numbers** for a drivable city, slightly wider than true scale because Roblox cars steer loosely and the camera sits behind them.

| Element | Real | Game (studs) | Notes |
|---|---|---|---|
| Traffic lane | 3.0–3.6 m | **13–15** | 14 is a good default |
| Parking lane | 2.4 m | **9–10** | Parallel parking along collectors |
| Bike lane | 1.5–2 m | 6–7 | Optional on arterials |
| Sidewalk | 2.5–4 m | **10–14** | Wider downtown (16+) |
| Kerb height | 15 cm | **0.6–0.8** | Characters step up automatically (1 stud) |
| Kerb return radius | 4–8 m | **12–20** | Bigger on truck routes |
| Crosswalk bar | 0.6 m wide | 2 wide, 2 gap | Bars run in the driving direction |
| Stop line | 0.3–0.6 m | 1.5–2 | |
| Lane line (dashed) | 3 m dash, 9 m gap | 0.5 wide, 10 dash, 20 gap | Solid double yellow centre: 0.5 + 0.5 gap + 0.5 |
| Door | 2.1 m | **7–8** tall, 4 wide | Garage doors 10–12 tall |
| Storey (residential) | 3 m | **10–11** | Ground-floor shop 12–14 |
| Car | 4.5 × 1.8 m | ~16 × 7 | Check against the chassis we use |
| Utility pole spacing | 30–50 m | **40–60** | One every 1–2 houses |
| Streetlight spacing | 30–40 m | **50–70** | Alternate sides on wide roads |
| City block | 80–250 m | **160–300** per side | Smaller downtown, bigger suburbs |

The "enclosure" rule from the hood research: street wall height about equal to street width feels like a real city street; below 1:4 it feels like a car-only strip. Use that to pick building heights per district.

---

## 2. Road hierarchy and the city plan

Real cities are built from a hierarchy (DevForum "Creating a realistic city"): highways link regions; arterials cross the city with few intersections; collectors link arterials to neighbourhoods and carry shops; local streets face houses; alleys serve the backs.

| Road type | Lanes (game) | Width curb to curb | Sidewalks | Where |
|---|---|---|---|---|
| Highway / bridge | 2 + 2, divided | 60–70 + median | none; barriers | Ring around the city, the coastal bridge (coast-05) |
| Arterial avenue | 2 + 2, turn lane | 60–74 | 12–16 | Downtown spine, strip malls (coast-04) |
| Collector street | 1 + 1 + parking both sides | 46–50 | 10–12 | Hood main street (hood-03), shops on the ground floor |
| Local street | 1 + 1, maybe parking one side | 28–36 | 8–10 or none | Houses, coastal roads (coast-02, coast-03) |
| Alley | 1 shared | 14–18 | none | Behind shops; dumpsters, back doors, fire escapes |

### A city plan for an RP map (district by district)
Map footprint: **2,000–3,000 studs across** for a 30–50 player server. Driving at ~80 studs/s crosses it in 30–40 s.

1. **Downtown** (grid, tall, dense): bank, police, hospital, shops. The visual landmark (tallest tower or a clock tower) is seen from everywhere.
2. **Hood / old town** (grid, 2–4 storeys, worn): apartments, corner store, barber, garage, basketball court, flood channel.
3. **Commercial strip** (arterial, big parking lots, low flat buildings): car dealer, petrol station, fast food, big-box store.
4. **Suburbs** (curving local streets, cul-de-sacs, lawns): player houses (the RP heart, see [[26 Fun and Roleplay Playbook]] §6).
5. **Industrial and port** (wide roads, warehouses, cranes, containers): trucking and fishing jobs.
6. **Coast** (winding road, palms, beach, pier, bridge to an island): leisure, boats, the scenic drive.
7. **Highway ring** connecting them, with on/off ramps, so driving across town is a joy.

**Layout rules:**
- Spawn in a calm, beautiful spot next to the first job and a car spawner, facing the landmark.
- Every job is within **30 s of driving** from spawn, and the map edge is **never** reachable without a reason (water, mountains, a wall of trees in haze).
- Mix grid and curves: a grid downtown (easy to navigate), curves in suburbs and coast (beautiful to drive).
- **T-intersections and offsets** break the grid's monotony (the Tokyo-edition guide notes real cities are loose grids with odd angles).
- Leave lots and gaps: parking lots, a park, an empty fenced lot. Gaps are as important as buildings.

---

## 3. The modular road kit (build once in Blender or parts)

All pieces snap on a **4-stud grid**, pivot at the road centre at ground level, with the road surface at Y = 0 and kerb tops at Y = 0.7.

| Piece | Size (studs) | Variants |
|---|---|---|
| Road straight | 40 long × width per type | Clean, worn, patched A/B/C; with/without parking lines |
| Road straight short | 20 long | Same |
| Crosswalk | 40 × width | Bars, faded bars |
| 4-way intersection | width × width | With stop lines, with hatch box (hood-03), signalised |
| T-intersection | width × width | Same |
| Curve | 15°, 30°, 45°, 90° at 3 radii | For local and coastal roads |
| Kerb straight | 20 long | Plain, red-painted, yellow-painted, with drain grate |
| Kerb return | quarter circle at radius 12, 16, 20 | With ramp for accessibility |
| Sidewalk slab | 8 × 8 or 10 × 10 | Clean, cracked, stained, with tree pit, with manhole |
| Driveway cut | 12–16 wide | Sloped kerb |
| Parking lot tile | 40 × 40 | Lines, faded lines, with oil stains |
| Median | 40 long | Planted, concrete, with palms |
| Bridge deck | 80 long | With barriers and lamp posts |
| Highway ramp | 120–200 long | Banked |
| Flood channel | 40 long | Sloped concrete walls (hood-02) |

**Markings:** build as their own thin parts (0.05 thick, `SmoothPlastic`, CanCollide off) on top of the road, or bake into the road texture. Thin parts are easier to edit and batch well when they share size and colour. Make them slightly off-white (240, 238, 230) and slightly worn on old streets; pure white glows under Realistic lighting.

**Curved and terrain-hugging roads (coastal look):**
- For a handful of curves: Blender road strip on a curve modifier, exported as segments (see [[38 Mesh Pipeline, LOD and Mobile Budgets]]).
- For many: a spline road plugin (for example RoadForge from Godberry Studios, or the community "Beautiful Roads" plugin; check the current version and licence before relying on one). Keep the generated segments few and long; thousands of thin wedge parts kill phones.
- Carve terrain under the road and add a soft shoulder (gravel or grass strip 2–4 studs) so the road never floats.
- Concrete jersey barriers on the water side of coastal roads; their tops get water-streak wear.

---

## 4. Building kit (facades that look real)

Real-looking buildings read in three bands:
1. **Ground floor (most detail):** shopfronts, roll-up shutters, barred windows, doors with steps, signs, awnings, AC boxes, menus, ATMs, posters.
2. **Middle floors (rhythm):** repeated windows with sills and frames, balconies, fire escapes (hood), shutters (coast). Vary curtains and lights per window.
3. **Roofline (silhouette):** parapet with cap, cornice, AC units, water tanks, vents, satellite dishes, antennas, a billboard frame (hood-03), pitched roofs with shingles (coast).

**Kit list (per style):** ground shop module (12 wide × 14 tall), residential ground module, upper window module (12 × 10), blank wall module, corner module, entrance module, garage bay (fire station), parapet and cornice strips, roof clutter set, awning set, sign boards, fire escape set, balcony set.

**Window tricks:**
- Recess windows 0.5–1 stud into the wall; a frame and sill sell depth more than any texture.
- Behind the glass: a dark plane 1–2 studs back with a **room decal** (our own pictures: curtains, a lamp, shelves). Vary them. Some windows lit at night (a SurfaceLight or emissive).
- Never leave an empty bright interior visible through glass on a closed building.

**Enterable interiors:** only for job buildings and player houses. Everything else is a facade. Use `ModelStreamingMode = Atomic` per building and stream or cull interiors by zone (`LihFolk/.../12 Performance Testing and Debugging/Client Zone Culling for Interiors and Cities.md`).

**Believable building types for an RP city:** fire station (coast-01: brick bay block + siding office wing + glass bay doors + bollards + hatching), police station, hospital with ambulance bay, petrol station with canopy, corner store, barber, laundromat, car wash, motel, strip mall, diner, church, school, warehouse, apartment block, bungalow, stilt beach house, pier restaurant (coast-05), marina.

---

## 5. Power lines (cheap realism)

Sagging wires across streets are one of the strongest "real city" signals in the hood references. Build them with `Beam`s, not parts:

```lua
--!strict
-- Command Bar: select two pole attachments (Attachment objects at the crossarm), then run.
-- Makes a sagging wire between them. Repeat for each wire.
local Selection = game:GetService("Selection")
local sel = Selection:Get()
local a0, a1 = sel[1], sel[2]
assert(a0 and a1 and a0:IsA("Attachment") and a1:IsA("Attachment"), "Select two Attachments")
local span = (a0.WorldPosition - a1.WorldPosition).Magnitude
local sag = span * 0.06 -- 6% sag reads natural; 10% for old, slack lines
local beam = Instance.new("Beam")
beam.Attachment0, beam.Attachment1 = a0, a1
beam.Width0, beam.Width1 = 0.12, 0.12
beam.Color = ColorSequence.new(Color3.fromRGB(25, 25, 25))
beam.LightInfluence = 1
beam.Segments = 12
-- CurveSize bends the beam along each attachment's own axis; point both attachments' Y axis up
-- (or flip the sign) so the wire droops down. Tune by eye.
beam.CurveSize0 = -sag * 1.5
beam.CurveSize1 = sag * 1.5
beam.FaceCamera = true
beam.Parent = a0.Parent
print("Wire span", math.floor(span), "studs")
```
(Sketch, not yet run in Studio. Beams don't collide, cost very little and render far.)

Poles: a wooden pole mesh with a crossarm, insulators, a transformer can on every third pole, a streetlight arm on some. Lean a few by 1–3°. Every 40–60 studs.

---

## 6. Street furniture placement rules

| Item | Rule |
|---|---|
| Fire hydrant | Near corners, 2–3 studs from kerb; red kerb paint either side |
| Trash can | At corners and bus stops; never mid-block in a row |
| Traffic light | Every signalised corner, on the far side of the intersection |
| Stop sign | At unsignalised local corners |
| Street name signs | On the corner pole; our own street names |
| Speed limit sign | Start of each road section (coast-02/03: "35") |
| Bus stop | Arterials only, every 300–500 studs; shelter + bench + timetable |
| Parking meter | Downtown collectors, every bay |
| Mailbox, newspaper box | Corners, near shops |
| Bollards | Fire station aprons, shop fronts, pedestrian zones |
| Benches | Parks, bus stops, shopfronts |
| Planters / tree pits | Downtown sidewalks, every 20–30 studs |
| Chain-link fence | Empty lots, courts, the flood channel (hood-01) |
| Parked cars | 1 per 2–3 bays; varied colours; some with covers |

---

## 7. Set dressing lists by zone

- **Hood street:** roll-up shutters, barred windows, AC boxes with drip stains, satellite dishes, chain-link, a basketball hoop, shopping cart, milk crates, a couch on the kerb (one, not ten), corner store signs, barber pole, laundromat, payphone, rusty hydrant, flood channel with graffiti.
- **Coastal town:** surf shop boards, bike racks, beach showers, lifeguard tower, dunes with fences, fishing gear on the pier, buoys, channel markers (red right returning), boat trailers, mailboxes on posts, white picket fence, palms in medians.
- **Fire station:** bay doors (glass panels), bollards, hatched apron, flagpole, hose tower, wall packs, a bench and grill out back.
- **Strip mall:** big parking lot with light poles, cart corrals, pylon sign, flat roofs with AC units, a fountain or planters (coast-04).
- **Port / industrial:** containers (tinted variants of one mesh), forklifts, pallets, cranes, chain-link with barbed wire, puddles.

**The storytelling rule:** every corner gets one small story you can read in 2 s: a bike locked to a pole, chalk drawings by a front door, a ladder against a wall with a paint can, a "for rent" sign. Few, deliberate, varied.

---

## 8. Blockout script (grid streets in seconds)

```lua
--!strict
-- Command Bar: grey blockout of a road grid. Edit the numbers, run, then build on top.
local BLOCK, ROAD, WALK, N = 200, 48, 12, 4 -- block size, road width (curb to curb), sidewalk, blocks per side
local folder = Instance.new("Folder")
folder.Name = "Blockout"
folder.Parent = workspace
local function part(size: Vector3, pos: Vector3, color: Color3, name: string)
	local p = Instance.new("Part")
	p.Anchored = true
	p.Size = size
	p.Position = pos
	p.Color = color
	p.Material = Enum.Material.SmoothPlastic
	p.Name = name
	p.Parent = folder
end
local pitch = BLOCK + ROAD
local total = N * pitch + ROAD
for i = 0, N do
	local x = i * pitch - total / 2 + ROAD / 2
	part(Vector3.new(ROAD, 1, total), Vector3.new(x, -0.5, 0), Color3.fromRGB(60, 60, 62), "RoadNS")
	part(Vector3.new(total, 1, ROAD), Vector3.new(0, -0.49, x), Color3.fromRGB(60, 60, 62), "RoadEW")
end
for i = 0, N - 1 do
	for j = 0, N - 1 do
		local cx = i * pitch - total / 2 + ROAD + BLOCK / 2
		local cz = j * pitch - total / 2 + ROAD + BLOCK / 2
		part(Vector3.new(BLOCK, 0.7, BLOCK), Vector3.new(cx, 0.35, cz), Color3.fromRGB(150, 150, 150), "Sidewalk")
		part(Vector3.new(BLOCK - WALK * 2, 0.8, BLOCK - WALK * 2), Vector3.new(cx, 0.4, cz), Color3.fromRGB(110, 120, 100), "Lot")
	end
end
print("Blockout grid", N, "x", N, "blocks, total", total, "studs")
```

## Sources
DevForum [Creating a realistic city](https://devforum.roblox.com/t/creating-a-realistic-city/3053768) (road hierarchy, regional architecture themes, study satellite views, realism vs gameplay), [Creating a realistic city: Tokyo edition](https://devforum.roblox.com/t/creating-a-realistic-city-tokyo-edition/3859433) (loose grids, T-intersections, layered street detail, "model as a memory, not a diagram"), [Hood style game map](https://devforum.roblox.com/t/hood-style-game-map/2938255) (too clean, too green, clutter critique). [Godberry RoadForge](https://godberrystudios.com/tools/roblox/roadforge/), DevForum [Beautiful Roads plugin](https://devforum.roblox.com/t/beautiful-roads-plugin-beta-0-4/511940). Real-world street numbers and the compression rule: `research_notes/Front page feel and gamey stages/hood_games_maps.md`.

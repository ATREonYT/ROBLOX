# Map and Building Quality: Lessons (Nov 2 2026)

What actually made the hood look better or worse, learned while building the Larp-style shops and fixing the map. Read this before any map or building work.

## 1. Check that textures load before judging the look
- **Symptom:** walls, roads and sidewalks look flat and plastic even though `MaterialService.Realistic` has about 150 MaterialVariants and 21,000+ parts use them.
- **Cause:** the place belongs to a **group**, but the texture images (472 PNGs in `realistic-textures/upload_flat`, ids in `realistic-textures/texture-ids.json`) were uploaded to **Alex's personal account**. Roblox then blocks the game from using them. Output shows "User is not authorized to access Asset" and "The experience doesn't have access permission … Click to share access".
- **Fix:** Alex clicks "Click to share access" in Output and shares all. In future, upload images **as the group** (Asset Manager: choose the group as creator) or grant the experience right after uploading.
- **How to check in one run:** `ContentProvider:PreloadAsync` every variant ColorMap and count `Success`. `GetAssetFetchStatus` alone can lie, so trust a screenshot.
- **Two more failure reasons in the same log:** `HttpError: DnsResolve` is the Mac's network, so restart Studio or the Wi-Fi. "Asset is not compliant / not approved" means moderation.
- The MCP tool `generate_material` and the old AI_* variants also never showed up in this place.

## 2. Low poly, but realistic: what reads as "real"
The reference look (vault `Vice Bay/References/Larp`) is plain blocks plus layers of detail:
- **Bays, not walls.** Split every shopfront into 10–14 stud bays with painted-brick piers. Each bay is a roll-up shutter, a barred glass front with stocked shelves, or a steel door.
- **Something over every bay:** a rusty box (built-in CorrodedMetal with no variant looks great), a striped fabric awning, or a metal fascia.
- **Clutter on the wall:** AC condensers with a rust-brown side panel and a rust drip below, downpipes, meter boxes, bars on every low window.
- **Variety is required.** Neighbouring shops need different types (rust / awning / tiled piers / rooftop sign / mural), colours and heights. 52 identical shops looked fake straight away.
- **Grime:** rain streaks under the coping, dirt at the base. Use a Decal on a transparent part 0.06 in front of the wall. SurfaceGui frames work as a fallback but look like stripes up close.
- **Lighting direction matters.** In this game the noon sun sits toward +Z, so a facade facing -Z is always in shade and looks dead. Check the sun direction before choosing which way a test street faces.

## 3. Builder pattern that worked
- `Miami Trap Life/tools/swap_hood_shops.lua` (live copy: `ServerStorage.MTL_Tools.SwapHoodShops`). It reads each old building's `Footprint` part, builds a new shop sized to it facing the same street, keeps the old sign text, and moves the original to `ServerStorage.MTL_ReplacedBuildings`. It is seeded per lot, so reruns are stable.
- Edit live scripts with find-and-replace on `Source`, then compare `#Source` with the repo file's byte count.
- Chunk heavy work and `task.wait()` every 5–15 buildings. A whole-map scan in one call drops the MCP connection.

## 4. Overlaps and flickering
- **Real wall clashes:** use `workspace:GetPartsInPart` on each building's big parts (Y>4, width>6), excluding its own model. Ignore hits whose top is under the wall bottom +1.2, because those are pavement under the base.
- **Typical clashes:** buildings sitting on the road edge (nudge 2–13 studs away from the clash centre, checking nothing new clashes), buildings under the elevated I-95 deck (move to storage, leave the lot ground), yard trees poking into neighbours (move the tree).
- **Flickering:** z-fighting comes from coplanar faces of different colour or material. Scan with a spatial hash and fix by shrinking or offsetting the smaller part by 0.02–0.05.

## 5. Cars
- Map parked cars were `VBAssets.SedanLite` (cut down). `VBAssets.SedanA` is the full model. Alex wants full detail: never simplify cars for performance.

## 6. Visibility
- Thick Atmosphere (Density 0.3–0.44, Haze 2+) plus distance blur made players feel they "can barely see anything". Density about 0.18–0.26 and Haze about 1–1.3 keep the mood and open the view. Camera max zoom is 220.
- `Workspace.StreamingTargetRadius` can't be set from scripts; it has to be set in the Properties panel.

## 7. Nov 2 evening pass (what was run, all reversible)
- **Flicker:** a whole-map coplanar-face scan (GetPartBoundsInBox per block part, time-boxed 25 s chunks). Of each pair, the smaller face is moved 0.025 studs along its normal, attribute `MTL_ZNudge`. About 8,400 parts. The road "Line" and "HoodWear" decal parts were already fine.
- **Decor:** `tools/decorate_hood_buildings.lua` adds the child model `MTL_Decor` to hood buildings. AC units go only where a raycast hits solid non-glass wall. It also adds downpipes, a grime decal per facade, and roof HVAC/vents/dish/water tank/billboard. Shops get side and back walls only.
- **Fill:** `tools/fill_plain_spaces.lua` adds `MTL_Fill` to EmptyLots (junk SedanA, tyres, pallets, cart, trash, weeds, sign) and `MTL_Tags` graffiti, drawn with SurfaceGui so it needs no assets. Skip job sites and interiors, and only tag a face whose outward ray hits no wall of the same building. A bounding-box "outside" test was too strict and removed 159 good tags.
- **Overlaps outside the hood:** 248 yard trees moved off neighbours. What's left is mostly oak canopies over a neighbour's roof and row shops sharing a party wall, which is acceptable.
- **Prompts:** every map interact prompt now has HoldDuration 0 (taps), also in `ServerStorage.VB.Core`.
- **Road paint:** white markings set to (222,220,210) and yellow to (214,176,62). Pure white reads as cartoon.

## 8. Map "silly mistakes" checklist (run before every hand-over)
Players judge the whole game by these. Walk the map at player height and check each one:
1. **Doors are reachable.** Nothing solid within 6 studs in front of any door: no stray wall, infill block, sign post, car, bin or marker.
2. **Every lot has a way in.** Parking lots, gas stations, garages and driveways connect to the road with a curb cut: the sidewalk is lowered to road level over 16–18 studs, with sloped flares. A car must be able to roll in without a bump over 0.3 studs.
3. **No steps where there shouldn't be.** Lot, apron and road tops are within 0.3 studs of each other. The sidewalk is the only raised level (0.5–0.7 above the road).
4. **Nothing floats and nothing is buried.** Props, cars, bins, trees and benches sit on the surface below them (gap under 0.1). Check with a downward raycast from each prop's lowest point.
5. **No paper walls.** Walls are at least 1 stud thick, and nothing is see-through from inside a building.
6. **No coplanar faces** (flicker). Overlays sit 0.02–0.05 off, and only one decal goes on any face.
7. **No overlaps** between buildings, roads and props, apart from trees over roofs, which are fine.
8. **Edges are closed.** No road ends in the void or over water without a barrier, wall or turn.
9. **Signs read right.** Text faces the street and isn't mirrored or upside down, and names aren't duplicated next door.
10. **Interact spots are clear.** Prompts aren't inside walls, and there's no marker or beam left from testing.
11. **Lights match the time.** Nothing glows by day that shouldn't, and every lamp head has a light at night.

## 9. Nov 2 night: cosmetic-bug sweep (what was found and how it was fixed)
- **"Little circles" at the Food Mart:** a SpawnLocation keeps its default `rbxasset://textures/SpawnLocation.png` Decal even at Transparency 1. Always remove the decal from spawns.
- **No way into lots:** every vehicle lot was surrounded by an unbroken 0.65–0.9 stud sidewalk curb. The fix is to split the Sidewalk part around an 18-stud gap and add a concrete apron at road height plus two WedgePart flares down from the walk (models `MTL_Driveway_<Lot>`). Done for FoodMart, GasStation ×2, UsedCarLot ×2, AutoShop, SudzCarWash ×2 and WestsideCarMeet ×2. Originals are in `ServerStorage.MTL_ReplacedBuildings.Driveways`.
- **Floating props:** measure from each part's real lowest point (world-axis extents), not the model's bounding box. Ray-cast past transparent parts and the invisible `Footprint` platforms (top at y 6). Otherwise half the props look buried.
- **Trees:** check each tree's trunk base with a ray.
  - Trees on asphalt move to the nearest grass, verge or median with 2.5 studs of room. The 48 that had none are in storage.
  - Trees on sidewalks are aligned 1.8 studs in from the curb, with a dark soil tree pit (3.4² Ground, 0.04 thick) and a concrete edge. If the curb spot is blocked, shift up to ±9 studs along the walk. If the walk is narrower than 5 studs, store the tree.
  - Attributes `MTL_MovedFrom` and `MTL_StreetTree` mark what changed.
- **Stray slabs:** a bare free-standing wall (TheEndsWall) reads as a mistake. Give it a cap, piers and a mural, or remove it.
- **Runtime-hidden markers:** `MTL_Stations` parts show at Transparency 0.4 in Edit, but JobService sets them to 1 at runtime. Don't "fix" them.

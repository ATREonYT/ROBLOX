# Nov 1 (pass 3) – Airport, Port Sol extras, Westside hood

## Hood buildings (src/lib/Build.lua)
- Larp exterior kit: `L.falseFront` (stepped/raised/cornice/eyebrow parapets + coping), `L.wallAC` (drip stains), `L.meterBank` + conduit, `L.wallPack`, `L.roofBillboard` (made-up advertisers, `L.ADS`), `L.sideAd`.
- `L.shell` hollow walk-in shells; `L.unitInterior` kinds: food, store, barber, phone, laundry, studio.
- `L.shop{interior=true}`: see-through storefronts and walk-in doors. Used for Burger Shack, Cafe La Habana, Fresh Cutz and Liberty Sound.
- `L.bays{interior=true}`: lifts, tool chests, tyres (Westside Auto Repair). Food Mart (spawn) is now walk-in.
- Houses: gable ends in the wall colour, blue-grey roofs, Florida-room wings, carports, porches, dishes, tall grass.
- Walk-ups: script name on a raised parapet, stair rails.
- Courts: gate gap, bench and lights.
- The `PaintedMetalA` variant is red, so it was removed everywhere (757 parts).

## New build scripts
- `32_cafe`: Cafe La Habana with interior.
- `33_exchange`: wrap-around LED ticker (3 bands) and VBX banners.
  - The StockMarket server only sets the text.
  - `VBTicker.client` scrolls the bands locally.
- `34_airport`: Vice Bay International, north of Coral County.
  - Coral Way continues north as Airport Rd → Airport Blvd.
  - 1,960-stud runway, open to cars through the service gate.
  - Terminal walk-in hall, 3 gates with jet bridges, tower, hangars, cargo sheds.
  - Heliport, fire rescue, Airport Inn, rental cars, fuel farm.
- `35_portsol_extras`:
  - Sol Raceway: 3,763-stud lap, 900-stud straight.
  - Port Sol Regional (2nd airport).
  - Sol Marina.
- `36_hood_west`: Mangrove Bay south half → Westside hood blocks.
  - Streets: NW 52 Ave plus NW 30–42 St.
  - Activities: Sudz Car Wash (job), Westside Courts, Westside Boxing (job), Fresh Cutz (job), Liberty Sound Studio (job), Westside Car Meet.
  - 3 hood empty lots became pickup courts.
- `26`/`28` now include the Airport and HoodWest folders.

## Aircraft (ServerStorage.VBPlanes, scripts stripped, nose -Z, pivot = ground centre)
- Airliner: Creator Store "A330-300 templates" (v2 mini), white, about 115 parts. Tail recoloured per airline.
- BizJet: "Plane Mesh" 17245739099, 2 MeshParts, scale 0.05. Gear added in code.
- Helicopter: 122791874113020. Pad and decals removed.

## Studio camera tip
Screenshots need `cam.CameraType = Scriptable` and `cam.Focus` set. Otherwise Studio keeps the user's view.

Part count: about 194k.

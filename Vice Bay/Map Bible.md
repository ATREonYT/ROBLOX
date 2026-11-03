---
tags: [vice-bay, roblox, map, gdd]

updated: 2026-11-01
---

# Vice Bay – Map Bible

A Miami-inspired GTA-style RP map. Players start in the hood (west) and move east toward downtown, the beach, the marina and the islands. Further west, over the Coral Causeway, is the lush Coral County suburb with hills.

> Coordinates are Roblox studs. North = −Z, east = +X. Street level (top of terrain) is **y = 2** (`L.G`). Sea level is about **y = −4**.

## Quick setup checklist (things only you can do in Studio)
- [ ] **Lighting → Technology = Future.** Scripts can't set this, and it's where most of the realistic look comes from.
- [ ] Game Settings → Security → **Enable Studio Access to API Services**, so the stock market can save holdings in Studio tests.
- [ ] Optional: Workspace → StreamingTargetRadius ≈ 900–1024 (StreamingEnabled is already on).
- [ ] Hook your own money system into `ServerScriptService/StockMarket` (`getCash` / `setCash`). It uses `leaderstats.Cash` by default.

## Districts (west → east)
| Zone | Area (approx) | Tier / feel |
|---|---|---|
| Coral County | x −4900…−2320 | Lush Florida suburb. Hills, curvy county roads with jersey barriers, strip malls, stilt houses |
| Coral Heights | hilltop (−3900, −1150), y ≈ 74 | Gated villas on a 74-stud hill, reached by a winding road |
| Glades | x −2050…−1800 | Marsh, airboat tours, boardwalk |
| Liberty Heights (hood) | x −1790…−935 | Tier 1. Crooked streets, alleys, graffiti, barred windows, roll-up shutters, power lines, patched asphalt, red curbs |
| The Tracks + I-95 | x −930…−748 | Rail line + elevated I-95, underpass courts |
| Wynwood / Midtown | x −720…300, north of river | Tier 3. Murals, warehouses, lofts, midrises, construction site |
| Little Habana | x −720…300, south of river | Tier 2. Colorful Spanish-sign storefronts, Domino Park |
| Port District | z 960…1140, x −1790…−100 | Freight, container work, fish market |
| Downtown (on the beach) | x 300…1440 | Tier 4. Towers, Stock Exchange, bank, exotic dealer, City Center supertalls |
| Beach | x 1460…1640 | Promenade, lifeguard towers, pier, bandshell |
| Yacht Marina | basin x 1000…1640, z 650…1060 | Floating docks, ~50 yachts, superyachts, fuel dock, dry stack, lighthouse |
| Islands | offshore | Star Island (only island with a bridge), Sunset Isles, Fisher Key, Key Vice, Sandbar, Cayo Perdido, Bird Key (boat only) |

## Key roads
- **Shore Rd** z −1110 · **North Ave** z ≈ −830/−820 · **Flagler** z ≈ −420/−400 · **Calle Ocho** z ≈ 600 · **Port Blvd** z 960 · **Port Rd** z 1060
- **Glades Rd** x −1790 · **Railroad Ave** x −935 · **I-95 Frontage** x −720 · **Biscayne Blvd** x 300 (palm median) · **Ocean Blvd** x 1440 (beachfront, palm median)
- **Dixie Ave**: diagonal through the hood. **River bank roads** on both sides of the Vice River.
- **Coral Causeway**: an arched bridge (26 studs high) from Glades Rd/Flagler to **Coral Blvd** (z −430, 4-lane palm median).
- **Main St (county)** x −3200 · **County Rd 1**: curvy, with barriers · **Shore Dr** on the south coast · **Coral Heights Rd**: winding, climbs the hill.
- **Star Island Causeway** from Ocean Blvd (z ≈ −800).

## Spawn
- `HoodSpawn` at **(−1432, 2, −378)**: the Liberty Food Mart parking lot, like the reference screenshots.

## Points of interest (98 tagged parts in `Workspace.ViceBay.POIs`)
Each POI is an invisible part with a ProximityPrompt and a floating map icon. Attributes: `Category`, `DisplayName`, plus `Job`/`Pay`, `Price`/`Tier`, `Sells`, `PriceMin`/`PriceMax`.
CollectionService tags: `JobSpot`, `Dealership`, `Shop`, `Property`, `Park`, `Finance`, `BoatDock`, `GasStation`, `ATM`, `POI`.

### Jobs
Hood: Burger Shack (cook), Westside Auto Repair (mechanic), A1 Scrapyard, City Sanitation, Westside Recycling, Suncoast Freight (trucker), Fire Station 3.
Habana: Cafe La Habana (waiter), Habana Pizza (app delivery), RideShare Hub, SuperMercado (stocker).
Wynwood/Midtown: Mural Crew (street artist), Creator House (content creator), Rivet Roasters (barista), Food Truck vendor, Sparkle Car Wash, The Vue construction site.
Downtown: VBX Trading Floor (trader), Biscayne National (teller), Brickell Financial Center (office), Grand Bay Hotel (valet), Mercy Hospital (paramedic), VBPD (police).
Beach/Marina: Lifeguard HQ, Helados stand, Pier fishing, Superyacht deckhand, Boat tours captain, Fisher Key ferry captain.
Islands/Glades: Star Island pool & garden, Cayo Perdido salvage diver, Glades airboat tours.
County: Coral County Fire Station 1, Mangrove Center clerk, The Old Pier cook.

### Dealerships (cheap → luxury)
Lucky's Used Autos (hood) → Habana Moto → Bayside EV & Motors → Prestige Exotics (downtown, turntables) → Vice Bay Yachts & Boats (marina).

### Properties (the come-up)
Starter Crib ($2.5k, **interior**) · Liberty Projects · Little Habana House · Wynwood Loft · Midtown Apartment · Palm Shores House ($240k, **interior**) · Shore Drive Stilt House · Downtown Condo · Grand Bay Penthouse ($1.8M, **interior + elevator**) · One Ocean Penthouse ($2.5M, **interior + elevator**) · Mercury Bay Sky Penthouse · Coral Heights Villa ($4.5M, **interior**) · Sunset Isles Villa · Fisher Key Golf Villa · Star Island Mega-Mansion ($12M, **interior**).
Interiors live in `Workspace.ViceBay.Interiors` and are tagged `PropertyInterior` with `PropertyName` and `Price` attributes. Penthouses use elevator doors tagged `Elevator`, handled by `ServerScriptService/PropertyElevators`.

### Parks & open space
Liberty Park (courts + skate) · Underpass Courts · Domino Park · Wynwood Walls · Food Truck Park · Midtown Park (pickleball/dog park) · Riverwalk Greenway · Beach Park & Bandshell · Key Vice Lighthouse Park · The Sandbar · Bird Key · Glades Boardwalk · Coral Heights Lookout.

## Stock market (Vice Bay Stock Exchange, "VBX")
- Building: Exchange Plaza, downtown (800, −200). A colonnade hall you can walk into, a trading floor with desks, a big board, 6 terminals and a tower above.
- `ServerScriptService/StockMarket`: 10 fictional stocks (VBX, BSCN, PRST, VOLT, VUE, RIDE, CRTR, NEON, SUNC, YCHT). Prices move every 4 s, with random news events. A scrolling LED ticker runs over the entrance and a live board sits inside. Buy and sell orders have small market impact. Holdings save to the DataStore `ViceBay_Stocks_v1`.
- `StarterPlayerScripts/StockTradingUI`: the trading window (list, chart, buy/sell, net worth) and news toasts.
- Remotes are in `ReplicatedStorage/ViceBayRemotes`: `StockUpdate`, `StockTrade`, `StockQuery`, `StockNews`.

## Look & assets
- Custom PBR materials (MaterialService): `VB_WornAsphalt` (hood roads), `VB_CleanAsphalt`, `VB_GrimeStucco` / `VB_GrimeStucco3`, `VB_CleanPavers`, `VB_RollShutter`, `VB_DockPlanks`.
- Meshes are cleaned (all scripts stripped) and stored in `ServerStorage/VBAssets`: Palm1, Palm2, Tree1, Tree2, Bush, TallGrass, cars (Elantra, Sable, MKZ, Sports), Dumpster, Bags, Trashcan, Boat, Lamp.
- Image decals: graffiti murals/tags and window bars (ids are in `L.IMG` in the builder library).
- Terrain: city ground is Concrete/Ground, parks are LeafyGrass, there are no grass blades, and the water is teal.

## Build system (for adding more)
- `ServerStorage/VBLib` is the builder library (edit-time only). Usage: `local L = require(game.ServerStorage.VBLib:Clone())`
  - Roads: `L.net(lines, river)` → `L.buildRoads(parent, net, folder)` → `L.roadDetails(parent, net)`; `L.road3D(par, pts, w, {barriers=true})` for hills/bridges
  - Lots: `L.fill(folder, net, chooser, filter)` places buildings along roads without overlapping anything
  - Generators: `house, shop, bays, stilts, walkup, warehouse, church, emptyLot, condoBoard, midrise, tower, supertall, artdeco, flhouse, stripmall, mansion, yacht, sailboat, shell + furnish (interiors), elevator`
  - Props: `palm, tree, bush, weeds, car, policeCar, ambulance, foodtruck, dumpster, hydrant, trashcan, bench, streetlight, trafficLight, stopSign, court, canopy, dock, bridge`
  - `L.poi(pos, category, name, attrs, opts)` adds a gameplay spot
- Road network data is not saved between Studio sessions (it was kept in `_G`). Rebuilding roads needs the line definitions again (see the build log).

## Performance
- About 49k parts in total. StreamingEnabled is on, so phones only load what's nearby.
- Small details (lines, decals, props) have CastShadow and CanCollide off. Wires are Beams, not parts.

## To-do / next passes
- [ ] More dense foliage in the county (refs: wall-to-wall bushes) and more hood clutter (cars at the curb, broken fences)
- [ ] Highway on/off ramps so I-95 is drivable
- [ ] More interiors (projects unit, Habana house, Sunset villa)
- [ ] Night lighting: PointLights on streetlights, neon signs on at night, day/night cycle
- [ ] Gameplay scripts for jobs, dealerships, property purchase (POIs + tags are ready)
- [ ] Refresh the canvas map plan to include Coral County and the City Center supertalls

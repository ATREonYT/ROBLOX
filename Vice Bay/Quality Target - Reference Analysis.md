# Quality Target – Reference Analysis

Screenshots of another realistic RP map (LA-style city + a modern stone villa), saved in `References/Quality Target/city` and `/house`. This is the bar Vice Bay is aiming for. Reference only: nothing is copied from that game.

## Why the city shots look good
1. **Meshes + PBR, not parts.** Walls, curbs, railings, poles, plants and cars are MeshParts with SurfaceAppearance (colour + normal + roughness). Parts with MaterialVariants get close for big flat surfaces (walls, roads); props need meshes.
2. **Continuous street walls.** Every block face is built out to the sidewalk, with no grass gaps. Ground floors are shops with awnings, signs and lit interiors; upper floors are repeated windows set into deep frames with cornices.
3. **Street furniture is dense and correct.**
   - Signal mast arms carry **street-name blade signs** (Wilshire, Anderson, 6th St).
   - Pedestrian heads, cobra-head lights, wooden **utility poles with sagging wires**.
   - Newspaper boxes, hydrants, mailboxes, bollards, bike racks, bus shelters with ads, parking meters, A-frames.
   - Curbs are painted red or yellow in places.
4. **Road paint tells you how to drive.**
   - Turn arrows, "ONLY" / "LANE" / "BUS" text, continental (zebra) crosswalks on every leg.
   - Hatch islands, lane-drop dashes, a double-yellow centre line.
5. **Big storytelling surfaces.** Large murals on blank side walls, graffiti on the viaduct, rooftop billboards, water tanks and HVAC.
6. **Infrastructure layers.**
   - Elevated freeway with round columns.
   - Arched bridge with balustrade and pylons; an underpass lit by fluorescent strips.
   - Rail viaduct, pylons with power lines, open-deck parking garages.
   - Surface parking lots with stalls, arrows and a ticket booth.
7. **Plazas.** Steps, planters, umbrella seating, palms, a fountain and level changes, all built around a central landmark.
8. **Lighting.** Future lighting, warm low sun, strong shadows and atmospheric haze. At dusk, lit windows and neon carry the scene.
9. **Streaming placeholders.** The black boxes in some shots are low-detail stand-ins for far models (StreamingEnabled model LOD).

## Why the villa looks good
- **Massing.** Stacked, offset white volumes with thick fascia slabs and deep overhangs. Floors cantilever past the stone walls below, and the composition is asymmetric.
- **Materials.**
  - Natural **fieldstone** on piers and blade walls.
  - Off-white render on the slabs; black-frame glazing with **horizontal blinds** half down.
  - Dark vertical-board pivot door with a long wood pull; vertical timber cladding on the garage.
- **Landscape.**
  - Raised stone planters with clipped **box hedges**.
  - Black bollard lights, large-format grey pavers, lawn, big boulders.
  - Pool edged in **dark mosaic tile**; pool water is terrain water.
- **Garden structures.**
  - Timber **pergola** cabana with a slatted roof and slat shadows.
  - White deep lounge sofas, a dining table with orange chairs, shade sails, a row of sun loungers.
- **Roof.** Rows of solar panels, AC condensers, flue pipes, thin railings and planted terrace edges.
- **Interiors (mesh furniture).**
  - Board-formed concrete walls; a black textured feature wall.
  - Slatted oak panels; faceted 3D gold wall panels; dark built-in shelving styled with books, vases and trailing plants.
  - Copper industrial pendants, a sage-green kitchen with a mosaic backsplash, rattan stools.
  - A freestanding bath, a walk-in shower with black grid glass, linen bedding, a leather lounge chair.

## How Vice Bay applies it (decisions)
- **Houses** — `src/Villa.lua`:
  - The composer combines several *shapes* (bar, L, U-courtyard, stacked offset, split-level, tower + wing) with several *finishes*, so no two houses match.
  - Shells only in Workspace (floors, walls, glass with blinds, landscaping).
  - **Interiors are built into `ServerStorage.VBInteriors/<HouseId>` and only cloned in when the house is claimed** (the `Owner` attribute is set), then removed when it's unclaimed. Keeps the live map light.
- **Performance budget.**
  - About 250–350 parts per unclaimed villa shell.
  - Detail comes from textures (MaterialVariants), UIGradient blinds, and solar and grid patterns on one part each, not extra parts.
  - Furniture meshes only load on claim.
- **City backlog**, from the list above:
  - street-name blades on signal arms
  - wires between poles
  - murals
  - open-deck parking garages
  - surface lots
  - underpass lighting
  - plaza level changes
  - shop interiors behind the glass

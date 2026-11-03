# Villas – Shapes, Finishes, Claimed Interiors

Every luxury house on the map (65 of them: Star Island, Sunset Isles, Fisher Key, Coral Heights and Mangrove Bay) comes from `src/Villa.lua`.
- **Target:** the stone-and-white villa references in `References/Quality Target/house`.
- **Rebuild:** `R.run("12_islands")`, `R.run("13_county")`, `R.run("17_mangrove")`, then `R.run("20_fit_landmarks")`.
- **Test one lot:** `R.run("21_villa_test", shape, palette, mirror)`.

## Shapes
The plan is a set of rects in house space (z = 0 at the front building line).

| Shape | Ground floor | Upper floor |
|---|---|---|
| bar | one long box | cantilevers to the garden and one side |
| ell | L-shape (wing to the garden) | over the opposite half |
| court | U around a courtyard (glass faces into it) | one side |
| stacked | two offset boxes | one big slab over both, overhang at the street |
| split | two halves, one stepped back | over one half, cantilevered |
| tower | long box + side wing | upper floor + a third-floor glass pavilion |
| wing | front bar + garden wing | sits across the back |

- Every house is randomly mirrored as well.
- The seed comes from the house name + position, so a rebuild reproduces the same house.

## Finishes (`L.VILLA_PALETTES`)
- **stone:** light fieldstone ground floor, white render upper floor, black frames, solar panels.
- **darkstone:** dark stone, concrete upper floor.
- **stucco:** all white, oak door and garage.
- **black:** black vertical siding, timber piers, dark-stone landscaping.
- **concrete:** board-formed concrete, bronze frames.
- **med:** beige stucco, clay hip roof, no glass on the street side.

## How detail stays cheap
- **Blinds:** venetian blinds are a SurfaceGui with a striped UIGradient on the glass. Each bay is lowered to a random height, so there are 0 extra parts.
- **Boards:** garage boards, door boards, pergola slats and solar cells use the same stripe trick.
- **Stone:** fieldstone is a MaterialVariant copied from MatPack G/D into `MaterialService.Realistic`:
  - StoneFieldLight = Cobblestone_PBR
  - StoneDark = MatPackD cobblestone
- **Large pavers:** PaverLargeGrey = MatPackI Concrete_Tiles_A (base material CorrodedMetal).
- **Facade rules:**
  - Back faces are always glass.
  - Side faces are solid with a slot or ribbon window.
  - The front has a stone pier pair around a pivot door, a timber garage door, and tall glass where the stair is.
- **Roof:** solar rows (max 3), condensers, flues.
- **Garden:**
  - Mosaic-lined pool cut into the terrain, with a paver terrace.
  - Timber pergola cabana with a white lounge.
  - Copper-post dining under a shade sail.
  - Boulders, palms, bollards, stone planters with box hedges.
- **Budget:** about 380 parts per shell.

## Interiors only for owners
- **Build:** `src/VillaInt.lua` builds each house's interior into `ServerStorage.VBInteriors/<HouseId>`, about 230 parts each.
- **Load:** the `ServerScriptService.VBHouseInteriors` script clones the interior in when the house's `Owner` attribute is set, and swings the pivot door open.
- **Unload:** it removes the interior and closes the door when `Owner` = "" or the owner leaves.
- **API:** `ServerStorage.VBHouseAPI:Invoke("claim", house, player)`, `("release", house)` and `("list")`.
- **Tag:** houses are tagged `VBHouse`. Attributes: `HouseId`, `HouseStyle`, `Owner`.

**Room layout** follows the shell:
- **Main volume:**
  - kitchen run plus island at the garage end (sage, black, white, oak or teal cabinets; mosaic backsplash; copper pendants; rattan stools)
  - dining by the glass
  - living at the stair end: dark media wall with books and a faceted oak panel, mesh sofa from `VBFurniture`, rug, lamp, plants, curtains
- **Wings:** guest bedroom or second lounge.
- **Upstairs:** master bedroom (slat wall, triptych, sideboard, lounge chair, freestanding tub by the glass), bathroom (walk-in shower with black grid glass, vessel sinks, WC), and an office.
- **Light budget:** at most 9 PointLights per interior.

**Furniture kit:** `ServerStorage.VBFurniture`, free Creator Store models with scripts stripped, re-pivoted so −Z = front. Includes:
- sofas: SofaChaise, SofaWalnut, SofaLeather, Loveseat, SectionalU, LoungeLeather
- chairs: Arm1, Arm2, ChairAccent, ChairDesk
- beds: BedLow, BedWhite (BedSuite is stored but no longer placed)
- tables and decor: SideTable, CoffeeBench, Planter, Decor_*
- boulders: Boulders1, Boulders2, Boulder3

## Result
- Live workspace went from 168k to 150k parts.
- Shells total 25k parts, and 15k interior parts sit in ServerStorage.
- The rollout produced 30 different shape/finish combinations across 65 houses.

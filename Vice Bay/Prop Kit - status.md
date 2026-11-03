# Prop kit: status (Nov 2)

The library is in `ServerStorage.VBProps/<Category>/<Name>` and is built by `src/build/38_props.lua`.
- Every item is cleaned: no scripts, sounds, prompts or welds; anchored; CanTouch/CanQuery off; small items have no collision or shadow; MeshParts use Box collision.
- The pivot sits at the bottom centre, so props drop straight onto a floor or shelf.
- Raw downloads are kept in `ServerStorage.VBPropCandidates` for review.

| Category | Item | Source |
|---|---|---|
| Store | ShelfBay (4 × 6.5 × 15, 5 shelves) | Creator Store 94350431635711 |
| Store | Register | Creator Store 108737011917105 (scaled to 1.6) |
| Store | DrinksFridge (3 glass doors, LED header, lit, stocked) | built in Studio (the store fridge rendered solid black) |
| Kitchen | Grill, Fryer | 14144434425, 2725730657 |
| Garage | CarLift, ToolChest, TireStack, Jack | 89290978342285, 9675076041, 9504148189, 12931798761 |
| Depot | Pallet, Forklift, PalletJack, Container | 10627539754, 12635164828, 94188768861634, 77003885266485 |
| Jobs | MopBucket, WetFloorSign, CardboardBox | 2414950007, 4950163226, 102880290032203 |
| Street | Hydrant, Payphone | 439585165, 4900193185 |

## Rejected
- Soda fountains: real brand names (cola brands).
- One payphone: "shell" in the name.
- The first fridge model: renders black.
- Anything from "Content Deleted" creators.

## Still to do (AI mesh generation)
- Roblox's mesh generator returned "Failed to fetch image for model generation" for every prompt (an outage on their side). Retry, or generate in Meshy/Tripo with the prompts in [[Prop Art List and Prompts]].
- Still needed:
  - product kit (cereal box, can, 2L bottle, chip bag, jar)
  - label images
  - burger, fries, tray, cup, takeout bag
  - exhaust hood, soda fountain (unbranded), valet podium, card reader, security window
- Once the meshes exist, name them `Gen_<Name>` in Workspace and re-run `38_props`. They move to `VBProps/Products`. Shelves are filled with `L.fillShelfRow`, which applies the shelf placement rules from the prop list (brand blocks of 3–6, 5–15% empty slots, ±5° yaw, every 3rd–5th item pulled forward).

## Check before use
- The CarLift mesh texture has partial brand lettering on the post ("…ert"). Retexture it or hide it before it goes in a visible spot.

## Nov 2: realistic low-poly pass (`src/build/39_prop_style.lua`)
The style matches the hood buildings: real sizes, simple honest shapes, muted colours (≤ ~200), real materials (brushed steel, matte plastic, cardboard), small believable details, and wear from decals.

**Rebuilt from scratch** (the old versions are in `ServerStorage.VBPropsOld`):
- ShelfBay: double-sided gondola with kick plate, uprights, end panels and price strips.
- Register: POS with tilted screen, printer and card reader.
- Grill: flat-top on a steel stand, oil-stained plate, knobs.
- Fryer: two oil vats, baskets, control panel.
- New: ExhaustHood and PrepTable.
- WetFloorSign: A-frame with CAUTION text.
- MopBucket: wringer, casters, mop.
- CardboardBox: tape and a "THIS SIDE UP" label.
- New: TrashBag.
- Container: 20 ft, corrugated, corner posts, lock bars, ID number.
- Payphone: unbranded.

**Kept** (good textured meshes): forklift, pallet, pallet jack, jack, tyres, car lift, hydrant, plus the built drinks fridge. Colours on untextured parts were desaturated by 30% and capped at 80% brightness (354 parts).

## Nov 2 (2): the whole kit is low poly
The textured Creator Store meshes looked too detailed next to the built props, so they were rebuilt as chunky low-poly models in the same style:
- tyre stack
- floor jack
- tool chest
- two-post car lift
- pallet (real 1.2 m size)
- pallet jack
- forklift
- fire hydrant

The meshes are kept in `ServerStorage.VBPropsOld`. The whole library is about 610 parts.

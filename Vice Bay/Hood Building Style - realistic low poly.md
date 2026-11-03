# Hood building style: realistic low poly (Nov 2)

The look was perfected on one test building and then applied to every hood builder through shared helpers in `src/lib/Build.lua`. Reference: the two-storey stucco block in `References/Larp/larp_09`. The test building is kept in `ServerStorage.VBStyleReference`.

## Recipe
- **Shape:** plain boxes with real proportions.
  - Floors 10–11 studs, ground-floor shops 12–15, parapet 1.8 with a light concrete coping on top.
  - The parked car (19 × 5.8) is the scale check: a roll-up door is 11 wide × 9 tall.
- **Walls:** plain Plaster or Brick, no noisy MaterialVariant. A water/mould streak decal (`rbxassetid://729943180`) goes on all four faces (0 extra parts). Sometimes a crack (30217423 / 483309292) or peeling-paint (164688340) decal panel.
- **Plinth:** a 2-stud dark concrete band around the base.
- **Palette:** muted only (`L.HOOD_COLS`): tans, greige, dusty salmon, faded sage and blue-grey, cream. Accents come from signs, cars and avatars.
- **Windows** (`L.win`): white frame plate, dark glass, cross mullion and a deep concrete sill. Bars are 7 verticals plus 3 rails, set forward. `L.sideWindows` puts windows on side walls too.
- **Facade life:**
  - split-AC condensers with a round fan and a pipe (`L.facadeAC`)
  - wall packs, meter banks, downspouts
  - roll-up shutters in grey metal with horizontal stripes (`L.villaStripes`, no textures)
  - rooftop billboards
- **Roads (37_hood_roads):**
  - dark stock Asphalt (38–46 grey)
  - oil (118775947) and wet-smudge (182906320) decal stains
  - patches with a pale rim and a dark centre (centre raised 0.07 to avoid z-fighting)
  - thin crack lines, oily gutters, faded paint
- **Don't use these:** the noisy HoodStucco* variants, DryGround/DirtLot (render as blue camo) and any user-uploaded image (blocked in the group game). Decal 146096699 has a grey background, so don't use it on roads.

## Part budget
- Wall wear is now decals, so the part-built streaks and patches in `L.grime` were removed.
- The map is about 206k parts.

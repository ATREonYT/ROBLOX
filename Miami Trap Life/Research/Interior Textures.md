# Interior Textures (Nov 2 2026)

Back to [[00 Master Plan]]. Goal (Alex): interiors stop looking like "old Roblox" (flat SmoothPlastic, the built-in Marble/CeramicTiles). Use modern PBR MaterialVariants that load in the group game.

## What loads in this place (tested)
- The group game can only use assets that are public / Roblox-owned or shared with the group. Images uploaded to Alex's personal account are blocked ("experience doesn't have access permission"). Some Roblox "Realistic" maps are blocked too: `Realistic.PlazaTiles` (normal 10998920777), `Realistic.RustCoarse` and `Realistic.RustyGrate` (metalness 9533230317) fail with "Asset is not approved for the requester". Check the Output for `Unable to load MaterialService.<name>` after adding any variant.
- Tested OK (no load errors, swatch board `Workspace.MTL_BuildingLab.TextureSwatches`, variants in `MaterialService.MTL_InteriorCandidates`, prefix `MTLc_`):
  - Roblox **Modern City Materials Pack** (Creator Store 13168345645, Roblox-owned): Plaster_A, Concrete_Tiles_A, PaintedBrick, Sidewalk_A, Concrete_Board_Formed_A, Concrete_Ribbed_A.
  - **HydraSix's Ultimate Material Pack** (11287061876, 511 variants, 0 scripts): Cheap Old Linoleum, Modern Tiles, Base White Tile, Industrial Tiles, Black White Tiles, Patterned BW Vinyl, Vintage Tile, Rectangle Polished Tile, Exquisite Polished Tile, Diamond Inlay Tiles, Rich Brown Tile, Luxury Vinyl Planks, Oak Floor, Office Carpet Fabric, Office Ceiling Tiles (30 studs/tile), Worn Painted Cement, Concrete 2, Sprayed Wall Texture, Fibrous Plaster, Painted Brick, White Brick Wall, Paint Peeling.
  - **Yasu's Wood Material Pack** (138519880374700, mvyasu, 35 variants, 0 scripts, colourless 1024² maps so Part.Color tints them): Varnished/Matte/Worn wood in herringbone, chevron, brick, checkerboard, endless planks.
  - Omair's Tiles pack (15536831081): TilesSmall/Medium/Big on Granite.
- Vetting rule: every free pack is scanned for `LuaSourceContainer` before use (the props thread found a backdoor in a free model). The three packs above have none.

## How to apply (rules)
- A MaterialVariant only renders from `MaterialService`, and the part's `Material` must equal the variant's `BaseMaterial` (e.g. Patterned BW Vinyl is Plastic, Office Ceiling Tiles is Plastic, the HydraSix tiles are Pavement).
- Colourless/pale maps are tinted by `Part.Color`: keep floors and walls at or under ~196 grey (the lighting rule), otherwise they wash out white.
- Set `StudsPerTile` per surface: floor tiles ~4–8 studs so a tile reads at human scale; ceiling tiles 8 (2x4 ft look); walls 8–10.

## Planned mapping (job interiors)
| Surface | Variant |
|---|---|
| Food Mart sales floor | Cheap Old Linoleum (VCT look) or Modern Tiles |
| Food Mart stockroom, auto shop floor | Worn Painted Cement / Concrete 2 |
| Every drop ceiling | Office Ceiling Tiles |
| Store walls (painted drywall) | Plaster_A (Roblox Modern City); Sprayed Wall Texture read too dark grey |
| Burger Shack dining | Patterned BW Vinyl (or Black White Tiles) |
| Burger Shack kitchen | Industrial Tiles; walls Base White Tile |
| Mall corridor | Rectangle Polished Tile / Exquisite Polished Tile; shops Luxury Vinyl Planks, Oak Floor, Varnished herringbone |
| Auto shop office | Luxury Vinyl Planks; waiting area Office Carpet Fabric |

## Texture-generation prompts (only for gaps)
Use these only if a surface still looks wrong after the packs above (seamless, square, 1024², PBR set: albedo + normal + roughness, no lighting baked in):
- "Seamless supermarket vinyl composition floor tile, 12-inch squares, off-white with faint grey speckle, thin dark grout lines, light scuffs and cart wheel marks, flat top-down, even lighting, PBR albedo"
- "Seamless 2x4 acoustic drop-ceiling tiles in a white metal grid, fissured mineral fibre texture, slight yellowing, top-down orthographic, even lighting"
- "Seamless red and white diner checkerboard vinyl tile, 9-inch squares, worn glossy finish, small chips at the corners, flat top-down, even lighting"
- "Seamless commercial kitchen quarry tile, terracotta red 6-inch squares, dark grout, greasy sheen, top-down, even lighting"

## Applied (Nov 2, live)
`MaterialService.MTL_Interior` (copies with stable names, StudsPerTile set): MTL_VCTTile (Base White Tile, 20), MTL_WallTile (Base White Tile, 10), MTL_CeilingTile (Office Ceiling Tiles, 30), MTL_Drywall (Plaster_A maps, 12), MTL_Concrete (Concrete 2, 14), MTL_DinerCheck (Black White Tiles, 12), MTL_KitchenTile (Rich Brown Tile, 10), MTL_MallTile (Rectangle Polished Tile, 14), MTL_VinylPlank (Luxury Vinyl Planks, 12), MTL_OakFloor (Oak Floor, 12), MTL_Carpet (Office Carpet Fabric, 10), MTL_CounterWood (Yasu Matte_Wood, 8).
The job builders apply them through `JobSiteKit.dress` / `dressPart`, which also sets the part Material to the variant's BaseMaterial and a light tint (`K.Tints`). Textured albedos are darker than flat colour, so these tints (~225-240) sit above the 196 flat-colour cap on purpose.

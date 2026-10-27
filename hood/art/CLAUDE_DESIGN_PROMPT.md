# Claude Design prompt: blocky World 1 objects (v2)

Paste **Part A** once at the start of every Claude Design chat. Then paste one batch from **Part C**.

Attach these reference images in the same message (they're in `CLAUDE_DESIGN_REFS.zip`):
- `ref_style_StreetBox.png` and `ref_style_GraffitiBox.png`: the target style (your own box sheets)
- `ref_style_GameGuns.jpg`: the guns as they are in the game now
- `ref_world_Soldier.jpg`: the game we're matching

---

## Part A: the style bible (paste every time)

You are designing 3D game objects for a Roblox simulator for kids, "+1 Hood Evolution". Every object must look like it belongs in the SAME game as the attached reference images. Match `ref_style_StreetBox.png` and `ref_style_GraffitiBox.png` as closely as you can: same construction, same bevel, same gloss, same colour logic.

**THE ONE RULE: BLOCKY, NOT ROUND, NOT LOW-POLY.**
Build every object ONLY out of rectangular blocks (cuboids), like a toy built from Roblox parts or LEGO bricks without studs.
- "Low poly" (faceted triangles, icospheres, crumpled gems) is WRONG.
- "Soft toy" (pills, blobs, balloons, capsules, smooth tubes) is WRONG.
- If it isn't a box, make it out of boxes.

**Construction grammar** (follow exactly):
1. **Blocks only.** Every piece is a cuboid with a small uniform bevel (≈ 8 % of its shortest side) on all edges. Same bevel on every piece of every object.
2. **Round things are stepped.** Anything round in real life (wheels, barrels, cylinders, cones, crowns, coins, magnets, rings, tree canopies, balls) is built from stacked or stepped blocks or a chunky 8-sided prism. Never a smooth cylinder or sphere.
   - A barrel = an octagonal prism with block bands.
   - A cone = 3-4 square tiers getting smaller.
   - A tree canopy = 3-5 overlapping cubes.
   - A coin = a thick octagon slab.
   - A ring or arrow = an octagon frame of blocks.
3. **Big simple shapes first, then 2-4 layers of chunky detail.** Detail comes from plates, insets and trims stacked on the big blocks, each at least ¼ the size of the face it sits on:
   - raised plates;
   - inset panels;
   - corner caps;
   - trim strips around the edges;
   - square rivets;
   - pixel-style emblems (crowns, stars and symbols made of small square blocks, like the crown on the Street Box).
4. **No thin parts.** Nothing thinner than 1/6 of the object's width. Poles, handles, legs and barrels are chunky.
5. **Solid and clean.** Every block sits flush on, or clearly into, the block under it. Edges line up, things are symmetric where they should be, and every block has a reason to be there. Nothing floats, clips at random or wobbles.
6. **Proportions are toy proportions:** slightly oversized, stubby, readable from far away. The silhouette must say what the object is at 64×64 pixels.
7. **Colour:**
   - 2 to 4 main colours per object, plus white or near-black trim. Use saturated, bright, clean colours like the references: red, white, gold yellow, sky blue, hot pink, lime green, royal purple.
   - Flat colour per block with a soft glossy plastic shine.
   - No textures, no gradients on the model, no realistic materials, no rust or dirt.
   - Light top faces, slightly darker sides (from the lighting, not painted).
8. **Text.** Only big chunky block letters, and only where asked (e.g. "2x", "VIP"). Never small text.
9. **Glow.** Only where asked, as separate flat blocks (they become Neon in Roblox).

**Banned** (redo the object if any appear):
- faceted low-poly spheres or gems;
- pills, capsules or blobs;
- smooth cylinders, cones or tubes;
- thin poles or wires;
- floating or intersecting junk;
- tiny details;
- realistic textures;
- more than 4 main colours;
- rounded "inflated" look;
- anything that wouldn't match the Street Box.

**Output for EACH object:**
- One image: ¾ view from slightly above, on a plain very light grey background, soft shadow, same studio lighting as the references.
- A second image: a straight side view (front view for signs and boards).
- A `.glb`:
  - units in Roblox studs (1 unit = 1 stud; a player is 5 studs tall);
  - pivot at the bottom centre;
  - front facing −Z;
  - one mesh per colour group is fine;
  - glow blocks as separate meshes named `<Name>_Glow_<RRGGBB>`;
  - under 10,000 triangles.
- File name exactly as given in the batch list.

**Before you show me an object, check it yourself against this list and fix it:**
1. Is every piece a bevelled block (or a stepped octagon for round things)?
2. Would it sit next to the Street Box without looking like a different game?
3. Is anything thin, floating, clipped or tiny?
4. Is the silhouette readable at 64×64?
5. Are there 4 main colours or fewer?

---

## Part B: how round things become blocky (give this to Claude Design too)

| Object | Wrong (what it made) | Right (blocky) |
|---|---|---|
| Tree | faceted icosphere blobs | a chunky square trunk, a canopy of 3-5 stacked or overlapping bevelled cubes in 2 greens |
| Bush | faceted blob | 2-3 overlapping bevelled cubes |
| Hydrant | smooth rounded hydrant | stacked octagonal blocks, square side caps, a stepped top |
| Trash can / barrel | smooth cylinder with rings | an octagonal prism, block bands, a stepped lid |
| Cone | smooth cone | 4 square tiers getting smaller, on a square base plate |
| Sandbags | soft pillows | bevelled flat bricks, stacked like a wall |
| Car | rounded toy car | box body plus box cabin, square block wheels with a hub plate |
| Street lamp | thin pole | a chunky square post (≥ 1 stud), a box lamp head |
| Basketball hoop | thin pole and wire net | a chunky square post, a box backboard, a square block rim, a net made of 3 block strips |
| Magnet | smooth U tube | a U made of 5 blocks, block caps on the ends |
| Dumbbell | round plates | octagon slab plates, a square bar |
| Crown | smooth dome | a block band with square block points, square gems (like the Street Box crown) |
| Coin | smooth disc | a thick octagon slab with an embossed square-pixel symbol |
| Gun | pills and smooth tubes | box receiver, box barrel (octagon at most), box grip and mag, plates and trims |
| "Auto" arrow ring | smooth torus | an octagon frame of blocks with a block arrow head |
| Clover | smooth leaves | 4 leaves, each made of 2-3 square blocks, a block stem |
| Pad base | glossy saucer | an octagon slab, 2 stepped tiers, a glow strip inset in the top edge |

---

## Part C: the batches (paste ONE per chat, after Part A)

### Batch 1: Robux pad prizes (~5 studs; these sell Robux, so make them the most exciting)
- **Pad_DoubleRep:** a block dumbbell, octagon plates, with "2x" in chunky block letters standing beside it.
- **Pad_DoubleCash:** a stack of block cash bundles with a paper band, 2 octagon coins and "2x".
- **Pad_VIP:** a block crown with square gems (Street Box style) on a velvet block cushion, and "VIP".
- **Pad_AutoShoot:** a blocky toy pistol inside a block "auto" arrow ring.
- **Pad_Lucky:** a block four-leaf clover on a thick octagon gold coin.
- **Pad_TripleOpen:** 3 stacked block shoe boxes in 3 colours, and "x3".
- **Pad_AutoOpen:** a block shoe box inside a block "auto" arrow ring.
- **Pad_ExtraEquip:** a blocky sneaker with a big block "+1".
- **Pad_Speed2x:** a blocky sneaker with block wings and a block lightning bolt, and "2x".
- **Pad_AutoCollect:** a block U-magnet pulling 3 octagon coins.
- **Pad_Base** (8 wide): an octagon slab with 2 stepped tiers, and a glow strip inset in the top edge (`_Glow_`).

### Batch 2: guns (side view matters most: that's how they look in the hand)
Pistol, Revolver, Uzi, Shotgun, Tommy, AK, Deagle, Minigun, Blaster, Diamond. Match the silhouettes and colours in `ref_style_GameGuns.jpg`, but build them in the Part A style. Make each a step more impressive than the last.
- Diamond: built from blocky blue "diamond" cubes with gold trim.
- Blaster: glow fins (`_Glow_`).
- Minigun: an octagon barrel cluster.

The grip's middle is the pivot (origin), with the muzzle facing −Z.

### Batch 3: lobby hero objects
- **Gate_Stage1** (20 wide × 14 tall): a block arch with a big plain sign board on top. Leave the board blank; the game writes on it.
- **Board_Boxes:** a hanging block sign with block chains.
- **Pedestal_Box** (7 wide, 1 tall): an octagon slab, 2 tiers, a glow inset.
- **Stand_Guns:** a block gun-shop counter with 10 block wall hooks and an awning made of block stripes.
- **Board_Leaderboard:** a block frame, 8 × 12, with an empty dark screen area.
- **Chest_Codes / Chest_GroupReward:** chests in the exact style of the Street Box (hinged block lid).
- **Stand_SpinWheel:** an octagon wheel with 8 block segments on a block stand.
- **Portal_World2:** a block arch with a glow inset (`_Glow_`), block chains and a block padlock.
- **Spawn_Pad:** a plain octagon slab, 12 wide, 2 tiers, no symbol.

### Batch 4: shooting range booths (8 wide × 12 deep, open sides, no side walls)
Range_1 … Range_8 and Range_VIP, each a different theme: street corner, carnival, target wall, junkyard, furnace, balloon party, neon arcade, toxic slime, gold VIP. Also Target_Dummy (5 tall, a block body with a block target on the chest).
Each booth is:
- a flat floor plate with a 1-stud rim;
- a back wall with the theme;
- ONE big target;
- 2-3 chunky theme props.

No thin poles.

### Batch 5: plaza scenery
Use the Part B table for every round thing:
- Tree_1, Tree_2, Bush_1;
- Cliff_Block: orange clay with a grass top, terraced in 3 stepped block layers;
- Building_1 … Building_4: low hood buildings, block windows and awnings;
- Hydrant, TrashCan, Bench, StreetLamp, Cone, Barrel, Crate, Sandbag, Car, Hoop, Fence, GraffitiWall (graffiti made of chunky pixel blocks).

### Batch 6: stage props
- **Street:** parked car, bus stop, newspaper box
- **Corner:** shop front, phone booth, crates
- **Alley:** dumpster, fire escape, pallets
- **Courts:** hoop, bleachers, fence
- **Yards:** shipping container, forklift, crane hook
- **Warehouse:** shelving, pallet boxes, roller door

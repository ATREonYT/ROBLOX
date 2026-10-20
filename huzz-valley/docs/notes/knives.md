# Knives

Read before touching knife skins, the worn knife, the Game Pass knives and their cards, the SetupKnives helper or
the stand sword showcase. The stab and lunge motion: [stab-lunge-catch.md](stab-lunge-catch.md). The avatar stands
themselves (where, signs, buying): [lobby.md](lobby.md). Huss Valley's knives and the plan for his models:
`docs/knife-study.md`, sheets `docs/previews/knife-study-*.jpg` (`tools/preview/knife_sheets.py`).

## Skins (`Config/CoinShop` Knife slot)
- His 30 `design/knives/Knives/*.glb` (+ `All_Knives.glb`) are the Knife slot in `Config/CoinShop` (Order 101-130, his
  names and rarities; Common 200, Uncommon 500, Rare 1000, Epic 2000, Legendary 4000, Mythic 8000 coins).
- Old keys sit on fitting models and keep their rules: RookieKnife = Training Kunai, HunterKnife = Hunter's Hook,
  MoonlitKnife = Hollow Moon (quests), SpinKnife = Celestial Edge (wheel, never sold), IceKnife/CandyKnife/ShadowKnife
  = Ice Shard / Sakura Blade / Shadow Cleaver.
- Baked facts (lengths 2.4-3.3 studs, glow colours, part names): `tools/knives/bake_knives.py` →
  `tools/knives/knives.json` + the setup script (53 rows with the pass and Halloween knives).
- Card pictures from the real meshes: `knife_meshes.py` → `render_cards.mjs` → `compose_cards.py` →
  `assets/art/knife-*.png` (packed 192 px; they show in Play only, EditableImage); `docs/previews/knife-cards.jpg`.
  Calm since Oct 20 14:07 (owner: "for all of the knifes, can you make the background look a bit less ai. the glow
  just gives it away like crazy"): a plain dark slate panel, a faint tint of the rarity colour, a soft shadow under
  the knife; no glow halo, bloom, sparkles or swoosh lines (all 53, his 30, 5 pass and 18 Halloween knives; old vs
  new and the ITEMS tab: `docs/previews/knife-cards-calm.jpg`). The PASSES tab's five cards are his own mock-up art
  (`cut_pass_knife_cards.py`, used as drawn), so they keep their glow. A card that can't be drawn shows the knife's 3D
  model instead of an emoji (ui.md, "Picture memory").
- `KnifeService` takes `ServerStorage/HuzzKnives/<Key>` when there, else the built-in knife tinted in the skin's colours.
  Hand by the model's `Grip`.
- **Effects: by tier and theme, from Huss Valley** (Oct 20 07:43, owner: "Can you make the vfx for some swords way
  better and more detailed, make them better for more high end ones"; 07:47: "check out the references provided from
  Huss valley, and then implement the vfx based on it. Make them fit and logically connected to the skin of the
  sword"). The numbers are `KnifeLook.VFX` + `KnifeLook.vfx(skin, where)`; `Shared/KnifeFx.add` builds them on the
  server (KnifeService: in hand, worn, on a stand), nothing runs every frame. The study and the per-skin table are
  in "Knife effects: the Huss Valley study" below; the method for any game's items is the repo's `VFX-ITEMS.md`.
  - Tiers (the coordinator's default, kept; second pass the same day to Huss Valley's VISIBILITY, coordinator: our
    first Celestial Seraph next to MELON5MAN "shows almost nothing", he'd read it as "no effects"): Common and
    Uncommon plain (only the swing trail); Rare one or two faint particle motes; Epic 2 crisp ball motes (1 worn),
    the theme's motif, the gem glowing and 5 slash sparkles; Legendary, Mythic and the pass knives (Exclusive) 3
    crisp ball motes in the gem's colour (3 worn, 4 on a stand), the gem glowing, the motif readable worn, a glint on
    the gem, a faint haze, one soft PointLight (range 6, no shadows; Brightness 1 on a stand, 0.5 in hand, on
    `KnifeFxLightAt` a quarter of the blade out from its middle: at the guard it washed the forearm yellow or pink)
    and the long trail (8 slash sparkles). The
    particle motes stay as a light extra (0.4 of their rate) beside the balls. In hand the full set, on a stand 1.2x
    the rate with no burst, worn 0.8x with no light and no burst (only a slash in hand throws sparkles).
  - The gem glowing (`KnifeFxGlow`, made by `Shared/KnifeFx` on the server, never changing): a solid Neon ball in
    the gem's colour, the whole gem's size and centre (0.1 to 0.35 studs; a gem cut into slices, like the stand-ins'
    two-half Seraph gem, is taken as one: `gemCluster`, so the ball sits in the ring's middle, not on one half;
    the model's `FxGem` attribute names the part, and KnifeModels / KnifeShapes specs print it per knife),
    Transparency 0.08 (Epic 0.15), the PointLight and
    the game's bloom its soft halo, plus a locked `orb` smoke puff. (Third pass, coordinator: the see-through 0.35
    ball "reads as a pale see-through bubble around the guard, which the owner will call cheap or AI".)
  - Ball motes (`Gameplay/KnifeFxRange` + `Shared/KnifeMotes`, on each screen only, so the server never replicates
    moving parts): `KnifeFx` marks the model (tag `HuzzKnifeMotes`, attributes Motes, MoteColor, MoteSize = 5% of
    the knife but never past 0.2 studs (small dots, not orbs), MoteDrift = the theme's rise or sink, MoteSeed); each
    screen makes that many small Neon balls in `Workspace > HuzzKnifeMotes` (no shadow, collide, query or touch;
    anchored) and moves them in one RenderStepped loop (all with one `Workspace:BulkMoveTo`, each part on its own
    if that fails; Transparency written only when it changes by more than 0.02): each floats 3.2 s on a soft loop off the blade's edges (never on the flat or inside it), fading in and
    out over 0.8 s (smoothstep, never a pop), staggered so 2 or 3 of 3 show at once. Four times a second the same
    module drops balls past 70 studs from the camera or on an Invisible player, switches worn knives' particles off
    past 70 studs and every knife's particles off while Invisible (the gem's glow is a part on the knife, so it
    fades with the body). The same loop times the glint (below). `tools/preview/smoke_knife_motes.luau` checks it in
    the harness (the harness keeps its last 500 `ParticleEmitter:Emit` calls in `__emitted`).
  - The glint (the star on the gem, top tier): Rate 0, one `Emit` every 2 s on a fixed timer per knife
    (`KnifeLook.VFX.GLINT_EVERY`, the model's `GlintEvery`; `Shared/KnifeMotes.glint`, never closer than 1.5 s, a
    knife made again waits a whole interval). The critic, Oct 20: at a random Rate 0.5 (plus Celestial's tip star)
    about 59% of the gaps were under 1 s; the tip star is gone and Storm's tiny sparks are its haze, not a glint.
    `tests/Knives.spec` checks no knife has any other locked star on its gem or tip, and runs the timer through
    uneven frames, stalls and remakes.
  - The gem (`KnifeFx` gemOf): his `guard_gem`, else a `gem` (Solar Reaper's pommel), else his biggest Neon part that
    isn't the blade or one of his baked aura bits (`aura_ring`, `aura_shard`, `spark`, `rune`, `wing_glow`: Void
    Fang's floating shards are not a gem). No gem (Void Fang, Abyss Eclipse, Storm Kunai...): no glow ball, the orb
    puff sits at the guard; the ball motes still float. `Gameplay/KnifeDress` leaves `KnifeFx*` parts showing when it hides the stand-in.
  - Limits: 16 particles a second per knife at most (6 per emitter), the glint once every 2 s (no strobing), Roblox's
    built-in particle pictures only (rbxasset://textures/particles/...: sparkles_main, fire_main, smoke_main; never an id we
    haven't uploaded, which shows as a white square), one light at most. `tests/Knives.spec` checks every knife.
  - What stays from before (the trail and arc ladder, `KnifeLook.LADDER`): every skin's slash trail in its own
    colour (`KnifeLook.trailLook`, Common and Uncommon faint, `trailSoft`), Epic and up the catcher's slash arc
    (`arc`); the effects ladder above is `KnifeLook.VFX.TIERS`. `KnifeService` plain still strips anything a model came
    with before ours go on (the Oct 20 03:01 call, "please fix the knifes finally, they are still missing pixels,
    and please just make them be normal": the missing pixels were the stand-in slices, so the effects come off one
    invisible box over the whole blade, `KnifeFxArea`, never a sliver). Old films: `docs/previews/knife-fx-ladder.mp4`,
    `motion3d/knife_fx_scene.luau`, `docs/previews/knives-vs-hv.jpg`, `knife-leap.mp4`.
- **His look, one to one** (`KnifeLook.glbMaterial`, the one rule for all of them): every part takes the Roblox
  material nearest his .glb's metallic and roughness (his blades and guards metallic 0.6 to 0.9, roughness 0.2 to
  0.3; grips metallic 0, roughness 0.8): glowing = Neon, metallic 0.5+ = Metal (Reflectance 0.12 when roughness is
  0.35 or less, else 0.04), roughness 0.7+ = Plastic, else SmoothPlastic. His own import's glow stays where he has
  it: 84 SurfaceAppearances (his colour picture + emissive mask, EmissiveStrength 0.9) on 15 knives, a softer real
  glow than Neon; Neon only on glowing parts without one (78 parts). `Config/Look` EnvironmentSpecularScale went
  0.2 to 0.4 so Metal mirrors the sky at all (0.2 was the Oct 19 matte lighting match: set it back if the plaza
  looks glossy). Nothing is laid over his model: no widening, no glow shell, no sheen (only the trail).

## The worn knife
- `KnifeLook.pick` = the shop's pick, else your first owned knife, else the default knife.
- **Where, by knife** (owner, Oct 19: "make the knifes when equipped be worn either on the back of the character or on
  the side. This is very important, and make the location based on what knife/sword it is"): the one table is
  `Config/CoinShop`'s `Wear` field, "Back" or "Side" on every knife row; the owner can change any of them. First
  picked from his .glb's measured length (`tools/knives/wear_table.luau` prints each knife's measure next to the
  table): 3.0+ studs = **Back** (16: his swords, katanas, reapers, scythe, the 5 pass knives, Celestial Edge, Shadow
  Cleaver 3.08), shorter = **Side** (37: knives, daggers, tantos, kunai, cleavers, sickles, karambits, shurikens; Blood
  Moon Tanto 2.98 is the longest). A knife with no row: the model's `Wear` attribute, else the same 3.0 rule (`KnifeLook.wearOf`).
  - **Back:** diagonal across the upper back like a sword in a back sheath, the handle end up over the right
    shoulder, the blade down to the left hip, `BACK_TILT` 40 degrees, flat side against the back, `GAP` 0.05 off it.
    A two-handed pole (`KnifeLook.twoHanded`: 3+ studs, gripped mid-pole: the reapers and the scythe) is turned
    head up: the head over the right shoulder, the pole down-left, its middle a little right of the spine so it
    clears the head, the hook out to the right.
  - **Side:** the right hip at the belt (R15 LowerTorso, R6 Torso), blade down and `SIDE_TILT` 15 degrees back,
    flat against the hip, just behind the hanging right arm (its forward reach measured from the real corners,
    hanging bits too: `shape.front`), hung the way round that reaches forward least.
  - Capes, wings, long hair (the avatar's own accessories): `KnifeLook.backClear` measures how far what hangs below
    the shoulders reaches behind the back; the back knife goes that much further out, over it. More than
    `CLEAR.Max` 0.9 (big wings): the knife goes to the hip instead (`wornAt`). `KnifeService.refit` runs again
    when an accessory loads in later.
  - Same rule on R15 and R6. The lobby stand copies hold their pass knife in the hand (the showcase) and carry no
    worn knife, so there's nothing to place there.
- Server-built, one per body: `give` (hand) and `giveBack` (worn) each remove the other; RoundService syncs on every
  change, spawn and avatar reload; a shop change swaps it at once (Bootstrap).
- A model the wrong size is refused (plain knife + one `[HuzzKnife]` warning).
- Never off the body: each screen's `Gameplay/KnifeGuard` hides a worn knife whose grip left its mount, or a piece
  that left its grip (see "Honest gaps", the floating black block).
- Spec `tests/KnifeWear.spec`: all 53 (his 30 models, the 23 pass and Halloween stand-ins) on R15 and R6 at rest:
  nothing inside the head, torso, legs or arms, the flat against the body, within 0.35 studs of it (worst 0.34);
  every row's Wear matches its measured length; the pole and hip directions; capes, hair and wings as boxes, and
  through the real KnifeService. Picture `docs/previews/knife-on-back.jpg` (`motion3d/knife_wear_scene.luau` +
  `motion3d/knife_wear_sheet.py`: three back, three hip, from behind and the front, next to a Huss Valley player's sword on
  the back).
- Gaps: checked at rest only: in a run the swinging right arm passes through a hip knife's hilt, and the legs and
  arms of a real avatar (not blocky) aren't checked; from the front a hip knife is mostly behind the arm (its tip
  shows under the hand); Huss Valley's sword sits nearly upright, ours slants 40 degrees (the diagonal was asked
  for); accessories are measured by their boxes, so a big see-through box pushes the knife out more than needed;
  nothing seen in Studio yet.

## In a catcher's hand
- `KnifeLook.handC0(at, reach)`: Huss Valley's grip, blade 150 degrees round the hand (down and a little forward), for
  knives reaching up to `HAND.Reach` 2.2 studs from the grip to the tip; a longer blade is held `HAND.PerStud` 60
  degrees more forward per extra stud (at most `MinAngle` -118), so its tip stays off the floor in the idle, walk and
  run. `KnifeService.reachOf` measures the reach (TrailTip, else the shape). At the old fixed 150 the 3+ stud knives
  went into the floor (Crimson Requiem 0.43 studs under it in the walk).
- In a stab or a lunge the arm is up, so `Gameplay/Actions` eases a long blade back to 150 (`KnifeLook.slashC0`, in
  0.05 s, back in 0.12 s): every knife cuts and leads the leap the same way.
- Spec `tests/KnifeWear.spec` (all 30 and the 5 stand-ins through the pack's Idle, Walk and Run: tip 0.15+ studs over
  the floor; give() turns a long one; slashC0). Picture: the top right of `docs/previews/knife-check-vs-ref.jpg`
  (`motion3d/hand_floor_scene.luau`).

## Game Pass knives (`design/knives/gamepass/Gamepass_Knives.glb`)
- 5 more, rarity **Exclusive** (Mythic's calm effects, pink-white card), Order 131-135, `Pass` in `Config/CoinShop`,
  Price 0, never sold for coins (BuyWithCoins says "That one comes with the <pass> Game Pass.").
- **Each is its own Game Pass** (`Config/Products` `Knife`/`Card`, his card names): Hunter Knife = Crimson Requiem,
  Moonlit Knife = Hollow Eclipse, Sunrise Knife = Celestial Seraph, Inferno Knife = Dragon's Maw, Frost Knife =
  Frostbound Oath (checked against the meshes: all five match). VIP and Dance Pack give no knife.
- `ShopService` grants them only when Roblox says you own the pass (`CoinShop.passGrants`), and wears one if your
  Knife slot is empty. Same pipeline (cards with a GAME PASS label). A refunded pass doesn't take them back yet.
  Once owned, a pass knife's card in the coin shop's items has an EXCLUSIVE rim and label in pink
  (`Screens/Shop` `rarityColor.Exclusive`, as in the admin panel; it had no rarity colour before the knife check).
- **Shop > PASSES** starts with the 5 knife pass cards: since Oct 20 14:31 the Shop's 251 x 338 cards ([ui.md](ui.md),
  "The Shop"), each with his card's knife art (cut from `design/knives/Five_Elemental_Knife_Cards.png` by
  `tools/icons/cut_pass_knife_cards.py` into `assets/art/pass-knife-*.png`, 240 px, Play only until uploaded), the
  name in his card's colour line, and the VIP and Dance Pack rows under them; BUY + Robux mark, "coming soon" and
  never a prompt while `Id = 0`, Price 0 = not set (the live price shows once there's an ID). The older one-to-one
  copy of his card row (`docs/previews/knife-cards-vs-mockup.jpg`) was before the one-page Shop.
- **The cards are alive:** animated card art, not a 3D viewport (his pass models aren't in his place yet and the art
  already is the knife): each card's element colour swells softly over the picture (`Effects.pulse`, about every 5 s,
  never under 0.78 see-through), 7 small shapes of its element float up over it (`Effects.motes`: petals for Hunter
  and Sunrise, dots for Moonlit and Inferno, diamonds for Frost; plain frames, no upload), the white shine, and the
  card lifts to 104% under the mouse (`Effects.lift`). All saved twins, hidden until their loop runs, stopped by
  Reduced Motion. Still `docs/previews/knife-cards-alive.jpg` (the motes are small and calm; the pulse shows only in motion).
- **Stand-ins until his import** (`Shared/KnifeShapes`, data `Shared/KnifeStandIns` = the list, one module a knife in
  `Shared/KnifeStandInParts`, 8-18 KB each, baked by `tools/knives/bake_stand_ins.py`, needs shapely): solid plain
  parts cut from his own `Gamepass_Knives.glb` and `Halloween_Knives.glb`. Each look of his (colour, glow, material)
  seen from the blade's broad side, its outline filled solid and cut into triangles, each triangle two WedgeParts
  turned about the blade's thin axis (a plain rectangle is one block), each piece as thick as his triangles there, a
  smaller piece 0.02 studs proud of each bigger one under it, each side (`OVER`; it was 0.004, Oct 20: Roblox flickers
  between faces that close from a distance, which the offline renderer can't show); at most 199 parts a knife (98 to 199): the piece costing the
  most is smoothed first (his bandage wraps and chain links before anything else), rings never smoothed square and
  real cut-outs never filled (Hollow Eclipse's moon, the Seraph's halo). His colours and `glbMaterial`, his length;
  hanging bits are named Tassel so pommel to tip stays his. Oct 20 (owner: "please fix the knifes finally, they are
  still missing pixels, and please just make them be normal"; his screenshots `design/owner-oct19/2010-knife-red.png`
  and `2010-knife-gold.png` are these stand-ins: Crimson Requiem and Celestial Seraph in his hand): the Oct 19 cut
  (0.04 stud slices of blocks) read as scattered bits, stepped edges and loose feather strips; now each outline is
  whole and smooth. Seen edge on they are flat slabs (his model is rounder). Picture
  `docs/previews/knife-standins-solid.jpg` (the 5 pass knives: his .glb | Oct 19 slices | solid now | his model on
  screen; `knife_glb_scene.luau` with `OLD_SHAPES` = the old `KnifeShapes.lua` and its data, render.mjs draws wedges).
  Worn, close up: `docs/previews/knife-solid-worn.jpg` (the 5 pass knives and Candy Reaper, Thorn Karambit, Toadstool
  Sickle, Grand Witch Scythe, Taffy Karambit, Cupcake Cleaver on the back or at the hip, each from about 3 studs at two
  angles; `knife_wear_scene.luau` with KNIFE_SET=solid, `tools/preview/motion3d/knife_solid_sheet.py`): no seams between wedges
  and no layer fighting the blade offline; one small white tick inside Hollow Eclipse's black blade (a sliver of its
  white edge). Flicker in Studio is still unchecked.
  Spec `tests/KnifeShapes.spec` (lengths, his .glb's box within 0.06 studs from each part's real corners, his colours
  only, at most 200 parts, scaler, stand size, even scale and no shell, nothing on the knife, arc). They are the
  server's knife (length, grip, trail points) and the fallback on any screen that can't draw his model; each screen
  dresses them as his .glb (next). The round 1 hand-made ones: `docs/previews/stand-knives-standins.jpg` (owner's
  Oct 19 screenshot: "an orange blocky jagged blade" and "a small cyan stub", nothing like his model).
- **His .glb on every screen until his import** (`Gameplay/KnifeDress`, data `ServerStorage/HuzzKnifeGlb/<Key>_<n>`,
  handed out by `HuzzServer/KnifeGlbService`): the server tags a pass or Halloween stand-in `GlbKnife` (attribute
  `Glb` = its key, `KnifeService.template`); the first time a screen shows a knife it asks the server for that knife's
  meshes one at a time (remote `KnifeGlb`: `(key, n)` -> mesh, nil when no more, false = "ask again later" past 900
  asks a minute; key and n checked), so nobody downloads all 3.3 MB of the 23 knives at join (Oct 19, with the
  Halloween knives; before that the 5 lived in Shared/KnifeGlb and every player got them). Each client builds his
  model as it is (every triangle, 1,662 to 19,156 a knife, 3 to 14 looks: one MeshPart per colour,
  glow and material, each in its `mat` / `refl` from `glbMaterial`) with `AssetService:CreateEditableMesh` (not
  FixedSize: that refuses AddVertex) + `CreateMeshPartAsync(Content.fromObject(mesh))`, holds it on the Handle with a
  Weld whose C0 is its .glb place, set once every mesh is made (Oct 20: making a mesh waits, a knife on a walking
  body moves meanwhile, and the old WeldConstraints, made against wherever the Handle had been, left the first-made
  pieces floating off the knife by however far it moved; "worn, the body moving" in `tests/KnifeModels.spec`), sized
  by the model's `Stretch` (a stand's big copy, set by `KnifeService.scale`, even every way) and hides the stand-in's
  parts (Transparency 1 on that screen; its particles, lights and trail stay). A stand's copy is a Clone of the
  server's (tags and attributes come along) parented into the Workspace, which the client watches. All or nothing
  per knife; one `[HuzzKnife] pass knives as his model: ...` line in Output says on (print) or why not (a warning),
  quietly: nothing on screen (Oct 19 evening; the red problem box is off too, `UI/Report` SHOW_BOX false).
  **Oct 19, his Studio Play showed the plain stand-ins** ("the server has no meshes for HollowEclipse:
  ServerStorage/HuzzKnifeGlb missing?"): `default.project.json` never mapped `ServerStorage/HuzzKnifeGlb`, so Rojo
  never sent the meshes (mapped since d6db14f; the place build always had them). Next in line is the "Allow Mesh /
  Image APIs" switch (Roblox fails EditableMesh by default in a published place). With the switch off the stand-ins
  show (cut from his outline, above). Checked one to one (Oct 19 evening): `docs/previews/knife-detail-vs-glb.jpg`
  (`knife_glb_scene.luau` with `KNIFE_SET=detail`): his four most detailed knives (Celestial Seraph, Hollow Eclipse,
  Grand Witch Scythe, Abyss Eclipse) as his .glb next to the game's, close up, in the hand, worn and (the pass two)
  big on a stand: every pair matches (same shape, colours, place and size; materials approximated offline).
  Baked by `tools/knives/bake_pass_meshes.py` (16-bit steps across each mesh's box, base64; at most 1,500
  triangles a file, every module under 60 KB: 263 files, the largest 49 KB). Hand, back, hip, stands, admin give and
  crate prizes all go through `KnifeService.template`, so all get it.
  **Where it works:** Studio Play (each screen). Live: Roblox only allows EditableMesh when the owner (13+, ID
  verified) turns on Game Settings > Security > "Allow Mesh / Image APIs" (the same switch the drawn icons already
  need, `UI/ImageLoader`); without that, or on a phone out of mesh
  memory (Roblox's limits: 60,000 vertices and 20,000 triangles a mesh, a memory budget per device), the plain
  stand-ins show. The lasting fix is still his import (SetupKnives below): real uploaded meshes, the same on every
  device, and then nothing here runs.

## In the live game (owner, Oct 20 15:13: "make it so that the knifes also appear inside of the actual roblox game")
What can't show live, and what shows instead (nothing here needs a setting):
- **His 30 imported knives** are his uploaded meshes (680 of them) on an invisible Handle: Studio draws a mesh from
  its own copy right after his import, a live screen loads it from Roblox, and an upload Roblox hasn't finished or
  approved loads nothing there (his Oct 20 Output said exactly that of some crate uploads: "being generated", asset
  120038515596009 "not approved"). Such a knife was simply gone, with nothing in its place: the one path with no
  fallback (every other knife already had one). Cause not proven from here (cloud sessions can't reach Roblox): only
  the live game shows which meshes load.
  Fix: a plain cut of his own .glb for each of the 30, kept as data on the server (`ServerStorage/HuzzKnifeBackups/<Key>`,
  baked by `tools/knives/bake_stand_ins.py backups`, the same cut as the pass and Halloween stand-ins: 40-199 parts a
  knife, 3-17 KB, 399 KB in all). A copy of his knife carries only its `Backup` attribute (`KnifeService.addBackup`).
  Each screen's `Gameplay/KnifeMeshCheck` loads his meshes (`ContentProvider:PreloadAsync`) for every such knife in
  the Workspace and in the 3D knife on a card. Where one of his meshes fails (or no answer in 8 s), that screen asks
  for the cut's rows once a knife (remote `KnifeBackup`, `KnifeGlbService.backup`), builds it on that copy
  (`Shared/KnifeCut`: parts `KnifeBackup<n>` in a Folder, welded to his Handle, turned half round where his import
  is: Solar Reaper) and hides his parts; his meshes loading later remove it. A texture failing doesn't count. One
  `[HuzzKnife] <key>: his mesh rbxassetid://... didn't load here` line in Output (F9 in the live game).
  Parts (critic, Oct 20 evening: the first version carried the cut, hidden, in every copy): his 30 copies summed are
  710 parts now against 5,182 then (24 a copy on average instead of 173; Moonlit Knife's cut alone was 199), so about
  3,000 to 5,000 fewer replicated parts in a full game; the cut's parts exist only on a screen that needs them.
  Test: `tools/preview/smoke_knife_backup.luau` (20 checks: copies carry nothing extra, the server hands out all 30
  cuts and nothing else, each cut welded, no trail points of its own, same tip, bottom and width as his model, left
  out of the measured shape; the screen builds and removes it both ways, asks once a knife, keeps his parts when no
  cut can be had).
- **The 5 pass and 18 Halloween knives** are drawn as his model with EditableMesh (`Gameplay/KnifeDress`) only where
  Roblox allows it (live: Game Settings > Security > "Allow Mesh / Image APIs", which needs the owner 13+ and ID
  verified); everywhere else their stand-in shows, cut from his .glb (as before: EditableMesh is only the extra).
- **Knife pictures on cards** are drawn with EditableImage (the same setting); without it a card shows the knife's own
  3D model (`UI/ImageLoader` fallback, remote KnifeView), which now carries the backup too.
- **Folders only Rojo sends** (`HuzzKnifeGlb`, `HuzzKnifeBackups`) reach the published game only if they were in the
  place when he published: the place build (`build_yours.luau`) puts both in; his own Rojo place has them while
  Rojo is connected and keeps them once saved. `HuzzKnives` (his 30) is in the place build, not in Rojo.
- Owner's steps: `docs/STUDIO-STEPS.md` Part 6.

## Knife effects: the Huss Valley study (Oct 20)
Their skins, cropped to the knife: `docs/previews/knife-vfx-hv-reference.jpg` (`tools/preview/knife_vfx_reference.py`,
their recording f1c7bb86, the only HV round recording in the uploads: 32fe8d21 and 87565d66 aren't there; af1237a7
is their Halloween lobby, no skins close up).
| Their skin | What it does |
|---|---|
| MELON5MAN (cyan blade, gold halo guard, cyan gem), worn | 2 or 3 round cyan motes (~0.15 to 0.2 studs) drifting slowly (~0.5 stud/s) round the blade, in the gem's colour; the gem is Neon with a bloom |
| XxSanVetxX (cyan blades, cyan gems), worn | the same cyan motes, plus a small magenta glint near the edge |
| cxsh (purple and gold, pink gem), worn | a sparkle star in the pink gem and a soft purple haze under the blade |
| Mrsmagic (red and white wing blade, blue gem), worn | 2 or 3 soft blue electric wisps (~0.5 studs, a new shape each frame) round the blade's middle |
| Danilo (pink skin), in hand | a soft pink glow ~1 stud round the blade and a few sparkles; brighter in the swing, a small sparkle cluster |
What they don't do: no big arc on the knife, no spark shower, no flash, nothing far from the blade. The same
effects show worn on the back. So ours: the colour is the skin's gem (`Glow`, else the pass element's light, else
the blade), a handful of particles, each placed at the skin's detail (`KnifeFxGem` = his gem, else the guard; the
tip; the blade's box). Measured on MELON5MAN at 5.0 s: a mote is about 5% of the knife's length across (15 px of a
310 px knife), solid and saturated; the gem's orb with its bloom about 15% (45 px); 2 to 4 motes on show at once.
Themes (`KnifeLook.VFX.THEMES`, picked per knife in `VFX.OF` from its name and colours): Fire (embers rising off the
edge, small flames, heat haze: Ember Edge, Solar Reaper, Dragon's Maw), Ice (snow sinking, frost mist sinking: Frost
Fang, Frostbound Oath), Void (motes pulled in from a shell round the blade, a dark swirl: Shadow Knife, Void Fang,
Abyss Eclipse), Celestial (light motes rising, the halo's glow at the gem, a star at the tip: Spin Knife, Celestial
Seraph), Moon (pale wisps), Blood (red drips falling: Blood Moon Tanto), Sakura (petals drifting off sideways: Candy
Knife, Crimson Requiem), Storm (Mrsmagic's wisps, tiny sparks: Thunder Fang, Storm Kunai), Venom, Witch, Candy,
Pumpkin, Spirit (the Halloween knives).
Pictures (offline, our look-alikes of Roblox's built-in pictures): `docs/previews/knife-vfx-sheet.jpg` (8 knives,
in hand and on a stand), `docs/previews/knife-vfx-vs-hv.jpg` (MELON5MAN worn next to our Celestial Seraph worn),
`docs/previews/knife-vfx.mp4` (Dragon's Maw, Frostbound Oath, Abyss Eclipse slashing, 30 fps). Made with
`motion3d/knife_vfx_scene.luau` (the real KnifeService + KnifeFx, every emitter run) and `knife_vfx_sheet.py`.

## Owner how-to: SetupKnives (Studio, once)
1. File > Import 3D > `huzz-valley/design/knives/Knives/All_Knives.glb`, Import (and
   `design/knives/gamepass/Gamepass_Knives.glb` and `design/knives/halloween/Halloween_Knives.glb` the same way).
2. View > Command Bar, paste `require(game.ServerStorage.HuzzStudioTools.SetupKnives)()` (or the whole of
   `tools/knives/setup_knives.lua`), Enter.
3. Output says `[HuzzKnife] Done: 53 of 53 knives are in ServerStorage > HuzzKnives.` (a warning names any it
   couldn't find).
4. File > Save.
5. Right-click ServerStorage > HuzzKnives > Save to File, send `HuzzKnives.rbxm`; we put it in `assets/knives/` and
   `build_yours.luau` puts it in every build.
- Received Oct 18 (30 of 30; the 5 pass knives and the 18 Halloween knives need steps 1-5 again). His place still holds the broken 8 and
  uncoloured parts: importing Gamepass_Knives.glb and running step 2 once fixes them too (Output: "repaired: it was
  the wrong size or way round" x8, "fixed colours and glow" for the rest).
- SetupKnives matches "name + digits", refits by position (his shurikens, a star round one spot, by their blade
  part's own turn: the positions can't say which way is up), guesses from the box's long axis, and on a re-run
  repairs/recolours models already in HuzzKnives in place (`tests/SetupKnives.spec`: Studio-style names, both glbs,
  his real broken 8 in `tests/fixtures/HuzzKnives-oct18-first-run.rbxm`).
- **Oct 19: his file fixed offline** (`tools/knives/colour_knives.luau --write`): runs his own SetupKnives on the
  file as we received it (`assets/knives/HuzzKnives-received.rbxm`, the 8 already repaired) exactly as his re-run
  would and writes `assets/knives/HuzzKnives.rbxm`: 585 parts of 30 knives take their .glb colour and material
  (Metal on his metal), his 84 glowing SurfaceAppearances stay, Neon only on the 78 glowing parts without one;
  Crimson Tanto, Night Tanto and Twin Fang turned back a quarter, their flat had faced the wrong way; Twin Fang's grip
  back on its Handle. It drops the import's leftover colour pictures and checks every part against
  `tools/knives/knife_boxes.json` (each .glb part's box, colour, glow, metallic and roughness in the Handle's space,
  `knife_boxes.py`): worst 0.008 studs. `tools/knives/inspect_knives.luau` lists any file's knife parts.
- **Spec `tests/KnifeModels.spec`** (in `check.sh`): one look rule (KnifeLook, colour_knives, his SetupKnives through
  the file); his 30 are all his meshes, on their .glb spots, in their .glb colour and material, his 84 glows kept,
  attachments at the grip, guard and tip; every one of the 53 keys in hand, worn and on a stand has his mesh blade or
  a stand-in tagged for the dress with a baked blade (a plain block blade fails it), an even stand scale and nothing
  laid over it (no GlowShell, no sheen); the baked meshes decode inside Roblox's limits with his colours, materials
  and box, each module under 60 KB; the dress places, sizes, colours and hides, all or nothing; KnifeGlbService hands
  out one mesh and refuses odd keys and numbers.
- Picture `docs/previews/knives-glb-vs-ours.jpg` (`tools/preview/motion3d/knife_glb_scene.luau`, drawn from the game's
  own parts, materials approximated in three.js: his .glb's own metallic/roughness vs Roblox Metal / SmoothPlastic /
  Plastic / Neon / his glow at Look's EnvironmentSpecularScale): 5 of his knives as his .glb | before | now, the 5
  pass knives as his .glb | old stand-in | new stand-in | dressed, then Dragon's Maw on the back and Twin Fang in the
  hand.

## Stand sword showcase (`Shared/StandShowcase`, drawn by `Gameplay/AvatarStands`)
- A stand with a knife doesn't run; client only, only within NEAR 160. It holds a guard (the hand low in front of the
  right hip, the blade slanting up and out to the right, its tip under the sign; breathing and weight shift; R15 feet
  planted by leg IK) and every `CYCLE` 3.3 s plays one of its
  moves in turn. Each stand starts on its own move (its build number) at its own time (its spot). The twirl turns the
  knife in the fist via the weld's C0 (`grip`); R6 has no elbow, so shoulder and grip share the bend (simpler, still
  reads). Knife-less stands keep the run.
- **Size:** `KnifeService.display` scales the stand copy to `KnifeLook.STAND.Length` 4.4 studs (his models are 3.2,
  the old stand-in dagger 1.9) with `KnifeService.scale` (by hand: sizes, offsets, attachments, welds, meshes,
  lights). The hand scaler runs everywhere (check_lobby_boards also checks the size).
- **His shape, only bigger:** the stand copy is scaled the same every way (`KnifeService.scale` still takes a
  Vector3 in the Handle's axes). The round 2 widening (`KnifeLook.standWiden`, up to 2x) and the see-through Neon
  `GlowShell` over the blade are gone (owner, Oct 19: "they dont look as good as in the glb file": both hid his
  model).
- **Trail:** a `StandSlash` Trail from `StandTrailBase` (45% up the blade, added by display) to TrailTip, on only in
  the cuts, `TRAIL_LIFETIME` 0.2 s in the element's colours (Sunrise gold, never white), tapered. The copy carries
  its stand effects (`KnifeFx` "stand", above; no `KnifeBurst`, so a move throws no sparks); its own Neon parts
  still glow. `tools/preview/check_lobby_boards` checks the stand knife by the owner's newer rule (07:43 "make them
  better for more high end ones" over 03:01's "make them be normal" for the high-end knives): effects by tier, one
  light at most, the glint on its timer, no spark bursts.
- **Elements** (`KnifeLook.ELEMENTS`): their emitters off since Oct 20 ("just make them be normal"); each pass
  knife keeps its trail colours from it, and its effects now come from `KnifeLook.VFX` (Effects above). (They were: Hunter red petals + twinkles, Moonlit moon glint + violet
  wisps, Sunrise gold feathers, Inferno flames + embers, Frost shards + snowflakes + mist, a stand light and a tip
  glint; `KnifeLook.elementRate` stays for the old films.)
- **The aura, no disc** (Oct 19 evening, owner: "make the gamepass characters look better without that green circle
  on the bottom, and add some vfx, make the characters more atrractive so people buy the knifes"): the green Neon
  disc under the feet is gone (no base: the copy stands on the floor where his block was). `KnifeLook.AURA`, built by
  `Gameplay/AvatarStands` in the knife's element colour (else the pass colour): soft specks rising from a ring round
  the feet (`AuraMotes`, Glow, 7/s, on the invisible `StandAura`), a few stars twinkling round the body
  (`AuraTwinkles`, 2.5/s, in the invisible `StandAuraBody` column) and a soft light 2.2 studs in front of the chest
  (`StandAuraLight` on the copy's root, brightness 0.7, range 7, its colour 45% white so faces keep their colour).
  Under 10 particles a second, each fades over a second or more, nothing flashes. Pose: the guard's free arm now hangs
  loose at the side (it was raised in a fist, stiff; `StandShowcase` READY off). Before/after in his framing:
  `docs/previews/pass-stands-before-after.jpg` (his screenshot | ours before | now with his model | now with the switch
  off; `tools/preview/pass_stands_sheet.py` over `stand_knives_scene.luau` `STAND_SET=pass2`, `STAND_LOOK=old` for the
  disc), film `docs/previews/pass-stands-aura.mp4`. `check_lobby_boards` checks no disc, invisible holders, the
  knife's colour, under 10 a second and the light; nothing on the knife itself (Oct 20). The aura's pictures are
  Roblox's own built-in sparkle until he uploads `assets/fx` (`Shared/FxTexture` falls back, never a blank square).
- **Moves:** each knife has a `STYLES` entry (hold + 3 moves): Inferno = Low hold, Whirl (a full-body spin into a
  lunging slash), Scrape (the reference cleaver's ground sweep: a crouch with the blade back low on the right, then
  one big arc low across the front), Cleave (overhead and one big arc down); Moonlit = Low, Cleave, Scrape, Whirl;
  Hunter = Low, Bloom (arm high, a spin, a burst of petals, an arm-out slash), Flick, Combo (forehand sweep, backhand
  return, wrist twirl); Sunrise = Guard, Flick (two wrist flicks and a twirl), Flourish (overhead twirl, diagonal
  cut), Bloom; Frost = Guard, Whirl, Rising (crouch, rising cut, twirl), Flick. The Low hold hangs the big blade down
  and out to the right side, in front of the body.
- **Face out at rest:** each hold has a `twist` (the knife's turn about its own blade, after the grip: Guard -52, Low
  80, measured on R15 and R6), so at rest the blade's broad face looks out of the stand instead of its edge; in a move
  the twist eases back to 0 (the edge leads the cut) and returns with the hold (`StandShowcase.knifeTurn` builds the
  weld's turn for AvatarStands, the spec and the renders; the spec checks the width axis is across the view and the
  face looks out). A spin turns the whole body (`spin`; the feet turn with it). A move's `burst` would throw the knife's
  KnifeBurst once (AvatarStands), but stand copies carry none since this pass.
- Spec `tests/StandShowcase.spec` (at ready the blade slants up and out to the right in front of the torso, tip under
  the sign; a move every loop, no pops at 30/60 fps, back to ready, feet planted) runs every style on R15 and R6 at the
  big size. Video `docs/previews/stand-showcase.mp4`
  (`tools/preview/motion3d/stand_scene.luau`, mock rigs, his meshes). Side by side at 30 fps:
  `docs/previews/stand-knives-vs-ref.mp4` + still sheet `.jpg` (`tools/preview/stand_knives_vs_ref.sh` over
  `motion3d/stand_knives_scene.luau`: top his reference, bottom ours, same row and framing, his meshes;
  `KNIFE_MODE=standin` draws the plain-part stand-ins).
- **Still worse than the reference** (after the knife check): the reference's cleaver hangs nearly straight down by
  the leg with a fire cloud round it, bigger than our flames (ours sticks out diagonally to the side, so its tip clears
  the floor at 4.4 studs); the Sunrise blade renders as plain white (his card's silver and blue
  line don't show); in the Flick and Flourish the Sunrise blade still passes up through its sign for a moment; our
  signs aren't in the render (only their words).
  One picture: `docs/previews/knife-check-vs-ref.jpg` (reference at rest; before and after with his meshes and with the
  stand-ins; the long knife in hand; `tools/preview/knife_check_sheet.py`). Older still:
  `docs/previews/stand-knives-rest-vs-ref.jpg` (round 3).

## Halloween knives (`design/knives/halloween/Halloween_Knives.glb`, Oct 19)
- Owner: his 18 Halloween knives, "make it one to one". Coin-shop knives like his 30 (`Config/CoinShop` Order
  140-157, `Set` = Pumpkin / Witch / Candy: his file's three rows of 6), each set rising Common to Mythic in his
  order (dagger or shuriken first, the katana, reaper or scythe last) on the same price ladder (200 to 8,000). Sold
  all year: no timer, no "limited". The admin GIVE list shows them (it lists every Knife-slot item).
  | Pumpkin | Vine Dagger, Harvest Sickle, Gourd Cleaver, Thorn Karambit, Pumpkin King Katana, Jack's Reaper |
  | Witch | Hex Shuriken, Potion Dagger, Toadstool Sickle, Moonlit Cleaver, Coven Katana, Grand Witch Scythe |
  | Candy | Gumdrop Dagger, Peppermint Shuriken, Taffy Karambit, Cupcake Cleaver, Sugar Rush Katana, Candy Reaper |
- Same pipeline as the pass knives: `bake_knives.py` (keys from his node names, `Jack_s_Reaper` = JacksReaper),
  card pictures from his meshes (`ONLY=halloween` for `render_cards.mjs` / `compose_cards.py`), stand-ins cut from his
  file, his model on screen via KnifeDress until his import, SetupKnives knows them (owner how-to step 1); its
  summary went from `[HuzzKnife] Done: 35 of 35 knives are in ServerStorage > HuzzKnives.` to 53 of 53).
- Sizes: the 30's length rule (2.4-3.3 studs), but never blown up more than his 30 are for their size (6.07 studs a
  .glb unit): the shurikens stay about 1.2 studs, the karambits 1.7, as small next to a dagger as in his file.
  Pommel to the very top (Cupcake Cleaver's cherry and Gourd Cleaver's stem stand above the blade's tip). His
  sickles, karambits and shurikens are wider than a knife: `Wide` (width / length, baked) lets `KnifeLook.sane` accept
  them (limit `max(0.6, Wide x 1.15)`); his import carries it as the model's `Wide` attribute.
- Picture `docs/previews/halloween-knives.jpg`: each as his .glb | stand-in | his model on screen, their card
  pictures, three worn and three held (`KNIFE_SET=halloween` on `knife_glb_scene.luau`).
- Gaps: no "HALLOWEEN" heading in the shop (they sit together by Order, after the pass knives); the reapers and the
  scythe are held like every knife (blade down at the side, the blade near the floor) and worn on the back/hip by
  length (Oct 19 evening: the reapers and scythe on the back head up, the rest at the hip); a shuriken in the hand
  is small; the stand showcase is the pass knives' only.

## Honest gaps
- Live knives (Oct 20 15:13): which of his 680 meshes load live, and whether the swap to the cut looks right on a
  real screen, only the live game shows; checked offline with a stub for Roblox's loader. The cut is flat slabs
  (his model is rounder) and leaves out Abyss Eclipse's thin hanging chain. No picture of the 30 cuts yet. Building a
  cut (up to 199 parts) happens on the screen at the moment a mesh fails: a short hitch is possible on a slow phone.
- Knife effects (Oct 20): only seen offline, drawn with our look-alikes of Roblox's built-in particle pictures; how
  smoke_main and sparkles_main really read, the PointLight, the Neon glow ball under the bloom and the size of a
  mote only Studio shows. Third pass (crisp Neon ball motes, a solid gem ball): the film and the stands now read
  like Huss Valley's crisp coloured dots. In the worn side by side (`docs/previews/knife-vfx-vs-hv.jpg`) ours is
  still a step behind: the offline picture draws Neon flat with no bloom halo, so the Seraph's gem ball is a flat
  cyan disc (now in the ring's middle: the stand-in's gem is two halves, `Part151` and `Part152`) and only one
  ball lands in that crop at that moment (theirs two or three). The swing film `docs/previews/knife-vfx.mp4` was
  made before the timed glint, the hand light's move and the 0.2 stud mote cap. Whether
  Roblox's bloom gives the ball and the motes their soft halo only Studio shows. The 3D crate reveal
  (`UI/Crate3D`) is a ViewportFrame, which draws no particles, so it shows no knife effects (its backlight already
  takes the colour).
- Not seen in Studio yet: knife positions, the owner's knives (meshes after his import, the leap and dive), the knife
  showcase (the big stand knives, the spins, the card motes/pulse, the slash arc), the long blades' forward grip and
  its ease back in a stab. The 5 pass and 18 Halloween models still need his import (`Gamepass_Knives.glb`,
  `Halloween_Knives.glb` + SetupKnives) to be exactly his everywhere. Until then each screen dresses the stand-ins as
  his .glb with EditableMesh (`Gameplay/KnifeDress`), which needs the "Allow Mesh / Image APIs" switch: his Oct 20
  screenshots still show the stand-ins, so on his screen it isn't running (his `[HuzzKnife]` Output line says why;
  we haven't seen it). Checked offline (`tools/knives/mesh_audit.py`): none of his meshes is wound inside out (rings
  and chains only look so to the centre test; open edges are where two looks meet), so one-sided triangles are not
  why; no back faces added. The solid stand-ins (Oct 20) are not his model: flat seen edge on, rounded parts as
  slabs, small details smoothed (the Seraph's halo a little many-sided, the bandage wraps and chain links simplified),
  Neon and Metal approximated offline; they are only checked offline, not in Studio. How Metal, his SurfaceAppearance
  glow and the 0.4 specular really look only Studio shows; the pass knives' glow is Neon. The offline picture draws
  his imported knives' parts with the .glb part each came from (his uploaded meshes themselves only Studio shows). A
  refunded pass keeps its knives. The in-hand check uses the pack's Idle/Walk/Run on a blocky R15; a player's own
  avatar animations or a short R6 arm can still bring a long tip nearer the floor.
- **The owner's "floating black block"** (Oct 19 evening `design/owner-oct19/2010-floating-block.png`; Oct 20 14:07
  "please remove that black thing that is attacthed to my character": `design/owner-oct20/1407-black-block-character.png`
  is the same file byte for byte, `1407-black-block-ground.png` is new): the cause is still not proven, so since Oct 20
  it is made impossible instead. Each screen's `Gameplay/KnifeGuard` hides a worn knife whose grip is more than
  `KnifeLook.STRAY` (1.5) studs from where its weld holds it, or outside the body part it hangs from. It also hides a
  piece that is 1.5 studs farther from the grip than it was made (the server's `Reach` attribute). It prints one
  `[HuzzKnife] hid ...` line naming the part, and the part shows again once it is back in place. Not "every part
  within 1 stud of the body": a sickle's or shuriken's blade rightly reaches 2.2 studs out, and a shuriken's grip sits
  0.9 out. `tests/KnifeWear.spec` checks two things. No worn knife (53 plus the default) is hidden on blocky, slim,
  big, wide (1.6 across) or R6 bodies. The default knife's grip moved to the block's spot hides the knife, and one
  loose piece hides only that piece. What is measured:
  - A plain box, about 3:1, a visible top face, colour (21, 27, 54) lit, (10, 12, 29) in shade, bluer than his black
    hoodie (8, 11, 19) beside it.
  - In the ground picture it casts **no shadow** while his lantern next to it casts a long one: almost every part the
    game makes has shadows off, his own avatar's and his place's parts have them on. So it is most likely ours.
  - He wears the default knife (0 coins, the Mock save), and in the Oct 19 picture no grip or steel blade shows at his
    right hip. The default knife's dark grip (`KnifeService` `build()`: 0.22 x 0.75 x 0.26, colour (32, 30, 38), shadow
    off) fits the box's shape and colour under the lobby's blue light. But its four steel pieces (pommel, guard,
    blade, tip) aren't in either picture.
  - On a blocky R15 the default knife sits right: the grip at (1.18, -0.10, 0.82) in the LowerTorso, just behind the
    right hip, all four steel pieces welded on (`tests/KnifeWear.spec`). So if it is the grip, what moves it is
    something only Studio does (his avatar is built on AnimationConstraints and AccessoryRigidConstraints, like his
    girls: `Shared/GirlRig`), not the placement numbers.
  - Ruled out: the Midnight cape (0.08 thin with a purple lining, and nobody can have it yet), the knife dress pieces
    (fixed Oct 20, `312e64b`), his imported knife folders (`Workspace > Halloween knives / Gamepass knifes`: loose
    and collidable, but 100+ studs below the lobby), and every other dark part in his place.
  - The Studio finder `tools/studio/find-floating-parts.lua` printed nothing on Oct 20 because it read `Part0` on
    every joint. His hair and hats are held by AccessoryRigidConstraints, which have no `Part0`, so it stopped at the
    first hat. Fixed: it reads a constraint's two Attachments, each line is tried on its own, and each line now says
    `shadow OFF` for the game's parts (`tests/FindFloating.spec`, which fails on the old finder). One run in Play
    (`docs/STUDIO-STEPS.md` Part 4) names the block, its size and what holds it (now the last resort: the
    `[HuzzKnife] hid` line names it too).
  - Second pass (Oct 20) checked his place's knives part by part. A fresh Mock save wears our `build()` dagger, because
    his `HuzzKnives` has no `HuzzKnife`. His 30 models are 680 MeshParts with a Handle at Transparency 1 and no plain
    visible part, so a mesh that fails to load leaves nothing, not a box. When the EditableMesh dress fails on a pass
    or Halloween knife, the whole plain stand-in shows, with its Handle hidden. Only the default dagger has a visible
    plain grip. On odd bodies the grip sits off its torso by the same amount, because it is fixed by the C0 and doesn't
    depend on size. So what moves it in his Studio is still unknown.
- Oct 19 evening (aura): only offline so far. The aura uses Roblox's sparkle picture until he uploads `assets/fx`
  (Glow, Twinkle), so in Studio the rising specks are small 4-point sparkles, not soft dots; how bright the aura light
  reads under his lobby light only Studio shows. The long scythes and reapers are still held like a knife (blade low
  by the leg). The aura is calmer than the reference stands' fire clouds on purpose ("dont make it overly crazy").

## Why it is this way / history
- **Skins** (owner, Oct 18: "add some vfx to the knifes, but make it fit it, and dont make it overly crazy").
- **Worn on the back** (owner Oct 18: "be shown on the back of the character"; the old belt mount was too low to notice).
- **Back or side by knife** (owner Oct 18: "for the katanas ... on the side" put long slim blades at the left hip;
  Oct 19: "make the location based on what knife/sword it is", "This is very important"): now long blades go on the
  back like a sheathed sword and short knives at the hip, one table row per knife so he can move any of them.
- **The broken 8:** 8 of his Oct 18 file came out of the setup ~12x too big and sideways, fixed offline by
  `tools/knives/repair_knives.luau`. Cause: Studio renames repeated part names across an import (2nd knife's
  `blade_0` = `blade_02`, 5th's `blade_05`, its 2nd part `blade_052`), the setup matched exact names only, and its box
  guess assumed upright while All_Knives.glb lies flat; renamed parts on all 30 also missed their colour and Neon.
  Hence today's SetupKnives matching.
- **Game Pass knives** (owner Oct 18: "these are going to be the gamepasses users can buy"). VIP and Dance Pack used
  to give a knife; not any more.
- **Live cards** (owner Oct 19: "better knife animations ... in the gamepass sections").
- **Stand showcase** (owner, Oct 18: "showcase the swords that the gamepass includes ... the swinging animation, make
  it look good though"): first a guard plus three moves (Combo, Flourish, Rising) for every stand.
- **Oct 19, big and in his reference's style** (owner: "right now its very small and you dont even notice it ... make
  the knife animations look like the ones i have attached in the video, but make the text different, not ui";
  `design/lobby-ref/oct19-stands-ref.mp4`: PUMPKIN CLEAVER, VIP DAGGER, VOWBREAKER; we copied the motion and effects,
  never its sign words, LIMITED or ENDS IN timers). Round 1 made it 4.4 studs. An earlier `Model:ScaleTo` try broke 3
  lobby checks because the Lune harness has no ScaleTo, so the stand's mount failed; hence the hand scaler.
- Round 2 ("in the reference the knife is the first thing you see"): the widening (toward `STAND.Width` 1.7 studs,
  `MaxWiden` / `MaxThick` 2x) and glow shell (`STAND.Shell` 0.4 see-through; both removed Oct 19, below), the Scrape move,
  `TRAIL_LIFETIME` 0.2. Round 3: the face-out twist.
- **Knife check, Oct 19** (owner: "Can you check the knifes over and over again to make sure it's the best it can
  be"): every blade on a stand had become a paddle about twice as long as wide (the widening went up to 4.5x), so the
  Sunrise longsword read as a white slab and the Hunter katana stand-in as a pink brick, unlike his cards: now at most
  2x and never squatter than 3 to 1. The upright guard put the 4.4 stud blade 2.6 studs over the head, through the
  sign, seen end-on: now it slants up and out to the side. Long knives went into the floor in a catcher's hand: now
  held more forward (back to 150 in the cut). Also: the pass stand-ins worn on the body are checked, and an owned pass
  knife's shop card has its EXCLUSIVE colour.
- **"The knifes dont even have their shapes", Oct 19** (owner, after testing: "they all dont look good, please fix
  them and use the glb file to get them one to one, whenever you wear or use them" / "all of the knifes"; his
  screenshot: a dark plank on the back with smoky orange bits). Cause: a Game Pass knife (most likely Dragon's Maw:
  the fire element's stand-in pictures are the smoke) worn as its plain-part stand-in, which is a box by design until
  his import; and his 30 were never finished by SetupKnives' colour step (most parts default grey plastic or the
  import's own picture, glow parts not glowing) with three turned a quarter so their flat faced the wrong way. Fixed
  as above: his file finished offline, the pass knives dressed as his .glb on each screen.
- **"They dont look as good as in the glb file", Oct 19** (owner, of his 30 in Studio). Cause: our colour step had
  removed his import's 84 glowing SurfaceAppearances (Neon went from 78 to 162 parts) and made every other part
  SmoothPlastic, so his metal looked flat, under a 0.2 EnvironmentSpecularScale; the stand widening, the GlowShell and
  the sheen glint covered his model too. Fixed as above (his glow back, materials from his .glb, specular 0.4,
  nothing laid over it). The same day his Studio screenshot of the stands showed the pass knives' hand-made
  stand-ins: now cut from his .glb.
- **Oct 19 evening** (owner, 17:41: "can you make the knife models more detailed because there are alot of details
  missing, please then make the gamepass characters look better without that green circle on the bottom, and add
  some vfx, make the characters more atrractive so people buy the knifes, and make the knifes more advanced"; his
  screenshots `design/owner-oct19/1840-*.png`). The missing details were the plain stand-ins: Rojo never sent
  `HuzzKnifeGlb` (fixed d6db14f), checked one to one after; the red pop-up and the dress's own on-screen line went
  (Output only); the effects went one calm step up; the disc became the aura and the guard's free arm relaxes.

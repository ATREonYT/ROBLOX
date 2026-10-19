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
- `KnifeService` takes `ServerStorage/HuzzKnives/<Key>` when there, else the built-in knife tinted in the skin's colours.
  Hand by the model's `Grip`.
- **Effects** `KnifeLook.LADDER` (Oct 19 evening, one calm step up: "make the knifes more advanced"): every skin's
  slash trail in its own colour (`KnifeLook.trailLook`; Common and Uncommon faint, `trailSoft`; only the default
  knife keeps the faint white one), Uncommon + a faint light (0.35, range 2), Rare soft light + 1.5 sparkles a
  second, Epic 3 sparkles + the slash arc (`arc`: the knife's `SlashColor`, as before Epic and up), Legendary light
  Range 4 + effects on the back + a star glint at the tip in hand (`glint`: one about every 3 s, grows and fades over
  half a second), Mythic + embers. Nothing laid over his model (Uncommon's old white sheen glint stays gone). The
  particles come off the whole blade: a knife of 3+ blade blocks (the stand-ins) gets an invisible `KnifeFxArea`
  over them (`KnifeService` fxPartOf; before, a stand-in's fire or petals left its one biggest slice). Stand-in
  particle textures until uploads. Film `docs/previews/knife-fx-ladder.mp4` + `.jpg` (one of his knives a rarity,
  slashing; `motion3d/knife_fx_scene.luau`); older `docs/previews/knives-vs-hv.jpg`, `knife-leap.mp4`.
- **His look, one to one** (`KnifeLook.glbMaterial`, the one rule for all of them): every part takes the Roblox
  material nearest his .glb's metallic and roughness (his blades and guards metallic 0.6 to 0.9, roughness 0.2 to
  0.3; grips metallic 0, roughness 0.8): glowing = Neon, metallic 0.5+ = Metal (Reflectance 0.12 when roughness is
  0.35 or less, else 0.04), roughness 0.7+ = Plastic, else SmoothPlastic. His own import's glow stays where he has
  it: 84 SurfaceAppearances (his colour picture + emissive mask, EmissiveStrength 0.9) on 15 knives, a softer real
  glow than Neon; Neon only on glowing parts without one (78 parts). `Config/Look` EnvironmentSpecularScale went
  0.2 to 0.4 so Metal mirrors the sky at all (0.2 was the Oct 19 matte lighting match: set it back if the plaza
  looks glossy). Nothing is laid over his model: no widening, no glow shell, no sheen (only particles, light and
  the trail, calm).

## The worn knife
- `KnifeLook.pick` = the shop's pick, else your first owned knife, else the default knife; diagonal across the back
  (handle over the right shoulder), or at the left hip like a sheathed sword for long slim blades (`KnifeLook.wearOf`:
  a `Wear` attribute/field "Back"/"Side", else measured from the model: 3+ studs and blade 5.5x longer than wide; of
  the 30 only Celestial Edge; the Game Pass katanas get sorted the same way).
- Server-built, one per body: `give` (hand) and `giveBack` (worn) each remove the other; RoundService syncs on every
  change, spawn and avatar reload; a shop change swaps it at once (Bootstrap).
- A model the wrong size is refused (plain knife + one `[HuzzKnife]` warning).
- Spec `tests/KnifeWear.spec` (all 30 and the 5 pass stand-ins on R15/R6, no clipping except the hanging hand on the
  hip hilt); picture `docs/previews/knife-on-back.jpg` (`motion3d/knife_wear_scene.luau`).

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
- **Shop > PASSES** opens on 5 cards one-to-one with his mockup (`design/knives/Five_Elemental_Knife_Cards.png`,
  scaled 0.2993 to 120 x 214 so a whole card fits; art cut by `tools/icons/cut_pass_knife_cards.py` into
  `assets/art/pass-knife-*.png`, 240 px, Play only until uploaded), the VIP and Dance Pack banners under them;
  BUY + Robux mark, "coming soon" and never a prompt while `Id = 0`, Price 0 = not set (the live price shows once
  there's an ID). Side by side `docs/previews/knife-cards-vs-mockup.jpg` (`shots.sh shop-knife-cards` +
  `side_by_side.py knife-cards`). The card names use Gotham (the owner's font rule), wider than his mockup's
  rounded font.
- **The cards are alive:** animated card art, not a 3D viewport (his pass models aren't in his place yet and the art
  already is the knife): each card's element colour swells softly over the picture (`Effects.pulse`, about every 5 s,
  never under 0.78 see-through), 7 small shapes of its element float up over it (`Effects.motes`: petals for Hunter
  and Sunrise, dots for Moonlit and Inferno, diamonds for Frost; plain frames, no upload), the white shine, and the
  card lifts to 104% under the mouse (`Effects.lift`). All saved twins, hidden until their loop runs, stopped by
  Reduced Motion. Still `docs/previews/knife-cards-alive.jpg` (the motes are small and calm; the pulse shows only in motion).
- **Stand-ins until his import** (`Shared/KnifeShapes`, data `Shared/KnifeStandIns` = the list, one module a knife in
  `Shared/KnifeStandInParts`, 4-13 KB each, baked by `tools/knives/bake_stand_ins.py`): plain blocks cut from his own
  `Gamepass_Knives.glb` and `Halloween_Knives.glb` (owner's Oct 19 screenshot:
  the first hand-made ones, "an orange blocky jagged blade" and "a small cyan stub", were nothing like his model):
  his knife in 0.04 stud slices, one block per stretch of each of his looks (colour, glow, material), joined up the
  blade while it barely changes, a smaller look a hair proud of a bigger one under it; 52 to 177 blocks a knife, his
  colours and `glbMaterial`, his length; the tassel blocks are named Tassel so pommel to tip stays his. Spec
  `tests/KnifeShapes.spec` (lengths, his .glb's box within 0.06 studs, his colours only, at most 200 parts, scaler,
  stand size, even scale and no shell, elements, budget, arc). They are the server's knife (length, grip, trail
  points, particles) and the fallback on any screen that can't draw his model; each screen dresses them as his .glb
  (next). The round 1 hand-made ones: `docs/previews/stand-knives-standins.jpg`.
- **His .glb on every screen until his import** (`Gameplay/KnifeDress`, data `ServerStorage/HuzzKnifeGlb/<Key>_<n>`,
  handed out by `HuzzServer/KnifeGlbService`): the server tags a pass or Halloween stand-in `GlbKnife` (attribute
  `Glb` = its key, `KnifeService.template`); the first time a screen shows a knife it asks the server for that knife's
  meshes one at a time (remote `KnifeGlb`: `(key, n)` -> mesh, nil when no more, false = "ask again later" past 900
  asks a minute; key and n checked), so nobody downloads all 3.3 MB of the 23 knives at join (Oct 19, with the
  Halloween knives; before that the 5 lived in Shared/KnifeGlb and every player got them). Each client builds his
  model as it is (every triangle, 1,662 to 19,156 a knife, 3 to 14 looks: one MeshPart per colour,
  glow and material, each in its `mat` / `refl` from `glbMaterial`) with `AssetService:CreateEditableMesh` (not
  FixedSize: that refuses AddVertex) + `CreateMeshPartAsync(Content.fromObject(mesh))`, welds it to the Handle sized
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
  the cuts, `TRAIL_LIFETIME` 0.2 s in the element's colours (Sunrise gold, never white), tapered. The steady rarity
  glow is the display knife's own.
- **Elements** (`KnifeLook.ELEMENTS`, in place of Mythic's sparkles and embers; stand rate, about a third in hand, a
  sixth on the back, `KnifeLook.elementRate`): Hunter red petals (10/s, 0.55) + twinkles, Moonlit moon glint at the tip
  + violet wisps (6/s), Sunrise gold feathers + twinkles, Inferno flames along the blade (24/s, size 1.3) + rising
  embers, Frost ice shards + snowflakes + a faint mist (stand only); on a stand also a soft light (0.6, range 4: the
  Oct 19 lighting keeps glow on the object, so Neon and particles carry it) and a star glint at the tip about every
  2.5 s.
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
  knife's colour, under 10 a second and the light. At most 32 particles a second per stand knife (Inferno 31), nothing
  flashes. Until he uploads `assets/fx`, Studio shows Roblox's sparkle and fire pictures instead.
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
  face looks out). A spin turns the whole body (`spin`; the feet turn with it). A move's `burst` throws the knife's
  KnifeBurst once (AvatarStands).
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
  the same rule; a shuriken in the hand is small; the elements and stand showcase are the pass knives' only.

## Honest gaps
- Not seen in Studio yet: knife positions, the owner's knives (meshes after his import, glow, sparkles, the leap and
  dive), the knife showcase (the big stand knives, element particles with stand-in pictures, the spins, the card
  motes/pulse, the slash arc), the long blades' forward grip and its ease back in a stab. The 5 pass models still need
  his import (`Gamepass_Knives.glb` + SetupKnives) to be real everywhere; until then each screen dresses the stand-ins
  as his .glb with EditableMesh (`Gameplay/KnifeDress`): his first Studio Play (Oct 19) showed the plain stand-ins
  because Rojo never sent the meshes (fixed d6db14f); whether EditableMesh then runs needs the "Allow Mesh / Image
  APIs" switch (his `[HuzzKnife]` Output line says on or why not); the triangle facing (counter-clockwise assumed) and the look under Studio light are unproven;
  otherwise the stand-ins show, now cut from his .glb but still blocky (stepped edges on the curved katana, the
  feather guard as grey blocks, Dragon's Maw more orange than his). How Metal, his SurfaceAppearance glow and the
  0.4 specular really look only Studio shows (the offline picture approximates materials); the 5 pass knives' glow
  is Neon (no SurfaceAppearance pictures of his for them until his import). The offline picture draws his imported knives'
  parts with the .glb part each came from (his uploaded meshes themselves only Studio shows). A refunded pass keeps its knives. The in-hand check uses the pack's Idle/Walk/Run on a blocky R15; a
  player's own avatar animations or a short R6 arm can still bring a long tip nearer the floor.
- Oct 19 evening (effects step up, aura): only offline so far. The aura and the knife sparkles use Roblox's sparkle
  picture until he uploads `assets/fx` (Glow, Twinkle, StarFlare), so in Studio the rising specks are small 4-point
  sparkles, not soft dots; how bright the aura light reads under his lobby light only Studio shows (the film's light
  is an approximation). The stand-ins (switch off) stay blocky next to his .glb: stepped edges on curves, the
  Seraph's feather guard as blocks, the scythe's thin pole; the long scythes and reapers are still held like a knife
  (blade low by the leg). The aura is calmer than the reference stands' fire clouds on purpose ("dont make it overly
  crazy").

## Why it is this way / history
- **Skins** (owner, Oct 18: "add some vfx to the knifes, but make it fit it, and dont make it overly crazy").
- **Worn on the back** (owner Oct 18: "be shown on the back of the character"; the old belt mount was too low to notice).
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

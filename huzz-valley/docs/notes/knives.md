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
  `tools/knives/knives.json` + the setup script (35 rows with the pass knives).
- Card pictures from the real meshes: `knife_meshes.py` → `render_cards.mjs` → `compose_cards.py` →
  `assets/art/knife-*.png` (packed 192 px; they show in Play only, EditableImage); `docs/previews/knife-cards.jpg`.
- `KnifeService` takes `ServerStorage/HuzzKnives/<Key>` when there, else the built-in knife tinted in the skin's colours.
  Hand by the model's `Grip`.
- **Effects** `KnifeLook.LADDER`: Common none, Uncommon sheen, Rare soft light, Epic +3 sparkles a second and a tinted
  slash trail, Legendary light Range 4 + glow on the back, Mythic + embers (stand-in particle textures until
  uploads). Pictures `docs/previews/knives-vs-hv.jpg`, `knife-leap.mp4`.

## The worn knife
- `KnifeLook.pick` = the shop's pick, else your first owned knife, else the default knife; diagonal across the back
  (handle over the right shoulder), or at the left hip like a sheathed sword for long slim blades (`KnifeLook.wearOf`:
  a `Wear` attribute/field "Back"/"Side", else measured from the model: 3+ studs and blade 5.5x longer than wide; of
  the 30 only Celestial Edge; the Game Pass katanas get sorted the same way).
- Server-built, one per body: `give` (hand) and `giveBack` (worn) each remove the other; RoundService syncs on every
  change, spawn and avatar reload; a shop change swaps it at once (Bootstrap).
- A model the wrong size is refused (plain knife + one `[HuzzKnife]` warning).
- Spec `tests/KnifeWear.spec` (all 30 on R15/R6, no clipping except the hanging hand on the hip hilt); picture
  `docs/previews/knife-on-back.jpg` (`motion3d/knife_wear_scene.luau`).

## Game Pass knives (`design/knives/gamepass/Gamepass_Knives.glb`)
- 5 more, rarity **Exclusive** (Mythic's calm effects, pink-white card), Order 131-135, `Pass` in `Config/CoinShop`,
  Price 0, never sold for coins (BuyWithCoins says "That one comes with the <pass> Game Pass.").
- **Each is its own Game Pass** (`Config/Products` `Knife`/`Card`, his card names): Hunter Knife = Crimson Requiem,
  Moonlit Knife = Hollow Eclipse, Sunrise Knife = Celestial Seraph, Inferno Knife = Dragon's Maw, Frost Knife =
  Frostbound Oath (checked against the meshes: all five match). VIP and Dance Pack give no knife.
- `ShopService` grants them only when Roblox says you own the pass (`CoinShop.passGrants`), and wears one if your
  Knife slot is empty. Same pipeline (cards with a GAME PASS label). A refunded pass doesn't take them back yet.
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
- **Stand-ins until his import** (`Shared/KnifeShapes`): each pass knife's card shape from plain parts at its real
  length (katana, moon-hole cleaver, feather-guard longsword, jagged blade, crystal blade, glowing edges in Neon), so
  his place doesn't show our 1.9 stud dagger for them; still `docs/previews/stand-knives-standins.jpg` (the round 1
  picture, before the widening). Spec `tests/KnifeShapes.spec` (lengths, scaler, stand size, width and glow shell,
  elements, budget, arc).

## Owner how-to: SetupKnives (Studio, once)
1. File > Import 3D > `huzz-valley/design/knives/Knives/All_Knives.glb`, Import (and
   `design/knives/gamepass/Gamepass_Knives.glb` the same way).
2. View > Command Bar, paste `require(game.ServerStorage.HuzzStudioTools.SetupKnives)()` (or the whole of
   `tools/knives/setup_knives.lua`), Enter.
3. Output says `[HuzzKnife] Done: 35 of 35 knives are in ServerStorage > HuzzKnives.` (a warning names any it
   couldn't find).
4. File > Save.
5. Right-click ServerStorage > HuzzKnives > Save to File, send `HuzzKnives.rbxm`; we put it in `assets/knives/` and
   `build_yours.luau` puts it in every build.
- Received Oct 18 (30 of 30; the 5 pass knives need steps 1-5 again). His place still holds the broken 8 and
  uncoloured parts: importing Gamepass_Knives.glb and running step 2 once fixes them too (Output: "repaired: it was
  the wrong size or way round" x8, "fixed colours and glow" for the rest).
- SetupKnives matches "name + digits", refits by position, guesses from the box's long axis, and on a re-run
  repairs/recolours models already in HuzzKnives in place (`tests/SetupKnives.spec`: Studio-style names, both glbs,
  his real broken 8 in `tests/fixtures/HuzzKnives-oct18-first-run.rbxm`).

## Stand sword showcase (`Shared/StandShowcase`, drawn by `Gameplay/AvatarStands`)
- A stand with a knife doesn't run; client only, only within NEAR 160. It holds a guard (blade up, in front of the
  right shoulder, breathing and weight shift; R15 feet planted by leg IK) and every `CYCLE` 3.3 s plays one of its
  moves in turn. Each stand starts on its own move (its build number) at its own time (its spot). The twirl turns the
  knife in the fist via the weld's C0 (`grip`); R6 has no elbow, so shoulder and grip share the bend (simpler, still
  reads). Knife-less stands keep the run.
- **Size:** `KnifeService.display` scales the stand copy to `KnifeLook.STAND.Length` 4.4 studs (his models are 3.2,
  the old stand-in dagger 1.9) with `KnifeService.scale` (by hand: sizes, offsets, attachments, welds, meshes,
  lights). The hand scaler runs everywhere (check_lobby_boards also checks the size).
- **Broader than life:** display only, after the length scale `KnifeLook.standWiden` widens the blade to about
  `STAND.Width` 1.7 studs (at most `MaxWiden` 4.5x: his katanas ~3.5-4.5x, the big cleaver ~2x) and thickens it up to
  `MaxThick` 2.6x (`KnifeService.scale` takes a Vector3 in the Handle's axes: X thickness, Y length, Z width), then
  lays a `GlowShell` over every part with "blade" in its name: Neon in the element's light colour, `STAND.Shell` 0.4
  see-through, welded (a steady glow, nothing flashes).
- **Trail:** a `StandSlash` Trail from `StandTrailBase` (45% up the blade, added by display) to TrailTip, on only in
  the cuts, `TRAIL_LIFETIME` 0.2 s in the element's colours (Sunrise gold, never white), tapered. The steady rarity
  glow is the display knife's own.
- **Elements** (`KnifeLook.ELEMENTS`, in place of Mythic's sparkles and embers; stand rate, about a third in hand, a
  sixth on the back, `KnifeLook.elementRate`): Hunter red petals (10/s, 0.55) + twinkles, Moonlit moon glint at the tip
  + violet wisps (6/s), Sunrise gold feathers + twinkles, Inferno flames along the blade (24/s, size 1.3) + rising
  embers, Frost ice shards + snowflakes + a faint mist (stand only); on a stand also a soft light (0.6, range 4: the
  Oct 19 lighting keeps glow on the object, so Neon and particles carry it; the stand disc light is 0.4 / range 6) and
  a star glint at the tip about every 2.5 s. At most 32 particles a second per stand knife (Inferno 31), nothing
  flashes. Until he uploads `assets/fx`, Studio shows Roblox's sparkle and fire pictures instead.
- **Moves:** each knife has a `STYLES` entry (hold + 3 moves): Inferno = Low hold, Whirl (a full-body spin into a
  lunging slash), Scrape (the reference cleaver's ground sweep: a crouch with the blade back low on the right, then
  one big arc low across the front), Cleave (overhead and one big arc down); Moonlit = Low, Cleave, Scrape, Whirl;
  Hunter = Low, Bloom (arm high, a spin, a burst of petals, an arm-out slash), Flick, Combo (forehand sweep, backhand
  return, wrist twirl); Sunrise = Guard, Flick (two wrist flicks and a twirl), Flourish (overhead twirl, diagonal
  cut), Bloom; Frost = Guard, Whirl, Rising (crouch, rising cut, twirl), Flick. The Low hold hangs the big blade down
  and out to the right side, in front of the body.
- **Face out at rest:** each hold has a `twist` (the knife's turn about its own blade, after the grip: Guard -70, Low
  80, measured on R15 and R6), so at rest the blade's broad face looks out of the stand instead of its edge; in a move
  the twist eases back to 0 (the edge leads the cut) and returns with the hold (`StandShowcase.knifeTurn` builds the
  weld's turn for AvatarStands, the spec and the renders; the spec checks the width axis is across the view and the
  face looks out). A spin turns the whole body (`spin`; the feet turn with it). A move's `burst` throws the knife's
  KnifeBurst once (AvatarStands).
- Spec `tests/StandShowcase.spec` (blade in front of the torso at ready, a move every loop, no pops at 30/60 fps, back
  to ready, feet planted) runs every style on R15 and R6 at the big size. Video `docs/previews/stand-showcase.mp4`
  (`tools/preview/motion3d/stand_scene.luau`, mock rigs, his meshes). Side by side at 30 fps:
  `docs/previews/stand-knives-vs-ref.mp4` + still sheet `.jpg` (`tools/preview/stand_knives_vs_ref.sh` over
  `motion3d/stand_knives_scene.luau`: top his reference, bottom ours, same row and framing, his meshes;
  `KNIFE_MODE=standin` draws the plain-part stand-ins).
- **Still worse than the reference** (after round 3): the reference's cleaver hangs nearly straight down by the leg
  with a fire cloud round it, bigger than our flames (ours sticks out diagonally to the side, so its tip clears the
  floor at 4.4 studs); the resting Sunrise blade stays in the frame but touches its sign; our signs aren't in the
  render. Still `docs/previews/stand-knives-rest-vs-ref.jpg` (rest pose next to the reference). The render has no
  bloom, so Studio's Neon shell will glow more.

## Honest gaps
- Not seen in Studio yet: knife positions, the owner's knives (meshes after his import, glow, sparkles, the leap and
  dive), the knife showcase (the big stand knives, element particles with stand-in pictures, the spins, the card
  motes/pulse, the slash arc). The 5 pass models still need his import (`Gamepass_Knives.glb` + SetupKnives); until
  then the stand-ins show. A refunded pass keeps its knives.

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
- Round 2 ("in the reference the knife is the first thing you see"): the widening and glow shell, the Scrape move,
  `TRAIL_LIFETIME` 0.2. Round 3: the face-out twist.

# Huzz Valley: project memory

A Roblox game based on Huss Valley: rounds where players steal and hold the lead, plus collectible anime companions ranked in tiers (Sub1, Sub3, Sub5, MTB, HTB, Stacy, True Eve), dances, quests and cosmetics. Work on the branch the session names (`HUZZ-VALLEY` so far).

The UI golden slice and its backend are built (saving, coins and gems, shop purchases, settings), and so is the core round loop with the overhead girl carry (see Gameplay).

## Design authority
- The design kit is in `design/`:
  - `approved-original.png` is the approved look;
  - `pages/01-18` are the page references and `annotated/` the numbered positions;
  - `specifications/PAGE-POSITIONS.md` has the target rectangles;
  - `IMPLEMENTATION-PROMPT.md` has the full rules;
  - `CHARACTER-REPLACEMENT-MAP.md` has the model slots.
- Read only the page you're building.
- **Colours:** purple header with faint square studs (one tiled texture per strip: `assets/icons/stud-tile.png` from `tools/icons/make_stud_tile.py`; the owner asked for a texture instead of one part per stud); peach selected tab, navy inactive; periwinkle actions (never green); slate for done or disabled; small red close square.
- **Fonts (the owner's table; don't change them):**
  - window headings: Montserrat Black (Heavy) in caps with a thin dark outline;
  - names and product titles: Montserrat Bold, no outline;
  - tabs: Roboto Condensed Bold, in caps;
  - buttons: Roboto Condensed Bold with a minimal outline;
  - descriptions: Roboto Condensed Regular;
  - prices, currencies and XP: Montserrat Bold;
  - search fields and small labels: Montserrat Medium.
  - All of these live in `UI/Theme.lua` as `Theme.Fonts`.
- **Every colour and size is measured** from the references (the critic report's numbers are in `UI/Theme.lua`). Every main window is 701 x 320 (the owner asked for one size), so Settings no longer resizes per tab.
- **Robux prices:** every Robux price wears the Robux badge: U+E002, Roblox's own Robux mark, in dark navy before the number. Never use the kit's mockup hexagon (not official).

## Code map (`src/`, Rojo)
- `ReplicatedStorage/Shared`:
  - `Net` (every remote);
  - `Format`;
  - `Config/Products` (shop items: Id 0 = not created; `OnSale = false` = shows SOON);
  - `Config/Settings` (defaults and validation);
  - `Config/Assets` (icon IDs; empty until imported).
- `ServerScriptService/HuzzServer`:
  - `Bootstrap` (also makes the Master/Music/Effects SoundGroups);
  - `DataService` (ProfileStore; all changes go through `update()`);
  - `ShopService` (receipts and passes);
  - `SettingsService` (`allows()` answers social permissions, so any inventory or invite feature must call it);
  - `CosmeticsService` (trail and aura on the character).
- `StarterPlayerScripts/HuzzClient`:
  - `Main` (starts everything; applies audio, reduced motion, menu key and the VIP chat tag);
  - `UI/Kit` (the only component set: window, tabs, button, pill, segmented, slider);
  - `UI/ModalManager` (one window at a time; the player's `MenuOpen` attribute tells gameplay to ignore menu clicks);
  - `UI/Screens/*`.
- `StarterGui/HuzzUI.rbxm`: the whole UI as real parts the owner edits in Studio. It is **generated**: `build_place.sh` builds the UI from the scripts and saves it there. Never edit it by hand.
- **Sizes are reference px** (as measured on the 768-wide pages). `UI/Scale.lua` applies one UIScale per window, about 1.82x at 1920x1080.

## Checks and previews (run before every commit)
- Put Lune on PATH: `/root/bin/lune`, or download 0.10.5 to `/root/bin`.
- `sh tools/preview/check.sh` runs all three check files and must show 0 failed (39 + 34 + 29, plus 37 built from nothing, at the time of writing).
- `NODE_PATH=/opt/node22/lib/node_modules sh tools/preview/shots.sh <outDir> [names]` renders each screen under its reference page at 2x. Names: shop-passes, shop-cosmetics, shop-coins, settings-social, settings-audio, settings-controls, menu, lobby-hud, dances, index, progression, quests, tiers.
- Copy the ones that changed to `docs/previews/` as JPEG.
- The renderer approximates Roblox:
  - the Robux glyph draws small;
  - the avatar is a grey stand-in;
  - icons come from `assets/icons` even before they're imported.
- **Packed picture names** come from the file names (`tier-crown-mtb` → `TierCrownMtb`), so code must use that spelling. The renderer finds files without caring about capitals, so a wrong name only shows up in Studio; `check_index_tiers` checks the crowns.
- **Pictures (`assets/art`) and 7 icons** come from the owner's sharp pack `design/sharp/Huzz-Valley-UI-Sharp.zip` (see-through renders, 1254 px squares), brought in by `python3 tools/icons/import_sharp.py`. That script only frames each picture to its slot's shape (top crop, centre crop or fit with margins) and sizes it to 2x the slot (crowns 3x). The name map and slot shapes are in the script. The pictures have no backgrounds, so cards draw a blue gradient behind them. Card pictures have no printed badges or stars, so badges are live, in one spot.
- **Icons:** most of `assets/icons` (about 180-210 px) come from the owner's sharp sheet `design/icons-hd/owner-icon-sheet.webp`, cut by `python3 tools/icons/slice_sheet.py` (the name map is in the script). Lock, search, play, stop, xp-badge, currency-plus and controls-menu come from the sharp pack. The outline star, the equipped tick, the sneaker and the navy shirt (`shirt-equip`, for EQUIP/UNEQUIP) come from `design/sharp/Huzz-Valley-Additional-Icons.zip`. The fist, stopwatch and players (quest icons) come from `design/sharp/Huzz-Valley-Quest-Icons.zip`. All packs are imported by `import_sharp.py`. The rest are still small kit crops cleared by `clear_background.py`: the filled star, quests-clipboard, the white shirt (shop benefit), gift-benefit and music-benefit. The pack's hearts were a mix-up and are unused. Running `clear_background.py` overwrites the sheet icons, so run `slice_sheet.py` after it. **Never redraw or upscale them** (the owner's call). `pack_images.py` shrinks the packed in-game icons to 192 px (sharp on Retina screens, where icons show at about 200 px).

## Studio safety
- Lune's built-in copy of the Roblox API is older than Roblox (it lacks EditableImage, for example), so a clean harness run does not prove the code runs in Studio.
- Main.client starts every part through `Report.run`: a failing part can't stop the others, and any error shows in a red box on screen for the owner to screenshot.
- Images draw in-game from `Shared/Images` (EditableImage) until IDs are uploaded. Re-run `python3 tools/icons/pack_images.py` after changing anything in `assets/`.
- **Pictures in Studio's edit mode:** `src/ServerStorage/HuzzStudioTools/ShowPictures.server.lua` is a Studio helper, installed once with right-click > Save as Local Plugin. It adds a "Huzz Valley" toolbar:
  - **Show Pictures** draws the packed pixels onto StarterGui images by their `Icon`/`Art` attribute (`ImageContent`, display only). It also runs when the place opens.
  - **Upload Pictures** does the same as `upload-images.lua`.
  - It reports in Output on lines starting with `[Huzz]`, and scripts in ServerStorage never run in the game.
  - It is untested here because it needs Studio. The first owner test showed nothing, either because it wasn't installed or because of a silent failure, which is why it now reports.
- **Uploading:** `tools/studio/upload-images.lua` (owner pastes it into the Command Bar) uploads every packed image with `AssetService:CreateAssetAsync`, writes `Config/ImageIds` (checked first by `Config/Assets`), and fills `Image` on StarterGui parts by their `Icon`/`Art` attribute. It is untested here: cloud sessions can't reach Roblox (apis.roblox.com is blocked). When the owner sends their ImageIds text, commit it to `src/ReplicatedStorage/Shared/Config/ImageIds.lua` and rebuild, so the StarterGui copy carries the IDs.

## UI in StarterGui (owner's call)
- **How it works:** Roblox copies `StarterGui.HuzzUI` into PlayerGui, and the screens reuse those parts instead of making new ones. `Kit.new` reuses an unused saved child with the same class and name (its "twin").
- **What the saved part keeps vs what the code sets:**
  - the saved part keeps its look (`Kit.LOOK`: position, size, colours, fonts, images, corners), so Studio edits show in the game;
  - the code still sets text, visibility and behaviour.
  - With no saved UI, the same code builds everything from nothing.
- **Rules for screen code:**
  - Make parts with `Kit.new`/Kit helpers and a `Parent`.
  - Never use `x.Parent = y` in screens; use `Kit.attach(x, y)` and use the part it returns.
  - A list that the code refills must clear its old children first (the saved example cards included).
  - Kit's used/reused bookkeeping uses plain tables cleared on `Destroying`, never weak tables. Weak tables with Instance keys drop entries at random (in Roblox and in Lune), which made the reuse random.
  - Siblings with the same name must be identical: a saved part is matched by name, and same-named siblings can come back in any order. Give differing ones their own names (as `Kit.studs` does: Studs, Studs2...). The "nothing doubled" check catches mistakes.
  - A position that depends on the device (the top bar, phones) is assigned after creation, so it applies to saved parts too.
- **Checks:** `check.sh` runs everything on the saved UI, plus `check.luau` once built from nothing (`HUZZ_FRESH=1`). It also checks that nothing is doubled and that a Studio edit survives.
- **Owner's edits:** the owner's Studio edits live only in their place. Regenerating `HuzzUI.rbxm` starts from the code again. Before changing UI code after they have edited in Studio, ask for their export (`tools/export-for-claude.lua`) and copy their changes into the code.
- **Limits:**
  - Icons, pictures and the header studs (a texture) look blank in Studio's edit mode unless the ShowPictures helper is installed or real image IDs are set.
  - Items inside lists (shop items, character and dance cards, rewards, quests) are redrawn by the code, so Studio edits there don't stay.

## Screen layout (owner's calls)
- The HUD's side buttons are Index, Shop, Dances and Menu (the owner swapped Tiers for Shop; Tiers stays in the Menu). They are centred on the left edge. The Menu side panel opens in that same spot (centred on the left edge) and replaces them.
- The gear sits in Roblox's top bar row: 44 px tall, 12 px from the right edge, lined up with Roblox's own buttons. On touch devices the coin and gem pills move into that row too, so the thumbstick has the bottom-left.
- Windows fit the ScreenGui's own area (`Scale.setRoot`), which is below the top bar and inside a phone's safe area.
- No dim layer behind windows: on phones it left grey bands at the sides. The blur alone covers the screen.
- The Dances preview is a navy card (picture, name, help line) with equal Play and Stop buttons inside it. There is no brown floor.

## Gameplay (round loop and carry)
- **Rules (owner's design):**
  - She stands in the middle while nobody has her (`Config/Round.GirlSpot`). The first runner across gets her
    automatically: she appears overhead, with no pickup (`Pickup = "FirstAcross"`, `Carry.PickupTime = 0`, the
    owner's call). `Pickup = "Grab"` (walk up to her in the middle) is built and tested but off.
  - A catcher never carries her. When a catcher tags her carrier, she falls down and follows that catcher on foot
    (`CarryService.follow` makes an anchored-root model tagged `HuzzFollower`; `Shared/FollowMotion` walks her on
    every client; the server only estimates where she is, for the next transfer). That covers the thief, a
    catcher inheriting her, and a catcher winning her.
  - Tagged runners, runners still out at the timeout and runners who die all catch next round.
  - Rounds alternate ZoneA ↔ ZoneB.
  - A catcher who tags her holder steals her. The first runner across rescues her, and the round after is Final:
    - the holder crosses and wins her;
    - or the holder is tagged and the tagger wins her (on a timeout, the thief wins).
  - The holder as the only runner left = Final. No runners left = the holder wins.
  - Solo (Studio Play): no catcher; cross, then cross back to win.
- **`Shared/RoundRules`** is a pure state machine that returns events; `tests/RoundRules.spec.luau` covers it.
  Change rules there first, with a test.
- **`HuzzServer/RoundService.server`** is its own Script, not started by Bootstrap: the UI harness runs Bootstrap,
  and an endless round loop would hang `check.sh`.
  - It turns rule events into world actions (`handlers`).
  - State goes in attributes on the `Round` remote (`Net`).
  - It sets Workspace `NextRoundAt`, which the Lobby HUD banner counts down to.
  - It saves through `DataService.update`: the winner's girl goes in `Characters[model name]`, and it adds the
    `Stats` Steals, HoldSeconds and Rounds.
- **Between games (owner's call):** a map vote (`Screens/MapVote`, design page 15, ModalManager window, opens on
  Stage "Voting"; `MapVoteService`: one vote per player, a new vote replaces the old, ties random). The winner is
  copied in front of the lobby island (`MapService.load`: maps live in `ReplicatedStorage.HuzzMaps` from server
  start; placed `Map.Gap` past the lobby edge on the side facing where the maps were built). Maps go in **as
  built** (owner: turning them came out "flipped"), only turned so the right long side faces the lobby
  (`openSide`: `Map.FarSide` names a landmark that goes away from the lobby, Halloween's Mausoleum;
  `Map.OpenSide` maps pick the side with fewer fences, BasketBall; others keep the side that faced the lobby
  as built). Invisible walls (`Map.BoundsHeight`) ring the field so nobody jumps off. An optional `MapSpot`
  part overrides the placement. `check_maps.luau` prints which side faces the lobby. It stays there after the game and is swapped
  out only when the next vote picks its replacement (owner's call).
  - **Girl roller (owner's call: small, top of the screen, top-to-bottom, real models):** after the vote,
    Stage "Rolling" (`Config/Round.Roll`): `Screens/GirlRoll` (a 320 x 254 kit window, not a ModalManager
    window, scaled to 0.62 of a window) runs a reel of rows (ViewportFrame portrait, name, rarity pill, chance)
    and stops on the game's girl in the gold middle slot. Portraits come from `ReplicatedStorage.HuzzGirls`
    (`GirlService.publish`: script-free copies keyed G1, G2..., never the usernames); only rows near the window
    hold a model. Its window is `Kit.window{Flat = true}` (a Frame, not a CanvasGroup) because ViewportFrames may
    not draw inside a CanvasGroup; MapVote's map pictures still sit in one, so check them in Studio. `Shared/GirlRoll` (pure, `tests/GirlRoll.spec.luau`)
    picks her by rarity weight, then evenly, and builds the strip from honest picks (no planted near-misses).
    The server puts {cells, stop, start, spin, odds} as JSON in the Round remote's `RollData` attribute (so
    mid-roll joiners see it; cleared after); she's rebuilt as R15 during the spin.
  - Players who join mid-game stay in the lobby watching.
  - The status pill and a banner show the round number.
  - Vote cards show a live ViewportFrame of each map, with its scripts stripped.
  - The map icon is a soft crop of page 15 (`assets/icons/map.png`) until the owner sends a sharp one.
- **The owner tests `places/HuzzValley-yours.rbxl`** (Rojo never connected for them): `build_yours.luau` swaps
  every script and the saved UI into their `places/HUSSANIME.rbxl`. `build_place.sh` makes it when that file
  exists. When they push a newer HUSSANIME.rbxl, rebuild.
- **The owner's maps** are in `Workspace/Maps`: Base_Map, BasketBall_Map (no Zone B, so one is mirrored) and
  Halloween_Map, plus `Spawn` (the SpawnBaseplate lobby).
  - Zones are named "Zone A"/"Zone B", 8 studs tall, floating, unanchored. Names match loosely, zones are
    anchored at start, and spawns and the girl use the floor under a zone (`MapService.ground`).
  - Middle covers the whole field, so catchers spawn within `Map.MiddleSpawn` of its centre.
  - `lune run huzz-valley/tools/check_maps.luau` checks a new place file.
  - `SafetyService` strips the CoreValidation scam on start (the hoops are still in BasketBall_Map).
- **`MapService`:** every folder/model in Workspace holding ZoneA + ZoneB + Middle is a map (named after the
  folder). `pick()` chooses one per game at random, never the same twice in a row, and fills `MapService.zones` in
  place, so RoundService's `zones` table stays valid. One global `Lobby`. Falls back to the old single-map tags,
  then to a built test field. A Map Vote page can later replace the random pick.
- **`GirlService`** handles the collection (`ServerStorage/AnimeGirls/<Rarity>/<Model>` or a `Rarity` attribute)
  and the rarity roll.
  - `makeCopy` strips scripts, switches her Humanoid off, scales her to `Carry.GirlLength`, and welds parts that
    aren't joined yet.
  - It walks the joint graph by hand, because anchored parts have no assemblies and doubling Motor6Ds with welds
    would lock her limbs.
- **`CarryService`** adds a Motor6D from the carrier's torso to her root.
  - She lives in `Workspace.HuzzCarried`, never inside the character, so walk animations can't bind her joints.
  - `Shared/CarryMath` holds the hold height and arm pose, shared by the server and the client so they agree.
    `tests/CarryMath.spec.luau` checks the directions on a stock R15 rig.
- **`HuzzClient/StartGameplay`** starts `Gameplay/*` through `Report.run`.
  - `CarryAnimator` sets Motor6D.Transform in PreSimulation, after the animations:
    - the carry joint: the pickup flight, the step bob and the inertia spring;
    - the carrier's shoulders and elbows: the pose, plus `AnimBlend` of the playing animation;
    - her limbs: dangling toward gravity.
    It tells its own writes from the Animator's by reading the Transform back (CFrames are float32).
  - `RoundHud` is a stand-in, to be rebuilt with Kit as the Match HUD page.
  - `AvatarAnimations` swaps in the IDs from `Config/Animations`.
- **Caught runners fall flat and lie there until the next round** (owner's call; `Config/Round.Knockdown`;
  `Enabled = false` = the old bench teleport). `KnockdownService` anchors the root and sets the character's
  `DownedAt`/`DownedFeet`/`DownedHeight`, lying bodies collide with nothing (the `HuzzDowned` group), and the
  next round's `upAll()` stands them up. `Gameplay/Knockdown` plays `Shared/DownMotion` (a plank fall over the
  feet, a bounce, then the sprawl).
- **Owner's motion calls:** no wiggle while carried (`Carried.Moods = false`, `Inertia = 0`, critically
  damped springs, small bob, no roll); the prize just stands normally (`Idle.Wave/Bounce = false`). The livelier
  version is still there behind those switches.
- **Coming from the owner: much better walking animations** (players and girls). Nothing should depend on
  the current walk:
  - player walk, run and idle IDs go in `Config/Animations` (the carry arms and lean are layered on top);
  - the follower girl plays `GirlIdle`/`GirlWalk`/`GirlRun` when set (blended and speed-matched in
    `CarryAnimator`), otherwise the procedural `GirlMotion.walk`;
  - retune `Carry.Bob.StepsPerStud`, `Carry.Follow.Stride` and `GirlWalkSpeed`/`GirlRunSpeed` to the new
    animations.
- **Zones (owner's call):** white safe lines on the zone edges facing the middle and a green SAFE ZONE billboard
  over the goal's line (`MapService.showGoal`, `Config/Round.Map.SafeLines`). Before GO runners can walk in their
  start zone but a wall stands on the start line (`MapService.holdStart`: an invisible 40-stud block plus a
  faint blue glass strip with a neon edge and posts, owner asked for faint) and `keepIn` puts back anyone who
  gets round it. `tools/check_maps.luau` checks the lines on the owner's maps.
- **Stabbing (owner's call, `Config/Round.TagMode = "Stab"`; "Touch" = the old run-into tag):** catchers hold a
  knife welded to the right hand (`KnifeService`; a `ServerStorage.HuzzKnife` model replaces it). Click, R2 or the
  STAB button (`Gameplay/Actions`) plays `Shared/StabMotion` at once and fires `Stab`; the server checks role,
  stage, cooldown and tags the nearest Active runner within `Stab.Range` roughly in front (not in the start
  zone). Other clients play it from the `Stab` message.
- **Hussing (owner's call):** the overhead carrier presses H, X or HUSS; the client sets `HussAt` (server time)
  on the carried model for itself and sends it, and the server checks and sets the same value. `CarryMotion.huss`
  throws her up (`Carry.Huss`), twirls her, swings his arms to a double flex with chest pumps, and catches her.
- **Placeholder moves:** the stab and huss are scripted until the owner's animations arrive
  (`Config/Animations.Stab`/`Huss`: with an ID the track plays and the scripted arms step aside; her throw stays
  scripted). `motion3d/action_scene.luau` renders both (`docs/previews/stab-and-huss.mp4`).
- **Powers (owner's call: "like Huss Valley but our own spice"):** `Config/Powers` lists them; runners get Heart
  Shield (Q: bubble blocks one stab, the catcher is dizzy and can't stab, the runner gets a burst; once per round)
  and Rizz Rush (E: speed burst); catchers get Love Trap (Q: heart trap, a runner who steps in is stuck) and
  Charm Wave (E: slows runners in reach). `HuzzServer/PowerService` decides everything (RoundService gives it
  a ctx and asks `speedOf`, `stuck`, `canStab`, `blocks`); lasting visuals are made on the server, bursts go out
  as `Power` messages (`Gameplay/PowerEffects`). The hotbar is `Screens/PowerBar` (two small square kit tiles, 62 px, bottom centre: owner asked for smaller;
  reads `PowerReady1/2` and `ShieldUntil`; `DizzyUntil` darkens STAB). Q, E and H are reserved keys (the Menu key
  can't take them). The shield bubble lives in `Workspace.HuzzShields`, outside the character, so the team
  Highlight doesn't outline it. Icons are emoji until the owner sends PNGs.
- **The girl over the map (owner's call, replaces the girl standing in the middle; `GirlSpot = "Sky"`):**
  `GirlService.showcase` puts a 3x copy of the game's girl `Showcase.Height` above the middle for the whole
  game, in her rarity colour: two neon rings, sparkles (default ParticleEmitter texture, no asset IDs), a
  PointLight, a Beam column and a "Rating" billboard (stars 1-7 by rarity, name, rarity). Anchored; every
  client turns and bobs it (`CarryAnimator`, tag `HuzzShowcase`, attribute `Base`).
- **Girls stay as built (owner: the R15 rebuild came out deformed):** `GirlRig = "Original"` (they're R6). Sizes,
  the hold and the showcase use `GirlService.bodyBounds` (body parts only), so hats, hair and wings can't shrink
  them or push the hold off-centre.
- **The Huss Valley sprint (owner's call):** `Shared/RunMotion` (pure, tuned in `Config/Run`) leans into the run,
  long strides with a high knee fold, arms pumping, shoulders twisting, a bounce; it blends in above walking
  speed (`From`/`Full`) on every R15 character (`Gameplay/RunAnimator`). `Gameplay/Frame` runs every scripted
  pose in order after Roblox's animations: run 10, carry 20, stab 30, knockdown 40. A carrier keeps the carry
  arms and leans less. `motion3d/run_scene.luau` renders it (`docs/previews/huss-run.mp4`). Speeds went up
  (runners 24, catchers 26, lobby 20). The H throw-and-catch is still there.
- **Blur:** the map vote window opens with no blur (`noBlur` in ModalManager); the owner's place has DepthOfField
  switched off already.
- **Icons in game:** they come from EditableImage, which needs Game Settings > Security > "Allow Mesh / Image
  APIs" (the warning says so); uploading (`upload-images.lua` or the plugin's Upload Pictures) removes the need.
- **Full-game simulation (`tools/sim/round_sim.luau`, run by `tools/check.sh`):** the real RoundService,
  PowerService, RoundRules, GirlRoll and configs on fake services with a virtual clock and bots who run,
  chase, stab, use powers, huss, cheat round the start wall, leave and join. It checks the stage order, the
  roller data, the map swap, knives, the start wall, traps, the holder and the saved winner, in 7 setups.
  Breaking keepRunnersIn or the knives makes it fail (checked). It can't see physics, animation or UI.
- **Outlines (reference video):** `RoundHud` puts a faint Highlight (outline only, 0.35 transparent) on
  everyone in the game: catchers red, runners blue, none on caught runners. Roblox draws at most 31
  Highlights at once, so servers over 31 players lose some outlines.
- **Girl animations (owner asked for all three, "make them good"):** `Shared/GirlMotion` (pure) holds her
  motion: `carried` (limbs fall toward gravity minus her real acceleration, plus moods Excited, Struggle,
  Cheer and Calm, set by the server through the carry model's `Mood`/`MoodAt`) and `idle` (the prize:
  weight shift, watching the nearest player, waving, bouncing). `Shared/CarryMotion` (pure) holds the carry
  joint, the arms and the waist lean; `Gameplay/CarryAnimator` only feeds them parts. Tunables:
  `Config/GirlMotion`.
- **The owner's girls:** `Workspace/ANIME GIRLS/<Rarity>/CAC_R6_<username>_<id>`: 36 unique (4 listed twice;
  counted once), all R6 except one R15 Secret built on doubled AnimationConstraints.
  - `GirlService.prepare` rebuilds the rolled girl as R15 from her HumanoidDescription (`Config/Round.GirlRig`).
  - `makeCopy` swaps AnimationConstraints for Motor6Ds.
  - Model names are real usernames, so the shown name comes from `Config/GirlNames` (empty = "<Rarity> Girl n").
  - The owner's place file is `places/HUSSANIME.rbxl`; read it with Lune `roblox.deserializePlace`.
- **3D motion preview:** `tools/preview/motion3d`. `follow_scene.luau` shows the tag and the follow;
  `sh video.sh girls_scene.luau out.mp4` runs the real
  CarryMotion/GirlMotion on mock rigs and renders a 30 fps MP4 (three.js in Chromium). `ORBIT=1` keeps the
  carrier still and circles the camera. Lune's `CFrame.lookAt` faces backwards: use `Rig.lookAt`.
- **Security:** the owner's Basket Ball Hoop free models carried a scam ("Model corruption detected… paste into
  the Command Bar", a `Dependencies/Utilities/CoreValidation` script inside the mesh) that installs a
  backdoor. Scan any place file the owner sends for scripts that use `GetObjects`, `HttpEnabled`, `require(<id>)`,
  `getfenv` or `loadstring`.
- **`sh tools/check.sh`** compiles every script, runs the specs and the full-game simulation. Run it with `tools/preview/check.sh`.
- **Not seen in Studio yet:** physics ownership of the welded girl and the Animator ordering. Ask the owner how
  the carry feels before tuning blind.
- **Waiting on the owner:** their girls and map (a `.rbxl` in `places/`, or `tools/studio/export-girls-and-map.lua`
  output). Check every girl (scale, rig, dangle) before tuning. Their rarities are Common → Secret, but the Index
  uses tiers (Sub1 → TrueEve) and `Config/Characters.List`: ask how they map, and add the girls to that list so
  the Index shows them.

## Place file
`sh tools/place/build_place.sh` rebuilds `places/HuzzValley.rbxl` (all scripts plus a baseplate). Rebuild it whenever `src/` changes, so the owner can always just open the file.

## Open items (owner's checklist lives in `README.md`)
- **Built:** Lobby HUD, Menu (a side panel over the HUD's side buttons), Shop, Settings, Character Index, Tiers, Dances and Progression (Rewards and Quests). Every main window is 701 x 320.
- **Next:** the round-driven pages (Map Vote, Recruitment, Results, Match HUD) on top of the round system; the Gift Picker (needs the gifting backend).
- **Missing from the owner:**
  - sharp versions of the 5 icons still from the kit crops (list under Checks and previews), including the filled star;
  - big preview pictures for Step and Wave (the Index preview uses each character's whole-body render);
  - running `tools/studio/upload-images.lua` and sending back the ImageIds text;
  - Game Pass and Developer Product IDs;
  - dance and pose animations;
  - companion models;
  - outfit assets.
- **Decided:**
  - not-on-sale items show their price but only say "coming soon" when tapped;
  - Aiko and Step are the starter companion and dance;
  - quests count real match events only;
  - there are no timers.

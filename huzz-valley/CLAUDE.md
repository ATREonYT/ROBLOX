# Huzz Valley: project memory

Huss Valley's crossing game, one to one, with collectible anime girls built in. Kid audience, owner judges by
eye. Branch `HUZZ-VALLEY`. Read the section you need; the owner's own words are in quotes.

## 1. Owner's standing calls (don't undo without asking)
- **The loop is Huss Valley's** (videos 32fe8d21, 87565d66; `docs/previews/hv-reference-*.jpg`). Girls add a
  prize layer on top; they never change the rules.
- **Look = Huss Valley's** (owner: "use the same fonts as Huss Valley, it's simple and feels nice"; "let go of
  that gold tone"): **one font, Roblox's Gotham** (`GothamSSm`: Black for titles, Bold for names/buttons, Medium
  for lines, Black Italic for big moments), **white text with a dark outline**, no gradient-banded titles, **no
  gold**: the one accent is **Huss Valley green** (`Theme.Colors.Accent`; selected tabs, your vote, progress,
  good news). The kit's purple/navy panels stay, see-through, with a studded texture over whole panels.
  The preview has no Gotham (not free): it draws Montserrat, its look-alike.
- **Text:** short, game-like, no dashes, no "AI" phrasing ("Messi is safe", "Got one!", "GO! Get across!").
- **Small HUD** (`Scale.HUD_SIZE = 0.55`); lobby side buttons and coin pills slide away during rounds.
- **Controls:** Space = dash (no jump in rounds); hold W = walk building into a run; G = dance wheel; Q/E = powers;
  click = stab; no mouse pointer in rounds (shift lock), Alt brings it back. **No girl toss** (removed).
- **Safe means safe:** once across you stay across (goal gate). During a Hero run only the Hero (and catchers) move.
- **Girls:** the equipped one **walks behind you** on the ground; effects are **tiny below Legendary**.
- **Never invent IDs** (assets, sounds, animations, passes). Empty + a checklist line in `README.md`.

## 2. Where things are (`src/`, Rojo `default.project.json`)
- `ReplicatedStorage/Shared`: `RoundRules` (pure rules, tested), `AuraLook`, `CinematicShot`, `RunMotion`,
  `CarryMotion`, `GirlMotion`, `FollowMotion`, `AnimationLibrary`, `Net`, `Config/*` (Round, Run, Powers, Dances,
  Animations, SoundIds, GirlLooks, GirlNames, Products, Settings...).
- `ServerStorage/HuzzAnimations.rbxm`: the owner's animations as raw KeyframeSequences (generated, §6; copied to
  ReplicatedStorage by Bootstrap in Studio only).
- `ServerScriptService/HuzzServer`: `RoundService.server` (the loop; its own Script), `MapService`, `GirlService`,
  `CarryService`, `KnockdownService`, `PowerService`, `NameTagService`, `CompanionService`, `DataService`
  (ProfileStore; all writes via `update()`), `ShopService`, `SettingsService`, `Bootstrap`.
- `StarterPlayerScripts/HuzzClient`: `Main` (UI screens via `Report.run`), `StartGameplay` (Gameplay/*),
  `UI/{Kit,Theme,Scale,Motion,ModalManager,State,DancePlayer}`, `UI/Screens/*`, `Gameplay/*`.
- `StarterGui/HuzzUI.rbxm`: **generated** by `build_place.sh`; never edit by hand.
- `design/`: kit pages, the owner's sharp art/icon zips, `anims/` (their movement pack + 200-dance file).

## 3. Checks, previews, builds (run before every commit; Lune at `/root/bin/lune`)
- `PATH=/root/bin:$PATH bash tools/check.sh`: compiles every script, RoundRules/CarryMath/GirlMotion/GirlRoll
  specs and the **full-game simulation** (`tools/sim/round_sim.luau`: real server code, bots, 7 setups; checks
  stage order, freezing, Hero-only runs, safe runners staying across, tags, the girl...). Prove a new sim check by
  breaking the code once and seeing it fail.
- `PATH=/root/bin:$PATH bash tools/preview/check.sh`: UI checks on the saved UI, then built from nothing.
- `PATH=/root/bin:$PATH LUNE=/root/bin/lune sh tools/place/build_place.sh`: regenerates `HuzzUI.rbxm`,
  `places/HuzzValley.rbxl` and **`places/HuzzValley-yours.rbxl`** (the owner's place with everything swapped in:
  what they test). Rebuild after every change and give the raw download link.
- UI pictures: `NODE_PATH=$(npm root -g) sh tools/preview/shots.sh <out> <names>` (reference on top, ours below).
  `HUZZ_FRESH=1` builds from code instead of the saved UI. Names include round-hud, hero-choice, welcome,
  dance-wheel, dances, shop-passes, shop-coins, progression, lobby-hud, menu, index, map-vote, power-bar.
- 3D videos: `tools/preview/motion3d` (`sh video.sh <scene> <out.mp4>`). `anim_scene.luau` plays any
  KeyframeSequence file (`ANIM_FILE=... ANIM_NAMES=a,b` or `ANIM_PREFIX=Dance_`) via `kfs.luau`, as Roblox would.
- Renderer limits: no `AutomaticSize` on frames (size chips by hand), the Robux glyph is small, saved-UI previews
  keep the saved look (use `HUZZ_FRESH=1` after style changes).

## 4. The round (`RoundRules` + `RoundService`)
- Lobby time (owner: "a bit more, so people can buy things, not too long"): `VoteTime` 30 s, `IntermissionTime` 25 s.
- Stages: Waiting → Voting (map vote) → Rolling (girl roller) → per round: Lineup → Picking (HERO/CHICKEN, 8 s,
  else random) → Chosen → HeroRun (only the Hero and catchers unfrozen) → Countdown → Running → RoundOver;
  GameOver. Runners win with everyone across `Crossings` (3) rounds in a row; downed runners left at the end join
  the catchers.
- Stab downs a runner (`KnockdownService`); a runner standing by them for `Rescue.Time` revives them (not from
  the start zone; `Rescue.Shield` after).
- **Safe gate:** `MapService.holdGoal` puts an invisible block on the goal line in collision group
  `HuzzSafeWall`, which only collides with `HuzzSafe` (Safe runners' parts: `MapService.setSafe` from
  `syncPlayer`); `keepSafe()` pulls back anyone who got round it, every frame of the round.
- Speeds: the server sets `WalkSpeed` and the cap `HuzzSpeed` on the Humanoid; `Gameplay/Sprint` ramps your
  own speed from `Run.StartSpeed` to the cap, easing out (~95% after `Run.Ramp`), while you hold a direction (0 stays
  0). Top speeds in `Config/Round.Speeds` (raised twice on the owner's request: runners 28, catchers 30).
- State lives in attributes: Round remote (Stage, EndsAt, Round, Goal, Streak, Crossings, PickId, PickAt,
  PickChoice, HolderId, GirlName, GirlRarity, LineCF...) and players (HuzzRole, HuzzStatus, HuzzHero,
  HuzzFrozen, ProtectedUntil, DashReady, PowerReady1/2). Local-only: HuzzCinematic, HuzzChoosing, HuzzWheel.
- `announce(text, colour, big)` = the message line (big = centre banner). Copy rules in §1.

## 5. In-game screens (Huss Valley look on the kit panels)
- `Gameplay/RoundHud` (code-built, 1280x720 scaled): round plate (purple header: ROUND n + clock; navy strip: role
  chip + IN A ROW bars), message bar, help line (control tips in your first two games), prize card, centre banners, the
  companion's reaction bubble, and team outlines (Highlights: red catchers, blue runners, yellow Hero, green safe).
- `Screens/HeroChoice` (green HERO / violet CHICKEN cards), `Screens/NextMap` (after you vote, the vote tucks into a
  "NEXT MAP" panel at the top left: both maps, votes, your pick in green, time left, an arrow back to the full vote;
  the winner shows for a few seconds; owner's HV reference), `Screens/PowerBar`, `Screens/DanceWheel` (G),
  `Screens/Welcome` (How to Play: auto-opens once, saves the `TutorialDone` setting; also in the Menu).
- `Gameplay/Cinematic`: the line-up camera and the hopping pick highlight (outline only while hopping).
- `Gameplay/Feel`: sprint FOV widening, dash FOV kick + speed lines (one per dash), footstep dust, step sound.
  Off with Reduced Motion (dust stays).
- `NameTagService`: Gotham (as Huss Valley); role title, name, "Lv. N · W wins", HELP! + rescue bar, big HERO/CHICKEN.

## 6. Animations (the owner's files)
- `tools/anim/extract_anims.luau` reads `design/anims/movement-pack.rbxl` and `200-dances.rbxl` and writes
  `src/ServerStorage/HuzzAnimations.rbxm`: Idle, Walk, Run (the pack's hunched Sprint, its own big arm swing: the owner rejected arms held in front;
  `docs/previews/run-arms-vs-hv.jpg`), Jump, Fall, Climb,
  DashLeft/DashRight (built: the sideways huss, matched to the owner's HV video; `docs/previews/huss-vs-reference.jpg`) and `Dance_<Id>` for the 25 in `Config/Dances` (names are
  ours; the originals are other games' emote names).
- Dance pictures (`UI/DancePose`): a still copy of your avatar posed by hand from the dance's KeyframeSequence at its
  most telling second (`Config/DancePoses`, made by `tools/preview/motion3d/dance_poses.luau`). No Animator, so
  they never lag (the first version ran 25 live animations and lagged). Used by the Dances cards (locked = dark
  silhouette) and the wheel's slots; the music note when the dance can't be read (live, before publishing).
- Dance wheel (`Screens/DanceWheel`, owner's taunt-wheel reference: `docs/previews/dance-wheel-vs-reference.jpg`):
  8 see-through dark circles round a big centre circle that names the hovered dance; no dimming, no CanvasGroup.
- Dancing in step: the `Dance` remote → `ActionService` sets `HuzzDance` / `HuzzDanceAt` (server time) on your
  character; `UI/DancePlayer` starts the same dance on the beat of the nearest dancer within 30 studs doing it, and
  your companion follows your track's time. (Studio's temporary animation IDs don't show on other test clients.)
- `Shared/AnimationLibrary.id(name, published)`: the published ID, else **in Studio only** a temporary ID from
  `KeyframeSequenceProvider:RegisterKeyframeSequence`, else "". So Studio tests play everything now; the live game
  needs `tools/studio/publish-animations.lua` (owner) and the IDs pasted into `Config/Animations` / `Config/Dances`.
- `Gameplay/Locomotion` (own character, when the pack can play) replaces Animate's walk/run: Idle/Walk/Run blended by
  a smoothed speed (`Shared/LocomotionMix`, rate capped ~1.1x so the sprint stays calm), Jump/Fall/Climb faded in,
  a small lean into turns. `RunAnimator`'s scripted run covers anything without animations. **Huss = sideways
  only** (owner): `Gameplay/Dash` picks left/right (A/D, else the last side), the server forces pure sideways.
- `Gameplay/CompanionDance`: your girl dances your dance, retargeted onto her R6 body (`Shared/DanceRetarget`,
  `Shared/KeyframeSampler`). Companions and the round girl are in the `HuzzCompanion` collision group (no bumping).
- `UI/DancePlayer`: one dance at a time on your Animator; walking away stops it. Starter = 20 dances, Robot =
  reward level 3, Dance Pack pass = Swing Time, Bounce Bounce, Squat Kick, Toprock.
- The stab is still scripted (`StabMotion`) until the owner sends one. `CarryMotion.huss` is dead code (toss removed).

## 7. The girls
- Collection: `Workspace/ANIME GIRLS/<Rarity>/CAC_R6_<user>_<id>` (36, R6). Shown names: `Config/GirlNames`
  (sound-alikes, never the originals). `GirlService` copies/scales/publishes them (`ReplicatedStorage.HuzzGirls`).
- Prize: floats over the map as a 3x showcase with her aura (no disc); a surviving Hero carries her; a catcher who
  stabs the carrier steals her (she follows); she goes home with the winning side (Index).
- Companions are only the girls you win: the kit's mock-up four (Aiko, Ren, Sora, Hina) were removed on the owner's
  request (`Characters.Retired`; `DataService` drops them from old saves). No starter companion.
- Safe lines, the start wall and the goal gate are trimmed to the floor (`MapService` `edge()`), so they never stick
  out past a map's edge when its zone box is wider than the floor. The invisible walls round the field
  (`boundary()`) stand at the floor's real edge too, and `MapService.catchFalls()` puts anyone who still drops below
  the field back on it (or, far below the lobby, back at the lobby spawn).
- The look (`Config/Look` → `HuzzServer/LookService`): colour grade, bloom, sun rays, light haze, lifted shadows
  (owner: "the filters that make the game feel premium"); the place build sets Lighting.Technology = Future.
- Shop passes follow the owner's pass banners (`design/shop/pass-banners.png`, art cropped into `vip` /
  `dance-pack`): navy glass rows with a rim and button in each pass's `Accent` (`Products`), styles `PassViolet` /
  `PassPink` (`docs/previews/shop-passes-vs-banner.jpg`).
- Effects: `Config/GirlLooks` (element + 2 colours per girl) → `Shared/AuraLook` (pure specs by rarity: Common
  faint motes ... Mythic/Secret full flames, wisps, slashes) → `Gameplay/AuraFX` (emitters, light, pooled slash
  beams) → `Gameplay/Auras` (your aura; others' "lite"; within 170 studs). Check: `tools/preview/check_girl_fx.luau`.
- Companion: walks on the ground ~3.5 studs behind you (`FollowMotion` + `GirlMotion`, `Config/GirlMotion.
  Companion`), hidden in rounds until you're Safe, then hops and cheers.

## 8. UI kit rules (UI lives in StarterGui as real parts: owner's call)
- Build with `Kit.new`/helpers and `Parent`; never `x.Parent = y` in screens (`Kit.attach`). Saved parts are
  reused by name ("twins"), so same-named siblings must be identical; lists clear old children first.
- Look: `UI/Theme` colours/fonts/transparency; `Kit.button` adds the shade gradient, outline and stud texture;
  `Kit.window` = see-through studded body with a stroke frame; `Kit.studPattern(frame, strength)` everywhere else.
  The texture is `assets/icons/stud-pattern.png` (`tools/icons/make_stud_pattern.py`), packed by `pack_images.py`.
- Every main window is 701 x 320. One window at a time (`ModalManager`; sets `MenuOpen`).
- Icons/art come from the owner's sharp packs; never redraw them. Packed names are PascalCase of file names and
  case-sensitive in Roblox.

## 9. Currencies, coin shop, crates
- **Coins** (earned: `Config/Round.Pay` per game, more for a win; Hero bonus; quests) buy **looks only** in the
  Shop's ITEMS tab (`Config/CoinShop`: trails, name colours, knife skins, all made from colours in code). Server:
  `ActionService` `BuyWithCoins` / `Wear` (one item per slot in `data.Wear`); shown by `CosmeticsService`
  (trails), `NameTagService` (name colour) and `KnifeService.give(character, skin)`.
- **Aura** = Huss Valley's gems (owner's call; old `Gems` saves migrate in `DataService`): from wins
  (`Pay.WonAura`) and the reward track. It pays for **crates** (`Config/Crates`, empty until the owner adds them;
  `Shared/CrateRoll` pure maths with shown odds and a pity counter, `tests/CrateRoll.spec.luau`; server
  `ActionService.OpenCrate`; no crate UI yet).
- **Aura stars in the lobby** (owner's star: `design/aura`, packed as `AuraStar` and `AuraStarWhite`): `Config/AuraStars`
  (count, kinds, values, weights) → `AuraPickupService` (server: spawns tagged `HuzzAuraStar` parts near the lobby
  spawn, ProximityPrompt E "Collect Aura", checks distance, adds Aura, respawns) → `Gameplay/AuraStars` (client
  look: the purple star as drawn, other colours tint the white copy; halo, sparkles, light, floor glow; Rainbow
  drifts slowly). Lobby only: rounds keep their power-ups. The Aura pills use `AuraStar` untinted.
  Preview: `docs/previews/aura-stars.mp4`.

## 10. Sounds
- 24 sounds made from scratch by `tools/sfx/make_sfx.py` → `assets/sfx/*.ogg` (list in `assets/sfx/README.md`).
- `Gameplay/Sfx.play(name, {volume, pitch, at})` with per-sound levels; `Config/SoundIds` empty until the owner
  uploads (Asset Manager bulk import + `tools/studio/collect-sound-ids.lua`); a few built-in stand-ins meanwhile.

## 11. Studio-only truths and the owner's steps
- The cloud can't reach Roblox: uploads (images, sounds, animations) and real purchases are the owner's steps
  (README checklist). Studio helpers report on lines tagged `[Huzz]`, `[HuzzSfx]`, `[HuzzAnim]`.
- Not yet seen in Studio: the safe gate's collision groups, the walk→run ramp feel, the dance preview viewport,
  the companion's walk on R6 girls, temporary animation IDs on the client. Ask how they feel before retuning.
- Security: scan any place the owner sends for `GetObjects`, `require(<id>)`, `getfenv`, `loadstring`, HTTP
  (their Basket Ball Hoop models carried a scam; `SafetyService` strips it).
- ProfileStore runs in Mock mode in Studio (progress resets on Stop): on purpose.

## 12. Open items
- Owner: upload pictures, sounds and animations; Game Pass / product IDs; power icons (4 PNGs); a stab animation;
  maybe rename dances; confirm the movement pack licence allows a published game.
- Us: a Match HUD/results page from the kit (none exists yet); the Gift Picker; the 5 remaining soft icons.

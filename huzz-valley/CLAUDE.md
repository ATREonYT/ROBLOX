# Huzz Valley: project memory

Huss Valley's crossing game, one to one, with collectible anime girls on top. Kid audience. The owner is a
non-coder on a Mac (Studio, GitHub Desktop, Rojo) who judges by eye, writes short messages and sends reference
videos/pictures. Branch `HUZZ-VALLEY`, folder `huzz-valley/`. The root `CLAUDE.md` rules (plain words, golden slice,
reference side by side, honest gaps, never invent IDs, kid-safe, purchases server-only) always apply.
Owner's own words are in quotes. Read only the section you need.

> **Work in progress, not a final state.** The game is mid-build and the owner has said plenty still needs fixing.
> This file is a running notebook of where things stand today, not a finished design: **the owner's newest message
> always beats anything written here.** When something changes, update the section it belongs to (and drop what's
> no longer true) in the same commit. Things marked as feeling right have mostly only been checked offline; expect
> them to be reworked once the owner tries them in Studio.

## 0. Start here (every session)
- Branch `HUZZ-VALLEY`, run everything from `huzz-valley/`. A fresh cloud container has no Lune: install it once with
  `mkdir -p /root/bin && cd /tmp && curl -sSLo lune.zip https://github.com/lune-org/lune/releases/download/v0.10.5/lune-0.10.5-linux-x86_64.zip && unzip -o lune.zip -d /root/bin && chmod +x /root/bin/lune && cd -`
  (image tools need `python3 -m pip install pillow`).
- The three commands (details in section 4), in this order before every commit:
  1. `PATH=/root/bin:$PATH bash tools/check.sh` (compile + specs + full-game sim)
  2. `PATH=/root/bin:$PATH bash tools/preview/check.sh` (UI checks)
  3. `PATH=/root/bin:$PATH LUNE=/root/bin/lune sh tools/place/build_place.sh` (regenerates `HuzzUI.rbxm` + places)
- Find code by grepping the header comments: every file opens with a plain-words comment saying what it does and
  quoting the owner's ask, e.g. `grep -rln "free spin" src`.

## 1. Owner's standing calls (don't undo without asking)
- **The loop is Huss Valley's** (their videos 32fe8d21 and 87565d66; frames in `docs/previews/hv-reference-*.jpg`).
  The girls are a prize layer on top; they never change the rules.
- **Look = Huss Valley's** ("use the same fonts as Huss Valley, it's simple and feels nice"; "let go of that gold
  tone"; gold "looks so AI"): one font, Roblox's **Gotham** (`GothamSSm`: Heavy titles, Bold names/buttons, Medium
  lines, Heavy Italic for big moments); **white text with a dark outline**; **no gold anywhere**; the one accent is
  **Huss Valley green** (`Theme.Colors.Accent` 5BE07A). Kit purple/navy panels stay, **see-through** ("make the UI
  more transparent", asked twice: `Theme.Transparency` Body 0.32 / Row 0.18) with a **studded texture over whole
  panels** (not stud strips). A second reference for polish: their video 9233ecef of another game (bright,
  saturated, crisp, glowing): aim for "a mix of this and Huss Valley".
- **Text:** short and game-like, no dashes, no "AI" phrasing ("Messi is safe", "Got one!", "YOU'RE OUT").
- **Controls:** **no jumping anywhere**. Space = the sideways huss (left/right only, lobby too; you turn to face the
  camera first so A/D go left/right on screen: "it only goes one way" without shift lock); a **catcher's Space
  in a round is a lunge** that stabs whoever it reaches; hold W = walk building into a run; G = dance wheel;
  Q/E = powers (catcher Q = Love Trap = the traps); click = stab; shift lock in rounds (Alt frees the mouse).
- **No girl toss** (removed). **Safe means safe:** once across you stay across. During a Hero run only the Hero and
  catchers move.
- **Companions are only girls you win** (the kit's Aiko/Ren/Sora/Hina mock-ups were removed). The equipped girl
  walks behind you on the ground, doesn't collide with you, and dances when you dance. Effects tiny below Legendary.
- **Knives:** everyone wears one on the back; catchers hold theirs in a round. The owner will send 3D knife renders.
- **Aura** = Huss Valley's gems. **Coins** buy looks (the owner picked "Coin cosmetics shop").
- **Never invent IDs** (assets, sounds, animations, passes, products): leave 0/"" and add a README checklist line.

## 2. How we work with this owner (lessons so far)
- Give status in short plain lines; one picture per change; end with the download link
  `https://github.com/atreonyt/roblox/raw/HUZZ-VALLEY/huzz-valley/places/HuzzValley-yours.rbxl` and how to try it.
- **Watch their videos frame by frame before changing anything they show** (ffmpeg contact sheets at 10 fps,
  cropped to the character). Examples that went wrong first: the run arms (we held them in front; Huss Valley
  swings them), the huss (first version was a cartwheel; theirs is a compact sideways lean).
- **Measure before "fixing" a scare:** the "walls missing" report turned out to be walls in the wrong place; the
  "high pitch sounds" were Roblox's ping played as a stand-in, pitched up.
- Big lists: split into tasks; use worktree agents only for self-contained parts (sounds, spin wheel), tell them
  exactly which files they may touch, then **cherry-pick** their commit and hand-merge the shared files
  (Net, ActionService, CoinShop, DataService, Products, RoundService). Binary files (HuzzUI.rbxm, places): take
  ours and rebuild.
- **Always run a fresh critic agent** on new code before reporting; it found real bugs every time (shield vs lunge,
  Dance Pack sync, fall net pulling lobby players, props shrinking walls, avatar joints).
- Report honestly: what's still worse than the reference, what only Studio can show, what's a stand-in.

## 3. Where things are (`src/`, Rojo `default.project.json`)
- `ReplicatedStorage/Shared`: pure, tested logic (`RoundRules`, `CrateRoll`, `SpinRules`, `GirlRoll`, `CarryMath`,
  `KeyframeSampler`, `DanceRetarget`, `LocomotionMix`, `AuraLook`...), `Net` (every remote), `AnimationLibrary`,
  `Config/*` (Round, Run, Look, Powers, Dances, DancePoses, Animations, SoundIds, Products, CoinShop, Crates,
  SpinWheel, AuraStars, Progression, Characters, GirlLooks, GirlNames, Settings...).
- `ServerScriptService/HuzzServer`: `RoundService.server` (the loop), `MapService`, `MapVoteService`, `GirlService`,
  `CarryService`, `KnockdownService`, `PowerService`, `KnifeService`, `NameTagService`, `CompanionService`,
  `CosmeticsService`, `AuraPickupService`, `PracticeBot`, `SpinService`, `LookService`, `ActionService` (UI verbs + Dance remote),
  `ProgressService`, `ShopService` (the one ProcessReceipt), `DataService` (ProfileStore; writes only via
  `update()`; `onChanged` hook), `SafetyService`, `Bootstrap`.
- `StarterPlayerScripts/HuzzClient`: `Main` (UI screens, each in `Report.run`), `StartGameplay` (Gameplay/*),
  `UI/{Kit,Theme,Scale,Motion,ModalManager,State,DancePlayer,DancePose,Toast}`, `UI/Screens/*`, `Gameplay/*`.
- `ServerStorage/HuzzAnimations.rbxm` (generated), `StarterGui/HuzzUI.rbxm` (generated: never edit by hand).
- `design/`: kit pages, the owner's art zips, `anims/` (movement pack + 200 dances), `aura/`, `shop/`, references.
- `places/HUSSANIME.rbxl` = the owner's own place (maps, girls, 3 lobbies, 4 spin wheels) as of Oct 17 (their
  `huss77.rbxl`); `HuzzValley-yours.rbxl` = it with all our code and UI swapped in (what the owner tests).

## 4. Checks, previews, builds (Lune 0.10.5 at `/root/bin/lune`; run before every commit)
- `PATH=/root/bin:$PATH bash tools/check.sh`: compiles every script; specs (RoundRules, CarryMath, GirlMotion,
  GirlMoves, StabMotion, DownMotion, GirlRoll, CrateRoll, SpinWheel); **the full-game simulation** (`tools/sim/round_sim.luau`: real server code, bots
  that run, stab, lunge, rescue, use powers; 7 setups). `lune run huzz-valley/tools/sim/round_sim.luau audit` (repo root) prints the
  loop numbers (stage times, waiting, win rates by player count, on the real map size) for `docs/loop-audit.md`. Its stubs (e.g. `KnifeService`) must get any new function
  RoundService calls, or games stop with "attempt to call a nil value".
- `PATH=/root/bin:$PATH bash tools/preview/check.sh`: UI checks on the saved UI, then built from nothing.
  It prints harness errors too ("snippet error"): a silent missing count means a check script crashed.
- `PATH=/root/bin:$PATH LUNE=/root/bin/lune sh tools/place/build_place.sh`: regenerates `HuzzUI.rbxm`, both places,
  and sets Lighting.Technology = Future in the owner's place. Rebuild after every change.
- UI pictures: `cd tools/preview && NODE_PATH=$(npm root -g) LUNE=/root/bin/lune HUZZ_FRESH=1 sh shots.sh <out> <name>`
  (names in `shots.sh`: dance-wheel, shop-passes, shop-items, quests, spin-wheel, round-hud, hero-choice...).
  The preview draws Montserrat for Gotham, has no AutomaticSize, and ignores UITextSizeConstraint with TextScaled.
- 3D videos: `tools/preview/motion3d` (`sh video.sh <scene.luau> <out.mp4>`): `anim_scene.luau` plays any
  KeyframeSequence (`ANIM_FILE`, `ANIM_NAMES`, `ANIM_VIEW=back|side`); `dance_poses.luau` picks each dance's pose
  and writes `Config/DancePoses`; `aura_star_scene.luau`. Render.mjs loads `assets/fx` and two `assets/icons`.
- Ad-hoc harness tests: `lune run harness.luau ../../src - "$(cat test.luau)" setup_ui.luau`. Fake a character
  with Motor6Ds to test posing; stub `AnimationLibrary.id` to force code paths.
- Owner's place inspection with Lune (`deserializePlace`): maps are in `Workspace.Maps` (Base_Map, BasketBall_Map,
  Halloween_Map; zone parts named case/space-insensitively), the lobby floors are the 3 `Maps.Spawn.SpawnBaseplate`s.
  `lune run huzz-valley/tools/check_maps.luau [place.rbxl]` (repo root) lists maps, lobby pairs and safe lines.
  Lune can't read `.Position` on parts loaded from a place file: use `.CFrame.Position` in code it runs.

## 5. Code conventions (Luau)
- **Files:** `.lua` under `src/` (Rojo: `X.server.lua` = Script, `X.client.lua` = LocalScript, plain `.lua` =
  ModuleScript); `.luau` for `tests/` and `tools/`. Tabs, `local function`, typed signatures
  (`function DataService.update(player: Player, fn: (any) -> ())`). `--!strict` only where a file already has it.
- **Header comment first:** what the file does in plain words, with the owner's words in quotes and the reason for
  any odd choice. Keep it true when you change the file; this is how the next session finds things.
- **Module shape:** `local X = {}` ... `return X`; services expose `X.start()`. Server: `Bootstrap.server.lua`
  requires and starts services in order (add new ones there). Client: `Main.client.lua` builds each screen with
  `require(Screens.<Name>).build(gui)` inside `Report.run` from its list; `StartGameplay.client.lua` does
  `Gameplay/<Name>.start()` from its list. Add a new screen or gameplay part to the matching list.
- **Tuning lives in `Shared/Config/*`** (numbers, odds, prices, IDs, text), with a comment for each owner-picked
  value. Rules that can be tested live in `Shared/*` as pure functions with no Instances (then add a spec).
- **Server is the authority:** clients send intents through `Shared/Net` remotes; the server validates, rate-limits
  (per-player `last*` tables) and writes. Saved data only via `DataService.update(player, fn)`; new saved fields go
  in `DataService.Template` (`Reconcile` fills them for old saves). UI verbs go through `ActionService` `VERBS`.
- **Round state is attributes,** not extra remotes (section 7). Read them with `GetAttributeChangedSignal`.
- **Generated, never hand-edit:** `Shared/Images/**` and `ServerStorage/HuzzImages/**` (`tools/icons/pack_images.py`), `StarterGui/HuzzUI.rbxm` and
  `places/*.rbxl` (`build_place.sh`), `ServerStorage/HuzzAnimations.rbxm` (`tools/anim/extract_anims.luau`),
  `Config/DancePoses` (`motion3d/dance_poses.luau`), `Config/ImageIds` (written by the owner's upload helper).
- **Guard Studio-only APIs** with `pcall` so the Lune harness and Studio both run (list in section 10).

## 6. Recipes (the usual changes)
- **New remote:** add it to `SPEC` in `Shared/Net` and a line in the header table (it misses Stab, Power, Hero,
  Dash, Lunge today: add them when you touch it); `Net.get(name)` on both sides; validate every argument on the
  server; add a stub to `tools/sim/round_sim.luau` if RoundService uses it.
- **New screen:** `UI/Screens/<Name>.lua` with `build(gui)`, built from `Kit` helpers, opened through
  `ModalManager`; add it to Main's list; add a check in `tools/preview/` and a name in `shots.sh`; rebuild the place
  so `HuzzUI.rbxm` has the new parts.
- **New paid item:** a row in `Config/Products` (or `CoinShop` for coins) with `Id = 0` and `OnSale` false until the
  owner sends the real ID; grant only in `ShopService`'s ProcessReceipt; add the ID to the README checklist.
- **New image:** drop the owner's PNG in `assets/icons` or `assets/art`, run `python3 tools/icons/pack_images.py`,
  use it with `Kit.icon(name)` / `Kit.art(name)`. Names are case-sensitive in Roblox.
- **New sound:** add it to `tools/sfx/make_sfx.py`, regenerate, add the key to `Config/SoundIds` as "" and play it
  with `Sfx.play`; the owner uploads it later.
- **New quest stat or reward:** count it from a real server event with `ProgressService.addStat(player, stat, n)`; chapters in
  `Config/Progression`.

## 7. The round (`Shared/RoundRules` + `RoundService`)
- Lobby: `VoteTime` 30 s, `IntermissionTime` 25 s ("a bit more, so people can buy things, not too long").
- Stages: Waiting → Voting → Rolling (girl roller) → per round: Lineup → Picking (HERO/CHICKEN, 6 s) → Chosen →
  HeroRun → Countdown → Running → RoundOver; GameOver. Runners win with everyone across 3 rounds in a row.
  Loop audit (Oct 17, `docs/loop-audit.md`): half of everyone's time was frozen, so Lineup 3 s, ChooseTime 6, ShowTime
  2, RoundEndPause 2.5, and one runner on the line skips the roulette (PickAt is set back so clients skip it too).
- **Stalls** (`Config/Round.Hurry`, `RoundRules.stalling`): everyone still to cross standing in the start zone for 5 s
  → the clock drops to 6 s ("Hurry! Run or you're out"; `hurry()` moves EndsAt too). A Hero still in the start
  zone after 6 s loses the solo run ("X didn't go. Everyone runs!"; counting starts 1 s in, "Go now!" to the Hero at
  3 s). Not counted while trapped or on the line; a catcher or the bot within 10 studs of the zone buys 10 s.
- **Last runner** (`RoundRules.lastRunner`, `Speeds.LastRunner` 30): in a round that started with 2+ runners, the
  only one still out is called out once ("X is the last runner!") and runs as fast as the real catcher (the bot's
  speed when it catches; never under 28); with Rizz Rush capped at catcher + 4.
- **Catching:** click stab (`Stab` remote) or a catcher's **lunge** (`Lunge` remote, `Config/Round.Lunge`: Speed 56,
  Up 18, HitRange 4.8 for 0.5 s, cooldown 3 s shared with the Space tile `DashReady`; stab mode only). Both go
  through `stabNear()`: shields, the safe start zone and a fresh rescue protect; a Heart Shield ends the lunge.
- **Downed and revived:** a downed runner lies still (`KnockdownService`); a runner beside them for 1.2 s revives
  them. **One second chance per game** (`RoundRules` `rescued`): caught again = `Caught.final` → "YOU'RE OUT", no
  rescue; joins the catchers at round end. Their tag says OUT (grey) instead of HELP!, so nobody runs over for nothing;
  `HuzzOut` on the player makes their HUD say "OUT. You join the catchers next round".
- **Practice Bot** (`HuzzServer/PracticeBot`, `Config/Round.Bot`; owner picked "Yes, add bots", Oct 17): any round
  with runners and no catcher (alone, or the only catcher left) gets a server NPC catcher named "Practice Bot"
  (default blocky body from `CreateHumanoidModelFromDescription`, grey with a red shirt, tag CATCHER / BOT, a knife).
  Starts at Speed 24 and adapts (`Bot.Step` 2 slower after it wins a game, faster after it loses, 18 to 28; its
  Reach 5 scales with it; "is slower/faster this game" when its next game starts; back to 24 when the game's
  players change or the server empties; only games where it caught the last round count), stabs through `stabNear(nil, ...)`,
  1.2 s breather after each stab. If it
  downs everyone nobody wins ("THE BOT WINS", no girl, no winner's pay). With it, one player starts a game in the
  live game too (`minPlayers` 1). Red outline like catchers; round walls it follows a PathfindingService path (computed in a
  task.spawn when a raycast to the target hits something solid), and sidesteps when stuck. The sim tests it
  with a fake body.
- **Powers** (free each round, `Config/Powers`): runners Heart Shield + Rizz Rush; catchers Love Trap + Charm Wave.
- **Speeds** (`Config/Round.Speeds`, raised twice: lobby 22, runner 28, catcher 30, holder 27). `Gameplay/Sprint`
  eases out from a walk (9) to the cap (~95% after `Run.Ramp` 1.2 s). Run animation rate caps keep it calm.
- **Safe gate:** invisible goal-line block in collision group `HuzzSafeWall`, colliding only with `HuzzSafe`
  (safe runners), plus `keepSafe()` every frame.
- **Field edges:** safe lines, start wall and goal gate are trimmed to the real floor (`MapService` `edge()`); the
  invisible walls (`boundary()`) stand at the floor's edge (a prop doesn't count as an edge); `catchFalls()` puts
  anyone below the field back on it (only within 8 studs of it) or far below the lobby back to its spawn.
- **One lobby per map** (owner's pick, Oct 17): the owner built a lobby island in front of each map. Each map
  belongs to its nearest lobby (`entry.lobby`); after the vote `MapService.useLobbyFor` switches the lobby and
  RoundService moves everyone there after the load (streamed in first); only that lobby's SpawnLocation is on. With
  several lobbies a map loads exactly where it was built (the owner built floors level with their lobby); with one
  lobby, the old "in front of the lobby" placement. The paint fade runs when the map loads, once everyone is there.
  The floor finder accepts tops up to 2 studs over the Middle box (Halloween's grass sits above it).
- **Map look:** when a map wins the vote, `MapService.paintLobby` gives the lobby floor that map's floor colour,
  material and textures (the floor = the part found most under a 5x5 grid over the field; Halloween's orange is a
  Texture on its grass).
- **Results screen** (`Screens/Results`, Oct 17): after a game, once back in the lobby with nothing open (it waits out the map vote) a
  GAME OVER window: YOU WIN / YOU LOST / THE BOT WINS, who got the girl, cards for crossed / caught / saved / hero
  runs (this game only: RoundService `tally`, filled by `addStat`) and the coins + Aura earned (Round remote
  "Results", per player; coins include a Hero bonus, Aura the stars collected: player attribute `HuzzGameAura`).
  Preview: `shots.sh <out> results`.
- **Pay:** 15 coins a game, 35 for a win, +3 Aura on a win, Hero bonus 25; x2 while a wheel boost lasts.
- **Girl odds** (`Config/Round.Rarities`, raised: "I'm only getting commons"): Common 28, Uncommon 24, Rare 20,
  Epic 14, Legendary 8, Mythic 4.5, Secret 1.5.
- State lives in attributes (Round remote: Stage, EndsAt, Goal, Streak, PickId, HolderId, VoteWinner...; players:
  HuzzRole, HuzzStatus, DashReady, ProtectedUntil...; characters: DashAt/Dir, LungeAt, HuzzDance/At).

## 8. Feel and look
- `Config/Look` → `HuzzServer/LookService` ("find the filters that make the game feel premium"): colour grade
  (+saturation, +contrast), bloom, soft sun rays, light haze, lifted cool shadows, early-afternoon sun. Oct 17:
  less haze (Density 0.2, Haze 0.3, Glare 0) and more colour (Saturation 0.28, Contrast 0.14): the haze washed out
  the colours ("looks still a bit bland and plain").
- `Gameplay/Juice` (Oct 17): everyone sees a green ring + confetti when someone reaches safety, a red ring + sparks
  on a catch, a rising green column on a rescue; a small camera shake for you (off with Reduced Motion). The first
  runner safe each round gets "FIRST!" (RoundService `First` event after their Safe; RoundHud banner / small line).
- Oct 17 round 2 ("more cinematic", "less ui", "cutscenes dont cut out"): Juice shakes harder (caught 0.7, catch
  0.4, GO, own huss/lunge) and the screen edges glow red as a catcher comes within 40 studs (`HuzzDanger`, 1 Hz swell
  close up), getting caught tints your screen red for 0.7 s (`HuzzHit` ColorCorrection), and a huss leaves a short white
  trail; no letterbox bars in `Cinematic`; while running the prize card, the gear (not on touch: no Menu key)
  and Roblox's player list step aside. Footsteps are ours (`Feel`, Sfx "step", lobby too; Roblox's "Running" muted;
  stand-in thud until the owner uploads `step`). Button clicks: preloaded UI sounds, mouse clicks sound on press.
  Girl names (`Config/GirlNames`): real character names now (owner, after asking about copyright: "make the names
  normal again, don't use similar ones"); 10 unknown girls keep plain invented names until the owner names them.
- `Gameplay/Feel`: the camera widens up to 11° at full sprint (lobby too), a dash kick, soft wind streaks drifting
  outward near top speed (never flashing), dust and steps in rounds, a `speed_wind` loop. Off with Reduced Motion.
- The big showcase girl over the map glows softly (`AuraFX`: scale > 1.5 → small light, less LightEmission;
  "too much light shining down").
- `Gameplay/Cinematic` (line-up camera), `Gameplay/RoundHud` (round plate, message line, banners, "Second chance!"),
  `Screens/HeroChoice` (60% size: "make the boxes smaller"), `Screens/NextMap` (your vote tucks into a NEXT MAP panel).

## 9. Animations (the owner's files)
- `tools/anim/extract_anims.luau` → `ServerStorage/HuzzAnimations.rbxm`: Idle, Walk, **Run = the pack's Sprint as
  it is** (big arm swings; `docs/previews/run-arms-vs-hv.jpg`), Jump, Fall, Climb, **DashLeft/DashRight** (built: a
  compact sideways lean), and 25 `Dance_<Id>` (our own names; the originals are other games' emotes).
- `Shared/AnimationLibrary.id`: published ID, else in Studio a temporary ID (KeyframeSequenceProvider), else "".
  Temporary IDs play only on the client that made them. The live game needs `tools/studio/publish-animations.lua`.
- `Gameplay/Locomotion` blends Idle/Walk/Run by smoothed speed; walk fades into run as you hold W.
- **The girls on the pack** (`Shared/GirlMoves`, no upload needed): Bootstrap copies Idle/Walk/Run to
  `ReplicatedStorage.HuzzGirlMoves` in Studio AND live (~180 KB); the follower girl, your companion (both via
  `FollowMotion` `rec.moves`) and the prize's idle play them by hand, retargeted to R6 (`DanceRetarget`), blended by
  `LocomotionMix` with `Config/GirlMotion.Pack`. Planted feet: each straight leg aims its foot over the R15 foot, the
  body surges with the step (a lock measured from the loop, which also sets each loop's 1x speed) and is lowered
  onto the stance foot. Scripted `GirlMotion` walk/idle only until the folder arrives. Spec `tests/GirlMoves.spec`,
  video `docs/previews/girl-pack-walk.mp4` (`motion3d/girl_pack_scene.luau`).
- **The stab** (`Shared/StabMotion`, scripted until `Config/Animations.Stab` is uploaded; `Config/Round.Stab.Time`
  0.42 s): coil 0.11 s (hand back by the ribs, shoulders turned away, free arm forward), thrust in 0.06 s (body
  turns and leans into it, free arm snaps back), a 0.1 s held hit, follow-through. The knife arm is raised by the
  run's hunch so it stabs level while sprinting; the head counter-turns to stay on the target. Written after the
  animations (Frame order 30), so it sits over the run. Spec `tests/StabMotion.spec`, video `docs/previews/stab.mp4`
  (`motion3d/stab_scene.luau`). The Practice Bot's stab shows too: RoundService sends "Stab" `{ bot = true }` on a
  hit (and at most once a cooldown while it keeps trying); `Gameplay/Actions` plays it on the `HuzzBot` model.
- **Getting up** (`DownMotion.rise`, `Gameplay/Knockdown`): the server stands a revived player up at once; the
  client tips the body back down about the feet and eases it up over 0.4 s (no pop). Spec `tests/DownMotion.spec`.
- Dances: `UI/DancePlayer` (one at a time; walking stops it; **in step**: the `Dance` remote puts HuzzDance /
  HuzzDanceAt (server time) on your character, and starting the same dance within 30 studs of a dancer joins
  their beat). `Gameplay/CompanionDance` puts your dance on your R6 girl at your track's time.
- **Dance pictures** (`UI/DancePose`): your avatar posed by hand from the KeyframeSequence at the dance's best
  second, walking every joint (Motor6D, Weld, WeldConstraint, AnimationConstraint) and anchoring it. **No Animator,
  so no lag** (25 live animated viewports lagged). Used by the Dances cards and the wheel; note icon as fallback
  on the wheel. The **Dances window** follows the Oct 17 mockup (`docs/previews/dances-vs-mockup.jpg`): 3 column
  cards glowing in each dance's `Config/Dances` Color (our `dance-fx-*` notes), a `Blurb` line under the big picture,
  and a white blocky stand-in figure in the same pose (`dance-still-*`: `motion3d/dance_stills.luau` +
  `tools/icons/make_dance_stills.py`, re-run when the dances change) until your avatar's picture is ready.
  Favourites: saved `FavDances`, server-capped at `Dances.MaxFavourites` (12).
- **Dance wheel** (`Screens/DanceWheel`, the owner's taunt-wheel reference): 8 see-through dark circles round a big
  centre circle; pictures built ahead while closed; opens with one smooth grow (no CanvasGroup, no stagger).

## 10. UI rules (UI lives in StarterGui as real parts: owner's call)
- Build with `Kit.new` / helpers and `Parent`; saved parts are reused by name ("twins"), and the saved look wins.
- Windows 701 x 320, one at a time (`ModalManager`). `Kit.button` adds shade, outline and stud texture.
- **Never use CanvasGroup for animation** (it lagged). Fade with scale/position tweens instead.
- **Rounded corners:** Lune writes `UICorner.CornerRadius` only under newer per-corner names that Studio may not
  read, so the build also stores the size in attribute `HuzzRadius` and `HuzzClient/Main` restores it at start.
- Roblox gotchas the preview won't show: whole-pixel offsets; ClipsDescendants ignores UICorner; never key weak
  tables by Instance; picture names are case-sensitive; guard APIs Lune lacks (`Sound.Ended`,
  `CharacterAppearanceLoaded`, `LoadAnimation`, `ViewportFrame.CurrentCamera` reads) with `pcall`.
- Icons/art: the owner's files, used as drawn (`tools/icons/pack_images.py`, icons packed at 192 px).
- Shop passes copy the owner's banners (`design/shop/pass-banners.png`): navy glass rows, coloured rim and button
  per pass (`Products` `Accent`, Kit styles `PassViolet` / `PassPink`).
- **Living UI** (`UI/Effects`, owner: "more effects, like shining, spinning ... like in the game pass sections"):
  `shine` (white streak every 4-5 s: pass rows, buy buttons, coin cards, the HUD Shop button), `rays` (our
  `assets/art/light-rays.png` turning behind the Spin wheel, and green behind the HUD Spin button while a free spin
  waits; its icon spins and FREE breathes). Parts are saved twins but invisible until the loop starts; Reduced
  Motion stops all (`Effects.setCalm` from Main). Previews park streaks off the edge; `SHINE=0` freezes mid-sweep.
  Colours kept as the kit (Huss Valley look): the owner left a palette switch optional.

## 11. Economy: coins, Aura, shop, wheel, quests
- **Coins** buy looks in the Shop's ITEMS tab (`Config/CoinShop`: trails, name colours, knife skins). Items with
  `Unlock` (quest knives) or `NotForSale` (Spin Knife) are never sold. The COINS tab sells coin packs for Robux
  (cards after the Oct 17 mockup, `docs/previews/coins-vs-mockup.jpg`; art cut by `tools/icons/make_screen_art.py`,
  placeholders until sharp PNGs); its buttons keep the Robux mark, never a coin icon.
- **Aura stars** (owner's star art in `design/aura`, packed `AuraStar` + white `AuraStarWhite` for tinting):
  float only in the playing zone (map Middle, outside ZoneA/ZoneB: `MapService.playSpot`) while a map is loaded,
  none between games; **run through one to collect** (server checks distance 10x a second). Owner (Oct 17): "different
  colors give different amounts ... the ones that give more are rarer": Blue 1 (40%), Green 2 (25%), Purple 3 (16%),
  Pink 5 (10%), White 10 (6%), Rainbow 25 (3%); rarer stars are bigger and brighter. The Aura "+" buttons explain it.
- **Spin the Wheel** (`Config/SpinWheel`, `Shared/SpinRules`, `HuzzServer/SpinService`, `Screens/SpinWheel`): a
  real free spin every 15 min; packs of 1/10/100 for 48/340/1200 Robux (Developer Products, Id 0 until the owner
  creates them, granted only in ShopService's ProcessReceipt). Odds shown: 100 coins 28%, 250 coins 22%, 25 Aura
  16%, x2 Coins 15 min 12%, 500 coins 10%, 60 Aura 7%, 1,000 coins 4%, Spin Knife 1%; a Legendary is guaranteed by
  spin 40 (pity shown where the reference had a fake "daily discount"). While an x2 Coins boost lasts, a green
  "x2 COINS 12:33" tag sits over the HUD coin pill (`LobbyHud`, from the saved `Boosts.Coins` end time). Opens from the owner's wheel model (name
  contains "spin" + "wheel", or tag `HuzzSpinWheel`) or the SPIN button.
- **Lore quests** (`Config/Progression.Chapters`): 4 chapters x 2 quests with a story line, opened in order
  (server-checked). Rewards: coins, Aura and three quest-only knives (Rookie, Hunter, Moonlit). Stats from real
  events: Rounds, Crossings, AuraStars, Heroes, Rescues, Catches, HoldSeconds, Wins.
- **Cosmetic slots** (`CoinShop.Slots`: Trail, Tag, Knife, Aura, Title, Pose, Outfit; read with `CoinShop.worn(data, slot)`:
  `""` = taken off on purpose, nil = an owned Robux cosmetic of that slot is worn). Robux cosmetics carry `Slot` in
  `Config/Products`. **Rewards** (`Earn` items, Price 0): Secret/Mythic/Legendary girls give a title, aura and trail;
  Girl Collector, Huss Hero, Guardian from stats. `RewardService.sync` grants them (never over a paid look).
  Worn auras: `AuraLook.worn`; Crown Pose: `Shared/CrownPose` + `Gameplay/CrownPose` (cooldown); Midnight = tint + cape.
- **Effect pictures** (`assets/fx`, `tools/fx/make_fx.py`, guide `docs/vfx-guide.md`) load through `Shared/FxTexture`
  from uploaded IDs; until the owner uploads, stand-ins show and shapes gated by `FxTexture.ready` stay hidden.
- **Secret cutscene:** `Shared/SecretReveal` (timeline, pure) + `Gameplay/SecretReveal` (effects, camera); the server
  sets `RevealAt` and the `Reveal` stage. Test in Studio with `Config/Round.StudioTestRarity = "Secret"`.
  Oct 17 reference (`design/vfx/ref3`): twin light beams, crossing slashes, glowing eyes, a 0.09 s manga impact frame
  (ScreenGui, skipped with Reduced Motion), shards/streaks/butterflies (wait for upload). Framing sketch:
  `tools/preview/secret_sketch.py` (layout only; motion and glow need Studio).
- **Crates** (`Config/Crates`, `Shared/CrateRoll` with odds + pity) are plumbed but empty until the owner designs them.

## 12. Sounds
- 34 sounds made from scratch (`tools/sfx/make_sfx.py` → `assets/sfx/*.ogg`; all in a row in
  `docs/previews/sfx-preview.ogg`): warm, C major pentatonic, brightness under 2.5 kHz, even loudness.
- `Gameplay/Sfx.play(name, {volume, pitch, at})`, `Sfx.loop("speed_wind")`. `Config/SoundIds` stays "" until the
  owner bulk-imports the files in Asset Manager and sends the IDs (`tools/studio/collect-sound-ids.lua` prints
  them). Built-in stand-ins meanwhile, never pitched above 1.1; silence beats a squeaky ping.

## 13. Studio-only truths
- The cloud can't reach Roblox: uploads, real purchases and the final look are the owner's steps. The upload and
  sound helpers live in the place (`ServerStorage/HuzzStudioTools`, run with one `require(...)()` line); the
  owner's click-by-click guide is `docs/STUDIO-STEPS.md`. Studio helpers report on Output lines tagged `[Huzz]`, `[HuzzSfx]`, `[HuzzAnim]`.
- Not yet seen in Studio: the Practice Bot (its walk, run animation, knife), the Oct 17 UI shine/rays/spin and Juice bursts, the new lighting, stars in the playing zone, the move between lobbies after the vote (instant, no fade yet), the lunge feel, sprint feel, lobby repaint, knife positions, spin animation, dance
  pictures on real avatars, dance sync across two clients (needs published dances).
- **Testing rounds:** alone, the Practice Bot catches. For real players, Studio Test tab > Clients and Servers,
  2 or 3 players, and wait for the vote (about a minute).
- ProfileStore is in Mock mode in Studio (progress resets on Stop): on purpose.
- Scan any place the owner sends for scam scripts (`GetObjects`, `require(<id>)`, `loadstring`, HTTP);
  `SafetyService` strips the known Basket Ball Hoop one.

## 14. Open items (a running list; add to it as the owner reports more)
- Owner: Game Pass IDs (VIP 199, Dance Pack 149) and Developer Product IDs (Sunset Trail, Blossom Aura, coin
  packs, spins 1/10/100); upload sounds, pictures and animations; an export of their spin wheel model (match its
  colours); their 3D knife renders; power icons; a stab animation; crate contents; dance names; movement pack licence.
- Owner's place notes (Oct 17): no Uncommon girls yet (the rarity is skipped until there are some); a plank path
  near the Halloween lobby and a basketball hoop sit loose in Workspace (not in a map folder).
- Owner (Oct 17): Shop ITEMS/COINS, DANCES and HOW TO PLAY (`Screens/HowToPlay`, was `Welcome`: first join +
  Menu) built from the `design/ui-oct17` mockups (`docs/previews/*-vs-mockup.jpg`, `tools/preview/side_by_side.py`,
  checks in `tools/preview/check_oct17.luau`). Their pictures are mockup crops (placeholders): ask for sharp PNGs.
  His Secret cutscene reference (not sent yet). Not seen in Studio: Crown Pose, Midnight cape, worn auras, the
  cutscene, the Oct 17 screens.
- Us: whatever the owner's next round of fixes asks for first; then the Gift Picker, more lore chapters.
- Everything in sections 7 to 12 is the current version, open to change: tuning numbers (speeds, odds, prices,
  lunge, wheel prizes), looks and feel are first passes waiting for the owner's verdict in Studio.

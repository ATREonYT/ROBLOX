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
  in a round is a lunge** that catches whoever it reaches (forward, or sideways with A/D, never back: owner Oct 18
  "leaps forward/sideways to catch the person"); hold W = walk building into a run; G = dance wheel;
  Q/E = powers (catcher Q = Love Trap = the traps); click = stab; shift lock in rounds (Alt frees the mouse).
- **No girl toss** (removed). **Safe means safe:** once across you stay across. During a Hero run only the Hero and
  catchers move.
- **Companions are only girls you win** (the kit's Aiko/Ren/Sora/Hina mock-ups were removed). The equipped girl
  walks behind you on the ground, doesn't collide with you, and dances when you dance. Effects tiny below Legendary.
- **Knives:** everyone wears one (on the back; long slim blades at the hip, owner Oct 18 "for the katanas ... on the
  side"); catchers hold theirs in a round. The owner's own 30 knives (Oct 18,
  `design/knives/`) are the skins (section 11, "Knives"): calm effects by rarity, "dont make it overly crazy".
  Study of Huss Valley's knives (on the back at the belt, slash with no wind-up, catch = red fill, no sparks or shake)
  and the plan for his models: `docs/knife-study.md`, sheets `docs/previews/knife-study-*.jpg` (`tools/preview/knife_sheets.py`).
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
  `ProgressService`, `LeaderboardService` (lobby boards), `ShopService` (the one ProcessReceipt), `DataService` (ProfileStore; writes only via
  `update()`; `onChanged` hook), `SafetyService`, `Bootstrap`.
- `StarterPlayerScripts/HuzzClient`: `Main` (UI screens, each in `Report.run`), `StartGameplay` (Gameplay/*),
  `UI/{Kit,Theme,Scale,Motion,ModalManager,State,DancePlayer,DancePose,Toast}`, `UI/Screens/*`, `Gameplay/*`.
- `ServerStorage/HuzzAnimations.rbxm` (generated), `StarterGui/HuzzUI.rbxm` (generated: never edit by hand).
- `design/`: kit pages, the owner's art zips, `anims/` (movement pack + 200 dances), `aura/`, `shop/`, references.
- `places/HUSSANIME.rbxl` = the owner's own place as of Oct 18 (maps, girls, his **new Halloween lobby** in
  `Workspace > StartingPoint`, one copy in front of each map; his old lobby islands moved aside in `Maps > Spawn`);
  `HuzzValley-yours.rbxl` = it with all our code and UI swapped in (what the owner tests). Top-down plan of the
  lobby with our boards, stands and his props: `docs/previews/new-lobby-layout.jpg` (`tools/world/lobby_dump.luau` +
  `tools/world/lobby_plan.py`).

## 4. Checks, previews, builds (Lune 0.10.5 at `/root/bin/lune`; run before every commit)
- `PATH=/root/bin:$PATH bash tools/check.sh`: compiles every script; specs (RoundRules, CarryMath, GirlMotion,
  GirlMoves, StabMotion, DownMotion, Movement, Locomotion, PlayerMoves, GirlRoll, CrateRoll, SpinWheel, Leaderboards,
  Knives, KnifeWear, KnifeShapes, Sounds, SoundPicks, SetupKnives, AdminRules, StandShowcase, LobbyLayout, SetupLobbyProps); **the full-game simulation** (`tools/sim/round_sim.luau`: real server code, bots
  that run, stab, lunge, rescue, use powers; 7 setups). `lune run huzz-valley/tools/sim/round_sim.luau audit` (repo root) prints the
  loop numbers (stage times, waiting, win rates by player count, on the real map size) for `docs/loop-audit.md`. Its stubs (e.g. `KnifeService`) must get any new function
  RoundService calls, or games stop with "attempt to call a nil value".
- `PATH=/root/bin:$PATH bash tools/preview/check.sh`: UI checks on the saved UI, then built from nothing.
  It prints harness errors too ("snippet error"): a silent missing count means a check script crashed.
- `PATH=/root/bin:$PATH LUNE=/root/bin/lune sh tools/place/build_place.sh`: regenerates `HuzzUI.rbxm`, both places,
  sets Lighting.Technology = ShadowMap in the owner's place and saves Config/Look's Lighting, effects, Sky and Terrain Clouds into it
  (so Studio's edit view shows the game's look too). Rebuild after every change.
- UI pictures: `cd tools/preview && NODE_PATH=$(npm root -g) LUNE=/root/bin/lune HUZZ_FRESH=1 sh shots.sh <out> <name>`
  (names in `shots.sh`: dance-wheel, shop-passes, shop-items, quests, spin-wheel, round-hud, hero-choice...).
  The preview draws Montserrat for Gotham, has no AutomaticSize (it does draw TextScaled with UITextSizeConstraint and TextTruncate).
- 3D videos: `tools/preview/motion3d` (`sh video.sh <scene.luau> <out.mp4>`): `anim_scene.luau` plays any
  KeyframeSequence (`ANIM_FILE`, `ANIM_NAMES`, `ANIM_VIEW=back|side`); `dance_poses.luau` picks each dance's pose
  and writes `Config/DancePoses`; `aura_star_scene.luau`. Render.mjs loads `assets/fx` and two `assets/icons`.
- Ad-hoc harness tests: `lune run harness.luau ../../src - "$(cat test.luau)" setup_ui.luau`. Fake a character
  with Motor6Ds to test posing; stub `AnimationLibrary.id` to force code paths.
- Owner's place inspection with Lune (`deserializePlace`): maps are in `Workspace.Maps` (Base_Map, BasketBall_Map,
  Halloween_Map; zone parts named case/space-insensitively), the lobby floors are the plazas of the 3 copies of his
  new lobby in `StartingPoint` (`Shared/LobbyLayout.floors`; the old `Maps.Spawn.SpawnBaseplate`s are no longer used).
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
  with `Sfx.play`; the owner uploads it later. Clicks, the Secret cutscene and dance music are never made here:
  pick real licensed ones (section 12, `docs/sound-picks.md`).
- **New quest stat or reward:** count it from a real server event with `ProgressService.addStat(player, stat, n)`; chapters in
  `Config/Progression`.

## 7. The round (`Shared/RoundRules` + `RoundService`)
- Lobby: `VoteTime` 30 s, `IntermissionTime` 25 s ("a bit more, so people can buy things, not too long").
- Stages: Waiting → Voting → Rolling (girl roller) → per round: Lineup → Picking (HERO/CHICKEN, 6 s) → Chosen →
  HeroRun → Countdown → Running → RoundOver; GameOver. Runners win with everyone across 3 rounds in a row.
  Loop audit (Oct 17, `docs/loop-audit.md`): half of everyone's time was frozen, so Lineup 3 s, ChooseTime 6, ShowTime
  2, RoundEndPause 2.5, and one runner on the line skips the roulette (PickAt is set back so clients skip it too).
  Owner Oct 18 ("make the round a bit longer, for example the hero round"): HeroTime 30 (was 20), RoundTime 60 (was 45).
- **Power cards survive the Hero run** (owner Oct 18: "if you run out of time why dont you have any buttons
  after?"): after a Hero run RoundService calls `PowerService.clear(true)` (traps and effects go, cards and
  cooldowns stay); plain `clear()` had wiped PowerReady1/2, which hid the whole power bar (and the huss card) for
  the run that followed. The sim checks every runner/catcher still playing has PowerReady1 in Running/HeroRun.
- **Loop audit 2 (Oct 18, fixes in):** a catchers' win pays only catchers who caught someone (or the lead); the
  girl goes to the catcher with the most catches (lead breaks ties); XP every game (`Config/Progression.GameXP`:
  40 + 40 win + 25 a Hero run + 5 per crossing/rescue/catch; each level past the track pays `Beyond` 100 coins +
  10 Aura); Hero bonus only with another runner in the game (solo farming paid ~10x); Pay 25/50; a repeat girl
  pays `DupeCoins` by rarity; a chapter opens once ONE quest of the chapter before is claimed (solo players can't
  rescue or catch; the screen shows `Progression.shownChapter`); only runners pick up stars in a game; Results:
  CATCHES card, XP pill, "X takes her home"; Hero card "Make it: carry her +25", Chicken "Safe, but no girl".
  Not done yet (need screens): a Crates tab so Aura has a use, a dot on Menu when a quest can be claimed.
- **Countdown after a camera shot** (CHICKEN or no answer: owner, "the numbers just dont appear well"): RoundService
  adds `CAMERA_BACK` 0.6 s to a Countdown that follows Lineup/Picking/Chosen, so the camera's 0.3 s swing back ends
  first; RoundHud draws only the last 3 s, never while `HuzzCinematic` is on, times GO! from the server's EndsAt, and
  hides every HERO/CHICKEN tag word until GO! fades. Check: `tools/preview/check_countdown.luau`; strip
  `docs/previews/chicken-countdown.jpg` (`countdown_strip.py`).
- **Stalls** (`Config/Round.Hurry`, `RoundRules.stalling`): everyone still to cross standing in the start zone for 5 s
  → the clock drops to 6 s ("Hurry! Run or you're out"; `hurry()` moves EndsAt too). A Hero still in the start
  zone after 6 s loses the solo run ("X didn't go. Everyone runs!"; counting starts 1 s in, "Go now!" to the Hero at
  3 s). Not counted while trapped or on the line; a catcher or the bot within 10 studs of the zone buys 10 s.
- **Last runner** (`RoundRules.lastRunner`, `Speeds.LastRunner` 30): in a round that started with 2+ runners, the
  only one still out is called out once ("X is the last runner!") and runs as fast as the real catcher (the bot's
  speed when it catches; never under 28); with Rizz Rush capped at catcher + 4.
- **Catching:** click stab (`Stab` remote) or a catcher's **lunge** (`Lunge` remote, `Config/Round.Lunge`: eases 72 to 40 over 0.38 s,
  the way you steer: `Shared/KnifeLeap.direction`, forward or sideways with A/D, never back; the hit box points along
  the leap; a whole-body leap with the slash when the knife reaches someone (§9 "The lunge"); Up 24 (was 18: see §9), HitRange 4.8 for 0.5 s, cooldown 3 s shared with the Space tile `DashReady`; stab mode only). Both go
  through `stabNear()`: shields, the safe start zone and a fresh rescue protect; a Heart Shield ends the lunge.
  **Pinpoint** (owner Oct 18: "make hitboxes pinpoint"): the catcher's own screen picks the runner whose body is
  in a box in front of them (`Gameplay/HitCheck`; Stab Reach 5.5 x Width 4, Lunge 4.5 x 4) and sends that UserId
  (false = a miss); the server only checks it's possible (Range/HitRange + Slack 3, one runner per lunge). A client
  that sends nothing gets the old server search (the sim bots).
- **Catchers stay out of both safe zones** (owner Oct 18): `MapService.holdCatchers` stands an invisible wall on
  each zone's middle-facing edge for the whole game, group `HuzzCatcherWall`, colliding only with `HuzzCatcher`
  (catchers' parts, `MapService.setCatcher` from `syncPlayer`; the bot too); `keepSafe()` pushes out any catcher
  who got past (`MapService.pushOut`).
- **Chicken gets nothing** (owner Oct 18: "you dont recieve the girl if you run chicken"): a runner who chose
  Chicken (not a timed-out random pick) and never went Hero this game can't be handed the girl at the end
  (`RoundRules` `chickens`, `brave`: one Hero run keeps the claim); if every
  runner left chose Chicken nobody wins her ("Nobody went HERO", Results "Chicken gets nothing. Go HERO to win
  her!").
- **First across wins her when no Hero did** (owner Oct 18, later: "if you go chicken, still the first person to reach
  the safe zone gets the girl, right now nobody does"): after Chicken, a caught Hero or a timed-out Hero, while she
  still floats, the first runner across takes her (`RoundRules.reachSafe`, GirlMoved "First", "X got there first and
  won <girl> over!"), skipping whoever chose Chicken. A catcher holding her keeps her.
- **Downed and revived:** a downed runner lies still (`KnockdownService`; owner Oct 18: "not have a swinging animations
  ... make them lay on the floor and look like their dead"): `DownMotion` owns every joint (root, waist, hands, feet
  straight; arms out flat 125°, chin up 40°, no bounce, Lift 0.6), so the run playing underneath can't swing the
  body or push it into the floor. Spec: still and above the floor; picture `docs/previews/downed-still.jpg`
  (`motion3d/down_scene.luau`). A runner beside them for 1.2 s revives
  them. **One second chance per game** (`RoundRules` `rescued`): caught again = `Caught.final` → "YOU'RE OUT", no
  rescue; joins the catchers at round end. Their tag says OUT (grey) instead of HELP!, so nobody runs over for nothing (a downed tag shows to 250 studs, HELP! / OUT
  big; other tags hide past 80);
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
  sets off at 16 and reaches the cap in ~0.5 s (section 8). Run animation rate caps keep it calm.
- **Safe gate:** invisible goal-line block in collision group `HuzzSafeWall`, colliding only with `HuzzSafe`
  (safe runners), plus `keepSafe()` every frame. The start wall and the goal gate have no visuals any more (owner
  Oct 18: "get rid of laser wall"); the white lines on the floor mark start and finish.
- **Field edges:** safe lines, start wall and goal gate are trimmed to the real floor (`MapService` `edge()`); the
  invisible walls (`boundary()`) stand at the floor's edge (a prop doesn't count as an edge). Across the run the
  walls may go up to 40 studs past the zone boxes over the map's own level floor, and the loaded copy's zones are
  then stretched to the floor (Halloween's zones sat 15 studs off its floor: a wall cut the field and the girl wasn't
  centred, owner Oct 18). Loose Workspace parts resting on a map's floor move into that map at start (his Halloween
  path floated over the sea with another map on; `check_maps.luau` counts them); `catchFalls()` puts
  anyone below the field back on it (only within 8 studs of it) or far below the lobby back to its spawn.
- **One lobby per map** (owner's pick, Oct 17): the owner built a lobby island in front of each map. Oct 18 he
  replaced them with one new Halloween lobby ("I made it the lobby for all of the maps"), pasted in front of each map
  (`Workspace > StartingPoint`; the BasketBall and Halloween copies are pasted twice on top of each other). The game
  finds each copy's plaza (`Shared/LobbyLayout.floors`: the biggest flat part per copy, 124 x 136, top 12.5; copies on
  top of each other count once), so it's still one lobby per map, the new one everywhere; spawns are his
  SpawnLocations on each plaza (in `Maps > Spawn`). His old islands stay where he moved them, unused. Each map
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
- **Pay:** 25 coins a game, 50 for a win, +3 Aura on a win, Hero bonus 25 (not alone); x2 while a wheel boost lasts.
- **Girl odds** (`Config/Round.Rarities`, raised: "I'm only getting commons"): Common 28, Uncommon 24, Rare 20,
  Epic 14, Legendary 8, Mythic 4.5, Secret 1.5.
- **News vs big moments** (feel study, Oct 17): RoundService `announce(text, color)` only writes the message line
  (no "big" flag; colour = green good news, red caught/out, white news, rarity colour for the prize). Centre words
  are RoundHud's own: 3-2-1, GO!, SAFE!, FIRST!, YOU'RE DOWN/OUT, BACK UP!, the win and "<girl> IS YOURS".
- State lives in attributes (Round remote: Stage, EndsAt, Goal, Streak, PickId, HolderId, VoteWinner...; players:
  HuzzRole, HuzzStatus, DashReady, ProtectedUntil...; characters: DashAt/Dir, LungeAt, HuzzDance/At).

## 8. Feel and look
- `Config/Look` → `HuzzServer/LookService` ("find the filters that make the game feel premium"): colour grade,
  bloom, soft sun rays, light haze (Density 0.2, Haze 0.3), lifted cool shadows, early-afternoon sun. Feel study
  (`docs/feel-study.md` gap 3): the floor was blown out (brightness 0.76 to 0.87, 35 to 48% clipped vs HV 0.62 / 15%),
  so Brightness 2.8 → 2.0, Exposure +0.15 → -0.1, grade Contrast 0.12, Saturation 0.35 (estimate:
  `tools/preview/feel/look_estimate.py`, lobby ~0.64, round ~0.72). Map parts keep the owner's colours.
  Owner Oct 18 ("that brighter contrast ... but not too much contrast so it looks normal"): Brightness 2.0 -> 2.2,
  Ambient 92,96,112 -> 96,100,116, OutdoorAmbient 128,130,148 -> 132,134,152, Exposure -0.1 -> -0.05, grade Contrast
  0.12 -> 0.16, Saturation 0.35 -> 0.4 (estimate on his lobby frame: brightness 0.65 -> 0.70, contrast +8%, nothing
  clipped; 2.3 / 0 / 0.18 / 0.42 clipped a third of the floor). Picture `docs/previews/lobby-look-before-after.jpg`
  (`tools/preview/feel/look_before_after.py`: a model of the grade, not a render).
- **Even, cartoony light** (owner Oct 19: "make the lighting be one to one as the game, you see how the objects dont
  have light only around them, there is even, nice, cartoony lighting over the map"; reference
  `design/lobby-ref/oct19-lighting-ref.png`). Measured there (`tools/preview/feel/light_measure.py`, boxes
  `boxes_ref_oct19.json`): a cast shadow keeps 0.53 of the sunlit floor, a block's shaded side 0.82 of its lit top,
  shade a little blue (+53), sky 87,178,249. Ours (Oct 17 recording, `boxes_our_oct17.json`) kept 0.25: a strong sun
  over a weak sky fill, plus **Future** lighting, which gives every PointLight its own pool and shadows. Now:
  **Technology ShadowMap** (`build_yours.luau`; sun shadows stay, lamps light softly with no pools or shadows of
  their own), Brightness 2.2 -> 1.4, ClockTime 14.2 -> 13, latitude 28 -> 23, Ambient 96,100,116 -> 150,150,160,
  OutdoorAmbient 132,134,152 -> 210,210,218, EnvironmentDiffuseScale 0.6 -> 1 (the blue-ish shade),
  EnvironmentSpecularScale 0.5 -> 0.2, ShadowSoftness 0.35 -> 0.6, Exposure -0.05 -> +0.05, grade Contrast 0.16 ->
  0.05, Saturation 0.4 -> 0.12 (orange floors went neon), Bloom 0.55/22/1.5 -> 0.4/24/1.6, SunRays 0.05 -> 0.03.
  Our lamps turned down so the glow stays on the object: lobby props 1.4/12 -> 0.5/7 (fainter pad pools), board
  pumpkin/candle/base 0.8/7, 0.5/5, 0.6/9 -> 0.4/5, 0.3/4, 0.3/6, aura stars 1.2+0.25t / 9+1.5t -> 0.6+0.15t / 6+t,
  the showcase girl's key/rim/stand 2.2/1.1/1.4 -> 1.5/0.8/1.0. The board slab is now his daylight slate (section 11,
  "Lobby leaderboards"). SecretReveal's night look also sets EnvironmentDiffuseScale 0.25 (put back after).
  Model (`tools/preview/light`: `render_light.mjs` three.js scene from `tools/world/scene_dump.luau`, calibrated so the
  Oct 17 look gives the measured 0.25; `calibrate.py`, `looks.json`, `light_compare.py`): cast shadow / sun 0.29 ->
  0.51 (reference 0.53), sunlit floors as bright or brighter. Picture `docs/previews/lighting-vs-ref.jpg` (a model,
  not a render). Light audit of his place: `tools/world/light_audit.luau`.
- **Sky** (owner Oct 19: "try making the skybox better for the better lighting experience"; same reference: saturated
  blue overhead, big soft white clouds low down, a clean horizon). No uploads: Roblox's built-in sky stays (his place
  sets no skybox IDs; no store skybox ID was found that we could verify), `Config/Look.Atmosphere` paints it bluer
  (Color 178,214,255 at the horizon, Decay 85,165,245 above, Density 0.22, Offset 0.25, Haze 0.3), `Look.Sky` (sun
  14, stars 3000; made in Lighting if missing) and `Look.Clouds` = real 3D Terrain Clouds (`Workspace.Terrain >
  HuzzClouds`: Cover 0.4, Density 0.75, white). LookService applies them; the place build saves them. Model
  `docs/previews/sky-vs-ref.jpg` (`tools/preview/light/sky_model.py`: a model, not a render; its skybox colours are
  read off the reference, its clouds are flat blobs). A proper cartoon skybox would need 6 face pictures uploaded.
- `Gameplay/Juice`: one world effect per moment beside the message line (study gap 15): confetti on safe, a quick red
  spark burst on a catch, a green ring lifting off the floor on a rescue, hearts and sparkles in the girl's rarity
  colour round the winner (knife pass 2: the catch's burst is now a thin cut line and 10 sparks in the catcher's knife
  colour; the red read is RoundHud's red fill, §9 "The catch"). Shakes only for being caught, catching and GO (none on a huss or lunge: HV has none). The
  first runner safe each round gets "FIRST!" (RoundService `First` event; RoundHud).
- **Powers** (`Gameplay/PowerEffects`, `Config/Powers.Fx`, the other game's ability timing): a glow builds (0.25 s;
  Shield and Rush 0.15 s), one bright frame (`Gameplay/Burst.flashOk`: at most one a second per screen), the effect
  0.35 s, a 0.15 s fade; white core → pink → purple. Shield: a bubble bursts out; Rush: a ring standing up behind you
  and white speed lines; Trap: the glow drops and a ring slams round the trap; Charm Wave: a ring gathers, then two
  rings run out (its slow lands when they do: PowerService waits `Fx.WindUp`). Each has a sound; others' powers pop
  their name over them (root +7, clear of their name tag); during the wind-up the caster strikes a cast pose (both arms
  forward and up 60°, a 10° lean: `Run.Cast`, drawn by `RunMotion` on everyone via `RunAnimator`, local attributes
  HuzzCastAt/Len); your Q/E tile squashes on press and glows pink when the server takes it. Charm Wave: 16 pieces a
  ring, no haze, every ring's pieces moved with one `Workspace:BulkMoveTo` a frame (`Burst.bulkMove`). All plain neon parts
  (`Gameplay/Burst`: real rings of short pieces, glow orbs, world text), so nothing waits for an upload. Film:
  `motion3d/power_scene.luau` → `docs/previews/powers.mp4`, `feel-powers-after.jpg` (`tools/preview/powers_vs_og.py`).
- Oct 17 round 2 ("more cinematic", "less ui", "cutscenes dont cut out"): Juice shakes harder (caught 0.4, was 0.7: it stacked
  with the red tint; catch 0.4, GO) and the screen edges glow red as a catcher comes within 40 studs (`HuzzDanger`, 1 Hz swell
  close up), getting caught tints your screen red for 0.7 s (`HuzzHit` ColorCorrection) (the huss's white trail is gone:
  `Feel` draws HV's thin speed lines); no letterbox bars in `Cinematic`; while running the prize card, the gear (not on touch: no Menu key)
  and Roblox's player list step aside. Footsteps are ours (`Feel`, Sfx "step", lobby too; Roblox's "Running" muted;
  stand-in thud until the owner uploads `step`). Button clicks: preloaded UI sounds, mouse clicks sound on press.
  Girl names (`Config/GirlNames`): the owner's own list (Oct 18), matched by the code at the end of each model's name
  (e.g. `_E2B52D` = Rem); Alya, Rize, Waguri, Yui and Miku Nakano had no code match and are best guesses (header).
- **Movement and camera vs Huss Valley** (Oct 17, `docs/feel-study.md` gaps 4-9 and 14; spec `tests/Movement.spec`):
  - `Gameplay/Sprint`: you set off at `Run.StartSpeed` 16 and reach the cap in ~0.5 s (`Ramp`; was 9 over 1.2 s).
  - The huss (`Gameplay/Dash`): left/right along the **camera's** right; the body eases (0.08 s) to the nearer way
    along the camera's line (never a snap, at most a quarter turn; none in shift lock). The push eases every frame
    from `Round.Dash` Speed 64 to EndSpeed 28 over 0.30 s (`RunMotion.pushSpeed`: 12 studs, owner Oct 18 "a bit further"; was 9).
    The server takes the sent facing within 150° (was 110°). The lunge eases the same way (72 to 40 over 0.38 s,
    19 studs, the old reach).
  - `Gameplay/Feel`: +2° FOV at full sprint (was 11°), held through a huss; no huss FOV kick, no screen-edge
    streaks or line ring. A huss draws 6 thin white Beams riding with whoever husses (`RunMotion.hussLines`,
    `Run.Dash.Lines`), seen by everyone near. Dust, steps, a `speed_wind` loop. Reduced Motion turns off the FOV.
  - Round camera (`Gameplay/Cinematic` + `Shared/CinematicShot`): the hand-back lands where Roblox's camera will be
    (zoom 12, 14° down, the shift-lock offset only when `ShiftLock.wouldLock()`: same test as ShiftLock, so not with
    Alt held, a menu open or the dance wheel up; zoom pinned for that moment), then zoom is capped at 22 in rounds; the
    lobby keeps the place's limits. You are ~31% of the screen tall, the horizon ~32% from the top.
  - Shot changes: one 0.25 s quart swing that orbits round and over the runners (`Shot.transition`, at least 4
    studs over heads), the eye pulled in front of walls and the floor (`clear()`). Secret cutscene hand-back: a
    0.2 s dip to black; once fully black the camera goes back to Roblox (Custom) behind where you stand now (your old
    angle and distance), black holds 2 frames, then lifts (no fly-back, no cut on a clear screen).
  - Film: `HUSS_ONLY=1 sh video.sh ramp_scene.luau out.mp4`, sheet `motion3d/huss_sheet.py` →
    `docs/previews/feel-huss-after.jpg`. Not seen in Studio yet.
- The big showcase girl over the map (`GirlService.showcase`, study gap 12: she read as a dark blob) stands on a small
  stand with a glowing band in her rarity colour (never wider than her stance: "the rings hid her from below"; inside
  her Aura box, so the cutscene's bounds don't change), a key light low in front (-0.3 x her height, Brightness 1.5 since Oct 19, was 2.2: she
  read dark from the field), a rim light behind, a soft glow up from the stand (short ranges, nothing above her: "too
  much light shining down"), and her name big in her rarity colour over her head (1.8 studs x scale
  above it, so her head doesn't cut the line seen from below; a pixel floor so it reads from the far end; stars white). Only her root is anchored: every client plays the
  pack's Idle on her (`CarryAnimator`) and hides the stand and its lights during the Secret cutscene. Her aura glows
  softly (`AuraFX`: scale > 1.5 → small light). Your companion steps in and out behind a puff of sparkles (`Auras`).
  Smoke tests: `tools/preview/smoke_showcase.luau`, `smoke_feel_fx.luau` (harness).
- **The girls' effects** (Oct 18, owner: "they still look strange and low quality ... they just float there";
  `AuraLook.girl` → `Gameplay/AuraFX`, for your companion, the round's girl and the prize): anchored to her and the floor
  like the pro references (`design/vfx/vysvex-green-reference.mp4`, ref3, Soul Reaper): a light pool + crisp ring flat
  under her feet (SurfaceGui circles on a thin part in `Workspace.HuzzAuraFX`, outside her model; it follows her lower
  foot, swells as she breathes, a highlight runs round the ring; on the prize it lights her stand top; hidden while
  carried or while `HuzzRevealing`), flame tongues wrapped round her (critic: "two thin pastel stalks" before; Beams
  twisting up from her feet, curling in over her, staggered heights, the ring turning slowly, saturated, a white-hot
  inner ring behind her outline; outer ZOffset small, so they cross her legs but not her face), orbiting neon balls
  with Trails (trails off while she walks), trails on feet/hands only while she moves, puffs per
  stride, streaks rising off the floor, and a beat (draw in 0.35 s, flare, a ring runs out, sparkles; Mythic up a
  crescent slash) every 3.6/3.0/2.6 s. Carried: nothing on or from the floor (no pool, floor particles, puffs or foot
  trails). Streamed-out parts: Auras drops the effects and rebuilds them when she streams back.
  Ladder: Common = calm pool + 1 emitter; + ring (Uncommon); + runner, element, puffs, glow, 2 small calm tongues
  (Rare; owner picked "Small flames": same wrap and turn, end at her waist to chest, thin, soft, no core, no beat);
  + 1 orb, breathing, 3 small tongues (Epic); + big flames with a white-hot core, beat, 2 orbs, foot trails (Legendary,
  6 emitters); + slash,
  hand glints/trails, 3 orbs (Mythic, 7); + two tones, crystals, butterflies, halo, 4 orbs (Secret, 9; budget 12).
  The prize gets at least the Rare look. Only the particles wait for uploads; everything else shows today.
  Calmer (owner Oct 18, "a bit more lowkey for some"): Legendary 4+1 tongues, Mythic 5+2, Secret 6+2, shorter,
  fainter (outer alpha 0.4), softer lights, fewer streaks. Worn auras: flame particles move with the body
  (inherit 0.95; at 0.4 a running player trailed a long glowing band), smaller, half the rate, half the light.
  Spec: `check_girl_fx.luau` (budget, ladder, Rare/Epic tongues smaller and fewer than Legendary's, beat, pool follows,
  no per-frame instances). Tier row `motion3d/girl_tiers_scene.luau` + `tools/fx/girl_tiers_sheet.py` →
  `docs/previews/girl-vfx-tiers.jpg`. Film
  `motion3d/girl_vfx_scene.luau` → `docs/previews/girl-vfx.mp4`; sheet `tools/fx/girl_vfx_vs_ref.py` →
  `girl-vfx-vs-ref.jpg`. Your own aura when she's equipped ("Player") and worn auras keep the older emitter look.
- `Gameplay/Cinematic` (line-up camera, above), `Gameplay/RoundHud` (text-only top, coloured message line, big banners only for big moments; section 7/10),
  `Screens/HeroChoice` (60% size: "make the boxes smaller"), `Screens/NextMap` (your vote tucks into a NEXT MAP panel).
  Map pictures (owner Oct 18): `Config/Round` `Map.Pictures` names the `Config/Assets.Art` picture per map folder
  (Base/Halloween/BasketBall from `design/maps/`, packed 512 px, Play only until uploaded); a map not listed shows its live 3D view.

## 9. Animations (the owner's files)
- `tools/anim/extract_anims.luau` → `ServerStorage/HuzzAnimations.rbxm`: Idle, Walk, **Run = the pack's Sprint as
  it is** (big arm swings; `docs/previews/run-arms-vs-hv.jpg`), Jump, Fall, Climb, **DashLeft/DashRight** (built: a
  compact sideways lean), and 25 `Dance_<Id>` (our own names; the originals are other games' emotes).
- `Shared/AnimationLibrary.id`: published ID, else in Studio a temporary ID (KeyframeSequenceProvider), else "".
  Temporary IDs play only on the client that made them. The live game needs `tools/studio/publish-animations.lua`.
- **Everyone walks with the pack, Studio and live, nothing uploaded** (owner Oct 18: "player to player less choppy",
  "make the walking animations way way better"): `Gameplay/Locomotion` plays Idle/Walk/Run on your own Animator when
  it can (Studio); `Gameplay/PlayerMoves` (Frame order 8) samples the same three from `HuzzGirlMoves` by hand onto
  every other R15 body's Motor6D.Transform (and yours in live), blended by `LocomotionMix`. Others' speed comes from
  their body's position over a 0.25 s window (`LocomotionMix.track`, `Run.Track`: holds through 0.15 s network stalls,
  ignores teleports), never their replicated velocity (that jumpy number made the old scripted legs stutter). Fades
  out for a dance/Action track; downed = speed 0 under the knockdown; carriers' arms go to CarryAnimator. LOD:
  re-sampled every frame within 70 studs, 30/s to 160, 15/s beyond or behind the camera. `RunAnimator` now draws only
  the huss and cast on top (`dashOnly`); its scripted run shows only before the pack's folder arrives.
- **Planted feet** (`Config/Run.Loco`, measured by `motion3d/pack_measure.luau`): the pack Walk keeps its foot still at
  4.35 studs/s (`WalkAt` 4.3, was 8), the Run at 14 (`RunAt` 14, was 25); walk hands over to run at 6-11 studs/s (was
  13-21, so the walk skated at half the ground speed at the 16 you set off at). Foot slide is under 5% up to 16
  studs/s; the run is capped at 1.12x = 4.6 steps/s (HV's), so at 28 the feet slide ~44% like HV's quick steps. Speeds
  scale with avatar size (`RootHeight` 3). Specs `tests/Locomotion.spec` (pure maths) and `tests/PlayerMoves.spec`
  (the real Gameplay files on fake bodies). Film `docs/previews/remote-walk.mp4` (`motion3d/remote_walk_scene.luau`:
  before/after over a jumpy network, then the set-off from behind); sheet `docs/previews/walk-vs-hv.jpg`
  (`motion3d/walk_sheet.py`): full run ~0.1 s after W in both. Footstep sounds (`Feel`, `Run.Stride` 12) still step
  by distance, so below ~28 they're slower than the feet. Not seen in Studio yet.
- **The huss pose is `Shared/RunMotion`'s for everyone, you too** (`Gameplay/RunAnimator` draws only the huss on your
  own character when your run is the pack's): a wide low crouch (Oct 17 critic: "a stiff tilt"): Crouch 0.75 (head
  drops 19%), leaning ~28° mostly at the waist (`Run.Dash` SideRoll 12 + SideWaist 14), outside leg out 55°, inside
  thigh up 45° and out 42°, knee -80; held to 0.30 s, upright by ~0.42 s. Still narrower and higher than HV's flat
  straddle (`docs/previews/feel-huss-after.jpg`). Your own huss's server DashAt is ignored within 0.6 s of your
  local one (`RunMotion.dashAt`, local attribute HuzzMyDashAt), so a laggy echo never restarts the lean or lines. The built DashLeft/DashRight (38° lean) plays only once the owner
  publishes a run (`Config/Animations.Run`); re-extract with a smaller lean before then.
- **The girls on the pack** (`Shared/GirlMoves`, no upload needed): Bootstrap copies Idle/Walk/Run to
  `ReplicatedStorage.HuzzGirlMoves` in Studio AND live (~180 KB); the follower girl, your companion (both via
  `FollowMotion` `rec.moves`) and the prize's idle play them by hand, retargeted to R6 (`DanceRetarget`), blended by
  `LocomotionMix` with `Config/GirlMotion.Pack`. Planted feet: each straight leg aims its foot over the R15 foot, the
  body surges with the step (a lock measured from the loop, which also sets each loop's 1x speed) and is lowered
  onto the stance foot. Scripted `GirlMotion` walk/idle only until the folder arrives. Spec `tests/GirlMoves.spec`,
  video `docs/previews/girl-pack-walk.mp4` (`motion3d/girl_pack_scene.luau`).
  Oct 18 "so choppy": the small companion sprinted at 9 steps/s (legs jumping 44° a frame) and the lock jolted her
  body every step. Now at most `Pack.MaxSteps` 4.8 steps/s, the lock rounded off and faded as her feet slide
  (`Pack.Surge`): 23°/frame, no jolts (`motion3d/girl_smooth_measure.luau`; limits in the spec).
- **Carried girls** (Oct 18 "not just be held straight up like that"; `GirlMotion.carried`, `Config/GirlMotion.Carried.Pose`):
  she sits up in his raised hands (upper body up 24°, legs bent up 62° at the hips, R15 knees bent, arms half
  hanging), dips and dangles on his real footfalls (`CarryMotion` reads his right hip), swings her feet, a small kick,
  wave or look round now and then; calm (under 6° a frame). Spec `tests/GirlMotion.spec`. Before/after film
  `docs/previews/girls-walk-carry.mp4` (`motion3d/girls_walk_carry_scene.luau`). Not seen in Studio yet.
- **The stab** (`Shared/StabMotion`, scripted until `Config/Animations.Stab` is uploaded; `Config/Round.Stab.Time`
  0.40 s, Huss Valley's slash from `docs/knife-study.md`): no wind-up; the arm sweeps out to the right side, landing
  at ~0.07 s, held out (free arm pointing ahead) to 0.24 s, back by 0.40; trail on 0.02 to 0.45 of it. The knife arm
  is raised by the run's hunch so it slashes level while sprinting. (The lunge is its own move now: below.) Written after the
  animations (Frame order 30), so it sits over the run. Spec `tests/StabMotion.spec`, video `docs/previews/stab.mp4`
  (`motion3d/stab_scene.luau`). The Practice Bot's stab shows too: RoundService sends "Stab" `{ bot = true }` on a
  hit (and at most once a cooldown while it keeps trying); `Gameplay/Actions` plays it on the `HuzzBot` model.
  Oct 19 (owner: "better knife animations, not only during gameplay"): same timing and still no wind-up, but the
  wrist snaps the blade flat into the sweep and the body leans in a little more; a Game Pass knife's trail is in its
  element's colours, lasts 0.17 s (`KnifeLook.TRAIL.ElementLifetime`) and tapers; Epic and up draw a thin crescent
  round the front and right of the catcher (`KnifeLook.ARC`: a Beam on two root attachments, gone in 0.2 s, never
  solid) and a pass knife throws half its element's burst (`KnifeBurst`). Before/after film
  `docs/previews/stab-before-after.mp4` + `.jpg` (`motion3d/stab_fx_scene.luau`, `STAB_OLD` = the old module copied
  next to the new one). Honest: the arm change is small; the arc reads faintly in the render.
- **The lunge** (knife pass 2, Oct 19, owner: "give them a good vfx, make them have good animations, the leaping, the
  killing ... take your time"; `Shared/StabMotion` `LEAP`, `play(rec, now, true)`). Why: before, the lunge was the click
  slash at take-off with the legs still running, a 0.18 s hop and a 35° waist dive only after landing, so it read as a
  stumble; and your own lunge waited for the server's echo (a round trip late). Now:
  - **Your own lunge plays the moment you press Space** (`Gameplay/Dash` calls `Actions.lungeLocal` before its hit check;
    the server's "Stab" echo within 0.8 s is ignored). Everyone else plays it from the server's "Stab" `{ lunge = true }`.
  - **The whole body leaps** (it owns the root joint and the legs as well as the waist, head and arms, then hands them
    back by `LEAP.Up` 0.72 s): no crouch first (the push is already moving at 72), the take-off pose blends in over
    `In` 0.12 s (4 frames at 30 fps, so no pop); the body tips 18-22° into the leap about the hips, the lead knee drives
    up (left leg forward; the side's own leg on an A/D leap), the back leg pushes off long behind and tucks in the air.
  - **The knife leads**: the arm reaches ahead, the blade level and pointing forward (`REACH`), the free arm back.
  - **The slash lands when the knife reaches someone**: `StabMotion.slash` from `Dash` (your screen's hit check) or from
    the server's "Caught" (everyone else's, so it lines up with the runner's fall there); if it reaches no one, at
    `SlashBy` 0.14 s. The sweep goes from the reach out to the right in 0.07 s, then the click slash's overshoot, hold
    and return. The slash trail, `KnifeLook.ARC` crescent and the `KnifeBurst` start with the slash, not at take-off.
  - **Landing**: at the hop's end (`StabMotion.air()` = 2 x Up / 196.2) the body drops into a low lunge, tipped ~34°
    into the leap, lead foot ahead, back knee low; the hips come down by exactly what keeps the feet on the floor
    (`lowestFoot`, from the joints' C0/C1, not the parts, which lag a frame). Held to `Out` 0.47 s.
  - **Up 24, was 18** (`Config/Round.Lunge`): at 18 the body was off the floor 0.18 s (5 frames) and 0.8 studs high, too
    short to show a take-off, a knife leading and a landing; HV's catcher is in the air ~0.4 s. 24 = 0.245 s, 1.5 studs.
    The push (72 to 40 over 0.38 s, 19 studs) and the hit box are unchanged.
  - **The leap's ribbon** (`KnifeLook.CATCH.Streak`, HV's lunge ribbon): a Trail between two points on the UpperTorso,
    white into the knife's colour (its `SlashColor`, else steel white), 0.14 s long (~8 studs at the leap's speed), on
    for the push only (`Gameplay/Actions`).
  - Spec `tests/StabMotion.spec` (leans in, never back; knee ahead and back leg behind; knife ahead with the blade
    forward; slash within 0.08 s of reaching someone, at SlashBy otherwise, before landing; lands tipped >28° with the
    feet on the floor; sideways tips and leads with that leg; body parts turn at most 16°/frame at 60 fps and 30° at
    30 fps; every joint handed back).
- **The catch** (knife pass 2; HV's read from `docs/knife-study.md` section 4, players read "catch", never "kill"):
  - **Red fill** on the caught runner (`Gameplay/RoundHud`, on their team Highlight, everyone's screen,
    `KnifeLook.CATCH.Fill` / `catchFill`): FillTransparency 0.12 for 0.07 s (HV's 2 solid frames), up to 0.6 by 0.25 s,
    gone by 0.42 s. The solid frames only through `Burst.flashOk` (one flash a second per screen), else the tint only.
    Then a **red outline while they lie down** (refreshHighlight: Runner + Downed = red; they used to lose theirs).
  - **Knife-colour touches** (`Gameplay/Juice`, one each per catch, calm): a thin cut line drawn on across the runner's
    back in 0.06 s and gone by 0.26 s (a Beam on their UpperTorso, so it falls with them) and 10 sparks, both in the
    catcher's knife colour. They replaced 30 red-and-white sparks (generic, and HV has none). Your own screen keeps
    the red tint (`HuzzHit`) and the shakes (owner asked for shake).
  - **The runner reacts, then falls with momentum** (`Shared/DownMotion`): the hit (`HIT`: in 0.1 s the back arches,
    head back, arms fly up and out, knees buckle; at its fullest before the body has tipped 10°, gone by 0.34 s), and
    the body slides on `Knockdown.Slide` 2.2 studs as it falls (fast, then settling; it used to stop dead from a sprint).
    The server shortens the slide before a wall (`KnockdownService`: raycast ahead, the character's `DownedSlide`);
    clients, the server's final placement, standing up and the rescue range all use it.
  - Spec `tests/DownMotion.spec` (the hit at once, before the tip; slide fast at first and done by the landing; no
    slide = the old fall; no part over 45°/frame at 30 fps).
  - Film `docs/previews/catch-before-after.mp4` (30 fps: side view, the catcher's camera, the runner's camera; before
    left, after right; full speed then 1/4 speed) and `catch-before-after.jpg`, from `motion3d/catch_scene.luau`
    (`CATCH_OLD=1` loads `StabMotionOld`/`DownMotionOld`: copy the old modules next to the new ones to re-render the
    before, then delete them; `CATCH_VIEW` = side / catcher / runner).
  - Honest: not seen in Studio yet. The preview draws the red fill by recolouring the parts (Studio's Highlight fill is
    an overlay) and draws particles additively, so bursts over the sky look whiter than in Roblox. The run animation
    under the leap is the pack's, so the take-off blend in Studio starts from a mid-stride pose the spec doesn't test.
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
- **Text must fit its box** (owner: "the rarities ... go out of the uis borders"): never leave a name or chip on
  AutomaticSize in a row with no width cap. `Kit.textWidth` (TextService, else a Montserrat estimate),
  `Kit.fitLine(label, maxW, size, min, keepBox)` (shrink, then "..."), `Kit.fitBlock` (two lines), `Kit.badge`
  (rarity chip, measured and capped). Set sizes after `Kit.new` (saved twins keep their saved look). The Index
  preview gives the name the whole 128 px column and puts the rarity chip on the picture's top-right corner, like
  the cards. Check: `tools/preview/overflow.sh` (in `check.sh`; `overflow.js` flags text past its box, window,
  panel or the screen, and text on text, on every `shots.sh` screen plus the long-name shots `index-girls*`,
  `tiers-girls`, `*-long`). The preview now draws TextScaled with its UITextSizeConstraint and TextTruncate.
- Shop passes copy the owner's banners (`design/shop/pass-banners.png`): navy glass rows, coloured rim and button
  per pass (`Products` `Accent`, Kit styles `PassViolet` / `PassPink`).
- **Living UI** (`UI/Effects`, owner: "more effects, like shining, spinning ... like in the game pass sections"):
  `shine` (white streak every 4-5 s: pass rows, buy buttons, coin cards, the HUD Shop button), `rays` (our
  `assets/art/light-rays.png` turning behind the Spin wheel, and green behind the HUD Spin button while a free spin
  waits; its icon spins and FREE breathes). Parts are saved twins but invisible until the loop starts; Reduced
  Motion stops all (`Effects.setCalm` from Main). Previews park streaks off the edge; `SHINE=0` freezes mid-sweep.
  Colours kept as the kit (Huss Valley look): the owner left a palette switch optional.
- **Round HUD** (`Gameplay/RoundHud`, built by code at runtime, not a saved twin; `docs/previews/feel-ui-after.jpg`):
  text only at the top like Huss Valley, IgnoreGuiInset: "ROUND 2 · 1 OF 3 IN A ROW" (14) in Roblox's top-bar row
  (y 5-20 of 720, centred), the message line (Gotham Heavy, TextScaled 14-27 in a 512 x 28 box = 40% wide, 3 px dark
  outline, no panel, instant swap; outside a game it shows 5 s below the NEXT ROUND plate), "Runner · 0:21" (14,
  ends y 62 = 8.6%; HV 8.8%), a help line only in the player's very first round. The prize card sits under the top bar. **`Theme.MessageColour`** (default
  true) colours the message words; false = always white (owner asked; earlier he wanted white everywhere). Big
  words at y 194 of 720 (27%); 3-2-1-GO drawn each frame from EndsAt (pop 1.4 to 1 in 0.15 s, fade by 0.94 s; GO!
  green 124; section 7 for the wait after a shot). Prize card hidden in Countdown/HeroRun/Running. Own name tag faded, hidden in camera shots
  (`HuzzCinematic`/`HuzzChoosing`; a HERO/CHICKEN word stays, except during 3-2-1-GO) and from HeroRun through RoundOver (it sat where the
  centre words print). Outlines 0.55 see-through,
  no fill. Today's Girl roller (`Screens/GirlRoll`): right edge under the gear, 0.5 of a window. Check:
  `tools/preview/check_round_hud.luau`; shots `round-hud-runner`, `round-count`; picture `feel_ui_after.py`.

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
  Collecting one pops a "+N" in the star's colour where it was (HV's gems) with a soft burst everyone near sees
  ("AuraCollected" goes to all clients with the collector's id); no toast.
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
  from uploaded IDs; until the owner uploads, stand-ins show and shapes gated by `FxTexture.ready` stay hidden
  (nothing is uploaded yet: `Config/ImageIds` is empty, so every particle in Studio is Roblox's sparkle/fire/smoke;
  the girls' pools, rings, flames, orbs and trails need no picture; their flames turn soft once `Fx/BeamGlow` is in).
  The cutscene's 9 (beam-glow, beam-ladder, lightning, butterfly, crystal, star-flare, rays, nebula, bokeh) are the
  owner's own art since Oct 17: one sheet `design/vfx/owner-vfx-sheet-oct17.png` cut by `tools/fx/cut_owner_sheet.py`
  (re-run it if he sends separate files; don't redraw them with make_fx.py).
- **Secret cutscene:** `Shared/SecretReveal` (timeline, pure) + `Gameplay/SecretReveal` (effects, camera); the server
  sets `RevealAt` and the `Reveal` stage. Test in Studio with `Config/Round.StudioTestRarity = "Secret"`.
  **10 s** since Oct 19 (owner: "more detailed, especially the beams ... make the duration of it logical"; was 14.5 s,
  which dragged and everyone waits through it): 3.4 s of beams building to the burst, ~4.2 s with her (lands, her
  NAME on screen 4.5 to 6.3, push into her face), ~1.9 s finale and rise, 0.5 s hand-back. Why, and every beat's
  time (for sounds): `docs/secret-beats.md`. A local night look (Lighting/Atmosphere/Bloom/Sky/grade, the Terrain clouds thin and violet, the sun shrinks
  away; put back exactly; checked) until 8.3. **Beams** (`SecretReveal.PILLARS`, `LAYERS`): few (3 threads) → twins → a ring of 6 →
  all converge into the eyes' point; each a stack of 5 plain Beams (haze to white-hot middle, reads with nothing
  uploaded), pulses climbing (Transparency rebuilt per frame), helix strands, a gliding white filament, sparks, floor
  pools. Also shockwaves (dome, floor ring, ring facing you), a magic circle under her, a violet rim, her name card
  (`HuzzSecretName` ScreenGui, from the showcase's `GirlName` attribute); CarryAnimator keeps her Idle playing.
  Camera (owner Oct 18: "chopy", "not very logical"): one smooth move through `SecretReveal.KEYS` (monotone cubic,
  always in front of her), one cut (`CUTS` 6.4, under the swell); FOV kicks ease, shake is a 4.5 Hz wobble.
  Checks in `check_girl_fx.luau` (camera per frame, length 8-11 s, beams few → many, name readable, beat order).
  Film `motion3d/secret_scene.luau` (real module; bloom and sky are imitations; `SECRET_NOTEX=1` = today's look with
  nothing uploaded) → `docs/previews/secret-cutscene.mp4`, `secret-cutscene-notex.mp4`, `secret-vs-ref3.jpg`
  (`secret_vs_ref.py`), `secret-vs-ref3.mp4` (`secret_vs_ref_video.sh`, the reference re-timed to our beats);
  flashes `tools/preview/flash_check.py <film>`.
  The Secret girls are **C.C. and Marin** (owner, Oct 17; `Config/GirlNames`). The owner's place streams (StreamingEnabled):
  the showcase is `ModelStreamingMode` Persistent and RoundService streams the spot in around everyone (at most 3 s,
  `ReplicationFocus` until the end) before `RevealAt`; his first Studio recording (old 7.5 s build) showed an empty
  spot with no girl and no map because of this.
- **Knives** (owner, Oct 18: "add some vfx to the knifes, but make it fit it, and dont make it overly crazy"): his 30
  `design/knives/Knives/*.glb` (+ `All_Knives.glb`) are the Knife slot in `Config/CoinShop` (Order 101-130, his names
  and rarities; Common 200, Uncommon 500, Rare 1000, Epic 2000, Legendary 4000, Mythic 8000 coins). Old keys sit on
  fitting models and keep their rules: RookieKnife = Training Kunai, HunterKnife = Hunter's Hook, MoonlitKnife =
  Hollow Moon (quests), SpinKnife = Celestial Edge (wheel, never sold), IceKnife/CandyKnife/ShadowKnife = Ice Shard /
  Sakura Blade / Shadow Cleaver. Baked facts (lengths 2.4-3.3 studs, glow colours, part names):
  `tools/knives/bake_knives.py` → `tools/knives/knives.json` + the setup script. Card pictures from the real meshes:
  `knife_meshes.py` → `render_cards.mjs` → `compose_cards.py` → `assets/art/knife-*.png` (packed 192 px; they show in
  Play only, EditableImage); `docs/previews/knife-cards.jpg`. `KnifeService` takes `ServerStorage/HuzzKnives/<Key>`
  when there, else the built-in knife tinted in the skin's colours. **Worn knife** (owner Oct 18: "be shown on the
  back of the character"; the old belt mount was too low to notice): `KnifeLook.pick` = the shop's pick, else your
  first owned knife, else the default knife; diagonal across the back (handle over the right shoulder), or at the
  left hip like a sheathed sword for long slim blades (`KnifeLook.wearOf`: a `Wear` attribute/field "Back"/"Side",
  else measured from the model: 3+ studs and blade 5.5x longer than wide; of the 30 only Celestial Edge; the Game
  Pass katanas get sorted the same way). Server-built, one per body: `give` (hand) and `giveBack` (worn) each remove
  the other; RoundService syncs on every change, spawn and avatar reload; a shop change swaps it at once (Bootstrap).
  A model the wrong size is refused (plain knife + one `[HuzzKnife]` warning): 8 of his Oct 18 file came out of the
  setup ~12x too big and sideways, fixed offline by `tools/knives/repair_knives.luau`. Cause: Studio renames repeated
  part names across an import (2nd knife's `blade_0` = `blade_02`, 5th's `blade_05`, its 2nd part `blade_052`), the
  setup matched exact names only, and its box guess assumed upright while All_Knives.glb lies flat; renamed parts on
  all 30 also missed their colour and Neon. SetupKnives now matches "name + digits", refits by position, guesses from
  the box's long axis, and on a re-run repairs/recolours models already in HuzzKnives in place (`tests/SetupKnives.spec`:
  Studio-style names, both glbs, his real broken 8 in `tests/fixtures/HuzzKnives-oct18-first-run.rbxm`). Spec `tests/KnifeWear.spec`
  (all 30 on R15/R6, no clipping except the hanging hand on the hip hilt); picture `docs/previews/knife-on-back.jpg`
  (`motion3d/knife_wear_scene.luau`).
  **Game Pass knives** (owner Oct 18, `design/knives/gamepass/Gamepass_Knives.glb`): 5 more, rarity **Exclusive**
  (Mythic's calm effects, pink-white card), Order 131-135, `Pass` in `Config/CoinShop`, Price 0, never sold for coins
  (BuyWithCoins says "That one comes with the <pass> Game Pass."). **Each is its own Game Pass** (owner Oct 18: "these
  are going to be the gamepasses users can buy"; `Config/Products` `Knife`/`Card`, his card names): Hunter Knife =
  Crimson Requiem, Moonlit Knife = Hollow Eclipse, Sunrise Knife = Celestial Seraph, Inferno Knife = Dragon's Maw,
  Frost Knife = Frostbound Oath (checked against the meshes: all five match). VIP and Dance Pack give no knife now.
  `ShopService` grants them only when Roblox says you own the pass (`CoinShop.passGrants`), and wears one if your
  Knife slot is empty. Same pipeline (35 rows in `knives.json`, cards with a GAME PASS label). A refunded pass doesn't
  take them back yet. **Shop > PASSES** opens on 5 cards one-to-one with his mockup
  (`design/knives/Five_Elemental_Knife_Cards.png`, scaled 0.2993 to 120 x 214 so a whole card fits; art cut by
  `tools/icons/cut_pass_knife_cards.py` into `assets/art/pass-knife-*.png`, 240 px, Play only until uploaded), the VIP
  and Dance Pack banners under them; BUY + Robux mark, "coming soon" and never a prompt while `Id = 0`, Price 0 = not
  set (the live price shows once there's an ID). Side by side `docs/previews/knife-cards-vs-mockup.jpg`
  (`shots.sh shop-knife-cards` + `side_by_side.py knife-cards`).
  **The cards are alive** (owner Oct 19: "better knife animations ... in the gamepass sections"): animated card art,
  not a 3D viewport (his pass models aren't in his place yet and the art already is the knife): each card's element
  colour swells softly over the picture (`Effects.pulse`, about every 5 s, never under 0.78 see-through), 7 small
  shapes of its element float up over it (`Effects.motes`: petals for Hunter and Sunrise, dots for Moonlit and
  Inferno, diamonds for Frost; plain frames, no upload), the white shine, and the card lifts to 104% under the mouse
  (`Effects.lift`). All saved twins, hidden until their loop runs, stopped by Reduced Motion. Still
  `docs/previews/knife-cards-alive.jpg` (the motes are small and calm; the pulse shows only in motion).
  **Stand-ins until his import** (`Shared/KnifeShapes`): each pass knife's card shape from plain parts at its real
  length (katana, moon-hole cleaver, feather-guard longsword, jagged blade, crystal blade, glowing edges in Neon),
  so his place no longer shows our 1.9 stud dagger for them; still `docs/previews/stand-knives-standins.jpg`.
  Spec `tests/KnifeShapes.spec` (lengths, scaler, stand size, width and glow shell, elements, budget, arc).
  Hand by the model's `Grip`; effects `KnifeLook.LADDER`: Common none, Uncommon sheen, Rare soft light, Epic +3
  sparkles a second and a tinted slash trail, Legendary light Range 4 + glow on the back, Mythic + embers (stand-in
  particle textures until uploads). Pictures `docs/previews/knives-vs-hv.jpg`, `knife-leap.mp4`.
  **Owner how-to (Studio, once):** 1. File > Import 3D > `huzz-valley/design/knives/Knives/All_Knives.glb`, Import (and
  `design/knives/gamepass/Gamepass_Knives.glb` the same way).
  2. View > Command Bar, paste `require(game.ServerStorage.HuzzStudioTools.SetupKnives)()` (or the whole of
  `tools/knives/setup_knives.lua`), Enter. 3. Output says `[HuzzKnife] Done: 35 of 35 knives are in ServerStorage >
  HuzzKnives.` (a warning names any it couldn't find). 4. File > Save. 5. Right-click ServerStorage > HuzzKnives >
  Save to File, send `HuzzKnives.rbxm`; we put it in `assets/knives/` and `build_yours.luau` puts it in every build. Received Oct 18 (30 of 30; the 5 pass knives need steps 1-5 again). His place
  still holds the broken 8 and uncoloured parts: importing Gamepass_Knives.glb and running step 2 once fixes them too
  (Output: "repaired: it was the wrong size or way round" x8, "fixed colours and glow" for the rest).
- **Crates** (`Config/Crates`, `Shared/CrateRoll` with odds + pity) are plumbed but empty until the owner designs them.
- **Lobby leaderboards** (owner, Oct 18: "make the leaderboards just like in the video ... make them follow your
  character", "move smoothly", "look more like the reference ones but keep some halloween mood", "make it follow me in
  real time, not adjust after i move"; Oct 19: "please check the leaderboards over again"). References: his clip
  `design/lobby-ref/lb_f1.jpg`, `lb_f2.jpg` (night) and the HIGHEST LEVEL board up close in daylight in
  `oct19-lighting-ref.png`.
  - **Look** (`Shared/LeaderboardLook`, layout measured in its header): 14 x 18 stud slab, 700 x 900 face: title
    Gotham Heavy 52, "GLOBAL · ALL TIME · TOP 50", 12 rows of 50 that scroll (headshot, "#1 name" centred, long names
    shrink, value right: "LEVEL 402", "2611" + trophy, "33.5K CATCHES"), white text with a dark slate outline, studs
    over the face (`assets/icons/board-stud.png`). **Slate blue-grey** since Oct 19: his daylight board measures
    105,122,143 all over; the clip's mauve was the same board under his night lobby's purple light. `Colors.Face`
    104,118,135 is that with the game's grade undone (the face is unlit; the spec checks it against Config/Look);
    row bands the same colour, marked by their light and dark edges. Halloween, calm: a faint web in the corner, a
    pumpkin and a candle welded on top, a soft orange glow at the base. Side by side, same spot and perspective:
    `docs/previews/leaderboard-vs-ref.jpg` (`tools/preview/leaderboard_vs_ref.py`: our face through his board's
    perspective, graded; slab 105,121,143 vs his 105,122,143).
  - **Turn** (`Gameplay/Leaderboards`, `Shared/LeaderboardRules`, `Config/Leaderboards`): each screen turns its copy
    about its own upright centre to face your root every frame (`TurnRate` 20, capped at `TurnSpeedMax` 300 deg/s so
    a respawn is a quarter-second swing, not 37 degrees in one frame), at most `TurnMax` 75. `aimSmooth` has no jumps
    (the old aim flicked 75 degrees at 120 round and at the range edge, so it flicked back and forth while you stood on
    that line): past the limit it holds, from 120 round it eases home (straight behind = home), `TurnRange` 120 studs
    then `TurnFade` 20 more. No body (respawning): it holds. **Never into his build**: `LeaderboardRules.room` with
    `GetPartsInPart` every `TurnStep` 3 degrees finds how far each way it may turn (re-measured every 4 s nearby, as
    parts stream in); his terrace slope stops MOST CATCHES at 51 one way and MOST RESCUES at 60 / 51.
    Film `docs/previews/leaderboard-turn.mp4` (`motion3d/board_turn_scene.luau`: his lobby, the game's maths, walk,
    run, two husses, round MOST CATCHES, respawn; biggest step 5 deg a frame at 60 fps, 10 at 30).
  - **Where** (`HuzzServer/LeaderboardService`, `Shared/LobbyLayout.boardSpots`): anything named `Leaderboard...` or
    tagged `HuzzLeaderboard` (attribute `Stat`), else five per lobby: HIGHEST LEVEL, MOST WINS, MOST GIRLS on his three
    grey `Podium`s, MOST CATCHES and MOST RESCUES on the terrace ledge behind the plaza; the place build saves them in
    `Workspace > HuzzLeaderboards`. Sight lines in all 3 copies: `tools/world/board_sight.luau` (distance, how much of
    the face is hidden, letter height). From the front half of the plaza the podium boards read well (21-29 studs,
    title 15-20 px on a 900 px window); from the spawn they are 85-90 studs away (title ~5 px, the same size as Huss
    Valley's boards, so too small to read there) and his girls' display in the middle hides most of them.
  - **Numbers**: live only, one OrderedDataStore per stat (`HuzzValley_LB_v1_<Stat>`), saved every 90 s when changed and
    on leave, top 50 read every 60 s, budget-checked, every call in pcall (a failing store leaves just this server's
    players); players here always mixed in live, and someone who leaves stays listed until the next read (Studio:
    only who is here). JSON in attributes on `ReplicatedStorage.HuzzLeaderboards`.
  - Checks: `tests/Leaderboards.spec.luau` (formats, order, colour, no jumps, room, 30/60 fps),
    `tools/preview/check_lobby_boards.luau` (the real client: turning, limit, home, holding while respawning).
- **Avatar stands** (owner, Oct 18: "make the blocks i have in the lobby, next to the spin the wheel turn into my
  character and have like animated running ... selling a gamepass", then "make the character things in the lobby
  work ... gamepasses shown with the character of the person playing, equipped with some exclusive knifes";
  reference `design/lobby-ref/stands-ref.jpg`): `Gameplay/AvatarStands` turns any Part/Model named `AvatarStand` or
  tagged `HuzzAvatarStand` into a copy of the viewer's own avatar doing the sword showcase below (no knife: running in
  place, the owner's Run when it plays, else `RunMotion`; R6 a simple swing) holding its pass's exclusive knife in the right hand, turning to you calmly
  (the boards' turn, up to 70°), a calm glow, a sign (tag pill, title, "EXCLUSIVE KNIFE: CELESTIAL SERAPH") and a
  price button. **Where:** in his new lobby (Oct 18: "add ... all of the gamepass things to the new lobby") an
  invisible flat `AvatarStand` part each, in a row along the plaza's empty side, opposite the podium boards (the pads
  now hold his props, Oct 18; `Shared/LobbyLayout.standSpots` + `pickRow`: a spot is clear when nothing over 1 stud
  stands in its box and nothing over 8 between it and the edge; lobby A x -183.5, z 18 / 28 at the front, 53.5 / 63.5 /
  73.5 further back, either side of the spin wheel; `Workspace > HuzzAvatarStands`, tagged, `StandOn` Top, facing
  into the plaza): the back three sell Hunter, Moonlit and Sunrise Knife, the front two Inferno and Frost Knife:
  each stand one knife Game Pass and its knife, the five once each in every lobby copy (`AvatarStandRules.assign`,
  used by AvatarStandService and the place build; a stand on VIP / Dance Pack is moved onto the next knife pass;
  standSpots lists the back three first so they keep his card order).
  `HuzzServer/AvatarStandService` makes them at game start when the place has no stands (his Rojo-synced place); the
  place build saves the same ones. Places without pads: his grey blocks beside the big spin wheels
  (`AvatarStandRules.findBlocks`; his old islands' blocks now stay plain blocks). It puts a ready copy of each pass
  knife in `ReplicatedStorage > HuzzStandKnives` (his model from `ServerStorage/HuzzKnives/<Key>`, else the tinted
  built-in knife). Tall blocks hide and you stand where they stood; flat ones are pedestals (`StandOn`). The button
  opens `PromptGamePassPurchase` only with a real Game Pass ID AND a `Config/Products` pass that's OnSale; otherwise
  "SOON" / "COMING SOON" (today both: VIP Id 0, DancePack not OnSale). No timers or LIMITED/ENDS IN copy.
  **Owner how-to (Studio):** nothing to do: press Play. To move them in the downloaded build: Explorer >
  Workspace > HuzzAvatarStands > AvatarStand (invisible: click it in Explorer, then drag with Move), or change its
  Attributes: `Pass` (String: `VIP` or `DancePack`), `Knife` (String: one of that pass's knives, e.g.
  `CrimsonRequiem`; another pass's knife is refused with a warning), `Title`, `Subtitle`, `Tag`, `Price`, `Color`,
  `StandOn`. In his own Rojo place they're made fresh each Play; to keep his own spots there, copy the
  `HuzzAvatarStands` and `HuzzLeaderboards` folders from the downloaded build into his Workspace (then the game uses
  his). Real knife models: import `Gamepass_Knives.glb` and run SetupKnives (section 11, "Knives"). To sell:
  create the Game Pass on the Creator Dashboard, paste its ID into `Config/Products` (that pass's `Id`), `OnSale =
  true`. Leaderboards: drag the boards in `Workspace > HuzzLeaderboards` (each is a Model: click it, Move); a board's
  `Stat` attribute picks what it ranks.
- **Lobby props** (owner, Oct 18: "implementing these objects into the lobby on top of the already placed circles.
  Give it some VFX and make it look good just like in the pictures"; his `design/lobby/Lobby_Props.glb`, references
  `design/lobby/ref-halloween-shop.png`, `ref-shop-like-reward.png`): one prop floats over each of the five round
  pads at the plaza's front, in every lobby copy (`Config/LobbyProps`, `Shared/LobbyLayout.propSpots`,
  `Shared/LobbyPropBuild`, `HuzzServer/LobbyPropService`, `Gameplay/LobbyProps`; the place build saves them in
  `Workspace > HuzzLobbyProps`, one `LobbyProp` model per pad with attributes Title, Line, Opens, Scale, Color, Glow).
  Two-pad side: SHOP (Shop_Stall, opens the Shop), LIKE THE GAME! (Like_Reward_Gift, decoration: Roblox can't tell a
  game who liked it, so no reward). Three-pad side: FREE SPIN (Pumpkin_Patch_Chest, opens Spin the Wheel; the line
  under it counts down to your real free spin), WITCH'S BREW (cauldron) and SWEETS & TREATS (coffin), decoration (no
  menu fits). A ProximityPrompt and a click open the menu (never in a round). Each bobs 0.35 studs over 3.4 s and
  turns once in 18 s (client, within 200 studs), has a soft PointLight under it that breathes over 4 s, a glow pool on
  the pad, 5 sparkles a second and a bold FredokaOne title (dark outline, white lift) in its colour. Until he imports
  his meshes each is built from plain parts in his colours (`HuzzServer/LobbyPropShapes`, baked by
  `tools/props/bake_props.py`: no stud textures, no SHOP / LIKE pictures, rings, chains, vines or frosting; the coffin
  is boxy). Side by side `docs/previews/lobby-props-vs-ref.jpg` (`tools/props/prop_meshes.py` + `render_props.mjs` +
  `props_vs_ref.py`: his meshes as the helper sets them up, bloom and grade added).
  **Owner how-to (Studio, once):** 1. File > Import 3D > `huzz-valley/design/lobby/Lobby_Props.glb`, Import.
  2. Command Bar: `require(game.ServerStorage.HuzzStudioTools.SetupLobbyProps)()` (or paste
  `tools/props/setup_lobby_props.lua`). 3. Output: `[HuzzProps] Done: 5 of 5`; the pads swap to his models.
  4. File > Save; right-click ServerStorage > HuzzLobbyProps > Save to File, send `HuzzLobbyProps.rbxm`; it goes in
  `assets/props/` and `build_yours.luau` puts it in every build. Spec `tests/SetupLobbyProps.spec` (Studio-style
  turn, size and names). To move one: drag its `LobbyProp` in `Workspace > HuzzLobbyProps`; `Scale` sets its size.
- **Stand sword showcase** (owner, Oct 18: "showcase the swords that the gamepass includes ... the swinging
  animation, make it look good though"): a stand with a knife no longer runs; `Shared/StandShowcase` (client only,
  only within NEAR 160) holds a guard (blade up, in front of the right shoulder, breathing and weight shift; R15 feet
  planted by leg IK) and every `CYCLE` 3.3 s plays one of three moves in turn: Combo (forehand sweep, backhand
  return, wrist twirl), Flourish (overhead twirl, diagonal cut) and Rising (crouch, rising cut, twirl). Each stand
  starts on its own move (its build number) at its own time (its spot). The twirl turns the knife in the fist via the
  weld's C0 (`grip`); R6 has no elbow, so shoulder and grip share the bend (simpler, still reads). AvatarStands adds
  a `StandSlash` Trail (TrailBase to TrailTip, skin colour, `TRAIL_LIFETIME` 0.2 since Oct 19 round 2) that's on only in the cuts; the
  steady rarity glow is the display knife's own. Knife-less stands keep the run. Spec `tests/StandShowcase.spec`
  (blade in front of the torso at ready, a move every loop, no pops at 30/60 fps, back to ready, feet planted);
  video `docs/previews/stand-showcase.mp4` (`tools/preview/motion3d/stand_scene.luau`, mock rigs, his meshes).
  **Oct 19, big and in his reference's style** (owner: "right now its very small and you dont even notice it ... make
  the knife animations look like the ones i have attached in the video, but make the text different, not ui";
  `design/lobby-ref/oct19-stands-ref.mp4`: PUMPKIN CLEAVER, VIP DAGGER, VOWBREAKER; we copied the motion and
  effects, never its sign words, LIMITED or ENDS IN timers):
  - **Size:** `KnifeService.display` scales the stand copy to `KnifeLook.STAND.Length` 4.4 studs (his models are
    3.2, the old stand-in dagger 1.9) with `KnifeService.scale` (by hand: sizes, offsets, attachments, welds,
    meshes, lights). An earlier `Model:ScaleTo` try broke 3 lobby checks because the Lune harness has no ScaleTo, so
    the stand's mount failed; the hand scaler runs everywhere (check_lobby_boards now also checks the size).
  - **Broader than life** (round 2, "in the reference the knife is the first thing you see"): display only, after
    the length scale `KnifeLook.standWiden` widens the blade to about `STAND.Width` 1.7 studs (at most `MaxWiden`
    4.5x: his katanas ~3.5-4.5x, the big cleaver ~2x) and thickens it up to `MaxThick` 2.6x (`KnifeService.scale`
    takes a Vector3 in the Handle's axes: X thickness, Y length, Z width), then lays a `GlowShell` over every part
    with "blade" in its name: Neon in the element's light colour, `STAND.Shell` 0.4 see-through, welded (a steady
    glow, nothing flashes). The slash runs from `StandTrailBase` (45% up the blade, added by display) to the tip.
  - **Elements** (`KnifeLook.ELEMENTS`, in place of Mythic's sparkles and embers; stand rate, about a third in hand,
    a sixth on the back, `KnifeLook.elementRate`): Hunter red petals (10/s, 0.55) + twinkles, Moonlit moon glint at
    the tip + violet wisps (6/s), Sunrise gold feathers + twinkles, Inferno flames along the blade (24/s, size 1.3)
    + rising embers, Frost ice shards + snowflakes + a faint mist (stand only); on a stand also a soft light
    (0.6, range 4: the Oct 19 lighting keeps glow on the object, so Neon and particles carry it; the stand disc
    light is 0.4 / range 6) and a star glint at the tip about every 2.5 s. At most 32 particles a second per stand knife (Inferno 31), nothing
    flashes. Until he uploads `assets/fx`, Studio shows Roblox's sparkle and fire pictures instead.
  - **Moves:** each knife has a `STYLES` entry (hold + 3 moves): Inferno = Low hold, Whirl (a full-body spin into a
    lunging slash), Scrape (round 2, the reference cleaver's ground sweep: a crouch with the blade back low on the
    right, then one big arc low across the front), Cleave (overhead and one big arc down); Moonlit = Low, Cleave,
    Scrape, Whirl; Hunter = Low,
    Bloom (arm high, a spin, a burst of petals, an arm-out slash), Flick, Combo; Sunrise = Guard, Flick (two wrist
    flicks and a twirl), Flourish, Bloom; Frost = Guard, Whirl, Rising, Flick. The Low hold hangs the big blade down
    and out to the right side, in front of the body. **Face out at rest** (round 3): each hold has a `twist` (the
    knife's turn about its own blade, after the grip: Guard -70, Low 80, measured on R15 and R6), so at rest the
    blade's broad face looks out of the stand instead of its edge; in a move the twist eases back to 0 (the edge
    leads the cut) and returns with the hold (`StandShowcase.knifeTurn` builds the weld's turn for AvatarStands, the
    spec and the renders; the spec checks the width axis is across the view and the face looks out). A spin turns the whole body (`spin`; the feet turn with it). A move's `burst`
    throws the knife's KnifeBurst once (AvatarStands). Trail 0.2 s in the element's colours (Sunrise gold, never
    white), tapered, from mid-blade.
  - Spec `tests/StandShowcase.spec` runs every style on R15 and R6 at the big size. Side by side at 30 fps:
    `docs/previews/stand-knives-vs-ref.mp4` + still sheet `.jpg` (`tools/preview/stand_knives_vs_ref.sh` over
    `motion3d/stand_knives_scene.luau`: top his reference, bottom ours, same row and framing, his meshes;
    `KNIFE_MODE=standin` draws the plain-part stand-ins).
  - Still worse than the reference (after round 3): the reference's cleaver hangs nearly straight down by the leg
    with a fire cloud round it, bigger than our flames (ours sticks out diagonally to the side, so its tip clears the
    floor at 4.4 studs); the resting Sunrise blade now stays in the frame but touches its sign; our signs aren't in
    the render. Still `docs/previews/stand-knives-rest-vs-ref.jpg` (rest pose next to the reference). The render has no bloom, so Studio's Neon shell will glow more.
    `stand-knives-standins.jpg` is still the round 1 picture (before the widening).

- **Admin panel** (owner, Oct 18: "give me a admin command panel or something so i can get any knife or any girl to
  spawn when i want it to do so"): `Screens/Admin` + `HuzzServer/AdminService` + `Shared/AdminRules`. Only the game's
  owner: Studio, else `player.UserId == game.CreatorId` (a game he owns) or rank 255 in the creator group (a group
  game); no user IDs typed anywhere, the server checks every request (remote `Admin`, ActionService's 0.15 s limit).
  Admins get a small ADMIN button bottom-left (Player attribute `HuzzAdmin`) opening KNIVES (GIVE: yours and worn) and
  GIRLS (SPAWN: yours and your companion, behind you at once; NEXT GAME: `GirlService.setNext`, the next roll lands on
  her, a Secret plays her cutscene). Spawning a girl loose mid-lobby doesn't fit the loop, so it's companion or next
  game. Checks `tests/AdminRules.spec` (a non-admin is refused), `tools/preview/check_admin.luau` (the real server).

## 12. Sounds
- **Real, researched sounds for clicks, the Secret cutscene and the dances** (owner Oct 19: "don't create random
  sound by yourself, do a research of what sounds good and not, and then logically select the best sounds/songs").
  **Never synthesize these three again** (`make_sfx.py` skips them: `RETIRED`). Research, picks, sources and reasons:
  `docs/sound-picks.md`; spec `tests/SoundPicks.spec` (every ID "" or rbxassetid with its store URL in the file and
  the doc, never invented).
  - **Safe sources, in order:** (1) Roblox's licensed library: uploads by **@Monstercat**, **@APMOfficial**,
    **@ProSoundEffects** ("(SFX)" titles). Public, free in any experience, plays in Studio and live, nothing to upload.
    Check the uploader: look-alike fan uploads exist. (2) CC0 packs (Kenney, freesound CC0, OpenGameArt CC0): the
    owner uploads them, then they're private to him (a group game needs them uploaded to / shared with the group).
    Never pop songs, other games' sounds or random community uploads.
  - Cloud sessions can't open roblox.com (WebFetch/curl blocked): find IDs with WebSearch limited to
    `create.roblox.com` (the result URLs carry the ID); GitHub clones work for CC0 packs.
  - **Clicks:** Roblox's licensed UI files are many-takes-in-one or high beeps, so the family is Kenney's CC0 Interface
    Sounds picked by numbers (`tools/sfx/measure_sfx.py`: 30-150 ms, soft 2 ms front, centroid ~0.8-1.4 kHz, ~0%
    above 4 kHz): click `drop_002`, hover `select_002`, open `maximize_009` (rises), close `minimize_009` (falls), in
    `assets/sfx/ui_*.ogg` + `LICENSE-kenney.txt`; listen `docs/previews/ui-sounds-oct19.ogg`. IDs "" until he uploads.
  - **Secret cutscene:** keyed to beats, not seconds (`Config/SecretSounds`: Build = riser + glistening bed, Burst =
    magic hit + pixie-dust tail and the riser cut under it, Reveal = APM's 8 s fantasy sting, End = fades);
    `Gameplay/SecretReveal` calls `Sfx.beat(...)`. Pro Sound Effects + APM IDs in `Config/SoundIds`.
  - **Dances:** 11 Monstercat/APM tracks for 25 dances by style (`Config/Dances` `Music` -> `Tracks`; Crab Rave for
    the meme dances, breakbeat for b-boy, electro swing for Swing/Flapper...); dance tempos measured by
    `motion3d/dance_tempo.luau` (reliable only where it says strength > 0.4). `Gameplay/Music.dance` plays it for you
    only, looped, at 0.22 (background 0.3) and dips the background to 35%; `danceStop` fades it (DancePlayer calls
    both). `Start` offsets are 0 until someone listens.
  - **Owner verifies:** paste `tools/studio/check-sound-picks.lua` in the Command Bar: `[HuzzSfx] OK/MISSING`,
    `PLAYS/WON'T PLAY` per ID, each played for 4 s. Levels are first guesses until he hears them.
- **Button sounds** (owner Oct 18: "they sound glitchy, and dont feel too premium"): one press = one sound. Kit
  buttons sound on `MouseButton1Down` (only the button on top gets it; `InputBegan` could also reach buttons behind
  an open window, so one click could sound 2-3 times a little out of step), touch on `Activated`; `Sfx` skips the
  same ui_* sound within `UI_GAP` (0.08 s for clicks), replays preloaded copies (never a cut-off), no pitch wobble,
  through the Interface group. Until he uploads the Kenney files Roblox's button.wav stands in at pitch 0.9,
  quieter (open/close stay silent). Spec `tests/Sounds.spec`.
- The other ~30 game sounds are still made from scratch (`tools/sfx/make_sfx.py` → `assets/sfx/*.ogg`; all in a row
  in `docs/previews/sfx-preview.ogg`, which still has the old ui/secret ones): warm, C major pentatonic, brightness
  under 2.5 kHz, even loudness.
- `Gameplay/Sfx.play(name, {volume, pitch, at})`, `Sfx.loop("speed_wind")`. `Config/SoundIds` stays "" until the
  owner bulk-imports the files in Asset Manager and sends the IDs (`tools/studio/collect-sound-ids.lua` prints
  them). Built-in stand-ins meanwhile, never pitched above 1.1; silence beats a squeaky ping.

- **Music** (`Gameplay/Music`, owner Oct 18: "randomly play in the background these audios in a volume that isnt too
  loud"): the owner's songs in his place (SoundService > Music > Background_Music Bg1-9; Important_Song_Actions >
  Winner_Music_Showcase), else the same songs by ID in `Config/Music` (Bg1-9 + winner, sent Oct 18).
  Shuffled, no repeat, fades, `Config/Music.Volume` 0.3 through the Music group; the win song on the Round "Results"
  event (background fades under it); the Secret cutscene quiets it. Bootstrap stops songs set to play by themselves.
- **Settings > Audio** (owner: "many options"): a scrolling list of 6 rows: Master, Music, Effects, Button Sounds
  (`InterfaceVolume`, the `Interface` group: Sfx sends `ui_*` there), Background Music ON/OFF + Next Song, Mute While
  Unfocused.

## 13. Studio-only truths
- The cloud can't reach Roblox: uploads, real purchases and the final look are the owner's steps. The upload and
  sound helpers live in the place (`ServerStorage/HuzzStudioTools`, run with one `require(...)()` line); the
  owner's click-by-click guide is `docs/STUDIO-STEPS.md`. Studio helpers report on Output lines tagged `[Huzz]`, `[HuzzSfx]`, `[HuzzAnim]`.
- Not yet seen in Studio: the Practice Bot (its walk, run animation, knife), the Oct 17 UI shine/rays/spin and Juice bursts, the new lighting, stars in the playing zone, the move between lobbies after the vote (instant, no fade yet), the lunge feel, sprint feel, lobby repaint, knife positions, spin animation, dance
  pictures on real avatars, the owner's knives (meshes after his import, glow, sparkles, the leap and dive), dance sync across two clients (needs published dances), the lobby leaderboards (studs
  picture (Play only), the slab colour under his grade, Gotham's size, headshots, scrolling, the calm turn, the
  pumpkin, candle and glow, the Oct 19 slate colour, the turn stopping before his slope) and the avatar stands (your copy, its run, the knife in its hand); the new lobby (the boards on the terrace ledges
  turning without touching the slope behind, the stand row, the move back after a game), the lobby props (his meshes
  after the import, the bob, turn, glow and titles) and the Oct 18 lighting tune; the Oct 19 even lighting (ShadowMap, strong sky fill, lamps turned down); the Oct 19 sky (Terrain clouds, bluer Atmosphere).
- **Which code ran?** Studio shows "build <date> UTC" small in the bottom right (and `[Huzz] Build` in Output), from
  `Config/Build` written by `build_place.sh`. The owner's Oct 18 recordings showed the OLD cutscene and HUD although
  the download was new: Rojo connected to his out-of-date local copy puts old scripts back. Fix: GitHub Desktop >
  branch HUZZ-VALLEY > Fetch/Pull origin before connecting Rojo (or don't connect Rojo when testing the download).
- **Testing rounds:** alone, the Practice Bot catches. For real players, Studio Test tab > Clients and Servers,
  2 or 3 players, and wait for the vote (about a minute).
- ProfileStore is in Mock mode in Studio (progress resets on Stop): on purpose.
- Scan any place the owner sends for scam scripts (`GetObjects`, `require(<id>)`, `loadstring`, HTTP);
  `SafetyService` strips the known Basket Ball Hoop one.

## 14. Open items (a running list; add to it as the owner reports more)
- Owner: Game Pass IDs (VIP 199, Dance Pack 149, and the 5 knife passes, Price 0 until he sets them: the cards and
  stands wait for them); import
  `Gamepass_Knives.glb` + rerun SetupKnives and Developer Product IDs (Sunset Trail, Blossom Aura, coin
  packs, spins 1/10/100); upload sounds, pictures and animations; an export of their spin wheel model (match its
  colours); run the knife setup and send `HuzzKnives.rbxm` (section 11, "Knives"); power icons; a stab animation; crate contents; dance names; movement pack licence.
- Owner's place notes (Oct 17): no Uncommon girls yet (the rarity is skipped until there are some); a plank path
  near the Halloween lobby and a basketball hoop sit loose in Workspace (the path's pieces on the field now move
  into Halloween_Map at start; the pieces on the lobby stay).
- Secret cutscene floor (Oct 18): the showcase floor is read from 6 studs over the Middle box (a ray started inside
  Halloween's grass missed it: she stood 8 low, knee-deep in the cutscene, camera under the floor), and the client
  re-reads the floor under her and keeps the camera 1.5 over it.
- Owner (Oct 17): Shop ITEMS/COINS, DANCES and HOW TO PLAY (`Screens/HowToPlay`, was `Welcome`: first join +
  Menu) built from the `design/ui-oct17` mockups (`docs/previews/*-vs-mockup.jpg`, `tools/preview/side_by_side.py`,
  checks in `tools/preview/check_oct17.luau`). Their pictures are mockup crops (placeholders): ask for sharp PNGs.
  His Secret cutscene reference (not sent yet). Not seen in Studio: Crown Pose, Midnight cape, worn auras, the
  cutscene, the Oct 17 screens.
- Halloween lobby (Oct 18): the owner builds it himself from `docs/HALLOWEEN-LOBBY-PLAN.md` +
  `docs/previews/halloween-lobby-layout.png` (Huss Valley's Halloween lobby, 200 x 182 round his island; drawn by
  `tools/world/halloween_layout.py`, his real positions from `tools/world/measure_halloween_lobby.luau`). The night
  look needs `Config/Look` changed (game-wide); values are in the plan.
- New lobby (Oct 18): his BasketBall and Halloween copies in `StartingPoint` are pasted twice (every part twice in
  the same place; the game counts them once, but it doubles those parts); his old islands still float off to the side
  in `Maps > Spawn` (unused; deleting them is safe: the game makes a spawn on each plaza if his SpawnLocations go too).
  The podium boards are hard to read from the spawn (85-90 studs, behind his girls' display): moving the spawn
  toward the podium side, or the display, would fix it (his build, his call).
- Lobby props (Oct 18): stand-ins until he imports `Lobby_Props.glb` and sends `HuzzLobbyProps.rbxm`; the titles on the
  three-pad side sit close (pads 7 apart); LIKE THE GAME!, WITCH'S BREW and SWEETS & TREATS open nothing yet.
- Knife showcase (Oct 19): not seen in Studio yet (the big stand knives, element particles with stand-in
  pictures, the spins, the card motes/pulse, the slash arc); the 5 pass models still need his import
  (`Gamepass_Knives.glb` + SetupKnives), until then the stand-ins show.
- Pass knives: a refunded pass keeps them; six grey-block stands (older places), five knives (the sixth repeats
  Hunter Knife). The card names use Gotham (the owner's font rule), wider than his mockup's rounded font.
- Lighting (Oct 19): the avatar stands' disc light is 0.4 / Range 6 (`Gameplay/AvatarStands`); his own 38 pumpkin PointLights (0.5 / 8) are unchanged (ShadowMap drops
  their shadows); the floors keep his own colours and materials (the reference's grey stone tiles are map design,
  not light). The cast-shadow numbers are a model, only Studio shows the real thing.
- Us: whatever the owner's next round of fixes asks for first; then the Gift Picker, more lore chapters.
- Everything in sections 7 to 12 is the current version, open to change: tuning numbers (speeds, odds, prices,
  lunge, wheel prizes), looks and feel are first passes waiting for the owner's verdict in Studio.

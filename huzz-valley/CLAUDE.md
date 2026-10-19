# Huzz Valley: project memory

Huss Valley's crossing game, one to one, with collectible anime girls on top. Kid audience. The owner sends reference
videos/pictures and judges by eye. The root `CLAUDE.md` rules (plain words, golden slice, reference side by side,
honest gaps, never invent IDs, kid-safe, purchases server-only) always apply. Owner's own words are in quotes.

**This is the lean core every session reads.** Each system's deep notes are topic files in `docs/notes/` (index:
section 9); read only the one you need.

> **Work in progress.** The owner's newest message always beats anything written here. Most of it was only checked
> offline; every tuning number, look and feel is a first pass waiting for his verdict in Studio.

**Keep notes, in the same commit as the change:** update the topic file it belongs to (a new system gets a new file
and an index row). When a change makes a note false, rewrite the note; don't append "was X" (one short reason is
fine). Owner quotes go in the topic's "Why" part. Keep this core about 20 KB and code header comments true.

## 0. Start here (every session)
- Branch `HUZZ-VALLEY`, run everything from `huzz-valley/`. A fresh cloud container has no Lune: install it once with
  `mkdir -p /root/bin && cd /tmp && curl -sSLo lune.zip https://github.com/lune-org/lune/releases/download/v0.10.5/lune-0.10.5-linux-x86_64.zip && unzip -o lune.zip -d /root/bin && chmod +x /root/bin/lune && cd -`
  (image tools need `python3 -m pip install pillow`).
- The three commands (details in section 4), in this order before every commit:
  1. `PATH=/root/bin:$PATH bash tools/check.sh` (compile + specs + full-game sim)
  2. `PATH=/root/bin:$PATH bash tools/preview/check.sh` (UI checks)
  3. `PATH=/root/bin:$PATH LUNE=/root/bin/lune sh tools/place/build_place.sh` (regenerates `HuzzUI.rbxm` + places)
- Then give the download link `https://github.com/atreonyt/roblox/raw/HUZZ-VALLEY/huzz-valley/places/HuzzValley-yours.rbxl`
  and how to try it.
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
  side"); catchers hold theirs in a round. The owner's own 30 knives (Oct 18, `design/knives/`) are the skins
  ([knives.md](docs/notes/knives.md)): calm effects by rarity, "dont make it overly crazy". Huss Valley's knives (on
  the back at the belt, slash with no wind-up, catch = red fill, no sparks or shake): `docs/knife-study.md`.
- **Aura** = Huss Valley's gems. **Coins** buy looks (the owner picked "Coin cosmetics shop").
- **Never invent IDs** (assets, sounds, animations, passes, products): leave 0/"" and add a README checklist line.

## 2. How we work with this owner (lessons so far)
- Give status in short plain lines; one picture per change; end with the download link (section 0) and how to try it.
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
- **Known pitfalls** (bug hunt, Oct 19; each one shipped once):
  - Streaming: a Model arrives before its parts. Never look a child part up once at start; look again until found
    (LobbyProps: FREE SPIN's line stayed blank in the other lobbies). Test it by parenting the part in late.
  - Our invisible walls are CanQuery off, so rays miss them: anything that moves a body by a raycast also clamps to
    the field (`MapService.fieldLocal` + `DownMotion.fieldSlide`; the catch slide went through side walls).
  - A ray at waist height misses fences and kerbs: cast one near the floor too when a lying body moves.
  - A queue or loop in one task: pcall each job, or one error stops everything after it (ImageLoader's knife pictures).
  - World prompts that open menus: block them in rounds AND during `HuzzCinematic` (the Secret cutscene plays in
    the lobby before roles are set).
  - The sim isn't deterministic (table order over Player keys): a scenario forces what it tests (edge cases makes
    every catcher lunge) instead of hoping a seed does it.
  - Worktree agents can't run `bash tools/check.sh` (blocked): run each `lune run tests/X.spec.luau` and the sim on
    their own, and pass harness snippets as `@file` instead of `"$(cat file)"`.

## 3. Where things are (`src/`, Rojo `default.project.json`)
- `ReplicatedStorage/Shared`: pure, tested logic (`RoundRules`, `CrateRoll`, `SpinRules`, `GirlRoll`, `CarryMath`,
  `KeyframeSampler`, `DanceRetarget`, `LocomotionMix`, `AuraLook`...), `Net` (every remote), `AnimationLibrary`,
  `Config/*` (Round, Run, Look, Powers, Dances, DancePoses, Animations, SoundIds, Products, CoinShop, Crates,
  SpinWheel, AuraStars, Progression, Characters, GirlLooks, GirlNames, Settings...).
- `ServerScriptService/HuzzServer`: `RoundService.server` (the loop), `MapService`, `MapVoteService`, `GirlService`,
  `CarryService`, `KnockdownService`, `PowerService`, `KnifeService`, `NameTagService`, `CompanionService`,
  `CosmeticsService`, `AuraPickupService`, `PracticeBot`, `SpinService`, `LookService`, `ActionService` (UI verbs +
  Dance remote), `ProgressService`, `LeaderboardService` (lobby boards), `ShopService` (the one ProcessReceipt),
  `DataService` (ProfileStore; writes only via `update()`; `onChanged` hook), `SafetyService`, `Bootstrap`.
- `StarterPlayerScripts/HuzzClient`: `Main` (UI screens, each in `Report.run`), `StartGameplay` (Gameplay/*),
  `UI/{Kit,Theme,Scale,Motion,ModalManager,State,DancePlayer,DancePose,Toast}`, `UI/Screens/*`, `Gameplay/*`.
- `ServerStorage/HuzzAnimations.rbxm` (generated), `StarterGui/HuzzUI.rbxm` (generated: never edit by hand).
- `design/`: kit pages, the owner's art zips, `anims/` (movement pack + 200 dances), `aura/`, `shop/`, references.
- `places/HUSSANIME.rbxl` = the owner's own place as of Oct 18 (maps, girls, his **new Halloween lobby** in
  `Workspace > StartingPoint`, one copy in front of each map; his old lobby islands moved aside in `Maps > Spawn`);
  `HuzzValley-yours.rbxl` = it with all our code and UI swapped in (what the owner tests).

## 4. Checks, previews, builds (Lune 0.10.5 at `/root/bin/lune`; run before every commit)
- `PATH=/root/bin:$PATH bash tools/check.sh`: compiles every script; every spec in `tests/` (each topic file names
  its own); **the full-game simulation** (`tools/sim/round_sim.luau`: real server code, bots that run, stab,
  lunge, rescue, use powers; 10 setups, one of them "edge cases": leaving mid-lunge and mid-cutscene, a reset
  mid-lunge, the admin's NEXT GAME Secret girl twice). `lune run huzz-valley/tools/sim/round_sim.luau audit` (repo
  root) prints the loop numbers for `docs/loop-audit.md`. Its stubs (e.g. `KnifeService`) must get any new function RoundService calls, or games stop
  with "attempt to call a nil value".
- `PATH=/root/bin:$PATH bash tools/preview/check.sh`: UI checks on the saved UI, then built from nothing.
  It prints harness errors too ("snippet error"): a silent missing count means a check script crashed.
- `PATH=/root/bin:$PATH LUNE=/root/bin/lune sh tools/place/build_place.sh`: regenerates `HuzzUI.rbxm`, both places,
  sets Lighting.Technology = ShadowMap in the owner's place and saves Config/Look's Lighting, effects, Sky and
  Terrain Clouds into it (so Studio's edit view shows the game's look too). Rebuild after every change.
- `python3 tools/notes/check_notes.py`: the notes split lost nothing (old tokens and quotes still present, index
  links and named paths exist).
- UI pictures: `cd tools/preview && NODE_PATH=$(npm root -g) LUNE=/root/bin/lune HUZZ_FRESH=1 sh shots.sh <out> <name>`
  (names in `shots.sh`: dance-wheel, shop-passes, shop-items, quests, spin-wheel, round-hud, hero-choice...).
  The preview draws Montserrat for Gotham, has no AutomaticSize (it does draw TextScaled with UITextSizeConstraint
  and TextTruncate).
- 3D videos: `tools/preview/motion3d` (`sh video.sh <scene.luau> <out.mp4>`; scenes per topic, and
  [animations.md](docs/notes/animations.md) for `anim_scene.luau`).
- Ad-hoc harness tests: `lune run harness.luau ../../src - "$(cat test.luau)" setup_ui.luau`. Fake a character
  with Motor6Ds to test posing; stub `AnimationLibrary.id` to force code paths.
- Owner's place inspection with Lune (`deserializePlace`): `lune run huzz-valley/tools/check_maps.luau [place.rbxl]`
  (repo root) lists maps, lobby pairs and safe lines; where maps and lobby floors live: [round.md](docs/notes/round.md).
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
- **Round state is attributes,** not extra remotes ([round.md](docs/notes/round.md)). Read them with
  `GetAttributeChangedSignal`.
- **Generated, never hand-edit:** `Shared/Images/**` and `ServerStorage/HuzzImages/**`
  (`tools/icons/pack_images.py`), `StarterGui/HuzzUI.rbxm` and `places/*.rbxl` (`build_place.sh`),
  `ServerStorage/HuzzAnimations.rbxm` (`tools/anim/extract_anims.luau`), `Config/DancePoses`
  (`motion3d/dance_poses.luau`), `Config/ImageIds` (written by the owner's upload helper).
- **Guard Studio-only APIs** with `pcall` so the Lune harness and Studio both run (list in [ui.md](docs/notes/ui.md)).

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
  pick real licensed ones ([sounds.md](docs/notes/sounds.md), `docs/sound-picks.md`).
- **New quest stat or reward:** count it from a real server event with `ProgressService.addStat(player, stat, n)`;
  chapters in `Config/Progression`.

## 7. Studio-only truths
- The cloud can't reach Roblox: uploads, real purchases and the final look are the owner's steps. The upload and
  sound helpers live in the place (`ServerStorage/HuzzStudioTools`, run with one `require(...)()` line); the
  owner's click-by-click guide is `docs/STUDIO-STEPS.md`. Studio helpers report on Output lines tagged `[Huzz]`,
  `[HuzzSfx]`, `[HuzzAnim]`, `[HuzzKnife]`, `[HuzzProps]`.
- **Which code ran?** Studio shows "build <date> UTC" small in the bottom right (and `[Huzz] Build` in Output), from
  `Config/Build` written by `build_place.sh`. The owner's Oct 18 recordings showed the OLD cutscene and HUD although
  the download was new: Rojo connected to his out-of-date local copy puts old scripts back. Fix: GitHub Desktop >
  branch HUZZ-VALLEY > Fetch/Pull origin before connecting Rojo (or don't connect Rojo when testing the download).
- **Testing rounds:** alone, the Practice Bot catches. For real players, Studio Test tab > Clients and Servers,
  2 or 3 players, and wait for the vote (about a minute).
- ProfileStore is in Mock mode in Studio (progress resets on Stop): on purpose.
- Scan any place the owner sends for scam scripts (`GetObjects`, `require(<id>)`, `loadstring`, HTTP);
  `SafetyService` strips the known Basket Ball Hoop one.
- **Not yet seen in Studio:** almost everything since Oct 17 (bot, feel, knives, lobby, light, sky, cutscene,
  dances). Each topic file lists what's not seen yet; don't call any of it finished.

## 8. Owner's to-do and open items (current only; add as the owner reports more)
- **Owner, in Studio:**
  - Game Pass IDs (VIP 199, Dance Pack 149, and the 5 knife passes, Price 0 until he sets them: the cards and
    stands wait for them).
  - Import `Gamepass_Knives.glb` and `Halloween_Knives.glb` + rerun SetupKnives and send `HuzzKnives.rbxm` again: we
    have his 30 knives (Oct 18, finished offline Oct 19) but not the 5 pass or 18 Halloween knives (until then each
    screen draws them from the .glb with
    EditableMesh: only with Game Settings > Security > "Allow Mesh / Image APIs", which needs his ID check; his Oct 19
    Play showed the plain stand-ins, so turn it on and send the `[HuzzKnife]` line or the red box);
    his own place still holds the broken 8 and his 30 without the Oct 19 materials ([knives.md](docs/notes/knives.md),
    "Owner how-to").
  - Import `Lobby_Props.glb`, run SetupLobbyProps, send `HuzzLobbyProps.rbxm` ([lobby.md](docs/notes/lobby.md)).
  - Developer Product IDs (Sunset Trail, Blossom Aura, coin packs, spins 1/10/100).
  - Upload sounds, pictures and animations (`Config/SoundIds`, `Config/ImageIds`, `tools/studio/publish-animations.lua`).
  - An export of their spin wheel model (match its colours); power icons; a stab animation; his crate design
    (contents, price, art: the Starter Crate is our first pick, [economy.md](docs/notes/economy.md)); dance names;
    movement pack licence; sharp PNGs for the Oct 17 screens (today mockup crops, placeholders).
- **Known gaps (ours):**
  - Not done yet (needs a screen): a dot on Menu when a quest can be claimed.
  - A refunded pass doesn't take its knives back yet.
  - LIKE THE GAME!, WITCH'S BREW and SWEETS & TREATS open nothing yet; titles on the three-pad side sit close.
  - The podium boards are hard to read from the spawn (his build, his call: [lobby.md](docs/notes/lobby.md)).
- **His place:** no Uncommon girls yet; loose plank path and hoop; lobby copies pasted twice; old islands unused
  ([round.md](docs/notes/round.md), [lobby.md](docs/notes/lobby.md)).
- **Us next:** whatever the owner's next round of fixes asks for first; then the Gift Picker, more lore chapters.

## 9. Index: where the deep notes live
| Topic | File | Read it when you touch |
|---|---|---|
| The round | [round.md](docs/notes/round.md) | stages, times, catching rules, safe zones, Practice Bot, maps, pay, girl odds, Results |
| Stab, lunge, catch | [stab-lunge-catch.md](docs/notes/stab-lunge-catch.md) | the stab and lunge motion, the catch's red fill and fall, getting up |
| Knives | [knives.md](docs/notes/knives.md) | skins, worn knife, Game Pass knives and cards, SetupKnives, stand sword showcase |
| Lobby, Lobby props | [lobby.md](docs/notes/lobby.md) | lobby per map, leaderboards, avatar stands, lobby props |
| Look and lighting | [look-and-lighting.md](docs/notes/look-and-lighting.md) | `Config/Look`, light, sky, lamp levels |
| Effects | [effects.md](docs/notes/effects.md) | Juice, powers, the girls' VFX, the showcase girl, effect pictures |
| Movement and camera | [movement-and-camera.md](docs/notes/movement-and-camera.md) | sprint, huss, FOV, round camera, shot changes |
| Animations and dances | [animations.md](docs/notes/animations.md) | the pack, walking, huss pose, girls' moves, carrying, dances |
| Economy | [economy.md](docs/notes/economy.md) | coins, Aura stars, wheel, quests, cosmetics, crates, admin panel |
| Secret cutscene | [secret-cutscene.md](docs/notes/secret-cutscene.md) | the Secret girl's 10 s reveal |
| Sounds and music | [sounds.md](docs/notes/sounds.md) | licensed picks, button sounds, made sounds, music, audio settings |
| UI | [ui.md](docs/notes/ui.md) | UI rules, text fit, living UI, round HUD, round screens |
| Knife study | [knife-study.md](docs/knife-study.md) | Huss Valley's knives frame by frame |
| Secret beats | [secret-beats.md](docs/secret-beats.md) | cutscene beat times (for sounds), ref3 comparison |
| Sound picks | [sound-picks.md](docs/sound-picks.md) | why each licensed sound was picked |
| Feel study | [feel-study.md](docs/feel-study.md) | the Oct 17 gaps vs Huss Valley |
| Loop audit | [loop-audit.md](docs/loop-audit.md) | stage times, waiting, win rates from the sim |
| VFX guide | [vfx-guide.md](docs/vfx-guide.md) | anime VFX built by code |
| Studio steps | [STUDIO-STEPS.md](docs/STUDIO-STEPS.md) | the owner's upload and test steps |
| Halloween plan | [HALLOWEEN-LOBBY-PLAN.md](docs/HALLOWEEN-LOBBY-PLAN.md) | his lobby plan, night look values |
| Pictures to make | [PICTURES-TO-MAKE.md](docs/PICTURES-TO-MAKE.md) | stand-in pictures he still makes |
| Previews | [previews](docs/previews) | every side-by-side, sheet and film |

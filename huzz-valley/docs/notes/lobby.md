# Lobby: lobbies per map, leaderboards, avatar stands, lobby props

Read before touching the lobbies, the boards, the avatar stands or the lobby props. The stand knives' moves and
effects: [knives.md](knives.md). Top-down plan of the lobby with our boards, stands and his props:
`docs/previews/new-lobby-layout.jpg` (`tools/world/lobby_dump.luau` + `tools/world/lobby_plan.py`). Owner's place
inspection with Lune: core `CLAUDE.md` section 4.

## One lobby per map (his new Halloween lobby everywhere)
- His one new Halloween lobby is pasted in front of each map (`Workspace > StartingPoint`; the BasketBall and
  Halloween copies are pasted twice on top of each other). The game finds each copy's plaza
  (`Shared/LobbyLayout.floors`: the biggest flat part per copy, 124 x 136, top 12.5; copies on top of each other count
  once), so it's still one lobby per map; spawns are his SpawnLocations on each plaza (in `Maps > Spawn`). His old
  islands stay where he moved them, unused (deleting them is safe: the game makes a spawn on each plaza if his
  SpawnLocations go too).
- Each map belongs to its nearest lobby (`entry.lobby`); after the vote `MapService.useLobbyFor` switches the lobby
  and RoundService moves everyone there after the load (streamed in first); only that lobby's SpawnLocation is on.
  With several lobbies a map loads exactly where it was built (the owner built floors level with their lobby); with
  one lobby, the old "in front of the lobby" placement. The paint fade runs when the map loads, once everyone is
  there. The floor finder accepts tops up to 2 studs over the Middle box (Halloween's grass sits above it).
- **Map look:** when a map wins the vote, `MapService.paintLobby` gives the lobby floor that map's floor colour,
  material and textures (the floor = the part found most under a 5x5 grid over the field; Halloween's orange is a
  Texture on its grass).
- Spec `tests/LobbyLayout.spec`; check `tools/preview/check_new_lobby.luau`.

## Lobby leaderboards
- References: his clip `design/lobby-ref/lb_f1.jpg`, `lb_f2.jpg` (night) and the HIGHEST LEVEL board up close in
  daylight in `oct19-lighting-ref.png`.
- **Look** (`Shared/LeaderboardLook`, layout measured in its header): 14 x 18 stud slab, 700 x 900 face: title Gotham
  Heavy 52, "GLOBAL · ALL TIME · TOP 50", 12 rows of 50 that scroll (headshot, "#1 name" centred, long names shrink,
  value right: "LEVEL 402", "2611" + trophy, "33.5K CATCHES"), white text with a dark slate outline, studs over the
  face (`assets/icons/board-stud.png`). **Slate blue-grey:** his daylight board measures 105,122,143 all over.
  `Colors.Face` 104,118,135 is that with the game's grade undone (the face is unlit; the spec checks it against
  Config/Look); row bands the same colour, marked by their light and dark edges. Halloween, calm: a faint web in the
  corner, a pumpkin and a candle welded on top, a soft orange glow at the base (lamps: pumpkin/candle/base 0.4/5,
  0.3/4, 0.3/6). Side by side, same spot and perspective: `docs/previews/leaderboard-vs-ref.jpg`
  (`tools/preview/leaderboard_vs_ref.py`: our face through his board's perspective, graded; slab 105,121,143 vs his
  105,122,143).
- **Turn** (`Gameplay/Leaderboards`, `Shared/LeaderboardRules`, `Config/Leaderboards`): each screen turns its copy
  about its own upright centre to face your root every frame (`TurnRate` 20, capped at `TurnSpeedMax` 300 deg/s so a
  respawn is a quarter-second swing, not 37 degrees in one frame), at most `TurnMax` 75. `aimSmooth` has no jumps:
  past the limit it holds, from 120 round it eases home (straight behind = home), `TurnRange` 120 studs then
  `TurnFade` 20 more. No body (respawning): it holds. **Never into his build**: `LeaderboardRules.room` with
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
  Valley's boards, so too small to read there) and his girls' display in the middle hides most of them (his call:
  core open items).
- **Numbers**: live only, one OrderedDataStore per stat (`HuzzValley_LB_v1_<Stat>`), saved every 90 s when changed and
  on leave, top 50 read every 60 s, budget-checked, every call in pcall (a failing store leaves just this server's
  players); players here always mixed in live, and someone who leaves stays listed until the next read (Studio: only
  who is here). JSON in attributes on `ReplicatedStorage.HuzzLeaderboards`.
- Checks: `tests/Leaderboards.spec.luau` (formats, order, colour, no jumps, room, 30/60 fps),
  `tools/preview/check_lobby_boards.luau` (the real client: turning, limit, home, holding while respawning).

## Avatar stands (`Gameplay/AvatarStands`, `HuzzServer/AvatarStandService`, `Shared/AvatarStandRules`)
- Turns any Part/Model named `AvatarStand` or tagged `HuzzAvatarStand` into a copy of the viewer's own avatar doing
  the sword showcase ([knives.md](knives.md); no knife: running in place, the owner's Run when it plays, else
  `RunMotion`; R6 a simple swing) holding its pass's exclusive knife in the right hand, turning to you calmly (the
  boards' turn, up to 70°), a calm glow, a sign (tag pill, title, "EXCLUSIVE KNIFE: CELESTIAL SERAPH") and a price
  button. Reference `design/lobby-ref/stands-ref.jpg`.
- **Where:** in his new lobby an invisible flat `AvatarStand` part each, in a row along the plaza's empty side,
  opposite the podium boards (`Shared/LobbyLayout.standSpots` + `pickRow`: a spot is clear when nothing over 1 stud
  stands in its box and nothing over 8 between it and the edge; lobby A x -183.5, z 18 / 28 at the front, 53.5 / 63.5 /
  73.5 further back, either side of the spin wheel; `Workspace > HuzzAvatarStands`, tagged, `StandOn` Top, facing into
  the plaza).
- **Which pass:** the back three sell Hunter, Moonlit and Sunrise Knife, the front two Inferno and Frost Knife: each
  stand one knife Game Pass and its knife, the five once each in every lobby copy (`AvatarStandRules.assign`, used by
  AvatarStandService and the place build; a stand on VIP / Dance Pack is moved onto the next knife pass; standSpots
  lists the back three first so they keep his card order). Older places: six grey-block stands, five knives (the
  sixth repeats Hunter Knife).
- `HuzzServer/AvatarStandService` makes them at game start when the place has no stands (his Rojo-synced place); the
  place build saves the same ones. Places without pads: his grey blocks beside the big spin wheels
  (`AvatarStandRules.findBlocks`; his old islands' blocks stay plain blocks). It puts a ready copy of each pass knife
  in `ReplicatedStorage > HuzzStandKnives` (his model from `ServerStorage/HuzzKnives/<Key>`, else the tinted built-in
  knife). Tall blocks hide and you stand where they stood; flat ones are pedestals (`StandOn`).
- **Buying:** the button opens `PromptGamePassPurchase` only with a real Game Pass ID AND a `Config/Products` pass
  that's OnSale; otherwise "SOON" / "COMING SOON" (today all of them: every knife pass has `Id = 0`). No timers or
  LIMITED/ENDS IN copy. The stand disc light is 0.4 / Range 6.
- **Owner how-to (Studio):** nothing to do: press Play. To move them in the downloaded build: Explorer > Workspace >
  HuzzAvatarStands > AvatarStand (invisible: click it in Explorer, then drag with Move), or change its Attributes:
  `Pass` (String: a Game Pass key from `Config/Products`, e.g. `HunterKnifePass`; `VIP` or `DancePack` is moved
  onto the next knife pass), `Knife` (String: one of that pass's
  knives, e.g. `CrimsonRequiem`; another pass's knife is refused with a warning), `Title`, `Subtitle`, `Tag`,
  `Price`, `Color`, `StandOn`. In his own Rojo place they're made fresh each Play; to keep his own spots there, copy
  the `HuzzAvatarStands` and `HuzzLeaderboards` folders from the downloaded build into his Workspace (then the game
  uses his). Real knife models: import `Gamepass_Knives.glb` and run SetupKnives ([knives.md](knives.md), "Owner
  how-to"). To sell: create the Game Pass on the Creator Dashboard, paste its ID into `Config/Products` (that pass's
  `Id`), `OnSale = true`. Leaderboards: drag the boards in `Workspace > HuzzLeaderboards` (each is a Model: click it,
  Move); a board's `Stat` attribute picks what it ranks.

## Lobby props (`Config/LobbyProps`, `Shared/LobbyLayout.propSpots`, `Shared/LobbyPropBuild`, `HuzzServer/LobbyPropService`, `Gameplay/LobbyProps`)
- One prop floats over each of the five round pads at the plaza's front, in every lobby copy; the place build saves
  them in `Workspace > HuzzLobbyProps`, one `LobbyProp` model per pad with attributes Title, Line, Opens, Scale, Color,
  Glow. From his `design/lobby/Lobby_Props.glb`, references `design/lobby/ref-halloween-shop.png`,
  `ref-shop-like-reward.png`.
- Two-pad side: SHOP (Shop_Stall, opens the Shop), LIKE THE GAME! (Like_Reward_Gift, decoration: Roblox can't tell a
  game who liked it, so no reward). Three-pad side: FREE SPIN (Pumpkin_Patch_Chest, opens Spin the Wheel; the line
  under it counts down to your real free spin), WITCH'S BREW (cauldron) and SWEETS & TREATS (coffin), decoration (no
  menu fits). A ProximityPrompt and a click open the menu (never in a round, never during `HuzzCinematic`).
- Each bobs 0.35 studs over 3.4 s and turns once in 18 s (client, within 200 studs), has a soft PointLight under it
  (0.5 / 7) that breathes over 4 s, a glow pool on the pad, 5 sparkles a second and a bold FredokaOne title (dark
  outline, white lift) in its colour. FREE SPIN's line looks its part up again until found (streaming).
- Until he imports his meshes each is built from plain parts in his colours (`HuzzServer/LobbyPropShapes`, baked by
  `tools/props/bake_props.py`: no stud textures, no SHOP / LIKE pictures, rings, chains, vines or frosting; the coffin
  is boxy). Side by side `docs/previews/lobby-props-vs-ref.jpg` (`tools/props/prop_meshes.py` + `render_props.mjs` +
  `props_vs_ref.py`: his meshes as the helper sets them up, bloom and grade added).
- **Owner how-to (Studio, once):** 1. File > Import 3D > `huzz-valley/design/lobby/Lobby_Props.glb`, Import.
  2. Command Bar: `require(game.ServerStorage.HuzzStudioTools.SetupLobbyProps)()` (or paste
  `tools/props/setup_lobby_props.lua`). 3. Output: `[HuzzProps] Done: 5 of 5`; the pads swap to his models.
  4. File > Save; right-click ServerStorage > HuzzLobbyProps > Save to File, send `HuzzLobbyProps.rbxm`; it goes in
  `assets/props/` (not there yet) and `build_yours.luau` puts it in every build. Spec `tests/SetupLobbyProps.spec`
  (Studio-style turn, size and names). To move one: drag its `LobbyProp` in `Workspace > HuzzLobbyProps`; `Scale`
  sets its size.
- Open: stand-ins until he sends `HuzzLobbyProps.rbxm`; the titles on the three-pad side sit close (pads 7 apart);
  LIKE THE GAME!, WITCH'S BREW and SWEETS & TREATS open nothing yet.

## Honest gaps
- Not seen in Studio yet: the move between lobbies after the vote (instant, no fade yet), the lobby repaint; the
  lobby leaderboards (studs picture (Play only), the slab colour under his grade, Gotham's size, headshots,
  scrolling, the calm turn, the pumpkin, candle and glow, the Oct 19 slate colour, the turn stopping before his
  slope); the avatar stands (your copy, its run, the knife in its hand); the new lobby (the boards on the terrace
  ledges turning without touching the slope behind, the stand row, the move back after a game); the lobby props
  (his meshes after the import, the bob, turn, glow and titles).
- His place: the BasketBall and Halloween copies in `StartingPoint` are pasted twice (every part twice in the same
  place; the game counts them once, but it doubles those parts); his old islands still float off to the side in
  `Maps > Spawn` (unused). The podium boards are hard to read from the spawn: moving the spawn toward the podium side,
  or the display, would fix it (his build, his call).

## Why it is this way / history
- **One lobby per map** (owner's pick, Oct 17): he first built a lobby island in front of each map. Oct 18 he replaced
  them with one new Halloween lobby ("I made it the lobby for all of the maps"). Before that he planned it from
  `docs/HALLOWEEN-LOBBY-PLAN.md` + `docs/previews/halloween-lobby-layout.png` (Huss Valley's Halloween lobby, 200 x 182
  round his island; drawn by `tools/world/halloween_layout.py`, his real positions from
  `tools/world/measure_halloween_lobby.luau`). The night look needs `Config/Look` changed (game-wide); values are in
  the plan.
- **Leaderboards** (owner, Oct 18: "make the leaderboards just like in the video ... make them follow your character",
  "move smoothly", "look more like the reference ones but keep some halloween mood", "make it follow me in real time,
  not adjust after i move"; Oct 19: "please check the leaderboards over again"). The slate colour is from Oct 19: the
  clip's mauve was the same board under his night lobby's purple light. The old aim flicked 75 degrees at 120 round
  and at the range edge, so it flicked back and forth while you stood on that line; hence `aimSmooth`.
- **Avatar stands** (owner, Oct 18: "make the blocks i have in the lobby, next to the spin the wheel turn into my
  character and have like animated running ... selling a gamepass", then "make the character things in the lobby
  work ... gamepasses shown with the character of the person playing, equipped with some exclusive knifes"). In his
  new lobby (Oct 18: "add ... all of the gamepass things to the new lobby") the pads hold his props, so the stands
  moved to the empty side.
- **Lobby props** (owner, Oct 18: "implementing these objects into the lobby on top of the already placed circles.
  Give it some VFX and make it look good just like in the pictures"). The Oct 19 light turned their lamps down from
  1.4/12 (fainter pad pools); the boards' from 0.8/7, 0.5/5, 0.6/9.

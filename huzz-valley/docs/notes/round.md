# The round (`Shared/RoundRules` + `RoundService`)

Read before touching the loop, its times, catching rules, safe zones, the Practice Bot, maps and field edges, pay,
girl odds or the Results screen. The stab/lunge/catch motion and VFX: [stab-lunge-catch.md](stab-lunge-catch.md).
The lobby side (one lobby per map, paint, his new lobby): [lobby.md](lobby.md). Quest XP and coins: [economy.md](economy.md).

## Stages and times
- Lobby: `VoteTime` 30 s, `IntermissionTime` 25 s ("a bit more, so people can buy things, not too long").
- Stages: Waiting → Voting → Rolling (girl roller) → per round: Lineup → Picking (HERO/CHICKEN, 6 s) → Chosen →
  HeroRun → Countdown → Running → RoundOver; GameOver.
- **Last runner standing** (owner Oct 19: "make the round not be capped at 3, but go on until there is one person left
  in the runners and he wins the game and wins the girl"): rounds go on, caught runners join the catchers, and the
  round that ends with one runner left (game started with 2+) makes them the winner and moves the girl to them
  (`RoundRules` "LastStanding", GirlMoved "Last"). No runners left = catchers win. A game that started with one
  runner (practice with the bot, or 1 runner vs 1 catcher) still ends after `Crossings` 3 clean rounds in a row.
  `MaxRounds` 20 is only a safety net (the runners left win). HUD: "ROUND n · N RUNNERS LEFT". Loop audit: games
  with 4-12 players last about 4-5 min, 6-9 rounds; a few hit the 20-round net.
- `lune run huzz-valley/tools/sim/round_sim.luau audit` prints stage times, waiting and win rates by player count,
  on the real map size.
- Lineup 3 s, ChooseTime 6, ShowTime 2, RoundEndPause 2.5, HeroTime 30, RoundTime 60. One runner on the line skips
  the roulette (PickAt is set back so clients skip it too).
- **Countdown after a camera shot** (CHICKEN or no answer): RoundService adds `CAMERA_BACK` 0.6 s to a Countdown that
  follows Lineup/Picking/Chosen, so the camera's 0.3 s swing back ends first; RoundHud draws only the last 3 s, never
  while `HuzzCinematic` is on, times GO! from the server's EndsAt, and hides every HERO/CHICKEN tag word until GO!
  fades. Check: `tools/preview/check_countdown.luau`; strip `docs/previews/chicken-countdown.jpg` (`countdown_strip.py`).
- **Stalls** (`Config/Round.Hurry`, `RoundRules.stalling`): everyone still to cross standing in the start zone for 5 s
  → the clock drops to 6 s ("Hurry! Run or you're out"; `hurry()` moves EndsAt too). A Hero still in the start
  zone after 6 s loses the solo run ("X didn't go. Everyone runs!"; counting starts 1 s in, "Go now!" to the Hero at
  3 s). Not counted while trapped or on the line; a catcher or the bot within 10 studs of the zone buys 10 s.
- **Last runner** (`RoundRules.lastRunner`, `Speeds.LastRunner` 30): in a round that started with 2+ runners, the
  only one still out is called out once ("X is the last runner!") and runs as fast as the real catcher (the bot's
  speed when it catches; never under 28); with Rizz Rush capped at catcher + 4.
- **Power cards survive the Hero run:** after a Hero run RoundService calls `PowerService.clear(true)` (traps and
  effects go, cards and cooldowns stay). The sim checks every runner/catcher still playing has PowerReady1 in
  Running/HeroRun.
- **Powers** (free each round, `Config/Powers`): runners Heart Shield + Rizz Rush; catchers Love Trap + Charm Wave.
  Their look: [effects.md](effects.md).
- **Speeds** (`Config/Round.Speeds`): lobby 22, runner 28, catcher 30, holder 27. `Gameplay/Sprint` sets off at 16
  and reaches the cap in ~0.5 s ([movement-and-camera.md](movement-and-camera.md)). Run animation rate caps keep it calm.

## Catching
- **Click stab** (`Stab` remote) or a catcher's **lunge** (`Lunge` remote, `Config/Round.Lunge`: eases 72 to 40 over
  0.38 s, the way you steer: `Shared/KnifeLeap.direction`, forward or sideways with A/D, never back; the hit box
  points along the leap; a whole-body leap with the slash when the knife reaches someone; Up 24, HitRange 4.8 for
  0.5 s, cooldown 3 s shared with the Space tile `DashReady`; stab mode only). Both go through `stabNear()`: shields,
  the safe start zone and a fresh rescue protect; a Heart Shield ends the lunge.
- **Pinpoint:** the catcher's own screen picks the runner whose body is in a box in front of them (`Gameplay/HitCheck`;
  Stab Reach 5.5 x Width 4, Lunge 4.5 x 4) and sends that UserId (false = a miss); the server only checks it's
  possible (Range/HitRange + Slack 3, one runner per lunge). A client that sends nothing gets the old server search
  (the sim bots).
- **Catchers stay out of both safe zones:** `MapService.holdCatchers` stands an invisible wall on each zone's
  middle-facing edge for the whole game, group `HuzzCatcherWall`, colliding only with `HuzzCatcher` (catchers' parts,
  `MapService.setCatcher` from `syncPlayer`; the bot too); `keepSafe()` pushes out any catcher who got past
  (`MapService.pushOut`).
- **Downed and revived:** a downed runner lies still (`KnockdownService`): `DownMotion` owns every joint (root, waist,
  hands, feet straight; arms out flat 125°, chin up 40°, no bounce, Lift 0.6), so the run playing underneath can't
  swing the body or push it into the floor. Spec: still and above the floor; picture `docs/previews/downed-still.jpg`
  (`motion3d/down_scene.luau`). A runner beside them for 1.2 s revives them. **One second chance per game**
  (`RoundRules` `rescued`): caught again = `Caught.final` → "YOU'RE OUT", no rescue; joins the catchers at round end.
  Their tag says OUT (grey) instead of HELP!, so nobody runs over for nothing (a downed tag shows to 250 studs,
  HELP! / OUT big; other tags hide past 80); `HuzzOut` on the player makes their HUD say "OUT. You join the catchers
  next round". The hit, slide and getting up: [stab-lunge-catch.md](stab-lunge-catch.md).

## Who gets the girl
- **Chicken still wins her** (owner Oct 19: "make them get her"): choosing Chicken never takes the claim away. The
  Hero's edge is getting her first, alone, plus the Hero bonus. `s.chickens` still records who chose Chicken.
- **First across wins her when no Hero did:** after Chicken, a caught Hero or a timed-out Hero, while she still
  floats, the first runner across takes her (`RoundRules.reachSafe`, GirlMoved "First", "X got there first and won
  <girl> over!"), the one who chose Chicken included. A catcher holding her keeps her.
- A catchers' win: the girl goes to the catcher with the most catches (lead breaks ties).
- **Girl odds** (`Config/Round.Rarities`): Common 28, Uncommon 24, Rare 20, Epic 14, Legendary 8, Mythic 4.5,
  Secret 1.5. The Secret girls are **C.C. and Marin** (owner, Oct 17; `Config/GirlNames`); their cutscene:
  [secret-cutscene.md](secret-cutscene.md).
- Girl names (`Config/GirlNames`): the owner's own list (Oct 18), matched by the code at the end of each model's name
  (e.g. `_E2B52D` = Rem); Alya, Rize, Waguri, Yui and Miku Nakano had no code match and are best guesses (header).

## Practice Bot (`HuzzServer/PracticeBot`, `Config/Round.Bot`)
- Any round with runners and no catcher (alone, or the only catcher left) gets a server NPC catcher named "Practice
  Bot" (default blocky body from `CreateHumanoidModelFromDescription`, grey with a red shirt, tag CATCHER / BOT, a knife).
- Starts at Speed 24 and adapts (`Bot.Step` 2 slower after it wins a game, faster after it loses, 18 to 28; its Reach 5
  scales with it; "is slower/faster this game" when its next game starts; back to 24 when the game's players change
  or the server empties; only games where it caught the last round count), stabs through `stabNear(nil, ...)`,
  1.2 s breather after each stab.
- If it downs everyone nobody wins ("THE BOT WINS", no girl, no winner's pay). With it, one player starts a game in
  the live game too (`minPlayers` 1). Red outline like catchers; round walls it follows a PathfindingService path
  (computed in a task.spawn when a raycast to the target hits something solid), and sidesteps when stuck. The sim
  tests it with a fake body. Its stab animation: [stab-lunge-catch.md](stab-lunge-catch.md).

## Maps and the field (`MapService`)
- In his place maps are in `Workspace.Maps` (Base_Map, BasketBall_Map, Halloween_Map; zone parts named
  case/space-insensitively); the lobby floors are the plazas of the 3 copies of his new lobby in `StartingPoint`
  (`Shared/LobbyLayout.floors`; the old `Maps.Spawn.SpawnBaseplate`s are no longer used). `check_maps.luau` lists
  maps, lobby pairs and safe lines.
- **Safe gate:** invisible goal-line block in collision group `HuzzSafeWall`, colliding only with `HuzzSafe` (safe
  runners), plus `keepSafe()` every frame. The start wall and the goal gate have no visuals; the white lines on the
  floor mark start and finish.
- **Field edges:** safe lines, start wall and goal gate are trimmed to the real floor (`MapService` `edge()`); the
  invisible walls (`boundary()`) stand at the floor's edge (a prop doesn't count as an edge). Across the run the
  walls may go up to 40 studs past the zone boxes over the map's own level floor, and the loaded copy's zones are
  then stretched to the floor. Loose Workspace parts resting on a map's floor move into that map at start
  (`check_maps.luau` counts them); `catchFalls()` puts anyone below the field back on it (only within 8 studs of it)
  or far below the lobby back to its spawn.
- Maps load per lobby and repaint the lobby floor: [lobby.md](lobby.md). Map pictures in the vote: [ui.md](ui.md).

## After a game
- **Results screen** (`Screens/Results`): after a game, once back in the lobby with nothing open (it waits out the map
  vote) a GAME OVER window: YOU WIN / YOU LOST / THE BOT WINS, who got the girl, cards for crossed / caught / saved /
  hero runs (this game only: RoundService `tally`, filled by `addStat`) and the coins + Aura earned (Round remote
  "Results", per player; coins include a Hero bonus, Aura the stars collected: player attribute `HuzzGameAura`).
  Also a CATCHES card, XP pill, "X takes her home"; Hero card "Make it: carry her +25", Chicken "First across wins her".
  Preview: `shots.sh <out> results`.
- **Pay:** 25 coins a game, 50 for a win, +3 Aura on a win, Hero bonus 25 (only with another runner in the game);
  x2 while a wheel boost lasts. A catchers' win pays only catchers who caught someone (or the lead). A repeat girl
  pays `DupeCoins` by rarity.
- XP every game (`Config/Progression.GameXP`: 40 + 40 win + 25 a Hero run + 5 per crossing/rescue/catch; each level
  past the track pays `Beyond` 100 coins + 10 Aura). A chapter opens once ONE quest of the chapter before is claimed
  (solo players can't rescue or catch; the screen shows `Progression.shownChapter`); only runners pick up stars in
  a game.

## Messages and state
- **News vs big moments:** RoundService `announce(text, color)` only writes the message line (no "big" flag;
  colour = green good news, red caught/out, white news, rarity colour for the prize). Centre words are RoundHud's
  own: 3-2-1, GO!, SAFE!, FIRST!, YOU'RE DOWN/OUT, BACK UP!, the win and "<girl> IS YOURS". The HUD: [ui.md](ui.md).
- State lives in attributes (Round remote: Stage, EndsAt, Goal, Streak, PickId, HolderId, VoteWinner...; players:
  HuzzRole, HuzzStatus, DashReady, ProtectedUntil...; characters: DashAt/Dir, LungeAt, HuzzDance/At).

## Honest gaps
- Not seen in Studio yet: the Practice Bot (its walk, run animation, knife).
- His place (Oct 17): no Uncommon girls yet (the rarity is skipped until there are some); a plank path near the
  Halloween lobby and a basketball hoop sit loose in Workspace (the path's pieces on the field now move into
  Halloween_Map at start; the pieces on the lobby stay).

## Why it is this way / history
- Loop audit (Oct 17, `docs/loop-audit.md`): half of everyone's time was frozen, hence the short Lineup, ChooseTime,
  ShowTime and RoundEndPause and the skipped roulette.
- Owner Oct 18 ("make the round a bit longer, for example the hero round"): HeroTime and RoundTime went up from 20
  and 45.
- **Power cards:** owner Oct 18: "if you run out of time why dont you have any buttons after?". Plain `clear()` had
  wiped PowerReady1/2, which hid the whole power bar (and the huss card) for the run that followed.
- **Countdown:** owner, "the numbers just dont appear well" after a CHICKEN or no answer.
- **Lunge Up 24** (from 18): the body was off the floor too briefly to read; details in [stab-lunge-catch.md](stab-lunge-catch.md).
- **Pinpoint:** owner Oct 18: "make hitboxes pinpoint".
- **Catcher walls:** owner Oct 18 asked that catchers stay out of both safe zones.
- **Chicken:** owner Oct 18: "you dont recieve the girl if you run chicken". Later the same day: "if you go chicken,
  still the first person to reach the safe zone gets the girl, right now nobody does". Oct 19 (alone, he chose
  Chicken in round 1, crossed first and got nothing): "fix the users not getting the girl if they win on the chicken
  round in the first round ... make them get her", so Chicken no longer blocks her at all.
- **Downed pose:** owner Oct 18: "not have a swinging animations ... make them lay on the floor and look like their dead".
- **Practice Bot:** owner picked "Yes, add bots" (Oct 17).
- **Speeds** were raised twice before reaching today's numbers.
- **No laser walls:** owner Oct 18: "get rid of laser wall".
- **Field edges:** Halloween's zones sat 15 studs off its floor: a wall cut the field and the girl wasn't centred
  (owner Oct 18). His Halloween path floated over the sea with another map on, hence moving loose floor parts.
- **Girl odds** were raised after "I'm only getting commons".
- **Loop audit 2 (Oct 18, fixes in):** the catcher-only pay, the girl to the top catcher, XP every game, the Hero bonus
  only with another runner (solo farming paid ~10x), Pay 25/50, `DupeCoins`, the one-quest chapter rule and runners-only
  stars all came from it. Results got the CATCHES card and the XP pill then.
- **News vs big moments** came from the feel study (Oct 17). The Results screen is from Oct 17.

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
  with 4-12 players last about 4-5 min, 6-9 rounds; a few hit the 20-round net. **Known gap (Oct 19):** an AFK
  player drawn as the only catcher catches nobody, so the game runs all 20 rounds (about 11 min, runners crossing
  an empty field); nothing swaps him out yet (audit "6 + 1 AFK": 4 of 23 games hit the net; a traced run showed
  the AFK catcher's game going all 20 rounds, and a lone real catcher against 5 runners sometimes taking 13-20).
  The sim's "AFK runner" scenario lets its AFK bot play only when he is the only catcher, so it tests the AFK
  runner, not this gap.
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
  speed when it catches; never under 28); with a Speed Boost capped at catcher + 4.
- **Power cards survive the Hero run:** after a Hero run RoundService calls `PowerService.clear(true)` (traps and
  effects go, cards and cooldowns stay). The sim checks every runner/catcher still playing has PowerReady1 in
  Running/HeroRun.
- **Abilities** (free each round, `Config/Powers`; simple names, owner Oct 19: "make simple lingo such as rizz rush,
  just make it simple"; they were Heart Shield, Rizz Rush, Love Trap, Charm Wave):
  - Runners: Q is one of **Shield / Invisible / Glitchy / Body Double**, picked at random each round by
    `PowerService.newRound` (never the same as your last round; `RunnerPick`, slot name "Pick"; his picture c shows
    one card). E is **Speed Boost**, which only works while you carry the girl (owner: "give the rush to a person only
    having the girl": the server refuses it otherwise, the card only shows then; the sim flags a boost by anyone else).
  - Catchers: Q **Bear Trap** (thrown Throw 10 studs ahead with a throw pose, flies Flight 0.6 s, lands on the floor
    short of walls and field edges and never in the start zone, arms Arm 0.35 s later; MaxOut 2; snaps round the
    runner's feet and holds Hold 1.6 s), E **Slow Wave**.
  - Every ability is refused while stunned or stuck (`PowerService.use` checks `stuck`).
  - Names, numbers and card text: `Config/Powers`. Their look: [effects.md](effects.md); the cards: [ui.md](ui.md).
- **Speeds** (`Config/Round.Speeds`): lobby 22, runner 28, catcher 30, holder 27. `Gameplay/Sprint` sets off at 16
  and reaches the cap in ~0.5 s ([movement-and-camera.md](movement-and-camera.md)). Run animation rate caps keep it calm.
  **Each round is a tiny bit faster:** +2% per round after the first, capped at +20% (`Config/Round.SpeedUp`,
  `RoundRules.speedScale`), for runners, catchers and the Practice Bot alike (`PracticeBot.setScale`), set on the
  server; the lobby never changes. `State` attribute `SpeedUp` (1.06 = 6% faster) is there for the HUD.

## Catching
- **Click stab** (`Stab` remote) or a catcher's **lunge** (`Lunge` remote, `Config/Round.Lunge`: eases 72 to 40 over
  0.38 s, the way you steer: `Shared/KnifeLeap.direction`, forward or sideways with A/D, never back; the hit box
  points along the leap; a whole-body leap with the slash when the knife reaches someone; Up 24, hits for HitWindow
  0.5 s (HitRange 4.8 is only the sim bot's "close enough to leap"), cooldown 3 s shared with the Space tile `DashReady`; stab mode only). Both go through `stabNear()`: shields,
  the safe start zone and a fresh rescue protect; a Shield ends the lunge. The players see it as the **dive**
  (owner Oct 19: "add a dive feature for the tagger and after they use it they are stunned for 2 seconds"): after
  `Lunge.StunAfter` 0.38 s the catcher is stunned for `Lunge.Stun` 2 s (`PowerService.stun`: speed 0, no stab, no
  abilities; RoundService calls it right after setting LungeAt). The knife needs `Stab.Cooldown` 1 s between stabs
  (owner: "one second charge time for knife only"; the bar shows KNIFE CHARGING).
- **Touch is the real bodies** (`Shared/TouchHit`, one rule for the screen, the server and the spec): the knife's
  reach is a box from the catcher's middle out along their facing (or their leap): Stab Reach 4.5 x Width 3.5, Lunge
  4.5 x 4, 7 tall. It counts only if it overlaps one of the runner's own body parts (limbs, torso, head; never hats,
  hair, wings or the worn knife), give or take `Touch.Tolerance` 0.4 studs (a separating-axis box test). Straight
  ahead the knife reaches 4.4 studs past the catcher's chest.
- The catcher's screen (`Gameplay/HitCheck`) picks the runner it touches and sends that UserId (false = a miss)
  **and what it showed** at that moment: the runner's root as drawn (`seen`) and the catcher's own (`mine`).
  **Pinpoint (Oct 19): the server judges that** (`RoundService.screenHit`, `Shared/TouchHit.verify`), tied to its
  own history (`HuzzServer/HitHistory`, every player's root for 0.6 s, `Touch.Keep`) so a cheat gains at most 1 stud:
  - one moment: `seen` within 1.5 studs (`SeenSlack`) of the runner's path, no further back than the catcher's ping
    + 0.15 s (`TouchHit.lookBack`, at most 0.35 s `MaxRewind`); the runner's turn is the server's, not the claim's;
  - `mine` within 1.5 studs (`MineSlack`) of where the server has the catcher over the last 0.2 s (`MineBack`), or
    0.06 s on at their speed (`Lead`: a diving screen is a packet ahead of the server);
  - the knife points the way the server has the catcher facing (a claimed facing only within 35°, `FaceSlack`), or
    along the dive; its box from `mine` touches the body at `seen`;
  - the cap: the same box from the server's own catcher touches the runner where the server had them at that
    moment, give or take 1 stud more (`CapSlack`).
  A claim that fails falls back to the server's own test (below), so no fair hit counts less often than before.
  One runner per lunge, and a dive's claim only up to its landing (`Lunge.StunAfter` + 0.1 s from the press; the
  catcher then lies stunned). A client that sends no `seen`/`mine` (old clients, the sim's bots) gets the server's
  own test: the body anywhere between now and ping/2 + 0.1 s ago (`Touch.Smoothing`), at most `MaxRewind`,
  re-checked for 0.25 s; a client that sends nothing at all gets that test without a pick. Why and the measured gap: [stab-lunge-catch.md](stab-lunge-catch.md)
  "Pinpoint". The Practice Bot's knife is checked where it
  was 0.1 s ago (what runners saw) against bodies now. Spec `tests/TouchHit.spec` (prints the numbers above).
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
  <girl> over!"), the one who chose Chicken included.
- **A catcher who catches her carrier keeps her only until the next runner gets across** (owner Oct 19, rule
  "Reclaimed"): she walks behind him (on foot, as before: `CarryService.follow`), the line says "X caught her carrier!
  Next runner across takes <girl> back!" (only while someone can still get across: on the catch that ends the game it
  says "X caught the last runner!", or just "X caught her carrier!" when the last runner standing wins; counted when the
  line goes out, so two catches in the same frame count both), and the next runner to reach the safe zone (any round) takes her ("X made
  it across and took <girl> back!"). Runners already across don't. A Hero who makes it still takes her first.
- **A catchers' win (nobody left):** she goes to the catcher who caught the LAST runner (owner Oct 19;
  `RoundRules` `lastCatchBy`; the HUD says "X caught the last runner and wins <girl>"). If the clock or a fall caught
  the last runner (or the last runner left), the catcher holding her keeps her, else the one with the most catches
  (lead breaks ties).
- The quest stat "Steals" counts only a catcher taking her off her carrier ("Stolen"), not a hand-back, the last
  runner's win or a reassign.
- **Everyone caught turns into a catcher** (owner Oct 19) from the next round (not mid-round, so a round stays
  readable); a rescue in the same round keeps them a runner. The last runner standing still wins the game and her.
  The sim checks every caught runner is a catcher at the next line-up.
- **Girl odds** (`Config/Round.Rarities`): Common 28, Uncommon 24, Rare 20, Epic 14, Legendary 8, Mythic 4.5,
  Secret 1.5. The Secret girls are **C.C. and Marin** (owner, Oct 17; `Config/GirlNames`); their cutscene:
  [secret-cutscene.md](secret-cutscene.md).
- Girl names (`Config/GirlNames`): the owner's own list (Oct 18), matched by the code at the end of each model's name
  (e.g. `_E2B52D` = Rem); Alya, Rize, Waguri, Yui and Miku Nakano had no code match and are best guesses (header).

## Practice Bot (`HuzzServer/PracticeBot`, `Config/Round.Bot`)
- Any round with runners and no catcher (alone, or the only catcher left) gets a server NPC catcher named "Practice
  Bot" (default blocky body from `CreateHumanoidModelFromDescription`, grey with a red shirt, tag CATCHER / BOT, a knife).
- Starts at Speed 24 and adapts (`Bot.Step` 2 slower after it wins a game, faster after it loses, 18 to 28, times
  the round's speed-up; it stabs with the knife's box like a player (it used to hit anything within Reach 5 all round); "is slower/faster this game" when its next game starts; back to 24 when the game's players change
  or the server empties; only games where it caught the last round count), stabs through `stabNear(nil, ...)`,
  1.2 s breather after each stab.
- If it downs everyone nobody wins ("THE BOT WINS", no girl, no winner's pay). With it, one player starts a game in
  the live game too (`minPlayers` 1). Red outline like catchers; round walls it follows a PathfindingService path
  (computed in a task.spawn when a raycast to the target hits something solid), and sidesteps when stuck. The sim
  tests it with a fake body. Its stab animation: [stab-lunge-catch.md](stab-lunge-catch.md).

## Maps and the field (`MapService`)
- In his place maps are in `Workspace.Maps` (Base_Map, BasketBall_Map, Halloween_Map; zone parts named
  case/space-insensitively); the lobby is ONE of the 3 copies of his new lobby in `StartingPoint` (the others are
  put away at start: [lobby.md](lobby.md); the old `Maps.Spawn.SpawnBaseplate`s are no longer used).
  `check_maps.luau` lists maps, the lobby and safe lines.
- **Where bodies go** (owner, Oct 19: "make them spawn not in the middle inside of objects and just make them spawn
  on open ground"; "make catchers spawn in the middle"). Every spot is open ground (`Shared/SpawnSpots`, rules in
  [lobby.md](lobby.md)):
  - **Catchers** (`MapService.middleSpot(i, start)`, from `RoundService.place`): a row across the field on the line
    halfway between the two safe lines (`fieldMiddle`, within 0.5 studs of his Middle box's centre on all three
    maps), 5 studs apart, the first dead centre, extra rows 4 studs either side; inside the walls, outside both safe
    zones, facing the runners' start zone. The Practice Bot takes spot 1. Before: a random spot up to 20 studs from
    the Middle box (open, but scattered).
  - **Runners on the line** (`MapService.lineup`): the planned shoulder-to-shoulder spot, moved up to 2 studs to
    open ground (behind the line, in the zone, 3 from the others), else the next free place along the line or in
    the rows behind.
  - **Bench / lobby / respawn / rejoin:** `benchSpot` (open ground near a point on the bench), `lobbySpot` (the spawn
    pad), his SpawnLocation on the pad.
  - Spec `tests/Spawns.spec.luau` (his place, every map, 1 / 6 / 12 / 24 runners, 8 catchers); the sim stubs these
    spots with the old random ones.
- **Safe gate:** invisible goal-line block in collision group `HuzzSafeWall`, colliding only with `HuzzSafe` (safe
  runners), plus `keepSafe()` every frame. The start wall and the goal gate have no visuals; the white lines on the
  floor mark start and finish.
- **Field edges:** safe lines, start wall and goal gate are trimmed to the real floor (`MapService` `edge()`); the
  invisible walls (`boundary()`) stand at the floor's edge (a prop doesn't count as an edge). Across the run the
  walls may go up to 40 studs past the zone boxes over the map's own level floor, and the loaded copy's zones are
  then stretched to the floor. Loose Workspace parts resting on a map's floor move into that map at start
  (`check_maps.luau` counts them); `catchFalls()` puts anyone below the field back on it (only within 8 studs of it)
  or far below the lobby back to its spawn.
- Maps load in front of the one lobby and repaint its floor: [lobby.md](lobby.md). Map pictures in the vote: [ui.md](ui.md).

## After a game
- **Results = the winner page** (`Screens/Results`, owner Oct 19 "winner page", his picture a; layout in
  [ui.md](ui.md)): after a game, once back in the lobby with nothing open (it waits out the map vote): RUNNERS WIN /
  CATCHERS WIN / THE BOT WINS, MVP / Survival / Catches top 3 with avatars, your XP and its parts, coins + Aura
  earned, your girl line ("X takes her home"), your level bar. The Round remote's "Results" (per player) carries `board` (everyone's
  numbers this game: RoundService `tally`, filled by `addStat`), `team`, `xp`, `heroPaid`, coins (with a Hero bonus
  and the friend +10%) and Aura (the stars collected: player attribute `HuzzGameAura`). Rankings: `Shared/Standings`.
  Preview: `shots.sh <out> results results-catchers`. (Hero card "Make it: carry her +25" and Chicken "First across
  wins her" are the HeroChoice cards.)
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
- Not seen in Studio yet: the Practice Bot (its walk, run animation, knife), the touch with real lag (the server's
  look-back uses `GetNetworkPing`), how often the bot catches now (sim: 2 catches in 10 games, was 5 in 11: it must
  really touch you, so it may need to be faster); the catchers' row in the middle and the open-ground line-up
  (checked offline on his place only).
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
- **Pinpoint:** owner Oct 18: "make hitboxes pinpoint". Oct 19: "make the player to player touch WAY MORE accurate".
  Measured: the screen box was 5.5 x 4 and counted accessories, the server took any claim within Range + Slack =
  11.5 studs root to root, its fallback 8.5 studs at almost any angle, the bot 5 studs all round. Now everything is
  the same body-touch test, with the look-back so a fair hit on a laggy screen still counts.
- **Speed up:** owner Oct 19: "speed goes up every round a very tiny bit".
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
- **The catcher's hold on her** (owner, Oct 19): "please make it so that if the catcher gets the girl and there are
  still runners left the catcher keeps the girl until the next runner makes it to the safe zone. And the girl will be
  recieved by the catcher only if at the end he catches the last runner." and "every person who got caught turns into
  a catcher". Before, a catcher who caught her carrier kept her for good, and the catchers' girl went to the most
  catches.
- **Loop audit 2 (Oct 18, fixes in):** the catcher-only pay, the girl to the top catcher, XP every game, the Hero bonus
  only with another runner (solo farming paid ~10x), Pay 25/50, `DupeCoins`, the one-quest chapter rule and runners-only
  stars all came from it. Results got the CATCHES card and the XP pill then.
- **News vs big moments** came from the feel study (Oct 17). The Results screen is from Oct 17.

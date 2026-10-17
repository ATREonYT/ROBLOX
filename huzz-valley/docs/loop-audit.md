# Loop audit (Oct 17)

Owner's ask: "make the mechanics the best they can be, and make the core loop be the best".

How the numbers are made: `lune run huzz-valley/tools/sim/round_sim.luau audit [runs] [setup]` (repo root) plays
the REAL server code (RoundService, RoundRules, PowerService, PracticeBot) with bot players on a field the size of
the owner's maps (safe lines 280 studs apart, 165 long; `tools/check_maps.luau`). 8 runs of 30 minutes per setup.
`HUZZ_SRC=<old src folder>/` runs an older copy of `src` with the same bots, for the "before" column.

The bots: runners sprint (walk 9 building to 28 over 1.2 s), most curve away from a catcher ahead of them and huss
sideways when one gets within 9 studs, 60% go and help up a downed runner nearby; catchers chase where a runner was
0.33 s ago (a kid's reaction plus lag), half stab, half lunge (the leap carries them). A "beginner" runs straight
across and never husses. "AFK" never moves or answers.

**Read the win rates as a trend, not the truth.** They swing with bot skill: with catchers that react instantly,
runners won 1 to 4% at every size; with the 0.33 s reaction, about half at 4+ players. Against the Practice Bot a kid
alone won 82% if they steer, 11% if they run straight. With 65 to 95 games per setup, a win rate moves about 6 points
from noise alone. What held at every skill level: half of everyone's time was frozen, an AFK runner stalled rounds,
and 1 or 2 player games were lopsided.

## What we found (before)

| Players | Game length | Rounds/game | Runners win | Hero runs made | Rescues/game | Frozen per round | Rounds hit the 45 s clock |
|---|---|---|---|---|---|---|---|
| 1 (+ Practice Bot) | 88 s | 2.8 | 82% | 89% | 0 | 15.9 s | 0% |
| 1 beginner (+ bot) | 54 s | 1.6 | 11% | 13% | 0 | 17.3 s | 0% |
| 2 | 61 s | 1.8 | 26% | 42% | 0 | 16.9 s | 0% |
| 4 | 120 s | 3.1 | 59% | 60% | 0.3 | 19.2 s | 0% |
| 8 | 151 s | 4.0 | 44% | 60% | 1.8 | 18.6 s | 0% |
| 12 | 163 s | 4.2 | 37% | 53% | 4.2 | 19.3 s | 0% |
| 6 + 1 AFK | 184 s | 4.2 | 45% | 49% (5% ran out of time) | 0.8 | 19.8 s | 19% |

"Frozen per round" = line-up + pick + show + countdown + round over. No game reached MaxRounds (12); the sim found
no rule problems.

Share of each player's time:

| Players | play (run, chase, rescue) | frozen | watching a Hero run | safe, waiting | down, waiting | lobby |
|---|---|---|---|---|---|---|
| 1 (+ bot) | 24% | 49% | 0% | 1% | 0% | 26% |
| 2 | 18% | 49% | 0% | 0% | 0% | 33% |
| 4 | 23% | 48% | 5% | 2% | 1% | 20% |
| 8 | 23% | 48% | 7% | 2% | 2% | 18% |
| 12 | 24% | 47% | 8% | 3% | 2% | 16% |
| 6 + 1 AFK | 24% | 43% | 5% | 12% | 2% | 14% |

- **Half of everyone's time was frozen:** about 19 s standing still per round for about 11 s of running.
- **An AFK runner stalled the game:** the start zone protects them, so every round they were in ran the full 45 s
  while everyone across stood waiting (12% of their time). An AFK runner picked as HERO froze everyone for 20 s.
- **Downed runners on their last chance still said HELP!**, so others ran over to a body nobody can help up.
- **The Practice Bot was either far too hard or far too easy** for a kid alone, depending on how they run.
- **2 players are lopsided:** one runner against one catcher wins about 1 game in 4 (Ask Alex below).
- **The lobby is a third of a small game:** the 30 s vote against games of about a minute (Ask Alex below).

## What changed (after, same bots, same runs)

| # | Change | Before | After |
|---|---|---|---|
| 1 | Shorter pure waits: line-up 3.5 → 3 s, pick 8 → 6 s, show 2.6 → 2 s, round over 3.5 → 2.5 s | 18.6 s frozen per round (8 players) | 15.8 s |
| 2 | One runner on the line skips the roulette (the pick opens at once) | 16.9 s frozen per round (2 players) | 12.8 s |
| 3 | Hurry: everyone still to cross waiting in the start zone for 5 s drops the clock to 6 s | AFK game: 19% of rounds ran the full 45 s, 16.8 s running per round, 184 s games | 0%, 12.4 s, 164 s |
| 4 | A Hero still in the start zone after 6 s loses the solo run, everyone runs | 5% of Hero runs (AFK game) ran out the 20 s | 0% (7 cut short) |
| 5 | Last runner: in a round that started with 2+ runners, the only one left is called out and runs at 30 (a catcher's speed) | no moment, 28 | called out every such round; win rates stay within noise (8 players 44 → 51%, 12 players 37 → 40%) |
| 6 | Runners down with no second chance show OUT (grey), not HELP! | HELP! on a lost cause | OUT |
| 7 | The Practice Bot adapts: 2 slower after it wins, 2 faster after it loses (18 to 28), its reach scales with it, and the message line says so | kid alone: 82% (steers) / 11% (beginner) | 57% / 25% |

Share of each player's time after: frozen 45 to 46% with 2+ players (was 47 to 49%), safe and waiting in the AFK
game 6% (was 12%).

Full after table:

| Players | Game length | Rounds/game | Runners win | Hero runs made | Rescues/game | Frozen per round | Rounds hit the 45 s clock |
|---|---|---|---|---|---|---|---|
| 1 (+ Practice Bot) | 72 s | 2.5 | 57% | 71% | 0 | 12.8 s | 0% |
| 1 beginner (+ bot) | 57 s | 2.0 | 25% | 39% | 0 | 12.8 s | 0% |
| 2 | 56 s | 1.8 | 27% | 41% | 0 | 12.8 s | 0% |
| 4 | 114 s | 3.3 | 51% | 54% | 0.4 | 15.8 s | 0% |
| 8 | 149 s | 4.2 | 51% | 60% | 1.7 | 15.8 s | 0% |
| 12 | 176 s | 5.0 | 40% | 61% | 4.1 | 16.6 s | 0% |
| 6 + 1 AFK | 164 s | 4.5 | 58% | 56% (none ran out) | 0.8 | 16.9 s | 0% |

Tests: RoundRules spec covers `stalling` and `lastRunner`; the sim checks the Hurry happens with an AFK runner, no
round or Hero run runs out its clock there, the last runner is called and boosted (and nobody else is), the bot stays
between its speeds and changes speed, and the stages still go in order (Picking may now go straight to Countdown
when the picked runner leaves).

## Ask Alex (rules the owner set: proposals only, nothing changed)

1. **2 players:** a lone runner against one catcher wins about 1 in 4. Should a game with one runner need only
   2 clean rounds instead of 3?
2. **Map vote:** end the 30 s vote early once everyone has voted? (You asked for 30 s to have time to shop; in a
   1 or 2 player game the lobby is a third of the time.)
3. **No answer to HERO or CHICKEN:** today it's a random pick. Should no answer mean CHICKEN, so an AFK kid never
   gets the solo run? (Change 4 already stops an AFK Hero after 6 s.)
4. **Joining mid-game:** a kid who joins waits in the lobby for the whole game (up to about 3 minutes). Join as a
   catcher at the next line-up?
5. **Winning against the Practice Bot gives the girl.** A good kid alone wins over half their games (about one girl a
   minute and a half). Keep it, or give the solo winner coins only?
6. **Rescue camping:** catchers can wait next to a downed runner and stab whoever comes to help. Make the rescuer
   safe while their bar fills (like the 2 s shield after a rescue)?

## Honest gaps

- These are bot numbers. Real kids steer, lag and give up differently; only Studio play with real players shows
  the true win rates and how the shorter waits feel next to the cutscenes.
- Only Studio can show: the Hurry banner and the clock jumping to 6, the OUT tag's grey on the map, the
  "last runner" banner timing, the pick opening at once for a single runner (camera skips the sweep), and the bot's
  run animation at its new speeds.
- The sim can't see rescue camping, kids who stand in the middle, or late joiners, so those aren't measured.
- The Practice Bot's speed is shared by the server: a new kid joining a server where it sped up meets a faster bot
  for a game or two.
- No new sounds: the new moments use the message line only (owner uploads sounds; no IDs invented).

# Loop audit (Oct 17)

Owner's ask: "make the mechanics the best they can be, and make the core loop be the best".

How the numbers are made: `lune run huzz-valley/tools/sim/round_sim.luau audit [runs]` (repo root) plays the REAL
server code (RoundService, RoundRules, PowerService, PracticeBot) with bot players on a field the size of the owner's
maps (safe lines 280 studs apart, 165 long; `tools/check_maps.luau`). 8 runs of 30 minutes per setup.
The bots: runners sprint across (walk 9 building to 28 over 1.2 s), most huss sideways away from a catcher within
9 studs, 60% go and help up a downed runner within 30 studs; catchers chase where a runner was 0.33 s ago (a kid's
reaction plus lag), half stab, half lunge (and the leap carries them). "AFK" = a player who never moves or answers.

**Read the win rates as a trend, not the truth.** They swing with bot skill: with catchers that react instantly,
runners won 1 to 4% at every size; with the 0.33 s reaction, 40 to 50% at 4+ players. What holds at every skill
level: small games are lopsided, half of everyone's time is spent frozen, and an AFK runner stalls rounds.

## Before

| Players | Games | Game length | Rounds/game | Runners win | Catchers win | Hero runs made | Hero runs timed out | Rescues/game | Running stage/round | Rounds hit the clock |
|---|---|---|---|---|---|---|---|---|---|---|
| 1 (+ bot) | 161 | 58 s | 1.8 | 14% | 86% (all the bot) | 15% | 0% | 0.0 | 4.5 s | 0% |
| 2 | 165 | 55 s | 1.7 | 15% | 85% | 22% | 0% | 0.0 | 4.3 s | 0% |
| 4 | 92 | 123 s | 3.3 | 50% | 50% | 59% | 0% | 0.2 | 9.6 s | 0% |
| 8 | 78 | 145 s | 3.9 | 42% | 58% | 47% | 0% | 1.9 | 10.5 s | 0% |
| 12 | 72 | 158 s | 4.1 | 39% | 61% | 52% | 0% | 4.3 | 11.5 s | 0% |
| 6 + 1 AFK | 66 | 169 s | 3.9 | 42% | 58% | 54% | 2% | 0.7 | 16.4 s | 20% |

No game reached MaxRounds (12) and the sim found no rule problems in any setup.

Seconds per game in each stage (Voting = the lobby between games):

| Players | Voting | Rolling | Lineup | Picking | Chosen | HeroRun | Countdown | Running | RoundOver | GameOver |
|---|---|---|---|---|---|---|---|---|---|---|
| 1 (+ bot) | 31.1 | 7.6 | 6.4 | 12.9 | 4.8 | 5.1 | 2.4 | 8.2 | 2.8 | 8.0 |
| 2 | 31.3 | 7.7 | 6.1 | 12.6 | 4.5 | 5.0 | 2.2 | 7.4 | 2.4 | 8.0 |
| 4 | 31.5 | 7.7 | 11.8 | 22.4 | 8.8 | 16.4 | 9.2 | 32.3 | 8.1 | 8.0 |
| 8 | 32.5 | 8.1 | 14.5 | 27.7 | 10.7 | 17.7 | 11.7 | 43.0 | 10.6 | 8.0 |
| 12 | 33.0 | 8.2 | 15.5 | 28.7 | 11.5 | 19.9 | 12.8 | 50.6 | 11.6 | 8.0 |
| 6 + 1 AFK | 33.6 | 8.4 | 15.1 | 27.1 | 11.1 | 20.9 | 12.1 | 70.8 | 11.1 | 8.0 |

Share of each player's time (play = can run, chase or rescue):

| Players | play | frozen (roller, line-up, pick, countdown, round over, game over) | watching a Hero run | safe, waiting | down, waiting | lobby |
|---|---|---|---|---|---|---|
| 1 (+ bot) | 14% | 50% | 0% | 0% | 1% | 35% |
| 2 | 14% | 50% | 0% | 0% | 0% | 36% |
| 4 | 23% | 49% | 4% | 2% | 1% | 20% |
| 8 | 23% | 50% | 6% | 2% | 2% | 18% |
| 12 | 24% | 48% | 7% | 3% | 2% | 17% |
| 6 + 1 AFK | 23% | 43% | 5% | 12% | 2% | 15% |

What this says:
- **Half of everyone's time is frozen.** Each round spends about 19 s standing still (line-up 3.5, pick up to
  10.8, show 2.6, countdown 3, round over 3.5) for about 11 s of running. Only a quarter of a player's time is play.
- **Small games are lopsided.** A kid alone loses to the Practice Bot 86% of the time ("THE BOT WINS", no girl);
  one runner against one catcher wins 15%. One catch ends a 1 or 2 player game, and nobody is there to rescue.
- **An AFK runner stalls the game.** The start zone protects them, so every round they're in runs the full 45 s
  clock while everyone who crossed stands and waits (12% of their time). An AFK picked runner who lands on HERO
  freezes everyone for the whole 20 s Hero run.
- **Downed runners on their last chance still say HELP!**, so others run over to a body nobody can help up.
- Hero runs succeed about half the time with 4+ players, rescues grow with player count, no stalemates otherwise.

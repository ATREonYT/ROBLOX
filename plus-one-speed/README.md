# ⚡ Plus One Speed: Keyboard Run

Game #2! Our take on **+1 Speed Keyboard Escape** — the current king of the
hyper-casual genre on Roblox (3.8 billion visits, ~500K concurrent players).

The whole game is **one script**: [`PlusOneSpeed.server.lua`](PlusOneSpeed.server.lua).
It builds the entire keyboard world by itself when you press Play.

## What the game is

- **Every step you take = +1 Speed.** That's it. That's the game. Your
  character literally gets faster the more you run, forever.
- Run across a giant obby of **candy keyboard keys** floating over a desk.
  Gaps get wider stage by stage — jump them at first, and once you're fast
  enough, **run straight over them** without jumping (the genre's famous
  power-trip moment).
- A **yellow WINS pad** at the end of each of the 8 stages pays out Wins
  (later stages pay way more). Fall off? You teleport back to your latest
  safe zone — your speed is never lost.
- **Trail shop**: spend Wins on 5 glowing trails that are both cosmetic AND
  permanent multipliers on your speed gain (up to +400% for the Rainbow).
- **Rebirth statue**: reset your speed for a permanent multiplier — x1.5 at
  Level 15, then +0.5x every tier (the real game's exact curve). Trails and
  Wins survive rebirths, so every run back is faster.
- **AFK treadmill** at spawn: stand on it and gain speed while doing nothing.
- **Angry brainrots** (cameo from game #1!) patrol stages 4, 6 and 8, sweeping
  across the keys — get bonked and you're probably going off the edge.
- **The Golden Brainrot** waits at the very end: +250 Wins every 3 minutes
  for anyone who can make the full run.
- Everyone's speed floats above their head, so the flexing is automatic.

## Setup (5 minutes, no experience needed)

1. **Install Roblox Studio** from [create.roblox.com](https://create.roblox.com)
   (click "Get Studio"). Log in with your normal Roblox account.
2. Open Studio → create a new place with the **Baseplate** template.
3. Find the **Explorer** panel (usually on the right; it's in the View
   menu/tab if hidden).
4. In the Explorer, hover over **ServerScriptService** → click the **+** →
   choose **Script**.
5. Delete the one line of default code in the window that opens.
6. Open [`PlusOneSpeed.server.lua`](PlusOneSpeed.server.lua) on GitHub, click
   the **copy button** (two squares, top-right of the file), and **paste
   everything** into the empty script.
7. Press **Play** (F5). Now RUN.

## Publishing & saving

Same as game #1: **File → Publish to Roblox**, make it Public in your game's
Access Settings on create.roblox.com, and enable
**Studio Access to API Services** (Settings → Security) so speed, Wins,
rebirths and trails save between visits. This game works fine with any
server size — more runners, more fun.

## Making it yours (easy tweaks!)

Everything is at the top of the script in the CONFIG section:

- `SPEED_PER_STEP = 1` → make every step worth more
- `STAGE_COUNT = 8` → build a longer keyboard (it generates automatically!)
- `TREADMILL_GAIN = 2` → juicier AFK gains
- `GOLDEN_BONUS = 250` → a bigger jackpot at the end
- Add trails to the `TRAILS` list, or new phrases to `KEY_PHRASES` (the
  letters printed on the keys — make them spell anything you want)
- Change the rebirth curve in `REBIRTH_LEVELS`

## Ideas for version 2

- More worlds (a second keyboard theme past the Golden Brainrot)
- Pets/eggs bought with Wins
- Zombie-chase stages (the top clone adds chasing hordes)
- Keycap click sounds (the real game's ASMR hook)
- Leaderboard statues for the fastest players ever

---

*Built together with Claude. Game #2 of many.*

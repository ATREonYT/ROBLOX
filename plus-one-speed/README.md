# ⌨️ Plus One Speed: Candy Keyboard

Game #2, rebuilt properly this time. Our faithful from-scratch take on the
**+1 Speed Keyboard Escape** formula (the current genre king — billions of
visits) — a candy & chocolate world made of giant mechanical keyboard keys
that **click and press down under your feet**, where **every step makes you
permanently faster**.

This game is **two scripts** (the second one is the on-screen GUI):
- [`PlusOneSpeed.server.lua`](PlusOneSpeed.server.lua) — the whole game world
- [`PlusOneSpeed.client.lua`](PlusOneSpeed.client.lua) — the interface

## What the game is

- **Every step = +Speed**, multiplied by your digit plates × rebirths ×
  trails (× the x2 boost). Your speed floats over your head for everyone
  to envy.
- **The keys actually work**: every keycap has a pink under-skirt, a candy
  top, a printed letter — and it **presses down with a click** when you step
  on it. Faster running = faster click-clack. That's the ASMR magic of the
  real game.
- **The lobby is a keyboard**: you spawn on giant clicking keys, with the
  **treadmill row** on one side (AFK speed — upgrade to Golden/Diamond),
  the **8 numbered digit plates** on the other (permanently raise your
  speed-per-step, buy them in order), a **server leaderboard** on the back
  wall, and the Stage 1 archway ahead.
- **8 candy stages** in a line, each with its own gimmick:
  gaps → zigzag → a **rolling jawbreaker** → the **choco tsunami** wave →
  bouncy marshmallows → **timed truffle gates** → a pure speed-check sprint →
  the gummy-guarded finale.
- Each stage ends on a giant **yellow WIN keycap**: smash it, bank the Wins,
  and get whooshed back to spawn — then pay a few Wins in the **Teleport
  menu** to jump straight back to your furthest stage. Falling = back to
  spawn too (the real game's loop!).
- **GUI like the big games**: big speed counter up top, Wins counter,
  and a left-side button column — **Shop** (x2 boost), **Trails** (7 tiers,
  Green ×1.5 up to Void ×25 — each one multiplies ALL your speed gain),
  **Rebirth** (the genre's real curve: Level 15 → ×1.5, then ×2, ×2.5...
  with a progress bar), **Teleport**, and a **FREE!** welcome gift.
  Plus "+X" popups raining as you run.
- **The Golden Brainrot** waits past stage 8 (+25K Wins every 3 min), and a
  locked **World 2 gate** is standing there waiting for us to mod it in.

## Setup (5 minutes — note there are TWO scripts now)

1. **Install Roblox Studio** from [create.roblox.com](https://create.roblox.com),
   log in with your Roblox account.
2. Open Studio → new place with the **Baseplate** template.
3. In the **Explorer** (View menu if hidden):
   - Hover **ServerScriptService** → **+** → **Script** → delete the default
     line → paste ALL of [`PlusOneSpeed.server.lua`](PlusOneSpeed.server.lua).
   - Expand **StarterPlayer** → hover **StarterPlayerScripts** → **+** →
     **LocalScript** → delete the default line → paste ALL of
     [`PlusOneSpeed.client.lua`](PlusOneSpeed.client.lua).
4. Press **Play** (F5). Walk forward. Hear the clicks. Watch the number.

⚠️ Common mistake: the second script must be a **LocalScript** (not a
Script), and it goes in **StarterPlayerScripts** — if the GUI doesn't
appear, that's the first thing to check.

## Publishing & saving

**File → Publish to Roblox**, then make it Public in your game's Access
Settings on create.roblox.com. Saving works automatically for real players
once published; to also have saving in Studio tests, enable **Studio Access
to API Services** (File → Game Settings → Security). Public servers in the
real game run 22 players — set whatever you like.

## Making it yours (this is the fun part)

Everything is in the CONFIG section at the top of the server script:

- `STAGES` — add a stage! Copy a line, pick a name, colors, a `phrase`
  (the letters printed on its keys) and a `gimmick`: `none`, `zigzag`,
  `ball`, `wave`, `bouncy`, `gates`, or `chasers`. The map builds itself.
- `PLATES`, `TRAILS`, `REBIRTHS` — retune the whole economy
- `GOLDEN_BONUS`, `BOOST_COST`, `FREE_REWARD` — the juicy numbers
- World 2 is just... more `STAGES` entries plus moving the gate. When you're
  ready, we build it together.

## Ideas for next time

- World 2 (the research says: harsher stages — closing gates, wind, a
  chasing teddy-bear boss, then a space-candy World 3)
- Win streaks (consecutive clears multiply payouts)
- Auras on top of trails, pets, more treadmill tiers
- Music + richer click sound variety per stage

---

*Built together with Claude. Game #2 of many — this time studied properly.*

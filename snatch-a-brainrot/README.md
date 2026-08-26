# 🧠 Snatch a Brainrot

Our first game! A bright, cartoony remake of **Steal a Brainrot** — the Roblox
game that holds the all-time record for concurrent players in ANY video game
ever (25.8 million people playing at once in July 2026).

The whole game is **one script**: [`BrainrotGame.server.lua`](BrainrotGame.server.lua).
It builds the entire map, all 24 characters, the lighting, the UI — everything —
by itself when you press Play.

## What the game is

- Meme characters ("brainrots") march out of a cave and waddle down a **red
  carpet** in the middle of a bright candy-colored island.
- **Tap E** next to one to buy it before it walks away — it then **runs to
  your base by itself** and hops onto a free pad.
- It **earns cash every second**, but the money piles up at its pad — you
  have to **stand in your base to collect it** (watch the green +$ popups!).
- Climb the rarity ladder: Common → Rare → Epic → Legendary → Mythic →
  **Brainrot God** → **Secret**. The scary ones get announced to everyone,
  and if nothing big has spawned for 5 minutes, the carpet guarantees one.
- **Mutations**: some spawn Gold (1.25x money), Diamond (1.5x), or Rainbow
  (**10x**, color-cycling, everyone will fight over it).
- **Steal** from other players: hold E on a brainrot in their base, carry it
  over your head (you're slowed!), and run home to keep it.
- **Defend**: hit the red BASE LOCK button for a 45s shield, and slap thieves
  with your **Slap Bat** — they instantly drop what they stole. New players
  get a free 60s shield so they can't be robbed while learning.
- **FUSION ALTAR** (our own twist — the real game doesn't have this!):
  collect **3 identical brainrots** and fuse them at the purple altar into a
  random one from the **next rarity tier up**. Suddenly commons matter.
- **BRAINROT RUSH**: every ~8 minutes the whole server gets 60 seconds of
  **2x income and tripled mutation luck**. The screen goes golden. Chaos.

## Setup (5 minutes, no experience needed)

1. **Install Roblox Studio** from [create.roblox.com](https://create.roblox.com)
   (click "Get Studio"). Log in with your normal Roblox account.
2. Open Studio → create a new place with the **Baseplate** template.
3. Find the **Explorer** panel (usually on the right). If you don't see it,
   look for it in the **View** menu/tab — Roblox moves buttons around between
   Studio versions, but Explorer is always in there.
4. In the Explorer, hover over **ServerScriptService** → click the **+** that
   appears → choose **Script**.
5. A code window opens with one line already in it. **Delete that line.**
6. Open [`BrainrotGame.server.lua`](BrainrotGame.server.lua) on GitHub, click
   the **copy button** (two squares, top-right of the file), and **paste
   everything** into the empty script in Studio.
7. Press **Play** (F5). You're in the game!

## Testing the stealing with fake players

Stealing needs more than one player, and Studio can simulate that:

1. Find the **Test** section (a tab in classic Studio, or the dropdown next
   to the Play button in newer Studio versions).
2. Change **1 Player** to **2 Players** (or more) and click **Start**.
3. Studio opens one game window per player — buy a brainrot in one window,
   then switch to the other window and steal it! Slap the thief with the bat.
4. Click **Cleanup** / stop the servers when you're done.

## Publishing it for real (so friends can join)

1. **File → Publish to Roblox** → give it a name → **Create**.
2. Make it public: [create.roblox.com](https://create.roblox.com) →
   **Creations** → your game → **Access Settings** → set **Playability**
   to **Public**.
3. Turn on **saving** (cash + brainrots survive rejoining): on your game's
   page in create.roblox.com open **Configure/Settings → Security** and
   enable **Studio Access to API Services**. Without it the game still works,
   it just doesn't save between visits.
4. **Important:** the map has **8 bases**, so set your server size to 8:
   your game on create.roblox.com → **Places** → your place → set
   **Maximum Players** to **8**. (Extra players beyond 8 aren't broken —
   they queue and automatically get the next base that frees up — but 8 is
   the intended experience.)

## Making it yours (easy tweaks — try these!)

Everything tweakable is at the **top** of the script in the CONFIG section:

- `STARTING_CASH = 100` → more starting money
- `SPAWN_INTERVAL = 4` → lower = brainrots appear faster
- `RUSH_EVERY = 480` → how often the Rush event hits
- `LOCK_DURATION = 45` → longer base shield
- Add your own character to the `CHARACTERS` list! Copy a line, change the
  name, price, income, colors and `look` (any of: blob, cheese, piggy,
  shrimp, tire, banana, cup, trunk, fridge, plane, train, shark, cow, log,
  trio, combo). Inventing brainrots is literally how the real game got famous.
- Change rarity odds in `RARITIES` (`chance` is a weight — bigger = more common).

If the game ever breaks after an edit, open the **Output** panel (in the View
menu) — the red error line tells you exactly which line is unhappy.

## Ideas for version 3

- **Rebirth**: trade everything for a permanent income multiplier
- Shop: Speed Coil, bigger bats, traps
- Real meshes from the Toolbox for the characters
- Sounds & music (the real game's chaos is 50% audio)
- Trading between players

---

*Built together with Claude. Game #1 of many.*

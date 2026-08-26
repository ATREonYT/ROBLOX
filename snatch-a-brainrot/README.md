# 🧠 Snatch a Brainrot

Our first game! A simplified remake of **Steal a Brainrot** — the Roblox game
that holds the all-time record for concurrent players in ANY video game ever
(25.8 million people playing at once in July 2026).

The whole game is **one script**: [`BrainrotGame.server.lua`](BrainrotGame.server.lua).
It builds the entire map, characters, and game systems by itself when you press Play.

## What the game is

- Meme characters ("brainrots") walk down a conveyor belt in the middle of the map.
- Stand next to one and **hold E to buy it** before it walks away.
- It goes to your base and **earns cash every second** — but the cash piles up
  at your base, and you have to **stand in your base to collect it**.
- Save up for rarer brainrots: Common → Rare → Epic → Legendary → Mythic →
  **Brainrot God** → **Secret**. Rare ones get announced to the whole server.
- Some spawn with **mutations**: Gold (1.25x money), Diamond (1.5x), or
  Rainbow (**10x!**).
- **Steal** from other players: hold E on a brainrot in their base, carry it
  over your head (you walk slower!), and run home to keep it.
- **Defend yourself**: press the red BASE LOCK button to shield your base for
  45 seconds, and slap thieves with your **Slap Bat** — they instantly drop
  what they stole.

## Setup (5 minutes, no experience needed)

1. **Install Roblox Studio** from [create.roblox.com](https://create.roblox.com)
   (click "Get Studio"). Log in with your normal Roblox account.
2. Open Studio → click **Baseplate** (the plain template) to create a new place.
3. Find the **Explorer** panel on the right. If you don't see it, click the
   **View** tab at the top and turn on **Explorer**.
4. In the Explorer, hover over **ServerScriptService** → click the **+** that
   appears → choose **Script**.
5. A code window opens with one line already in it (`print("Hello world!")`).
   **Delete that line.**
6. Open [`BrainrotGame.server.lua`](BrainrotGame.server.lua) on GitHub, click
   the **copy button** (two squares, top-right of the file), and **paste
   everything** into the empty script in Studio.
7. Press the big blue **Play** button (or F5). You're in the game!

## Testing the stealing with fake players

Stealing needs more than one player. Studio can simulate this:

1. Click the **Test** tab at the top of Studio.
2. Where it says **1 Player**, change it to **2 Players** (or more), then click
   **Start**.
3. Studio opens one window per player — buy a brainrot in one window, then
   switch to the other window and steal it!
4. Click **Cleanup** in the Test tab when you're done.

## Publishing it for real (so friends can join)

1. **File → Publish to Roblox** → give it a name → **Create**.
2. To make it public: go to [create.roblox.com](https://create.roblox.com) →
   **Creations** → click your game → **Access Settings** →
   set **Playability** to **Public**.
3. To make **saving** work (cash + brainrots survive rejoining): on your
   game's page in create.roblox.com, open **Configure → Security** (or in
   Studio: **Game Settings → Security**) and turn ON
   **Enable Studio Access to API Services**. Without this the game still
   works fine — it just doesn't save between visits.

## Making it yours (easy tweaks — try these!)

Everything tweakable is at the **top** of the script in the CONFIG section:

- `STARTING_CASH = 100` → give players more starting money
- `SPAWN_INTERVAL = 4` → lower = brainrots appear faster
- `LOCK_DURATION = 45` → longer base shield
- Add your own character to the `CHARACTERS` list! Copy any line, change the
  name, price, income, color, and size. Invent your own brainrot — that's
  literally how the real game got famous.
- Change rarity odds in `RARITIES` (`chance` is a weight — bigger = more common).

If the game ever breaks after an edit, check the **Output** panel
(View tab → Output) — the red error line tells you which line is unhappy.

## Ideas for version 2 (when you're ready)

- **Rebirth**: trade all your cash + brainrots for a permanent income multiplier
- **Floors**: second floor of slots on your base
- Shop items: Speed Coil, bigger bat, traps
- Real character models (Roblox Toolbox has free brainrot models — search
  the name and drag one in)
- Sounds & music (the real game's chaos is 50% audio)

---

*Built together with Claude. Game #1 of many.*

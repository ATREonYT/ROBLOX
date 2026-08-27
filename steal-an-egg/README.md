# Steal an Egg (rebuild)

Your Steal an Egg rebuild — now a complete game, with the map modeled on
the real one: a long walled canyon of zones. You spawn in the **SAFE
ZONE** with the bases, and the deeper you walk, the rarer the wild eggs:

```
SAFE ZONE  ->  Meadow  ->  Desert  ->  Grove  ->  Snowfields  ->  THE EGG MACHINE
(bases+shop)   Common      Rare        Epic       Legendary       Mythic & Secret
```

## What's in the game

- **EggGame.server.lua** — the whole game in one server script:
  - The canyon map: checkered zone floors, sloped dirt walls with grass
    tops, the red safe-zone line, the desert pyramid + cacti, the Grove's
    pond, snowfields with ice crystals, sleeping birds, and the glowing
    **Egg Machine** sealing the far end.
  - **Wild eggs** appear scattered around the zones — tap E to buy one and
    it tumbles home to a nest at your base. 15 egg types + a secret one.
  - **Hatching**: every egg hatches into a bird worth **3x** its income.
    Stolen eggs KEEP their hatch progress, so a nearly-hatched egg is the
    juiciest target in the game.
  - **Stealing**: hold E on someone's nest egg, then run home. Bonk
    thieves with your **frying pan**; **lock** your base to shield it.
  - Mutations (Shiny / Glowing / Rainbow), a pity timer, the **Golden
    Goose** and **Egg Rain** events, cash piles you collect by standing in
    your base, and **saving** (cash, eggs, hatch progress, trails).
- **TrailShop.client.lua** — the card-style Trail Shop GUI. Now wired to
  the server: real cash, purchases the server validates, trails everyone
  can see, and a real speed boost (your getaway upgrade!). Opens at the
  shop stand in the SAFE ZONE (any part named `TrailShopZone`).

## Setup

1. Best in a fresh **Baseplate** place — the script builds the whole map
   at Play (everything lands in one `EggMap` folder; delete it and the
   built map is gone).
2. Sync with Rojo (`rojo.exe serve` in this folder, connect the plugin),
   **or** paste `EggGame.server.lua` into a Script in ServerScriptService
   and `TrailShop.client.lua` into a LocalScript in StarterPlayerScripts.
3. ⚠️ If you hand-pasted the old TrailShop before, delete that copy first
   — two copies will fight each other.
4. **To make saving work**: publish the place, then in Studio go to
   Game Settings → Security → turn ON "Enable Studio Access to API
   Services". Without it the game still runs fine, it just won't save.

## Tuning

Every number worth playing with is at the top of `EggGame.server.lua`
(`CONFIG`) — egg prices and incomes, hatch times, lock timers, event
frequency. Change a line, sync, press Play.

## Ideas for next time

Rebirths, a global leaderboard, pets that follow you, more zones past the
Egg Machine — ask Claude and it's a two-minute job.

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

## Putting it into your EXISTING place ("Steal an egg rebuild")

The game builds its whole map at Play, so it drops straight into the
place you already have. One-time cleanup first (make a backup copy of
the place first: File → Save to File As):

1. Delete the old hand-pasted **TrailShop** LocalScript from
   StarterPlayerScripts — otherwise two shops fight each other.
2. Delete your old **TrailShopZone** part — the new map builds its own
   shop stand in the SAFE ZONE. (If you keep yours, the script skips
   building the stand and the shop opens at your part instead.)
3. Your old map parts sit right where the canyon will build. Delete
   them, or drag them into **ServerStorage** to keep them without them
   showing up in the world. Deleting the **Baseplate** looks best — the
   canyon floats over the sky void, just like the real game.
4. Then add the two scripts (next section) and press Play.

## Setup

1. Sync with Rojo (`rojo.exe serve` in this folder, connect the plugin),
   **or** paste `EggGame.server.lua` into a Script named `EggGame` in
   ServerScriptService and `TrailShop.client.lua` into a LocalScript
   named `TrailShop` in StarterPlayerScripts.
2. Press Play — the whole map builds itself (everything lands in one
   `EggMap` folder in the workspace; delete it and the built map is
   gone).
3. **To make saving work**: publish the place, then in Studio go to
   Game Settings → Security → turn ON "Enable Studio Access to API
   Services". Without it the game still runs fine, it just won't save.

## Tuning

Every number worth playing with is at the top of `EggGame.server.lua`
(`CONFIG`) — egg prices and incomes, hatch times, lock timers, event
frequency. Change a line, sync, press Play.

## Ideas for next time

Rebirths, a global leaderboard, pets that follow you, more zones past the
Egg Machine — ask Claude and it's a two-minute job.

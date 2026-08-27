# Steal an Egg (rebuild)

Your Steal an Egg rebuild's scripts, synced by Rojo.

Currently contains:

- **TrailShop.client.lua** — the card-style Trail Shop GUI (buy / equip /
  unequip with a real trail on your character) that opens automatically
  when you step into a part named `TrailShopZone` (Anchored ✓,
  CanCollide ☐, Transparency 1).

To sync: put `rojo.exe` in this folder, run `rojo.exe serve` here, then
connect the Rojo plugin in the Studio place for THIS game.

⚠️ First connect only: delete the hand-pasted TrailShop LocalScript from
StarterPlayerScripts before connecting, or you'll have two copies of the
shop fighting each other.

As more scripts get added to this game, they get files here and an entry
in `default.project.json` — ask Claude and it's a two-minute job.

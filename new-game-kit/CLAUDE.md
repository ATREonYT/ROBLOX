# A game made from the New Game Kit

Read the repo's root `CLAUDE.md` first (owner rules, kid-safe money rules, never invent ids). Then this.

## Before every commit
- `PATH=/root/bin:$PATH sh tools/check.sh`: specs, the play-through, then rebuilds `src/StarterGui/KitHUD.rbxm` and `places/<Game>.rbxl`.
  Lune 0.10.5 install line: `README.md`. Give the owner the place file's "Download raw file" link and what to try.
- A green offline run doesn't prove Studio works. Say what only Studio can show.

## How the code is shaped
- One server Script: `src/Main.server.luau`. Order: `PlayerData.Configure` -> `Policy.Init` -> each `Init(config)` ->
  hooks -> `Receipts.Start` -> `PlayerData.Start`. A new system goes in `src/Server/<Name>.luau` with the same shape
  (`Init`, `RegisterSlice`, `Net.Handle` with a rate limit and one validator per argument) and a spec in `tests/`.
- Only `PlayerData` writes player data; only `Receipts` sets `ProcessReceipt`. Never add a second of either.
- Gameplay income goes through `Currency.Earn` (multipliers apply). Rewards use the `Rewards` format and
  `Rewards.CanGrant` before marking anything claimed.
- Everything a player sees about money comes from the server or from `GetProductInfoAsync`: never hard-code Robux prices.
- Odds: anything random that Robux touches shows its odds first (`Eggs.GetOdds`), and is hidden or refused where
  `PaidRandomAllowed` is not true.
- UI: change `src/Shared/HudBuilder.luau` (the parts), then rebuild; `src/Client/KitClient.client.luau` finds parts by name.
  A TextButton's child must not be named `Text` (the property hides it): labels are called `Label`.
- Pictures of the HUD: `lune run tools/preview/export.luau out.json Shop` then
  `NODE_PATH=$(npm root -g) node tools/preview/shoot.js out.json out.png 1280 720`.

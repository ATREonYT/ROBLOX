# Robux items: what to create on the Roblox website

Every Robux item in the game is already built and tested. Until you create it on the website and paste its id
into `hood/src/ReplicatedStorage/Shared/Config/Products.lua`, its button says "Coming soon!" and nothing breaks.

**Where:** [create.roblox.com](https://create.roblox.com) → your experience → **Monetization**.

## Game passes (Monetization → Passes)

Create a pass, set its price, copy its id, and paste it at `Products.Passes.<Key>`.

| Name | Price (Robux) | Key in Products.lua | What it does |
|---|---|---|---|
| 2x Power | 199 | `DoubleRep` | Every shot gives double Power |
| 2x Cash | 149 | `DoubleCash` | Double Cash from the pads and goals |
| VIP | 249 | `VIP` | Gold VIP tag + 1.5x Cash |
| Auto Fight | 99 | `AutoShoot` | Your gun fires at stage goons on its own |
| Lucky | 129 | `Lucky` | Epic-and-better shoes are twice as likely in Cash boxes |
| Triple Open | 179 | `TripleOpen` | Open 3 Cash shoe boxes at once (for 3x the Cash) |
| +1 Shoe Slot | 99 | `ExtraEquip` | Wear 4 pairs of shoes instead of 3 |
| 10x Cash | 199 | `TenXCash` | The pink pad before every gate pays 10x the yellow one (+100 instead of +10 at Stage 1) |
| Pro Bay | 99 | `RangeVIP1` | Opens PRO BAY, the x100 Power shooting lane, forever |
| Gold Bay | 249 | `RangeVIP2` | Opens GOLD BAY, the x250 Power shooting lane (the best one), forever |
| Auto Open | 249 | `AutoOpen` | The box's T button opens box after box by itself (one at a time, stops when you press it or run out of Cash) |
| 2x Speed | 99 | `Speed2x` | Walk speed exactly x2 |
| Auto Collect | 149 | `AutoCollect` | A street's pad Cash is paid the moment its crew is down (the 10x pad's amount with the 10x pass); the pad then only takes you back to the lobby. There are no loose drops in the game, so pads are what it collects |

## Developer products (Monetization → Developer Products)

Create a product, set its price, copy its id, and paste it at `Products.DeveloperProducts.<Key>`.

| Name | Price (Robux) | Key in Products.lua | What it gives |
|---|---|---|---|
| Exclusive Box | 99 | `ShoeBoxExclusive` | 1 Exclusive Box opening |
| 3 Exclusive Boxes | 249 | `ShoeBoxExclusive3` | 3 openings (297 if bought one by one) |
| 8 Exclusive Boxes | 599 | `ShoeBoxExclusive8` | 8 openings (792 if bought one by one) |
| Grail Box | 199 | `ShoeBoxGrail` | 1 Grail Box opening |
| 3 Grail Boxes | 499 | `ShoeBoxGrail3` | 3 openings (597 if bought one by one) |
| 8 Grail Boxes | 1199 | `ShoeBoxGrail8` | 8 openings (1592 if bought one by one) |
| Boost Bundle | 119 | `BoostBundle` | Two 2x Power boosts + one 3x Power boost (147 separately) |
| 2x Power Boost | 39 | `RepBoost2x` | 15 minutes of 2x Power |
| 3x Power Boost | 69 | `RepBoost3x` | 15 minutes of 3x Power |
| Block Party | 149 | `BlockParty` | 2x Power for everyone in the server, 15 minutes |
| Tiny Cash Pack | 19 | `TinyCash` | +500 Cash at Stage 1, more at later stages (x pad Cash ^ 0.6, Products.cashAmount) |
| Small Cash Pack | 49 | `SmallCash` | +1,400 Cash at Stage 1, scaled the same way |
| Medium Cash Pack | 129 | `MediumCash` | +4,000 Cash at Stage 1, scaled the same way |
| Large Cash Pack | 399 | `LargeCash` | +13,500 Cash at Stage 1, scaled the same way |
| Tiny Power Pack | 19 | `PowerPack1` | The larger of 0.1x your next rebirth's Power and 0.15x the Power you hold now |
| Small Power Pack | 49 | `PowerPack2` | The larger of 0.3x your next rebirth's Power and 0.45x what you hold |
| Medium Power Pack | 129 | `PowerPack3` | The larger of 0.9x your next rebirth's Power and 1.35x what you hold |
| Large Power Pack | 399 | `PowerPack4` | The larger of 3x your next rebirth's Power and 4.5x what you hold |
| Skip Rebirth | 99 | `SkipRebirth` | Rebirth now without the Power |
| 2x Offline | 49 | `OfflineX2` | Doubles the Power you earned while away (the Welcome back card; if you already claimed it, the same amount again) |
| Restore Streak | 25 | `RestoreStreak` | Keeps the Daily Rewards streak after a missed day (offered only after a miss, in the Daily Rewards window). If there is nothing to restore any more, the buyer gets the next day's reward instead |

## If you change a price on the website

1. Change that item's `Price` in `Products.lua` too. The card shows it until the live price loads.
2. If the item is part of a bundle, also update the bundle's `WasPrice`. The struck-through number must stay the
   real one-by-one price.
3. For the two single Robux boxes, also update `RobuxPrice` in `Config/Shoes.lua`. That price is shown on the
   box's label in the lobby.
4. For Pro Bay and Gold Bay, also update `RobuxPrice` on the lane's row in `Config/Skins.lua` (`S.Stations`, the
   `Pro` and `Gold` rows). That price is shown over the lane in the lobby.

## How the new passes work in game

- **10x Cash:** before every gate stand two pads. The yellow Return pad pays the stage's Cash (+10 at Stage 1, more
  each stage) and takes you back to the lobby. The pink pad pays 10 times that and does the same, but only with this
  pass. Without the pass, stepping on the pink pad opens the purchase window. The 2x Cash and VIP passes add to both
  pads as usual.
- **Pro Bay / Gold Bay:** the two best shooting lanes in the lobby. Every other lane opens with rebirths (up to x50
  at 10 rebirths, and the Champ Ring in the Boss Yard at x75 at 12). These two open only with their pass, at any
  rebirth. Stepping into one without the pass opens its purchase window.

## Upload the icons first

Studio shows simple 3D stand-ins for the UI icons until the pictures are uploaded. To upload them, run:

```
python3 hood/tools/upload_assets.py
```

`hood/art/README_upload.md` explains how. Do it before judging how the UI looks.

## Other things to set (not Robux items)

- **Group reward:** put your Roblox group's id in `hood/src/ServerScriptService/HoodServer/ServerConfig.lua` (`GroupId`, 0 = off).
  Members get a one-time Cash + 2x Power reward from the Daily Rewards window (`Player:IsInGroup`).
- **"Robux: ?" teaser:** the HUD's side pass buttons (2x Cash, 2x Power, Auto Fight) show "?" for their price until a tap has
  opened Roblox's own purchase prompt, which always shows the real price; after it (bought or declined) our button shows the price.
  The Store and the in-world boards always show prices.

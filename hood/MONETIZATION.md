# Robux items: what to create on the Roblox website

Every Robux item in the game is already built and tested. Until you create it on the website and paste its id
into `hood/src/ReplicatedStorage/Shared/Config/Products.lua`, its button says "Coming soon!" and nothing breaks.

**Where:** [create.roblox.com](https://create.roblox.com) → your experience → **Monetization**.

## Game passes (Monetization → Passes)

Create a pass, set its price, copy its id, and paste it at `Products.Passes.<Key>`.

| Name | Price (Robux) | Key in Products.lua | What it does |
|---|---|---|---|
| 2x Power | 199 | `DoubleRep` | Every shot gives double Power |
| 2x Cash | 149 | `DoubleCash` | Double Cash from gates, waves and goals |
| VIP | 249 | `VIP` | Gold VIP tag + 1.5x Cash |
| Auto Fight | 99 | `AutoShoot` | Your gun fires at stage goons on its own |
| Lucky | 129 | `Lucky` | Epic-and-better shoes are twice as likely in Cash boxes |
| Triple Open | 179 | `TripleOpen` | Open 3 Cash shoe boxes at once (for 3x the Cash) |
| +1 Shoe Slot | 99 | `ExtraEquip` | Wear 4 pairs of shoes instead of 3 |

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
| Tiny Cash Pack | 19 | `TinyCash` | +500 Cash |
| Small Cash Pack | 49 | `SmallCash` | +1,400 Cash |
| Medium Cash Pack | 129 | `MediumCash` | +4,000 Cash |
| Large Cash Pack | 399 | `LargeCash` | +13,500 Cash |
| Tiny Power Pack | 19 | `PowerPack1` | 0.1x your next rebirth's Power |
| Small Power Pack | 49 | `PowerPack2` | 0.3x your next rebirth's Power |
| Medium Power Pack | 129 | `PowerPack3` | 0.9x your next rebirth's Power |
| Large Power Pack | 399 | `PowerPack4` | 3x your next rebirth's Power |
| Skip Rebirth | 99 | `SkipRebirth` | Rebirth now without the Power |

## If you change a price on the website

1. Change that item's `Price` in `Products.lua` too. The card shows it until the live price loads.
2. If the item is part of a bundle, also update the bundle's `WasPrice`. The struck-through number must stay the
   real one-by-one price.
3. For the two single Robux boxes, also update `RobuxPrice` in `Config/Shoes.lua`. That price is shown on the
   box's label in the lobby.

## Upload the icons first

Studio shows simple 3D stand-ins for the UI icons until the pictures are uploaded. To upload them, run:

```
python3 hood/tools/upload_assets.py
```

`hood/art/README_upload.md` explains how. Do it before judging how the UI looks.

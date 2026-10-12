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
| Gold Bay | 249 | `RangeVIP2` | Opens GOLD BAY, the x250 Power shooting lane, forever |
| Head Lane | 699 | `RangeVIP3` | Opens the HEAD LANE, the x500 Power shooting lane on the gold stage at the end of the training aisle (the best one), forever |
| Auto Open | 249 | `AutoOpen` | The box's T button opens box after box by itself (one at a time, stops when you press it or run out of Cash) |
| 2x Speed | 99 | `Speed2x` | Walk speed exactly x2 |
| Auto Collect | 149 | `AutoCollect` | A street's pad Cash is paid the moment its crew is down (the 10x pad's amount with the 10x pass); the pad then only takes you back to the lobby. There are no loose drops in the game, so pads are what it collects |

## Developer products (Monetization → Developer Products)

Create a product, set its price, copy its id, and paste it at `Products.DeveloperProducts.<Key>`.

| Name | Price (Robux) | Key in Products.lua | What it gives |
|---|---|---|---|
| Chrome Box | 99 | `ShoeBoxExclusive` | 1 Chrome Box opening (brief 30: the Exclusive Box's new name; the key stays) |
| 3 Chrome Boxes | 249 | `ShoeBoxExclusive3` | 3 openings (297 if bought one by one) |
| 8 Chrome Boxes | 599 | `ShoeBoxExclusive8` | 8 openings (792 if bought one by one) |
| Crown Box | 199 | `ShoeBoxGrail` | 1 Crown Box opening (brief 30: the Grail Box's new name; the key stays) |
| 3 Crown Boxes | 499 | `ShoeBoxGrail3` | 3 openings (597 if bought one by one) |
| 8 Crown Boxes | 1199 | `ShoeBoxGrail8` | 8 openings (1592 if bought one by one) |
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
| Big Cash Pack | 249 | `BigCash` | 8,000 Cash (x your best stage), the 5th Cash Pack; giftable (brief 30, round 2) |
| Mega Cash Pack | 999 | `MegaCash` | 34,500 Cash (x your best stage): the tall MEGA card with the BEST VALUE ribbon, the most Cash per Robux; giftable |
| Big Power Pack | 249 | `PowerPackBig` | 1.8x your next rebirth's Power (or 2.7x the Power you hold, whichever is more) |
| Mega Power Pack | 999 | `PowerPackMega` | 7.8x your next rebirth's Power (or 11.7x the Power you hold, whichever is more) |
| Street Pack | 399 | `FeaturedPack1` | The weekly Featured pack, one of three (brief 30): 6,000 Cash (x your best stage, like the Cash Packs) + a 3x Power boost for 15 min + 1 Chrome Box, in one purchase |
| Grail Pack | 449 | `FeaturedPack2` | The second weekly pack: 4,000 Cash (scaled) + a 3x Power boost for 15 min + 1 Crown Box |
| Sneaker Pack | 399 | `FeaturedPack3` | The third weekly pack: 12,000 Cash (scaled) + a 2x Power boost for 15 min + 1 Chrome Box |
| Starter Pack | 149 | `StarterPack` | Once per player (brief 30, HUD): 5,000 Cash (x your best stage, like the Cash Packs) + 30 min of 2x Power (two 15 min boosts) + 1 opening of this world's cheapest Robux box. After it is bought, its HUD button and window are gone for good |
| 3 Spins | 39 | `SpinPack` | 3 spins of the Spin Wheel (brief 30, HUD). They never run out; the free spin still comes every 4 hours |
| Revive | 15 | `Revive` | (brief 30) On the REVIVE? screen after a knockout in a stage fight: stand up where you fell with full HP. The free red "No" (or the 10 s running out) puts you back at the stage start as before. The countdown waits while the purchase prompt is open (at most 60 s); if the screen had already closed when Roblox finishes the purchase, you still get full HP and a short shield |
| Revenge | 39 | `Revenge` | (brief 30) On the same screen: stand up with full HP AND knock out the crew you were fighting (its gate opens as if you'd beaten it) |
| World Boss Skip | 25 | `WorldBossSkip` | (brief 30) The blue SKIP on the "Next <name> boss fight in m:ss" timer: the next World Boss lands now, for everyone in the server (the regular timer goes on after it) |
| The Grail Bundle | 1499 | `GrailBundle` | One pair each of The Grail, Astro Crown and Platinum Wings, added in one purchase (brief 30). The price is `Products.GrailBundlePrice` (the user's R$1,499); the Store's Featured section shows it with the bundle's own chest. No countdown, no struck-through price, no sale: it is simply on sale at this price |

The Store shows ONE of the three at a time and the pick changes every Monday 00:00 UTC (`Products.featuredAt`, the same for every player; the countdown on the card is real). Create all three products; each always grants exactly what its card says, even if Roblox retries the receipt after the week turned over.

The Grail Bundle (brief 30) is not part of that rotation: it is always in the Featured section, under the week's pack. Its receipt adds the three pairs once per purchase (a retried receipt never adds them twice) and says so in a notice. Until its id is pasted the card shows the price and taps say "coming soon".

Gift A Player (brief 30): the Cash Packs and the Robux boxes can be bought for another player in the server; the server grants it to them (both are told), and if they left it goes to the buyer. Passes, boosts and Power packs are never gifted. No new product is needed for gifting.

The HUD's four extras (brief 30): the **Spin Wheel** (top left: one free spin every 4 hours, real time, also while you are away; the window lists each prize's real chance), **Playtime Rewards** (6 gifts at 5 / 10 / 15 / 25 / 40 / 60 minutes played in one visit), **Missions** (3 small tasks at a time, new ones as you finish them) and the **Starter Pack**. Only the Starter Pack and 3 Spins cost Robux; the rest is free. Until their ids are pasted, their buy buttons say "Coming soon!".

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

`hood/art/README_upload.md` explains how. Do it before judging how the UI looks. (Brief 30: the World 1 box and shoe
pictures, `Box_*.png` and `Shoe_*.png`, were re-rendered from the new chests and shoes and `Box_GrailBundle.png` is new;
the tool sees the changed files and uploads them again, so the ids in IconModels.Images point at the new pictures.)

## Other things to set (not Robux items)

- **Group reward:** put your Roblox group's id in `hood/src/ServerScriptService/HoodServer/ServerConfig.lua` (`GroupId`, 0 = off).
  Members get a one-time Cash + 2x Power reward from the Daily Rewards window (`Player:IsInGroup`).
- **"Robux: ?" teaser:** the HUD's side pass buttons (2x Cash, 2x Power, Auto Fight) show "?" for their price until a tap has
  opened Roblox's own purchase prompt, which always shows the real price; after it (bought or declined) our button shows the price.
  The Store and the in-world boards always show prices.

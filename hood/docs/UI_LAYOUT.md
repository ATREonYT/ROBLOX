# +1 Hood Evolution: the UI, piece by piece (Oct 27)

For sketching the new UI with an AI. It lists every button, counter and window the game has today, where each one sits,
and the style rules every piece follows. The layout copies the soldier game (+1 Soldier Evolution): if a sketch shows
something not on this list, it has no code behind it yet.

The screen is drawn on a **1280 x 720 canvas** (a laptop screen), under Roblox's own top bar. Phones use the same layout,
scaled down.

## 1. The main screen (HUD), always visible

```
+---------------------------------------------------------------------------------------------+
| [Roblox bar]     (Spin Wheel)          NEXT GOAL                    (Playtime)   (Starter)  |
|                                        Beat the Interns                          ( Pack )   |
|                                                                     (Missions)              |
| [   SHOP  🧺 !]                                                              [ x2 Cash   ] |
| [Rebirth][Items]                                                              [ x2 Power  ] |
| [Shoes ][Skins ]                                                                            |
|                                                                                             |
|                                                                                             |
| 🏆 Rank 3                         ⚡ 12.5K Power                                             |
| 🔄 Rebirth 2                      [=========Rebirth bar=======] 57%     [Auto Fight]         |
| 💵 1.2K Cash                      [⚡+5K] [⚡+25K] [⚡+100K]                                    |
| Friend Boost +0% [+]                                                                        |
+---------------------------------------------------------------------------------------------+
```

**Left column** (top-left, 20 px from the left edge)
- **Shop** bar: 156 x 60, a basket icon breaking out of the top, a rainbow "!" badge when something is new.
- Four square buttons, 71 x 71, in a 2 x 2 grid under it: **Rebirth** (with a small "57%" pill: how close the next
  rebirth is), **Items** (guns and boosts), **Shoes**, **Skins**. A cyan count circle on a corner when something is new.

**Bottom-left counters** (stacked, bottom-left corner)
- Rank (trophy icon + "Rank 3"), Rebirths (rebirth icon + "Rebirth 2"), Cash (cash icon + amount), "Friend Boost +0%" with a
  small green + button.

**Bottom centre**
- Your **Power** (lightning icon + the number), above:
- the **Rebirth bar**: 400 x 38, fills toward your next rebirth; "x3 Power" multiplier text on it.
- Under the bar, three **Power pack** buttons (120 x 34 each): "+5K", "+25K", "+100K" with their Robux price.
- To the right of the bar: **Auto Fight** (70 x 40).

**Right column** (top-right, 11 px from the right edge)
- Offer cards, 160 x 52 each, stacked: **x2 Cash**, **x2 Power** (icon left, big title, Robux price under).
- Above them: **Playtime Rewards** (gift with a clock), **Starter Pack** (the crate), **Missions** (the clipboard),
  each a 60-88 px icon with a caption under it.

**Top**
- **Spin Wheel** (68 px wheel, top-left area beside Roblox's buttons, "Ready" when a free spin is waiting).
- **NEXT GOAL** in gold at the top centre, the goal in white under it ("Beat the Interns"). Flashes "GOAL DONE!" when you
  finish one.

## 2. Windows (open from the buttons)
Every window (Oct 27, the owner's mockup `refs/ui/owner_ui_windows_oct27.png`, built in `Shared/UIKit` Kit.window /
Kit.windowBody / Kit.tabs, `InventoryKit.frame` and `ArtKit.panel`): a dark navy body with a faint blue square tile, a thick
dark outline and rounded corners; a bright yellow header bar with the icon breaking out at its left, the title in white
Montserrat Black and a red square **X**; dark pill tabs with the open one blue; items on solid rarity-coloured tiles.
Only one window is open at a time; the game behind it blurs a little.

| Window | Opens from | What's inside |
|---|---|---|
| **Shop** (EXCLUSIVE SHOP) | Shop bar | Power packs, x2 Cash, x2 Power, x10 Cash pad, the paid ranges (PRO BAY, GOLD BAY, HEAD LANE), potions, Auto Collect, Triple Open, Extra Equip, the Boost Bundle; a **Weekly Deal!** card (its countdown is the real weekly rotation) with a row of four pass tiles under it (2x Power, 2x Cash, Lucky, Triple Open); **GIFT** buttons ("Gift A Player"); an **ENTER A CODE** box with **REDEEM**. |
| **Rebirth** | Rebirth square | "Rebirth N" and a one-line subtitle; **Current** and **Next Rebirth** cards (Power multiplier, walk speed) with a ">>>" between them; "Rebirth resets your Power" on a small red pill; the bar; a big green **Rebirth** button (grey "Need X" until ready). Beside it the purple **Skip Rebirth** card (from rebirth 4: four honest lines and the green Robux price), or before that a **You keep** card (Cash, guns, shoes, stages and goals). |
| **Items** | Items square | Your guns (equip), boosts and potions; "Equip Best"; "More guns at the ARMORY"; "No boosts yet" when empty. |
| **Shoes** | Shoes square | A grid of your shoes, rarity colours, "NEW!" tags, Favorite (star) and Delete (trash) buttons, a Search box, **Equip Best**. |
| **Skins** | Skins square | Gun skins grid. |
| **World** | the World button / the portal | World 1 (The Hood), World 2 (Business District), each with its picture and "Coming soon" or the travel button. |
| **Spin Wheel** | the wheel | The wheel, **SPIN!**, "Chances" (the odds for every slice, always shown), "Next free spin in 12:00". |
| **Playtime Rewards** | the gift | A row of gifts that unlock the longer you play, **Claim!** on each ready one. |
| **Missions** | the clipboard | A list of tasks with progress bars and rewards. |
| **Starter Pack** | the crate | What's in it, its price, **OWNED** once bought. |
| **Daily Rewards** | pops up on joining | Seven days of rewards, today's highlighted, **Claim!**. |
| **Ranks** | the Rank counter | The rank ladder and what each one needs. |
| **Shoe box opening** | the shoe boxes in the lobby | Full-screen: the box shakes and opens, the shoe flies out with its rarity; **Stop Auto Open**. The paid boxes always show their odds and the pity counter. |
| **Rank up / Level** | pops up | "RANK UP!" with the new rank, "Press to Close". |

## 3. The cartoony style (what a lot of simulator games do)
1. **Thick dark outline on everything**: buttons, icons, text and windows (near-black navy, about 3-5 px at 720p).
2. **Chunky, rounded shapes**: corner radius 8-22 px, nothing thin or sharp.
3. **A darker "lip" under every button** (6 px), so it looks raised and you can press it down.
4. **Bright, saturated fills with a top-to-bottom gradient**: lighter on top, deeper underneath. One colour per job:
   green = buy and claim, red = close, yellow/gold = rewards and Cash, cyan = Power, purple = rebirth, rainbow = the best paid
   thing (like your **Skip Rebirth**).
5. **A white shine streak** across the top third of big buttons.
6. **Big bold text** (Montserrat Black / GothamBlack), white or gradient-filled, with a thick dark outline. Numbers short:
   1.2K, 3.4M, 1.25B.
7. **The icon breaks out of the button**: it's bigger than the button and pokes over the top edge (like the Shop basket).
8. **Little badges** on corners: a red or rainbow "!", a count circle, a percentage pill, "NEW!".
9. **Robux prices** always with the Robux sign, in a small green or dark tag.
10. **Few colours at once on screen**: the game world stays calm, the buttons are the loud part.

## 4. The animations the UI gets
The motion is already written (`Shared/UIMotion`, `Shared/Juice`, `HoodClient/Motion`); new art plugs into it:
- **Press**: a button squashes to about 92% and springs back, with a click sound.
- **Hover** (computer): grows to about 106%, the icon tilts a little.
- **Windows** pop in from 80% with a little overshoot, and the background blurs. Closing them shrinks and fades.
- **Idle wiggle**: anything ready to claim (Playtime gift, free spin, Daily) gently bobs and tilts every few seconds. That's
  at most one flash a second (a rule for kids' games).
- **Counters** roll up to the new number, and a "+5K" flies from where you earned it to the counter.
- **Shine**: a light streak sweeps across the rainbow and gold buttons now and then.
- **Badges** pop in with a bounce.

## 5. What to send back
- Icons: `hood/docs/ICON_LIST.md` (done: your sheet is already cut and in the game, waiting for upload).
- For each button and window above: a picture of the finished look (any size; same style rules). Buttons can be one
  picture each (the empty button without text: the game writes the words and numbers on top, so they can change), or one
  sheet with names under each, like your icon sheet.

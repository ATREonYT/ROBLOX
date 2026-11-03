---
tags: [miami-trap-life, ui, research, hood-games]
updated: 2026-11-03
---
# Hood game GUIs: the patterns, measured against ours

Back to [[00 Hood Games Index]] · frame list and per-game notes in [index.md](index.md) · our redesign in [[GUI Redesign Spec]].

This note sits on top of the 143 frames in this folder (10 games) and the earlier Urban Reload / OPPS / BlockSpin pack in `benchmarks/`. The `index.md` lists the conventions. This note answers **why ours still looks less "real" than theirs, element by element**, with sizes measured from the frames.

## 1. The big one: size
Measured as a share of screen height so different resolutions compare. Ours is from `04-hud-day.jpg` and `08-phone-open.jpg` (Nov 3).

| Element | Hood games (range) | Ours now | Verdict |
|---|---|---|---|
| Money number height | 1.6–2.4% (TB3, Philly, Da Hood, Vice City) · South Bronx is the outlier at ~3% | **3.3%**, inside a 280 × 64 px pill | about 1.5× too big |
| Stat bar thickness | 1.3–2% (TB3, Da Hood, Philly) | rings 5% wide | rings OK, a touch big |
| Hotbar slot | 5.5–6.7% (Da Hood, Streetz War 2, TB3) | **7.2%**, round | slightly big |
| Minimap | most RP games have none, or a small one; GTA-style ones ~18–20% | **26%** | too big |
| Phone, open | 9–10% wide × 40–45% tall (Vice City 2, Streetz War 2) | **21% wide × 60% tall** | about 2× too big |
| Objective / status text | 1.5–1.9%, often plain text with a shadow | 1.8% in a 50 px pill | fine |

Hood games look "real" partly **because the HUD is small**. The world is the star and the HUD sits in the corners like GTA's. A big chunky HUD reads as a simulator or an obby. Shrinking ours is the single biggest win, ahead of any colour or font change.

## 2. Where things go
- **Status stack.** The RP games (Tha Bronx 3, Philly Streetz 2, South Bronx, Streetz War 2) put money and needs bars together **bottom-left**. Da Hood, Vice City 2 and BlockSpin put money **top-right**. Both are normal. Ours is top-right, which matches what Alex picked, so we keep it.
- **Hotbar: always bottom-centre.** Slots are small, dark and translucent, the slot number sits top-left in tiny type, and the name sits inside. **The selected slot gets a 2 px outline** that sits exactly on the slot edge. It is blue in 8 of 10 games (around RGB 70,130,255) and white in Vice City 2.
- **Prompts are next to the object, not in a HUD bar.** [E] key-cap plus two lines: a small grey object name over a bold white action. A hold ring goes around the key-cap.
- **Status lines are plain text, bottom-centre**, white with a soft shadow: "You are in a safezone 🛡", "Immunity will expire in 886 seconds", "You are being seen on camera!" (red). No box.
- **Keybind hints sit right-middle or bottom-left**: a small key-cap plus a label, and the list changes when you get in a car (Vice City 2, Da Hood 2026, South Bronx's controller list, BlockSpin).
- **World labels** float over places: floating text plus an emoji (South Bronx "APARTMENTS 🏠", "DEALERSHIP") or Da Hood's "[Item] - $price" over shop pads.

## 3. How things are drawn
- **Panels:** dark (RGB 20–35) at 10–30% transparency, small corners (4–8 px), and either no border or a **1 px light hairline that sits exactly on the edge**. Nobody in this pack uses a second offset outline, a bevel line or a drop shadow that shows as a band.
- **Text:** Gotham/Montserrat bold for numbers and labels, medium for body. Sizes are small (10–14 px at 720p). Caps only for short labels ("HUNGER", "ENERGY", "IN SAFEZONE").
- **Colour:** green money everywhere. One accent for selection (blue). Red for danger, death and illegal. Everything else is grey and white. Philly Streetz 2 adds a colour per stat icon (lime money, pink bank, orange hunger, blue energy), and it still reads clean because each colour sits on a small round icon, not on a big panel.
- **Icons:** either glossy round 3D-ish icons (Philly, South London) or simple glyphs (TB3 bank columns, Vice City hex). Emoji only on world markers and status lines.
- **Motion:** quick slides and fades. Money ticks up, a "+$" or "- $1,030" floats near the number, and toasts slide in from the side.

## 4. Screens, game by game, who does it best
| Screen | Best reference | What to learn |
|---|---|---|
| Whole HUD, clean | Philly Streetz 2 `hud-stats-combat` | Round icon + label + thin pill bar, all small, bottom-left |
| Survival stats | Tha Bronx 3 `hud-tired-stats` | 4 thin bars with an icon at the end, a white body silhouette that shows injuries, short red warnings ("You are tired") |
| Cash vs bank | Vice City 2 `hud-cash-bank-closeup`, TB3 | Two numbers, the second in a different colour, small labels |
| Hotbar | Streetz War 2, Da Hood | Small squares, names in the slot, blue selected outline |
| Shop | Philly Streetz 2 `shop-guns-catalog` | Translucent panel over the live store: CATALOG list on the left, CHECKOUT preview on the right, a green "PURCHASE ($100)", a red "Exit Store" |
| Shop, list style | Tha Bronx 3 `shop-city-illegal` | Name, stock, price rows, one green Buy, a red "Success! -$3000" |
| Phone | Vice City 2, Streetz War 2 | A slim iPhone at the right, 40–45% of screen height, a real lock screen, apps that do something (Maps with pins, a supplier app, social posts that also show as HUD toasts) |
| Death | Vice City 2, Philly, TB3 | Red or dark world, "killed by NAME", a countdown, one line of flavour text |
| Alerts | Streetz War 2 `hud-onfoot-frisk` | A small left card: icon, title, "43s ago", a progress line, a "Set GPS" button |
| Robbery feedback | Da Hood ATM, Outwest bank | Money props with floating "$126" values, counters "0/20" |

## 5. What we already do better
- A real tutorial with one objective at a time and a cinematic intro. None of these games has that.
- Our phone looks more modern than most of theirs (dynamic island, real clock, app grid).
- Eased motion and sound on every tap.

## 6. What we must not copy
- Vice City 2's chamfered panels, white bracket lines, hex money badges and red-wave phone wallpaper. It is our direct Miami competitor and owns that look.
- Paid "Keep Inventory" or revenge buttons on the death screen.
- Anyone's logos, icons, fonts or exact layouts.

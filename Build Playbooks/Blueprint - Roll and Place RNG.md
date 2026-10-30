---
tags: [build-playbooks, blueprint, rng, collection, idle]
updated: 2026-10-30
---

# Blueprint - Roll and Place RNG

Back to [[00 Build Router]] · Family overview: [[01 Current Hits October 2026]]

**Code:** start from [[05 New Game Kit]] (`sh new-game-kit/tools/new_game.sh`); build only this blueprint's own loop.

**One line:** press Roll to get a random unit, keep the best ones on your plot to earn cash every second, and buy more luck and income so the next rolls are better.

Reference games: Anime Dice (99% rating, an update every Saturday), Sol's RNG. Deep teardown: [[Teardown - Sol's RNG]]. Genre notes: `LihFolk/LihFolk Vault V2/10 Game Design and Genres/Genre Playbook - RNG and Collection Games.md`.

## 1. Pick the twist
- **What you roll:** dice, cards, gacha capsule, slot machine, a fishing cast, a cooking pot (original units only).
- **What units do:** earn on a plot (Anime Dice), fight in a tower (Anime Dice towers), or just collect (Sol's RNG auras).
- Keep the roll free and fast. Paid luck is optional and must show odds.

## 2. Loop
```text
roll (free, every ~1 s) ─► unit (rarity × grade × trait) ─► place best on plot ─► cash/s
   ▲                                                                         │
   └── luck upgrades, better dice, roll speed ◄── cash ◄─────────────────────┘
          towers / side modes ─► gems, potions, trait rerolls
          rebirth ─► reset cash, keep units ─► permanent multiplier
```
First minute: Roll is the biggest button on screen; the first 5 rolls are guaranteed to improve (a starter pity); place one unit and watch cash tick; turn on Auto Roll (free) within 2 minutes.

## 3. What Anime Dice does (the layered multipliers)
| Layer | Range | Note |
|---|---|---|
| Dice (base luck) | 200x → 3,000x, costing $30M → $12B | each dice tier is a big goal |
| Grade (income multiplier) | D 1.1x → Z+ 25x | rolled on every unit |
| Trait | 25.4% (tier I) → 0.006% (Transcendent); up to 27x | rerolled with Trait Rerolls from towers |
| Upgrades | Money and Luck feed each other; Roll Speed third | Unit Storage matters less once Auto Sell is on |
| Rebirth | resets cash; units, grades and traits stay | |
Source: [All Things How guide](https://allthings.how/anime-dice-roblox-how-to-progress-fast-full-guide/).

## 4. Systems
| # | System | Note |
|---|---|---|
| 1 | One weighted roll table (rarity → grade → trait) that also builds the odds panel | [[Drop Tables Rarity and Pity Systems]], [[Rarity Ladders and Drop Pacing Math]] |
| 2 | Luck as a divisor on rarity weights, shown live | [[Paid Random Items and Odds Disclosure in Practice]] |
| 3 | Auto Roll + Auto Sell thresholds | [[Hold vs Toggle Auto-Sprint Auto-Equip and Quick Slots]] |
| 4 | Plot with N slots, cash/s, offline earnings | [[Tycoon Plots and Droppers End to End]], [[Offline Earnings]] |
| 5 | Big numbers (1.5B, 12T) | [[Big Numbers Precision and Formatting]] |
| 6 | Side mode: tower floors for gems and rerolls | [[Round-Based Minigame Loop End to End]] |
| 7 | Global rare-roll announcements ("X rolled a 1 in 1,000,000!") | social proof; rate-limit them |
| 8 | Index / collection book | [[Saved Inventory End to End]] |

## 5. Rules (2026)
- Anything random that Robux can speed up (luck potions, paid rolls) counts as a paid random item: odds summing to 100% before buying, odds update live while a boost is active, `PolicyService` check, no hidden odds. See [[Regional Compliance - Paid Random Items and Country Rules]].
- Free Auto Roll is fine and good for retention. Don't sell "auto" as the only way to play.

## 6. Done when
- [ ] Roll → place → cash in under 30 s.
- [ ] The odds panel is built from the same table as the roll.
- [ ] A rare roll feels huge (screen flash ≤ 1 per second, sound, server announcement).

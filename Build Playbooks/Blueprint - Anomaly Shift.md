---
tags: [build-playbooks, blueprint, anomaly, horror-lite, job-sim]
updated: 2026-10-30
---

# Blueprint - Anomaly Shift

Back to [[00 Build Router]] · Family overview: [[01 Current Hits October 2026]]

**One line:** work a normal job on a night shift (hospital, fry stand, kebab kiosk), serve each customer or patient, and spot the ones that are subtly wrong before they get you.

Reference games: Animal Hospital (Anomaly), Sell Fries! [Anomaly], Scary Shawarma Kiosk: the ANOMALY. Servers of about 30, no voice chat. Related notes: [[Case Study - Doors]], [[Horror Monster Chase AI End to End]], `LihFolk/LihFolk Vault V2/10 Game Design and Genres/Genre Playbook - Horror and Story.md`.

> [!warning] Spikes and fades fast
> Animal Hospital went from about 358K to 35K players in one month (StudioKrew, Sept 2026). Build it small and fast (one to two weeks), ride the spike, and have 3 new "nights" ready.

## 1. Pick the twist
- **Job (something kids know):** vet, fry stand, ice-cream truck, school nurse, pizza delivery, hotel desk.
- **Anomaly rule (one sentence, shown on a poster in the shop):** "Real dogs have 4 legs. Never serve a customer with no shadow."
- Kid-friendly scary: spooky, not gory. Check the maturity questionnaire and [[Policy and Age Rules 2026]].

## 2. Loop
```text
night N starts ─► customer arrives ─► inspect (look, ask, scan) ─► serve OR refuse/report
                                         │ wrong call on an anomaly ─► jumpscare ─► shift over
       next night (new rules, new anomalies) ◄── survive until 6 AM ◄── cash for upgrades/cosmetics
```
- A night lasts **5-8 minutes** (**start**), with 6-10 customers and 1-3 anomalies.
- Each new night adds one new anomaly type and one new rule on the poster.

## 3. Systems
| # | System | Note |
|---|---|---|
| 1 | Customer queue + a checklist of "normal" traits | data-driven: each customer is a table of traits |
| 2 | Anomaly generator: swap 1-2 traits from a weighted list | [[Drop Tables Rarity and Pity Systems]] |
| 3 | Inspect tools (flashlight, scanner, thermometer) | each reveals one trait |
| 4 | Fail state: one jumpscare (≤ 1 flash per second), then a results screen | [[Comfort Toggles - Flashes Damage Numbers and Hit-Stop]] |
| 5 | Night progression + save of the best night | [[Saved Inventory End to End]] |
| 6 | Co-op: 2-4 friends share a shift (co-play days are a discovery signal) | [[Social Design and Multiplayer Play]] |
| 7 | Cosmetics for the uniform and the shop | [[Shop with Game Passes and Developer Products End to End]] |

## 4. Look and feel
- Cosy, well-lit shop interior against a dark, foggy outside. The contrast does the scaring.
- Sound carries it: hum, rain, footsteps, one sting for the reveal.
- Lighting: dim ambient, a warm PointLight per lamp, Atmosphere density up outside only.

## 5. Money
Cosmetics (uniforms, shop skins), a "second chance" product (once per night, clearly priced), and a friend-revive. No pay-to-skip nights.

## 6. Done when
- [ ] First customer within 15 s; the first anomaly in night 1 is obvious.
- [ ] Every anomaly follows a rule written on the poster (fair, never random death).
- [ ] Playable solo and with friends.

---
tags: [build-playbooks, realistic-rp, crime, police, wanted, jail]
updated: 2026-11-01
---

# 08 Crime, Police and Wanted Levels

Back to [[00 Start Here - Realistic City RP]] · Older genre note: LihFolk `Genre Playbook - Open-World City and Crime Roleplay` §2-4 · Kit: `Server/Wanted.luau`, `Roleplay.JailSeconds`

## 1. The loop

```text
Criminal (opt-in role) commits a crime the SERVER saw ─► heat → stars ─► 911 auto-call to police with the place
   ─► police respond (icons of starred players show on police GPS when spotted)
   ─► chase (cars, on foot) ─► cuff (hold 1.5 s within 8 studs, stars > 0) ─► transport or instant booking
   ─► jail 12 s/star (10-60 s), robbery cash in pocket confiscated + fine ─► release at the station
   or ─► escape: stay unseen 45 s, then stars fade (20 s each) ─► deposit the take at an ATM = success
```
Southwest Florida's version gates bigger targets behind crime ranks (diners and gas stations first, banks last), with ~80 s robbery timers and 300 s per-register cooldowns. That's a good shape. Ours, in our own words:

## 2. Crime ranks and targets (fictional, non-graphic)

| Rank (by successful jobs) | Unlocks | Hold time | Cooldown (per target) | Payout | Heat |
|---|---|---|---|---|---|
| 1 Rookie | corner store register, ATM | 60 s | 300 s | $300-$600 | Robbery 45 (3★) |
| 2 Hustler | gas station, car theft (NPC cars) | 75 s | 300 s | $600-$1,200 | 45 / 30 |
| 3 Planner | jewellery store (glass cases, a 4-player job) | 90 s | 600 s | $1,500-$3,000 split | 45 + alarms |
| 4 Mastermind | **bank vault** (2-6 players, drill, keypad mini-game, server-wide alert) | 180 s | 2,000 s server-wide | $8k-$20k split | 100 (5★) |

- No drugs, no laundering, no kidnapping, no realistic gang content. "Heists" are about timing, roles (driver, lookout, hacker, cracker) and getaways.
- A robbery needs **police online** (at least 1 on duty per 2 criminals) or it's disabled with "Too quiet tonight: no cops on duty". This is the single most important balance rule: crime is a *game against players*, not free money.
- Robberies run on **server timers** with progress bars visible to the police too; leaving the area (> 25 studs) pauses the hold.

## 3. Police (fun, capped, no Discord applications)

- Opt-in team from the Jobs app, **capped at 25% of the server** (kit `Roleplay.CanJoin` with `cap`). Rank by arrests without collateral (no damage to civilians).
- Tools: **taser** (non-lethal, 1 s stun, 6 s cooldown, 25 studs), cuffs, radio (calls feed), spike strip (one per officer), patrol car with lights/siren (siren sound 1 loop, light bar flashes **once per second max**).
- Seeing = **line of sight within 120 studs** (server raycast every 0.5 s from on-duty officers to starred players). Seen → `Wanted.Seen` (fade timer restarts) and the criminal appears on all police GPS for 10 s.
- Arrest: `Wanted.CanArrest(w, now, distance, onDuty)` → cuffs (hold 1.5 s, interrupted if the target breaks LOS or moves 6 studs) → `Wanted.Bounty` paid to the officer → jail.
- Abuse guard: cuffing someone with 0 stars is impossible (the server refuses), so police can't grief civilians. Tasering a civilian with 0 stars costs the officer rank points.

Hood games gate police behind a Discord application and group rank. We don't: everyone can try police in the Jobs app, rank is earned in-game. Discord and group ranks can add cosmetics only.

## 4. Jail (short and still fun)
- Jail is a **yard**, not a cell: basketball hoop, pull-up bar, a vending machine. 10-60 s (kit clamps). Countdown on screen. Bail: pay 2× the fine to leave now.
- Jailbreak attempt: an optional 15 s mini-game (dig/vent) that, if it works, sets 2★ heat. Keeps "jail" playful.
- Never: forced long sentences, cells with no exit, jail on rejoin longer than the remaining seconds.

## 5. Wanted (kit `Wanted`) numbers

| Crime | Heat | Stars |
|---|---|---|
| Speeding past a police car | 5 | 1 |
| Trespass in a closed store | 10 | 1 |
| Knocking out a protected player | 25 | 2 |
| Car theft | 30 | 2 |
| Store robbery | 45 | 3 |
| Bank vault | 100 | 5 |
Heat fades after **45 s unseen**, then **20 s per star**. Bounty **$150/star**, jail **12 s/star**.

Stars show above the criminal's head **only to police** (a BillboardGui with `PlayerToHideFrom` isn't enough; put it in a police-only ScreenGui marker layer driven by a server list sent only to police).

## Done when
- With 6 police and 10 criminals on a server, a store robbery gets a response within 30 s most of the time.
- A civilian can play an hour without being cuffed, tased or robbed unless they chose a crime role.

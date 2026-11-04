---
tags: [build-playbooks, realistic-rp, monetisation, starter-pack, gamepasses, private-servers]
updated: 2026-11-01
---

# 12 Money - Starter Packs, Passes and Offers

Back to [[00 Start Here - Realistic City RP]] · Our rules and numbers: [[21 Money and Retention at Studio Level]], [[Brief - Saving, Economy and Monetization]] · Kit: `Shared/Offers.luau`, `Server/Receipts.luau`, `Server/Shop.luau`

## 1. What city RPs sell (and what we sell)

| Product | Type | Price idea (R$) | Fair? | Notes |
|---|---|---|---|---|
| **Starter Pack** | Dev product, once per account | 199 | Yes | $15k bank + a starter car colour + a cosmetic outfit + 2 h 2× job XP. Value must be obvious (show "what's inside") |
| VIP | Game Pass | 399-699 | Yes | Name tag colour, 2 extra garage slots, VIP lounge, +10% job pay (pay, not damage) |
| Premium cars pack | Game Pass | 299-799 | Yes | Exclusive *styles*; same performance band as earnable cars at that level |
| Bigger garage / outfit slots | Game Pass | 99-199 | Yes | Storage, never items |
| Mansion tier house | Game Pass | 499 | Yes | ER:LC sells premium housing the same way |
| Police/Medic gear cosmetics | Game Pass | 149-299 | Yes | Liveries, uniforms; no stronger tasers |
| Cash packs | Dev products | 49 → 1,699 ladder | Careful | Allowed, but cap their effect: cash can't buy weapons above your level, and the bonus labels must pass `Offers.Ladder` |
| Private servers | Roblox private servers | 0-100/mo | Yes | Huge in RP (friend groups, events). Offer free or cheap, with owner controls (PvP rules, time, weather) |
| Subscriptions | Roblox subscription (payable in Robux since April 2026) | monthly | Later | "City Pass": daily bank bonus + monthly exclusive car style; only once retention is proven |
| Paid random items | — | — | **No** at launch | If ever: odds shown, pity counter, `PolicyService` check |

Never sell: stronger guns, damage boosts, police/crime role skips past caps, protection from arrest, or "win" items. Pay-to-win in PvP kills an RP server.

## 2. The starter pack, done our way
The screenshots show a starter pack tile with a **countdown (22:20)**. Our rule is **no fake timers or scarcity** (`CLAUDE.md`; the repo's kid-safe check flags "ends in" countdown text in code). So:
- Show the tile only to players in their **first 3 sessions**, labelled "New Player Pack", **no countdown**. If we want urgency, it's *real*: it disappears after session 3 and the shop says so plainly ("Only for new players").
- Show it **after** the first paycheck (minute 2-3), not at spawn: they now know what money means. Kit `Offers.CanShow` already holds unasked offers off for the first 3 minutes, keeps an 8 s gap and shows one per session to non-buyers.
- One tap opens a card listing every item with a picture; "Buy for 199" calls `PromptProductPurchase`. **Grant only in `ProcessReceipt`, once per PurchaseId, "granted" only after the save** (kit `Receipts` + `PlayerData`).
- Regional pricing (live since April 2025, opt-in per item) lowers prices in many countries automatically; turn it on for passes and the starter pack (Roblox reported +17% to +52% more spenders in test regions).

## 3. Where the shop lives
- Phone **Shop** app (all of it) + **contextual** offers at the moment of need (Roblox's "contextual purchases" guidance): garage full → "More slots" card; at the dealership → premium styles row; after an arrest → nothing (never sell at a moment of loss).
- No pop-ups during combat, chases, robberies or within 10 s of a knockout. One modal at a time; never stack.

## 4. Numbers to watch
Conversion (payers / DAU) 2-5% for RP; ARPDAU; starter pack take rate in sessions 1-3; refund/support complaints; and the **economy check** that cash packs don't move the median time-to-first-car below 20 minutes for non-payers (if it does, payers are skipping the game).

## Done when
- Every product shows what it gives before purchase, and nothing gives combat power.
- A test purchase, a redelivered receipt and a failed save all behave (kit play-through covers this).

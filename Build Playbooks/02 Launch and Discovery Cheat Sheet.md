---
tags: [build-playbooks, launch, discovery, policy, 2026]
updated: 2026-10-30
---

# 02 Launch and Discovery Cheat Sheet

Back to [[00 Build Router]]

The 2026 rules on one page. Details and sources: [[Discovery and Monetization Changes 2025-2026]], [[Policy and Age Rules 2026]], [[Roblox Changes 2025-2026]], and the Roblox discovery doc (create.roblox.com/docs/production/promotion/discovery, read 2026-10-30).

## How Home recommends games (since June-August 2026)
Only players who joined **organically from Recommended For You** count. Ads, search and friend joins don't feed these signals. Everything is measured **per user**.

| Priority | Signal | What it means for us |
|---|---|---|
| Most important | Play-through rate | Thumbnail + title make a kid click. |
| Most important | First-play bounce (under 60 s and 61-180 s) | **The first 60 seconds decide everything.** First reward in under 60 s. |
| Most important | Play days per user (Day 1, Days 2-7, Days 8-28) | A reason to come back tomorrow and in week 3: offline earnings, daily reward, weekly update. |
| Most important | Playtime per user (capped at 60 min per day) | Several short sessions beat one marathon. |
| Important | Intentional co-play days | Friends joining, invites, private servers. Make playing with a friend better. |
| Important | Qualified play sessions | Real sessions, not accidental clicks. |
| Important | Spend days per user, Robux per user | Many small, fair purchases across many days (a price ladder). |

Also from the doc:
- A **custom thumbnail is required** for Home. Default thumbnails are ineligible (since 2026-10-19). Thumbnails must match the gameplay.
- Games that closely copy an existing title (name and visuals) are deprioritised. **Add your own spin.**
- Titles that lead with money rewards get less exposure.
- Saturday is the weekly traffic peak; summer and holidays are seasonal peaks.
- Use Experience Events (up to 5 event thumbnails) and experience notifications for comebacks.

## Can kids even find the game? (Roblox Kids 5-8, Select 9-15)
- The game needs a **Minimal or Mild** maturity label (Moderate reaches only 9-15 and 16+).
- It must **pass selection**: owner ID verification + two-step verification + a Plus/Premium subscription at least 2 months old (or a refundable per-game fee), plus a real-time evaluation of how 16+ players engage.
- Social hangouts and free-form drawing are excluded by default.
- So: plan launch as a **16+ trial first**, prove retention, then get into Kids/Select. See [[Policy and Age Rules 2026]] section 2.

## Money rules that get games removed if broken
- Paid random items (eggs, crates, luck boosts, spins): numeric odds that sum to 100% before purchase, live odds while a boost is active, every outcome worth something, `PolicyService` check that fails closed, a separate check for trading paid items. [[Paid Random Items and Odds Disclosure in Practice]].
- Show prices with `GetProductInfoAsync` (Plus members see discounts), never hard-coded.
- Repo rules (`CLAUDE.md`): no fake timers or stock, at most 1 flash per second, never sell something that gives nothing yet, grant purchases only on the server, once per PurchaseId.

## Launch checklist
- [ ] Maturity questionnaire filled in; the label is Minimal or Mild.
- [ ] A custom thumbnail that shows the real game; icon readable at 150 px ([[Thumbnails and CTR Start Here]]).
- [ ] The title explains the game ("Verb For X", "+1 X Evolution").
- [ ] The first reward lands in under 60 s on a phone; nothing to read.
- [ ] A reason to return tomorrow (offline earnings, daily reward) and in week 3 (weekly updates planned).
- [ ] A friend bonus (co-play): an invite button, a "play with friends" multiplier.
- [ ] A price ladder of small, fair items; passes are self-only.
- [ ] Odds panels for anything random that Robux touches.
- [ ] [[16 Cartoony Kid-Appeal Checklist]] passed; tested on a real phone at low graphics.
- [ ] Launch on a Friday or Saturday; small ads test; watch first-play bounce and D1 in Creator Analytics.
- [ ] Benchmarks to aim for: D1 12-15%, D7 2-3% (from [[Why 90% of Roblox Games Never Get Players]]); core loop understood in 2-5 minutes.

## After launch
- Weekly update on a fixed day, shown in the title and with an event thumbnail.
- Read Creator Analytics, Acquisition, Home Recommendations; fix the weakest signal first.
- [[Live Ops Deep Dive Start Here]], [[Retention and Return Hooks]].

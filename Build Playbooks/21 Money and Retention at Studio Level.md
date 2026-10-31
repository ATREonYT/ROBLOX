---
tags: [build-playbooks, monetization, retention, live-ops, pricing, analytics, kid-safe, studio-level]
updated: 2026-10-31
---

# 21 Money and Retention at Studio Level

Back to [[00 Build Router]] · Studio practice: [[18 Studio-Level Development Playbook]] · Whole game: [[20 Whole-Game Field Guide]] · Loops and numbers: [[12 Game Loop Logic Playbook]] · Rules and APIs: `Sector Briefs/Brief - Saving, Economy and Monetization.md`, `Sector Briefs/Brief - Game Design, Retention and Growth.md`

**Why this note exists.** On Oct 31 Alex asked every thread to keep going, and money and retention were the thinnest part of the studio-level notes. The two Sector Briefs already cover the APIs (receipts, passes, odds, Roblox Plus). This note is how a studio *decides*: what to sell, at what price, when to show it, how to read the numbers, and how to bring kids back. It is all filtered through our house rules.

**Sources:**
- LihFolk: `11 Monetization Publishing and Live Ops/` (Unit Economics, Robux Price Points and Offer Design, Analytics and Funnels, Measuring Onboarding, Ads and Rewarded Video, Subscriptions), `38 Live Ops Deep Dive/` (Battle Pass, Event Calendars, Limited-Time Offers) and `48 Economy Design Deep Dive/`.
- The two Sector Briefs (verified Oct 30, 2026), which win where they disagree.
- Roblox publishes **no recommended prices**. Every price below is a rule of thumb, marked (r).

**Our rules come first:**
- No fake timers, scarcity or stock.
- Paid random items show odds and a pity counter.
- Never sell something that gives nothing yet.
- No VIP branding.
- Purchases are granted only on the server.

## 0. The one-paragraph version
Fix retention before money: an offer can't save a game that kids don't come back to. Sell **permanent, visible upgrades** (2× coins, auto-tap, extra pet slots, a trail ladder) and **one fair currency ladder**. Price them by the ladder rules in §2, show the price from Roblox (never typed), and pop up unasked offers rarely (§4). Read four numbers weekly (§5) and change one thing at a time.

## 1. What to sell in a kids' simulator (in order of trust)
| Rank | Product | Why it works | Kid-safe notes |
|---|---|---|---|
| 1 | **Permanent passes** that change how you play: 2× coins, auto-tap, faster hatch, +1 pet slot | A one-time buy, visible every session, never expires | Tell the player exactly what they get ("2× coins forever"). Check ownership with `UserOwnsGamePassAsync` on the server. |
| 2 | **Cosmetic ladder** (trails, auras, cannon skins) from tiny to the top tier | Kids show it off; doesn't break balance | The top tier gets the loudest look and a plain name, never "VIP" |
| 3 | **Currency ladder** (Gems) | Repeatable, so a few big fans can buy it more than once | Value must rise with each pack (§2). Gems that buy eggs make those eggs paid random items: odds and pity. |
| 4 | **Starter pack** (one per player, the best value in the game) | The first purchase is the hardest; a great first deal earns trust | Shown after the first rebirth, never in the first 3 minutes |
| 5 | **Small helpful consumables** (a 15-min 2× boost) | Fills leftovers under 100 Robux | Say the exact effect and length. Never sell a revive straight after a loss to a young child. |
| — | Season pass, experience subscriptions | Only once kids already return on several days a week | Later, not now. See §6. |
| ✗ | Countdown offers, "only N left", crossed-out "was" prices, near-miss luck pop-ups | They work by pressure | Banned for us. `tools/kidsafe_check.py` fails the build on most of them. |

**Never sell something that does nothing yet.** A pass for a feature that isn't built shows its price and says "Coming soon". Tapping it never opens a purchase (repo `CLAUDE.md`).

## 2. Pricing: the ladder rules (r)
1. **Rungs:** 3 to 5 per category.
   - Impulse: under 100 (75, 79, 99) catches leftover Robux.
   - Core: 150–600 (passes, main packs).
   - Premium: 700–1,500.
   - Whale: 2,000+ only for repeatable things (currency), never a one-time pass.
2. **Value per Robux rises with every rung, but by less each time.** Example:

   | Pack | Gems | Price | Bonus |
   |---|---|---|---|
   | Small | 100 | 99 | 0% |
   | Medium | 600 | 449 | +32% |
   | Large | 1,300 | 899 | +43% |
   | Huge | 3,000 | 1,999 | +49% |

   If the top jump is bigger than the one below it, nobody buys the middle packs.
3. **Labels are computed, never typed.** `Offers.Ladder(rungs)` returns the bonus % from the real amounts and refuses a ladder that breaks rule 2. (LihFolk measured a pass whose text said 1.5× while the code gave 2×.)
4. **Prices end in 9.** That is the platform habit. Leave room between rungs: at 399 and 449, the cheaper one wins almost every time.
5. **Price permanent passes by how long a fan plays.** 2× coins forever is worth more than a 15-minute boost. Typical simulator passes sit at 99–499 (r).
6. **What you really earn:** about 70% of the price, lower in cheaper regions (regional pricing is on for all passes since March 30, 2026). Roblox Plus discounts are paid by Roblox, so your share doesn't drop. `Offers.NetRobux(499, 0.7, 0.6)` = 307 per sale, not 349.
7. **Never hard-code prices on screen.** Show `GetProductInfoAsync`'s price. Games with about 60,000 sales in 30 days can let Roblox's price optimization test prices; don't build our own price tests.

## 3. The shop players open themselves
- One shop button, always in the same spot. Kids find it by habit.
- **Passes first**, then the currency ladder, then cosmetics. Put the best-value or most-loved item in the top-left card with one honest badge ("Best value" computed from §2, or "Most popular" from real sales).
- Every card shows: the picture, one line on exactly what it does, the price from Roblox, and "Owned ✓" when owned. A pass that's owned never asks again.
- Paid random items (eggs bought with Gems or Robux): odds as final-item %, updated live while a luck boost is on, plus the pity counter ("Guaranteed Epic in 12 hatches"). The kit's `Odds` and `EggHatch` do this.
- After a purchase: a quick celebration (note 14 premium layer), the item appears **at once** and is visible in the world, and "Thank you!" is said once. Never ask for a second purchase straight after.

## 4. Offers the player did not ask for (pacing, `Offers.CanShow`)
| Rule | Value | Why |
|---|---|---|
| Quiet start | no unasked offer in the first **3 minutes** of the first session | The first minute decides discovery (quits under 60 s count against you) |
| Gap | never two pop-ups within **8 s** | LihFolk measured it in their reference project |
| Per session | **1** for someone who never bought, **2** for a buyer | Pop-ups cost D1 retention |
| After "no thanks" | wait **10 minutes** | A quick re-ask feels like nagging |
| Best moments | right after a win (first rebirth, new zone, rare hatch), or when the player taps a locked thing | The moment beats the price |
| Never | after a loss for young kids, during a reveal or cutscene, or on a timer | Kid-safe |

Asked-for shops (the player tapped Shop) have no limit. `Offers.Rules` holds the numbers; change them there.

## 5. The numbers a studio reads every week
| Number | What it tells you | Aim for (r) | Where |
|---|---|---|---|
| **Play-through** (clicks ÷ impressions on Home) | The thumbnail and title | Rising after each thumbnail test | Creator Hub, Acquisition |
| **First-play bounce** (quit under 60 s, and 61–180 s) | The first minute | As low as possible: Home ranks on it since June 15, 2026 | Creator Hub, Home Recommendations |
| **D1 retention** (came back the next day) | The first session | 12–15% to start, more is great | Creator Hub, Retention |
| **D7 / D2–7 play days** | Is there a mid-game? | D7 2–3% to start | Creator Hub, Retention |
| **Payer conversion** (buyers ÷ players per day) | Is the shop trusted and visible? | Watch the trend, not the number | Creator Hub, Monetization |
| **ARPDAU** (Robux per daily player) | Money per player | Compare only with your own past weeks | Creator Hub, Monetization |

**How to read them:**
- Fix the **weakest early number first**: thumbnail, then the first minute, then D1, then money.
- **Plays steady but D1 fell:** something broke the first session (a pop-up, a bug, a slow load).
- **D1 steady but D7 fell:** a mid-game wall, or the content ran out.
- **After every update**, compare the 3 days of new players after it with the 3 days before. Updates often help old players and hurt new ones.
- **Funnels** (`AnalyticsService` on the server, up to 10): join → first tap → first buy (in-game coins) → first hatch → first rebirth → second session. The biggest drop is the next job.
- **A/B tests:** test timing and layout, never prices. `Offers.Bucket(userId, "test_name")` gives each player a stable 0–99 bucket. Decide the winning number (usually D1) **before** looking. Run until each side has hundreds of players.
- **Creator Rewards** (they replaced Premium Payouts): 5 Robux a day per Active Spender who plays 10+ minutes in your game as one of their first three games that day, plus 35% of a new player's first $100 when you brought them. So **daily return and playtime are money too**.

## 6. Retention: bringing kids back (the kid-safe hooks)
**Discovery counts play days in three windows:** D1, D2–7 and D8–28. Plan a hook for each window.

| Window | Hook | Kit piece |
|---|---|---|
| Next day (D1) | Offline earnings ("You earned 4,200 while away!"), a 7-day daily reward, a quest left at 2/3 | `Income` offline, `DailyRewards`, `Quests` |
| Days 2–7 | The streak continues; a missed day **pauses** it instead of wiping it (no guilt); new zone or egg one rebirth away | `DailyRewards` (graceDays), `Progression` |
| Days 8–28 | A weekly update with something new to see (zone, egg, cosmetic), weekly leaderboard, weekly quests | `Leaderboard` (weekly), live ops in §7 |
| Every session | An exit hook that is real and short: a playtime gift in 4 minutes, a hatch 2 coins away. **Never** a punishment for leaving. | `PlaytimeGifts` |

- **Friends:** a visible "Play with friends" bonus (+10% per friend in the server (r)). Reward a referral only when the friend actually arrives (`ReferredByPlayerId` in join data), never on "invited".
- **Notifications:** Experience notifications reach only opted-in players **13+**, once per player per day, and the opt-in prompt can show once per 30 days. For under-13 kids, the only channels outside the game are update announcements and Experience Events. Developer push notifications are announced for late 2026 and **not shipped**: don't build on them.
- **Under-16 discovery:** games must pass selection with 250 unique plays from engaged, age-checked 16+ players in 60 days (Roblox said 100 from November). Plan an older-player trial first.

## 7. Live ops: a calendar a small team can keep
- **Measure first:** count what we really shipped in the last 6 weeks, then plan. Keep **one buffer week a month**.
- **Most updates are config:** a new egg, a reskinned zone, a rotation of quests. At most **one new mechanic a month**.
- **Weekends:** don't run a 2× event every weekend; kids learn to play only then. Space them out and check the weekdays.
- **Free events can end on a real date** (a Halloween zone open Oct 24–Nov 7). The end date shown is the real one, stored on the server and shown in server time. **Nothing sold** gets a countdown in our games.
- **Seasonal cosmetics:** don't promise "never returns" unless you will keep it forever. Simpler for us: seasonal items come back next year.
- **Every update:** short patch notes in the game ("New: Lava Zone and Lava Egg!"), plus the update announcement on the game page.
- **Kill switches:** ship each new feature behind `Flags.On("Name")`, so a bad event can be turned off live (note 18 §11 B).

**Season pass, later (only if kids return several days a week and we can ship new rewards monthly):**
- Roblox's guidance: about a month long, a week of rest between seasons, about 10 tiers, daily missions that never need paid currency, and a free track with its own final reward.
- A late buyer gets every tier already reached.
- **Unclaimed rewards are granted automatically at the end.**
- Plan XP with 15–20% slack, so a normal player finishes.
- Kid-safe extra for us: no "buy tiers" button, and the premium price is shown with what it gives up front.

## 8. Rewarded video ads (only if we qualify)
- **Eligibility:**
  - the creator is 13+, with 2-Step Verification and a verified ID;
  - the game is public, with no free-form user creation;
  - an approved Maturity & Compliance questionnaire;
  - 2,000+ visitors a month.
- **The reward:** fixed, never Robux, never random, and never so big it breaks the economy. For example, 15 minutes of 2× coins.
- **Grant it only in ProcessReceipt** (the ad reward is a developer product), never also after the ad call. That gives a double grant.
- **Placement:** one clear opt-in button, never forced, never in the first minutes. Check availability right before offering.

## 9. Studio checklist before turning on money
- [ ] D1 is acceptable in a soft launch (excluded from Recommended, or a small ad test) **before** adding offers.
- [ ] Every product has a server grant; receipts grant once per PurchaseId, "granted" only after the save (`tools/sim.luau` proves it).
- [ ] Ladder checked with `Offers.Ladder`; labels come from it.
- [ ] Prices on screen come from `GetProductInfoAsync`; none typed.
- [ ] Paid random items: final-item odds, live while boosted, pity counter shown; refused where `PolicyService` restricts them (sim proves it).
- [ ] Unasked offers go through `Offers.CanShow`.
- [ ] Nothing for sale has a countdown, a stock count or a "was" price (`kidsafe_check.py`).
- [ ] Not-yet-built features say "Coming soon" and never prompt.
- [ ] Funnel events logged on the server; a weekly review on the calendar.
- [ ] Every product, pass and ad ID left at 0 until Alex creates it. Never invented. All listed on Alex's checklist.

## 10. What only Alex can do
- Create the passes and products in the Creator Hub, set their prices, and send back the IDs.
- Turn on regional pricing (on by default) and later price optimization.
- Fill in the Maturity & Compliance questionnaire, and the rewarded-ad eligibility steps.
- Read the Creator Hub numbers weekly (§5), or send screenshots so we can read them together.

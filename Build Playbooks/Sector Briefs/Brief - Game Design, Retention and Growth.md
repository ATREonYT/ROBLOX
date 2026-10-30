---
tags: [sector-brief, game-design, retention, live-ops, discovery, growth, thumbnails, notifications, kids-policy, 2026]
updated: 2026-10-30
---
# Brief - Game Design, Retention and Growth
Back to [[00 Build Router]] · All briefs: [[Sector Briefs Index]]

This brief goes one level deeper than [[02 Launch and Discovery Cheat Sheet]]. Read that page for the one-screen version. This page gives the recipes, the code hooks and the exact limits.

> TL;DR
> - **Home ranks your game on per-user signals from organic Recommended For You players only**: play-through rate, first-play bounce (under 60 s and 61-180 s), play days (D1, D2-7, D8-28), playtime (capped at 60 min per user per day). Ads, search and friend joins do not feed these. Build for the first 60 seconds and for Day 2. (Roblox docs, discovery, updated 2026-10-29)
> - **No custom thumbnail, no Home impressions.** Titles that lead with money rewards, mismatched metadata and copycat games are deprioritised. (Roblox docs)
> - **Under-16 players only see games that pass selection.** Label must be Minimal or Mild for Roblox Kids (5-8). Entry bar today: 250 unique plays from highly engaged, age-checked 16+ players in 60 days (Roblox docs). Roblox said at RDC 2026 it drops to **100 this November** (DevForum, RDC26 recap). Plan a 16+ trial first.
> - **Personal notifications reach only opted-in players 13+**, one per player per day, and the opt-in prompt can show at most once per 30 days. For under-13 kids, your only out-of-game channels are update announcements and Experience Events. (Roblox docs)
> - **Developer push notifications are not shipped yet**: announced at RDC 2026 for "late 2026", framed for turn-based and async games. Do not build around them yet. (DevForum, RDC26 recap)
> - **Rewards pay on arrival, never on "invited".** `GameInvitePromptClosed` no longer tells you who was invited. Key referral rewards on `ReferredByPlayerId` in join data. (Roblox docs, SocialService)
> - **Creator Rewards pays you for engagement and new users**: 5 Robux per day per Active Spender who plays you 10+ minutes as one of their first three games, and 35% of a new or returning user's first $100 for 60 days. Share Links count only if the game averages 100+ DAU. (Roblox docs, Creator Rewards)
> - **Kid-safe always** (repo `CLAUDE.md`): odds before any paid random item, no fake timers or stock, at most 1 flash per second, grants on the server only.

## Current state (Oct 2026): what's new, renamed or deprecated

| Change | Status | What it means for us | Source |
|---|---|---|---|
| Recommended For You uses only organic RFY users, per-user signals; playtime capped at 60 min/user/day | Live | Many short sessions and return days beat marathons | Roblox docs, discovery |
| Custom thumbnail required for Home impressions | Live | Upload real gameplay art before launch day | Roblox docs, discovery |
| Semantic search in all supported languages ("food games") | Live | Describe the game in plain words a kid would type; no keyword stuffing | Roblox docs, discovery |
| Roblox Kids (5-8) and Select (9-15) live worldwide since June 16, 2026 | Live | A new game starts as 16+ only | DevForum (June 16, 2026) |
| Highly Engaged Player (HEP) entry bar: 500 → 250 (Aug 19, 2026) → 100 (November 2026, announced) | 250 live, 100 coming | Kids games can reach under-16s much sooner | DevForum (Aug 19, 2026); DevForum RDC26 recap |
| Keep-eligibility bar: 25 HEP (from July 16, 2026) | Live | Once in, a small steady audience keeps you in | DevForum (July 16, 2026 update) |
| Expedited review fee: 100,000 → 50,000 Robux per game, refundable, review up to 48 h | Live (docs) | Skips the HEP bar; only worth it for a proven game | Roblox docs; DevForum (June 16, 2026) |
| Single-question age questionnaire to reach 16+ in most regions | Announced RDC 2026 | Faster first publish; the full questionnaire is still needed for restricted content and to target kids honestly | DevForum RDC26 recap |
| Early testing with up to 10 age-checked friends before publishing | Late 2026 | Free pre-launch playtest | DevForum RDC26 recap |
| Developer push notifications for opted-in players ("alert when it's their turn") | Late 2026 (Studio beta reported for October by third parties) | Async features (hatch timers, turns) may get a real push channel; wait for docs | DevForum RDC26 recap |
| Play on the web in Chrome from the Details Page URL, no install | Late 2026 | Every link in a video description becomes one-tap play. First 60 s must work with mouse and keyboard | DevForum RDC26 recap |
| Pre-roll video ads while a game loads; revenue shared; Plus subscribers skip them | Coming soon | Keep loading short; no code needed | DevForum RDC26 recap |
| Ads Manager objective "Engagement" targets HEP toward Kids/Select; "Earnings" limited | Live (beta) | Use Engagement only to cross the HEP bar | Roblox docs, Ads Manager |
| Social media links on profiles and game pages raised to 16+ (June 30, 2026) | Live | Do not rely on game-page social links to reach kids | DevForum (June 16, 2026 post) |
| Creator Affiliate program and Engagement-Based Payouts replaced by Creator Rewards (July 24, 2025) | Done | Ignore any guide that promises "up to 50% affiliate share" | Roblox docs |
| Deprecated: `BadgeService:AwardBadge`, `UserHasBadge`, `IsDisabled`, `IsLegal` | Deprecated | Use `AwardBadgeAsync`, `UserHasBadgeAsync`, `GetBadgeInfoAsync().IsEnabled` | Roblox docs, BadgeService |
| Deprecated: `SocialService:PromptLinkSharing` | Deprecated | Use `PromptLinkSharingAsync` (server only) | Roblox docs, SocialService |
| `GameInvitePromptClosed` `recipientIds` is always empty | Changed | You cannot reward "invites sent" | Roblox docs, SocialService |

## The recipes (how we build X)

### 1. The core loop of a kid simulator (design)
Rule of thumb, from [[Genre Playbook - Simulators]], [[Core Loops and Session Design]] and our blueprints:
1. One verb the kid already knows (tap, run, launch, hatch). The +1 games use "time passes, number grows".
2. One number that grows on screen every second.
3. One thing to spend it on that makes the number grow faster (upgrade, pet, cannon).
4. A visible next goal ("Biome 2: 250 Speed", see [[Blueprint - Egg Run]]).
5. A reset with a permanent multiplier (rebirth) once the curve flattens. Geometric multiplier slightly below the cost growth ([[Progression and Pacing Design]]).
6. Close the loop three or more times in the first 5 minutes ([[First-Time User Experience and Onboarding]]).

### 2. The first 60 seconds (the most important ranking signal we control)
Targets (Vault note: [[First-Time User Experience and Onboarding]]): control within about 10 s of join, first verb by 30 s, first big reward by 40 s. Discovery measures bounce under 60 s and at 61-180 s (Roblox docs).
- Spawn facing the action. No text wall, no menu, no cutscene.
- One arrow, one line of text, one target. Teach other systems later, just in time.
- The first egg or upgrade costs what a kid earns in about 20 seconds (Rule of thumb).
- Delay every pop-up (shop, daily reward, notification opt-in) until after the first reward.
- Test it on a phone at low graphics, and with mouse and keyboard for Chrome play.

Measure it with an onboarding funnel (server, `--!strict`):
```lua
--!strict
-- ServerScriptService/Onboarding.server.luau
local AnalyticsService = game:GetService("AnalyticsService")
local Players = game:GetService("Players")

local STEPS = { "Joined", "FirstTap", "FirstUpgrade", "FirstEgg", "FirstRebirthSeen" }
local reached: { [Player]: number } = {}

local function logStep(player: Player, step: number)
	if (reached[player] or 0) >= step then return end
	reached[player] = step
	AnalyticsService:LogOnboardingFunnelStepEvent(player, step, STEPS[step])
end

Players.PlayerAdded:Connect(function(p) logStep(p, 1) end)
Players.PlayerRemoving:Connect(function(p) reached[p] = nil end)
-- Call logStep(player, 2..5) from the game server when each first happens.
-- Only log for players on their first session (check your saved data).
```
Rules (Vault note: [[Teaching Through Level Design]] citing Roblox docs): steps start at 1, go up to 100, and skipped steps count as completed. Read results in Creator Analytics, Funnels.

### 3. Progression pacing and rarity ladders
- Pace on the **median and p90 wait**, not the mean. The next unreached tier should take one to two sessions at each stage (Vault note: [[Rarity Ladders and Drop Pacing Math]]).
- Ladder ratios small at the bottom, larger at the top. Add pity or fragments for the tail.
- Plot time-per-step T(n) for the whole ladder. It should rise slowly and drop at milestones (a sawtooth) ([[Progression and Pacing Design]]).
- New players: commons only for the first few minutes so early luck does not skip the ladder (Vault note: [[Progression and Pacing Design]], reference project).
- If Robux touches a random roll (egg, spin, luck boost): numeric odds summing to 100% before purchase, live odds during boosts, every outcome has value, `PolicyService` check that fails closed. See [[Paid Random Items and Odds Disclosure in Practice]].

### 4. Social and co-play (an "Important" ranking signal)
"Intentional co-play days" count joins, invites and private servers (Roblox docs). So:
- A visible "Play with friends" bonus (for example +10% per friend in the server, Rule of thumb).
- Rare hatches announced to the whole server ([[Social Design and Multiplayer Play]]).
- Design for a server of 3, not 30.
- An invite button after a proud moment, behind the pop-up gate.

Invite prompt (client):
```lua
--!strict
local SocialService = game:GetService("SocialService")
local Players = game:GetService("Players")
local player = Players.LocalPlayer

local function tryInvite()
	local ok, canSend = pcall(function()
		return SocialService:CanSendGameInviteAsync(player)
	end)
	if not (ok and canSend) then return end
	local options = Instance.new("ExperienceInviteOptions")
	options.PromptMessage = "Hatch eggs together!" -- short, or it is hidden
	options.LaunchData = "invite"                  -- up to 200 characters
	SocialService:PromptGameInvite(player, options)
end
```
Reward on arrival (server). `ReferredByPlayerId` is in `Player:GetJoinData()` for all invite types, and join data can arrive a few seconds late (Vault note: [[Friend Invites Referrals and Experience Invites]]). Treat `LaunchData` as untrusted input. Credit each invitee once, keyed by the invitee's user id, and only after they qualify (for example 10 minutes played, Rule of thumb). Code: the referral service in that note.

Share link for off-platform friends (server only):
```lua
--!strict
local SocialService = game:GetService("SocialService")
local function offerShare(player: Player, zone: string)
	local ok, err = pcall(function()
		SocialService:PromptLinkSharingAsync(player, {
			ExpirationSeconds = 86400, -- the default
			LaunchData = "zone:" .. zone,
		})
	end)
	if not ok then warn("[Share]", err) end
end
```

### 5. Daily return: daily reward, streaks, offline earnings
- Day boundary = server-side integer day from UTC (`os.time() // 86400`), not "24 hours since last claim" (Vault note: [[Daily Rewards System End to End]]).
- Our reference `cannon-evolution/src/server/GameServer.server.lua` uses a cooldown since last claim (`claimDaily`) and offline earnings capped by `OFFLINE_MAX_HOURS`. For a new game, prefer the day-index version from that note.
- Decide the missed-day policy in writing. Kid-friendly default: a missed day pauses the streak instead of wiping it (Rule of thumb; no guilt mechanics, see [[Ethical Design and Player Trust]]).
- Mark the day claimed only after the grant succeeds.
- Discovery counts play days in three windows: D1, D2-7, D8-28 (Roblox docs). Plan hooks for each: offline earnings and a 7-day calendar (D1-7), weekly quests and the weekly update (D8-28).

### 6. Experience notifications (13+ only)
Facts (Roblox docs, Experience notifications guide and ExperienceNotificationService reference):
- Game needs 100+ visits, not under moderation.
- Strings are made in Creator Dashboard, Engagement, Notifications. 99 characters, parameters in `{braces}`, launch data up to 200 bytes, type `"MOMENT"` only.
- One notification per user per day per experience, plus a cross-experience daily cap. Delivery is not guaranteed; reach depends on engagement. A high Turn Off rate shrinks your future reach.
- Send from game servers with the Creator Store Open Cloud package (`createUserNotification`) or from outside with Open Cloud (`POST /cloud/v2/users/{userId}/notifications`). Details and payload shapes: [[Experience Notifications and Return Prompts]].

Opt-in prompt, only after a delayed payoff (egg starts hatching, crop planted), never at join:
```lua
--!strict
-- LocalScript (client). The prompt text is fixed by Roblox.
local ExperienceNotificationService = game:GetService("ExperienceNotificationService")

local function askAfterDelayedPayoff()
	local ok, canPrompt = pcall(function()
		return ExperienceNotificationService:CanPromptOptInAsync()
	end)
	if ok and canPrompt then
		-- Show our own one-line context first: "Want a ping when your egg hatches?"
		ExperienceNotificationService:PromptOptIn()
	end
end
ExperienceNotificationService.OptInPromptClosed:Connect(function()
	-- log an analytics event if you want the opt-in rate
end)
```
It will not show if the player is under 13, already opted in, or saw it for your game in the last 30 days (Roblox docs).

### 7. Weekly update cadence, events and badges
- **Weekly update on a fixed day**, live by Friday so it catches Saturday's traffic peak (Saturday peak: Roblox docs; Friday launch: Rule of thumb).
- **Update announcement**: 60 characters, at most one every 3 days, reaches followers including under-13s (Roblox docs, Experience events). Name the content: "New world: Candy Land + 6 pets", not "bug fixes".
- **Experience Events**: up to 10 ongoing or upcoming at once; players tap Notify Me; joiners carry `GameJoinContext.EventId` in join data; Trending Events needs an event started in the last 7 days with 1,000+ RSVPs and public; off-platform featuring needs submission 7+ days ahead and a 7-30 day run is recommended (Roblox docs). In-game RSVP button: `SocialService:PromptRsvpToEventAsync(eventId)` (client, event in this experience, not yet started).
- **Badges** for real milestones (first rebirth, world 2, 7-day streak), awarded on the server:
```lua
--!strict
local BadgeService = game:GetService("BadgeService")
local function award(player: Player, badgeId: number)
	if badgeId == 0 then return end -- ID not set yet: owner fills it in
	local ok, err = pcall(function()
		BadgeService:AwardBadgeAsync(player.UserId, badgeId)
	end)
	if not ok then warn("[Badge]", err) end
end
```
Never invent badge IDs. Leave them 0 on the owner's checklist ([[Badges and Achievement Design]]).

### 8. Discovery: title, icon, thumbnails, search
- Title says the verb and the thing: "+1 Cannon Evolution", "Hatch a Brainrot". No "FREE ROBUX", no other game's name (money-led titles get less exposure: Roblox docs).
- Icon: square, at least 512 x 512, readable at about 150 px (Vault note: [[Thumbnail Specs, Rules and Upload - Sizes, Count and Policy]], citing Roblox docs).
- Thumbnails: 16:9, ideally 1920 x 1080, under 3 MB; 2 to 5 active for Home personalisation; must match the real game (same note; [[Thumbnail Composition for High CTR - Focal Point, Contrast and Readability]]).
- Description: first line a plain sentence a kid would search ("Hatch pets, launch cannons, get stronger"). Search is semantic (Roblox docs).
- Read the Home Recommendations and Acquisition pages in Creator Analytics weekly. Fix the weakest signal first: low play-through = thumbnail/title; high bounce = first 60 s; low D1 = no reason to return.

### 9. Moments, clips and share links
- Make one payoff moment per session clip-worthy: big number, rare hatch, server-wide announcement ([[Blueprint - Plus One Evolution]]).
- Moments (short gameplay videos) is live in the US; gameplay videos from game Details Pages appear in Moments (third-party RDC summary, not confirmed in docs). Upload good gameplay video to the Details Page.
- Optional photo button with `CaptureService:PromptShareCapture` ([[Photo Mode and In-Game Screenshots with CaptureService]]).
- Make one Creator Hub Share Link per channel (each YouTube video, each Discord) and compare them in Acquisition analytics (Vault note: [[Friend Invites Referrals and Experience Invites]]).

### 10. Ads Manager (Sponsored)
Facts (Roblox docs, Ads Manager): objectives Plays, Earnings (limited) and Engagement; auto-bidding from your budget; daily or lifetime budget; results as CPP (cost per play); up to 10 thumbnails per campaign; audiences All, New, Recent (needs 10,000+ recent players) and Lapsed (needs 20,000+); Robux to ad credit conversion is permanent; advertisers 13+ with verified email, card payments 18+. Ad players are not counted in Recommended For You ranking (Roblox docs, discovery).
- Use a small Plays test to check play-through and D1 of thumbnails. Judge after 2-3 days; plays can take up to 48 h to appear (Vault note: [[Sponsored Ads and Campaign Math]]).
- Use Engagement only to cross the Kids/Select HEP bar. It costs more per play by design (DevForum, June 16, 2026).

### 11. Reaching kids: maturity and Kids/Select eligibility
1. Fill in the maturity questionnaire for every published place, test places too. A game without it is unplayable (Vault note: [[Policy and Age Rules 2026]]).
2. Aim for **Minimal** or **Mild**: cartoon hits, light unrealistic marks, no realistic blood, no romance, no hangout with private spaces, no free-form drawing (Vault notes: [[Gore Policy and Kid-Friendly Hit Feedback]], [[Policy and Age Rules 2026]]).
3. Owner account: age-checked, verified (government ID if 18+), 2-Step Verification on.
4. Either Roblox Plus or Premium for 2 consecutive months, or the one-time refundable per-game fee (1,000 Robux per DevForum, June 16, 2026; the docs link the amount elsewhere). Refunded automatically 90 days after the game becomes eligible, or 90 days after payment if it never does (Roblox docs).
5. Launch to 16+, then gather highly engaged, age-checked players. Track progress live in Creator Hub, Audience Reach.
6. A HEP is a 16+ age-checked player with enough account tenure, playtime in your game, and a purchase anywhere on Roblox in the last 60 days. Spending in your game is not needed (Roblox docs).

## Numbers and limits

| Item | Value | Source |
|---|---|---|
| Playtime counted for ranking | max 60 min per user, per game, per day | Roblox docs, discovery (updated 2026-10-29) |
| First-play bounce windows | under 60 s; 61-180 s | Roblox docs, discovery |
| Play days windows | Day 1; Days 2-7; Days 8-28 | Roblox docs, discovery |
| Weekly traffic peak | Saturday | Roblox docs, discovery |
| Kids/Select entry bar | 250 unique plays from HEP in 60 days | Roblox docs, Kids and Select |
| Kids/Select entry bar (announced) | 100, from November 2026 | DevForum, RDC26 recap |
| Keep-eligibility bar | 25 HEP | DevForum (July 16, 2026 update) |
| Expedited review | 50,000 Robux per game, refundable, up to 48 h | Roblox docs; DevForum (June 16, 2026) for 48 h |
| Per-game publishing fee for all ages | 1,000 Robux, refundable | DevForum (June 16, 2026) |
| Fee refund timing | 90 days after eligibility, or 90 days after payment | Roblox docs, Kids and Select |
| Subscription alternative | Plus or Premium, 2 consecutive months | Roblox docs, Kids and Select |
| Notification eligibility | 100 visits since launch | Roblox docs, Experience notifications |
| Notifications per user | 1 per day per experience, plus aggregate cap | Roblox docs |
| Notification string | 99 characters; launch data 200 bytes | Roblox docs |
| Opt-in prompt | not shown if under 13, already opted in, or shown in last 30 days | Roblox docs |
| Notification analytics | shown after 100 aggregate impressions | Roblox docs |
| Update announcement | 60 characters, one per 3 days | Roblox docs, Experience events |
| Experience Events | up to 10 ongoing or upcoming | Roblox docs, Experience events |
| Trending Events | started in last 7 days, 1,000+ RSVPs, public | Roblox docs, Experience events |
| Off-platform featuring | submit 7+ days before start; 7-30 day run recommended | Roblox docs, Experience events |
| Event thumbnails | up to 5 per event | Vault note: [[Thumbnail Specs, Rules and Upload - Sizes, Count and Policy]] (citing discovery docs) |
| Share link default expiry | 86,400 s | Roblox docs, SocialService |
| Invite `LaunchData` | up to 200 characters | Vault note: [[Friend Invites Referrals and Experience Invites]] |
| `AwardBadgeAsync` rate limit | 50 + 35 per user per minute | Roblox docs, BadgeService |
| Onboarding funnel steps | 1 to 100 | Vault note: [[Teaching Through Level Design]] (citing docs) |
| Thumbnails | 16:9, ideally 1920 x 1080; 2-5 active for personalisation; under 3 MB | Vault note: [[Thumbnail Specs, Rules and Upload - Sizes, Count and Policy]] |
| Icon | 512 x 512 minimum, seen at about 150 px | same |
| Ads audiences | Recent needs 10,000+; Lapsed needs 20,000+ | Roblox docs, Ads Manager |
| Ads thumbnails | up to 10 per campaign, 16:9 | Roblox docs, Ads Manager |
| Creator Rewards, Daily Engagement | 5 Robux per Active Spender per day (10+ min, one of their first 3 games that day) | Roblox docs, Creator Rewards |
| Active Spender | $9.99+ spent on Roblox in last 60 days | Roblox docs, Creator Rewards |
| Creator Rewards, Audience Expansion | 35% of first $100 of a new or reactivated user's purchases, over 60 days; needs ID-verified creator | Roblox docs, Creator Rewards |
| Share Link or direct-join qualification | 10+ min that day; game averages 100+ DAU for 60 days | Roblox docs, Creator Rewards |
| Creator Rewards hold | 60 days as Earned Robux | Roblox docs, Creator Rewards |
| New games in top 1,000 by hours (Aug 2026) | 33% launched in prior 90 days | DevForum, RDC26 recap |
| Retention benchmarks to aim for | D1 12-15%, D7 2-3% | Vault note via [[02 Launch and Discovery Cheat Sheet]] (Rule of thumb) |

## Pitfalls
- **Rewarding "invite sent".** The invite prompt does not tell you who was invited. Reward only qualified arrivals.
- **Opt-in prompt at join.** It wastes the 30-day prompt and trains "No". Ask after a delayed payoff, with a context line first.
- **Planning retention on notifications for a 5-8 audience.** Under-13s never get personal notifications. Use offline earnings, daily calendar, update announcements and events.
- **Using `AwardBadge`, `UserHasBadge`, `PromptLinkSharing`.** Deprecated. Use the `Async` versions.
- **Copying a hit's name and thumbnail.** Non-unique games are deprioritised on Home and can get no ad delivery (Roblox docs).
- **"FREE ROBUX" or money in the title.** Less exposure, and it is a trust problem for kids.
- **Fake urgency in events.** Event countdowns must be real; no fake stock, no "only 3 left" (repo `CLAUDE.md`).
- **Judging ads on the first evening.** Plays and earnings can lag up to 48 h.
- **Believing a guide that says 500 HEP or a 100,000 Robux expedited fee.** Those were June-August 2026 numbers.
- **Treating the RDC "developer push notifications" as an existing API.** As of Oct 30, 2026 the docs still describe only notification-stream delivery for experience notifications.
- **Day boundary by "24 h since last claim".** Kids drift later every day and lose streaks. Use a UTC day index.
- **Trusting `LaunchData`.** Anyone can craft a link. The server decides what the data is allowed to do.
- **Social hangout or drawing features in a kids game.** They push the game to 16+.

## Checklist before shipping
- [ ] First reward under 40-60 s on a phone; onboarding funnel logged with `LogOnboardingFunnelStepEvent`.
- [ ] Loop closes 3+ times in 5 minutes; next goal always visible.
- [ ] Rarity ladder checked on median and p90 waits; odds panel on anything Robux touches.
- [ ] Co-play bonus visible; invite button after a proud moment; referral pays on qualified arrival, once per invitee.
- [ ] Daily reward on a UTC day index; offline earnings; missed-day policy written.
- [ ] Notification strings created (99 chars); opt-in only after a delayed payoff; one queued notification per user.
- [ ] Badges for first rebirth, new world, 7-day streak; IDs on the owner's checklist (0 until set).
- [ ] Custom thumbnail(s) that show the real game; icon readable at 150 px; plain-English title and first description line.
- [ ] Maturity questionnaire done; label Minimal or Mild; no hangout or drawing features.
- [ ] Owner: verified, 2SV on, Plus/Premium 2 months or per-game fee paid; Audience Reach tab watched.
- [ ] One Share Link per channel; Details Page has gameplay video.
- [ ] Weekly update day chosen; first event drafted (7+ days ahead if you want off-platform featuring).
- [ ] Mouse-and-keyboard pass for Chrome web play.

## Go deeper
- Loops and genre: [[Genre Playbook - Simulators]], [[Simulator and RNG Genre Teardown]], [[Core Loops and Session Design]], [[Viral Game Anatomy - Hooks, Loops and Timing]], [[Teardown - Steal An Egg]], [[Teardown - Tap Simulator REBORN]], [[Teardown - Plants vs Brainrots]]
- Onboarding: [[First-Time User Experience and Onboarding]], [[Onboarding by Genre - The First Five Minutes]], [[Measuring Onboarding - Funnels, Drop-off and A-B Tests]], [[Onboarding Funnel]]
- Pacing and rarity: [[Progression and Pacing Design]], [[Rarity Ladders and Drop Pacing Math]], [[Paid Random Items and Odds Disclosure in Practice]], [[Regional Compliance - Paid Random Items and Country Rules]]
- Social: [[Social Design and Multiplayer Play]], [[Friend Invites Referrals and Experience Invites]], [[Roblox Communities as Your On-Platform Hub]]
- Retention and live ops: [[Retention and Return Hooks]], [[Daily Rewards System End to End]], [[Login Streaks]], [[Live Ops Deep Dive Start Here]], [[Live Ops Events and Updates]], [[Event Calendars and Content Planning]], [[Limited-Time Offers - Design and Ethics]], [[Battle Pass and Season Design]], [[Patch Notes and Player Communication]], [[Update Cadence and Hype Cycles]]
- Notifications and badges: [[Experience Notifications and Return Prompts]], [[Badges and Achievement Design]]
- Discovery: [[Discovery and the Algorithm]], [[Discovery and Monetization Changes 2025-2026]], [[From CTR to CCU - Impressions, Play-Through and the Discovery Loop]], [[Experience Description and Search Keywords]]
- Thumbnails and icons: [[Thumbnails and CTR Start Here]], [[Thumbnail Composition for High CTR - Focal Point, Contrast and Readability]], [[Thumbnail Specs, Rules and Upload - Sizes, Count and Policy]], [[Thumbnail and Icon A-B Testing - Method, Sample Size and Reading Results]], [[Game Icon Design - Readable at Small Sizes]]
- Growth: [[Launch Strategy - The First Two Weeks]], [[Sponsored Ads and Campaign Math]], [[Short-Form Video Marketing]], [[Photo Mode and In-Game Screenshots with CaptureService]], [[Creator Rewards]], [[Rescuing a Weak Launch - Empty Servers, Low CCU and Relaunch Tactics]], [[A-B Testing and Experiments on Roblox]]
- Policy for kids: [[Policy and Age Rules 2026]], [[Publishing an Experience]], [[Roblox Policies Ratings and Compliance]], [[Marketing to Kids and Teens - Age Rules and Paid-Promo Disclosure]], [[Ethical Design and Player Trust]]
- Our playbooks: [[02 Launch and Discovery Cheat Sheet]], [[03 What's New on Roblox - RDC 2026 and October]], [[Blueprint - Egg Run]], [[Blueprint - Plus One Evolution]], [[16 Cartoony Kid-Appeal Checklist]]
- Code: `cannon-evolution/src/server/GameServer.server.lua` (daily, missions, offline earnings).

## Sources
All read 2026-10-30.
- https://create.roblox.com/docs/en-us/discovery.md (page updated 2026-10-29)
- https://create.roblox.com/docs/en-us/production/publishing/kids-and-select
- https://devforum.roblox.com/t/roblox-kids-and-select-global-launch-upcoming-updates-to-eligibility-ads-manager-and-expedited-review/4685717 (June 16, 2026, updates to July 16)
- https://devforum.roblox.com/t/highly-engaged-player-threshold-drops-to-250/4820164 (Aug 19, 2026)
- https://devforum.roblox.com/t/rdc26-what-we-announced/4865880
- https://gamertagmythras.com/blog/roblox/roblox-rdc-2026-announcements (third-party RDC summary; used only where labelled)
- https://create.roblox.com/docs/production/promotion/experience-notifications
- https://create.roblox.com/docs/reference/engine/classes/ExperienceNotificationService.md
- https://create.roblox.com/docs/production/promotion/experience-events.md
- https://create.roblox.com/docs/production/promotion/ads-manager.md
- https://create.roblox.com/docs/creator-rewards.md (page updated 2026-10-29)
- https://create.roblox.com/docs/creator-programs/creator-affiliate.md
- https://create.roblox.com/docs/reference/engine/classes/BadgeService.md
- https://create.roblox.com/docs/reference/engine/classes/SocialService.md
- Not re-read this session (web budget ran out): content maturity, analytics and thumbnails docs. Those facts come from the named vault notes, which cite the docs as of October 2026.

## Vault corrections
- [[Engine Limits, Quotas and Defaults - Cheat Sheet]] (Publishing fee row): "Refunded after 25 highly engaged players for 60 days". Correction: the docs say the fee is refunded automatically 90 days after the game becomes eligible, or 90 days after payment if it never does. 25 HEP is the keep-eligibility bar. Source: Roblox docs, Kids and Select.
- [[Publishing an Experience]] (fee table): same refund claim ("refundable if the game keeps 25 highly engaged players for 60 days"). Same correction and source.
- [[03 What's New on Roblox - RDC 2026 and October]]: lists developer push notifications with examples "your egg hatched", "your base was raided". Correction: Roblox's RDC26 recap frames it as "alert when it's their turn" for opted-in players (turn-based and async games), timed "late 2026". General use cases are not confirmed. Source: DevForum RDC26 recap.
- [[Open Questions - Whole Vault]] (Kids/Select row): the 50,000 vs 100,000 Robux and 250 vs 500 conflict is resolved by date. 100,000 and 500 were June 2026; 500 → 250 on Aug 19, 2026; docs now say 50,000; 100 announced for November 2026. Sources: DevForum (June 16 and Aug 19, 2026), Roblox docs.

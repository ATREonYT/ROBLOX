# Everything else hit Roblox games do well (non-VFX), with how-tos for kid-friendly simulators

Researched Oct 31, 2026. Scope: what is NEW or DEEPER than the vault already covers (core loops, economy pacing, staged tutorial HUD, level-ups, rebirths, kid-safe monetization rules, map basics).
Labels: **[cited]** = from a linked source; **[est]** = our estimate or common practice, not from a source. Kid-safe flags: **[NOT ALLOWED]** marks any tactic that uses fake timers, fake scarcity, hidden odds or pressure.

Research budget note: about 20 lookups were used. The strongest primary sources are the Roblox Creator Docs and staff DevForum posts. Several UI/sound "juice" items have no official doc and are listed as [est] practice under Inferences.

---

## 1. Sound and music: layering, pitch, ducking, SoundGroups, 3D vs 2D, sourcing

### Takeaway
Roblox's built-in mixing tool is the SoundGroup tree, with sidechain ducking through a CompressorSoundEffect. Roblox now calls SoundGroups "legacy" and points to the newer Audio objects. For a small team, a three-group mix (Music, SFX, UI) with ducking under big reward stingers is enough. Most "hit game" sound feel comes from pitch variation and rising pitch on combos, which is plain scripting (see Inferences).

### Cited Findings
- A `SoundGroup` is a legacy mixer that groups Sounds or other SoundGroups so you can set their volume and effects together. The docs say it is "discouraged in favor of the more robust functionality of audio objects." [cited] — [Sound groups (Creator Docs)](https://create.roblox.com/docs/en-us/sound/groups)
- How to use them [cited] — [Sound groups](https://create.roblox.com/docs/en-us/sound/groups):
  - put the groups under `SoundService`;
  - assign a sound by setting its `Sound.SoundGroup` property, not by parenting it;
  - nest groups to make a mix tree;
  - `Volume` multiplies its children (range 0–10). A Sound at 0.5 in a group at 0.5 plays at 0.25.
- Ducking setup [cited] — [Sound groups](https://create.roblox.com/docs/en-us/sound/groups):
  - insert a `CompressorSoundEffect` into the low-priority group (for example Music);
  - set its `SideChain` to the high-priority Sound or SoundGroup;
  - tune `Threshold` (-80 to 0 dB), `Attack` (0.001–1 s), `Release` (0.001–1 s) and `Ratio` (1–50);
  - "use small ducking amounts where possible."
- Mixing advice from the same doc [cited] — [Sound groups](https://create.roblox.com/docs/en-us/sound/groups):
  - name groups by purpose (SoundEffects, BackgroundMusic);
  - keep player-ability sounds separate from environment sounds;
  - group sounds that share an effect (for example cave reverb).

### Inferences
- **How-to: the starter mix [est].**
  - Under SoundService make `Master > Music, SFX, UI, Ambience`.
  - Put a CompressorSoundEffect on `Music` with SideChain = `SFX/Stingers` (rare hatch, level-up, rebirth).
  - Starting values (Threshold about -30 dB, Ratio 4–6, Attack 0.01 s, Release 0.4 s) are guesses to tune by ear.
  - Give players a settings toggle for Music and SFX: kids often play with music off.
- **Pitch variation [est].** Repeated sounds (clicks, coins, hits) should play `PlaybackSpeed = base * (0.92..1.08)`, random each time, so a sound heard 1,000 times doesn't grate. Use a pool of 3–5 cloned Sounds per effect so a new play doesn't cut off the last one.
- **Rising pitch on combos [est].**
  - Each hit within about 0.6 s of the last raises `PlaybackSpeed` by one semitone (multiply by about 1.0595).
  - Cap it at about +12 semitones, then hold or reset with a "combo end" chime.
  - Coin pickups in bursts use the same trick.
- **3D vs 2D [est].**
  - A Sound parented to a Part or Attachment is 3D: it drops off with distance via `RollOffMinDistance` / `RollOffMaxDistance`. Use 3D for world events like an egg cracking or a machine.
  - A Sound parented to SoundService, or played with `SoundService:PlayLocalSound`, is 2D. Use 2D for UI and your own rewards.
  - Rule of thumb: your own reward is 2D (always heard at full volume); other players' events are 3D (quieter, positional).
- **Music per area [est].**
  - Put a `Zone` volume per area, or check the player's position each 0.5 s.
  - Crossfade between area tracks by tweening Volume over about 1.5 s.
  - Keep one shared "reward" layer that never changes.
- **Sourcing safely [est].**
  - Make sounds in-house (the repo already has `tools/sfx/make_sfx.py`), or use Roblox's own licensed audio library (Creator Store audio, which includes licensed music for use in experiences).
  - Never upload copyrighted pop songs or "meme" audio clips: Roblox audio moderation and DMCA takedowns apply.
  - Do not reuse other games' audio IDs.

### Gaps
- I did not fetch the newer Audio API docs (AudioPlayer, AudioEmitter, AudioListener, wires). It is unconfirmed whether ducking now has a better path there.
- I found no developer postmortem quantifying sound's effect on retention.
- I did not verify the current terms and limits of the Creator Store licensed music catalog in this pass.

---

## 2. UI juice and readability: numbers, rarity colours, damage numbers, notification stacks, button feel, mobile thumb zones, safe areas, controller

### Takeaway
Roblox gives the plumbing: `ScreenGui.ScreenInsets` / `SafeAreaCompatibility` for notches and the top bar, and `GuiService` for gamepad selection. The "juice" itself (abbreviated numbers, rarity colour ladders, floating reward numbers, stacked toasts, squash-on-press buttons) is convention, not doc. I found no official numbers for it, so the how-tos below are practice [est].

### Cited Findings
- `ScreenGui.ScreenInsets` is an enum controlling which device insets the GUI respects. Its values are `None`, `DeviceSafeInsets`, `CoreUISafeInsets` (stays clear of Roblox's top bar) and `TopbarSafeInsets`. [cited] — [ScreenInsets enum (Creator Docs)](https://create.roblox.com/docs/reference/engine/enums/ScreenInsets.md); [ScreenGui API reference](https://robloxapi.github.io/ref/class/ScreenGui.html)
- Developers asked how `GuiService:GetGuiInset()` relates to ScreenInsets, and found the older inset function doesn't fully match the new enum behaviour. [cited, community] — [DevForum thread](https://devforum.roblox.com/t/guiservicegetguiinset-for-screeninsets/2803966)

### Inferences
- **Safe areas [est].** Set the HUD ScreenGui to `ScreenInsets = CoreUISafeInsets`. Put full-screen backgrounds (shop dim, loading screen) on a separate ScreenGui with `None` and `IgnoreGuiInset = true`, so they cover the whole screen while their buttons stay safe.
- **Number formatting [est].**
  - Use one shared `Format.abbrev(n)` everywhere: 1,234 → "1.23K", 1.5e6 → "1.5M", then B, T, Qa, Qi… Use 3 significant figures and drop trailing zeros.
  - Show the full number with commas in a tooltip or on the stats page.
  - Never mix styles on one screen.
- **Rarity colours [est].** Use the genre's common ladder, which kids already read without labels:
  - Common grey, Uncommon green, Rare blue, Epic purple, Legendary orange/gold, Mythic red/pink;
  - "Secret" or "Exclusive" use rainbow or black.
  - Always pair the colour with the word, for colour-blind players.
- **Reward / damage numbers [est].**
  - Use a BillboardGui at the hit point (or a ScreenGui label at the cursor for clicks).
  - Motion: pop scale 0.6 → 1.15 → 1.0 in about 0.12 s, rise 2–3 studs, fade over 0.6 s.
  - Merge numbers that land within 0.15 s into one growing number, so the screen doesn't flood.
  - Size by value tier, not raw value.
- **Notification stack [est].**
  - Keep one queue module that shows at most 3 toasts.
  - New toasts push older ones up. Each lives about 3 s; important ones (rare pet) live longer and get the stinger sound.
  - Merge duplicates ("+5 Coins ×3").
  - This fits the repo rule of "one message line".
- **Button feel [est].**
  - On `MouseButton1Down`, tween a UIScale to 0.92 in 0.05 s; on release, go to 1.05 then 1.0 (about 0.15 s, Back easing).
  - Add a click sound with pitch variation, and a hover lift on PC only.
  - Disable the button for 0.25 s after each press so double-taps don't fire twice.
- **Mobile thumb zones [est].**
  - Main action button at the bottom right, minimum about 64 px touch target, kept out of the jump button's spot.
  - Menus at the left or top-left.
  - Nothing important in the top centre: Roblox's top bar and chat live there.
  - Test at phone size (about 390×844 pt) in Studio's device emulator.
- **Controller [est].**
  - Mark every menu button `Selectable = true` and set `NextSelectionUp/Down/Left/Right` where the automatic order is wrong.
  - Call `GuiService.SelectedObject = firstButton` when a menu opens.
  - Bind open/close to ButtonB and shoulder buttons with `ContextActionService`.
  - Show button prompts (A/B/X icons) only when `UserInputService.GamepadEnabled` is true or when the last input type was a gamepad.

### Gaps
- I found no official Roblox guidance or measured data on number abbreviation, rarity colours, damage numbers or touch-target sizes.
- I did not fetch Roblox's gamepad/UI-navigation docs in this pass, so the controller notes are practice, not cited.

---

## 3. Social and retention: server luck, group rewards, friend boosts, trading safety, leaderboards, daily/streak/playtime rewards, codes, favorite prompts, update cadence and live events

### Takeaway
The biggest hit of 2025, Grow a Garden, credits weekly updates and a persistent world that grows while you're away. It reached a 22.3M peak CCU. Since June 2026, Roblox's own discovery rewards 28-day retention and co-play. That makes the social and return features (invite prompts with launch data, friend co-play, honest daily rewards, scheduled live events) worth more than before. Trading must follow PolicyService rules. MemoryStore sorted maps are the official tool for live global leaderboards.

### Cited Findings
- **Grow a Garden (Jandel, interview) [cited]** — [GamesBeat interview](https://gamesbeat.com/?p=305182):
  - "We started weekly updates." His company is "known for doing weekly updates in games across Roblox."
  - The persistent world is the hook: "You return and your plants have grown bigger, or you've grown new fruit."
  - Numbers: about 100,000 CCU "within two weeks"; peak concurrent "22.3 million"; about "60 million" peak DAU; about "30 billion" total plays.
- Grow a Garden's "Admin Abuse" is a weekly scheduled live event, run by the developer around the update time, with boosted weather and mutations. Press covers its schedule and time changes. [cited, press/fan sites] — [Gamepressure: what is Admin Abuse](https://www.gamepressure.com/newsroom/what-is-admin-abuse-in-grow-a-garden-gag-we-explain-what-to-expec/z58490); [Gamepressure: update time changed](https://www.gamepressure.com/newsroom/this-weeks-grow-a-garden-gag-update-time-is-changed-farmers-marke/z08a4c)
- **Invite prompts [cited]** — [Invite prompts (Creator Docs)](https://create.roblox.com/docs/production/promotion/invite-prompts):
  - Call `SocialService:CanSendGameInviteAsync()` inside pcall, then `SocialService:PromptGameInvite(player, options)`.
  - `ExperienceInviteOptions` fields: `PromptMessage`, `InviteUser` (one friend's UserId), `InviteMessageId` (a Notification asset from Creator Dashboard > Engagement > Notifications; its text must contain `{experienceName}`), and `LaunchData` (max 200 characters).
  - The server reads `Player:GetJoinData().LaunchData`. It can take a few seconds to arrive, so retry.
  - The docs mention a "Friend Invite Reward System" for rewarding inviters and invitees.
- **MemoryStore quotas [cited]** — [Memory stores (Creator Docs)](https://create.roblox.com/docs/en-us/cloud-services/memory-stores.md):
  - Memory: "64 KB + 1.2 KB * [number of users]" per game.
  - Requests: "1000 + 120 * [number of concurrent users]" units per minute; 100,000 per data structure; about 30,000 per partition.
  - A sorted map lives on one partition. Global leaderboards are a listed use case.
  - Expiration is 0–3,888,000 s (45 days), and 45 days is also the default.
- **Paid random items and trading [cited]** — [Paid random items (Creator Docs)](https://create.roblox.com/docs/en-us/production/monetization/paid-random-items.md):
  - Odds disclosure:
    - show every outcome with its odds as percentages totalling 100% before purchase;
    - a pop-up list must be labelled "Info" or "Details", because an (i) icon alone is "not sufficient";
    - luck boosts must state their effect in numbers, and the displayed odds must update while a boost is active;
    - the rules also cover keys or tokens bought with Robux.
  - Per-player policy check with `PolicyService:GetPolicyInfoForPlayerAsync`:
    - if `ArePaidRandomItemsRestricted`, offer a free path, fixed order, direct purchase, or hide or block the item;
    - if `IsPaidItemTradingAllowed` is false, that player must not trade paid random outcomes or other paid items.

### Inferences
- **Server luck boost [est].**
  - Hits sell a server-wide "x2 Luck for 15 min" developer product that helps everyone in the server. It works socially because the buyer is thanked in chat.
  - Kid-safe version:
    - show the real remaining time, counted down from a server timestamp;
    - show the numeric luck effect, and update displayed odds while it is active (required by the policy above);
    - never show a fake "ending soon!" countdown;
    - if a boost is triggered by a free event, say so.
  - **[NOT ALLOWED]** any timer that resets, invents urgency or lies about time left.
- **Group join reward [est].**
  - Check `player:IsInGroupAsync(GROUP_ID)` on the server (cache it, recheck on a "Verify" button) and give a small permanent perk (for example +10% coins).
  - Must be a one-time, small, non-Robux reward.
  - `GROUP_ID` stays 0 until the owner supplies it (repo rule: never invent IDs).
- **Friends multiplier [est].**
  - Give +X% per friend in the same server (`player:IsFriendsWith(other.UserId)`, cached at join), capped at about 4 friends.
  - This feeds Roblox's "intentional co-play days" signal (see §4).
  - Pair it with the invite prompt, using LaunchData to spawn the friend next to the inviter.
- **Rewarding invites [est].** Reward only when the invitee actually joins (verified by LaunchData's sender id plus a server check), with a daily cap. Never reward bare prompt-opening, which encourages spam.
- **Trading safety [est].**
  - Do the whole trade on the server.
  - Two-step confirm with a 3-second "accept" delay after any change, and show both sides' item values and rarity.
  - Lock items during the trade and log every trade (ID, both users, items) to a DataStore so support can roll back.
  - Block trading paid items for players whose policy says `IsPaidItemTradingAllowed = false`.
  - Give new accounts a playtime gate (for example 30 min) before trading, against scam alts.
  - No trading of items bought minutes ago, to limit chargeback abuse.
- **Global leaderboard [est, built on cited quotas].**
  - Live board: MemoryStore SortedMap (fast, about 45-day expiry, good for weekly or event boards). Use `GetRangeAsync(Descending, 50)` every 60 s per server, not per player.
  - All-time board: OrderedDataStore, written at most every few minutes per player, and on leave.
  - Show "Your rank" separately.
  - Shard keys if the game gets big, since one sorted map sits on one partition (about 30k units/min).
- **Daily rewards and streaks without dark patterns [est].**
  - A 7-day calendar that shows all rewards up front.
  - A missed day pauses the streak instead of wiping it, or allows a free "catch-up" once a week.
  - Unlock times are tied to the real UTC day, and the time until the next reward is shown honestly.
  - **[NOT ALLOWED]**: selling streak repairs, "you'll lose everything!" pop-ups, fake countdowns.
- **Playtime rewards [est].**
  - Gifts at 5, 10, 15, 25, 40, 60 minutes of the session, with real timers counted from server time.
  - Roblox caps playtime credit at 60 min per user per day in discovery (§4), so there is no ranking reason to push past an hour. That is also kinder to kids.
- **Codes [est].**
  - Server-side code table with an expiry date and one claim per player (saved in the profile).
  - Codes are posted in the game description, group and social media.
  - Rewards are small free items (boosts, coins), never Robux items.
- **Like / favorite prompts [est].**
  - `AvatarEditorService:PromptSetFavorite(placeId, Enum.AvatarItemType... )` is the in-game favorite prompt. I did not verify its exact current signature.
  - Show it once, after a happy moment such as the first rare hatch, never at join and never with a reward attached. Roblox discovery guidance says to build trust "without promotional monetary rewards" (§4).
  - **[NOT ALLOWED]** "Like for a reward" and gated content behind likes.
- **Update cadence and live events [est, Grow a Garden is cited].**
  - Weekly small updates at a fixed, published time (for example Saturday 10 am ET), plus a scheduled live event right after the update (an "admin event" with boosted weather or luck for 30–60 min).
  - Show the next event time honestly in the lobby.
  - Limited-time events are fine if the end date is real and fixed, and if event items either come back later or are clearly seasonal cosmetics.
  - **[NOT ALLOWED]** fake "only 3 left!" stock, rotating shops that lie about restocks, and pressure language.

### Gaps
- No primary-source numbers on how much group rewards, friend multipliers or daily streaks lift D1/D7 for simulators.
- I did not fetch the "Friend Invite Reward System" doc page, so its exact rules on rewarding invites are unconfirmed.
- No developer postmortems from Steal a Brainrot, Pet Simulator 99, Blox Fruits or Adopt Me were found in this pass.
- I didn't verify the current `PromptSetFavorite` signature.

---

## 4. Discovery and growth: algorithm signals (2025–2026), thumbnails/icons, maturity labels, ads and sponsored experiences

### Takeaway
On June 15, 2026, Roblox moved Recommended For You from a 7-day to a 28-day retention view. It split "qualified play-through" into separate signals for play-through, session quality and spend. The top signals are now:
- play-through rate;
- first-play bounce (under 60 s and 61–180 s);
- play days per user (D1, D2–7, D8–28);
- playtime per user, capped at 60 min/day.

Co-play and spend matter next. A custom thumbnail is required to get Home impressions. Since Sep 30, 2025, a game must have a maturity label to be playable at all. Rewarded video ads are shown only to players 13 and older.

### Cited Findings
- **The June 2026 discovery update [cited]** — [Roblox Newsroom, June 2026](https://about.roblox.com/newsroom/2026/06/optimizing-discovery-great-games-reach-millions-players-roblox):
  - Recommended For You moved from a 7-day view to a 28-day view, with signals for Day 1, Days 2–7 and Days 8–28.
  - The former qualified play-through rate is now split into play-through behaviour, session quality and spend.
  - Reason: overweighting short-term engagement let games with eye-catching thumbnails displace games with lasting value.
  - Stated value signals: players returning over time, bringing friends (co-play) and spending.
  - Roblox cites 132M DAU (Q1 2026).
  - The exact weights are in a linked DevForum post, which I did not fetch.
- **Discovery doc [cited]** — [Discovery (Creator Docs)](https://create.roblox.com/docs/discovery.md):
  - Surfaces: Recommended for You, Continue Playing, Friends, Sponsored, Curated sorts, Standout Games, Live Events, Game Details "similar games", Search (including semantic search), Discover charts, and Notifications.
  - Most important signals:
    - play-through rate ("The rate at which users play your game after seeing it in the Recommended for You sort");
    - first-play bounce rate, a negative signal measured at under 60 s and 61–180 s;
    - play days per user (D1, D2–7, D8–28);
    - playtime per user, capped at "a maximum of 60 minutes per user, per game, per day".
  - Important signals: intentional co-play days, qualified play sessions, spend days and Robux per user. All signals are averaged per user.
  - "A custom thumbnail is required for your game to receive impressions from homepage recommendations."
  - Thumbnails should "accurately reflect your game."
  - Build trust without "promotional monetary rewards."
- Earlier context: in late 2024 Roblox staff were testing changes to the Recommended For You algorithms. [cited] — [DevForum: Testing Improvements to RFY](https://devforum.roblox.com/t/testing-improvements-to-the-%E2%80%9Crecommended-for-you%E2%80%9D-algorithms/3275201)
- **Maturity labels [cited]** — [DevForum: Unrated Experiences](https://devforum.roblox.com/t/important-updates-unrated-experiences-and-changes-to-experience-pages/3899317); [Content maturity (Creator Docs)](https://create.roblox.com/docs/production/promotion/content-maturity):
  - The Maturity & Compliance questionnaire was due by **September 30, 2025**. After that, unrated experiences became unplayable for the public and left top charts.
  - Creators can still test them, and a label makes the game playable immediately.
  - The questionnaire is at Creator Dashboard > Audience > Maturity & Compliance.
  - Experience pages now show a default minimum age beside the label.
  - Inaccurate answers can get the label removed.
- **Rewarded video ads [cited]** — [DevForum: More Creators Can Now Use Rewarded Video Ads](https://devforum.roblox.com/t/more-creators-can-now-use-rewarded-video-ads/3838678):
  - Eligibility started at 100K+ average DAU over 28 days, with plans to expand.
  - API: `AdService:GetAdAvailabilityNowAsync(Enum.AdFormat.RewardedVideo)`, `CreateAdRewardFromDevProductId`, `ShowRewardedVideoAdAsync`.
  - "Only users aged 13 and older will be eligible to see Rewarded Video ads."
  - Ads run 6–30 s. Rewarded video may be "up to 3%" of earnings early on.
  - Implementations are reviewed, and violations can revoke payouts.
- **Ads Manager:** Sponsored Experiences moved into Ads Manager [cited — [DevForum](https://devforum.roblox.com/t/sponsored-experiences-moving-to-ads-manager/2661756/171)]. Roblox posted an RDC 2025 ads recap for creators [cited — [DevForum: Ads for Creators RDC Recap](https://devforum.roblox.com/t/ads-for-creators-rdc-recap-and-what%E2%80%99s-next/3929106)]. I did not fetch it.

### Inferences
- **What to design for, in order [est, from cited signals].**
  1. The first 60 seconds: the first reward within about 10 s and the first upgrade within about 60 s, to beat the bounce signal.
  2. A reason to come back tomorrow and in week 2–4: growth while away (Grow a Garden's hook), a weekly event and an honest daily calendar.
  3. Friends playing together: friend boost and invites.
  4. Fair spend: a small first purchase that is clearly worth it.
- Chasing sessions over 60 min/day earns no discovery credit.
- **Thumbnails [est].** Since misleading thumbnails were the stated reason for the change, show real gameplay with one bold focal object, readable at phone size. Use 3–5 thumbnails, and use Creator Hub's thumbnail tests if available.
- **Icon [est].** One character or object with a big silhouette and high contrast, no tiny text, and a recognisable colour kept across updates.
- **Ads [est].** For a new small game, Sponsored/Ads Manager spend is a test tool: run a small budget and compare play-through and D1 against organic traffic. Rewarded video isn't available until about 100K DAU, and reaches 13+ only, so it is irrelevant for a kid game at launch.

### Gaps
- I did not fetch the DevForum post with the exact June 2026 signal weights.
- I found no current Ads Manager cost-per-play numbers from a primary source; third-party blogs exist but were not verified.
- No official thumbnail A/B testing doc was checked in this pass.
- Icon guidance is not in the discovery doc.

---

## 5. Technical polish: fast join and loading, data saving (ProfileStore), anti-exploit, analytics

### Takeaway
Analytics funnels are server-only, cover up to 10 funnels, and are the main tool for finding where kids quit. ProfileStore (loleris, successor to ProfileService) is the community-standard save wrapper, with session locking and auto-save. Loading should be a quick ReplicatedFirst screen that preloads only the first-view assets, with content streaming on.

### Cited Findings
- **Funnels [cited]** — [Funnel events (Creator Docs)](https://create.roblox.com/docs/en-us/production/analytics/funnel-events.md):
  - `AnalyticsService:LogOnboardingFunnelStepEvent(player, step, "Name")` for one-time onboarding.
  - `AnalyticsService:LogFunnelStepEvent(player, "FunnelName", funnelSessionId, step, "Name")` for recurring funnels such as the shop.
  - These are server only, and only in published games.
  - Up to 10 funnels on the dashboard. Steps expire after 180 days.
  - Only the 10 most recent session IDs are tracked per user per funnel. Only the first repeat of a step counts.
  - Skipped steps are auto-completed, so validate step numbers from the client.
- AnalyticsService also has event types for economy and custom events. [cited] — [Event types (Creator Docs)](https://create.roblox.com/docs/en-us/production/analytics/event-types); [DevForum launch post: funnel and economy events](https://devforum.roblox.com/t/analytics-track-funnel-and-economy-events-to-grow-your-experience-faster/3060398?page=6)
- ProfileStore is "a Roblox DataStore wrapper that streamlines auto-saving, session locking". It is a single ModuleScript, the successor to ProfileService, with a wiki and tutorials. [cited] — [DevForum: ProfileStore](https://devforum.roblox.com/t/profilestore/3190543)
- Community threads cover ReplicatedFirst loading screens and `ContentProvider:PreloadAsync`. A common pitfall: PreloadAsync on everything makes loading slow, or seems to finish only after the game loads. [cited, community] — [DevForum: PreloadAsync loads after rest of game](https://devforum.roblox.com/t/contentproviderpreloadasync-loads-after-rest-of-game-loads/1666094); [DevForum: ReplicatedFirst or PreloadAsync?](https://devforum.roblox.com/t/should-i-make-my-loading-screen-with-replicatedfirst-or-contentproviderpreloadasync/3805310)

### Inferences
- **Loading [est].**
  - LocalScript in ReplicatedFirst: build a simple branded screen, call `ReplicatedFirst:RemoveDefaultLoadingScreen()`, then `PreloadAsync` only the HUD icons and first-area decals (about 20–50 assets).
  - Wait for `game:IsLoaded()`, fade out, and hard-cap it at about 8 s so a slow asset never traps a kid.
  - Show a "Skip" button after 3 s.
  - Turn on `Workspace.StreamingEnabled`, set the spawn area as `Persistent` (or use `RequestStreamAroundAsync`), and keep the lobby light.
- **Saving [est].**
  - ProfileStore with session lock, `:Reconcile()` for new fields, and auto-save. Grant purchases only after a save, per repo rule.
  - Mock mode in Studio, as the repo already does.
  - Keep one profile per player, under about 100 KB.
- **Anti-exploit basics [est].**
  - The server owns all numbers: currency, luck and rolls happen on the server.
  - Remotes send intent ("I clicked egg 3"), never results.
  - Rate-limit each remote per player (for example max 10/s), and check distance to whatever is being interacted with.
  - Sanity-check walk speed and teleports on the server.
  - Never trust client-sent analytics step numbers.
  - Log and kick, don't ban, on first offence, to avoid false positives on kids with lag.
- **Analytics plan for a simulator [est].**
  - Onboarding funnel: Joined → First click → First currency → First upgrade → First egg → First pet equipped → First rebirth.
  - Shop funnel: Opened → Viewed item → Prompted → Bought.
  - Economy events for every currency source and sink.
  - Custom events for "left during loading" and "closed tutorial".
  - Review the funnel against the discovery bounce windows (under 60 s, 61–180 s).

### Gaps
- I did not fetch ProfileStore's wiki, so details (auto-save interval, MessagingService session stealing, `AddUserId` for GDPR) are unconfirmed here.
- I did not fetch AnalyticsService `LogCustomEvent` limits or rate limits.
- I didn't check the official Roblox docs for StreamingEnabled or ContentProvider in this pass.
- No official anti-exploit guide was fetched; the anti-exploit notes are standard practice, not cited.

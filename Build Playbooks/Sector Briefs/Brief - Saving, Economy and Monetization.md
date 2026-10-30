---
tags: [sector-brief, datastore, profilestore, memorystore, economy, simulator, monetization, compliance, receipts, roblox-plus]
updated: 2026-10-30
---
# Brief - Saving, Economy and Monetization
Back to [[00 Build Router]] · All briefs: [[Sector Briefs Index]]

> TL;DR
> - Player saves go through **one** session-locked ProfileStore module. `.Mock` in Studio, `Cancel` on leave, `AddUserId`, `Reconcile`, kick on `OnSessionEnd`. Copy `huzz-valley/src/ServerScriptService/HuzzServer/DataService.lua`.
> - DataStore budgets are **per experience** and **shared with Open Cloud** since July 29, 2026: base 300 + CCU x 40 reads, 300 + CCU x 20 writes per minute. Storage cap is 500 MB + 1 MB per lifetime player. There is no "one write per key every 6 seconds" rule on the limits page.
> - Developer products: grant once per `PurchaseId`, store the PurchaseId **in the same profile** as the grant, and answer "granted" only after that save completes. `MarketplaceService:BindReceiptHandler` (new) is an allowed alternative to `ProcessReceipt`. Copy `huzz-valley/src/ServerScriptService/HuzzServer/ShopService.lua`.
> - Never hard-code Robux prices. Regional pricing is **on by default for all passes** (March 30, 2026) and Roblox Plus members get 10-20% off. Show prices with `GetProductInfoAsync` (`GetProductInfo` is deprecated).
> - Paid random items (eggs, spins, crates bought with Robux or Robux-bought currency): show every final outcome as a % before purchase, update odds live when boosts are active, and check `PolicyService:GetPolicyInfoForPlayerAsync().ArePaidRandomItemsRestricted`.
> - Premium is gone for new buyers. Use `PromptRobloxSubscriptionPurchase` and `Player.HasRobloxSubscription`. `PromptPremiumPurchase` and `Player.MembershipType` are deprecated. Premium Payouts became Creator Rewards (July 2025).
> - Economy: exponential cost `a * r^L` (r 1.07-1.25), and one shared math module used by the client label and the server charge. Numbers above 2^53 lose whole-number precision. Never save NaN or inf.

## Current state (Oct 2026): what's new, renamed or deprecated

**Saving**
- **July 29, 2026:** in-game and Open Cloud DataStore requests share one per-experience budget per request type. The base rose to 300. Storage baseline rose from 100 MB to 500 MB (+1 MB per lifetime player). Open Cloud scripts (migrations, support tools) now spend the same budget as live servers (DevForum, July 15, 2026).
- **Storage caps are enforced, but they do not block writes.** Overage is billed after a grace period (Vault note [[Data and Cloud Changes 2025-2026]]).
- Throttle errors now name the level: `StandardWriteExperienceThrottled` (experience budget) vs `StandardWriteGameServerThrottled` (this server), plus `DatastoreThrottled`, `KeyThrottled` and the old 301-306 queue codes (Roblox docs).
- `DataStoreService:SetRateLimitForRequestType(requestType, baseLimit, perPlayerLimit)` changes this server's defaults. The docs sample raises `StandardRead` to a base of 1000. `GetRequestBudgetForRequestType` reads the current budget (Roblox docs).
- ProfileStore (loleris) is the maintained successor to ProfileService. Do not start new games on ProfileService (DevForum ProfileStore thread; Vault note [[Session Locking and Profile Libraries]]).

**Monetization**
- **New: `MarketplaceService:BindReceiptHandler(transactionType: Enum.ReceiptType, handler, filter?) -> RBXScriptConnection`.** The handler returns `Enum.ReceiptDecision.Processed` or `.NotProcessedYet` (not `ProductPurchaseDecision`). A bound handler wins over `ProcessReceipt`. Receipts it does not claim fall through to `ProcessReceipt`. A duplicate filter or a second catch-all throws an error. `Enum.ReceiptType`: `DeveloperProduct`, `RobuxTransferSender`, `RobuxTransferReceiver` (Roblox docs).
- **Deprecated on `MarketplaceService`:** `GetProductInfo` (use `GetProductInfoAsync`), `PlayerOwnsAsset` and `PlayerOwnsBundle` (use the `Async` versions), and `PromptPremiumPurchase` (Roblox docs).
- **Cross-game developer product sales were disabled May 30, 2026.** Robux transfers (`PromptRobuxTransferAsync`) are the suggested route (Roblox docs, Developer products guide).
- **Roblox Plus** launched April 30, 2026 at $4.99 per month. Members get 10% off in-game items (20% from the third consecutive month). **Roblox pays for the discount**, so the creator's share is unchanged. Members get free paid private servers, and creators are paid up to 100 Robux per subscriber per server instead. The sign-up bonus is 250 Robux per month for 3 months for each subscriber who signs up through your `PromptRobloxSubscriptionPurchase`. Premium stopped new sales, and its 10% Robux bonus ended May 30, 2026 (DevForum, April 10, 2026).
- `Player.MembershipType` is deprecated. `Player.HasRobloxSubscription` (boolean) is the current check (Roblox docs).
- **Regional pricing** for passes is on by default from March 30, 2026 (you can opt out per pass). Developer products stay opt-in, because of gifting and trading arbitrage (DevForum, March 5, 2026).
- **DevEx:** $0.0038 per earned Robux since September 5, 2025 (Robux earned before then still pays $0.0035). $0.0054 for qualifying spend by age-checked US 18+ players. Minimum cash-out 30,000. Robux received by transfer cannot be DevEx'd (Roblox docs; DevForum Plus post).
- **Creator Rewards replaced Premium Payouts** (July 24, 2025). It has two parts: Daily Engagement (5 Robux per Active Spender who plays 10+ min) and Audience Expansion (35% of a new user's first $100) (Vault note [[Subscriptions and Premium Payouts]], citing docs).
- **AdService:** `ShowVideoAd` and `VideoAdClosed` are deprecated. Rewarded video uses `GetAdAvailabilityNowAsync`, `CreateAdRewardFromDevProductId` and `ShowRewardedVideoAdAsync`, and **the reward arrives as a receipt** with `ProductPurchaseChannel == Enum.ProductPurchaseChannel.AdReward` (Roblox docs).
- Legacy `apis.roblox.com/game-passes/v1` and `developer-products/v1|v2` web endpoints were retired (April 2026). Use the Open Cloud Game Passes and Developer Products APIs (Vault note [[Data and Cloud Changes 2025-2026]]).

## The recipes (how we build X)

### 1. Player save (ProfileStore, session-locked)
Copy the shape of `huzz-valley/src/ServerScriptService/HuzzServer/DataService.lua`. The vendored module is in `business-evolution/src/ServerScriptService/Packages/ProfileStore.luau`.
```lua
--!strict
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ProfileStore = require(script.Parent.Packages.ProfileStore)

local TEMPLATE = { Schema = 2, Coins = 0, Gems = 0, Rebirths = 0, Receipts = {} :: {string}, LastOnline = 0 }
local store = ProfileStore.New("PlayerData_v1", TEMPLATE)
if RunService:IsStudio() then store = store.Mock end -- Studio resets on Stop (our rule)

local profiles: { [Player]: any } = {}

local function onPlayerAdded(player: Player)
	local profile = store:StartSessionAsync("Player_" .. player.UserId, {
		Cancel = function() return player.Parent ~= Players end,
	})
	if not profile then player:Kick("Your save couldn't load. Please rejoin.") return end
	profile:AddUserId(player.UserId) -- GDPR erasure support
	profile:Reconcile()              -- fills new template fields; never overwrites
	-- migrate(profile.Data) here: step Schema up, never down
	profile.OnSessionEnd:Connect(function()
		profiles[player] = nil
		player:Kick("Your data was opened on another server. Please rejoin.")
	end)
	if player.Parent == Players then profiles[player] = profile else profile:EndSession() end
end
for _, p in Players:GetPlayers() do task.spawn(onPlayerAdded, p) end
Players.PlayerAdded:Connect(onPlayerAdded)
Players.PlayerRemoving:Connect(function(p) local pr = profiles[p]; if pr then pr:EndSession() end end)
```
- ProfileStore autosaves every 300 s by default (`AUTO_SAVE_PERIOD`) and handles `BindToClose` itself. A stolen session lock resolves after `SESSION_STEAL` = 40 s (vendored source constants).
- Change `profile.Data` only on the server. Mark changes with plain writes: no save per coin.
- **Migrations:** keep a `Schema` integer, run ordered steps that never yield, and refuse to load a save that has a newer schema than the code (Vault note [[Data Schema Design and Migrations]]).
- Cannot save: `Vector3`, `CFrame`, `Color3`, Instances, NaN/inf, mixed array/dictionary keys. Store plain numbers, strings and tables (Vault note [[Data Schema Design and Migrations]]).

### 2. Developer product receipt (the money path)
Copy the shape of `huzz-valley/src/ServerScriptService/HuzzServer/ShopService.lua` `processReceipt`:
1. `Players:GetPlayerByUserId(info.PlayerId)` is nil → `NotProcessedYet`.
2. Wait for the profile (with a timeout) → if nil or not active, `NotProcessedYet`.
3. Unknown `ProductId` → `NotProcessedYet` (never acknowledge something you can't grant).
4. If `info.PurchaseId` is not in `profile.Data.Receipts`: run a grant function that does not yield, then add the PurchaseId (keep the last ~100-200).
5. `profile:Save()` (it does not yield), then poll `profile.LastSavedData.Receipts` until the PurchaseId is there (timeout ~20 s).
6. Return `PurchaseGranted` only if it is saved. Otherwise return `NotProcessedYet` (it is redelivered later).

Exactly one `MarketplaceService.ProcessReceipt =` in the whole place (grep it). With `BindReceiptHandler`, use one catch-all in one script, or filtered handlers per product. Return `Enum.ReceiptDecision.Processed` only after the same save check:
```lua
--!strict
local conn = MarketplaceService:BindReceiptHandler(Enum.ReceiptType.DeveloperProduct, function(info)
	return if handleAndConfirmSaved(info) then Enum.ReceiptDecision.Processed else Enum.ReceiptDecision.NotProcessedYet
end) -- no filter = catch-all
```
Rewarded-ad rewards and real purchases both come through here. Branch on `info.ProductPurchaseChannel` only for analytics, not for whether to grant.

### 3. Game passes
- **Server:** on join, `pcall(MarketplaceService.UserOwnsGamePassAsync, MarketplaceService, player.UserId, passId)` once per pass. Cache it, and **retry on error instead of storing false**.
- **Server:** `MarketplaceService.PromptGamePassPurchaseFinished` (server-side connection) with `purchased == true` → re-check or set the cache and apply the perk. Never trust a client remote saying "I own it" (Vault note [[Game Passes]]).
- **Client price label:** `MarketplaceService:GetProductInfoAsync(passId, Enum.InfoType.GamePass)`, then read `PriceInRobux` and `IsForSale`. Use `Enum.InfoType.Product` for dev products. Wrap it in `pcall`. If it fails, show "..." and not a stale constant.

### 4. Paid random items (eggs, crates, spins)
1. One roll table in `ReplicatedStorage` is used by both the server roll and the odds UI. Flatten tiers to **final-outcome %** that sums to 100 (Roblox docs; Vault note [[Paid Random Items and Odds Disclosure in Practice]]).
2. Show odds before spending, with a worded "Odds" or "Info" button (an "(i)" icon alone is not enough). When a luck boost is active, show the **boosted** odds. Show the pity counter (our kid rule).
3. Server, on join: `pcall(PolicyService.GetPolicyInfoForPlayerAsync, PolicyService, player)`. If `ArePaidRandomItemsRestricted` is true (or the call failed: treat that as restricted), use one of the documented treatments: a free earnable path, a fixed disclosed order, direct purchase of a specific item, hide it, block the purchase with a message, or keep the player out of the area (Roblox docs).
4. If `IsPaidItemTradingAllowed` is false, block trading of paid or paid-random outcomes for that player (Roblox docs, paid random items page).
5. Free random rewards (earned without Robux or Robux-bought currency) do not need odds by policy. Our kid rule still shows them.

### 5. Rewarded video ad
Client: `AdService:GetAdAvailabilityNowAsync(Enum.AdFormat.RewardedVideo)` returns `IsAvailable` → show the button (one result is good for one ad). Button → RemoteEvent → server: `local reward = AdService:CreateAdRewardFromDevProductId(productId)`, then `AdService:ShowRewardedVideoAdAsync(player, reward)`. **Grant only in the receipt handler** (Roblox docs). The creator and game have eligibility rules (13+ creator, ID-verified, approved questionnaire, ~2,000 monthly visitors) (Vault note [[Ads and Rewarded Video]]; re-check before building).

### 6. Roblox Plus button
Client: `MarketplaceService:PromptRobloxSubscriptionPurchase(Players.LocalPlayer)`. Server: grant any thank-you perk only when `player:GetPropertyChangedSignal("HasRobloxSubscription")` shows true, never on the prompt-finished event (Vault note [[Subscriptions and Premium Payouts]]).

### 7. Simulator economy maths (one shared `EconomyMath` module in ReplicatedStorage)
- **Upgrade cost:** `cost(L) = a * r^L`. Use r 1.07-1.10 for tracks bought many times per session, 1.12-1.18 for a few per session, 1.2+ only near a cap (Vault note [[Pricing Curves and Upgrade Costs]]).
- **Payback** = cost / extra income per minute. Players stop buying when payback is longer than they expect to stay in the zone. Compute the natural stop level per zone (same note).
- **Bulk buy n levels from L0:** `a * r^L0 * (r^n - 1) / (r - 1)`. Max affordable n = `floor(log(1 + M*(r-1)/(a*r^L0)) / log(r))`, then check n and n+1 against M to fix float off-by-one (same note).
- **Rebirth:** cost `Base * Growth^rebirths`, coins reset, permanent multiplier. The vault's paced example uses Growth 1.25 (~3.2 h to a 25-rebirth prestige gate). Growth 1.5 walls at around rebirth 15 (~130 h). Add a second layer (prestige) to rescue the wall (Vault note [[Rebirth and Prestige System End to End]]).
- **Offline earnings:** store `LastOnline = os.time()` on the server at save. On join, pay `min(now - LastOnline, CAP) * rate * fraction`. Cap it, pay only a fraction of active income, start only after onboarding, and never trust client time (Vault note [[Offline Earnings]]; cap and fraction values are a rule-of-thumb design choice).
- **Price anything in coins relative to the multiplier**, or late players buy everything instantly (Vault note [[Economy Inflation Sinks and Faucets Math]]).
- **Big numbers:** Luau numbers are doubles, with exact integers up to 2^53 (~9.007e15) and a max of ~1.8e308. Past 1e15, `+1` vanishes. Past 1e308 a value becomes `inf`, and then NaN. Clamp, check finiteness before save, and use a mantissa-exponent number if a game really goes past 1e300 (Vault note [[Big Numbers Precision and Formatting]]; IEEE 754).
- **Format honestly:** round **down** in labels ("999.9K", not "1.00M" for 999,999), or a player taps Buy and gets refused (Vault note [[Rebirth and Prestige System End to End]]).

### 8. MemoryStore (cross-server, temporary)
Use it for live event boards, matchmaking queues, server lists and caches. **Never** use it for anything that must survive. Every write gets the shortest sensible expiration (max 3,888,000 s = 45 days). Remove processed items. Cache reads per server (Roblox docs; Vault note [[MemoryStore Service]]).

## Numbers and limits

| Item | Value | Source |
|---|---|---|
| DataStore read budget (per experience, per min) | 300 + CCU x 40 | Roblox docs, limits page (read 2026-10-30) |
| DataStore write budget | 300 + CCU x 20 | Roblox docs |
| DataStore list / remove | 300 + CCU x 2 / 300 + CCU x 40 | Roblox docs |
| `UpdateAsync` cost | 1 read + 1 write | Roblox docs |
| Per-server standard defaults | read 60 + n x 40, write 60 + n x 40, list 5 + n x 2 | Roblox docs |
| Per-server ordered write / remove | 30 + n x 5 | Roblox docs |
| Max value per key | 4,194,304 characters | Roblox docs |
| Per-key throughput | read 25 MB/min, write 4 MB/min | Roblox docs |
| Name / key / scope length | 50 characters | Roblox docs |
| Metadata total | 300 characters | Roblox docs |
| Request queue per type | 30 requests, then errors 301-306 | Roblox docs |
| Storage cap | 500 MB + 1 MB x lifetime users (latest versions, compressed) | Roblox docs; DevForum July 15, 2026 |
| MemoryStore memory | 64 KB + 1.2 KB x users (shrinks 8 days after users leave) | Roblox docs |
| MemoryStore requests | 1000 + 120 x CCU units per min | Roblox docs |
| MemoryStore item size / structure | 32 KB / 1,000,000 items, 100 MB | Roblox docs |
| MemoryStore max expiration | 3,888,000 (45 days; units implied seconds) | Roblox docs |
| ProfileStore autosave / steal | 300 s / 40 s | Vendored ProfileStore source |
| Dev product price | 1 to 1,000,000,000 Robux | Roblox docs, Developer products |
| Plus price / discount | $4.99/mo; 10%, 20% from 3rd month, funded by Roblox | DevForum April 10, 2026 |
| Plus sign-up bonus | 250 Robux x 3 months (750 max) | DevForum April 10, 2026 |
| Plus private server payout | up to 100 Robux per subscriber per server, top 5 servers, 60+ min in 30 days | DevForum April 10, 2026 |
| DevEx standard / US 18+ | $0.0038 / $0.0054 per earned Robux | Roblox docs, DevEx page |
| DevEx minimum | 30,000 earned Robux, age 13+ | Roblox docs |
| Creator Rewards hold | 60 days | Vault note [[Subscriptions and Premium Payouts]] |
| Experience subscription prices | $2.99, $4.99, $7.99, $9.99, $14.99 tiers | Vault note [[Subscriptions and Premium Payouts]] |
| Rewarded video length | 6-30 s, click to play | Vault note [[Ads and Rewarded Video]] |
| Upgrade growth r | 1.07-1.25 | Vault note [[Pricing Curves and Upgrade Costs]] |
| Exact-integer limit | 2^53 ≈ 9.007e15 | Rule of thumb (IEEE 754) |

## Pitfalls (what AI models and beginners get wrong)
- Quoting "60 + players x 10" style formulas, the old 250 base, or the "6 seconds per key" rule. Use the table above.
- `GetAsync` then `SetAsync` on a player key, or two scripts writing player data. One module, session-locked.
- **Saving defaults over real data after a failed load.** If the load fails, kick or block saves; never write the template.
- Returning `PurchaseGranted` before the save is confirmed. The repo's own `cannon-evolution/src/server/GameServer.server.lua` does this (see Vault corrections).
- Two `ProcessReceipt` assignments, so one silently replaces the other. Or mixing `BindReceiptHandler` with `ProcessReceipt` without knowing that bound handlers win.
- Returning `Enum.ProductPurchaseDecision` from a `BindReceiptHandler` handler. It must return `Enum.ReceiptDecision`.
- Granting in `PromptProductPurchaseFinished`, or after `ShowRewardedVideoAdAsync` returns. The receipt is the grant.
- Hard-coded "R$ 99" labels. Regional prices and Plus discounts make them wrong.
- Using `GetProductInfo`, `PromptPremiumPurchase` or `MembershipType` in new code.
- Showing tier odds ("Rare 10%") instead of final-item odds, or a display table that drifts from the roll table.
- Storing "owns pass = false" when `UserOwnsGamePassAsync` errored. The player then loses a paid perk for the session.
- Open Cloud migration scripts run at peak time. They now drain the same budget as live servers.
- Long MemoryStore TTLs "just in case". The quota fills up and new writes fail.
- NaN from `0/0` passes every `coins < cost` check (comparisons with NaN are false) and corrupts the save.
- Rebirth or upgrade formulas typed twice (client label and server charge), so they drift.
- Fake timers or "only 3 left" stock on kid offers (banned by our rules).

## Checklist before shipping
- [ ] One data module. ProfileStore `.Mock` in Studio, `Cancel` on leave, `AddUserId`, `Reconcile`, kick on `OnSessionEnd`.
- [ ] `Schema` field and migration steps. A fixture save of every past schema loads cleanly ([[Save Migration Tests - Fixture Saves and Golden Files]]).
- [ ] No NaN/inf/Vector3/Instance in saved data. A finite check runs before every save.
- [ ] Exactly one receipt path (grep `ProcessReceipt` and `BindReceiptHandler`). Idempotent on `PurchaseId`, which is stored in the same profile. "Granted" only after the save is confirmed.
- [ ] Every product ID in config has a grant function. Unknown IDs return `NotProcessedYet`. IDs left as 0 are on the owner's checklist (never invented).
- [ ] Pass ownership is cached on the server from `UserOwnsGamePassAsync`. Errors retry instead of storing false.
- [ ] All prices shown come from `GetProductInfoAsync`.
- [ ] Every paid random item: final-outcome odds, live boosted odds, pity counter, `ArePaidRandomItemsRestricted` handled, trading gated by `IsPaidItemTradingAllowed`.
- [ ] No "coming soon" item ever opens a purchase prompt.
- [ ] Rewarded ads grant only through the receipt. Ads are enabled in the dashboard with a real dev product.
- [ ] Plus prompt uses `PromptRobloxSubscriptionPurchase`. No Premium prompts.
- [ ] Economy simulated for the first 2 hours: payback per upgrade, rebirth pacing, offline cap ([[Simulating an Economy Before Launch]]).
- [ ] Studio "Enable Studio Access to API Services" decided. Mock mode is on by default.

## Go deeper
- Saving: [[DataStore Fundamentals]] · [[Saving Correctly - Autosave and BindToClose]] · [[Session Locking and Profile Libraries]] · [[ProfileStore]] · [[Data Loss Prevention and Recovery]] · [[Debugging DataStore Problems]] · [[Player Privacy and Data Deletion]]
- Migration: [[Data Schema Design and Migrations]] · [[Schema Migrations - Worked Case Studies]] · [[Save Migration Tests - Fixture Saves and Golden Files]]
- Cross-server: [[MemoryStore Service]] · [[OrderedDataStores and Leaderboards]] · [[Trading Systems Without Duplication]]
- 2025-2026 deltas: [[Data and Cloud Changes 2025-2026]] · [[Discovery and Monetization Changes 2025-2026]] · [[Policy and Age Rules 2026]] · [[Engine Limits, Quotas and Defaults - Cheat Sheet]]
- Receipts and passes: [[Developer Products and ProcessReceipt]] · [[Purchase Data and Receipts]] · [[Game Passes]] · [[Shop with Game Passes and Developer Products End to End]] · [[Refunds Chargebacks and Purchase Support]]
- Pricing: [[Pricing and Store Design]] · [[Robux Price Points and Offer Design]] · [[Subscriptions and Premium Payouts]] · [[Subscriptions and Recurring Revenue]] · [[Ads and Rewarded Video]] · [[Creator Rewards]] · [[DevEx and Cashing Out]]
- Compliance: [[Paid Random Items and Odds Disclosure in Practice]] · [[Roblox Policies Ratings and Compliance]] · [[Regional Compliance - Paid Random Items and Country Rules]] · [[Drop Tables Rarity and Pity Systems]]
- Economy: [[Economy Design Start Here]] · [[Currency Architecture - Soft Hard and Event Currencies]] · [[Pricing Curves and Upgrade Costs]] · [[Rebirth and Prestige System End to End]] · [[Economy Inflation Sinks and Faucets Math]] · [[Offline Earnings]] · [[Big Numbers Precision and Formatting]] · [[Economy Exploits - Dupes Races and Purchase Abuse]] · [[Retention and Return Hooks]]
- AI mistakes: [[AI Pitfalls - Data and Monetization]] · skills `LihFolk/skills/roblox-datastore-safety/SKILL.md`, `LihFolk/skills/roblox-monetization-compliance/SKILL.md`
- Repo code to copy: `huzz-valley/src/ServerScriptService/HuzzServer/DataService.lua`, `huzz-valley/src/ServerScriptService/HuzzServer/ShopService.lua`

## Sources (all read 2026-10-30)
- https://create.roblox.com/docs/reference/engine/classes/MarketplaceService (methods, deprecations, BindReceiptHandler)
- https://create.roblox.com/docs/en-us/reference/engine/classes/MarketplaceService.md (BindReceiptHandler details, receipt fields)
- https://create.roblox.com/docs/reference/engine/enums/ReceiptType.md and https://create.roblox.com/docs/reference/engine/enums/ReceiptDecision.md
- https://create.roblox.com/docs/production/monetization/developer-products
- https://create.roblox.com/docs/cloud-services/data-stores/error-codes-and-limits
- https://create.roblox.com/docs/reference/engine/classes/DataStoreService
- https://create.roblox.com/docs/cloud-services/memory-stores
- https://create.roblox.com/docs/reference/engine/classes/PolicyService
- https://create.roblox.com/docs/production/monetization/paid-random-items
- https://create.roblox.com/docs/reference/engine/classes/AdService
- https://create.roblox.com/docs/reference/engine/classes/Player
- https://create.roblox.com/docs/de-de/production/monetization/developer-exchange
- https://devforum.roblox.com/t/introducing-roblox-plus/4567894
- https://devforum.roblox.com/t/enabling-regional-prices-for-all-passes-to-grow-your-global-audience/4471199
- https://devforum.roblox.com/t/unifying-data-stores-open-cloud-and-game-apis-and-increasing-storage-limits/4739240
- https://devforum.roblox.com/t/profilestore-save-your-player-data-easy-datastore-module/3190543?page=9
- Not re-read (fetch budget ran out): Creator Rewards page and the rewarded video guide. Those rows cite vault notes verified October 2026.

## Vault corrections
- **[[DataStore Fundamentals]]**: says it is "Unverified whether `SetRateLimitForRequestType` can raise" the per-server defaults. Correction: the reference page says the defaults can be changed, and its sample sets `StandardRead` to a base of 1000 (default 60), so it can raise them. Source: DataStoreService reference, read 2026-10-30. The exact maxima (10,000 / 200, given in [[Data and Cloud Changes 2025-2026]]) were not shown on the page: unverified.
- **`LihFolk/skills/roblox-datastore-safety/SKILL.md`** lists the write base "300 vs 250" as disputed. Correction: settled at 300 since July 29, 2026 (limits page and DevForum unification post).
- **[[Ads and Rewarded Video]]**: lists `UnregisterAdOpportunity` as deprecated. Correction: the AdService reference marks only `ShowVideoAd` and `VideoAdClosed` deprecated. `UnregisterAdOpportunity` is current. Also, the guide now lives at `create.roblox.com/docs/production/promotion/rewarded-video-ads`.
- **[[Developer Products and ProcessReceipt]]**: says `PlaceIdWherePurchased` appears only in older docs. Correction: the current BindReceiptHandler docs list `PlaceIdWherePurchased` and `ReceiptType` as receipt fields.
- **Repo code (not vault): `cannon-evolution/src/server/GameServer.server.lua` ProcessReceipt** calls `save(player)` and returns `PurchaseGranted` without checking that the save succeeded. Its save is also a plain `UpdateAsync` with no session lock. This breaks the CLAUDE.md rule "answer granted only after the save". Fix by copying the huzz-valley ShopService pattern.

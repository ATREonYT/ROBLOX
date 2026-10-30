---
tags: [sector-brief, luau, architecture, networking, remotes, server-authority, anti-exploit, security, purchases]
updated: 2026-10-30
---
# Brief - Code, Networking and Security
Back to [[00 Build Router]] · All briefs: [[Sector Briefs Index]]

> TL;DR
> - **The server owns every number that matters**: cash, wins, speed level, pets, prices, cooldowns. The client only asks ("I want to buy upgrade X") and draws what the server says.
> - **One server entry Script, one client entry LocalScript, everything else ModuleScripts.** The server creates all remotes in one folder from one list. Same shape as `cannon-evolution/`.
> - **Every remote handler starts the same way**: per-player rate limit, then type check every argument (`typeof`, NaN, range), then look things up in server data. Never take a price, amount, or player from the payload.
> - **Purchases**: one `ProcessReceipt` in the place, grant once per `PurchaseId`, return `PurchaseGranted` only after the save succeeded. Game passes: `UserOwnsGamePassAsync` on join, cached on the server.
> - **Speed games**: the client moves its own character. Set `WalkSpeed` on the server, sample position on the server, and rubber-band (not kick) when someone is too fast. Server Authority (July 2026) blocks speed hacks natively, but it forces StreamingEnabled and four other settings, so it is a new-game decision, not a patch.
> - **Use 2026 API names**: `GetProductInfoAsync`, `AwardBadgeAsync`, `LoadCharacterAsync`, and so on. Old names still run but are flagged.
> - **Use `UnreliableRemoteEvent` only for throwaway cosmetic data** (under 1,000 bytes). Never for purchases, rewards or anything that must happen.
> - `--!strict` at the top of every new script. The new type solver is the default. `const` exists, but don't use it in our repo yet (see Pitfalls).

## Current state (Oct 2026): what's new, renamed or deprecated

| Change | When | What to do | Label |
|---|---|---|---|
| 46 yielding methods renamed with `Async` (`GetProductInfoAsync`, `PlayerOwnsAssetAsync`, `AwardBadgeAsync`, `LoadCharacterAsync`, `IsInGroupAsync`, `ApplyDescriptionAsync`...) | Jan 14, 2026 | Write the `Async` name. Old names work, are not scheduled for removal, and are flagged by Script Analysis. `WaitForChild`, `InvokeServer` and `InvokeClient` were **not** renamed. | Vault note [[Engine and API Changes 2025-2026]] (DevForum PSA Jan 14, 2026) |
| `GetRankInGroup` / `GetRoleInGroup` (and their `Async` versions) deprecated | Docs Sept 2026 | `GroupService:GetRolesInGroupAsync`. `IsInGroupAsync` is fine. | Vault note [[API Renames and Deprecations 2025-2026]] |
| Luau's new type solver is the default | Released Nov 20, 2025; Beta toggle removed Jan 7, 2026 | Templates start Nonstrict. Strict scripts stayed on the old solver unless `UseNewLuauTypeSolver = Enabled`. Read-only table properties and type functions now work. | DevForum (Nov 20, 2025) |
| `const` keyword for locals | Luau 0.711 era (spring 2026); on the Creator Hub Variables page | `const MAX_LEVEL = 100`. Forbids reassignment, including `+=`. The value is not frozen: a `const` table can still change (use `table.freeze`). Contextual: old code using `const` as a name still works. | Roblox docs (Variables page, read Oct 30, 2026) |
| **Server Authority** full release | July 9, 2026 | Opt in with `Workspace.AuthorityMode = Server`. Forces `NextGenerationReplication`, `PlayerScriptsUseInputActionSystem`, `SignalBehavior = Deferred`, `StreamingEnabled`, `UseFixedSimulation`. Server runs the simulation; clients predict and roll back. Speed hacks and physics exploits are blocked without custom anti-cheat. | DevForum (July 9, 2026); Roblox docs guide |
| Under Server Authority, RemoteEvents are **not** on the simulation timeline | July 2026 | A remote can arrive before or after the property/attribute change it relates to. Send the value in the remote, or listen to the change itself. | Roblox docs (Server Authority guide) |
| Camera `InputAction` replication removed under Server Authority | July 9, 2026 | `Player:GetCameraState()` (CFrame, FieldOfView, ViewportSize). | DevForum (July 9, 2026) |
| Input Action System (`InputContext`, `InputAction`, `InputBinding`) drives the default player scripts | Full release June 11, 2026 | Opt in with `Workspace.PlayerScriptsUseInputActionSystem`. Planned default-on early 2027, old scripts removed mid 2027. Code calling `require(PlayerModule):GetControls()` will break then. | Vault note [[Server Authority and Input Migration 2026]] (DevForum June 11, 2026) |
| `InputAction:Fire` deprecated | Docs Aug 2026 | `InputBinding:Fire` on a binding of type `Scriptable`. | Vault note [[API Renames and Deprecations 2025-2026]] |
| Physics replication rewrite | Global rollout June 15, 2026 | New desync since mid-June? Test `Workspace.ImprovedPhysicsReplication = Disabled` (temporary escape hatch) before rewriting your code. | Vault note [[Server Authority and Input Migration 2026]] (DevForum June 2026) |
| `SignalBehavior.Default` still means `Immediate` | Docs Oct 19, 2026 | Will become `Deferred` (no date). Write handlers that work under Deferred: don't rely on an event firing "right now" inside the line that caused it. | Vault note [[Engine and API Changes 2025-2026]] |
| Client-side `TeleportService:Teleport` deprecated; `ReserveServer(Async)` deprecated | Aug and Oct 29, 2026 | Server-side `TeleportAsync`. For reserved servers, set `TeleportOptions.ReservedServerId` to a fresh `HttpService:GenerateGUID(false)`. | Vault note [[API Renames and Deprecations 2025-2026]] |
| Cross-game developer product sales disabled | May 30, 2026 | Only sell products inside your own game. `PromptProductPurchaseFinished` is never proof of payment. | Roblox docs (Developer products page) |
| Player text (pet names, signs) | Oct 21, 2026 | Filter it and rate-limit to one submission per minute per player. | Vault note [[API Renames and Deprecations 2025-2026]] (DevForum Oct 21, 2026) |
| Server error stack traces deep-link to the script and place version in Studio | Oct 2026 | Read server errors from the Creator Dashboard; the link opens the line. | Vault note [[Engine and API Changes 2025-2026]] |

## The recipes (how we build X)

### 1. Project layout (Rojo, same shape as `cannon-evolution/`)
- `src/server/GameServer.server.lua` -> `ServerScriptService` (the only server Script). Owns data, purchases, remotes.
- `src/client/GameClient/init.client.lua` + sibling modules -> `StarterPlayer.StarterPlayerScripts` (the only LocalScript).
- `src/shared/GameConfig.lua` -> `ReplicatedStorage` (prices, upgrade curves, pet tables; read by both sides, **trusted only on the server**).
- Server-only modules (data, purchase handling, anti-cheat) go in `ServerScriptService` or `ServerStorage`, never `ReplicatedStorage`: clients can read every replicated script.
- Start-up order: load modules, register handlers, then create the `Remotes` folder last, so a client can never fire into a handler that isn't connected yet.
- Handle players who joined before your `PlayerAdded` connected: loop `Players:GetPlayers()` once after connecting.

### 2. Remotes created by the server

```lua
--!strict
-- ServerScriptService/Remotes (ModuleScript)
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local folder = Instance.new("Folder")
folder.Name = "Remotes"

local function make(name: string, className: "RemoteEvent" | "UnreliableRemoteEvent" | "RemoteFunction"): Instance
	local r = Instance.new(className)
	r.Name = name
	r.Parent = folder
	return r
end

local Remotes = {
	Request = make("Request", "RemoteFunction") :: RemoteFunction, -- C->S: action, ... -> ok, message
	BuyUpgrade = make("BuyUpgrade", "RemoteEvent") :: RemoteEvent, -- C->S: upgradeId, amount
	Sync = make("Sync", "RemoteEvent") :: RemoteEvent,             -- S->C: data snapshot
	Fx = make("Fx", "UnreliableRemoteEvent") :: UnreliableRemoteEvent, -- S->C: cosmetic only
}

function Remotes.publish()
	folder.Parent = ReplicatedStorage -- call after every handler is connected
end

return Remotes
```
Client side: `local Remotes = ReplicatedStorage:WaitForChild("Remotes")`. Never create remotes on the client (they won't replicate to the server).

Which remote type:
- `RemoteEvent`: anything that must arrive (buy, rebirth, hatch, equip). Reliable and ordered, including across different RemoteEvents.
- `RemoteFunction` client->server (`InvokeServer`): when the client needs an answer (`ok, message`). Never use `InvokeClient`: if the client never returns, the server thread waits forever.
- `UnreliableRemoteEvent`: per-frame cosmetics only (trail positions, aim). Can be dropped or reordered. Over 1,000 bytes is always dropped.

### 3. A rate limiter (token bucket)

```lua
--!strict
-- ServerScriptService/RateLimit (ModuleScript)
local Players = game:GetService("Players")

type Bucket = { tokens: number, last: number }

local RateLimit = {}

-- ratePerSec: steady allowance. burst: how many quick taps in a row are fine.
function RateLimit.new(ratePerSec: number, burst: number): (Player) -> boolean
	local buckets: { [Player]: Bucket } = {}
	Players.PlayerRemoving:Connect(function(p) buckets[p] = nil end)
	return function(player: Player): boolean
		local now = os.clock()
		local b = buckets[player]
		if not b then
			b = { tokens = burst, last = now }
			buckets[player] = b
		end
		b.tokens = math.min(burst, b.tokens + (now - b.last) * ratePerSec)
		b.last = now
		if b.tokens < 1 then
			return false
		end
		b.tokens -= 1
		return true
	end
end

return RateLimit
```
Starting limits (Rule of thumb; log rejections for a week before tightening): buy/upgrade 5 per s burst 5; rebirth 1 per s burst 1; hatch 3 per s burst 3; text submissions 1 per 60 s (Roblox rule, see table). A rate-limit hit is silently dropped and logged. Never kick on rate limits alone.

### 4. A validated handler (the template for every remote)

```lua
--!strict
local Config = require(game:GetService("ReplicatedStorage").GameConfig)
local Data = require(script.Parent.Data)          -- server-only profile access
local RateLimit = require(script.Parent.RateLimit)
local Remotes = require(script.Parent.Remotes)

local allowBuy = RateLimit.new(5, 5)

local function isFiniteNumber(v: unknown): boolean
	return typeof(v) == "number" and v == v and v ~= math.huge and v ~= -math.huge
end

Remotes.BuyUpgrade.OnServerEvent:Connect(function(player: Player, upgradeId: unknown, amount: unknown)
	if not allowBuy(player) then return end                         -- 1. rate limit first
	if typeof(upgradeId) ~= "string" or #upgradeId > 40 then return end -- 2. type + size
	if not isFiniteNumber(amount) then return end
	local n = math.floor(amount :: number)
	if n < 1 or n > 100 then return end                             -- 3. range
	local upgrade = Config.Upgrades[upgradeId]                      -- 4. server lookup
	if not upgrade then return end
	local data = Data.get(player)
	if not data then return end                                     -- profile not loaded yet
	local price = Config.PriceFor(upgrade, data.Levels[upgradeId] or 0, n) -- 5. server computes price
	if data.Cash < price then return end
	data.Cash -= price                                              -- 6. change state, no yield in between
	data.Levels[upgradeId] = (data.Levels[upgradeId] or 0) + n
	Data.markDirty(player)
end)
```
The rules behind it:
- The first argument of `OnServerEvent` is the real sender. Never accept a `player` or `userId` argument.
- Check, then change, with **no yield in between** (no `task.wait`, no DataStore call). Handlers start in order but a yielding handler lets the next request start, which is how dupes happen.
- For "is the player near the thing" (claim a coin, touch a pad, open an egg), check distance on the server against the server's copy of the part, with slack for lag (Rule of thumb: 10 to 15 studs).
- Tables from the client: check each field. Mixed number/string keys get mangled, metatables are lost, and an Instance the client can't see arrives as `nil` (Roblox docs, remote events guide).

### 5. Purchases (developer products and game passes)

```lua
--!strict
-- Only ONE script in the whole place sets this.
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")

MarketplaceService.ProcessReceipt = function(receipt)
	local player = Players:GetPlayerByUserId(receipt.PlayerId)
	local data = player and Data.get(player)
	if not (player and data) then
		return Enum.ProductPurchaseDecision.NotProcessedYet -- Roblox retries later (next join)
	end
	if data.Receipts[receipt.PurchaseId] then
		return Enum.ProductPurchaseDecision.PurchaseGranted  -- already granted once
	end
	local grant = Products.byId[receipt.ProductId]
	if not grant then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	grant(player, data)
	data.Receipts[receipt.PurchaseId] = true
	if not Data.saveNow(player) then                         -- must report success or failure
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	return Enum.ProductPurchaseDecision.PurchaseGranted
end
```
- If the save can fail without `saveNow` saying so, the player can be charged and lose the item. `Data.saveNow` must return `false` on failure.
- Keep the `Receipts` table from growing forever: keep the most recent ones only (Rule of thumb: last 50 to 100).
- With ProfileStore, follow its own receipt example; the session lock is what makes "grant once" safe across servers.
- Game passes: on join, `pcall(MarketplaceService.UserOwnsGamePassAsync, MarketplaceService, player.UserId, passId)` and cache the result on the server. Update the cache on the server's `PromptGamePassPurchaseFinished` when `wasPurchased` is true. Gameplay reads the cache only. Never trust a client message that says "I own it".
- Prices shown in the shop come from `GetProductInfoAsync`, not hard-coded numbers (Roblox Plus discounts and regional prices change them).
- Kid-safe: paid random items (eggs) show their odds and a pity counter; no fake timers or stock; an item with no product ID yet says "coming soon" and never opens a prompt (repo `CLAUDE.md`).

### 6. Speed games: server-side speed check (classic replication)
The client owns its character's physics, so an exploiter can move anywhere. The server can only notice and correct.

```lua
--!strict
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local INTERVAL = 0.25     -- seconds between samples (Vault note: 0.2 to 0.5 s)
local SLACK = 1.5         -- multiplier over the speed the server set (Rule of thumb)
local BUCKET_MAX = 3      -- strikes before a rubber-band (Rule of thumb)

type State = { pos: Vector3, t: number, strikes: number }
local states: { [Player]: State } = {}
local exemptUntil: { [Player]: number } = {}

-- Call this before EVERY server-side move (teleport to world 2, launch, respawn).
local function exempt(player: Player, seconds: number)
	exemptUntil[player] = os.clock() + seconds
end

local acc = 0
RunService.Heartbeat:Connect(function(dt)
	acc += dt
	if acc < INTERVAL then return end
	acc = 0
	local now = os.clock()
	for _, player in Players:GetPlayers() do
		local char = player.Character
		local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		if not (root and hum) then states[player] = nil; continue end
		local s = states[player]
		if not s or (exemptUntil[player] or 0) > now then
			states[player] = { pos = root.Position, t = now, strikes = 0 }
			continue
		end
		local elapsed = now - s.t
		if elapsed > INTERVAL * 3 then -- server hitch: reset, don't judge
			s.pos, s.t = root.Position, now
			continue
		end
		local flat = (root.Position - s.pos) * Vector3.new(1, 0, 1)
		local allowed = hum.WalkSpeed * SLACK * elapsed + 4 -- +4 studs for ping jitter
		if flat.Magnitude > allowed then
			s.strikes += 1
			if s.strikes >= BUCKET_MAX then
				root.CFrame = CFrame.new(s.pos) -- rubber-band to last good spot
				s.strikes = 0
				warn("[AntiCheat] speed", player.UserId, math.floor(flat.Magnitude / elapsed))
				continue
			end
		else
			s.strikes = math.max(0, s.strikes - 1)
		end
		s.pos, s.t = root.Position, now
	end
end)
Players.PlayerRemoving:Connect(function(p) states[p] = nil; exemptUntil[p] = nil end)
```
- `hum.WalkSpeed` read on the server is the value the **server** set; client changes to it don't replicate. That is why WalkSpeed must only ever be set on the server (as `applyWalkSpeed` does in `cannon-evolution`).
- Moving platforms, launchers, cannons and knockback make honest players look fast: exempt them or subtract the floor's velocity (see the movement note).
- Make cheating pointless where you can: rewards check distance and checkpoints on the server, so teleporting to the finish line earns nothing.

### 7. When to use Server Authority instead
- Good fit (DevForum July 9, 2026): consistent physics for character movement, vehicles and sports; easiest with default avatars and simple physics. Templates: Racing, Soccer, Laser Tag.
- Cost: it forces StreamingEnabled (parts may not exist on the client), Deferred signals, and moving simulation code into a ModuleScript run on both sides via `RunService:BindToSimulation(fn)`, using `time()` (not `os.clock()`/`tick()`), with state in attributes only. `Destroy()` and reparenting error inside bound functions. Server CPU goes up.
- Rule of thumb for us: don't switch a live simulator to it. For a **new** obby/race/speed game, try it on the golden slice first and judge it in a real published test (mobile/console clients can lag a few days behind desktop after engine updates).

### 8. Typed Luau habits
- `--!strict` on every new file. Annotate function parameters and module exports; let locals infer.
- Remote arguments are `unknown` until checked with `typeof`. Don't cast them with `::` before checking.
- `export type PlayerData = { Cash: number, Levels: { [string]: number }, Receipts: { [string]: boolean } }` in the data module, and use it everywhere.
- `task.wait`, `task.spawn`, `task.delay`, `task.defer` only. Never `wait()`, `spawn()`, `delay()`.
- `workspace:GetServerTimeNow()` for timers both sides must agree on (round end, boosts). Under Server Authority, `time()` inside simulation code.

## Numbers and limits

| Limit | Value | Source |
|---|---|---|
| Client-to-server remote rate | About 500 requests per second per client, shared by all remotes of the same type (RemoteEvent and UnreliableRemoteEvent each have their own pool) | Roblox docs, RemoteEvent "Throttling" (read Oct 30, 2026) |
| Over the rate | RemoteEvent: delayed, order kept. UnreliableRemoteEvent: dropped | Vault note [[RemoteEvents RemoteFunctions and Unreliable Remotes]] (citing Roblox docs) |
| UnreliableRemoteEvent payload | Over 1,000 bytes is dropped, not resent | Roblox docs, remote events guide (read Oct 30, 2026) |
| RemoteEvent ordering | Ordered, including across different RemoteEvent instances; no order between RemoteFunctions and RemoteEvents | Roblox docs, remote events guide |
| Server Authority forced settings | 5 (`NextGenerationReplication`, `PlayerScriptsUseInputActionSystem`, `SignalBehavior` Deferred, `StreamingEnabled`, `UseFixedSimulation`) | Roblox docs, Server Authority guide |
| Attributes that replicate under Server Authority | First 64 per Instance; names and string values max 50 characters | Roblox docs, Server Authority guide |
| Playing animation tracks per Animator under Server Authority | 8 | DevForum (July 9, 2026) |
| Methods renamed with `Async` | 46 | Vault note [[Engine and API Changes 2025-2026]] (DevForum Jan 14, 2026) |
| Player text submissions | 1 per minute per player, filtered | Vault note [[API Renames and Deprecations 2025-2026]] (DevForum Oct 21, 2026) |
| Cross-game developer product sales | Disabled from May 30, 2026 | Roblox docs, Developer products page |
| Speed sample interval | 0.2 to 0.5 s | Vault note [[Detecting Movement Exploits - Speed Fly Noclip Teleport]] |
| `cannon-evolution` Request throttle | 1 call per 0.08 s per player | Repo code `cannon-evolution/src/server/GameServer.server.lua` |

## Pitfalls (what AI models and beginners get wrong)
- **Trusting the payload.** `BuyItem:FireServer("Sword", 0)` with the price as an argument; `GiveCash:FireServer(1e9)`; a `player` argument. The server must compute everything.
- **Leaving debug remotes live** (`GiveCoins`, `SetLevel`). Every shipped remote is callable by every player. Gate test tools with a server-side UserId allowlist or `RunService:IsStudio()`.
- **NaN and infinity.** `amount ~= amount` is true for NaN, and `math.huge` passes `> 0`. Use the `isFiniteNumber` check.
- **Yielding between check and change** (a DataStore call, `task.wait`) inside a buy handler. Two fast requests both pass the check: dupe.
- **Granting in `PromptProductPurchaseFinished`** or on a client message. It does not prove payment.
- **Returning `PurchaseGranted` when the save failed.** Our own reference game does this: `cannon-evolution` `ProcessReceipt` calls `save(player)`, which swallows failure after 3 retries, then returns `PurchaseGranted` anyway. Fix it in new games (`saveNow` that returns success).
- **Two `ProcessReceipt` assignments** (one per system). Only the last one runs.
- **`InvokeClient`** from the server. A disconnected or malicious client freezes the server thread.
- **Per-frame `FireServer` on a reliable remote.** Eats the shared 500/s budget and delays the purchase remote behind it. Use UnreliableRemoteEvent for streams, or send only on change.
- **Setting `WalkSpeed` on the client** in a speed game. The client then runs fast, but the server's speed check (which reads the server value) flags the honest player.
- **Kicking on the first strike.** Mobile lag bunches movement. Use strikes plus rubber-banding; log and review before any ban.
- **Old API names from training data**: `GetProductInfo`, `LoadCharacter`, `AwardBadge`, `ReserveServer`, client `TeleportService:Teleport`, `wait()`, legacy `Chat`. Grep for them before shipping.
- **"A remote arrives after the attribute I set before it."** Not guaranteed under Server Authority / Next Generation Replication. Send the value in the remote.
- **Turning on Server Authority to "fix speed hackers"** in an existing game: streaming breaks every `workspace.Map.Part` lookup on the client.
- **`const` in our repo.** It is valid Luau in Studio now, but our offline Lune harness (Lune 0.10.5) and other tools may not parse it yet (Unverified). Use `local` with UPPER_CASE names until the harness is checked.
- **Weak tables keyed by Instance** for per-player state: entries vanish at random (repo `CLAUDE.md`). Use a normal table and clear it on `PlayerRemoving`.
- **Server modules in `ReplicatedStorage`**: exploiters can read them (prices, anti-cheat thresholds, admin lists).

## Checklist before shipping
- [ ] One server entry Script, one client entry LocalScript; server-only modules not in `ReplicatedStorage`.
- [ ] All remotes created by the server in one `Remotes` folder, published after handlers connect.
- [ ] Every `OnServerEvent` / `OnServerInvoke` starts with a rate limit, then `typeof` + range checks on every argument.
- [ ] No handler takes a player, price, amount-of-reward or owned-flag from the client.
- [ ] No `InvokeClient`. No reliable remote fired every frame.
- [ ] No debug or admin remote reachable by normal players in a live server.
- [ ] Exactly one `ProcessReceipt`; it checks `PurchaseId`, saves, and returns `PurchaseGranted` only on a successful save.
- [ ] Game passes checked with `UserOwnsGamePassAsync` on the server; the client's view is cosmetic.
- [ ] `WalkSpeed` (and jump power) set only on the server; server speed check with exemptions for every server move, launcher and moving platform.
- [ ] Rewards (coins, checkpoints, wins) check distance and order on the server.
- [ ] Player text filtered and limited to 1 per minute.
- [ ] `grep -nE ":(GetProductInfo|PlayerOwnsAsset|AwardBadge|LoadCharacter|IsInGroup|GetRankInGroup|ReserveServer)\(|[^.]wait\(|[^.]spawn\(" src` returns nothing.
- [ ] `--!strict` at the top of new files; no Script Analysis warnings.
- [ ] Ran a quick abuse test: fire each remote with wrong types, NaN, huge numbers and 50 times a second from the Command Bar's client context.

## Go deeper
- Structure: [[Project Structure and Bootstrapping]], [[Script Types and Run Context]], [[Module Scripts and Requiring]], [[Module Design and Dependency Injection]], [[Frameworks - Knit Matter and Others]]
- Luau language and types: [[Luau Language Essentials]], [[Luau Type System and Strict Mode]], [[Advanced Types - Generics and Type Functions]], [[Task Library Coroutines and Yielding]], [[Error Handling and Retries]], [[Buffers and Binary Data]]
- 2025-2026 changes: [[Engine and API Changes 2025-2026]], [[API Renames and Deprecations 2025-2026]], [[AI Pitfalls - Stale APIs and Luau]], [[Engine Limits, Quotas and Defaults - Cheat Sheet]]
- Networking: [[Client-Server Model]], [[RemoteEvents RemoteFunctions and Unreliable Remotes]], [[Replication Rules]], [[Network Ownership]], [[Instance Streaming]], [[Events Signals and Connections]], [[Debugging Client-Server Desync]], [[Cookbook - Remotes and Networking]], [[Server Authority and Input Migration 2026]], [[Server Authority and Validation]], [[Rate Limiting and Abuse Prevention]], [[Remote Abuse Patterns and Rate Limiting in Practice]]
- Anti-exploit: [[Anti-Exploit Start Here]], [[How Exploits Work - The Client Boundary]], [[Exploits and Anti-Cheat]], [[Detecting Movement Exploits - Speed Fly Noclip Teleport]], [[False Positives Lag and Fair Enforcement]], [[Logging Bans and Appeals]], [[Testing Your Own Remotes - Fuzzing and Abuse Tests]], [[Admin Commands Done Safely - Permissions and Audit Logs]], [[Economy Exploits - Dupes Races and Purchase Abuse]], [[Text Filtering - TextService for Names, Signs and Messages]]
- Skills: [[Skill - Roblox Secure Remotes]], [[Skill - Roblox Anti-Exploit Review]]. Reference code: `cannon-evolution/src/server/GameServer.server.lua` (remotes list, `Request` RemoteFunction with 0.08 s throttle, `ProcessReceipt`, `loadPasses`, `applyWalkSpeed`), `cannon-evolution/default.project.json`.

## Sources
- https://create.roblox.com/docs/projects/server-authority (read 2026-10-30)
- https://devforum.roblox.com/t/full-release-ship-fair-and-competitive-games-with-server-authority/4727993 (July 9, 2026; read 2026-10-30)
- https://create.roblox.com/docs/scripting/events/remote (read 2026-10-30)
- https://create.roblox.com/docs/reference/engine/classes/RemoteEvent.md (Throttling section; read 2026-10-30)
- https://create.roblox.com/docs/reference/engine/classes/UnreliableRemoteEvent (read 2026-10-30)
- https://create.roblox.com/docs/luau/variables (`const`; read 2026-10-30)
- https://devforum.roblox.com/t/release-notes-for-711/4473831 (`const` introduced; read 2026-10-30); https://github.com/luau-lang/rfcs/pull/166 (const RFC; read 2026-10-30); https://devforum.roblox.com/t/feedback-on-variables/4590572/1 (Apr 22, 2026; read 2026-10-30)
- https://devforum.roblox.com/t/general-release-luau%E2%80%99s-new-type-solver/4084991 (Nov 20, 2025; read 2026-10-30)
- https://create.roblox.com/docs/production/monetization/developer-products (read 2026-10-30)
- Vault notes listed above (LihFolk Vault V2, folders 02, 03, 22, 29, 35, 49), read 2026-10-30.

## Vault corrections
| Note | Claim | Correction | Source |
|---|---|---|---|
| [[Engine and API Changes 2025-2026]] (section 5) | New type solver general release "late 2025; exact date Unverified" | Posted November 20, 2025 | DevForum general release post (read 2026-10-30) |
| [[Error Handling and Retries]] (line 118) | Lists `MarketplaceService` `GetProductInfo` | Use `GetProductInfoAsync` (renamed Jan 14, 2026) | Vault note [[API Renames and Deprecations 2025-2026]] |
| [[Cookbook - Players and Characters]] (lines 288, 290, 446) | Prose says `LoadCharacter` (code above it correctly uses `LoadCharacterAsync`) | Say `LoadCharacterAsync` throughout | Same as above |
| [[Server Authority and Input Migration 2026]] | Tools: "`EquipTool`/`UnequipTools` not allowed; weld a model" | Still true inside bound functions per the guide, but the July 9, 2026 release post claims "Full support for Backpacks and Tools" and warns that changing Tools during a misprediction may delete the Tool's Weld on the client. Note both. | Roblox docs guide + DevForum July 9, 2026 |
| [[Rate Limiting and Abuse Prevention]] (line 284) | "Using `tick()`: use `os.clock()`" | Fine for classic games; under Server Authority, simulation code must use `time()` | Roblox docs, Server Authority guide |

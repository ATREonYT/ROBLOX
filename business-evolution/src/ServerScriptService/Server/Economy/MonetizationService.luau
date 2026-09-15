--!strict
-- Gamepass plumbing (§10). Ownership is checked ONCE per player per session
-- and cached — UserOwnsGamePassAsync is a rate-limited web call, and income
-- math asks about passes every tick. The cache refreshes the moment a purchase
-- prompt closes, so a mid-session buy takes effect immediately.
--
-- Passes with Id == 0 haven't been created on the website yet and are skipped
-- everywhere, so the game runs fine before monetization is wired up.

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local DataService = require(ServerScriptService.Server.Data.DataService)
local Stack = require(ServerScriptService.Server.Economy.Stack)

local Shared = ReplicatedStorage.Shared
local Monetization = require(Shared.Config.Monetization)

local Trove = require(ReplicatedStorage.Packages.Trove)

-- PurchaseLog marker: written the first time the Starter Pack contents are
-- granted, so a rejoin (or a second purchase-finished event) can never pay out
-- the 500 Wins twice.
local STARTER_PACK_MARKER = "grant_StarterPack"
local STARTER_PACK_WINS = 500 -- matches the pass description in Config/Monetization

local TRAIL_PREFIX = "BriefcaseTrail_"

local MonetizationService = {}

local trove = Trove.new()
-- One child trove per player holds their CharacterAdded connection, so a
-- leaver's connection dies without touching anyone else's.
local playerTroves: { [Player]: Trove.Trove } = {}
-- Session ownership cache: player -> pass Key -> true. Absent key = not owned
-- (or still being fetched, which safely reads as not owned until it lands).
local ownedByPlayer: { [Player]: { [string]: boolean } } = {}

-- Reverse lookup for PromptGamePassPurchaseFinished, which hands us a numeric
-- id, not a Key. Built once at require time from pure config.
local keyByPassId: { [number]: string } = {}
for _, pass in Monetization.Passes do
	if pass.Id ~= 0 then
		keyByPassId[pass.Id] = pass.Key
	end
end
for _, trailDef in Monetization.Trails do
	if trailDef.Id ~= 0 then
		keyByPassId[trailDef.Id] = trailDef.Key
	end
end

local function owns(player: Player, key: string): boolean
	local owned = ownedByPlayer[player]
	return owned ~= nil and owned[key] == true
end

-- What DataService hands to the Stack on every income calculation. The Buyout
-- bundle IMPLIES its four component passes, so the stack never needs to know
-- the bundle exists.
local function passesFor(player: Player): Stack.Passes
	local buyout = owns(player, "Buyout")
	return {
		DoubleWins = buyout or owns(player, "DoubleWins"),
		DoubleProductivity = buyout or owns(player, "DoubleProductivity"),
		InternSlots = buyout or owns(player, "InternSlots"),
		Delegate = buyout or owns(player, "Delegate"),
	}
end

-- ── Starter Pack ────────────────────────────────────────────────────────────

local function maybeGrantStarterPack(player: Player)
	if not owns(player, "StarterPack") then
		return
	end
	local data = DataService.get(player)
	if not data then
		return -- profile not in yet; the PlayerLoaded hook retries this
	end
	if table.find(data.PurchaseLog, STARTER_PACK_MARKER) then
		return -- already granted in some earlier session
	end
	DataService.update(player, function(live)
		-- Marker first, in the same synchronous mutation as the payout: there
		-- is no ordering where the Wins land without the marker.
		table.insert(live.PurchaseLog, STARTER_PACK_MARKER)
		live.Wins += STARTER_PACK_WINS
		-- "if tier 0": a player who already earned a better keyboard must not
		-- be downgraded by their own purchase.
		if live.Gear.Keyboard == 0 then
			live.Gear.Keyboard = 1
		end
	end)
	DataService.pushState(player)
end

-- ── Briefcase trails ────────────────────────────────────────────────────────

-- Trails config is ordered cheapest → priciest, so the highest tier owned is
-- the LAST owned entry. Only that one attaches — stacking five trails on one
-- character would be soup.
local function highestOwnedTrail(player: Player): { Key: string, Color: { number } }?
	for index = #Monetization.Trails, 1, -1 do
		local trailDef = Monetization.Trails[index]
		if owns(player, trailDef.Key) then
			return trailDef
		end
	end
	return nil
end

local function applyTrailFor(player: Player)
	local character = player.Character
	if not character then
		return -- next CharacterAdded re-applies
	end
	local root = character:FindFirstChild("HumanoidRootPart")
	if not (root and root:IsA("BasePart")) then
		return
	end
	-- Strip any previous trail first so a mid-session upgrade replaces instead
	-- of stacking.
	for _, child in root:GetChildren() do
		if string.find(child.Name, TRAIL_PREFIX, 1, true) == 1 then
			child:Destroy()
		end
	end
	local trailDef = highestOwnedTrail(player)
	if not trailDef then
		return
	end
	local color = Color3.fromRGB(trailDef.Color[1], trailDef.Color[2], trailDef.Color[3])

	local top = Instance.new("Attachment")
	top.Name = TRAIL_PREFIX .. "Top"
	top.Position = Vector3.new(0, 1, 0)
	local bottom = Instance.new("Attachment")
	bottom.Name = TRAIL_PREFIX .. "Bottom"
	bottom.Position = Vector3.new(0, -1.2, 0)

	local trail = Instance.new("Trail")
	trail.Name = TRAIL_PREFIX .. trailDef.Key
	trail.Attachment0 = top
	trail.Attachment1 = bottom
	trail.Color = ColorSequence.new(color)
	trail.LightEmission = 0.6
	trail.Lifetime = 0.4
	trail.MinLength = 0.1
	trail.FaceCamera = true
	-- Taper + fade toward the tail so the ribbon ends softly instead of being
	-- chopped off at the lifetime boundary. (No default engine texture needed —
	-- this keeps the project free of external asset ids.)
	trail.WidthScale = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(1, 0.25),
	})
	trail.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.25),
		NumberSequenceKeypoint.new(1, 1),
	})

	top.Parent = root
	bottom.Parent = root
	trail.Parent = root
end

-- ── Ownership cache lifecycle ───────────────────────────────────────────────

-- Runs in its own thread (web calls yield). Fills the table registered at
-- join; if the player leaves mid-fetch the table is already orphaned, so the
-- late writes land nowhere visible.
local function buildOwnershipCache(player: Player)
	local owned = ownedByPlayer[player]
	if not owned then
		return
	end
	for passId, key in keyByPassId do
		local ok, result = pcall(function()
			return MarketplaceService:UserOwnsGamePassAsync(player.UserId, passId)
		end)
		-- A failed web call reads as "not owned" for this session; the next
		-- purchase prompt or rejoin corrects it. Never block play on it.
		if ok and result == true then
			owned[key] = true
		end
	end
	if player.Parent == nil then
		return
	end
	maybeGrantStarterPack(player)
	applyTrailFor(player)
	-- Derived numbers (ClickIncome, InternSlots...) change with passes, so the
	-- client needs a fresh snapshot once ownership is known.
	DataService.pushState(player)
end

local function watchPlayer(player: Player)
	if playerTroves[player] then
		return
	end
	local playerTrove = trove:Extend()
	-- Cast: the old Luau solver can't prove two instantiations of Trove's
	-- generic-method type are identical; the value really is a Trove.
	playerTroves[player] = playerTrove :: any
	ownedByPlayer[player] = {}

	playerTrove:Connect(player.CharacterAdded, function(character: Model)
		task.spawn(function()
			-- The root part streams in after CharacterAdded fires; wait
			-- (bounded) for it or the trail would silently skip every respawn.
			character:WaitForChild("HumanoidRootPart", 10)
			if character.Parent then
				applyTrailFor(player)
			end
		end)
	end)

	task.spawn(buildOwnershipCache, player)
end

local function unwatchPlayer(player: Player)
	local playerTrove = playerTroves[player]
	if playerTrove then
		playerTroves[player] = nil
		playerTrove:Destroy()
	end
	ownedByPlayer[player] = nil
end

local function onPromptFinished(player: Player, gamePassId: number, wasPurchased: boolean)
	if not wasPurchased then
		return
	end
	local key = keyByPassId[gamePassId]
	local owned = ownedByPlayer[player]
	if key == nil or owned == nil then
		return -- a pass from some other experience, or the player already left
	end
	owned[key] = true
	maybeGrantStarterPack(player)
	applyTrailFor(player)
	DataService.pushState(player)
end

function MonetizationService:Init()
	-- All wiring happens in Start; nothing here may touch other services.
end

function MonetizationService:Start()
	-- From here on, every income calculation in the game sees real ownership.
	DataService.setPassProvider(passesFor)

	trove:Connect(Players.PlayerAdded, watchPlayer)
	trove:Connect(Players.PlayerRemoving, unwatchPlayer)
	for _, player in Players:GetPlayers() do
		watchPlayer(player)
	end

	-- The cache fetch can finish before the profile loads; this second hook
	-- covers that ordering so the Starter Pack grant is never missed.
	-- Cast: DataService's Signals are unparameterized Signal.new() values,
	-- which the solver can't match against Trove's SignalLike shape.
	trove:Connect(DataService.PlayerLoaded :: any, function(player: Player)
		maybeGrantStarterPack(player)
	end)

	trove:Connect(MarketplaceService.PromptGamePassPurchaseFinished, onPromptFinished)
end

return MonetizationService

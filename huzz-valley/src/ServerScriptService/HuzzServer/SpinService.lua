-- Spin the Wheel, server side (owner: "a free spin once every 15 minutes, but if they want to buy they can").
--   * The owner's wheel in the lobby: any Model or Part in Workspace whose name has "spin" and "wheel" in it (any
--     case, spaces or not), or anything tagged "HuzzSpinWheel", gets a ProximityPrompt (E, "Spin the Wheel") and a
--     ClickDetector. Using it opens the Spin the Wheel screen on that player's screen (SpinOpen remote). The lobby
--     HUD's SPIN button opens the same screen, so it works without the model too.
--   * The Spin remote (count = 1, 5 or 10): the free spin first, then owned spins; the server rolls with the shown
--     odds and the pity counter (Shared/CrateRoll), gives the prizes and saves (Shared/SpinRules.spin). The client
--     only animates to the slice it's told.
--   * Bought spins are granted only in ShopService's ProcessReceipt (Products.Spins, Kind "Spins").
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Wheel = require(ReplicatedStorage.Shared.Config.SpinWheel)
local SpinRules = require(ReplicatedStorage.Shared.SpinRules)
local CrateRoll = require(ReplicatedStorage.Shared.CrateRoll)
local Net = require(ReplicatedStorage.Shared.Net)
local DataService = require(script.Parent.DataService)

local SpinService = {}

local TAG = "HuzzSpinWheel"
local MIN_GAP = 0.8 -- seconds between spin requests from one player (the screen's spin takes ~5 s anyway)
local OPEN_GAP = 1 -- seconds between opens from the wheel in the lobby

local random = Random.new()
local lastSpin: { [Player]: number } = {}
local lastOpen: { [Player]: number } = {}

-- x2 while that boost lasts (RoundService pays round coins times this).
function SpinService.boost(player: Player, kind: string): number
	local profile = DataService.get(player)
	if not profile then return 1 end
	return SpinRules.boost(profile.Data, kind, os.time())
end

-- Spins `count` times for the player. Returns true and { rolls, land, usedFree } or false and why.
function SpinService.spin(player: Player, count: any): (boolean, any)
	if count ~= 1 and not table.find(Wheel.Multi, count) then return false, "Pick a spin." end
	local now = os.clock()
	if lastSpin[player] and now - lastSpin[player] < MIN_GAP then return false, "Wait for the wheel to stop." end
	if not DataService.get(player) then return false, "Your save is still loading." end
	lastSpin[player] = now
	local ok, result = false, "Couldn't spin. Try again."
	DataService.update(player, function(data)
		ok, result = SpinRules.spin(data, Wheel, count, os.time(), function(pity)
			return CrateRoll.roll(Wheel, pity, function() return random:NextNumber() end)
		end)
	end)
	if ok then
		result.land = SpinRules.best(result.rolls, CrateRoll.RANK)
	end
	return ok, result
end

-- "Spin Wheel", "SPINWHEEL", "spin_the_wheel", "Spin The Wheel Model" all count.
local function looksLikeWheel(inst: Instance): boolean
	if not (inst:IsA("Model") or inst:IsA("BasePart")) then return false end
	local name = string.lower(inst.Name):gsub("[%s_%-]", "")
	return string.find(name, "spin", 1, true) ~= nil and string.find(name, "wheel", 1, true) ~= nil
end

-- The part the prompt and click go on: the model's PrimaryPart, else its biggest part.
local function mainPart(inst: Instance): BasePart?
	if inst:IsA("BasePart") then return inst end
	local model = inst :: Model
	if model.PrimaryPart then return model.PrimaryPart end
	local best, size = nil, -1
	for _, d in inst:GetDescendants() do
		if d:IsA("BasePart") then
			local s = d.Size.X * d.Size.Y * d.Size.Z
			if s > size then best, size = d, s end
		end
	end
	return best
end

local openRemote: RemoteEvent
local hooked: { [Instance]: boolean } = {}

local function open(player: Player)
	local now = os.clock()
	if lastOpen[player] and now - lastOpen[player] < OPEN_GAP then return end
	lastOpen[player] = now
	openRemote:FireClient(player)
end

local function hook(inst: Instance)
	if hooked[inst] then return end
	-- (a wheel inside a wheel model: the outer one already has the prompt)
	local up = inst.Parent
	while up and up ~= workspace do
		if hooked[up] then return end
		up = up.Parent
	end
	local part = mainPart(inst)
	if not part then return end
	hooked[inst] = true
	inst.Destroying:Connect(function() hooked[inst] = nil end)
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "HuzzSpinPrompt"
	prompt.ActionText = "Spin the Wheel"
	prompt.ObjectText = ""
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 14
	prompt.RequiresLineOfSight = false
	prompt.Parent = part
	prompt.Triggered:Connect(open)
	local click = Instance.new("ClickDetector")
	click.Name = "HuzzSpinClick"
	click.MaxActivationDistance = 40
	click.Parent = part
	pcall(function() click.MouseClick:Connect(open) end)
	print("[Huzz] Spin the Wheel found:", inst:GetFullName())
end

function SpinService.start()
	openRemote = Net.get("SpinOpen") :: RemoteEvent
	(Net.get("Spin") :: RemoteFunction).OnServerInvoke = function(player, count)
		return SpinService.spin(player, count)
	end
	Players.PlayerRemoving:Connect(function(p)
		lastSpin[p], lastOpen[p] = nil, nil
	end)
	-- the owner's wheel model(s): by name or by tag, now and when added later
	for _, inst in CollectionService:GetTagged(TAG) do hook(inst) end
	CollectionService:GetInstanceAddedSignal(TAG):Connect(hook)
	for _, inst in workspace:GetDescendants() do
		if looksLikeWheel(inst) then hook(inst) end
	end
	workspace.DescendantAdded:Connect(function(inst)
		if looksLikeWheel(inst) then task.defer(hook, inst) end -- (deferred: let its parts load in first)
	end)
end

return SpinService

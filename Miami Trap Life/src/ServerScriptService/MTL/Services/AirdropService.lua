--!strict
-- Airdrops (Quality pass, Benchmark Gap List 2.7). See Config/Live.Airdrop.
-- Timeline for one drop:  heads-up (everyone: banner + marker, LiveState {type="airdrop", phase="incoming"})
--   -> the crate falls on its parachute for the last `fallSeconds` -> lands: chute goes, red flare smoke + glow,
--   a "Hold E · Open" prompt (5 s) -> first player to finish the hold gets the cash (+ sometimes a cheap tool)
--   -> crate pops open, smoke stops, removed a few seconds later. Unopened crates go after `stayMinutes`.
-- The prompt's Triggered is the only payout path, and the server checks the player is alive and within reach.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Live = require(ReplicatedStorage.MTL.Config.Live)
local Net = require(ReplicatedStorage.MTL.Net)
local Notify = require(script.Parent.Notify)
local EconomyService = require(script.Parent.EconomyService)
local WaypointService = require(script.Parent.WaypointService)

local A = Live.Airdrop
local AirdropService = {}

local WAYPOINT = "airdrop"
local rng = Random.new()
local current: { crate: Model?, spot: any, landed: boolean, opened: boolean, token: number }? = nil
local token = 0

local function log(...)
	print("[MTL Airdrop]", ...)
end

local function crimeService(): any?
	local m = script.Parent:FindFirstChild("CrimeService")
	if not m then
		return nil
	end
	local ok, svc = pcall(require, m)
	return if ok then svc else nil
end

local function broadcast(payload: any)
	Net.get("LiveState"):FireAllClients(payload)
end

local function clearMarkers()
	for _, p in Players:GetPlayers() do
		WaypointService.clear(p, WAYPOINT)
	end
end

local function folder(): Folder
	local f = workspace:FindFirstChild("MTL_Live")
	if not f then
		f = Instance.new("Folder")
		f.Name = "MTL_Live"
		f.Parent = workspace
	end
	return f :: Folder
end

local function setFlare(crate: Model, on: boolean)
	for _, d in crate:GetDescendants() do
		if d:IsA("ParticleEmitter") or d:IsA("PointLight") then
			d.Enabled = on
		end
	end
end

local function finish(t: number, after: number)
	task.delay(after, function()
		if current and current.token == t then
			if current.crate then
				current.crate:Destroy()
			end
			current = nil
			clearMarkers()
			broadcast({ type = "airdrop", phase = "gone" })
		end
	end)
end

local function pay(player: Player, at: Vector3)
	local cash = rng:NextInteger(A.cash[1], A.cash[2])
	local toolText = nil
	if rng:NextNumber() < A.toolChance then
		local id = A.tools[rng:NextInteger(1, #A.tools)]
		local crime = crimeService()
		local gave = false
		if crime and crime.giveTool then
			local ok, res = pcall(crime.giveTool, player, id)
			gave = ok and res == true
		end
		if gave then
			toolText = id
		else
			cash += A.toolCashValue
		end
	end
	EconomyService.addCash(player, cash, "Airdrop", true, at)
	EconomyService.addXP(player, A.xp, "Airdrop", at)
	Notify.banner(player, "SUPPLY DROP", "+$" .. cash .. (if toolText then " and a " .. toolText else ""), Color3.fromRGB(255, 120, 90))
	log(player.Name, "opened the drop:", cash, toolText or "")
	return cash, toolText
end

local function land(t: number)
	local c = current
	if not c or c.token ~= t or not c.crate then
		return
	end
	c.landed = true
	local crate = c.crate
	local chute = crate:FindFirstChild("Chute")
	if chute then
		-- the canopy sags and drifts off downwind
		for _, d in chute:GetDescendants() do
			if d:IsA("BasePart") then
				TweenService:Create(d, TweenInfo.new(1.6, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
					CFrame = d.CFrame * CFrame.new(6, -9, 2) * CFrame.Angles(0.6, 0, 0.9),
					Transparency = 1,
				}):Play()
			elseif d:IsA("Beam") then
				d.Enabled = false
			end
		end
		task.delay(1.7, function()
			chute:Destroy()
		end)
	end
	setFlare(crate, true)
	local root = crate.PrimaryPart :: BasePart
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "OpenDrop"
	prompt.ActionText = "Open"
	prompt.ObjectText = "Supply drop"
	prompt.HoldDuration = A.holdSeconds
	prompt.MaxActivationDistance = 9
	prompt.RequiresLineOfSight = false
	prompt.Parent = root
	prompt.Triggered:Connect(function(player)
		local cc = current
		if not cc or cc.token ~= t or cc.opened then
			return
		end
		local char = player.Character
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		local hrp = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
		if not hum or hum.Health <= 0 or not hrp or (hrp.Position - root.Position).Magnitude > 14 then
			return
		end
		cc.opened = true
		prompt:Destroy()
		local cash = pay(player, root.Position + Vector3.new(0, 3, 0))
		-- lid pops, smoke stops, crate goes a moment later
		local lid = crate:FindFirstChild("Lid") :: BasePart?
		if lid then
			TweenService:Create(lid, TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
				CFrame = lid.CFrame * CFrame.new(0, 0.9, -1.2) * CFrame.Angles(math.rad(-70), 0, 0),
			}):Play()
		end
		setFlare(crate, false)
		clearMarkers()
		broadcast({ type = "airdrop", phase = "opened", by = player.DisplayName, cash = cash })
		finish(t, 6)
	end)
	broadcast({ type = "airdrop", phase = "landed", at = root.Position, label = c.spot.label })
	finish(t, A.stayMinutes * 60)
end

function AirdropService.drop(spotId: string?)
	if current then
		return false
	end
	local spot = A.spots[rng:NextInteger(1, #A.spots)]
	if spotId then
		for _, s in A.spots do
			if s.id == spotId then
				spot = s
			end
		end
	end
	local lib = ReplicatedStorage:FindFirstChild("MTL_Live")
	local template = lib and lib:FindFirstChild("SupplyCrate")
	if not (template and template:IsA("Model")) then
		warn("[MTL Airdrop] ReplicatedStorage.MTL_Live.SupplyCrate is missing")
		return false
	end
	token += 1
	local t = token
	local c = { crate = nil :: Model?, spot = spot, landed = false, opened = false, token = t }
	current = c
	log("incoming ->", spot.id)
	broadcast({ type = "airdrop", phase = "incoming", at = spot.at, label = spot.label, seconds = A.warnSeconds })
	for _, p in Players:GetPlayers() do
		Notify.banner(p, "SUPPLY DROP INCOMING", "Landing at " .. spot.label .. " in " .. A.warnSeconds .. "s", Color3.fromRGB(255, 120, 90))
		WaypointService.set(p, WAYPOINT, spot.at, { label = "Supply drop", radius = 6, breadcrumbs = false })
	end
	-- the fall: spawn high up, glide down over the last `fallSeconds`, with a lazy sway
	task.delay(math.max(0, A.warnSeconds - A.fallSeconds), function()
		if not current or current.token ~= t then
			return
		end
		local crate = (template :: Model):Clone()
		crate.Name = "SupplyDrop"
		setFlare(crate, false)
		local yaw = CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0)
		local ground = CFrame.new(spot.at) * yaw
		crate:PivotTo(ground + Vector3.new(0, A.dropHeight, 0))
		crate.Parent = folder()
		c.crate = crate
		local start = os.clock()
		while current and current.token == t and crate.Parent do
			local u = math.clamp((os.clock() - start) / A.fallSeconds, 0, 1)
			local ease = u -- a parachute falls at a steady speed
			local sway = CFrame.Angles(math.sin(os.clock() * 1.3) * 0.06 * (1 - u), 0, math.cos(os.clock() * 1.1) * 0.06 * (1 - u))
			crate:PivotTo((ground + Vector3.new(0, A.dropHeight * (1 - ease), 0)) * sway)
			if u >= 1 then
				break
			end
			task.wait()
		end
		crate:PivotTo(ground)
		land(t)
	end)
	return true
end

-- who's in the server and not mid-cutscene: drops only when someone can actually go
local function anyoneAround(): boolean
	return #Players:GetPlayers() >= A.minPlayers
end

function AirdropService.init()
	-- late joiners see a drop that's already out
	Players.PlayerAdded:Connect(function(player)
		task.wait(8)
		local c = current
		if c and not c.opened and player.Parent then
			WaypointService.set(player, WAYPOINT, c.spot.at, { label = "Supply drop", radius = 6, breadcrumbs = false })
			Net.get("LiveState"):FireClient(player, { type = "airdrop", phase = if c.landed then "landed" else "incoming", at = c.spot.at, label = c.spot.label, seconds = 30 })
		end
	end)
	task.spawn(function()
		task.wait(A.firstAfter)
		while true do
			if anyoneAround() and not current then
				AirdropService.drop()
			end
			task.wait(A.every)
		end
	end)
end

return AirdropService

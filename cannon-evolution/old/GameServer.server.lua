--[[
	GameServer  (Script)
	Location: ServerScriptService > GameServer

	Handles: saving (DataStore), leaderstats, training stations, Grand Cannon launch.

	Expects in Workspace (made by BuildWorld1.lua):
	  TrainingStations > Station_1..6  (Model, attribute StationId)
	      Pad, StandPoint, Muzzle, Target (Model with Center part), Cannon (Model)
	  LaunchPoint  (Part with a ProximityPrompt)
]]

local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage:WaitForChild("GameConfig"))

---------------------------------------------------------------------------
-- Remotes
---------------------------------------------------------------------------
local remotes = Instance.new("Folder")
remotes.Name = "Remotes"
local function remote(name, class)
	local r = Instance.new(class or "RemoteEvent")
	r.Name = name
	r.Parent = remotes
	return r
end
local TrainingState = remote("TrainingState") -- S->C: stationId or nil
local TrainingShot = remote("TrainingShot") -- S->All: player, stationId, gain
local StopTraining = remote("StopTraining") -- C->S
local LaunchPlayer = remote("LaunchPlayer") -- S->C: velocity
local LaunchResult = remote("LaunchResult") -- S->C: distance, coins, isBest
local Notify = remote("Notify") -- S->C: text, color
local RequestRebirth = remote("RequestRebirth") -- C->S
remotes.Parent = ReplicatedStorage

---------------------------------------------------------------------------
-- Data
---------------------------------------------------------------------------
local store = DataStoreService:GetDataStore(Config.DATASTORE_NAME)
local profiles = {} -- [player] = { Data = {}, Loaded = bool }

local function deepCopy(t)
	local c = {}
	for k, v in pairs(t) do
		c[k] = type(v) == "table" and deepCopy(v) or v
	end
	return c
end

local function reconcile(data, template)
	for k, v in pairs(template) do
		if data[k] == nil then
			data[k] = type(v) == "table" and deepCopy(v) or v
		elseif type(v) == "table" and type(data[k]) == "table" then
			reconcile(data[k], v)
		end
	end
	return data
end

local function withRetries(fn)
	for attempt = 1, 3 do
		local ok, result = pcall(fn)
		if ok then
			return true, result
		end
		warn("[GameServer] DataStore attempt " .. attempt .. " failed: " .. tostring(result))
		task.wait(attempt * 2)
	end
	return false
end

local function updateLeaderstats(player)
	local profile = profiles[player]
	local ls = player:FindFirstChild("leaderstats")
	if not (profile and ls) then
		return
	end
	ls.Strength.Value = profile.Data.Strength
	ls.Rebirths.Value = profile.Data.Rebirths
	ls.Coins.Value = profile.Data.Coins
	player:SetAttribute("Strength", profile.Data.Strength)
	player:SetAttribute("Rebirths", profile.Data.Rebirths)
	player:SetAttribute("Coins", profile.Data.Coins)
	player:SetAttribute("BestDistance", profile.Data.BestDistance)
end

local function save(player)
	local profile = profiles[player]
	if not (profile and profile.Loaded) then
		return -- never overwrite data that failed to load
	end
	withRetries(function()
		store:UpdateAsync("Player_" .. player.UserId, function()
			return profile.Data
		end)
	end)
end

local function onPlayerAdded(player)
	local ls = Instance.new("Folder")
	ls.Name = "leaderstats"
	for _, name in ipairs({ "Strength", "Rebirths", "Coins" }) do
		local v = Instance.new("NumberValue")
		v.Name = name
		v.Parent = ls
	end
	ls.Parent = player

	local ok, stored = withRetries(function()
		return store:GetAsync("Player_" .. player.UserId)
	end)
	if not player.Parent then
		return
	end
	if not ok then
		player:Kick("Couldn't load your data. Please rejoin!")
		return
	end
	profiles[player] = {
		Data = reconcile(type(stored) == "table" and stored or {}, Config.DefaultData),
		Loaded = true,
	}
	updateLeaderstats(player)
end

---------------------------------------------------------------------------
-- Training stations
---------------------------------------------------------------------------
local stationsFolder = workspace:WaitForChild("TrainingStations")
local training = {} -- [player] = { Station = model, Id = n, NextShot = t }
local leaveCooldown = {} -- [player] = time
local passCache = {} -- [player] = { [passId] = bool }

local function ownsPass(player, passId)
	if passId <= 0 then
		return false
	end
	passCache[player] = passCache[player] or {}
	local cached = passCache[player][passId]
	if cached ~= nil then
		return cached
	end
	local ok, owns = pcall(MarketplaceService.UserOwnsGamePassAsync, MarketplaceService, player.UserId, passId)
	if ok then
		passCache[player][passId] = owns
	end
	return ok and owns
end

MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, purchased)
	if purchased then
		passCache[player] = passCache[player] or {}
		passCache[player][passId] = true
		Notify:FireClient(player, "Thanks! Your new cannon is unlocked 🎉", Color3.fromRGB(255, 215, 70))
	end
end)

local function getRoot(player)
	local char = player.Character
	return char and char:FindFirstChild("HumanoidRootPart"), char and char:FindFirstChildOfClass("Humanoid")
end

local function stopTraining(player, stepOff)
	local state = training[player]
	if not state then
		return
	end
	training[player] = nil
	leaveCooldown[player] = os.clock()
	local root = getRoot(player)
	if root then
		root.Anchored = false
		if stepOff then
			-- move them back off the pad so they don't instantly re-trigger it
			local stand = state.Station.StandPoint.CFrame
			player.Character:PivotTo(stand * CFrame.new(0, 0, 7))
		end
	end
	TrainingState:FireClient(player, nil)
end

local function startTraining(player, station)
	local profile = profiles[player]
	local root, hum = getRoot(player)
	if not (profile and root and hum and hum.Health > 0) then
		return
	end
	if training[player] or player:GetAttribute("Launching") then
		return
	end
	if leaveCooldown[player] and os.clock() - leaveCooldown[player] < Config.STATION_LEAVE_COOLDOWN then
		return
	end

	local id = station:GetAttribute("StationId")
	local info = Config.GetStation(id)
	if not info then
		return
	end
	if info.GamePass then
		if not ownsPass(player, info.GamePass) then
			leaveCooldown[player] = os.clock()
			if info.GamePass > 0 then
				MarketplaceService:PromptGamePassPurchase(player, info.GamePass)
			else
				Notify:FireClient(player, "The " .. info.Name .. " is coming soon!", Color3.fromRGB(255, 200, 60))
			end
			return
		end
	elseif profile.Data.Rebirths < info.Rebirths then
		leaveCooldown[player] = os.clock()
		Notify:FireClient(player, "You need " .. info.Rebirths .. " Rebirths for the " .. info.Name .. "!", Color3.fromRGB(255, 90, 90))
		return
	end

	-- Lock in place in front of the cannon, facing the target
	local stand = station.StandPoint.CFrame
	local hipOffset = hum.HipHeight + root.Size.Y / 2
	player.Character:PivotTo(stand + Vector3.new(0, hipOffset, 0))
	root.AssemblyLinearVelocity = Vector3.zero
	root.Anchored = true

	training[player] = { Station = station, Id = id, NextShot = os.clock() + 0.4 }
	TrainingState:FireClient(player, id)
end

for _, station in ipairs(stationsFolder:GetChildren()) do
	local pad = station:FindFirstChild("Pad")
	if pad then
		pad.Touched:Connect(function(hit)
			local player = Players:GetPlayerFromCharacter(hit.Parent)
			if player then
				startTraining(player, station)
			end
		end)
	end
end

StopTraining.OnServerEvent:Connect(function(player)
	stopTraining(player, true)
end)

-- Shots
RunService.Heartbeat:Connect(function()
	local now = os.clock()
	for player, state in pairs(training) do
		local profile = profiles[player]
		local root, hum = getRoot(player)
		if not (profile and root and hum and hum.Health > 0) then
			training[player] = nil
		elseif now >= state.NextShot then
			state.NextShot = now + Config.SHOT_INTERVAL
			local gain = Config.ShotGain(Config.GetStation(state.Id), profile.Data.Rebirths)
			profile.Data.Strength += gain
			updateLeaderstats(player)
			TrainingShot:FireAllClients(player, state.Id, gain)
		end
	end
end)

---------------------------------------------------------------------------
-- Rebirth
---------------------------------------------------------------------------
RequestRebirth.OnServerEvent:Connect(function(player)
	local profile = profiles[player]
	if not profile or player:GetAttribute("Launching") then
		return
	end
	local cost = Config.RebirthCost(profile.Data.Rebirths)
	if profile.Data.Strength < cost then
		Notify:FireClient(player, "You need " .. Config.Format(cost) .. " Strength to rebirth!", Color3.fromRGB(255, 90, 90))
		return
	end
	stopTraining(player, true)
	profile.Data.Strength = 0
	profile.Data.Rebirths += 1
	updateLeaderstats(player)
	Notify:FireClient(player, "🔄 Rebirth " .. profile.Data.Rebirths .. "! Every shot is now stronger", Color3.fromRGB(120, 200, 255))
end)

---------------------------------------------------------------------------
-- Grand Cannon launch
---------------------------------------------------------------------------
local launchPoint = workspace:WaitForChild("LaunchPoint")
local prompt = launchPoint:FindFirstChildOfClass("ProximityPrompt")
local lastLaunch = {}

local function returnToLobby(player)
	local char = player.Character
	local spawn = workspace:FindFirstChildOfClass("SpawnLocation")
	if char and spawn then
		char:PivotTo(spawn.CFrame + Vector3.new(0, 4, 0))
	end
end

local function launch(player)
	local profile = profiles[player]
	local root, hum = getRoot(player)
	if not (profile and root and hum and hum.Health > 0) then
		return
	end
	if player:GetAttribute("Launching") then
		return
	end
	if lastLaunch[player] and os.clock() - lastLaunch[player] < Config.LAUNCH_COOLDOWN then
		return
	end
	stopTraining(player, false)
	lastLaunch[player] = os.clock()
	player:SetAttribute("Launching", true)

	local strength = profile.Data.Strength
	local origin = launchPoint.Position
	local flatDir = Config.LAUNCH_DIRECTION.Unit
	player.Character:PivotTo(CFrame.lookAt(origin, origin + flatDir))
	task.wait() -- let the teleport replicate before the client applies velocity
	LaunchPlayer:FireClient(player, Config.LaunchVelocity(strength))

	-- Track the flight from the server's view of the character
	local startTime = os.clock()
	local furthest = 0
	local stillFor = 0
	local last = os.clock()
	while player.Parent and os.clock() - startTime < Config.FLIGHT_TIMEOUT do
		task.wait(0.1)
		local now = os.clock()
		root = getRoot(player)
		if not root then
			break
		end
		local offset = root.Position - origin
		furthest = math.max(furthest, offset:Dot(flatDir))
		if now - startTime > 1 and root.AssemblyLinearVelocity.Magnitude < 4 then
			stillFor += now - last
			if stillFor > 0.3 then
				break
			end
		else
			stillFor = 0
		end
		last = now
	end
	if not player.Parent then
		return
	end

	local distance = math.floor(math.clamp(furthest, 0, Config.MaxRange(strength) * 1.15 + 50))
	local coins = math.floor(distance * Config.COINS_PER_STUD)
	local isBest = distance > profile.Data.BestDistance
	profile.Data.Coins += coins
	profile.Data.TotalLaunches += 1
	if isBest then
		profile.Data.BestDistance = distance
	end
	updateLeaderstats(player)
	LaunchResult:FireClient(player, distance, coins, isBest)

	task.wait(Config.RETURN_DELAY)
	if player.Parent then
		returnToLobby(player)
		player:SetAttribute("Launching", false)
	end
end

if prompt then
	prompt.Triggered:Connect(function(player)
		task.spawn(launch, player)
	end)
end

---------------------------------------------------------------------------
-- Lifecycle
---------------------------------------------------------------------------
Players.PlayerAdded:Connect(onPlayerAdded)
for _, p in ipairs(Players:GetPlayers()) do
	task.spawn(onPlayerAdded, p)
end

Players.PlayerRemoving:Connect(function(player)
	training[player] = nil
	leaveCooldown[player] = nil
	lastLaunch[player] = nil
	passCache[player] = nil
	save(player)
	profiles[player] = nil
end)

task.spawn(function()
	while true do
		task.wait(Config.AUTOSAVE_INTERVAL)
		for player in pairs(profiles) do
			task.spawn(save, player)
		end
	end
end)

game:BindToClose(function()
	local pending = 0
	for player in pairs(profiles) do
		pending += 1
		task.spawn(function()
			save(player)
			pending -= 1
		end)
	end
	local t = os.clock()
	while pending > 0 and os.clock() - t < 25 do
		task.wait(0.1)
	end
end)

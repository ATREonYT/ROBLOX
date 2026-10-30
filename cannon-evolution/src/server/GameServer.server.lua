--[[
	GameServer  (Script)  ->  ServerScriptService > GameServer

	All game rules live here; the client only asks (Remotes.Request) and shows.
	Sections: remotes, data, sync, helpers, rewards, training, launch, rebirth,
	upgrades, pets & eggs, cannons, worlds, missions, daily/playtime, codes,
	boosts, purchases, orbs, leaderboards, lifecycle.
]]

local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")

local Config = require(ReplicatedStorage:WaitForChild("GameConfig"))
local IS_STUDIO = RunService:IsStudio()

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
local Request = remote("Request", "RemoteFunction") -- C->S: action, ... -> ok, message
local Sync = remote("Sync") -- S->C: data snapshot
local Notify = remote("Notify") -- S->C: text, color
local TrainingState = remote("TrainingState") -- S->C: stationId | nil
local TrainingShot = remote("TrainingShot") -- S->All: player, stationId, gain, crit
local LaunchPlayer = remote("LaunchPlayer") -- S->C: velocity
local LaunchResult = remote("LaunchResult") -- S->C: distance, cash, gems, isBest
local Hatched = remote("Hatched") -- S->C: eggId, { petKey, ... }
local Leaderboards = remote("Leaderboards") -- S->All: { [boardId] = { {Name, Value}, ... } }
local OfflineEarnings = remote("OfflineEarnings") -- S->C: power, seconds
local Rewarded = remote("Rewarded") -- S->C: list of { Icon, Text } for a reward popup
local Unlocked = remote("Unlocked") -- S->C: title, icon, line for the "UNLOCKED!" celebration
remotes.Parent = ReplicatedStorage

---------------------------------------------------------------------------
-- Data
---------------------------------------------------------------------------
local store = DataStoreService:GetDataStore(Config.DATASTORE_NAME)
local profiles = {} -- [player] = { Data, Loaded, JoinTime, PlaytimeClaimed = {}, Passes = {} }

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
		elseif type(v) == "table" and type(data[k]) == "table" and next(v) ~= nil and #v == 0 then
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

-- Studio test switch: set the attribute FreshSaveTest on Workspace to play as a brand-new player.
-- Your real save is neither loaded nor overwritten while it's on.
local function freshSaveTest()
	return IS_STUDIO and workspace:GetAttribute("FreshSaveTest") == true
end

local function save(player)
	local profile = profiles[player]
	if not (profile and profile.Loaded) or freshSaveTest() then
		return
	end
	profile.Data.LastOnline = os.time()
	withRetries(function()
		store:UpdateAsync("Player_" .. player.UserId, function()
			return profile.Data
		end)
	end)
end

---------------------------------------------------------------------------
-- Gamepasses
---------------------------------------------------------------------------
-- Ownership is fetched once on join (loadPasses) so hasPass never yields.
local function hasPass(player, key)
	local profile = profiles[player]
	return profile ~= nil and profile.Passes[key] == true
end

local function loadPasses(player)
	local profile = profiles[player]
	for key, pass in pairs(Config.Passes) do
		if pass.Id > 0 then
			local ok, owns = pcall(MarketplaceService.UserOwnsGamePassAsync, MarketplaceService, player.UserId, pass.Id)
			profile.Passes[key] = ok and owns or false
		elseif IS_STUDIO and Config.TEST_PURCHASES_IN_STUDIO then
			profile.Passes[key] = profile.Data.Products["Pass_" .. key] == true
		end
	end
end

local function boostActive(profile, id)
	return (profile.Data.Boosts[id] or 0) > 0
end

---------------------------------------------------------------------------
-- Sync to client
---------------------------------------------------------------------------
local dirty = {}

local function markDirty(player)
	dirty[player] = true
end

local function snapshot(player)
	local profile = profiles[player]
	local data = profile.Data
	local passes = {}
	for key in pairs(Config.Passes) do
		passes[key] = hasPass(player, key)
	end
	-- dense array: sparse number keys don't survive a remote
	local claimed = {}
	for i = 1, #Config.PlaytimeRewards do
		claimed[i] = profile.PlaytimeClaimed[i] == true
	end
	local shared = table.clone(data)
	shared.Receipts = nil
	shared.Codes = nil
	return {
		Data = shared,
		Passes = passes,
		Playtime = os.clock() - profile.JoinTime,
		PlaytimeClaimed = claimed,
		ServerTime = os.time(),
		AutoLaunch = player:GetAttribute("AutoLaunch") == true,
	}
end

local function updateLeaderstats(player)
	local profile = profiles[player]
	local ls = player:FindFirstChild("leaderstats")
	if not (profile and ls) then
		return
	end
	ls.Power.Value = profile.Data.Power
	ls.Rebirths.Value = profile.Data.Rebirths
	ls.Cash.Value = profile.Data.Cash
end

RunService.Heartbeat:Connect(function()
	for player in pairs(dirty) do
		dirty[player] = nil
		if profiles[player] and player.Parent then
			updateLeaderstats(player)
			Sync:FireClient(player, snapshot(player))
		end
	end
end)

local function notify(player, text, color)
	Notify:FireClient(player, text, color)
end

local RED = Color3.fromRGB(255, 90, 90)
local GOLD = Color3.fromRGB(255, 215, 70)
local GREEN = Color3.fromRGB(120, 255, 140)

---------------------------------------------------------------------------
-- Currency + stats helpers
---------------------------------------------------------------------------
local addPet -- defined in pets section

local function addCash(player, amount)
	local profile = profiles[player]
	amount = math.floor(amount)
	profile.Data.Cash += amount
	profile.Data.Stats.CashEarned += amount
	markDirty(player)
end

local function addGems(player, amount)
	local profile = profiles[player]
	if hasPass(player, "VIP") then
		amount *= 1.5
	end
	profile.Data.Gems += math.floor(amount)
	markDirty(player)
end

local function addBoost(player, id, minutes)
	local boosts = profiles[player].Data.Boosts
	local ids = id == "All" and { "Power", "Cash", "Luck" } or { id }
	for _, b in ipairs(ids) do
		boosts[b] = (boosts[b] or 0) + minutes * 60
	end
	markDirty(player)
end

-- Grants a reward table like { Cash = 10, Gems = 5, CashMinutes = 3, Boost = "Power", Minutes = 15, Pet = "dog" }
local function grantReward(player, reward, scale)
	local profile = profiles[player]
	local data = profile.Data
	scale = scale or 1
	local shown = {}
	if reward.Cash then
		addCash(player, reward.Cash * scale)
		table.insert(shown, { Icon = "Cash", Text = "+" .. Config.Format(reward.Cash * scale) .. " Cash" })
	end
	if reward.CashMinutes then
		local amount = Config.CashPerMinute(data) * reward.CashMinutes * scale
		addCash(player, amount)
		table.insert(shown, { Icon = "CashLarge", Text = "+" .. Config.Format(amount) .. " Cash" })
	end
	if reward.PowerMinutes then
		local amount = Config.PowerPerMinute(data, hasPass(player, "VIP")) * reward.PowerMinutes * scale
		data.Power += math.floor(amount)
		table.insert(shown, { Icon = "PowerLarge", Text = "+" .. Config.Format(amount) .. " Power" })
	end
	if reward.Gems then
		addGems(player, reward.Gems * scale)
		table.insert(shown, { Icon = "Gem", Text = "+" .. Config.Format(reward.Gems * scale) .. " Gems" })
	end
	if reward.Boost then
		addBoost(player, reward.Boost, reward.Minutes or 15)
		table.insert(shown, { Icon = "PotionRed", Text = (reward.Boost == "All" and "All" or "2x " .. reward.Boost) .. " Boost " .. (reward.Minutes or 15) .. "m" })
	end
	if reward.Pet then
		addPet(player, reward.Pet)
		local info = Config.Pets[reward.Pet]
		table.insert(shown, { Icon = "Favorite", Text = (info and info.Name or reward.Pet) .. " Pet!", Pet = reward.Pet })
	end
	markDirty(player)
	if #shown > 0 then
		Rewarded:FireClient(player, shown)
	end
end

---------------------------------------------------------------------------
-- Character helpers
---------------------------------------------------------------------------
local function getRoot(player)
	local char = player.Character
	return char and char:FindFirstChild("HumanoidRootPart"), char and char:FindFirstChildOfClass("Humanoid")
end

local function applyWalkSpeed(player)
	local profile = profiles[player]
	local _, hum = getRoot(player)
	if profile and hum then
		hum.WalkSpeed = 16 + Config.Level(profile.Data, "Speed")
	end
end

local function lobbySpawnCFrame()
	local spawn = workspace:FindFirstChildOfClass("SpawnLocation")
	return spawn and spawn.CFrame + Vector3.new(0, 4, 0) or CFrame.new(0, 20, 0)
end

---------------------------------------------------------------------------
-- Training stations
---------------------------------------------------------------------------
local stationsFolder = workspace:WaitForChild("TrainingStations")
local training = {} -- [player] = { Station, Id, NextShot }
local leaveCooldown = {}

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
			player.Character:PivotTo(state.Station.StandPoint.CFrame * CFrame.new(0, 3, 7))
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
	local info = Config.Stations[station:GetAttribute("StationId")]
	if not info then
		return
	end
	leaveCooldown[player] = os.clock()
	if info.Pass then
		if not hasPass(player, info.Pass) then
			local pass = Config.Passes[info.Pass]
			if pass.Id > 0 then
				MarketplaceService:PromptGamePassPurchase(player, pass.Id)
			else
				notify(player, "The " .. info.Name .. " needs the " .. pass.Name .. " gamepass!", GOLD)
			end
			return
		end
	elseif profile.Data.Rebirths < info.Rebirths then
		notify(player, "You need " .. info.Rebirths .. " Rebirths for the " .. info.Name .. "!", RED)
		return
	end

	local stand = station.StandPoint.CFrame
	player.Character:PivotTo(stand + Vector3.new(0, hum.HipHeight + root.Size.Y / 2, 0))
	root.AssemblyLinearVelocity = Vector3.zero
	root.Anchored = true
	training[player] = { Station = station, Id = info.Id, NextShot = os.clock() + 0.4 }
	TrainingState:FireClient(player, info.Id)
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

local function shotPower(player, stationInfo)
	local profile = profiles[player]
	local data = profile.Data
	local gain = stationInfo.Gain * Config.PowerMultiplier(data)
	if hasPass(player, "DoublePower") then
		gain *= 2
	end
	if boostActive(profile, "Power") then
		gain *= 2
	end
	local crit = math.random() < Config.CritChance(data)
	if crit then
		gain *= 5
	end
	return math.max(1, math.floor(gain)), crit
end

RunService.Heartbeat:Connect(function()
	local now = os.clock()
	for player, state in pairs(training) do
		local profile = profiles[player]
		local root, hum = getRoot(player)
		if not (profile and root and hum and hum.Health > 0) then
			training[player] = nil
		elseif now >= state.NextShot then
			state.NextShot = now + Config.ShotInterval(profile.Data)
			local info = Config.Stations[state.Id]
			local gain, crit = shotPower(player, info)
			profile.Data.Power += gain
			profile.Data.Stats.Shots += 1
			markDirty(player)
			TrainingShot:FireAllClients(player, state.Id, gain, crit)
		end
	end
end)

---------------------------------------------------------------------------
-- Grand Cannon launch
---------------------------------------------------------------------------
local launchPoint = workspace:WaitForChild("LaunchPoint")
local launchZone = workspace:FindFirstChild("LaunchZone")
local lastLaunch = {}

-- Furthest the track goes along LAUNCH_DIRECTION from the Grand Cannon
local trackLength = (function()
	local cf, size = workspace.map1b:GetBoundingBox()
	local far = cf.Position + Config.LAUNCH_DIRECTION.Unit * size.X / 2
	return math.max((far - launchPoint.Position):Dot(Config.LAUNCH_DIRECTION.Unit) - 60, 200)
end)()

-- Stone Skipping style: the Grand Cannon fires a cannonball that skims the
-- water down the track. The server decides the distance and the reward up
-- front, every client plays the ball (the owner's camera follows it), and
-- the reward lands when the ball stops.
local function cashFor(player, profile, distance)
	local cash = distance * Config.CASH_PER_STUD * Config.CashMultiplier(profile.Data)
	if hasPass(player, "DoubleCash") then
		cash *= 2
	end
	if boostActive(profile, "Cash") then
		cash *= 2
	end
	return math.floor(cash)
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

	local data = profile.Data
	local maxRange = Config.MaxRange(data.Power, Config.RangeMultiplier(data))
	local distance = math.floor(math.clamp(maxRange * (0.9 + math.random() * 0.1), Config.MIN_LAUNCH_DISTANCE, trackLength))
	local duration = Config.FlightTime(distance)
	local cash = cashFor(player, profile, distance)
	local walkSpeed = hum.WalkSpeed
	hum.WalkSpeed = 0
	LaunchPlayer:FireAllClients(player, launchPoint.Position, distance, duration, cash)

	local startTime = os.clock()
	while player.Parent and os.clock() - startTime < duration + 0.2 do
		task.wait(0.1)
	end
	if not (player.Parent and profiles[player]) then
		return
	end

	local gems = 0
	if math.random() < Config.GEM_CHANCE_PER_LAUNCH then
		gems = math.random(1, 3)
		addGems(player, gems)
	end
	local isBest = distance > data.BestDistance
	addCash(player, cash)
	data.TotalLaunches += 1
	data.Stats.Launches += 1
	if isBest then
		data.BestDistance = distance
	end
	markDirty(player)
	LaunchResult:FireClient(player, distance, cash, gems, isBest)

	task.wait(Config.RETURN_DELAY)
	root, hum = getRoot(player)
	if hum then
		hum.WalkSpeed = walkSpeed
	end
	-- step back out of the Launch Zone so walking in again throws again
	if root and launchZone and (root.Position - launchZone.Position).Magnitude < 20 then
		local back = launchZone.Position + Config.LAUNCH_DIRECTION.Unit * (launchZone.Size.X / 2 + 6) + Vector3.new(0, 3, 0)
		player.Character:PivotTo(CFrame.lookAt(back, back - Config.LAUNCH_DIRECTION.Unit))
	end
	player:SetAttribute("Launching", false)
end

if launchZone then
	launchZone.Touched:Connect(function(hit)
		local player = Players:GetPlayerFromCharacter(hit.Parent)
		if player and not training[player] and not player:GetAttribute("Launching") then
			task.spawn(launch, player)
		end
	end)
end

-- Auto Launch gamepass
task.spawn(function()
	while true do
		task.wait(1)
		for player, profile in pairs(profiles) do
			if player:GetAttribute("AutoLaunch") and not training[player] and not player:GetAttribute("Launching") then
				if hasPass(player, "AutoLaunch") and (not lastLaunch[player] or os.clock() - lastLaunch[player] > Config.AUTO_LAUNCH_INTERVAL) then
					task.spawn(launch, player)
				end
			end
		end
	end
end)

---------------------------------------------------------------------------
-- Rebirth
---------------------------------------------------------------------------
-- Give every rebirth cannon the player has reached, and equip the best one
-- they own when a new one arrives (they can still switch in the Cannons menu).
local function grantRebirthCannons(player)
	local data = profiles[player].Data
	local newest
	for _, c in ipairs(Config.Cannons) do
		if c.Currency == "Rebirth" and data.Rebirths >= c.Rebirths and not data.Cannons[c.Id] then
			data.Cannons[c.Id] = true
			newest = c
		end
	end
	if newest then
		data.EquippedCannon = Config.BestCannon(data).Id
		markDirty(player)
	end
	return newest
end

local function doRebirth(player, free)
	local profile = profiles[player]
	local data = profile.Data
	local powerCost, cashCost = Config.RebirthCost(data.Rebirths)
	if not free and (data.Power < powerCost or data.Cash < cashCost) then
		return false, "You need " .. Config.Format(powerCost) .. " Power and " .. Config.Format(cashCost) .. " Cash!"
	end
	stopTraining(player, true)
	data.Power = 0
	data.Cash = 0
	data.Rebirths += 1
	data.Stats.Rebirths += 1
	markDirty(player)
	notify(player, "🔄 Rebirth " .. data.Rebirths .. "! +50% Power forever", Color3.fromRGB(120, 200, 255))
	local cannon = grantRebirthCannons(player)
	if cannon then
		Unlocked:FireClient(player, cannon.Id .. " Cannon", "Evolve", "Unlocked and equipped! It's waiting at the Launch Zone")
	end
	return true
end

---------------------------------------------------------------------------
-- Upgrades
---------------------------------------------------------------------------
local function buyUpgrade(player, id)
	local profile = profiles[player]
	local upgrade = Config.FindUpgrade(id)
	if not upgrade then
		return false
	end
	local level = Config.Level(profile.Data, id)
	if level >= upgrade.Max then
		return false, "Max level!"
	end
	local cost = Config.UpgradeCost(upgrade, level)
	if profile.Data.Cash < cost then
		return false, "Not enough Cash!"
	end
	profile.Data.Cash -= cost
	profile.Data.Upgrades[id] = level + 1
	if id == "Speed" then
		applyWalkSpeed(player)
	end
	markDirty(player)
	return true
end

---------------------------------------------------------------------------
-- Pets & eggs
---------------------------------------------------------------------------
local function maxEquipped(player)
	return Config.MAX_EQUIPPED + (hasPass(player, "ExtraEquip") and Config.EXTRA_EQUIP or 0)
end

local function refreshPetAttribute(player)
	local names = {}
	for _, pet in ipairs(profiles[player].Data.Pets) do
		if pet.Equipped then
			table.insert(names, pet.Name)
		end
	end
	player:SetAttribute("EquippedPets", table.concat(names, ","))
end

function addPet(player, petKey)
	local data = profiles[player].Data
	if not Config.Pets[petKey] then
		return
	end
	local pet = { Id = data.NextPetUid, Name = petKey, Equipped = false }
	data.NextPetUid += 1
	table.insert(data.Pets, pet)
	-- auto-equip if a slot is free
	local equipped = 0
	for _, p in ipairs(data.Pets) do
		if p.Equipped then
			equipped += 1
		end
	end
	if equipped < maxEquipped(player) then
		pet.Equipped = true
		refreshPetAttribute(player)
	end
	markDirty(player)
	return pet
end

local function rollPet(player, egg)
	local profile = profiles[player]
	local luck = Config.LuckMultiplier(profile.Data)
	if hasPass(player, "Lucky") then
		luck *= 2
	end
	if boostActive(profile, "Luck") then
		luck *= 2
	end
	-- luck multiplies the weight of every pet except the most common one,
	-- more for rarer ones
	local weights, total = {}, 0
	for i, entry in ipairs(egg.Pets) do
		local w = entry[2] * (i == 1 and 1 or luck ^ math.min(i - 1, 3))
		weights[i] = w
		total += w
	end
	local roll = math.random() * total
	for i, entry in ipairs(egg.Pets) do
		roll -= weights[i]
		if roll <= 0 then
			return entry[1]
		end
	end
	return egg.Pets[1][1]
end

local function hatch(player, egg, count, paid)
	local profile = profiles[player]
	local data = profile.Data
	if #data.Pets + count > Config.MAX_PETS then
		return false, "Your pet inventory is full! Delete some pets."
	end
	if not paid then
		local cost = egg.Price * count
		local currency = egg.Currency
		if data[currency] < cost then
			return false, "Not enough " .. currency .. "!"
		end
		data[currency] -= cost
	end
	local results = {}
	for _ = 1, count do
		local key = rollPet(player, egg)
		addPet(player, key)
		table.insert(results, key)
	end
	data.Stats.Hatches += count
	markDirty(player)
	Hatched:FireClient(player, egg.Id, results)
	return true
end

local function findPet(data, uid)
	for i, pet in ipairs(data.Pets) do
		if pet.Id == uid then
			return pet, i
		end
	end
end

local function equipPet(player, uid, equip)
	local data = profiles[player].Data
	local pet = findPet(data, uid)
	if not pet then
		return false
	end
	if equip then
		local equipped = 0
		for _, p in ipairs(data.Pets) do
			if p.Equipped then
				equipped += 1
			end
		end
		if equipped >= maxEquipped(player) then
			return false, "All pet slots are full!"
		end
	end
	pet.Equipped = equip and true or false
	refreshPetAttribute(player)
	markDirty(player)
	return true
end

local function equipBest(player)
	local data = profiles[player].Data
	for _, p in ipairs(data.Pets) do
		p.Equipped = false
	end
	local sorted = table.clone(data.Pets)
	table.sort(sorted, function(a, b)
		return (Config.Pets[a.Name] and Config.Pets[a.Name].Boost or 0) > (Config.Pets[b.Name] and Config.Pets[b.Name].Boost or 0)
	end)
	for i = 1, math.min(maxEquipped(player), #sorted) do
		sorted[i].Equipped = true
	end
	refreshPetAttribute(player)
	markDirty(player)
	return true
end

local function deletePet(player, uid)
	local data = profiles[player].Data
	local _, index = findPet(data, uid)
	if not index then
		return false
	end
	table.remove(data.Pets, index)
	refreshPetAttribute(player)
	markDirty(player)
	return true
end

---------------------------------------------------------------------------
-- Cannons
---------------------------------------------------------------------------
local function buyCannon(player, id)
	local data = profiles[player].Data
	local cannon = Config.GetCannon(id)
	if not cannon or data.Cannons[id] then
		return false
	end
	if cannon.Currency == "Robux" then
		return false, "Buy this one in the shop!"
	end
	if cannon.Currency == "Rebirth" then
		return false, "Rebirth " .. cannon.Rebirths .. " times to unlock it!"
	end
	if cannon.Currency ~= "Free" then
		if data[cannon.Currency] < cannon.Price then
			return false, "Not enough " .. cannon.Currency .. "!"
		end
		data[cannon.Currency] -= cannon.Price
	end
	data.Cannons[id] = true
	data.EquippedCannon = id
	markDirty(player)
	return true
end

local function equipCannon(player, id)
	local data = profiles[player].Data
	if not data.Cannons[id] then
		return false
	end
	data.EquippedCannon = id
	markDirty(player)
	return true
end

---------------------------------------------------------------------------
-- Worlds
---------------------------------------------------------------------------
local function teleportToWorld(player, worldId)
	local world = Config.Worlds[worldId]
	local profile = profiles[player]
	if not world or not player.Character then
		return false
	end
	if profile.Data.Rebirths < world.Rebirths then
		return false, "Needs " .. world.Rebirths .. " Rebirths!"
	end
	stopTraining(player, false)
	if worldId == 1 then
		player.Character:PivotTo(lobbySpawnCFrame())
		return true
	end
	local zone = workspace.map1b.StoneSkipMap:FindFirstChild(world.Zone)
	if not zone then
		return false, "World not found"
	end
	local cf, size = zone:GetBoundingBox()
	local top = cf.Position + Vector3.new(0, size.Y / 2 + 50, 0)
	local hit = workspace:Raycast(top, Vector3.new(0, -size.Y - 100, 0))
	local pos = hit and hit.Position + Vector3.new(0, 4, 0) or top
	player.Character:PivotTo(CFrame.lookAt(pos, pos + Config.LAUNCH_DIRECTION))
	return true
end

---------------------------------------------------------------------------
-- Missions
---------------------------------------------------------------------------
local function periodKeys()
	local now = os.time()
	local daily = os.date("!%Y-%m-%d", now)
	local weekly = "W" .. math.floor((now + 3 * 86400) / (7 * 86400)) -- weeks start Monday
	return daily, weekly
end

local function statValue(data, stat)
	if stat == "Distance" then
		return data.BestDistance
	end
	return data.Stats[stat] or 0
end

local function refreshMissions(data)
	local m = data.Missions
	local daily, weekly = periodKeys()
	if m.DailyKey ~= daily then
		m.DailyKey = daily
		m.Daily = {}
		for _, def in ipairs(Config.Missions.Daily) do
			m.Daily[def.Id] = { Base = statValue(data, def.Stat), Claimed = false }
		end
	end
	if m.WeeklyKey ~= weekly then
		m.WeeklyKey = weekly
		m.Weekly = {}
		for _, def in ipairs(Config.Missions.Weekly) do
			m.Weekly[def.Id] = { Base = statValue(data, def.Stat), Claimed = false }
		end
	end
	for _, def in ipairs(Config.Missions.Infinite) do
		if not m.Infinite[def.Id] then
			m.Infinite[def.Id] = { Tier = 1, Base = statValue(data, def.Stat) }
		end
	end
end

local function claimMission(player, category, id)
	local data = profiles[player].Data
	refreshMissions(data)
	local defs = Config.Missions[category]
	if not defs then
		return false
	end
	local def
	for _, d in ipairs(defs) do
		if d.Id == id then
			def = d
		end
	end
	local state = def and data.Missions[category][id]
	if not state then
		return false
	end
	local progress = statValue(data, def.Stat) - state.Base
	if category == "Infinite" then
		local goal = math.floor(def.Goal * def.GoalGrowth ^ (state.Tier - 1))
		if progress < goal then
			return false, "Not done yet!"
		end
		grantReward(player, def.Reward, state.Tier)
		state.Tier += 1
		state.Base = statValue(data, def.Stat)
	else
		if state.Claimed then
			return false, "Already claimed!"
		end
		if progress < def.Goal then
			return false, "Not done yet!"
		end
		state.Claimed = true
		grantReward(player, def.Reward)
	end
	markDirty(player)
	return true
end

---------------------------------------------------------------------------
-- Daily + playtime rewards, codes, boosts
---------------------------------------------------------------------------
local function claimDaily(player)
	local daily = profiles[player].Data.Daily
	local now = os.time()
	if now - daily.LastClaim < Config.DAILY_COOLDOWN then
		return false, "Come back in " .. Config.FormatTime(Config.DAILY_COOLDOWN - (now - daily.LastClaim))
	end
	if daily.LastClaim > 0 and now - daily.LastClaim > Config.DAILY_STREAK_RESET then
		daily.Streak = 0
	end
	local day = daily.Streak % #Config.DailyRewards + 1
	daily.Streak += 1
	daily.LastClaim = now
	grantReward(player, Config.DailyRewards[day].Reward)
	return true
end

local function claimPlaytime(player, index)
	local profile = profiles[player]
	local info = Config.PlaytimeRewards[index]
	if not info or profile.PlaytimeClaimed[index] then
		return false
	end
	if os.clock() - profile.JoinTime < info.Minutes * 60 then
		return false, "Keep playing to unlock this!"
	end
	profile.PlaytimeClaimed[index] = true
	grantReward(player, info.Reward)
	return true
end

local function redeemCode(player, code)
	local data = profiles[player].Data
	code = string.upper(tostring(code or "")):gsub("%s", "")
	local reward = Config.Codes[code]
	if not reward then
		return false, "Invalid code"
	end
	if data.Codes[code] then
		return false, "Already redeemed!"
	end
	data.Codes[code] = true
	grantReward(player, reward)
	return true, "Code redeemed!"
end

local function buyBoost(player, id)
	local data = profiles[player].Data
	for _, boost in ipairs(Config.Boosts) do
		if boost.Id == id then
			if data.Gems < boost.Gems then
				return false, "Not enough Gems!"
			end
			data.Gems -= boost.Gems
			addBoost(player, id, boost.Minutes)
			return true, boost.Name .. " active!"
		end
	end
	return false
end

-- Boost timers tick while online
task.spawn(function()
	while true do
		task.wait(1)
		for player, profile in pairs(profiles) do
			local any = false
			for id, left in pairs(profile.Data.Boosts) do
				if left > 0 then
					profile.Data.Boosts[id] = math.max(0, left - 1)
					any = true
				end
			end
			if any then
				markDirty(player)
			end
		end
	end
end)

---------------------------------------------------------------------------
-- Purchases (gamepasses + developer products)
---------------------------------------------------------------------------
local function grantProduct(player, key)
	local product = Config.Products[key]
	local profile = profiles[player]
	if not (product and profile) then
		return false
	end
	local g = product.Grant
	if g.Rebirth then
		doRebirth(player, true)
	end
	if g.Egg then
		hatch(player, Config.GetEgg(g.Egg), g.Count or 1, true)
	end
	if g.Cannon then
		profile.Data.Cannons[g.Cannon] = true
		profile.Data.EquippedCannon = g.Cannon
		Unlocked:FireClient(player, g.Cannon .. " Cannon", "Evolve", "Unlocked and equipped!")
	end
	local reward = {}
	for _, k in ipairs({ "Cash", "CashMinutes", "PowerMinutes", "Gems", "Pet" }) do
		reward[k] = g[k]
	end
	if next(reward) then
		grantReward(player, reward)
	end
	markDirty(player)
	return true
end

local productById = {}
for key, product in pairs(Config.Products) do
	if product.Id > 0 then
		productById[product.Id] = key
	end
end

MarketplaceService.ProcessReceipt = function(receipt)
	local player = Players:GetPlayerByUserId(receipt.PlayerId)
	local profile = player and profiles[player]
	if not profile then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	if profile.Data.Receipts[receipt.PurchaseId] then
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end
	local key = productById[receipt.ProductId]
	if not key or not grantProduct(player, key) then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	profile.Data.Receipts[receipt.PurchaseId] = true
	save(player)
	return Enum.ProductPurchaseDecision.PurchaseGranted
end

MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, purchased)
	if not purchased or not profiles[player] then
		return
	end
	for key, pass in pairs(Config.Passes) do
		if pass.Id == passId then
			profiles[player].Passes[key] = true
			Unlocked:FireClient(player, pass.Name, pass.Icon, pass.Desc or "Thank you for the support!")
			if key == "ExtraEquip" then
				refreshPetAttribute(player)
			end
		end
	end
	markDirty(player)
end)

local function purchase(player, kind, key)
	local profile = profiles[player]
	local item = kind == "Pass" and Config.Passes[key] or Config.Products[key]
	if not item then
		return false
	end
	if kind == "Pass" and hasPass(player, key) then
		return false, "You already own this!"
	end
	if item.ComingSoon then
		return false, "Coming soon!"
	end
	if item.Id > 0 then
		if kind == "Pass" then
			MarketplaceService:PromptGamePassPurchase(player, item.Id)
		else
			MarketplaceService:PromptProductPurchase(player, item.Id)
		end
		return true
	end
	-- No id yet: free test purchase in Studio, "coming soon" live
	if IS_STUDIO and Config.TEST_PURCHASES_IN_STUDIO then
		if kind == "Pass" then
			profile.Data.Products["Pass_" .. key] = true
			profile.Passes[key] = true
			Unlocked:FireClient(player, item.Name, item.Icon, "[Studio test] " .. (item.Desc or ""))
			markDirty(player)
		else
			grantProduct(player, key)
		end
		return true
	end
	return false, "Coming soon!"
end

---------------------------------------------------------------------------
-- Cash orbs around the lobby
---------------------------------------------------------------------------
local orbFolder = Instance.new("Folder")
orbFolder.Name = "Orbs"
orbFolder.Parent = workspace

local function lobbyArea()
	local lobby = workspace.map1b.StoneSkipMap:FindFirstChild("Lobby")
	if lobby then
		return lobby:GetBoundingBox()
	end
	return CFrame.new(), Vector3.new(60, 10, 60)
end

local function collectOrb(player, orb)
	if not orb.Parent or orb:GetAttribute("Taken") or not profiles[player] then
		return
	end
	orb:SetAttribute("Taken", true)
	if orb:GetAttribute("Gem") then
		addGems(player, 1)
	else
		addCash(player, math.max(5, Config.CashPerMinute(profiles[player].Data) * 0.05))
	end
	orb:Destroy()
end

local function spawnOrb()
	local cf, size = lobbyArea()
	for _ = 1, 10 do
		local p = cf.Position + Vector3.new((math.random() - 0.5) * size.X * 0.8, size.Y, (math.random() - 0.5) * size.Z * 0.8)
		local hit = workspace:Raycast(p, Vector3.new(0, -size.Y * 2, 0))
		if hit and not hit.Instance:IsDescendantOf(stationsFolder) then
			local isGem = math.random() < Config.ORB_GEM_CHANCE
			local orb = Instance.new("Part")
			orb.Shape = Enum.PartType.Ball
			orb.Size = Vector3.one * 1.6
			orb.Material = Enum.Material.Neon
			orb.Color = isGem and Color3.fromRGB(220, 80, 255) or Color3.fromRGB(90, 230, 90)
			orb.Anchored = true
			orb.CanCollide = false
			orb.Position = hit.Position + Vector3.new(0, 2, 0)
			orb:SetAttribute("Gem", isGem)
			orb.Touched:Connect(function(h)
				local player = Players:GetPlayerFromCharacter(h.Parent)
				if player then
					collectOrb(player, orb)
				end
			end)
			orb.Parent = orbFolder
			return
		end
	end
end

task.spawn(function()
	while Config.ORB_COUNT > 0 do
		if #orbFolder:GetChildren() < Config.ORB_COUNT then
			spawnOrb()
		end
		-- Auto Collect pass: pull in nearby orbs
		for player in pairs(profiles) do
			local root = getRoot(player)
			if root and hasPass(player, "AutoCollect") then
				for _, orb in ipairs(orbFolder:GetChildren()) do
					if (orb.Position - root.Position).Magnitude < Config.ORB_AUTO_RANGE then
						collectOrb(player, orb)
					end
				end
			end
		end
		task.wait(Config.ORB_RESPAWN / Config.ORB_COUNT)
	end
end)

---------------------------------------------------------------------------
-- Leaderboards
---------------------------------------------------------------------------
local boardStores = {}
for _, board in ipairs(Config.LEADERBOARDS) do
	boardStores[board.Id] = DataStoreService:GetOrderedDataStore(Config.DATASTORE_NAME .. "_LB_" .. board.Id)
end
local nameCache = {}
local latestBoards = {}

local function nameFor(userId)
	if nameCache[userId] then
		return nameCache[userId]
	end
	local ok, name = pcall(Players.GetNameFromUserIdAsync, Players, userId)
	nameCache[userId] = ok and name or "Player"
	return nameCache[userId]
end

local function refreshLeaderboards()
	for player, profile in pairs(profiles) do
		if profile.Loaded and not freshSaveTest() then
			for _, board in ipairs(Config.LEADERBOARDS) do
				-- ordered stores hold integers below 2^53, so store log10 to fit
				-- numbers of any size while keeping the order
				local value = math.max(0, profile.Data[board.Stat] or 0)
				local stored = math.floor(math.log10(value + 1) * 1e13)
				pcall(boardStores[board.Id].SetAsync, boardStores[board.Id], tostring(player.UserId), stored)
			end
		end
	end
	local result = {}
	for _, board in ipairs(Config.LEADERBOARDS) do
		local ok, pages = pcall(boardStores[board.Id].GetSortedAsync, boardStores[board.Id], false, 10)
		local rows = {}
		if ok then
			for _, entry in ipairs(pages:GetCurrentPage()) do
				local value = math.floor(10 ^ (entry.value / 1e13) - 1 + 0.5)
				table.insert(rows, { Name = nameFor(tonumber(entry.key)), Value = value })
			end
		end
		result[board.Id] = rows
	end
	latestBoards = result
	Leaderboards:FireAllClients(result)
end

task.spawn(function()
	task.wait(10)
	while true do
		refreshLeaderboards()
		task.wait(Config.LEADERBOARD_REFRESH)
	end
end)

---------------------------------------------------------------------------
-- Request router
---------------------------------------------------------------------------
local actions = {
	StopTraining = function(player)
		stopTraining(player, true)
		return true
	end,
	Rebirth = function(player)
		return doRebirth(player, false)
	end,
	BuyUpgrade = buyUpgrade,
	Hatch = function(player, eggId, count)
		local egg = Config.GetEgg(eggId)
		if not egg or egg.Currency == "Robux" then
			return false
		end
		count = (count == 3 and hasPass(player, "TripleOpen")) and 3 or 1
		return hatch(player, egg, count, false)
	end,
	EquipPet = equipPet,
	EquipBest = equipBest,
	DeletePet = deletePet,
	BuyCannon = buyCannon,
	EquipCannon = equipCannon,
	Teleport = teleportToWorld,
	ClaimMission = claimMission,
	ClaimDaily = claimDaily,
	ClaimPlaytime = claimPlaytime,
	RedeemCode = redeemCode,
	BuyBoost = buyBoost,
	Purchase = purchase,
	SetSetting = function(player, key, value)
		local settings = profiles[player].Data.Settings
		if settings[key] ~= nil and type(value) == "boolean" then
			settings[key] = value
			markDirty(player)
			return true
		end
		return false
	end,
	SetAutoLaunch = function(player, on)
		if on and not hasPass(player, "AutoLaunch") then
			return purchase(player, "Pass", "AutoLaunch")
		end
		player:SetAttribute("AutoLaunch", on == true)
		markDirty(player)
		return true
	end,
	SetTutorial = function(player, step)
		local data = profiles[player].Data
		if type(step) == "number" and step > data.Tutorial and step <= 20 then
			data.Tutorial = math.floor(step)
			markDirty(player)
		end
		return true
	end,
	GetLeaderboards = function()
		return latestBoards
	end,
}

local requestCooldown = {}
Request.OnServerInvoke = function(player, action, ...)
	local profile = profiles[player]
	local fn = actions[action]
	if not (profile and profile.Loaded and fn) then
		return false
	end
	-- light rate limit
	local now = os.clock()
	if requestCooldown[player] and now - requestCooldown[player] < 0.08 then
		return false
	end
	requestCooldown[player] = now
	local ok, result, message = pcall(fn, player, ...)
	if not ok then
		warn("[GameServer] " .. action .. " failed: " .. tostring(result))
		return false
	end
	if result == false and message then
		notify(player, message, RED)
	elseif message then
		notify(player, message, GREEN)
	end
	return result, message
end

---------------------------------------------------------------------------
-- Lifecycle
---------------------------------------------------------------------------
local function onCharacterAdded(player, char)
	local hum = char:WaitForChild("Humanoid")
	applyWalkSpeed(player)
	hum.Died:Connect(function()
		training[player] = nil
		TrainingState:FireClient(player, nil)
	end)
end

---------------------------------------------------------------------------
-- Tutorial guide: the character in the intro cutscene (classic colours).
-- Each client clones it from ReplicatedStorage for its own cutscene.
---------------------------------------------------------------------------
task.spawn(function()
	local ok, guide = pcall(function()
		local desc = Instance.new("HumanoidDescription")
		local skin = Color3.fromRGB(245, 205, 48)
		desc.HeadColor, desc.LeftArmColor, desc.RightArmColor = skin, skin, skin
		desc.TorsoColor = Color3.fromRGB(13, 105, 172)
		desc.LeftLegColor, desc.RightLegColor = Color3.fromRGB(164, 189, 71), Color3.fromRGB(164, 189, 71)
		return Players:CreateHumanoidModelFromDescription(desc, Enum.HumanoidRigType.R15)
	end)
	if ok and guide then
		guide.Name = "TutorialGuide"
		guide.Parent = ReplicatedStorage
	else
		warn("[Tutorial] couldn't build the guide: " .. tostring(guide))
	end
end)

local function onPlayerAdded(player)
	local ls = Instance.new("Folder")
	ls.Name = "leaderstats"
	for _, name in ipairs({ "Power", "Rebirths", "Cash" }) do
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
	if freshSaveTest() then
		stored = nil
	end
	local data = reconcile(type(stored) == "table" and stored or {}, Config.DefaultData)
	profiles[player] = { Data = data, Loaded = true, JoinTime = os.clock(), PlaytimeClaimed = {}, Passes = {} }
	loadPasses(player)
	if not player.Parent then
		profiles[player] = nil
		return
	end
	refreshMissions(data)
	refreshPetAttribute(player)
	grantRebirthCannons(player) -- players who rebirthed before these unlocks existed

	-- Offline earnings
	if data.LastOnline > 0 then
		local away = math.min(os.time() - data.LastOnline, Config.OFFLINE_MAX_HOURS * 3600)
		if away > 600 then -- only after 10+ minutes away
			local earned = math.floor(Config.PowerPerMinute(data, hasPass(player, "VIP")) / 60 * away * Config.OFFLINE_RATE)
			if earned > 0 then
				data.Power += earned
				task.delay(3, function()
					OfflineEarnings:FireClient(player, earned, away)
				end)
			end
		end
	end
	data.LastOnline = os.time()

	player.CharacterAdded:Connect(function(char)
		onCharacterAdded(player, char)
	end)
	if player.Character then
		task.spawn(onCharacterAdded, player, player.Character)
	end
	markDirty(player)
	if next(latestBoards) then
		Leaderboards:FireClient(player, latestBoards)
	end
end

Players.PlayerAdded:Connect(onPlayerAdded)
for _, p in ipairs(Players:GetPlayers()) do
	task.spawn(onPlayerAdded, p)
end

Players.PlayerRemoving:Connect(function(player)
	training[player] = nil
	leaveCooldown[player] = nil
	lastLaunch[player] = nil
	requestCooldown[player] = nil
	dirty[player] = nil
	save(player)
	profiles[player] = nil
end)

-- Missions roll over at midnight UTC while people are online
task.spawn(function()
	while true do
		task.wait(Config.AUTOSAVE_INTERVAL)
		for player, profile in pairs(profiles) do
			refreshMissions(profile.Data)
			markDirty(player)
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

-- The first-session guidance on the server (HOOK, brief 23: a new player hooked in 30 seconds; the design is
-- brief/out23/HOOK/first30.md, the rules Shared/OnboardingRules). Four times a second, for every loaded player:
--   * the step (OnboardingRules.step) from what the other services already keep: Power, rebirths, guns and Cash from
--     the profile; the best crew ever beaten (profile Waves.Cleared, WaveService's WaveCleared); WaveStage, WaveLeft and
--     RunCleared (WaveService / Runs). Published as the player attribute OnboardingStep (Train | Door | Fight | Cash |
--     Gift | Gun | Run | Done); HoodClient/Onboarding shows it.
--   * the welcome present, once per player ever: on the Gift step it waits at OnboardingRules.giftSpot (the lobby
--     spawn + GiftOffset), published as OnboardingGiftAt (a world Vector3) for the client to draw. Walking into it
--     (OnboardingRules.atGift, checked here from the root's position) opens GiftCount pairs of the Street box at its
--     normal odds through HoodServer/ShoeOpening (the same unboxing as a bought box; nothing is paid).
--   * the quiet window: OnboardingQuiet = true for the first QuietSeconds of play (StageService's 10x pad and
--     LobbyService's Robux lanes open no purchase prompt meanwhile).
-- Saved inside the profile's existing Onboarding table: Gift, Done, Seconds (OnboardingRules.sanitize). A returning
-- player who is already past the opening (OnboardingRules.veteran) is marked Done on first sight: no guidance, no gift,
-- no quiet window.
local Players = game:GetService('Players')
local RS = game:GetService('ReplicatedStorage')
local CollectionService = game:GetService('CollectionService')
local Data = require(script.Parent.DataService)
local Rules = require(RS.Shared.OnboardingRules)
local Guns = require(RS.Shared.Config.Guns)
local ActiveMap = require(RS.Shared.ActiveMap)

while not RS:GetAttribute('FoundationReady') do task.wait(0.1) end
local okOpen, ShoeOpening = pcall(require, script.Parent.ShoeOpening)
if not okOpen then
	warn('[OnboardingService] ShoeOpening missing: the welcome gift is off. ' .. tostring(ShoeOpening))
	ShoeOpening = nil
end

-- The map's pieces: the lobby spawn (for the present) and Stage 1's recommended Power (the step from Train to Door).
local active = ActiveMap.wait(10)
local function lobbySpawn()
	if not active then return nil end
	local root = active.Root
	local spawnPart
	for _, d in root:GetDescendants() do
		if d:IsA('SpawnLocation') then spawnPart = d break end
	end
	local at = root:GetAttribute('LobbySpawn')
	local floor = spawnPart and spawnPart.CFrame.Position.Y + spawnPart.Size.Y / 2
	if typeof(at) == 'Vector3' then
		local world = active.Frame * at
		return Vector3.new(world.X, floor or world.Y, world.Z)
	end
	return spawnPart and Vector3.new(spawnPart.CFrame.Position.X, floor, spawnPart.CFrame.Position.Z) or nil
end
local spawnAt = lobbySpawn()
local giftAt = spawnAt and Rules.giftSpot(spawnAt, active and active.Frame) or nil
local function stageOneNeed()
	local ok, tagged = pcall(function() return CollectionService:GetTagged('HoodStageGate') end)
	for _, g in ok and tagged or {} do
		if g:GetAttribute('Stage') == 1 then
			local r = g:GetAttribute('Required')
			if type(r) == 'number' and r > 0 then return r end
		end
	end
	return 10
end

local function set(player, name, value)
	if player:GetAttribute(name) ~= value then player:SetAttribute(name, value) end
end
local function num(v) return type(v) == 'number' and v == v and v or 0 end

local function stateOf(player, data, ob)
	local owned = type(data.Guns) == 'table' and data.Guns.Owned or {}
	local count = 0
	for id, on in owned do
		if on == true and Guns.ById[id] then count += 1 end
	end
	local _, cost = Rules.nextGun(Guns.List, owned)
	local waves = type(data.Waves) == 'table' and data.Waves.Cleared or nil
	local wave = player:GetAttribute('WaveCleared')
	return {
		Done = ob.Done, Gift = ob.Gift, Rebirths = data.Rebirths, Power = data.Rep, Need = stageOneNeed(),
		Beaten = math.max(num(waves), num(wave)),
		WaveStage = num(player:GetAttribute('WaveStage')), WaveLeft = num(player:GetAttribute('WaveLeft')),
		RunCleared = num(player:GetAttribute('RunCleared')),
		Guns = count, Cash = data.Cash, GunCost = cost,
		Stages = num(player:GetAttribute('StagesCleared')),
		Boxes = type(data.Shoes) == 'table' and num(data.Shoes.Opened) or 0,
	}
end

local function rootOf(player)
	local c = player.Character
	local root = c and c:FindFirstChild('HumanoidRootPart')
	local h = c and c:FindFirstChildOfClass('Humanoid')
	if not root or not h or h.Health <= 0 then return nil end
	return root
end

-- The present, once: the flag goes first, so nothing can ever give it twice.
local function give(player, profile, ob)
	if ob.Gift then return end
	ob.Gift = true
	set(player, 'OnboardingGiftAt', nil)
	if ShoeOpening then
		local ok, err = pcall(ShoeOpening.openMany, player, profile, Rules.GiftBox, Rules.GiftCount)
		if not ok then warn('[OnboardingService] The welcome gift could not open: ' .. tostring(err)) end
	end
	Data.push(player)
end

local seen = {} -- [player] = true once the first sight (the veteran check) is done this session
local function check(player, dt)
	local profile = Data.get(player)
	if not profile then return end
	local data = profile.Data
	local ob = Rules.sanitize(data.Onboarding)
	data.Onboarding = ob
	if not seen[player] then
		seen[player] = true
		if not ob.Done and not ob.Gift and Rules.veteran(stateOf(player, data, ob)) then
			ob.Done = true
			ob.Seconds = math.max(ob.Seconds, Rules.QuietSeconds)
		end
	end
	Rules.tick(ob, dt)
	set(player, 'OnboardingQuiet', Rules.quietFor(ob))
	local step = Rules.step(stateOf(player, data, ob))
	if step == 'Done' and not ob.Done then
		ob.Done = true
		Data.push(player)
	end
	set(player, 'OnboardingStep', step)
	if step == 'Gift' and not ob.Gift then
		if not giftAt then
			give(player, profile, ob)
		else
			set(player, 'OnboardingGiftAt', giftAt)
			local root = rootOf(player)
			if root and Rules.atGift(root.Position, giftAt) then give(player, profile, ob) end
		end
	else
		set(player, 'OnboardingGiftAt', nil)
	end
end

Players.PlayerRemoving:Connect(function(player) seen[player] = nil end)
while true do
	local dt = task.wait(0.25)
	for _, player in Players:GetPlayers() do
		local ok, err = pcall(check, player, math.min(type(dt) == 'number' and dt or 0.25, 1))
		if not ok then warn('[OnboardingService] ' .. tostring(err)) end
	end
end

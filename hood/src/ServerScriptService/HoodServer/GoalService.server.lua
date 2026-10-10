-- The goal chain (the soldier game's "GOAL DONE! ... / NEXT GOAL: ... - where to go"; the list is GoalRules). The
-- server checks each player's current goal once a second against what it knows (Power, gates passed, waves cleared,
-- pad cash-outs, guns owned, the range you stand in, rebirths), pays its small Cash reward (x2 with the x2 Cash pass)
-- and moves you on; the step is saved in the profile
-- (Goals). A profile from before the chain catches up quietly on its first check (no rewards for old progress).
-- Player attributes (HoodClient/Goals shows them): GoalStep (#List + 1 = all done), GoalText, GoalWhere, GoalReward.
-- Remote Goal, to that player: { Kind = 'Done', Text, Reward, NextText, NextWhere, NextReward } when a goal completes.
-- Reads the attributes StageService (StagesCleared, CashOuts, BestCashOut), WaveService (WaveCleared; unset on maps without waves)
-- and LobbyService (TrainingStation) keep on the server, the boxes opened (profile Shoes.Opened) and whether this map
-- has shoe boxes (ShoeService sets ReplicatedStorage's ShoeBoxes).
local Players = game:GetService('Players')
local RS = game:GetService('ReplicatedStorage')
local Data = require(script.Parent.DataService)
local Net = require(RS.Shared.Net)
local GoalRules = require(RS.Shared.GoalRules)
local Skins = require(RS.Shared.Config.Skins)
local Guns = require(RS.Shared.Config.Guns)
local Boosts = require(script.Parent.Boosts)

while not RS:GetAttribute('FoundationReady') do task.wait(0.1) end
local remote = Net.get('Goal')

local rangeIndex = {}
for i, s in Skins.Stations do rangeIndex[s.Id] = i end

local function stateOf(player, profile)
	local owned = 0
	for id, on in profile.Data.Guns.Owned do
		if on == true and Guns.ById[id] then owned += 1 end
	end
	local station = player:GetAttribute('TrainingStation')
	local wave = player:GetAttribute('WaveCleared')
	local stages = player:GetAttribute('StagesCleared')
	local cashOuts = player:GetAttribute('CashOuts')
	local cashOutStage = player:GetAttribute('BestCashOut')
	return {
		Power = profile.Data.Rep,
		Stages = type(stages) == 'number' and stages or 0,
		Wave = type(wave) == 'number' and wave or 0,
		Waves = type(wave) == 'number', -- (no waves on this map: wave and pad goals are skipped)
		CashOuts = type(cashOuts) == 'number' and cashOuts or 0,
		CashOutStage = type(cashOutStage) == 'number' and cashOutStage or 0,
		Guns = owned,
		Range = type(station) == 'string' and rangeIndex[station] or 0, -- ('Locked:<Id>' and '' are 0)
		Boxes = type(profile.Data.Shoes) == 'table' and profile.Data.Shoes.Opened or 0,
		Rebirths = profile.Data.Rebirths,
		ShoeBoxes = RS:GetAttribute('ShoeBoxes') == true, -- (no shoe boxes on this map: the box goal is skipped)
	}
end

local function set(player, name, value)
	if player:GetAttribute(name) ~= value then player:SetAttribute(name, value) end
end
local function publish(player, step)
	local g = GoalRules.at(step)
	set(player, 'GoalStep', step)
	set(player, 'GoalText', g and g.Text or GoalRules.AllDone.Text)
	set(player, 'GoalWhere', g and g.Where or GoalRules.AllDone.Where)
	set(player, 'GoalReward', g and g.Reward or 0)
end

local function check(player)
	local profile = Data.get(player)
	if not profile then return end
	local goals = profile.Data.Goals
	local done = GoalRules.advance(goals, stateOf(player, profile))
	if done then
		local paid = Boosts.cashFor(player, done.Reward)
		profile.Data.Cash = math.min(1e12, profile.Data.Cash + paid)
		player:SetAttribute('Cash', profile.Data.Cash)
		local nextGoal = GoalRules.at(goals.Step)
		remote:FireClient(player, {
			Kind = 'Done', Text = done.Text, Reward = paid,
			NextText = nextGoal and nextGoal.Text or GoalRules.AllDone.Text,
			NextWhere = nextGoal and nextGoal.Where or GoalRules.AllDone.Where,
			NextReward = nextGoal and nextGoal.Reward or 0,
		})
		Data.push(player)
	end
	publish(player, goals.Step)
end

-- The goal line shows the moment a profile loads (HOOK, brief 23: a new player reads "Stand in BAY 1" at once); the
-- stage and wave services get a moment before the first check (their attributes land within a second; WaveCleared may
-- legitimately stay unset), so a returning player's catch-up sees their progress. Then one check a second.
-- (CRITIC3 r1, HOOK) A big moment has the screen to itself: no goal completes for HOLD seconds after a pad cash-out
-- (CashOuts: the "+10 Cash" pop) or a gun purchase (OwnedGuns: HOOK's "x2 POWER!"), so their GOAL DONE lands after it.
local TICK, GRACE, EVERY, HOLD = 0.25, 3, 1, 2.2
local HOLD_ON = { 'CashOuts', 'OwnedGuns' }
local since, holdUntil, seen = {}, {}, {} -- [player] = seconds since their profile loaded / os.clock() until which checks
-- wait / { [attribute] = value } as this loop last saw them (a change, seen before the check in the same pass, holds)
while task.wait(TICK) do
	for _, player in Players:GetPlayers() do
		local profile = Data.get(player)
		if profile then
			local was = since[player]
			local now = (was or -TICK) + TICK
			since[player] = now
			local last = seen[player]
			local values = {}
			for _, name in HOLD_ON do
				values[name] = player:GetAttribute(name)
				if last and values[name] ~= last[name] and last[name] ~= nil then holdUntil[player] = os.clock() + HOLD end
			end
			seen[player] = values
			if was == nil then
				local ok, err = pcall(publish, player, profile.Data.Goals.Step)
				if not ok then warn('[GoalService] ' .. tostring(err)) end
			elseif now >= GRACE and os.clock() >= (holdUntil[player] or 0) and math.floor(now / EVERY) ~= math.floor(was / EVERY) then
				local ok, err = pcall(check, player)
				if not ok then warn('[GoalService] ' .. tostring(err)) end
			end
		else
			since[player] = nil
		end
	end
	for player in since do
		if player.Parent ~= Players then since[player], holdUntil[player], seen[player] = nil, nil, nil end
	end
end

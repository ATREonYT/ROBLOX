-- The goal chain (the soldier game's "GOAL DONE! ... / NEXT GOAL: ... - where to go"; the list is GoalRules). The
-- server checks each player's current goal once a second against what it knows (Power, gates passed, waves cleared,
-- guns owned, the range you stand in), pays its small Cash reward and moves you on; the step is saved in the profile
-- (Goals). A profile from before the chain catches up quietly on its first check (no rewards for old progress).
-- Player attributes (HoodClient/Goals shows them): GoalStep (#List + 1 = all done), GoalText, GoalWhere, GoalReward.
-- Remote Goal, to that player: { Kind = 'Done', Text, Reward, NextText, NextWhere, NextReward } when a goal completes.
-- Reads the attributes StageService (StagesCleared), WaveService (WaveCleared; unset on maps without waves) and
-- LobbyService (TrainingStation) keep on the server.
local Players = game:GetService('Players')
local RS = game:GetService('ReplicatedStorage')
local Data = require(script.Parent.DataService)
local Net = require(RS.Shared.Net)
local GoalRules = require(RS.Shared.GoalRules)
local Skins = require(RS.Shared.Config.Skins)
local Guns = require(RS.Shared.Config.Guns)

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
	return {
		Power = profile.Data.Rep,
		Stages = type(stages) == 'number' and stages or 0,
		Wave = type(wave) == 'number' and wave or 0,
		Waves = type(wave) == 'number', -- (no waves on this map: wave goals are skipped)
		Guns = owned,
		Range = type(station) == 'string' and rangeIndex[station] or 0, -- ('Locked:<Id>' and '' are 0)
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
		profile.Data.Cash = math.min(1e12, profile.Data.Cash + done.Reward)
		player:SetAttribute('Cash', profile.Data.Cash)
		local nextGoal = GoalRules.at(goals.Step)
		remote:FireClient(player, {
			Kind = 'Done', Text = done.Text, Reward = done.Reward,
			NextText = nextGoal and nextGoal.Text or GoalRules.AllDone.Text,
			NextWhere = nextGoal and nextGoal.Where or GoalRules.AllDone.Where,
			NextReward = nextGoal and nextGoal.Reward or 0,
		})
		Data.push(player)
	end
	publish(player, goals.Step)
end

-- Give the stage and wave services a moment after a profile loads before the first check (their attributes land
-- within a second; WaveCleared may legitimately stay unset), so a returning player's catch-up sees their progress.
local ready = {}
while task.wait(1) do
	for _, player in Players:GetPlayers() do
		if Data.get(player) then
			ready[player] = (ready[player] or 0) + 1
			if ready[player] >= 3 then
				local ok, err = pcall(check, player)
				if not ok then warn('[GoalService] ' .. tostring(err)) end
			end
		else
			ready[player] = nil
		end
	end
	for player in ready do
		if player.Parent ~= Players then ready[player] = nil end
	end
end

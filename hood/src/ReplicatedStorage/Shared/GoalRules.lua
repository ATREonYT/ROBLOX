-- The goal chain (the soldier game's "GOAL DONE! ... / NEXT GOAL: ... - where to go", the hood way): one goal at a
-- time for World 1, each naming what to do, where to go and the small Cash it pays. Pure rules shared by GoalService
-- (which checks and pays, server-side) and the unit tests; Goals.client shows what the server says.
--   A goal is done when the player's state reaches its Need: Power (Rep), Stages (gates passed), Wave (WaveCleared),
--   Guns (guns owned) or Range (the place in Skins.Stations of the unlocked range you stand in, 0 = none).
local GoalRules = {}

GoalRules.List = {
	{ Id = 'FreeRange', Text = 'Shoot at the FREE range', Where = 'BAY 1 on the range stand, get 10 Power', Reward = 5, Need = { Power = 10 } },
	{ Id = 'Stage1', Text = 'Walk to Stage 1', Where = 'the big door at the end of the hall', Reward = 10, Need = { Stages = 1 } },
	{ Id = 'Wave1', Text = "Clear Stage 1's targets", Where = 'in the side yard past the door', Reward = 15, Need = { Wave = 1 } },
	{ Id = 'Gun', Text = 'Buy a gun', Where = 'the ARMORY in the back corner of the hall', Reward = 20, Need = { Guns = 2 } },
	{ Id = 'Stage3', Text = 'Reach Stage 3', Where = 'down the street past Stage 2', Reward = 25, Need = { Stages = 3 } },
	{ Id = 'Range2', Text = 'Train at the next range', Where = 'BAY 2, next to BAY 1 (50 Power)', Reward = 30, Need = { Range = 2 } },
	{ Id = 'Stage6', Text = 'Reach Stage 6', Where = 'keep heading down the street', Reward = 50, Need = { Stages = 6 } },
	{ Id = 'Gun3', Text = 'Get a better gun', Where = 'the ARMORY has the Street Uzi', Reward = 75, Need = { Guns = 3 } },
	{ Id = 'Range4', Text = 'Train at BAY 4', Where = 'the range stand in the hall (500 Power)', Reward = 100, Need = { Range = 4 } },
	{ Id = 'Stage10', Text = 'Reach Stage 10', Where = 'further down the street', Reward = 150, Need = { Stages = 10 } },
	{ Id = 'Range6', Text = 'Train at BAY 6', Where = 'the top row of the range stand (3K Power)', Reward = 200, Need = { Range = 6 } },
	{ Id = 'Stage13', Text = 'Reach Stage 13', Where = 'the far end of the street', Reward = 300, Need = { Stages = 13 } },
	{ Id = 'Wave15', Text = "Clear Stage 15's targets", Where = 'the last street before the Boss Yard', Reward = 500, Need = { Wave = 15 } },
	{ Id = 'BossYard', Text = 'Reach the Boss Yard', Where = 'through the gate after Stage 15', Reward = 750, Need = { Stages = 16 } },
	{ Id = 'BossWave', Text = 'Clear the Boss Yard', Where = 'shoot every target in the yard', Reward = 1000, Need = { Wave = 16 } },
}
GoalRules.ById = {}
for i, g in GoalRules.List do
	g.Step = i
	GoalRules.ById[g.Id] = g
end
GoalRules.AllDone = { Text = 'ALL GOALS DONE!', Where = 'World 2 is coming soon' }

local function number(v)
	return type(v) == 'number' and v == v and v or 0
end

-- True when `state` meets the goal. A wave goal on a map without waves (state.Waves false) can't be met; advance()
-- skips it instead.
function GoalRules.done(goal, state)
	for key, need in goal.Need do
		if key == 'Wave' and not state.Waves then return false end
		if number(state[key]) < need then return false end
	end
	return true
end

-- Whether a goal can apply on this map (wave goals need waves).
function GoalRules.applies(goal, state)
	return goal.Need.Wave == nil or state.Waves == true
end

-- One check of a player's chain. `goals` = the profile's { Step, Synced }. A profile from before the chain (Synced
-- false) skips every goal it has already met, quietly and unpaid, then is synced. Otherwise the current goal, when
-- met, is completed (at most one a call, so each gets its moment) and returned for the caller to pay; goals that
-- can't apply on this map are skipped quietly. Returns the completed goal or nil.
function GoalRules.advance(goals, state)
	local list = GoalRules.List
	local function skippable(g) return not GoalRules.applies(g, state) end
	if not goals.Synced then
		while goals.Step <= #list and (GoalRules.done(list[goals.Step], state) or skippable(list[goals.Step])) do goals.Step += 1 end
		goals.Synced = true
		return nil
	end
	while goals.Step <= #list and skippable(list[goals.Step]) do goals.Step += 1 end
	local g = list[goals.Step]
	if g and GoalRules.done(g, state) then
		goals.Step += 1
		while goals.Step <= #list and skippable(list[goals.Step]) do goals.Step += 1 end
		return g
	end
	return nil
end

-- The goal at a step (nil once the chain is done).
function GoalRules.at(step)
	return GoalRules.List[step]
end

-- Makes a profile's Goals table safe: { Step = whole number 1..#List + 1, Synced = boolean }.
function GoalRules.sanitize(goals)
	if type(goals) ~= 'table' then return { Step = 1, Synced = false } end
	local step = goals.Step
	if type(step) ~= 'number' or step ~= step or step % 1 ~= 0 then step = 1 end
	goals.Step = math.clamp(step, 1, #GoalRules.List + 1)
	goals.Synced = goals.Synced == true
	return goals
end

-- "NEXT GOAL: Clear Stage 1's targets - in the side yard past the door" (the video's line).
function GoalRules.line(goal)
	if not goal then return GoalRules.AllDone.Text .. ' - ' .. GoalRules.AllDone.Where end
	return goal.Text .. ' - ' .. goal.Where
end

return GoalRules

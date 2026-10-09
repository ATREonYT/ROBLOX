-- The goal chain (the soldier game's "GOAL DONE! ... / NEXT GOAL: ... - where to go", the hood way): one goal at a
-- time for World 1, each naming what to do, where to go and the small Cash it pays. Pure rules shared by GoalService
-- (which checks and pays, server-side) and the unit tests; Goals.client shows what the server says.
--   A goal is done when the player's state reaches its Need: Power (Rep), Stages (gates passed), Wave (WaveCleared),
--   Guns (guns owned), Range (the place in Skins.Stations of the unlocked range you stand in, 0 = none) or Boxes (shoe
--   boxes opened, ShoeService).
--   A Side goal (opening a shoe box) is not on the way anywhere: a player who is past it in the chain gets it as a
--   detour (Goals.Back = the step to return to once it is done), so nobody skips it and nobody repeats a goal.
local GoalRules = {}

GoalRules.List = {
	{ Id = 'FreeRange', Text = 'Shoot at the FREE range', Where = 'BAY 1 on the range stand, get 10 Power', Reward = 5, Need = { Power = 10 } },
	{ Id = 'Stage1', Text = 'Walk to Stage 1', Where = 'the big door at the end of the hall', Reward = 10, Need = { Stages = 1 } },
	{ Id = 'Wave1', Text = "Clear Stage 1's targets", Where = 'in the side yard past the door', Reward = 15, Need = { Wave = 1 } },
	{ Id = 'Gun', Text = 'Buy a gun', Where = 'the ARMORY in the back corner of the hall', Reward = 20, Need = { Guns = 2 } },
	{ Id = 'Shoe', Text = 'Open a shoe box', Where = 'the boxes are at the back of the hall', Reward = 25, Need = { Boxes = 1 }, Side = true },
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
-- The chain's version, saved with each profile's Goals (Chain). Goals inserted after players saved steps: Step is
-- where the new goal went in the chain of version Chain (GoalRules.migrate moves older saves).
GoalRules.Chain = 2
GoalRules.Inserted = { { Chain = 2, Step = 5 } } -- Shoe, after Gun

local function number(v)
	return type(v) == 'number' and v == v and v or 0
end

-- True when `state` meets the goal. A wave goal on a map without waves (state.Waves false), or a shoe-box goal on a
-- map without shoe boxes (state.ShoeBoxes not true), can't be met; advance() skips it instead.
function GoalRules.done(goal, state)
	if not GoalRules.applies(goal, state) then return false end
	for key, need in goal.Need do
		if number(state[key]) < need then return false end
	end
	return true
end

-- Whether a goal can apply on this map (wave goals need waves, shoe-box goals need shoe boxes).
function GoalRules.applies(goal, state)
	return (goal.Need.Wave == nil or state.Waves == true) and (goal.Need.Boxes == nil or state.ShoeBoxes == true)
end

-- Moves past the current goal: back to where a detour started (Back), else on to the next one.
local function onward(goals)
	goals.Step = goals.Back or goals.Step + 1
	goals.Back = nil
end

-- One check of a player's chain. `goals` = the profile's { Step, Synced, Back }. A profile from before the chain
-- (Synced false) skips every goal it has already met, quietly and unpaid, then is synced; if that stops it at a Side
-- goal, the side goal comes first and Back keeps the first unmet goal after it. Otherwise the current goal, when met,
-- is completed (at most one a call, so each gets its moment) and returned for the caller to pay; goals that can't
-- apply on this map are skipped quietly. Returns the completed goal or nil.
function GoalRules.advance(goals, state)
	local list = GoalRules.List
	local function skippable(g) return not GoalRules.applies(g, state) end
	local function met(g) return GoalRules.done(g, state) or skippable(g) end
	if not goals.Synced then
		while goals.Step <= #list and met(list[goals.Step]) do onward(goals) end
		local g = list[goals.Step]
		if g and g.Side then
			local back = goals.Step + 1
			while back <= #list and met(list[back]) do back += 1 end
			if back > goals.Step + 1 then goals.Back = back end
		end
		goals.Synced = true
		return nil
	end
	while goals.Step <= #list and skippable(list[goals.Step]) do onward(goals) end
	local g = list[goals.Step]
	if g and GoalRules.done(g, state) then
		onward(goals)
		while goals.Step <= #list and skippable(list[goals.Step]) do onward(goals) end
		return g
	end
	return nil
end

-- Saved Goals from an older chain (Chain missing or lower than GoalRules.Chain): each goal inserted since keeps every
-- saved step on the same goal (steps at or after it move up one), and a player already past the new goal gets it now
-- as a detour, returning to their own goal after it (Back). Run before the profile is reconciled. Returns goals.
function GoalRules.migrate(goals)
	if type(goals) ~= 'table' then return goals end
	local chain = type(goals.Chain) == 'number' and goals.Chain or 1
	for _, ins in GoalRules.Inserted do
		if chain < ins.Chain and type(goals.Step) == 'number' then
			local function shift(step) return step >= ins.Step and step + 1 or step end
			if type(goals.Back) == 'number' then
				goals.Step, goals.Back = shift(goals.Step), shift(goals.Back) -- (already on a detour: keep it)
			elseif goals.Step >= ins.Step then
				goals.Step, goals.Back = ins.Step, goals.Step + 1
			end
		end
	end
	goals.Chain = GoalRules.Chain
	return goals
end

-- The goal at a step (nil once the chain is done).
function GoalRules.at(step)
	return GoalRules.List[step]
end

-- Makes a profile's Goals table safe: { Step = whole number 1..#List + 1, Synced = boolean, Back = nil or a whole
-- number after Step up to #List + 1 }. (Chain is set by migrate.)
function GoalRules.sanitize(goals)
	if type(goals) ~= 'table' then return { Step = 1, Synced = false } end
	local step = goals.Step
	if type(step) ~= 'number' or step ~= step or step % 1 ~= 0 then step = 1 end
	goals.Step = math.clamp(step, 1, #GoalRules.List + 1)
	goals.Synced = goals.Synced == true
	local back = goals.Back
	if type(back) ~= 'number' or back ~= back or back % 1 ~= 0 or back <= goals.Step or back > #GoalRules.List + 1 then back = nil end
	goals.Back = back
	return goals
end

-- "NEXT GOAL: Clear Stage 1's targets - in the side yard past the door" (the video's line).
function GoalRules.line(goal)
	if not goal then return GoalRules.AllDone.Text .. ' - ' .. GoalRules.AllDone.Where end
	return goal.Text .. ' - ' .. goal.Where
end

return GoalRules

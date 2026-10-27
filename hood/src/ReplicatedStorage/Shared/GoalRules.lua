-- The goal chain (the soldier game's "GOAL DONE! ... / NEXT GOAL: ... - where to go", the hood way): one goal at a
-- time for World 1, each naming what to do, where to go and the small Cash it pays. Pure rules shared by GoalService
-- (which checks and pays, server-side) and the unit tests; Goals.client shows what the server says.
--   A goal is done when the player's state reaches its Need: Power (Rep), Stages (gates ever passed), Wave (WaveCleared,
--   the best stage whose crew you ever beat), CashOuts (pad cash-outs this session: brief 23's run loop), CashOutStage
--   (the furthest stage you have cashed out at this session), Guns (guns
--   owned), Range (the place in Skins.Stations of the open lane you stand in, 0 = none), Boxes (shoe boxes opened,
--   ShoeService) or Rebirths.
--   A Side goal (opening a shoe box) is not on the way anywhere: a player who is past it in the chain gets it as a
--   detour (Goals.Back = the step to return to once it is done), so nobody skips it and nobody repeats a goal.
-- (brief 30, HUD: the lead) The HUD shows a goal as ONE short line, Text, at most GoalRules.MaxText characters, with its Cash
-- beside it, like the reference's "Hatch an egg"; Where stays for the goal list (HUD.client's Quest window) and the tutorial.
-- The run loop (brief 23) the chain teaches: train in BAY 1, walk to Stage 1, beat its crew (the next gate opens), step
-- on a pad to cash out (back to the lobby), spend the Cash, then fight further each run.
local Skins = require(script.Parent.Config.Skins)
local PadRules = require(script.Parent.PadRules)
local Balance = require(script.Parent.Config.Balance)

local GoalRules = {}
GoalRules.MaxText = 28

-- A lane goal reads its lane's name and rebirths from Config/Skins (ECON's ladder), so the words never go stale.
local function lane(id, goalId, reward, where)
	local index, station = 0, nil
	for i, st in Skins.Stations do
		if st.Id == id then index, station = i, st end
	end
	local rebirths = station and station.Rebirths or 0
	local count = rebirths == 1 and '1 rebirth' or (rebirths .. ' rebirths')
	return {
		Id = goalId, Text = 'Train ' .. (id == 'Ring' and 'in the ' or 'at ') .. (station and station.Name or id),
		Where = string.format(where or 'it opens at %s', count), Reward = reward, Need = { Range = index },
	}
end

-- (ECON, brief 23: the first goals pay only a little, so the yellow pad's "+20 Cash" is the biggest number of the first
-- minute and a purchase goal never refunds the purchase.)
-- (Where: the hall's layout as built: the ranges are the lanes on the west wall, the ARMORY the stand on the east
-- side, the shoe boxes at the back, the stage door at the end. The ranges fire by themselves; every stage is a crew of
-- goons to beat, and the two pads before its far gate cash out.)
-- (Oct 27, flow) A Tutorial goal is one the tutorial itself walks you through: while the tutorial runs it completes
-- quietly (its Cash still lands; GoalService marks the message Quiet), and the tutorial ends on one "YOU'RE READY!"
-- moment instead of five GOAL DONE moments in 20 seconds (the audit, hood/docs/research/OUR_FIRST_10_MIN.md).
local FIRST_POWER = (Balance.Worlds and Balance.Worlds[1] and Balance.Worlds[1].StagePower[1]) or 10
GoalRules.FirstPower = FIRST_POWER
GoalRules.List = {
	-- (Oct 27, flow: the kid stays in BAY 1 until Stage 1's Power, and the goal says it in Power, not in Levels)
	{ Id = 'FreeRange', Text = 'Train to ' .. FIRST_POWER .. ' Power in BAY 1', Where = 'on the left, it shoots for you', Reward = 2, Need = { Power = FIRST_POWER }, Tutorial = true },
	{ Id = 'Stage1', Text = 'Walk to Stage 1', Where = 'through the big door ahead', Reward = 3, Need = { Stages = 1 }, Tutorial = true },
	{ Id = 'Wave1', Text = 'Beat the Stage 1 crew', Where = 'hold to shoot them', Reward = 5, Need = { Wave = 1 }, Tutorial = true },
	{ Id = 'CashOut', Text = 'Step on the yellow pad', Where = 'by the gate: ' .. PadRules.text(PadRules.reward(1, false)), Reward = 5, Need = { CashOuts = 1 }, Tutorial = true },
	{ Id = 'Gun', Text = 'Buy a gun', Where = 'at the ARMORY, right side of the hall', Reward = 5, Need = { Guns = 2 }, Tutorial = true },
	-- (CRITIC3 r1: the stage 2 pad pays for the shoe box the next goal points at)
	{ Id = 'CashOut2', Text = 'Beat Stage 2 and cash out', Where = 'the yellow pad: ' .. PadRules.text(PadRules.reward(2, false)), Reward = 5, Need = { CashOutStage = 2 } },
	{ Id = 'Shoe', Text = 'Open a shoe box', Where = 'at the back of the hall', Reward = 5, Need = { Boxes = 1 }, Side = true },
	{ Id = 'Stage3', Text = 'Reach Stage 3', Where = 'beat each crew to open its gate', Reward = 25, Need = { Stages = 3 } },
	{ Id = 'Rebirth1', Text = 'Rebirth!', Where = 'fill the Level bar, then tap Rebirth', Reward = 30, Need = { Rebirths = 1 } },
	-- (Oct 27 pacing: the chain follows the order a player meets things: Stage 6 with 1 rebirth, BAY 2 at 2, Stage 10
	-- with 3, BAY 3 at 4, Stage 13 with 6, BAY 4 at 7, the boss in the 9th rebirth's cycle; then the last lanes at 15,
	-- 30 and 50 rebirths.)
	{ Id = 'Stage6', Text = 'Reach Stage 6', Where = 'beat the crews down the street', Reward = 50, Need = { Stages = 6 } },
	lane('Tape', 'Range2', 60),
	{ Id = 'Gun4', Text = 'Get the Pump Shotgun', Where = 'at the ARMORY', Reward = 75, Need = { Guns = 4 } },
	{ Id = 'Stage10', Text = 'Reach Stage 10', Where = 'further down the street', Reward = 150, Need = { Stages = 10 } },
	lane('Street', 'Range3', 100),
	{ Id = 'Stage13', Text = 'Reach Stage 13', Where = 'the far end of the street', Reward = 300, Need = { Stages = 13 } },
	lane('Heavy', 'Range4', 200),
	-- FIGHTS30 BEGIN (brief 30, FIGHTS: the last stage is just a strong last enemy, "remove everything saying its a boss"; the ids stay)
	{ Id = 'Wave15', Text = 'Beat the Stage 15 crew', Where = 'before the warehouse', Reward = 500, Need = { Wave = 15 } },
	{ Id = 'BossYard', Text = 'Reach Stage 16', Where = 'the warehouse past Stage 15', Reward = 750, Need = { Stages = 16 } },
	{ Id = 'BossWave', Text = 'Beat the Harbor crew', Where = 'in the warehouse, Stage 16', Reward = 1000, Need = { Wave = 16 } },
	-- FIGHTS30 END
	lane('Speed', 'Range5', 1200),
	lane('DoubleEnd', 'Range6', 1500),
	lane('Ring', 'Ring', 2500, 'Stage 16, at %s'), -- FIGHTS30 (was 'Boss Yard, at %d rebirths')
}
-- (Oct 27) World 2, Business District (its own place; Shared/WorldInfo): a fresh chain through its five districts (City Streets,
-- Modern Plaza, Construction Zone, Transit Area, Luxury District), up to the CEO on the rooftop. You
-- arrive with your rebirths, guns and shoes, so it's only the new stages, the crews and the last lanes; the rewards are
-- scaled to its pads (7K to 40K). A World 2 visitor's goals start unsynced (HoodServer/WorldData), so the lanes and guns
-- they already have are skipped quietly.
local okW, WorldInfo = pcall(function() return require(script.Parent.WorldInfo) end)
GoalRules.World = okW and WorldInfo.current() or 1
if GoalRules.World == 2 then
	GoalRules.List = {
		{ Id = 'Stage1', Text = 'Walk to Business District Stage 1', Where = 'through the big doors ahead', Reward = 500, Need = { Stages = 1 } },
		{ Id = 'Wave1', Text = 'Beat the Interns', Where = 'hold to shoot them', Reward = 750, Need = { Wave = 1 } },
		{ Id = 'CashOut', Text = 'Step on the yellow pad', Where = 'by the gate: ' .. PadRules.text(PadRules.reward(1, false)), Reward = 750, Need = { CashOuts = 1 } },
		{ Id = 'Stage4', Text = 'Reach Stage 4', Where = 'the Modern Plaza, past the City Streets', Reward = 1500, Need = { Stages = 4 } },
		{ Id = 'Stage6', Text = 'Reach Stage 6', Where = 'by the plaza fountains', Reward = 2500, Need = { Stages = 6 } },
		{ Id = 'Stage10', Text = 'Reach Stage 10', Where = 'under the train line, past the cranes', Reward = 4000, Need = { Stages = 10 } },
		{ Id = 'Stage13', Text = 'Reach Stage 13', Where = 'the Luxury District, with the palms', Reward = 6000, Need = { Stages = 13 } },
		{ Id = 'Wave15', Text = 'Beat the Stage 15 crew', Where = 'by the red BOSS gate', Reward = 8000, Need = { Wave = 15 } },
		{ Id = 'BossYard', Text = 'Reach the rooftop', Where = 'through the BOSS gate, Stage 16', Reward = 10000, Need = { Stages = 16 } },
		{ Id = 'BossWave', Text = 'Beat The CEO', Where = 'on the rooftop, Stage 16', Reward = 15000, Need = { Wave = 16 } },
		lane('Speed', 'Range5', 12000),
		lane('DoubleEnd', 'Range6', 20000),
		lane('Ring', 'Ring', 30000, 'Stage 16, at %s'),
	}
end
GoalRules.ById = {}
for i, g in GoalRules.List do
	g.Step = i
	GoalRules.ById[g.Id] = g
end
GoalRules.AllDone = GoalRules.World == 2 and { Text = 'ALL GOALS DONE!', Where = 'more worlds are coming soon' }
	or { Text = 'ALL GOALS DONE!', Where = 'take the World 2 portal to the Business District' }
-- The chain's version, saved with each profile's Goals (Chain). Older chains, by goal id (GoalRules.migrate moves a
-- saved step to the same goal in this chain).
GoalRules.Chain = 5 -- (5: Oct 27 pacing, the lanes spread over 50 rebirths; BAY 5 after the boss)
GoalRules.Chains = {
	[1] = { 'FreeRange', 'Stage1', 'Wave1', 'Gun', 'Stage3', 'Range2', 'Stage6', 'Gun3', 'Range4', 'Stage10', 'Range6', 'Stage13', 'Wave15', 'BossYard', 'BossWave' },
	[2] = { 'FreeRange', 'Stage1', 'Wave1', 'Gun', 'Shoe', 'Stage3', 'Range2', 'Stage6', 'Gun3', 'Range4', 'Stage10', 'Range6', 'Stage13', 'Wave15', 'BossYard', 'BossWave' },
	[3] = { 'FreeRange', 'Stage1', 'Wave1', 'Gun', 'Shoe', 'Stage3', 'Rebirth1', 'Stage6', 'Range2', 'Gun4', 'Range3', 'Stage10', 'Range4', 'Stage13', 'Range5', 'Wave15', 'BossYard', 'BossWave', 'Range8', 'Ring' },
	[4] = { 'FreeRange', 'Stage1', 'Wave1', 'CashOut', 'Gun', 'CashOut2', 'Shoe', 'Stage3', 'Rebirth1', 'Stage6', 'Range2', 'Gun4', 'Range3', 'Stage10', 'Range4', 'Stage13', 'Range5', 'Wave15', 'BossYard', 'BossWave', 'Range6', 'Ring' },
}
-- Goals of an older chain that are gone, and the goal of this chain that takes their place (one level: chains 1-2's
-- Range6 was BAY 4's goal; chain 3's Range8, the gold lane, is a Robux lane now, so its place goes to BAY 6). Only for
-- chains 1-3: from chain 4 on, Range6 is BAY 6's own goal.
GoalRules.Renamed = { Gun3 = 'Gun4', Range6 = 'Range4', Range8 = 'Range6' }

local function number(v)
	return type(v) == 'number' and v == v and v or 0
end

-- (Oct 27, the core loop) What the goal line says for `goal` with `rebirths` rebirths: a lane goal whose lane is still
-- locked reads "Rebirth to open BAY 4" (where: "it opens at 7 rebirths, you have 6"), so the line never sends a player
-- to a locked lane with nothing to do there. nil goal: the chain is done. Returns text, where.
function GoalRules.shown(goal, rebirths)
	if not goal then return GoalRules.AllDone.Text, GoalRules.AllDone.Where end
	local st = goal.Need.Range and Skins.Stations[goal.Need.Range]
	local n = number(rebirths)
	if st and (st.Rebirths or 0) > n then
		return 'Rebirth to open ' .. st.Name, string.format('it opens at %d rebirths, you have %d', st.Rebirths, n)
	end
	return goal.Text, goal.Where
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

-- Whether a goal can apply on this map (wave and pad goals need waves, shoe-box goals need shoe boxes).
function GoalRules.applies(goal, state)
	local waves = goal.Need.Wave == nil and goal.Need.CashOuts == nil and goal.Need.CashOutStage == nil
	return (waves or state.Waves == true) and (goal.Need.Boxes == nil or state.ShoeBoxes == true)
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

-- Saved Goals from an older chain (Chain missing or lower than GoalRules.Chain): the saved step (and a detour's Back)
-- moves to the same goal in this chain, by id (a goal that is gone moves to the one that took its place, else to the
-- next one of the old chain that still exists). Goals new to this chain that come before the player's step are not
-- handed out after the fact. Run before the profile is reconciled. Returns goals.
function GoalRules.migrate(goals)
	if type(goals) ~= 'table' then return goals end
	local chain = type(goals.Chain) == 'number' and goals.Chain or 1
	local old = GoalRules.World == 1 and GoalRules.Chains[chain] -- (the old chains are World 1's)
	if old then
		local function map(step)
			if type(step) ~= 'number' or step ~= step or step % 1 ~= 0 then return step end
			if step > #old then return #GoalRules.List + 1 end
			for i = math.max(1, step), #old do
				local id = old[i]
				local g = GoalRules.ById[(chain < 4 and GoalRules.Renamed[id]) or id]
				if g then return g.Step end
			end
			return #GoalRules.List + 1
		end
		goals.Step, goals.Back = map(goals.Step), map(goals.Back)
		if type(goals.Back) == 'number' and type(goals.Step) == 'number' and goals.Back <= goals.Step then goals.Back = nil end
		-- A side goal the old chain didn't have, already behind the player: theirs now as a detour (back to their step).
		if goals.Back == nil and type(goals.Step) == 'number' then
			for _, g in GoalRules.List do
				if g.Side and g.Step < goals.Step and not table.find(old, g.Id) then
					goals.Step, goals.Back = g.Step, goals.Step
					break
				end
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

-- "NEXT GOAL: Beat the Stage 1 crew - hold to shoot them" (the video's line).
function GoalRules.line(goal)
	if not goal then return GoalRules.AllDone.Text .. ' - ' .. GoalRules.AllDone.Where end
	return goal.Text .. ' - ' .. goal.Where
end

return GoalRules

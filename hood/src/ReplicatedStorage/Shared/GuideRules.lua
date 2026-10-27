-- GuideRules (Oct 27, the core loop: "make the core loop done well"): where the lasting guide after the tutorial points
-- for the current goal, like the soldier game's small bouncing arrow over "where to go". Pure rules, unit-tested;
-- HoodClient/GoalGuide finds the named thing in the map and draws the arrow.
--   GuideRules.target(goal, state) -> { Kind, Stage?, Station? } | nil
--     goal: a GoalRules goal (nil: the chain is done); state: { Rebirths, RunCleared, World }.
--     Kinds: 'Lane' (Station: a Config/Skins station id), 'Gate' (Stage: the furthest gate it may point to; the client
--     picks the next one ahead of you up to it), 'Pad' (Stage: the yellow pad of that stage), 'Armory', 'Boxes' (the
--     shoe boxes), 'Portal' (World 1's door to World 2). nil: nothing in the world to walk to (a rebirth goal, a lane
--     still locked: the goal line says "Rebirth to open ..." then, GoalRules.shown).
--   GuideRules.Near[kind]: studs from the target within which you are there and the guide hides.
local Skins = require(script.Parent.Config.Skins)

local GuideRules = {}

-- (Lane: inside the lane's box; the ARMORY and the portal: from the front edge you walk up to)
GuideRules.Near = { Lane = 0, Gate = 9, Pad = 5, Armory = 7, Boxes = 14, Portal = 7 }

local function number(v) return type(v) == 'number' and v == v and v or 0 end

-- The first free lane (BAY 1): no rebirths, no pass, no Robux.
function GuideRules.firstLane()
	for _, s in Skins.Stations do
		if (s.Rebirths or 0) == 0 and not s.Pass and not s.RobuxPrice then return s.Id end
	end
	return Skins.Stations[1] and Skins.Stations[1].Id or nil
end

function GuideRules.target(goal, state)
	state = state or {}
	if not goal then
		return (number(state.World) <= 1) and { Kind = 'Portal' } or nil
	end
	local need = goal.Need or {}
	local rebirths = number(state.Rebirths)
	if need.Range then
		local st = Skins.Stations[need.Range]
		if not st or (st.Rebirths or 0) > rebirths then return nil end
		return { Kind = 'Lane', Station = st.Id }
	end
	if need.Power then return { Kind = 'Lane', Station = GuideRules.firstLane() } end
	if need.Guns then return { Kind = 'Armory' } end
	if need.Boxes then return { Kind = 'Boxes' } end
	if need.Rebirths then return nil end
	local cleared = number(state.RunCleared)
	if need.CashOuts then
		if cleared >= 1 then return { Kind = 'Pad', Stage = cleared } end
		return { Kind = 'Gate', Stage = 1 }
	end
	if need.CashOutStage then
		if cleared >= need.CashOutStage then return { Kind = 'Pad', Stage = cleared } end
		return { Kind = 'Gate', Stage = need.CashOutStage }
	end
	if need.Wave then return { Kind = 'Gate', Stage = need.Wave } end
	if need.Stages then return { Kind = 'Gate', Stage = need.Stages } end
	return nil
end

return GuideRules

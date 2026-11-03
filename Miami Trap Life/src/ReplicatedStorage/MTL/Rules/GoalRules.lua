--!strict
-- Pure FreePlay goal evaluation (no Instances; unit-tested in tools/tests/test_flat_rules.py).
-- Input: a save snapshot (data). Output: one entry per visible goal, in Config/Goals order:
--   { id, title, sub, done, claimed, soon, progress (0..1), progressText, action, reward }
-- `claimed` = the reward was already given (data.Goals.Done[id]); a claimed goal stays done even if the number
-- drops again later (spending cash never "un-does" Save5k).
local Goals = require(script.Parent.Parent.Config.Goals)

local GoalRules = {}

local function money(n: number): string
	local s = tostring(math.floor(n))
	local out = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	if out:sub(1, 1) == "," then
		out = out:sub(2)
	end
	return "$" .. out
end
GoalRules.money = money

local function count(t: any): number
	local n = 0
	if type(t) == "table" then
		for _, v in t do
			if v then
				n += 1
			end
		end
	end
	return n
end

-- (done, progress 0..1, progressText) for one goal definition.
function GoalRules.check(g: any, d: any): (boolean, number, string)
	local kind = g.kind
	if kind == "power" then
		local on = d.Home ~= nil and d.Home.PowerOn == true
		if on then
			return true, 1, "Power on"
		end
		local cash = d.Cash or 0
		local need = g.amount or 1
		return false, math.clamp(cash / math.max(need, 1), 0, 1), money(math.min(cash, need)) .. " / " .. money(need)
	elseif kind == "shifts" then
		local job = d.Job and d.Job.Current or ""
		local n = (job ~= "" and d.Job.Shifts and d.Job.Shifts[job]) or 0
		local need = g.count or 1
		return n >= need, math.clamp(n / need, 0, 1), string.format("%d / %d", math.min(n, need), need)
	elseif kind == "level" then
		local lv = d.Level or 1
		return lv >= g.level, math.clamp(lv / g.level, 0, 1), string.format("Level %d / %d", math.min(lv, g.level), g.level)
	elseif kind == "cash" then
		local cash = d.Cash or 0
		return cash >= g.amount, math.clamp(cash / g.amount, 0, 1), money(math.min(cash, g.amount)) .. " / " .. money(g.amount)
	elseif kind == "car" then
		-- done once you've bought any car at the dealer (Garage.Bought; the free bike/truck don't count)
		local n = count(d.Garage and d.Garage.Bought)
		if n > 0 then
			return true, 1, "Bought"
		end
		local cash = d.Cash or 0
		local need = g.amount or 1
		return false, math.clamp(cash / math.max(need, 1), 0, 1), money(math.min(cash, need)) .. " / " .. money(need)
	elseif kind == "guns" then
		local n = count(d.Inventory and d.Inventory.Guns)
		local need = g.count or 1
		return n >= need, math.clamp(n / need, 0, 1), string.format("%d / %d", math.min(n, need), need)
	end
	return false, 0, "Coming soon"
end

function GoalRules.visible(g: any, d: any): boolean
	return g.path == nil or g.path == d.Path
end

function GoalRules.evaluate(d: any, list: { any }?): { any }
	local out = {}
	local claimedSet = (d.Goals and d.Goals.Done) or {}
	for _, g in list or Goals.List do
		if GoalRules.visible(g, d) then
			local soon = g.kind == "soon"
			local done, progress, text = GoalRules.check(g, d)
			local claimed = claimedSet[g.id] ~= nil
			table.insert(out, {
				id = g.id,
				title = g.title,
				sub = g.sub,
				done = (done or claimed) and not soon,
				claimed = claimed,
				soon = soon,
				progress = if claimed then 1 else progress,
				progressText = if claimed and not done then "Done" else text,
				action = g.action,
				reward = g.reward or 0,
			})
		end
	end
	return out
end

-- The first goal that is not done and not "soon" (or nil when everything playable is done).
function GoalRules.top(d: any, list: { any }?): any?
	for _, e in GoalRules.evaluate(d, list) do
		if not e.done and not e.soon then
			return e
		end
	end
	return nil
end

-- Goals that are done but not yet rewarded (the server pays these once and records them).
function GoalRules.newlyDone(d: any, list: { any }?): { any }
	local out = {}
	for _, e in GoalRules.evaluate(d, list) do
		if e.done and not e.claimed then
			table.insert(out, e)
		end
	end
	return out
end

-- The HUD objective line for free play.
function GoalRules.objective(d: any, prefix: string?, list: { any }?): string
	local top = GoalRules.top(d, list)
	if not top then
		return ""
	end
	return (prefix or Goals.ObjectivePrefix) .. top.title .. "  (" .. top.progressText .. ")"
end

return GoalRules

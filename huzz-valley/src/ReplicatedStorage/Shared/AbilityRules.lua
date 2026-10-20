--[[
	Bought abilities (owner, Oct 20 15:13: "Please then make the abilities be bought, add a few more abilities").
	Pure rules (no Instances) for ActionService ("BuyAbility", "EquipAbility"), HuzzServer/PowerService (which power
	goes in each slot, the cooldown check), DataService (old saves) and the UI (UI/AbilityCards, Screens/Loadout);
	tests/AbilityRules.spec.
	  * Saved: Abilities[name] = true for each one bought; Loadout = { Runner, CatcherQ, CatcherE } (Config/Powers.Loadout).
	  * Owned = Starter (Shield, Bear Trap, Slow Wave), Free (Speed Boost) or bought. Coins only, never Robux.
	  * The loadout only ever holds abilities you own on the right side; anything else falls back to the default, so a
	    broken or old save always plays. The catcher's Q and E are never the same ability.
	  * Runner "Random": one of the runner abilities you own, never the same as last round when you own two or more.
	  * Old saves (made before abilities were bought, no Abilities table yet) keep every ability they could already
	    roll: Shield, Invisible, Glitchy and Body Double (Config/Powers.Grandfathered). Fairer than one free starter
	    for them: nobody loses what they had. New saves start with one per side (Shield; Bear Trap + Slow Wave, since a
	    catcher has two keys) and buy the rest.
]]
local Powers = require(script.Parent.Config.Powers)

local AbilityRules = {}

AbilityRules.GRACE = 0.15 -- seconds a press may come early (the card's clock and the server's differ a little)

-- The ability's definition, only for real abilities (a table in Config/Powers with a Side).
function AbilityRules.def(name: any)
	local d = type(name) == "string" and Powers[name]
	return if type(d) == "table" and d.Side ~= nil then d else nil
end

function AbilityRules.owns(data: any, name: any): boolean
	local d = AbilityRules.def(name)
	if not d then return false end
	if d.Starter or d.Free then return true end
	local owned = type(data) == "table" and data.Abilities
	return type(owned) == "table" and owned[name] == true
end

-- Everything you could put on a side, in the shop's order: { name, owned }.
function AbilityRules.list(data: any, side: string)
	local out = {}
	for _, name in Powers.Shop[side] or {} do
		table.insert(out, { name = name, owned = AbilityRules.owns(data, name) })
	end
	return out
end

-- Buys one with coins: true, or false and why (the words the player sees). Edits data in place.
function AbilityRules.buy(data: any, name: any): (boolean, string?)
	local d = AbilityRules.def(name)
	if not d or d.Free then return false, "Unknown ability." end
	if AbilityRules.owns(data, name) then return false, "You own this already." end
	local price = d.Price or 0
	if type(price) ~= "number" or price <= 0 then return false, "That one can't be bought." end
	local coins = if type(data.Coins) == "number" then data.Coins else 0
	if coins < price then return false, `You need {price - coins} more coins.` end
	data.Coins = coins - price
	data.Abilities = if type(data.Abilities) == "table" then data.Abilities else {}
	data.Abilities[name] = true
	return true
end

-- The loadout to play with: the saved one where it's still valid, the default anywhere it isn't.
function AbilityRules.loadout(data: any)
	local saved = type(data) == "table" and type(data.Loadout) == "table" and data.Loadout or {}
	local out = {}
	for key, side in Powers.Loadout.Sides do
		local v = saved[key]
		local d = AbilityRules.def(v)
		local ok = (key == "Runner" and v == "Random") or (d ~= nil and d.Side == side and not d.Free and AbilityRules.owns(data, v))
		out[key] = if ok then v else Powers.Loadout.Default[key]
	end
	if out.CatcherQ == out.CatcherE then
		-- (two the same: the other default takes E, or Q when E was the default)
		local dq, de = Powers.Loadout.Default.CatcherQ, Powers.Loadout.Default.CatcherE
		if out.CatcherQ == dq then out.CatcherE = de else out.CatcherE = dq end
		if out.CatcherQ == out.CatcherE then out.CatcherQ = dq end
	end
	return out
end

-- Puts an owned ability (or "Random" for the runner) in a loadout key. Catcher: picking the one already in the other
-- key swaps them. Edits data in place: true, or false and why.
function AbilityRules.equip(data: any, key: any, name: any): (boolean, string?)
	local side = type(key) == "string" and Powers.Loadout.Sides[key]
	if not side then return false, "Unknown slot." end
	if not (key == "Runner" and name == "Random") then
		local d = AbilityRules.def(name)
		if not d or d.Free then return false, "Unknown ability." end
		if d.Side ~= side then return false, `That one is for {string.lower(d.Side)}s.` end
		if not AbilityRules.owns(data, name) then return false, "Buy it first." end
	end
	local now = AbilityRules.loadout(data)
	if side == "Catcher" then
		local other = if key == "CatcherQ" then "CatcherE" else "CatcherQ"
		if now[other] == name then now[other] = now[key] end
	end
	now[key] = name
	data.Loadout = now
	return true
end

-- The runner's ability this round: their pick, or for Random one they own (not last round's when they own two or
-- more). rand(n) gives 1..n (math.random or a Random's NextInteger).
function AbilityRules.runnerPick(data: any, last: string?, rand: ((number) -> number)?): string
	local pick = AbilityRules.loadout(data).Runner
	if pick ~= "Random" then return pick end
	local pool, all = {}, {}
	for _, e in AbilityRules.list(data, "Runner") do
		if e.owned then
			table.insert(all, e.name)
			if e.name ~= last then table.insert(pool, e.name) end
		end
	end
	if #pool == 0 then pool = all end
	if #pool == 0 then return "Shield" end
	local r = rand or function(n) return math.random(1, n) end
	return pool[math.clamp(r(#pool), 1, #pool)]
end

-- Which power goes in a slot (1 = Q, 2 = E) for a role, from a loadout (AbilityRules.loadout) and this round's runner
-- pick. nil when the role has no such slot.
function AbilityRules.slot(role: string?, slot: number, loadout: any, runnerPick: string?): string?
	local list = role and Powers[role]
	local entry = type(list) == "table" and list[slot]
	if type(entry) == "string" then return entry end
	if type(entry) ~= "table" then return nil end
	if entry.Loadout == "Runner" then return runnerPick or (loadout and loadout.Runner) end
	return loadout and loadout[entry.Loadout]
end

-- Cooldowns: a slot's ready time is a server time; -1 = used up this round (once per round). A press counts from
-- GRACE before it's ready.
function AbilityRules.canUse(readyAt: number?, now: number): boolean
	local r = readyAt or 0
	return r >= 0 and now >= r - AbilityRules.GRACE
end

-- When a slot is ready again after a use at `now`: -1 for a once-a-round power.
function AbilityRules.nextReady(name: string, now: number): number
	local d = Powers[name]
	if d.OncePerRound then return -1 end
	return now + (d.Cooldown or 0)
end

-- Seconds left on a cooldown (0 when ready; math.huge when used up for the round).
function AbilityRules.left(readyAt: number?, now: number): number
	local r = readyAt or 0
	if r < 0 then return math.huge end
	return math.max(0, r - now)
end

-- Old saves: `hadAbilities` = the save already had an Abilities table before the template filled it in. A save
-- without one was made before abilities were bought: it keeps every runner ability it could roll. Returns true when
-- it gave anything. Safe to run on every load.
function AbilityRules.migrate(data: any, hadAbilities: boolean): boolean
	if type(data) ~= "table" then return false end
	if type(data.Abilities) ~= "table" then data.Abilities = {} end
	if type(data.Loadout) ~= "table" then data.Loadout = {} end
	if hadAbilities then return false end
	local gave = false
	for _, name in Powers.Grandfathered do
		local d = AbilityRules.def(name)
		if d and not d.Starter and not data.Abilities[name] then
			data.Abilities[name] = true
			gave = true
		end
	end
	return gave
end

return AbilityRules

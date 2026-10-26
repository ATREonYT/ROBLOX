--[[
	The winner page's standings (Screens/Results; owner, Oct 19: "winner page", his picture
	design/owner-oct19/pic-a-winner-page.png): pure rules, no Instances (tests/Standings.spec).
	RoundService sends every player's numbers for the game ("board": user, name, crossed, catches, rescues, heroes,
	won); each tab ranks them by one number and the page shows the top 3:
	  MVP       points: a catch, a save or a Hero run 3, a crossing 2, being on the winning side 5
	  Survival  crossings (each one is a round you got through)
	  Catches   catches
	Equal numbers share a place ("Joint #3", as in his picture); nobody with 0 is shown.
]]
local Standings = {}

Standings.Tabs = {
	{ Key = "MVP", Text = "MVP", Sub = "Most Valuable", One = "Point", Many = "Points" },
	{ Key = "Survival", Text = "Survival", Sub = "Most Crossings", One = "Crossing", Many = "Crossings" },
	{ Key = "Catches", Text = "Catches", Sub = "Most Catches", One = "Catch", Many = "Catches" },
}
Standings.Points = { Catch = 3, Rescue = 3, Hero = 3, Cross = 2, Won = 5 }

local function n(v: any): number
	return math.max(0, math.floor(tonumber(v) or 0))
end

function Standings.value(e: any, key: string): number
	if key == "Survival" then return n(e.crossed) end
	if key == "Catches" then return n(e.catches) end
	local P = Standings.Points
	return P.Catch * n(e.catches) + P.Rescue * n(e.rescues) + P.Hero * n(e.heroes) + P.Cross * n(e.crossed) + (if e.won == true then P.Won else 0)
end

function Standings.tab(key: string)
	for _, t in Standings.Tabs do
		if t.Key == key then return t end
	end
	return Standings.Tabs[1]
end

-- "11 Catches" / "1 Catch"
function Standings.text(key: string, value: number): string
	local t = Standings.tab(key)
	return `{value} {if value == 1 then t.One else t.Many}`
end

-- The top `count` (3) by this tab: { { entry, value, place, joint } } best first; ties share a place.
-- Same numbers keep the board's order (the server's), then names A to Z, so the page never shuffles.
function Standings.top(board: { any }, key: string, count: number?): { any }
	local list = {}
	for i, e in board or {} do
		local v = Standings.value(e, key)
		if v > 0 then table.insert(list, { entry = e, value = v, order = i }) end
	end
	table.sort(list, function(a, b)
		if a.value ~= b.value then return a.value > b.value end
		local an, bn = tostring(a.entry.name or ""), tostring(b.entry.name or "")
		if an ~= bn then return an < bn end
		return a.order < b.order
	end)
	local out = {}
	for i, r in list do
		if i > (count or 3) then break end
		local place = i
		if i > 1 and r.value == list[i - 1].value then place = out[i - 1].place end
		out[i] = { entry = r.entry, value = r.value, place = place, joint = false }
	end
	for i, r in out do
		local before, after = out[i - 1], list[i + 1]
		r.joint = (before ~= nil and before.value == r.value) or (after ~= nil and after.value == r.value)
	end
	return out
end

-- "#1", "Joint #3"
function Standings.placeText(r: any): string
	return (if r.joint then "Joint #" else "#") .. tostring(r.place)
end

-- The tab the page opens on: the winning side's number (catchers: Catches; runners: Survival; the bot: MVP).
function Standings.defaultTab(team: string?, bot: boolean?): string
	if bot then return "MVP" end
	if team == "Catchers" then return "Catches" end
	if team == "Runners" then return "Survival" end
	return "MVP"
end

return Standings

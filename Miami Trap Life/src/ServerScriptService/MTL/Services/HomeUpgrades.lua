--!strict
-- Liberty OS "Home" app, server half (registered by DeskService). The flat's upgrade tiers (Config/OS.Home):
--   state        -> { tier, tiers = {{ tier, title, price, level, lines, owned, can, why }...} }
--   buy { tier } -> next tier only, level + cash checked; sets Home.Tier and asks PropertyService to re-dress
--                   the room when the player gets up from the desk (the monitor and chair they're using are
--                   tiered too), via PropertyService.refreshTier(player) behind a short fade: you stand, the
--                   screen dips, and the flat is new.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local OS = require(ReplicatedStorage.MTL.Config.OS)
local DataService = require(script.Parent.DataService)
local EconomyService = require(script.Parent.EconomyService)

local HomeUpgrades = {}

local pending: { [Player]: boolean } = {}

local function redress(player: Player)
	local okP, PropertyService = pcall(require, script.Parent.PropertyService)
	if okP and type(PropertyService) == "table" and (PropertyService :: any).refreshTier then
		task.spawn((PropertyService :: any).refreshTier, player)
	end
end

local function tierOf(d: any): number
	local h = d.Home or {}
	return math.clamp(tonumber(h.Tier) or 0, 0, OS.Home.Max)
end

local function state(d: any): any
	local cur = tierOf(d)
	local out = {}
	for i = 0, OS.Home.Max do
		local t = OS.Home.Tiers[i]
		local why: string? = nil
		if i <= cur then
			why = nil
		elseif i > cur + 1 then
			why = "Buy " .. OS.Home.Tiers[i - 1].title .. " first"
		elseif (d.Level or 1) < t.level then
			why = "Level " .. t.level
		elseif d.Cash < t.price then
			why = "Need $" .. t.price
		end
		table.insert(out, { tier = i, title = t.title, price = t.price, level = t.level, lines = t.lines, owned = i <= cur, can = i == cur + 1 and why == nil, why = why })
	end
	return { ok = true, tier = cur, tiers = out }
end

function HomeUpgrades.handle(player: Player, action: string, args: any): any
	local d = DataService.get(player)
	if not d then
		return { ok = false, err = "Still loading" }
	end
	if action == "state" then
		return state(d)
	elseif action == "buy" then
		local want = if type(args) == "table" then tonumber(args.tier) else nil
		local cur = tierOf(d)
		if want ~= cur + 1 or want > OS.Home.Max then
			return { ok = false, err = "Upgrade in order" }
		end
		local t = OS.Home.Tiers[want]
		if (d.Level or 1) < t.level then
			return { ok = false, err = "Unlocks at Level " .. t.level }
		end
		if not EconomyService.spend(player, t.price, "HomeUpgrade") then
			return { ok = false, err = "Not enough cash" }
		end
		d.Home = d.Home or {}
		d.Home.Tier = want
		EconomyService.addXP(player, OS.Home.XP, "HomeUpgrade")
		DataService.push(player)
		pending[player] = true
		local res = state(d)
		res.bought = want
		return res
	end
	return { ok = false, err = "Unknown action" }
end

function HomeUpgrades.onStand(player: Player)
	if pending[player] then
		pending[player] = nil
		redress(player)
	end
end

function HomeUpgrades.init(_desk: any)
	game:GetService("Players").PlayerRemoving:Connect(function(p)
		pending[p] = nil
	end)
end

return HomeUpgrades

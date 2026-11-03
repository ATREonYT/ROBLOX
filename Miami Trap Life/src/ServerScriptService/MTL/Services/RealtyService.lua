--!strict
-- Royce Realty (Liberty OS app "Realty", server half; vault §5). Buying a property is a PC action; using it is a
-- map action (FreightService / ReUpService / PropertyService read Realty.Owned).
--   list         -> { props = {{ id, ...listing, owned, can, why }}, cash, level }
--   buy { id }   -> level/path/needs/cash checked, Realty.Owned[id] = os.time(), XP, Mail-style toast
--   gps { id }   -> sets a waypoint to the property's door (works seated; shows when you stand up)
-- API: RealtyService.owns(player, id) -> bool · RealtyService.Bought (Signal: player, id)
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Realty = require(ReplicatedStorage.MTL.Config.Realty)
local Signal = require(ReplicatedStorage.MTL.Signal)
local DataService = require(script.Parent.DataService)
local EconomyService = require(script.Parent.EconomyService)
local Notify = require(script.Parent.Notify)
local WaypointService = require(script.Parent.WaypointService)

local RealtyService = {}
RealtyService.Bought = Signal.new()

local function owned(d: any): { [string]: number }
	d.Realty = d.Realty or {}
	d.Realty.Owned = d.Realty.Owned or {}
	return d.Realty.Owned
end

local function cratesSold(d: any): number
	local n = 0
	for _, w in (d.Freight or {}) do
		if type(w) == "table" then
			n += tonumber(w.Sold) or 0
		end
	end
	return n
end

local function packsSold(d: any): number
	return tonumber(d.ReUp and d.ReUp.Sold) or 0
end

-- nil = can buy; otherwise the reason shown on the listing.
local function why(d: any, id: string): string?
	local p = Realty.Props[id]
	if owned(d)[id] then
		return nil
	end
	if (d.Level or 1) < p.level then
		return "Level " .. p.level
	end
	local n = p.needs
	if n then
		if n.path and d.Path ~= n.path then
			return n.path .. " life only"
		end
		if n.own and not owned(d)[n.own] then
			return "Own the " .. Realty.Props[n.own].title
		end
		if n.crates and cratesSold(d) < n.crates then
			return string.format("Sell %d crates (%d/%d)", n.crates, cratesSold(d), n.crates)
		end
		if n.packs and packsSold(d) < n.packs then
			return string.format("Move %d packs (%d/%d)", n.packs, packsSold(d), n.packs)
		end
	end
	if p.at == Vector3.zero then
		return "Coming soon"
	end
	return nil
end

function RealtyService.owns(player: Player, id: string): boolean
	local d = DataService.get(player)
	return d ~= nil and owned(d)[id] ~= nil
end

local function list(d: any): any
	local out = {}
	for _, id in Realty.Order do
		local p = Realty.Props[id]
		local w = why(d, id)
		table.insert(out, {
			id = id,
			title = p.title,
			area = p.area,
			kind = p.kind,
			price = p.price,
			level = p.level,
			cap = p.cap,
			size = p.size,
			blurb = p.blurb,
			owned = owned(d)[id] ~= nil,
			can = w == nil and owned(d)[id] == nil and d.Cash >= p.price,
			why = w or (if d.Cash < p.price and not owned(d)[id] then "Need $" .. p.price else nil),
		})
	end
	return { ok = true, props = out, cash = d.Cash, level = d.Level }
end

function RealtyService.handle(player: Player, action: string, args: any): any
	local d = DataService.get(player)
	if not d then
		return { ok = false, err = "Still loading" }
	end
	local id = if type(args) == "table" then tostring(args.id) else ""
	local p = Realty.Props[id]
	if action == "list" then
		return list(d)
	elseif action == "buy" then
		if not p then
			return { ok = false, err = "Unknown property" }
		end
		if owned(d)[id] then
			return { ok = false, err = "You already own it" }
		end
		local w = why(d, id)
		if w then
			return { ok = false, err = w }
		end
		if not EconomyService.spend(player, p.price, "Realty:" .. id) then
			return { ok = false, err = "Not enough cash" }
		end
		owned(d)[id] = os.time()
		EconomyService.addXP(player, Realty.XP, "Realty")
		DataService.push(player)
		RealtyService.Bought:Fire(player, id)
		Notify.banner(player, "PROPERTY BOUGHT", p.title .. " · " .. p.area, Color3.fromRGB(240, 192, 72))
		local res = list(d)
		res.bought = id
		return res
	elseif action == "gps" then
		if not p or p.at == Vector3.zero then
			return { ok = false, err = "Unknown property" }
		end
		WaypointService.set(player, "Realty", p.at, { label = p.title, radius = 14, breadcrumbs = true })
		return { ok = true }
	end
	return { ok = false, err = "Unknown action" }
end

function RealtyService.init(_desk: any)
	WaypointService.Arrived:Connect(function(player: Player, wid: string)
		if wid == "Realty" then
			WaypointService.clear(player, "Realty")
		end
	end)
end

return RealtyService

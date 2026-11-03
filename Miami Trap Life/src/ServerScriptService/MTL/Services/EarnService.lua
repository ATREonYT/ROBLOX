--!strict
-- The Money app's server side: "earnRoute" { id } sets the GPS to where that way of earning starts
-- (Config/Earn entry: location = a Config/Locations key, or position). Uses the phone's GPS waypoint, so the
-- wayfinding trail and the GPS app's "clear" both work on it. Locations is read here on the server, where
-- JobService has already moved job sites onto the real map spots.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Earn = require(ReplicatedStorage.MTL.Config.Earn)
local Locations = require(ReplicatedStorage.MTL.Config.Locations)
local PhoneConfig = require(ReplicatedStorage.MTL.Config.Phone)
local PhoneService = require(script.Parent.PhoneService)
local WaypointService = require(script.Parent.WaypointService)
local Notify = require(script.Parent.Notify)

local EarnService = {}

local function resolve(m: any): (Vector3?, number)
	if typeof(m.position) == "Vector3" then
		return m.position, 14
	end
	local loc = m.location and (Locations :: any)[m.location]
	if typeof(loc) == "Vector3" then
		return loc, 14
	elseif type(loc) == "table" then
		local p = loc.Door or loc.Position or loc.Inside
		if typeof(p) == "Vector3" then
			return p, loc.Radius or 14
		end
	end
	return nil, 0
end

function EarnService.route(player: Player, id: string): boolean
	local m = Earn.get(id)
	if not m then
		return false
	end
	local pos, radius = resolve(m)
	if not pos then
		Notify.toast(player, "No map spot for that one yet")
		return false
	end
	WaypointService.set(player, PhoneConfig.GPSWaypointId, pos, { label = m.title, radius = radius })
	player:SetAttribute("MTL_GPS", id)
	return true
end

function EarnService.init()
	PhoneService.onAction("earnRoute", function(player, payload)
		if type(payload.id) == "string" and #payload.id < 64 then
			if EarnService.route(player, payload.id) then
				Notify.toast(player, "GPS set")
			end
		end
	end)
end

return EarnService

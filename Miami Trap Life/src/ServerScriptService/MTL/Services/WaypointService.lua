--!strict
-- Server-owned waypoints. set() shows a marker + ground breadcrumbs on the player's screen (WayfindingController)
-- and the SERVER checks arrival (distance from the character), then fires Arrived. Clients can't fake arriving.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage.MTL.Net)
local Signal = require(ReplicatedStorage.MTL.Signal)

local WaypointService = {}
WaypointService.Arrived = Signal.new() -- (player, id)

type Waypoint = { id: string, position: Vector3, label: string, radius: number, breadcrumbs: boolean }
local active: { [Player]: { [string]: Waypoint } } = {}

-- opts: { label = "Liberty Food Mart", radius = 12, breadcrumbs = true }
function WaypointService.set(player: Player, id: string, position: Vector3, opts: { [string]: any }?)
	local o = opts or {}
	local wp: Waypoint = {
		id = id,
		position = position,
		label = o.label or "",
		radius = o.radius or 12,
		breadcrumbs = if o.breadcrumbs == nil then true else o.breadcrumbs,
	}
	active[player] = active[player] or {}
	active[player][id] = wp
	Net.get("Waypoint"):FireClient(player, wp)
end

function WaypointService.clear(player: Player, id: string)
	local list = active[player]
	if list and list[id] then
		list[id] = nil
		Net.get("Waypoint"):FireClient(player, { id = id, clear = true })
	end
end

function WaypointService.has(player: Player, id: string): boolean
	return active[player] ~= nil and active[player][id] ~= nil
end

-- Re-sends every active waypoint (after a respawn the client rebuilds its markers).
function WaypointService.resend(player: Player)
	for _, wp in active[player] or {} do
		Net.get("Waypoint"):FireClient(player, wp)
	end
end

function WaypointService.init()
	Players.PlayerRemoving:Connect(function(p)
		active[p] = nil
	end)
	Net.get("ClientReady").OnServerEvent:Connect(function(p)
		WaypointService.resend(p) -- covers first join and every respawn (the client re-sends ClientReady)
	end)

	task.spawn(function()
		while true do
			task.wait(0.25)
			for player, list in active do
				local char = player.Character
				local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
				if root then
					for id, wp in list do
						-- flat distance + generous height, so stairs/kerbs never block arrival
						local d = root.Position - wp.position
						if Vector2.new(d.X, d.Z).Magnitude <= wp.radius and math.abs(d.Y) <= 20 then
							list[id] = nil
							Net.get("Waypoint"):FireClient(player, { id = id, clear = true, arrived = true })
							WaypointService.Arrived:Fire(player, id)
						end
					end
				end
			end
		end
	end)
end

return WaypointService

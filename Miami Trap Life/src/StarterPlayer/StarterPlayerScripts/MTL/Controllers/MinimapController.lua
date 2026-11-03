--!strict
-- The round radar in the bottom-left corner (top-left on touch screens, clear of the thumbstick), a gold GPS route
-- along the roads to the current waypoint, and a full-screen map (N, the MAP menu tile, or tap the radar) where you
-- drop your own waypoint. Original look: the HUD's plain dark grey (Theme.HUD) with gold for "go here" (UI/Guide).
--
-- How it draws (cheap enough for phones):
--   * Roads are flat rectangles baked from the map (ReplicatedStorage.MTL_RoadMap, tools/BakeRoadMap.lua), one Frame
--     each, in world units (1 px = 1 stud) inside a size-0 "World" frame. A UIScale on the parent zooms, the parent's
--     Rotation turns the map with the camera, and a CanvasGroup with a round UICorner clips it to the circle.
--   * Road frames are grouped in 256-stud squares; only squares near you are Visible, so a few hundred draw at once.
--   * Blips (places, waypoints) sit outside the rotation and are placed by hand each frame so emoji stay upright,
--     and the waypoint sticks to the rim when it's off the radar.
--   * The route comes from Rules/RoadGraph (A* over road cells), refreshed every ~1 s while moving or when you
--     leave the line. Waypoints come from WayfindingController (server waypoints + the player's map pin).
-- API: Minimap.openMap() / Minimap.closeMap() / Minimap.toggleMap() / Minimap.graph() -> RoadGraph or nil
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")

local Theme = require(ReplicatedStorage.MTL.UI.Theme)
local Guide = require(ReplicatedStorage.MTL.UI.Guide)
local Motion = require(ReplicatedStorage.MTL.UI.Motion)
local Format = require(ReplicatedStorage.MTL.Format)
local RoadGraph = require(ReplicatedStorage.MTL.Rules.RoadGraph)
local StoryRules = require(ReplicatedStorage.MTL.Rules.StoryRules)
local PhoneRules = require(ReplicatedStorage.MTL.Rules.PhoneRules)
local Locations = require(ReplicatedStorage.MTL.Config.Locations)
local HUDConfig = require(ReplicatedStorage.MTL.Config.HUD)
local PhoneConfig = require(ReplicatedStorage.MTL.Config.Phone)
local Cfg = require(ReplicatedStorage.MTL.Config.Minimap)
local ClientData = require(script.Parent.ClientData)
local UIState = require(script.Parent.UIState)
local Wayfinder = require(script.Parent.WayfindingController)

local player = Players.LocalPlayer
local H = (Theme :: any).HUD
local MC = Cfg.Colors
local GOLD = Guide.Color

local Sfx: any = nil
do
	local m = ReplicatedStorage.MTL.UI:FindFirstChild("Sfx")
	if m then
		local ok, mod = pcall(require, m)
		Sfx = if ok then mod else nil
	end
end
local function sound(name: string)
	if Sfx then
		pcall(Sfx.play, name)
	end
end

local Minimap = {}

local function new(className: string, props: { [string]: any }): any
	local inst = Instance.new(className)
	for k, v in props do
		if k ~= "Parent" then
			(inst :: any)[k] = v
		end
	end
	if props.Parent then
		inst.Parent = props.Parent
	end
	return inst
end

local function round(parent: Instance)
	new("UICorner", { CornerRadius = UDim.new(1, 0), Parent = parent })
end

local function root(): BasePart?
	local char = player.Character
	return char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
end

---------------------------------------------------------------- data

local roadData: any = nil
local roadRects: { RoadGraph.Rect } = {}
local waterRects: { RoadGraph.Rect } = {}
local graph: RoadGraph.Graph? = nil

type Place = { name: string, emoji: string, pos: Vector3, requires: string?, place: any?, ok: boolean }
local places: { Place } = {}

local function buildPlaces()
	places = {}
	for _, m in HUDConfig.Markers.List do
		table.insert(places, { name = m.name, emoji = m.emoji, pos = m.pos, requires = m.requires, place = nil, ok = true })
	end
	for _, p in PhoneConfig.Places do
		local pos = PhoneRules.placePosition(p, Locations)
		if pos then
			local dup = false
			for _, q in places do
				if (q.pos - pos).Magnitude < 40 then
					dup = true
					break
				end
			end
			if not dup then
				local emoji = (Cfg.CategoryEmoji :: any)[p.category] or "📍"
				table.insert(places, { name = p.label, emoji = emoji, pos = pos, requires = p.requires, place = p, ok = false })
			end
		end
	end
end

local function refreshAllowed()
	local d = ClientData.get()
	local stage = d and d.Story and d.Story.Stage
	local ownsHome = d and d.Home and d.Home.Owned and next(d.Home.Owned) ~= nil
	for _, p in places do
		if p.place then
			p.ok = stage ~= nil and PhoneRules.placeVisible(p.place, stage, ownsHome == true)
		elseif p.requires then
			p.ok = stage ~= nil and StoryRules.reached(stage, p.requires)
		else
			p.ok = true
		end
	end
end

---------------------------------------------------------------- shared drawing

local function rectFrame(r: RoadGraph.Rect, color: Color3, pad: number, parent: Instance): Frame
	return new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromOffset(r.x, r.z),
		Size = UDim2.fromOffset(r.L + pad, r.W + pad),
		Rotation = r.ang,
		BackgroundColor3 = color,
		BorderSizePixel = 0,
		Parent = parent,
	})
end

type Cell = { frame: Frame, x: number, z: number }

-- Draws water + roads into `world` as three layers (water < streets < raised roads) and returns the cull cells.
-- yields between chunks so a phone never stalls on the first frame
local function drawMap(world: Frame, cull: boolean): { Cell }
	local cells: { Cell } = {}
	local byKey: { [string]: { [string]: Frame } } = {}
	local layers = {}
	for i, name in { "Water", "Roads", "Raised" } do
		layers[name] = new("Frame", { Name = name, Size = UDim2.fromOffset(0, 0), BackgroundTransparency = 1, ZIndex = i, Parent = world })
	end
	local function holder(layer: string, r: RoadGraph.Rect): Instance
		if not cull or math.max(r.L, r.W) > Cfg.CullCell * 1.5 then
			return layers[layer]
		end
		local cx, cz = math.floor(r.x / Cfg.CullCell), math.floor(r.z / Cfg.CullCell)
		local k = cx .. "," .. cz
		local set = byKey[k]
		if not set then
			set = {}
			byKey[k] = set
		end
		local f = set[layer]
		if not f then
			f = new("Frame", { Name = k, Size = UDim2.fromOffset(0, 0), BackgroundTransparency = 1, Visible = false, Parent = layers[layer] })
			set[layer] = f
			table.insert(cells, { frame = f, x = (cx + 0.5) * Cfg.CullCell, z = (cz + 0.5) * Cfg.CullCell })
		end
		return f
	end
	local n = 0
	for _, r in waterRects do
		rectFrame(r, MC.Water, 0, holder("Water", r))
	end
	for _, r in roadRects do
		local raised = r.y >= 14
		rectFrame(r, if raised then MC.Highway else MC.Road, 2, holder(if raised then "Raised" else "Roads", r))
		n += 1
		if n % 400 == 0 then
			task.wait()
		end
	end
	return cells
end

type RouteDraw = { layer: Frame, frames: { Frame }, width: number }

local function newRouteDraw(world: Frame, width: number): RouteDraw
	local layer = new("Frame", { Name = "Route", Size = UDim2.fromOffset(0, 0), BackgroundTransparency = 1, ZIndex = 4, Parent = world })
	return { layer = layer, frames = {}, width = width }
end

local function drawRoute(rd: RouteDraw, pts: { Vector3 }?)
	local n = 0
	if pts then
		for i = 2, #pts do
			local a, b = pts[i - 1], pts[i]
			local dx, dz = b.X - a.X, b.Z - a.Z
			local len = math.sqrt(dx * dx + dz * dz)
			if len > 0.5 then
				n += 1
				local f = rd.frames[n]
				if not f then
					f = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), BackgroundColor3 = GOLD, BorderSizePixel = 0, Parent = rd.layer })
					round(f)
					rd.frames[n] = f
				end
				f.Position = UDim2.fromOffset((a.X + b.X) / 2, (a.Z + b.Z) / 2)
				f.Size = UDim2.fromOffset(len + rd.width, rd.width)
				f.Rotation = math.deg(math.atan2(dz, dx))
				f.Visible = true
			end
		end
	end
	for i = n + 1, #rd.frames do
		rd.frames[i].Visible = false
	end
end

local function makeBlip(emoji: string, size: number, parent: Instance): Frame
	local f = new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.fromOffset(size, size),
		BackgroundColor3 = H.Marker,
		BackgroundTransparency = H.MarkerTransparency,
		Visible = false,
		Parent = parent,
	})
	round(f)
	new("UIStroke", { Color = H.MarkerStroke, Transparency = 0.72, Thickness = 1, Parent = f })
	new("TextLabel", {
		Name = "Icon",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Text = emoji,
		TextSize = math.floor(size * 0.6),
		FontFace = H.Font,
		TextColor3 = H.Paper,
		Parent = f,
	})
	return f
end

-- gold diamond (the route target) / small gold dot (other waypoints)
local function makeWaypointBlip(primary: boolean, parent: Instance): Frame
	local s = if primary then 14 else 9
	local f = new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.fromOffset(s, s),
		Rotation = if primary then 45 else 0,
		BackgroundColor3 = GOLD,
		BorderSizePixel = 0,
		ZIndex = 3,
		Visible = false,
		Parent = parent,
	})
	if not primary then
		round(f)
	end
	new("UIStroke", { Color = H.Shadow, Transparency = 0.35, Thickness = 2, Parent = f })
	return f
end

---------------------------------------------------------------- route (shared by radar + full map)

local route: { Vector3 }? = nil
local routeFor: string? = nil
local routeTarget: Vector3? = nil
local routeFrom: Vector3? = nil
local lastRoute = 0
local radarRoute: RouteDraw? = nil
local mapRoute: RouteDraw? = nil
local routeLabel: TextLabel? = nil

local function distToRoute(p: Vector3): number
	local pts = route
	if not pts then
		return math.huge
	end
	local best = math.huge
	for i = 2, math.min(#pts, 6) do
		local a, b = pts[i - 1], pts[i]
		local abx, abz = b.X - a.X, b.Z - a.Z
		local len2 = abx * abx + abz * abz
		local t = if len2 > 0 then math.clamp(((p.X - a.X) * abx + (p.Z - a.Z) * abz) / len2, 0, 1) else 0
		local dx, dz = a.X + abx * t - p.X, a.Z + abz * t - p.Z
		best = math.min(best, math.sqrt(dx * dx + dz * dz))
	end
	return best
end

local function setRoute(pts: { Vector3 }?)
	route = pts
	if radarRoute then
		drawRoute(radarRoute, pts)
	end
	if mapRoute then
		drawRoute(mapRoute, pts)
	end
end

local function refreshRoute(force: boolean?)
	local wp = Wayfinder.primary()
	local r = root()
	if not wp or not r then
		if route then
			setRoute(nil)
		end
		routeFor, routeTarget = nil, nil
		if routeLabel then
			routeLabel.Visible = false
		end
		return
	end
	local me = r.Position
	local target: Vector3 = wp.position
	local flat = Vector2.new(me.X - target.X, me.Z - target.Z).Magnitude
	if flat <= (wp.radius or 12) + 4 then
		if route then
			setRoute(nil)
		end
		if routeLabel then
			routeLabel.Visible = false
		end
		return
	end
	local now = os.clock()
	local moved = if routeFrom then (me - routeFrom).Magnitude else math.huge
	local due = force
		or route == nil
		or routeFor ~= wp.id
		or (routeTarget and (routeTarget - target).Magnitude > 1)
		or distToRoute(me) > Cfg.OffRoute
		or (now - lastRoute > Cfg.Reroute and moved > 6)
	if due then
		lastRoute = now
		local pts: { Vector3 }? = nil
		if graph then
			pts = RoadGraph.route(graph, me, target)
		end
		if not pts then
			pts = { me, target } -- no road path (or the road data hasn't loaded): straight line
		end
		routeFor, routeTarget, routeFrom = wp.id, target, me
		setRoute(pts)
	end
	-- distance left along the line
	local pts = route
	if pts and routeLabel then
		local left = (Vector2.new(pts[2].X, pts[2].Z) - Vector2.new(me.X, me.Z)).Magnitude
		for i = 3, #pts do
			left += (Vector2.new(pts[i].X, pts[i].Z) - Vector2.new(pts[i - 1].X, pts[i - 1].Z)).Magnitude
		end
		routeLabel.Text = Format.distance(left)
		routeLabel.Visible = true
	end
end

---------------------------------------------------------------- radar

local gui: ScreenGui
local radar: Frame
local pivot: Frame
local world: Frame
local scaleObj: UIScale
local blipLayer: Frame
local arrow: TextLabel
local northTag: Frame
local streetLabel: TextLabel
local radarCells: { Cell } = {}
local radarBlips: { [Place]: Frame } = {}
local wpBlips: { [string]: Frame } = {}
local zoom = Cfg.ZoomFoot
local hidden = false
local mapOpen = false

local function isTouch(): boolean
	return UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
end

local function layout()
	local vp = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or Vector2.new(1280, 720)
	local size = if vp.Y < Cfg.SmallBelow then Cfg.SmallSize else Cfg.Size
	radar.Size = UDim2.fromOffset(size, size)
	if isTouch() then
		-- the thumbstick owns the bottom-left on phones; sit under the top bar instead
		local inset = GuiService:GetGuiInset()
		radar.AnchorPoint = Vector2.new(0, 0)
		radar.Position = UDim2.new(0, Cfg.Margin, 0, inset.Y + 8)
		streetLabel.AnchorPoint = Vector2.new(0, 0)
		streetLabel.Position = UDim2.new(0, 2, 1, 8)
	else
		radar.AnchorPoint = Vector2.new(0, 1)
		radar.Position = UDim2.new(0, Cfg.Margin, 1, -Cfg.Margin)
		streetLabel.AnchorPoint = Vector2.new(0, 1)
		streetLabel.Position = UDim2.new(0, 2, 0, -8)
	end
end

local function buildRadar()
	local pg = player:WaitForChild("PlayerGui")
	local old = pg:FindFirstChild("MTL_Minimap")
	if old then
		old:Destroy()
	end
	gui = new("ScreenGui", {
		Name = "MTL_Minimap",
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		DisplayOrder = 5, -- same layer as the HUD
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		Parent = pg,
	})
	radar = new("Frame", { Name = "Radar", BackgroundTransparency = 1, Parent = gui })
	local back = new("Frame", {
		Name = "Back",
		Position = UDim2.fromOffset(-4, -4),
		Size = UDim2.new(1, 8, 1, 8),
		BackgroundColor3 = H.Ink,
		BackgroundTransparency = H.InkTransparency,
		Parent = radar,
	})
	new("UIStroke", { Color = MC.Ring, Transparency = MC.RingTransparency, Thickness = 1.5, Parent = back })

	-- "Circle": a CanvasGroup clips the turning map to a true circle. "Rounded": plain rectangle clipping (works on
	-- every device, even where CanvasGroups fall back), drawn as a rounded square.
	local circle = Cfg.Shape ~= "Rounded"
	local clip = new(if circle then "CanvasGroup" else "Frame", {
		Name = "Clip",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = MC.Land,
		ClipsDescendants = true,
		ZIndex = 2,
		Parent = radar,
	})
	if circle then
		round(back)
		round(clip)
	else
		new("UICorner", { CornerRadius = UDim.new(0, 14), Parent = back })
		new("UICorner", { CornerRadius = UDim.new(0, 10), Parent = clip })
	end
	pivot = new("Frame", { Name = "Pivot", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(0, 0), BackgroundTransparency = 1, Parent = clip })
	scaleObj = new("UIScale", { Scale = zoom, Parent = pivot })
	world = new("Frame", { Name = "World", Size = UDim2.fromOffset(0, 0), BackgroundTransparency = 1, Parent = pivot })
	radarRoute = newRouteDraw(world, Cfg.RouteWidth)

	blipLayer = new("Frame", { Name = "Blips", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 3, Parent = radar })

	arrow = new("TextLabel", {
		Name = "You",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(20, 20),
		BackgroundTransparency = 1,
		Text = "▲",
		TextSize = 17,
		FontFace = H.Font,
		TextColor3 = MC.Player,
		ZIndex = 5,
		Parent = radar,
	})
	new("UIStroke", { Color = H.Shadow, Transparency = 0.25, Thickness = 2, Parent = arrow })

	northTag = new("Frame", {
		Name = "North",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.fromOffset(18, 18),
		BackgroundColor3 = H.Ink,
		ZIndex = 4,
		Parent = radar,
	})
	round(northTag)
	new("UIStroke", { Color = MC.Ring, Transparency = 0.6, Thickness = 1, Parent = northTag })
	new("TextLabel", {
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Text = "N",
		TextSize = 11,
		FontFace = H.Font,
		TextColor3 = H.Paper,
		ZIndex = 4,
		Parent = northTag,
	})

	local rl = new("TextLabel", {
		Name = "RouteDistance",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 1, -2),
		Size = UDim2.fromOffset(70, 22),
		BackgroundColor3 = H.Ink,
		Text = "",
		TextSize = 13,
		FontFace = H.Font,
		TextColor3 = GOLD,
		ZIndex = 6,
		Visible = false,
		Parent = radar,
	})
	new("UICorner", { CornerRadius = UDim.new(1, 0), Parent = rl })
	new("UIStroke", { Color = GOLD, Transparency = 0.5, Thickness = 1, Parent = rl })
	routeLabel = rl

	streetLabel = new("TextLabel", {
		Name = "Street",
		Size = UDim2.fromOffset(260, 18),
		BackgroundTransparency = 1,
		Text = "",
		TextSize = 15,
		FontFace = H.Font,
		TextColor3 = H.Paper,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 6,
		Parent = radar,
	})
	new("UIStroke", { Color = H.LabelStroke, Transparency = 0.45, Thickness = 1.5, Parent = streetLabel })

	local open = new("TextButton", {
		Name = "Open",
		Text = "",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 7,
		Parent = radar,
	})
	open.Activated:Connect(function()
		Minimap.openMap()
	end)

	for _, p in places do
		radarBlips[p] = makeBlip(p.emoji, Cfg.BlipSize, blipLayer)
	end

	layout()
	if workspace.CurrentCamera then
		workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(layout)
	end
end

local function cullRadar(me: Vector3)
	local R = radar.AbsoluteSize.X / 2
	local reach = R / math.max(zoom, 0.05) + Cfg.CullCell
	for _, c in radarCells do
		local dx, dz = c.x - me.X, c.z - me.Z
		c.frame.Visible = dx * dx + dz * dz <= reach * reach
	end
end

local lastCull = 0
local lastStreet = 0

local function stepRadar(dt: number)
	gui.Enabled = not hidden and not mapOpen
	if not gui.Enabled then
		return
	end
	local cam = workspace.CurrentCamera
	local r = root()
	if not cam or not r then
		return
	end
	local me = r.Position
	local v = r.AssemblyLinearVelocity
	local speed = Vector2.new(v.X, v.Z).Magnitude
	local k = math.clamp((speed - 18) / math.max(Cfg.DriveSpeed - 18, 1), 0, 1)
	local target = Cfg.ZoomFoot + (Cfg.ZoomDrive - Cfg.ZoomFoot) * k
	zoom += (target - zoom) * math.min(1, dt * 1.5)
	scaleObj.Scale = zoom
	world.Position = UDim2.fromOffset(-me.X, -me.Z)

	local yaw = 0
	if Cfg.RotateWithCamera then
		local look = cam.CFrame.LookVector
		if Vector2.new(look.X, look.Z).Magnitude > 0.05 then
			yaw = math.atan2(look.X, -look.Z)
		end
	end
	pivot.Rotation = -math.deg(yaw)
	local pl = r.CFrame.LookVector
	arrow.Rotation = math.deg(math.atan2(pl.X, -pl.Z) - yaw)

	local R = radar.AbsoluteSize.X / 2
	local c, s = math.cos(-yaw), math.sin(-yaw)
	local function place(p: Vector3): (number, number, number)
		local x, y = (p.X - me.X) * zoom, (p.Z - me.Z) * zoom
		local rx, ry = x * c - y * s, x * s + y * c
		return rx, ry, math.sqrt(rx * rx + ry * ry)
	end

	-- north tag rides the rim
	local nx, ny = 0 * c - (-1) * s, 0 * s + (-1) * c
	northTag.Position = UDim2.fromOffset(R + nx * (R - 1), R + ny * (R - 1))

	-- places: only inside the circle
	local inner = R - Cfg.BlipSize / 2 - 2
	for p, f in radarBlips do
		if p.ok then
			local x, y, d = place(p.pos)
			if d <= inner then
				f.Position = UDim2.fromOffset(R + x, R + y)
				f.Visible = true
			else
				f.Visible = false
			end
		else
			f.Visible = false
		end
	end

	-- waypoints: always shown, pinned to the rim when far
	local top = Wayfinder.primary()
	local seen: { [string]: boolean } = {}
	for _, wp in Wayfinder.list() do
		local primary = top ~= nil and wp.id == top.id
		local keyId = wp.id .. (if primary then "#p" else "")
		seen[keyId] = true
		local f = wpBlips[keyId]
		if not f then
			f = makeWaypointBlip(primary, blipLayer)
			wpBlips[keyId] = f
		end
		local x, y, d = place(wp.position)
		local rim = R - 7
		if d > rim then
			x, y = x / d * rim, y / d * rim
		end
		f.Position = UDim2.fromOffset(R + x, R + y)
		f.ZIndex = if primary then 4 else 3
		f.Visible = true
	end
	for id, f in wpBlips do
		if not seen[id] then
			f:Destroy()
			wpBlips[id] = nil
		end
	end

	local now = os.clock()
	if now - lastCull > 0.25 then
		lastCull = now
		cullRadar(me)
	end
	if graph and now - lastStreet > 0.5 then
		lastStreet = now
		streetLabel.Text = RoadGraph.streetAt(graph, me)
	end
end

---------------------------------------------------------------- full-screen map

local mapGui: ScreenGui? = nil
local mapView: Frame
local mapPivot: Frame
local mapWorld: Frame
local mapScale: UIScale
local mapBlipLayer: Frame
local mapYou: TextLabel
local mapClear: TextButton
local mapBlips: { [Place]: Frame } = {}
local mapWp: { [string]: Frame } = {}
local mapZoom = Cfg.MapZoomStart
local mapCenter = Vector2.zero -- world x/z at the middle of the view
local mapBuilt = false

local function viewCenter(): Vector2
	return mapView.AbsolutePosition + mapView.AbsoluteSize / 2
end

local function worldToScreen(p: Vector3): Vector2
	return viewCenter() + (Vector2.new(p.X, p.Z) - mapCenter) * mapZoom - mapView.AbsolutePosition
end

local function screenToWorld(sp: Vector2): Vector2
	return mapCenter + (sp - viewCenter()) / mapZoom
end

local function applyMapView()
	mapScale.Scale = mapZoom
	mapWorld.Position = UDim2.fromOffset(-mapCenter.X, -mapCenter.Y)
end

local function pinOf(): { [string]: any }?
	for _, wp in Wayfinder.list() do
		if wp.id == Cfg.PinId then
			return wp
		end
	end
	return nil
end

local function stepMap()
	if not mapOpen or not mapGui then
		return
	end
	local size = mapView.AbsoluteSize
	local showNames = mapZoom >= 0.42
	for p, f in mapBlips do
		if p.ok then
			local sp = worldToScreen(p.pos)
			local on = sp.X > -20 and sp.Y > -20 and sp.X < size.X + 20 and sp.Y < size.Y + 20
			f.Visible = on
			if on then
				f.Position = UDim2.fromOffset(sp.X, sp.Y)
				;(f:FindFirstChild("Name") :: TextLabel).Visible = showNames
			end
		else
			f.Visible = false
		end
	end
	local top = Wayfinder.primary()
	local seen: { [string]: boolean } = {}
	for _, wp in Wayfinder.list() do
		local primary = top ~= nil and wp.id == top.id
		local keyId = wp.id .. (if primary then "#p" else "")
		seen[keyId] = true
		local f = mapWp[keyId]
		if not f then
			f = makeWaypointBlip(primary, mapBlipLayer)
			f.Size = UDim2.fromOffset(if primary then 18 else 11, if primary then 18 else 11)
			mapWp[keyId] = f
		end
		local sp = worldToScreen(wp.position)
		f.Position = UDim2.fromOffset(sp.X, sp.Y)
		f.Visible = true
	end
	for id, f in mapWp do
		if not seen[id] then
			f:Destroy()
			mapWp[id] = nil
		end
	end
	local r = root()
	if r then
		local sp = worldToScreen(r.Position)
		mapYou.Position = UDim2.fromOffset(sp.X, sp.Y)
		local pl = r.CFrame.LookVector
		mapYou.Rotation = math.deg(math.atan2(pl.X, -pl.Z))
		mapYou.Visible = true
	else
		mapYou.Visible = false
	end
	mapClear.Visible = pinOf() ~= nil
end

local function setPin(pos: Vector3, label: string)
	Wayfinder.set(Cfg.PinId, pos, { label = label, radius = Cfg.PinArrive, breadcrumbs = true })
	sound("Tap")
	refreshRoute(true)
end

local function clearPin()
	Wayfinder.clear(Cfg.PinId)
	sound("Tap")
	refreshRoute(true)
end

local function mapClick(sp: Vector2)
	local rel = sp - mapView.AbsolutePosition
	-- on the pin: take it away
	local pin = pinOf()
	if pin and (worldToScreen(pin.position) - rel).Magnitude <= 18 then
		clearPin()
		return
	end
	-- on a place: route there
	local best: Place? = nil
	local bestD = 18
	for p, f in mapBlips do
		if p.ok and f.Visible then
			local d = (worldToScreen(p.pos) - rel).Magnitude
			if d < bestD then
				best, bestD = p, d
			end
		end
	end
	if best then
		setPin(best.pos, best.name)
		return
	end
	-- anywhere else: snap to the nearest road
	local w = screenToWorld(sp)
	local pos = Vector3.new(w.X, 3, w.Y)
	if graph then
		local id = RoadGraph.nearest(graph, pos, 160)
		if id then
			pos = Vector3.new(graph.nx[id], graph.ny[id] + 1, graph.nz[id])
		end
	end
	setPin(pos, "Waypoint")
end

local function buildMap()
	if mapBuilt then
		return
	end
	mapBuilt = true
	local pg = player:WaitForChild("PlayerGui")
	local g = new("ScreenGui", {
		Name = "MTL_BigMap",
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		DisplayOrder = 9, -- above the HUD (5), job (6), gun (7), mission (8); under the phone (10)
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		Enabled = false,
		Parent = pg,
	})
	mapGui = g
	new("Frame", { Name = "Dim", Size = UDim2.fromScale(1, 1), BackgroundColor3 = MC.Land, BackgroundTransparency = 0, BorderSizePixel = 0, Parent = g })
	mapView = new("Frame", { Name = "View", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ClipsDescendants = true, Active = true, ZIndex = 2, Parent = g })
	mapPivot = new("Frame", { Name = "Pivot", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(0, 0), BackgroundTransparency = 1, Parent = mapView })
	mapScale = new("UIScale", { Scale = mapZoom, Parent = mapPivot })
	mapWorld = new("Frame", { Name = "World", Size = UDim2.fromOffset(0, 0), BackgroundTransparency = 1, Parent = mapPivot })
	mapBlipLayer = new("Frame", { Name = "Blips", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 3, Parent = mapView })

	for _, p in places do
		local f = makeBlip(p.emoji, 28, mapBlipLayer)
		local name = new("TextLabel", {
			Name = "Name",
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, 0, 1, 3),
			Size = UDim2.fromOffset(160, 16),
			BackgroundTransparency = 1,
			Text = p.name,
			TextSize = 13,
			FontFace = H.BodyFont,
			TextColor3 = H.Paper,
			Visible = false,
			Parent = f,
		})
		new("UIStroke", { Color = H.LabelStroke, Transparency = 0.4, Thickness = 1.5, Parent = name })
		mapBlips[p] = f
	end
	mapYou = new("TextLabel", {
		Name = "You",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.fromOffset(26, 26),
		BackgroundTransparency = 1,
		Text = "▲",
		TextSize = 22,
		FontFace = H.Font,
		TextColor3 = MC.Player,
		ZIndex = 5,
		Parent = mapBlipLayer,
	})
	new("UIStroke", { Color = H.Shadow, Transparency = 0.2, Thickness = 2, Parent = mapYou })

	-- header + footer
	local bar = new("Frame", {
		Name = "Header",
		Size = UDim2.new(1, 0, 0, 64),
		BackgroundColor3 = H.Ink,
		BackgroundTransparency = 0.15,
		BorderSizePixel = 0,
		ZIndex = 10,
		Parent = g,
	})
	local inset = GuiService:GetGuiInset()
	new("UIPadding", { PaddingTop = UDim.new(0, math.max(inset.Y - 36, 0)), Parent = bar })
	new("TextLabel", {
		Name = "Title",
		Position = UDim2.fromOffset(24, 0),
		Size = UDim2.new(0, 200, 1, 0),
		BackgroundTransparency = 1,
		Text = "MAP",
		TextSize = 24,
		FontFace = H.Font,
		TextColor3 = H.Paper,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 10,
		Parent = bar,
	})
	local close = new("TextButton", {
		Name = "Close",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -18, 0.5, 0),
		Size = UDim2.fromOffset(44, 44),
		BackgroundColor3 = H.Ink2,
		Text = "✕",
		TextSize = 20,
		FontFace = H.Font,
		TextColor3 = H.Paper,
		AutoButtonColor = true,
		ZIndex = 10,
		Parent = bar,
	})
	new("UICorner", { CornerRadius = H.Corner, Parent = close })
	close.Activated:Connect(function()
		Minimap.closeMap()
	end)
	mapClear = new("TextButton", {
		Name = "ClearPin",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -74, 0.5, 0),
		Size = UDim2.fromOffset(170, 44),
		BackgroundColor3 = H.Ink2,
		Text = "Clear waypoint",
		TextSize = 15,
		FontFace = H.Font,
		TextColor3 = GOLD,
		AutoButtonColor = true,
		Visible = false,
		ZIndex = 10,
		Parent = bar,
	})
	new("UICorner", { CornerRadius = H.Corner, Parent = mapClear })
	mapClear.Activated:Connect(clearPin)

	local hint = new("TextLabel", {
		Name = "Hint",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -16),
		Size = UDim2.fromOffset(560, 34),
		BackgroundColor3 = H.Ink,
		BackgroundTransparency = 0.15,
		Text = if isTouch()
			then "Tap to set a waypoint  ·  Pinch to zoom  ·  Drag to move"
			else "Click to set a waypoint  ·  Scroll to zoom  ·  Drag to move  ·  N to close",
		TextSize = 14,
		FontFace = H.BodyFont,
		TextColor3 = H.Muted,
		ZIndex = 10,
		Parent = g,
	})
	new("UICorner", { CornerRadius = UDim.new(1, 0), Parent = hint })
	new("UISizeConstraint", { MaxSize = Vector2.new(560, 34), Parent = hint })
	hint.Size = UDim2.new(0.92, 0, 0, 34)

	-- input: drag to pan, click/tap to pin, wheel/pinch to zoom
	local drag: { start: Vector2, center: Vector2, moved: boolean, input: InputObject }? = nil
	local touches = 0
	mapView.InputBegan:Connect(function(input)
		local t = input.UserInputType
		if t == Enum.UserInputType.MouseButton1 or t == Enum.UserInputType.Touch then
			if t == Enum.UserInputType.Touch then
				touches += 1
			end
			if touches <= 1 then
				drag = { start = Vector2.new(input.Position.X, input.Position.Y), center = mapCenter, moved = false, input = input }
			else
				drag = nil -- second finger: pinch, not a tap
			end
		end
	end)
	UserInputService.InputChanged:Connect(function(input)
		if not mapOpen then
			return
		end
		local t = input.UserInputType
		if drag and (t == Enum.UserInputType.MouseMovement or (t == Enum.UserInputType.Touch and input == drag.input)) then
			local delta = Vector2.new(input.Position.X, input.Position.Y) - drag.start
			if delta.Magnitude > 6 then
				drag.moved = true
			end
			if drag.moved then
				mapCenter = drag.center - delta / mapZoom
				applyMapView()
			end
		elseif t == Enum.UserInputType.MouseWheel then
			local mp = UserInputService:GetMouseLocation() - GuiService:GetGuiInset()
			local before = screenToWorld(mp)
			mapZoom = math.clamp(mapZoom * (1.18 ^ input.Position.Z), Cfg.MapZoomMin, Cfg.MapZoomMax)
			mapCenter = before - (mp - viewCenter()) / mapZoom
			applyMapView()
		end
	end)
	UserInputService.InputEnded:Connect(function(input)
		local t = input.UserInputType
		if t == Enum.UserInputType.Touch then
			touches = math.max(0, touches - 1)
		end
		if not mapOpen or not drag then
			return
		end
		if t == Enum.UserInputType.MouseButton1 or (t == Enum.UserInputType.Touch and input == drag.input) then
			local d = drag
			drag = nil
			if not d.moved then
				mapClick(Vector2.new(input.Position.X, input.Position.Y))
			end
		end
	end)
	local pinchZoom = mapZoom
	UserInputService.TouchPinch:Connect(function(positions, scale, _velocity, state)
		if not mapOpen then
			return
		end
		if state == Enum.UserInputState.Begin then
			pinchZoom = mapZoom
		elseif #positions >= 2 then
			local mid = (positions[1] + positions[2]) / 2
			local before = screenToWorld(mid)
			mapZoom = math.clamp(pinchZoom * scale, Cfg.MapZoomMin, Cfg.MapZoomMax)
			mapCenter = before - (mid - viewCenter()) / mapZoom
			applyMapView()
		end
	end)

	-- the roads (no culling: the whole city can be on screen)
	mapRoute = newRouteDraw(mapWorld, Cfg.RouteWidth * 1.6)
	task.spawn(function()
		drawMap(mapWorld, false)
		if mapRoute then
			mapRoute.layer.ZIndex = 4
		end
		drawRoute(mapRoute :: RouteDraw, route)
	end)
end

function Minimap.openMap()
	if mapOpen then
		return
	end
	if UIState.get().hideHUD and not UIState.has("BigMap") then
		return -- a cutscene / fade owns the screen
	end
	buildMap()
	local g = mapGui :: ScreenGui
	mapOpen = true
	local r = root()
	if r then
		mapCenter = Vector2.new(r.Position.X, r.Position.Z)
	end
	mapZoom = Cfg.MapZoomStart
	applyMapView()
	g.Enabled = true
	UIState.push("BigMap", { hideHUD = true, lockControls = true })
	sound("Open")
	local dim = g:FindFirstChild("Dim") :: Frame
	dim.BackgroundTransparency = 0.6
	Motion.tween(dim, Motion.Fast, { BackgroundTransparency = 0 })
	mapScale.Scale = mapZoom * 0.9
	Motion.tween(mapScale, Motion.Normal, { Scale = mapZoom })
	if mapRoute then
		drawRoute(mapRoute, route)
	end
	stepMap()
end

function Minimap.closeMap()
	if not mapOpen then
		return
	end
	mapOpen = false
	if mapGui then
		mapGui.Enabled = false
	end
	UIState.pop("BigMap")
	sound("Close")
end

function Minimap.toggleMap()
	if mapOpen then
		Minimap.closeMap()
	else
		Minimap.openMap()
	end
end

function Minimap.graph(): RoadGraph.Graph?
	return graph
end

---------------------------------------------------------------- boot

function Minimap.init()
	buildPlaces()
	refreshAllowed()
	buildRadar()
	ClientData.Changed:Connect(refreshAllowed)

	UIState.Changed:Connect(function(state)
		hidden = state.hideHUD == true
		-- a cutscene starting while the map is open closes it (cutscenes also hide the phone; the map doesn't)
		if mapOpen and state.hidePhone then
			Minimap.closeMap()
		end
	end)

	UserInputService.InputBegan:Connect(function(input, processed)
		if processed then
			return
		end
		for _, k in Cfg.MapKeys do
			if input.KeyCode == k then
				Minimap.toggleMap()
				return
			end
		end
		if mapOpen and (input.KeyCode == Enum.KeyCode.ButtonB or input.KeyCode == Enum.KeyCode.Backspace) then
			Minimap.closeMap()
		end
	end)

	Wayfinder.Changed:Connect(function()
		task.defer(refreshRoute, true)
	end)

	RunService:BindToRenderStep("MTL_Minimap", Enum.RenderPriority.Camera.Value + 3, function(dt)
		stepRadar(dt)
		stepMap()
	end)

	-- route + pin arrival, 5x a second
	task.spawn(function()
		while true do
			task.wait(0.2)
			local ok, err = pcall(refreshRoute, false)
			if not ok then
				warn("[MTL Minimap] route:", err)
			end
			local pin = pinOf()
			local r = root()
			if pin and r then
				local d = r.Position - pin.position
				if Vector2.new(d.X, d.Z).Magnitude <= Cfg.PinArrive then
					Wayfinder.clear(Cfg.PinId)
					local arrive = (Theme :: any).Sounds and (Theme :: any).Sounds.Arrive
					if Sfx and arrive and arrive ~= "" then
						pcall(Sfx.playId, arrive, { volume = 0.4 })
					end
				end
			end
		end
	end)

	-- roads: baked data -> draw (in chunks) -> graph (in the background)
	task.spawn(function()
		local mod = ReplicatedStorage:WaitForChild("MTL_RoadMap", 30)
		if not mod or not mod:IsA("ModuleScript") then
			warn("[MTL Minimap] no ReplicatedStorage.MTL_RoadMap: run tools/BakeRoadMap.lua in Studio. Radar shows places only.")
			return
		end
		local ok, d = pcall(require, mod)
		if not ok or type(d) ~= "table" then
			warn("[MTL Minimap] MTL_RoadMap failed:", d)
			return
		end
		roadData = d
		roadRects = RoadGraph.parse(d.Roads)
		waterRects = RoadGraph.parseWater(d.Water)
		radarCells = drawMap(world, true)
		if radarRoute then
			radarRoute.layer.ZIndex = 4
		end
		local r = root()
		if r then
			cullRadar(r.Position)
		end
		local t0 = os.clock()
		local okG, g = pcall(RoadGraph.build, roadData, 200)
		if okG then
			graph = g
			print(string.format("[MTL Minimap] roads: %d pieces, %d route nodes (%.0f ms)", #roadRects, #g.nx, (os.clock() - t0) * 1000))
			refreshRoute(true)
		else
			warn("[MTL Minimap] road graph failed:", g)
		end
	end)
end

return Minimap

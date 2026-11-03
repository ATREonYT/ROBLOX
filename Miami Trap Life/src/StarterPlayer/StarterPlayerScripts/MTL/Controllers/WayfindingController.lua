--!strict
-- Waypoints the server sets (Waypoint remote). For each: a floating marker with the name and distance, and an arrow
-- on the screen edge when it's off screen. For the newest waypoint with breadcrumbs: a thin line FLOATING at waist
-- height along a walkable path (PathfindingService) with bold cartoon arrows gliding along it toward the target, and
-- a big bouncing arrow pointing down at the destination (Alex: "not on the floor", "cartoony models", "smooth").
-- The look is the simulator / tycoon tutorial arrow (Research: Tutorial Arrows and Hint Cards): solid colour, thick
-- black outline, a gentle bob, never a light show. Everything moves per frame from a continuous position on the path
-- and eases toward it, so nothing jumps when the path is recomputed. Arrival is decided by the server.
-- Research: "Onboarding Funnels and Wayfinding". Client API (local markers, e.g. job tasks):
--   Wayfinder.set(id, position, { label, radius, breadcrumbs })   Wayfinder.clear(id)
--   Wayfinder.list() -> { {id, position, label, radius, breadcrumbs, order} }   Wayfinder.primary() -> the route target
--   Wayfinder.Changed:Connect(fn)   (fires on every set / clear; the minimap redraws its GPS route from it)
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local PathfindingService = game:GetService("PathfindingService")
local SoundService = game:GetService("SoundService")

local Net = require(ReplicatedStorage.MTL.Net)
local Theme = require(ReplicatedStorage.MTL.UI.Theme)
local Sfx = require(ReplicatedStorage.MTL.UI.Sfx)
local Format = require(ReplicatedStorage.MTL.Format)
local Motion = require(ReplicatedStorage.MTL.UI.Motion)
local UIState = require(script.Parent.UIState)
local Guide = require(ReplicatedStorage.MTL.UI.Guide) -- one colour + style for every cue
local Signal = require(ReplicatedStorage.MTL.Signal)

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera
local C = Theme.Colors

local Wayfinder = {}
Wayfinder.Changed = Signal.new()

-- tuning
local CHEVRON_SPACING = 9 -- studs between arrows
local CHEVRON_COUNT = 8 -- so the trail shows ~70 studs ahead
local FLOW_SPEED = 5 -- studs/s the arrows glide toward the target
local REPATH_EVERY = 3 -- seconds
local STRAY_REPATH = 10 -- studs off the line -> repath now
local SAMPLE_STEP = 2.5 -- studs between ground samples on the path
local MAX_PATH_DIST = 1200 -- beyond this, breadcrumbs point straight for the first stretch
local LINE_HEIGHT = 2.6 -- studs above the ground: about waist height on an R15 avatar
local RIBBON_WIDTH = 0.16 -- a thin guide line between the arrows
local BOB = 0.15 -- the arrows breathe up and down a little (studs)
local ARROW_COLOR = Color3.fromRGB(255, 214, 64) -- cartoon yellow (a touch brighter than Guide.Color so it reads in daylight)
local OUTLINE_COLOR = Color3.fromRGB(28, 24, 18)

type WP = {
	id: string,
	position: Vector3,
	label: string,
	radius: number,
	breadcrumbs: boolean,
	order: number,
	attachment: Attachment,
	billboard: BillboardGui,
}

local waypoints: { [string]: WP } = {}
local orderCounter = 0
local edgeGui: ScreenGui
local edgeArrow: Frame
local trailFolder: Folder
local chevrons: { Model } = {} -- the gliding arrows (name kept from the chevron days)
local shown: { [Model]: CFrame } = {} -- each arrow's displayed CFrame (eased toward its target every frame)
local ribbon: { { a0: Attachment, a1: Attachment, beam: Beam } } = {} -- one Beam per trail sample gap
local goal: { [string]: any } = {} -- the destination arrow + ring
local arrowModel: Model -- every arrow part lives in here, so ONE Highlight outlines them all
local smoothBase: number? = nil -- the player's eased distance along the trail
local trail: { Vector3 } = {} -- ground points from the player toward the target
local trailLength = 0
local lastPath = 0
local pathing = false
local hidden = false

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

local function root(): BasePart?
	local char = player.Character
	return char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
end

---------------------------------------------------------------- markers

local function makeMarker(wp: WP)
	local att = new("Attachment", { Name = "MTL_WP_" .. wp.id, WorldPosition = wp.position, Parent = workspace.Terrain })
	local bb = new("BillboardGui", {
		Name = "MTL_WP_" .. wp.id,
		Adornee = att,
		AlwaysOnTop = true,
		LightInfluence = 0,
		Size = UDim2.fromOffset(180, 64),
		StudsOffsetWorldSpace = Vector3.new(0, 5, 0),
		MaxDistance = 1e6,
		ResetOnSpawn = false,
		Parent = player:WaitForChild("PlayerGui"),
	})
	local icon = new("Frame", {
		Name = "Icon",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0),
		Size = UDim2.fromOffset(18, 18),
		Rotation = 45,
		BackgroundColor3 = Guide.Color,
		Parent = bb,
	})
	new("UIStroke", { Color = C.Shadow, Transparency = 0.4, Thickness = 2, Parent = icon })
	new("TextLabel", {
		Name = "Label",
		Position = UDim2.fromOffset(0, 24),
		Size = UDim2.new(1, 0, 0, 20),
		BackgroundTransparency = 1,
		FontFace = Theme.Fonts.Bold,
		Text = wp.label,
		TextColor3 = C.Text,
		TextSize = 15,
		Parent = bb,
	})
	new("TextLabel", {
		Name = "Distance",
		Position = UDim2.fromOffset(0, 43),
		Size = UDim2.new(1, 0, 0, 16),
		BackgroundTransparency = 1,
		FontFace = Theme.Fonts.Body,
		Text = "",
		TextColor3 = Guide.Color,
		TextSize = 13,
		Parent = bb,
	})
	for _, l in bb:GetChildren() do
		if l:IsA("TextLabel") then
			new("UIStroke", { Color = C.Shadow, Transparency = 0.45, Thickness = 1.5, Parent = l })
		end
	end
	wp.attachment = att
	wp.billboard = bb
end

local function primary(): WP?
	local best: WP? = nil
	for _, wp in waypoints do
		if wp.breadcrumbs and (not best or wp.order > best.order) then
			best = wp
		end
	end
	return best
end

-- the edge arrow's target: the breadcrumb waypoint, else the newest one (job task markers have no breadcrumbs,
-- and in the 2026-11-02 play-test a task behind you had nothing pointing at it)
local function arrowTarget(): WP?
	local top = primary()
	if top then
		return top
	end
	for _, wp in waypoints do
		if not top or wp.order > top.order then
			top = wp
		end
	end
	return top
end

---------------------------------------------------------------- breadcrumbs

-- A bold flat arrow (points along -Z, lies in the X-Z plane, centred): a thick shaft and a wide head made from a
-- square turned 45 degrees (its back half reads as the barbs). Plain colour; the shared Highlight draws the outline.
local function arrowParts(parent: Instance, scale: number): { BasePart }
	local function piece(name: string, size: Vector3): BasePart
		return new("Part", {
			Name = name,
			Anchored = true,
			CanCollide = false,
			CanQuery = false,
			CanTouch = false,
			CastShadow = false,
			Material = Enum.Material.SmoothPlastic,
			Color = ARROW_COLOR,
			Size = size * scale,
			Transparency = 1,
			Parent = parent,
		})
	end
	local shaft = piece("Shaft", Vector3.new(0.7, 0.3, 1.5))
	shaft:SetAttribute("Off", Vector3.new(0, 0, 0.55))
	local head = piece("Head", Vector3.new(1.35, 0.3, 1.35))
	head:SetAttribute("Off", Vector3.new(0, 0, -0.45))
	head:SetAttribute("Turn", 45)
	return { shaft, head }
end

local function placeArrow(m: Model, cf: CFrame, transparency: number)
	for _, p in m:GetChildren() do
		if p:IsA("BasePart") then
			local off = (p:GetAttribute("Off") :: Vector3?) or Vector3.zero
			local turn = (p:GetAttribute("Turn") :: number?) or 0
			p.CFrame = cf * CFrame.new(off * (p:GetAttribute("Scale") or 1)) * CFrame.Angles(0, math.rad(turn), 0)
			p.Transparency = transparency
		end
	end
end

local function makeChevron(): Model
	local m = Instance.new("Model")
	m.Name = "Arrow"
	arrowParts(m, 1)
	m.Parent = arrowModel
	return m
end

-- the line between the arrows: thin Beams between attachments LINE_HEIGHT above each ground sample
local function makeRibbon(n: number)
	for _ = 1, n do
		local a0 = new("Attachment", { Parent = workspace.Terrain })
		local a1 = new("Attachment", { Parent = workspace.Terrain })
		local beam = new("Beam", {
			Attachment0 = a0,
			Attachment1 = a1,
			Color = ColorSequence.new(ARROW_COLOR),
			LightEmission = 0.3,
			LightInfluence = 0,
			FaceCamera = true,
			Segments = 1,
			Width0 = RIBBON_WIDTH,
			Width1 = RIBBON_WIDTH,
			Enabled = false,
			Parent = trailFolder,
		})
		table.insert(ribbon, { a0 = a0, a1 = a1, beam = beam })
	end
end

-- the destination: a big arrow pointing DOWN, bouncing and slowly turning (two crossed copies so it reads from
-- every side), and a soft ring on the ground
local function makeGoal()
	local m = Instance.new("Model")
	m.Name = "GoalArrow"
	for i = 1, 2 do
		local half = Instance.new("Model")
		half.Name = "Half" .. i
		local parts = arrowParts(half, 2.2)
		for _, p in parts do
			p:SetAttribute("Scale", 2.2)
		end
		half.Parent = m
	end
	m.Parent = arrowModel
	goal.model = m
	goal.ring = new("Part", {
		Name = "GoalRing",
		Shape = Enum.PartType.Cylinder,
		Anchored = true,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
		CastShadow = false,
		Material = Enum.Material.Neon,
		Color = ARROW_COLOR,
		Size = Vector3.new(0.06, 5, 5),
		Transparency = 1,
		Parent = trailFolder,
	})
end

local function hideGoal()
	if goal.model then
		for _, half in goal.model:GetChildren() do
			placeArrow(half :: Model, CFrame.new(0, -500, 0), 1)
		end
		goal.ring.Transparency = 1
	end
end

local groundParams = RaycastParams.new()
groundParams.FilterType = Enum.RaycastFilterType.Exclude
groundParams.IgnoreWater = false

-- The ground under a path point. Only surfaces near the path's own height count, so arrows never land on a parked
-- car's roof, an awning or a shelf top (they used to); walk-through and invisible parts are skipped too.
local function ground(p: Vector3): Vector3
	local skip: { Instance } = { player.Character :: any, trailFolder }
	for _ = 1, 5 do
		groundParams.FilterDescendantsInstances = skip
		local hit = workspace:Raycast(p + Vector3.new(0, 6, 0), Vector3.new(0, -30, 0), groundParams)
		if not hit then
			return p
		end
		local part = hit.Instance
		local solid = not part:IsA("BasePart") or (part.CanCollide and part.Transparency < 0.95)
		if solid and math.abs(hit.Position.Y - p.Y) <= 2.5 then
			return hit.Position + Vector3.new(0, 0.08, 0)
		end
		table.insert(skip, part)
	end
	return p
end

-- Turns a list of path points into evenly spaced ground samples (first ~110 studs only).
local function resample(points: { Vector3 }): ({ Vector3 }, number)
	local out = { ground(points[1]) }
	local total = 0
	local carry = 0
	for i = 1, #points - 1 do
		local a, b = points[i], points[i + 1]
		local seg = (b - a).Magnitude
		local d = SAMPLE_STEP - carry
		while d <= seg do
			table.insert(out, ground(a:Lerp(b, d / seg)))
			total += SAMPLE_STEP
			if total > CHEVRON_SPACING * CHEVRON_COUNT + 60 then
				return out, total
			end
			d += SAMPLE_STEP
		end
		carry = seg - (d - SAMPLE_STEP)
	end
	table.insert(out, ground(points[#points]))
	return out, total + carry
end

local function straightPoints(from: Vector3, to: Vector3): { Vector3 }
	local dir = (to - from)
	local len = math.min(dir.Magnitude, CHEVRON_SPACING * CHEVRON_COUNT + 60)
	return { from, from + dir.Unit * len }
end

local function repath(target: Vector3)
	if pathing then
		return
	end
	local r = root()
	if not r then
		return
	end
	pathing = true
	lastPath = os.clock()
	local from = r.Position - Vector3.new(0, 2.8, 0) -- the feet, not the waist: the line height is added on top
	task.spawn(function()
		local points: { Vector3 }
		if (target - from).Magnitude > MAX_PATH_DIST then
			points = straightPoints(from, target)
		else
			local path = PathfindingService:CreatePath({ AgentRadius = 2, AgentHeight = 5, AgentCanJump = true, WaypointSpacing = 4 })
			local ok = pcall(function()
				path:ComputeAsync(from, target)
			end)
			if ok and path.Status == Enum.PathStatus.Success then
				points = {}
				for _, w in path:GetWaypoints() do
					table.insert(points, w.Position)
				end
			else
				points = straightPoints(from, target)
			end
		end
		if #points >= 2 then
			trail, trailLength = resample(points)
		end
		pathing = false
	end)
end

-- point at distance d along the trail, and the direction there
local function along(d: number): (Vector3?, Vector3?)
	if #trail < 2 then
		return nil, nil
	end
	local i = math.floor(d / SAMPLE_STEP) + 1
	if i >= #trail then
		return nil, nil
	end
	local a, b = trail[i], trail[i + 1]
	local f = (d - (i - 1) * SAMPLE_STEP) / SAMPLE_STEP
	return a:Lerp(b, f), (b - a)
end

-- the player's position projected onto the trail polyline (continuous, not snapped to a sample), as a distance
-- along it, plus how far off the line the player is. Only the first stretch: the player can't be further along.
local function nearestOnTrail(p: Vector3): (number, number)
	local best, bestD = math.huge, 0
	local q = Vector2.new(p.X, p.Z)
	for i = 1, math.min(#trail - 1, 30) do
		local a = Vector2.new(trail[i].X, trail[i].Z)
		local b = Vector2.new(trail[i + 1].X, trail[i + 1].Z)
		local ab = b - a
		local len2 = ab:Dot(ab)
		local f = if len2 > 1e-6 then math.clamp((q - a):Dot(ab) / len2, 0, 1) else 0
		local dist = (a + ab * f - q).Magnitude
		if dist < best then
			best, bestD = dist, (i - 1 + f) * SAMPLE_STEP
		end
	end
	return bestD, best
end

local function hideTrail()
	for _, m in chevrons do
		placeArrow(m, CFrame.new(0, -500, 0), 1)
		shown[m] = nil
	end
	for _, r in ribbon do
		r.beam.Enabled = false
	end
	smoothBase = nil
end

local goalGround: { [Vector3]: Vector3 } = {}
local function updateGoal(wp: WP?, near: boolean)
	if not wp or hidden or not goal.model then
		hideGoal()
		return
	end
	local g = goalGround[wp.position]
	if not g then
		local hit = workspace:Raycast(wp.position + Vector3.new(0, 4, 0), Vector3.new(0, -20, 0), groundParams)
		g = if hit then hit.Position else wp.position - Vector3.new(0, 1, 0)
		goalGround[wp.position] = g
	end
	local now = os.clock()
	-- a soft bounce (ease in-out, like a ball), a slow turn, pointing straight down
	local bounce = (math.sin(now * 3.2) + 1) / 2
	local at = g + Vector3.new(0, 6.2 + bounce * 0.9, 0)
	local spin = CFrame.Angles(0, now * 1.2, 0)
	local down = CFrame.Angles(math.rad(-90), 0, 0) -- the arrow's -Z (its tip) turned to point at the ground
	local tr = if near then 0.4 else 0
	local halves = goal.model:GetChildren()
	for i, half in halves do
		placeArrow(half :: Model, CFrame.new(at) * spin * CFrame.Angles(0, (i - 1) * math.pi / 2, 0) * down, tr)
	end
	-- the ring on the ground slowly opens and fades: "this is the spot"
	local pulse = (now * 0.6) % 1
	local d = math.min(wp.radius or 4, 6) * (0.6 + 0.6 * pulse)
	goal.ring.Size = Vector3.new(0.06, d, d)
	goal.ring.CFrame = CFrame.new(g + Vector3.new(0, 0.1, 0)) * CFrame.Angles(0, 0, math.rad(90))
	goal.ring.Transparency = 0.4 + 0.6 * pulse
end

local function updateTrail(wp: WP?, dt: number)
	local r = root()
	if not wp or not r or hidden then
		hideTrail()
		updateGoal(wp, false)
		return
	end
	local flat = Vector2.new(r.Position.X - wp.position.X, r.Position.Z - wp.position.Z).Magnitude
	updateGoal(wp, flat <= wp.radius + 6)
	if flat <= wp.radius + 6 then
		hideTrail()
		return
	end
	local base, off = 0, 0
	if #trail > 1 then
		base, off = nearestOnTrail(r.Position)
	end
	if os.clock() - lastPath > REPATH_EVERY or off > STRAY_REPATH then
		repath(wp.position)
	end
	if #trail < 2 then
		return
	end
	-- ease the player's place on the line (a new path snaps it, then it glides again)
	if not smoothBase or math.abs(base - smoothBase) > 6 then
		smoothBase = base
	else
		smoothBase += (base - smoothBase) * math.min(1, dt * 10)
	end
	local b0 = smoothBase :: number
	local UP = Vector3.new(0, LINE_HEIGHT, 0)
	local reach = CHEVRON_SPACING * CHEVRON_COUNT
	local function fade(rel: number): number
		-- 1 = fully shown: fade in just ahead of the player, fade out at the far end
		return math.clamp((rel - 2) / 5, 0, 1) * math.clamp((reach - rel) / 14, 0, 1)
	end
	-- the thin line
	for i, seg in ribbon do
		local d0 = b0 + 2 + (i - 1) * SAMPLE_STEP
		local d1 = d0 + SAMPLE_STEP
		local p0 = along(d0)
		local p1 = along(d1)
		if p0 and p1 and d1 < trailLength and d1 - b0 <= reach then
			seg.a0.WorldPosition = p0 + UP
			seg.a1.WorldPosition = p1 + UP
			seg.beam.Transparency = NumberSequence.new(1 - 0.5 * fade(d0 - b0), 1 - 0.5 * fade(d1 - b0))
			seg.beam.Enabled = true
		else
			seg.beam.Enabled = false
		end
	end
	-- the arrows glide along it toward the target, each easing to its spot (no jitter when the path changes)
	local now = os.clock()
	local phase = (now * FLOW_SPEED) % CHEVRON_SPACING
	local k = 1 - math.exp(-dt * 14)
	for i, m in chevrons do
		local rel = (i - 1) * CHEVRON_SPACING + phase + 3
		local d = b0 + rel
		local pos, dir = along(d)
		if pos and dir and dir.Magnitude > 0.01 and d < trailLength then
			local at = pos + UP + Vector3.new(0, math.sin(now * 2.6 + i * 0.8) * BOB, 0)
			-- lying flat, tipped up toward the camera so it reads from a third-person view
			local target = CFrame.lookAt(at, at + Vector3.new(dir.X, 0, dir.Z)) * CFrame.Angles(math.rad(22), 0, 0)
			local cur = shown[m]
			if not cur or (cur.Position - target.Position).Magnitude > 4 then
				cur = target -- first frame, or it wrapped from the far end back to the start
			else
				cur = cur:Lerp(target, k)
			end
			shown[m] = cur
			placeArrow(m, cur, 1 - fade(rel))
		else
			placeArrow(m, CFrame.new(0, -500, 0), 1)
			shown[m] = nil
		end
	end
end

---------------------------------------------------------------- edge arrow + distances

local function updateMarkers(top: WP?)
	local r = root()
	for _, wp in waypoints do
		wp.billboard.Enabled = not hidden
		if r then
			wp.billboard.Distance.Text = Format.distance((r.Position - wp.position).Magnitude)
		end
	end
	if hidden or not top or not r then
		edgeArrow.Visible = false
		return
	end
	local screen, onScreen = camera:WorldToViewportPoint(top.position + Vector3.new(0, 5, 0))
	local vp = camera.ViewportSize
	local margin = 48
	if onScreen and screen.X > margin and screen.X < vp.X - margin and screen.Y > margin and screen.Y < vp.Y - margin then
		edgeArrow.Visible = false
		return
	end
	-- direction from screen centre toward the target (flip when behind the camera)
	local center = vp / 2
	local dir = Vector2.new(screen.X, screen.Y) - center
	if screen.Z < 0 then
		dir = -dir
	end
	if dir.Magnitude < 1 then
		dir = Vector2.new(0, -1)
	end
	dir = dir.Unit
	local sx = (vp.X / 2 - margin) / math.max(math.abs(dir.X), 1e-4)
	local sy = (vp.Y / 2 - margin) / math.max(math.abs(dir.Y), 1e-4)
	local p = center + dir * math.min(sx, sy)
	edgeArrow.Position = UDim2.fromOffset(math.floor(p.X), math.floor(p.Y))
	edgeArrow.Arrow.Rotation = math.deg(math.atan2(dir.Y, dir.X)) + 90
	edgeArrow.Distance.Text = Format.distance((r.Position - top.position).Magnitude)
	edgeArrow.Visible = true
end

local function buildEdge()
	edgeGui = new("ScreenGui", {
		Name = "MTL_Waypoints",
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		DisplayOrder = 4,
		Parent = player:WaitForChild("PlayerGui"),
	})
	edgeArrow = new("Frame", {
		Name = "Edge",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.fromOffset(60, 60),
		BackgroundTransparency = 1,
		Visible = false,
		Parent = edgeGui,
	})
	local arrow = new("TextLabel", {
		Name = "Arrow",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.4),
		Size = UDim2.fromOffset(30, 30),
		BackgroundTransparency = 1,
		FontFace = Theme.Fonts.Display,
		Text = "▲", -- TODO(Alex art): arrow image
		TextColor3 = Guide.Color,
		TextSize = 28,
		Parent = edgeArrow,
	})
	new("UIStroke", { Color = C.Shadow, Transparency = 0.4, Thickness = 2, Parent = arrow })
	local dist = new("TextLabel", {
		Name = "Distance",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0.72),
		Size = UDim2.fromOffset(80, 16),
		BackgroundTransparency = 1,
		FontFace = Theme.Fonts.Bold,
		Text = "",
		TextColor3 = C.Text,
		TextSize = 13,
		Parent = edgeArrow,
	})
	new("UIStroke", { Color = C.Shadow, Transparency = 0.45, Thickness = 1.5, Parent = dist })
end

---------------------------------------------------------------- API

function Wayfinder.set(id: string, position: Vector3, opts: { [string]: any }?)
	local o = opts or {}
	Wayfinder.clear(id, true)
	orderCounter += 1
	local wp = {
		id = id,
		position = position,
		label = o.label or "",
		radius = o.radius or 12,
		breadcrumbs = if o.breadcrumbs == nil then true else o.breadcrumbs,
		order = orderCounter,
	} :: any
	makeMarker(wp)
	waypoints[id] = wp
	trail = {}
	lastPath = 0
	-- small pop so the eye catches a new marker
	local icon = wp.billboard.Icon
	icon.Size = UDim2.fromOffset(4, 4)
	Motion.tween(icon, Motion.Spring, { Size = UDim2.fromOffset(18, 18) })
	Wayfinder.Changed:Fire()
end

function Wayfinder.clear(id: string, silent: boolean?)
	local wp = waypoints[id]
	if not wp then
		return
	end
	waypoints[id] = nil
	wp.attachment:Destroy()
	wp.billboard:Destroy()
	trail = {}
	if not silent then
		hideTrail()
		hideGoal()
		Wayfinder.Changed:Fire()
	end
end

-- read-only copies for the minimap / full map
function Wayfinder.list(): { { [string]: any } }
	local out = {}
	for _, wp in waypoints do
		table.insert(out, { id = wp.id, position = wp.position, label = wp.label, radius = wp.radius, breadcrumbs = wp.breadcrumbs, order = wp.order })
	end
	table.sort(out, function(a, b)
		return a.order < b.order
	end)
	return out
end

-- the waypoint the GPS routes to: the newest one with breadcrumbs, else the newest one
function Wayfinder.primary(): { [string]: any }?
	local wp = arrowTarget()
	if not wp then
		return nil
	end
	return { id = wp.id, position = wp.position, label = wp.label, radius = wp.radius, breadcrumbs = wp.breadcrumbs, order = wp.order }
end

function Wayfinder.init()
	trailFolder = new("Folder", { Name = "MTL_Breadcrumbs", Parent = workspace })
	arrowModel = new("Model", { Name = "Arrows", Parent = trailFolder })
	-- one outline for every arrow: the cartoon look (a thick dark edge, no fill tint, hidden behind walls)
	new("Highlight", {
		Name = "Outline",
		Adornee = arrowModel,
		FillTransparency = 1,
		OutlineColor = OUTLINE_COLOR,
		OutlineTransparency = 0,
		DepthMode = Enum.HighlightDepthMode.Occluded,
		Parent = arrowModel,
	})
	for _ = 1, CHEVRON_COUNT do
		table.insert(chevrons, makeChevron())
	end
	makeRibbon(math.ceil(CHEVRON_SPACING * CHEVRON_COUNT / SAMPLE_STEP) + 2)
	makeGoal()
	buildEdge()

	UIState.Changed:Connect(function(state)
		hidden = state.hideWaypoints == true or state.hideHUD == true
	end)

	Net.get("Waypoint").OnClientEvent:Connect(function(msg)
		if type(msg) ~= "table" or type(msg.id) ~= "string" then
			return
		end
		if msg.clear then
			Wayfinder.clear(msg.id)
			if msg.arrived and Theme.Sounds.Arrive ~= "" then
				Sfx.playId(Theme.Sounds.Arrive, { volume = 0.4 })
			end
		elseif typeof(msg.position) == "Vector3" then
			Wayfinder.set(msg.id, msg.position, msg)
		end
	end)

	RunService.RenderStepped:Connect(function(dt)
		local top = primary()
		updateTrail(top, dt)
		updateMarkers(arrowTarget())
	end)
end

return Wayfinder

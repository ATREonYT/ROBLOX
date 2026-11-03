--!strict
-- Round emoji markers floating over places in the world (jobs, parks, shops...), from Config/HUD.Markers.
-- Drawn in their own ScreenGui (MTL_Markers, IgnoreGuiInset so they line up with the camera) and placed every
-- frame with WorldToViewportPoint, which keeps them crisp at any distance. Close markers win: a marker that
-- would overlap a nearer one is hidden. The name + distance shows when you're close or looking right at it.
-- Positions come from config (not map parts), so StreamingEnabled never hides them. The map's own POI
-- "MapIcon" billboards are switched off on the client so only one set of icons shows.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local GuiService = game:GetService("GuiService")

local Config = require(ReplicatedStorage.MTL.Config.HUD)
local Theme = require(ReplicatedStorage.MTL.UI.Theme)
local Format = require(ReplicatedStorage.MTL.Format)
local StoryRules = require(ReplicatedStorage.MTL.Rules.StoryRules)
local Build = require(ReplicatedStorage.MTL.UI.Build.HUD)
local ClientData = require(script.Parent.ClientData)
local UIState = require(script.Parent.UIState)

local player = Players.LocalPlayer
local M = Config.Markers

local Markers = {}

type Entry = { def: any, frame: Frame, pos: Vector3, range: number, shown: boolean, alpha: number }
local entries: { Entry } = {}
local gui: ScreenGui
local hidden = false
local OVERLAP = 1.12 -- markers keep this much space between them (1 = just touching); the farther one hides

local function allowed(def: any): boolean
	if not def.requires then
		return true
	end
	local data = ClientData.get()
	local stage = data and data.Story and data.Story.Stage
	return stage ~= nil and StoryRules.reached(stage, def.requires)
end

local function setAlpha(e: Entry, a: number)
	if math.abs(e.alpha - a) < 0.01 then
		return
	end
	e.alpha = a
	local disc = e.frame:FindFirstChild("Disc") :: Frame
	disc.BackgroundTransparency = 1 - (1 - Theme.HUD.MarkerTransparency) * a
	local ic = disc:FindFirstChild("Icon")
	if ic and ic:IsA("TextLabel") then
		ic.TextTransparency = 1 - a
	elseif ic and ic:IsA("ImageLabel") then
		ic.ImageTransparency = 1 - a
	end
	local st = disc:FindFirstChild("Stroke") :: UIStroke?
	if st then
		st.Transparency = 1 - 0.2 * a
	end
end

-- Screen space the HUD and waypoints already use. Markers never draw over these, and a waypoint label that
-- would sit under the HUD (objective pill, cash, hotbar, menu) is hidden until it moves clear.
type Rect = { x0: number, y0: number, x1: number, y1: number }
local HUD_PARTS = { "Objective", "Top", "Hotbar", "Menu", "Toasts" }
local hudGui: ScreenGui? = nil

local function rectOf(g: GuiObject, inset: Vector2, pad: number): Rect
	local p, s = g.AbsolutePosition + inset, g.AbsoluteSize
	return { x0 = p.X - pad, y0 = p.Y - pad, x1 = p.X + s.X + pad, y1 = p.Y + s.Y + pad }
end

local function hits(r: Rect, x0: number, y0: number, x1: number, y1: number): boolean
	return x1 > r.x0 and x0 < r.x1 and y1 > r.y0 and y0 < r.y1
end

local function hudRects(): { Rect }
	local out = {}
	local g = hudGui
	if not g or not g.Enabled then
		return out
	end
	local inset = GuiService:GetGuiInset()
	for _, name in HUD_PARTS do
		local f = g:FindFirstChild(name) :: GuiObject?
		if f and f.Visible then
			if name == "Toasts" or name == "Menu" then
				-- only the parts actually on screen (toast rows, the button or the open panel)
				for _, c in f:GetChildren() do
					if c:IsA("GuiObject") and c.Visible and c.AbsoluteSize.X > 0 then
						table.insert(out, rectOf(c, inset, 6))
					end
				end
			else
				table.insert(out, rectOf(f, inset, 6))
			end
		end
	end
	-- the minimap (its own ScreenGui, bottom left)
	local mm = player.PlayerGui:FindFirstChild("MTL_Minimap") :: ScreenGui?
	if mm and mm.Enabled then
		local mmInset = if mm.IgnoreGuiInset then Vector2.zero else inset
		for _, c in mm:GetChildren() do
			if c:IsA("GuiObject") and c.Visible and c.AbsoluteSize.X > 0 then
				table.insert(out, rectOf(c, mmInset, 8))
			end
		end
	end
	return out
end

-- waypoint billboards (WayfindingController: PlayerGui.MTL_WP_<id>, adorned to an attachment)
local function waypointRects(cam: Camera, reserved: { Rect }): { { r: Rect, pos: Vector3 } }
	local out = {}
	for _, bb in player.PlayerGui:GetChildren() do
		if bb:IsA("BillboardGui") and string.sub(bb.Name, 1, 7) == "MTL_WP_" then
			local att = bb.Adornee
			local pos = if att and att:IsA("Attachment") then att.WorldPosition elseif att and att:IsA("BasePart") then att.Position else nil
			if pos then
				local sp, on = cam:WorldToViewportPoint(pos + bb.StudsOffsetWorldSpace)
				local w, h = bb.Size.X.Offset, bb.Size.Y.Offset
				local r = { x0 = sp.X - w / 2, y0 = sp.Y - h / 2, x1 = sp.X + w / 2, y1 = sp.Y + h / 2 }
				local under = false
				if on and sp.Z > 0 then
					for _, hr in reserved do
						if hits(hr, r.x0 + w * 0.25, r.y0, r.x1 - w * 0.25, r.y1) then
							under = true
							break
						end
					end
				end
				bb.Enabled = not under
				if on and sp.Z > 0 and not under then
					table.insert(out, { r = r, pos = pos })
				end
			end
		end
	end
	return out
end

-- indoors (a roof over the camera): world markers would show through the walls, so they hide
local indoors = false
local lastRoofCheck = 0
local roofParams = RaycastParams.new()
roofParams.FilterType = Enum.RaycastFilterType.Exclude

local function checkRoof(cam: Camera)
	local now = os.clock()
	if now - lastRoofCheck < 0.4 then
		return
	end
	lastRoofCheck = now
	roofParams.FilterDescendantsInstances = { player.Character :: any }
	local hit = workspace:Raycast(cam.CFrame.Position, Vector3.new(0, 60, 0), roofParams)
	local part = hit and hit.Instance
	-- a real roof: solid and wide (tree tops, lamp arms and signs don't count)
	indoors = part ~= nil and part:IsA("BasePart") and part.Transparency < 0.9 and part.Size.X * part.Size.Z > 150
end

local function step()
	local cam = workspace.CurrentCamera
	if cam then
		checkRoof(cam)
	end
	if hidden or indoors or not cam then
		for _, e in entries do
			e.frame.Visible = false
		end
		return
	end
	local camPos = cam.CFrame.Position
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	local me = if root then root.Position else camPos
	local vp = cam.ViewportSize
	local centre = vp / 2
	local reserved = hudRects()
	local wps = waypointRects(cam, reserved)

	-- nearest first, so the nearer marker wins any overlap
	local visible = {}
	for _, e in entries do
		local d = (e.pos - me).Magnitude
		if d <= e.range and e.def._ok then
			local top = e.pos + Vector3.new(0, M.Height, 0)
			local sp, onScreen = cam:WorldToViewportPoint(top)
			if onScreen and sp.Z > 0 then
				table.insert(visible, { e = e, d = d, sp = Vector2.new(sp.X, sp.Y) })
				continue
			end
		end
		e.frame.Visible = false
	end
	table.sort(visible, function(a, b)
		return a.d < b.d
	end)
	local placed: { { p: Vector2, r: number } } = {}
	local best: Entry? = nil
	local bestScore, bestD = math.huge, 0
	for rank, v in visible do
		local e = v.e
		e.frame.ZIndex = 1000 - rank -- nearer markers draw on top
		local t = math.clamp((v.d - 60) / (M.Range - 60), 0, 1)
		local scale = 1 - (1 - M.MinScale) * t
		local radius = M.Size * scale / 2
		local blocked = false
		for _, p in placed do
			if (p.p - v.sp).Magnitude < (p.r + radius) * OVERLAP then
				blocked = true
				break
			end
		end
		if not blocked then
			local x0, y0, x1, y1 = v.sp.X - radius, v.sp.Y - radius, v.sp.X + radius, v.sp.Y + radius
			for _, r in reserved do
				if hits(r, x0, y0, x1, y1) then
					blocked = true
					break
				end
			end
			if not blocked then
				for _, w in wps do
					-- the waypoint already marks this place, or its label would sit on the marker
					if (w.pos - e.pos).Magnitude < 40 or hits(w.r, x0, y0, x1, y1) then
						blocked = true
						break
					end
				end
			end
		end
		if blocked then
			e.frame.Visible = false
			continue
		end
		table.insert(placed, { p = v.sp, r = radius })
		e.frame.Visible = true
		e.frame.Position = UDim2.fromOffset(v.sp.X, v.sp.Y)
		;(e.frame:FindFirstChild("Scale") :: UIScale).Scale = scale
		-- fade in the last 15% of the range
		local fade = math.clamp((e.range - v.d) / (e.range * 0.15), 0, 1)
		setAlpha(e, fade)
		-- one name tag at a time: the marker you're looking at, else the nearest one you're standing by
		local off = (v.sp - centre).Magnitude
		local score = if off < math.min(vp.X, vp.Y) * 0.12 then off elseif v.d <= M.LabelRange then 1000 + v.d else math.huge
		if score < bestScore then
			bestScore, best, bestD = score, e, v.d
		end
		;(e.frame:FindFirstChild("Tag") :: TextLabel).Visible = false
	end
	if best then
		local tag = best.frame:FindFirstChild("Tag") :: TextLabel
		-- the name tag gets its own space too: hide any other marker it would cover
		local bp = Vector2.new(best.frame.Position.X.Offset, best.frame.Position.Y.Offset)
		local s = (best.frame:FindFirstChild("Scale") :: UIScale).Scale
		local halfW = (#best.def.name * 8 + 70) / 2
		local top, bottom = bp.Y + M.Size * s / 2, bp.Y + M.Size * s / 2 + 30
		for _, e in entries do
			if e ~= best and e.frame.Visible then
				local p = Vector2.new(e.frame.Position.X.Offset, e.frame.Position.Y.Offset)
				local r = M.Size * (e.frame:FindFirstChild("Scale") :: UIScale).Scale / 2
				if math.abs(p.X - bp.X) < halfW + r and p.Y + r > top and p.Y - r < bottom then
					e.frame.Visible = false
				end
			end
		end
		tag.Visible = true
		tag.Text = string.format('%s  <font color="#9FE89A">%s</font>', best.def.name, Format.distance(bestD))
		best.frame.ZIndex = 2000
	end
end

local function refreshAllowed()
	for _, e in entries do
		e.def._ok = allowed(e.def)
	end
end

function Markers.init()
	local pg = player:WaitForChild("PlayerGui")
	local old = pg:FindFirstChild("MTL_Markers")
	if old then
		old:Destroy()
	end
	gui = Instance.new("ScreenGui")
	gui.Name = "MTL_Markers"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 1 -- under the HUD and the phone
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Parent = pg
	task.spawn(function()
		hudGui = pg:WaitForChild("MTL_HUD", 10) :: ScreenGui?
	end)

	for _, def in M.List do
		local f = Build.marker(def.emoji, def.name, M.Size)
		f.Name = "Marker_" .. def.name
		f.Visible = false
		f.Parent = gui
		table.insert(entries, { def = table.clone(def), frame = f, pos = def.pos, range = def.range or M.Range, shown = false, alpha = -1 })
	end
	-- the map ships its own "MapIcon" billboards on the POIs; these markers replace them, so switch those off
	-- (client only, the map itself is untouched) so the two sets never pile on top of each other
	local function quiet(inst: Instance)
		if inst:IsA("BillboardGui") and inst.Name == "MapIcon" then
			inst.Enabled = false
		end
	end
	for _, d in workspace:GetDescendants() do
		quiet(d)
	end
	workspace.DescendantAdded:Connect(quiet)

	refreshAllowed()
	ClientData.Changed:Connect(refreshAllowed)
	UIState.Changed:Connect(function(state)
		hidden = state.hideHUD or state.hideWaypoints
	end)
	RunService:BindToRenderStep("MTL_MapMarkers", Enum.RenderPriority.Camera.Value + 2, step)
end

return Markers

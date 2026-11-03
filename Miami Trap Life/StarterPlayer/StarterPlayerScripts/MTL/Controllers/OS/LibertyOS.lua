--!strict
-- Liberty OS: the full-screen desk PC (vault: Research/Desk Computer Empire.md §4). Opened by DeskController
-- after the camera pushes into the monitor. Built in code (one ScreenGui, MTL_LibertyOS); every element is
-- found by name, so Alex's art can replace the drawn wallpaper / glyphs later (Config/OS.Look).
--
-- App modules live in OS/Apps/<id>.lua and return { mount = function(content: Frame, api) -> handle }.
-- handle = { unmount = fn, push = fn(data)?, back = fn() -> boolean? }.
-- api = { request(action, args) -> result, notify(text, color?), tap(), data() -> snapshot, look, gps(pos, label) }
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Lighting = game:GetService("Lighting")

local Net = require(ReplicatedStorage.MTL.Net)
local OS = require(ReplicatedStorage.MTL.Config.OS)
local OSRules = require(ReplicatedStorage.MTL.Rules.OSRules)
local Format = require(ReplicatedStorage.MTL.Format)

local LibertyOS = {}

local player = Players.LocalPlayer
local L = OS.Look

local gui: ScreenGui? = nil
local group: CanvasGroup? = nil
local refs: any = {}
local current: any = nil -- { id, handle, window }
local opts: any = {}
local appState: { [string]: { open: boolean, why: string? } } = {}
local clockConn: RBXScriptConnection? = nil
local isOpen = false

---------------------------------------------------------------- tiny UI helpers

local function new(class: string, props: { [string]: any }?, children: { Instance }?): any
	local i = Instance.new(class)
	for k, v in props or {} do
		if k ~= "Parent" then
			(i :: any)[k] = v
		end
	end
	for _, c in children or {} do
		c.Parent = i
	end
	if props and props.Parent then
		i.Parent = props.Parent
	end
	return i
end

local function corner(r: number?): UICorner
	return new("UICorner", { CornerRadius = UDim.new(0, r or 2) })
end

local function stroke(t: number?, c: Color3?): UIStroke
	return new("UIStroke", { Color = c or L.Line, Transparency = t or L.LineT, Thickness = 1, ApplyStrokeMode = Enum.ApplyStrokeMode.Border })
end

local function text(parent: Instance, s: string, o: { [string]: any }?): TextLabel
	o = o or {}
	return new("TextLabel", {
		Parent = parent,
		Name = o.name or "Text",
		BackgroundTransparency = 1,
		Text = s,
		Font = o.font or L.Body,
		TextSize = o.size or 16,
		TextColor3 = o.color or L.Text,
		TextXAlignment = o.align or Enum.TextXAlignment.Left,
		TextYAlignment = o.valign or Enum.TextYAlignment.Center,
		TextWrapped = o.wrap or false,
		TextTruncate = if o.wrap then Enum.TextTruncate.None else Enum.TextTruncate.AtEnd,
		Size = o.sizeU or UDim2.new(1, 0, 0, (o.size or 16) + 6),
		Position = o.pos or UDim2.new(),
		AnchorPoint = o.anchor or Vector2.zero,
		ZIndex = o.z or 1,
		RichText = o.rich or false,
		LayoutOrder = o.order or 0,
	})
end
LibertyOS.text = text
LibertyOS.new = new
LibertyOS.corner = corner
LibertyOS.stroke = stroke

-- A flat button: dark plate, hairline, hover lightens, press dips. Calls onClick + a key tap on the rig.
local function button(parent: Instance, label: string, onClick: () -> (), o: { [string]: any }?): TextButton
	o = o or {}
	local base = o.color or L.Panel3
	local b = new("TextButton", {
		Parent = parent,
		Name = o.name or "Button",
		AutoButtonColor = false,
		BackgroundColor3 = base,
		Text = label,
		Font = o.font or L.Bold,
		TextSize = o.size or 15,
		TextColor3 = o.textColor or L.Text,
		Size = o.sizeU or UDim2.new(0, 120, 0, 34),
		Position = o.pos or UDim2.new(),
		AnchorPoint = o.anchor or Vector2.zero,
		LayoutOrder = o.order or 0,
		ZIndex = o.z or 1,
	}, { corner(), stroke() })
	local hover = base:Lerp(Color3.new(1, 1, 1), 0.08)
	b.MouseEnter:Connect(function()
		TweenService:Create(b, TweenInfo.new(0.12), { BackgroundColor3 = hover }):Play()
	end)
	b.MouseLeave:Connect(function()
		TweenService:Create(b, TweenInfo.new(0.16), { BackgroundColor3 = base }):Play()
	end)
	b.Activated:Connect(function()
		if opts.onTap then
			opts.onTap()
		end
		LibertyOS.click()
		onClick()
	end)
	return b
end
LibertyOS.button = button

-- Key click: the shared UI sound set (UI/Sfx + Theme.Sfx, "Click"); silent if it isn't there. Never invent ids.
local Sfx: any = nil
pcall(function()
	Sfx = require(ReplicatedStorage.MTL.UI.Sfx)
end)
function LibertyOS.click()
	if Sfx and Sfx.has and Sfx.has("Click") then
		Sfx.play("Click", { volume = 0.25, jitter = 0.08 })
	end
end

---------------------------------------------------------------- the desktop

local function drawWallpaper(screen: Frame)
	local wall = new("Frame", { Parent = screen, Name = "Wallpaper", Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, ZIndex = 0 })
	new("UIGradient", {
		Parent = wall,
		Rotation = 90,
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, L.WallTop),
			ColorSequenceKeypoint.new(0.52, L.WallMid),
			ColorSequenceKeypoint.new(0.7, L.WallLow),
			ColorSequenceKeypoint.new(1, L.WallBottom),
		}),
	})
	if L.Wallpaper ~= "rbxassetid://0" then
		new("ImageLabel", { Parent = wall, Name = "Image", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Image = L.Wallpaper, ScaleType = Enum.ScaleType.Crop, ZIndex = 0 })
		return
	end
	-- the sun sinking behind downtown
	new("Frame", { Parent = wall, Name = "Sun", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.68, 0.6), Size = UDim2.fromScale(0.16, 0.16), BackgroundColor3 = Color3.fromRGB(255, 196, 120), BorderSizePixel = 0, ZIndex = 0 }, {
		new("UICorner", { CornerRadius = UDim.new(1, 0) }),
		new("UIAspectRatioConstraint", { AspectRatio = 1 }),
		new("UIGradient", { Rotation = 90, Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.7, 0.2), NumberSequenceKeypoint.new(1, 1) }) }),
	})
	-- skyline: deterministic towers (Liberty in the front, downtown behind)
	local rng = Random.new(77)
	local far = Color3.fromRGB(70, 40, 70)
	local near = Color3.fromRGB(26, 20, 34)
	for layer = 1, 2 do
		local x = 0
		while x < 1 do
			local w = rng:NextNumber(0.025, 0.06)
			local h = if layer == 1 then rng:NextNumber(0.12, 0.34) else rng:NextNumber(0.05, 0.16)
			local tower = new("Frame", {
				Parent = wall,
				Name = "Tower",
				AnchorPoint = Vector2.new(0, 1),
				Position = UDim2.fromScale(x, 0.93),
				Size = UDim2.fromScale(w, h),
				BackgroundColor3 = if layer == 1 then far else near,
				BorderSizePixel = 0,
				ZIndex = 0,
			})
			if layer == 1 then
				for _ = 1, rng:NextInteger(1, 5) do
					new("Frame", { Parent = tower, Name = "Lit", Position = UDim2.fromScale(rng:NextNumber(0.15, 0.8), rng:NextNumber(0.1, 0.8)), Size = UDim2.fromOffset(3, 3), BackgroundColor3 = Color3.fromRGB(255, 210, 140), BorderSizePixel = 0, ZIndex = 0 })
				end
			end
			x += w + rng:NextNumber(0, 0.012)
		end
	end
	text(wall, "LIBERTY OS", { name = "Watermark", font = L.Head, size = 22, color = Color3.fromRGB(255, 240, 230), pos = UDim2.new(1, -24, 0, 18), anchor = Vector2.new(1, 0), sizeU = UDim2.fromOffset(240, 26), align = Enum.TextXAlignment.Right }).TextTransparency = 0.55
end

local function appDef(id: string): any?
	for _, a in OS.Apps do
		if a.id == id then
			return a
		end
	end
	return nil
end

local function glyphTile(parent: Instance, def: any, size: number): Frame
	local tile = new("Frame", { Parent = parent, Name = "Glyph", Size = UDim2.fromOffset(size, size), BackgroundColor3 = L.Panel, BorderSizePixel = 0 }, { corner(3), stroke(0.85) })
	new("Frame", { Parent = tile, Name = "Stripe", Size = UDim2.new(1, 0, 0, 3), BackgroundColor3 = def.color, BorderSizePixel = 0 })
	text(tile, def.glyph, { name = "Mark", font = L.Head, size = math.floor(size * 0.5), color = def.color, align = Enum.TextXAlignment.Center, sizeU = UDim2.fromScale(1, 1) })
	return tile
end

function LibertyOS.notify(s: string, color: Color3?)
	if not refs.toasts then
		return
	end
	local t = new("Frame", { Parent = refs.toasts, Name = "Toast", Size = UDim2.new(1, 0, 0, 46), BackgroundColor3 = L.Panel, BackgroundTransparency = 0.05, BorderSizePixel = 0 }, { corner(), stroke() })
	new("Frame", { Parent = t, Size = UDim2.new(0, 3, 1, 0), BackgroundColor3 = color or L.Select, BorderSizePixel = 0 })
	text(t, s, { size = 14, pos = UDim2.fromOffset(14, 0), sizeU = UDim2.new(1, -20, 1, 0), wrap = true })
	t.Position = UDim2.fromOffset(30, 0)
	TweenService:Create(t, TweenInfo.new(0.22, Enum.EasingStyle.Quint), { Position = UDim2.new() }):Play()
	task.delay(4, function()
		if t.Parent then
			local tw = TweenService:Create(t, TweenInfo.new(0.2), { BackgroundTransparency = 1 })
			tw:Play()
			for _, d in t:GetDescendants() do
				if d:IsA("TextLabel") then
					TweenService:Create(d, TweenInfo.new(0.2), { TextTransparency = 1 }):Play()
				end
			end
			tw.Completed:Wait()
			t:Destroy()
		end
	end)
end

local function api(id: string): any
	return {
		look = L,
		request = function(action: string, args: any): any
			local ok, res = pcall(function()
				return Net.get("OSRequest"):InvokeServer(id, action, args)
			end)
			if not ok then
				return { ok = false, err = "No connection" }
			end
			return res
		end,
		notify = LibertyOS.notify,
		tap = function()
			if opts.onTap then
				opts.onTap()
			end
		end,
		data = function(): any
			local cd = script.Parent.Parent:FindFirstChild("ClientData")
			local ok, mod = pcall(require, cd)
			return if ok and mod then mod.get() else nil
		end,
		ui = LibertyOS,
	}
end

local function closeApp()
	if not current then
		return
	end
	local c = current
	current = nil
	if c.handle and c.handle.unmount then
		pcall(c.handle.unmount)
	end
	local w = c.window :: Frame
	TweenService:Create(w, TweenInfo.new(0.16, Enum.EasingStyle.Quad), { Position = w.Position + UDim2.fromOffset(0, 18) }):Play()
	task.delay(0.12, function()
		w:Destroy()
	end)
	if refs.taskApp then
		refs.taskApp.Visible = false
	end
end

local function comingSoon(content: Frame, def: any, why: string?)
	local box = new("Frame", { Parent = content, Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1 })
	local tile = glyphTile(box, def, 96)
	tile.AnchorPoint = Vector2.new(0.5, 0.5)
	tile.Position = UDim2.fromScale(0.5, 0.4)
	text(box, if why then "Locked" else "Coming soon", { font = L.Head, size = 30, align = Enum.TextXAlignment.Center, pos = UDim2.fromScale(0, 0.55), sizeU = UDim2.new(1, 0, 0, 36) })
	text(box, why and ("Unlocks at: " .. why) or "This app is still being built.", { color = L.Dim, size = 16, align = Enum.TextXAlignment.Center, pos = UDim2.fromScale(0, 0.62), sizeU = UDim2.new(1, 0, 0, 22) })
end

function LibertyOS.openApp(id: string)
	local def = appDef(id)
	if not def or not refs.screen then
		return
	end
	if current and current.id == id then
		return
	end
	closeApp()
	local win = new("Frame", {
		Parent = refs.screen,
		Name = "Window_" .. id,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 40),
		Size = UDim2.new(1, -240, 1, -96),
		BackgroundColor3 = L.Panel,
		BorderSizePixel = 0,
		ZIndex = 5,
	}, { corner(), stroke(0.8) })
	local bar = new("Frame", { Parent = win, Name = "TitleBar", Size = UDim2.new(1, 0, 0, 38), BackgroundColor3 = L.Panel2, BorderSizePixel = 0, ZIndex = 5 }, { corner() })
	new("Frame", { Parent = bar, Name = "Accent", Size = UDim2.new(0, 3, 1, 0), BackgroundColor3 = def.color, BorderSizePixel = 0, ZIndex = 6 })
	text(bar, string.upper(def.title), { name = "Title", font = L.Head, size = 20, pos = UDim2.fromOffset(16, 0), sizeU = UDim2.new(1, -120, 1, 0), z = 6 })
	button(bar, "✕", function()
		closeApp()
	end, { name = "Close", sizeU = UDim2.fromOffset(38, 38), pos = UDim2.new(1, 0, 0, 0), anchor = Vector2.new(1, 0), color = L.Panel2, size = 16, z = 6 })
	local content = new("Frame", { Parent = win, Name = "Content", Position = UDim2.fromOffset(0, 38), Size = UDim2.new(1, 0, 1, -38), BackgroundTransparency = 1, ClipsDescendants = true, ZIndex = 5 })
	-- open motion: up 18 px + quick fade of the plate
	win.Position = UDim2.new(0.5, 0, 0, 58)
	TweenService:Create(win, TweenInfo.new(0.22, Enum.EasingStyle.Quint), { Position = UDim2.new(0.5, 0, 0, 40) }):Play()
	current = { id = id, window = win, handle = nil }
	if refs.taskApp then
		refs.taskApp.Visible = true
		refs.taskAppLabel.Text = string.upper(def.title)
	end
	local st = appState[id]
	if st and not st.open then
		comingSoon(content, def, st.why)
		return
	end
	local mod = script.Parent:FindFirstChild("Apps") and script.Parent.Apps:FindFirstChild(id)
	if not mod then
		comingSoon(content, def, nil)
		return
	end
	local ok, app = pcall(require, mod)
	if not ok or type(app) ~= "table" or not app.mount then
		warn("[MTL OS] app failed to load", id, app)
		comingSoon(content, def, nil)
		return
	end
	local okMount, handle = pcall(app.mount, content, api(id))
	if not okMount then
		warn("[MTL OS] mount failed", id, handle)
		return
	end
	current.handle = handle
end

local function refreshIcons()
	task.spawn(function()
		local res = api("Shell").request("apps")
		if not res or not res.ok then
			return
		end
		for _, a in res.apps do
			appState[a.id] = { open = a.open, why = a.why }
			local icon = refs.icons and refs.icons:FindFirstChild("Icon_" .. a.id)
			if icon then
				icon.Glyph.BackgroundTransparency = if a.open then 0 else 0.4
				icon.Glyph.Mark.TextTransparency = if a.open then 0 else 0.6
				icon.Lock.Visible = not a.open
				icon.Lock.Text = a.why or ""
			end
		end
	end)
end

local function build(): ScreenGui
	local pg = player:WaitForChild("PlayerGui")
	local g = new("ScreenGui", { Name = "MTL_LibertyOS", ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 60, Enabled = false, ZIndexBehavior = Enum.ZIndexBehavior.Sibling })
	local cg = new("CanvasGroup", { Parent = g, Name = "Fade", Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0), BorderSizePixel = 0, GroupTransparency = 1 })
	-- the 16:9 screen, letterboxed in black like the monitor's bezel
	local screen = new("Frame", { Parent = cg, Name = "Screen", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(1, 1), BackgroundColor3 = L.Panel, BorderSizePixel = 0, ClipsDescendants = true }, {
		new("UIAspectRatioConstraint", { AspectRatio = 16 / 9, AspectType = Enum.AspectType.FitWithinMaxSize }),
	})
	drawWallpaper(screen)
	-- icons (left column)
	-- icons: a column that wraps into a second one on short screens (8 apps don't fit 720p in one column)
	local icons = new("Frame", { Parent = screen, Name = "Icons", Position = UDim2.fromOffset(22, 22), Size = UDim2.new(0, 220, 1, -80), BackgroundTransparency = 1, ZIndex = 2 }, {
		new("UIGridLayout", { CellSize = UDim2.fromOffset(96, 86), CellPadding = UDim2.fromOffset(12, 12), FillDirection = Enum.FillDirection.Vertical, SortOrder = Enum.SortOrder.LayoutOrder }),
	})
	for i, def in OS.Apps do
		local icon = new("TextButton", { Parent = icons, Name = "Icon_" .. def.id, Size = UDim2.fromOffset(96, 86), BackgroundTransparency = 1, Text = "", LayoutOrder = i, ZIndex = 2, AutoButtonColor = false })
		local tile = glyphTile(icon, def, 56)
		tile.AnchorPoint = Vector2.new(0.5, 0)
		tile.Position = UDim2.new(0.5, 0, 0, 0)
		tile.ZIndex = 2
		local lbl = text(icon, def.title, { name = "Label", size = 13, align = Enum.TextXAlignment.Center, pos = UDim2.fromOffset(0, 60), sizeU = UDim2.new(1, 0, 0, 16), z = 2 })
		lbl.TextStrokeTransparency = 0.6
		local lock = text(icon, "", { name = "Lock", size = 11, color = L.Gold, align = Enum.TextXAlignment.Center, pos = UDim2.fromOffset(0, 74), sizeU = UDim2.new(1, 0, 0, 13), z = 2 })
		lock.Visible = false
		icon.MouseEnter:Connect(function()
			TweenService:Create(tile, TweenInfo.new(0.12), { Position = UDim2.new(0.5, 0, 0, -3) }):Play()
		end)
		icon.MouseLeave:Connect(function()
			TweenService:Create(tile, TweenInfo.new(0.16), { Position = UDim2.new(0.5, 0, 0, 0) }):Play()
		end)
		icon.Activated:Connect(function()
			LibertyOS.click()
			if opts.onTap then
				opts.onTap()
			end
			LibertyOS.openApp(def.id)
		end)
	end
	-- taskbar
	local bar = new("Frame", { Parent = screen, Name = "Taskbar", AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 1), Size = UDim2.new(1, 0, 0, 42), BackgroundColor3 = L.Panel, BackgroundTransparency = 0.04, BorderSizePixel = 0, ZIndex = 8 })
	new("Frame", { Parent = bar, Name = "Line", Size = UDim2.new(1, 0, 0, 1), BackgroundColor3 = L.Line, BackgroundTransparency = 0.88, BorderSizePixel = 0, ZIndex = 8 })
	local start = new("TextButton", { Parent = bar, Name = "Start", Size = UDim2.new(0, 120, 1, 0), BackgroundTransparency = 1, Text = "", ZIndex = 8 })
	text(start, "LIBERTY", { font = L.Head, size = 20, pos = UDim2.fromOffset(16, 0), sizeU = UDim2.new(1, -16, 1, 0), z = 8 })
	start.Activated:Connect(function()
		closeApp()
	end)
	local taskApp = new("Frame", { Parent = bar, Name = "OpenApp", Position = UDim2.fromOffset(130, 6), Size = UDim2.fromOffset(180, 30), BackgroundColor3 = L.Panel3, BorderSizePixel = 0, Visible = false, ZIndex = 8 }, { corner(), stroke() })
	new("Frame", { Parent = taskApp, Name = "Under", AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 1), Size = UDim2.new(1, 0, 0, 2), BackgroundColor3 = L.Select, BorderSizePixel = 0, ZIndex = 8 })
	refs.taskAppLabel = text(taskApp, "", { font = L.Bold, size = 13, align = Enum.TextXAlignment.Center, sizeU = UDim2.fromScale(1, 1), z = 8 })
	refs.taskApp = taskApp
	refs.cash = text(bar, "", { name = "Cash", font = L.Head, size = 20, color = L.Money, align = Enum.TextXAlignment.Right, pos = UDim2.new(1, -250, 0, 0), sizeU = UDim2.new(0, 140, 1, 0), z = 8 })
	refs.clock = text(bar, "", { name = "Clock", font = L.Bold, size = 15, align = Enum.TextXAlignment.Right, pos = UDim2.new(1, -96, 0, 0), sizeU = UDim2.new(0, 80, 1, 0), z = 8 })
	button(bar, "EXIT", function()
		if opts.onClose then
			opts.onClose()
		end
	end, { name = "Exit", sizeU = UDim2.fromOffset(64, 30), pos = UDim2.new(1, -330, 0, 6), color = L.Panel3, size = 13, z = 8 })
	-- notifications
	refs.toasts = new("Frame", { Parent = screen, Name = "Toasts", AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -18, 1, -54), Size = UDim2.fromOffset(320, 300), BackgroundTransparency = 1, ZIndex = 9 }, {
		new("UIListLayout", { Padding = UDim.new(0, 8), VerticalAlignment = Enum.VerticalAlignment.Bottom, SortOrder = Enum.SortOrder.LayoutOrder }),
	})
	refs.screen = screen
	refs.icons = icons
	group = cg
	g.Parent = pg
	return g
end

local function tickClock()
	if refs.clock then
		refs.clock.Text = OSRules.clock(Lighting.ClockTime * 60)
	end
	local cdMod = script.Parent.Parent:FindFirstChild("ClientData")
	local ok, CD = pcall(require, cdMod)
	local d = ok and CD and CD.get()
	if refs.cash and d then
		refs.cash.Text = Format.cash(d.Cash or 0)
	end
end

function LibertyOS.open(o: { [string]: any }?)
	opts = o or {}
	if not gui then
		gui = build()
	end
	assert(gui and group)
	gui.Enabled = true
	isOpen = true
	group.GroupTransparency = 1
	TweenService:Create(group, TweenInfo.new(opts.fade or 0.18, Enum.EasingStyle.Quad), { GroupTransparency = 0 }):Play()
	refreshIcons()
	tickClock()
	if clockConn then
		clockConn:Disconnect()
	end
	local acc = 0
	clockConn = game:GetService("RunService").Heartbeat:Connect(function(dt)
		acc += dt
		if acc > 0.5 then
			acc = 0
			tickClock()
		end
	end)
	-- first boot: the welcome mail
	task.delay(0.5, function()
		local res = api("Shell").request("mail")
		if res and res.ok and #res.mail > 0 then
			local newest = res.mail[1]
			if os.time() - (newest.at or 0) < 5 then
				LibertyOS.notify("New mail: " .. newest.subject, L.Select)
			end
		end
	end)
end

function LibertyOS.close(fade: number?)
	if not gui or not group then
		return
	end
	isOpen = false
	closeApp()
	if clockConn then
		clockConn:Disconnect()
		clockConn = nil
	end
	local g = gui
	if (fade or 0) <= 0 then
		g.Enabled = false
		return
	end
	local tw = TweenService:Create(group, TweenInfo.new(fade :: number), { GroupTransparency = 1 })
	tw:Play()
	tw.Completed:Once(function()
		if not isOpen then
			g.Enabled = false
		end
	end)
end

-- Backspace / B: close the open app first; true = used.
function LibertyOS.back(): boolean
	if current then
		if current.handle and current.handle.back and current.handle.back() then
			return true
		end
		closeApp()
		return true
	end
	return false
end

function LibertyOS.push(app: string, data: any)
	if current and current.id == app and current.handle and current.handle.push then
		pcall(current.handle.push, data)
	end
end

function LibertyOS.isOpen(): boolean
	return isOpen
end

return LibertyOS

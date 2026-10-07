-- Runs Hood's Studio code against a fake DataModel built from hood/src (Rojo layout),
-- then writes every BasePart in Workspace to JSON for the three.js previewer.
-- Usage: lune run harness.luau <srcDir> <outJson|-> <luau snippet> [setup.luau]
local roblox = require("@lune/roblox")
local fs = require("@lune/fs")
local serde = require("@lune/serde")
local luau = require("@lune/luau")
local task = require("@lune/task")
local process = require("@lune/process")

local SRC, OUT, SNIPPET, SETUP = process.args[1], process.args[2], process.args[3], process.args[4]
local __exportPartsImpl
local Instance, Vector3, CFrame, Color3, Enum = roblox.Instance, roblox.Vector3, roblox.CFrame, roblox.Color3, roblox.Enum

local game = Instance.new("DataModel")
local workspace = game:GetService("Workspace")
for _, s in { "ReplicatedStorage", "ServerStorage", "ServerScriptService", "Lighting", "Players", "StarterPlayer", "ChangeHistoryService", "Selection", "SoundService", "RunService" } do
	pcall(function() game:GetService(s) end)
end
local sps = Instance.new("StarterPlayerScripts"); sps.Parent = game:GetService("StarterPlayer")

-- Deterministic stand-in for Roblox's Random (preview only).
local Random = {}
Random.__index = Random
function Random.new(seed)
	return setmetatable({ s = (math.floor(seed or 1) % 2147483647 + 2147483647) % 2147483647 + 1 }, Random)
end
function Random:_next()
	self.s = (self.s * 48271) % 2147483647
	return self.s / 2147483647
end
function Random:NextNumber(a, b) a = a or 0; b = b or 1; return a + (b - a) * self:_next() end
function Random:NextInteger(a, b) return math.floor(a + (b - a + 1) * self:_next()) end

-- Engine methods Lune doesn't ship.
local pivots = setmetatable({}, { __mode = "k" })
local function partsOf(inst)
	local list = {}
	for _, d in inst:GetDescendants() do if d:IsA("BasePart") then table.insert(list, d) end end
	return list
end
local function bounds(inst)
	local lo, hi = Vector3.new(math.huge, math.huge, math.huge), Vector3.new(-math.huge, -math.huge, -math.huge)
	for _, p in partsOf(inst) do
		local x, y, z, a, b, c, d, e, f, g, h, i = p.CFrame:GetComponents()
		local s = p.Size
		local hx = (math.abs(a) * s.X + math.abs(b) * s.Y + math.abs(c) * s.Z) / 2
		local hy = (math.abs(d) * s.X + math.abs(e) * s.Y + math.abs(f) * s.Z) / 2
		local hz = (math.abs(g) * s.X + math.abs(h) * s.Y + math.abs(i) * s.Z) / 2
		lo = Vector3.new(math.min(lo.X, x - hx), math.min(lo.Y, y - hy), math.min(lo.Z, z - hz))
		hi = Vector3.new(math.max(hi.X, x + hx), math.max(hi.Y, y + hy), math.max(hi.Z, z + hz))
	end
	return lo, hi
end
roblox.implementMethod("Model", "GetBoundingBox", function(self)
	local lo, hi = bounds(self)
	return CFrame.new((lo + hi) / 2), hi - lo
end)
roblox.implementMethod("Model", "GetPivot", function(self)
	if pivots[self] then return pivots[self] end
	local lo, hi = bounds(self)
	if lo.X == math.huge then return CFrame.new() end
	return CFrame.new((lo + hi) / 2)
end)
roblox.implementMethod("Model", "PivotTo", function(self, target)
	local current = pivots[self] or (function() local lo, hi = bounds(self); return CFrame.new((lo + hi) / 2) end)()
	local delta = target * current:Inverse()
	for _, p in partsOf(self) do p.CFrame = delta * p.CFrame end
	pivots[self] = target
end)
roblox.implementMethod("BasePart", "GetPivot", function(self) return self.CFrame end)
roblox.implementMethod("BasePart", "PivotTo", function(self, target) self.CFrame = target end)
roblox.implementProperty("BasePart", "Position", function(self) return self.CFrame.Position end, function(self, v)
	self.CFrame = self.CFrame - self.CFrame.Position + v
end)
roblox.implementMethod("Instance", "WaitForChild", function(self, name)
	return self:FindFirstChild(name)
end)
roblox.implementMethod("ChangeHistoryService", "SetWaypoint", function() end)
-- UI: no layout engine here, so screens report zero size and signals never fire.
local dummySignal = { Connect = function() return { Disconnect = function() end } end, Once = function() return { Disconnect = function() end } end }
roblox.implementMethod("Instance", "GetPropertyChangedSignal", function() return dummySignal end)
for _, cls in { "ScreenGui", "Frame", "TextLabel", "TextButton", "ImageLabel", "ScrollingFrame" } do roblox.implementProperty(cls, "AbsoluteSize", function() return roblox.Vector2.new(0, 0) end) end
roblox.implementMethod("Selection", "Set", function() end)
roblox.implementMethod("Selection", "Get", function() return {} end)

-- Load hood/src into the DataModel using Rojo naming rules.
local function load(dir, parent)
	for _, name in fs.readDir(dir) do
		local path = dir .. "/" .. name
		if fs.isDir(path) then
			local folder = parent:FindFirstChild(name)
			if not folder then folder = Instance.new("Folder"); folder.Name = name; folder.Parent = parent end
			load(path, folder)
		elseif name:match("%.lua$") or name:match("%.luau$") then
			local base, kind = name:match("^(.-)%.(server)%.luau?$")
			if not base then base, kind = name:match("^(.-)%.(client)%.luau?$") end
			if not base then base = name:match("^(.-)%.luau?$") end
			local cls = kind == "server" and "Script" or kind == "client" and "LocalScript" or "ModuleScript"
			local s = Instance.new(cls); s.Name = base; s.Source = fs.readFile(path); s.Parent = parent
		end
	end
end
for _, svc in fs.readDir(SRC) do
	local target = svc == "StarterPlayer" and game:GetService("StarterPlayer") or game:GetService(svc)
	load(SRC .. "/" .. svc, target)
end

-- Lune's CFrame.lookAt mis-orients non-horizontal directions; Roblox's is correct, so mirror Roblox here.
local CFrameFixed = setmetatable({
	lookAt = function(at, target, up)
		up = up or Vector3.new(0, 1, 0)
		local look = (target - at).Unit
		local right = look:Cross(up).Unit
		return CFrame.fromMatrix(at, right, right:Cross(look), -look)
	end,
}, { __index = CFrame })
function exportUI(result, OUT)
	local function rgb(c) return { c.R, c.G, c.B } end
	local UDim, UDim2, Vector2, ColorSequence, NumberSequence = roblox.UDim, roblox.UDim2, roblox.Vector2, roblox.ColorSequence, roblox.NumberSequence
	local function get(inst, prop, default)
		local ok, v = pcall(function() return inst[prop] end)
		if ok and v ~= nil then return v end
		return default
	end
	local function udim(u) return { u.Scale, u.Offset } end
	local function udim2(u) return { u.X.Scale, u.X.Offset, u.Y.Scale, u.Y.Offset } end
	local function seqColor(cs) local t = {}; for _, k in cs.Keypoints do table.insert(t, { k.Time, k.Value.R, k.Value.G, k.Value.B }) end; return t end
	local function seqNum(ns) local t = {}; for _, k in ns.Keypoints do table.insert(t, { k.Time, k.Value }) end; return t end
	local function gradient(g)
		local off = get(g, "Offset", Vector2.new(0, 0))
		return { c = seqColor(get(g, "Color", ColorSequence.new(Color3.new(1, 1, 1)))), tr = seqNum(get(g, "Transparency", NumberSequence.new(0))), rot = get(g, "Rotation", 0), off = { off.X, off.Y }, on = get(g, "Enabled", true) }
	end
	local function fontOf(inst)
		local okEnum, enumName = pcall(function() return inst.Font.Name end)
		local okFace, family, weight = pcall(function() return inst.FontFace.Family, inst.FontFace.Weight.Name, inst.FontFace.Style.Name end)
		local okStyle, style = pcall(function() return inst.FontFace.Style.Name end)
		-- Lune keeps Font and FontFace apart (Roblox syncs them); whichever the code set is readable.
		if okEnum then return { enum = enumName } end
		if okFace then return { family = family, weight = weight, style = okStyle and style or "Normal" } end
		return { enum = "SourceSans" }
	end
	local function node(inst)
		local n = { c = inst.ClassName, n = inst.Name, kids = {}, mods = {} }
		local okA, attrs = pcall(function() return inst:GetAttributes() end)
		if okA and next(attrs) then n.attrs = attrs end
		if inst:IsA("GuiObject") then
			n.pos = udim2(get(inst, "Position", UDim2.new())); n.size = udim2(get(inst, "Size", UDim2.new()))
			local a = get(inst, "AnchorPoint", Vector2.new()); n.anchor = { a.X, a.Y }
			n.bg = rgb(get(inst, "BackgroundColor3", Color3.new(1, 1, 1))); n.bgT = get(inst, "BackgroundTransparency", 0)
			n.vis = get(inst, "Visible", true); n.z = get(inst, "ZIndex", 1); n.order = get(inst, "LayoutOrder", 0)
			n.rot = get(inst, "Rotation", 0); n.clip = get(inst, "ClipsDescendants", false)
			n.auto = get(inst, "AutomaticSize", Enum.AutomaticSize.None).Name
			if inst:IsA("CanvasGroup") then n.groupT = get(inst, "GroupTransparency", 0) end
			if inst:IsA("TextLabel") or inst:IsA("TextButton") or inst:IsA("TextBox") then
				n.text = {
					t = get(inst, "Text", ""), color = rgb(get(inst, "TextColor3", Color3.new(0, 0, 0))), size = get(inst, "TextSize", 14),
					scaled = get(inst, "TextScaled", false), wrap = get(inst, "TextWrapped", false), rich = get(inst, "RichText", false),
					xa = get(inst, "TextXAlignment", Enum.TextXAlignment.Center).Name, ya = get(inst, "TextYAlignment", Enum.TextYAlignment.Center).Name,
					tT = get(inst, "TextTransparency", 0), sC = rgb(get(inst, "TextStrokeColor3", Color3.new(0, 0, 0))), sT = get(inst, "TextStrokeTransparency", 1),
					lh = get(inst, "LineHeight", 1), font = fontOf(inst),
				}
			end
			if inst:IsA("ImageLabel") or inst:IsA("ImageButton") then
				local r = get(inst, "SliceCenter", nil)
				n.img = { id = get(inst, "Image", ""), color = rgb(get(inst, "ImageColor3", Color3.new(1, 1, 1))), t = get(inst, "ImageTransparency", 0), st = get(inst, "ScaleType", Enum.ScaleType.Stretch).Name }
			end
		else
			n.insets = get(inst, "ScreenInsets", Enum.ScreenInsets.CoreUISafeInsets).Name
			n.ignoreInset = get(inst, "IgnoreGuiInset", false); n.enabled = get(inst, "Enabled", true)
		end
		for _, ch in inst:GetChildren() do
			local cls = ch.ClassName
			if cls == "UICorner" then n.mods.corner = udim(get(ch, "CornerRadius", UDim.new(0, 8)))
			elseif cls == "UIStroke" then
				local g = ch:FindFirstChildOfClass("UIGradient")
				n.mods.stroke = { c = rgb(get(ch, "Color", Color3.new())), t = get(ch, "Transparency", 0), th = get(ch, "Thickness", 1), mode = get(ch, "ApplyStrokeMode", Enum.ApplyStrokeMode.Contextual).Name, on = get(ch, "Enabled", true), grad = g and gradient(g) or nil }
			elseif cls == "UIGradient" then n.mods.grad = gradient(ch)
			elseif cls == "UIPadding" then n.mods.pad = { udim(get(ch, "PaddingLeft", UDim.new())), udim(get(ch, "PaddingRight", UDim.new())), udim(get(ch, "PaddingTop", UDim.new())), udim(get(ch, "PaddingBottom", UDim.new())) }
			elseif cls == "UIListLayout" then
				n.mods.list = { dir = get(ch, "FillDirection", Enum.FillDirection.Vertical).Name, pad = udim(get(ch, "Padding", UDim.new())), h = get(ch, "HorizontalAlignment", Enum.HorizontalAlignment.Left).Name, v = get(ch, "VerticalAlignment", Enum.VerticalAlignment.Top).Name, sort = get(ch, "SortOrder", Enum.SortOrder.Name).Name }
			elseif cls == "UIGridLayout" then
				n.mods.grid = { cell = udim2(get(ch, "CellSize", UDim2.fromOffset(100, 100))), pad = udim2(get(ch, "CellPadding", UDim2.fromOffset(5, 5))), dir = get(ch, "FillDirection", Enum.FillDirection.Horizontal).Name, h = get(ch, "HorizontalAlignment", Enum.HorizontalAlignment.Left).Name, v = get(ch, "VerticalAlignment", Enum.VerticalAlignment.Top).Name, sort = get(ch, "SortOrder", Enum.SortOrder.Name).Name, max = get(ch, "FillDirectionMaxCells", 0) }
			elseif cls == "UIAspectRatioConstraint" then n.mods.aspect = { r = get(ch, "AspectRatio", 1), type = get(ch, "AspectType", Enum.AspectType.FitWithinMaxSize).Name, dom = get(ch, "DominantAxis", Enum.DominantAxis.Width).Name }
			elseif cls == "UIScale" then n.mods.scale = get(ch, "Scale", 1)
			elseif cls == "UISizeConstraint" then local mn, mx = get(ch, "MinSize", Vector2.new()), get(ch, "MaxSize", Vector2.new(math.huge, math.huge)); n.mods.sizeLimit = { mn.X, mn.Y, mx.X == math.huge and 1e9 or mx.X, mx.Y == math.huge and 1e9 or mx.Y }
			elseif cls == "UITextSizeConstraint" then n.mods.textLimit = { get(ch, "MinTextSize", 1), get(ch, "MaxTextSize", 100) }
			elseif ch:IsA("GuiObject") then table.insert(n.kids, node(ch))
			end
		end
		return n
	end
	fs.writeFile(OUT, serde.encode("json", node(result)))
end

-- Virtual-time TweenService (preview only): tweens advance when the snippet calls __stepTweens(dt).
local Easing = {}
do
	local pi = math.pi
	local function outBounce(t)
		if t < 1 / 2.75 then return 7.5625 * t * t
		elseif t < 2 / 2.75 then t -= 1.5 / 2.75; return 7.5625 * t * t + 0.75
		elseif t < 2.5 / 2.75 then t -= 2.25 / 2.75; return 7.5625 * t * t + 0.9375
		else t -= 2.625 / 2.75; return 7.5625 * t * t + 0.984375 end
	end
	local IN = {
		Linear = function(t) return t end,
		Sine = function(t) return 1 - math.cos(t * pi / 2) end,
		Quad = function(t) return t * t end, Cubic = function(t) return t ^ 3 end, Quart = function(t) return t ^ 4 end, Quint = function(t) return t ^ 5 end,
		Exponential = function(t) return t == 0 and 0 or 2 ^ (10 * t - 10) end,
		Circular = function(t) return 1 - math.sqrt(1 - t * t) end,
		Back = function(t) local c = 1.70158; return (c + 1) * t ^ 3 - c * t * t end,
		Elastic = function(t) if t == 0 or t == 1 then return t end; return -(2 ^ (10 * t - 10)) * math.sin((t * 10 - 10.75) * (2 * pi) / 3) end,
		Bounce = function(t) return 1 - outBounce(1 - t) end,
	}
	function Easing.get(alpha, style, dir)
		local f = IN[style.Name] or IN.Quad
		local d = dir.Name
		if d == "In" then return f(alpha) end
		if d == "Out" then return 1 - f(1 - alpha) end
		if alpha < 0.5 then return f(alpha * 2) / 2 end
		return 1 - f((1 - alpha) * 2) / 2
	end
end
local function lerpValue(a, b, t)
	local ty = typeof(a)
	if ty == "number" then return a + (b - a) * t end
	if ty == "UDim2" then return roblox.UDim2.new(a.X.Scale + (b.X.Scale - a.X.Scale) * t, a.X.Offset + (b.X.Offset - a.X.Offset) * t, a.Y.Scale + (b.Y.Scale - a.Y.Scale) * t, a.Y.Offset + (b.Y.Offset - a.Y.Offset) * t) end
	if ty == "UDim" then return roblox.UDim.new(a.Scale + (b.Scale - a.Scale) * t, a.Offset + (b.Offset - a.Offset) * t) end
	if ty == "Vector2" then return roblox.Vector2.new(a.X + (b.X - a.X) * t, a.Y + (b.Y - a.Y) * t) end
	if ty == "Vector3" then return a + (b - a) * t end
	if ty == "Color3" then return a:Lerp(b, t) end
	if ty == "CFrame" then return a:Lerp(b, t) end
	return t < 1 and a or b
end
local clock = { t = 0, active = {} }
local function signal()
	local fns = {}
	local sig = {}
	function sig:Connect(fn) table.insert(fns, fn); return { Disconnect = function() table.remove(fns, table.find(fns, fn) or 0) end } end
	function sig:Once(fn) local c; c = sig:Connect(function(...) c.Disconnect(); fn(...) end); return c end
	function sig:Fire(...) for _, fn in table.clone(fns) do fn(...) end end
	return sig
end
local TweenInfoLib = { new = function(time, style, dir, repeatCount, reverses, delay)
	return { Time = time or 1, EasingStyle = style or Enum.EasingStyle.Quad, EasingDirection = dir or Enum.EasingDirection.Out, RepeatCount = repeatCount or 0, Reverses = reverses or false, DelayTime = delay or 0 }
end }
roblox.implementMethod("TweenService", "Create", function(_, inst, info, props)
	local tw = { Instance = inst, TweenInfo = info, Completed = signal(), PlaybackState = Enum.PlaybackState.Begin }
	function tw:Play()
		self.start, self.from = clock.t, {}
		for k in props do self.from[k] = inst[k] end
		self.PlaybackState = Enum.PlaybackState.Playing
		clock.active[self] = true
	end
	function tw:Cancel()
		if clock.active[self] then clock.active[self] = nil; self.PlaybackState = Enum.PlaybackState.Cancelled; self.Completed:Fire(Enum.PlaybackState.Cancelled) end
	end
	function tw:Pause() clock.active[self] = nil end
	tw._props = props
	return tw
end)
roblox.implementMethod("TweenService", "GetValue", function(_, alpha, style, dir) return Easing.get(alpha, style, dir) end)
local function stepTweens(dt)
	clock.t += dt
	for tw in table.clone(clock.active) do
		local info = tw.TweenInfo
		local elapsed = clock.t - tw.start - info.DelayTime
		if elapsed >= 0 then
			local loops = info.RepeatCount
			local span = info.Time * (info.Reverses and 2 or 1)
			local done = loops >= 0 and elapsed >= span * (loops + 1)
			local local_t = done and span or (elapsed % span)
			local alpha = math.min(1, local_t / info.Time)
			if info.Reverses and local_t > info.Time then alpha = 2 - local_t / info.Time end
			if done then alpha = info.Reverses and 0 or 1 end
			local e = Easing.get(math.clamp(alpha, 0, 1), info.EasingStyle, info.EasingDirection)
			for k, goal in tw._props do tw.Instance[k] = lerpValue(tw.from[k], goal, e) end
			if done then
				clock.active[tw] = nil
				tw.PlaybackState = Enum.PlaybackState.Completed
				tw.Completed:Fire(Enum.PlaybackState.Completed)
			end
		end
	end
end

local base = {
	game = game, workspace = workspace, Workspace = workspace, Instance = Instance, Vector3 = Vector3, CFrame = CFrameFixed,
	Color3 = Color3, Enum = Enum, UDim2 = roblox.UDim2, UDim = roblox.UDim, Vector2 = roblox.Vector2,
	BrickColor = roblox.BrickColor, NumberSequence = roblox.NumberSequence, ColorSequence = roblox.ColorSequence,
	NumberRange = roblox.NumberRange, NumberSequenceKeypoint = roblox.NumberSequenceKeypoint,
	ColorSequenceKeypoint = roblox.ColorSequenceKeypoint, Random = Random, Font = roblox.Font, Rect = roblox.Rect, __fs = fs, __serde = serde, __exportUI = function(...) return exportUI(...) end, TweenInfo = TweenInfoLib, __stepTweens = stepTweens, __exportParts = function(...) return __exportPartsImpl(...) end, task = task, warn = function(...) print("[warn]", ...) end,
}
local cache, loading = {}, {}
local function envFor(scriptInst)
	local env = { script = scriptInst }
	for k, v in base do env[k] = v end
	return env
end
function base.require(target)
	if cache[target] ~= nil then return cache[target] end
	assert(typeof(target) == "Instance" and target:IsA("ModuleScript"), "require expects a ModuleScript")
	assert(not loading[target], "cyclic require: " .. target:GetFullName())
	loading[target] = true
	local fn = luau.load(target.Source, { debugName = target:GetFullName(), environment = envFor(target) })
	local result = fn()
	loading[target] = nil
	cache[target] = result
	return result
end

if SETUP and SETUP ~= "" then
	luau.load(fs.readFile(SETUP), { debugName = "setup", environment = envFor(nil) })()
end
local function rgb(c) return { c.R, c.G, c.B } end
local function labels(gui)
	local out = {}
	for _, l in gui:GetDescendants() do
		if l:IsA("TextLabel") or l:IsA("TextButton") then
			local ok, scaled = pcall(function() return l.TextScaled end)
			table.insert(out, {
				text = l.Text, color = rgb(l.TextColor3), textT = l.TextTransparency, bg = rgb(l.BackgroundColor3), bgT = l.BackgroundTransparency,
				px = l.Position.X.Scale, py = l.Position.Y.Scale, sx = l.Size.X.Scale, sy = l.Size.Y.Scale,
				scaled = ok and scaled, size = l.TextSize, stroke = rgb(l.TextStrokeColor3), strokeT = l.TextStrokeTransparency,
				font = (function() local okF, f = pcall(function() return l.Font.Name end); return okF and f or nil end)(),
			})
			local ui = l:FindFirstChildOfClass("UIStroke")
			if ui then out[#out].stroke = rgb(ui.Color); out[#out].strokeT = ui.Transparency; out[#out].strokeW = ui.Thickness end
		elseif l:IsA("Frame") and l.BackgroundTransparency < 1 then
			table.insert(out, 1, {
				text = "", color = { 0, 0, 0 }, bg = rgb(l.BackgroundColor3), bgT = l.BackgroundTransparency,
				px = l.Position.X.Scale, py = l.Position.Y.Scale, sx = l.Size.X.Scale, sy = l.Size.Y.Scale, scaled = true, size = 1, stroke = { 0, 0, 0 }, strokeT = 1,
			})
		end
	end
	return out
end
local function collectParts(filter)
local parts = {}
local count = 0
for _, p in workspace:GetDescendants() do
	if p:IsA("BasePart") and (not filter or filter[p]) then
		count += 1
		local rec = {
			n = p.Name, k = p.ClassName, s = { p.Size.X, p.Size.Y, p.Size.Z }, cf = { p.CFrame:GetComponents() },
			c = rgb(p.Color), m = p.Material.Name, t = p.Transparency, studs = p.TopSurface == Enum.SurfaceType.Studs or nil,
			shadow = p.CastShadow,
		}
		if p:IsA("Part") then rec.sh = p.Shape.Name end
		local mesh = p:FindFirstChildOfClass("SpecialMesh")
		if mesh then rec.mesh = mesh.MeshType.Name; rec.ms = { mesh.Scale.X, mesh.Scale.Y, mesh.Scale.Z } end
		for _, child in p:GetChildren() do
			if child:IsA("SurfaceGui") then
				rec.guis = rec.guis or {}
				table.insert(rec.guis, { kind = "surface", face = child.Face.Name, labels = labels(child) })
			elseif child:IsA("BillboardGui") then
				rec.guis = rec.guis or {}
				local sz = child.Size
				table.insert(rec.guis, {
					kind = "billboard", sw = sz.X.Scale > 0 and sz.X.Scale or sz.X.Offset / 30, sh = sz.Y.Scale > 0 and sz.Y.Scale or sz.Y.Offset / 30,
					off = { child.StudsOffset.X, child.StudsOffset.Y, child.StudsOffset.Z }, top = child.AlwaysOnTop, labels = labels(child),
				})
			elseif child:IsA("Texture") then
				-- Tiled image on one face (the bag stations' stamped X): drawn by the renderer from PreviewTexture.
				rec.textures = rec.textures or {}
				table.insert(rec.textures, {
					face = child.Face.Name, tex = child.Texture, preview = child:GetAttribute("PreviewTexture"),
					su = child.StudsPerTileU, sv = child.StudsPerTileV, ou = child.OffsetStudsU, ov = child.OffsetStudsV,
					t = child.Transparency, c = rgb(child.Color3),
				})
			elseif child:IsA("PointLight") or child:IsA("SpotLight") then
				rec.lights = rec.lights or {}
				table.insert(rec.lights, { c = rgb(child.Color), b = child.Brightness, r = child.Range })
			end
		end
		-- Effects: emitters on the part or on its attachments, and beams between attachments.
		local function g(inst, prop, default) local ok, v = pcall(function() return inst[prop] end); if ok and v ~= nil then return v end; return default end
		local function seqN(ns) local t = {}; for _, k in ns.Keypoints do table.insert(t, { k.Time, k.Value, k.Envelope }) end; return t end
		local function seqC(cs) local t = {}; for _, k in cs.Keypoints do table.insert(t, { k.Time, k.Value.R, k.Value.G, k.Value.B }) end; return t end
		local function range(r) return { r.Min, r.Max } end
		local function cfOf(att) return p.CFrame * g(att, "CFrame", CFrame.new()) end
		local function emitter(e, cf, onPart)
			rec.fx = rec.fx or {}
			table.insert(rec.fx, {
				kind = "particles", name = e.Name, cf = { cf:GetComponents() }, box = onPart and { p.Size.X, p.Size.Y, p.Size.Z } or nil,
				tex = g(e, "Texture", "rbxasset://textures/particles/sparkles_main.dds"), rate = g(e, "Rate", 20), life = range(g(e, "Lifetime", roblox.NumberRange.new(5, 10))),
				speed = range(g(e, "Speed", roblox.NumberRange.new(5))), spread = { g(e, "SpreadAngle", roblox.Vector2.new()).X, g(e, "SpreadAngle", roblox.Vector2.new()).Y },
				size = seqN(g(e, "Size", roblox.NumberSequence.new(1))), tr = seqN(g(e, "Transparency", roblox.NumberSequence.new(0))), color = seqC(g(e, "Color", roblox.ColorSequence.new(Color3.new(1, 1, 1)))),
				emission = g(e, "LightEmission", 0), brightness = g(e, "Brightness", 1), drag = g(e, "Drag", 0), acc = { g(e, "Acceleration", Vector3.zero).X, g(e, "Acceleration", Vector3.zero).Y, g(e, "Acceleration", Vector3.zero).Z },
				rot = range(g(e, "Rotation", roblox.NumberRange.new(0))), rotSpeed = range(g(e, "RotSpeed", roblox.NumberRange.new(0))), squash = seqN(g(e, "Squash", roblox.NumberSequence.new(0))),
				shape = g(e, "Shape", Enum.ParticleEmitterShape.Box).Name, style = g(e, "ShapeStyle", Enum.ParticleEmitterShapeStyle.Volume).Name, inout = g(e, "ShapeInOut", Enum.ParticleEmitterShapeInOut.Outward).Name,
				dir = g(e, "EmissionDirection", Enum.NormalId.Top).Name, orient = g(e, "Orientation", Enum.ParticleOrientation.FacingCamera).Name, enabled = g(e, "Enabled", true),
				zoff = g(e, "ZOffset", 0), timeScale = g(e, "TimeScale", 1), burst = e:GetAttribute("PreviewBurst"), preview = e:GetAttribute("PreviewTexture"),
				flip = g(e, "FlipbookLayout", Enum.ParticleFlipbookLayout.None).Name,
			})
		end
		for _, child in p:GetChildren() do
			if child:IsA("ParticleEmitter") then emitter(child, p.CFrame, true)
			elseif child:IsA("Attachment") then
				for _, e in child:GetChildren() do if e:IsA("ParticleEmitter") then emitter(e, cfOf(child), false) end end
			elseif child:IsA("Beam") then
				local a0, a1 = g(child, "Attachment0", nil), g(child, "Attachment1", nil)
				if a0 and a1 and a0.Parent and a1.Parent then
					local c0 = a0.Parent.CFrame * g(a0, "CFrame", CFrame.new())
					local c1 = a1.Parent.CFrame * g(a1, "CFrame", CFrame.new())
					rec.fx = rec.fx or {}
					table.insert(rec.fx, {
						kind = "beam", name = child.Name, p0 = { c0:GetComponents() }, p1 = { c1:GetComponents() }, w0 = g(child, "Width0", 1), w1 = g(child, "Width1", 1),
						curve0 = g(child, "CurveSize0", 0), curve1 = g(child, "CurveSize1", 0), segments = g(child, "Segments", 10), faceCamera = g(child, "FaceCamera", false),
						color = seqC(g(child, "Color", roblox.ColorSequence.new(Color3.new(1, 1, 1)))), tr = seqN(g(child, "Transparency", roblox.NumberSequence.new(0.5))),
						emission = g(child, "LightEmission", 0), brightness = g(child, "Brightness", 1), tex = g(child, "Texture", ""), preview = child:GetAttribute("PreviewTexture"),
						texLen = g(child, "TextureLength", 1), texMode = g(child, "TextureMode", Enum.TextureMode.Stretch).Name,
					})
				end
			end
		end
		table.insert(parts, rec)
	end
end
return parts, count
end
__exportPartsImpl = function(filter, path, time)
	local parts = collectParts(filter)
	fs.writeFile(path, serde.encode("json", { parts = parts, time = time }))
end
local result = luau.load(SNIPPET, { debugName = "snippet", environment = envFor(nil) })()
if result ~= nil then print("snippet returned:", typeof(result) == "table" and serde.encode("json", result) or tostring(result)) end

if OUT == "-" then return end

-- UI mode: when the snippet returns a GUI instance, write its tree for the HTML UI previewer instead of parts.
if typeof(result) == "Instance" and (result:IsA("LayerCollector") or result:IsA("GuiObject")) then
	exportUI(result, OUT)

	print("exported ui:", result:GetFullName())
	return
end
local parts, count = collectParts(nil)
fs.writeFile(OUT, serde.encode("json", { parts = parts }))
print("exported parts:", count)

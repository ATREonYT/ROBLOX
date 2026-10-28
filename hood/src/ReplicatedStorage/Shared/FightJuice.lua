-- FightJuice (Oct 28, the feel round; the owner: "add the nice effects that they use, add the good fighting
-- animations ... we need the quality and feel to be better"). The fight's weight and payoff, on top of Shared/FightFX's
-- reference marks (the "+N", the X, the star, the swoosh), client only, nothing sent:
--   FightJuice.hitStop(kind) -> seconds    how long a hit freezes the goon it lands on (and your swing): 0 for a shot,
--                                          a beat for a swing, the longest for the hit that knocks it out (pure)
--   FightJuice.squash(t) -> number         the hit's squash on a goon t s after it lands: 1 at once (fully squashed),
--                                          springing back through a small stretch to 0 by SquashTime (pure)
--   FightJuice.bounce(t) -> studs          a knocked-out body's bounce off the ground t s after it lands (pure)
--   FightJuice.streak(times, now) -> n     knock-outs in a row: each within StreakGap s of the one before (pure)
--   FightJuice.orbCount(n) -> count        Power orbs a knock-out sends to your counter for its streak n (pure)
--   FightJuice.project(camCF, fov, size, at) -> Vector2?, depth   a world point on the screen (pure: the harness has no
--                                          WorldToViewportPoint)
--   FightJuice.fovKick(degrees)            the camera's field of view widens a touch and springs back (a punch's thump);
--                                          kid-comfortable: never more than MaxFov degrees, no roll
--   FightJuice.glint(at, scale)            the wind-up's tell: a warm glint on the goon's fist as it draws back
--   FightJuice.koBurst(at, scale)          the knock-out: a ring of light and a puff of smoke (never white over the
--                                          screen: Shared/FlashGate is for that)
--   FightJuice.dizzy(head, scale, life)    three gold stars circling a knocked-out goon's head, then gone
--   FightJuice.orbs(fromWorld, count, kind) Power orbs burst out of a knocked-out goon and fly into the HUD's Power
--                                          counter, which bumps as each lands (kind 'Cash': green Cash orbs into the Cash
--                                          counter, a pad's cash-out)
--   FightJuice.streakChip(parent)          the "KO x2!" chip over the fight, below the top band: :ko(n), :hide()
local RS = game:GetService('ReplicatedStorage')
local Players = game:GetService('Players')
local RunService = game:GetService('RunService')
local TweenService = game:GetService('TweenService')

local FightJuice = {}
FightJuice.Parent = nil -- (Waves.client sets its HoodGoons folder; else Workspace)
FightJuice.HitStop = { Shot = 0, Melee = 0.06, KO = 0.09, KOMelee = 0.11 }
FightJuice.SquashTime = 0.28
FightJuice.BounceTime, FightJuice.BounceHeight = 0.3, 0.55
FightJuice.StreakGap = 2.5
FightJuice.MaxFov = 3
FightJuice.Gold = Color3.fromRGB(255, 206, 64)
FightJuice.GoldLight = Color3.fromRGB(255, 244, 176)
FightJuice.Ink = Color3.fromRGB(26, 22, 36)

---------------------------------------------------------------------------------------------- the rules (pure)
function FightJuice.hitStop(kind)
	return FightJuice.HitStop[kind or 'Shot'] or 0
end
-- 1 at the hit, springing back to 0 by SquashTime with one small overshoot (a stretch, about -0.25)
function FightJuice.squash(t)
	if type(t) ~= 'number' or t < 0 or t >= FightJuice.SquashTime then return 0 end
	local u = t / FightJuice.SquashTime
	return math.exp(-4 * u) * math.cos(u * math.pi * 1.5) * (1 - u)
end
-- one hop off the ground, a quarter of the first, then still
function FightJuice.bounce(t)
	local T = FightJuice.BounceTime
	if type(t) ~= 'number' or t < 0 or t >= T then return 0 end
	local first = T * 0.65
	if t < first then return FightJuice.BounceHeight * math.sin(math.pi * t / first) end
	return FightJuice.BounceHeight * 0.25 * math.sin(math.pi * (t - first) / (T - first))
end
-- times: the clock of each knock-out so far, oldest first; the streak is how many came each within StreakGap of the last
function FightJuice.streak(times, now)
	if type(times) ~= 'table' or #times == 0 then return 0 end
	if now and now - times[#times] > FightJuice.StreakGap then return 0 end
	local n = 1
	for i = #times, 2, -1 do
		if times[i] - times[i - 1] <= FightJuice.StreakGap then n += 1 else break end
	end
	return n
end
function FightJuice.orbCount(n)
	return math.clamp(2 + (tonumber(n) or 1), 3, 7)
end
-- size: the viewport (Vector2); returns the point in pixels from its top left, and how far in front of the camera
function FightJuice.project(camCF, fov, size, at)
	local rel = camCF:PointToObjectSpace(at)
	local d = -rel.Z
	if d <= 0.05 then return nil, d end
	local f = (size.Y / 2) / math.tan(math.rad(fov or 70) / 2)
	return Vector2.new(size.X / 2 + rel.X / d * f, size.Y / 2 - rel.Y / d * f), d
end

---------------------------------------------------------------------------------------------- helpers
local function tween(obj, t, props, style, dir, delay)
	local ok, tw = pcall(TweenService.Create, TweenService, obj, TweenInfo.new(t, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out, 0, false, delay or 0), props)
	if ok and tw then tw:Play() end
	return tw
end
local function later(t, fn)
	task.delay(t, function() pcall(fn) end)
end
local function anchor(name, at)
	local p = Instance.new('Part')
	p.Name = name
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = true, false, false, false, false
	p.Transparency = 1
	p.Size = Vector3.new(0.2, 0.2, 0.2)
	p.CFrame = CFrame.new(at)
	p.Parent = FightJuice.Parent or workspace
	return p
end
local function billboard(p, w, h)
	local g = Instance.new('BillboardGui')
	g.Name = p.Name
	g.Size = UDim2.fromScale(w, h)
	g.LightInfluence = 0
	g.AlwaysOnTop = true
	g.MaxDistance = 140
	g.ClipsDescendants = false
	g.Parent = p
	return g
end
local function frame(parent, name, x, y, w, h, color, corner, z)
	local f = Instance.new('Frame')
	f.Name = name
	f.AnchorPoint = Vector2.new(0.5, 0.5)
	f.Position = UDim2.fromScale(x, y)
	f.Size = UDim2.fromScale(w, h)
	f.BackgroundColor3 = color
	f.BorderSizePixel = 0
	f.ZIndex = z or 2
	if corner then
		local c = Instance.new('UICorner')
		c.CornerRadius = UDim.new(corner, 0)
		c.Parent = f
	end
	f.Parent = parent
	return f
end
local function edge(f, color, thick)
	local s = Instance.new('UIStroke')
	s.Color = color or FightJuice.Ink
	s.Thickness = thick or 2
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.Parent = f
	return s
end
-- a 4-point star (two crossed diamonds) in `color`, centred in its parent at (x, y), `w` of its width
local function star(parent, name, x, y, w, color, z)
	local h = Instance.new('Frame')
	h.Name = name
	h.BackgroundTransparency = 1
	h.AnchorPoint = Vector2.new(0.5, 0.5)
	h.Position = UDim2.fromScale(x, y)
	h.Size = UDim2.fromScale(w, w)
	h.Parent = parent
	for _, r in { 0, 90 } do
		local d = frame(h, 'Point', 0.5, 0.5, 0.3, 1, color, 0.5, z)
		d.Rotation = r
		edge(d, FightJuice.Ink, 1.5)
	end
	frame(h, 'Core', 0.5, 0.5, 0.42, 0.42, color, 0.5, (z or 2) + 1).Rotation = 45
	return h
end

---------------------------------------------------------------------------------------------- the camera's thump
local fov = { x = 0, v = 0, applied = 0, conn = nil }
function FightJuice.fovKick(degrees)
	local cam = workspace.CurrentCamera
	if not cam then return end
	fov.v += math.clamp(degrees or 1.5, 0, FightJuice.MaxFov) * 26
	if fov.conn then return end
	local ok, conn = pcall(function()
		return RunService.PreRender:Connect(function(dt)
			local c = workspace.CurrentCamera
			if not c then return end
			dt = math.min(dt, 0.05)
			-- a spring at 4 Hz, a little under-damped: out fast, back with the faintest overshoot
			local k, z = (2 * math.pi * 4) ^ 2, 2 * (2 * math.pi * 4) * 0.62
			fov.v += (-k * fov.x - z * fov.v) * dt
			fov.x = math.clamp(fov.x + fov.v * dt, -1, FightJuice.MaxFov)
			c.FieldOfView += fov.x - fov.applied
			fov.applied = fov.x
			if math.abs(fov.x) < 0.01 and math.abs(fov.v) < 0.05 then
				c.FieldOfView -= fov.applied
				fov.x, fov.v, fov.applied = 0, 0, 0
				if fov.conn then fov.conn:Disconnect() end
				fov.conn = nil
			end
		end)
	end)
	if ok then fov.conn = conn end
end

---------------------------------------------------------------------------------------------- the wind-up's tell
function FightJuice.glint(at, scale)
	scale = scale or 1
	local p = anchor('WindupGlint', at)
	local g = billboard(p, 1.6 * scale, 1.6 * scale)
	local s = star(g, 'Glint', 0.5, 0.5, 0.2, FightJuice.GoldLight, 3)
	tween(s, 0.12, { Size = UDim2.fromScale(1, 1), Rotation = 45 }, Enum.EasingStyle.Back)
	for _, d in s:GetDescendants() do
		if d:IsA('Frame') then tween(d, 0.14, { BackgroundTransparency = 1 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In, 0.14) end
		if d:IsA('UIStroke') then tween(d, 0.14, { Transparency = 1 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In, 0.14) end
	end
	later(0.32, function() p:Destroy() end)
	return p
end

---------------------------------------------------------------------------------------------- the knock-out
-- A gold ring of light opening round the body and a few soft grey puffs rolling out low (3D parts: they read from
-- every side and the offline previews draw them).
function FightJuice.koBurst(at, scale)
	scale = scale or 1
	local p = anchor('KOBurst', at)
	local g = billboard(p, 2 * scale, 2 * scale)
	local ring = frame(g, 'Ring', 0.5, 0.5, 0.3, 0.3, FightJuice.Gold, 0.5, 2)
	ring.BackgroundTransparency = 1
	local st = edge(ring, FightJuice.GoldLight, 6)
	tween(g, 0.3, { Size = UDim2.fromScale(6.5 * scale, 6.5 * scale) }, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	tween(ring, 0.3, { Size = UDim2.fromScale(1, 1) }, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	tween(st, 0.3, { Transparency = 1, Thickness = 1 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	later(0.35, function() p:Destroy() end)
	for k = 1, 6 do
		local q = Instance.new('Part')
		q.Name = 'KOPuff'
		q.Shape = Enum.PartType.Ball
		q.Material = Enum.Material.SmoothPlastic
		q.Color = k % 2 == 0 and Color3.fromRGB(236, 232, 226) or Color3.fromRGB(250, 248, 244)
		q.Anchored, q.CanCollide, q.CanQuery, q.CanTouch, q.CastShadow = true, false, false, false, false
		local a = (k / 6) * math.pi * 2 + math.random() * 0.4
		local dir = Vector3.new(math.cos(a), 0, math.sin(a))
		q.Size = Vector3.one * 0.9 * scale
		q.CFrame = CFrame.new(at + dir * 0.5 * scale - Vector3.new(0, 1.4 * scale, 0))
		q.Transparency = 0.15
		q.Parent = FightJuice.Parent or workspace
		tween(q, 0.5, { Size = Vector3.one * 2.4 * scale, CFrame = CFrame.new(at + dir * 2.4 * scale - Vector3.new(0, 1.1 * scale, 0)), Transparency = 1 }, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
		later(0.55, function() q:Destroy() end)
	end
end
-- head: the heap's head part (followed as it settles) or a fixed point
function FightJuice.dizzy(head, scale, life)
	scale, life = scale or 1, life or 1.4
	local at = typeof(head) == 'Vector3' and head or (head and head.CFrame.Position) or Vector3.zero
	local p = anchor('Dizzy', at)
	local stars = {}
	for k = 1, 3 do
		local q = anchor('DizzyStar', at)
		q.Parent = p
		local g = billboard(q, 0.75 * scale, 0.75 * scale)
		star(g, 'Star', 0.5, 0.5, 0.95, FightJuice.Gold, 3)
		stars[k] = { part = q, gui = g }
	end
	local t0 = os.clock()
	local conn
	local ok = pcall(function()
		conn = RunService.PreRender:Connect(function()
			local t = os.clock() - t0
			if t > life or not p.Parent then
				if conn then conn:Disconnect() end
				if p.Parent then p:Destroy() end
				return
			end
			local c = typeof(head) == 'Instance' and head.Parent and head.CFrame.Position or at
			local fade = math.clamp((life - t) / 0.3, 0, 1)
			local grow = math.clamp(t / 0.15, 0, 1)
			for k, s in stars do
				local a = t * 5.2 + k * (2 * math.pi / 3)
				s.part.CFrame = CFrame.new(c + Vector3.new(math.cos(a) * 1.1 * scale, 0.9 * scale + math.sin(a * 2) * 0.12, math.sin(a) * 1.1 * scale))
				s.gui.Size = UDim2.fromScale(0.75 * scale * grow * (0.4 + 0.6 * fade), 0.75 * scale * grow * (0.4 + 0.6 * fade))
			end
		end)
	end)
	if not ok then later(life, function() p:Destroy() end) end
	return p
end

---------------------------------------------------------------------------------------------- Power orbs into the HUD
local orbGui, orbRoot
local targets, icons = {}, {}
-- the HUD's counter an orb flies into: 'Power' (the bicep and number over the Level bar) or 'Cash' (the counter column)
local function counterOf(kind)
	local pl = Players.LocalPlayer
	local pg = pl and pl:FindFirstChildOfClass('PlayerGui')
	if not pg then return nil end
	local t = targets[kind]
	if t and t.Parent then return t end
	t = nil
	local hud = pg:FindFirstChild('HoodHUD')
	if kind == 'Cash' then
		local col = hud and hud:FindFirstChild('Counters', true)
		t = col and col:FindFirstChild('Cash')
	else
		for _, d in (hud and hud:GetDescendants() or {}) do
			if d.Name == 'Power' and d:IsA('GuiObject') and d:FindFirstChild('Value') then t = d break end
		end
	end
	targets[kind] = t
	return t
end
local function iconOf(name)
	if icons[name] == nil then
		local ok, Kit = pcall(require, RS.Shared.UIKit)
		local okI, id = false, nil
		if ok and Kit and Kit.iconImage then okI, id = pcall(Kit.iconImage, name) end
		icons[name] = okI and type(id) == 'string' and id or ''
	end
	return icons[name]
end
FightJuice.OfflineAt = { Power = Vector2.new(636, 566), Cash = Vector2.new(80, 652) }
FightJuice.OrbLook = {
	Power = { Icon = 'Muscle', Fill = Color3.fromRGB(255, 206, 64), Light = Color3.fromRGB(255, 244, 176), Dark = Color3.fromRGB(255, 160, 40) },
	Cash = { Icon = 'Cash', Fill = Color3.fromRGB(96, 214, 72), Light = Color3.fromRGB(214, 255, 170), Dark = Color3.fromRGB(40, 160, 60) },
}
local function orbLayer()
	if orbGui and orbGui.Parent then return orbRoot end
	local pl = Players.LocalPlayer
	local pg = pl and pl:FindFirstChildOfClass('PlayerGui')
	if not pg then return nil end
	orbGui = Instance.new('ScreenGui')
	orbGui.Name = 'HoodFightOrbs'
	orbGui.ResetOnSpawn = false
	orbGui.IgnoreGuiInset = true
	orbGui.DisplayOrder = 7 -- (over the HUD and the fight counter, under the windows)
	orbRoot = Instance.new('Frame')
	orbRoot.Name = 'Root'
	orbRoot.BackgroundTransparency = 1
	orbRoot.Size = UDim2.fromScale(1, 1)
	orbRoot.Parent = orbGui
	orbGui.Parent = pg
	return orbRoot
end
local function bump(gui)
	local ok, Motion = pcall(require, RS.Shared.UIMotion)
	if ok and Motion and Motion.bump then pcall(Motion.bump, gui, 0.14, 0.16) end
end
function FightJuice.orbs(fromWorld, count, kind)
	kind = FightJuice.OrbLook[kind or 'Power'] and kind or 'Power'
	local look = FightJuice.OrbLook[kind]
	local cam = workspace.CurrentCamera
	local root = orbLayer()
	local row = counterOf(kind)
	if not (cam and root and row) then return 0 end
	local size = cam.ViewportSize
	if not size or size.X < 10 then size = Vector2.new(1280, 720) end
	local from = FightJuice.project(cam.CFrame, cam.FieldOfView, size, fromWorld)
	if not from then return 0 end
	-- (the counter's place on the screen; the offline harness has no layout: there the HUD's usual spot at 1280 x 720)
	local okT, to = pcall(function() return row.AbsolutePosition + row.AbsoluteSize / 2 - root.AbsolutePosition end)
	if not okT or typeof(to) ~= 'Vector2' then to = FightJuice.OfflineAt[kind] or Vector2.new(size.X / 2, size.Y - 150) end
	count = count or 4
	for k = 1, count do
		local o = Instance.new('ImageLabel')
		o.Name = 'Orb'
		o.BackgroundColor3 = look.Fill
		o.BackgroundTransparency = 0
		o.AnchorPoint = Vector2.new(0.5, 0.5)
		o.Size = UDim2.fromOffset(30, 30)
		o.Position = UDim2.fromOffset(from.X, from.Y)
		o.Image = iconOf(look.Icon)
		o.ScaleType = Enum.ScaleType.Fit
		o:SetAttribute('PreviewImage', look.Icon)
		o.ZIndex = 2
		local c = Instance.new('UICorner')
		c.CornerRadius = UDim.new(0.5, 0)
		c.Parent = o
		local g = Instance.new('UIGradient')
		g.Color = ColorSequence.new(look.Light, look.Dark)
		g.Rotation = 90
		g.Parent = o
		edge(o, Color3.new(1, 1, 1), 2.5)
		local sc = Instance.new('UIScale')
		sc.Scale = 0.2
		sc.Parent = o
		o.Parent = root
		-- out in a ring (0.18 s, eased), a beat, then a curve into the counter (ease in: it speeds up), staggered
		local a = (k / count) * math.pi * 2 + math.random() * 0.5
		local spread = 46 + math.random() * 28
		local mid = from + Vector2.new(math.cos(a) * spread, math.sin(a) * spread * 0.8 - 18)
		tween(o, 0.18, { Position = UDim2.fromOffset(mid.X, mid.Y) }, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
		tween(sc, 0.18, { Scale = 1 }, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
		local start = 0.24 + k * 0.05
		local fly = 0.5
		later(start, function()
			local t0 = os.clock()
			local p0 = mid
			local p1 = Vector2.new(mid.X + (to.X - mid.X) * 0.2, math.min(mid.Y, to.Y) - 80) -- (bows up and over)
			local conn
			conn = RunService.PreRender:Connect(function()
				local u = math.clamp((os.clock() - t0) / fly, 0, 1)
				local e = u * u * (3 - 2 * u)
				e = e * e * 0.35 + e * 0.65
				local q = (1 - e) ^ 2 * p0 + 2 * (1 - e) * e * p1 + e * e * to
				if o.Parent then
					o.Position = UDim2.fromOffset(q.X, q.Y)
					sc.Scale = 1 - 0.35 * e
				end
				if u >= 1 then
					conn:Disconnect()
					if o.Parent then o:Destroy() end
					bump(row)
				end
			end)
		end)
		later(start + 1.5, function() if o.Parent then o:Destroy() end end) -- (a safety net)
	end
	return count
end

---------------------------------------------------------------------------------------------- "KO x2!"
-- The streak chip under the fight counter: gold words, a dark outline, a pop each knock-out; it eases away 1.6 s after
-- the last. A single knock-out shows nothing (the counter going down says it).
function FightJuice.streakChip(parent)
	local holder = Instance.new('Frame')
	holder.Name = 'Streak'
	holder.BackgroundTransparency = 1
	holder.AnchorPoint = Vector2.new(0.5, 0)
	holder.Position = UDim2.new(0.5, 0, 0.27, 0) -- (below the top band, where the counter, CLEAR! and the hint live: one voice there)
	holder.Size = UDim2.fromOffset(240, 38)
	holder.Visible = false
	holder.Parent = parent
	local sc = Instance.new('UIScale')
	sc.Parent = holder
	local t = Instance.new('TextLabel')
	t.Name = 'Text'
	t.BackgroundTransparency = 1
	t.Size = UDim2.fromScale(1, 1)
	t.TextScaled = true
	t.Text = ''
	t.ZIndex = 3
	pcall(function() t.FontFace = require(RS.Shared.Fonts).Title end)
	t.TextColor3 = FightJuice.Gold
	edge(t, FightJuice.Ink, 3).ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
	t.Parent = holder
	pcall(function() require(RS.Shared.TextStyle).apply(t, 'gold', { Thickness = 3 }) end)
	local chip = { Gui = holder, token = 0 }
	local WORDS = { [2] = 'DOUBLE KO!', [3] = 'TRIPLE KO!' }
	function chip.ko(n)
		if (n or 0) < 2 then return end
		chip.token += 1
		local my = chip.token
		t.Text = WORDS[n] or ('KO x' .. n .. '!')
		t.TextTransparency = 0
		holder.Visible = true
		sc.Scale = 0.55
		tween(sc, 0.22, { Scale = 1 }, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
		later(1.6, function()
			if chip.token ~= my then return end
			tween(sc, 0.25, { Scale = 0.8 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
			tween(t, 0.25, { TextTransparency = 1 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
			later(0.27, function() if chip.token == my then holder.Visible = false end end)
		end)
	end
	function chip.hide()
		chip.token += 1
		holder.Visible = false
	end
	return chip
end

return FightJuice

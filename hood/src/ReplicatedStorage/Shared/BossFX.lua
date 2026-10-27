-- (brief 29) A boss's big moves on your screen (Waves.client): the RED telegraph on the ground, the thing it throws or
-- rolls, and the hit. Look from the reference (refs29 section 6): a flat, solid, translucent red (#E8101C) shape with
-- lighter marks, crisp edges, that fills up as the hit comes. Kid-friendly: dust, rings and stars, no blood.
--   local t = BossFX.telegraph(frame, a, y, parent)  a = the server's 'Tele' (map frame), y = ground height (map frame)
--   t.update(progress)      0..1 through the telegraph (the fill grows; the edge pulses faster near the end)
--   t.finish(landed)        a white flash, then it fades and goes
--   BossFX.impact(at, radius, color?)       a ground ring, dust and sparks at `at` (world)
--   BossFX.fly(prop, from, to, time, opts)  a thrown (arc) or rolled (opts.roll) prop from -> to (world), landing at time
--   BossFX.dust(at, scale)                   a dust puff (a charge's trail, a landing)
--   (brief 29, P3b) shapes Square (the container drop: R = half the side, one per P) and Ring (the shockwave: a band
--   from Ri to R round P[1]); BossFX.drop(prop, at, time) drops a prop straight down onto `at` (world)
-- Every part is anchored, non-colliding, non-query, no shadow, in `parent` (HoodGoons).
local RS = game:GetService('ReplicatedStorage')
local RunService = game:GetService('RunService')
local TweenService = game:GetService('TweenService')

local BossFX = {}
BossFX.Red = Color3.fromRGB(232, 16, 28) -- (the reference's #E8101C)
BossFX.Light = Color3.fromRGB(255, 132, 120)
BossFX.Edge = Color3.fromRGB(255, 236, 228)
BossFX.Lift = 0.08 -- studs over the ground
BossFX.Parent = nil -- (Waves.client sets its HoodGoons folder)

local function part(name, size, cf, color, transparency, shape, parent)
	local p = Instance.new(shape == 'Wedge' and 'WedgePart' or 'Part')
	p.Name = name
	if shape and shape ~= 'Wedge' then p.Shape = shape end
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = Enum.Material.SmoothPlastic
	p.Transparency = transparency or 0
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = true, false, false, false, false
	p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	p.Parent = parent or BossFX.Parent or workspace
	return p
end
BossFX.part = part

-- A flat disc of radius r lying on the ground at cf (its up = the ground's up).
local UPRIGHT = CFrame.Angles(0, 0, math.pi / 2)
local function disc(name, cf, r, h, color, transparency, parent)
	return part(name, Vector3.new(h, 2 * r, 2 * r), cf * UPRIGHT, color, transparency, Enum.PartType.Cylinder, parent)
end

-- A flat triangle a, b, c (world points on one plane) from two wedges, `h` thick (the usual two-wedge triangle).
local function triangle(a, b, c, h, color, transparency, parent, w1, w2)
	local ab, ac, bc = b - a, c - a, c - b
	local abd, acd, bcd = ab:Dot(ab), ac:Dot(ac), bc:Dot(bc)
	if abd > acd and abd > bcd then
		c, a = a, c
	elseif acd > bcd and acd > abd then
		a, b = b, a
	end
	ab, ac, bc = b - a, c - a, c - b
	local right = ac:Cross(ab)
	if right.Magnitude < 1e-6 then return w1, w2 end
	right = right.Unit
	local up = bc:Cross(right).Unit
	local back = bc.Unit
	local height = math.abs(ab:Dot(up))
	w1 = w1 or part('ConeSlice', Vector3.one, CFrame.new(), color, transparency, 'Wedge', parent)
	w2 = w2 or part('ConeSlice', Vector3.one, CFrame.new(), color, transparency, 'Wedge', parent)
	w1.Size = Vector3.new(h, math.max(0.05, height), math.max(0.05, math.abs(ab:Dot(back))))
	w1.CFrame = CFrame.fromMatrix((a + b) / 2, right, up, back)
	w2.Size = Vector3.new(h, math.max(0.05, height), math.max(0.05, math.abs(ac:Dot(back))))
	w2.CFrame = CFrame.fromMatrix((a + c) / 2, -right, up, -back)
	return w1, w2
end

local function v3(t) return Vector3.new(t[1] or 0, 0, t[2] or 0) end

function BossFX.telegraph(frame, a, y, parent)
	local holder = Instance.new('Model')
	holder.Name = 'BossTelegraph'
	holder.Parent = parent or BossFX.Parent or workspace
	local lift = (y or 0) + BossFX.Lift
	local function at(p, dy) return frame * CFrame.new(p.X, lift + (dy or 0), p.Z) end
	local fills, edges, all = {}, {}, {}
	local api = {}
	local O, D = v3(a.O or {}), v3(a.D or { 0, 1 })
	if D.Magnitude < 1e-3 then D = Vector3.new(0, 0, 1) end
	D = D.Unit
	if a.Shape == 'Line' then
		local L, W = a.L or 20, a.W or 4
		local mid = O + D * (L / 2)
		local cf = CFrame.lookAt(at(mid).Position, at(mid + D).Position)
		local base = part('Lane', Vector3.new(W, 0.1, L), cf, BossFX.Red, 0.35, nil, holder)
		table.insert(all, base)
		-- crisp light edges down both sides and across the far end
		for _, s in { -1, 1 } do
			table.insert(edges, part('LaneEdge', Vector3.new(0.3, 0.12, L), cf * CFrame.new(s * (W / 2 - 0.15), 0.01, 0), BossFX.Edge, 0.15, nil, holder))
		end
		table.insert(edges, part('LaneEnd', Vector3.new(W, 0.12, 0.3), cf * CFrame.new(0, 0.01, -L / 2 + 0.15), BossFX.Edge, 0.15, nil, holder))
		-- chevrons pointing down the lane (the reference's lighter diagonal marks)
		for k = 1, math.max(2, math.floor(L / 7)) do
			local z = L / 2 - k * L / (math.max(2, math.floor(L / 7)) + 1)
			for _, s in { -1, 1 } do
				local arm = part('Chevron', Vector3.new(0.35, 0.11, W * 0.42), cf * CFrame.new(s * W * 0.15, 0.005, z) * CFrame.Angles(0, s * math.rad(45), 0), BossFX.Light, 0.25, nil, holder)
				table.insert(all, arm)
			end
		end
		local fill = part('LaneFill', Vector3.new(W - 0.6, 0.11, 0.05), cf, BossFX.Red, 0.12, nil, holder)
		fills[1] = function(k)
			local len = math.max(0.05, L * k)
			fill.Size = Vector3.new(W - 0.6, 0.11, len)
			fill.CFrame = cf * CFrame.new(0, 0.004, L / 2 - len / 2)
		end
		table.insert(all, fill)
	elseif a.Shape == 'Circle' then
		for k, c in a.P or { a.O } do
			local cf = at(v3(c))
			local R = a.R or 6
			table.insert(edges, disc('RingEdge', cf, R, 0.1, BossFX.Edge, 0.15, holder))
			table.insert(all, disc('Ring', cf * CFrame.new(0, 0.01, 0), R - 0.35, 0.1, BossFX.Red, 0.3, holder))
			local fill = disc('RingFill', cf * CFrame.new(0, 0.02, 0), 0.05, 0.1, BossFX.Red, 0.1, holder)
			table.insert(all, fill)
			-- a cross in the middle: where it lands
			table.insert(all, part('Mark', Vector3.new(R * 0.5, 0.12, 0.35), cf * CFrame.new(0, 0.03, 0) * CFrame.Angles(0, math.rad(45), 0), BossFX.Light, 0.2, nil, holder))
			table.insert(all, part('Mark', Vector3.new(R * 0.5, 0.12, 0.35), cf * CFrame.new(0, 0.03, 0) * CFrame.Angles(0, math.rad(-45), 0), BossFX.Light, 0.2, nil, holder))
			fills[k] = function(p) local r = math.max(0.05, (R - 0.35) * p) fill.Size = Vector3.new(0.1, 2 * r, 2 * r) end
		end
	elseif a.Shape == 'Square' then
		-- (brief 29, P3b) the container drop: a red square (R = half its side) where each container comes down, a light
		-- frame, a cross, and a fill growing from the middle
		for k, c in a.P or { a.O } do
			local cf = at(v3(c))
			local R = a.R or 4
			table.insert(all, part('Square', Vector3.new(2 * R - 0.6, 0.1, 2 * R - 0.6), cf, BossFX.Red, 0.3, nil, holder))
			for _, e in { { 0, R - 0.15, 2 * R, 0.3 }, { 0, -R + 0.15, 2 * R, 0.3 }, { R - 0.15, 0, 0.3, 2 * R }, { -R + 0.15, 0, 0.3, 2 * R } } do
				table.insert(edges, part('SquareEdge', Vector3.new(e[3], 0.12, e[4]), cf * CFrame.new(e[1], 0.01, e[2]), BossFX.Edge, 0.15, nil, holder))
			end
			for _, yaw in { 45, -45 } do
				table.insert(all, part('Mark', Vector3.new(R * 0.9, 0.12, 0.35), cf * CFrame.new(0, 0.03, 0) * CFrame.Angles(0, math.rad(yaw), 0), BossFX.Light, 0.2, nil, holder))
			end
			local fill = part('SquareFill', Vector3.new(0.1, 0.11, 0.1), cf * CFrame.new(0, 0.02, 0), BossFX.Red, 0.1, nil, holder)
			table.insert(all, fill)
			fills[k] = function(q) local w = math.max(0.1, (2 * R - 0.6) * q) fill.Size = Vector3.new(w, 0.11, w) end
		end
	elseif a.Shape == 'Ring' then
		-- (P3b) the shockwave: a red band between Ri and R round the boss (a ring of flat segments), its light rims, and
		-- a fill sweeping out from the inner rim; the middle stays clear (the safe spot by the boss)
		local c = a.P and a.P[1] and v3(a.P[1]) or O
		local R, Ri = a.R or 20, a.Ri or 6
		local n = 28
		local cf = at(c)
		local mid, band = (R + Ri) / 2, R - Ri
		for i = 0, n - 1 do
			local t = (i + 0.5) / n * math.pi * 2
			local seg = CFrame.Angles(0, t, 0)
			local outerW, innerW = 2 * math.pi * R / n + 0.1, 2 * math.pi * Ri / n + 0.1
			table.insert(all, part('RingBand', Vector3.new((outerW + innerW) / 2, 0.1, band - 0.5), cf * seg * CFrame.new(0, 0, -mid), BossFX.Red, 0.32, nil, holder))
			table.insert(edges, part('RingRim', Vector3.new(outerW, 0.12, 0.3), cf * seg * CFrame.new(0, 0.01, -R + 0.15), BossFX.Edge, 0.15, nil, holder))
			table.insert(edges, part('RingRim', Vector3.new(innerW, 0.12, 0.3), cf * seg * CFrame.new(0, 0.01, -Ri - 0.15), BossFX.Edge, 0.15, nil, holder))
		end
		local wave = {}
		for i = 0, n - 1 do wave[i] = part('RingFill', Vector3.new(0.1, 0.11, 0.1), cf, BossFX.Red, 0.1, nil, holder) table.insert(all, wave[i]) end
		fills[1] = function(q)
			local r = Ri + 0.3 + (band - 0.6) * q
			local d = (r - Ri - 0.3)
			for i = 0, n - 1 do
				local t = (i + 0.5) / n * math.pi * 2
				local w = 2 * math.pi * ((Ri + r) / 2) / n + 0.1
				wave[i].Size = Vector3.new(w, 0.11, math.max(0.05, d))
				wave[i].CFrame = cf * CFrame.Angles(0, t, 0) * CFrame.new(0, 0.02, -(Ri + 0.3 + d / 2))
			end
		end
	elseif a.Shape == 'Cone' then
		local L, ang = a.L or 18, a.A or math.rad(60)
		local n = 6
		local function arcPt(i, len)
			local t = -ang / 2 + ang * i / n
			local d = Vector3.new(D.X * math.cos(t) - D.Z * math.sin(t), 0, D.X * math.sin(t) + D.Z * math.cos(t))
			return at(O + d * len).Position
		end
		local o = at(O).Position
		for i = 0, n - 1 do
			local w1, w2 = triangle(o, arcPt(i, L), arcPt(i + 1, L), 0.1, BossFX.Red, 0.35, holder)
			table.insert(all, w1); table.insert(all, w2)
			table.insert(edges, part('ConeEdge', Vector3.new(0.3, 0.12, (arcPt(i, L) - arcPt(i + 1, L)).Magnitude + 0.2), CFrame.lookAt((arcPt(i, L) + arcPt(i + 1, L)) / 2, arcPt(i + 1, L)), BossFX.Edge, 0.15, nil, holder))
		end
		for _, i in { 0, n } do
			local p = arcPt(i, L)
			table.insert(edges, part('ConeSide', Vector3.new(0.3, 0.12, L), CFrame.lookAt((o + p) / 2, p), BossFX.Edge, 0.15, nil, holder))
		end
		local slices = {}
		fills[1] = function(k)
			local len = math.max(0.3, L * k)
			local up = Vector3.new(0, 0.01, 0)
			for i = 0, n - 1 do
				local s = slices[i] or {}
				s[1], s[2] = triangle(o + up, arcPt(i, len) + up, arcPt(i + 1, len) + up, 0.11, BossFX.Red, 0.1, holder, s[1], s[2])
				slices[i] = s
			end
		end
	end
	for _, e in edges do table.insert(all, e) end
	api.Model = holder
	function api.update(progress)
		local k = math.clamp(progress, 0, 1)
		for _, f in fills do f(k) end
		-- the edge pulses, quicker as the hit comes
		local pulse = 0.15 + 0.35 * (0.5 + 0.5 * math.sin(os.clock() * (8 + 16 * k)))
		for _, e in edges do e.Transparency = pulse * (1 - k * 0.6) end
	end
	function api.finish(landed)
		local white = landed and require(script.Parent.FlashGate).take('boss') -- (one white flash a second at most)
		for _, p in all do
			if p.Parent then
				p.Color = p.Color:Lerp(Color3.new(1, 1, 1), white and 0.5 or 0.25)
				TweenService:Create(p, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Transparency = 1 }):Play()
			end
		end
		task.delay(0.35, function() holder:Destroy() end)
	end
	api.update(0)
	return api
end

-- A dust puff: soft grey balls swelling and fading.
function BossFX.dust(at, scale, count)
	scale = scale or 1
	for k = 1, count or 5 do
		local a = k / (count or 5) * math.pi * 2 + math.random() * 0.6
		local off = Vector3.new(math.cos(a), 0.2 + math.random() * 0.3, math.sin(a)) * scale
		local p = part('Dust', Vector3.one * 1.1 * scale, CFrame.new(at + off * 0.3), Color3.fromRGB(214, 206, 196):Lerp(Color3.new(1, 1, 1), math.random() * 0.4), 0.15, Enum.PartType.Ball)
		TweenService:Create(p, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Size = Vector3.one * 2.6 * scale, CFrame = CFrame.new(at + off * 1.4 + Vector3.new(0, 0.8 * scale, 0)), Transparency = 1 }):Play()
		task.delay(0.55, function() p:Destroy() end)
	end
end

-- The hit landing: a white shock ring racing out over the ground, dust and sparks.
function BossFX.impact(at, radius, color)
	radius = radius or 6
	local ring = disc('Shock', CFrame.new(at + Vector3.new(0, 0.15, 0)), radius * 0.25, 0.15, Color3.new(1, 1, 1), 0.1)
	TweenService:Create(ring, TweenInfo.new(0.32, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), { Size = Vector3.new(0.15, radius * 2.3, radius * 2.3), Transparency = 1 }):Play()
	task.delay(0.36, function() ring:Destroy() end)
	BossFX.dust(at, math.clamp(radius / 5, 0.8, 2.2), 7)
	local ok, Juice = pcall(require, RS.Shared.Juice)
	if ok then
		Juice.burst(at + Vector3.new(0, 1, 0), color or Color3.fromRGB(255, 220, 60), math.clamp(radius / 5, 0.8, 2))
	end
end

-- The thing a boss throws: the PropModels model when there is one, else a ball in its colour.
local PROP_COLOR = { Dodgeball = Color3.fromRGB(226, 52, 52), Basketball = Color3.fromRGB(236, 112, 40), MoneyBag = Color3.fromRGB(96, 150, 70), Crate = Color3.fromRGB(176, 124, 70), Barrel = Color3.fromRGB(52, 92, 170) }
local propModels = nil
local function buildProp(name, scale)
	if propModels == nil then
		local shared = RS:FindFirstChild('Shared')
		local models = shared and shared:FindFirstChild('Models')
		local m = models and models:FindFirstChild('PropModels')
		local ok, r = false, nil
		if m then ok, r = pcall(require, m) end
		propModels = ok and type(r) == 'table' and r or false
	end
	if propModels and propModels.Meta and propModels.Meta[name] then
		local ok, model = pcall(propModels.build, name, scale or 1)
		if ok and model then
			model.Parent = BossFX.Parent or workspace
			return model
		end
	end
	local holder = Instance.new('Model')
	holder.Name = name or 'Prop'
	local ball = part('Ball', Vector3.one * 2 * (scale or 1), CFrame.new(), PROP_COLOR[name] or Color3.fromRGB(226, 52, 52), 0, Enum.PartType.Ball, holder)
	holder.PrimaryPart = ball
	holder.Parent = BossFX.Parent or workspace
	return holder
end
BossFX.buildProp = buildProp

-- A prop flying from -> to (world) in `time` seconds: a high arc (or along the ground with opts.roll), spinning; it
-- lands with an impact (opts.radius) and is gone a moment later.
-- (P3b) A prop dropped from high above straight onto `at` (world), landing at `time`: a container off the crane.
function BossFX.drop(name, at, time, height)
	return BossFX.fly(name, at + Vector3.new(0, height or 26, 0), at, time, { drop = true, scale = 1 })
end

function BossFX.fly(name, from, to, time, opts)
	opts = opts or {}
	local model = buildProp(name, opts.scale)
	-- (moved part by part about its pivot part: the same in a live game and in the offline previews)
	local pivot = model.PrimaryPart
	local rel = {}
	for _, d in model:GetDescendants() do
		if d:IsA('BasePart') then rel[d] = pivot and pivot.CFrame:Inverse() * d.CFrame or CFrame.identity end
	end
	local t0 = os.clock()
	-- (P3b) opts.drop: straight down, speeding up (gravity), no spin; opts.slide: along the ground facing its way, no spin
	local flat = opts.roll or opts.drop or opts.slide
	local height = flat and 0 or math.max(6, (to - from).Magnitude * 0.35)
	local conn
	local function place(k)
		local p = from:Lerp(to, opts.drop and k * k or k) + Vector3.new(0, height * 4 * k * (1 - k), 0)
		local spin = opts.roll and CFrame.Angles(-k * time * 14, 0, 0) or (opts.drop or opts.slide) and CFrame.identity or CFrame.Angles(k * 9, k * 5, 0)
		local dir = Vector3.new(to.X - from.X, 0, to.Z - from.Z)
		local face = (dir.Magnitude > 1e-3 and not opts.drop) and CFrame.lookAt(p, p + dir) or CFrame.new(p) * CFrame.Angles(0, opts.yaw or 0, 0)
		local cf = face * spin
		for d, r in rel do d.CFrame = cf * r end
	end
	place(0)
	conn = RunService.PreRender:Connect(function()
		local k = (os.clock() - t0) / math.max(0.05, time)
		if k >= 1 then
			conn:Disconnect()
			place(1)
			if not (opts.roll or opts.slide) then BossFX.impact(to, opts.radius or 5, opts.color) end
			task.delay((opts.roll or opts.slide) and 0.1 or opts.drop and 0.9 or 0.45, function()
				for _, d in model:GetDescendants() do
					if d:IsA('BasePart') then TweenService:Create(d, TweenInfo.new(0.25), { Transparency = 1 }):Play() end
				end
				task.delay(0.3, function() model:Destroy() end)
			end)
			return
		end
		place(k)
	end)
	return model
end

return BossFX

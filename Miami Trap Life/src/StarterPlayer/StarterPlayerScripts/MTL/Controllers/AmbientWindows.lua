--!strict
-- Night windows + things that sway (client only). Required by AmbientLife (step() from its one Heartbeat).
--   windows  18:30-06:00: 35-45% of the hood's windows glow warm (Neon 255,214,160 panes 0.03 studs in front of the
--            glass, AmbientMap.Windows), 4% flicker TV-blue. After 1 am they go dark one by one; early risers light
--            up at 5:30. A different pattern every night, the same on every client. No PointLights (Bloom does it).
--   sway     laundry and flags DressHoodLife tagged MTL_Sway swing gently within 120 studs.
-- LightingController does NOT light windows (it only does street lamps), so this is the one owner.
local CollectionService = game:GetService("CollectionService")

local AmbientWindows = {}

type Win = { cf: CFrame, size: Vector3, part: Part?, state: number, onAt: number, warm: Color3 }
type Flick = { part: BasePart, nextAt: number, untilT: number, base: number }
type Swing = { part: BasePart, base: CFrame, hinge: Vector3, axis: Vector3, amp: number, speed: number, phase: number }

local cfg: any
local R: any
local folder: Folder
local wins: { Win } = {}
local swings: { [BasePart]: Swing } = {}
local flicks: { Flick } = {}
local lastCheck = -1e9
local rng = Random.new()

local function pane(w: Win): Part
	local p = Instance.new("Part")
	p.Name = "Lit"
	p.Anchored = true
	p.CanCollide = false
	p.CanTouch = false
	p.CanQuery = false
	p.CastShadow = false
	p.Material = Enum.Material.Neon
	p.Size = w.size
	p.CFrame = w.cf
	p.Color = w.warm
	p.Transparency = 1
	p.Parent = folder
	return p
end

local function updateWindows(ctx: any)
	local W = cfg.Windows
	for i, w in wins do
		local s = R.windowState(i, ctx.hour, ctx.day, W)
		-- evenings switch on one by one over ~70 minutes, not all at 18:30
		local h = ctx.hour % 24
		if s > 0 and h >= W.On and h < w.onAt then
			s = 0
		end
		if s ~= w.state then
			w.state = s
			if s > 0 and not w.part then
				w.part = pane(w)
			end
			local p = w.part
			if p then
				p.Transparency = if s > 0 then 0.08 else 1
				p.Color = if s == 2 then W.TV else w.warm
			end
		end
	end
end

local function flickerTVs(ctx: any)
	for _, w in wins do
		if w.state == 2 and w.part and (w.cf.Position - ctx.camPos).Magnitude < 160 then
			local k = math.noise(ctx.now * 3, w.cf.X * 0.1, w.cf.Z * 0.1)
			w.part.Transparency = 0.15 + 0.45 * math.abs(k)
			w.part.Color = cfg.Windows.TV:Lerp(Color3.fromRGB(210, 220, 236), math.clamp(k + 0.3, 0, 1) * 0.5)
		end
	end
end

---------------------------------------------------------------- sway

local function addSwing(inst: Instance)
	if not inst:IsA("BasePart") or swings[inst] then
		return
	end
	local kind = (inst:GetAttribute("Sway") :: string?) or "Laundry"
	local def = cfg.Sway[kind] or cfg.Sway.Laundry
	local cf = inst.CFrame
	local hinge = (inst:GetAttribute("Hinge") :: Vector3?) or (cf * Vector3.new(0, inst.Size.Y / 2, 0))
	local axis = (inst:GetAttribute("Axis") :: Vector3?) or cf.RightVector
	swings[inst] = {
		part = inst,
		base = cf,
		hinge = hinge,
		axis = axis.Unit,
		amp = math.rad(def.amp) * rng:NextNumber(0.7, 1.2),
		speed = def.speed * rng:NextNumber(0.85, 1.15),
		phase = rng:NextNumber(0, 6.28),
	}
end

local function updateSway(ctx: any)
	local r = cfg.Sway.Radius
	for part, s in swings do
		if not part.Parent then
			swings[part] = nil
		elseif (s.hinge - ctx.camPos).Magnitude < r then
			-- a gust now and then on top of the slow swing
			local gust = 0.6 + 0.4 * math.noise(ctx.now * 0.3, s.phase)
			local a = s.amp * gust * math.sin(ctx.now * s.speed + s.phase)
			local rot = CFrame.fromAxisAngle(s.axis, a)
			part.CFrame = CFrame.new(s.hinge) * rot * CFrame.new(-s.hinge) * s.base
		end
	end
end

---------------------------------------------------------------- neon flicker
-- shop neon (tagged MTL_Flicker by DressHoodLife) stutters once every 8-20 s, never constantly

local function addFlick(inst: Instance)
	if inst:IsA("BasePart") then
		table.insert(flicks, { part = inst, nextAt = os.clock() + rng:NextNumber(4, 20), untilT = 0, base = inst.Transparency })
	end
end

local function updateFlicks(ctx: any)
	for i = #flicks, 1, -1 do
		local f = flicks[i]
		if not f.part.Parent then
			table.remove(flicks, i)
		elseif ctx.now >= f.nextAt then
			f.nextAt = ctx.now + rng:NextNumber(8, 20)
			f.untilT = ctx.now + rng:NextNumber(0.25, 0.6)
		elseif ctx.now < f.untilT then
			f.part.Transparency = if math.random() < 0.5 then 0.75 else f.base
		elseif f.part.Transparency ~= f.base then
			f.part.Transparency = f.base
		end
	end
end

---------------------------------------------------------------- loop

function AmbientWindows.init(ctx: any)
	cfg = ctx.cfg
	R = ctx.R
	folder = Instance.new("Folder")
	folder.Name = "Windows"
	folder.Parent = ctx.folder
	for i, w in ctx.map.Windows or {} do
		if i > cfg.Windows.Max then
			break
		end
		-- { x, y, z, yawDeg, width, height } : the outside face of the glass, facing out
		local cf = CFrame.new(w[1], w[2], w[3]) * CFrame.Angles(0, math.rad(w[4]), 0)
		table.insert(wins, {
			cf = cf,
			size = Vector3.new(math.max(w[5] - 0.2, 0.6), math.max(w[6] - 0.2, 0.6), 0.05),
			part = nil,
			state = 0,
			onAt = cfg.Windows.On + R.hash(i, 77) * 1.2,
			warm = if R.hash(i, 5) < 0.3 then cfg.Windows.Warm2 else cfg.Windows.Warm,
		})
	end
	for _, inst in CollectionService:GetTagged("MTL_Sway") do
		addSwing(inst)
	end
	CollectionService:GetInstanceAddedSignal("MTL_Sway"):Connect(addSwing)
	for _, inst in CollectionService:GetTagged("MTL_Flicker") do
		addFlick(inst)
	end
	CollectionService:GetInstanceAddedSignal("MTL_Flicker"):Connect(addFlick)
end

function AmbientWindows.step(ctx: any, _dt: number, far: boolean)
	if far and ctx.now - lastCheck > 2 then
		lastCheck = ctx.now
		updateWindows(ctx)
	end
	if far then
		flickerTVs(ctx)
	end
	updateFlicks(ctx)
	updateSway(ctx)
end

function AmbientWindows.stats(): number
	local n = 0
	for _, w in wins do
		if w.state > 0 then
			n += 1
		end
	end
	return n
end

return AmbientWindows

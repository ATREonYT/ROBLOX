--[[
	The Bear Trap's look (Config/Powers.BearTrap), built from plain parts so it shows before any mesh is uploaded, and
	shaped like the icon on the owner's picture b (design/owner-oct19/pic-b-catcher-bar.png): a dark purple metal ring
	of two toothed jaws, a light square plate in the middle on a bar across.

	Pure maths plus Instance.new, so the server (HuzzServer/PowerService: the trap on the floor), every screen
	(Gameplay/PowerEffects: the trap flying in its arc, the snap when it springs) and the offline preview
	(motion3d/power_scene.luau) all build the same thing.
	  BearTrap.build(accent)            -> Model (parts named, anchored, no collisions); jaws open, glow hidden
	  BearTrap.pose(model, at, jaw, scale?) -> places it: `at` = the trap's centre on the floor (any CFrame, so it can
	                                       spin in the air), jaw 0 = open (the jaws flat, teeth up) .. 1 = shut (both
	                                       jaws stand up and their teeth meet); scale (default 1) sizes it (in the hand)
	  BearTrap.arm(model, on)           -> the soft danger disc (its catch radius) on or off
	A real trap's jaws lie flat when it's set and swing up about the bar to close, so that's what `jaw` does.
]]
local BearTrap = {}

BearTrap.R = 2.1 -- the jaws' radius (studs): the ring is 4.2 across, inside the 3-stud catch radius's 6
local SEGS = 7 -- pieces in each half ring
local METAL = Color3.fromRGB(78, 64, 112) -- dark purple metal (his icon)
local RIM = Color3.fromRGB(112, 94, 158)
local TEETH = Color3.fromRGB(205, 198, 232)
local PLATE = Color3.fromRGB(186, 172, 222)
local BAR = Color3.fromRGB(96, 84, 128)

-- Every piece in the trap's own space with the jaws open: { name, size, colour, material, cframe, jaw (1 front,
-- 2 back, nil = fixed) }. The jaws' pieces are given flat; pose() turns them about the bar (the X axis).
local function pieces()
	local list = {}
	local R = BearTrap.R
	for j, side in { 1, -1 } do -- front jaw (-Z), back jaw (+Z)
		local shift = if j == 2 then 0.5 else 0 -- (the back jaw's teeth sit between the front's, so they interlock)
		for i = 0, SEGS - 1 do
			local a0, a1 = math.pi * i / SEGS, math.pi * (i + 1) / SEGS
			local p0 = Vector3.new(R * math.cos(a0), 0, -side * R * math.sin(a0))
			local p1 = Vector3.new(R * math.cos(a1), 0, -side * R * math.sin(a1))
			local mid = (p0 + p1) / 2
			local along = (p1 - p0)
			local cf = CFrame.lookAt(mid + Vector3.new(0, 0.13, 0), mid + Vector3.new(0, 0.13, 0) + along)
			table.insert(list, { "Jaw" .. j .. "_" .. i, Vector3.new(0.3, 0.26, along.Magnitude + 0.08), if i % 2 == 0 then METAL else RIM,
				Enum.Material.Metal, cf, j })
			-- a tooth: a wedge standing up on the jaw's inner edge, its sharp side up
			local ta = math.pi * (i + 0.5 + shift * 0.5) / SEGS
			if ta < math.pi - 0.05 then
				local tp = Vector3.new((R - 0.12) * math.cos(ta), 0.5, -side * (R - 0.12) * math.sin(ta))
				local inward = -Vector3.new(math.cos(ta), 0, -side * math.sin(ta))
				-- a WedgePart is full height at its back (+Z) and slopes down to its front: the tall side faces the
				-- middle, so the tooth's point stands over the jaw's inner edge (X = up x back, a right-handed frame)
				table.insert(list, { "Tooth" .. j .. "_" .. i, Vector3.new(0.24, 0.5, 0.3), TEETH, Enum.Material.Metal,
					CFrame.fromMatrix(tp, Vector3.yAxis:Cross(inward), Vector3.yAxis), j, "Wedge" })
			end
		end
	end
	-- the bar the jaws turn about, with a spring coil at each end
	table.insert(list, { "Bar", Vector3.new(2 * R + 0.5, 0.2, 0.28), BAR, Enum.Material.Metal, CFrame.new(0, 0.1, 0) })
	for k, x in { -1, 1 } do
		table.insert(list, { "Spring" .. k, Vector3.new(0.5, 0.42, 0.42), RIM, Enum.Material.Metal,
			CFrame.new(x * (R + 0.25), 0.21, 0), nil, "Cylinder" })
	end
	-- the plate in the middle (step on it and it snaps), on a short stem
	table.insert(list, { "Plate", Vector3.new(1.15, 0.16, 1.15), PLATE, Enum.Material.SmoothPlastic, CFrame.new(0, 0.3, 0) })
	table.insert(list, { "Stem", Vector3.new(0.34, 0.14, 0.9), BAR, Enum.Material.Metal, CFrame.new(0, 0.22, 0.55) })
	return list
end

function BearTrap.build(accent: Color3?): Model
	local model = Instance.new("Model")
	model.Name = "BearTrap"
	for _, p in pieces() do
		local part
		if p[7] == "Wedge" then
			part = Instance.new("WedgePart")
		else
			part = Instance.new("Part")
			if p[7] == "Cylinder" then
				part.Shape = Enum.PartType.Cylinder
			end
		end
		part.Name = p[1]
		part.Size = p[2]
		part.Color = p[3]
		part.Material = p[4]
		part.Anchored, part.CanCollide, part.CanQuery, part.CanTouch, part.CastShadow = true, false, false, false, false
		part.CFrame = p[5]
		part:SetAttribute("BaseSize", p[2])
		part:SetAttribute("Jaw", p[6])
		part.Parent = model
	end
	-- the danger disc: soft, flat, the size of the catch radius (shown once the trap is armed)
	local glow = Instance.new("Part")
	glow.Name = "Glow"
	glow.Shape = Enum.PartType.Cylinder
	glow.Material = Enum.Material.Neon
	glow.Color = accent or Color3.fromRGB(222, 112, 96)
	glow.Transparency = 1
	glow.Size = Vector3.new(0.05, 6, 6)
	glow.Anchored, glow.CanCollide, glow.CanQuery, glow.CanTouch, glow.CastShadow = true, false, false, false, false
	glow.Parent = model
	return model
end

-- Where each piece goes (cached by name: the open pose in the trap's space).
local BASE = nil
local function base()
	if not BASE then
		BASE = {}
		for _, p in pieces() do
			BASE[p[1]] = { cf = p[5], jaw = p[6] }
		end
	end
	return BASE
end

function BearTrap.pose(model: Model, at: CFrame, jaw: number, scale: number?)
	local b = base()
	local k = scale or 1
	local a = math.clamp(jaw, 0, 1) * math.rad(90)
	local turn = { CFrame.Angles(a, 0, 0), CFrame.Angles(-a, 0, 0) } -- front jaw up and back, back jaw up and forward
	for _, part in model:GetChildren() do
		if part:IsA("BasePart") then
			local p = b[part.Name]
			if p then
				local cf = (if p.jaw then turn[p.jaw] else CFrame.identity) * p.cf
				part.CFrame = at * (if k ~= 1 then cf.Rotation + cf.Position * k else cf)
				local size = part:GetAttribute("BaseSize")
				if typeof(size) == "Vector3" then
					part.Size = size * k
				end
			elseif part.Name == "Glow" then
				part.CFrame = at * CFrame.new(0, 0.03, 0) * CFrame.Angles(0, 0, math.rad(90))
			end
		end
	end
end

function BearTrap.arm(model: Model, on: boolean)
	local glow = model:FindFirstChild("Glow")
	if glow and glow:IsA("BasePart") then
		glow.Transparency = if on then 0.72 else 1
	end
end

return BearTrap

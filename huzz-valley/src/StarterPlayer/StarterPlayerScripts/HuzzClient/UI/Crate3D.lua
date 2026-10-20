--[[
	The owner's own 3D knife crate in a ViewportFrame (owner, Oct 20: "make these crates for the opening of the normal
	knifes ... and make the opening animations look appropriate"; his crate shop mockup the same night draws each
	crate big on its card). His model as he built it (ReplicatedStorage > HuzzCrates, Shared/CrateModels), never
	redrawn: UI/Screens/CrateOpen plays the opening with it (Shop > CRATES shows his own picture of the cards since
	Oct 20, 07:23: "Just put the ui picture i sent you").

	  Crate3D.new(parent, crate, view, props?) -> handle or nil (nil until his model is there: draw CrateArt instead)
	      view "Open" = the opening (lower in the frame, room above for the knife). It starts as he built it (the
	      Storm Vault and the Beast Chest stand open in his model, as on his mockup; the Dojo Chest is shut).
	  handle.Viewport
	  handle.knife(item)            his little knife for that Config/CoinShop item (from the same set) for the reveal
	  handle.pose(t, calm, color)   the opening at time t (Shared/CrateMotion: build-up, the top cracks and light in
	                                 `color` spills out, it swings open, the knife rises slowly with one turn and
	                                 hovers facing you, one glint runs along its blade, a few motes drift up, the camera
	                                 eases in a touch). Premium = restraint (owner, 07:51: "feels too ai"): no rings,
	                                 rays or discs; light (his glow parts, the light colour) and timing instead.
	  handle.knifeScreen()          where the knife is in the frame now: its middle up from the frame's middle and its
	                                 length (both 0..1 of the frame's height) and its lean (radians); the opening screen
	                                 puts a dark knife's soft light behind its blade there
	  Crate3D.RevealHook            nil, or fn(knife: Model, item): called once his knife is placed for the reveal.
	                                 A hook for the knife's own effect (the knife VFX work: Rare and up); this file
	                                 adds none itself
	  handle.destroy()

	How it opens: Shared/CrateMotion.split picks his lid (his .glb's own lid group: the Storm Vault's lid, the Beast
	Chest's jaw with its teeth and horns; else everything over his body's top: the Dojo Chest's roof) and it swings on
	a hinge along the back of the body's top. A crate he built open is first shut by its Built angle (Config/Crates). His crates are built square to the world with their front to -Z (all three),
	so the crate's own frame is the world's, moved to its middle. His "glow_" parts carry a SurfaceAppearance: its
	Color is tinted to the rarity colour as it opens (pcall: nothing breaks if Roblox refuses). A ViewportFrame has no
	lights, so the coloured glow round it is the opening screen's own 2D light.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local CrateModels = require(Shared.CrateModels)
local CrateMotion = require(Shared.CrateMotion)
local CoinShop = require(Shared.Config.CoinShop)

local Crate3D = {}
Crate3D.RevealHook = nil :: ((Model, any) -> ())? -- (see the header: the knife's own effect at the reveal)

local function folder(): Instance?
	return ReplicatedStorage:FindFirstChild(CrateModels.Folder)
end

-- Is his model there for this crate?
function Crate3D.available(crate: any): boolean
	local m = CrateModels.crate(folder(), crate)
	return m ~= nil and m:IsA("Model")
end

-- the box round a model's parts (world-aligned: his crates and knives are built square to the world)
local function box(m: Instance): (Vector3, Vector3)
	local lo, hi = Vector3.new(math.huge, math.huge, math.huge), Vector3.new(-math.huge, -math.huge, -math.huge)
	for _, d in m:GetDescendants() do
		if d:IsA("BasePart") then
			local p, h = d.CFrame.Position, d.Size / 2
			lo = Vector3.new(math.min(lo.X, p.X - h.X), math.min(lo.Y, p.Y - h.Y), math.min(lo.Z, p.Z - h.Z))
			hi = Vector3.new(math.max(hi.X, p.X + h.X), math.max(hi.Y, p.Y + h.Y), math.max(hi.Z, p.Z + h.Z))
		end
	end
	if lo.X > hi.X then return Vector3.zero, Vector3.one end
	return (lo + hi) / 2, hi - lo
end

local function strip(copy: Instance)
	for _, d in copy:GetDescendants() do
		if d:IsA("LuaSourceContainer") or d:IsA("Sound") or d:IsA("ParticleEmitter") then d:Destroy()
		elseif d:IsA("BasePart") then d.Anchored = true; d.CanCollide = false; d.CanQuery = false; d.CanTouch = false end
	end
end

function Crate3D.new(parent: Instance, crate: any, view: string, props: { [string]: any }?)
	local source, set = CrateModels.crate(folder(), crate)
	if not (source and source:IsA("Model")) then return nil end
	local vp = Instance.new("ViewportFrame")
	vp.Name = "Crate3D"
	vp.Size = UDim2.fromScale(1, 1)
	vp.BackgroundTransparency = 1
	vp.Ambient, vp.LightColor, vp.LightDirection = Color3.fromRGB(150, 150, 170), Color3.fromRGB(255, 250, 240), Vector3.new(-0.45, -1, 0.7)
	vp:SetAttribute("RuntimeOnly", true) -- (built at run time from his model; never saved in StarterGui)
	for k, v in props or {} do (vp :: any)[k] = v end
	local model = source:Clone()
	strip(model)
	local centre, size = box(model)
	local h = size.Y
	-- each part's place in the crate's frame (its middle), and which swing open
	local parts, offsets, rows = {}, {}, {}
	local glows = {}
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			local off = CFrame.new(-centre) * d.CFrame
			table.insert(parts, d)
			table.insert(offsets, off)
			table.insert(rows, { name = d.Name, y = off.Position.Y, z = off.Position.Z, sy = d.Size.Y, sz = d.Size.Z, group = CrateModels.groupOf(d, model) })
			if string.find(string.lower(d.Name), "glow", 1, true) then
				local sa = d:FindFirstChildOfClass("SurfaceAppearance")
				local ok, base = pcall(function() return (sa :: any).Color end)
				table.insert(glows, { part = d, sa = sa, base = if ok and typeof(base) == "Color3" then base else Color3.new(1, 1, 1), color = d.Color })
			end
		end
	end
	local opens, hy, hz = CrateMotion.split(rows, crate.Model.Body)
	local swings = {}
	for _, i in opens do swings[i] = true end
	local hinge = CFrame.new(0, hy, hz)
	local built = math.rad(crate.Model.Built or 0) -- (how far his model's lid already stands open: Config/Crates)
	model.Parent = vp

	local cam = Instance.new("Camera")
	cam.FieldOfView = 30
	cam.Parent = vp
	vp.CurrentCamera = cam
	local reach = math.max(size.X, size.Y, size.Z)
	-- the camera: in front (-Z), a little above; the "Open" view keeps the crate low with room over it for the knife
	local function aim(grow: number)
		local down = math.rad(14)
		local look = Vector3.new(0, h * 0.95, 0)
		local dist = (reach * 1.02) / math.tan(math.rad(15)) / grow
		cam.CFrame = CFrame.lookAt(look + Vector3.new(0, math.sin(down) * dist, -math.cos(down) * dist), look)
	end
	aim(1)

	local handle = { Viewport = vp }
	local zoom = 1 -- (the camera's push-in times the build-up's grow, as last posed)
	local baseAmbient = vp.Ambient
	-- the motes (small soft beads in the rarity colour) and the one glint along the blade: plain parts, hidden until
	-- the pose shows them (no shapes: Neon reads as light in a ViewportFrame)
	local function bead(name: string): Part
		local b = Instance.new("Part")
		b.Name, b.Anchored, b.CanCollide, b.CanQuery, b.CanTouch = name, true, false, false, false
		b.Material, b.Shape, b.CastShadow, b.Transparency = Enum.Material.Neon, Enum.PartType.Ball, false, 1
		b.Size = Vector3.one * 0.1
		b.Parent = vp
		return b
	end
	local motes: { Part } = {}
	for i = 1, CrateMotion.Motes do motes[i] = bead("Mote" .. i) end
	local glint = bead("Glint")
	glint.Shape, glint.Color = Enum.PartType.Block, Color3.new(1, 1, 1)
	-- the light inside: a thin glowing layer just under his top, seen through the gap while it is cracked, fading out as
	-- it swings open (CrateMotion.spill; a ViewportFrame has no lights of its own: Neon is how light shows)
	local spill = bead("Spill")
	spill.Shape = Enum.PartType.Block
	-- angle: how far the top is open from shut (his model as built = `built`)
	local function place(root: CFrame, angle: number)
		local swing = hinge * CFrame.Angles(angle - built, 0, 0) * hinge:Inverse()
		for i, p in parts do
			p.CFrame = if swings[i] then root * swing * offsets[i] else root * offsets[i]
		end
	end
	local rest = CFrame.new(0, h / 2, 0) -- (his crate's middle; its bottom sits at y = 0)
	place(rest, built) -- (as he built it: the shop's cards)

	-- his little knife from the same set, made show size (about three quarters of the crate's height)
	local knife: Model? = nil
	local kParts, kOffsets, kSizes, kSeen = {}, {}, {}, {}
	local kBase, kLen, kDeep = 1, 1, 0.1
	function handle.knife(item: any)
		if knife then knife:Destroy(); knife = nil end
		kParts, kOffsets, kSizes, kSeen = {}, {}, {}, {}
		local src = CrateModels.knife(set, typeof(item) == "table" and item or CoinShop.get(item))
		if not (src and src:IsA("Model")) then return false end
		local k = src:Clone() :: Model
		strip(k)
		local kc, ks = box(k)
		kBase = (h * 0.78) / math.max(ks.Y, 0.05)
		kLen, kDeep = ks.Y, ks.Z
		for _, d in k:GetDescendants() do
			if d:IsA("BasePart") then
				table.insert(kParts, d)
				table.insert(kOffsets, CFrame.new(-kc) * d.CFrame)
				table.insert(kSizes, d.Size)
				table.insert(kSeen, d.Transparency)
				d.Transparency = 1 -- (hidden until the opening's pose shows it)
			end
		end
		k.Parent = vp
		knife = k
		if Crate3D.RevealHook then
			local def = typeof(item) == "table" and item or CoinShop.get(item)
			task.spawn(pcall, Crate3D.RevealHook, k, def) -- (its own effect, if the knife VFX work hooks in; never breaks the opening)
		end
		return true
	end

	local tinted = -1
	local function tint(mix: number, color: Color3?)
		if not color or math.abs(mix - tinted) < 0.02 then return end
		tinted = mix
		for _, g in glows do
			-- his SurfaceAppearance's tint first; if Roblox refuses it (or there is none), the part's own colour
			local ok = g.sa ~= nil and pcall(function() (g.sa :: any).Color = g.base:Lerp(color, mix) end)
			if not ok then pcall(function() g.part.Color = g.color:Lerp(color, mix) end) end
		end
	end

	local kNow = { up = 0, scale = 0, tilt = 0 }
	function handle.pose(t: number, calm: boolean?, color: Color3?)
		local s = CrateMotion.shake(t, calm)
		local root = CFrame.new(0, s.lift * h, 0) * CFrame.Angles(s.tilt, 0, s.roll) * CFrame.new(0, h / 2, 0)
		place(root, CrateMotion.lid(t))
		zoom = s.grow * CrateMotion.push(t, calm)
		aim(zoom)
		local bright, mix = CrateMotion.glow(t)
		tint(mix, color)
		-- the light that spills out as it cracks: a touch of the rarity colour over everything (light, not a shape)
		vp.Ambient = if color then baseAmbient:Lerp(color, 0.18 * mix * bright) else baseAmbient
		spill.Transparency = if color then 1 - 0.8 * CrateMotion.spill(t) else 1 -- (gone 0.4 s after it swings open)
		if color then
			spill.Color = color:Lerp(Color3.new(1, 1, 1), 0.35)
			spill.Size = Vector3.new(size.X * 0.8, h * 0.02, size.Z * 0.7)
			spill.CFrame = root * CFrame.new(0, hy - h * 0.025, 0)
		end
		local shown = if color then CrateMotion.motes(t, calm) else {}
		for i, q in shown do
			local b = motes[i]
			b.Size = Vector3.one * (q.size * h)
			b.Color = (color :: Color3):Lerp(Color3.new(1, 1, 1), 0.3)
			b.CFrame = CFrame.new(q.x * size.X, q.y * h, q.z * size.Z)
			b.Transparency = 1 - q.alpha
		end
		for i = #shown + 1, #motes do motes[i].Transparency = 1 end
		glint.Transparency = 1
		if knife then
			local kp = CrateMotion.knife(t, calm)
			local scale = kBase * kp.scale
			local at = CFrame.new(0, h * (0.35 + 0.95 * kp.up), -size.Z * 0.05) * CFrame.Angles(0, kp.spin, 0) * CFrame.Angles(0, 0, kp.tilt)
			for i, p in kParts do
				local o = kOffsets[i]
				p.Size = kSizes[i] * scale
				p.CFrame = at * (CFrame.new(o.Position * scale) * o.Rotation)
				p.Transparency = if kp.seen then kSeen[i] else 1
			end
			kNow = { up = kp.up, scale = kp.scale, tilt = kp.tilt * math.cos(kp.spin) } -- (its lean as seen: none side-on)
			-- one glint: a thin streak of light sliding up the face of the blade (towards you) from the handle to the tip
			local along, ga = CrateMotion.glint(t, calm)
			if along and kp.seen then
				local len = kLen * scale
				glint.Size = Vector3.new(len * 0.02, len * 0.14, len * 0.01)
				glint.CFrame = at * CFrame.new(0, (along - 0.5) * len * 0.9, -(kDeep * scale / 2 + len * 0.01))
				glint.Transparency = 1 - 0.85 * ga
			end
		end
	end

	function handle.knifeScreen(): (number, number, number)
		-- (aim(): half the frame's height = 1.02 reach / zoom at the crate's middle; the knife's middle is 0.35 h + 0.95
		-- h * up over the bottom, the camera aims at 0.95 h)
		local half = reach * 1.02 / zoom
		local y = (h * (0.35 + 0.95 * kNow.up) - h * 0.95) / half * 0.5
		return y, (h * 0.78 * kNow.scale) / half * 0.5, kNow.tilt
	end

	function handle.destroy()
		vp:Destroy()
	end

	vp.Parent = parent
	return handle
end

return Crate3D

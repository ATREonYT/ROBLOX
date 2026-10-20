--[[
	The owner's own 3D knife crate in a ViewportFrame (owner, Oct 20: "make these crates for the opening of the normal
	knifes ... and make the opening animations look appropriate"; his crate shop mockup the same night draws each
	crate big on its card). His model as he built it (ReplicatedStorage > HuzzCrates, Shared/CrateModels), never
	redrawn or recoloured: UI/Screens/CrateOpen plays the opening with it (Shop > CRATES shows his own picture of the
	cards since Oct 20, 07:23: "Just put the ui picture i sent you").

	  Crate3D.new(parent, crate, view, props?) -> handle or nil (nil until his model is there: draw CrateArt instead)
	      view "Open" = the opening: the ViewportFrame fills `parent` (the whole screen), a fixed shot with the crate
	      low and room over it for the knife (Shared/CrateMotion.camera). It starts as he built it (the Storm Vault
	      and the Beast Chest stand open in his model, as on his mockup; the Dojo Chest is shut).
	      view "Card" = his crate as he built it, filling the frame, turned a little as on his mockup: the stand-in
	      for his crate pictures when they can't be drawn (UI/CrateArt.hisPicture; owner, Oct 20 14:07, his
	      CRATES tab showed cardboard boxes).
	  handle.Viewport               the crate's ViewportFrame
	  handle.knife(item)            his little knife for that Config/CoinShop item (from the same set) for the reveal
	  handle.pose(t, calm, color)   the opening at time t (Shared/CrateMotion): three heavy hops, the latch pops and a
	                                 thin line of light in `color` (the rarity colour) shows in the gap, the lid is
	                                 flung open with a bounce, the knife comes out big in front of the crate with a
	                                 three quarter turn and stops sharp; the crate falls into shadow behind it
	  Crate3D.RevealHook            nil, or fn(knife: Model, item): called once his knife is placed for the reveal.
	                                 A hook for the knife's own effect (the knife VFX work: Rare and up); this file
	                                 adds none itself
	  handle.destroy()

	Owner, Oct 20 15:13: "remove so much glow from the crates, and then make it feel premium". So, in both views:
	his glow parts keep their colours and textures, but their own glow (the SurfaceAppearance EmissiveStrength he
	set, 1.5 on the crates) is turned down to GlowKeep of it on our copy (his model in ReplicatedStorage is never
	touched; pcall: nothing breaks if Roblox refuses); nothing is tinted, no motes, glint, haze or light wash. The one
	light is the thin layer inside the lid (Spill) while it cracks and swings open. His knives' aura_ring and
	aura_shard parts are hidden in the opening (owner, 07:51: "they have the circle around the knife when it opens,
	remove it").
	The knife has its own ViewportFrame (KnifeView, over the crate's) so it can stay brightly lit while the crate falls
	into shadow (a ViewportFrame has one light for everything in it). KnifeView sits in a frame (KnifeClip) cut at the
	crate's front top edge on the screen until the whole knife is out, so it comes out of the crate, not in front of
	it. Its light rim (Rim parts: a copy of each part a hair bigger, flat light colour, just behind it) outlines the
	blade so even a black blade reads on the dark backdrop; a light edge, never a glow round it. A soft contact
	shadow (Shadow frames) sits under the crate on the screen.
	How it opens: Shared/CrateMotion.split picks his lid (his .glb's own lid group: the Storm Vault's lid, the Beast
	Chest's jaw with its teeth and horns; else everything over his body's top: the Dojo Chest's roof) and it swings on
	a hinge along the back of the body's top. A crate he built open is first shut by its Built angle (Config/Crates).
	His crates are built square to the world with their front to -Z (all three), so the crate's own frame is the
	world's, moved to its middle.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local CrateModels = require(Shared.CrateModels)
local CrateMotion = require(Shared.CrateMotion)
local CoinShop = require(Shared.Config.CoinShop)

local Crate3D = {}
Crate3D.RevealHook = nil :: ((Model, any) -> ())? -- (see the header: the knife's own effect at the reveal)
Crate3D.GlowKeep = 0.3 -- how much of his crates' own glow (EmissiveStrength) shows in our views (Oct 20 15:13)

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

-- his glow, turned down on our copy (his colours and textures stay; only how much it shines on its own)
local function calmGlow(copy: Instance)
	for _, d in copy:GetDescendants() do
		if d:IsA("SurfaceAppearance") then
			pcall(function()
				local s = (d :: any).EmissiveStrength
				if typeof(s) == "number" and s > 0 then (d :: any).EmissiveStrength = s * Crate3D.GlowKeep end
			end)
		end
	end
end

local function baseName(n: string): string
	return (string.gsub(string.gsub(n, "_Node$", ""), "_%d+$", ""))
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
	calmGlow(model)
	local centre, size = box(model)
	local h = size.Y
	-- each part's place in the crate's frame (its middle), and which swing open
	local parts, offsets, rows = {}, {}, {}
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			local off = CFrame.new(-centre) * d.CFrame
			table.insert(parts, d)
			table.insert(offsets, off)
			table.insert(rows, { name = d.Name, y = off.Position.Y, z = off.Position.Z, sy = d.Size.Y, sz = d.Size.Z, group = CrateModels.groupOf(d, model) })
		end
	end
	local opens, hy, hz = CrateMotion.split(rows, crate.Model.Body)
	local swings = {}
	for _, i in opens do swings[i] = true end
	local front = math.huge -- (the front of his body: where the knife comes out over)
	for _, r in rows do
		if baseName(r.name) == crate.Model.Body then front = math.min(front, r.z - r.sz / 2) end
	end
	if front == math.huge then front = -size.Z / 2 end
	local hinge = CFrame.new(0, hy, hz)
	local built = math.rad(crate.Model.Built or 0) -- (how far his model's lid already stands open: Config/Crates)
	model.Parent = vp

	local cam = Instance.new("Camera")
	cam.FieldOfView = CrateMotion.Camera.Fov
	cam.Parent = vp
	vp.CurrentCamera = cam
	local reach = math.max(size.X, size.Y, size.Z)
	local lookY, eyeY, eyeZ = CrateMotion.camera(h, 1)
	-- the camera: "Open" = CrateMotion's fixed shot (its bottom middle at 0); "Card" = the whole crate, centred
	local function aim(push: number)
		if view == "Card" then -- (the whole crate, centred, a three-quarter view like his pictures)
			local d = (reach * 0.62) / math.tan(math.rad(15))
			local look = Vector3.new(0, h * 0.5, 0)
			cam.FieldOfView = 30
			cam.CFrame = CFrame.lookAt(look + CFrame.Angles(0, math.rad(-22), 0) * Vector3.new(0, math.sin(math.rad(16)) * d, -math.cos(math.rad(16)) * d), look)
			return
		end
		lookY, eyeY, eyeZ = CrateMotion.camera(h, push)
		cam.CFrame = CFrame.lookAt(Vector3.new(0, eyeY, eyeZ), Vector3.new(0, lookY, 0))
	end
	aim(1)

	local handle = { Viewport = vp }
	local baseAmbient, baseLight = vp.Ambient, vp.LightColor
	-- the one light from inside: a thin layer just under his top, seen through the gap while the latch is popped and
	-- as it swings, then gone (CrateMotion.spill; a ViewportFrame has no lights of its own: Neon is how light shows)
	local spill = Instance.new("Part")
	spill.Name, spill.Anchored, spill.CanCollide, spill.CanQuery, spill.CanTouch = "Spill", true, false, false, false
	spill.Material, spill.CastShadow, spill.Transparency = Enum.Material.Neon, false, 1
	spill.Size = Vector3.new(size.X * 0.8, h * 0.02, size.Z * 0.7)
	spill.Parent = vp
	-- angle: how far the top is open from shut (his model as built = `built`)
	local function place(root: CFrame, angle: number)
		local swing = hinge * CFrame.Angles(angle - built, 0, 0) * hinge:Inverse()
		for i, p in parts do
			p.CFrame = if swings[i] then root * swing * offsets[i] else root * offsets[i]
		end
	end
	local rest = CFrame.new(0, h / 2, 0) -- (his crate's middle; its bottom sits at y = 0)
	place(rest, built) -- (as he built it: the shop's cards)

	-- the opening only: the knife's own view (clipped at the crate's front top edge until it is out), and a soft
	-- contact shadow under the crate
	local z = vp.ZIndex
	local clip, kvp, kcam, shadows = nil :: Frame?, nil :: ViewportFrame?, nil :: Camera?, {} :: { Frame }
	if view == "Open" then
		for i, k in { 1, 0.78, 0.56 } do
			local s = Instance.new("Frame")
			s.Name = "Shadow" .. i
			s.AnchorPoint = Vector2.new(0.5, 0.5)
			s.BackgroundColor3 = Color3.new(0, 0, 0)
			s.BackgroundTransparency = 1
			s.BorderSizePixel = 0
			s.ZIndex = math.max(z - 1, 1)
			s:SetAttribute("Width", k)
			s:SetAttribute("RuntimeOnly", true)
			local corner = Instance.new("UICorner")
			corner.CornerRadius = UDim.new(1, 0)
			corner.Parent = s
			s.Parent = parent
			shadows[i] = s
		end
		local c = Instance.new("Frame")
		c.Name = "KnifeClip"
		c.Size = UDim2.fromScale(1, 1)
		c.BackgroundTransparency = 1
		c.ClipsDescendants = true
		c.ZIndex = z + 1
		c:SetAttribute("RuntimeOnly", true)
		c.Parent = parent
		local k = Instance.new("ViewportFrame")
		k.Name = "KnifeView"
		k.Size = UDim2.fromScale(1, 1)
		k.BackgroundTransparency = 1
		k.ZIndex = z + 1
		-- (its own light: bright and white from the front, so the knife stays crisp while the crate goes dark)
		k.Ambient, k.LightColor, k.LightDirection = Color3.fromRGB(190, 190, 200), Color3.fromRGB(255, 255, 250), Vector3.new(0.35, -0.55, 0.75)
		k.Parent = c
		local kc = Instance.new("Camera")
		kc.FieldOfView = CrateMotion.Camera.Fov
		kc.Parent = k
		k.CurrentCamera = kc
		clip, kvp, kcam = c, k, kc
	end

	-- his little knife from the same set, made show size (CrateMotion.Knife.Len crate heights long at full size)
	local knife: Model? = nil
	local kParts, kOffsets, kSizes, kSeen = {}, {}, {}, {}
	local rims: { { part: BasePart, i: number } } = {}
	local kBase, kLen, kW, kDeep = 1, 1, 0.1, 0.1
	local kColor: Color3? = nil -- (his knife's main colour: a dark one gets a wider rim)
	local cleared = false -- (the whole knife has come out over the crate's front edge: no more clipping)
	function handle.knife(item: any)
		if knife then knife:Destroy(); knife = nil end
		for _, r in rims do r.part:Destroy() end
		kParts, kOffsets, kSizes, kSeen, rims = {}, {}, {}, {}, {}
		cleared = false
		local def = typeof(item) == "table" and item or CoinShop.get(item)
		local src = CrateModels.knife(set, def)
		if not (src and src:IsA("Model")) then return false end
		local k = src:Clone() :: Model
		strip(k)
		local kc, ks = box(k)
		kBase = (h * CrateMotion.Knife.Len) / math.max(ks.Y, 0.05)
		kLen, kW, kDeep = ks.Y, math.max(ks.X, 0.01), ks.Z
		kColor = def and def.Colors and def.Colors[1]
		local rimColor = Color3.new(1, 1, 1)
		for _, d in k:GetDescendants() do
			if d:IsA("BasePart") then
				table.insert(kParts, d)
				table.insert(kOffsets, CFrame.new(-kc) * d.CFrame)
				table.insert(kSizes, d.Size)
				-- (his aura ring and shards: hidden, owner 07:51 "remove it")
				table.insert(kSeen, if CrateMotion.isAura(d.Name) then 1 else d.Transparency)
				d.Transparency = 1 -- (hidden until the opening's pose shows it)
				if kvp and kSeen[#kSeen] < 1 then -- (only what shows; never the aura parts)
					if math.max(d.Size.X, d.Size.Y) >= ks.Y * 0.06 then -- (the big shapes make the outline)
						local r = d:Clone()
						for _, ch in r:GetChildren() do ch:Destroy() end
						r.Name = "Rim"
						r.Material = Enum.Material.Neon
						r.Color = rimColor
						r.CastShadow = false
						pcall(function() (r :: any).TextureID = "" end)
						r.Transparency = 1
						r.Parent = kvp
						table.insert(rims, { part = r, i = #kParts })
					end
				end
			end
		end
		k.Parent = kvp or vp
		knife = k
		if Crate3D.RevealHook then
			task.spawn(pcall, Crate3D.RevealHook, k, def) -- (its own effect, if the knife VFX work hooks in; never breaks the opening)
		end
		return true
	end

	local function aspect(): number
		local ok, a = pcall(function() return vp.AbsoluteSize end) -- (not drawn yet, or the offline harness: 16:9)
		return if ok and typeof(a) == "Vector2" and a.X > 0 and a.Y > 0 then a.X / a.Y else 16 / 9
	end

	function handle.pose(t: number, calm: boolean?, color: Color3?)
		local s = CrateMotion.shake(t, calm)
		local root = CFrame.new(0, s.lift * h, 0) * CFrame.Angles(s.tilt, 0, s.roll) * CFrame.new(0, h / 2, 0)
		place(root, CrateMotion.lid(t))
		aim(CrateMotion.push(t, calm))
		if kcam then kcam.CFrame = cam.CFrame end
		-- the crate falls into shadow as the knife comes out (only the knife stays bright)
		local dm = CrateMotion.Dim * CrateMotion.dim(t, calm)
		vp.Ambient = baseAmbient:Lerp(Color3.new(0, 0, 0), dm)
		vp.LightColor = baseLight:Lerp(Color3.new(0, 0, 0), dm)
		-- the one light from inside, in the rarity colour
		local sp = if color then CrateMotion.spill(t) else 0
		spill.Transparency = 1 - 0.9 * sp
		if color then
			spill.Color = color:Lerp(Color3.new(1, 1, 1), 0.5)
			spill.CFrame = root * CFrame.new(0, hy - h * 0.025, 0)
		end
		local ar = aspect()
		-- the contact shadow on the floor under it (smaller and fainter while it is up in a hop)
		if #shadows > 0 then
			local sx, sy = CrateMotion.project(lookY, eyeY, eyeZ, 0, 0, 0, ar)
			local ex = CrateMotion.project(lookY, eyeY, eyeZ, size.X * 0.5, 0, 0, ar)
			local w = math.abs(ex - sx) * 2 * (1 - 1.5 * math.max(s.lift, 0))
			for _, f in shadows do
				local k = f:GetAttribute("Width") :: number
				f.Position = UDim2.fromScale(sx, sy)
				f.Size = UDim2.fromScale(w * k * 1.05, w * k * 0.16 * ar)
				f.BackgroundTransparency = 1 - 0.22 * (1 - 3 * math.max(s.lift, 0))
			end
		end
		if knife then
			local kp = CrateMotion.knife(t, calm)
			local ky, kz = CrateMotion.knifeSpot(kp)
			local scale = kBase * kp.scale
			local at = CFrame.new(0, h * ky, -size.Z * kz) * CFrame.Angles(0, 0, kp.tilt) * CFrame.Angles(0, kp.spin, 0)
			for i, p in kParts do
				local o = kOffsets[i]
				p.Size = kSizes[i] * scale
				p.CFrame = at * (CFrame.new(o.Position * scale) * o.Rotation)
				p.Transparency = if kp.seen then kSeen[i] else 1
			end
			-- the rim: each big part a hair bigger (the same width all round: more along the knife's narrow width),
			-- just behind it, in a light colour lifted from the rarity colour
			local rim = if kp.seen then CrateMotion.rim(t, calm) else 0
			local wPx = CrateMotion.rimWidth(kColor) * kLen
			local grow = Vector3.new(1 + 2 * wPx / kW, 1 + 2 * wPx / kLen, 1)
			local back = cam.CFrame.LookVector * (kDeep * scale * 0.6 + h * 0.01)
			local rimCol = if color then color:Lerp(Color3.new(1, 1, 1), CrateMotion.RimWhite) else Color3.new(1, 1, 1)
			for _, r in rims do
				local o = kOffsets[r.i]
				r.part.Size = kSizes[r.i] * scale * grow
				r.part.CFrame = CFrame.new(back) * at * (CFrame.new(o.Position * scale * grow) * o.Rotation)
				r.part.Color = rimCol
				r.part.Transparency = 1 - rim
			end
			-- cut at the crate's front top edge on the screen until the whole knife has come out over it
			if clip and kvp then
				local edge = root * Vector3.new(0, hy, front)
				local _, rimY = CrateMotion.project(lookY, eyeY, eyeZ, edge.X, edge.Y, edge.Z, ar)
				local low = 0
				for _, e in { -0.5, 0.5 } do
					local p = at * Vector3.new(0, e * kLen * scale, 0)
					local _, y = CrateMotion.project(lookY, eyeY, eyeZ, p.X, p.Y, p.Z, ar)
					low = math.max(low, y)
				end
				if kp.seen and low < rimY - 0.004 then cleared = true end
				local frac = if cleared or calm then 1 else math.clamp(rimY, 0.02, 1)
				clip.Size = UDim2.fromScale(1, frac)
				kvp.Size = UDim2.fromScale(1, 1 / frac)
			end
		end
	end

	function handle.destroy()
		vp:Destroy()
		if clip then clip:Destroy() end
		for _, f in shadows do f:Destroy() end
	end

	vp.Parent = parent
	return handle
end

return Crate3D

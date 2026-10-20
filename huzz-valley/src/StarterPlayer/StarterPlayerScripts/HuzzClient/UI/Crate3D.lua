--[[
	The owner's own 3D knife crate in a ViewportFrame (owner, Oct 20: "make these crates for the opening of the normal
	knifes ... and make the opening animations look appropriate"; his crate shop mockup the same night draws each
	crate big on its card). His model as he built it (ReplicatedStorage > HuzzCrates, Shared/CrateModels), never
	redrawn: Shop > CRATES shows it on each card, UI/Screens/CrateOpen plays the opening with it.

	  Crate3D.new(parent, crate, view, props?) -> handle or nil (nil until his model is there: draw CrateArt instead)
	      view "Card" = the shop card (a little from above, so an open crate shows its inside), "Open" = the opening
	      (lower in the frame, room above for the knife). It starts as he built it (the Storm Vault and the Beast
	      Chest stand open in his model, as on his mockup; the Dojo Chest is shut).
	  handle.Viewport
	  handle.knife(item)            his little knife for that Config/CoinShop item (from the same set) for the reveal
	  handle.pose(t, calm, color)   the opening at time t (Shared/CrateMotion: shut, build-up, the top swings open, the
	                                 light inside takes `color`, the knife rises spinning and stops facing you)
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
		local down = if view == "Card" then math.rad(24) else math.rad(14)
		local look = if view == "Card" then Vector3.new(0, h * 0.48, 0) else Vector3.new(0, h * 0.95, 0)
		local dist = (reach * (if view == "Card" then 0.54 else 1.02)) / math.tan(math.rad(15)) / grow
		cam.CFrame = CFrame.lookAt(look + Vector3.new(0, math.sin(down) * dist, -math.cos(down) * dist), look)
	end
	aim(1)

	local handle = { Viewport = vp }
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
	local kBase = 1
	function handle.knife(item: any)
		if knife then knife:Destroy(); knife = nil end
		kParts, kOffsets, kSizes, kSeen = {}, {}, {}, {}
		local src = CrateModels.knife(set, typeof(item) == "table" and item or CoinShop.get(item))
		if not (src and src:IsA("Model")) then return false end
		local k = src:Clone() :: Model
		strip(k)
		local kc, ks = box(k)
		kBase = (h * 0.78) / math.max(ks.Y, 0.05)
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
		return true
	end

	local tinted = -1
	local function tint(mix: number, color: Color3?)
		if not color or math.abs(mix - tinted) < 0.02 then return end
		tinted = mix
		for _, g in glows do
			pcall(function()
				if g.sa then (g.sa :: any).Color = g.base:Lerp(color, mix) else g.part.Color = g.color:Lerp(color, mix) end
			end)
		end
	end

	function handle.pose(t: number, calm: boolean?, color: Color3?)
		local s = CrateMotion.shake(t, calm)
		local root = CFrame.new(0, s.lift * h, 0) * CFrame.Angles(s.tilt, 0, s.roll) * CFrame.new(0, h / 2, 0)
		place(root, CrateMotion.lid(t))
		aim(s.grow)
		local _, mix = CrateMotion.glow(t)
		tint(mix, color)
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
		end
	end

	function handle.destroy()
		vp:Destroy()
	end

	vp.Parent = parent
	return handle
end

return Crate3D

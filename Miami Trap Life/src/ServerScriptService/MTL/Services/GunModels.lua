--!strict
-- Gun models for GunService (Piece 5). Real model if Alex put one in ReplicatedStorage.MTL_Assets.Guns.<Model>,
-- otherwise a clean placeholder built from parts (dark metal, readable silhouette per gun type).
--
-- A real model needs: a BasePart named "Handle" (the grip), an Attachment named "Muzzle" anywhere inside
-- (barrel tip, its -Z/LookVector pointing out of the barrel), optionally an Attachment "Grip" in the Handle
-- (where the palm sits). The barrel should point along the Handle's LookVector (-Z). Every part is welded
-- to the Handle here and made massless / non-colliding / non-queryable, so they never block bullets or physics.
--
-- Sounds: Fire, Tail, Empty, ReloadStart, ReloadEnd, Equip are created in the Handle from Config/Guns.Sounds
-- (or the gun's own Sounds table). The client plays them locally.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Guns = require(ReplicatedStorage.MTL.Config.Guns)

local GunModels = {}

local METAL = Color3.fromRGB(32, 33, 37)
local METAL_LIGHT = Color3.fromRGB(58, 60, 66)
local WOOD = Color3.fromRGB(105, 66, 38)

local function part(model: Model, name: string, size: Vector3, cf: CFrame, color: Color3?, material: Enum.Material?): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cf
	p.Color = color or METAL
	p.Material = material or Enum.Material.Metal
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = model
	return p
end

-- All placeholder shapes are laid out with the barrel along -Z and the grip (Handle) at the origin.
local SHAPES: { [string]: (Model) -> (Vector3) } = {
	Pistol = function(m)
		part(m, "Slide", Vector3.new(0.24, 0.26, 1.05), CFrame.new(0, 0.32, -0.32), METAL_LIGHT)
		part(m, "Frame", Vector3.new(0.22, 0.14, 0.8), CFrame.new(0, 0.14, -0.25))
		part(m, "Guard", Vector3.new(0.06, 0.16, 0.3), CFrame.new(0, 0.0, -0.22))
		return Vector3.new(0, 0.32, -0.88)
	end,
	Revolver = function(m)
		part(m, "Barrel", Vector3.new(0.18, 0.2, 1.1), CFrame.new(0, 0.34, -0.6), METAL_LIGHT)
		local cyl = part(m, "Cylinder", Vector3.new(0.36, 0.34, 0.34), CFrame.new(0, 0.26, -0.12) * CFrame.Angles(0, math.rad(90), 0))
		cyl.Shape = Enum.PartType.Cylinder
		part(m, "Frame", Vector3.new(0.2, 0.18, 0.5), CFrame.new(0, 0.16, -0.05))
		return Vector3.new(0, 0.34, -1.16)
	end,
	Uzi = function(m)
		part(m, "Body", Vector3.new(0.28, 0.34, 1.0), CFrame.new(0, 0.3, -0.25), METAL_LIGHT)
		part(m, "Barrel", Vector3.new(0.12, 0.12, 0.35), CFrame.new(0, 0.32, -0.92))
		part(m, "Mag", Vector3.new(0.16, 0.6, 0.2), CFrame.new(0, -0.35, 0.02))
		return Vector3.new(0, 0.32, -1.1)
	end,
	Shotgun = function(m)
		part(m, "Receiver", Vector3.new(0.26, 0.32, 0.9), CFrame.new(0, 0.26, -0.3), METAL_LIGHT)
		part(m, "Barrel", Vector3.new(0.14, 0.14, 2.1), CFrame.new(0, 0.36, -1.75))
		part(m, "Pump", Vector3.new(0.22, 0.2, 0.7), CFrame.new(0, 0.18, -1.45), WOOD, Enum.Material.Wood)
		part(m, "Stock", Vector3.new(0.22, 0.38, 1.1), CFrame.new(0, 0.12, 0.75) * CFrame.Angles(math.rad(-8), 0, 0), WOOD, Enum.Material.Wood)
		return Vector3.new(0, 0.36, -2.8)
	end,
	AK = function(m)
		part(m, "Receiver", Vector3.new(0.26, 0.34, 1.3), CFrame.new(0, 0.28, -0.35), METAL_LIGHT)
		part(m, "Barrel", Vector3.new(0.1, 0.1, 1.3), CFrame.new(0, 0.34, -1.6))
		part(m, "Handguard", Vector3.new(0.22, 0.22, 0.7), CFrame.new(0, 0.26, -1.25), WOOD, Enum.Material.Wood)
		part(m, "Mag", Vector3.new(0.16, 0.7, 0.26), CFrame.new(0, -0.2, -0.55) * CFrame.Angles(math.rad(18), 0, 0))
		part(m, "Stock", Vector3.new(0.2, 0.36, 1.0), CFrame.new(0, 0.16, 0.8) * CFrame.Angles(math.rad(-6), 0, 0), WOOD, Enum.Material.Wood)
		return Vector3.new(0, 0.34, -2.28)
	end,
}

-- Moving parts (attribute GunRole = Mag / Slide / Pump / Cylinder) hang on a Motor6D "Role_<role>" in the
-- Handle instead of a weld, so the client's GunPose can slide the mag out, rack the slide, work the pump.
local function weldAll(model: Model, handle: BasePart)
	for _, d in model:GetDescendants() do
		local role = d:GetAttribute("GunRole")
		if d:IsA("BasePart") and d ~= handle and type(role) == "string" and role ~= "ShellTemplate" and not handle:FindFirstChild("Role_" .. role) then
			for _, w in d:GetChildren() do
				if w:IsA("WeldConstraint") or w:IsA("Weld") then
					w:Destroy()
				end
			end
			local m = Instance.new("Motor6D")
			m.Name = "Role_" .. role
			m.Part0 = handle
			m.Part1 = d
			m.C0 = handle.CFrame:ToObjectSpace(d.CFrame)
			m.Parent = handle
		end
	end
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = false
			d.CanCollide = false
			d.CanQuery = false
			d.CanTouch = false
			d.Massless = true
			d.CastShadow = d == handle or d.Size.Magnitude > 0.6
			if d ~= handle then
				local hasWeld = false
				for _, w in d:GetChildren() do
					if (w:IsA("WeldConstraint") or w:IsA("Weld")) then
						hasWeld = true
					end
				end
				local r = d:GetAttribute("GunRole")
				if type(r) == "string" and handle:FindFirstChild("Role_" .. r) then
					hasWeld = true -- held by its Role_ motor
				end
				if not hasWeld then
					local w = Instance.new("WeldConstraint")
					w.Part0 = handle
					w.Part1 = d
					w.Parent = d
				end
			end
		end
	end
end

local function addSounds(handle: BasePart, gunId: string)
	local def = Guns.Defs[gunId]
	local own = (def and def.Sounds) or {}
	local slots: { [string]: string } = {}
	for slot, default in Guns.Sounds do
		slots[slot] = own[slot] or default
	end
	for slot, id in own do
		slots[slot] = id -- per-gun extras (e.g. the shotgun's Pump)
	end
	for slot, id in slots do
		if slot == "Hit" or slot == "Kill" or slot == "Hurt" then
			continue -- UI sounds, played by the client from Config/Guns directly
		end
		if id ~= "" and not handle:FindFirstChild(slot) then
			local s = Instance.new("Sound")
			s.Name = slot
			s.SoundId = id
			s.Volume = if slot == "Fire" then 0.8 else 0.5
			s.RollOffMode = Enum.RollOffMode.InverseTapered
			s.RollOffMinDistance = if slot == "Tail" then 60 else 12
			s.RollOffMaxDistance = if slot == "Tail" then 900 else 350
			s.Parent = handle
		end
	end
end

local function placeholder(gunId: string, shape: string): Model
	local m = Instance.new("Model")
	m.Name = gunId
	local handle = part(m, "Handle", Vector3.new(0.2, 0.55, 0.3), CFrame.new(0, -0.05, 0.05))
	local build = SHAPES[shape] or SHAPES.Pistol
	local muzzlePos = build(m)
	local muzzle = Instance.new("Attachment")
	muzzle.Name = "Muzzle"
	muzzle.CFrame = handle.CFrame:ToObjectSpace(CFrame.new(muzzlePos))
	muzzle.Parent = handle
	local grip = Instance.new("Attachment")
	grip.Name = "Grip"
	grip.CFrame = handle.CFrame:ToObjectSpace(CFrame.new(0, 0.05, 0.05)) -- palm a little above the grip centre
	grip.Parent = handle
	m.PrimaryPart = handle
	return m
end

-- Returns a fresh, unparented model with Handle (PrimaryPart), Muzzle + Grip attachments and sounds.
function GunModels.build(gunId: string): Model
	local def = Guns.Defs[gunId]
	local shape = (def and def.Model) or "Pistol"
	local assets = ReplicatedStorage:FindFirstChild("MTL_Assets")
	local folder = assets and assets:FindFirstChild("Guns")
	local source = folder and folder:FindFirstChild(shape)
	local model: Model
	if source and source:IsA("Model") and source:FindFirstChild("Handle", true) then
		model = source:Clone()
		model.Name = gunId
	else
		model = placeholder(gunId, shape)
	end
	local handle = model:FindFirstChild("Handle", true) :: BasePart
	model.PrimaryPart = handle
	if not model:FindFirstChild("Muzzle", true) then
		local a = Instance.new("Attachment")
		a.Name = "Muzzle"
		a.Position = Vector3.new(0, 0.3, -1)
		a.Parent = handle
	end
	if not handle:FindFirstChild("Grip") then
		local a = Instance.new("Attachment")
		a.Name = "Grip"
		a.Parent = handle
	end
	weldAll(model, handle)
	addSounds(handle, gunId)
	model:SetAttribute("MTL_GunId", gunId)
	return model
end

return GunModels

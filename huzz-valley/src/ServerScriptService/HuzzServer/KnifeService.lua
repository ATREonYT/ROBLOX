--[[
	Catchers hold a knife in their right hand (as in the reference). It's a model welded to the
	hand, not a Tool, so there's nothing to equip or drop and no backpack. HuzzClient/Gameplay/Stab
	plays the stab and lights the blade's trail.

	The knife is built from parts here. To use your own, put a Model named "HuzzKnife" in
	ServerStorage with a part named "Handle": the hand holds the Handle's centre, and the
	Handle's top (+Y) is the way the blade points. Add Attachments "TrailBase" and "TrailTip"
	along the blade for the slash trail.
]]
local ServerStorage = game:GetService("ServerStorage")

local KnifeService = {}
local NAME = "HuzzKnife"

local function part(class, props)
	local p = Instance.new(class)
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.Massless = false, false, false, false, true
	p.CastShadow = false
	p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	for k, v in props do
		p[k] = v
	end
	return p
end

local function weld(a, b)
	local w = Instance.new("WeldConstraint")
	w.Part0, w.Part1 = a, b
	w.Parent = b
end

-- A dagger: dark grip with a pommel, a steel guard, a slim blade with a pointed tip.
local function build()
	local model = Instance.new("Model")
	local dark, steel = Color3.fromRGB(32, 30, 38), Color3.fromRGB(205, 212, 224)
	local handle = part("Part", { Name = "Handle", Size = Vector3.new(0.22, 0.75, 0.26), Color = dark, Material = Enum.Material.SmoothPlastic, Parent = model })
	local function add(class, props, offset)
		local p = part(class, props)
		p.CFrame = handle.CFrame * offset
		p.Parent = model
		weld(handle, p)
		return p
	end
	add("Part", { Name = "Pommel", Size = Vector3.new(0.26, 0.12, 0.3), Color = steel, Material = Enum.Material.Metal }, CFrame.new(0, -0.42, 0))
	add("Part", { Name = "Guard", Size = Vector3.new(0.24, 0.1, 0.62), Color = steel, Material = Enum.Material.Metal }, CFrame.new(0, 0.42, 0))
	local blade = add("Part", { Name = "Blade", Size = Vector3.new(0.07, 1.05, 0.3), Color = steel, Material = Enum.Material.Metal, Reflectance = 0.15 }, CFrame.new(0, 0.995, 0.02))
	-- WedgePart: its tall edge is at +Z, so the point sits over the blade's back (a dagger tip).
	add("WedgePart", { Name = "Tip", Size = Vector3.new(0.07, 0.42, 0.3), Color = steel, Material = Enum.Material.Metal, Reflectance = 0.15 }, CFrame.new(0, 1.73, 0.02))
	local base = Instance.new("Attachment")
	base.Name = "TrailBase"
	base.Position = Vector3.new(0, -0.4, 0)
	base.Parent = blade
	local tip = Instance.new("Attachment")
	tip.Name = "TrailTip"
	tip.Position = Vector3.new(0, 0.85, 0)
	tip.Parent = blade
	model.PrimaryPart = handle
	return model
end

local function template()
	local custom = ServerStorage:FindFirstChild(NAME)
	if custom and custom:IsA("Model") and custom:FindFirstChild("Handle", true) then
		return custom:Clone()
	end
	return build()
end

function KnifeService.has(character)
	return character ~= nil and character:FindFirstChild(NAME) ~= nil
end

-- Into the right hand, blade pointing down and a little forward (it comes up level in the stab).
-- skin (optional): a Config/CoinShop Knife item: its blade, guard and pommel take its colours, the blade glows a
-- little, and the slash streak matches.
function KnifeService.give(character, skin)
	if not character or KnifeService.has(character) then
		return
	end
	local hand = character:FindFirstChild("RightHand") or character:FindFirstChild("Right Arm")
	if not hand then
		return
	end
	local model = template()
	model.Name = NAME
	if skin and not ServerStorage:FindFirstChild(NAME) then
		local a, b = skin.Colors[1], skin.Colors[#skin.Colors]
		for _, d in model:GetDescendants() do
			if d:IsA("BasePart") then
				if d.Name == "Blade" or d.Name == "Tip" then
					d.Color, d.Material, d.Reflectance = a, Enum.Material.Neon, 0
					d.Transparency = 0.05
				elseif d.Name == "Guard" or d.Name == "Pommel" then
					d.Color = b
				end
			end
		end
		model:SetAttribute("Skin", skin.Key)
	end
	local handle = model:FindFirstChild("Handle", true)
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored, d.CanCollide, d.CanQuery, d.CanTouch, d.Massless = false, false, false, false, true
		end
	end
	local grip = hand:FindFirstChild("RightGripAttachment")
	local at = if grip then grip.Position else Vector3.new(0, -hand.Size.Y / 2 + 0.1, 0)
	local motor = Instance.new("Motor6D") -- a Motor6D (not a Weld) so it moves with the hand on every client at once
	motor.Name = "KnifeGrip"
	motor.Part0 = hand
	motor.Part1 = handle
	-- Handle +Y (the blade) -> the hand's down-and-forward: 150 degrees round the hand's X axis.
	motor.C0 = CFrame.new(at) * CFrame.Angles(math.rad(-150), 0, 0)
	motor.C1 = CFrame.identity
	motor.Parent = handle
	-- The slash: a short white-to-pink streak behind the blade, switched on by each client during a stab.
	local base, tip = model:FindFirstChild("TrailBase", true), model:FindFirstChild("TrailTip", true)
	if base and tip then
		local trail = Instance.new("Trail")
		trail.Name = "SlashTrail"
		trail.Attachment0, trail.Attachment1 = base, tip
		trail.Lifetime = 0.16
		trail.MinLength = 0
		trail.LightEmission = 0.6
		trail.Color = if skin then ColorSequence.new(Color3.new(1, 1, 1), skin.Colors[#skin.Colors]) else ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(255, 120, 200))
		trail.Transparency = NumberSequence.new(0.25, 1)
		trail.Enabled = false
		trail.Parent = handle
	end
	model.Parent = character
end

function KnifeService.take(character)
	local knife = character and character:FindFirstChild(NAME)
	if knife then
		knife:Destroy()
	end
end

return KnifeService

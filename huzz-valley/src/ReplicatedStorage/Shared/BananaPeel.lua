--[[
	The Banana Peel's look (Config/Powers.BananaPeel; new Oct 20, owner: "add a few more abilities, but make them well
	made"). Built like the Bear Trap (Shared/BearTrap) so the two read as a pair: a bright yellow peel with three
	flaps lying open on the floor, a brown stem, a thin glowing yellow ring the size of its slip radius (dim while it
	lands, bright once it can trip a catcher) and a floating 🍌 sign over it, so it is easy to see and walk round.
	Plain parts only (no picture to upload).

	Pure maths plus Instance.new, so the server (HuzzServer/PowerService: the peel on the floor), every screen
	(Gameplay/PowerEffects: the peel tossed back) and the offline film (motion3d/power_scene.luau) build the same.
	  BananaPeel.build()                    -> Model (anchored, no collisions): Ring, Peel, Flap1..3, Stem, Sign
	  BananaPeel.pose(model, at, scale?)    -> `at` = its centre on the floor (any CFrame, so it can tumble in the
	                                           air); scale (default 1) sizes it
	  BananaPeel.arm(model, on)             -> the ring dim while it lands, bright once it can trip someone
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Powers = require(ReplicatedStorage:WaitForChild("Shared").Config.Powers)

local BananaPeel = {}

local YELLOW = Color3.fromRGB(255, 214, 64)
local INNER = Color3.fromRGB(255, 242, 196) -- the pale inside of a peel
local BROWN = Color3.fromRGB(110, 72, 34)
local SIGN_UP, SIGN_SIZE = 1.3, 1.8

local function part(model: Model, name: string, shape: Enum.PartType?, size: Vector3, color: Color3): Part
	local p = Instance.new("Part")
	p.Name = name
	if shape then p.Shape = shape end
	p.Size = size
	p.Color = color
	p.Material = Enum.Material.SmoothPlastic
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = true, false, false, false, false
	p:SetAttribute("BaseSize", size)
	p.Parent = model
	return p
end

function BananaPeel.build(): Model
	local model = Instance.new("Model")
	model.Name = "BananaPeel"
	local r = Powers.BananaPeel.Radius
	local ring = part(model, "Ring", Enum.PartType.Cylinder, Vector3.new(0.06, r * 2, r * 2), YELLOW)
	ring.Material = Enum.Material.Neon
	ring.Transparency = 0.75
	part(model, "Peel", Enum.PartType.Cylinder, Vector3.new(0.3, 1.1, 1.1), INNER)
	for i = 1, 3 do
		part(model, "Flap" .. i, nil, Vector3.new(0.5, 0.14, 1.5), YELLOW)
	end
	part(model, "Stem", nil, Vector3.new(0.22, 0.22, 0.5), BROWN)
	local holder = part(model, "Sign", nil, Vector3.new(0.2, 0.2, 0.2), YELLOW)
	holder.Transparency = 1
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.new(SIGN_SIZE, 0, SIGN_SIZE, 0)
	gui.LightInfluence = 0
	gui.MaxDistance = 160
	gui.Parent = holder
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = "🍌"
	label.TextScaled = true
	label.Parent = gui
	return model
end

-- Where each piece sits, from the peel's centre on the floor.
local FLAT = CFrame.Angles(0, 0, math.rad(90)) -- (a cylinder's round faces are on its X axis)
local function offset(name: string): CFrame?
	if name == "Ring" then return CFrame.new(0, 0.04, 0) * FLAT end
	if name == "Peel" then return CFrame.new(0, 0.2, 0) * FLAT end
	if name == "Stem" then return CFrame.new(0, 0.42, 0) * CFrame.Angles(math.rad(-35), 0, 0) * CFrame.new(0, 0, -0.1) end
	if name == "Sign" then return CFrame.new(0, SIGN_UP, 0) end
	local i = tonumber(string.match(name, "^Flap(%d)$"))
	if i then
		-- three flaps opening out from the middle, a little turned up at the tips
		return CFrame.Angles(0, math.rad(30 + (i - 1) * 120), 0) * CFrame.new(0, 0.16, -0.8) * CFrame.Angles(math.rad(14), 0, 0)
	end
	return nil
end

function BananaPeel.pose(model: Model, at: CFrame, scale: number?)
	local k = scale or 1
	for _, p in model:GetChildren() do
		if p:IsA("BasePart") then
			local off = offset(p.Name)
			if off then
				p.CFrame = at * CFrame.new(off.Position * k) * (off - off.Position)
				local size = p:GetAttribute("BaseSize")
				if typeof(size) == "Vector3" then p.Size = size * k end
				if p.Name == "Sign" then
					local gui = p:FindFirstChildOfClass("BillboardGui")
					if gui then gui.Size = UDim2.new(SIGN_SIZE * k, 0, SIGN_SIZE * k, 0) end
				end
			end
		end
	end
end

function BananaPeel.arm(model: Model, on: boolean)
	local ring = model:FindFirstChild("Ring")
	if ring and ring:IsA("BasePart") then
		ring.Transparency = if on then 0.35 else 0.75
	end
end

return BananaPeel

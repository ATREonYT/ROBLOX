--[[
	The Bear Trap's look (Config/Powers.BearTrap): the old Love Trap's big pink heart disc, kept as it was (owner,
	Oct 20: "just keep the same effects, change the name"). A flat dark-pink disc the size of the catch radius with
	a neon pink disc on it and a floating 💘 sign over its middle, exactly the pieces the Love Trap had in
	HuzzServer/PowerService before the renames (ed870f6). The metal toothed trap that replaced it for one batch is in
	the history (d6db14f) if it is ever wanted again.

	Pure maths plus Instance.new, so the server (HuzzServer/PowerService: the trap on the floor), every screen
	(Gameplay/PowerEffects: the disc flying in its arc) and the offline preview (motion3d/power_scene.luau) all build
	the same thing.
	  BearTrap.build(accent)             -> Model (parts named, anchored, no collisions): Base, Glow, Sign
	  BearTrap.pose(model, at, _, scale?) -> places it: `at` = the disc's centre on the floor (any CFrame, so it can
	                                        spin in the air); scale (default 1) sizes it (small in the hand). The
	                                        third argument (the old metal jaws) is ignored.
	  BearTrap.arm(model, on)            -> the neon disc dim while the trap lands, full once it can catch
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Powers = require(ReplicatedStorage:WaitForChild("Shared").Config.Powers)

local BearTrap = {}

local DARK = Color3.fromRGB(120, 20, 70) -- the Love Trap's base disc
local SIGN_UP, SIGN_SIZE = 1.2, 2.2 -- the 💘 sign: studs over the floor, studs across

local function radius(): number
	return Powers.BearTrap.Radius
end

function BearTrap.build(accent: Color3?): Model
	local model = Instance.new("Model")
	model.Name = "BearTrap"
	local r = radius()
	local function disc(name, size, color, transparency)
		local p = Instance.new("Part")
		p.Name = name
		p.Shape = Enum.PartType.Cylinder
		p.Size = size
		p.Color = color
		p.Transparency = transparency
		p.Material = Enum.Material.SmoothPlastic
		p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = true, false, false, false, false
		p:SetAttribute("BaseSize", size)
		p.Parent = model
		return p
	end
	disc("Base", Vector3.new(0.2, r * 2, r * 2), DARK, 0.1)
	local glow = disc("Glow", Vector3.new(0.24, r * 2 - 0.8, r * 2 - 0.8), accent or Color3.fromRGB(255, 110, 190), 0.25)
	glow.Material = Enum.Material.Neon
	local holder = Instance.new("Part")
	holder.Name = "Sign"
	holder.Transparency = 1
	holder.Size = Vector3.new(0.2, 0.2, 0.2)
	holder.Anchored, holder.CanCollide, holder.CanQuery, holder.CanTouch, holder.CastShadow = true, false, false, false, false
	holder.Parent = model
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.new(SIGN_SIZE, 0, SIGN_SIZE, 0)
	gui.LightInfluence = 0
	gui.MaxDistance = 160
	gui.Parent = holder
	local heart = Instance.new("TextLabel")
	heart.Size = UDim2.fromScale(1, 1)
	heart.BackgroundTransparency = 1
	heart.Text = "💘"
	heart.TextScaled = true
	heart.Parent = gui
	return model
end

-- Heights over the floor of each piece's centre (the Love Trap's offsets).
local UPS = { Base = 0.1, Glow = 0.12 }

function BearTrap.pose(model: Model, at: CFrame, _jaw: number?, scale: number?)
	local k = scale or 1
	local flat = CFrame.Angles(0, 0, math.rad(90)) -- (a cylinder's round faces are on its X axis)
	for _, part in model:GetChildren() do
		if part:IsA("BasePart") then
			local up = UPS[part.Name]
			if up then
				part.CFrame = at * CFrame.new(0, up * k, 0) * flat
				local size = part:GetAttribute("BaseSize")
				if typeof(size) == "Vector3" then
					part.Size = size * k
				end
			elseif part.Name == "Sign" then
				part.CFrame = at * CFrame.new(0, SIGN_UP * k, 0)
				local gui = part:FindFirstChildOfClass("BillboardGui")
				if gui then
					gui.Size = UDim2.new(SIGN_SIZE * k, 0, SIGN_SIZE * k, 0)
				end
			end
		end
	end
end

function BearTrap.arm(model: Model, on: boolean)
	local glow = model:FindFirstChild("Glow")
	if glow and glow:IsA("BasePart") then
		glow.Transparency = if on then 0.25 else 0.6
	end
end

return BearTrap

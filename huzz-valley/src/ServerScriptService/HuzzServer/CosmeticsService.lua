-- Puts bought cosmetics on the player's character. Everyone sees them (they are server-made).
--   SunsetTrail  a warm Trail from the waist down.
--   BlossomAura  soft pink sparkles around the body (Roblox's built-in sparkle texture until a petal texture
--                is uploaded; set PETAL_TEXTURE then).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DataService = require(script.Parent.DataService)
local CoinShop = require(ReplicatedStorage.Shared.Config.CoinShop)

local CosmeticsService = {}

local PETAL_TEXTURE = "rbxasset://textures/particles/sparkles_main.dds"

local function sunsetTrail(root: BasePart)
	local a0 = Instance.new("Attachment")
	a0.Name = "SunsetTrailTop"
	a0.Position = Vector3.new(0, 0.6, 0.4)
	a0.Parent = root
	local a1 = Instance.new("Attachment")
	a1.Name = "SunsetTrailBottom"
	a1.Position = Vector3.new(0, -0.9, 0.4)
	a1.Parent = root
	local t = Instance.new("Trail")
	t.Name = "SunsetTrail"
	t.Attachment0, t.Attachment1 = a0, a1
	t.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 214, 102)),
		ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 140, 66)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(232, 72, 120)),
	})
	t.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 1) })
	t.Lifetime = 0.45
	t.MinLength = 0.1
	t.LightEmission = 0.3
	t.FaceCamera = true
	t.Parent = root
end

local function blossomAura(root: BasePart)
	local e = Instance.new("ParticleEmitter")
	e.Name = "BlossomAura"
	e.Texture = PETAL_TEXTURE
	e.Color = ColorSequence.new(Color3.fromRGB(255, 182, 213), Color3.fromRGB(255, 120, 170))
	e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.35), NumberSequenceKeypoint.new(1, 0) })
	e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 1) })
	e.Lifetime = NumberRange.new(1.2, 2)
	e.Rate = 8 -- calm on purpose: kid-friendly, no flashing
	e.Speed = NumberRange.new(0.6, 1.2)
	e.SpreadAngle = Vector2.new(180, 180)
	e.Acceleration = Vector3.new(0, -0.6, 0)
	e.RotSpeed = NumberRange.new(-40, 40)
	e.Shape = Enum.ParticleEmitterShape.Box
	e.Parent = root
end

-- A coin-shop trail (Config/CoinShop): the same shape as Sunset Trail, in the item's colours.
local function coinTrail(root: BasePart, item: CoinShop.Item)
	local a0 = Instance.new("Attachment")
	a0.Name = "WornTrailTop"
	a0.Position = Vector3.new(0, 0.6, 0.4)
	a0.Parent = root
	local a1 = Instance.new("Attachment")
	a1.Name = "WornTrailBottom"
	a1.Position = Vector3.new(0, -0.9, 0.4)
	a1.Parent = root
	local t = Instance.new("Trail")
	t.Name = "WornTrail"
	t:SetAttribute("Item", item.Key)
	t.Attachment0, t.Attachment1 = a0, a1
	t.Color = CoinShop.sequence(item)
	t.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.15), NumberSequenceKeypoint.new(1, 1) })
	t.Lifetime = if item.Rainbow then 0.6 else 0.45
	t.MinLength = 0.1
	t.LightEmission = 0.35
	t.FaceCamera = true
	t.Parent = root
end

local function clearTrails(root: BasePart)
	for _, name in { "SunsetTrail", "SunsetTrailTop", "SunsetTrailBottom", "WornTrail", "WornTrailTop", "WornTrailBottom" } do
		local x = root:FindFirstChild(name)
		while x do
			x:Destroy()
			x = root:FindFirstChild(name)
		end
	end
end

local function apply(player: Player)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local profile = DataService.get(player)
	if not root or not profile then return end
	local data = profile.Data
	-- one trail at a time: the worn one (a coin item or Sunset Trail); owners of Sunset Trail wear it by default
	local wear = data.Wear or {}
	local trailKey = wear.Trail
	if trailKey == nil and data.Cosmetics.SunsetTrail then trailKey = "SunsetTrail" end
	if trailKey and not data.Cosmetics[trailKey] then trailKey = nil end
	local current = root:FindFirstChild("WornTrail") and root.WornTrail:GetAttribute("Item") or (root:FindFirstChild("SunsetTrail") and "SunsetTrail")
	if current ~= trailKey then
		clearTrails(root)
		if trailKey == "SunsetTrail" then
			sunsetTrail(root)
		elseif trailKey and CoinShop.get(trailKey) then
			coinTrail(root, CoinShop.get(trailKey) :: CoinShop.Item)
		end
	end
	-- Blossom Aura: always on while owned
	local has = root:FindFirstChild("BlossomAura")
	if data.Cosmetics.BlossomAura and not has then
		blossomAura(root)
	elseif not data.Cosmetics.BlossomAura and has then
		has:Destroy()
	end
end

function CosmeticsService.refresh(player: Player)
	apply(player)
end

function CosmeticsService.start()
	local function onJoin(player: Player)
		player.CharacterAdded:Connect(function(character)
			character:WaitForChild("HumanoidRootPart", 10)
			apply(player)
		end)
		if DataService.waitFor(player, 15) then apply(player) end
	end
	Players.PlayerAdded:Connect(onJoin)
	for _, p in Players:GetPlayers() do task.spawn(onJoin, p) end
end

return CosmeticsService

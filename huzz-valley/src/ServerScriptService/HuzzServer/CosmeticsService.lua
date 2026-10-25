--[[
	Puts worn cosmetics on the player's character. Everyone sees them. One item per slot (Config/CoinShop.worn):
	  Trail   made here: a coloured streak (our Streak picture) with a white core; the rarer ones (Sunset Trail and
	          the girls' rewards) also drop little twinkles while you run.
	  Aura    the character's HuzzAura attribute; every client draws it (HuzzClient/Gameplay/Auras with AuraFX, as
	          the girls' auras), so the orbit lights and sparks move smoothly without loading the server.
	  Pose    the character's HuzzPose attribute: Crown Pose plays when you win (RoundService sets HuzzPoseAt;
	          HuzzClient/Gameplay/CrownPose draws the pose and the crown).
	  Outfit  Midnight Outfit, made here: your clothes tinted midnight blue and a starry night cape. (Real outfit
	          clothing needs asset IDs from the owner; this is our own look until then.) The cape is welded to the
	          torso the character has now; when Roblox swaps in the avatar's own torso the cape is made again on it
	          (the old weld dies with the old torso; tests/Cape.spec). Not the owner's Oct 20 "floating black block":
	          that block is thick and has no purple lining, and nobody can have the outfit yet (Id 0).
	Pictures come from Shared/FxTexture (Roblox's stand-ins until the owner uploads ours).
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DataService = require(script.Parent.DataService)
local CoinShop = require(ReplicatedStorage.Shared.Config.CoinShop)
local FxTexture = require(ReplicatedStorage.Shared.FxTexture)

local CosmeticsService = {}

local rgb = Color3.fromRGB
local WHITE = Color3.new(1, 1, 1)

-- Trails that aren't coin-shop items: { colours, twinkles? }.
local ROBUX_TRAILS = {
	SunsetTrail = { Colors = { rgb(255, 214, 102), rgb(255, 140, 66), rgb(232, 72, 120) }, Twinkle = true },
}

local function seq(colors: { Color3 }, white: boolean): ColorSequence
	local keys = {}
	local n = #colors
	if white then table.insert(keys, ColorSequenceKeypoint.new(0, colors[1]:Lerp(WHITE, 0.75))) end
	for i, c in colors do
		local t = if white then 0.2 + 0.8 * (i - 1) / math.max(n - 1, 1) else (i - 1) / math.max(n - 1, 1)
		table.insert(keys, ColorSequenceKeypoint.new(t, c))
	end
	if keys[#keys].Time < 1 then table.insert(keys, ColorSequenceKeypoint.new(1, colors[n])) end
	return ColorSequence.new(keys)
end

-- On the middle of the body, top to bottom the same either side of the waist (owner, Oct 23 16:52: "make trails be
-- on the center of body"; they used to sit behind the back and low).
-- The trail starts on the body's centre line, just behind it (the root's +Z is its back), and its newest bit is
-- see-through (FADE_IN of its life), so it never draws over the runner (owner, Oct 25: "fix the trail being on the
-- person": it used to start inside the body and sweep across it on every turn).
local BACK = 0.6
local FADE_IN = 0.14
local function attachment(root: BasePart, name: string, y: number): Attachment
	local a = Instance.new("Attachment")
	a.Name = name
	a.Position = Vector3.new(0, y, BACK)
	a.Parent = root
	return a
end

local TRAIL_PARTS = { "WornTrail", "WornTrailCore", "WornTrailTop", "WornTrailBottom", "WornTrailCoreTop", "WornTrailCoreBottom", "WornTrailTwinkles" }

local function clearTrail(root: BasePart)
	for _, name in TRAIL_PARTS do
		for _, x in root:GetChildren() do
			if x.Name == name then x:Destroy() end
		end
	end
	-- (older saves' Sunset Trail parts)
	for _, name in { "SunsetTrail", "SunsetTrailTop", "SunsetTrailBottom" } do
		local x = root:FindFirstChild(name)
		if x then x:Destroy() end
	end
end

-- A streak behind you: the coloured body (fading to nothing) with a short white core inside it, as anime swooshes.
local function trail(root: BasePart, key: string, colors: { Color3 }, rich: boolean, twinkle: boolean)
	local t = Instance.new("Trail")
	t.Name = "WornTrail"
	t:SetAttribute("Item", key)
	t.Attachment0, t.Attachment1 = attachment(root, "WornTrailTop", 0.8), attachment(root, "WornTrailBottom", -0.8)
	if FxTexture.ready("Streak") then -- (solid colour, as before, until our streak picture is uploaded)
		t.Texture = FxTexture.get("Streak")
		t.TextureMode = Enum.TextureMode.Stretch
	end
	t.Color = seq(colors, rich)
	t.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(FADE_IN, 0.1), NumberSequenceKeypoint.new(0.6, 0.4), NumberSequenceKeypoint.new(1, 1) })
	t.WidthScale = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(1, 0.25) })
	t.Lifetime = if rich then 0.55 else 0.45
	t.MinLength = 0.1
	t.LightEmission = 0.6
	t.LightInfluence = 0
	t.FaceCamera = true
	t.Parent = root
	if rich then
		local core = Instance.new("Trail")
		core.Name = "WornTrailCore"
		core.Attachment0, core.Attachment1 = attachment(root, "WornTrailCoreTop", 0.4), attachment(root, "WornTrailCoreBottom", -0.4)
		if FxTexture.ready("Streak") then
			core.Texture = FxTexture.get("Streak")
			core.TextureMode = Enum.TextureMode.Stretch
		end
		core.Color = ColorSequence.new(WHITE, colors[1]:Lerp(WHITE, 0.5))
		core.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(FADE_IN * 1.8, 0.15), NumberSequenceKeypoint.new(1, 1) })
		core.WidthScale = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(1, 0) })
		core.Lifetime = 0.25
		core.MinLength = 0.1
		core.LightEmission = 1
		core.LightInfluence = 0
		core.FaceCamera = true
		core.Parent = root
	end
	if twinkle then
		-- little stars left behind while you run (switched off when you stand still: start())
		local e = Instance.new("ParticleEmitter")
		e.Name = "WornTrailTwinkles"
		FxTexture.flipbook(e, "Twinkle", "Random")
		e.Color = seq(colors, true)
		e.LightEmission = 1
		e.LightInfluence = 0
		e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.15, 0.45, 0.1), NumberSequenceKeypoint.new(1, 0) })
		e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.7, 0.1), NumberSequenceKeypoint.new(1, 1) })
		e.Lifetime = NumberRange.new(0.5, 0.9)
		e.Rate = 10
		e.Speed = NumberRange.new(0.2, 0.8)
		e.SpreadAngle = Vector2.new(180, 180)
		e.Acceleration = Vector3.new(0, -2, 0)
		e.Rotation = NumberRange.new(0, 360)
		e.Shape = Enum.ParticleEmitterShape.Box
		e.Enabled = false
		e.Parent = root
	end
end

-- Midnight Outfit -------------------------------------------------------------------------------------------------
local NIGHT = rgb(64, 70, 128) -- the tint on your clothes (it multiplies them: light clothes turn midnight blue)
local CAPE = rgb(18, 20, 46)
local LINING = rgb(96, 64, 186)

local function outfitOn(character: Model)
	-- (clothes can arrive after the body: tinted whenever this runs, each piece once)
	for _, c in character:GetChildren() do
		if (c:IsA("Shirt") or c:IsA("Pants")) and c:GetAttribute("HuzzOwnColor") == nil then
			c:SetAttribute("HuzzOwnColor", c.Color3)
			c.Color3 = NIGHT
		end
	end
	local torso = (character:FindFirstChild("UpperTorso") or character:FindFirstChild("Torso")) :: BasePart?
	local old = character:FindFirstChild("MidnightCape")
	if old then
		-- (the cape is welded at spawn; when Roblox swaps in the avatar's own torso the weld dies with the old one and
		-- the cape would fall away. A cape not held by the current torso is made again on it. This was first blamed
		-- for the owner's Oct 20 "floating black block"; it wasn't that: docs/notes/economy.md.)
		local w = old:FindFirstChildOfClass("WeldConstraint")
		if w and torso and w.Part0 == torso and w.Part1 == old then return end
		old:Destroy()
	end
	if not torso then return end
	local cape = Instance.new("Part")
	cape.Name = "MidnightCape"
	cape.Size = Vector3.new(torso.Size.X * 0.95, torso.Size.Y * 1.75, 0.08)
	cape.Color = CAPE
	cape.Material = Enum.Material.SmoothPlastic
	cape.CanCollide, cape.CanQuery, cape.CanTouch, cape.Massless, cape.CastShadow = false, false, false, true, false
	cape.TopSurface, cape.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	local lining = cape:Clone()
	lining.Name = "Lining"
	lining.Size = cape.Size - Vector3.new(0.12, 0.12, 0.04)
	lining.Color = LINING
	lining.Material = Enum.Material.Neon
	lining.Transparency = 0.35
	-- hung from the shoulders, falling back a little
	local hang = CFrame.new(0, torso.Size.Y * 0.5 - cape.Size.Y * 0.5, torso.Size.Z * 0.5 + 0.12) * CFrame.Angles(math.rad(-8), 0, 0)
	cape.CFrame = torso.CFrame * hang
	lining.CFrame = cape.CFrame * CFrame.new(0, 0, -0.05)
	local w = Instance.new("WeldConstraint")
	w.Part0, w.Part1 = torso, cape
	w.Parent = cape
	local w2 = Instance.new("WeldConstraint")
	w2.Part0, w2.Part1 = cape, lining
	w2.Parent = lining
	lining.Parent = cape
	-- stars twinkling on the cape, and the odd crescent moon
	local stars = Instance.new("ParticleEmitter")
	stars.Name = "Stars"
	FxTexture.flipbook(stars, "Twinkle", "Random")
	stars.Color = ColorSequence.new(rgb(235, 235, 255), rgb(180, 170, 255))
	stars.LightEmission, stars.LightInfluence = 1, 0
	stars.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.3, 0.22, 0.06), NumberSequenceKeypoint.new(1, 0) })
	stars.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 0.2) })
	stars.Lifetime = NumberRange.new(1, 1.8)
	stars.Rate = 5
	stars.Speed = NumberRange.new(0)
	stars.Rotation = NumberRange.new(0, 360)
	stars.LockedToPart = true
	stars.ZOffset = 0.1
	stars.Shape = Enum.ParticleEmitterShape.Box
	stars.Parent = cape
	local moon = Instance.new("ParticleEmitter")
	moon.Name = "Moon"
	moon.Texture = FxTexture.get("Moon")
	moon.Color = ColorSequence.new(rgb(240, 236, 255))
	moon.LightEmission, moon.LightInfluence = 0.8, 0
	moon.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.2, 0.4), NumberSequenceKeypoint.new(0.8, 0.4), NumberSequenceKeypoint.new(1, 0) })
	moon.Lifetime = NumberRange.new(2.5, 3)
	moon.Rate = 0.35
	moon.Speed = NumberRange.new(0)
	moon.Rotation = NumberRange.new(-20, 20)
	moon.LockedToPart = true
	moon.ZOffset = 0.12
	moon.Shape = Enum.ParticleEmitterShape.Box
	moon.Parent = cape
	cape.Parent = character
end

local function outfitOff(character: Model)
	local cape = character:FindFirstChild("MidnightCape")
	if cape then cape:Destroy() end
	for _, c in character:GetChildren() do
		local own = (c:IsA("Shirt") or c:IsA("Pants")) and c:GetAttribute("HuzzOwnColor")
		if typeof(own) == "Color3" then
			(c :: Clothing).Color3 = own
			c:SetAttribute("HuzzOwnColor", nil)
		end
	end
end

-- Everything worn, onto the current character ---------------------------------------------------------------------
local function apply(player: Player)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local profile = DataService.get(player)
	if not character or not root or not profile then return end
	local data = profile.Data

	local trailKey = CoinShop.worn(data, "Trail")
	local current = root:FindFirstChild("WornTrail") and root.WornTrail:GetAttribute("Item")
	if current ~= trailKey then
		clearTrail(root)
		local item = trailKey and CoinShop.get(trailKey)
		local robux = trailKey and ROBUX_TRAILS[trailKey]
		if robux then
			trail(root, trailKey :: string, robux.Colors, true, robux.Twinkle == true)
		elseif item then
			local reward = item.Rarity ~= nil
			trail(root, item.Key, item.Colors, reward or item.Rainbow == true, reward)
		end
		local twinkles = root:FindFirstChild("WornTrailTwinkles") :: ParticleEmitter?
		if twinkles then twinkles.Enabled = root.AssemblyLinearVelocity.Magnitude > 3 end -- (already running)
	end

	character:SetAttribute("HuzzAura", CoinShop.worn(data, "Aura"))
	character:SetAttribute("HuzzPose", CoinShop.worn(data, "Pose"))
	if CoinShop.worn(data, "Outfit") == "MidnightOutfit" then outfitOn(character) else outfitOff(character) end
end

function CosmeticsService.refresh(player: Player)
	apply(player)
end

function CosmeticsService.start()
	local function onJoin(player: Player)
		player.CharacterAdded:Connect(function(character)
			local root = character:WaitForChild("HumanoidRootPart", 10)
			character:WaitForChild("UpperTorso", 2) -- (the cape hangs from it; R6 bodies have Torso)
			apply(player)
			-- avatar clothes load after the body: tint them when they arrive (Midnight Outfit); the avatar's own torso
			-- can arrive after it too (it replaces the first one): the cape moves onto it
			character.ChildAdded:Connect(function(c)
				if c:IsA("Shirt") or c:IsA("Pants") or (c:IsA("BasePart") and (c.Name == "UpperTorso" or c.Name == "Torso")) then
					task.defer(apply, player)
				end
			end)
			-- trail twinkles only while running
			local humanoid = character:FindFirstChildOfClass("Humanoid")
			if humanoid and root then
				humanoid.Running:Connect(function(speed)
					local e = root:FindFirstChild("WornTrailTwinkles") :: ParticleEmitter?
					if e then e.Enabled = speed > 3 end
				end)
			end
		end)
		if DataService.waitFor(player, 60) then apply(player) end
	end
	Players.PlayerAdded:Connect(onJoin)
	for _, p in Players:GetPlayers() do task.spawn(onJoin, p) end
end

return CosmeticsService

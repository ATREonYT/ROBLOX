-- The collection of girls: finds the owner's models, rolls the round's girl
-- by rarity, and makes clean, scaled copies to carry or put on display.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CollectionService = game:GetService("CollectionService")

local Config = require(ReplicatedStorage.Shared.Config.Round)
local Carry = require(ReplicatedStorage.Shared.Config.Carry)
local GirlNames = require(ReplicatedStorage.Shared.Config.GirlNames)
local GirlRoll = require(ReplicatedStorage.Shared.GirlRoll)
local Characters = require(ReplicatedStorage.Shared.Config.Characters)

local GirlService = {}
GirlService.catalog = {} -- { id, name, rarity, template }
local seen = {}
local countByRarity = {}

local rarityByName = {}
for _, r in Config.Rarities do
	rarityByName[r.Name] = r
end

function GirlService.rarity(name)
	return rarityByName[name] or { Name = name, Weight = 1, Color = Color3.new(1, 1, 1) }
end

local function addGirl(model, folderRarity)
	-- Each girl once, even if she's in the folder twice.
	if seen[model.Name] or not model:FindFirstChildWhichIsA("BasePart", true) then
		return
	end
	seen[model.Name] = true
	local rarity = model:GetAttribute("Rarity") or folderRarity or "Common"
	countByRarity[rarity] = (countByRarity[rarity] or 0) + 1
	-- id = the model's name, the key saved in the player's Characters (Index). The shown
	-- name comes from Config/GirlNames (the models are named after the avatars' owners).
	local name = model:GetAttribute("DisplayName") or GirlNames[model.Name]
	if not name or name == "" then
		name = `{rarity} Girl {countByRarity[rarity]}`
	end
	table.insert(GirlService.catalog, { id = model.Name, name = name, rarity = rarity, template = model })
end

-- Default R15 rigs in rarity colours, so the game runs before the real girls are in.
local function addPlaceholders()
	local list = { { "Mei", "Common" }, { "Hana", "Rare" }, { "Yuki", "Legendary" }, { "Sakura", "Secret" } }
	for _, entry in list do
		local ok, model = pcall(function()
			local desc = Instance.new("HumanoidDescription")
			local c = GirlService.rarity(entry[2]).Color
			desc.HeadColor = Color3.fromRGB(255, 220, 200)
			desc.LeftArmColor, desc.RightArmColor = desc.HeadColor, desc.HeadColor
			desc.TorsoColor, desc.LeftLegColor, desc.RightLegColor = c, c, c
			return Players:CreateHumanoidModelFromDescription(desc, Enum.HumanoidRigType.R15)
		end)
		if ok and model then
			model.Name = entry[1]
			addGirl(model, entry[2])
		end
	end
	warn(`[Huzz] No girls found in {Config.GirlFolders[1][2]}: using {#GirlService.catalog} placeholder rigs`)
end

function GirlService.init()
	for _, path in Config.GirlFolders do
		local ok, service = pcall(game.GetService, game, path[1])
		local folder = ok and service:FindFirstChild(path[2])
		if folder then
			for _, child in folder:GetChildren() do
				if child:IsA("Model") then
					addGirl(child, nil)
				elseif child:IsA("Folder") then
					for _, model in child:GetChildren() do
						if model:IsA("Model") then
							addGirl(model, child.Name)
						end
					end
				end
			end
		end
	end
	if #GirlService.catalog == 0 then
		addPlaceholders()
	end
	GirlService.publish()
	Characters.addGirls(ReplicatedStorage:FindFirstChild("HuzzGirls")) -- won girls can be equipped / favourited
	print(`[Huzz] {#GirlService.catalog} girls in the collection`)
end

--[[
	Picture copies for the girl roller: every girl as a still model in ReplicatedStorage.HuzzGirls,
	named by a short key (G1, G2... never the avatar owner's username), with no scripts, so each
	client can show her in a ViewportFrame. The roll's cells carry the key.
]]
function GirlService.publish()
	local folder = ReplicatedStorage:FindFirstChild("HuzzGirls")
	if folder then
		folder:ClearAllChildren()
	else
		folder = Instance.new("Folder")
		folder.Name = "HuzzGirls"
		folder.Parent = ReplicatedStorage
	end
	for i, girl in GirlService.catalog do
		girl.key = "G" .. i
		local ok, copy = pcall(function()
			return girl.template:Clone()
		end)
		if ok and copy then
			for _, d in copy:GetDescendants() do
				if d:IsA("LuaSourceContainer") then
					d:Destroy()
				elseif d:IsA("BasePart") then
					d.Anchored, d.CanCollide, d.CanQuery, d.CanTouch = true, false, false, false
				elseif d:IsA("Humanoid") then
					d.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
				end
			end
			copy.Name = girl.key
			copy:SetAttribute("Rarity", girl.rarity)
			copy:SetAttribute("Id", girl.id) -- her save key, for the Index (Config/Characters.addGirls)
			copy:SetAttribute("Name", girl.name)
			copy.Parent = folder
		end
	end
end

-- Weighted by rarity (only rarities that have girls), then even within it (Shared/GirlRoll).
local rng = Random.new()
local function rand()
	return rng:NextNumber()
end
function GirlService.roll()
	return GirlRoll.pick(GirlService.catalog, Config.Rarities, rand)
end

-- The roller strip shown to everyone: honest picks with the winner at `at`, plus the real odds.
function GirlService.strip(winner, length, at)
	return GirlRoll.strip(GirlService.catalog, Config.Rarities, winner, length, at, rand), GirlRoll.odds(GirlService.catalog, Config.Rarities)
end

local function nameTag(model, girl, root, offsetY)
	local gui = Instance.new("BillboardGui")
	gui.Name = "HuzzNameTag"
	gui.Size = UDim2.fromOffset(200, 44)
	gui.StudsOffsetWorldSpace = Vector3.new(0, offsetY, 0)
	gui.AlwaysOnTop = false
	gui.MaxDistance = 120
	gui.Adornee = root
	local function label(text, y, h, color, weight)
		local t = Instance.new("TextLabel")
		t.BackgroundTransparency = 1
		t.Size = UDim2.new(1, 0, 0, h)
		t.Position = UDim2.fromOffset(0, y)
		t.Text = text
		t.TextColor3 = color
		t.TextScaled = true
		t.FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json", weight)
		local stroke = Instance.new("UIStroke")
		stroke.Thickness = 1.5
		stroke.Color = Color3.fromRGB(20, 18, 40)
		stroke.Parent = t
		t.Parent = gui
	end
	label(girl.name, 0, 24, Color3.new(1, 1, 1), Enum.FontWeight.Heavy)
	local rarity = GirlService.rarity(girl.rarity)
	label(string.upper(rarity.Name), 24, 18, if rarity.Name == "Secret" then Color3.new(1, 1, 1) else rarity.Color, Enum.FontWeight.Bold)
	gui.Parent = model
end

--[[
	Rebuilds an R6 girl as R15 from her HumanoidDescription (same clothes, hair
	and body), so she gets elbows and knees for the animations. Done once per girl,
	the first time she's rolled; if Roblox can't build her, the original is kept.
]]
function GirlService.prepare(girl)
	if girl.prepared or Config.GirlRig ~= "R15" then
		return
	end
	girl.prepared = true
	local humanoid = girl.template:FindFirstChildOfClass("Humanoid")
	local desc = humanoid and humanoid:FindFirstChildOfClass("HumanoidDescription")
	if not desc or humanoid.RigType == Enum.HumanoidRigType.R15 then
		return
	end
	local ok, result = pcall(Players.CreateHumanoidModelFromDescription, Players, desc:Clone(), Enum.HumanoidRigType.R15)
	if ok and result then
		result.Name = girl.id
		girl.template = result
	else
		warn(`[Huzz] Couldn't rebuild {girl.name} as R15 ({result}); using her original model`)
	end
end

-- Avatars on Roblox's newer joints use AnimationConstraints (some doubled up).
-- The copy gets one plain Motor6D per joint instead, which every part of the game animates.
local function useMotors(model)
	local done = {}
	for _, d in model:GetDescendants() do
		if d.ClassName == "AnimationConstraint" then
			local a0, a1 = d.Attachment0, d.Attachment1
			local part0, part1 = a0 and a0.Parent, a1 and a1.Parent
			if part0 and part1 and part0:IsA("BasePart") and part1:IsA("BasePart") and not done[part1] then
				done[part1] = true
				local motor = Instance.new("Motor6D")
				motor.Name = d.Name
				motor.Part0, motor.Part1 = part0, part1
				motor.C0, motor.C1 = a0.CFrame, a1.CFrame
				motor.Parent = part1
			end
		end
	end
	for _, d in model:GetDescendants() do
		if d.ClassName == "AnimationConstraint" or d:IsA("BallSocketConstraint") or d:IsA("NoCollisionConstraint") then
			d:Destroy()
		end
	end
end

-- Her body's box (head, torso, arms and legs: no hats, hair, wings or other accessories) in her root's
-- frame. Sizes and the hold use this, so a big hat or wings can't shrink her or push her off-centre.
local function bodyBounds(model, root)
	local frame = root.CFrame
	local lo, hi
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") and d ~= root and d.Transparency < 1 and not d:FindFirstAncestorWhichIsA("Accoutrement") then
			local h = d.Size / 2
			for _, c in { Vector3.new(-1, -1, -1), Vector3.new(1, -1, -1), Vector3.new(-1, 1, -1), Vector3.new(1, 1, -1),
				Vector3.new(-1, -1, 1), Vector3.new(1, -1, 1), Vector3.new(-1, 1, 1), Vector3.new(1, 1, 1) } do
				local p = frame:PointToObjectSpace(d.CFrame:PointToWorldSpace(h * c))
				lo = if lo then lo:Min(p) else p
				hi = if hi then hi:Max(p) else p
			end
		end
	end
	if not lo then
		return model:GetBoundingBox()
	end
	return frame * CFrame.new((lo + hi) / 2), hi - lo
end
GirlService.bodyBounds = bodyBounds

--[[
	A copy of the girl ready to weld or display: scripts removed, scaled to
	Carry.GirlLength, every part joined to one root, no collisions, and any
	Humanoid switched off so it never fights the carrier's physics.
	Returns model, root, centre (bounding-box CFrame), size (extents).
	Parts stay anchored; the caller unanchors once she's welded.
]]
function GirlService.makeCopy(girl, parent)
	local model = girl.template:Clone()
	model:SetAttribute("Id", girl.id) -- (clients theme her effects by these: Shared/AuraLook)
	model:SetAttribute("Rarity", girl.rarity)
	useMotors(model)
	for _, d in model:GetDescendants() do
		if d:IsA("BaseScript") or d:IsA("ModuleScript") or d:IsA("BillboardGui") and d.Name == "HuzzNameTag" then
			d:Destroy()
		end
	end
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	local root = model:FindFirstChild("HumanoidRootPart") or model.PrimaryPart
	if not root then
		local biggest = 0
		for _, d in model:GetDescendants() do
			if d:IsA("BasePart") and d.Size.Magnitude > biggest then
				root, biggest = d, d.Size.Magnitude
			end
		end
	end
	model.PrimaryPart = root

	local parts = {}
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = true
			d.CanCollide = false
			d.CanTouch = false
			d.CanQuery = false
			d.Massless = true
			table.insert(parts, d)
		end
	end
	if humanoid then
		humanoid.EvaluateStateMachine = false
		humanoid.PlatformStand = true
		humanoid.BreakJointsOnDeath = false
		humanoid.RequiresNeck = false
		humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
		humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	end
	model.Parent = parent

	local height = select(2, bodyBounds(model, root)).Y -- her body, not her hat
	if height > 0.1 then
		model:ScaleTo(model:GetScale() * Carry.GirlLength / height)
	end

	-- Parts not already joined to the root (loose meshes, unwelded accessories)
	-- get welded. The joint graph is walked by hand: anchored parts don't form
	-- assemblies yet, and doubling a rig's Motor6Ds with welds would lock its limbs.
	local links = {}
	local function link(a, b)
		if a and b then
			links[a] = links[a] or {}
			links[b] = links[b] or {}
			table.insert(links[a], b)
			table.insert(links[b], a)
		end
	end
	for _, d in model:GetDescendants() do
		if d:IsA("JointInstance") or d:IsA("WeldConstraint") then
			link(d.Part0, d.Part1)
		end
	end
	local joined, queue = { [root] = true }, { root }
	while #queue > 0 do
		for _, other in links[table.remove(queue)] or {} do
			if not joined[other] then
				joined[other] = true
				table.insert(queue, other)
			end
		end
	end
	for _, p in parts do
		if not joined[p] and p ~= root then
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = root
			weld.Part1 = p
			weld.Parent = p
		end
	end

	local centre, size = bodyBounds(model, root)
	nameTag(model, girl, root, size.Y * 0.5 + 1.2)
	return model, root, centre, size
end

--[[
	The game's girl as a big showpiece floating over the map (owner's call, instead of her standing in
	the middle): `at` is where her feet float. Scaled up (Config/Round.Showcase), standing in a column of
	light in her rarity colour, with sparkles round her, a glowing ring under her feet and her rating
	over her head (stars by rarity, her name, her rarity). Everything is anchored; every client spins
	and bobs her slowly (tag "HuzzShowcase", HuzzClient/Gameplay/CarryAnimator).
]]
function GirlService.showcase(girl, at, parent)
	local S = Config.Showcase
	local model, root = GirlService.makeCopy(girl, nil) -- built out of the world; parented when complete
	model.Name = "HuzzShowcase"
	local tag = model:FindFirstChild("HuzzNameTag")
	if tag then
		tag:Destroy()
	end
	model:ScaleTo(model:GetScale() * S.Scale)
	local centre, size = bodyBounds(model, root)
	model:PivotTo(CFrame.new(at + Vector3.new(0, size.Y / 2, 0)) * centre:ToObjectSpace(model:GetPivot()))
	centre, size = bodyBounds(model, root)
	local rarity = GirlService.rarity(girl.rarity)
	local color = if rarity.Name == "Secret" then Color3.fromRGB(235, 235, 255) else rarity.Color

	local function part(name, props)
		local p = Instance.new("Part")
		p.Name = name
		p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = true, false, false, false, false
		for k, v in props do
			p[k] = v
		end
		p.Parent = model
		return p
	end
	-- Nothing under her feet any more (owner: the rings hid her from below). Her effects (flames on her
	-- hands, her element all round her, crescent slashes, her light) are drawn by every client from her look
	-- (Gameplay/Auras + Shared/AuraLook, kind "Showcase"); this part only carries her rating board.
	local aura = part("Aura", { Size = size + Vector3.new(2, 2, 2), Transparency = 1, CFrame = centre })

	-- Her rating over her head: stars by rarity (Common 1 ... Secret 7), her name, her rarity.
	local order = 1
	for i, r in Config.Rarities do
		if r.Name == girl.rarity then
			order = i
		end
	end
	local gui = Instance.new("BillboardGui")
	gui.Name = "Rating"
	gui.Size = UDim2.new(S.Scale * 4.6, 0, S.Scale * 2.2, 0) -- studs: it grows and shrinks with her
	gui.StudsOffsetWorldSpace = Vector3.new(0, size.Y / 2 + S.Scale * 1.4, 0)
	gui.LightInfluence = 0
	gui.MaxDistance = 2000
	gui.Parent = aura
	local function label(text, y, h, color3, weight)
		local t = Instance.new("TextLabel")
		t.BackgroundTransparency = 1
		t.Size = UDim2.new(1, 0, h, 0)
		t.Position = UDim2.fromScale(0, y)
		t.Text = text
		t.TextColor3 = color3
		t.TextScaled = true
		t.FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json", weight)
		local stroke = Instance.new("UIStroke")
		stroke.Thickness = 2.5
		stroke.Color = Color3.fromRGB(20, 18, 40)
		stroke.Parent = t
		t.Parent = gui
	end
	label(string.rep("★", order) .. string.rep("☆", #Config.Rarities - order), 0, 0.3, Color3.fromRGB(255, 214, 92), Enum.FontWeight.Heavy)
	label(girl.name, 0.3, 0.42, Color3.new(1, 1, 1), Enum.FontWeight.Heavy)
	label(string.upper(rarity.Name), 0.72, 0.28, color, Enum.FontWeight.Bold)

	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = true
		end
	end
	model:SetAttribute("Base", model:GetPivot())
	CollectionService:AddTag(model, "HuzzShowcase")
	model.Parent = parent
	return model
end

-- Standing on the floor at `top` (a point on the ground) as the round's prize.
function GirlService.display(girl, top, lookAt, parent)
	local model, _, centre, size = GirlService.makeCopy(girl, parent)
	local target = CFrame.lookAt(top + Vector3.new(0, size.Y * 0.5, 0), Vector3.new(lookAt.X, top.Y + size.Y * 0.5, lookAt.Z))
	model:PivotTo(target * centre:ToObjectSpace(model:GetPivot()))
	model.Name = "HuzzPrize"
	-- Only her root stays anchored, so every client can animate her joints (HuzzClient/Gameplay/CarryAnimator).
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") and d ~= model.PrimaryPart then
			d.Anchored = false
		end
	end
	CollectionService:AddTag(model, "HuzzPrize")
	return model
end

return GirlService

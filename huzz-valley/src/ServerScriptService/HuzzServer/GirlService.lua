-- The collection of girls: finds the owner's models, rolls the round's girl
-- by rarity, and makes clean, scaled copies to carry or put on display.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CollectionService = game:GetService("CollectionService")

local Config = require(ReplicatedStorage.Shared.Config.Round)
local Carry = require(ReplicatedStorage.Shared.Config.Carry)
local GirlNames = require(ReplicatedStorage.Shared.Config.GirlNames)

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
	local list = { { "Aiko", "Common" }, { "Hana", "Rare" }, { "Yuki", "Legendary" }, { "Sakura", "Secret" } }
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
	print(`[Huzz] {#GirlService.catalog} girls in the collection`)
end

-- Weighted by rarity (only rarities that have girls), then even within it.
function GirlService.roll()
	local groups, total = {}, 0
	for _, girl in GirlService.catalog do
		local g = groups[girl.rarity]
		if not g then
			g = { weight = GirlService.rarity(girl.rarity).Weight, list = {} }
			groups[girl.rarity] = g
			total += g.weight
		end
		table.insert(g.list, girl)
	end
	local roll = math.random() * total
	for _, g in groups do
		roll -= g.weight
		if roll <= 0 then
			return g.list[math.random(#g.list)]
		end
	end
	return GirlService.catalog[math.random(#GirlService.catalog)]
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
		t.FontFace = Font.new("rbxasset://fonts/families/Montserrat.json", weight)
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

--[[
	A copy of the girl ready to weld or display: scripts removed, scaled to
	Carry.GirlLength, every part joined to one root, no collisions, and any
	Humanoid switched off so it never fights the carrier's physics.
	Returns model, root, centre (bounding-box CFrame), size (extents).
	Parts stay anchored; the caller unanchors once she's welded.
]]
function GirlService.makeCopy(girl, parent)
	local model = girl.template:Clone()
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

	local height = model:GetExtentsSize().Y
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

	local centre, size = model:GetBoundingBox()
	nameTag(model, girl, root, size.Y * 0.5 + 1.2)
	return model, root, centre, size
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

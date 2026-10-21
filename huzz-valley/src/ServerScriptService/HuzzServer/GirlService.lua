-- The collection of girls: finds the owner's models, rolls the round's girl
-- by rarity, and makes clean, scaled copies to carry or put on display.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CollectionService = game:GetService("CollectionService")

local Config = require(ReplicatedStorage.Shared.Config.Round)
local Carry = require(ReplicatedStorage.Shared.Config.Carry)
local GirlNames = require(ReplicatedStorage.Shared.Config.GirlNames)
local GirlRoll = require(ReplicatedStorage.Shared.GirlRoll)
local GirlRig = require(ReplicatedStorage.Shared.GirlRig)
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
-- The owner's admin panel (HuzzServer/AdminService) can pick the next game's girl: the roll returns her once.
local nextGirl = nil
function GirlService.byId(id: string)
	for _, g in GirlService.catalog do
		if g.id == id then return g end
	end
	return nil
end
function GirlService.setNext(girl)
	nextGirl = girl
end

function GirlService.roll()
	if nextGirl then
		local g = nextGirl
		nextGirl = nil
		return g
	end
	-- Studio test (Config/Round.StudioTestRarity, e.g. "Secret" to see her arrival cutscene): Studio only, never live.
	local test = Config.StudioTestRarity
	if type(test) == "string" and test ~= "" and game:GetService("RunService"):IsStudio() then
		for _, g in GirlService.catalog do
			if g.rarity == test then return g end
		end
	end
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

-- Avatars on Roblox's newer joints use AnimationConstraints (some doubled up): the copy gets one plain Motor6D per
-- joint, and every accessory welded to the body part it sits on (C.C.'s hair turns with her head): Shared/GirlRig.
local function useMotors(model)
	GirlRig.toMotors(model)
	GirlRig.joinAccessories(model)
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
	-- Every copy reaches every screen whole (owner, Oct 19: "make the girls be seen on everyones screen"). His place
	-- streams: a plain Model reaches other players before its parts, part by part, so their screens started her
	-- moves on a model with no root or limbs yet and she stood frozen or never showed. Persistent = sent whole, to
	-- everyone, and never streamed out (there are only a few girls at a time: the carried one, followers, the prize).
	pcall(function() (model :: any).ModelStreamingMode = Enum.ModelStreamingMode.Persistent end)
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
	the middle): `at` is where her feet float. Scaled up (Config/Round.Showcase), shown like a prize on a stand
	(the other game's demo stand, docs/feel-study.md gap 12: at 18 s of the owner's recording she read as a dark
	blob 3.5% of the screen tall):
	  - nothing under her feet (owner, Oct 21 16:17: "remove the bottom plate, and just keep her with some good vfx";
	    the stand before that, and the rings before it, hid her from below);
	  - soft light on her (the sun is above her and you look up at her from the field, so she was in her own
	    shade against the bright sky): a key light in front, a rim light in her colour behind, a soft glow up
	    from the stand. Short ranges, so nothing reaches the field ("too much light shining down");
	  - her title over her head: her name big in her rarity colour, her rarity and stars under it, sized in studs
	    with a floor in pixels so it still reads from the far end of the field.
	Her body plays the pack's Idle on every client (only her root part is anchored, like the prize girl), and every
	client spins and bobs her slowly (tag "HuzzShowcase", HuzzClient/Gameplay/CarryAnimator), which hides the stand
	and her lights while the Secret cutscene plays. The stand stays inside her "Aura" part's box, so her bounding box
	(the cutscene measures it) doesn't change.
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
	local titleColor = if rarity.Name == "Secret" then Color3.fromRGB(196, 160, 255) else rarity.Color
	-- her body: only the root part anchored, so every client can play her idle on her joints (CarryAnimator)
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = d == root
		end
	end

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

	-- No stand under her any more (owner, Oct 21 16:17, his picture of C.C. over the map: "remove the bottom plate,
	-- and just keep her with some good vfx"): she floats in her effects (Gameplay/Auras), with the soft light below.
	local feet = centre * CFrame.new(0, -size.Y / 2, 0)
	-- a soft glow up from under her feet onto her (you look up at her from the field)
	local up = part("StandGlow", { Size = Vector3.new(0.2, 0.2, 0.2), Transparency = 1, CFrame = feet * CFrame.new(0, -0.05, 0) })
	local spot = Instance.new("SpotLight")
	spot.Face, spot.Angle, spot.Brightness, spot.Range = Enum.NormalId.Top, 70, 1.0, size.Y * 0.9
	spot.Color, spot.Shadows = color:Lerp(Color3.new(1, 1, 1), 0.55), false
	spot.Parent = up
	-- a key light in front of her and a rim light in her colour behind; they turn with her. The key light sits low
	-- in front (players look up at her from the field, and she still read dark from there) and brighter, with a
	-- short range and no shadows; nothing lights her from above (owner: "too much light shining down").
	local function lamp(name, offset, brightness, tint, range)
		local holder = part(name, { Size = Vector3.new(0.2, 0.2, 0.2), Transparency = 1, CFrame = centre * offset })
		local light = Instance.new("PointLight")
		light.Brightness, light.Range, light.Color, light.Shadows = brightness, range or size.Y * 0.75, tint, false
		light.Parent = holder
	end
	-- (Oct 19: softer, 1.5 / 0.8 / stand 1.0, was 2.2 / 1.1 / 1.4: the brighter sky light now fills her shade)
	lamp("KeyLight", CFrame.new(0, -size.Y * 0.3, -(size.Z / 2 + size.Y * 0.3)), 1.5, Color3.fromRGB(255, 244, 236), size.Y * 0.7)
	lamp("RimLight", CFrame.new(0, size.Y * 0.2, size.Z / 2 + size.Y * 0.3), 0.8, color:Lerp(Color3.new(1, 1, 1), 0.3))

	-- Her rating over her head: stars by rarity (Common 1 ... Secret 7), her name, her rarity.
	local order = 1
	for i, r in Config.Rarities do
		if r.Name == girl.rarity then
			order = i
		end
	end
	local gui = Instance.new("BillboardGui")
	gui.Name = "Rating"
	-- studs (it grows and shrinks with her) plus a floor in pixels, so it still reads from the far end of the field
	gui.Size = UDim2.new(S.Scale * 6, 110, S.Scale * 2.4, 44)
	-- (its bottom edge sits 1.8 studs x scale over her head, however big the pixel floor makes it: seen from below,
	-- the front of her head and hair rises on screen and cut through the line at half a stud)
	gui.SizeOffset = Vector2.new(0, 0.5)
	gui.StudsOffsetWorldSpace = Vector3.new(0, size.Y / 2 + S.Scale * 1.8, 0)
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
		stroke.Thickness = 3
		stroke.Color = Color3.fromRGB(20, 18, 40)
		stroke.Parent = t
		t.Parent = gui
	end
	-- her name big in her rarity colour (the other game's "SOUL REAPER" over its stand), then her rarity in white
	-- with stars in her colour (no gold: owner's call)
	label(string.upper(girl.name), 0, 0.62, titleColor, Enum.FontWeight.Heavy)
	label(string.upper(rarity.Name) .. "  " .. string.rep("★", order), 0.64, 0.32, Color3.new(1, 1, 1), Enum.FontWeight.Bold)

	model:SetAttribute("Base", model:GetPivot())
	model:SetAttribute("GirlName", girl.name) -- (the Secret cutscene puts it on screen: Gameplay/SecretReveal)
	CollectionService:AddTag(model, "HuzzShowcase")
	-- (the owner's place streams: without this a far-away player's game never gets her parts, and the Secret
	-- cutscene filmed an empty spot. Persistent = every player always has her, whole)
	pcall(function() (model :: any).ModelStreamingMode = Enum.ModelStreamingMode.Persistent end)
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

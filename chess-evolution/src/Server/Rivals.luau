--!strict
-- +1 Chess Evolution: the human rivals standing at each stage's duel table.
-- Built from Roblox's default R15 body (no asset IDs needed), coloured per rival,
-- with part-built hats so each one reads at a glance. A rig named "RivalNPC" that is
-- already in the stage (for example the Blender rigs from assets/Rivals.rbxm) is kept.
local Players = game:GetService("Players")

local Rivals = {}

local SKIN = {
	Color3.fromRGB(255, 214, 170), Color3.fromRGB(234, 184, 146), Color3.fromRGB(198, 140, 100),
	Color3.fromRGB(150, 100, 70), Color3.fromRGB(255, 224, 189), Color3.fromRGB(176, 120, 84), Color3.fromRGB(226, 172, 128),
}

-- shirt, pants, hat style per rival
local LOOK = {
	PawnPete = { shirt = Color3.fromRGB(255, 90, 80), pants = Color3.fromRGB(50, 60, 90), hat = "cap" },
	KnightNadia = { shirt = Color3.fromRGB(60, 140, 255), pants = Color3.fromRGB(30, 34, 50), hat = "helm" },
	RookRocco = { shirt = Color3.fromRGB(255, 190, 40), pants = Color3.fromRGB(70, 50, 40), hat = "tower" },
	BishopBea = { shirt = Color3.fromRGB(170, 80, 240), pants = Color3.fromRGB(40, 30, 60), hat = "mitre" },
	QueenQuinn = { shirt = Color3.fromRGB(255, 120, 200), pants = Color3.fromRGB(60, 30, 60), hat = "tiara" },
	KingKai = { shirt = Color3.fromRGB(60, 220, 200), pants = Color3.fromRGB(20, 40, 50), hat = "crown" },
	GrandmasterOrion = { shirt = Color3.fromRGB(28, 26, 40), pants = Color3.fromRGB(20, 18, 28), hat = "crown", cape = Color3.fromRGB(200, 30, 60), boss = true },
}

local GOLD = Color3.fromRGB(255, 200, 40)

local function weld(p: BasePart, to: BasePart)
	local w = Instance.new("WeldConstraint")
	w.Part0 = to
	w.Part1 = p
	w.Parent = p
end

local function bit(parent: Instance, name: string, size: Vector3, cf: CFrame, color: Color3, attach: BasePart, shape: Enum.PartType?): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.CanCollide = false
	p.CanQuery = false
	p.Massless = true
	if shape then
		p.Shape = shape
	end
	p.Parent = parent
	weld(p, attach)
	return p
end

local function addHat(rig: Model, style: string, accent: Color3)
	local head = rig:FindFirstChild("Head") :: BasePart?
	if not head then
		return
	end
	local top = head.CFrame * CFrame.new(0, head.Size.Y / 2, 0)
	if style == "cap" then
		bit(rig, "Cap", Vector3.new(1.3, 0.45, 1.3), top * CFrame.new(0, 0.15, 0), accent, head)
		bit(rig, "Brim", Vector3.new(1.2, 0.12, 0.7), top * CFrame.new(0, 0, -0.75), accent, head)
	elseif style == "helm" then
		bit(rig, "Helm", Vector3.new(1.35, 0.7, 1.35), top * CFrame.new(0, 0.2, 0.05), Color3.fromRGB(220, 226, 240), head)
		bit(rig, "Plume", Vector3.new(0.25, 0.9, 1.1), top * CFrame.new(0, 0.8, 0.2), accent, head)
	elseif style == "tower" then
		bit(rig, "Tower", Vector3.new(1.3, 0.6, 1.3), top * CFrame.new(0, 0.25, 0), Color3.fromRGB(70, 70, 80), head)
		for _, d in { { -0.45, -0.45 }, { 0.45, -0.45 }, { -0.45, 0.45 }, { 0.45, 0.45 } } do
			bit(rig, "Merlon", Vector3.new(0.35, 0.35, 0.35), top * CFrame.new(d[1], 0.7, d[2]), Color3.fromRGB(70, 70, 80), head)
		end
	elseif style == "mitre" then
		local h = bit(rig, "Mitre", Vector3.new(1.0, 1.3, 1.0), top * CFrame.new(0, 0.55, 0) * CFrame.Angles(0, math.rad(45), 0), Color3.fromRGB(246, 238, 220), head)
		local _ = h
		bit(rig, "MitreBand", Vector3.new(1.1, 0.2, 1.1), top * CFrame.new(0, 0.1, 0) * CFrame.Angles(0, math.rad(45), 0), accent, head)
	elseif style == "tiara" or style == "crown" then
		local big = style == "crown"
		bit(rig, "CrownBand", Vector3.new(1.3, if big then 0.45 else 0.25, 1.3), top * CFrame.new(0, 0.12, 0), GOLD, head)
		for i = 0, (if big then 4 else 2) do
			local a = (i / (if big then 5 else 3)) * math.pi * 2
			bit(rig, "CrownSpike", Vector3.new(0.22, if big then 0.55 else 0.4, 0.22), top * CFrame.new(math.cos(a) * 0.55, if big then 0.6 else 0.45, math.sin(a) * 0.55), GOLD, head)
		end
		bit(rig, "CrownJewel", Vector3.new(0.3, 0.3, 0.3), top * CFrame.new(0, 0.2, -0.66), accent, head, Enum.PartType.Ball)
	end
end

local function nameTag(rig: Model, stage: any)
	local head = rig:FindFirstChild("Head") :: BasePart?
	if not head then
		return
	end
	local bb = Instance.new("BillboardGui")
	bb.Name = "RivalTag"
	bb.Size = UDim2.fromScale(7, 2)
	bb.StudsOffset = Vector3.new(0, 3.1, 0)
	bb.LightInfluence = 0
	bb.MaxDistance = 90
	bb.Adornee = head
	bb.Parent = head
	local list = Instance.new("UIListLayout")
	list.HorizontalAlignment = Enum.HorizontalAlignment.Center
	list.Parent = bb
	for i, row in { { stage.opponent.name, Color3.new(1, 1, 1), 0.58 }, { stage.opponent.title, stage.color, 0.42 } } do
		local t = Instance.new("TextLabel")
		t.Name = "Line" .. i
		t.LayoutOrder = i
		t.BackgroundTransparency = 1
		t.Size = UDim2.fromScale(1, row[3])
		t.FontFace = Font.fromEnum(Enum.Font.FredokaOne)
		t.TextScaled = true
		t.Text = row[1]
		t.TextColor3 = row[2]
		local s = Instance.new("UIStroke")
		s.Thickness = 2.5
		s.Color = Color3.fromRGB(25, 25, 35)
		s.Parent = t
		t.Parent = bb
	end
end

local function build(stageId: string, stage: any, i: number): Model?
	local look = LOOK[stage.rivalId] or LOOK.PawnPete
	local desc = Instance.new("HumanoidDescription")
	local skin = SKIN[((i - 1) % #SKIN) + 1]
	desc.HeadColor = skin
	desc.LeftArmColor = skin
	desc.RightArmColor = skin
	desc.TorsoColor = look.shirt
	desc.LeftLegColor = look.pants
	desc.RightLegColor = look.pants
	if look.boss then
		desc.HeightScale = 1.12
		desc.WidthScale = 1.08
	end
	local ok, rig = pcall(function()
		return Players:CreateHumanoidModelFromDescription(desc, Enum.HumanoidRigType.R15)
	end)
	if not ok or not rig then
		warn(`[Chess] rival {stageId}: could not build a body ({rig})`)
		return nil
	end
	rig.Name = "RivalNPC"
	local hum = rig:FindFirstChildOfClass("Humanoid") :: Humanoid
	hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	hum.BreakJointsOnDeath = false
	hum:SetStateEnabled(Enum.HumanoidStateType.Dead, false)
	local animate = rig:FindFirstChild("Animate")
	if animate then
		animate:Destroy() -- the client drives idle and tapping itself
	end
	-- the arms swing from the torso's colour: give the upper arms short sleeves
	for _, side in { "Left", "Right" } do
		local upper = rig:FindFirstChild(side .. "UpperArm") :: BasePart?
		if upper then
			upper.Color = look.shirt
		end
	end
	addHat(rig, look.hat, stage.color)
	if look.cape then
		local torso = rig:FindFirstChild("UpperTorso") :: BasePart?
		if torso then
			bit(rig, "Cape", Vector3.new(2.2, 3.2, 0.15), torso.CFrame * CFrame.new(0, -0.9, 0.62) * CFrame.Angles(math.rad(-8), 0, 0), look.cape, torso)
			bit(rig, "CapeClasp", Vector3.new(2.2, 0.3, 0.3), torso.CFrame * CFrame.new(0, 0.7, 0.55), GOLD, torso)
		end
	end
	rig:SetAttribute("RivalId", stage.rivalId)
	rig:SetAttribute("StageId", stageId)
	nameTag(rig, stage)
	return rig
end

function Rivals.Spawn(config: any, map: Instance)
	local stages = map:FindFirstChild("Stages")
	if not stages then
		return
	end
	for i, stageId in config.StageOrder do
		local stage = config.Stages[stageId]
		local model = stages:FindFirstChild(stageId)
		local tbl = model and model:FindFirstChild("DuelTable")
		local seat = tbl and tbl:FindFirstChild("SeatB") :: BasePart?
		if model and seat and not model:FindFirstChild("RivalNPC") then
			-- the Blender-made rig (assets/Rivals.rbxm, pivot at the feet) when it is installed
			-- 1st choice: the real Roblox avatars Alex generated in Studio (ServerStorage.ChessRivals);
			-- 2nd: the part-built rigs from assets/Rivals.rbxm; last: a default body built here.
			local real = game:GetService("ServerStorage"):FindFirstChild("ChessRivals")
			local assets = game:GetService("ReplicatedStorage"):FindFirstChild("ChessAssets")
			local made = (real and real:FindFirstChild(stage.rivalId or ""))
				or (assets and assets:FindFirstChild("Rivals") and assets.Rivals:FindFirstChild(stage.rivalId or ""))
			if made then
				local rig = made:Clone()
				rig.Name = "RivalNPC"
				rig:SetAttribute("StageId", stageId)
				local hum = rig:FindFirstChildOfClass("Humanoid")
				local root = rig:FindFirstChild("HumanoidRootPart") :: BasePart?
				if hum then
					hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
				end
				for _, p in rig:GetDescendants() do
					if p:IsA("BasePart") then
						p.Anchored = p == root
						p.CanCollide = false
					elseif p:IsA("Script") or p:IsA("LocalScript") then
						p:Destroy() -- no Animate/Health scripts: the client drives the animations
					end
				end
				if hum and root then
					-- stand the feet on the pad whatever the rig's own pivot is
					local target = seat.CFrame * CFrame.new(0, hum.HipHeight + root.Size.Y / 2, 0)
					rig:PivotTo(target * (root.CFrame:Inverse() * rig:GetPivot()))
				else
					rig:PivotTo(seat.CFrame)
				end
				nameTag(rig, stage)
				rig.Parent = model
				continue
			end
			local rig = build(stageId, stage, i)
			if rig then
				local root = rig:FindFirstChild("HumanoidRootPart") :: BasePart
				local hum = rig:FindFirstChildOfClass("Humanoid") :: Humanoid
				root.Anchored = true
				rig:PivotTo(seat.CFrame * CFrame.new(0, hum.HipHeight + root.Size.Y / 2, 0))
				rig.Parent = model
			end
		end
	end
	print("[Chess] rivals ready")
end

return Rivals

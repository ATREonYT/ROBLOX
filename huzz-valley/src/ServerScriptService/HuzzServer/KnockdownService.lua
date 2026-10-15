--[[
	Caught runners fall on the floor and lie there until the round ends.
	The server anchors the root part where they stood, stops them moving and
	sets the character's DownedAt (server time), DownedFeet (CFrame on the
	ground) and DownedHeight; every client plays the fall (Shared/DownMotion via
	HuzzClient/Gameplay/Knockdown). Lying bodies don't block anyone (their own
	collision group).
]]
local PhysicsService = game:GetService("PhysicsService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config.Round)
local DownMotion = require(ReplicatedStorage.Shared.DownMotion)

local KnockdownService = {}
local GROUP = "HuzzDowned"
local downed = {} -- Player -> { character, root, groups = {part -> group} }

pcall(function()
	PhysicsService:RegisterCollisionGroup(GROUP)
	PhysicsService:CollisionGroupSetCollidable(GROUP, "Default", false)
	PhysicsService:CollisionGroupSetCollidable(GROUP, GROUP, false)
end)

function KnockdownService.isDown(player)
	return downed[player] ~= nil
end

function KnockdownService.down(player)
	if downed[player] then
		return
	end
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = humanoid and humanoid.RootPart
	if not (root and humanoid.Health > 0) then
		return
	end

	-- The floor under them, ignoring characters and girls.
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local ignore = { Workspace:FindFirstChild("HuzzCarried"), Workspace:FindFirstChild("HuzzFollowers") }
	for _, p in game:GetService("Players"):GetPlayers() do
		table.insert(ignore, p.Character)
	end
	params.FilterDescendantsInstances = ignore
	local hit = Workspace:Raycast(root.Position, Vector3.new(0, -50, 0), params)
	local groundY = if hit then hit.Position.Y else root.Position.Y - 3
	local yaw = select(2, root.CFrame:ToEulerAnglesYXZ())
	local feet = CFrame.new(root.Position.X, groundY, root.Position.Z) * CFrame.Angles(0, yaw, 0)
	local height = root.Position.Y - groundY

	local entry = { character = character, root = root, groups = {} }
	downed[player] = entry
	root.Anchored = true
	humanoid.PlatformStand = true
	humanoid.AutoRotate = false
	for _, d in character:GetDescendants() do
		if d:IsA("BasePart") then
			entry.groups[d] = d.CollisionGroup
			d.CollisionGroup = GROUP
		end
	end
	character:SetAttribute("DownedFeet", feet)
	character:SetAttribute("DownedHeight", height)
	character:SetAttribute("DownedAt", Workspace:GetServerTimeNow())
	-- The server's copy lands flat too (clients play the fall in between).
	task.delay(Config.Knockdown.FallTime, function()
		if downed[player] == entry and root.Parent then
			root.CFrame = DownMotion.rootCFrame(feet, height, 99)
		end
	end)
end

function KnockdownService.up(player)
	local entry = downed[player]
	downed[player] = nil
	if not entry or not entry.character.Parent then
		return
	end
	local character, root = entry.character, entry.root
	local feet, height = character:GetAttribute("DownedFeet"), character:GetAttribute("DownedHeight")
	character:SetAttribute("DownedAt", nil)
	character:SetAttribute("DownedFeet", nil)
	character:SetAttribute("DownedHeight", nil)
	for part, group in entry.groups do
		if part.Parent then
			part.CollisionGroup = group
		end
	end
	if feet and height then
		root.CFrame = feet * CFrame.new(0, height, 0)
	end
	root.Anchored = false
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.PlatformStand = false
		humanoid.AutoRotate = true
	end
end

function KnockdownService.upAll()
	for player in downed do
		KnockdownService.up(player)
	end
end

game:GetService("Players").PlayerRemoving:Connect(function(player)
	downed[player] = nil
end)

return KnockdownService

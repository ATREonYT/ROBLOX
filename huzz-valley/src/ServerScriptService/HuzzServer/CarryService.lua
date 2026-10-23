--[[
	Puts a girl over a player's head. The server only builds the joint: a
	Motor6D from the carrier's torso to her root, in the resting hold. Every
	client then animates that joint's Transform and the carrier's arms
	(HuzzClient/CarryAnimator), so it's smooth for everyone with no network cost.

	She lives in Workspace.HuzzCarried, not inside the character, so the
	carrier's walk animations never grab her joints. Attributes on her model:
	Carrier (UserId), Start (server time), From (Vector3: where she flies in from),
	Mood ("Calm" | "Excited" | "Struggle" | "Cheer") and MoodAt (server time).
]]
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Carry = require(ReplicatedStorage.Shared.Config.Carry)
local CarryMath = require(ReplicatedStorage.Shared.CarryMath)
local GirlService = require(script.Parent.GirlService)
local GirlSign = require(script.Parent.GirlSign)

local CarryService = {}
local carried = {} -- Player -> model (carried overhead, or following on foot)

local function makeFolder(name)
	local f = Workspace:FindFirstChild(name) or Instance.new("Folder")
	f.Name = name
	f.Parent = Workspace
	return f
end
local folder = makeFolder("HuzzCarried")
local followFolder = makeFolder("HuzzFollowers")

function CarryService.get(player)
	local model = carried[player]
	if model and model.Parent then
		return model
	end
	carried[player] = nil
	return nil
end

-- Where she is right now (for the next transfer). A follower is moved by each
-- client, so the server uses the spot she walks to behind the catcher.
function CarryService.position(player)
	local model = CarryService.get(player)
	if model and model:GetAttribute("Follow") then
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		return root and (root.CFrame * CFrame.new(Carry.Follow.Offset)).Position + Vector3.new(0, model:GetAttribute("RootHeight") or 3, 0)
	end
	return model and model:GetBoundingBox().Position
end

function CarryService.remove(player)
	local model = carried[player]
	carried[player] = nil
	if model then
		model:Destroy()
	end
	GirlSign.remove(player.Character) -- (the "HAS <HER>" sign over their head goes with her)
end

local function dropWithCarrier(player, humanoid, model)
	humanoid.Died:Once(function()
		if carried[player] == model then
			CarryService.remove(player)
		end
	end)
end

--[[
	She walks behind this player (a catcher who caught her carrier) instead of
	being carried. fromPosition: where she starts (on the old carrier's head,
	so she falls down first), or nil for her spot behind him. Her root stays
	anchored and every client walks her (HuzzClient/Gameplay/CarryAnimator).
	Attributes: Follow (UserId), RootHeight (root above her feet).
]]
function CarryService.follow(player, girl, fromPosition)
	CarryService.remove(player)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local leader = character and character:FindFirstChild("HumanoidRootPart")
	if not (leader and humanoid and humanoid.Health > 0) then
		return nil
	end
	local model, root, centre, size = GirlService.makeCopy(girl, followFolder)
	model.Name = "Follower_" .. player.Name
	local rootHeight = root.Position.Y - (centre.Position.Y - size.Y / 2)
	local start = fromPosition or (leader.CFrame * CFrame.new(Carry.Follow.Offset)).Position
	local yaw = select(2, leader.CFrame:ToEulerAnglesYXZ())
	-- Upright, her root at the start point (the clients take it from there).
	model:PivotTo(CFrame.new(start) * CFrame.Angles(0, yaw, 0) * root.CFrame:ToObjectSpace(model:GetPivot()))
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") and d ~= root then
			d.Anchored = false
		end
	end
	model:SetAttribute("Follow", player.UserId)
	model:SetAttribute("RootHeight", rootHeight)
	CollectionService:AddTag(model, "HuzzFollower")
	carried[player] = model
	pcall(GirlSign.put, character, girl)
	dropWithCarrier(player, humanoid, model)
	return model
end

function CarryService.removeAll()
	for player in carried do
		CarryService.remove(player)
	end
end

-- How she feels about her carrier (Shared/GirlMotion plays it).
function CarryService.setMood(player, mood)
	local model = CarryService.get(player)
	if model then
		model:SetAttribute("Mood", mood)
		model:SetAttribute("MoodAt", Workspace:GetServerTimeNow())
	end
end

function CarryService.give(player, girl, fromPosition, mood)
	CarryService.remove(player)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local rig = character and CarryMath.rig(character)
	if not (rig and humanoid and humanoid.Health > 0) then
		return nil
	end

	local model, root, centre, size = GirlService.makeCopy(girl, folder)
	model.Name = "Carried_" .. player.Name
	-- (her own name tag goes: carried, it sat in the carrier's body; owner, Oct 23 14:10: "the girl name isnt above
	-- his head but inside the body". Her name shows over his head instead: GirlSign, "HAS <HER NAME>")
	local tag = model:FindFirstChild("HuzzNameTag")
	if tag then tag:Destroy() end
	model:SetAttribute("Carrier", player.UserId)
	model:SetAttribute("GirlName", girl.name)
	model:SetAttribute("Start", Workspace:GetServerTimeNow())
	model:SetAttribute("From", fromPosition)
	model:SetAttribute("Mood", mood or "Calm")
	model:SetAttribute("MoodAt", Workspace:GetServerTimeNow())

	local motor = Instance.new("Motor6D")
	motor.Name = "HuzzCarryMotor"
	motor.Part0 = rig.torso
	motor.Part1 = root
	motor.C0 = CarryMath.holdC0(rig, size.Z)
	motor.C1 = root.CFrame:ToObjectSpace(centre)
	motor.Parent = model
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = false
		end
	end
	carried[player] = model
	pcall(GirlSign.put, character, girl)

	-- She goes down with her carrier; RoundService re-gives her on respawn.
	dropWithCarrier(player, humanoid, model)
	return model
end

Players.PlayerRemoving:Connect(CarryService.remove)

return CarryService

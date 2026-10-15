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
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local CarryMath = require(ReplicatedStorage.Shared.CarryMath)
local GirlService = require(script.Parent.GirlService)

local CarryService = {}
local carried = {} -- Player -> model

local folder = Workspace:FindFirstChild("HuzzCarried") or Instance.new("Folder")
folder.Name = "HuzzCarried"
folder.Parent = Workspace

function CarryService.get(player)
	local model = carried[player]
	if model and model.Parent then
		return model
	end
	carried[player] = nil
	return nil
end

-- Where she is right now (for the next pickup's flight).
function CarryService.position(player)
	local model = CarryService.get(player)
	return model and model:GetBoundingBox().Position
end

function CarryService.remove(player)
	local model = carried[player]
	carried[player] = nil
	if model then
		model:Destroy()
	end
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
	local tag = model:FindFirstChild("HuzzNameTag")
	if tag then
		tag.StudsOffsetWorldSpace = Vector3.new(0, size.Z * 0.5 + 1.4, 0) -- she's lying down
	end
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

	-- She goes down with her carrier; RoundService re-gives her on respawn.
	humanoid.Died:Once(function()
		if carried[player] == model then
			CarryService.remove(player)
		end
	end)
	return model
end

Players.PlayerRemoving:Connect(CarryService.remove)

return CarryService

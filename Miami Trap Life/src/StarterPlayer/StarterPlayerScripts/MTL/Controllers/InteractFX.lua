--!strict
-- Every proximity prompt answers back: a soft pop sound, a small burst at the prompt and a tiny camera nod when you
-- complete one. Hold times are NOT changed here: a prompt the server made checks its own HoldDuration, so shortening
-- it on the client could make the server ignore the press. Snappier holds = set HoldDuration where the prompt is made.
-- Only touches prompts on this client; the server still decides what a prompt does. Prompts on our own MTL_* parts
-- only get the camera nod (the job / mission code plays their sounds).
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Movement = require(ReplicatedStorage.MTL.Config.Movement)
local Theme = require(ReplicatedStorage.MTL.UI.Theme)
local Sfx = require(ReplicatedStorage.MTL.UI.Sfx)
local JobFX = require(script.Parent.JobFX)
local Juice = require(script.Parent.Juice)

local InteractFX = {}

local function promptPosition(prompt: ProximityPrompt): Vector3?
	local p = prompt.Parent
	if p and p:IsA("BasePart") then
		return p.Position
	elseif p and p:IsA("Attachment") then
		return p.WorldPosition
	elseif p and p:IsA("Model") then
		return p:GetPivot().Position
	end
	return nil
end

function InteractFX.init()
	ProximityPromptService.PromptTriggered:Connect(function(prompt, who)
		if who ~= Players.LocalPlayer then
			return
		end
		Juice.hit("Prompt")
		-- our own systems' prompts (MTL_JobAnchor, mission points...) already play their own sound + effect
		local owner = prompt.Parent
		if owner and string.sub(owner.Name, 1, 4) == "MTL_" then
			return
		end
		Sfx.play(Movement.PromptSound)
		local at = promptPosition(prompt)
		if at then
			JobFX.burst(at, Theme.Colors.Accent)
		end
	end)
end

return InteractFX

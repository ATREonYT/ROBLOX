--!strict
-- Every interaction prompt in the game ("E · Enter store", "Hold E · Restock") drawn in the game's own low-poly
-- style instead of Roblox's default grey bubble: a key tile (keyboard key, gamepad button or a tap target),
-- the action + object text, and a fill that rises while you hold. Works for prompts any system makes:
-- Default-style prompts are switched to Custom on this client only; prompts someone already made Custom
-- (with their own UI) are left alone.
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Theme = require(ReplicatedStorage.MTL.UI.Theme)
local Motion = require(ReplicatedStorage.MTL.UI.Motion)
local Build = require(ReplicatedStorage.MTL.UI.Build.HUD)

local player = Players.LocalPlayer

local Prompts = {}

local ours: { [ProximityPrompt]: boolean } = {} -- prompts this controller restyled
local folder: Folder

local GAMEPAD = { ButtonX = "X", ButtonY = "Y", ButtonA = "A", ButtonB = "B", ButtonL1 = "LB", ButtonR1 = "RB" }

local function adopt(inst: Instance)
	if inst:IsA("ProximityPrompt") and inst.Style == Enum.ProximityPromptStyle.Default then
		ours[inst] = true
		inst.Style = Enum.ProximityPromptStyle.Custom
	end
end

local function keyText(prompt: ProximityPrompt, inputType: Enum.ProximityPromptInputType): string
	if inputType == Enum.ProximityPromptInputType.Gamepad then
		return GAMEPAD[prompt.GamepadKeyCode.Name] or prompt.GamepadKeyCode.Name
	elseif inputType == Enum.ProximityPromptInputType.Touch then
		return "👆"
	end
	local s = UserInputService:GetStringForKeyCode(prompt.KeyboardKeyCode)
	return if s ~= "" then string.upper(s) else prompt.KeyboardKeyCode.Name
end

local function show(prompt: ProximityPrompt, inputType: Enum.ProximityPromptInputType)
	if not ours[prompt] then
		return
	end
	local bb = Build.prompt()
	bb.Name = "Prompt"
	bb.Adornee = prompt.Parent :: any
	bb.Parent = folder
	local body = bb:FindFirstChild("Body") :: any
	local popScale = body.Pop :: UIScale -- held here: once the prompt is gone, body.Pop can no longer be looked up
	local conns: { RBXScriptConnection } = {}

	local function refresh()
		local key = body.Key
		key.Letter.Text = keyText(prompt, inputType)
		body.Info.Action.Text = prompt.ActionText
		body.Info.Object.Text = prompt.ObjectText
		body.Info.Object.Visible = prompt.ObjectText ~= ""
		body.Info.Hold.Visible = prompt.HoldDuration > 0
		bb.Enabled = prompt.Enabled
	end
	refresh()
	for _, prop in { "ActionText", "ObjectText", "HoldDuration", "Enabled", "KeyboardKeyCode" } do
		table.insert(conns, prompt:GetPropertyChangedSignal(prop):Connect(refresh))
	end

	-- hold: the key tile fills from the bottom over HoldDuration
	local fill = body.Key.Fill
	local holdTween: Tween? = nil
	table.insert(conns, prompt.PromptButtonHoldBegan:Connect(function()
		fill.Size = UDim2.fromScale(1, 0)
		holdTween = Motion.tween(fill, TweenInfo.new(prompt.HoldDuration, Enum.EasingStyle.Linear), { Size = UDim2.fromScale(1, 1) })
	end))
	table.insert(conns, prompt.PromptButtonHoldEnded:Connect(function()
		if holdTween then
			holdTween:Cancel()
		end
		Motion.tween(fill, Motion.Fast, { Size = UDim2.fromScale(1, 0) })
	end))
	table.insert(conns, prompt.Triggered:Connect(function()
		popScale.Scale = 1.12
		Motion.tween(popScale, Motion.Spring, { Scale = 1 })
		fill.Size = UDim2.fromScale(1, 0)
	end))

	-- touch / mouse: the whole prompt is a button
	local button = body :: TextButton
	table.insert(conns, button.InputBegan:Connect(function(input)
		local t = input.UserInputType
		if t == Enum.UserInputType.Touch or t == Enum.UserInputType.MouseButton1 then
			prompt:InputHoldBegin()
			popScale.Scale = 0.95
		end
	end))
	table.insert(conns, button.InputEnded:Connect(function(input)
		local t = input.UserInputType
		if t == Enum.UserInputType.Touch or t == Enum.UserInputType.MouseButton1 then
			prompt:InputHoldEnd()
			Motion.tween(popScale, Motion.Spring, { Scale = 1 })
		end
	end))

	-- in: pop up from the key
	popScale.Scale = 0.6
	Motion.tween(popScale, Motion.Spring, { Scale = 1 })

	local hidden: RBXScriptConnection
	hidden = ProximityPromptService.PromptHidden:Connect(function(p)
		if p ~= prompt then
			return
		end
		hidden:Disconnect()
		for _, c in conns do
			c:Disconnect()
		end
		Motion.tween(popScale, Motion.Fast, { Scale = 0.6 }).Completed:Once(function()
			bb:Destroy()
		end)
	end)
end

function Prompts.init()
	folder = Instance.new("Folder")
	folder.Name = "MTL_Prompts"
	folder.Parent = player:WaitForChild("PlayerGui")
	for _, d in workspace:GetDescendants() do
		adopt(d)
	end
	workspace.DescendantAdded:Connect(adopt)
	ProximityPromptService.PromptShown:Connect(show)
end

return Prompts

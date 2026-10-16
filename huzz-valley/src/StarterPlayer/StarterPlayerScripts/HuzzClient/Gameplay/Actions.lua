--[[
	The two round moves:
	  STAB (catchers, while a round runs): left click, a gamepad's R2, or the STAB button.
	  HUSS (whoever carries her overhead): H, a gamepad's X, or the HUSS button.
	Both play at once on your own screen and are checked by the server (RoundService):
	a stab tags the nearest runner in reach, a huss sets HussAt on the carried girl so
	every client plays the throw (CarryAnimator / Shared/CarryMotion).

	Also plays everyone's stab (Shared/StabMotion, or Config/Animations.Stab when set)
	and lights the knife's slash trail. Buttons sit bottom right, above a phone's jump
	button, and only show when the move is available.
]]
local M = {}

function M.start()
	local Players = game:GetService("Players")
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local RunService = game:GetService("RunService")
	local UserInputService = game:GetService("UserInputService")
	local Workspace = game:GetService("Workspace")

	local Shared = ReplicatedStorage:WaitForChild("Shared")
	local Net = require(Shared.Net)
	local Config = require(Shared.Config.Round)
	local Carry = require(Shared.Config.Carry)
	local Animations = require(Shared.Config.Animations)
	local CarryMath = require(Shared.CarryMath)
	local StabMotion = require(Shared.StabMotion)

	local player = Players.LocalPlayer
	local RoundNet = Net.get("Round") :: RemoteEvent
	local StabNet = Net.get("Stab") :: RemoteEvent
	local HussNet = Net.get("Huss") :: RemoteEvent
	local carried = Workspace:WaitForChild("HuzzCarried")

	-- Everyone's stabs, keyed by Player (never by a character Instance in a weak table).
	local stabs = {} -- Player -> { rec, character, trail, track }

	local function playStab(p)
		local character = p.Character
		local rig = character and CarryMath.rig(character)
		if not (rig and rig.kind == "R15") then
			return
		end
		local s = stabs[p]
		if not s or s.character ~= character then
			if s then
				StabMotion.release(s.rec)
			end
			s = { rec = StabMotion.new(rig), character = character }
			stabs[p] = s
		end
		StabMotion.play(s.rec, os.clock())
		if Animations.Stab ~= "" then
			local humanoid = character:FindFirstChildOfClass("Humanoid")
			local animator = humanoid and humanoid:FindFirstChildOfClass("Animator")
			if animator and not s.track then
				local animation = Instance.new("Animation")
				animation.AnimationId = Animations.Stab
				local ok, track = pcall(animator.LoadAnimation, animator, animation)
				if ok then
					track.Priority = Enum.AnimationPriority.Action
					s.track = track
				end
			end
			if s.track then
				s.track:Play(0.05)
			end
		end
	end

	require(script.Parent.Frame).on(30, function()
		local now = os.clock()
		for p, s in stabs do
			local character = s.character
			if not character.Parent or p.Parent == nil then
				stabs[p] = nil
			else
				local playing = StabMotion.step(s.rec, now, Animations.Stab == "")
				local knife = character:FindFirstChild("HuzzKnife")
				local trail = knife and knife:FindFirstChild("SlashTrail", true)
				if trail then
					trail.Enabled = playing and StabMotion.trailOn(s.rec, now)
				end
			end
		end
	end)

	RoundNet.OnClientEvent:Connect(function(kind, data)
		if kind == "Stab" and data.id ~= player.UserId then
			local p = Players:GetPlayerByUserId(data.id)
			if p then
				playStab(p)
			end
		end
	end)
	Players.PlayerRemoving:Connect(function(p)
		stabs[p] = nil
	end)

	-- What you can do right now.
	local lastStab, lastHuss = -math.huge, -math.huge
	local function busy()
		local c = player.Character
		return player:GetAttribute("MenuOpen") == true or c == nil or c:GetAttribute("DownedAt") ~= nil
	end
	local function canStab()
		local c = player.Character
		return Config.TagMode == "Stab" and player:GetAttribute("HuzzRole") == "Catcher" and RoundNet:GetAttribute("Stage") == "Running"
			and c ~= nil and c:FindFirstChild("HuzzKnife") ~= nil and not busy()
			and (player:GetAttribute("DizzyUntil") or 0) <= Workspace:GetServerTimeNow() -- a popped Heart Shield
	end
	local function myGirl()
		for _, model in carried:GetChildren() do
			if model:GetAttribute("Carrier") == player.UserId then
				return model
			end
		end
		return nil
	end
	local function canHuss()
		return myGirl() ~= nil and not busy()
	end
	local function hussReady()
		return os.clock() - lastHuss >= Carry.Huss.Time + Config.HussCooldown
	end

	local function stab()
		if canStab() and os.clock() - lastStab >= Config.Stab.Cooldown then
			lastStab = os.clock()
			playStab(player)
			StabNet:FireServer()
		end
	end
	local function huss()
		local girl = myGirl()
		if girl and not busy() and hussReady() then
			lastHuss = os.clock()
			local at = Workspace:GetServerTimeNow()
			girl:SetAttribute("HussAt", at) -- on this screen at once; the server sets the same time for everyone
			HussNet:FireServer(at)
		end
	end

	UserInputService.InputBegan:Connect(function(input, processed)
		if processed or UserInputService:GetFocusedTextBox() then
			return
		end
		local t, key = input.UserInputType, input.KeyCode
		if t == Enum.UserInputType.MouseButton1 or key == Enum.KeyCode.ButtonR2 then
			stab()
		elseif key == Enum.KeyCode.H or key == Enum.KeyCode.ButtonX then
			huss()
		end
	end)

	-- On-screen buttons (the kit's periwinkle action style).
	local CONDENSED = Font.new("rbxasset://fonts/families/RobotoCondensed.json", Enum.FontWeight.Bold)
	local ACTION, ACTION_TOP, RIM = Color3.fromHex("7E7CEF"), Color3.fromHex("8C8CF6"), Color3.fromHex("1F2347")
	local SLATE = Color3.fromHex("556585")
	local gui = Instance.new("ScreenGui")
	gui.Name = "HuzzActions"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 4
	local touch = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled

	local function button(name, label, hint, y, onPress)
		local b = Instance.new("TextButton")
		b.Name = name
		b.AnchorPoint = Vector2.new(1, 1)
		b.Position = UDim2.new(1, -22, 1, y)
		b.Size = UDim2.fromOffset(if touch then 104 else 150, if touch then 104 else 58)
		b.BackgroundColor3 = Color3.new(1, 1, 1)
		b.AutoButtonColor = false
		b.Text = ""
		b.Visible = false
		b.Parent = gui
		local corner = Instance.new("UICorner")
		corner.CornerRadius = if touch then UDim.new(0.5, 0) else UDim.new(0, 10)
		corner.Parent = b
		local stroke = Instance.new("UIStroke")
		stroke.Thickness, stroke.Color = 2.5, RIM
		stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		stroke.Parent = b
		local gradient = Instance.new("UIGradient")
		gradient.Rotation = 90
		gradient.Parent = b
		local text = Instance.new("TextLabel")
		text.BackgroundTransparency = 1
		text.Size = UDim2.new(1, -10, if touch then 0.42 else 0.62, 0)
		text.Position = UDim2.new(0, 5, if touch then 0.24 else 0.06, 0)
		text.FontFace = CONDENSED
		text.Text = label
		text.TextScaled = true
		text.TextColor3 = Color3.new(1, 1, 1)
		text.Parent = b
		local textStroke = Instance.new("UIStroke")
		textStroke.Thickness, textStroke.Color = 1.5, RIM
		textStroke.Parent = text
		local small = Instance.new("TextLabel")
		small.BackgroundTransparency = 1
		small.Size = UDim2.new(1, -10, 0.26, 0)
		small.Position = UDim2.new(0, 5, if touch then 0.64 else 0.66, 0)
		small.FontFace = CONDENSED
		small.Text = if touch then "" else hint
		small.TextScaled = true
		small.TextColor3 = Color3.fromRGB(226, 228, 255)
		small.Parent = b
		b.Activated:Connect(onPress)
		local function paint(ready)
			local top, bottom = if ready then ACTION_TOP else SLATE:Lerp(Color3.new(1, 1, 1), 0.08), if ready then ACTION else SLATE
			gradient.Color = ColorSequence.new(top, bottom)
		end
		paint(true)
		return b, paint
	end
	local y0 = if touch then -150 else -110
	local stabButton, paintStab = button("Stab", "STAB", "CLICK", y0, stab)
	local hussButton, paintHuss = button("Huss", "HUSS", "PRESS H", y0, huss)
	gui.Parent = player:WaitForChild("PlayerGui")

	RunService.RenderStepped:Connect(function()
		stabButton.Visible = canStab()
		hussButton.Visible = canHuss()
		if stabButton.Visible then
			paintStab(os.clock() - lastStab >= Config.Stab.Cooldown)
		end
		if hussButton.Visible then
			paintHuss(hussReady())
		end
	end)
end

return M

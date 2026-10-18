--[[
	The catchers' move: STAB (while a round runs): left click, a gamepad's R2, or the STAB button.
	It plays at once on your own screen; the runner inside your knife's reach on your screen (Gameplay/HitCheck,
	"make hitboxes pinpoint") is sent to the server (RoundService), which checks it's possible and tags them. (The girl toss is gone: owner's call.)

	Also plays everyone's stab (Shared/StabMotion, or Config/Animations.Stab when set), the Practice Bot's
	too (RoundService sends "Stab" with bot = true), and lights the knife's slash trail. Buttons sit bottom right, above a phone's jump
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
	local Animations = require(Shared.Config.Animations)
	local CarryMath = require(Shared.CarryMath)
	local StabMotion = require(Shared.StabMotion)
	local Sfx = require(script.Parent.Sfx)
	local HitCheck = require(script.Parent.HitCheck)

	local player = Players.LocalPlayer
	local RoundNet = Net.get("Round") :: RemoteEvent
	local StabNet = Net.get("Stab") :: RemoteEvent

	-- Everyone's stabs, keyed by Player, or "bot" for the Practice Bot (never by a character Instance in a weak table).
	local stabs = {} -- Player | "bot" -> { rec, character, trail, track }

	-- ago: how far into the move to start (the bot's stab arrives after its hit, so it starts near the thrust)
	-- lunge: the Space leap (the slash, then a dive into the leap's direction: Shared/StabMotion)
	local function playStab(p, model: Model?, ago: number?, lunge: boolean?)
		local character = model or (typeof(p) == "Instance" and (p :: Player).Character or nil)
		local rig = character and CarryMath.rig(character)
		if not (rig and rig.kind == "R15") then
			return
		end
		local s = stabs[p]
		if not s or s.character ~= character then
			if s then
				StabMotion.release(s.rec)
			end
			s = { rec = StabMotion.new(rig, character:FindFirstChild("HumanoidRootPart")), character = character }
			stabs[p] = s
		end
		StabMotion.play(s.rec, os.clock() - (ago or 0), lunge)
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
			if not character.Parent or (typeof(p) == "Instance" and p.Parent == nil) then
				stabs[p] = nil
			else
				local root = s.rec.root
				if s.rec.lunge and root then -- the dive leans the way the body is flying (forward or sideways)
					local v = root.CFrame:VectorToObjectSpace(root.AssemblyLinearVelocity)
					if Vector3.new(v.X, 0, v.Z).Magnitude > 8 then StabMotion.setDive(s.rec, v) end
				end
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
		if kind == "Stab" and data.bot then
			local CollectionService = game:GetService("CollectionService")
			local bot = CollectionService:GetTagged("HuzzBot")[1]
			if bot and bot:IsA("Model") then
				playStab("bot", bot, if data.hit then 0.12 else 0)
			end
		elseif kind == "Stab" and (data.id ~= player.UserId or data.lunge) then
			local p = Players:GetPlayerByUserId(data.id)
			if p then
				playStab(p, nil, 0, data.lunge == true)
			end
		end
	end)
	Players.PlayerRemoving:Connect(function(p)
		stabs[p] = nil
	end)

	-- What you can do right now.
	local lastStab = -math.huge
	local function busy()
		local c = player.Character
		return player:GetAttribute("MenuOpen") == true or c == nil or c:GetAttribute("DownedAt") ~= nil
	end
	local function canStab()
		local c = player.Character
		local stage = RoundNet:GetAttribute("Stage")
		return Config.TagMode == "Stab" and player:GetAttribute("HuzzRole") == "Catcher" and (stage == "Running" or stage == "HeroRun")
			and player:GetAttribute("HuzzFrozen") ~= true
			and c ~= nil and c:FindFirstChild("HuzzKnife") ~= nil and not busy()
			and (player:GetAttribute("DizzyUntil") or 0) <= Workspace:GetServerTimeNow() -- a popped Heart Shield
	end
	local function stab()
		if canStab() and os.clock() - lastStab >= Config.Stab.Cooldown then
			lastStab = os.clock()
			playStab(player)
			Sfx.play("stab")
			-- pinpoint (Gameplay/HitCheck): the runner inside your knife's reach on your screen, now or while the
			-- blade comes round (0.1 s); false = a clean miss; nothing sent = this build can't check
			local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
			if not root then
				StabNet:FireServer()
				return
			end
			local S = Config.Stab
			local hit = HitCheck.find(root, S.Reach, S.Width)
			if hit == false then
				StabNet:FireServer()
				return
			end
			if hit then
				StabNet:FireServer(hit)
				return
			end
			task.spawn(function()
				local t0 = os.clock()
				while os.clock() - t0 < 0.1 do
					RunService.Heartbeat:Wait()
					local found = root.Parent and HitCheck.find(root, S.Reach, S.Width)
					if found then
						StabNet:FireServer(found)
						return
					end
				end
				StabNet:FireServer(false)
			end)
		end
	end
	UserInputService.InputBegan:Connect(function(input, processed)
		if processed or UserInputService:GetFocusedTextBox() then
			return
		end
		local t, key = input.UserInputType, input.KeyCode
		if t == Enum.UserInputType.MouseButton1 or key == Enum.KeyCode.ButtonR2 then
			stab()
		end
	end)

	-- On-screen buttons (the kit's periwinkle action style).
	local Theme = require(script.Parent.Parent.UI.Theme)
	local DISPLAY = Theme.Fonts.Heading -- (the kit's faces)
	local ROUNDED = Theme.Fonts.Button
	local C = Theme.Colors
	local ACTION, ACTION_TOP, RIM = C.Action, C.ActionTop, C.ActionRim
	local SLATE = C.Slate
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
		text.FontFace = DISPLAY
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
		small.FontFace = ROUNDED
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
	gui.Parent = player:WaitForChild("PlayerGui")

	RunService.RenderStepped:Connect(function()
		stabButton.Visible = canStab()
		if stabButton.Visible then
			paintStab(os.clock() - lastStab >= Config.Stab.Cooldown)
		end
	end)
end

return M

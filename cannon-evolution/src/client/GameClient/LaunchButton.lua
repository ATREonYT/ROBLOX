--[[
	LaunchButton  (ModuleScript, started by Effects)
	Stone Skipping's THROW zone, our way (Alex, Oct 30: "feel and operate like it"): stand in the
	Launch Zone at the end of the dock and a big green LAUNCH button pops up just over your head.
	Tap it (or press E) to fire; it comes back about a second after you're home, so you can keep
	launching from the same spot. Back home, your cash floats up over your head like their "+1 trophy".
	The server checks you really are in the zone (GameServer "Launch").
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Remotes = ReplicatedStorage:WaitForChild("Remotes")

return function(ctx)
	local Kit, Config, State = ctx.Kit, ctx.Config, ctx.State
	local new = Kit.new
	local player = Players.LocalPlayer

	local zone = workspace:WaitForChild("LaunchZone", 30)
	if not zone then
		warn("[LaunchButton] no LaunchZone in Workspace")
		return
	end

	-- the button: a fixed size on screen (pixels), floating over your character
	local board = new("BillboardGui", {
		Name = "LaunchButton", Size = UDim2.fromOffset(196, 78), StudsOffset = Vector3.new(0, 4.4, 0),
		AlwaysOnTop = true, Active = true, LightInfluence = 0, ResetOnSpawn = false, Enabled = false,
		Parent = player:WaitForChild("PlayerGui"),
	})
	local btn = Kit.card({ Button = true, Name = "Launch", Color = Kit.Colors.Green, Color2 = Kit.Colors.GreenDark, Size = UDim2.fromScale(1, 1), Radius = 14, StrokeSize = 4, ZIndex = 2, Parent = board })
	Kit.movingPattern(btn, { Lite = true, Texture = "StudTile", Speed = 0, ImageTransparency = 0.8, ZIndex = 2, Radius = 14 })
	Kit.text({ Text = "LAUNCH", Size = 46, StrokeSize = 4.5, FrameSize = UDim2.fromScale(1, 1), Position = UDim2.fromOffset(0, -2), ZIndex = 4, Parent = btn })
	if UserInputService.KeyboardEnabled and not UserInputService.TouchEnabled then
		-- the key, in a little chip on the corner
		local chip = Kit.card({ Name = "Key", Color = Kit.Colors.White, Color2 = Kit.Colors.Gray, Size = UDim2.fromOffset(30, 30), Position = UDim2.new(1, -8, 0, -10), Anchor = Vector2.new(0.5, 0), Radius = 8, StrokeSize = 3, ZIndex = 5, Parent = btn })
		Kit.text({ Text = "E", Size = 22, Color = Kit.Colors.Outline, Stroke = false, ZIndex = 6, Parent = chip })
	end
	local scale = Kit.scale(btn)

	local function adorn(char)
		board.Adornee = char:WaitForChild("HumanoidRootPart", 10)
	end
	if player.Character then
		task.spawn(adorn, player.Character)
	end
	player.CharacterAdded:Connect(adorn)

	local function inZone()
		local root = board.Adornee
		if not (root and root.Parent) then
			return false
		end
		local rel = zone.CFrame:PointToObjectSpace(root.Position)
		return math.abs(rel.X) <= zone.Size.X / 2 + 1 and math.abs(rel.Z) <= zone.Size.Z / 2 + 1 and rel.Y > -2 and rel.Y < 9
	end

	local pressedAt = -10
	local homeAt = -10 -- when you got back from your last launch
	local function fire()
		if not board.Enabled then
			return
		end
		pressedAt = os.clock()
		Kit.press(btn, 0.85)
		Kit.playSound("Click")
		board.Enabled = false
		ctx.Request("Launch")
	end
	btn.Activated:Connect(fire)
	UserInputService.InputBegan:Connect(function(input, processed)
		if not processed and (input.KeyCode == Enum.KeyCode.E or input.KeyCode == Enum.KeyCode.ButtonX) then
			fire()
		end
	end)

	player:GetAttributeChangedSignal("Launching"):Connect(function()
		if player:GetAttribute("Launching") ~= true then
			homeAt = os.clock()
		end
	end)

	-- show it while you stand in the zone; pop in when it appears, then a slow breath (no flashing)
	local shown, poppedAt = false, -10
	RunService.Heartbeat:Connect(function()
		local now = os.clock()
		local want = inZone()
			and player:GetAttribute("Launching") ~= true
			and State.Training == nil
			and now - pressedAt > 1.2 -- the server's answer is on its way
			and now - homeAt > 0.9 -- a beat after landing home, like Stone Skipping
		if want ~= shown then
			shown = want
			board.Enabled = want
			if want then
				poppedAt = now
				scale.Scale = 0.5
				Kit.tween(scale, 0.35, { Scale = 1 }, Enum.EasingStyle.Back)
			end
		end
		if shown and now - poppedAt > 0.4 then
			-- one gentle grow-and-settle a second
			scale.Scale = 1 + 0.03 * (1 - math.cos((now - poppedAt) * 2 * math.pi))
		end
	end)

	-- back home: your cash floats up over your head (their "+1 trophy")
	local pending
	Remotes.LaunchResult.OnClientEvent:Connect(function(_, cash)
		pending = cash
	end)
	player:GetAttributeChangedSignal("Launching"):Connect(function()
		local root = board.Adornee
		if player:GetAttribute("Launching") == true or not pending or not root then
			return
		end
		local cash = pending
		pending = nil
		local pop = new("BillboardGui", {
			Name = "CashPop", Size = UDim2.fromOffset(260, 56), StudsOffset = Vector3.new(0, 3.2, 0),
			AlwaysOnTop = true, LightInfluence = 0, Adornee = root, Parent = player.PlayerGui,
		})
		local label = Kit.text({ Text = "+$" .. Config.Format(cash), Size = 44, StrokeSize = 4.5, Color = Kit.Colors.Green, Parent = pop })
		local s = Kit.scale(label)
		s.Scale = 0.4
		Kit.tween(s, 0.3, { Scale = 1 }, Enum.EasingStyle.Back)
		TweenService:Create(pop, TweenInfo.new(1.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { StudsOffset = Vector3.new(0, 6, 0) }):Play()
		task.delay(0.6, function()
			TweenService:Create(label, TweenInfo.new(0.5), { TextTransparency = 1 }):Play()
			local stroke = label:FindFirstChildOfClass("UIStroke")
			if stroke then
				TweenService:Create(stroke, TweenInfo.new(0.5), { Transparency = 1 }):Play()
			end
		end)
		task.delay(1.2, function()
			pop:Destroy()
		end)
	end)
end

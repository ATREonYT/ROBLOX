--[[
	BallStand  (ModuleScript)
	The cannonball stand in the lobby (workspace.CannonBallStand, built by
	src/tools/BuildCannonBallStand.lua): one cannonball floats on each pad.
	Walk up and press to buy it with Cash, or to pick it once you own it.
	The picked pad glows green, every other pad purple, and switching fades
	the colours and hops the new ball (Alex, Oct 30).
	Balls come from ReplicatedStorage.CannonBalls (a model named like the
	ball's Id) when Alex's are there, otherwise a simple ball is built here.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

local BALL_SIZE = 2.6
local HOVER = 0.5 -- gap between the pad and the ball
local FADE = TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

-- pad colours by part: [name] = { picked, not picked }; StateTop comes in a neon and a plain layer
local GREEN, PURPLE = 1, 2
local PALETTE = {
	StateGlow = { Color3.fromRGB(150, 250, 172), Color3.fromRGB(205, 170, 255) },
	StateMat = { Color3.fromRGB(116, 222, 146), Color3.fromRGB(175, 140, 245) },
	StateStrip = { Color3.fromRGB(26, 156, 64), Color3.fromRGB(120, 55, 205) },
	StateShade = { Color3.fromRGB(27, 153, 68), Color3.fromRGB(95, 40, 170) },
	StateTopNeon = { Color3.fromRGB(64, 220, 104), Color3.fromRGB(170, 95, 255) },
	StateTop = { Color3.fromRGB(64, 220, 104), Color3.fromRGB(150, 80, 235) },
}

return function(ctx)
	local Kit, Config, State = ctx.Kit, ctx.Config, ctx.State
	local new = Kit.new

	local stand = workspace:WaitForChild("CannonBallStand", 30)
	if not stand then
		warn("[BallStand] no CannonBallStand in Workspace")
		return
	end

	-- pads in Config.Balls order: lower row first, left to right as you face the stand (+X first)
	local pads = {}
	for _, p in ipairs(stand:GetChildren()) do
		if p.Name == "PadBase" then
			table.insert(pads, p)
		end
	end
	table.sort(pads, function(a, b)
		if math.abs(a.Position.Y - b.Position.Y) > 1 then
			return a.Position.Y < b.Position.Y
		end
		return a.Position.X > b.Position.X
	end)

	local function partsOn(pad)
		local list = {}
		for _, p in ipairs(stand:GetChildren()) do
			if p:IsA("BasePart") and string.sub(p.Name, 1, 5) == "State" then
				local d = p.Position - pad.Position
				if math.abs(d.Y) < 1.5 and Vector2.new(d.X, d.Z).Magnitude < 3.2 then
					local key = p.Name == "StateTop" and p.Material == Enum.Material.Neon and "StateTopNeon" or p.Name
					if PALETTE[key] then
						table.insert(list, { Part = p, Colors = PALETTE[key] })
					end
				end
			end
		end
		return list
	end

	local imported = ReplicatedStorage:FindFirstChild("CannonBalls")
	local function buildBall(info)
		local m = imported and imported:FindFirstChild(info.Id)
		if m and (m:IsA("Model") or m:IsA("BasePart")) then
			m = m:Clone()
			if m:IsA("BasePart") then
				local wrap = Instance.new("Model")
				m.Parent = wrap
				wrap.PrimaryPart = m
				m = wrap
			end
			local _, size = m:GetBoundingBox()
			m:ScaleTo(m:GetScale() * BALL_SIZE / math.max(size.X, size.Y, size.Z))
		else
			-- cartoony stand-in: ball, a band round the middle, a cap on top and a soft shine
			m = Instance.new("Model")
			local core = new("Part", { Name = "Core", Shape = Enum.PartType.Ball, Size = Vector3.one * BALL_SIZE, Color = info.Color, Material = Enum.Material.SmoothPlastic, Parent = m })
			new("Part", { Name = "Band", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.45, BALL_SIZE * 1.04, BALL_SIZE * 1.04), Color = info.Band, Material = Enum.Material.SmoothPlastic, CFrame = CFrame.Angles(0, math.rad(90), 0), Parent = m })
			new("Part", { Name = "Cap", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.35, 0.8, 0.8), Color = info.Band, Material = Enum.Material.SmoothPlastic, CFrame = CFrame.new(0, BALL_SIZE / 2, 0) * CFrame.Angles(0, 0, math.rad(90)), Parent = m })
			new("Part", { Name = "Shine", Shape = Enum.PartType.Ball, Size = Vector3.one * 0.55, Color = Color3.new(1, 1, 1), Material = Enum.Material.SmoothPlastic, Transparency = 0.25, CFrame = CFrame.new(-0.55, 0.75, -0.75), Parent = m })
			m.PrimaryPart = core
		end
		for _, p in ipairs(m:GetDescendants()) do
			if p:IsA("BasePart") then
				p.Anchored = true
				p.CanCollide = false
				p.CanQuery = false
				p.CanTouch = false
				p.CastShadow = false
			elseif p:IsA("Light") then
				p:Destroy() -- no light spilling round the stand (Alex, Oct 30)
			end
		end
		m.Name = "Ball_" .. info.Id
		return m
	end

	local folder = new("Folder", { Name = "StandBalls", Parent = workspace })
	local slots = {}
	for i, pad in ipairs(pads) do
		local info = Config.Balls[i]
		if not info then
			break
		end
		local slot = { Info = info, Parts = partsOn(pad), Hop = -10, Phase = i * 0.7 }
		slot.Base = pad.Position + Vector3.new(0, pad.Size.Z / 2 + HOVER + BALL_SIZE / 2, 0)
		slot.Model = buildBall(info)
		slot.Model:PivotTo(CFrame.new(slot.Base))
		slot.Model.Parent = folder

		-- name, bonus and price over the ball
		local anchor = new("Part", { Name = "Label_" .. info.Id, Size = Vector3.one * 0.2, Transparency = 1, Anchored = true, CanCollide = false, CanQuery = false, CanTouch = false, CFrame = CFrame.new(slot.Base + Vector3.new(0, BALL_SIZE / 2 + 1.4, 0)), Parent = folder })
		local bb = new("BillboardGui", { Size = UDim2.fromScale(5, 2), LightInfluence = 0, MaxDistance = 70, Parent = anchor })
		local name = new("TextLabel", { Size = UDim2.fromScale(1, 0.45), BackgroundTransparency = 1, Font = Enum.Font.FredokaOne, TextScaled = true, Text = info.Name, TextColor3 = Color3.new(1, 1, 1), Parent = bb })
		new("UIStroke", { Thickness = 2, Color = Color3.fromRGB(25, 15, 40), Parent = name })
		slot.Status = new("TextLabel", { Size = UDim2.fromScale(1, 0.4), Position = UDim2.fromScale(0, 0.5), BackgroundTransparency = 1, Font = Enum.Font.FredokaOne, TextScaled = true, Text = "", TextColor3 = Kit.Colors.Yellow, Parent = bb })
		new("UIStroke", { Thickness = 2, Color = Color3.fromRGB(25, 15, 40), Parent = slot.Status })

		slot.Prompt = new("ProximityPrompt", {
			ObjectText = info.Name .. " Cannonball", ActionText = "Pick", HoldDuration = 0,
			MaxActivationDistance = 9, RequiresLineOfSight = false, Parent = anchor,
		})
		slot.Prompt.Triggered:Connect(function()
			local data = State.Data
			if not data then
				return
			end
			if data.Balls[info.Id] then
				if data.EquippedBall ~= info.Id then
					ctx.Request("EquipBall", info.Id)
				end
			else
				ctx.Request("BuyBall", info.Id)
			end
		end)

		-- a puff of sparkles when this ball gets picked
		slot.Burst = new("ParticleEmitter", {
			Texture = "rbxasset://textures/particles/sparkles_main.dds", Enabled = false, Rate = 0,
			Color = ColorSequence.new(PALETTE.StateGlow[GREEN]), Lifetime = NumberRange.new(0.5, 0.9),
			Speed = NumberRange.new(4, 8), SpreadAngle = Vector2.new(180, 180), Size = NumberSequence.new(0.6, 0),
			Parent = anchor,
		})
		slots[i] = slot
	end

	local picked
	local function refresh(first)
		local data = State.Data
		if not data then
			return
		end
		for _, slot in ipairs(slots) do
			local id = slot.Info.Id
			local owned = data.Balls[id] == true
			local isPicked = data.EquippedBall == id
			local bonus = slot.Info.CashBonus > 0 and ("+" .. math.floor(slot.Info.CashBonus * 100 + 0.5) .. "% Cash") or ""
			slot.Status.Text = isPicked and "✅ PICKED" or owned and (bonus ~= "" and bonus or "OWNED") or ("💵 " .. Config.Format(slot.Info.Price) .. (bonus ~= "" and ("  " .. bonus) or ""))
			slot.Status.TextColor3 = isPicked and Color3.fromRGB(120, 255, 150) or owned and Color3.new(1, 1, 1) or Kit.Colors.Yellow
			slot.Prompt.ActionText = isPicked and "Picked" or owned and "Pick" or ("Buy  " .. Config.Format(slot.Info.Price))
			slot.Prompt.Enabled = not isPicked
			for _, entry in ipairs(slot.Parts) do
				local color = entry.Colors[isPicked and GREEN or PURPLE]
				if first then
					entry.Part.Color = color
				elseif entry.Part.Color ~= color then
					TweenService:Create(entry.Part, FADE, { Color = color }):Play()
				end
			end
		end
		if data.EquippedBall ~= picked then
			for _, slot in ipairs(slots) do
				if slot.Info.Id == data.EquippedBall and not first then
					slot.Hop = os.clock()
					slot.Burst:Emit(14)
					Kit.playSound("Reward")
				end
			end
			picked = data.EquippedBall
		end
	end
	State.Changed:Connect(function()
		refresh(false)
	end)
	task.spawn(function()
		State.WaitForData()
		refresh(true)
	end)

	-- slow spin and bob; the picked ball spins faster and hops when it's chosen
	RunService.RenderStepped:Connect(function()
		local t = os.clock()
		for _, slot in ipairs(slots) do
			local isPicked = slot.Info.Id == picked
			local h = t - slot.Hop
			local hop = h < 0.6 and math.sin(h / 0.6 * math.pi) * 1.4 or 0
			local y = math.sin(t * 2 + slot.Phase) * 0.15 + hop
			local spin = t * (isPicked and 1.6 or 0.5) + slot.Phase
			slot.Model:PivotTo(CFrame.new(slot.Base + Vector3.new(0, y, 0)) * CFrame.Angles(0, spin, math.rad(12)))
		end
	end)
end

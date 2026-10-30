--[[
	BuildRebirthSigns: paste into the Command Bar once (already run in the place).
	Hangs a rebirth sign on the wall over each training area, showing the
	rebirths it needs and the Power multiplier it gives. The client fills in
	the rebirth icon (Icons.RebirthSign) and the LOCKED / UNLOCKED ribbon.
	Safe to run again: it replaces each station's RebirthSign.
]]

local Config = require(game.ReplicatedStorage.GameConfig)

local WALL_Z = -202.3 -- the lobby wall behind the training targets
local BOARD = Vector2.new(11, 22 / 3) -- fits the 12-stud booth spacing
local CENTRE_Y = 26
local PPS = 600 / 11 -- SurfaceGui pixels per stud; keeps the 600 x 400 layout

local function new(class, props)
	local i = Instance.new(class)
	for k, v in pairs(props) do
		if k ~= "Parent" then
			i[k] = v
		end
	end
	i.Parent = props.Parent
	return i
end

local function stroke(parent, thickness, color)
	return new("UIStroke", { Thickness = thickness, Color = color or Color3.fromRGB(25, 15, 40), ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = parent })
end

local function label(parent, text, props)
	local l = new("TextLabel", {
		BackgroundTransparency = 1,
		Font = Enum.Font.FredokaOne,
		TextScaled = true,
		Text = text,
		TextColor3 = props.Color or Color3.new(1, 1, 1),
		Size = props.Size,
		Position = props.Position or UDim2.new(),
		AnchorPoint = props.Anchor or Vector2.zero,
		TextXAlignment = props.AlignX or Enum.TextXAlignment.Center,
		Name = props.Name or "Label",
		ZIndex = props.ZIndex or 3,
		Parent = parent,
	})
	new("UIStroke", { Thickness = props.StrokeSize or 5, Color = Color3.fromRGB(25, 15, 40), Parent = l })
	return l
end

for _, info in ipairs(Config.Stations) do
	local station = workspace.TrainingStations:FindFirstChild("Station_" .. info.Id)
	if station then
		for _, name in ipairs({ "RebirthSign", "Sign" }) do -- Sign: the old floating billboard
			local old = station:FindFirstChild(name)
			if old then
				old:Destroy()
			end
		end
		local x = station.Pad.Position.X
		local accent = info.Pass and Color3.fromRGB(190, 80, 255) or Color3.fromRGB(70, 200, 255)

		local board = new("Part", {
			Name = "RebirthSign",
			Anchored = true,
			CanCollide = false,
			CanQuery = false,
			CanTouch = false,
			CastShadow = false,
			Size = Vector3.new(BOARD.X, BOARD.Y, 0.4),
			CFrame = CFrame.lookAt(Vector3.new(x, CENTRE_Y, WALL_Z), Vector3.new(x, CENTRE_Y, WALL_Z + 1)),
			Transparency = 1,
		})
		board:SetAttribute("Rebirths", info.Rebirths)
		board:SetAttribute("Pass", info.Pass)
		local glow = new("PointLight", { Color = accent, Range = 16, Brightness = 1.5, Parent = board })
		glow.Name = "Glow"

		local gui = new("SurfaceGui", {
			Name = "Gui",
			Face = Enum.NormalId.Front,
			LightInfluence = 0,
			SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud,
			PixelsPerStud = PPS,
			Parent = board,
		})
		local W, H = BOARD.X * PPS, BOARD.Y * PPS

		-- card: dark body, chunky outline, glossy accent gradient
		local card = new("Frame", { Name = "Card", Size = UDim2.new(1, -24, 1, -24), Position = UDim2.fromOffset(12, 12), BackgroundColor3 = Color3.fromRGB(40, 30, 70), Parent = gui })
		new("UICorner", { CornerRadius = UDim.new(0, 40), Parent = card })
		stroke(card, 12)
		new("UIGradient", {
			Rotation = 90,
			Color = ColorSequence.new(accent:Lerp(Color3.new(1, 1, 1), 0.15), accent:Lerp(Color3.new(0, 0, 0), 0.55)),
			Parent = card,
		})
		local shine = new("Frame", { Name = "Shine", Size = UDim2.new(1, -40, 0.32, 0), Position = UDim2.fromOffset(20, 14), BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 0.82, ZIndex = 2, Parent = card })
		new("UICorner", { CornerRadius = UDim.new(0, 28), Parent = shine })

		-- name across the top
		label(card, info.Name, { Name = "Title", Size = UDim2.new(1, -60, 0, 70), Position = UDim2.new(0.5, 0, 0, 18), Anchor = Vector2.new(0.5, 0) })

		-- rebirth icon (filled by the client) with an emoji until the image is uploaded
		local iconSize = 190
		local icon = new("ImageLabel", {
			Name = "Icon",
			BackgroundTransparency = 1,
			ScaleType = Enum.ScaleType.Fit,
			Size = UDim2.fromOffset(iconSize, iconSize),
			Position = UDim2.fromOffset(34, 96),
			ZIndex = 3,
			Parent = card,
		})
		icon:SetAttribute("Icon", info.Pass and "VIP" or "RebirthSign")
		label(icon, info.Pass and "⭐" or "🔄", { Name = "Fallback", Size = UDim2.fromScale(1, 1), StrokeSize = 0 })

		-- what it needs, and what it gives
		local need = info.Pass and "GAMEPASS" or info.Rebirths == 0 and "FREE" or (info.Rebirths .. (info.Rebirths == 1 and " Rebirth" or " Rebirths"))
		label(card, need, {
			Name = "Need",
			Size = UDim2.new(1, -(iconSize + 70), 0, 96),
			Position = UDim2.fromOffset(iconSize + 50, 100),
			AlignX = Enum.TextXAlignment.Left,
			Color = info.Pass and Color3.fromRGB(255, 215, 80) or Color3.new(1, 1, 1),
			StrokeSize = 6,
		})
		local pill = new("Frame", { Name = "Multiplier", Size = UDim2.new(1, -(iconSize + 70), 0, 82), Position = UDim2.fromOffset(iconSize + 50, 200), BackgroundColor3 = Color3.fromRGB(255, 200, 40), ZIndex = 3, Parent = card })
		new("UICorner", { CornerRadius = UDim.new(0.5, 0), Parent = pill })
		stroke(pill, 6)
		new("UIGradient", { Rotation = 90, Color = ColorSequence.new(Color3.fromRGB(255, 235, 110), Color3.fromRGB(255, 160, 20)), Parent = pill })
		label(pill, "x" .. Config.Format(info.Gain) .. " ⚡ Power", { Name = "Text", Size = UDim2.new(1, -24, 1, -14), Position = UDim2.fromScale(0.5, 0.5), Anchor = Vector2.new(0.5, 0.5), ZIndex = 4 })

		-- LOCKED / UNLOCKED ribbon along the bottom (the client keeps it current)
		local ribbon = new("Frame", { Name = "Status", Size = UDim2.new(0.6, 0, 0, 62), Position = UDim2.new(0.5, 0, 1, -16), AnchorPoint = Vector2.new(0.5, 1), BackgroundColor3 = Color3.fromRGB(235, 60, 60), ZIndex = 3, Parent = card })
		new("UICorner", { CornerRadius = UDim.new(0.5, 0), Parent = ribbon })
		stroke(ribbon, 6)
		label(ribbon, info.Rebirths == 0 and not info.Pass and "✅ UNLOCKED" or "🔒 LOCKED", { Name = "Text", Size = UDim2.new(1, -20, 1, -12), Position = UDim2.fromScale(0.5, 0.5), Anchor = Vector2.new(0.5, 0.5), ZIndex = 4 })

		-- frame the sign on the wall with two neon brackets
		for _, side in ipairs({ -1, 1 }) do
			new("Part", {
				Name = "Bracket",
				Anchored = true,
				CanCollide = false,
				CanQuery = false,
				CastShadow = false,
				Material = Enum.Material.Neon,
				Color = accent,
				Size = Vector3.new(0.6, BOARD.Y - 1, 0.6),
				CFrame = board.CFrame * CFrame.new(side * (BOARD.X / 2 + 0.2), 0, 0.1),
				Parent = board,
			})
		end
		board.Parent = station
	end
end
print("[BuildRebirthSigns] signs placed over " .. #workspace.TrainingStations:GetChildren() .. " training areas")

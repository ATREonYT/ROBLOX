--[[
	BuildRebirthSigns: paste into the Command Bar after BuildWorld1.
	One label per training lane, like Stone Skipping's (Alex, Oct 31): the same size, at the same height
	over the far end of every lane, three lines stacked the same way on each:
	  - a dark pill with the rebirth icon and the rebirths the lane needs (VIP for the pass lane)
	  - UNLOCKED in green or LOCKED in red (the client sets it for each player, Effects.lua)
	  - the power it gives, big: "5x POWER"
	Sized like the reference (measured on its label): the pill a little wider than the power line and
	about 1.6 times as tall as its letters, the LOCKED line about two thirds of the power line.
	It replaces the floating rebirth tiles and the separate "x20" tags.
	Safe to run again: it replaces each station's RebirthSign.
]]

local Config = require(game.ReplicatedStorage.GameConfig)

local WIDE, TALL = 9, 6.4 -- studs: the label's size, the same on every lane
local HEIGHT = 9 -- studs over the stand pad: the same on every lane, just over the low lane (Oct 31)

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
		Name = props.Name or "Label",
		ZIndex = props.ZIndex or 3,
		Parent = parent,
	})
	new("UIStroke", { Thickness = props.StrokeSize or 4, Color = Color3.fromRGB(25, 15, 40), Parent = l })
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
		-- over the target (the lane's far end), at the same height on every lane
		local target = station:FindFirstChild("Target")
		local over = target and target:FindFirstChild("Center") and target.Center.Position or station.Pad.Position
		local board = new("Part", {
			Name = "RebirthSign",
			Anchored = true,
			CanCollide = false,
			CanQuery = false,
			CanTouch = false,
			CastShadow = false,
			Size = Vector3.one * 0.2,
			CFrame = CFrame.new(over.X, station.Pad.Position.Y + HEIGHT, over.Z),
			Transparency = 1,
		})
		board:SetAttribute("Rebirths", info.Rebirths)
		board:SetAttribute("Pass", info.Pass)

		local gui = new("BillboardGui", {
			Name = "Gui",
			Size = UDim2.fromScale(WIDE, TALL),
			LightInfluence = 0,
			MaxDistance = 220,
			Parent = board,
		})
		local card = new("Frame", { Name = "Card", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Parent = gui })

		-- 1. the pill: rebirth icon (filled by the client; an emoji until then) and the rebirths needed
		local pill = new("Frame", {
			Name = "Pill",
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.fromScale(0.5, 0),
			Size = UDim2.fromScale(0.86, 0.36), -- wider than the power line, like the reference's
			BackgroundColor3 = Color3.fromRGB(20, 18, 30),
			BackgroundTransparency = 0.2,
			ZIndex = 1,
			Parent = card,
		})
		new("UICorner", { CornerRadius = UDim.new(0.5, 0), Parent = pill })
		new("UIStroke", { Thickness = 2, Color = Color3.fromRGB(255, 255, 255), Transparency = 0.6, Parent = pill })
		local icon = new("ImageLabel", {
			Name = "Icon",
			BackgroundTransparency = 1,
			ScaleType = Enum.ScaleType.Fit,
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.fromScale(0.1, 0.18),
			Size = UDim2.fromScale(0.22, 0.34),
			ZIndex = 2,
			Parent = card,
		})
		icon:SetAttribute("Icon", info.Pass and "VIP" or "RebirthSign")
		label(icon, info.Pass and "⭐" or "🔄", { Name = "Fallback", Size = UDim2.fromScale(1, 1), StrokeSize = 0 })
		label(card, info.Pass and "VIP" or tostring(info.Rebirths), {
			Name = "Number",
			Anchor = Vector2.new(0, 0.5),
			Position = UDim2.fromScale(0.35, 0.18),
			Size = UDim2.fromScale(0.48, 0.25),
			StrokeSize = 3,
			ZIndex = 4,
		})

		-- 2. LOCKED / UNLOCKED (Effects.lua sets the words and the colour for each player)
		local status = new("Frame", {
			Name = "Status",
			Position = UDim2.fromScale(0, 0.42),
			Size = UDim2.fromScale(1, 0.16),
			BackgroundTransparency = 1,
			Parent = card,
		})
		local open = info.Rebirths == 0 and not info.Pass
		label(status, open and "UNLOCKED" or "LOCKED", {
			Name = "Text",
			Size = UDim2.fromScale(1, 1),
			Color = open and Color3.fromRGB(110, 235, 100) or Color3.fromRGB(240, 70, 70),
			StrokeSize = 3,
		})

		-- 3. the power it gives
		label(card, Config.Format(info.Gain) .. "x POWER", {
			Name = "Multiplier",
			Size = UDim2.fromScale(0.78, 0.38),
			Position = UDim2.fromScale(0.5, 1),
			Anchor = Vector2.new(0.5, 1),
			StrokeSize = 5,
		})
		board.Parent = station
	end
end
print("[BuildRebirthSigns] one label over each of " .. #workspace.TrainingStations:GetChildren() .. " training lanes")

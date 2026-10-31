--[[
	BuildRebirthSigns: paste into the Command Bar after BuildWorld1.
	One label per training lane, like Stone Skipping's (Alex, Oct 31): the same size, at the same height
	over the far end of every lane, three lines stacked the same way on each:
	  - a dark pill with the rebirth icon and the rebirths the lane needs (for the gamepass lane: the Robux icon
	    and the pass's price in gold, Oct 31)
	  - UNLOCKED in green or LOCKED in red (the client sets it for each player, Effects.lua)
	  - the power it gives, big: "5x POWER"
	Sized like the reference (measured on its label): the pill a little wider than the power line and
	about 1.6 times as tall as its letters, the LOCKED line about two thirds of the power line.
	It replaces the floating rebirth tiles and the separate "x20" tags.
	Safe to run again: it replaces each station's RebirthSign.
]]

local Config = require(game.ReplicatedStorage.GameConfig)

local WIDE, TALL = 9, 6.4 -- studs: the label's size, the same on every lane (for lanes built at 0.9)
local HEIGHT = 9 -- studs over the stand pad: the same on every lane, just over the low lane (Oct 31)
-- the lanes grew with the 2x map (BuildWorld1 BOOTH_SCALE 1.25, Oct 31): the label grows with them
local TUNED_AT = 0.9

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
		local k = station:GetScale() / TUNED_AT * (info.Pass and 1.3 or 1) -- the gamepass lane's label is bigger
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
			CFrame = CFrame.new(over.X, station.Pad.Position.Y + HEIGHT * k, over.Z),
			Transparency = 1,
		})
		board:SetAttribute("Rebirths", info.Rebirths)
		board:SetAttribute("Pass", info.Pass)

		local gui = new("BillboardGui", {
			Name = "Gui",
			Size = UDim2.fromScale(WIDE * k, TALL * k),
			LightInfluence = 0,
			MaxDistance = 260,
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
		-- the gamepass lane's pill shows its Robux price in gold (Oct 31: "make it seem more buyable"); the price is
		-- the pass's own (GameConfig), never a made-up one
		local pass = info.Pass and Config.Passes[info.Pass]
		new("UIStroke", { Thickness = pass and 3 or 2, Color = pass and Color3.fromRGB(255, 205, 60) or Color3.fromRGB(255, 255, 255), Transparency = pass and 0 or 0.6, Parent = pill })
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
		icon:SetAttribute("Icon", pass and "Robux" or "RebirthSign")
		label(icon, pass and "R$" or "🔄", { Name = "Fallback", Size = UDim2.fromScale(1, 1), StrokeSize = 0 })
		label(card, pass and tostring(pass.Price) or tostring(info.Rebirths), {
			Color = pass and Color3.fromRGB(255, 215, 70) or nil,
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
			Position = UDim2.fromScale(0, 0.4),
			Size = UDim2.fromScale(1, 0.2),
			BackgroundTransparency = 1,
			Parent = card,
		})
		local open = info.Rebirths == 0 and not info.Pass
		-- the gamepass lane says GAMEPASS in gold until you own it (Effects.lua keeps it so for each player)
		label(status, open and "UNLOCKED" or (pass and "GAMEPASS" or "LOCKED"), {
			Name = "Text",
			Size = UDim2.fromScale(1, 1),
			Color = open and Color3.fromRGB(110, 235, 100) or (pass and Color3.fromRGB(255, 215, 70) or Color3.fromRGB(240, 70, 70)),
			StrokeSize = 3,
		})

		-- 3. the power it gives
		label(card, Config.Format(info.Gain) .. "x POWER", {
			Name = "Multiplier",
			Color = pass and Color3.fromRGB(255, 215, 70) or nil, -- gold on the gamepass lane
			Size = UDim2.fromScale(0.78, 0.38),
			Position = UDim2.fromScale(0.5, 1),
			Anchor = Vector2.new(0.5, 1),
			StrokeSize = 5,
		})
		board.Parent = station
	end
end
print("[BuildRebirthSigns] one label over each of " .. #workspace.TrainingStations:GetChildren() .. " training lanes")

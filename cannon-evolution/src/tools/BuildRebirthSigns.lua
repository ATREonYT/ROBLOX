--[[
	BuildRebirthSigns: paste into the Command Bar once (already run in the place).
	Floats a rebirth sign over each training area: the rebirth icon with the
	rebirths it needs on it, and the Power multiplier underneath; nothing else
	(Alex, Oct 30: the old wall boards are gone). The client fills in the icon
	(Icons.RebirthSign) and dims it while the booth is locked.
	Safe to run again: it replaces each station's RebirthSign.
]]

local Config = require(game.ReplicatedStorage.GameConfig)

local SIGN = 7 -- studs across
local LIFT = 4.5 -- studs over the top of the booth

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
		-- over the middle of the booth, a little above its highest point
		local top = -math.huge
		local lo, hi = Vector3.new(math.huge, 0, math.huge), Vector3.new(-math.huge, 0, -math.huge)
		for _, p in ipairs(station:GetDescendants()) do
			if p:IsA("BasePart") and p.Transparency < 1 then
				top = math.max(top, p.Position.Y + p.Size.Y / 2)
				lo = Vector3.new(math.min(lo.X, p.Position.X), 0, math.min(lo.Z, p.Position.Z))
				hi = Vector3.new(math.max(hi.X, p.Position.X), 0, math.max(hi.Z, p.Position.Z))
			end
		end
		local x = station.Pad.Position.X
		local z = (lo.Z + hi.Z) / 2

		local board = new("Part", {
			Name = "RebirthSign",
			Anchored = true,
			CanCollide = false,
			CanQuery = false,
			CanTouch = false,
			CastShadow = false,
			Size = Vector3.one * 0.2,
			CFrame = CFrame.new(x, top + LIFT + SIGN / 2, z),
			Transparency = 1,
		})
		board:SetAttribute("Rebirths", info.Rebirths)
		board:SetAttribute("Pass", info.Pass)

		local gui = new("BillboardGui", {
			Name = "Gui",
			Size = UDim2.fromScale(SIGN, SIGN * 1.25),
			LightInfluence = 0,
			MaxDistance = 220,
			Parent = board,
		})
		local card = new("Frame", { Name = "Card", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Parent = gui })

		-- the rebirth icon (filled by the client), an emoji until then
		local icon = new("ImageLabel", {
			Name = "Icon",
			BackgroundTransparency = 1,
			ScaleType = Enum.ScaleType.Fit,
			Size = UDim2.fromScale(1, 0.8),
			ZIndex = 2,
			Parent = card,
		})
		icon:SetAttribute("Icon", info.Pass and "VIP" or "RebirthSign")
		label(icon, info.Pass and "⭐" or "🔄", { Name = "Fallback", Size = UDim2.fromScale(1, 1), StrokeSize = 0 })
		-- the rebirths it needs, big on the icon
		label(icon, info.Pass and "VIP" or tostring(info.Rebirths), {
			Name = "Number",
			Size = UDim2.fromScale(0.62, 0.42),
			Position = UDim2.fromScale(0.5, 0.5),
			Anchor = Vector2.new(0.5, 0.5),
			StrokeSize = 5,
			ZIndex = 4,
		})
		-- the multiplier it gives
		label(card, "x" .. Config.Format(info.Gain), {
			Name = "Multiplier",
			Size = UDim2.fromScale(0.9, 0.24),
			Position = UDim2.fromScale(0.5, 1),
			Anchor = Vector2.new(0.5, 1),
			Color = Color3.fromRGB(255, 220, 60),
			StrokeSize = 5,
		})
		board.Parent = station
	end
end
print("[BuildRebirthSigns] signs placed over " .. #workspace.TrainingStations:GetChildren() .. " training areas")

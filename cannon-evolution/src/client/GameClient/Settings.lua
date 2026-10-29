--[[
	Settings panel: toggles saved on the server, plus Redeem Code.
	Effects.lua applies the settings whenever data changes.
]]

return function(ctx)
	local Kit, State = ctx.Kit, ctx.State
	local new = Kit.new

	local OPTIONS = {
		{ Key = "Music", Name = "Music" },
		{ Key = "Sfx", Name = "Sound Effects" },
		{ Key = "ShowPlayers", Name = "Show Other Players" },
		{ Key = "ShowPets", Name = "Show Pets" },
		{ Key = "LowGraphics", Name = "Low Graphics" },
	}

	local panel = Kit.panel({ Title = "Settings", Icon = "Settings", Size = UDim2.fromOffset(600, 520) })
	local body = panel.Body
	local list = new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 1, -110), ZIndex = 23, Parent = body })
	Kit.list(list, 8)

	local toggles = {}
	for i, opt in ipairs(OPTIONS) do
		local row = Kit.card({ Color = Kit.Colors.Card, Size = UDim2.new(1, -8, 0, 60), Order = i, Parent = list, ZIndex = 24 })
		Kit.text({ Text = opt.Name, Size = 26, AlignX = Enum.TextXAlignment.Left, FrameSize = UDim2.new(1, -170, 1, 0), Position = UDim2.fromOffset(16, 0), ZIndex = 26, Parent = row })
		local btn
		btn = Kit.button({ Text = "ON", Color = "Green", Size = UDim2.fromOffset(120, 44), Position = UDim2.new(1, -12, 0.5, 0), Anchor = Vector2.new(1, 0.5), ZIndex = 27, Parent = row, OnClick = function()
			local value = not State.Data.Settings[opt.Key]
			State.Data.Settings[opt.Key] = value -- instant feedback; server confirms on next sync
			btn:SetText(value and "ON" or "OFF")
			btn:SetColor(value and "Green" or "Red")
			ctx.Request("SetSetting", opt.Key, value)
		end })
		toggles[opt.Key] = btn
	end

	-- Redeem code
	local codeRow = Kit.card({ Color = Kit.Colors.Purple, Color2 = Kit.Colors.PurpleDark, Position = UDim2.new(0, 0, 1, -96), Size = UDim2.new(1, -8, 0, 90), ZIndex = 24, Parent = body })
	Kit.movingPattern(codeRow, { Texture = "Stripes", Speed = 20, ImageTransparency = 0.75, ZIndex = 24 })
	Kit.text({ Text = "Redeem Code", Size = 22, AlignX = Enum.TextXAlignment.Left, FrameSize = UDim2.new(1, -20, 0, 26), Position = UDim2.fromOffset(14, 4), ZIndex = 26, Parent = codeRow })
	local box = new("TextBox", {
		BackgroundColor3 = Color3.new(1, 1, 1),
		PlaceholderText = "Enter code...",
		Text = "",
		Font = Kit.Font,
		TextSize = 24,
		TextColor3 = Color3.fromRGB(40, 40, 50),
		ClearTextOnFocus = false,
		Size = UDim2.new(1, -180, 0, 44),
		Position = UDim2.fromOffset(14, 34),
		ZIndex = 27,
		Parent = codeRow,
	})
	Kit.corner(10, box)
	Kit.stroke(3, nil, box)
	Kit.button({ Text = "Redeem", Color = "Green", Size = UDim2.fromOffset(140, 44), Position = UDim2.new(1, -14, 0, 34), Anchor = Vector2.new(1, 0), ZIndex = 27, Parent = codeRow, OnClick = function()
		if box.Text ~= "" then
			local ok = ctx.Request("RedeemCode", box.Text)
			if ok then
				box.Text = ""
			end
		end
	end })

	local function refresh()
		local data = State.Data
		if not data then
			return
		end
		for _, opt in ipairs(OPTIONS) do
			local on = data.Settings[opt.Key]
			toggles[opt.Key]:SetText(on and "ON" or "OFF")
			toggles[opt.Key]:SetColor(on and "Green" or "Red")
		end
	end

	return { Frame = panel.Frame, OnOpen = refresh, Refresh = refresh }
end

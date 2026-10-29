--[[
	Rebirth panel: Power + Cash requirements with progress bars, what you
	get, and the Rebirth / Skip Rebirth buttons.
]]

return function(ctx)
	local Kit, Config, State = ctx.Kit, ctx.Config, ctx.State
	local new = Kit.new

	local panel = Kit.panel({ Title = "Rebirth", Icon = "Rebirth", Size = UDim2.fromOffset(700, 500) })
	local body = panel.Body

	local count = Kit.text({ Text = "", Size = 30, Color = Kit.Colors.Yellow, FrameSize = UDim2.new(1, 0, 0, 34), ZIndex = 24, Parent = body })

	-- requirements
	local req = Kit.card({ Color = Kit.Colors.Card, Position = UDim2.fromOffset(0, 40), Size = UDim2.new(0.5, -6, 0, 250), ZIndex = 23, Parent = body })
	Kit.text({ Text = "Requirements", Size = 28, FrameSize = UDim2.new(1, 0, 0, 36), Position = UDim2.fromOffset(0, 6), ZIndex = 25, Parent = req })
	local function reqRow(y, icon, color, color2)
		Kit.icon(icon, { Size = UDim2.fromOffset(52, 52), Position = UDim2.fromOffset(12, y), ZIndex = 26, Parent = req })
		local label = Kit.text({ Text = "", Size = 22, AlignX = Enum.TextXAlignment.Left, FrameSize = UDim2.new(1, -84, 0, 24), Position = UDim2.fromOffset(72, y), ZIndex = 26, Parent = req })
		local bar = Kit.progress({ Parent = req, Position = UDim2.fromOffset(72, y + 28), Size = UDim2.new(1, -86, 0, 24), Color = color, Color2 = color2, ZIndex = 25 })
		return label, bar
	end
	local powerLabel, powerBar = reqRow(56, "Power", Kit.Colors.Blue, Kit.Colors.BlueDark)
	local cashLabel, cashBar = reqRow(126, "Cash", Kit.Colors.Green, Kit.Colors.GreenDark)
	Kit.text({ Text = "Resets Power and Cash.\nUpgrades, pets and cannons stay!", Size = 17, Color = Color3.fromRGB(255, 200, 200), FrameSize = UDim2.new(1, -16, 0, 44), Position = UDim2.fromOffset(8, 196), ZIndex = 26, Parent = req })

	-- rewards
	local rew = Kit.card({ Color = Kit.Colors.Purple, Color2 = Kit.Colors.PurpleDark, Position = UDim2.new(0.5, 6, 0, 40), Size = UDim2.new(0.5, -6, 0, 250), ZIndex = 23, Parent = body })
	Kit.movingPattern(rew, { Texture = "StudTile", Speed = 14, ImageTransparency = 0.8, ZIndex = 23 })
	Kit.sparkles(rew, 5)
	Kit.text({ Text = "Rewards", Size = 28, FrameSize = UDim2.new(1, 0, 0, 36), Position = UDim2.fromOffset(0, 6), ZIndex = 25, Parent = rew })
	local rewList = new("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(10, 46), Size = UDim2.new(1, -20, 1, -54), ZIndex = 24, Parent = rew })
	Kit.list(rewList, 4, false, Enum.HorizontalAlignment.Left)
	for i, r in ipairs(Config.RebirthRewards) do
		local row = new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 36), LayoutOrder = i, ZIndex = 24, Parent = rewList })
		Kit.icon(r.Icon, { Size = UDim2.fromOffset(34, 34), ZIndex = 26, Parent = row })
		Kit.text({ Text = r.Text, Size = 22, AlignX = Enum.TextXAlignment.Left, FrameSize = UDim2.new(1, -44, 1, 0), Position = UDim2.fromOffset(44, 0), ZIndex = 26, Parent = row })
	end

	-- buttons
	local rebirthBtn = Kit.button({ Name = "RebirthButton", Text = "Rebirth", Icon = "Rebirth", Color = "Green", TextSize = 34, IconSize = 40, Size = UDim2.new(0.5, -6, 0, 76), Position = UDim2.fromOffset(0, 306), ZIndex = 26, Parent = body, OnClick = function()
		ctx.Request("Rebirth")
	end })
	local skip = Kit.button({ Text = "Skip Rebirth", Icon = "RebirthSkip", Color = "Yellow", TextSize = 30, IconSize = 40, Size = UDim2.new(0.5, -6, 0, 76), Position = UDim2.new(0.5, 6, 0, 306), ZIndex = 26, Parent = body, OnClick = function()
		ctx.Request("Purchase", "Product", "SkipRebirth")
	end })
	Kit.rainbowFill(skip.Gradient)
	Kit.rainbowStroke(skip.Instance, 3)
	Kit.shine(skip.Instance, 2.5)
	Kit.text({ Text = " " .. Config.Products.SkipRebirth.Price, Size = 18, FrameSize = UDim2.fromOffset(80, 22), Position = UDim2.new(1, -84, 1, -4), Anchor = Vector2.new(0, 1), ZIndex = 40, Parent = skip.Instance })
	local nextText = Kit.text({ Text = "", Size = 20, FrameSize = UDim2.new(1, 0, 0, 24), Position = UDim2.fromOffset(0, 390), ZIndex = 24, Parent = body })

	local function refresh()
		local data = State.Data
		if not data then
			return
		end
		local powerCost, cashCost = Config.RebirthCost(data.Rebirths)
		count.Text = "Rebirths: " .. data.Rebirths
		powerLabel.Text = Config.Format(powerCost) .. " Power"
		powerBar:Set(data.Power / powerCost, Config.Format(data.Power) .. " / " .. Config.Format(powerCost))
		cashLabel.Text = Config.Format(cashCost) .. " Cash"
		cashBar:Set(data.Cash / cashCost, Config.Format(data.Cash) .. " / " .. Config.Format(cashCost))
		local ready = data.Power >= powerCost and data.Cash >= cashCost
		rebirthBtn:SetColor(ready and "Green" or "Gray")
		-- next unlock from stations / worlds
		local unlock
		for _, s in ipairs(Config.Stations) do
			if not s.Pass and s.Rebirths > data.Rebirths and (not unlock or s.Rebirths < unlock.Rebirths) then
				unlock = { Rebirths = s.Rebirths, Name = s.Name }
			end
		end
		for _, w in ipairs(Config.Worlds) do
			if w.Rebirths > data.Rebirths and (not unlock or w.Rebirths < unlock.Rebirths) then
				unlock = { Rebirths = w.Rebirths, Name = w.Name .. " World" }
			end
		end
		nextText.Text = unlock and ("Next unlock: " .. unlock.Name .. " at " .. unlock.Rebirths .. " Rebirths") or "Everything unlocked!"
	end

	return { Frame = panel.Frame, OnOpen = refresh, Refresh = refresh }
end

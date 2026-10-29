--[[
	Rebirth panel, laid out like Alex's mockup (design/cannon_ui_panels.zip,
	rebirth.png): what you have >> what you need, one progress bar and a big
	green Rebirth button. Game extras the mockup doesn't show sit in the button
	row: the rebirth count on the left and Skip Rebirth on the right.
]]

return function(ctx)
	local Kit, Config, State = ctx.Kit, ctx.Config, ctx.State
	local new = Kit.new

	local panel = Kit.panel({ Title = "Rebirth", Icon = "Rebirth", Size = UDim2.fromOffset(640, 400) })
	local body = panel.Body
	local _, card = Kit.inset({ Parent = body, ZIndex = 22 })

	-- have >> need
	local function valueRow(x, y, icon)
		Kit.icon(icon, { Size = UDim2.fromOffset(56, 56), Position = UDim2.new(x, 0, 0, y), ZIndex = 26, Parent = card })
		return Kit.text({ Text = "", Size = 40, StrokeSize = 3.5, AlignX = Enum.TextXAlignment.Left, FrameSize = UDim2.new(0.3, -70, 0, 56), Position = UDim2.new(x, 70, 0, y), ZIndex = 26, Parent = card })
	end
	local havePower = valueRow(0.08, 14, "Power")
	local haveCash = valueRow(0.08, 74, "Cash")
	local needPower = valueRow(0.6, 14, "Power")
	local needCash = valueRow(0.6, 74, "Cash")
	Kit.icon("Chevrons", { Size = UDim2.fromOffset(72, 72), Position = UDim2.new(0.5, -8, 0, 32), Anchor = Vector2.new(0.5, 0), ZIndex = 26, Parent = card })

	Kit.text({
		Text = "Every rebirth: +" .. math.floor(Config.REBIRTH_POWER_BONUS * 100) .. "% Power, +" .. math.floor(Config.REBIRTH_CASH_BONUS * 100) .. "% Cash, new cannons and worlds",
		Size = 17,
		Color = Kit.Colors.Yellow,
		FrameSize = UDim2.new(1, -24, 0, 22),
		Position = UDim2.fromOffset(12, 136),
		ZIndex = 26,
		Parent = card,
	})

	local bar = Kit.progress({ Parent = card, Position = UDim2.fromOffset(18, 164), Size = UDim2.new(1, -36, 0, 34), ZIndex = 25 })

	-- button row
	local rebirthBtn = Kit.button({ Name = "RebirthButton", Text = "Rebirth", Color = "Green", TextSize = 40, StrokeSize = 4, Size = UDim2.new(0.52, 0, 0, 66), Position = UDim2.new(0.5, 0, 0, 214), Anchor = Vector2.new(0.5, 0), ZIndex = 26, Parent = card, OnClick = function()
		ctx.Request("Rebirth")
	end })

	local count = Kit.text({ Text = "", Size = 20, FrameSize = UDim2.new(0.22, -12, 0, 66), Position = UDim2.fromOffset(12, 214), ZIndex = 26, Parent = card })

	local skip = Kit.button({ Text = "Skip", Icon = "RebirthSkip", Color = "Yellow", TextSize = 24, IconSize = 30, Size = UDim2.new(0.2, 0, 0, 54), Position = UDim2.new(1, -12, 0, 220), Anchor = Vector2.new(1, 0), ZIndex = 26, Parent = card, OnClick = function()
		ctx.Request("Purchase", "Product", "SkipRebirth")
	end })
	Kit.rainbowFill(skip.Gradient)
	Kit.shine(skip.Instance, 2.5)
	Kit.text({ Text = Kit.priceText("Robux", Config.Products.SkipRebirth.Price), Size = 15, FrameSize = UDim2.fromOffset(80, 18), Position = UDim2.new(0.5, 0, 1, 4), Anchor = Vector2.new(0.5, 0), ZIndex = 40, Parent = skip.Instance })

	local function refresh()
		local data = State.Data
		if not data then
			return
		end
		local powerCost, cashCost = Config.RebirthCost(data.Rebirths)
		count.Text = "Rebirths\n" .. data.Rebirths
		havePower.Text = Config.Format(data.Power)
		haveCash.Text = Config.Format(data.Cash)
		needPower.Text = Config.Format(powerCost)
		needCash.Text = Config.Format(cashCost)
		local p, c = data.Power / powerCost, data.Cash / cashCost
		havePower.TextColor3 = p >= 1 and Kit.Colors.Green or Kit.Colors.White
		haveCash.TextColor3 = c >= 1 and Kit.Colors.Green or Kit.Colors.White
		-- the bar follows whichever requirement is further away
		if p <= c then
			bar:Set(p, Config.Format(data.Power) .. " / " .. Config.Format(powerCost) .. " Power")
		else
			bar:Set(c, Config.Format(data.Cash) .. " / " .. Config.Format(cashCost) .. " Cash")
		end
		rebirthBtn:SetColor((p >= 1 and c >= 1) and "Green" or "Gray")
	end

	return { Frame = panel.Frame, OnOpen = refresh, Refresh = refresh }
end

--[[
	Upgrades panel: Player / Cannon tabs, Cash-priced levels.
]]

return function(ctx)
	local Kit, Config, State = ctx.Kit, ctx.Config, ctx.State

	local panel = Kit.panel({ Title = "Upgrades", Icon = "Arrow", Size = UDim2.fromOffset(760, 520) })
	local body = panel.Body
	local scroll = Kit.scrolling({ Parent = body, Position = UDim2.fromOffset(0, 50), Size = UDim2.new(1, 0, 1, -50), ZIndex = 23 })
	Kit.list(scroll, 8)

	local rows = {}
	local current = "Player"

	local function build()
		Kit.clear(scroll)
		rows = {}
		for i, up in ipairs(Config.Upgrades[current]) do
			local row = Kit.card({ Color = Kit.Colors.Card, Size = UDim2.new(1, -12, 0, 84), Order = i, Parent = scroll, ZIndex = 24 })
			Kit.icon(up.Icon, { Size = UDim2.fromOffset(64, 64), Position = UDim2.fromOffset(12, 10), ZIndex = 26, Parent = row })
			Kit.text({ Text = up.Name, Size = 26, AlignX = Enum.TextXAlignment.Left, FrameSize = UDim2.new(0.4, 0, 0, 30), Position = UDim2.fromOffset(88, 8), ZIndex = 26, Parent = row })
			local desc = Kit.text({ Text = up.Desc, Size = 18, Color = Kit.Colors.Yellow, AlignX = Enum.TextXAlignment.Left, FrameSize = UDim2.new(0.4, 0, 0, 22), Position = UDim2.fromOffset(88, 36), ZIndex = 26, Parent = row })
			local bar = Kit.progress({ Parent = row, Position = UDim2.new(0, 88, 0, 60), Size = UDim2.new(0.55, -88, 0, 19), ZIndex = 25 })
			local btn = Kit.button({ Text = "", Icon = "Cash", Color = "Green", Size = UDim2.fromOffset(200, 56), Position = UDim2.new(1, -12, 0.5, 0), Anchor = Vector2.new(1, 0.5), ZIndex = 27, Parent = row, OnClick = function()
				ctx.Request("BuyUpgrade", up.Id)
			end })
			rows[up.Id] = { Bar = bar, Button = btn, Desc = desc }
		end
	end

	local function refresh()
		local data = State.Data
		if not data then
			return
		end
		for _, up in ipairs(Config.Upgrades[current]) do
			local r = rows[up.Id]
			if r then
				local level = Config.Level(data, up.Id)
				r.Bar:Set(level / up.Max, "Lv " .. level .. " / " .. up.Max)
				if level >= up.Max then
					r.Button:SetText("MAX")
					r.Button:SetColor("Purple")
				else
					local cost = Config.UpgradeCost(up, level)
					r.Button:SetText(Config.Format(cost))
					r.Button:SetColor(data.Cash >= cost and "Green" or "Gray")
				end
			end
		end
	end

	local tabs = Kit.tabs({ Names = { "Player", "Cannon" }, Parent = body, OnSelect = function(name)
		current = name
		build()
		refresh()
	end })

	return {
		Frame = panel.Frame,
		OnOpen = function(tab)
			tabs:Select(tab or current)
		end,
		Refresh = refresh,
	}
end

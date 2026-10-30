--[[
	Upgrades panel: Player / Cannon tabs, Cash-priced levels, laid out as a
	grid of tiles like Alex's mockup.
]]

return function(ctx)
	local Kit, Config, State = ctx.Kit, ctx.Config, ctx.State
	local new = Kit.new

	local panel = Kit.panel({ Title = "Upgrades", Icon = "Evolve", Size = UDim2.fromOffset(780, 440) })
	local body = panel.Body
	-- grid of upgrade tiles like the mockup (design/cannon_ui_panels.zip, upgrades.png)
	local holder = new("Frame", { Name = "Tiles", BackgroundTransparency = 1, Position = UDim2.fromOffset(0, 54), Size = UDim2.new(1, 0, 1, -54), ZIndex = 23, Parent = body })
	local grid = Kit.grid(holder, UDim2.new(1 / 3, -8, 0, 150), 10)
	grid.HorizontalAlignment = Enum.HorizontalAlignment.Left

	local rows = {}
	local current = "Player"

	local function build()
		Kit.clear(holder)
		rows = {}
		for i, up in ipairs(Config.Upgrades[current]) do
			local tile, fill = Kit.inset({ Name = up.Id, Tile = true, Parent = holder, ZIndex = 24 })
			tile.LayoutOrder = i
			Kit.icon(up.Icon, { Size = UDim2.fromOffset(66, 66), Position = UDim2.fromOffset(6, 6), ZIndex = 27, Parent = fill })
			Kit.text({ Text = up.Name, Size = 26, StrokeSize = 3, Scaled = true, MaxSize = 26, AlignX = Enum.TextXAlignment.Left, FrameSize = UDim2.new(1, -84, 0, 28), Position = UDim2.fromOffset(78, 6), ZIndex = 27, Parent = fill })
			local lv = Kit.text({ Text = "", Size = 24, StrokeSize = 3, Color = Kit.Colors.Yellow, AlignX = Enum.TextXAlignment.Left, FrameSize = UDim2.new(1, -84, 0, 26), Position = UDim2.fromOffset(78, 34), ZIndex = 27, Parent = fill })
			Kit.text({ Text = up.Desc, Size = 15, Color = Color3.fromRGB(190, 215, 240), AlignX = Enum.TextXAlignment.Left, FrameSize = UDim2.new(1, -84, 0, 18), Position = UDim2.fromOffset(78, 60), ZIndex = 27, Parent = fill })
			local btn = Kit.button({ Text = "", Icon = "Cash", Color = "Green", TextSize = 28, IconSize = 32, Size = UDim2.new(1, -12, 0, 46), Position = UDim2.new(0.5, 0, 1, -6), Anchor = Vector2.new(0.5, 1), ZIndex = 28, Parent = fill, OnClick = function()
				ctx.Request("BuyUpgrade", up.Id)
			end })
			rows[up.Id] = { Level = lv, Button = btn }
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
				r.Level.Text = "Lv. " .. level .. (level >= up.Max and "" or (" / " .. up.Max))
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

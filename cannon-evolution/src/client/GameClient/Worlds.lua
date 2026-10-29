--[[
	Worlds panel: one card per zone with Teleport, locked by rebirths.
]]

return function(ctx)
	local Kit, Config, State = ctx.Kit, ctx.Config, ctx.State

	local panel = Kit.panel({ Title = "Worlds", Icon = "World", Size = UDim2.fromOffset(820, 520) })
	local scroll = Kit.scrolling({ Parent = panel.Body, ZIndex = 23 })
	Kit.grid(scroll, UDim2.fromOffset(240, 200), 12)

	local cards = {}
	for i, world in ipairs(Config.Worlds) do
		local card = Kit.card({ Color = world.Color, Order = i, Parent = scroll, ZIndex = 24 })
		Kit.movingPattern(card, { Lite = true, Texture = "StudTile", Speed = 12, ImageTransparency = 0.8, ZIndex = 24 })
		Kit.text({ Text = world.Name, Size = 30, FrameSize = UDim2.new(1, 0, 0, 36), Position = UDim2.fromOffset(0, 8), ZIndex = 27, Parent = card })
		local icon = Kit.icon("World", { Size = UDim2.fromOffset(80, 80), Position = UDim2.new(0.5, 0, 0, 90), Anchor = Vector2.new(0.5, 0.5), ZIndex = 26, Parent = card })
		local lock = Kit.text({ Text = "🔒 " .. world.Rebirths .. " Rebirths", Size = 22, FrameSize = UDim2.new(1, 0, 0, 26), Position = UDim2.fromOffset(0, 128), ZIndex = 27, Parent = card })
		local btn = Kit.button({ Text = "Teleport", Color = "Green", Size = UDim2.new(1, -24, 0, 42), Position = UDim2.new(0.5, 0, 1, -10), Anchor = Vector2.new(0.5, 1), ZIndex = 27, Parent = card, OnClick = function()
			if ctx.Request("Teleport", world.Id) then
				ctx.Close()
			end
		end })
		cards[i] = { Lock = lock, Button = btn, Icon = icon, Card = card }
	end

	local function refresh()
		local data = State.Data
		if not data then
			return
		end
		for i, world in ipairs(Config.Worlds) do
			local c = cards[i]
			local open = data.Rebirths >= world.Rebirths
			c.Lock.Visible = not open
			c.Button:SetText(open and "Teleport" or "Locked")
			c.Button:SetColor(open and "Green" or "Gray")
			c.Icon.Rotation = open and 0 or -8
		end
	end

	return { Frame = panel.Frame, OnOpen = refresh, Refresh = refresh }
end

--[[
	Worlds panel, laid out like Alex's mockup (design/cannon_ui_panels.zip,
	worlds.png): one row of tall world cards. Open worlds get a green
	Teleport button; locked ones are darkened with a lock and a "Rebirth N"
	pill. The row scrolls sideways when there are more worlds than fit.
]]

return function(ctx)
	local Kit, Config, State = ctx.Kit, ctx.Config, ctx.State
	local new = Kit.new

	local panel = Kit.panel({ Title = "Worlds", Icon = "World", Size = UDim2.fromOffset(940, 430) })
	local _, card = Kit.inset({ Parent = panel.Body, ZIndex = 22 })
	local scroll = Kit.scrolling({ Parent = card, ZIndex = 23 })
	scroll.AutomaticCanvasSize = Enum.AutomaticSize.X
	scroll.ScrollingDirection = Enum.ScrollingDirection.X
	scroll.ScrollBarThickness = 8
	-- room for the card outlines (ScrollingFrame clips outside strokes)
	scroll.UIPadding.PaddingLeft = UDim.new(0, 10)
	scroll.UIPadding.PaddingTop = UDim.new(0, 10)
	local list = Kit.list(scroll, 12, true, Enum.HorizontalAlignment.Left)
	list.VerticalAlignment = Enum.VerticalAlignment.Top

	-- simple drawn padlock (no emoji)
	local function padlock(parent)
		local lock = new("Frame", { Name = "Lock", BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.52), Size = UDim2.fromOffset(64, 72), ZIndex = 29, Parent = parent })
		local shackle = new("Frame", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0), Size = UDim2.fromOffset(38, 46), ZIndex = 29, Parent = lock })
		Kit.corner(19, shackle)
		new("UIStroke", { Thickness = 8, Color = Color3.fromRGB(235, 235, 240), Parent = shackle })
		local body = new("Frame", { BackgroundColor3 = Color3.new(1, 1, 1), AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.fromScale(0.5, 1), Size = UDim2.fromOffset(64, 46), ZIndex = 30, Parent = lock })
		Kit.corner(10, body)
		Kit.stroke(4, nil, body)
		Kit.gradient(Color3.fromRGB(255, 255, 255), Color3.fromRGB(190, 195, 210), body)
		local hole = new("Frame", { BackgroundColor3 = Kit.Colors.Outline, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.48), Size = UDim2.fromOffset(10, 18), ZIndex = 31, Parent = body })
		Kit.corner(5, hole)
		return lock
	end

	local cards = {}
	for i, world in ipairs(Config.Worlds) do
		local c = Kit.card({ Name = "World" .. world.Id, Color = world.Color:Lerp(Color3.new(1, 1, 1), 0.15), Color2 = world.Color:Lerp(Color3.new(0, 0, 0), 0.3), Size = UDim2.fromOffset(160, 300), Order = i, StrokeSize = 4, Parent = scroll, ZIndex = 24 })
		Kit.movingPattern(c, { Lite = true, Texture = "StudTile", Speed = 0, ImageTransparency = 0.82, ZIndex = 24 })
		Kit.text({ Text = world.Name, Size = 28, StrokeSize = 3.5, Scaled = true, MaxSize = 28, FrameSize = UDim2.new(1, -10, 0, 34), Position = UDim2.new(0.5, 0, 0, 8), Anchor = Vector2.new(0.5, 0), ZIndex = 33, Parent = c })
		local icon = Kit.icon("World", { Size = UDim2.fromOffset(112, 112), Position = UDim2.fromScale(0.5, 0.47), Anchor = Vector2.new(0.5, 0.5), ZIndex = 26, Parent = c })
		local shade = new("Frame", { Name = "Shade", BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.45, Size = UDim2.fromScale(1, 1), ZIndex = 28, Parent = c })
		Kit.corner(12, shade)
		local lock = padlock(c)
		local btn = Kit.button({ Text = "Teleport", Color = "Green", TextSize = 26, Size = UDim2.new(1, -16, 0, 46), Position = UDim2.new(0.5, 0, 1, -10), Anchor = Vector2.new(0.5, 1), ZIndex = 32, Parent = c, OnClick = function()
			if ctx.Request("Teleport", world.Id) then
				ctx.Close()
			end
		end })
		cards[i] = { Button = btn, Icon = icon, Shade = shade, Lock = lock }
	end

	local function refresh()
		local data = State.Data
		if not data then
			return
		end
		for i, world in ipairs(Config.Worlds) do
			local c = cards[i]
			local open = data.Rebirths >= world.Rebirths
			c.Shade.Visible = not open
			c.Lock.Visible = not open
			c.Button.Instance.Active = open
			c.Button:SetText(open and "Teleport" or ("Rebirth " .. world.Rebirths))
			c.Button:SetColor(open and "Green" or "Dark")
		end
	end

	return { Frame = panel.Frame, OnOpen = refresh, Refresh = refresh }
end

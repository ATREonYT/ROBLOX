--[[
	Shop panel: one long scrolling page like the Stone Skipping shop in Alex's
	recordings (Oct 30): Featured banner, then "~ Section ~" bars for
	Gamepasses, Cannons, Power & Cash, Gems, Boosts and Codes. The HUD's
	+ buttons jump straight to a section. Every tile keeps our moving
	background, shine sweep and sparkles.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

return function(ctx)
	local Kit, Config, State = ctx.Kit, ctx.Config, ctx.State
	local new = Kit.new

	local panel = Kit.panel({ Title = "Shop", Icon = "Shop", Size = UDim2.fromOffset(900, 580) })
	local body = panel.Body
	local _, card = Kit.inset({ Parent = body, ZIndex = 22 })
	local content = Kit.scrolling({ Name = "Content", Parent = card, ZIndex = 24 })
	content.ScrollBarThickness = 8
	-- room for tile outlines (ScrollingFrame clips outside strokes)
	content.UIPadding.PaddingLeft = UDim.new(0, 10)
	content.UIPadding.PaddingRight = UDim.new(0, 14)
	content.UIPadding.PaddingTop = UDim.new(0, 10)
	content.UIPadding.PaddingBottom = UDim.new(0, 12)
	Kit.list(content, 12)

	local TILE_COLORS = {
		DoublePower = Color3.fromRGB(255, 150, 30), DoubleCash = Color3.fromRGB(60, 190, 70), Lucky = Color3.fromRGB(40, 200, 150),
		TripleOpen = Color3.fromRGB(170, 70, 255), OctoOpen = Color3.fromRGB(230, 60, 170), AutoCollect = Color3.fromRGB(50, 140, 255), ExtraEquip = Color3.fromRGB(120, 80, 230),
		VIP = Color3.fromRGB(255, 190, 30), AutoLaunch = Color3.fromRGB(230, 60, 60),
	}

	local function robuxButton(parent, price, onClick, props)
		props = props or {}
		local b = Kit.button({
			Text = tostring(price), Icon = "Robux", Color = props.Color or "Green",
			Size = props.Size or UDim2.new(1, -16, 0, 38), Position = props.Position or UDim2.new(0.5, 0, 1, -8),
			Anchor = props.Anchor or Vector2.new(0.5, 1), TextSize = props.TextSize or 26, IconSize = props.IconSize or 26,
			ZIndex = 30, Parent = parent, OnClick = onClick,
		})
		return b
	end

	-- Generic animated shop tile
	local function tile(parent, props)
		local card = Kit.card({ Color = props.Color, Size = props.Size, Order = props.Order, Parent = parent, ZIndex = 25 })
		Kit.movingPattern(card, { Lite = true, Texture = props.Texture or "Stripes", Speed = 25, ImageTransparency = 0.55, ZIndex = 25 })
		Kit.sparkles(card, 3)
		Kit.shine(card, 3 + math.random())
		Kit.text({ Text = props.Title, Size = 22, Scaled = true, MaxSize = 24, FrameSize = UDim2.new(1, -10, 0, 28), Position = UDim2.fromOffset(5, 4), ZIndex = 30, Parent = card })
		-- the icon fills the space between the title and the text/button below
		local below = props.Desc and 92 or 52
		local icon = Kit.icon(props.Icon, { Size = UDim2.new(1, -24, 1, -(34 + below + 6)), Position = UDim2.new(0.5, 0, 0, 34 + 3), Anchor = Vector2.new(0.5, 0), ZIndex = 29, Parent = card })
		new("UIAspectRatioConstraint", { Parent = icon })
		Kit.bob(icon, 3, 2.2)
		Kit.hoverLift(card, icon)
		if props.Desc then
			Kit.text({ Text = props.Desc, Size = 16, Scaled = true, MaxSize = 17, Wrapped = true, FrameSize = UDim2.new(1, -12, 0, 36), Position = UDim2.new(0.5, 0, 1, -52), Anchor = Vector2.new(0.5, 1), ZIndex = 30, Parent = card })
		end
		if props.Owned then
			-- green ribbon in place of the buy button
			local ribbon = new("Frame", { Name = "Owned", BackgroundColor3 = Color3.new(1, 1, 1), Size = UDim2.new(1, -16, 0, 38), Position = UDim2.new(0.5, 0, 1, -8), AnchorPoint = Vector2.new(0.5, 1), ZIndex = 30, Parent = card })
			Kit.corner(10, ribbon)
			Kit.stroke(3, nil, ribbon)
			Kit.gradient(Kit.Colors.Green, Kit.Colors.GreenDark, ribbon)
			Kit.text({ Text = "✔ OWNED", Size = 24, Scaled = true, MaxSize = 24, FrameSize = UDim2.new(1, -10, 0.8, 0), Position = UDim2.fromScale(0.5, 0.5), Anchor = Vector2.new(0.5, 0.5), ZIndex = 31, Parent = ribbon })
			return card, ribbon
		end
		local buy
		if props.Gems then
			buy = Kit.button({ Text = "💎 " .. props.Gems, Color = "Purple", Size = UDim2.new(1, -16, 0, 38), Position = UDim2.new(0.5, 0, 1, -8), Anchor = Vector2.new(0.5, 1), TextSize = 24, ZIndex = 30, Parent = card, OnClick = props.OnBuy })
		else
			buy = robuxButton(card, props.Price, props.OnBuy)
		end
		Kit.jiggle(buy.Instance, 3.5 + math.random() * 1.5, 3)
		return card
	end

	-----------------------------------------------------------------------
	-- Featured
	-----------------------------------------------------------------------
	local featuredIndex = 1
	local rebuild -- set below
	local function buildFeatured(page)
		local item = Config.Featured[featuredIndex]
		local product = Config.Products[item.Product]
		local banner, grad = Kit.card({ Color = item.Color, Color2 = item.Color:Lerp(Color3.new(0, 0, 0), 0.55), Size = UDim2.new(1, 0, 0, 260), Parent = page, ZIndex = 25 })
		grad.Rotation = 0
		Kit.movingPattern(banner, { Texture = "Stripes", Speed = 35, ImageTransparency = 0.45, ZIndex = 25 })
		Kit.rainbowStroke(banner, 4)
		local art = new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(0.42, 0, 1, 0), ZIndex = 26, Parent = banner })
		Kit.rays(art, { Size = UDim2.fromOffset(420, 420), Color = Color3.new(1, 1, 1), Transparency = 0.7, ZIndex = 26 })
		local model, picture
		if item.Model then
			model = ReplicatedStorage:FindFirstChild("Cannons") and ReplicatedStorage.Cannons:FindFirstChild(item.Model)
		elseif item.Egg then
			local egg = Config.GetEgg(item.Egg)
			if Kit.hasImage("Egg_" .. egg.Id) then
				picture = "Egg_" .. egg.Id -- Alex's drawn egg, the same picture as everywhere else
			else
				model = ReplicatedStorage:FindFirstChild("Eggs") and ReplicatedStorage.Eggs:FindFirstChild(egg.Model)
			end
		end
		if picture then
			local ic = Kit.icon(picture, { Size = UDim2.fromOffset(200, 200), Position = UDim2.fromScale(0.5, 0.5), Anchor = Vector2.new(0.5, 0.5), ZIndex = 28, Parent = art })
			Kit.bob(ic, 6, 1.6)
		elseif model then
			local vp = Kit.viewport(art, model, { Size = UDim2.fromScale(0.95, 0.95), Spin = 30, ZIndex = 28 })
			Kit.bob(vp, 5, 1.6)
		else
			local ic = Kit.icon(item.Icon or "StarterCrate", { Size = UDim2.fromOffset(200, 200), Position = UDim2.fromScale(0.5, 0.5), Anchor = Vector2.new(0.5, 0.5), ZIndex = 28, Parent = art })
			Kit.bob(ic, 6, 1.6)
		end
		Kit.sparkles(banner, 8)
		Kit.shine(banner, 3.5)
		local newTag = Kit.text({ Text = "NEW!", Size = 34, Color = Color3.fromRGB(255, 60, 60), StrokeColor = Color3.new(1, 1, 1), FrameSize = UDim2.fromOffset(110, 40), Position = UDim2.fromOffset(10, 6), ZIndex = 31, Parent = banner })
		newTag.Rotation = -10
		Kit.animate(newTag, function(_, t)
			Kit.scale(newTag).Scale = 1 + math.sin(t * 4) * 0.06
		end)
		Kit.text({ Text = item.Title, Size = 50, StrokeSize = 4, AlignX = Enum.TextXAlignment.Left, FrameSize = UDim2.new(0.56, 0, 0, 60), Position = UDim2.new(0.42, 0, 0, 14), ZIndex = 31, Parent = banner })
		for i, line in ipairs(item.Lines) do
			Kit.text({ Text = "⭐ " .. line, Size = 28, AlignX = Enum.TextXAlignment.Left, FrameSize = UDim2.new(0.56, 0, 0, 34), Position = UDim2.new(0.42, 0, 0, 70 + (i - 1) * 36), ZIndex = 31, Parent = banner })
		end
		local buy = robuxButton(banner, product.Price, function()
			ctx.Request("Purchase", "Product", item.Product)
		end, { Size = UDim2.fromOffset(260, 56), Position = UDim2.new(0.7, 0, 1, -14), TextSize = 38, IconSize = 38 })
		Kit.shine(buy.Instance, 2.5)
		-- arrows
		for _, dir in ipairs({ -1, 1 }) do
			Kit.button({
				Text = dir < 0 and "<" or ">", Color = "Dark", Size = UDim2.fromOffset(40, 64),
				Position = dir < 0 and UDim2.new(0, 6, 0.5, 0) or UDim2.new(1, -6, 0.5, 0), Anchor = Vector2.new(dir < 0 and 0 or 1, 0.5),
				TextSize = 34, ZIndex = 32, Parent = banner, OnClick = function()
					featuredIndex = (featuredIndex - 1 + dir) % #Config.Featured + 1
					rebuild("Featured")
				end,
			})
		end
	end

	-----------------------------------------------------------------------
	-- Grid pages
	-----------------------------------------------------------------------
	local function gridPage(page, cell)
		page.AutomaticSize = Enum.AutomaticSize.Y
		Kit.grid(page, cell or UDim2.fromOffset(196, 220), 12)
		return page
	end

	local builders = {
		Featured = buildFeatured,
		Gamepasses = function(page)
			local grid = gridPage(page)
			for i, key in ipairs(Config.PassOrder) do
				local pass = Config.Passes[key]
				tile(grid, {
					Title = pass.Name, Icon = pass.Icon, Color = TILE_COLORS[key], Order = i, Desc = pass.Desc,
					Price = pass.Price, Owned = State.Passes[key], OnBuy = function()
						ctx.Request("Purchase", "Pass", key)
					end,
				})
			end
		end,
		Cash = function(page)
			local grid = gridPage(page)
			local data = State.Data
			for i, key in ipairs({ "CashSmall", "CashMedium", "CashLarge", "PowerPack1", "PowerPack2", "PowerPack3" }) do
				local p = Config.Products[key]
				local amount
				if p.Grant.CashMinutes then
					amount = "+" .. Config.Format(Config.CashPerMinute(data) * p.Grant.CashMinutes) .. " Cash"
				else
					amount = "+" .. Config.Format(Config.PowerPerMinute(data, State.Passes.VIP) * p.Grant.PowerMinutes) .. " Power"
				end
				tile(grid, {
					Title = p.Name, Icon = p.Icon, Order = i, Desc = amount, Price = p.Price, Texture = "StudTile",
					Color = p.Grant.CashMinutes and Color3.fromRGB(60, 190, 70) or Color3.fromRGB(255, 170, 30),
					OnBuy = function()
						ctx.Request("Purchase", "Product", key)
					end,
				})
			end
		end,
		Gems = function(page)
			local grid = gridPage(page)
			for i, key in ipairs({ "GemsSmall", "GemsMedium", "GemsLarge", "StarterPack" }) do
				local p = Config.Products[key]
				tile(grid, {
					Title = p.Name, Icon = p.Icon, Order = i, Price = p.Price, Texture = "StudTile",
					Desc = key == "StarterPack" and "500 Gems + Royal Cube + Cash" or nil,
					Color = key == "StarterPack" and Color3.fromRGB(240, 150, 30) or Color3.fromRGB(180, 70, 255),
					OnBuy = function()
						ctx.Request("Purchase", "Product", key)
					end,
				})
			end
		end,
		Boosts = function(page)
			local grid = gridPage(page)
			for i, boost in ipairs(Config.Boosts) do
				local left = boost.Id ~= "All" and State.Data.Boosts[boost.Id] or nil
				tile(grid, {
					Title = boost.Name, Icon = boost.Icon, Order = i, Gems = boost.Gems, Texture = "StudTile",
					Desc = boost.Minutes .. " minutes" .. (left and left > 0 and ("  (" .. Config.FormatTime(left) .. " left)") or ""),
					Color = Color3.fromRGB(230, 70, 120),
					OnBuy = function()
						ctx.Request("BuyBoost", boost.Id)
					end,
				})
			end
		end,
		Cannons = function(page)
			local grid = gridPage(page, UDim2.fromOffset(260, 300))
			for i, cannon in ipairs(Config.Cannons) do
				if cannon.Currency == "Robux" then
					local p = Config.Products[cannon.Product]
					local owned = State.Data.Cannons[cannon.Id]
					local card = tile(grid, {
						Title = cannon.Id .. " Cannon", Icon = "Evolve", Order = i, Price = p.Price, Owned = owned,
						Desc = "x" .. cannon.Mult .. " Power", Color = cannon.Featured and Color3.fromRGB(40, 200, 60) or Color3.fromRGB(80, 60, 220),
						OnBuy = function()
							ctx.Request("Purchase", "Product", cannon.Product)
						end,
					})
					local model = ReplicatedStorage:FindFirstChild("Cannons") and ReplicatedStorage.Cannons:FindFirstChild(cannon.Model)
					if model then
						card:FindFirstChild("Icon_Evolve"):Destroy()
						Kit.viewport(card, model, { Size = UDim2.new(0.8, 0, 0.55, 0), Position = UDim2.fromScale(0.5, 0.45), Spin = 30, ZIndex = 29 })
					end
				end
			end
		end,
	}

	builders.Codes = function(page)
		page.Size = UDim2.new(1, 0, 0, 96)
		local box = Kit.card({ Color = Kit.Colors.Purple, Color2 = Kit.Colors.PurpleDark, Size = UDim2.fromScale(1, 1), ZIndex = 25, Parent = page })
		Kit.movingPattern(box, { Lite = true, Texture = "StudTile", Speed = 0, ImageTransparency = 0.8, ZIndex = 25 })
		Kit.text({ Text = "Redeem codes for free Cash, Gems and boosts!", Size = 22, FrameSize = UDim2.new(1, -20, 0, 26), Position = UDim2.fromOffset(10, 6), ZIndex = 27, Parent = box })
		local input = new("TextBox", {
			BackgroundColor3 = Color3.new(1, 1, 1), PlaceholderText = "Enter code here...", Text = "", Font = Kit.Font, TextSize = 24,
			TextColor3 = Color3.fromRGB(40, 40, 50), ClearTextOnFocus = false, Size = UDim2.new(1, -190, 0, 46), Position = UDim2.fromOffset(14, 38), ZIndex = 27, Parent = box,
		})
		Kit.corner(10, input)
		Kit.stroke(3, nil, input)
		Kit.button({ Text = "Redeem", Color = "Green", Size = UDim2.fromOffset(150, 46), Position = UDim2.new(1, -14, 0, 38), Anchor = Vector2.new(1, 0), ZIndex = 27, Parent = box, OnClick = function()
			if input.Text ~= "" and ctx.Request("RedeemCode", input.Text) then
				input.Text = ""
			end
		end })
	end

	-- one long page: a "~ Title ~" bar, then that section's tiles
	local SECTIONS = {
		{ Key = "Featured" },
		{ Key = "Gamepasses", Title = "Gamepasses" },
		{ Key = "Cannons", Title = "Cannons" },
		{ Key = "Cash", Title = "Power & Cash" },
		{ Key = "Gems", Title = "Gems" },
		{ Key = "Boosts", Title = "Boosts" },
		{ Key = "Codes", Title = "Codes" },
	}
	local sections, bars = {}, {}
	for i, sec in ipairs(SECTIONS) do
		if sec.Title then
			local bar = new("Frame", { Name = sec.Key .. "Bar", BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 48), LayoutOrder = i * 2 - 1, ZIndex = 25, Parent = content })
			Kit.corner(10, bar)
			Kit.text({ Text = "~ " .. sec.Title .. " ~", Size = 40, StrokeSize = 4.5, FrameSize = UDim2.fromScale(1, 1), ZIndex = 26, Parent = bar })
			bars[sec.Key] = bar
		end
		sections[sec.Key] = new("Frame", { Name = sec.Key, BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 260), LayoutOrder = i * 2, ZIndex = 25, Parent = content })
	end

	function rebuild(key)
		local page = sections[key]
		Kit.clear(page)
		if State.Data then
			builders[key](page)
		end
	end
	local function rebuildAll()
		for _, sec in ipairs(SECTIONS) do
			rebuild(sec.Key)
		end
	end

	-- rotate the featured item every 8 seconds while open
	task.spawn(function()
		while true do
			task.wait(8)
			if panel.Frame.Visible then
				featuredIndex = featuredIndex % #Config.Featured + 1
				rebuild("Featured")
			end
		end
	end)

	local lastPasses = ""
	return {
		Frame = panel.Frame,
		OnOpen = function(tab)
			-- jump to a section (the HUD's + buttons ask for Cash or Gems)
			local target = tab and bars[tab]
			-- wait a moment so the freshly built grids have their real sizes
			task.delay(0.1, function()
				if target then
					content.CanvasPosition = Vector2.new(0, target.AbsolutePosition.Y - content.AbsolutePosition.Y + content.CanvasPosition.Y - 10)
				else
					content.CanvasPosition = Vector2.zero
				end
			end)
		end,
		Refresh = function()
			-- rebuild only when ownership changes, so animations don't restart
			local key = ""
			for _, k in ipairs(Config.PassOrder) do
				key ..= State.Passes[k] and "1" or "0"
			end
			if key ~= lastPasses and State.Data then
				lastPasses = key
				rebuildAll()
			end
		end,
	}
end

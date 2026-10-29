--[[
	Shop panel: Featured carousel, Gamepasses, Cash, Gems, Boosts, Cannons.
	Every tile has a moving background (stripes/studs), shine sweep and
	sparkles; the featured banner adds spinning rays and a rainbow outline.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

return function(ctx)
	local Kit, Config, State = ctx.Kit, ctx.Config, ctx.State
	local new = Kit.new

	local panel = Kit.panel({ Title = "Shop", Icon = "Shop", Size = UDim2.fromOffset(900, 580) })
	local body = panel.Body
	local content = new("Frame", { Name = "Content", BackgroundTransparency = 1, Position = UDim2.fromOffset(0, 52), Size = UDim2.new(1, 0, 1, -52), ZIndex = 22, Parent = body })

	local TILE_COLORS = {
		DoublePower = Color3.fromRGB(255, 150, 30), DoubleCash = Color3.fromRGB(60, 190, 70), Lucky = Color3.fromRGB(40, 200, 150),
		TripleOpen = Color3.fromRGB(170, 70, 255), AutoCollect = Color3.fromRGB(50, 140, 255), ExtraEquip = Color3.fromRGB(120, 80, 230),
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
	local function buildFeatured(page)
		local item = Config.Featured[featuredIndex]
		local product = Config.Products[item.Product]
		local banner, grad = Kit.card({ Color = item.Color, Color2 = item.Color:Lerp(Color3.new(0, 0, 0), 0.55), Size = UDim2.new(1, 0, 0, 260), Parent = page, ZIndex = 25 })
		grad.Rotation = 0
		Kit.movingPattern(banner, { Texture = "Stripes", Speed = 35, ImageTransparency = 0.45, ZIndex = 25 })
		Kit.rainbowStroke(banner, 4)
		local art = new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(0.42, 0, 1, 0), ZIndex = 26, Parent = banner })
		Kit.rays(art, { Size = UDim2.fromOffset(420, 420), Color = Color3.new(1, 1, 1), Transparency = 0.7, ZIndex = 26 })
		local model
		if item.Model then
			model = ReplicatedStorage:FindFirstChild("Cannons") and ReplicatedStorage.Cannons:FindFirstChild(item.Model)
		elseif item.Egg then
			local egg = Config.GetEgg(item.Egg)
			model = ReplicatedStorage:FindFirstChild("Eggs") and ReplicatedStorage.Eggs:FindFirstChild(egg.Model)
		end
		if model then
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
					panel.Show("Featured")
				end,
			})
		end
		-- row of gamepass tiles under the banner
		local row = new("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(0, 272), Size = UDim2.new(1, 0, 0, 180), ZIndex = 25, Parent = page })
		Kit.list(row, 10, true)
		for i, key in ipairs({ "DoublePower", "DoubleCash", "Lucky", "TripleOpen", "AutoCollect" }) do
			local pass = Config.Passes[key]
			tile(row, {
				Title = pass.Name, Icon = pass.Icon, Color = TILE_COLORS[key], Size = UDim2.fromOffset(160, 176), Order = i,
				Price = pass.Price, Owned = State.Passes[key], OnBuy = function()
					ctx.Request("Purchase", "Pass", key)
				end,
			})
		end
	end

	-----------------------------------------------------------------------
	-- Grid pages
	-----------------------------------------------------------------------
	local function gridPage(page, cell)
		local scroll = Kit.scrolling({ Parent = page, ZIndex = 24 })
		Kit.grid(scroll, cell or UDim2.fromOffset(196, 220), 12)
		return scroll
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

	local tabs
	local currentTab = "Featured"
	function panel.Show(name)
		currentTab = name
		Kit.clear(content)
		if State.Data then
			builders[name](content)
		end
	end

	tabs = Kit.tabs({ Names = { "Featured", "Gamepasses", "Cash", "Gems", "Boosts", "Cannons" }, Parent = body, Size = UDim2.new(1, 0, 0, 42), OnSelect = panel.Show })

	-- rotate the featured item every 8 seconds while open
	task.spawn(function()
		while true do
			task.wait(8)
			if panel.Frame.Visible and currentTab == "Featured" then
				featuredIndex = featuredIndex % #Config.Featured + 1
				panel.Show("Featured")
			end
		end
	end)

	local lastPasses = ""
	return {
		Frame = panel.Frame,
		OnOpen = function(tab)
			tabs:Select(tab or "Featured")
		end,
		Refresh = function()
			-- rebuild only when ownership changes, so animations don't restart
			local key = ""
			for _, k in ipairs(Config.PassOrder) do
				key ..= State.Passes[k] and "1" or "0"
			end
			if key ~= lastPasses then
				lastPasses = key
				panel.Show(currentTab)
			end
		end,
	}
end

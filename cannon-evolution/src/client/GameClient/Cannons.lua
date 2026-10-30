--[[
	Cannons panel: collection grid with rarity tabs. Click to buy / equip.
	The equipped cannon multiplies Power from every shot.
	The last tab, Balls, is the cannonball shop (the same balls as the stand in
	the lobby): bought with Cash, each adds a Cash bonus to every launch. The
	picked ball's card is green and the others purple, like the stand's pads.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

return function(ctx)
	local Kit, Config, State = ctx.Kit, ctx.Config, ctx.State
	local new = Kit.new

	local TIER_COLORS = {
		Basic = Color3.fromRGB(120, 130, 150),
		Rare = Color3.fromRGB(70, 140, 255),
		Epic = Color3.fromRGB(170, 70, 255),
		Legendary = Color3.fromRGB(255, 170, 30),
		Secret = Color3.fromRGB(40, 40, 50),
	}

	local panel = Kit.panel({ Title = "Cannons", Icon = "Cannon", Size = UDim2.fromOffset(820, 560) })
	local body = panel.Body
	local info = Kit.text({ Text = "", Size = 22, Color = Kit.Colors.Yellow, FrameSize = UDim2.new(1, 0, 0, 26), Position = UDim2.fromOffset(0, 48), ZIndex = 24, Parent = body })
	local scroll = Kit.scrolling({ Parent = body, Position = UDim2.fromOffset(0, 78), Size = UDim2.new(1, 0, 1, -78), ZIndex = 24 })
	Kit.grid(scroll, UDim2.fromOffset(140, 160), 10)

	local cards = {} -- [id] = { Card, Status }
	local currentTab = "All"

	local function statusFor(cannon)
		local data = State.Data
		if data.EquippedCannon == cannon.Id then
			return "Equipped", "Green"
		elseif data.Cannons[cannon.Id] then
			return "Equip", "Blue"
		elseif cannon.Currency == "Robux" then
			return "Shop", "Yellow"
		elseif cannon.Currency == "Cash" then
			return "💵 " .. Config.Format(cannon.Price), "Green"
		elseif cannon.Currency == "Gems" then
			return "💎 " .. Config.Format(cannon.Price), "Purple"
		elseif cannon.Currency == "Rebirth" then
			return "🔄 " .. cannon.Rebirths .. " Rebirths", "Gray"
		end
		return "Free", "Green"
	end

	-- A drawn cannonball in the ball's own colours: the body, its band and a shine
	local function drawBall(parent, ball, size, y)
		local body = new("Frame", { Name = "Ball", BackgroundColor3 = ball.Color, Size = UDim2.fromOffset(size, size), Position = UDim2.new(0.5, 0, 0, y), AnchorPoint = Vector2.new(0.5, 0.5), ZIndex = 27, Parent = parent })
		Kit.corner(size, body)
		Kit.stroke(3, nil, body)
		local band = new("Frame", { Name = "Band", BackgroundColor3 = ball.Band, BorderSizePixel = 0, Size = UDim2.new(0.94, 0, 0, math.floor(size * 0.16)), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), ZIndex = 28, Parent = body })
		Kit.corner(6, band)
		local shine = new("Frame", { Name = "Shine", BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 0.45, Size = UDim2.fromOffset(math.floor(size * 0.24), math.floor(size * 0.16)), Position = UDim2.fromScale(0.3, 0.24), AnchorPoint = Vector2.new(0.5, 0.5), Rotation = -30, ZIndex = 29, Parent = body })
		Kit.corner(size, shine)
		return body
	end

	local ballCards = {} -- [id] = { Gradient, Text, Status, Ball }

	local function buildBalls()
		ballCards = {}
		for i, ball in ipairs(Config.Balls) do
			local card, grad = Kit.card({ Button = true, Color = Kit.Colors.Purple, Order = i, Parent = scroll, ZIndex = 25 })
			Kit.movingPattern(card, { Lite = true, Texture = "StudTile", Speed = 10, ImageTransparency = 0.8, ZIndex = 25 })
			-- Alex's imported ball model where there is one (ReplicatedStorage.CannonBalls), a drawn ball otherwise
			local balls = ReplicatedStorage:FindFirstChild("CannonBalls")
			local model = ball.Model and balls and balls:FindFirstChild(ball.Id)
			local art
			if Kit.hasImage("Ball_" .. ball.Id) then
				-- Alex's drawn ball (Icons Ball_<id>) wins over the 3D model and the drawn stand-in
				art = Kit.icon("Ball_" .. ball.Id, { Size = UDim2.fromOffset(80, 80), Position = UDim2.new(0.5, 0, 0, 58), Anchor = Vector2.new(0.5, 0.5), ZIndex = 27, Parent = card })
			elseif model then
				art = Kit.viewport(card, model, { Size = UDim2.fromOffset(78, 78), Position = UDim2.new(0.5, 0, 0, 58), Spin = 30, FitLargest = true, Zoom = 0.85 / (ball.CardZoom or 1), ZIndex = 27 }) -- CardZoom: meshes with sparkles baked in frame bigger
			else
				art = drawBall(card, ball, 54, 58)
			end
			if ball.CashBonus > 0 then
				Kit.text({ Text = "+" .. math.floor(ball.CashBonus * 100 + 0.5) .. "% Cash", Size = 16, Color = Kit.Colors.Yellow, FrameSize = UDim2.fromOffset(110, 20), Position = UDim2.fromOffset(6, 4), AlignX = Enum.TextXAlignment.Left, ZIndex = 30, Parent = card })
			end
			Kit.text({ Text = ball.Name, Size = 22, Scaled = true, MaxSize = 22, FrameSize = UDim2.new(1, -8, 0, 24), Position = UDim2.new(0.5, 0, 0, 98), Anchor = Vector2.new(0.5, 0), ZIndex = 28, Parent = card })
			local status = Kit.card({ Color = Kit.Colors.Green, Size = UDim2.new(1, -12, 0, 26), Position = UDim2.new(0.5, 0, 1, -6), Anchor = Vector2.new(0.5, 1), Radius = 8, StrokeSize = 2.5, ZIndex = 28, Parent = card })
			local statusText = Kit.text({ Text = "", Size = 18, Scaled = true, MaxSize = 18, FrameSize = UDim2.new(1, -6, 1, -4), Position = UDim2.fromScale(0.5, 0.5), Anchor = Vector2.new(0.5, 0.5), ZIndex = 29, Parent = status })
			card.Activated:Connect(function()
				Kit.playSound("Click")
				Kit.press(card, 0.9)
				local data = State.Data
				if data.EquippedBall == ball.Id then
					return
				end
				local ok = ctx.Request(data.Balls[ball.Id] and "EquipBall" or "BuyBall", ball.Id)
				if ok then
					-- the new ball hops, like on the stand
					Kit.tween(art, 0.12, { Position = UDim2.new(0.5, 0, 0, 46) }, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
					task.delay(0.12, function()
						Kit.tween(art, 0.3, { Position = UDim2.new(0.5, 0, 0, 58) }, Enum.EasingStyle.Bounce)
					end)
				end
			end)
			ballCards[ball.Id] = { Gradient = grad, Text = statusText, Status = status }
		end
	end

	local function refreshBalls()
		local data = State.Data
		for _, ball in ipairs(Config.Balls) do
			local c = ballCards[ball.Id]
			if c then
				local text, color
				if data.EquippedBall == ball.Id then
					text, color = "Equipped", "Green"
				elseif data.Balls and data.Balls[ball.Id] then
					text, color = "Equip", "Blue"
				else
					text, color = "$" .. Config.Format(ball.Price), data.Cash >= ball.Price and "Green" or "Gray"
				end
				c.Text.Text = text
				c.Status:FindFirstChildOfClass("UIGradient").Color = ColorSequence.new(Kit.Colors[color], Kit.Colors[color .. "Dark"])
				local picked = data.EquippedBall == ball.Id
				c.Gradient.Color = ColorSequence.new(picked and Kit.Colors.Green or Kit.Colors.Purple, picked and Kit.Colors.GreenDark or Kit.Colors.PurpleDark)
			end
		end
		local equipped = Config.GetBall(data.EquippedBall) or Config.Balls[1]
		info.Text = "Ball: " .. equipped.Name .. "  •  +" .. math.floor(equipped.CashBonus * 100 + 0.5) .. "% Cash from every launch"
	end

	local function build()
		Kit.clear(scroll)
		cards = {}
		ballCards = {}
		if currentTab == "Balls" then
			buildBalls()
			return
		end
		local models = ReplicatedStorage:FindFirstChild("Cannons")
		for i, cannon in ipairs(Config.Cannons) do
			if currentTab == "All" or cannon.Tier == currentTab then
				local card = Kit.card({ Button = true, Color = TIER_COLORS[cannon.Tier], Order = i, Parent = scroll, ZIndex = 25 })
				Kit.movingPattern(card, { Lite = true, Texture = "StudTile", Speed = 10, ImageTransparency = 0.8, ZIndex = 25 })
				if cannon.Tier == "Secret" or cannon.Tier == "Legendary" then
					Kit.rainbowStroke(card, 3)
					Kit.sparkles(card, 3)
				end
				local model = models and models:FindFirstChild(cannon.Model)
				if model then
					Kit.viewport(card, model, { Size = UDim2.new(1, -10, 0, 96), Position = UDim2.new(0.5, 0, 0, 52), Yaw = 35, ZIndex = 27 }) -- cannon models face +Z, unlike pets
				else
					Kit.icon("Evolve", { Size = UDim2.fromOffset(80, 80), Position = UDim2.new(0.5, 0, 0, 52), Anchor = Vector2.new(0.5, 0.5), ZIndex = 27, Parent = card })
				end
				Kit.text({ Text = cannon.Id, Size = 22, Scaled = true, MaxSize = 22, FrameSize = UDim2.new(1, -8, 0, 24), Position = UDim2.new(0.5, 0, 0, 100), Anchor = Vector2.new(0.5, 0), ZIndex = 28, Parent = card })
				Kit.text({ Text = "x" .. cannon.Mult, Size = 16, Color = Kit.Colors.Yellow, FrameSize = UDim2.fromOffset(60, 20), Position = UDim2.fromOffset(6, 4), AlignX = Enum.TextXAlignment.Left, ZIndex = 28, Parent = card })
				local status = Kit.card({ Color = Kit.Colors.Green, Size = UDim2.new(1, -12, 0, 26), Position = UDim2.new(0.5, 0, 1, -6), Anchor = Vector2.new(0.5, 1), Radius = 8, StrokeSize = 2.5, ZIndex = 28, Parent = card })
				local statusText = Kit.text({ Text = "", Size = 18, Scaled = true, MaxSize = 18, FrameSize = UDim2.new(1, -6, 1, -4), Position = UDim2.fromScale(0.5, 0.5), Anchor = Vector2.new(0.5, 0.5), ZIndex = 29, Parent = status })
				card.Activated:Connect(function()
					Kit.playSound("Click")
					Kit.pop(card, 0.9)
					local data = State.Data
					if data.Cannons[cannon.Id] then
						ctx.Request("EquipCannon", cannon.Id)
					elseif cannon.Currency == "Robux" then
						ctx.Request("Purchase", "Product", cannon.Product)
					else
						ctx.Request("BuyCannon", cannon.Id)
					end
				end)
				cards[cannon.Id] = { Status = status, Text = statusText }
			end
		end
	end

	local function refresh()
		if not State.Data then
			return
		end
		if currentTab == "Balls" then
			refreshBalls()
			return
		end
		for _, cannon in ipairs(Config.Cannons) do
			local c = cards[cannon.Id]
			if c then
				local text, color = statusFor(cannon)
				c.Text.Text = text
				local grad = c.Status:FindFirstChildOfClass("UIGradient")
				local top = Kit.Colors[color]
				local bottom = Kit.Colors[color .. "Dark"]
				grad.Color = ColorSequence.new(top, bottom)
			end
		end
		local equipped = Config.GetCannon(State.Data.EquippedCannon)
		info.Text = "Equipped: " .. equipped.Id .. " Cannon  •  x" .. equipped.Mult .. " Power"
	end

	local tabNames = table.clone(Config.CannonTabs)
	table.insert(tabNames, "Balls")
	local tabs = Kit.tabs({ Names = tabNames, Parent = body, OnSelect = function(name)
		currentTab = name
		build()
		refresh()
	end })

	return {
		Frame = panel.Frame,
		OnOpen = function(tab)
			tabs:Select(tab or currentTab)
		end,
		Refresh = refresh,
	}
end

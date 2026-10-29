--[[
	Cannons panel: collection grid with rarity tabs. Click to buy / equip.
	The equipped cannon multiplies Power from every shot.
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

	local panel = Kit.panel({ Title = "Cannons", Icon = "Evolve", Size = UDim2.fromOffset(820, 560) })
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

	local function build()
		Kit.clear(scroll)
		cards = {}
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
					Kit.viewport(card, model, { Size = UDim2.new(1, -10, 0, 96), Position = UDim2.new(0.5, 0, 0, 52), ZIndex = 27 })
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

	local tabs = Kit.tabs({ Names = Config.CannonTabs, Parent = body, OnSelect = function(name)
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

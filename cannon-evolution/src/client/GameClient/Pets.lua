--[[
	Pets panel. "Eggs" tab: one studded egg card with its pets, their odds
	and the 1 / 3 / 8 buttons (1 / 3 / 10 on the Robux egg); arrows step through the eggs. "Pets" tab: inventory with equip, equip best, delete.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

return function(ctx)
	local Kit, Config, State = ctx.Kit, ctx.Config, ctx.State
	local new = Kit.new

	local EGG_COLORS = {
		Starter = Color3.fromRGB(230, 190, 120), Woodland = Color3.fromRGB(80, 180, 80), Nature = Color3.fromRGB(150, 210, 60),
		Ocean = Color3.fromRGB(60, 150, 255), Magic = Color3.fromRGB(160, 80, 255), Hacker = Color3.fromRGB(30, 170, 60),
		Secret = Color3.fromRGB(200, 40, 70),
	}

	local panel = Kit.panel({ Title = "Pets", Icon = "Favorite", Size = UDim2.fromOffset(880, 560) })
	local body = panel.Body
	local content = new("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(0, 52), Size = UDim2.new(1, 0, 1, -52), ZIndex = 22, Parent = body })

	local function model(folder, name)
		local f = ReplicatedStorage:FindFirstChild(folder)
		return f and f:FindFirstChild(name)
	end

	-----------------------------------------------------------------------
	-- Eggs
	-----------------------------------------------------------------------
	-- one big studded card per egg, laid out like the Stone Skipping egg card
	-- (references/image-10.webp): egg on the left, its pets in a row with the
	-- odds under each in the rarity colour, buy buttons bottom right.
	-- < > arrows step through the eggs.
	local selectedEgg = "Starter"
	local function buildEggs()
		Kit.clear(content)
		local egg = Config.GetEgg(selectedEgg)
		local color = EGG_COLORS[egg.Id] or Kit.Colors.Purple
		local show = Kit.card({ Color = color:Lerp(Color3.new(1, 1, 1), 0.1), Color2 = color:Lerp(Color3.new(0, 0, 0), 0.35), Size = UDim2.fromScale(1, 1), ZIndex = 24, Radius = 10, Parent = content })
		Kit.litePattern(show, { Texture = "StudTile", ImageTransparency = 0.82, ZIndex = 24 })
		if egg.Currency == "Robux" then
			Kit.rainbowStroke(show, 4)
		end
		Kit.sparkles(show, 6)
		Kit.text({ Text = egg.Name, Size = 62, StrokeSize = 5, AlignX = Enum.TextXAlignment.Left, FrameSize = UDim2.new(0.6, 0, 0, 70), Position = UDim2.new(0.38, 0, 0, 14), ZIndex = 30, Parent = show })
		local priceLine = egg.Currency == "Robux" and "Exclusive egg" or ((egg.Currency == "Gems" and "Gems " or "$") .. Config.Format(egg.Price) .. " each")
		Kit.text({ Text = priceLine, Size = 26, StrokeSize = 3, Color = Color3.fromRGB(255, 236, 120), AlignX = Enum.TextXAlignment.Left, FrameSize = UDim2.new(0.6, 0, 0, 30), Position = UDim2.new(0.38, 2, 0, 80), ZIndex = 30, Parent = show })

		-- the egg, big, on the left
		local art = new("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(24, 30), Size = UDim2.new(0.34, 0, 1, -60), ZIndex = 25, Parent = show })
		Kit.rays(art, { Size = UDim2.fromOffset(380, 380), Color = Color3.new(1, 1, 1), Transparency = 0.75, ZIndex = 25 })
		local m = model("Eggs", egg.Model)
		if m then
			local vp = Kit.viewport(art, m, { Size = UDim2.fromScale(1, 1), Spin = 25, Zoom = 0.85, ZIndex = 27 })
			Kit.bob(vp, 6, 1.8)
		end

		-- its pets in a row, odds underneath in the rarity colour
		local row = new("Frame", { BackgroundTransparency = 1, Position = UDim2.new(0.38, 0, 0, 122), Size = UDim2.new(0.56, 0, 0, 170), ZIndex = 27, Parent = show })
		Kit.list(row, 6, true, Enum.HorizontalAlignment.Left)
		local total = 0
		for _, entry in ipairs(egg.Pets) do
			total += entry[2]
		end
		local cellW = math.floor(math.min(118, 470 / #egg.Pets))
		for i, entry in ipairs(egg.Pets) do
			local petInfo = Config.Pets[entry[1]]
			local rarity = Config.Rarities[petInfo.Rarity]
			local cell = new("Frame", { BackgroundTransparency = 1, Size = UDim2.fromOffset(cellW, 170), LayoutOrder = i, ZIndex = 27, Parent = row })
			local pm = model("Pets", entry[1])
			if pm then
				Kit.viewport(cell, pm, { Size = UDim2.fromOffset(cellW + 30, cellW + 30), Position = UDim2.new(0.5, 0, 0, 62), Spin = 35, Zoom = 0.8, ZIndex = 28 })
			end
			local chance = entry[2] / total * 100
			local odds = Kit.text({ Text = (chance < 1 and string.format("%.1f", chance) or string.format("%d", math.floor(chance + 0.5))) .. "%", Size = 32, StrokeSize = 4, Color = (petInfo.Rarity == "Common" or petInfo.Rarity == "Uncommon" or petInfo.Rarity == "Secret" or petInfo.Rarity == "Mythic") and Color3.new(1, 1, 1) or rarity.Color, FrameSize = UDim2.new(1, 10, 0, 36), Position = UDim2.new(0.5, 0, 0, 122), Anchor = Vector2.new(0.5, 0), ZIndex = 30, Parent = cell })
			if petInfo.Rarity == "Secret" or petInfo.Rarity == "Mythic" then
				local g = new("UIGradient", { Parent = odds })
				Kit.rainbowFill(g)
			end
		end

		-- buy buttons, bottom right (x10 rainbow, x3 yellow, x1 green)
		local buttons = new("Frame", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -20, 1, -22), Size = UDim2.new(0.6, 0, 0, 66), ZIndex = 28, Parent = show })
		Kit.list(buttons, 14, true, Enum.HorizontalAlignment.Right)
		local function eggButton(order, label, priceText, color, icon, onClick, rainbow)
			local b = Kit.button({ Text = priceText, Icon = icon, Color = color, Size = UDim2.fromOffset(152, 62), TextSize = 30, IconSize = 30, Order = -order, ZIndex = 30, Parent = buttons, OnClick = onClick })
			b.Instance.Name = "EggBuy" .. order -- the tutorial points at EggBuy1
			Kit.text({ Text = label, Size = 28, StrokeSize = 3.5, FrameSize = UDim2.fromOffset(60, 28), Position = UDim2.fromOffset(-10, -20), AlignX = Enum.TextXAlignment.Left, ZIndex = 35, Parent = b.Instance })
			if rainbow then
				Kit.rainbowFill(b.Gradient)
			end
			return b
		end
		if egg.Currency == "Robux" then
			eggButton(1, "x1", Config.Products[egg.Products[1]].Price, "Green", "Robux", function()
				ctx.Request("Purchase", "Product", egg.Products[1])
			end)
			eggButton(2, "x3", Config.Products[egg.Products[3]].Price, "Yellow", "Robux", function()
				ctx.Request("Purchase", "Product", egg.Products[3])
			end)
			eggButton(3, "x10", Config.Products[egg.Products[10]].Price, "Green", "Robux", function()
				ctx.Request("Purchase", "Product", egg.Products[10])
			end, true)
		else
			local icon = egg.Currency == "Gems" and "Gem" or "Cash"
			eggButton(1, "x1", Config.Format(egg.Price), "Green", icon, function()
				ctx.Request("Hatch", egg.Id, 1)
			end)
			-- x3 and x8 hatch at once with their gamepass (8x Open covers x3 too); without it the button sells the pass
			local function multiButton(order, n, pass, color, rainbow)
				local owned = State.Passes[pass] or (n == 3 and State.Passes.OctoOpen)
				if owned then
					eggButton(order, "x" .. n, Config.Format(egg.Price * n), color, icon, function()
						ctx.Request("Hatch", egg.Id, n)
					end, rainbow)
				else
					eggButton(order, "x" .. n, "Unlock", color, "Robux", function()
						ctx.Request("Purchase", "Pass", pass)
					end, rainbow)
				end
			end
			multiButton(2, 3, "TripleOpen", "Yellow")
			multiButton(3, 8, "OctoOpen", "Green", true)
		end

		-- step through the eggs
		local index = 1
		for i, e in ipairs(Config.Eggs) do
			if e.Id == selectedEgg then
				index = i
			end
		end
		for _, dir in ipairs({ -1, 1 }) do
			Kit.button({
				Text = dir < 0 and "<" or ">", Color = "Dark", Size = UDim2.fromOffset(44, 70), TextSize = 36,
				Position = dir < 0 and UDim2.new(0, -14, 0.5, 0) or UDim2.new(1, 14, 0.5, 0), Anchor = Vector2.new(dir < 0 and 0 or 1, 0.5),
				ZIndex = 36, Parent = show, OnClick = function()
					selectedEgg = Config.Eggs[(index - 1 + dir) % #Config.Eggs + 1].Id
					buildEggs()
				end,
			})
		end
	end

	-----------------------------------------------------------------------
	-- Inventory
	-----------------------------------------------------------------------
	local selectedPet = nil
	local function buildInventory()
		Kit.clear(content)
		local data = State.Data
		local maxEquip = Config.MAX_EQUIPPED + (State.Passes.ExtraEquip and Config.EXTRA_EQUIP or 0)
		local equipped = 0
		for _, p in ipairs(data.Pets) do
			if p.Equipped then
				equipped += 1
			end
		end
		local top = new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 46), ZIndex = 24, Parent = content })
		Kit.text({ Text = "Equipped " .. equipped .. "/" .. maxEquip .. "   •   Pets " .. #data.Pets .. "/" .. Config.MAX_PETS .. "   •   +" .. Config.Format(Config.PetBoost(data) * 100) .. "% Power", Size = 22, AlignX = Enum.TextXAlignment.Left, FrameSize = UDim2.new(1, -360, 1, 0), ZIndex = 25, Parent = top })
		Kit.button({ Text = "Equip Best", Color = "Green", Icon = "Favorite", Size = UDim2.fromOffset(170, 42), Position = UDim2.new(1, -180, 0, 2), ZIndex = 26, Parent = top, OnClick = function()
			ctx.Request("EquipBest")
		end })
		if not State.Passes.ExtraEquip then
			Kit.button({ Text = "+2 Slots", Icon = "Robux", Color = "Yellow", Size = UDim2.fromOffset(160, 42), Position = UDim2.new(1, -350, 0, 2), ZIndex = 26, Parent = top, OnClick = function()
				ctx.Request("Purchase", "Pass", "ExtraEquip")
			end })
		end

		local grid = Kit.scrolling({ Parent = content, Position = UDim2.fromOffset(0, 52), Size = UDim2.new(1, -230, 1, -52), ZIndex = 24 })
		Kit.grid(grid, UDim2.fromOffset(96, 110), 8)
		local sorted = table.clone(data.Pets)
		table.sort(sorted, function(a, b)
			if a.Equipped ~= b.Equipped then
				return a.Equipped
			end
			return (Config.Pets[a.Name] and Config.Pets[a.Name].Boost or 0) > (Config.Pets[b.Name] and Config.Pets[b.Name].Boost or 0)
		end)
		for i, pet in ipairs(sorted) do
			local petInfo = Config.Pets[pet.Name]
			if petInfo then
				local rarity = Config.Rarities[petInfo.Rarity]
				local cell = Kit.card({ Button = true, Color = rarity.Color, Order = i, Parent = grid, ZIndex = 25, Radius = 10 })
				if pet.Equipped then
					Kit.stroke(4, Kit.Colors.Green, cell)
					Kit.text({ Text = "✔", Size = 22, Color = Kit.Colors.Green, FrameSize = UDim2.fromOffset(24, 24), Position = UDim2.fromOffset(4, 2), ZIndex = 30, Parent = cell })
				end
				if selectedPet == pet.Id then
					Kit.stroke(4, Kit.Colors.Yellow, cell)
				end
				local pm = model("Pets", pet.Name)
				if pm then
					Kit.viewport(cell, pm, { Size = UDim2.new(1, -8, 0, 70), Position = UDim2.new(0.5, 0, 0, 42), ZIndex = 27 })
				else
					Kit.icon("Favorite", { Size = UDim2.fromOffset(54, 54), Position = UDim2.new(0.5, 0, 0, 40), Anchor = Vector2.new(0.5, 0.5), ZIndex = 27, Parent = cell })
				end
				Kit.text({ Text = "x" .. string.format("%.2f", 1 + petInfo.Boost):gsub("%.?0+$", ""), Size = 18, Color = Kit.Colors.Yellow, FrameSize = UDim2.new(1, 0, 0, 22), Position = UDim2.new(0.5, 0, 1, -4), Anchor = Vector2.new(0.5, 1), ZIndex = 29, Parent = cell })
				cell.Activated:Connect(function()
					Kit.playSound("Click")
					selectedPet = pet.Id
					buildInventory()
				end)
			end
		end
		if #sorted == 0 then
			Kit.text({ Text = "No pets yet! Hatch an egg 🥚", Size = 30, FrameSize = UDim2.new(1, 0, 0, 60), Position = UDim2.fromOffset(0, 80), ZIndex = 26, Parent = grid })
		end

		-- details side
		local side = Kit.card({ Color = Kit.Colors.Card, Position = UDim2.new(1, -220, 0, 52), Size = UDim2.new(0, 220, 1, -52), ZIndex = 24, Parent = content })
		local pet
		for _, p in ipairs(data.Pets) do
			if p.Id == selectedPet then
				pet = p
			end
		end
		if not pet then
			Kit.text({ Text = "Select a pet", Size = 24, FrameSize = UDim2.new(1, 0, 0, 40), Position = UDim2.fromOffset(0, 20), ZIndex = 26, Parent = side })
			return
		end
		local petInfo = Config.Pets[pet.Name]
		local rarity = Config.Rarities[petInfo.Rarity]
		Kit.rays(side, { Size = UDim2.fromOffset(240, 240), Position = UDim2.new(0.5, 0, 0, 100), Color = rarity.Color, Transparency = 0.5, ZIndex = 25 })
		local pm = model("Pets", pet.Name)
		if pm then
			Kit.viewport(side, pm, { Size = UDim2.fromOffset(160, 160), Position = UDim2.new(0.5, 0, 0, 100), Spin = 40, ZIndex = 27 })
		end
		Kit.text({ Text = petInfo.Name, Size = 30, FrameSize = UDim2.new(1, 0, 0, 34), Position = UDim2.fromOffset(0, 186), ZIndex = 28, Parent = side })
		Kit.text({ Text = petInfo.Rarity, Size = 22, Color = rarity.Color, FrameSize = UDim2.new(1, 0, 0, 26), Position = UDim2.fromOffset(0, 220), ZIndex = 28, Parent = side })
		Kit.text({ Text = "+" .. Config.Format(petInfo.Boost * 100) .. "% Power", Size = 24, Color = Kit.Colors.Yellow, FrameSize = UDim2.new(1, 0, 0, 28), Position = UDim2.fromOffset(0, 248), ZIndex = 28, Parent = side })
		Kit.button({ Text = pet.Equipped and "Unequip" or "Equip", Color = pet.Equipped and "Gray" or "Green", Size = UDim2.new(1, -20, 0, 46), Position = UDim2.new(0.5, 0, 1, -66), Anchor = Vector2.new(0.5, 1), ZIndex = 29, Parent = side, OnClick = function()
			ctx.Request("EquipPet", pet.Id, not pet.Equipped)
		end })
		Kit.button({ Text = "Delete", Icon = "Delete", Color = "Red", Size = UDim2.new(1, -20, 0, 46), Position = UDim2.new(0.5, 0, 1, -12), Anchor = Vector2.new(0.5, 1), ZIndex = 29, Parent = side, OnClick = function()
			selectedPet = nil
			ctx.Request("DeletePet", pet.Id)
		end })
	end

	local current = "Eggs"
	local tabs = Kit.tabs({ Names = { "Eggs", "Pets" }, Parent = body, OnSelect = function(name)
		current = name
		if not State.Data then
			return
		end
		if name == "Eggs" then
			buildEggs()
		else
			buildInventory()
		end
	end })

	local lastPetsKey = ""
	local lastPassKey = ""
	return {
		Frame = panel.Frame,
		OnOpen = function(tab, eggId)
			if eggId and Config.GetEgg(eggId) then
				selectedEgg = eggId
			end
			tabs:Select(tab or current)
		end,
		Refresh = function()
			if not State.Data then
				return
			end
			if current == "Eggs" then
				-- swap "Unlock" for the price once a hatch gamepass is bought
				local passKey = tostring(State.Passes.TripleOpen) .. tostring(State.Passes.OctoOpen)
				if passKey ~= lastPassKey then
					lastPassKey = passKey
					buildEggs()
				end
				return
			end
			-- rebuild only when the pet list actually changed
			local parts = {}
			for _, p in ipairs(State.Data.Pets) do
				table.insert(parts, p.Id .. (p.Equipped and "e" or ""))
			end
			local key = table.concat(parts, ",")
			if key ~= lastPetsKey then
				lastPetsKey = key
				buildInventory()
			end
		end,
	}
end

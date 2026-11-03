--!strict
-- Garage app, two tabs:
--   MY CARS  every car you own, one card each with a picture. SPAWN brings it next to you (the old one goes away
--            first); the car that's out shows OUT NOW with PUT AWAY.
--   DEALER   every car for sale, cheapest first, with price and top speed. BUY asks "Tap again to buy" first so
--            nobody spends $60,000 by accident; cars you can't afford say how much more you need.
-- The server does every check (owned, cash, cooldown, room, indoors) and answers with a toast.
-- Reads Config/Vehicles, the save's Cash + Garage.Owned, the player attribute MTL_Car, and the body-only previews
-- in ReplicatedStorage.MTL_CarPreviews (a car without one just shows its initials). Phone.open("Garage",
-- { tab = "Dealer" }) opens straight on the dealer.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Vehicles = require(ReplicatedStorage.MTL.Config.Vehicles)

local App = { id = "Garage", title = "Garage" }
local stylePanel: (any, Instance, any, any, any) -> ()

local TABS = { { "Mine", "My cars" }, { "Dealer", "Dealer" } }

local function money(n: number): string
	local s = tostring(math.floor(n))
	local out = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	return "$" .. (string.gsub(out, "^,", ""))
end

-- A 3/4 front view of the car's body-only preview model, or nil when there isn't one yet.
local function picture(parent: Instance, car: any, Theme: any): Frame
	local P = Theme.Phone
	local holder = Instance.new("Frame")
	holder.Name = "Picture"
	holder.LayoutOrder = 0
	holder.Size = UDim2.new(1, 0, 0, 120)
	holder.BackgroundColor3 = Color3.fromRGB(58, 60, 70)
	holder.BorderSizePixel = 0
	holder.Parent = parent
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 12)
	corner.Parent = holder
	local grad = Instance.new("UIGradient")
	grad.Rotation = 90
	grad.Color = ColorSequence.new(Color3.fromRGB(255, 255, 255), Color3.fromRGB(150, 150, 160))
	grad.Parent = holder

	local folder = ReplicatedStorage:FindFirstChild(Vehicles.PreviewFolder)
	local src = folder and folder:FindFirstChild(car.template)
	if not src or not src:IsA("Model") then
		local l = Instance.new("TextLabel")
		l.Name = "Placeholder"
		l.Size = UDim2.fromScale(1, 1)
		l.BackgroundTransparency = 1
		l.FontFace = Theme.Fonts.Display
		l.Text = string.upper(car.class or "")
		l.TextColor3 = P.CardHover or Color3.fromRGB(90, 92, 100)
		l.TextSize = 22
		l.Parent = holder
		return holder
	end
	local view = Instance.new("ViewportFrame")
	view.Name = "View"
	view.Size = UDim2.fromScale(1, 1)
	view.BackgroundTransparency = 1
	view.Ambient = Color3.fromRGB(150, 150, 160)
	view.LightColor = Color3.fromRGB(255, 250, 240)
	view.LightDirection = Vector3.new(-0.5, -1, -0.6)
	view.Parent = holder
	local m = (src :: Model):Clone()
	m.Parent = view
	local cf, size = m:GetBoundingBox()
	local pivot = m:GetPivot()
	local look = pivot.LookVector
	local dir = (look * 1.0 - pivot.RightVector * 0.95 + Vector3.yAxis * 0.42).Unit
	local cam = Instance.new("Camera")
	cam.FieldOfView = 30
	local dist = (size.Magnitude / 2) / math.tan(math.rad(15)) * 0.86
	cam.CFrame = CFrame.lookAt(cf.Position + dir * dist, cf.Position - Vector3.new(0, size.Y * 0.08, 0))
	cam.Parent = view
	view.CurrentCamera = cam
	return holder
end

local render: (any, any, any) -> ()

-- A row of colour dots; `sel` = the selected id. onPick(id).
local function swatches(ctx: any, parent: Instance, items: { any }, sel: string, factory: Color3?, order: number, onPick: (string) -> ())
	local UIKit, Theme = ctx.UIKit, ctx.Theme
	local C = Theme.Colors
	local row = UIKit.new("Frame", {
		Name = "Swatches",
		LayoutOrder = order,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		Parent = parent,
	})
	local grid = Instance.new("UIGridLayout")
	grid.CellSize = UDim2.fromOffset(30, 30)
	grid.CellPadding = UDim2.fromOffset(9, 8)
	grid.SortOrder = Enum.SortOrder.LayoutOrder
	grid.Parent = row
	for i, it in items do
		local on = it.id == sel
		local b = UIKit.new("TextButton", {
			Name = "Swatch_" .. it.id,
			LayoutOrder = i,
			BackgroundColor3 = it.color or factory or Color3.fromRGB(60, 62, 70),
			AutoButtonColor = false,
			Text = if it.color == nil and it.id == "Off" then "/" else "",
			TextColor3 = C.TextDim,
			TextSize = 14,
			FontFace = Theme.Fonts.Bold,
			Parent = row,
		}, { UIKit.corner(UDim.new(1, 0)) })
		local ring = UIKit.stroke(0, if on then C.Text else Color3.fromRGB(80, 82, 90))
		ring.Thickness = if on then 2.5 else 1
		ring.Parent = b
		b.Activated:Connect(function()
			ctx.sfx("PhoneTap")
			onPick(it.id)
		end)
	end
	return row
end

-- Paint + underglow for one owned car: pick, see the price, then Apply (nothing is charged until Apply).
stylePanel = function(ctx: any, card: Instance, car: any, d: any, state: any)
	local UIKit, Theme = ctx.UIKit, ctx.Theme
	local C = Theme.Colors
	local S = Vehicles.Style
	local saved = (d and d.Garage and d.Garage.Style and d.Garage.Style[car.id]) or {}
	local pick = state.pick
	local paint = pick.paint or saved.paint or "Factory"
	local glow = pick.glow or saved.glow or "Off"
	local cost = 0
	local p = Vehicles.paint(paint)
	if paint ~= (saved.paint or "Factory") and p and p.color then
		cost += S.PaintPrice
	end
	local g = Vehicles.glow(glow)
	if g and g.color and not saved.glowOwned then
		cost += S.GlowPrice
	end
	local function pickAndRedraw(field: string, id: string)
		pick[field] = id
		render(ctx, ctx.data() or d, state)
	end
	UIKit.label(card, "PAINT  ·  " .. money(S.PaintPrice), { size = 11, bold = true, dim = true, name = "PaintLabel", order = 20 })
	UIKit.label(card, (p and p.name) or paint, { size = 13, bold = true, name = "PaintName", order = 21 })
	swatches(ctx, card, S.Paints, paint, nil, 22, function(id)
		pickAndRedraw("paint", id)
	end)
	UIKit.label(card, "UNDERGLOW  ·  " .. (if saved.glowOwned then "unlocked" else money(S.GlowPrice) .. " once"), { size = 11, bold = true, dim = true, name = "GlowLabel", order = 23 })
	UIKit.label(card, (g and g.name) or glow, { size = 13, bold = true, name = "GlowName", order = 24 })
	swatches(ctx, card, S.Glows, glow, nil, 25, function(id)
		pickAndRedraw("glow", id)
	end)
	local changed = (pick.paint ~= nil and pick.paint ~= (saved.paint or "Factory")) or (pick.glow ~= nil and pick.glow ~= (saved.glow or "Off"))
	local cash = (d and d.Cash) or 0
	UIKit.button(card, if not changed then "Pick a colour" elseif cost > cash then ("Need " .. money(cost - cash) .. " more") elseif cost > 0 then ("Apply  ·  " .. money(cost)) else "Apply", {
		style = "primary",
		name = "Apply",
		order = 26,
		height = 38,
		disabled = not changed or cost > cash,
		onClick = function()
			ctx.action("styleCar", { id = car.id, paint = pick.paint, glow = pick.glow })
			state.pick = {}
		end,
	})
end

render = function(ctx: any, d: any, state: any)
	ctx.clear()
	local UIKit, Theme = ctx.UIKit, ctx.Theme
	local C, P = Theme.Colors, Theme.Phone
	UIKit.header(ctx.frame, "Garage")
	local list = UIKit.scroll(ctx.frame, 44, "Cars")
	local owned = (d and d.Garage and d.Garage.Owned) or {}
	local cash = (d and d.Cash) or 0
	local out = Players.LocalPlayer:GetAttribute("MTL_Car")
	local order = 0
	local function nextOrder(): number
		order += 1
		return order
	end

	-- tabs
	local tabs = UIKit.new("Frame", {
		Name = "Tabs",
		LayoutOrder = nextOrder(),
		Size = UDim2.new(1, 0, 0, 34),
		BackgroundColor3 = P.Card,
		Parent = list,
	}, { UIKit.corner(UDim.new(0, 10)), UIKit.list(0, true), UIKit.padding(3) })
	for i, t in TABS do
		local on = state.tab == t[1]
		local b = UIKit.new("TextButton", {
			Name = "Tab_" .. t[1],
			LayoutOrder = i,
			Size = UDim2.new(1 / #TABS, 0, 1, 0),
			BackgroundColor3 = P.CardHover,
			BackgroundTransparency = if on then 0 else 1,
			AutoButtonColor = false,
			FontFace = Theme.Fonts.Bold,
			Text = t[2],
			TextColor3 = if on then C.Text else C.TextDim,
			TextSize = 13,
			Parent = tabs,
		}, { UIKit.corner(UDim.new(0, 8)) })
		b.Activated:Connect(function()
			if state.tab ~= t[1] then
				state.tab = t[1]
				ctx.sfx("PhoneTap")
				render(ctx, ctx.data() or d, state)
			end
		end)
	end

	if state.tab == "Mine" then
		local any = false
		for _, car in Vehicles.Cars do
			if not owned[car.id] then
				continue
			end
			any = true
			local isOut = out == car.id
			local card = UIKit.card(list, nextOrder(), "Car_" .. car.id)
			if isOut then
				UIKit.stroke(0, C.Accent).Parent = card
			end
			picture(card, car, Theme)
			UIKit.label(card, car.name, { size = 20, bold = true, name = "Title", order = 1 })
			UIKit.label(card, car.maker .. "  ·  " .. car.class, { size = 12, dim = true, name = "Sub", order = 2 })
			if car.blurb then
				UIKit.label(card, car.blurb, { size = 12, dim = true, wrap = true, name = "Blurb", order = 3 })
			end
			if isOut then
				UIKit.label(card, "OUT NOW", { size = 11, bold = true, color = C.Accent, name = "Status", order = 4 })
			end
			UIKit.button(card, if isOut then "Spawn again" else "Spawn", {
				style = "primary",
				name = "Spawn",
				order = 10,
				onClick = function()
					ctx.sfx("PhoneTap")
					ctx.action("spawnCar", { id = car.id })
				end,
			})
			if isOut then
				UIKit.button(card, "Put away", {
					style = "secondary",
					name = "PutAway",
					order = 11,
					height = 36,
					onClick = function()
						ctx.action("despawnCar", {})
					end,
				})
			end
			local styling = state.styling == car.id
			UIKit.button(card, if styling then "Close style" else "Style", {
				style = "secondary",
				name = "StyleToggle",
				order = 12,
				height = 34,
				onClick = function()
					ctx.sfx("PhoneTap")
					state.styling = if styling then nil else car.id
					state.pick = {}
					render(ctx, ctx.data() or d, state)
				end,
			})
			if styling then
				stylePanel(ctx, card, car, d, state)
			end
		end
		if not any then
			UIKit.empty(list, "No cars yet. The dealer tab has some.", nextOrder())
		end
		return
	end

	-- dealer
	local wallet = UIKit.label(list, "Cash  " .. money(cash), { size = 14, bold = true, color = C.Money or C.Accent, name = "Cash", order = nextOrder() })
	wallet.TextXAlignment = Enum.TextXAlignment.Right
	for _, car in Vehicles.Cars do
		if not car.price then
			continue
		end
		local have = owned[car.id] == true
		local card = UIKit.card(list, nextOrder(), "Deal_" .. car.id)
		picture(card, car, Theme)
		UIKit.label(card, car.name, { size = 20, bold = true, name = "Title", order = 1 })
		local bits = { car.maker, car.class }
		if car.speed then
			table.insert(bits, "Top " .. car.speed .. " mph")
		end
		UIKit.label(card, table.concat(bits, "  ·  "), { size = 12, dim = true, name = "Sub", order = 2 })
		if car.blurb then
			UIKit.label(card, car.blurb, { size = 12, dim = true, wrap = true, name = "Blurb", order = 3 })
		end
		UIKit.label(card, money(car.price), { size = 18, bold = true, color = if have then C.TextDim else (C.Money or C.Accent), name = "Price", order = 4 })
		if have then
			UIKit.label(card, "IN YOUR GARAGE", { size = 11, bold = true, color = C.Accent, name = "Owned", order = 5 })
		elseif cash < car.price then
			UIKit.button(card, "Need " .. money(car.price - cash) .. " more", { style = "secondary", name = "Buy", order = 10, height = 38, disabled = true })
		else
			local armed = false
			local btn: TextButton
			btn = UIKit.button(card, "Buy", {
				style = "primary",
				name = "Buy",
				order = 10,
				onClick = function()
					if not armed then
						armed = true
						ctx.sfx("PhoneTap")
						btn.Text = "TAP AGAIN TO BUY  ·  " .. money(car.price)
						task.delay(Vehicles.Tuning.BuyConfirmSeconds or 3, function()
							if armed and btn.Parent then
								armed = false
								btn.Text = "BUY"
							end
						end)
						return
					end
					armed = false
					btn.Text = "BUYING..."
					ctx.action("buyCar", { id = car.id })
					task.delay(4, function() -- no answer (or a "not enough cash" toast): back to normal
						if btn.Parent and btn.Text == "BUYING..." then
							btn.Text = "BUY"
						end
					end)
				end,
			})
		end
	end
end

local function styleKey(d: any): string
	local bits = {}
	for id, st in (d.Garage and d.Garage.Style) or {} do
		table.insert(bits, id .. ":" .. tostring(st.paint) .. ":" .. tostring(st.glow) .. ":" .. tostring(st.glowOwned))
	end
	table.sort(bits)
	return table.concat(bits, ",")
end

function App.mount(frame: Frame, ctx: any)
	local state = { tab = if ctx.args and ctx.args.tab == "Dealer" then "Dealer" else "Mine", styling = nil, pick = {} }
	local last = ""
	local function refresh(d: any)
		if not d or not frame.Parent then
			return
		end
		local keys = {}
		for id, v in (d.Garage and d.Garage.Owned) or {} do
			if v then
				table.insert(keys, id)
			end
		end
		table.sort(keys)
		-- cash only matters on the dealer tab (which buttons say Buy vs Need $X more)
		local key = table.concat(keys, ",")
			.. "|"
			.. tostring(Players.LocalPlayer:GetAttribute("MTL_Car"))
			.. "|"
			.. (if state.tab == "Dealer" or state.styling then tostring(d.Cash) else "")
			.. "|"
			.. styleKey(d)
		if key ~= last then
			last = key
			render(ctx, d, state)
		end
	end
	ctx.onData(refresh)
	ctx.track(Players.LocalPlayer:GetAttributeChangedSignal("MTL_Car"):Connect(function()
		refresh(ctx.data())
	end))
end

return App

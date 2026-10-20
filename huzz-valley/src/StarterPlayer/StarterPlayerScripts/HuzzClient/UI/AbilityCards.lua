--[[
	The ability cards (owner, Oct 20 15:13: "Please then make the abilities be bought, add a few more abilities"): one
	card per round ability of a side (Config/Powers.Shop order), in the kit's navy rows. Built by the Shop's ABILITIES
	section, which is where you buy them AND pick what you bring (there is no separate window: an 8th Menu row didn't
	fit the Menu, critic Oct 20):
	  local h = AbilityCards.build(slot) -- no opts: your loadout line, then RUNNERS and CATCHERS at the slot's width
	  local cards = AbilityCards.build(parent, { side = "Runner", width = 600, y = 0 }) -- one side's grid
	  -- cards.height: how tall the grid is; cards.refresh(): redraw from the save
	Each card: the ability's picture (his own power pictures in their coloured tiles, owner Oct 20 20:34: "bring back the
	old pictures for the powers", tools/icons/cut_power_tiles.py), its name, what it does, its cooldown in its colour,
	how to beat it, and a button:
	  not owned  BUY 600 (coins, ActionService "BuyAbility": the server checks and takes the coins; Toast says why not)
	  runner     EQUIP / EQUIPPED (on Q; "EquipAbility", key Runner)
	  catcher    Q and E (each glows green when that key holds it; picking the other key's one swaps them)
	A runner grid starts with RANDOM (a new one you own each round), unless opts.random == false. Starters (Shield,
	Bear Trap, Slow Wave) say STARTER. Equips play from the next round. Prices and rules: Shared/AbilityRules.
	opts: side ("Runner" | "Catcher"), width (default 600), y (top, default 0), columns (default 2), random (runner
	RANDOM card, default true), name (the grid frame's name, default "<Side>Abilities").
]]
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Powers = require(Shared.Config.Powers)
local AbilityRules = require(Shared.AbilityRules)
local UI = script.Parent
local Theme = require(UI.Theme)
local Kit = require(UI.Kit)
local State = require(UI.State)
local Toast = require(UI.Toast)
local Motion = require(UI.Motion)

local new = Kit.new
local C, F = Theme.Colors, Theme.Fonts

local AbilityCards = {}

AbilityCards.CARD_H = 116
AbilityCards.GAP = 8
local RANDOM = { Name = "Random", Card = "RANDOM", Icon = "AbilityRandom", Tile = Color3.fromRGB(17, 143, 124), Emoji = "🎲",
	Text = "A new one you own each round", Accent = C.Accent }

local function line(props: { [string]: any }, stroke: number?): TextLabel
	props.TextWrapped = false
	local l = Kit.text(props)
	new("UIStroke", { Name = "Outline", Color = C.TitleStroke, Thickness = stroke or 1.2, LineJoinMode = Enum.LineJoinMode.Round, Parent = l })
	return l
end

local function cooldownText(def): string
	if def.OncePerRound then return "ONCE A ROUND" end
	if def.Cooldown then return string.format("COOLDOWN %ds", def.Cooldown) end
	return ""
end

-- One card. Returns { row, paint() }.
local function card(parent: Instance, name: string, x: number, y: number, w: number, side: string)
	local def = if name == "Random" then RANDOM else Powers[name]
	local h = AbilityCards.CARD_H
	local row = new("Frame", { Name = name, Position = UDim2.fromOffset(x, y), Size = UDim2.fromOffset(w, h), BackgroundColor3 = C.Row,
		BackgroundTransparency = Theme.Transparency.Row, BorderSizePixel = 0, ZIndex = 2, Parent = parent }, { Kit.corner(7), Kit.stroke(C.RowBorder, 2) })
	-- his picture in its coloured tile (owner, Oct 20 20:34: "bring back the old pictures for the powers ... We want to
	-- stand out"): the picture rounded (UICorner on the image itself), rimmed in his tile's colour (Config/Powers Tile)
	local rimColor = def.Tile or def.Accent
	local tile = new("Frame", { Name = "Tile", Position = UDim2.fromOffset(10, 10), Size = UDim2.fromOffset(60, 60),
		BackgroundColor3 = rimColor:Lerp(Color3.new(0, 0, 0), 0.6), BorderSizePixel = 0, ZIndex = 3, Parent = row }, { Kit.corner(8), Kit.stroke(rimColor, 2) })
	if def.Icon then
		local icon = Kit.icon(def.Icon, { Name = "Icon", Size = UDim2.fromScale(1, 1), ZIndex = 4, Parent = tile })
		Kit.attach(Kit.corner(8), icon)
	else
		Kit.text({ Name = "Glyph", Text = def.Emoji or "", TextSize = 34, TextXAlignment = Enum.TextXAlignment.Center, TextWrapped = false,
			Size = UDim2.fromScale(1, 1), ZIndex = 4, Parent = tile })
	end
	local textW = w - 84 - 10
	local title = line({ Name = "AbilityName", Text = string.upper(def.Name), FontFace = F.Name, TextSize = 17, Position = UDim2.fromOffset(80, 8),
		Size = UDim2.fromOffset(textW, 20), ZIndex = 3, Parent = row }, 1.5)
	Kit.fitLine(title, textW - 70, 17, 12, true)
	local tag = line({ Name = "Tag", Text = "", FontFace = F.Number, TextSize = 11, TextColor3 = C.SubText, TextXAlignment = Enum.TextXAlignment.Right,
		AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -10, 0, 10), Size = UDim2.fromOffset(70, 14), ZIndex = 3, Parent = row }, 1)
	line({ Name = "Does", Text = def.Text, FontFace = F.Body, TextSize = 14, TextColor3 = C.NoteText, Position = UDim2.fromOffset(80, 29),
		Size = UDim2.fromOffset(textW, 17), ZIndex = 3, TextTruncate = Enum.TextTruncate.AtEnd, Parent = row }, 1)
	-- how to beat it (two lines at most), then the cooldown in its colour on the bottom row, left of the button
	local counter = Kit.text({ Name = "Counter", Text = if def.Counter then "Beat it: " .. def.Counter else "", FontFace = F.Body, TextSize = 13,
		TextColor3 = C.SubText, TextWrapped = true, TextYAlignment = Enum.TextYAlignment.Top, Position = UDim2.fromOffset(80, 48),
		Size = UDim2.fromOffset(textW, 30), ZIndex = 3, Parent = row })
	new("UIStroke", { Name = "Outline", Color = C.TitleStroke, Thickness = 1, LineJoinMode = Enum.LineJoinMode.Round, Parent = counter })
	line({ Name = "Cooldown", Text = cooldownText(def), FontFace = F.Number, TextSize = 12, TextColor3 = def.Accent, Position = UDim2.new(0, 12, 1, -31),
		Size = UDim2.fromOffset(w - 24 - 120, 16), ZIndex = 3, Parent = row }, 1)
	-- the buttons, bottom right: BUY, EQUIP, or Q and E
	local buy = Kit.button({ Name = "Buy", Text = tostring(def.Price or ""), Style = "CoinAction", Icon = "CurrencyCoin", IconSize = 18, FontFace = F.Button,
		TextSize = 15, Corner = 6, RimThickness = 1.5, AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -10, 1, -8), Size = UDim2.fromOffset(116, 30),
		ZIndex = 4, Parent = row })
	local equip = Kit.button({ Name = "Equip", Text = "EQUIP", Style = "Slate", FontFace = F.Button, TextSize = 14, Corner = 6, RimThickness = 1.5,
		AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -10, 1, -8), Size = UDim2.fromOffset(116, 30), ZIndex = 4, Parent = row })
	local keyQ = Kit.button({ Name = "KeyQ", Text = "Q", Style = "Slate", FontFace = F.Button, TextSize = 15, Corner = 6, RimThickness = 1.5,
		AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -56, 1, -8), Size = UDim2.fromOffset(42, 30), ZIndex = 4, Parent = row })
	local keyE = Kit.button({ Name = "KeyE", Text = "E", Style = "Slate", FontFace = F.Button, TextSize = 15, Corner = 6, RimThickness = 1.5,
		AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -10, 1, -8), Size = UDim2.fromOffset(42, 30), ZIndex = 4, Parent = row })

	local busy = false
	local function act(verb: string, ...)
		if busy then return end
		busy = true
		local args = table.pack(...)
		task.spawn(function()
			local ok, why = State.action(verb, table.unpack(args, 1, args.n))
			busy = false
			if ok then
				Motion.pop(row)
				if verb == "BuyAbility" then Toast.show(string.upper(def.Name) .. " is yours!") end
			else
				Toast.show(why or "Couldn't do that. Try again.")
			end
		end)
	end
	buy.onClick(function() act("BuyAbility", name) end)
	equip.onClick(function() act("EquipAbility", "Runner", name) end)
	keyQ.onClick(function() act("EquipAbility", "CatcherQ", name) end)
	keyE.onClick(function() act("EquipAbility", "CatcherE", name) end)

	local function paint()
		local data = State.data or {}
		local owned = name == "Random" or AbilityRules.owns(data, name)
		local loadout = AbilityRules.loadout(data)
		tag.Text = if name == "Random" then "" elseif def.Starter then "STARTER" elseif owned then "OWNED" else ""
		buy.Instance.Visible = not owned
		equip.Instance.Visible = owned and side == "Runner"
		keyQ.Instance.Visible = owned and side == "Catcher"
		keyE.Instance.Visible = owned and side == "Catcher"
		if not owned then
			local coins = if type(data.Coins) == "number" then data.Coins else 0
			buy.setStyle(if coins >= (def.Price or 0) then "CoinAction" else "Disabled")
		elseif side == "Runner" then
			local on = loadout.Runner == name
			equip.setText(if on then "EQUIPPED" else "EQUIP")
			equip.setStyle(if on then "Selected" else "Slate")
		else
			keyQ.setStyle(if loadout.CatcherQ == name then "Selected" else "Slate")
			keyE.setStyle(if loadout.CatcherE == name then "Selected" else "Slate")
		end
		local on = (side == "Runner" and loadout.Runner == name) or (side == "Catcher" and (loadout.CatcherQ == name or loadout.CatcherE == name))
		local stroke = row:FindFirstChildOfClass("UIStroke")
		if stroke then stroke.Color = if on then C.Accent else C.RowBorder end
	end
	return { row = row, paint = paint }
end

local function buildSide(parent: Instance, o: { [string]: any })
	local side = o.side or "Runner"
	local width = o.width or 600
	local cols = o.columns or 2
	local gap = AbilityCards.GAP
	local names = table.clone(Powers.Shop[side] or {})
	if side == "Runner" and o.random ~= false then table.insert(names, 1, "Random") end
	local rows = math.ceil(#names / cols)
	local cardW = math.floor((width - (cols - 1) * gap) / cols)
	local height = rows * AbilityCards.CARD_H + (rows - 1) * gap
	local grid = new("Frame", { Name = o.name or (side .. "Abilities"), Position = UDim2.fromOffset(o.x or 0, o.y or 0), Size = UDim2.fromOffset(width, height),
		BackgroundTransparency = 1, ZIndex = 2, Parent = parent })
	local cards = {}
	for i, name in names do
		local c = (i - 1) % cols
		local r = (i - 1) // cols
		cards[name] = card(grid, name, c * (cardW + gap), r * (AbilityCards.CARD_H + gap), cardW, side)
	end
	local function refresh()
		for _, c in cards do c.paint() end
	end
	State.changed(function() if grid.Parent then refresh() end end)
	refresh()
	return { frame = grid, cards = cards, height = height, refresh = refresh }
end

-- Both sides in one frame, for the Shop's ABILITIES section: what you bring (one line, green; a change plays from the
-- next round), then a RUNNERS
-- title and its cards (RANDOM first), then CATCHERS and its cards. Sizes the parent frame and returns the height.
local function nameOf(key: string): string
	if key == "Random" then return "RANDOM" end
	local d = Powers[key]
	return if d then string.upper(d.Name) else key
end
local function buildBoth(parent: Instance): number
	local width = if parent:IsA("GuiObject") and parent.Size.X.Offset > 0 then parent.Size.X.Offset else 600
	local now = line({ Name = "YourLoadout", Text = "", FontFace = F.Name, TextSize = 16, TextColor3 = C.Accent, Position = UDim2.fromOffset(2, 0),
		Size = UDim2.fromOffset(width - 4, 20), ZIndex = 2, Parent = parent }, 1.5)
	local function paintNow()
		local l = AbilityRules.loadout(State.data or {})
		now.Text = string.format("YOU BRING   RUNNER Q: %s   ·   CATCHER Q: %s  E: %s", nameOf(l.Runner), nameOf(l.CatcherQ), nameOf(l.CatcherE))
	end
	paintNow()
	State.changed(function() if now.Parent then paintNow() end end)
	local y = 30
	for i, side in { "Runner", "Catcher" } do
		if i > 1 then y += 14 end
		line({ Name = side .. "Title", Text = string.upper(side) .. "S", FontFace = F.Name, TextSize = 18, Position = UDim2.fromOffset(2, y),
			Size = UDim2.fromOffset(width - 4, 22), ZIndex = 2, Parent = parent }, 1.5)
		y += 28
		local g = buildSide(parent, { side = side, width = width, y = y })
		y += g.height
	end
	if parent:IsA("GuiObject") then parent.Size = UDim2.new(parent.Size.X, UDim.new(0, y)) end
	return y
end

-- build(parent, { side = ... }): one side's grid, returns { frame, cards, height, refresh }.
-- build(parent) with no opts: both sides for the Shop's ABILITIES slot; returns the height (and sizes parent).
function AbilityCards.build(parent: Instance, opts: { [string]: any }?): any
	if opts == nil then
		return buildBoth(parent)
	end
	return buildSide(parent, opts)
end

return AbilityCards

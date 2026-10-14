-- Mogging Tiers (design/pages/11 and the V2 addendum): every tier, highest first, with how many of its characters the
-- player has collected, and a panel for the selected tier with a VIEW IN INDEX button (opens the Index filtered to
-- that tier). Counts come only from the character catalogue and the saved ownership (unique ids, nothing invented).
-- A character's tier is fixed: collecting characters never upgrades one, so the page's text says that plainly
-- (the kit's "Collect more items to unlock higher tiers!" read as if it did).
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Characters = require(Shared.Config.Characters)
local UI = script.Parent.Parent
local Theme = require(UI.Theme)
local Kit = require(UI.Kit)
local State = require(UI.State)
local ModalManager = require(UI.ModalManager)
local Motion = require(UI.Motion)

local C = Theme.Colors
local F = Theme.Fonts
local new = Kit.new
local hex = Color3.fromHex

local Tiers = {}

local W, H = 701, 320 -- every main window shares this size

-- Page 11's own colours per tier (name, second word of the name, progress fill), measured. Tiers the page doesn't
-- show filled fall back to their name colour. Unknown tiers use the catalogue's badge colour.
local LOOK = {
	TrueEve = { Name = hex("C9D4F8"), Name2 = hex("BD6BF5"), Fill = hex("C9A8F8") },
	Stacy = { Name = hex("F293C4"), Fill = hex("F293C4") },
	HTB = { Name = hex("F08397"), Fill = hex("F2B45A") },
	MTB = { Name = hex("E98CFD"), Fill = hex("FB93A0"), Big = hex("E070E8") },
	Sub5 = { Name = hex("F64C70"), Fill = hex("E2CDB0") },
	Sub3 = { Name = hex("7CCFFC"), Fill = hex("66C8FB") },
	Sub1 = { Name = hex("FBFBFD"), Fill = hex("BFC5D2") },
}
local COL = {
	Row = hex("1A2F4A"), RowRim = hex("2A4466"), Select = hex("F6DC52"), Count = hex("F8D74A"), Empty = hex("2F4D74"),
	Panel = hex("152A48"), PanelRim = hex("2B4A6E"), Label = hex("E6EAF4"), Blurb = hex("DCE2EE"),
}
local function look(tier: string)
	local l = LOOK[tier]
	if l then return l end
	local c = Characters.TierColors[tier] or C.Slate
	return { Name = c, Fill = c }
end
-- crown art cropped from page 11 (assets/art/tier-crown-*.png)
local function crownArt(tier: string): string return "TierCrown" .. tier end

-- The picture shown for a character in the panel: the kit's page-11 art for Aiko, else its card art.
local PANEL_ART = { Aiko = "CharAikoTiers" }

local ROW = { X = 13, Y = 55, W = 352, H = 33, Gap = 4 }
local SEGMENTS = 5
local PANEL = { X = 374, Y = 55, W = 313, H = 255 }
local ART_W = 170

local selected: string? = nil

-- Unique owned / catalogue count for one tier.
local function counts(tier: string): (number, number)
	local have, total = 0, 0
	for _, c in Characters.List do
		if c.Tier == tier then
			total += 1
			if State.data.Characters[c.Id] ~= nil then have += 1 end
		end
	end
	return have, total
end

-- The highest tier the player owns a character in (nil if none).
local function highestCollected(): string?
	for i = #Characters.Tiers, 1, -1 do
		local t = Characters.Tiers[i]
		if (counts(t)) > 0 then return t end
	end
	return nil
end

-- A right-pointing chevron drawn from two bars.
local function chevronRight(parent: Instance, x: number)
	local f = new("Frame", { Name = "Chevron", AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, x, 0.5, 0), Size = UDim2.fromOffset(8, 12), BackgroundTransparency = 1, Parent = parent })
	for i, rot in { 45, -45 } do
		new("Frame", { Name = "Bar", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, i == 1 and 0.3 or 0.7, 0), Size = UDim2.fromOffset(9, 3), Rotation = rot, BackgroundColor3 = C.Text, BorderSizePixel = 0, Parent = f }, { Kit.corner(1) })
	end
end

-- "3 / 8": the owned number can wear its own colour.
local function countLabel(parent: Instance, props)
	local row = new("Frame", { Name = props.Name or "Count", Position = props.Position, AnchorPoint = props.AnchorPoint or Vector2.zero, Size = props.Size, BackgroundTransparency = 1, Parent = parent },
		{ Kit.list(Enum.FillDirection.Horizontal, 0, props.Align or Enum.HorizontalAlignment.Center, Enum.VerticalAlignment.Center) })
	local have = Kit.text({ Name = "Have", Text = "0", FontFace = props.Font or F.Number, TextSize = props.TextSize, AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.new(0, 0, 1, 0), TextWrapped = false, LayoutOrder = 1, Parent = row })
	local rest = Kit.text({ Name = "Rest", Text = " / 0", FontFace = props.Font or F.Number, TextSize = props.TextSize, AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.new(0, 0, 1, 0), TextWrapped = false, LayoutOrder = 2, Parent = row })
	return function(n: number, total: number, color: Color3, suffix: string?)
		have.Text = tostring(n)
		have.TextColor3 = color
		rest.Text = " / " .. tostring(total) .. (suffix or "")
	end
end

function Tiers.build(parent: Instance)
	local window = Kit.window({ Name = "Tiers", Title = "MOGGING TIERS", Icon = "TierCrown", Width = W, Height = H, TitleSize = 24, TitleX = 63, TitleOffsetY = 1, TitleWidth = 208, Parent = parent, OnClose = function() ModalManager.close() end })
	local panel = window.Panel

	-- Tier rows (page 11 #3), highest tier first.
	local rows: { { Tier: string, Instance: TextButton, refresh: () -> () } } = {}
	local refreshPanel: () -> () = function() end
	local order = {}
	for i = #Characters.Tiers, 1, -1 do table.insert(order, Characters.Tiers[i]) end
	for i, tier in order do
		local l = look(tier)
		local btn = new("TextButton", { Name = tier, Text = "", AutoButtonColor = false, Selectable = true, Position = UDim2.fromOffset(ROW.X, ROW.Y + (i - 1) * (ROW.H + ROW.Gap)), Size = UDim2.fromOffset(ROW.W, ROW.H), BackgroundColor3 = COL.Row, BorderSizePixel = 0, Parent = panel }, { Kit.corner(4) })
		local rim = Kit.stroke(COL.RowRim, 1)
		rim.Name = "Rim"
		rim = Kit.attach(rim, btn)
		Motion.bindButton(btn, function() return nil end)
		Kit.art(crownArt(tier), { Name = "Crown", ScaleType = Enum.ScaleType.Fit, AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 7, 0.5, 0), Size = UDim2.fromOffset(25, 23), Parent = btn })
		-- the name; TRUE EVE wears two colours like the reference
		local nameRow = new("Frame", { Name = "Name", Position = UDim2.fromOffset(48, 0), Size = UDim2.new(0, 80, 1, 0), BackgroundTransparency = 1, Parent = btn },
			{ Kit.list(Enum.FillDirection.Horizontal, 5, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Center) })
		local words = string.split(Characters.TierNames[tier] or tier, " ")
		for w, word in words do
			local color = (w > 1 and l.Name2) or l.Name
			if #words == 2 and tier ~= "TrueEve" then -- "SUB 5" reads as one word on this page (SUB5)
				if w == 2 then break end
				word = words[1] .. words[2]
			end
			Kit.text({ Name = "Word" .. w, Text = word, FontFace = F.Tab, TextSize = 18, TextColor3 = color, AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.new(0, 0, 1, 0), TextWrapped = false, LayoutOrder = w, Parent = nameRow })
		end
		-- progress: five segments filled in proportion to owned / total in this tier
		local segs = {}
		for s = 1, SEGMENTS do
			segs[s] = new("Frame", { Name = "Segment" .. s, AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 129 + (s - 1) * 18, 0.5, 0), Size = UDim2.fromOffset(16, 14), BackgroundColor3 = COL.Empty, BorderSizePixel = 0, Parent = btn }, { Kit.corner(1) })
		end
		local setCount = countLabel(btn, { Position = UDim2.new(0, 238, 0, 0), Size = UDim2.new(0, 52, 1, 0), TextSize = 15 })
		chevronRight(btn, 326)
		local function refresh()
			local have, total = counts(tier)
			local filled = total > 0 and math.floor(have / total * SEGMENTS + 0.5) or 0
			for s, seg in segs do seg.BackgroundColor3 = s <= filled and l.Fill or COL.Empty end
			local sel = selected == tier
			setCount(have, total, sel and COL.Count or C.Text)
			rim.Color = sel and COL.Select or COL.RowRim
			rim.Thickness = sel and 2 or 1
		end
		btn.Activated:Connect(function()
			if selected == tier then return end
			selected = tier
			for _, r in rows do r.refresh() end
			refreshPanel()
		end)
		table.insert(rows, { Tier = tier, Instance = btn, refresh = refresh })
	end

	-- Selected tier panel (page 11 #4-#5).
	local box = new("Frame", { Name = "TierPanel", Position = UDim2.fromOffset(PANEL.X, PANEL.Y), Size = UDim2.fromOffset(PANEL.W, PANEL.H), BackgroundColor3 = COL.Panel, BorderSizePixel = 0, Parent = panel }, { Kit.corner(4), Kit.stroke(COL.PanelRim, 1) })
	local artHolder = new("Frame", { Name = "Art", Position = UDim2.fromOffset(1, 1), Size = UDim2.fromOffset(ART_W, PANEL.H - 2), BackgroundTransparency = 1, Parent = box })
	local TX = ART_W + 13
	local label = Kit.text({ Name = "Label", Text = "Highest Collected", FontFace = F.Label, TextSize = 12, TextColor3 = COL.Label, Position = UDim2.fromOffset(TX, 20), Size = UDim2.fromOffset(PANEL.W - TX - 6, 18), TextWrapped = false, Parent = box })
	local crown: ImageLabel? = nil
	local bigName = Kit.text({ Name = "TierName", Text = "", FontFace = F.Heading, TextSize = 27, Position = UDim2.fromOffset(TX + 40, 44), Size = UDim2.fromOffset(PANEL.W - TX - 44, 40), TextWrapped = false, Parent = box })
	local setBigCount = countLabel(box, { Name = "Collected", Position = UDim2.fromOffset(TX, 88), Size = UDim2.fromOffset(PANEL.W - TX - 4, 26), TextSize = 15, Font = F.Name, Align = Enum.HorizontalAlignment.Left })
	local blurb = Kit.text({ Name = "Blurb", Text = "", TextSize = 14, LineHeight = 0.95, TextColor3 = COL.Blurb, TextYAlignment = Enum.TextYAlignment.Top, Position = UDim2.fromOffset(TX, 122), Size = UDim2.fromOffset(PANEL.W - TX - 8, 64), Parent = box })
	local view = Kit.button({ Name = "ViewInIndex", Text = "VIEW IN INDEX", TextSize = 21, Corner = 5, Position = UDim2.fromOffset(PANEL.X + PANEL.W - 3 - 145, PANEL.Y + PANEL.H - 5 - 46), Size = UDim2.fromOffset(145, 46), ZIndex = 2, Parent = panel })
	view.onClick(function()
		if selected then ModalManager.open("Index", { Tier = selected }) end
	end)

	local shownArt = ""
	refreshPanel = function()
		local tier = selected
		if not tier then return end
		local l = look(tier)
		local have, total = counts(tier)
		local best = highestCollected()
		label.Text = if best == tier then "Highest Collected" else "Selected Tier"
		if crown then crown:Destroy() end
		crown = Kit.art(crownArt(tier), { Name = "Crown", ScaleType = Enum.ScaleType.Fit, Position = UDim2.fromOffset(TX - 2, 47), Size = UDim2.fromOffset(37, 34), Parent = box })
		bigName.Text = Characters.TierNames[tier] or tier
		-- long names (STACY, TRUE EVE) shrink to stay inside the panel (about 0.75 em per heavy capital)
		bigName.TextSize = math.min(27, math.floor((PANEL.W - TX - 44) / (#bigName.Text * 0.75)))
		bigName.TextColor3 = l.Big or l.Name
		setBigCount(have, total, l.Big or l.Name, " collected")
		blurb.Text = if total == 0 then "No characters in this tier yet."
			elseif have == total then "You have every character in this tier!"
			else "Each character keeps its tier. Collect more to fill the bar!"
		-- picture: an owned character from this tier (newest first), else the locked silhouette
		local pick, newest = nil, -math.huge
		for _, c in Characters.List do
			local t = State.data.Characters[c.Id]
			if c.Tier == tier and t ~= nil then
				local n = type(t) == "number" and t or 0
				if n > newest or (n == newest and pick and c.Id < pick.Id) then pick, newest = c, n end
			end
		end
		local artName = if pick then (PANEL_ART[pick.Id] or pick.Art or "CharLocked") else "CharLocked"
		if artName ~= shownArt then
			shownArt = artName
			for _, ch in artHolder:GetChildren() do ch:Destroy() end
			-- left corners rounded, right edge square (a rounded copy plus a square copy clipped right of the corners)
			local r = 3
			local full = PANEL_ART[pick and pick.Id or ""] ~= nil
			local function img(props)
				props.ScaleType = full and Enum.ScaleType.Crop or Enum.ScaleType.Fit
				return Kit.art(artName, props)
			end
			Kit.attach(Kit.corner(r), img({ Name = "Picture", Size = UDim2.fromScale(1, 1), Parent = artHolder }))
			local right = new("Frame", { Name = "Right", Position = UDim2.fromOffset(r, 0), Size = UDim2.new(1, -r, 1, 0), BackgroundTransparency = 1, ClipsDescendants = true, Parent = artHolder })
			img({ Name = "Picture", Position = UDim2.fromOffset(-r, 0), Size = UDim2.fromOffset(ART_W, PANEL.H - 2), Parent = right })
		end
	end

	local function refreshAll()
		if not selected then selected = highestCollected() or order[1] end
		for _, r in rows do r.refresh() end
		refreshPanel()
	end
	State.changed(refreshAll)

	ModalManager.register("Tiers", {
		window = window,
		-- opens on the highest tier collected (or the given tier)
		onOpen = function(tier)
			if type(tier) == "string" and table.find(Characters.Tiers, tier) then selected = tier else selected = highestCollected() or selected end
			refreshAll()
		end,
		firstSelect = function() return rows[1] and rows[1].Instance end,
		items = function()
			local list = {}
			for _, r in rows do table.insert(list, r.Instance) end
			return list
		end,
	})
	refreshAll()
	return window
end

return Tiers

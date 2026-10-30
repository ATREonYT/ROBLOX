-- Pictures for crates (Shop > CRATES and UI/Screens/CrateOpen): the crate itself and one card per item.
-- The crate is drawn from plain UI parts in the kit's colours (a purple box with the header's glossy lid, dark straps,
-- light corner caps and the owner's Aura star on a white lock plate): a STAND-IN until the owner sends his own crate
-- art (then swap crate() for Kit.art). Its lid is its own part, so the opening can pop it off.
-- Item cards use the game's real pictures: the coin shop's own art (Config/CoinShop Art: trails, name colours, the
-- owner's knives), your avatar dancing the dance (UI/DancePose; its still DanceStill<Id> until that's ready) and the
-- coin pack art for coins, with a rim and a foot bar in the rarity's colour (the Spin wheel's rarity colours: see
-- CrateArt.color).
-- CrateArt.hisPicture: the owner's own crate pictures (his crate shop mockup's cards, Kit.art CrateCard*) for Shop >
-- CRATES and the Halloween shop, with his real 3D crate standing in whenever a picture can't be drawn (owner, Oct 20
-- 14:07: his CRATES tab showed three cardboard boxes, ImageLoader's glyph, "please add the crates into the normal
-- crate section"). Never a glyph there.
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local CoinShop = require(Shared.Config.CoinShop)
local Dances = require(Shared.Config.Dances)
local RoundConfig = require(Shared.Config.Round)
local SpinWheel = require(Shared.Config.SpinWheel)
local Format = require(Shared.Format)
local Theme = require(script.Parent.Theme)
local Kit = require(script.Parent.Kit)
local Crate3D = require(script.Parent.Crate3D)

local C, F = Theme.Colors, Theme.Fonts
local new = Kit.new
local hex = Color3.fromHex

local CrateArt = {}

-- Rarity colours: the Spin wheel's (Config/SpinWheel.RarityColors), so both reward screens agree and Legendary is
-- pink, not the girls' orange-gold (owner: "no gold anywhere", gold "looks so AI"). Mythic and Secret, which the
-- wheel doesn't have, come from Config/Round (Secret as violet: near-black doesn't read on the dark window).
local rarityColor: { [string]: Color3 } = {}
for _, r in RoundConfig.Rarities do rarityColor[r.Name] = r.Color end
rarityColor.Secret = Color3.fromRGB(150, 110, 255)
for name, c in SpinWheel.RarityColors do rarityColor[name] = c end

function CrateArt.color(rarity: string): Color3
	return rarityColor[rarity] or Color3.new(1, 1, 1)
end

local function round(f: GuiObject, r: number)
	Kit.attach(Kit.corner(r), f)
end

-- The crate, drawn in a square of `s` px centred on `pos`. Returns its holder, body and lid (the lid sits on top).
function CrateArt.crate(parent: Instance, s: number, pos: UDim2, name: string?)
	local holder = new("Frame", { Name = name or "Crate", AnchorPoint = Vector2.new(0.5, 0.5), Position = pos, Size = UDim2.fromOffset(s, s), BackgroundTransparency = 1, Parent = parent })
	new("UIScale", { Name = "Pop", Parent = holder })
	local function px(v: number) return math.round(v * s) end
	local shadow = new("Frame", { Name = "Shadow", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(px(0.5), px(0.94)), Size = UDim2.fromOffset(px(0.86), px(0.1)), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.6, BorderSizePixel = 0, ZIndex = 1, Parent = holder })
	round(shadow, px(0.05))
	-- the box
	local body = new("Frame", { Name = "Body", Position = UDim2.fromOffset(px(0.1), px(0.4)), Size = UDim2.fromOffset(px(0.8), px(0.52)), BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, ZIndex = 2, Parent = holder }, { Kit.corner(px(0.06)), Kit.stroke(C.Ink, math.max(2, px(0.016))) })
	new("UIGradient", { Name = "Shade", Rotation = 90, Color = ColorSequence.new(hex("8C6BFF"), hex("4A2BC2")), Parent = body })
	Kit.studPattern(body, 0.28)
	for i, x in { 0.2, 0.7 } do -- two dark straps down the front
		new("Frame", { Name = "Strap" .. i, Position = UDim2.fromOffset(px(x * 0.8), 0), Size = UDim2.fromOffset(px(0.08), px(0.52)), BackgroundColor3 = hex("231A66"), BackgroundTransparency = 0.15, BorderSizePixel = 0, ZIndex = 3, Parent = body })
	end
	for i, c in { { 0, 0 }, { 1, 0 }, { 0, 1 }, { 1, 1 } } do -- light corner caps
		local cap = new("Frame", { Name = "Cap" .. i, AnchorPoint = Vector2.new(c[1], c[2]), Position = UDim2.fromScale(c[1], c[2]), Size = UDim2.fromOffset(px(0.12), px(0.12)), BackgroundColor3 = hex("D9DEF0"), BorderSizePixel = 0, ZIndex = 4, Parent = body }, { Kit.stroke(C.Ink, math.max(1, px(0.01))) })
		round(cap, px(0.03))
	end
	local plate = new("Frame", { Name = "Plate", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(px(0.4), px(0.24)), Size = UDim2.fromOffset(px(0.26), px(0.26)), BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, ZIndex = 5, Parent = body }, { Kit.stroke(C.Ink, math.max(2, px(0.014))) })
	round(plate, px(0.05))
	Kit.icon("AuraStar", { Name = "Star", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(px(0.21), px(0.21)), ZIndex = 6, Parent = plate })
	-- the lid: the windows' glossy header purple, a little wider than the box
	local lid = new("Frame", { Name = "Lid", Position = UDim2.fromOffset(px(0.05), px(0.26)), Size = UDim2.fromOffset(px(0.9), px(0.17)), BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, ZIndex = 7, Parent = holder }, { Kit.corner(px(0.05)), Kit.stroke(C.Ink, math.max(2, px(0.016))) })
	local g = {}
	for _, k in C.HeaderGradient do table.insert(g, ColorSequenceKeypoint.new(k[1], k[2])) end
	new("UIGradient", { Name = "Gloss", Rotation = 90, Color = ColorSequence.new(g), Parent = lid })
	Kit.studPattern(lid, 0.4)
	new("Frame", { Name = "Shine", Position = UDim2.fromOffset(px(0.04), px(0.025)), Size = UDim2.fromOffset(px(0.82), math.max(2, px(0.02))), BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 0.35, BorderSizePixel = 0, ZIndex = 8, Parent = lid })
	return holder, body, lid
end

-- Each crate's box colour (Config/Crates `Colors` = { top, bottom } hex; the Starter Crate keeps the kit purple), so the
-- crates tell apart at a glance in the Shop and on the opening screen.
function CrateArt.paint(holder: Instance, crate: any)
	local body = holder:FindFirstChild("Body")
	local shade = body and body:FindFirstChild("Shade")
	if not (shade and shade:IsA("UIGradient")) then return end
	local c = crate and crate.Colors
	shade.Color = ColorSequence.new(hex(c and c[1] or "8C6BFF"), hex(c and c[2] or "4A2BC2"))
end

-- What an item looks like: { art, fit (picture fits instead of filling), tint (backdrop colour) }.
local function look(item: any): (string?, boolean)
	if item.Kind == "Coins" then
		return if (item.Amount or 0) >= 400 then "CoinPack2000" else "CoinPack500", false
	elseif item.Kind == "Dance" then
		local d = Dances.get(item.Id)
		return if d then "DanceStill" .. d.Id else nil, true
	else
		local c = CoinShop.get(item.Id)
		return if c then c.Art else nil, false
	end
end

-- The item's picture filling a w x h box (rounded r): its rarity's dark backdrop, then the picture.
function CrateArt.picture(parent: Instance, item: any, w: number, h: number, r: number, pos: UDim2?, z: number?)
	local col = CrateArt.color(item.Rarity)
	local box = new("Frame", { Name = "Picture", Position = pos or UDim2.new(), Size = UDim2.fromOffset(w, h), BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, ZIndex = z or 2, Parent = parent })
	round(box, r)
	new("UIGradient", { Name = "Backdrop", Rotation = 90, Color = ColorSequence.new(col:Lerp(hex("1A1F4A"), 0.55), hex("10143A")), Parent = box })
	local art, fit = look(item)
	if art then
		local img = Kit.art(art, { Name = "Art", Size = UDim2.fromScale(1, 1), ScaleType = if fit then Enum.ScaleType.Fit else Enum.ScaleType.Crop, ZIndex = (z or 2) + 1, Parent = box })
		round(img, r) -- (rounded on the picture itself: clipping ignores corners)
		-- a dance: your own avatar dancing it over the still once it's ready (owner, Oct 23 03:37: "make the characters
		-- in the ui showcasing the dances, dance, everywhere where its shown"; UI/DancePose, in view only). Not in the
		-- crate list's tiny rows, where a body would be a few pixels tall.
		if item.Kind == "Dance" and h >= 48 then
			pcall(function()
				require(script.Parent.DancePose).picture(box, item.Id, { Name = "Dancer", Size = UDim2.fromScale(1, 1), ZIndex = (z or 2) + 2 }, false, nil, function()
					img.ImageTransparency = 1
				end)
			end)
		end
	end
	return box
end

-- One reel card, w x h: dark navy with the rarity's rim, its glow rising from the foot, the picture, the name and
-- the rarity in its colour, and a solid foot bar.
function CrateArt.card(parent: Instance, item: any, w: number, h: number, name: string?)
	local col = CrateArt.color(item.Rarity)
	local card = new("Frame", { Name = name or "Card", Size = UDim2.fromOffset(w, h), BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, ZIndex = 2, Parent = parent }, { Kit.corner(8), Kit.stroke(col, 3) })
	new("UIGradient", { Name = "Fill", Rotation = 90, Color = ColorSequence.new(hex("1E2B5E"), hex("10183A")), Parent = card })
	local glow = new("Frame", { Name = "Glow", Position = UDim2.fromScale(0, 0.35), Size = UDim2.fromScale(1, 0.65), BackgroundColor3 = col, BackgroundTransparency = 0.55, BorderSizePixel = 0, ZIndex = 2, Parent = card })
	round(glow, 8)
	new("UIGradient", { Rotation = 90, Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(1, 0.15) }), Parent = glow })
	local pw = w - 12
	CrateArt.picture(card, item, pw, math.round(pw * 0.72), 6, UDim2.fromOffset(6, 6), 3)
	local nameY = 6 + math.round(pw * 0.72) + 4
	local label = Kit.name({ Name = "Name", Text = item.Name, FontFace = F.Heading, TextSize = 16, TextXAlignment = Enum.TextXAlignment.Center, Position = UDim2.fromOffset(4, nameY), Size = UDim2.fromOffset(w - 8, 20), ZIndex = 5, Parent = card })
	Kit.attach(new("UIStroke", { Name = "Outline", Color = C.TitleStroke, Thickness = 1.5, LineJoinMode = Enum.LineJoinMode.Round }), label)
	Kit.fitLine(label, w - 10, 16, 11, true)
	local rare = Kit.text({ Name = "Rarity", Text = string.upper(item.Rarity), FontFace = F.Heading, TextSize = 11, TextColor3 = col, TextXAlignment = Enum.TextXAlignment.Center, TextWrapped = false, Position = UDim2.fromOffset(4, nameY + 21), Size = UDim2.fromOffset(w - 8, 14), ZIndex = 5, Parent = card })
	Kit.attach(new("UIStroke", { Name = "Outline", Color = C.TitleStroke, Thickness = 1.2 }), rare)
	local foot = new("Frame", { Name = "Foot", AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 3, 1, -3), Size = UDim2.new(1, -6, 0, 5), BackgroundColor3 = col, BorderSizePixel = 0, ZIndex = 4, Parent = card })
	round(foot, 2)
	return card
end

-- His crate picture (Kit.art `art`) in a box, and what stands in when it can't be drawn (ImageLoader puts its
-- NoPicture glyph on a picture it couldn't draw: here that glyph is hidden and his real 3D crate takes the picture's
-- place, in the same box: UI/Crate3D "Card"; without his model yet, the drawn crate in his crate's colours).
-- opts:
--   Name, Position, Size (px), ZIndex   the box
--   Model   the Config/Crates crate whose 3D model stands in (Witch's Brew shows the Beast's, Sweets & Treats the Dojo's)
--   Crop    { x, y, w, h, W, H }: show only that part of his W x H picture (the Halloween cards: his crate without
--           his BUY), else the whole picture, stretched to the box
--   Card    { W, H, Buy = { x, y, w, h } }: the stand-in also draws his card's panel and his BUY bar where he drew it
--           (Shop > CRATES, whose invisible BUY button lies over that spot)
-- The stand-in (and everything in it) carries the NoPicture attribute like ImageLoader's glyphs: made at run time,
-- never saved into StarterGui, and the offline preview draws his picture instead. Returns the picture (ImageLabel).
function CrateArt.hisPicture(parent: Instance, art: string, opts: { [string]: any }): ImageLabel
	local z = opts.ZIndex or 2
	local size: UDim2 = opts.Size
	local w, h = size.X.Offset, size.Y.Offset
	local box: GuiObject
	local pic: ImageLabel
	if opts.Crop then
		local c = opts.Crop
		box = new("Frame", { Name = opts.Name or "CratePicture", Position = opts.Position, Size = size, BackgroundTransparency = 1, ClipsDescendants = true, ZIndex = z, Parent = parent })
		local sx, sy = w / c[3], h / c[4]
		pic = Kit.art(art, { Name = "Picture", Position = UDim2.fromOffset(-math.round(c[1] * sx), -math.round(c[2] * sy)), Size = UDim2.fromOffset(math.round(c[5] * sx), math.round(c[6] * sy)), ScaleType = Enum.ScaleType.Stretch, ZIndex = z, Parent = box })
	else
		pic = Kit.art(art, { Name = opts.Name or "Picture", Position = opts.Position, Size = size, ScaleType = Enum.ScaleType.Stretch, ZIndex = z, Parent = parent })
		box = pic
	end
	local standIn: Frame? = nil
	local function build(): Frame
		local f = new("Frame", { Name = "StandIn", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = z, Parent = box })
		local crateArea: GuiObject = f
		if opts.Card then
			-- his card: a navy panel with a light rim (as on his mockup), his BUY bar where he drew it
			local card = opts.Card
			local panel = new("Frame", { Name = "Panel", Position = UDim2.fromOffset(2, 2), Size = UDim2.new(1, -4, 1, -4), BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, ZIndex = z, Parent = f }, { Kit.corner(8), Kit.stroke(hex("3D47A0"), 1.5) })
			new("UIGradient", { Rotation = 90, Color = ColorSequence.new(hex("2C3680"), hex("1F2560")), Parent = panel })
			local b = card.Buy
			local bar = new("Frame", { Name = "BuyBar", Position = UDim2.fromScale(b[1] / card.W, b[2] / card.H), Size = UDim2.fromScale(b[3] / card.W, b[4] / card.H), BackgroundColor3 = hex("6A5CF6"), BorderSizePixel = 0, ZIndex = z + 1, Parent = f }, { Kit.corner(5), Kit.stroke(hex("A79FFF"), 1) })
			local label = Kit.text({ Name = "Label", Text = Format.RobuxMark .. " BUY", FontFace = F.Heading, TextSize = math.max(10, math.floor(h * b[4] / card.H * 0.55)), TextXAlignment = Enum.TextXAlignment.Center, TextWrapped = false, Size = UDim2.fromScale(1, 1), ZIndex = z + 2, Parent = bar })
			new("UIStroke", { Name = "Outline", Color = C.Ink, Thickness = 1.5, LineJoinMode = Enum.LineJoinMode.Round, Parent = label })
			crateArea = new("Frame", { Name = "CrateArea", Position = UDim2.fromScale(0.04, 0.03), Size = UDim2.fromScale(0.92, b[2] / card.H - 0.05), BackgroundTransparency = 1, ZIndex = z + 1, Parent = f })
		end
		local ok, view = pcall(function() return if opts.Model and Crate3D.available(opts.Model) then Crate3D.new(crateArea, opts.Model, "Card", { ZIndex = z + 1 }) else nil end)
		if not ok then warn("[HuzzUI] CrateArt: his 3D crate couldn't stand in for the picture:", view) end
		if not (ok and view) then -- (his model isn't here yet: the drawn crate in his crate's colours)
			local s = math.max(16, math.floor(math.min(w, h) * 0.8))
			CrateArt.paint(CrateArt.crate(crateArea, s, UDim2.fromScale(0.5, 0.5), "DrawnCrate"), opts.Model)
		end
		f:SetAttribute("NoPicture", true)
		for _, d in f:GetDescendants() do d:SetAttribute("NoPicture", true) end
		return f
	end
	local function update()
		local glyph = pic:FindFirstChild("NoPicture")
		if glyph and glyph:IsA("GuiObject") then glyph.Visible = false end -- (never the cardboard box glyph here)
		if glyph and not standIn then standIn = build() end
		if standIn then standIn.Visible = glyph ~= nil end
	end
	pcall(function() pic.ChildAdded:Connect(function() task.defer(update) end) end) -- (the picture can fail later too)
	pcall(function() pic.ChildRemoved:Connect(function() task.defer(update) end) end) -- (and show later: then his picture)
	update()
	return pic
end

return CrateArt

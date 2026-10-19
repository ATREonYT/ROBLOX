-- Pictures for crates (Shop > CRATES and UI/Screens/CrateOpen): the crate itself and one card per item.
-- The crate is drawn from plain UI parts in the kit's colours (a purple box with the header's glossy lid, dark straps,
-- light corner caps and the owner's Aura star on a white lock plate): a STAND-IN until the owner sends his own crate
-- art (then swap crate() for Kit.art). Its lid is its own part, so the opening can pop it off.
-- Item cards use the game's real pictures: the coin shop's own art (Config/CoinShop Art: trails, name colours, the
-- owner's knives), the dance's still (DanceStill<Id>) and the coin pack art for coins, with a rim and a foot bar in the
-- rarity's colour (the Spin wheel's rarity colours: see CrateArt.color).
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local CoinShop = require(Shared.Config.CoinShop)
local Dances = require(Shared.Config.Dances)
local RoundConfig = require(Shared.Config.Round)
local SpinWheel = require(Shared.Config.SpinWheel)
local Theme = require(script.Parent.Theme)
local Kit = require(script.Parent.Kit)

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

return CrateArt

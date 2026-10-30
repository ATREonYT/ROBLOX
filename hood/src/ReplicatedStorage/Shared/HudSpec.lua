-- The HUD's layout, measured on the soldier game (brief 30, bible §2.7) and written down once, so HUD.client, the feature
-- scripts (Wheel.client, Extras.client), the tutorial and the tests read the same numbers.
-- Measured on ref_W31.0_stage1_wave_idle_at_gate.jpg and ref_W03.0_spawn_cross_west.jpg scaled to 720 px tall (the game
-- view 1148 x 720, the same height as UIKit's 1280 x 720 design canvas, so one reference px = one design px), and
-- ref_ref29_hud_buttons_skins.png for the colours. Design px; y is measured inside the HUD's Root, which starts under
-- Roblox's top bar (58 px at 720), so a reference y of Y px is Y - 58 here; a negative y reaches up into the top bar's band
-- (the reference's spin wheel, boss timer and Playtime gift live there, beside Roblox's own buttons).
--   Left    anchored to the screen's left edge: the left column and the bottom-left block
--   Right   anchored to the right edge (x = px in from it): the offer cards, Starter Pack, Playtime, Missions
--   Bottom  anchored to the bottom edge (y = px of the row's centre or top ABOVE the bottom), centred on the screen
local Kit = require(script.Parent.UIKit)
local hex = Kit.hex

local Spec = {}
Spec.Inset = 58 -- Roblox's top bar at 720
Spec.RefW = 1148 -- the reference's game view at 720 tall

-- The HUD's scale. The references are whole screens 720 px tall, Roblox's top bar included, so a reference px is a screen
-- px when the WHOLE screen is 720 tall; Kit.scaleFor fits the 1280 x 720 canvas into the area UNDER the top bar (662 px
-- there), which would draw everything measured here 8% small. The HUD's own screens (HoodHUD, HoodGoals, HoodNotices)
-- use Spec.screen / Spec.scaleFor instead. Phones keep Kit's scale (their layout is tuned on it).
function Spec.scaleFor(abs)
	if math.min(abs.X, abs.Y) <= 500 then return Kit.scaleFor(abs) end
	local ok, inset = pcall(function() return game:GetService('GuiService'):GetGuiInset() end)
	local top = ok and typeof(inset) == 'Vector2' and inset.Y or Spec.Inset
	return math.clamp(math.min(abs.X / Spec.RefW, (abs.Y + top) / Kit.Reference.Y), 0.5, 1.6)
end
-- Kit.screen's ScreenGui and Root, scaled by Spec.scaleFor: returns gui, root, fit(abs)
function Spec.screen(name, displayOrder)
	local gui = Kit.new('ScreenGui', { Name = name, ResetOnSpawn = false, IgnoreGuiInset = false, ZIndexBehavior = Enum.ZIndexBehavior.Sibling, ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets, DisplayOrder = displayOrder or 0 })
	local root = Kit.new('Frame', { Name = 'Root', BackgroundTransparency = 1, BorderSizePixel = 0, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(1, 1), Parent = gui })
	root:SetAttribute('ScaleRule', 'Hud') -- (for the preview renderer, which works the screens' scale out itself)
	local scale = Kit.new('UIScale', { Parent = root })
	local function fit(abs)
		local k = Spec.scaleFor(abs)
		scale.Scale = k
		root.Size = UDim2.fromScale(1 / k, 1 / k) -- after scaling, Root exactly fills the screen
	end
	gui:GetPropertyChangedSignal('AbsoluteSize'):Connect(function() fit(gui.AbsoluteSize) end)
	return gui, root, fit
end

-- the left column (ref: Shop 20..173 x 221..281; Pets / Rebirth 71 px squares at x 20 / 105, y 295; Items / Skins y 378)
-- (Oct 27, round 8, CRITIC_OCT27 gap 10: our small squares were 5.3 % of the screen's width, the ref's 7.8 %) the grid
-- is 1.35x: squares 96 (7.5 % of 1280 and of 1920), the Shop bar over both, the words a size up
Spec.Column = {
	X = 20, Y = 163, -- the column's top-left in Root (the Shop's top is 221 - 58)
	Square = 96, GapX = 16, GapY = 14,
	ShopW = 208, ShopH = 66, ShopGap = 14, -- (the Shop bar spans both squares)
	Badge = { X = 196, Y = 4, W = 30, H = 32 }, -- the Shop's rainbow "!": its centre in the bar
	Pill = { Right = 20, Y = 3, W = 50, H = 24, TextSize = 18 }, -- the Rebirth "57%" pill: centre 20 in from the right edge, 3 down
	Count = { Size = 26, Right = 2, Y = 3 }, -- the cyan count circle on a square's top-right corner (ref Items "1")
	ShopText = 28, SquareText = 24,
}
-- the bottom-left block (ref: Rank row centre 568, Rebirths 609, Wins 653, Friend Boost 694; the screen's bottom is 720)
Spec.Counters = {
	Rank = { Above = 152, Icon = 36, IconX = 12, TextX = 55, TextSize = 28 },
	Rebirths = { Above = 111, Icon = 38, IconX = 11, TextX = 56, TextSize = 26 },
	Cash = { Above = 67, Icon = 40, IconX = 10, TextX = 56, TextSize = 26 },
	Friend = { Above = 26, TextX = 10, TextSize = 22, Plus = 37 }, -- (the reference's words are narrower than ours; round 8: 20 -> 22, the small-text floor)
}
-- the bottom centre (ref: the bar 375..775 x 600..638; Power 204 centred at 570; Multiplier 385.. at 587; the packs
-- 648..682; Autowin 820..890 x 600..640)
-- (round 8, CRITIC_OCT27 gap 10: the level bar 31 % of the width against the ref's 35 %, the packs 9.2 % against 10.9 %)
-- the bottom block 1.12x, and no word under 17 px at 720
Spec.Bottom = {
	BarW = 448, BarH = 42, BarAbove = 124, -- the bar's top is 124 px over the bottom
	TrackColor = hex('2C2C34'), TrackTransparency = 0.4, BarStuds = 0.14, -- (the unfilled part: a see-through dark grey, faint studs)
	PowerAbove = 156, PowerIcon = 32, PowerText = 28,
	MultAbove = 138, MultX = 10, MultText = 20,
	PackW = 134, PackH = 38, PackGap = 23, PackAbove = 74, PackText = 26, PackPrice = 19,
	AutoW = 88, AutoH = 46, AutoGap = 40, AutoText = 17,
}
-- (round 8) no HUD word under this many screen px on a computer (phones: Kit.PhoneMinText dp, raised to 12)
Spec.MinText = 17
Spec.PhoneMinText = 12
-- the right column (ref: the x2 cards 977..1137 = 160 x 52, 11 in from the right edge, tops at 237 / 325 / 413)
Spec.Offers = { W = 176, H = 52, Right = 11, Top = 179, Step = 88, TitleSize = 30, PriceSize = 20 }
-- (Oct 27, round 8, CRITIC_OCT27 gap 8: the title hid the card's own picture) the picture in its own box at the card's
-- right end, poking over its top edge like the ref's (Kit.inBox: x, y, w, h in the card's px), the title left of it
Spec.OfferIcon = { X = 176 - 70, Y = -18, W = 72, H = 72, Margin = 0.04, TitleW = 176 - 76 }
-- where the cards' pictures sit (a UIKit Kit.Place rule; fractions of the card's height): the reference's trophy is about
-- 1.4 h wide and 1.15 h tall, centred, its top 0.2 h over the card's top edge, the title over it. (Oct 27, round 7,
-- OUR_UI_AUDIT B: it stood 0.28 h over, 18-24 px into the gap above; now exactly the reference's 0.2 h. Held fully inside
-- the card, the picture hid behind the title.)
Spec.OfferArt = { W = 1.5, H = 1.3, X = 0.5, XH = 0, Y = 0.42, TopAt = -0.2 }
-- the Shop bar's basket (ref: 80 x 60 over a 155 x 60 bar, centred, its handle 0.2 h over the top; its foot hides behind
-- "Shop"; drawn in a frame from 0.5 h over the top down to the bar's bottom edge)
Spec.ShopArt = { W = 1.42, H = 1.3, X = 0.5, XH = 0, Y = 0.3, TopAt = -0.24, ClipTop = -0.5 }
-- the top extras (ref: the wheel centred at 258 x 70, 68 across; Playtime Rewards centred 241 in from the right; Starter
-- Pack 94 in; Missions under Playtime)
Spec.Spin = { X = 258, Y = 12, Size = 68, Badge = 18, Caption = 22 }
Spec.Playtime = { Right = 241, Y = -16, Icon = 68, Caption = 20 }
Spec.Starter = { Right = 94, Y = 0, Icon = 88, Caption = 20 } -- (Oct 27: up beside Playtime, Y 82 -> 0: at 82 it sat on the x2 Cash card)
Spec.Missions = { Right = 243, Y = 107, Icon = 60, Caption = 22 }
-- the top centre: the boss timer line (ref 10..48, "Next GUNSHIP boss fight in: 2:52" + SKIP) and the fight chip
-- (CLEAR! / 5 LEFT, about 103 x 29 centred at 36) share the band; FIGHTS fills both slots
Spec.TopCentre = { BossW = 470, BossY = -48, BossH = 38, ChipW = 140, ChipH = 36, ChipY = -40 }
-- the goal line (ref: NEXT GOAL gold centred at 91, the goal in white 50 px under it)
Spec.Goal = { HeadY = 33, LineY = 58, HeadSize = 24, LineSize = 24 }

-- Colours sampled on the references (top -> bottom of each fill; `rim` the light band inside the black outline).
-- Two-tone cards (the x2 cards, the level bar) keep the reference's gloss: a flat bright top half, a light seam, then the
-- darker ramp.
local function seq(stops) local t = {} for i, s in stops do t[i] = { s[1], hex(s[2]) } end return t end
Spec.Tone = {
	shop = { top = hex('FDF553'), base = hex('F2AB3D'), lip = hex('D08A1E'), stroke = hex('5A2E00'), rim = hex('FFFFB0') },
	pets = { top = hex('EA36F7'), base = hex('AE56F5'), lip = hex('8030C8'), stroke = hex('2A0B4E'), rim = hex('F8B0FF') },
	rebirth = { top = hex('87F6FB'), base = hex('5CBCF8'), lip = hex('2E90C8'), stroke = hex('062C48'), rim = hex('DCFFFF') },
	items = { top = hex('FDF553'), base = hex('F2AB3D'), lip = hex('D08A1E'), stroke = hex('5A2E00'), rim = hex('FFFFB0') },
	skins = { top = hex('EC6C5A'), base = hex('C44A44'), lip = hex('98302C'), stroke = hex('4A0B16'), rim = hex('FFB4A8') },
	offerGold = { top = hex('FCFF3A'), base = hex('E95E09'), lip = hex('C8640A'), stroke = hex('5A2E00'), rim = hex('FFFFB8'), rot = 90,
		seq = seq({ { 0, 'FCFF4A' }, { 0.47, 'FAFF10' }, { 0.5, 'FFFF7A' }, { 0.53, 'FBDE18' }, { 1, 'EC6209' } }) },
	offerCyan = { top = hex('87FFFF'), base = hex('3CB4F0'), lip = hex('2A90C8'), stroke = hex('062C48'), rim = hex('E0FFFF'), rot = 90,
		seq = seq({ { 0, '8AFFFF' }, { 0.47, '56EFFF' }, { 0.5, 'A8FAFF' }, { 0.53, '51D5FB' }, { 1, '3AB2F2' } }) },
	-- (the lead, r8: the reference's fill is a bright #58F8F8 studded cyan, barely darker at its foot)
	level = { top = hex('9CFFFC'), base = hex('46E4F4'), lip = hex('2AB0D0'), stroke = hex('062C48'), rim = hex('DCFFFF'), rot = 90,
		seq = seq({ { 0, 'A4FFFC' }, { 0.42, '6EFFFA' }, { 0.5, 'C8FFFD' }, { 0.56, '58F8F8' }, { 1, '46E2F4' } }) },
	levelReady = { top = hex('E6FF60'), base = hex('36D402'), lip = hex('20A000'), stroke = hex('0E3A00'), rim = hex('E8FFB0'), rot = 90,
		seq = seq({ { 0, 'EEFF6A' }, { 0.45, 'C8FF3A' }, { 0.5, 'F2FFB0' }, { 0.55, '7AE82A' }, { 1, '36C402' } }) },
	pack1 = { top = hex('FFF060'), base = hex('F5A812'), lip = hex('C88A10'), stroke = hex('5A4600'), rim = hex('FFF8B8'), rot = 90,
		seq = seq({ { 0, 'FFF26A' }, { 0.47, 'FAE146' }, { 0.5, 'FFF6A8' }, { 0.53, 'F5C712' }, { 1, 'F29A10' } }) },
	pack2 = { top = hex('F65CF6'), base = hex('9A1CE0'), lip = hex('7A10B0'), stroke = hex('2A0B4E'), rim = hex('FFB8FF'), rot = 90,
		seq = seq({ { 0, 'F870F8' }, { 0.47, 'EC2CF3' }, { 0.5, 'FFA8FF' }, { 0.53, 'C024EC' }, { 1, '9418DC' } }) },
	pack3 = Kit.Tone.rainbow,
	auto = { top = hex('4A4F5C'), base = hex('2E3440'), lip = hex('1E222C'), stroke = hex('0E1020'), rim = hex('8A90A0') },
	friend = { top = hex('C8F83A'), base = hex('7ACC12'), lip = hex('4E9A06'), stroke = hex('2A3A06'), rim = hex('E8FFA0') },
	pill = { top = hex('D8FF4A'), base = hex('7ED612'), lip = hex('4E9A06'), stroke = hex('0E3A00'), rim = hex('F0FFB0') },
}
Spec.Text = {
	gold = { hex('FFF27A'), hex('FFA81A') }, -- the reference's gold numbers ("Multiplier: x1", the Wins count, GOAL DONE!)
	rebirths = { hex('FFFFFF'), hex('FF6A6A') }, -- the Rebirths count (white -> red, like the rebirth ball)
	lime = { hex('E8FF4A'), hex('5EE83A') }, -- "ONLY 79", the pack prices
	friend = { hex('FFFFFF'), hex('FFC4E4') }, -- "Friend Boost:" (white with a pink foot)
}

return Spec

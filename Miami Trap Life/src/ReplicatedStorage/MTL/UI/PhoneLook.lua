--!strict
-- The phone's look, matched to the HUD palette (Theme.HUD, Nov 2 evening): plain, normal game-UI colours.
-- Dark slate panels + white text; green ONLY for money / buy buttons, gold ONLY for level, soft blue for
-- selected / hover. Rounded 8-14 px corners, 1.5 px soft white borders, Gotham Heavy labels + Medium body.
--
-- Same shape as Theme (Colors / Fonts / Corner / CornerSmall / Phone ...), so every phone file reads it exactly
-- like Theme; anything not set here (Sfx, Sounds, Job...) falls through to Theme. Reskin the phone HERE.
local Theme = require(script.Parent.Theme)

local C3 = Color3.fromRGB

local ink = C3(24, 25, 29) -- panels
local ink2 = C3(38, 40, 46) -- tiles and cards
local paper = C3(245, 245, 245) -- text
local muted = C3(165, 168, 175) -- secondary text
local blue = C3(96, 170, 255) -- selected / hover
local money = C3(92, 196, 104) -- money + buy buttons only
local gold = C3(240, 192, 72) -- level only
local danger = C3(230, 72, 72)

local gotham = "rbxasset://fonts/families/GothamSSm.json"

local Colors = {
	Glass = ink,
	GlassTransparency = 0.12,
	Stroke = C3(255, 255, 255),
	StrokeTransparency = 0.86,
	StrokeThickness = 1.5,
	Text = paper,
	TextDim = muted,
	Accent = blue, -- selection, links, toggles, the send button
	AccentAlt = C3(56, 59, 68), -- neutral fill (avatars, banner icon)
	Money = money,
	Danger = danger,
	Gold = gold,
	Shadow = C3(0, 0, 0),
}

local Fonts = {
	Display = Font.new(gotham, Enum.FontWeight.Heavy), -- labels, titles, big numbers
	Head = Font.new(gotham, Enum.FontWeight.Heavy),
	Bold = Font.new(gotham, Enum.FontWeight.Bold), -- row titles, buttons
	Body = Font.new(gotham, Enum.FontWeight.Medium), -- sentences
	Mono = Theme.Fonts.Mono,
}

local tile = ink2

local Phone = setmetatable({
	Frame = C3(20, 21, 24), -- the phone body
	FrameStroke = C3(62, 65, 74),
	Rim = C3(62, 65, 74), -- edge + side buttons
	Screen = C3(16, 17, 20),
	WallTop = C3(44, 58, 104), -- wallpaper: deep night blue fading to near-black, like a stock phone wallpaper
	WallBottom = C3(12, 13, 22),
	Card = ink2,
	CardHover = C3(50, 53, 61),
	Bubble = C3(40, 41, 46), -- their messages (a messenger's dark grey)
	BubbleMe = C3(32, 137, 255), -- my messages (messenger blue, white text)
	BubbleMeText = C3(255, 255, 255),
	Badge = danger, -- unread count (a phone's red dot)
	Answer = money,
	Decline = danger,
	Ink = ink,
	Line = C3(255, 255, 255),
	LineTransparency = 0.86,
	LineThickness = 1.5,
	Accent = blue,
	-- shape: rounded phone, rounded UI
	LowPoly = false,
	FrameCorner = UDim.new(0, 36),
	ScreenCorner = UDim.new(0, 28),
	Corner = UDim.new(0, 10),
	IconCorner = UDim.new(0, 14),
	BubbleCorner = UDim.new(0, 14),
	TileColor = tile,
	-- real phones have colourful app icons with a white symbol; these are calm versions of the stock colours
	AppColors = {
		Messages = C3(52, 199, 89),
		Calls = C3(48, 176, 82),
		Jobs = C3(255, 149, 0),
		Map = C3(10, 132, 255),
		Settings = C3(110, 112, 120),
		Plug = C3(30, 31, 36),
		Goals = C3(255, 69, 58),
		Camera = C3(72, 74, 82),
		Garage = C3(94, 92, 230),
		Money = C3(40, 160, 90),
		Story = C3(175, 82, 222),
	},
	IconGradient = true, -- a soft top-lit gradient on each icon
	-- the dock: frosted glass
	GlassTint = C3(255, 255, 255),
	GlassAlpha = 0.84,
	-- no decorative word on the wallpaper (plain is the point); set a string here to bring it back
	WallWord = "",
}, { __index = Theme.Phone })

local Look = setmetatable({
	Colors = Colors,
	Fonts = Fonts,
	Corner = UDim.new(0, 10),
	CornerSmall = UDim.new(0, 8),
	Phone = Phone,
}, { __index = Theme })

return Look

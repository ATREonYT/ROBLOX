--!strict
-- The approved look as tokens (design/theme.json, calibrated against design/pages). Nothing else hard-codes colours.
-- All sizes are in reference pixels: the size things measure in the 768-wide page references. Each window applies
-- one UIScale (see Scale.lua), so these numbers can be checked straight against design/annotated.
local Theme = {}

local hex = Color3.fromHex
-- Started from the reference pages' measured colours; the owner then asked for richer ones ("bland"): deeper
-- indigo panels, a more vivid purple and gold, brighter actions. Every button also gets a top-to-bottom shade (Kit).
Theme.Colors = {
	Frame = hex("0A1433"), -- 3.5 px dark frame round every window, header included
	Panel = hex("1A2A52"),
	MenuPanel = hex("0E1A3C"),
	Row = hex("233866"), RowTop = hex("2A4276"), RowBottom = hex("1E3058"), RowBorder = hex("34508C"),
	Header = hex("7C5CF6"), HeaderTop = hex("C4B4FF"),
	HeaderGradient = { { 0, hex("A38DFF") }, { 0.45, hex("7F60F8") }, { 1, hex("6440E6") } },
	Stud = hex("9576F9"), StudBottom = hex("7D61EB"), StudShadow = hex("6951D0"),
	TitleStroke = hex("0B0F24"), TitleShadow = hex("0B0F24"), TitleBand = hex("DADDF2"),
	InactiveTab = hex("2A4580"), InactiveTabTop = hex("3E5EA0"), TabRim = hex("0D1640"),
	HeaderTab = hex("243F74"), HeaderTabRim = hex("10133F"),
	SelectedTab = hex("38C95A"), SelectedTabTop = hex("8DF29A"), SelectedRim = hex("0E3F1A"), -- Huss Valley green (owner: no gold)
	Accent = hex("5BE07A"), -- the one bright colour: selected things, progress, good news,
	Segment = hex("324E86"), SegmentTop = hex("4766A6"),
	Action = hex("7466FF"), ActionHover = hex("8678FF"), ActionPressed = hex("5E50E8"), ActionTop = hex("ABA3FF"), ActionRim = hex("1C1562"),
	GiftTop = hex("B84FFA"), GiftBottom = hex("9925F9"), GiftRim = hex("3B0A6A"), -- the purple gift button (gradient)
	RobuxBadge = hex("1F2350"), -- the dark Robux mark on price buttons
	Disabled = hex("68739A"), DisabledTop = hex("8590B5"),
	Slate = hex("52628E"), SlateTop = hex("6A7CA8"),
	Text = hex("FFFFFF"),
	SubText = hex("B3C1EE"),
	NoteText = hex("C3CBE8"),
	DarkText = hex("182542"),
	TextShadow = hex("0A1426"),
	Close = hex("FF3355"), CloseTop = hex("FF6B83"), CloseBottom = hex("DE1240"), CloseRim = hex("3A0520"),
	Progress = hex("5BE07A"),
	Ink = hex("141B33"),
	Pill = hex("141F48"), PillRim = hex("1B2355"),
	Plus = hex("6A5BF2"), PlusTop = hex("9A8FFF"), PlusRim = hex("1C1562"), HudPlus = hex("5E52E6"),
	Divider = hex("4A6488"), Groove = hex("16273F"), CellRow = hex("18334E"), IconCell = hex("12293F"), CellDivider = hex("132B43"),
	Track = hex("2B477E"), TrackFill = hex("7C6CFF"), TrackRim = hex("08172B"), Knob = hex("C6C3FC"), KnobRim = hex("1A2560"),
	KeyBox = hex("172E48"), KeyBoxRim = hex("365984"), PercentBox = hex("0F253A"),
	MenuRow = hex("1A3160"), MenuRowTop = hex("2C4C8C"),
	HudTop = hex("373C96"), HudMid = hex("252C72"), HudBottom = hex("161D4E"), HudHighlight = hex("6370CC"), HudRing = hex("050D33"),
	Banner = hex("7A50FF"), BannerSeam = hex("5A34D6"), BannerRim = hex("161C36"),
	-- Coin cards (reference 08): 1 px rim, art on top, a fill that darkens just under the art, periwinkle price button.
	CoinCardRim = hex("34558F"), CoinCardShade = hex("132550"), CoinCard = hex("1C3260"), CoinCardBottom = hex("172A52"),
	CoinText = hex("FFFFFF"), CoinBlurb = hex("EDF5FA"),
	CoinBuy = hex("7466FF"), CoinBuyTop = hex("ABA3FF"), CoinBuyBevel = hex("8678FF"), CoinBuyRim = hex("0A1227"),
}

Theme.Transparency = { Panel = 0, Header = 0.06, Body = 0.22, Row = 0.12 } -- owner: "make the UI more transparent" (the world shows through the window bodies)

-- One font, as Huss Valley (owner: "use the same fonts as Huss Valley, it's simple and feels nice"): Roblox's
-- own Gotham, in a few weights. White text with a dark outline; big moments in Black Italic.
local GOTHAM = "rbxasset://fonts/families/GothamSSm.json"
Theme.Fonts = {
	Heading = Font.new(GOTHAM, Enum.FontWeight.Heavy), -- window titles: SHOP, DANCES (caps, dark outline)
	Name = Font.new(GOTHAM, Enum.FontWeight.Bold), -- names, product titles, the message line
	Tab = Font.new(GOTHAM, Enum.FontWeight.Bold), -- tabs (caps)
	Button = Font.new(GOTHAM, Enum.FontWeight.Bold), -- buttons (caps, thin outline)
	Body = Font.new(GOTHAM, Enum.FontWeight.Medium), -- descriptions, help lines
	Number = Font.new(GOTHAM, Enum.FontWeight.Bold), -- prices, coins, timers
	Label = Font.new(GOTHAM, Enum.FontWeight.Medium), -- search fields, small labels
	Big = Font.new(GOTHAM, Enum.FontWeight.Heavy, Enum.FontStyle.Italic), -- 3-2-1, GO!, SAFE, wins
}

-- Text sizes (reference px).
Theme.Text = { Title = 33, Tab = 18, Name = 21, Blurb = 17, Label = 14, Button = 20, Small = 11, Row = 17 }

Theme.Corner = 3
Theme.Motion = { Hover = 0.15, Press = 0.09, Release = 0.35, Open = 0.5, Close = 0.2, Tab = 0.2, Stagger = 0.05, Slide = 0.45, Hud = 0.4 }

return Theme

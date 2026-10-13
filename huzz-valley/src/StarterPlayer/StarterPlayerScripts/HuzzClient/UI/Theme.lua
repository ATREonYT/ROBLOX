--!strict
-- The approved look as tokens (design/theme.json, calibrated against design/pages). Nothing else hard-codes colours.
-- All sizes are in reference pixels: the size things measure in the 768-wide page references. Each window applies
-- one UIScale (see Scale.lua), so these numbers can be checked straight against design/annotated.
local Theme = {}

local hex = Color3.fromHex
-- Measured from the reference pages (critic pass: sampled pixels, not guesses).
Theme.Colors = {
	Frame = hex("072848"), -- 3.5 px dark frame round every window, header included
	Panel = hex("17283F"),
	MenuPanel = hex("0B2138"),
	Row = hex("223754"), RowTop = hex("213451"), RowBottom = hex("243954"), RowBorder = hex("2E4669"),
	Header = hex("7A5FEB"), HeaderTop = hex("9C86EF"),
	HeaderGradient = { { 0, hex("8A72F2") }, { 0.35, hex("7256EA") }, { 0.70, hex("7E66EF") }, { 1, hex("785AE8") } },
	Stud = hex("9576F9"), StudBottom = hex("7D61EB"), StudShadow = hex("6951D0"),
	TitleStroke = hex("1F1A90"), TitleShadow = hex("120F70"), TitleBand = hex("DADDF2"),
	InactiveTab = hex("28436D"), InactiveTabTop = hex("344F7B"), TabRim = hex("12183F"),
	HeaderTab = hex("223C64"), HeaderTabRim = hex("10133F"),
	SelectedTab = hex("FCCB76"), SelectedTabTop = hex("F8E58C"), SelectedRim = hex("3A2A12"),
	Segment = hex("375071"), SegmentTop = hex("445C7D"),
	Action = hex("7E7CEF"), ActionHover = hex("8E8CF5"), ActionPressed = hex("6C69DA"), ActionTop = hex("8C8CF6"), ActionRim = hex("1F2347"),
	GiftTop = hex("B84FFA"), GiftBottom = hex("9925F9"), GiftRim = hex("3B0A6A"), -- the purple gift button (gradient)
	RobuxBadge = hex("1F2350"), -- the dark Robux mark on price buttons
	Disabled = hex("717992"), DisabledTop = hex("7E869E"),
	Slate = hex("556585"), SlateTop = hex("637493"),
	Text = hex("F4F3FA"),
	SubText = hex("A6B8D6"),
	NoteText = hex("BAC2CF"),
	DarkText = hex("182542"),
	TextShadow = hex("0A1426"),
	Close = hex("EE1443"), CloseTop = hex("F31747"), CloseBottom = hex("DC0D3E"), CloseRim = hex("3A0520"),
	Progress = hex("F4C45F"),
	Ink = hex("141B33"),
	Pill = hex("16264A"), PillRim = hex("1B2355"),
	Plus = hex("5B54C4"), PlusTop = hex("6362C3"), PlusRim = hex("1E1C60"), HudPlus = hex("4F53B5"),
	Divider = hex("4A6488"), CellDivider = hex("132B43"),
	Track = hex("315177"), TrackFill = hex("8482F5"), TrackRim = hex("08172B"), Knob = hex("C6C3FC"), KnobRim = hex("1A2560"),
	KeyBox = hex("172E48"), KeyBoxRim = hex("365984"), PercentBox = hex("0F253A"),
	MenuRow = hex("172E48"), MenuRowTop = hex("234170"),
	HudTop = hex("2B3575"), HudMid = hex("212E5E"), HudBottom = hex("152242"), HudHighlight = hex("46599A"), HudRing = hex("050D33"),
	Banner = hex("7553E8"), BannerSeam = hex("5D3DCB"), BannerRim = hex("161C36"),
	-- Coin cards (reference 08): 1 px rim, art on top, a fill that darkens just under the art, periwinkle price button.
	CoinCardRim = hex("2D5380"), CoinCardShade = hex("12283F"), CoinCard = hex("19314C"), CoinCardBottom = hex("18304B"),
	CoinText = hex("FFFFFF"), CoinBlurb = hex("EDF5FA"),
	CoinBuy = hex("7977EE"), CoinBuyTop = hex("8A89F6"), CoinBuyBevel = hex("8486F2"), CoinBuyRim = hex("0A1227"),
}

Theme.Transparency = { Panel = 0, Header = 0, Body = 0.25, Row = 0 } -- the reference panels are opaque

local CONDENSED = "rbxasset://fonts/families/RobotoCondensed.json"
local MONTSERRAT = "rbxasset://fonts/families/Montserrat.json"
-- The owner's font table (one role per kind of text):
Theme.Fonts = {
	Heading = Font.new(MONTSERRAT, Enum.FontWeight.Heavy), -- SHOP, DANCES, PROGRESSION: Montserrat Black, uppercase, thin dark outline
	Name = Font.new(MONTSERRAT, Enum.FontWeight.Bold), -- character names, product titles: no outline
	Tab = Font.new(CONDENSED, Enum.FontWeight.Bold), -- OWNED, COSMETICS, QUESTS: uppercase
	Button = Font.new(CONDENSED, Enum.FontWeight.Bold), -- CLAIM, PLAY, UNEQUIP: consistent size, minimal outline
	Body = Font.new(CONDENSED, Enum.FontWeight.Regular), -- descriptions, quest instructions
	Number = Font.new(MONTSERRAT, Enum.FontWeight.Bold), -- prices, currencies, XP numbers
	Label = Font.new(MONTSERRAT, Enum.FontWeight.Medium), -- search fields, smaller labels
}

-- Text sizes (reference px).
Theme.Text = { Title = 33, Tab = 19, Name = 23, Blurb = 17, Label = 14, Button = 20, Small = 11, Row = 17 }

Theme.Corner = 3
Theme.StudTile = 24 -- reference px per stud tile (the texture has one bevelled stud per tile)
Theme.Motion = { Hover = 0.10, Press = 0.07, Open = 0.20, Close = 0.14, Tab = 0.12 }

return Theme

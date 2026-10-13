--!strict
-- The approved look as tokens (design/theme.json, calibrated against design/pages). Nothing else hard-codes colours.
-- All sizes are in reference pixels: the size things measure in the 768-wide page references. Each window applies
-- one UIScale (see Scale.lua), so these numbers can be checked straight against design/annotated.
local Theme = {}

local hex = Color3.fromHex
Theme.Colors = {
	Panel = hex("253D59"),
	Body = hex("1E3150"), -- the darker field the rows sit on
	Row = hex("2A4466"),
	RowBorder = hex("3E5A80"),
	Header = hex("8363C4"),
	HeaderStud = hex("9479D0"),
	InactiveTab = hex("30466D"),
	SelectedTab = hex("F8C56E"),
	Action = hex("8C88CC"),
	ActionHover = hex("9C99DB"),
	ActionPressed = hex("7773B5"),
	Gift = hex("9B3FE0"),
	Disabled = hex("66728E"),
	Text = hex("F4F3FA"),
	SubText = hex("C9D2E6"),
	DarkText = hex("182542"),
	Border = hex("536985"),
	SelectedBorder = hex("F2CB69"),
	Close = hex("D82B57"),
	Progress = hex("F4C45F"),
	Ink = hex("141B33"), -- title outline
	Pill = hex("1B2A47"),
	Plus = hex("7D5FD0"),
	Divider = hex("4A6488"),
	Track = hex("3A5277"),
}

Theme.Transparency = { Panel = 0.12, Header = 0.0, Body = 0.25, Row = 0.1 }

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
Theme.Text = { Title = 29, Tab = 17, Name = 21, Blurb = 17, Label = 14, Button = 20, Small = 11, Row = 15 }

Theme.Corner = 4
Theme.Motion = { Hover = 0.10, Press = 0.07, Open = 0.20, Close = 0.14, Tab = 0.12 }

return Theme

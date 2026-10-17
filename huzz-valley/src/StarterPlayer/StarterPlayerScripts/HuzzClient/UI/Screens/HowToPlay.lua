-- How to Play, after the owner's Oct 17 mockup (design/ui-oct17/how-to-play.png; owner earlier: "make the onboarding
-- for the game feel nice"). Three numbered cards: 1 RUN ACROSS (green), 2 SAVE FRIENDS (blue), 3 BE THE HERO (pink),
-- each with a short line (key words in the card's colour) and a picture cut from the mockup (placeholders until the
-- owner sends sharp PNGs: tools/icons/make_screen_art.py). Along the bottom, the keys as they really are in our game
-- (CLAUDE.md section 1): Space dash (a catcher's Space lunges), Q power (E the other one), click stab (catchers), Alt
-- frees the mouse. On a touch screen only the dash button and the power tiles show (the rest are keyboard only).
-- It opens by itself the first time someone joins (once their save has loaded, in the lobby, nothing else open) and
-- from the Menu's How to Play any time. Closing it saves the TutorialDone setting, so it never pops up again itself.
-- The mockup's window is taller than ours (701 x 320, as every window), so the cards are shorter: each picture keeps
-- the middle of the action.
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")

local UI = script.Parent.Parent
local Theme = require(UI.Theme)
local Kit = require(UI.Kit)
local State = require(UI.State)
local ModalManager = require(UI.ModalManager)

local C = Theme.Colors
local F = Theme.Fonts
local new = Kit.new
local hex = Color3.fromHex

local HowToPlay = {}

local W, H = 701, 320 -- every main window shares this size
-- measured on the mockup (x 0.514), squeezed to the window's height
local CARD = { X = { 16, 247, 471 }, W = { 221, 216, 216 }, Y = 55, H = 205, Badge = 32, PicY = 84 }
local KEYS = { X = 16, Y = 268, W = 672, H = 44, CapH = 30 }
local CARDS = {
	{ Title = "RUN ACROSS", Color = hex("6CE17D"), Fill = hex("173A32"),
		Text = "Reach the {SAFE ZONE} across the map without getting stabbed." },
	{ Title = "SAVE FRIENDS", Color = hex("3A7DE5"), Fill = hex("10204D"),
		Text = "Someone down? Stand next to them to {pick them back up.}" },
	{ Title = "BE THE HERO", Color = hex("E85A86"), Fill = hex("4A1A30"),
		Text = "Picked? Go {HERO} and cross alone. Make it and you carry her!" },
}
-- the line's highlight in each card's colour, a little lighter so it reads on the dark card
local HIGHLIGHT = { hex("7CF28E"), hex("64AEFF"), hex("FF6FA2") }
-- Our keys (keyboard). Cap = the key's label (nil: the mouse picture); Sub = a smaller second line.
local KEYBOARD = {
	{ Cap = "Space", CapW = 62, X = 10, Label = "Dash", Sub = "Catchers lunge", Divider = 180 },
	{ Cap = "Q", CapW = 38, X = 192, Label = "Use Power", Divider = 336 },
	{ Cap = nil, CapW = 22, X = 352, Label = "Click", Sub = "Stab (Catchers)", Divider = 500 },
	{ Cap = "Alt", CapW = 48, X = 514, Label = "Free Mouse" },
}
-- On a touch screen the same parts are relabelled (the saved UI holds the keyboard row) and the keyboard-only
-- keys hide.
local TOUCH = { { Cap = "DASH", Label = "Button" }, { Cap = "Q E", Label = "Power tiles" } }
local COL = { Keys = hex("0E1A3F"), KeysRim = hex("233565"), Divider = hex("1E2E5E"), Cap = hex("13204A"), CapRim = hex("8FB0FF"), Sub = hex("A9B7E0"), Card = hex("0D1638") }

local function richText(def, i: number): string
	local color = HIGHLIGHT[i]
	local tag = string.format('<font color="#%02X%02X%02X"><b>', math.round(color.R * 255), math.round(color.G * 255), math.round(color.B * 255))
	return (def.Text:gsub("{(.-)}", function(w) return tag .. w .. "</b></font>" end))
end

local function card(parent: Instance, i: number, def)
	local w = CARD.W[i]
	local f = new("Frame", { Name = "Card" .. i, Position = UDim2.fromOffset(CARD.X[i], CARD.Y), Size = UDim2.fromOffset(w, CARD.H), BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, Parent = parent }, { Kit.corner(8), Kit.stroke(def.Color, 2) })
	-- dark card lit from the top in its colour (the mockup's tinted glass)
	new("UIGradient", { Name = "Fill", Rotation = 90, Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, def.Fill), ColorSequenceKeypoint.new(0.45, def.Fill:Lerp(COL.Card, 0.5)), ColorSequenceKeypoint.new(1, COL.Card) }), Parent = f })
	-- the soft outer glow of the rim
	local halo = new("Frame", { Name = "Halo", Position = UDim2.fromOffset(-3, -3), Size = UDim2.new(1, 6, 1, 6), BackgroundTransparency = 1, Parent = f }, { Kit.corner(10) })
	new("UIStroke", { Name = "Glow", Color = def.Color, Thickness = 2, Transparency = 0.6, Parent = halo })
	-- the picture fills the lower part, its top fading into the card under the text
	Kit.attach(Kit.corner(6), Kit.art("HowToPlay" .. i, { Name = "Picture", Position = UDim2.fromOffset(2, CARD.PicY), Size = UDim2.fromOffset(w - 4, CARD.H - CARD.PicY - 2), Parent = f }))
	-- the step number: a round badge in the card's colour with a white rim
	local badge = new("Frame", { Name = "Step", Position = UDim2.fromOffset(8, 7), Size = UDim2.fromOffset(CARD.Badge, CARD.Badge), BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, Parent = f }, { Kit.corner(math.floor(CARD.Badge / 2)), Kit.stroke(Color3.new(1, 1, 1), 2) })
	new("UIGradient", { Name = "Fill", Rotation = 90, Color = ColorSequence.new(def.Color:Lerp(Color3.new(1, 1, 1), 0.2), def.Color:Lerp(Color3.new(0, 0, 0), 0.25)), Parent = badge })
	local digit = Kit.text({ Name = "Digit", Text = tostring(i), FontFace = F.Heading, TextSize = 20, TextXAlignment = Enum.TextXAlignment.Center, Size = UDim2.fromScale(1, 1), Parent = badge })
	new("UIStroke", { Name = "Outline", Color = C.TitleStroke, Thickness = 1.5, Parent = digit })
	local title = Kit.name({ Name = "Title", Text = def.Title, FontFace = F.Heading, TextSize = 18, Position = UDim2.fromOffset(48, 7), Size = UDim2.fromOffset(w - 54, 32), Parent = f })
	new("UIStroke", { Name = "Outline", Color = C.TitleStroke, Thickness = 1.5, LineJoinMode = Enum.LineJoinMode.Round, Parent = title })
	Kit.text({ Name = "Blurb", Text = richText(def, i), RichText = true, FontFace = F.Label, TextSize = 13, LineHeight = 1.0, TextYAlignment = Enum.TextYAlignment.Top, Position = UDim2.fromOffset(36, 40), Size = UDim2.fromOffset(w - 44, 44), ZIndex = 2, Parent = f })
	return f
end

-- A key cap: a dark navy rounded square with a light blue glowing rim, its label in white.
local function cap(parent: Instance, text: string?, x: number, w: number)
	local y = math.floor((KEYS.H - KEYS.CapH) / 2)
	if not text then
		-- the mouse: a white rounded body with the button line, drawn (no icon in the kit)
		local mouse = new("Frame", { Name = "Mouse", Position = UDim2.fromOffset(x, y - 1), Size = UDim2.fromOffset(w, KEYS.CapH + 2), BackgroundColor3 = hex("E9EEFA"), BorderSizePixel = 0, Parent = parent }, { Kit.corner(math.floor(w / 2)), Kit.stroke(hex("6E7FB0"), 1) })
		new("Frame", { Name = "Line", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 3), Size = UDim2.fromOffset(2, 9), BackgroundColor3 = hex("6E7FB0"), BorderSizePixel = 0, Parent = mouse })
		return mouse
	end
	local f = new("Frame", { Name = "Cap", Position = UDim2.fromOffset(x, y), Size = UDim2.fromOffset(w, KEYS.CapH), BackgroundColor3 = COL.Cap, BorderSizePixel = 0, Parent = parent }, { Kit.corner(6), Kit.stroke(COL.CapRim, 2) })
	Kit.text({ Name = "Key", Text = text, FontFace = F.Name, TextSize = 16, TextXAlignment = Enum.TextXAlignment.Center, TextWrapped = false, Size = UDim2.fromScale(1, 1), Parent = f })
	return f
end

function HowToPlay.build(parent: Instance)
	local player = Players.LocalPlayer
	local window = Kit.window({ Name = "HowToPlay", Title = "HOW TO PLAY", Icon = "Players", Width = W, Height = H, TitleWidth = 230, Parent = parent, OnClose = function() ModalManager.close() end })
	local panel = window.Panel
	local cards = {}
	for i, def in CARDS do
		cards[i] = card(panel, i, def)
	end

	-- the key row
	local keys = new("Frame", { Name = "Keys", Position = UDim2.fromOffset(KEYS.X, KEYS.Y), Size = UDim2.fromOffset(KEYS.W, KEYS.H), BackgroundColor3 = COL.Keys, BackgroundTransparency = 0.1, BorderSizePixel = 0, Parent = panel }, { Kit.corner(6), Kit.stroke(COL.KeysRim, 1) })
	local touch = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
	for i, k in KEYBOARD do
		local slot = new("Frame", { Name = "Key" .. i, Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Parent = keys })
		local c = cap(slot, k.Cap, k.X, k.CapW)
		local t = TOUCH[i]
		if touch then
			slot.Visible = t ~= nil
			local keyText = c:FindFirstChild("Key") :: TextLabel?
			if t and keyText then keyText.Text = t.Cap end
		end
		local tx = k.X + k.CapW + 12
		local label = if touch and t then t.Label else k.Label
		if k.Sub then
			Kit.text({ Name = "Label", Text = label, FontFace = F.Label, TextSize = 15, TextWrapped = false, Position = UDim2.fromOffset(tx, 5), Size = UDim2.fromOffset(150, 18), Parent = slot })
			Kit.text({ Name = "Sub", Text = k.Sub, FontFace = F.Label, TextSize = 11, TextColor3 = COL.Sub, TextWrapped = false, Position = UDim2.fromOffset(tx, 23), Size = UDim2.fromOffset(150, 14), Parent = slot })
		else
			Kit.text({ Name = "Label", Text = label, FontFace = F.Label, TextSize = 15, TextWrapped = false, Position = UDim2.fromOffset(tx, 0), Size = UDim2.fromOffset(150, KEYS.H), Parent = slot })
		end
		if k.Divider then
			new("Frame", { Name = "Divider", Position = UDim2.fromOffset(k.Divider, 6), Size = UDim2.fromOffset(2, KEYS.H - 12), BackgroundColor3 = COL.Divider, BorderSizePixel = 0, Visible = not (touch and i == #TOUCH), Parent = slot })
		end
	end

	ModalManager.register("HowToPlay", {
		window = window,
		onClose = function()
			if State.setting("TutorialDone") ~= true then
				task.spawn(State.setSetting, "TutorialDone", true)
			end
		end,
		firstSelect = function() return window.Close.Instance end,
		items = function() return cards end,
	})

	-- First time here: open once the save has loaded, in the lobby, with nothing else open (if a round or a
	-- window is in the way, it waits for the lobby).
	local opened = false
	local function maybeOpen()
		if opened or not State.data.Loaded or State.setting("TutorialDone") == true then return end
		local role = player:GetAttribute("HuzzRole")
		if ModalManager.current() == nil and role ~= "Runner" and role ~= "Catcher" then
			opened = true
			task.delay(1.2, function()
				if ModalManager.current() == nil then ModalManager.open("HowToPlay") else opened = false end
			end)
		end
	end
	State.changed(maybeOpen)
	ModalManager.changed(function() task.defer(maybeOpen) end)
	player:GetAttributeChangedSignal("HuzzRole"):Connect(maybeOpen)
	maybeOpen()
	return window
end

return HowToPlay

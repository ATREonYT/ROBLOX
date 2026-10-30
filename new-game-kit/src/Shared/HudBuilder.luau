--!strict
-- New Game Kit: HudBuilder (builds the cartoony HUD as real parts)
-- Install: ReplicatedStorage/Kit/HudBuilder (ModuleScript)
--
-- Repo rule: UI lives in StarterGui as real parts. tools/build_place.luau runs
-- this builder once (offline, with Lune) and saves the result as
-- src/StarterGui/KitHUD.rbxm, so the owner sees and edits it in Studio.
-- The client (src/Client/KitClient.client.luau) reuses those parts by name and
-- only calls Build itself if KitHUD is missing.
--
-- Style (roblox-cartoony-ui skill): opaque toy panels, darker lip under every
-- button, black 3 px outline, corner 10, vertical gradient, chunky FredokaOne
-- text with a dark stroke. Colour = meaning: yellow primary, green confirm,
-- red close, blue navigate. No emoji: every button has an empty Icon
-- ImageLabel for the owner's icons (never invent asset ids). Whole-pixel
-- offsets only; fixed TextSize, no TextScaled.
-- Uses only Instance.new and datatypes, so it runs in Studio and in Lune.

local HudBuilder = {}

local FONT = Font.fromEnum(Enum.Font.FredokaOne)
local INK = Color3.fromRGB(20, 18, 30)
local WHITE = Color3.new(1, 1, 1)

HudBuilder.Colors = {
	Yellow = { Color3.fromRGB(255, 214, 51), Color3.fromRGB(222, 150, 10) },
	Green = { Color3.fromRGB(120, 230, 60), Color3.fromRGB(60, 170, 30) },
	Red = { Color3.fromRGB(255, 80, 80), Color3.fromRGB(200, 30, 45) },
	Blue = { Color3.fromRGB(80, 170, 255), Color3.fromRGB(35, 100, 215) },
	Purple = { Color3.fromRGB(180, 110, 255), Color3.fromRGB(115, 50, 210) },
	Orange = { Color3.fromRGB(255, 160, 60), Color3.fromRGB(220, 95, 20) },
	Pink = { Color3.fromRGB(255, 130, 200), Color3.fromRGB(215, 70, 150) },
	Panel = { Color3.fromRGB(255, 250, 235), Color3.fromRGB(240, 226, 196) },
	Card = { Color3.fromRGB(120, 195, 255), Color3.fromRGB(75, 145, 235) },
}

local function make(className: string, props: { [string]: any }, children: { Instance }?): any
	local inst = Instance.new(className)
	for key, value in props do
		if key ~= "Parent" then
			(inst :: any)[key] = value
		end
	end
	for _, child in children or {} do
		child.Parent = inst
	end
	if props.Parent then
		inst.Parent = props.Parent
	end
	return inst
end

local function corner(radius: number): UICorner
	return make("UICorner", { CornerRadius = UDim.new(0, radius) })
end

local function outline(thickness: number, color: Color3?): UIStroke
	return make("UIStroke", {
		Thickness = thickness,
		Color = color or INK,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		LineJoinMode = Enum.LineJoinMode.Round,
	})
end

local function gradient(top: Color3, bottom: Color3): UIGradient
	return make("UIGradient", {
		Color = ColorSequence.new(top, bottom),
		Rotation = 90,
	})
end

-- Chunky text with a dark outline so it reads on any colour.
local function label(name: string, text: string, size: number, props: { [string]: any }?): TextLabel
	local base = {
		Name = name,
		Text = text,
		FontFace = FONT,
		TextSize = size,
		TextColor3 = WHITE,
		BackgroundTransparency = 1,
		TextXAlignment = Enum.TextXAlignment.Center,
	}
	for k, v in props or {} do
		base[k] = v
	end
	return make("TextLabel", base, { make("UIStroke", { Thickness = 2, Color = INK, LineJoinMode = Enum.LineJoinMode.Round }) })
end
HudBuilder.Label = label

-- Toy button: a holder with a darker lip 4 px below the face. The click
-- target is holder.Face (a TextButton). Returns the holder.
function HudBuilder.ToyButton(name: string, text: string, colorName: string, size: UDim2, textSize: number?): Frame
	local colors = HudBuilder.Colors[colorName]
	local holder = make("Frame", { Name = name, Size = size, BackgroundTransparency = 1 })
	make("Frame", {
		Name = "Lip",
		Parent = holder,
		Size = UDim2.new(1, 0, 1, -4),
		Position = UDim2.fromOffset(0, 4),
		BackgroundColor3 = colors[2],
		BorderSizePixel = 0,
	}, { corner(10), outline(3) })
	local face = make("TextButton", {
		Name = "Face",
		Parent = holder,
		Size = UDim2.new(1, 0, 1, -4),
		BackgroundColor3 = WHITE,
		BorderSizePixel = 0,
		AutoButtonColor = false,
		Text = "",
	}, { corner(10), outline(3), gradient(colors[1], colors[2]:Lerp(colors[1], 0.45)) })
	make("ImageLabel", {
		Name = "Icon",
		Parent = face,
		Size = UDim2.fromOffset(0, 0), -- the client sizes it when an icon id is set
		BackgroundTransparency = 1,
		Image = "",
	})
	label("Label", text, textSize or 20, { Parent = face, Size = UDim2.fromScale(1, 1) })
	return holder
end

-- An opaque toy panel with a title tab and a red close button.
local function panel(name: string, title: string, colorName: string): (Frame, Frame)
	local colors = HudBuilder.Colors.Panel
	local accent = HudBuilder.Colors[colorName]
	local frame = make("Frame", {
		Name = name,
		Visible = false,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.52),
		Size = UDim2.fromScale(0.62, 0.68),
		BackgroundColor3 = WHITE,
		BorderSizePixel = 0,
	}, {
		corner(14),
		outline(4),
		gradient(colors[1], colors[2]),
		make("UISizeConstraint", { MinSize = Vector2.new(300, 230), MaxSize = Vector2.new(560, 420) }),
	})
	local tab = make("Frame", {
		Name = "Title",
		Parent = frame,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0),
		Size = UDim2.fromOffset(260, 46),
		BackgroundColor3 = WHITE,
		BorderSizePixel = 0,
		ZIndex = 3,
	}, { corner(12), outline(3), gradient(accent[1], accent[2]) })
	label("Label", title, 28, { Parent = tab, Size = UDim2.fromScale(1, 1), ZIndex = 4 })
	local close = HudBuilder.ToyButton("Close", "X", "Red", UDim2.fromOffset(44, 48), 26)
	close.AnchorPoint = Vector2.new(0.5, 0.5)
	close.Position = UDim2.new(1, -6, 0, 6)
	close.ZIndex = 5
	close.Parent = frame
	local body = make("Frame", {
		Name = "Body",
		Parent = frame,
		Position = UDim2.fromOffset(14, 34),
		Size = UDim2.new(1, -28, 1, -48),
		BackgroundTransparency = 1,
	})
	return frame, body
end

-- A scrolling list with a hidden row template the client clones.
local function list(parent: Instance, rowAction: string?): ScrollingFrame
	local scroller = make("ScrollingFrame", {
		Name = "List",
		Parent = parent,
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 8,
		ScrollBarImageColor3 = INK,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollingDirection = Enum.ScrollingDirection.Y,
	}, {
		make("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }),
		-- Room for outlines: a ScrollingFrame clips its children's outer strokes.
		make("UIPadding", { PaddingTop = UDim.new(0, 6), PaddingBottom = UDim.new(0, 6), PaddingLeft = UDim.new(0, 6), PaddingRight = UDim.new(0, 14) }),
	})
	local card = HudBuilder.Colors.Card
	local row = make("Frame", {
		Name = "RowTemplate",
		Parent = scroller,
		Visible = false,
		Size = UDim2.new(1, 0, 0, 66),
		BackgroundColor3 = WHITE,
		BorderSizePixel = 0,
	}, { corner(10), outline(3), gradient(card[1], card[2]) })
	make("ImageLabel", {
		Name = "Icon",
		Parent = row,
		Position = UDim2.fromOffset(8, 9),
		Size = UDim2.fromOffset(48, 48),
		BackgroundTransparency = 1,
		Image = "",
	})
	label("Title", "Title", 22, {
		Parent = row,
		Position = UDim2.fromOffset(64, 6),
		Size = UDim2.new(1, -200, 0, 28),
		TextXAlignment = Enum.TextXAlignment.Left,
	})
	label("Sub", "", 16, {
		Parent = row,
		Position = UDim2.fromOffset(64, 34),
		Size = UDim2.new(1, -200, 0, 24),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = Color3.fromRGB(255, 240, 200),
	})
	local action = HudBuilder.ToyButton("Action", rowAction or "Buy", "Green", UDim2.fromOffset(120, 48), 20)
	action.AnchorPoint = Vector2.new(1, 0.5)
	action.Position = UDim2.new(1, -8, 0.5, 0)
	action.Parent = row
	return scroller
end

-- The left menu: two columns of square toy buttons.
local MENU = {
	{ "Shop", "SHOP", "Yellow" },
	{ "Eggs", "EGGS", "Orange" },
	{ "Pets", "PETS", "Pink" },
	{ "Upgrades", "UPGRADE", "Blue" },
	{ "Rebirth", "REBIRTH", "Purple" },
	{ "Gifts", "GIFTS", "Green" },
	{ "Codes", "CODES", "Blue" },
	{ "Settings", "SETTINGS", "Blue" },
}
HudBuilder.Menu = MENU

function HudBuilder.Build(): ScreenGui
	local gui = make("ScreenGui", {
		Name = "KitHUD",
		ResetOnSpawn = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets,
	})

	-- Top bar: currency pills (clear of the Roblox top-bar buttons).
	local top = make("Frame", {
		Name = "TopBar",
		Parent = gui,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 8),
		Size = UDim2.fromOffset(480, 44),
		BackgroundTransparency = 1,
	}, { make("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		Padding = UDim.new(0, 10),
	}) })
	for i, pill in { { "Coins", "Yellow" }, { "Gems", "Blue" }, { "Rebirths", "Purple" } } do
		local colors = HudBuilder.Colors[pill[2]]
		local frame = make("Frame", {
			Name = pill[1],
			Parent = top,
			LayoutOrder = i,
			Size = UDim2.fromOffset(150, 40),
			BackgroundColor3 = WHITE,
			BorderSizePixel = 0,
		}, { corner(20), outline(3), gradient(colors[1], colors[2]) })
		make("ImageLabel", { Name = "Icon", Parent = frame, Position = UDim2.fromOffset(4, 2), Size = UDim2.fromOffset(36, 36), BackgroundTransparency = 1, Image = "" })
		label("Amount", "0", 24, { Parent = frame, Position = UDim2.fromOffset(40, 0), Size = UDim2.new(1, -48, 1, 0) })
	end

	-- Left menu: two columns of square buttons, placed by hand (whole pixels).
	local menu = make("Frame", {
		Name = "Menu",
		Parent = gui,
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 12, 0.5, 0),
		Size = UDim2.fromOffset(156, 4 * 82),
		BackgroundTransparency = 1,
	})
	for i, entry in MENU do
		local button = HudBuilder.ToyButton(entry[1], entry[2], entry[3], UDim2.fromOffset(74, 74), 15)
		button.LayoutOrder = i
		button.Position = UDim2.fromOffset(((i - 1) % 2) * 82, ((i - 1) // 2) * 82)
		button.Parent = menu
	end

	-- Big tap button, bottom right (thumb reach on phones).
	local tap = HudBuilder.ToyButton("Tap", "TAP!", "Green", UDim2.fromOffset(150, 96), 34)
	tap.AnchorPoint = Vector2.new(1, 1)
	tap.Position = UDim2.new(1, -16, 1, -16)
	tap.Parent = gui

	-- Panels.
	local panels = make("Folder", { Name = "Panels", Parent = gui })
	local shop, shopBody = panel("Shop", "SHOP", "Yellow")
	list(shopBody, "Buy")
	shop.Parent = panels
	local eggs, eggsBody = panel("Eggs", "EGGS", "Orange")
	list(eggsBody, "Hatch")
	eggs.Parent = panels
	local pets, petsBody = panel("Pets", "PETS", "Pink")
	list(petsBody, "Equip")
	pets.Parent = panels
	local upgrades, upgradesBody = panel("Upgrades", "UPGRADES", "Blue")
	list(upgradesBody, "Buy")
	upgrades.Parent = panels
	local gifts, giftsBody = panel("Gifts", "GIFTS", "Green")
	list(giftsBody, "Claim")
	gifts.Parent = panels
	local settings, settingsBody = panel("Settings", "SETTINGS", "Blue")
	list(settingsBody, "On")
	settings.Parent = panels

	local rebirth, rebirthBody = panel("Rebirth", "REBIRTH", "Purple")
	label("Info", "", 24, { Parent = rebirthBody, Size = UDim2.new(1, 0, 0.6, 0), TextWrapped = true })
	local rebirthButton = HudBuilder.ToyButton("Confirm", "REBIRTH", "Purple", UDim2.fromOffset(220, 64), 28)
	rebirthButton.AnchorPoint = Vector2.new(0.5, 1)
	rebirthButton.Position = UDim2.fromScale(0.5, 1)
	rebirthButton.Parent = rebirthBody
	rebirth.Parent = panels

	local codes, codesBody = panel("Codes", "CODES", "Blue")
	make("TextBox", {
		Name = "Input",
		Parent = codesBody,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 30),
		Size = UDim2.new(1, -40, 0, 56),
		BackgroundColor3 = WHITE,
		FontFace = FONT,
		TextSize = 26,
		TextColor3 = INK,
		PlaceholderText = "Type a code",
		PlaceholderColor3 = Color3.fromRGB(150, 150, 160),
		Text = "",
		ClearTextOnFocus = false,
	}, { corner(10), outline(3) })
	local redeem = HudBuilder.ToyButton("Redeem", "REDEEM", "Green", UDim2.fromOffset(200, 60), 26)
	redeem.AnchorPoint = Vector2.new(0.5, 1)
	redeem.Position = UDim2.fromScale(0.5, 1)
	redeem.Parent = codesBody
	codes.Parent = panels

	-- Popup (offline earnings, rewards) and toast (short feedback).
	local popup, popupBody = panel("Popup", "WELCOME BACK!", "Yellow")
	popup.Size = UDim2.fromScale(0.45, 0.45)
	popup.Parent = gui
	label("Message", "", 26, { Parent = popupBody, Size = UDim2.new(1, 0, 0.6, 0), TextWrapped = true })
	local ok = HudBuilder.ToyButton("Ok", "YAY!", "Green", UDim2.fromOffset(180, 60), 28)
	ok.AnchorPoint = Vector2.new(0.5, 1)
	ok.Position = UDim2.fromScale(0.5, 1)
	ok.Parent = popupBody

	label("Toast", "", 26, {
		Parent = gui,
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -130),
		Size = UDim2.fromOffset(520, 40),
		Visible = false,
		TextWrapped = true,
	})
	return gui
end

return HudBuilder

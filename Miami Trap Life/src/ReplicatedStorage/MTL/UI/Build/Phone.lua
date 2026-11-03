--!strict
-- Builds the MTL_Phone ScreenGui. Used two ways (same as HUD):
--   1. Edit time (Install.lua / command bar): saved into StarterGui as real instances Alex can reskin
--   2. Runtime fallback: PhoneController builds it only if PlayerGui has no MTL_Phone
-- PhoneController finds things BY NAME. Keep these names when reskinning (replace images/colours freely):
--   Phone (moves; has UIScale)            Phone/Body (the clickable phone, ImageButton)
--   Phone/Badge                            red count when closed
--   Body/Screen                            clips everything inside the glass
--   Screen/Wallpaper  Screen/StatusBar/{Time,Notch,Status}
--   Screen/Home/{Date,Clock,Grid,Dock}          Grid|Dock/App_<AppId>/{Icon/Art,Label}  (from Config/Phone.Apps)
--   Screen/AppHost                         apps mount here
--   Screen/Banner/{Icon,Title,Body}        notification that slides down from the top
--   Screen/Call/{Avatar,Caller,Status,Caption/{Who,Line},Choices,Answer,Decline,HangUp,Skip}
--   Screen/HomeBar                         tap = home, drag down = close
-- Layout is in design pixels (Config/Phone.Tuning.DesignSize, 300 x 620); UIScale fits it to the screen.
-- Look: UI/PhoneLook (matches the HUD palette: dark slate, white text, green only for money, soft blue for
-- selected). No emoji icons or facets: app icons are simple line symbols drawn from frames.
local Theme = require(script.Parent.Parent.PhoneLook) :: any
local UIKit = require(script.Parent.Parent.UIKit)
local PhoneConfig = require(script.Parent.Parent.Parent.Config.Phone) -- relative, so the installer's temp copy works

local C = Theme.Colors
local P = Theme.Phone
local new = UIKit.new
local corner = UIKit.corner

local Build = {}

local function hairline(transparency: number?, color: Color3?): UIStroke
	return new("UIStroke", {
		Name = "Stroke",
		Color = color or P.Line,
		Transparency = transparency or P.LineTransparency,
		Thickness = P.LineThickness or 1,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	})
end

local STATUS_H = 30
local HOMEBAR_H = 22

-- A phone handset drawn from plain frames, so it never depends on a font having the glyph.
-- Tilt 0 = lying flat with the ear and mouth pads pointing down (hang up); about -35 = tilted (answer).
local function handset(tilt: number, parent: Instance, color: Color3?, scale: number?): Frame
	local k = scale or 1
	local box = new("Frame", {
		Name = "Handset",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(30 * k, 22 * k),
		BackgroundTransparency = 1,
		Rotation = tilt,
		Parent = parent,
	})
	local function piece(name: string, x: number, y: number, w: number, h: number)
		new("Frame", {
			Name = name,
			Position = UDim2.fromOffset(x * k, y * k),
			Size = UDim2.fromOffset(w * k, h * k),
			BackgroundColor3 = color or C.Text,
			BorderSizePixel = 0,
			Parent = box,
		}, { corner(UDim.new(0, math.max(2, 4 * k))) })
	end
	piece("Grip", 1, 3, 28, 8)
	piece("Ear", 0, 6, 10, 13)
	piece("Mouth", 20, 6, 10, 13)
	return box
end

-- App symbols: simple line drawings in warm white, built from frames (no emoji, no font glyphs).
-- Drawn in a 26 x 26 box named "Art"; TODO(Alex art): Theme.Phone.Icons[id] image replaces it.
function Build.drawIcon(id: string, parent: Instance, color: Color3?, bg: Color3?): Frame
	local col = color or C.Text
	local back = bg or P.TileColor
	local art = new("Frame", {
		Name = "Art",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(26, 26),
		BackgroundTransparency = 1,
		Parent = parent,
	})
	local z = 0 -- later pieces draw on top (the pin's hole over its head, etc.)
	local function fill(x: number, y: number, w: number, h: number, round: UDim?, rot: number?, c: Color3?)
		z += 1
		return new("Frame", {
			ZIndex = z,
			Position = UDim2.fromOffset(x, y),
			Size = UDim2.fromOffset(w, h),
			Rotation = rot or 0,
			BackgroundColor3 = c or col,
			BorderSizePixel = 0,
			Parent = art,
		}, if round then { corner(round) } else nil)
	end
	local function ring(x: number, y: number, w: number, h: number, round: UDim?)
		z += 1
		return new("Frame", {
			ZIndex = z,
			Position = UDim2.fromOffset(x, y),
			Size = UDim2.fromOffset(w, h),
			BackgroundTransparency = 1,
			Parent = art,
		}, { corner(round or UDim.new(0, 3)), new("UIStroke", { Color = col, Thickness = 2, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }) })
	end
	local full = UDim.new(1, 0)
	if id == "Messages" then
		ring(1, 3, 24, 16, UDim.new(0, 4))
		fill(5, 16, 7, 7, nil, 45, back) -- gap in the outline where the tail leaves
		fill(6, 17, 5, 5, nil, 45)
		fill(6, 8, 14, 2)
		fill(6, 12, 9, 2)
	elseif id == "Calls" then
		handset(-35, art, col, 0.8)
	elseif id == "Jobs" then
		ring(1, 8, 24, 15, UDim.new(0, 2))
		ring(8, 3, 10, 7, UDim.new(0, 2))
		fill(1, 14, 24, 2)
	elseif id == "Map" then
		fill(8, 8, 10, 10, nil, 45) -- the pin's point
		fill(6, 1, 14, 14, full) -- the pin's head
		fill(10, 5, 6, 6, full, nil, back) -- the hole
		fill(5, 24, 16, 2) -- the ground
	elseif id == "Camera" then
		ring(1, 7, 24, 16, UDim.new(0, 3))
		fill(8, 3, 10, 5, UDim.new(0, 1))
		ring(8, 10, 10, 10, full)
	elseif id == "Settings" then
		for k, x in { 6, 15, 9 } do
			local y = 4 + (k - 1) * 8
			fill(1, y, 24, 2)
			fill(x - 1, y - 3, 8, 8, UDim.new(0, 1))
		end
	elseif id == "Plug" then
		ring(3, 9, 20, 15, UDim.new(0, 2))
		ring(8, 3, 10, 9, UDim.new(0, 4))
		fill(4, 10, 18, 4, nil, nil, back) -- hide the handle's lower half inside the bag
	elseif id == "Goals" then
		ring(1, 1, 24, 24, full)
		ring(7, 7, 12, 12, full)
		fill(11, 11, 4, 4, full)
	elseif id == "Garage" then
		fill(1, 12, 24, 8, UDim.new(0, 3)) -- body
		fill(6, 6, 14, 8, UDim.new(0, 4)) -- cabin
		fill(8, 8, 10, 4, UDim.new(0, 1), nil, back) -- window
		fill(3, 17, 8, 8, full, nil, back) -- wheel arches
		fill(15, 17, 8, 8, full, nil, back)
		fill(4, 18, 6, 6, full) -- wheels
		fill(16, 18, 6, 6, full)
	elseif id == "Story" then
		ring(3, 1, 20, 24, UDim.new(0, 3)) -- a book
		fill(3, 1, 5, 24, UDim.new(0, 2)) -- its spine
		fill(11, 7, 8, 2)
		fill(11, 11, 8, 2)
		fill(11, 15, 5, 2)
	elseif id == "Money" then
		ring(1, 6, 24, 15, UDim.new(0, 3)) -- a banknote
		ring(9, 9, 8, 9, full)
		fill(4, 12, 3, 3, full)
		fill(19, 12, 3, 3, full)
	else
		new("TextLabel", {
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			FontFace = Theme.Fonts.Display,
			Text = string.upper(string.sub(id, 1, 1)),
			TextColor3 = col,
			TextSize = 22,
			Parent = art,
		})
	end
	return art
end

-- Call screen button: a round button with a drawn handset and a label under it.
local function callButton(name: string, color: Color3, tilt: number, label: string, pos: UDim2, parent: Instance): TextButton
	local b = new("TextButton", {
		Name = name,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = pos,
		Size = UDim2.fromOffset(64, 64),
		BackgroundColor3 = color,
		AutoButtonColor = false,
		Text = "",
		Parent = parent,
	}, { corner(UDim.new(1, 0)) })
	handset(tilt, b)
	new("TextLabel", {
		Name = "Label",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 1, 6),
		Size = UDim2.fromOffset(100, 16),
		BackgroundTransparency = 1,
		FontFace = Theme.Fonts.Body,
		Text = label,
		TextColor3 = C.TextDim,
		TextSize = 13,
		Parent = b,
	})
	return b
end

-- One home-screen icon. Exposed so PhoneController can add icons for apps that aren't in the saved GUI yet.
function Build.appIcon(app: any, order: number): TextButton
	local icon = P.Icons[app.id] or "rbxassetid://0"
	local tile = new("TextButton", {
		Name = "App_" .. app.id,
		LayoutOrder = order,
		BackgroundTransparency = 1,
		Text = "",
		AutoButtonColor = false,
	})
	local square = new("ImageLabel", {
		Name = "Icon",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0),
		Size = UDim2.fromOffset(52, 52),
		BackgroundColor3 = P.AppColors[app.id] or P.TileColor,
		Image = if icon == "rbxassetid://0" then "" else icon, -- TODO(Alex art): app icon
		Parent = tile,
	}, { corner(P.IconCorner) })
	if P.IconGradient then
		-- top-lit like a real phone icon
		new("UIGradient", { Rotation = 90, Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(208, 208, 214)), Parent = square })
	else
		hairline().Parent = square
	end
	if icon == "rbxassetid://0" then
		Build.drawIcon(app.id, square, C.Text, square.BackgroundColor3)
	end
	new("TextLabel", {
		Name = "Label",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 57),
		Size = UDim2.new(1, 8, 0, 14),
		BackgroundTransparency = 1,
		FontFace = Theme.Fonts.Body,
		Text = app.title,
		TextColor3 = C.Text,
		TextSize = 11,
		Parent = tile,
	})
	return tile
end

function Build.build(): ScreenGui
	local size = PhoneConfig.Tuning.DesignSize
	local pad = P.BezelPadding

	local gui = new("ScreenGui", {
		Name = "MTL_Phone",
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		DisplayOrder = 10, -- above the HUD (5)
		ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets,
	})

	local phone = new("Frame", {
		Name = "Phone",
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -PhoneConfig.Tuning.Margin, 1, size.Y * 0.85),
		Size = UDim2.fromOffset(size.X, size.Y),
		Rotation = PhoneConfig.Tuning.TiltDegrees,
		BackgroundTransparency = 1,
		Parent = gui,
	}, { new("UIScale", { Scale = 1 }) })

	-- soft shadow under the phone
	new("Frame", {
		Name = "Shadow",
		Position = UDim2.fromOffset(0, 10),
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = C.Shadow,
		BackgroundTransparency = 0.55,
		ZIndex = 0,
		Parent = phone,
	}, { corner(P.FrameCorner) })

	-- the body: plain matte black with a thin dark edge (no metal gradient, no sheen)
	local body = new("ImageButton", {
		Name = "Body",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = P.Frame,
		AutoButtonColor = false,
		Image = "", -- TODO(Alex art): phone frame/case image
		Parent = phone,
	}, {
		corner(P.FrameCorner),
		new("UIStroke", { Name = "Edge", Color = P.Rim, Thickness = 2, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }),
	})

	-- side buttons (purely visual)
	new("Frame", { Name = "SideButton", Position = UDim2.new(1, 0, 0, 130), Size = UDim2.fromOffset(4, 60), BackgroundColor3 = P.Rim or P.FrameStroke, BorderSizePixel = 0, Parent = phone }, { corner(UDim.new(0, 2)) })
	new("Frame", { Name = "VolumeButton", Position = UDim2.new(0, -4, 0, 110), Size = UDim2.fromOffset(4, 40), BackgroundColor3 = P.Rim or P.FrameStroke, BorderSizePixel = 0, Parent = phone }, { corner(UDim.new(0, 2)) })
	new("Frame", { Name = "VolumeButton2", Position = UDim2.new(0, -4, 0, 160), Size = UDim2.fromOffset(4, 40), BackgroundColor3 = P.Rim or P.FrameStroke, BorderSizePixel = 0, Parent = phone }, { corner(UDim.new(0, 2)) })

	local screen = new("Frame", {
		Name = "Screen",
		Position = UDim2.fromOffset(pad, pad),
		Size = UDim2.new(1, -pad * 2, 1, -pad * 2),
		BackgroundColor3 = P.Screen,
		ClipsDescendants = true,
		Parent = body,
	}, { corner(P.ScreenCorner) })

	local wall = new("ImageLabel", {
		Name = "Wallpaper",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(1, 1, 1),
		Image = if P.Wallpaper == "rbxassetid://0" then "" else P.Wallpaper,
		ScaleType = Enum.ScaleType.Crop,
		Parent = screen,
	}, { corner(P.ScreenCorner) })
	if P.Wallpaper == "rbxassetid://0" then
		-- placeholder wallpaper until Alex's art: plain dark slate, a touch lighter at the top.
		-- Swap Theme.Phone.Wallpaper for an image any time.
		wall.BackgroundColor3 = Color3.new(1, 1, 1)
		new("UIGradient", { Rotation = 90, Color = ColorSequence.new(P.WallTop, P.WallBottom), Parent = wall })
	end
	if P.Wallpaper == "rbxassetid://0" and (P.WallWord or "") ~= "" then
		new("TextLabel", {
			Name = "Word",
			AnchorPoint = Vector2.new(0, 1),
			Position = UDim2.new(0, 14, 1, -6),
			Size = UDim2.new(1, -14, 0, 300),
			BackgroundTransparency = 1,
			FontFace = Theme.Fonts.Display,
			Text = P.WallWord or "VICE\nBAY",
			TextColor3 = C.Text,
			TextTransparency = 0.94,
			TextSize = 150,
			LineHeight = 0.82,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Bottom,
			Parent = wall,
		})
	end

	-- status bar: time · notch · signal/battery
	local status = new("Frame", {
		Name = "StatusBar",
		Size = UDim2.new(1, 0, 0, STATUS_H),
		BackgroundTransparency = 1,
		ZIndex = 20,
		Parent = screen,
	})
	new("TextLabel", {
		Name = "Time",
		Position = UDim2.fromOffset(20, 0),
		Size = UDim2.new(0.35, 0, 1, 0),
		BackgroundTransparency = 1,
		FontFace = Theme.Fonts.Bold,
		Text = "9:41 AM",
		TextColor3 = C.Text,
		TextSize = 13,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 20,
		Parent = status,
	})
	new("Frame", {
		Name = "Notch",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 7),
		Size = UDim2.fromOffset(84, 22),
		BackgroundColor3 = Color3.new(0, 0, 0),
		ZIndex = 21,
		Parent = status,
	}, { corner(UDim.new(1, 0)) })
	new("TextLabel", {
		Name = "Status",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -46, 0, 0),
		Size = UDim2.new(0, 24, 1, 0),
		BackgroundTransparency = 1,
		FontFace = Theme.Fonts.Bold,
		Text = "5G",
		TextColor3 = C.Text,
		TextSize = 11,
		TextXAlignment = Enum.TextXAlignment.Right,
		ZIndex = 20,
		Parent = status,
	})
	-- drawn signal bars + battery (right of "5G")
	local bars = new("Frame", { Name = "Signal", AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -74, 0.5, 1), Size = UDim2.fromOffset(16, 10), BackgroundTransparency = 1, ZIndex = 20, Parent = status })
	for k = 1, 4 do
		new("Frame", { Name = "Bar", AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, (k - 1) * 4, 1, 0), Size = UDim2.fromOffset(3, 2 + k * 2), BackgroundColor3 = C.Text, BorderSizePixel = 0, ZIndex = 20, Parent = bars }, { corner(UDim.new(0, 1)) })
	end
	local batt = new("Frame", { Name = "Battery", AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -18, 0.5, 1), Size = UDim2.fromOffset(22, 11), BackgroundTransparency = 1, ZIndex = 20, Parent = status }, {
		corner(UDim.new(0, 3)),
		new("UIStroke", { Color = C.Text, Transparency = 0.45, Thickness = 1 }),
	})
	new("Frame", { Name = "Level", Position = UDim2.fromOffset(2, 2), Size = UDim2.new(0.82, -4, 1, -4), BackgroundColor3 = C.Text, BorderSizePixel = 0, ZIndex = 20, Parent = batt }, { corner(UDim.new(0, 2)) })
	new("Frame", { Name = "Nub", AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(1, 1, 0.5, 0), Size = UDim2.fromOffset(2, 4), BackgroundColor3 = C.Text, BackgroundTransparency = 0.45, BorderSizePixel = 0, ZIndex = 20, Parent = batt })

	-- home screen
	local home = new("Frame", {
		Name = "Home",
		Position = UDim2.fromOffset(0, STATUS_H),
		Size = UDim2.new(1, 0, 1, -(STATUS_H + HOMEBAR_H)),
		BackgroundTransparency = 1,
		Parent = screen,
	})
	new("TextLabel", {
		Name = "Date",
		Position = UDim2.fromOffset(0, 12),
		Size = UDim2.new(1, 0, 0, 16),
		BackgroundTransparency = 1,
		FontFace = Theme.Fonts.Display,
		Text = "VICE BAY",
		TextColor3 = C.TextDim,
		TextSize = 14,
		Parent = home,
	})
	new("TextLabel", {
		Name = "Clock",
		Position = UDim2.fromOffset(0, 26),
		Size = UDim2.new(1, 0, 0, 76),
		BackgroundTransparency = 1,
		FontFace = Theme.Fonts.Display,
		Text = "9:41",
		TextColor3 = C.Text,
		TextSize = 66,
		Parent = home,
	})
	local grid = new("Frame", {
		Name = "Grid",
		Position = UDim2.fromOffset(12, 128),
		Size = UDim2.new(1, -24, 1, -128 - 92),
		BackgroundTransparency = 1,
		Parent = home,
	}, {
		new("UIGridLayout", {
			CellSize = UDim2.fromOffset(62, 78),
			CellPadding = UDim2.fromOffset(4, 10),
			HorizontalAlignment = Enum.HorizontalAlignment.Left,
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
		new("UIPadding", { PaddingLeft = UDim.new(0, 2) }),
	})
	-- dock: a flat dark strip along the bottom with the four everyday apps
	local dock = new("Frame", {
		Name = "Dock",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -6),
		Size = UDim2.new(1, -16, 0, 74),
		BackgroundColor3 = P.GlassTint,
		BackgroundTransparency = P.GlassAlpha,
		Parent = home,
	}, {
		corner(UDim.new(0, 22)),
		hairline(),
		new("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			Padding = UDim.new(0, 4),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	local inDock: { [string]: number } = {}
	for i, id in P.Dock or {} do
		inDock[id] = i
	end
	for i, app in PhoneConfig.Apps do
		local tile = Build.appIcon(app, i)
		if inDock[app.id] then
			tile.LayoutOrder = inDock[app.id]
			tile.Size = UDim2.fromOffset(62, 52)
			tile.Label.Visible = false -- real docks don't label
			tile.Parent = dock
		else
			tile.Parent = grid
		end
	end

	-- apps mount here (same area as Home)
	new("Frame", {
		Name = "AppHost",
		Position = UDim2.fromOffset(0, STATUS_H),
		Size = UDim2.new(1, 0, 1, -(STATUS_H + HOMEBAR_H)),
		BackgroundTransparency = 1, -- the Screen's own (rounded) background shows behind apps
		Visible = false,
		Parent = screen,
	})

	-- incoming / active call
	local call = new("Frame", {
		Name = "Call",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = P.Screen,
		BackgroundTransparency = 0, -- opaque: the home screen must not show through a call
		Visible = false,
		ZIndex = 10,
		Parent = screen,
	}, { corner(P.ScreenCorner) })
	new("TextLabel", {
		Name = "Avatar",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 70),
		Size = UDim2.fromOffset(86, 86),
		BackgroundColor3 = P.Card,
		FontFace = Theme.Fonts.Display,
		Text = "?",
		TextColor3 = C.Text,
		TextSize = 40,
		ZIndex = 11,
		Parent = call,
	}, { corner(UDim.new(1, 0)), hairline() })
	new("TextLabel", {
		Name = "Caller",
		Position = UDim2.fromOffset(0, 168),
		Size = UDim2.new(1, 0, 0, 30),
		BackgroundTransparency = 1,
		FontFace = Theme.Fonts.Display,
		Text = "Unknown",
		TextColor3 = C.Text,
		TextSize = 30,
		ZIndex = 11,
		Parent = call,
	})
	new("TextLabel", {
		Name = "Status",
		Position = UDim2.fromOffset(0, 200),
		Size = UDim2.new(1, 0, 0, 18),
		BackgroundTransparency = 1,
		FontFace = Theme.Fonts.Body,
		Text = "Incoming call...",
		TextColor3 = C.TextDim,
		TextSize = 14,
		ZIndex = 11,
		Parent = call,
	})
	local caption = new("TextButton", {
		Name = "Caption",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 236),
		Size = UDim2.new(1, -28, 0, 150),
		BackgroundColor3 = P.Card,
		BackgroundTransparency = 0,
		AutoButtonColor = false,
		Text = "",
		Visible = false,
		ZIndex = 11,
		Parent = call,
	}, { corner(P.Corner), hairline(), UIKit.padding(12, 12, 12) })

	new("TextLabel", {
		Name = "Who",
		Size = UDim2.new(1, 0, 0, 18),
		BackgroundTransparency = 1,
		FontFace = Theme.Fonts.Display,
		Text = "",
		TextColor3 = C.Accent,
		TextSize = 13,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 12,
		Parent = caption,
	})
	new("TextLabel", {
		Name = "Line",
		Position = UDim2.fromOffset(0, 22),
		Size = UDim2.new(1, 0, 1, -40),
		BackgroundTransparency = 1,
		FontFace = Theme.Fonts.Body,
		Text = "",
		TextColor3 = C.Text,
		TextSize = 16,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		ZIndex = 12,
		Parent = caption,
	})
	new("TextLabel", {
		Name = "Hint",
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.fromScale(1, 1),
		Size = UDim2.new(1, 0, 0, 14),
		BackgroundTransparency = 1,
		FontFace = Theme.Fonts.Body,
		Text = "tap to continue",
		TextColor3 = C.TextDim,
		TextSize = 11,
		TextXAlignment = Enum.TextXAlignment.Right,
		ZIndex = 12,
		Parent = caption,
	})
	new("Frame", {
		Name = "Choices",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 398),
		Size = UDim2.new(1, -28, 0, 100),
		BackgroundTransparency = 1,
		Visible = false,
		ZIndex = 11,
		Parent = call,
	}, { UIKit.list(8) })
	local inner = size.X - pad * 2
	callButton("Decline", P.Decline, 0, "Decline", UDim2.fromOffset(inner * 0.27, size.Y - pad * 2 - 90), call).ZIndex = 11
	callButton("Answer", P.Answer, -35, "Answer", UDim2.fromOffset(inner * 0.73, size.Y - pad * 2 - 90), call).ZIndex = 11
	local hang = callButton("HangUp", P.Decline, 0, "Hang up", UDim2.fromOffset(inner * 0.5, size.Y - pad * 2 - 90), call)
	hang.ZIndex = 11
	hang.Visible = false
	new("TextButton", {
		Name = "Skip",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -14, 0, STATUS_H + 6),
		Size = UDim2.fromOffset(60, 26),
		BackgroundColor3 = P.Card,
		AutoButtonColor = false,
		FontFace = Theme.Fonts.Bold,
		Text = "Skip",
		TextColor3 = C.Text,
		TextSize = 14,
		Visible = false,
		ZIndex = 12,
		Parent = call,
	}, { corner(P.Corner), hairline() })

	-- notification banner (slides down from above the screen)
	local banner = new("TextButton", {
		Name = "Banner",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, -80),
		Size = UDim2.new(1, -16, 0, 64),
		BackgroundColor3 = P.Card,
		BackgroundTransparency = 0,
		AutoButtonColor = false,
		Text = "",
		Visible = false,
		ZIndex = 30,
		Parent = screen,
	}, { corner(UDim.new(0, 18)), hairline() })
	new("TextLabel", {
		Name = "Icon",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 10, 0.5, 0),
		Size = UDim2.fromOffset(36, 36),
		BackgroundColor3 = P.TileColor,
		FontFace = Theme.Fonts.Display,
		Text = "",
		TextColor3 = C.Text,
		TextSize = 18,
		ZIndex = 31,
		Parent = banner,
	}, { corner(P.IconCorner), hairline() })
	new("TextLabel", {
		Name = "Title",
		Position = UDim2.fromOffset(56, 10),
		Size = UDim2.new(1, -66, 0, 18),
		BackgroundTransparency = 1,
		FontFace = Theme.Fonts.Display,
		Text = "",
		TextColor3 = C.Text,
		TextSize = 14,
		TextTruncate = Enum.TextTruncate.AtEnd,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 31,
		Parent = banner,
	})
	new("TextLabel", {
		Name = "Body", -- not "Text": Banner is a TextButton, so banner.Text would be its own Text property
		Position = UDim2.fromOffset(56, 30),
		Size = UDim2.new(1, -66, 0, 18),
		BackgroundTransparency = 1,
		FontFace = Theme.Fonts.Body,
		Text = "",
		TextColor3 = C.TextDim,
		TextSize = 13,
		TextTruncate = Enum.TextTruncate.AtEnd,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 31,
		Parent = banner,
	})

	-- home bar: tap = home, drag down = close
	local homeBar = new("TextButton", {
		Name = "HomeBar",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.fromScale(0.5, 1),
		Size = UDim2.new(1, 0, 0, HOMEBAR_H),
		BackgroundTransparency = 1,
		Text = "",
		ZIndex = 25,
		Parent = screen,
	})
	new("Frame", {
		Name = "Pill",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(104, 5),
		BackgroundColor3 = C.Text,
		BackgroundTransparency = 0.25,
		ZIndex = 25,
		Parent = homeBar,
	}, { corner(UDim.new(1, 0)) })

	-- red count on the closed phone (visible in the peek)
	new("TextLabel", {
		Name = "Badge",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromOffset(14, 14),
		Size = UDim2.fromOffset(24, 24),
		BackgroundColor3 = P.Badge,
		FontFace = Theme.Fonts.Display,
		Text = "1",
		TextColor3 = C.Text,
		TextSize = 13,
		Visible = false,
		ZIndex = 40,
		Parent = phone,
	}, { corner(UDim.new(1, 0)), UIKit.stroke(0, P.Frame) })

	return gui
end

return Build

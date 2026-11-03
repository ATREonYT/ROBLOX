--!strict
-- Builds the MTL_Gun ScreenGui (Piece 5): crosshair, hitmarker, ammo panel, weapon bar, touch buttons and the
-- hurt vignette. Used two ways, same as HUD/Phone/Job:
--   1. Edit time: tools/Install.lua saves it into StarterGui as real instances (Alex reskins it there)
--   2. Runtime fallback: GunController builds it only if PlayerGui has no MTL_Gun
-- GunController finds things BY NAME. Keep these names when reskinning:
--   Crosshair/{Top, Bottom, Left, Right, Dot}   Hint
--   Hitmarker/{A, B, C, D}
--   Ammo/{Gun, Mag, Reserve, Reload/Fill, Help}
--   WeaponBar/{SlotTemplate/{Key, Title, Count}}   (slots are clones named Slot_<GunId>)
--   Touch/{Fire, Aim, Reload}
--   Hurt/{Left, Right, Top, Bottom}
-- IgnoreGuiInset = true so the crosshair sits exactly on the camera's centre ray.
local Theme = require(script.Parent.Parent.Theme)

local C = Theme.Colors
local G = Theme.Gun

local function new(className: string, props: { [string]: any }, children: { Instance }?): any
	local inst = Instance.new(className)
	for k, v in props do
		if k ~= "Parent" then
			(inst :: any)[k] = v
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

local function corner(r: UDim?)
	return new("UICorner", { CornerRadius = r or Theme.Corner })
end

local function stroke(t: number?)
	return new("UIStroke", { Color = C.Stroke, Transparency = t or C.StrokeTransparency, Thickness = 1, ApplyStrokeMode = Enum.ApplyStrokeMode.Border })
end

local function bar(name: string, size: UDim2, parent: Instance, color: Color3?): Frame
	return new("Frame", {
		Name = name,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = size,
		BackgroundColor3 = color or G.Crosshair,
		BorderSizePixel = 0,
		Parent = parent,
	}, { new("UIStroke", { Color = G.CrosshairShadow, Transparency = 0.55, Thickness = 1 }) })
end

local function label(name: string, props: { [string]: any }): TextLabel
	local base = {
		Name = name,
		BackgroundTransparency = 1,
		FontFace = Theme.Fonts.Bold,
		TextColor3 = C.Text,
		TextSize = 14,
		Size = UDim2.new(1, 0, 0, 18),
	}
	for k, v in props do
		base[k] = v
	end
	return new("TextLabel", base)
end

local Build = {}

function Build.build(): ScreenGui
	local gui = new("ScreenGui", {
		Name = "MTL_Gun",
		ResetOnSpawn = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		DisplayOrder = 7, -- above HUD (5) and Job (6), below the phone (10)
		IgnoreGuiInset = true,
		Enabled = true,
	})

	-- crosshair: four bars that open with the current spread + a dot
	local cross = new("Frame", {
		Name = "Crosshair",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(0, 0),
		BackgroundTransparency = 1,
		Visible = false,
		Parent = gui,
	})
	bar("Top", UDim2.fromOffset(2, 9), cross)
	bar("Bottom", UDim2.fromOffset(2, 9), cross)
	bar("Left", UDim2.fromOffset(9, 2), cross)
	bar("Right", UDim2.fromOffset(9, 2), cross)
	local dot = bar("Dot", UDim2.fromOffset(3, 3), cross)
	dot.Position = UDim2.fromOffset(0, 0)
	label("Hint", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0.5, 34),
		Size = UDim2.fromOffset(260, 20),
		TextSize = 15,
		Text = "",
		TextStrokeTransparency = 0.5,
		Visible = false,
		Parent = gui,
	})

	-- hitmarker: an X of four short bars
	local hm = new("Frame", {
		Name = "Hitmarker",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(28, 28),
		BackgroundTransparency = 1,
		Visible = false,
		Parent = gui,
	})
	for i, name in { "A", "B", "C", "D" } do
		local b = bar(name, UDim2.fromOffset(2, 8), hm, G.Hit)
		local sx = if i == 1 or i == 4 then -1 else 1
		local sy = if i <= 2 then -1 else 1
		b.Position = UDim2.new(0.5, sx * 8, 0.5, sy * 8)
		b.Rotation = if sx * sy > 0 then -45 else 45
	end

	-- ammo panel (left of the phone; GunController moves it next to the phone at runtime)
	local ammo = new("Frame", {
		Name = "Ammo",
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -360, 1, -24),
		Size = UDim2.fromOffset(170, 70),
		BackgroundColor3 = G.Panel,
		BackgroundTransparency = C.GlassTransparency,
		Visible = false,
		Parent = gui,
	}, { corner(), stroke() })
	label("Gun", { Position = UDim2.fromOffset(12, 8), Size = UDim2.new(1, -24, 0, 14), TextSize = 12, TextColor3 = C.TextDim, TextXAlignment = Enum.TextXAlignment.Left, Text = "", Parent = ammo })
	label("Mag", {
		Position = UDim2.fromOffset(12, 22),
		Size = UDim2.fromOffset(70, 34),
		FontFace = Theme.Fonts.Mono,
		TextSize = 32,
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = "0",
		Parent = ammo,
	})
	label("Reserve", {
		Position = UDim2.fromOffset(84, 34),
		Size = UDim2.fromOffset(74, 20),
		FontFace = Theme.Fonts.Mono,
		TextSize = 16,
		TextColor3 = C.TextDim,
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = "/ 0",
		Parent = ammo,
	})
	local reload = new("Frame", {
		Name = "Reload",
		Position = UDim2.new(0, 12, 1, -9),
		Size = UDim2.new(1, -24, 0, 3),
		BackgroundColor3 = C.Stroke,
		BackgroundTransparency = 0.85,
		BorderSizePixel = 0,
		Visible = false,
		Parent = ammo,
	}, { corner(UDim.new(1, 0)) })
	new("Frame", { Name = "Fill", Size = UDim2.fromScale(0, 1), BackgroundColor3 = C.Accent, BorderSizePixel = 0, Parent = reload }, { corner(UDim.new(1, 0)) })
	label("Help", {
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 0, 0, -6),
		Size = UDim2.new(1, 0, 0, 14),
		TextSize = 12,
		TextColor3 = C.TextDim,
		TextXAlignment = Enum.TextXAlignment.Left,
		FontFace = Theme.Fonts.Body,
		TextStrokeTransparency = 0.7,
		Text = "",
		Parent = ammo,
	})

	-- weapon bar: bottom centre, one slot per gun you own
	local wb = new("Frame", {
		Name = "WeaponBar",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -18),
		Size = UDim2.fromOffset(600, 46),
		BackgroundTransparency = 1,
		Visible = false,
		Parent = gui,
	}, {
		new("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			VerticalAlignment = Enum.VerticalAlignment.Bottom,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 6),
		}),
	})
	local slot = new("TextButton", {
		Name = "SlotTemplate",
		Size = UDim2.fromOffset(104, 42),
		BackgroundColor3 = G.Panel,
		BackgroundTransparency = C.GlassTransparency,
		AutoButtonColor = false,
		Text = "",
		Visible = false,
		Parent = wb,
	}, { corner(Theme.CornerSmall), new("UIStroke", { Name = "Stroke", Color = C.Stroke, Transparency = C.StrokeTransparency, Thickness = 1, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }) })
	label("Key", { Position = UDim2.fromOffset(6, 4), Size = UDim2.fromOffset(14, 14), TextSize = 11, TextColor3 = C.TextDim, Text = "1", Parent = slot })
	label("Title", { Position = UDim2.fromOffset(22, 4), Size = UDim2.new(1, -28, 0, 16), TextSize = 13, TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, Text = "Gun", Parent = slot })
	label("Count", { Position = UDim2.fromOffset(22, 22), Size = UDim2.new(1, -28, 0, 14), TextSize = 11, FontFace = Theme.Fonts.Mono, TextColor3 = C.TextDim, TextXAlignment = Enum.TextXAlignment.Left, Text = "", Parent = slot })

	-- touch buttons: above the jump button, right thumb
	local touch = new("Frame", {
		Name = "Touch",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Visible = false,
		Parent = gui,
	})
	local function round(name: string, text: string, size: number, pos: UDim2): TextButton
		return new("TextButton", {
			Name = name,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = pos,
			Size = UDim2.fromOffset(size, size),
			BackgroundColor3 = G.Panel,
			BackgroundTransparency = 0.35,
			AutoButtonColor = false,
			FontFace = Theme.Fonts.Display,
			Text = text,
			TextColor3 = C.Text,
			TextSize = math.floor(size * 0.24),
			Parent = touch,
		}, { corner(UDim.new(1, 0)), new("UIStroke", { Color = C.Stroke, Transparency = 0.6, Thickness = 2, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }) })
	end
	round("Fire", "FIRE", 86, UDim2.new(1, -70, 1, -215))
	round("Aim", "AIM", 64, UDim2.new(1, -160, 1, -185))
	round("Reload", "R", 48, UDim2.new(1, -60, 1, -300))

	-- hurt vignette: four soft edges, the one facing the shooter flashes
	local hurt = new("Frame", { Name = "Hurt", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Parent = gui })
	local function edge(name: string, size: UDim2, pos: UDim2, anchor: Vector2, rotation: number)
		new("Frame", {
			Name = name,
			AnchorPoint = anchor,
			Position = pos,
			Size = size,
			BackgroundColor3 = G.Hurt,
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Parent = hurt,
		}, {
			new("UIGradient", {
				Rotation = rotation,
				Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.1), NumberSequenceKeypoint.new(1, 1) }),
			}),
		})
	end
	edge("Left", UDim2.fromScale(0.22, 1), UDim2.fromScale(0, 0), Vector2.new(0, 0), 0)
	edge("Right", UDim2.fromScale(0.22, 1), UDim2.fromScale(1, 0), Vector2.new(1, 0), 180)
	edge("Top", UDim2.fromScale(1, 0.25), UDim2.fromScale(0, 0), Vector2.new(0, 0), 90)
	edge("Bottom", UDim2.fromScale(1, 0.25), UDim2.fromScale(0, 1), Vector2.new(0, 1), 270)

	return gui
end

return Build

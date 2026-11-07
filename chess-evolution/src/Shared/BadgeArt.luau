--!strict
-- +1 Chess Evolution: original badge icons, drawn from plain Frames (no uploaded images).
-- One round disc per rating: saturated colour, dark outline, a soft top highlight and a white
-- symbol. Every size is in Scale, so the same art works in the HUD, above the pieces and in the
-- Studio preview. Shapes come from Config.BadgeLook[key].shape:
--   book (Book), arrow (Forced), check (Good), check2 (Excellent), star (Best),
--   target (Miss), circle + glyph (Great !, Brilliant !!, Inaccuracy ?!, Mistake ?, Blunder ??).
--   BadgeArt.Paint(disc, key, look)    -- disc: a square Frame; rebuilds its "Art" child

local BadgeArt = {}

local INK = Color3.fromRGB(28, 26, 40)
local WHITE = Color3.new(1, 1, 1)
local FONT = Font.fromEnum(Enum.Font.FredokaOne)

local function new(className: string, props: { [string]: any }, parent: Instance?): any
	local inst = Instance.new(className)
	for k, v in props do
		(inst :: any)[k] = v
	end
	if parent then
		inst.Parent = parent
	end
	return inst
end

-- A white bar centred at (cx, cy), length len, thickness th (all Scale of the disc), rotated rot degrees.
-- Bars get an ink outline so the symbol reads on light colours too.
local function bar(art: Frame, cx: number, cy: number, len: number, th: number, rot: number, z: number, color: Color3?)
	local b = new("Frame", {
		Name = "Bar",
		BackgroundColor3 = color or WHITE,
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(cx, cy),
		Size = UDim2.fromScale(len, th),
		Rotation = rot,
		ZIndex = z,
	}, art)
	new("UICorner", { CornerRadius = UDim.new(0.5, 0) }, b)
	return b
end

local function check(art: Frame, ox: number, oy: number, s: number, z: number)
	-- short arm down-right, long arm up-right; they meet at the bottom of the tick
	bar(art, ox + (-0.15) * s, oy + 0.09 * s, 0.30 * s, 0.14 * s, 45, z)
	bar(art, ox + 0.08 * s, oy - 0.01 * s, 0.52 * s, 0.14 * s, -50, z)
end

local function glyph(art: Frame, textValue: string, z: number)
	local t = new("TextLabel", {
		Name = "Glyph",
		BackgroundTransparency = 1,
		FontFace = FONT,
		Text = textValue,
		TextColor3 = WHITE,
		TextScaled = true,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.53),
		Size = UDim2.fromScale(if #textValue > 1 then 0.78 else 0.6, 0.66),
		ZIndex = z,
	}, art)
	new("UIStroke", { Thickness = 2, Color = INK, Name = "Outline" }, t)
	return t
end

local SHAPES: { [string]: (Frame, any, number) -> () } = {
	book = function(art, look, z)
		-- an open book: two pages leaning out from a spine
		local page = Color3.fromRGB(255, 248, 232)
		local l = bar(art, 0.355, 0.52, 0.27, 0.44, -8, z, page)
		local r = bar(art, 0.645, 0.52, 0.27, 0.44, 8, z, page)
		for _, p in { l, r } do
			(p:FindFirstChildOfClass("UICorner") :: UICorner).CornerRadius = UDim.new(0.12, 0)
		end
		-- page lines in the badge colour
		for i = 0, 2 do
			bar(art, 0.36, 0.42 + i * 0.09, 0.15, 0.035, -8, z + 1, look.color:Lerp(INK, 0.35))
			bar(art, 0.64, 0.42 + i * 0.09, 0.15, 0.035, 8, z + 1, look.color:Lerp(INK, 0.35))
		end
		bar(art, 0.5, 0.53, 0.05, 0.46, 0, z + 1, look.color:Lerp(INK, 0.5))
	end,
	arrow = function(art, _look, z)
		-- a forward arrow: shaft and a two-bar head meeting at the tip
		bar(art, 0.43, 0.5, 0.42, 0.14, 0, z)
		bar(art, 0.585, 0.405, 0.30, 0.14, 45, z)
		bar(art, 0.585, 0.595, 0.30, 0.14, -45, z)
	end,
	check = function(art, _look, z)
		check(art, 0.5, 0.52, 1, z)
	end,
	check2 = function(art, _look, z)
		check(art, 0.38, 0.54, 0.74, z)
		check(art, 0.62, 0.48, 0.74, z)
	end,
	star = function(art, _look, z)
		-- an eight-point burst: two squares, one turned, with a coloured heart
		local a = bar(art, 0.5, 0.5, 0.46, 0.46, 0, z)
		local b = bar(art, 0.5, 0.5, 0.46, 0.46, 45, z)
		for _, p in { a, b } do
			(p:FindFirstChildOfClass("UICorner") :: UICorner).CornerRadius = UDim.new(0.08, 0)
		end
		local heart = bar(art, 0.5, 0.5, 0.16, 0.16, 0, z + 1, Color3.fromRGB(255, 236, 120))
		local _ = heart
	end,
	target = function(art, look, z)
		-- a target: white ring, coloured gap, white bullseye, a small slash for "missed"
		local ring = new("Frame", {
			Name = "Ring",
			BackgroundTransparency = 1,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(0.6, 0.6),
			ZIndex = z,
		}, art)
		new("UICorner", { CornerRadius = UDim.new(0.5, 0) }, ring)
		new("UIStroke", { Thickness = 5, Color = WHITE }, ring)
		local dot = bar(art, 0.5, 0.5, 0.2, 0.2, 0, z)
		local _ = dot
		bar(art, 0.7, 0.3, 0.3, 0.08, -45, z + 1, look.color:Lerp(INK, 0.45))
	end,
}

-- Paints disc (a square Frame) as the badge for key. Safe to call again with another key.
function BadgeArt.Paint(disc: Frame, key: string, look: any)
	disc.BackgroundColor3 = look.color
	disc.BackgroundTransparency = 0
	if not disc:FindFirstChildOfClass("UICorner") then
		new("UICorner", { CornerRadius = UDim.new(0.5, 0) }, disc)
	end
	if not disc:FindFirstChildOfClass("UIStroke") then
		new("UIStroke", { Thickness = 4, Color = INK }, disc)
	end
	-- the old text glyph (HudBuilder) is replaced by the drawn art
	local old = disc:FindFirstChild("Glyph")
	if old and old:IsA("TextLabel") then
		old.Visible = false
	end
	local prev = disc:FindFirstChild("Art")
	if prev then
		prev:Destroy()
	end
	local z = disc.ZIndex + 1
	local art = new("Frame", { Name = "Art", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = z }, disc)
	art:SetAttribute("Badge", key)
	-- soft top highlight and a darker lower rim
	local shine = new("Frame", {
		Name = "Shine",
		BackgroundColor3 = WHITE,
		BackgroundTransparency = 0.72,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0.07),
		Size = UDim2.fromScale(0.7, 0.34),
		ZIndex = z,
	}, art)
	new("UICorner", { CornerRadius = UDim.new(0.5, 0) }, shine)
	local ring = new("Frame", {
		Name = "Rim",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(1, -8, 1, -8),
		ZIndex = z,
	}, art)
	new("UICorner", { CornerRadius = UDim.new(0.5, 0) }, ring)
	new("UIStroke", { Thickness = 2, Color = WHITE, Transparency = 0.55 }, ring)
	local draw = SHAPES[look.shape]
	if draw then
		draw(art, look, z + 1)
	else
		glyph(art, look.glyph, z + 1)
	end
	return art
end

-- Every badge key in display order (for the preview and the tests).
BadgeArt.Order = { "Brilliant", "Great", "Best", "Excellent", "Good", "Book", "Forced", "Inaccuracy", "Mistake", "Miss", "Blunder" }

-- Which ratings the live game can show today (the rest are preview-only until an encounter uses them).
BadgeArt.Live = {
	Brilliant = "win after a deep dip (25 or lower)",
	Great = "retake a 60+ lead after a 35-or-lower deficit",
	Best = "strongest routine push",
	Excellent = "strong routine push",
	Good = "steady opening push",
	Book = "first fight's scripted opening",
	Inaccuracy = "meter 40 or lower for 0.7 s",
	Mistake = "meter 25 or lower for 0.7 s",
	Miss = "recover 15, then drop 12 before leading",
	Blunder = "meter 10 or lower for 0.7 s, or defeat",
}

return BadgeArt

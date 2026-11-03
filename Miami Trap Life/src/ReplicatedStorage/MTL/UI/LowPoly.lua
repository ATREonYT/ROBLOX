--!strict
-- The shared low-poly UI look (tokens in Theme.LowPoly). Flat colour bands at an angle instead of smooth
-- gradients, a bold dark outline, small hard corners. Works on any GuiObject with a background.
--   LowPoly.style(frame, color, { outline = 3?, corner = UDim?, rim = true? })   -- all of the below in one go
--   LowPoly.facets(color) -> UIGradient   (set the frame's BackgroundColor3 to white; the gradient carries the colour)
--   LowPoly.outline(thickness?, color?) -> UIStroke
local Theme = require(script.Parent.Theme)

local L = (Theme :: any).LowPoly

local LowPoly = {}

local WHITE = Color3.new(1, 1, 1)
local BLACK = Color3.new(0, 0, 0)

-- three flat bands: light / base / dark, hard edges between them
function LowPoly.facets(color: Color3, angle: number?): UIGradient
	local a, b = L.FacetSplits[1], L.FacetSplits[2]
	local light = color:Lerp(WHITE, L.FacetLight)
	local dark = color:Lerp(BLACK, L.FacetDark)
	local g = Instance.new("UIGradient")
	g.Name = "Facets"
	g.Rotation = angle or L.FacetAngle
	g.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, light),
		ColorSequenceKeypoint.new(a, light),
		ColorSequenceKeypoint.new(a + 0.001, color),
		ColorSequenceKeypoint.new(b, color),
		ColorSequenceKeypoint.new(b + 0.001, dark),
		ColorSequenceKeypoint.new(1, dark),
	})
	return g
end

function LowPoly.outline(thickness: number?, color: Color3?): UIStroke
	local s = Instance.new("UIStroke")
	s.Name = "Stroke"
	s.Color = color or L.Outline
	s.Thickness = thickness or L.OutlineThickness
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.LineJoinMode = Enum.LineJoinMode.Miter -- square joins read as cut edges
	return s
end

-- thin light line along the top edge (the "lit" bevel)
function LowPoly.rim(parent: GuiObject)
	local r = Instance.new("Frame")
	r.Name = "Rim"
	r.AnchorPoint = Vector2.new(0.5, 0)
	r.Position = UDim2.new(0.5, 0, 0, 2)
	r.Size = UDim2.new(1, -10, 0, 2)
	r.BorderSizePixel = 0
	r.BackgroundColor3 = L.Rim
	r.BackgroundTransparency = L.RimTransparency
	r.ZIndex = parent.ZIndex
	r.Parent = parent
end

function LowPoly.style(frame: GuiObject, color: Color3, opts: { outline: number?, corner: UDim?, rim: boolean?, angle: number? }?)
	local o = opts or {}
	-- a UIGradient tints a button's own text too, so move the text into a child label first
	if (frame:IsA("TextButton") or frame:IsA("TextLabel")) and (frame :: any).Text ~= "" then
		local src = frame :: any
		local label = Instance.new("TextLabel")
		label.Name = "Text"
		label.Size = UDim2.fromScale(1, 1)
		label.BackgroundTransparency = 1
		label.FontFace = src.FontFace
		label.Text = src.Text
		label.TextColor3 = src.TextColor3
		label.TextSize = src.TextSize
		label.TextScaled = src.TextScaled
		label.ZIndex = src.ZIndex + 1
		for _, c in frame:GetChildren() do
			if c:IsA("UIStroke") and c.ApplyStrokeMode == Enum.ApplyStrokeMode.Contextual then
				c.Parent = label -- the text outline goes with the text
			end
		end
		src.Text = ""
		label.Parent = frame
	end
	for _, c in frame:GetChildren() do
		if c:IsA("UIGradient") or c:IsA("UIStroke") or c:IsA("UICorner") then
			c:Destroy()
		end
	end
	frame.BackgroundColor3 = WHITE
	LowPoly.facets(color, o.angle).Parent = frame
	if (o.outline or 1) > 0 then
		LowPoly.outline(o.outline).Parent = frame
	end
	local corner = Instance.new("UICorner")
	corner.CornerRadius = o.corner or L.Corner
	corner.Parent = frame
	if o.rim ~= false then
		LowPoly.rim(frame)
	end
end

return LowPoly

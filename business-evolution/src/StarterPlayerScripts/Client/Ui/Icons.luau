--!strict
-- Icons drawn from primitives (Frames + UICorner + rotation).
--
-- Why not emoji: they render differently on every platform — Windows, Android
-- and iOS all ship different glyph sets, several are colour-fixed so they
-- ignore your palette, and a few fall back to tofu boxes. They read as
-- placeholder. Why not image assets: uploading them needs a Roblox account,
-- so this project cannot produce asset ids; drawn icons need no upload, scale
-- cleanly and take the palette colour you hand them.
--
-- Every icon draws inside a square parent and fills it.

local Icons = {}

local function box(parent: Instance, position: UDim2, size: UDim2, color: Color3, rotation: number?, radius: number?): Frame
	local frame = Instance.new("Frame")
	frame.AnchorPoint = Vector2.new(0.5, 0.5)
	frame.Position = position
	frame.Size = size
	frame.BackgroundColor3 = color
	frame.BorderSizePixel = 0
	frame.Rotation = rotation or 0
	frame.Parent = parent
	if radius and radius > 0 then
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(radius, 0)
		corner.Parent = frame
	end
	return frame
end

-- ── The set ────────────────────────────────────────────────────────────────

local drawers: { [string]: (Frame, Color3, Color3) -> () } = {}

-- Briefcase: body, lid band, handle. Reads as "shop / gear".
drawers.Briefcase = function(root, main, accent)
	box(root, UDim2.fromScale(0.5, 0.58), UDim2.fromScale(0.78, 0.52), main, 0, 0.12)
	box(root, UDim2.fromScale(0.5, 0.5), UDim2.fromScale(0.8, 0.08), accent)
	box(root, UDim2.fromScale(0.5, 0.26), UDim2.fromScale(0.3, 0.1), main, 0, 0.4)
	box(root, UDim2.fromScale(0.5, 0.3), UDim2.fromScale(0.18, 0.06), accent, 0, 0.4)
end

-- Coffee cup: tapered body, handle, saucer. Reads as "interns / hire".
drawers.Coffee = function(root, main, accent)
	box(root, UDim2.fromScale(0.46, 0.5), UDim2.fromScale(0.5, 0.5), main, 0, 0.14)
	box(root, UDim2.fromScale(0.78, 0.48), UDim2.fromScale(0.2, 0.26), accent, 0, 0.5)
	box(root, UDim2.fromScale(0.78, 0.48), UDim2.fromScale(0.1, 0.14), Color3.new(0, 0, 0), 0, 0.5).BackgroundTransparency = 1
	box(root, UDim2.fromScale(0.46, 0.78), UDim2.fromScale(0.72, 0.1), accent, 0, 0.4)
	-- Steam.
	box(root, UDim2.fromScale(0.38, 0.2), UDim2.fromScale(0.06, 0.18), accent, -12, 0.5)
	box(root, UDim2.fromScale(0.54, 0.18), UDim2.fromScale(0.06, 0.22), accent, 10, 0.5)
end

-- Descending chart: three bars stepping down. Reads as "restructure / reset".
drawers.Chart = function(root, main, accent)
	box(root, UDim2.fromScale(0.24, 0.62), UDim2.fromScale(0.16, 0.46), main, 0, 0.2)
	box(root, UDim2.fromScale(0.5, 0.68), UDim2.fromScale(0.16, 0.34), main, 0, 0.2)
	box(root, UDim2.fromScale(0.76, 0.74), UDim2.fromScale(0.16, 0.22), main, 0, 0.2)
	-- The arrow across them, falling left to right.
	box(root, UDim2.fromScale(0.5, 0.34), UDim2.fromScale(0.86, 0.08), accent, 20, 0.5)
end

-- Lightning bolt: two offset parallelograms. Reads as "power".
drawers.Bolt = function(root, main, accent)
	box(root, UDim2.fromScale(0.56, 0.32), UDim2.fromScale(0.22, 0.42), main, 22, 0.1)
	box(root, UDim2.fromScale(0.44, 0.68), UDim2.fromScale(0.22, 0.42), main, 22, 0.1)
	box(root, UDim2.fromScale(0.5, 0.5), UDim2.fromScale(0.36, 0.1), accent, 20, 0.3)
end

-- Trophy: cup, stem, base, handles. Reads as "wins".
drawers.Trophy = function(root, main, accent)
	box(root, UDim2.fromScale(0.5, 0.36), UDim2.fromScale(0.46, 0.42), main, 0, 0.18)
	box(root, UDim2.fromScale(0.22, 0.34), UDim2.fromScale(0.14, 0.24), accent, 0, 0.5)
	box(root, UDim2.fromScale(0.78, 0.34), UDim2.fromScale(0.14, 0.24), accent, 0, 0.5)
	box(root, UDim2.fromScale(0.5, 0.66), UDim2.fromScale(0.12, 0.2), main)
	box(root, UDim2.fromScale(0.5, 0.8), UDim2.fromScale(0.44, 0.12), accent, 0, 0.25)
end

-- Two figures: head + shoulders, twice. Reads as "interns / pets owned".
drawers.People = function(root, main, accent)
	box(root, UDim2.fromScale(0.36, 0.34), UDim2.fromScale(0.26, 0.26), main, 0, 0.5)
	box(root, UDim2.fromScale(0.36, 0.68), UDim2.fromScale(0.42, 0.3), main, 0, 0.3)
	box(root, UDim2.fromScale(0.68, 0.38), UDim2.fromScale(0.22, 0.22), accent, 0, 0.5)
	box(root, UDim2.fromScale(0.68, 0.7), UDim2.fromScale(0.34, 0.26), accent, 0, 0.3)
end

-- Build `name` into a square container parented to `parent`.
function Icons.create(parent: Instance, name: string, main: Color3, accent: Color3?): Frame
	local root = Instance.new("Frame")
	root.Name = "Icon" .. name
	root.BackgroundTransparency = 1
	root.Size = UDim2.fromScale(1, 1)
	root.Parent = parent

	local ratio = Instance.new("UIAspectRatioConstraint")
	ratio.AspectRatio = 1
	ratio.Parent = root

	local draw = drawers[name]
	if draw then
		draw(root, main, accent or main)
	end
	return root
end

Icons.Names = { "Briefcase", "Coffee", "Chart", "Bolt", "Trophy", "People" }

return Icons

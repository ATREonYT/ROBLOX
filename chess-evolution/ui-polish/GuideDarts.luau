--!strict
-- +1 Chess Evolution: tutorial arrow line, ported from Cannon Evolution's Tutorial.lua (l.328-470,
-- matched to Alex's Stone Skipping recording; build guide §5). A chain of white darts with a notch
-- at the back and a dark copy behind each one as its outline, floating on one straight line from you
-- to the target, flat to the screen like a sticker, flowing forward. Darts grow in near you and
-- shrink into the target. Hidden when the target is closer than 7 studs.
-- local darts = GuideDarts.new(folder)  ->  darts:Draw(fromPosition, targetPosition) each frame, darts:Hide()
local GuideDarts = {}
GuideDarts.__index = GuideDarts

local ARROWS, SPACING, FLOW_SPEED = 30, 1.05, 2.5 -- SPACING in dart lengths on screen; FLOW_SPEED darts a second
local LEN, HALF, NOTCH, THICK = 1.6, 0.95, 0.5, 0.12 -- dart length, half width, notch depth, thickness
local RIM = 1.3 -- the dark copy behind each dart is this much bigger: its outline
local HIDDEN = CFrame.new(0, -500, 0)
local WHITE = Color3.fromRGB(246, 246, 252)
local DARK = Color3.fromRGB(30, 30, 55)

export type Darts = typeof(setmetatable({} :: { arrows: { { WedgePart } }, folder: Model, shown: boolean }, GuideDarts))

function GuideDarts.new(parent: Instance): Darts
	local folder = Instance.new("Model")
	folder.Name = "TutorialDarts"
	local arrows = {}
	for i = 1, ARROWS do
		local wedges = {}
		for w = 1, 8 do
			local p = Instance.new("WedgePart")
			p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = true, false, false, false, false
			p.Material = Enum.Material.SmoothPlastic
			p.Color = if w <= 4 then WHITE else DARK
			p.CFrame = HIDDEN
			p.Parent = folder
			wedges[w] = p
		end
		arrows[i] = wedges
	end
	folder.Parent = parent
	return setmetatable({ arrows = arrows, folder = folder, shown = true }, GuideDarts)
end

-- a flat triangle a, b, c from two wedges, THICK deep
local function triangle(a: Vector3, b: Vector3, c: Vector3, w1: WedgePart, w2: WedgePart)
	local ab, ac, bc = b - a, c - a, c - b
	local abd, acd, bcd = ab:Dot(ab), ac:Dot(ac), bc:Dot(bc)
	if abd > acd and abd > bcd then
		c, a = a, c
	elseif acd > bcd and acd > abd then
		a, b = b, a
	end
	ab, ac, bc = b - a, c - a, c - b
	local right = ac:Cross(ab).Unit
	local up = bc:Cross(right).Unit
	local back = bc.Unit
	local height = math.abs(ab:Dot(up))
	w1.Size = Vector3.new(THICK, height, math.abs(ab:Dot(back)))
	w1.CFrame = CFrame.fromMatrix((a + b) / 2, right, up, back)
	w2.Size = Vector3.new(THICK, height, math.abs(ac:Dot(back)))
	w2.CFrame = CFrame.fromMatrix((a + c) / 2, -right, up, -back)
end

function GuideDarts.Hide(self: Darts)
	if not self.shown then
		return
	end
	self.shown = false
	for _, wedges in self.arrows do
		for _, part in wedges do
			part.CFrame = HIDDEN
		end
	end
end

-- one straight line through the air from you to the target: it never bends and never follows the ground
function GuideDarts.Draw(self: Darts, from: Vector3, target: Vector3)
	local line = target - from
	local total = line.Magnitude
	if total < 7 then
		self:Hide()
		return
	end
	self.shown = true
	local lineDir = line.Unit
	local cam = workspace.CurrentCamera
	local camCF = cam.CFrame
	local camPos = camCF.Position
	local focal = cam.ViewportSize.Y / (2 * math.tan(math.rad(cam.FieldOfView) / 2))
	-- drop a dart each time the line has covered one dart length on screen, so the chain reads
	-- tip to notch at every distance and never piles up when it runs away from you
	local phase = (os.clock() * FLOW_SPEED) % 1
	local placed, nextMark, progress = 0, phase, 0
	local d, prevScreen = 2.5, nil :: Vector2?
	while d < total - 2 and placed < ARROWS do
		local pos = from + lineDir * d
		local depth = (pos - camPos):Dot(camCF.LookVector)
		local screen: Vector2? = nil
		if depth > 0.5 then
			local v = cam:WorldToViewportPoint(pos)
			screen = Vector2.new(v.X, v.Y)
		end
		if screen and prevScreen then
			local gapPx = SPACING * LEN * focal / depth
			progress += (screen - prevScreen).Magnitude / gapPx
		end
		prevScreen = screen
		if screen and progress >= nextMark and (pos - camPos).Magnitude > 6 then
			nextMark += 1
			placed += 1
			local wedges = self.arrows[placed]
			local normal = (camPos - pos).Unit
			-- flat to the screen like a sticker, pointing the way the line runs on screen
			local flat = lineDir - normal * lineDir:Dot(normal)
			if flat.Magnitude < 0.05 then
				flat = Vector3.yAxis - normal * normal.Y
			end
			local dir = flat.Unit
			local side = dir:Cross(normal)
			-- grow in near you and shrink into the target
			local k = 0.35 + 0.65 * math.clamp(math.min((d - 2.5) / 3, (total - 2 - d) / 3), 0, 1)
			for layer = 0, 1 do
				local r = if layer == 0 then k else k * RIM
				local c = pos - normal * (layer * THICK * 1.5) -- the dark copy sits just behind
				local tip = c + dir * (LEN / 2 * r)
				local tail = c - dir * (LEN / 2 * r)
				local notch = tail + dir * (NOTCH * r)
				local w = layer * 4
				triangle(tip, tail + side * (HALF * r), notch, wedges[w + 1], wedges[w + 2])
				triangle(tip, notch, tail - side * (HALF * r), wedges[w + 3], wedges[w + 4])
			end
		end
		d += 0.15
	end
	for i = placed + 1, ARROWS do
		for _, part in self.arrows[i] do
			part.CFrame = HIDDEN
		end
	end
end

return GuideDarts

--!strict
-- +1 Chess Evolution: tap pop-ups in the world (build guide §2, Nov 8; ported from Cannon
-- Effects.floatingText). One "+N" per accepted tap or treadmill tick, never merged, at a random spot
-- around the avatar: above the head, beside the body or at the feet.
-- Pooled BillboardGuis (16) on invisible anchors under the camera, so a tap creates nothing.
--   Look: Elo icon at text height on the left, "+N" in FredokaOne about 40 px, white, 3 px dark stroke.
--   Motion: UIScale 1.5 -> 1 over 0.18 s (Back out); rise 1.5 studs over 0.7 s (Quad out);
--   from 0.35 s the scale eases to 0.6 while text, icon and stroke fade out over 0.35 s.
--   Reduced Motion: no scale pop and only a small rise.
-- Usage: local pops = TapPops.new({ icon = "rbxassetid://...", reduced = function() return false end })
--        pops:Pop(humanoidRootPart, "+5")
local RunService = game:GetService("RunService")

local TapPops = {}
TapPops.__index = TapPops

local FONT = Font.new("rbxasset://fonts/families/FredokaOne.json", Enum.FontWeight.Regular)
local INK = Color3.fromRGB(22, 22, 28)
local POOL = 16
local LIVE_CAP = 12
local POP_T, RISE_T, FADE_AT, FADE_T = 0.18, 0.7, 0.35, 0.35
local RISE = 1.5

local function backOut(t: number): number
	local c1 = 1.70158
	local c3 = c1 + 1
	return 1 + c3 * (t - 1) ^ 3 + c1 * (t - 1) ^ 2
end

export type Pop = {
	anchor: Part,
	bb: BillboardGui,
	icon: ImageLabel,
	text: TextLabel,
	stroke: UIStroke,
	scale: UIScale,
	t0: number,
	drift: number,
}

function TapPops.new(opts: { icon: string?, reduced: (() -> boolean)? })
	local self: any = setmetatable({}, TapPops)
	self.reduced = opts.reduced or function()
		return false
	end
	self.free = {} :: { Pop }
	self.live = {} :: { Pop }
	local folder = Instance.new("Folder")
	folder.Name = "TapPops"
	folder.Parent = workspace.CurrentCamera or workspace
	for _ = 1, POOL do
		local anchor = Instance.new("Part")
		anchor.Name = "PopAnchor"
		anchor.Anchored, anchor.CanCollide, anchor.CanQuery, anchor.CanTouch = true, false, false, false
		anchor.CastShadow = false
		anchor.Transparency = 1
		anchor.Size = Vector3.one * 0.2
		anchor.Parent = folder
		local bb = Instance.new("BillboardGui")
		bb.Name = "Pop"
		bb.Size = UDim2.fromOffset(200, 60)
		bb.AlwaysOnTop = true
		bb.LightInfluence = 0
		bb.MaxDistance = 120
		bb.Enabled = false
		bb.Adornee = anchor
		bb.Parent = anchor
		local row = Instance.new("Frame")
		row.Name = "Row"
		row.BackgroundTransparency = 1
		row.Size = UDim2.fromScale(1, 1)
		row.Parent = bb
		local list = Instance.new("UIListLayout")
		list.FillDirection = Enum.FillDirection.Horizontal
		list.HorizontalAlignment = Enum.HorizontalAlignment.Center
		list.VerticalAlignment = Enum.VerticalAlignment.Center
		list.Padding = UDim.new(0, 4)
		list.SortOrder = Enum.SortOrder.LayoutOrder
		list.Parent = row
		local icon = Instance.new("ImageLabel")
		icon.Name = "Icon"
		icon.LayoutOrder = 1
		icon.BackgroundTransparency = 1
		icon.Size = UDim2.fromOffset(40, 40)
		icon.Image = opts.icon or ""
		icon.Visible = (opts.icon or "") ~= ""
		icon.Parent = row
		local text = Instance.new("TextLabel")
		text.Name = "Amount"
		text.LayoutOrder = 2
		text.BackgroundTransparency = 1
		text.AutomaticSize = Enum.AutomaticSize.X
		text.Size = UDim2.fromOffset(0, 48)
		text.FontFace = FONT
		text.TextSize = 40
		text.TextColor3 = Color3.new(1, 1, 1)
		text.Text = "+1"
		text.Parent = row
		local stroke = Instance.new("UIStroke")
		stroke.Thickness = 3
		stroke.Color = INK
		stroke.LineJoinMode = Enum.LineJoinMode.Round
		stroke.Parent = text
		local scale = Instance.new("UIScale")
		scale.Parent = row
		table.insert(self.free, { anchor = anchor, bb = bb, icon = icon, text = text, stroke = stroke, scale = scale, t0 = 0, drift = 0 })
	end
	self.conn = RunService.RenderStepped:Connect(function()
		self:_step()
	end)
	return self
end

-- One pop for one tap. `root` is the avatar's HumanoidRootPart.
function TapPops:Pop(root: BasePart, words: string, color: Color3?)
	local p: Pop? = table.remove(self.free)
	if not p or #self.live >= LIVE_CAP then
		if p then
			table.insert(self.free, p)
		end
		p = table.remove(self.live, 1) -- recycle the oldest
	end
	if not p then
		return
	end
	-- a random spot around the avatar, relative to the camera: x ±2.5, y -1.5..+3.5, z ±1
	local cam = workspace.CurrentCamera
	local cf = if cam then CFrame.lookAt(root.Position, root.Position + cam.CFrame.LookVector * Vector3.new(1, 0, 1)) else root.CFrame
	local off = Vector3.new((math.random() * 2 - 1) * 2.5, -1.5 + math.random() * 5, (math.random() * 2 - 1) * 1)
	p.anchor.CFrame = CFrame.new(cf:PointToWorldSpace(off))
	p.text.Text = words
	p.text.TextColor3 = color or Color3.new(1, 1, 1)
	p.drift = (math.random() - 0.5) * 0.6
	p.t0 = os.clock()
	p.bb.StudsOffset = Vector3.zero
	self:_paint(p, 0)
	p.bb.Enabled = true
	table.insert(self.live, p)
end

function TapPops:_paint(p: Pop, age: number)
	local reduced = self.reduced()
	local k = math.min(1, age / RISE_T)
	local rise = (1 - (1 - k) ^ 2) * (if reduced then RISE * 0.4 else RISE)
	p.bb.StudsOffset = Vector3.new(p.drift * k, rise, 0)
	local s
	if reduced then
		s = 1
	elseif age < POP_T then
		s = 1.5 - 0.5 * backOut(age / POP_T)
	elseif age < FADE_AT then
		s = 1
	else
		s = 1 - 0.4 * math.min(1, (age - FADE_AT) / FADE_T)
	end
	p.scale.Scale = s
	local f = math.clamp((age - FADE_AT) / FADE_T, 0, 1)
	p.text.TextTransparency = f
	p.stroke.Transparency = f
	p.icon.ImageTransparency = f
end

function TapPops:_step()
	local now = os.clock()
	local i = 1
	while i <= #self.live do
		local p = self.live[i]
		local age = now - p.t0
		if age >= FADE_AT + FADE_T then
			p.bb.Enabled = false
			table.remove(self.live, i)
			table.insert(self.free, p)
		else
			self:_paint(p, age)
			i += 1
		end
	end
end

return TapPops

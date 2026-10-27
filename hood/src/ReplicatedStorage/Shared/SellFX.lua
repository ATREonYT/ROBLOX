-- SellFX (brief 31, rule 28: "the paid products for robux more attractive"): the reference's selling craft for the
-- Robux offers on screen, kid-safe and honest (no timers, no stock, nothing flashes: each sparkle eases in and out over
-- 0.7 s, a few seconds apart).
--   SellFX.sparkles(parent, props) -> stop()
--       little four-point stars that twinkle in and out at random spots round an offer (ref_W01.0_spawn_view_north: the
--       stars round the x2 buttons and the Starter Pack; ref_V3-00.5_store_exclusive: the stars on the clover card).
--       props: Count (3), Size (16 px), Color (white), ZIndex, Every (2.8 s: one star's whole cycle),
--       Inset (0.08: keep this share of the parent's size clear at each edge).
--   SellFX.pulse(gui, amount, period) -> the tween
--       a gentle idle breath (scale 1 -> 1 + amount, 0.035, and back over `period`, 2.4 s) on a UIScale named Pulse.
local TweenService = game:GetService('TweenService')

local SellFX = {}

local function star(parent, size, color, z)
	local holder = Instance.new('Frame')
	holder.Name = 'Sparkle'
	holder.BackgroundTransparency = 1
	holder.AnchorPoint = Vector2.new(0.5, 0.5)
	holder.Size = UDim2.fromOffset(size, size)
	holder.ZIndex = z
	for _, rot in { 0, 90 } do
		local arm = Instance.new('Frame')
		arm.Name = 'Arm'
		arm.BorderSizePixel = 0
		arm.BackgroundColor3 = color
		arm.AnchorPoint = Vector2.new(0.5, 0.5)
		arm.Position = UDim2.fromScale(0.5, 0.5)
		arm.Size = UDim2.fromScale(1, 0.2)
		arm.Rotation = rot
		arm.ZIndex = z
		local g = Instance.new('UIGradient') -- (pointed tips: the arm fades out at both ends)
		g.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.5, 0), NumberSequenceKeypoint.new(1, 1) })
		g.Parent = arm
		local c = Instance.new('UICorner')
		c.CornerRadius = UDim.new(0.5, 0)
		c.Parent = arm
		arm.Parent = holder
	end
	local core = Instance.new('Frame')
	core.Name = 'Core'
	core.BorderSizePixel = 0
	core.BackgroundColor3 = Color3.new(1, 1, 1)
	core.AnchorPoint = Vector2.new(0.5, 0.5)
	core.Position = UDim2.fromScale(0.5, 0.5)
	core.Size = UDim2.fromScale(0.34, 0.34)
	core.ZIndex = z + 1
	local cc = Instance.new('UICorner')
	cc.CornerRadius = UDim.new(0.5, 0)
	cc.Parent = core
	core.Parent = holder
	local scale = Instance.new('UIScale')
	scale.Scale = 0
	scale.Parent = holder
	holder.Visible = false -- (hidden between twinkles)
	holder.Parent = parent
	return holder, scale
end

function SellFX.sparkles(parent, props)
	props = props or {}
	local n = props.Count or 3
	local every = props.Every or 2.8
	local inset = props.Inset or 0.08
	local alive = true
	local rng = Random.new(props.Seed or (#parent.Name * 7919 + n))
	for i = 1, n do
		local s, scale = star(parent, props.Size or 16, props.Color or Color3.new(1, 1, 1), props.ZIndex or 20)
		task.spawn(function()
			task.wait((i - 1) * every / n)
			while alive and s.Parent do
				s.Position = UDim2.fromScale(inset + rng:NextNumber() * (1 - 2 * inset), inset + rng:NextNumber() * (1 - 2 * inset))
				s.Rotation = 0
				s.Visible = true
				TweenService:Create(scale, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
				TweenService:Create(s, TweenInfo.new(0.7, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), { Rotation = 45 }):Play()
				task.wait(0.4)
				TweenService:Create(scale, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Scale = 0 }):Play()
				task.wait(0.32)
				s.Visible = false
				task.wait(math.max(0.1, every - 0.72))
			end
		end)
	end
	return function()
		alive = false
		for _, c in parent:GetChildren() do
			if c.Name == 'Sparkle' then c:Destroy() end
		end
	end
end

function SellFX.pulse(gui, amount, period)
	local s = gui:FindFirstChild('Pulse')
	if not s then
		s = Instance.new('UIScale')
		s.Name = 'Pulse'
		s.Parent = gui
	end
	s.Scale = 1
	local t = TweenService:Create(s, TweenInfo.new((period or 2.4) / 2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), { Scale = 1 + (amount or 0.035) })
	t:Play()
	return t
end

return SellFX

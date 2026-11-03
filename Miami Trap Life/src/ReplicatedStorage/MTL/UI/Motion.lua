--!strict
-- One place for UI timing so every panel moves the same way.
local TweenService = game:GetService("TweenService")

local Motion = {}

Motion.Fast = TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
Motion.Normal = TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
Motion.Slow = TweenInfo.new(0.45, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
Motion.Spring = TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out) -- phone rise, pops
Motion.Bar = TweenInfo.new(0.5, Enum.EasingStyle.Quart, Enum.EasingDirection.Out) -- XP bar fill
Motion.AppIn = TweenInfo.new(0.28, Enum.EasingStyle.Quint, Enum.EasingDirection.Out) -- phone apps opening

function Motion.tween(inst: Instance, info: TweenInfo, props: { [string]: any }): Tween
	local t = TweenService:Create(inst, info, props)
	t:Play()
	return t
end

-- Counts a TextLabel from one number to another (cash ticking up). `format` turns a number into text.
function Motion.count(label: TextLabel, from: number, to: number, duration: number, format: (number) -> string)
	local start = os.clock()
	local token = {}
	label:SetAttribute("MTL_CountToken", tostring(token))
	task.spawn(function()
		while true do
			if label:GetAttribute("MTL_CountToken") ~= tostring(token) then
				return -- a newer count took over
			end
			local a = math.clamp((os.clock() - start) / duration, 0, 1)
			local eased = 1 - (1 - a) ^ 3
			label.Text = format(from + (to - from) * eased)
			if a >= 1 then
				return
			end
			task.wait()
		end
	end)
end

return Motion

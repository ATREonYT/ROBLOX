--[[
	One PreSimulation step for every scripted pose, in a fixed order, so each layer sits on the one
	before it: 10 the run (RunAnimator), 20 the carry and the girls (CarryAnimator), 30 the stab
	(Actions), 40 the knockdown (Knockdown). Each runs after Roblox's own animations for the frame.
]]
local RunService = game:GetService("RunService")

local Frame = {}
local steps = {}

-- fn(dt) runs every frame; lower order runs first.
function Frame.on(order: number, fn: (number) -> ())
	table.insert(steps, { order = order, fn = fn })
	table.sort(steps, function(a, b) return a.order < b.order end)
end

RunService.PreSimulation:Connect(function(dt)
	for _, s in steps do
		local ok, err = pcall(s.fn, dt)
		if not ok then
			warn("[Huzz] pose step failed: " .. tostring(err))
		end
	end
end)

return Frame

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

-- (a step that keeps failing used to print every frame: 60 lines a second fill Output and make Studio itself lag,
-- owner Oct 23 "its very laggy". Each error now prints once, then a count every 10 s while it goes on.)
local told = {} -- error text -> { count, at }
RunService.PreSimulation:Connect(function(dt)
	for _, s in steps do
		local ok, err = pcall(s.fn, dt)
		if not ok then
			local key = tostring(err)
			local t = told[key]
			local now = os.clock()
			if not t then
				told[key] = { count = 0, at = now }
				warn("[Huzz] pose step failed: " .. key)
			else
				t.count += 1
				if now - t.at >= 10 then
					warn(string.format("[Huzz] pose step failed %d more times: %s", t.count, key))
					t.count, t.at = 0, now
				end
			end
		end
	end
end)

return Frame

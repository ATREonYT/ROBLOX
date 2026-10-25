-- Reports problems in Studio's Output on lines starting [HuzzUI]. Report.run(name, fn) runs fn and reports any
-- error under `name`. The red box on screen is kept but hidden (owner, Oct 19: "please remove the red pop up"):
-- set SHOW_BOX to true to see problems on screen again while testing.
local Report = {}

local SHOW_BOX = false

local box: TextLabel? = nil
local lines: { string } = {}

local function refresh()
	if not box then return end
	box.Text = "UI problem - please send Claude a screenshot:\n" .. table.concat(lines, "\n")
	box.Visible = SHOW_BOX and #lines > 0
end

function Report.mount(parent: Instance)
	local old = parent:FindFirstChild("ProblemReport")
	if old then old:Destroy() end
	local l = Instance.new("TextLabel")
	l.Name = "ProblemReport"
	l:SetAttribute("RuntimeOnly", true) -- never saved into StarterGui
	l.BackgroundColor3 = Color3.fromRGB(120, 10, 30)
	l.BackgroundTransparency = 0.1
	l.TextColor3 = Color3.new(1, 1, 1)
	l.Font = Enum.Font.Code
	l.TextSize = 14
	l.TextWrapped = true
	l.TextXAlignment = Enum.TextXAlignment.Left
	l.TextYAlignment = Enum.TextYAlignment.Top
	l.AutomaticSize = Enum.AutomaticSize.Y
	l.Size = UDim2.new(0.5, 0, 0, 20)
	l.Position = UDim2.new(0.25, 0, 0, 8)
	l.ZIndex = 100
	l.Visible = false
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft, pad.PaddingRight, pad.PaddingTop, pad.PaddingBottom = UDim.new(0, 8), UDim.new(0, 8), UDim.new(0, 6), UDim.new(0, 6)
	pad.Parent = l
	l.Parent = parent
	box = l
	refresh()
end

function Report.problem(name: string, err: any)
	local text = tostring(err)
	warn("[HuzzUI] " .. name .. " failed:\n" .. text)
	table.insert(lines, name .. ": " .. (text:match("^[^\n]*") or text))
	while #lines > 6 do table.remove(lines, 1) end
	refresh()
end

-- Runs fn; an error is reported instead of stopping everything after it. Returns ok, result.
function Report.run(name: string, fn: (...any) -> any, ...: any)
	local ok, result = xpcall(fn, function(e) return debug.traceback(tostring(e)) end, ...)
	if not ok then Report.problem(name, result) end
	return ok, result
end

-- For a clock that ticks in a loop (owner, Oct 25 15:09: "all of the timers dont work, they are just stuck on the
-- same numbers"): an error in one tick used to end the loop, and the clock froze on its last number for good. Now each
-- tick runs protected (Report.tick(name, fn, ...) -> true when it ran), and a failing one says so in Output once a
-- minute ([HuzzUI] lines) while the clock keeps going.
local tickTold = {} -- name -> os.clock() last said
function Report.tick(name: string, fn: (...any) -> any, ...: any): boolean
	local ok, err = pcall(fn, ...)
	if not ok and os.clock() - (tickTold[name] or -math.huge) > 60 then
		tickTold[name] = os.clock()
		warn("[HuzzUI] " .. name .. " clock tick failed (it keeps ticking): " .. tostring(err))
	end
	return ok
end

return Report

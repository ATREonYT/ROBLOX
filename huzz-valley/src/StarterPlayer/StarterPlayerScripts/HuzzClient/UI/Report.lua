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

return Report

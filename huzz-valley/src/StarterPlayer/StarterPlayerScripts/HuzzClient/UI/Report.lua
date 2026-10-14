-- Shows problems on screen (a small red box, top left) as well as in Studio's Output, so the owner can screenshot
-- an error without opening the Output window. Report.run(name, fn) runs fn and reports any error under `name`.
local Report = {}

local box: TextLabel? = nil
local lines: { string } = {}

local function refresh()
	if not box then return end
	box.Text = "UI problem - please send Claude a screenshot:\n" .. table.concat(lines, "\n")
	box.Visible = #lines > 0
end

function Report.mount(parent: Instance)
	local l = Instance.new("TextLabel")
	l.Name = "ProblemReport"
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
	local ok, result = xpcall(fn, debug.traceback, ...)
	if not ok then Report.problem(name, result) end
	return ok, result
end

return Report

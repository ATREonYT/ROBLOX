-- A short message at the top of the screen ("Coming in the next build", purchase errors). One at a time.
local Theme = require(script.Parent.Theme)
local Kit = require(script.Parent.Kit)
local Motion = require(script.Parent.Motion)

local Toast = {}
local label: TextLabel
local serial = 0

function Toast.mount(parent: Instance)
	label = Kit.text({
		Name = "Toast", Text = "", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 12),
		Size = UDim2.fromOffset(10, 40), AutomaticSize = Enum.AutomaticSize.X, TextXAlignment = Enum.TextXAlignment.Center,
		FontFace = Theme.Fonts.Button, TextSize = 20, BackgroundColor3 = Theme.Colors.Pill, BackgroundTransparency = 1,
		TextTransparency = 1, ZIndex = 50, TextWrapped = false, Visible = false, Parent = parent,
	})
	Kit.attach(Kit.corner(6), label)
	Kit.attach(Kit.pad(16, 16, 0, 0), label)
end

function Toast.show(text: string, seconds: number?)
	if not label then return end
	serial += 1
	local mine = serial
	label.Text = text
	label.Visible = true
	label.Position = UDim2.new(0.5, 0, 0, 0)
	Motion.tween(label, "toast", 0.2, { TextTransparency = 0, BackgroundTransparency = 0.1 })
	Motion.tween(label, "toastMove", 0.3, { Position = UDim2.new(0.5, 0, 0, 12) }, Enum.EasingStyle.Back)
	task.delay(seconds or 2.4, function()
		if serial ~= mine then return end
		Motion.tween(label, "toast", 0.2, { TextTransparency = 1, BackgroundTransparency = 1 })
		task.wait(0.2)
		if serial == mine then label.Visible = false end
	end)
end

return Toast

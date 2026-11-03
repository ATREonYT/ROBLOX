--!strict
-- Builds the MTL_Dropped ScreenGui: the card that shows while you're down ("YOU GOT DROPPED" + respawn countdown).
-- Used two ways, same as HUD/Phone/Job:
--   1. Edit time: the installer saves it into StarterGui as real instances (Alex reskins it there)
--   2. Runtime fallback: DeathController builds it only if PlayerGui has no MTL_Dropped
-- DeathController finds things BY NAME. Keep these names when reskinning:
--   Card (CanvasGroup), Card/Title, Card/Sub, Card/Bar/Fill
local Theme = require(script.Parent.Parent.Theme)

local C = Theme.Colors

local function new(className: string, props: { [string]: any }, children: { Instance }?): any
	local inst = Instance.new(className)
	for k, v in props do
		if k ~= "Parent" then
			(inst :: any)[k] = v
		end
	end
	for _, child in children or {} do
		child.Parent = inst
	end
	if props.Parent then
		inst.Parent = props.Parent
	end
	return inst
end

local Dropped = {}

function Dropped.build(): ScreenGui
	local gui = new("ScreenGui", {
		Name = "MTL_Dropped",
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		DisplayOrder = 40, -- above the HUD, under cutscenes (50)
		Enabled = false,
	})
	local card = new("CanvasGroup", {
		Name = "Card",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.62),
		Size = UDim2.fromOffset(360, 112),
		BackgroundColor3 = C.Glass,
		BackgroundTransparency = C.GlassTransparency,
		GroupTransparency = 1,
		Parent = gui,
	}, {
		new("UICorner", { CornerRadius = UDim.new(0, 14) }),
		new("UIStroke", { Color = C.Stroke, Transparency = C.StrokeTransparency, Thickness = 1 }),
	})
	new("TextLabel", {
		Name = "Title",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(0, 18),
		Size = UDim2.new(1, 0, 0, 34),
		FontFace = Theme.Fonts.Display,
		Text = "YOU GOT DROPPED",
		TextColor3 = C.Danger,
		TextSize = 30,
		Parent = card,
	})
	new("TextLabel", {
		Name = "Sub",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(0, 56),
		Size = UDim2.new(1, 0, 0, 20),
		FontFace = Theme.Fonts.Body,
		Text = "Back on your feet in 5",
		TextColor3 = C.TextDim,
		TextSize = 16,
		Parent = card,
	})
	local bar = new("Frame", {
		Name = "Bar",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 88),
		Size = UDim2.new(1, -48, 0, 4),
		BackgroundColor3 = C.Shadow,
		BackgroundTransparency = 0.5,
		BorderSizePixel = 0,
		Parent = card,
	}, { new("UICorner", { CornerRadius = UDim.new(1, 0) }) })
	new("Frame", {
		Name = "Fill",
		Size = UDim2.fromScale(0, 1),
		BackgroundColor3 = C.Text,
		BorderSizePixel = 0,
		Parent = bar,
	}, { new("UICorner", { CornerRadius = UDim.new(1, 0) }) })
	return gui
end

return Dropped

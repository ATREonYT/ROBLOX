--[[
	Every "press a key" prompt in the place uses E (owner, Oct 23 14:10: "please make everything be E not y, its y
	right now"): any ProximityPrompt in Workspace, ours or one he placed in Studio, gets KeyboardKeyCode E, now and
	whenever one appears. Its gamepad button is left as it is.
]]
local Workspace = game:GetService("Workspace")

local PromptKeys = {}

local function fix(d: Instance)
	if d:IsA("ProximityPrompt") and d.KeyboardKeyCode ~= Enum.KeyCode.E then
		d.KeyboardKeyCode = Enum.KeyCode.E
	end
end

function PromptKeys.start()
	for _, d in Workspace:GetDescendants() do fix(d) end
	Workspace.DescendantAdded:Connect(fix)
end

return PromptKeys

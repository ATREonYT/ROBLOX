-- TextLook (Oct 28, the owner after playing in Studio: "make the text shown to the user on the screen match the UI
-- more, and make it more cartoony"): the words the game's moments and lines put on screen get the UI's cartoon look
-- wherever their own script left them flat. Every bright word (not dark body text on a light card) in the screens
-- below that has no fill gradient of its own gets TextStyle.world (lit from the top, deeper at the foot, its colour
-- kept, round outline joins), and one with no outline at all gets TextStyle's thick ink outline. Looked at one beat
-- after a word appears (task.defer), so a script that adds its own gradient right after making the word keeps it.
-- The screens: the goal line and its moments (HoodGoals), the level toast and RANK UP! (HoodProgress), the stage
-- banners (StageFeedback), the fight's words (HoodWaves), the notices (HoodNotices), the new gun's moment
-- (HoodGunReveal), the World Boss (HoodWorldBoss) and the old callouts (HoodOnboarding). The mockup windows, the HUD
-- and the owner's artboards keep their own text (they are drawn to the mockup already).
local Players = game:GetService('Players')
local RS = game:GetService('ReplicatedStorage')
local TextStyle = require(RS.Shared.TextStyle)

local player = Players.LocalPlayer
local playerGui = player:WaitForChild('PlayerGui')
local SCREENS = {
	HoodGoals = true, HoodProgress = true, StageFeedback = true, HoodWaves = true, HoodNotices = true,
	HoodGunReveal = true, HoodWorldBoss = true, HoodOnboarding = true,
}
local function bright(c) return 0.299 * c.R + 0.587 * c.G + 0.114 * c.B >= 0.45 end
local function look(x)
	if not (x.Parent and (x:IsA('TextLabel') or x:IsA('TextButton'))) then return end
	if x:GetAttribute('Cartoon') or x:GetAttribute('Shadowed') or x.Name:sub(-6) == 'Shadow' then return end
	if x.Text == '' and not x:IsA('TextLabel') then return end
	if x:FindFirstChildOfClass('UIGradient') or not bright(x.TextColor3) then return end
	if not x:FindFirstChildOfClass('UIStroke') then
		local s = Instance.new('UIStroke')
		s.Color = TextStyle.Ink
		s.Thickness = TextStyle.outlineFor(x.TextScaled and math.max(14, x.AbsoluteSize.Y * 0.8) or x.TextSize)
		s.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
		s.Parent = x
		x.TextStrokeTransparency = 1
	end
	TextStyle.world(x)
end
local function watch(sg)
	if not (sg:IsA('ScreenGui') and SCREENS[sg.Name]) or sg:GetAttribute('TextLook') then return end
	sg:SetAttribute('TextLook', true)
	for _, d in sg:GetDescendants() do pcall(look, d) end
	sg.DescendantAdded:Connect(function(d)
		if d:IsA('TextLabel') or d:IsA('TextButton') then
			task.defer(function() pcall(look, d) end)
		end
	end)
end
for _, sg in playerGui:GetChildren() do pcall(watch, sg) end
playerGui.ChildAdded:Connect(function(sg)
	task.defer(function() pcall(watch, sg) end)
end)

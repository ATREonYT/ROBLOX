-- ScreenDip (Oct 28, the feel round: no hard cuts). A trip across the map (a pad's cash-out back to the lobby, a World
-- window trip) happens under a short dip to night blue instead of a jump cut: close() darkens the screen in 0.2 s, the
-- move happens under it, open() lifts it in 0.35 s. Never white, never a flash: a calm blink. Client only.
--   ScreenDip.close(maxHold)   darken; it lifts by itself after maxHold s (default 1.2) if open() never comes
--   ScreenDip.open()           lift
--   ScreenDip.Color, ScreenDip.In, ScreenDip.Out
local Players = game:GetService('Players')
local TweenService = game:GetService('TweenService')

local ScreenDip = {}
ScreenDip.Color = Color3.fromRGB(27, 31, 58)
ScreenDip.In, ScreenDip.Out = 0.2, 0.35

local gui, cover
local token = 0
local function ensure()
	if gui and gui.Parent then return true end
	local player = Players.LocalPlayer
	local pg = player and player:FindFirstChildOfClass('PlayerGui')
	if not pg then return false end
	gui = Instance.new('ScreenGui')
	gui.Name = 'HoodDip'
	gui.IgnoreGuiInset = true
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 40
	gui.Enabled = false
	cover = Instance.new('Frame')
	cover.Name = 'Cover'
	cover.Size = UDim2.fromScale(1, 1)
	cover.BackgroundColor3 = ScreenDip.Color
	cover.BackgroundTransparency = 1
	cover.BorderSizePixel = 0
	cover.Parent = gui
	gui.Parent = pg
	return true
end

function ScreenDip.open()
	if not ensure() then return end
	token += 1
	local my = token
	local tw = TweenService:Create(cover, TweenInfo.new(ScreenDip.Out, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { BackgroundTransparency = 1 })
	tw.Completed:Once(function() if token == my then gui.Enabled = false end end)
	tw:Play()
end
function ScreenDip.close(maxHold)
	if not ensure() then return end
	token += 1
	local my = token
	gui.Enabled = true
	TweenService:Create(cover, TweenInfo.new(ScreenDip.In, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { BackgroundTransparency = 0 }):Play()
	task.delay(maxHold or 1.2, function() if token == my then ScreenDip.open() end end) -- (a lost answer never leaves it dark)
end

return ScreenDip

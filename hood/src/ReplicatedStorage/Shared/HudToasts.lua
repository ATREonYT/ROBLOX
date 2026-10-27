-- The HUD's notices (brief 30, HUD), shared by every script that says something (HUD.client for the server's Notice lines,
-- Wheel.client, Extras.client, Retention.client). Client only; one ScreenGui 'HoodNotices' (DisplayOrder 10) for all.
-- Copied from the reference's notices (ref_W49.5_return_spawn_confetti_autowin.jpg "FREE AUTOWIN! / Try AUTOWIN free for 15
-- min!", ref_W25.0_not_enough_wins.jpg "NOT ENOUGH WINS / You need 10 Wins to hatch this!"): no box, the heavy font with a
-- thick near-black outline, a coloured line (lime = good, gold = news, red = can't, cyan = info) and, when there is more to
-- say, a white line under it; centred under the goal line (the reference's 30 % of the height), newest on top, three at
-- most. Each one springs in (0.22 s Back Out from 0.85 and 24 px higher), holds, and slides back out.
--   HudToasts.say(text, tone?, sub?)   tone: 'green' | 'gold' | 'red' | 'blue' | 'purple' | 'white' (default green)
--   HudToasts.toneFor(text)            a tone from what a server line says
-- (brief 30, the audit's U1: "2x Cash is coming soon!" sat on the Before You Go title, the Daily Rewards and the Store)
-- A notice NEVER covers an open window: while one is open (PlayerGui HoodWindow, the Retention cards' HoodCard, the
-- unboxing moment) it shows in the free band above or below that window when the band is tall enough, else it waits and
-- shows the moment the window closes (at most 3 wait; one older than 30 s is dropped).
local Players = game:GetService('Players')
local RS = game:GetService('ReplicatedStorage')
local Kit = require(RS.Shared.UIKit)
local Motion = require(RS.Shared.UIMotion)

local HudToasts = {}
local player = Players.LocalPlayer
local playerGui = player:WaitForChild('PlayerGui')
local hex = Kit.hex
HudToasts.Colors = {
	green = { hex('C8FF4A'), hex('5CE01E') }, gold = { hex('FFE84A'), hex('FFA810') }, red = { hex('FF7A6A'), hex('E8203A') },
	blue = { hex('9CF4FF'), hex('2EC4F0') }, purple = { hex('EAB8FF'), hex('B05CF8') }, white = { hex('FFFFFF'), hex('E8ECF4') },
}
HudToasts.Y = 150 -- design px under the top inset: the reference's FREE AUTOWIN! line (219 of 720, the inset is 58)
HudToasts.Size = 28
HudToasts.SubSize = 22
HudToasts.MomentBottom = 240 -- (Goals.client's GOAL DONE moment reaches 19 + 210 + a margin: notices sit under it while it is up)

local Spec = require(script.Parent.HudSpec)
local gui, root, fit = Spec.screen('HoodNotices', 10) -- (HudSpec: a reference px is a screen px at 720 tall)
local stack = Kit.new('Frame', { Name = 'Toasts', BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, HudToasts.Y), Size = UDim2.fromOffset(900, 180), ZIndex = 40, Parent = root })
Kit.new('UIListLayout', { Padding = UDim.new(0, 4), HorizontalAlignment = Enum.HorizontalAlignment.Center, SortOrder = Enum.SortOrder.LayoutOrder, Parent = stack })
gui:GetPropertyChangedSignal('AbsoluteSize'):Connect(function() fit(gui.AbsoluteSize) end)
gui.Parent = playerGui
fit(gui.AbsoluteSize)
HudToasts.Gui, HudToasts.Stack = gui, stack

local function windowName()
	local w = playerGui:GetAttribute('HoodWindow')
	if type(w) == 'string' and w ~= '' then return w end
	local c = playerGui:GetAttribute('HoodCard')
	if type(c) == 'string' and c ~= '' then return c end
	return nil
end
-- The open window's panel on screen (a Kit.window / Kit.shopWindow / InventoryKit panel carries DesignW), or nil.
local function panelOf(name)
	for _, g in playerGui:GetChildren() do
		if g:IsA('ScreenGui') and g.Enabled and g ~= gui then
			for _, d in g:GetDescendants() do
				if d:IsA('GuiObject') and d.Name == name and d:GetAttribute('DesignW') then
					local ok, size = pcall(function() return d.AbsoluteSize end)
					if ok and size.X > 0 then return d end
				end
			end
		end
	end
	return nil
end
-- Where the stack may go now: its design-px y (under the top inset), or nil to wait. A free band above or below the open
-- window, at least NEED screen px tall.
local NEED = 46
local function slotY()
	if playerGui:GetAttribute('Unboxing') == true then return nil end
	local name = windowName()
	local k = Spec.scaleFor(gui.AbsoluteSize)
	local y = HudToasts.Y
	if playerGui:GetAttribute('GoalMoment') == true then y = math.max(y, HudToasts.MomentBottom or 0) end
	if not name then return y end
	local p = panelOf(name)
	if not p then return nil end
	local ok, top, bottom = pcall(function() return p.AbsolutePosition.Y, p.AbsolutePosition.Y + p.AbsoluteSize.Y end)
	if not ok then return nil end
	local screenH = gui.AbsoluteSize.Y
	local above, below = top - 8, screenH - bottom - 8
	if above >= NEED and above >= below then return math.max(0, (above - NEED) / 2) / k end
	if below >= NEED then return (bottom + 8) / k end
	return nil
end

local count = 0
local waiting = {}
local function show(text, tone, sub)
	count += 1
	local colors = HudToasts.Colors[tone or 'green'] or HudToasts.Colors.green
	local h = HudToasts.Size + 8 + (sub and HudToasts.SubSize + 6 or 0)
	local slot = Kit.new('Frame', { Name = 'Toast' .. count, BackgroundTransparency = 1, Size = UDim2.fromOffset(900, h), LayoutOrder = -count, Parent = stack })
	local line = Kit.text({ Name = 'Toast', Text = tostring(text), TextSize = HudToasts.Size, Stroke = Kit.Color.black, StrokeThickness = 4.5, Size = UDim2.new(1, 0, 0, HudToasts.Size + 8), ZIndex = 44, Parent = slot })
	line.TextSize = Kit.fitSize(line.Text, HudToasts.Size, 900, 14) -- (round 7: a whole size that fits, not TextScaled)
	Kit.new('UIGradient', { Rotation = 90, Color = ColorSequence.new(colors[1], colors[2]), Parent = line })
	if sub then
		local s = Kit.text({ Name = 'Sub', Text = tostring(sub), TextSize = HudToasts.SubSize, Stroke = Kit.Color.black, StrokeThickness = 3.5, Position = UDim2.fromOffset(0, HudToasts.Size + 8), Size = UDim2.new(1, 0, 0, HudToasts.SubSize + 6), ZIndex = 44, Parent = slot })
		s.TextSize = Kit.fitSize(s.Text, HudToasts.SubSize, 900, 12)
	end
	Motion.toast(slot, 3)
	task.delay(3.5, function() if slot.Parent then slot:Destroy() end end)
	local slots = {}
	for _, s in stack:GetChildren() do
		if s:IsA('Frame') then table.insert(slots, s) end
	end
	table.sort(slots, function(a, b) return a.LayoutOrder < b.LayoutOrder end)
	for i = 4, #slots do slots[i]:Destroy() end
end
local function place()
	local y = slotY()
	if y then stack.Position = UDim2.new(0.5, 0, 0, y) end
	stack.Visible = y ~= nil
	return y ~= nil
end
HudToasts.place = place

function HudToasts.say(text, tone, sub)
	if place() then
		show(text, tone, sub)
		return
	end
	table.insert(waiting, { Text = text, Tone = tone, Sub = sub, At = os.clock() })
	while #waiting > 3 do table.remove(waiting, 1) end
end
local function flush()
	if not place() then return end
	local now = os.clock()
	local list = waiting
	waiting = {}
	for _, w in list do
		if now - w.At <= 30 then show(w.Text, w.Tone, w.Sub) end
	end
end
for _, name in { 'HoodWindow', 'HoodCard', 'Unboxing', 'GoalMoment' } do
	playerGui:GetAttributeChangedSignal(name):Connect(function() task.delay(0.3, flush) end)
end
task.spawn(function()
	while true do
		task.wait(0.5)
		if #waiting > 0 then flush() else place() end
	end
end)

-- A tone from what a server line says.
function HudToasts.toneFor(text)
	local lower = string.lower(tostring(text))
	if lower:find('soon') then return 'blue' end
	if lower:find('rebirth') and not lower:find('need') then return 'gold' end
	if lower:find('equipped') or lower:find('bought') or lower:find('cleared') or lower:find('thanks') or lower:find('won') or lower:find('reward') or lower:find('gift') then return 'green' end
	if lower:find('not enough') or lower:find("can't") or lower:find('cannot') or lower:find('slow down') then return 'red' end
	if lower:find('reach') or lower:find('walk') or lower:find('need') or lower:find('first') or lower:find('find') then return 'gold' end
	if lower:find('mission') then return 'gold' end
	return 'purple'
end
-- Splits "Title! The rest." into the reference's two lines: a short exclaimed head (up to 26 characters) and the rest in
-- white; anything else stays one line.
function HudToasts.split(text)
	text = tostring(text)
	local head, rest = string.match(text, '^([^!]-!)%s+(.+)$')
	if head and #head <= 26 and #rest > 0 then return head, rest end
	return text, nil
end

return HudToasts

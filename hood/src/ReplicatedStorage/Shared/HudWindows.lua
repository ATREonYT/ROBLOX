-- The HUD's windows (brief 30, HUD), shared by every script that opens one (HUD.client: Rebirth, Quest, Daily Rewards,
-- Ranks; Wheel.client: Spin Wheel; Extras.client: Playtime Rewards, Missions, Starter Pack). Client only. A ModuleScript,
-- so every LocalScript that requires it shares the same one ScreenGui ('HoodPanels', DisplayOrder 8, over the goal line)
-- and the same "which window is open" state.
--   HudWindows.make(name, props) -> win   a Kit.window (props: Title, Icon, Tone, Width, Height, TitleSize, Gloss) hidden,
--                                         with a backdrop that closes it on a tap beside it; win = { Name, Overlay, Panel,
--                                         Well, Header, Open = fn?, Update = fn? }
--   HudWindows.open(win) / .close() / .toggle(win) / .current()
-- One window at a time across every script: PlayerGui's HoodWindow attribute names the open one (the Store, the
-- inventory and the World window set it too); a window whose name it no longer holds closes. While any window is open the
-- HUD steps away (HUD.client) and notices wait or move clear of it (HudToasts).
-- Motion like the reference's panels (EGG clip: 0.15 -> 0.6 -> 0.9 -> 1.05 -> 1.0): UIMotion.open's spring from 0.8, the
-- world blurred behind (UIMotion.blur), and the window's direct children stagger in (each fades and rises 10 px, 0.03 s
-- apart) so a window never lands as one flat slab.
local Players = game:GetService('Players')
local RS = game:GetService('ReplicatedStorage')
local TweenService = game:GetService('TweenService')
local Kit = require(RS.Shared.UIKit)
local Motion = require(RS.Shared.UIMotion)

local HudWindows = {}
local player = Players.LocalPlayer
local playerGui = player:WaitForChild('PlayerGui')
local gui, root, fit
local list = {}
local current

local InventoryKit
do
	local node = RS.Shared:FindFirstChild('InventoryKit')
	local ok, result = pcall(function() return node and require(node) end)
	InventoryKit = ok and type(result) == 'table' and result or nil
end
local function coverPlayerList(on)
	if InventoryKit and type(InventoryKit.coverPlayerList) == 'function' then InventoryKit.coverPlayerList('HUD', on) end
end

local function relayout()
	if not gui then return end
	local abs = gui.AbsoluteSize
	if abs.X < 1 or abs.Y < 1 then return end
	fit(abs)
	for _, w in list do Kit.fitWindow(w.Panel, abs) end
end
function HudWindows.root()
	if not gui then
		gui, root, fit = Kit.screen('HoodPanels', nil, 8)
		gui:GetPropertyChangedSignal('AbsoluteSize'):Connect(relayout)
		gui.Parent = playerGui
		relayout()
	end
	return root, gui
end
HudWindows.relayout = relayout

local InstanceMap = require(script.Parent.InstanceMap) -- (not a weak table: see InstanceMap)
-- The window's own parts rise and fade in one after another (the reference's stagger-in). (bases: where each part rests,
-- kept while its stagger runs, so a second open mid-stagger never moves it for good)
local bases = InstanceMap.new()
local function staggerIn(win)
	local i = 0
	for _, c in win.Well:GetChildren() do
		if c:IsA('GuiObject') and c.Visible and c:GetAttribute('NoStagger') ~= true then
			i += 1
			local base = bases[c] or c.Position
			bases[c] = base
			c.Position = base + UDim2.fromOffset(0, 10)
			local s = Motion.scaleOf(c)
			s.Scale = 0.94
			local delay = math.min(i, 10) * 0.03
			task.delay(delay, function()
				if not c.Parent then return end
				local t = TweenService:Create(c, TweenInfo.new(0.22, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Position = base })
				t.Completed:Once(function() if c.Position == base then bases[c] = nil end end)
				t:Play()
				TweenService:Create(s, TweenInfo.new(0.22, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
			end)
		end
	end
end
HudWindows.staggerIn = staggerIn

function HudWindows.current() return current end
function HudWindows.close()
	local w = current
	if not w then return end
	current = nil
	coverPlayerList(false)
	Motion.blur(w.Name, false)
	Motion.close(w.Overlay, w.Panel)
	if w.Closed then pcall(w.Closed) end
	if playerGui:GetAttribute('HoodWindow') == w.Name then playerGui:SetAttribute('HoodWindow', '') end
end
function HudWindows.open(w)
	if current == w then return end
	if current then
		Motion.blur(current.Name, false)
		current.Overlay.Visible = false
		if current.Closed then pcall(current.Closed) end
		current = nil
	end
	current = w
	coverPlayerList(true)
	playerGui:SetAttribute('HoodWindow', w.Name)
	if w.Open then w.Open() end
	Motion.blur(w.Name, true)
	Motion.open(w.Overlay, w.Panel, 1)
	staggerIn(w)
end
function HudWindows.toggle(w)
	if current == w then HudWindows.close() else HudWindows.open(w) end
end

function HudWindows.make(name, props)
	local r = HudWindows.root()
	props = props or {}
	local panel, well, closeHit, overlay, header = Kit.window(r, { Name = name, Title = props.Title or name, Icon = props.Icon, Tone = props.Tone, Width = props.Width or 940, Height = props.Height or 642, TitleSize = props.TitleSize or 64, Gloss = props.Gloss })
	overlay.Visible = false
	-- taps beside the window close it; taps on the window stop there
	local backdrop = Kit.new('TextButton', { Name = 'Backdrop', Text = '', AutoButtonColor = false, BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 20, Parent = overlay })
	backdrop.Activated:Connect(HudWindows.close)
	Kit.new('TextButton', { Name = 'Sink', Text = '', AutoButtonColor = false, BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 21, Parent = panel })
	Motion.button(closeHit.Parent, HudWindows.close)
	local w = { Name = name, Overlay = overlay, Panel = panel, Well = well, Header = header }
	table.insert(list, w)
	relayout()
	return w
end

playerGui:GetAttributeChangedSignal('HoodWindow'):Connect(function()
	local open = playerGui:GetAttribute('HoodWindow')
	if current and open ~= current.Name then HudWindows.close() end
end)

return HudWindows

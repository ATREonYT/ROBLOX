-- The spin wheel (brief 30, HUD; the user's choice from the soldier game: bible §2.5 "spin wheel Ready x1", §2.7 "Spin
-- wheel x 20-25 %, y 4-15 %: rainbow wheel, red x1 badge, Ready"). The server decides everything (HoodServer/
-- HudExtrasService: the HudExtras remote; the rules are Shared/HudExtrasRules); this shows it:
--   * the HUD button in HoodHUD's SpinSlot (top-left, measured on ref_W31.0: the wheel 68 px across centred at 258 x 70 of
--     720, the red "x1" badge on its top-right, "Ready" in white over its foot). While a spin is ready the wheel turns
--     slowly (the reference's "alive bits": its wheel turns) and the badge shows how many you can use; otherwise the
--     caption counts down to the next free spin (a real timer: the server's SpinNext)
--   * the Spin Wheel window: the big wheel with each prize on its wedge and the red pointer on top, SPIN, the spins you
--     have and when the next free one comes, "3 Spins" for Robux (its real price; Roblox's own prompt), and every prize's
--     chance (the very numbers the server rolls with). A spin turns the wheel 4.2 s (Quint Out) onto the wedge the server
--     picked, then the prize pops on it.
-- Kid-safe and honest: no flashing (the wheel turns, nothing blinks), no fake timer, nothing opens by itself.
local Players = game:GetService('Players')
local RS = game:GetService('ReplicatedStorage')
local TweenService = game:GetService('TweenService')
local MarketplaceService = game:GetService('MarketplaceService')

local Shared = RS:WaitForChild('Shared')
local Kit = require(Shared.UIKit)
local Motion = require(Shared.UIMotion)
local Net = require(Shared.Net)
local Products = require(Shared.Config.Products)
local Rules = require(Shared.HudExtrasRules)
local Spec = require(Shared.HudSpec)
local Windows = require(Shared.HudWindows)
local Toasts = require(Shared.HudToasts)

local player = Players.LocalPlayer
local playerGui = player:WaitForChild('PlayerGui')
local px, hex, Color = UDim2.fromOffset, Kit.hex, Kit.Color
local BLACK = Color.black

local function label(props)
	props.Stroke = props.Stroke or BLACK
	props.StrokeThickness = props.StrokeThickness or math.max(2, (props.TextSize or 20) * 0.14)
	return Kit.text(props)
end
local function gradient(t, a, b)
	Kit.new('UIGradient', { Rotation = 90, Color = ColorSequence.new(a, b), Parent = t })
	return t
end
local function num(name, fallback)
	local v = player:GetAttribute(name)
	return type(v) == 'number' and v == v and v or fallback
end
local function clock(seconds)
	seconds = math.max(0, math.floor(seconds))
	local h, m, s = seconds // 3600, (seconds % 3600) // 60, seconds % 60
	return h > 0 and string.format('%d:%02d:%02d', h, m, s) or string.format('%d:%02d', m, s)
end
local function ask(action, arg)
	local ok, res = pcall(function() return Net.get('HudExtras'):InvokeServer(action, arg) end)
	return ok and type(res) == 'table' and res or nil
end
local function buy(key)
	local entry = Products.ByKey[key]
	local ok, why = Products.canBuy(key)
	if not ok then
		if why == 'noid' or why == 'off' then Toasts.say((entry and entry.Title or 'This') .. ' is coming soon!', 'blue') end
		return
	end
	pcall(function() MarketplaceService:PromptProductPurchase(player, Products.idOf(key)) end)
end
-- spins usable now, from the attributes: the free one (SpinFree, or SpinNext reached) and the extras
local function spinsNow()
	local free = player:GetAttribute('SpinFree') == true or (num('SpinNext', 0) > 0 and num('SpinNext', 0) <= os.time())
	return (free and 1 or 0) + num('SpinExtra', 0), free
end

---------------------------------------------------------------------------------------------- the HUD button
local hud = playerGui:WaitForChild('HoodHUD', 60)
local slot = hud and hud:WaitForChild('Root', 10) and hud.Root:WaitForChild('SpinSlot', 10)
local win -- (the window, below)
local hudWheel, badge, badgeText, caption
if slot then
	local S = Spec.Spin
	-- (the button inside the slot: the slot's own UIScale is the layout's, the press squash scales this one)
	local holder = Kit.new('Frame', { Name = 'Button', BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Parent = slot })
	Kit.new('TextButton', { Name = 'Hit', Text = '', AutoButtonColor = false, BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 9, Parent = holder })
	local body = Kit.new('Frame', { Name = 'Body', BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = px(S.Size + 10, S.Size + 10), ZIndex = 3, Parent = holder })
	hudWheel = Kit.icon3d(Kit.iconOr('SpinWheel', 'Rewards'), S.Size + 8, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), ZIndex = 3 })
	hudWheel.Parent = body
	-- the red "x1" badge on the wheel's top-right (ref 271..300 x 30..55 round a wheel centred at 258 x 70)
	badge = Kit.new('Frame', { Name = 'Badge', BackgroundColor3 = Color.white, BorderSizePixel = 0, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 27, 0.5, -28), Size = px(32, 26), ZIndex = 6, Parent = holder })
	Kit.corner(6).Parent = badge
	Kit.stroke(BLACK, 2.5, true).Parent = badge
	Kit.gradient(hex('FF5A6A'), hex('D8102E'), 0.5).Parent = badge
	badgeText = label({ Name = 'Count', Text = 'x1', TextSize = S.Badge, StrokeThickness = 2.5, ZIndex = 7, Parent = badge })
	caption = label({ Name = 'Caption', Text = 'Ready', TextSize = S.Caption, StrokeThickness = 3.5, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.5, 23), Size = px(130, 28), ZIndex = 8, Parent = holder })
	-- the press: a squash and a grow like every HUD button (UIMotion.button wants a holder with Hit and Body)
	holder:SetAttribute('Lip', 2)
	Motion.button(holder, function() if win then Windows.toggle(win) end end)
	local turning
	local function paint()
		local n, free = spinsNow()
		badge.Visible = n > 0
		badgeText.Text = 'x' .. (n > 99 and '99' or tostring(n))
		if n > 0 then
			caption.Text = 'Ready'
			caption.TextSize = S.Caption
		else
			caption.Text = clock(num('SpinNext', 0) - os.time())
			caption.TextSize = S.Caption - 4
		end
		-- (alive while ready: one slow turn every 8 s; still otherwise)
		if n > 0 and not turning then
			turning = TweenService:Create(hudWheel, TweenInfo.new(8, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut, -1), { Rotation = 360 })
			hudWheel.Rotation = 0
			turning:Play()
		elseif n <= 0 and turning then
			turning:Cancel()
			turning = nil
			hudWheel.Rotation = 0
		end
		return free
	end
	for _, name in { 'SpinFree', 'SpinExtra', 'SpinNext' } do
		player:GetAttributeChangedSignal(name):Connect(function()
			local before = badge.Visible
			paint()
			if badge.Visible and not before then Motion.pop(badge, 0.35) end
		end)
	end
	paint()
	task.spawn(function()
		while slot.Parent do
			task.wait(1)
			paint()
		end
	end)
end

---------------------------------------------------------------------------------------------- the window
do
	local W, H = 900, 600
	win = Windows.make('Spin', { Title = 'Spin Wheel', Icon = Kit.iconOr('SpinWheel', 'Rewards'), Tone = 'headerMagenta', Width = W, Height = H, Gloss = false })
	local well = win.Well
	local D = 400 -- the wheel's size
	local holder = Kit.new('Frame', { Name = 'WheelHolder', BackgroundTransparency = 1, Position = px(10, 2), Size = px(D, D + 20), ZIndex = 24, Parent = well })
	-- a soft light behind the wheel (the reference's rays behind a prize), still
	Kit.sunburst(D + 60, { AnchorPoint = Vector2.new(0.5, 0.5), Position = px(D / 2, D / 2 + 14), ZIndex = 24, Rays = 16, Alpha = 0.12 }).Parent = holder
	local disc = Kit.icon3d(Kit.iconOr('SpinWheelDisc', 'SpinWheel'), D, { AnchorPoint = Vector2.new(0.5, 0.5), Position = px(D / 2, D / 2 + 14), ZIndex = 25 })
	disc.Name = 'Wheel'
	disc.Parent = holder
	-- the prizes on their wedges (they turn with the wheel)
	local prizes = Kit.new('Frame', { Name = 'Prizes', BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = px(D / 2, D / 2 + 14), Size = px(D, D), ZIndex = 27, Parent = holder })
	-- the hub and the pointer stay still on top
	local hub = Kit.new('Frame', { Name = 'Hub', BackgroundColor3 = hex('FFD226'), BorderSizePixel = 0, AnchorPoint = Vector2.new(0.5, 0.5), Position = px(D / 2, D / 2 + 14), Size = px(58, 58), ZIndex = 31, Parent = holder })
	Kit.corner(UDim.new(0.5, 0)).Parent = hub
	Kit.stroke(BLACK, 5, true).Parent = hub
	Kit.gradient(hex('FFF070'), hex('F29A0A'), 0.55).Parent = hub
	local pointer = Kit.new('Frame', { Name = 'Pointer', BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0), Position = px(D / 2, -6), Size = px(44, 52), ZIndex = 32, Parent = holder })
	do
		-- a red arrowhead pointing down: a square turned 45 degrees under a short bar, black-edged
		local diamond = Kit.new('Frame', { Name = 'Tip', BackgroundColor3 = hex('FF3A4A'), BorderSizePixel = 0, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0, 24), Size = px(30, 30), Rotation = 45, ZIndex = 32, Parent = pointer })
		Kit.stroke(BLACK, 4, true, 0, Enum.LineJoinMode.Miter).Parent = diamond
		Kit.gradient(hex('FF7A7A'), hex('D0102A'), 0.5).Parent = diamond
		local cap = Kit.new('Frame', { Name = 'Cap', BackgroundColor3 = hex('FF5A64'), BorderSizePixel = 0, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 0), Size = px(40, 18), ZIndex = 33, Parent = pointer })
		Kit.corner(5).Parent = cap
		Kit.stroke(BLACK, 4, true).Parent = cap
	end
	-- the right side: the spins, SPIN, the free-spin line, 3 Spins, the chances
	local RX = D + 40
	local count = gradient(label({ Name = 'Spins', Text = 'Spins: 0', TextSize = 40, StrokeThickness = 5, TextXAlignment = Enum.TextXAlignment.Left, Position = px(RX, 4), Size = px(400, 46), ZIndex = 26, Parent = well }), hex('FFF27A'), hex('FFA81A'))
	local freeLine = label({ Name = 'Free', Text = '', TextSize = 22, StrokeThickness = 3.5, TextXAlignment = Enum.TextXAlignment.Left, Position = px(RX, 52), Size = px(410, 28), ZIndex = 26, Parent = well })
	local spinButton = Kit.blockButton({ Name = 'SpinButton', Tone = 'lime', Width = 250, Height = 78, Text = 'SPIN!', TextSize = 46, Outline = 5, RimWidth = 3, Studs = 20, Radius = 8, Position = px(RX, 92), ZIndex = 26 })
	spinButton.Parent = well
	local packEntry = Products.ByKey.SpinPack
	local packButton = Kit.robuxButton({ Name = 'SpinPack', Tone = 'gold', Width = 150, Height = 78, Price = packEntry and packEntry.Price or '?', TextSize = 30, Outline = 5, Radius = 8, Position = px(RX + 262, 92), ZIndex = 26 })
	packButton.Parent = well
	label({ Name = 'PackCap', Text = '+' .. Rules.Spin.PackSpins .. ' Spins', TextSize = 18, StrokeThickness = 3, AnchorPoint = Vector2.new(0.5, 0), Position = px(RX + 262 + 75, 172), Size = px(150, 22), ZIndex = 26, Parent = well })
	Motion.button(packButton, function() buy('SpinPack') end)
	gradient(label({ Name = 'ChanceHead', Text = 'Chances', TextSize = 24, StrokeThickness = 3.5, TextXAlignment = Enum.TextXAlignment.Left, Position = px(RX, 200), Size = px(400, 28), ZIndex = 26, Parent = well }), hex('9CF4FF'), hex('2EC4F0'))
	local chances = Kit.new('Frame', { Name = 'Chances', BackgroundTransparency = 1, Position = px(RX, 232), Size = px(420, 210), ZIndex = 26, Parent = well })
	local prize = Kit.new('Frame', { Name = 'Prize', BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = px(D / 2 + 10, D / 2 + 16), Size = px(420, 140), ZIndex = 40, Visible = false, Parent = well })
	prize:SetAttribute('NoStagger', true)
	local prizeText = gradient(label({ Name = 'Text', Text = '', TextSize = 40, StrokeThickness = 5, Size = UDim2.fromScale(1, 1), ZIndex = 41, Parent = prize }), hex('C8FF4A'), hex('5CE01E'))
	prizeText.TextWrapped = true
	local state, stateAt, spinning = nil, 0, false
	local angle = 0 -- the wheel's turn now (degrees)

	-- a prize's word on its wedge: "+400", "+100", "2x", "Box"
	local function shortLine(lines)
		local first = lines[1] or ''
		local n = string.match(first, '^(%+[%d%.]+%a?) Cash$') or string.match(first, '^(%+[%d%.]+%a?) Power$')
		if n then return n end
		local b = string.match(first, '^(%d+x) Power')
		if b then return b end
		if string.find(first, 'Box') then return 'Box' end
		return first
	end
	local function paintPrizes()
		for _, c in prizes:GetChildren() do c:Destroy() end
		for _, c in chances:GetChildren() do c:Destroy() end
		local wedges = state and state.Spin and state.Spin.Wedges
		if not wedges then return end
		for i, w in wedges do
			-- on the wheel: the prize's picture near the hub and a short word toward the rim, along the wedge's middle, reading
			-- outward (they turn with the wheel)
			local deg = Rules.wedgeAngle(i)
			local a = math.rad(deg)
			local function at(r) return px(D / 2 + math.sin(a) * r, D / 2 - math.cos(a) * r) end
			local pic = Kit.icon3d(w.Icon, 46, { AnchorPoint = Vector2.new(0.5, 0.5), Position = at(D * 0.2), ZIndex = 28 })
			pic.Rotation = deg
			pic.Name = 'Prize' .. i
			pic.Parent = prizes
			local short = shortLine(w.Lines)
			local t = label({ Name = 'Text' .. i, Text = short, TextSize = 18, StrokeThickness = 3, AnchorPoint = Vector2.new(0.5, 0.5), Position = at(D * 0.292), Size = px(70, 22), Rotation = deg, ZIndex = 29, Parent = prizes })
			t.TextScaled = true
			Kit.new('UITextSizeConstraint', { MaxTextSize = 18, MinTextSize = 10, Parent = t })
			-- in the chances list: a dot in the wedge's colour, the prize, its chance
			local col, row = (i - 1) // 4, (i - 1) % 4
			local line = Kit.new('Frame', { Name = 'Chance' .. i, BackgroundTransparency = 1, Position = px(col * 214, row * 50), Size = px(206, 46), ZIndex = 26, Parent = chances })
			local dot = Kit.new('Frame', { Name = 'Dot', BackgroundColor3 = hex(string.sub(w.Color, 2)), BorderSizePixel = 0, AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 0, 0.5, 0), Size = px(14, 14), ZIndex = 27, Parent = line })
			Kit.corner(UDim.new(0.5, 0)).Parent = dot
			Kit.stroke(BLACK, 2, true).Parent = dot
			Kit.icon3d(w.Icon, 38, { AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 18, 0.5, 0), ZIndex = 27 }).Parent = line
			local what = label({ Name = 'What', Text = table.concat(w.Lines, ' + '), TextSize = 16, StrokeThickness = 2.5, TextXAlignment = Enum.TextXAlignment.Left, Position = px(60, 2), Size = px(146, 22), ZIndex = 27, Parent = line })
			what.TextScaled = true
			Kit.new('UITextSizeConstraint', { MaxTextSize = 16, MinTextSize = 9, Parent = what })
			gradient(label({ Name = 'Chance', Text = w.Chance, TextSize = 17, StrokeThickness = 2.5, TextXAlignment = Enum.TextXAlignment.Left, Position = px(60, 22), Size = px(100, 20), ZIndex = 27, Parent = line }), hex('FFF27A'), hex('FFA81A'))
		end
	end
	local function paintSide()
		local n = spinsNow()
		count.Text = 'Spins: ' .. n
		local sp = state and state.Spin
		local wait = math.max(0, num('SpinNext', 0) - os.time())
		if player:GetAttribute('SpinFree') == true or wait <= 0 then
			freeLine.Text = 'Free spin ready!'
			freeLine.TextColor3 = hex('7CFF4F')
		else
			freeLine.Text = 'Next free spin in ' .. clock(wait)
			freeLine.TextColor3 = Color.white
		end
		local can = n > 0 and not spinning
		local l = spinButton:FindFirstChild('Label', true)
		if l then l.Text = spinning and '...' or 'SPIN!' end
		spinButton.Body.BackgroundTransparency = can and 0 or 0.4
		local _ = sp
	end
	local function refresh()
		local res = ask('State')
		if res and res.State then
			state, stateAt = res.State, os.clock()
			paintPrizes()
			paintSide()
		end
	end
	local function spin()
		if spinning then return end
		if spinsNow() <= 0 then
			Toasts.say('No spins right now!', 'red', 'A free spin comes back every ' .. math.floor(Rules.Spin.FreeEvery / 3600) .. ' hours.')
			return
		end
		spinning = true
		prize.Visible = false
		paintSide()
		local res = ask('Spin')
		if not res or not res.Ok or type(res.Wedge) ~= 'number' then
			spinning = false
			paintSide()
			return
		end
		if res.State then state, stateAt = res.State, os.clock() end
		-- five whole turns, then the picked wedge's middle under the pointer (a few degrees either side, like a real wheel)
		local land = -Rules.wedgeAngle(res.Wedge) + (math.random() - 0.5) * 24
		local target = angle + 360 * 5 + ((land - angle) % 360)
		angle = target % 360
		local t = TweenInfo.new(Rules.Spin.SpinSeconds, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
		TweenService:Create(disc, t, { Rotation = target }):Play()
		TweenService:Create(prizes, t, { Rotation = target }):Play()
		task.delay(Rules.Spin.SpinSeconds, function()
			disc.Rotation = angle
			prizes.Rotation = angle
			spinning = false
			prizeText.Text = 'You won ' .. table.concat(res.Lines or {}, ' + ') .. '!'
			prize.Visible = true
			local s = Motion.scaleOf(prize)
			s.Scale = 0.3
			Motion.tween(s, 0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out, { Scale = 1 })
			local item = prizes:FindFirstChild('Prize' .. res.Wedge)
			if item then Motion.pop(item, 0.5) end
			task.delay(2.4, function() if not spinning then prize.Visible = false end end)
			paintSide()
		end)
	end
	Motion.button(spinButton, spin)
	win.Open = function()
		prize.Visible = false
		paintPrizes()
		paintSide()
		task.spawn(refresh)
	end
	win.Update = paintSide
	task.spawn(function()
		while true do
			task.wait(1)
			if Windows.current() == win then paintSide() end
		end
	end)
	pcall(function()
		MarketplaceService.PromptProductPurchaseFinished:Connect(function(_, id, bought)
			if bought and Products.keyFor('Product', id) == 'SpinPack' then
				task.delay(1.5, function() if Windows.current() == win then refresh() end end)
			end
		end)
	end)
	local _ = stateAt
end

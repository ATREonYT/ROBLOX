-- The dance wheel (owner's reference: another game's taunt wheel): press G (gamepad Y) anywhere and 8 round,
-- see-through slots pop up round a big centre circle. Each slot shows your avatar frozen mid-dance (UI/DancePose),
-- its name and its number. Your favourite dances fill the slots first (star them in the Dances window), then the
-- rest you own; an empty slot opens your dances. Hover (or select) a slot and the centre says what it is; click it,
-- or press its number, to dance; click the playing one again to stop. Walking away stops it too (UI/DancePlayer).
-- G, Esc or a click outside closes it. No dimming and no fading layer (the old CanvasGroup lagged): it grows in
-- from the middle and the slots glide out. While it shows, shift lock lets go of the mouse ("HuzzWheel").
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Dances = require(Shared.Config.Dances)
local UI = script.Parent.Parent
local Theme = require(UI.Theme)
local Kit = require(UI.Kit)
local Scale = require(UI.Scale)
local State = require(UI.State)
local Toast = require(UI.Toast)
local ModalManager = require(UI.ModalManager)
local DancePlayer = require(UI.DancePlayer)
local DancePose = require(UI.DancePose)
local Sfx = require(UI.Parent.Gameplay.Sfx)

local C = Theme.Colors
local F = Theme.Fonts
local new = Kit.new

local DanceWheel = {}

local SIZE = 560 -- the whole wheel, reference px (scaled like the HUD)
local RING = 412 -- the circle the slots' centres sit on
local SLOT = 124 -- a slot's diameter
local CENTRE = 236 -- the centre circle's diameter
local SLOTS = 8
local PAGE_H = 347 -- the HUD reference height (as LobbyHud)
local GLASS = Color3.fromRGB(8, 10, 18) -- the see-through dark of the circles
local GLASS_T = 0.55 -- (owner: "more transparent in places like these")
local RIM_LIGHT = Color3.fromRGB(200, 205, 220)
local GREEN = C.Accent

-- Favourites first, then the other owned dances, in the list's order.
local function wheelDances(): { any }
	local list, seen = {}, {}
	for _, pass in { true, false } do
		for _, d in Dances.List do
			local fav = State.data.FavDances[d.Id] == true
			if not seen[d.Id] and DancePlayer.owned(d.Id) and fav == pass then
				table.insert(list, d)
				seen[d.Id] = true
			end
		end
	end
	return list
end

-- A see-through dark circle with a thick black rim and a thin light rim inside it (as the reference).
local function glassCircle(props: { [string]: any }, diameter: number): (Frame, UIStroke)
	local f = new("Frame", props)
	f.Size = UDim2.fromOffset(diameter, diameter)
	f.AnchorPoint = Vector2.new(0.5, 0.5)
	f.BackgroundColor3 = GLASS
	f.BackgroundTransparency = GLASS_T
	f.BorderSizePixel = 0
	new("UICorner", { CornerRadius = UDim.new(0.5, 0), Parent = f })
	local outer = new("UIStroke", { Name = "Rim", Color = Color3.new(0, 0, 0), Thickness = 4, Transparency = 0.05, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = f })
	local inner = new("Frame", { Name = "InnerRim", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.new(1, -6, 1, -6), BackgroundTransparency = 1, ZIndex = f.ZIndex, Parent = f })
	new("UICorner", { CornerRadius = UDim.new(0.5, 0), Parent = inner })
	new("UIStroke", { Color = RIM_LIGHT, Thickness = 2, Transparency = 0.55, Parent = inner })
	return f, outer
end

local function outlined(label: TextLabel, thickness: number)
	new("UIStroke", { Name = "Outline", Color = Color3.fromRGB(10, 12, 20), Thickness = thickness, Parent = label })
	return label
end

function DanceWheel.build(parent: Instance)
	local player = Players.LocalPlayer
	-- a click anywhere outside the wheel closes it
	local outside = new("TextButton", { Name = "DanceWheelOutside", Text = "", AutoButtonColor = false, Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Visible = false, ZIndex = 29, Parent = parent })
	local root = new("Frame", { Name = "DanceWheel", Active = true, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(SIZE, SIZE), BackgroundTransparency = 1, Visible = false, ZIndex = 30, Parent = parent })
	local fit = new("UIScale", { Name = "FitScale", Parent = root })
	Scale.bind(fit, function() return Scale.hud(PAGE_H) end) -- (fits a phone: the whole 560 box)
	local holder = new("Frame", { Name = "Holder", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 30, Parent = root })
	local pop = new("UIScale", { Name = "Pop", Parent = holder })

	-- the centre circle: the hovered (or playing) dance's name, a line under it, and the hint
	local disc = glassCircle({ Name = "Centre", Position = UDim2.fromScale(0.5, 0.5), ZIndex = 31, Parent = holder }, CENTRE)
	local title = outlined(new("TextLabel", { Name = "Title", Text = "", FontFace = F.Heading, TextSize = 28, TextColor3 = Color3.new(1, 1, 1), TextWrapped = true, BackgroundTransparency = 1, Position = UDim2.fromOffset(22, 58), Size = UDim2.new(1, -44, 0, 62), ZIndex = 32, Parent = disc }), 2)
	local line = outlined(new("TextLabel", { Name = "Line", Text = "", FontFace = F.Heading, TextSize = 21, TextColor3 = GREEN, BackgroundTransparency = 1, Position = UDim2.fromOffset(16, 124), Size = UDim2.new(1, -32, 0, 26), ZIndex = 32, Parent = disc }), 1.5)
	local hint = outlined(new("TextLabel", { Name = "Hint", Text = "", FontFace = F.Button, TextSize = 15, TextColor3 = Color3.fromRGB(225, 228, 238), BackgroundTransparency = 1, Position = UDim2.fromOffset(16, 158), Size = UDim2.new(1, -32, 0, 20), ZIndex = 32, Parent = disc }), 1)
	local all = new("TextButton", { Name = "AllDances", Text = "ALL DANCES", FontFace = F.Button, TextSize = 13, TextColor3 = Color3.new(1, 1, 1), AutoButtonColor = false, BackgroundColor3 = GLASS, BackgroundTransparency = 0.25, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 186), Size = UDim2.fromOffset(110, 24), ZIndex = 32, Parent = disc }, { new("UICorner", { CornerRadius = UDim.new(0.5, 0) }), new("UIStroke", { Color = RIM_LIGHT, Thickness = 1, Transparency = 0.5, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }) })

	-- the slots round the ring, 1 at the top, clockwise
	local slots = {}
	local hovered: number? = nil
	local refresh: () -> ()
	for i = 1, SLOTS do
		local a = math.rad(-90 + (i - 1) * (360 / SLOTS))
		local home = UDim2.fromOffset(math.round(SIZE / 2 + math.cos(a) * RING / 2), math.round(SIZE / 2 + math.sin(a) * RING / 2))
		local circle, rim = glassCircle({ Name = "Slot" .. i, Position = home, ZIndex = 32, Parent = holder }, SLOT)
		local button = new("TextButton", { Name = "Hit", Text = "", AutoButtonColor = false, BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 36, Parent = circle })
		local num = outlined(new("TextLabel", { Name = "Key", Text = tostring(i), FontFace = F.Heading, TextSize = 22, TextColor3 = GREEN, BackgroundTransparency = 1, Position = UDim2.fromOffset(10, 4), Size = UDim2.fromOffset(22, 24), ZIndex = 35, Parent = circle }), 1.5)
		local label = outlined(new("TextLabel", { Name = "DanceName", Text = "", FontFace = F.Heading, TextSize = 15, TextColor3 = Color3.new(1, 1, 1), TextScaled = true, TextWrapped = false, BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -13), Size = UDim2.new(1, -26, 0, 18), ZIndex = 35, Parent = circle }), 1.5)
		new("UITextSizeConstraint", { MaxTextSize = 16, MinTextSize = 9, Parent = label }) -- (long names shrink to stay inside the circle)
		local grow = new("UIScale", { Name = "Hover", Parent = circle })
		local s = { circle = circle, button = button, rim = rim, label = label, num = num, grow = grow, home = home, dance = nil, pictureDance = nil, pictureChar = nil }
		slots[i] = s
		button.MouseEnter:Connect(function()
			hovered = i
			Sfx.play("ui_hover")
			TweenService:Create(grow, TweenInfo.new(0.14, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Scale = 1.08 }):Play()
			refresh()
		end)
		button.MouseLeave:Connect(function()
			if hovered == i then hovered = nil end
			TweenService:Create(grow, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Scale = 1 }):Play()
			refresh()
		end)
	end

	local open = false
	function refresh()
		local list = wheelDances()
		local playing = DancePlayer.current()
		local character = player.Character
		for i, s in slots do
			local d = list[i]
			s.dance = d and d.Id
			s.label.Text = if d then d.Name else ""
			local isOn = d ~= nil and d.Id == playing
			s.rim.Color = if isOn or hovered == i then GREEN else Color3.new(0, 0, 0)
			s.rim.Thickness = if isOn then 5 else 4
			-- the picture: your avatar in this dance's pose (rebuilt only when the dance or your avatar changes)
			if (d and d.Id) ~= s.pictureDance or character ~= s.pictureChar then
				s.pictureDance, s.pictureChar = d and d.Id, character
				local old = s.circle:FindFirstChild("Dancer")
				if old then old:Destroy() end
				local oldNote = s.circle:FindFirstChild("Note")
				if oldNote then oldNote:Destroy() end
				if d then
					local circle = s.circle
					local function note()
						Kit.icon("DancesNote", { Name = "Note", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(SLOT / 2, SLOT / 2 - 10), Size = UDim2.fromOffset(46, 46), ZIndex = 33, Parent = circle })
					end
					if character then
						DancePose.picture(circle, d.Id, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(SLOT / 2, SLOT / 2 - 8), Size = UDim2.fromOffset(84, 84), ZIndex = 33 }, false, note)
					else
						note()
					end
				end
			end
		end
		-- the centre: what you're pointing at, else what's playing
		local focus = hovered and slots[hovered]
		local fd = focus and focus.dance and Dances.get(focus.dance)
		local pd = playing and Dances.get(playing)
		if fd then
			title.Text = fd.Name
			local ready = DancePlayer.ready(fd.Id)
			line.Text = if fd.Id == playing then "Playing · click to stop" elseif not ready then "Coming soon" else "Click to dance"
		elseif focus then
			title.Text = "Empty slot"
			line.Text = "Star dances to add them"
		elseif pd then
			title.Text = pd.Name
			line.Text = "Playing"
		else
			title.Text = "Dances"
			line.Text = "Pick a dance"
		end
		line.TextColor3 = if fd and not DancePlayer.ready(fd.Id) then Color3.fromRGB(190, 196, 214) else GREEN
		hint.Text = if UserInputService.TouchEnabled then "Tap a dance" else "Click a dance (1-8)"
	end

	local function setOpen(on: boolean)
		if on == open then return end
		if on and player:GetAttribute("HuzzChoosing") == true then return end -- (the Hero pick has the screen)
		open = on
		player:SetAttribute("HuzzWheel", on) -- (local only: shift lock lets go of the mouse)
		local token = {}
		root:SetAttribute("Token", tostring(token))
		if on then
			hovered = nil
			refresh()
			root.Visible, outside.Visible = true, true
			-- grows in from the middle (no bounce), and the slots glide out one after another, clockwise
			pop.Scale = 0.86
			TweenService:Create(pop, TweenInfo.new(0.24, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), { Scale = 1 }):Play()
			local centre = UDim2.fromOffset(SIZE / 2, SIZE / 2)
			for i, sl in slots do
				sl.circle.Position = sl.home:Lerp(centre, 0.4)
				sl.grow.Scale = 1
				task.delay((i - 1) * 0.02, function()
					TweenService:Create(sl.circle, TweenInfo.new(0.3, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), { Position = sl.home }):Play()
				end)
			end
			Sfx.play("ui_open")
		else
			TweenService:Create(pop, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Scale = 0.9 }):Play()
			task.delay(0.12, function()
				if root:GetAttribute("Token") == tostring(token) then
					root.Visible, outside.Visible = false, false
				end
			end)
			Sfx.play("ui_close")
		end
	end
	DanceWheel.setOpen = setOpen

	local function playSlot(i: number)
		local s = slots[i]
		if not (s and s.dance) then
			setOpen(false)
			ModalManager.open("Dances", "Favourites")
			return
		end
		local ok, why = DancePlayer.toggle(s.dance)
		Sfx.play(if ok then "ui_click" else "ui_error")
		if not ok then
			Toast.show(why or "That dance couldn't play.")
			return
		end
		setOpen(false)
	end
	for i, s in slots do
		s.button.Activated:Connect(function() playSlot(i) end)
	end
	all.Activated:Connect(function()
		setOpen(false)
		ModalManager.open("Dances")
	end)
	outside.Activated:Connect(function() setOpen(false) end)
	DancePlayer.changed(function() if open then refresh() end end)
	State.changed(function() if open then refresh() end end)
	ModalManager.changed(function(current) if current then setOpen(false) end end)
	player:GetAttributeChangedSignal("HuzzChoosing"):Connect(function()
		if player:GetAttribute("HuzzChoosing") == true then setOpen(false) end
	end)

	UserInputService.InputBegan:Connect(function(input, processed)
		if UserInputService:GetFocusedTextBox() then return end
		local k = input.KeyCode
		if not processed and (k == Enum.KeyCode.G or k == Enum.KeyCode.ButtonY) then
			setOpen(not open)
		elseif open and k == Enum.KeyCode.Escape then
			setOpen(false)
		elseif open and not processed then
			local n = table.find({ Enum.KeyCode.One, Enum.KeyCode.Two, Enum.KeyCode.Three, Enum.KeyCode.Four, Enum.KeyCode.Five, Enum.KeyCode.Six, Enum.KeyCode.Seven, Enum.KeyCode.Eight }, k)
			if n then playSlot(n) end
		end
	end)
	refresh()
	return root
end

return DanceWheel

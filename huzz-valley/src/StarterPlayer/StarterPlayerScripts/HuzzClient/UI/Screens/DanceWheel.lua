-- The dance wheel (owner's call, Huss Valley's emote wheel): press G (gamepad Y) anywhere and a ring of 8 dance
-- slots pops up round a centre disc. Your favourite dances fill the slots first (star them in the Dances window),
-- then the rest you own. Click a slot, or press its number, to dance; the playing one glows green. The centre
-- shows what's playing, MY DANCES (opens the Dances window) and STOP. Walking away stops the dance
-- (UI/DancePlayer). G, Esc or the X closes it. While it shows, shift lock lets go of the mouse ("HuzzWheel").
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")

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
local Sfx = require(UI.Parent.Gameplay.Sfx)

local C = Theme.Colors
local F = Theme.Fonts
local new = Kit.new
local TweenService = game:GetService("TweenService")

local DanceWheel = {}

local SIZE = 560 -- the whole wheel, reference px (scaled like the HUD)
local RING = 400 -- the ring's diameter
local SLOT = Vector2.new(150, 58)
local SLOTS = 8
local PAGE_H = 347 -- the HUD reference height (as LobbyHud)
local GREEN = Color3.fromRGB(96, 232, 140)

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

function DanceWheel.build(parent: Instance)
	local player = Players.LocalPlayer
	local root = new("Frame", { Name = "DanceWheel", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(SIZE, SIZE), BackgroundTransparency = 1, Visible = false, ZIndex = 30, Parent = parent })
	local fit = new("UIScale", { Name = "FitScale", Parent = root })
	Scale.bind(fit, function() return Scale.hud(PAGE_H) end) -- (fits a phone: the whole 560 box, title and hint inside)
	local pop = new("UIScale", { Name = "Pop", Parent = new("Frame", { Name = "Holder", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 30, Parent = root }) })
	local holder = pop.Parent :: Frame

	-- the ring: a thin see-through circle behind the slots
	local ring = new("Frame", { Name = "Ring", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(RING, RING), BackgroundColor3 = C.Frame, BackgroundTransparency = 0.55, ZIndex = 30, Parent = holder }, { new("UICorner", { CornerRadius = UDim.new(0.5, 0) }) })
	Kit.attach(Kit.stroke(C.RowBorder, 3, 0.2), ring)
	Kit.studPattern(ring, 0.25)

	-- the centre disc: what's playing, MY DANCES, STOP
	local disc = new("Frame", { Name = "Centre", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(188, 188), BackgroundColor3 = C.Panel, BackgroundTransparency = 0.15, ZIndex = 31, Parent = holder }, { new("UICorner", { CornerRadius = UDim.new(0.5, 0) }) })
	Kit.attach(Kit.stroke(C.Frame, 3), disc)
	Kit.studPattern(disc, 0.25)
	local nowLabel = Kit.text({ Name = "Now", Text = "", FontFace = F.Button, TextSize = 13, TextColor3 = C.SubText, TextXAlignment = Enum.TextXAlignment.Center, Position = UDim2.fromOffset(14, 28), Size = UDim2.new(1, -28, 0, 16), ZIndex = 32, Parent = disc })
	local nowName = Kit.name({ Name = "Playing", Text = "", TextSize = 19, TextXAlignment = Enum.TextXAlignment.Center, Position = UDim2.fromOffset(10, 46), Size = UDim2.new(1, -20, 0, 26), ZIndex = 32, Parent = disc })
	local mine = Kit.button({ Name = "MyDances", Text = "MY DANCES", TextSize = 15, Style = "Tab", Position = UDim2.fromOffset(24, 88), Size = UDim2.fromOffset(140, 32), ZIndex = 32, Parent = disc })
	local stop = Kit.button({ Name = "Stop", Text = "STOP", TextSize = 16, Style = "Action", Position = UDim2.fromOffset(24, 128), Size = UDim2.fromOffset(140, 34), ZIndex = 32, Parent = disc })

	-- heading and hint
	Kit.title({ Name = "Title", Text = "DANCES", TextSize = 30, Position = UDim2.fromOffset(18, 18), Size = UDim2.fromOffset(170, 36), ZIndex = 32, Parent = holder })
	local hint = Kit.text({ Name = "Hint", Text = "", FontFace = F.Button, TextSize = 15, TextColor3 = C.NoteText, TextXAlignment = Enum.TextXAlignment.Center, AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -2), Size = UDim2.fromOffset(SIZE, 20), TextWrapped = false, ZIndex = 32, Parent = holder })
	Kit.attach(Kit.stroke(C.Frame, 1.2), hint)
	local close = Kit.closeButton({ AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -40, 0, 30), Parent = holder })

	-- the slots round the ring, 1 at the top, clockwise
	local slots = {}
	for i = 1, SLOTS do
		local a = math.rad(-90 + (i - 1) * (360 / SLOTS))
		local cx, cy = SIZE / 2 + math.cos(a) * RING / 2, SIZE / 2 + math.sin(a) * RING / 2
		local b = Kit.button({ Name = "Slot" .. i, Text = "", Style = "Row", Position = UDim2.fromOffset(math.round(cx - SLOT.X / 2), math.round(cy - SLOT.Y / 2)), Size = UDim2.fromOffset(SLOT.X, SLOT.Y), Corner = 6, ZIndex = 32, Parent = holder })
		local num = Kit.text({ Name = "Key", Text = tostring(i), FontFace = F.Number, TextSize = 13, TextColor3 = C.SelectedTab, Position = UDim2.fromOffset(8, 4), Size = UDim2.fromOffset(16, 14), ZIndex = 33, Parent = b.Instance })
		local label = Kit.name({ Name = "DanceName", Text = "", TextSize = 16, TextXAlignment = Enum.TextXAlignment.Center, Position = UDim2.fromOffset(8, 10), Size = UDim2.new(1, -16, 0, 22), ZIndex = 33, Parent = b.Instance })
		local sub = Kit.text({ Name = "Sub", Text = "", FontFace = F.Button, TextSize = 12, TextColor3 = C.SubText, TextXAlignment = Enum.TextXAlignment.Center, Position = UDim2.fromOffset(8, 33), Size = UDim2.new(1, -16, 0, 16), TextWrapped = false, ZIndex = 33, Parent = b.Instance })
		local rim = b.Instance:FindFirstChild("Rim") :: UIStroke
		slots[i] = { button = b, label = label, sub = sub, num = num, rim = rim, dance = nil }
	end

	local open = false
	local function refresh()
		local list = wheelDances()
		local playing = DancePlayer.current()
		for i, s in slots do
			local d = list[i]
			s.dance = d and d.Id
			s.label.Text = if d then d.Name else "EMPTY"
			s.label.TextTransparency = if d then 0 else 0.5
			local isOn = d ~= nil and d.Id == playing
			local ready = d ~= nil and DancePlayer.ready(d.Id)
			s.sub.Text = if isOn then "PLAYING · WALK AWAY" elseif d and not ready then "COMING SOON" elseif d then "" else "STAR ONE IN MY DANCES"
			s.sub.TextColor3 = if isOn then GREEN else C.SubText
			s.label.Position = UDim2.fromOffset(8, if s.sub.Text == "" then 18 else 10)
			if s.rim then
				s.rim.Color = if isOn then GREEN else C.RowBorder
				s.rim.Thickness = if isOn then 3 else 1
			end
		end
		local d = playing and Dances.get(playing)
		nowLabel.Text = if d then "NOW PLAYING" else "PICK A DANCE"
		nowName.Text = if d then d.Name else ""
		stop.setStyle(if d then "Action" else "Disabled")
		hint.Text = if UserInputService.TouchEnabled then "TAP A DANCE · WALK AWAY TO STOP" else "CLICK OR PRESS 1-8 · WALK AWAY TO STOP · G TO CLOSE"
	end

	local function setOpen(on: boolean)
		if on == open then return end
		if on and player:GetAttribute("HuzzChoosing") == true then return end -- (the Hero pick has the screen)
		open = on
		player:SetAttribute("HuzzWheel", on) -- (local only: shift lock lets go of the mouse)
		if on then
			refresh()
			root.Visible = true
			pop.Scale = 0.85
			TweenService:Create(pop, TweenInfo.new(0.28, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
			Sfx.play("ui_open")
		else
			root.Visible = false
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
		if not ok then
			Toast.show(why or "That dance couldn't play.")
			return
		end
		setOpen(false)
	end
	for i, s in slots do
		s.button.onClick(function() playSlot(i) end)
	end
	mine.onClick(function()
		setOpen(false)
		ModalManager.open("Dances")
	end)
	stop.onClick(function() DancePlayer.stop() end)
	close.onClick(function() setOpen(false) end)
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

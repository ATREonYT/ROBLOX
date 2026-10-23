-- "Join our group" window (owner, Oct 22 19:09: "make a 'join the group' ui pop up for a reward in the style of our
-- ui, and make the reward 5 free spins on the wheel"). Laid out after his picture (Oct 23 16:26,
-- design/owner-oct23/free-spins-ref.png): FREE in white and SPINS in pink with a sparkle in the header; a sky-blue
-- body with pink petals drifting up; the wheel big in the middle in a pink glow and turning rays, a knife tile on its
-- left and a coins tile on its right (each tilted and rocking a little); "+5 SPINS" big and pink, one line, and one
-- wide JOIN GROUP button. JOIN GROUP opens Roblox's own join prompt (GroupService:PromptJoinAsync, guarded: not every
-- device or Studio has it), then claims by itself: the server checks with Roblox that you're in the group and gives
-- the spins once (ActionService "ClaimGroup" -> ProgressService.claimGroup); already in it, the same button claims.
-- His picture's girl and player hugging on the left need his art as a transparent PNG (the slot "Pair" waits for it).
-- It opens by itself once per visit, Config/Group.PopupAfter seconds into the lobby, while the spins aren't claimed
-- (like How to Play: never over a round or another window). The lobby's GROUP button (Screens/LobbyHud) opens it too.
-- With no group set (Config/Group.Id 0): the button says COMING SOON and does nothing, and it never pops up live
-- (in Studio it still does, so you can see it).
local Players = game:GetService("Players")
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Group = require(Shared.Config.Group)
local UI = script.Parent.Parent
local Theme = require(UI.Theme)
local Kit = require(UI.Kit)
local State = require(UI.State)
local Toast = require(UI.Toast)
local ModalManager = require(UI.ModalManager)
local Motion = require(UI.Motion)
local Effects = require(UI.Effects)

local new = Kit.new
local C, F = Theme.Colors, Theme.Fonts

local GroupRewardScreen = {}

local W, H = 500, 392

-- A four-point sparkle made of parts (the "\u{2726}" glyph showed as a box in Roblox's font: owner's screenshot,
-- Oct 23 17:48): two crossed bars that fade to points, and a small glow dot in the middle.
local function sparkle(parent: Instance, size: number, pos: UDim2, z: number, name: string?): Frame
	local f = new("Frame", { Name = name or "Sparkle", AnchorPoint = Vector2.new(0.5, 0.5), Position = pos, Size = UDim2.fromOffset(size, size), BackgroundTransparency = 1, ZIndex = z, Parent = parent })
	local thick = math.max(2, math.round(size / 7))
	for i, rot in { 0, 90 } do
		local bar = new("Frame", { Name = "Bar" .. i, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(thick, size), Rotation = rot, BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, ZIndex = z, Parent = f }, { Kit.corner(thick // 2) })
		new("UIGradient", { Name = "Points", Rotation = 90, Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.5, 0), NumberSequenceKeypoint.new(1, 1) }), Parent = bar })
	end
	local dot = math.max(4, math.round(size / 3.5))
	new("Frame", { Name = "Core", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(dot, dot), Rotation = 45, BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, ZIndex = z, Parent = f }, { Kit.corner(1) })
	return f
end

local function line(props: { [string]: any }, stroke: number?): TextLabel
	props.TextWrapped = props.TextWrapped == true
	local l = Kit.text(props)
	new("UIStroke", { Name = "Outline", Color = C.TitleStroke, Thickness = stroke or 1.5, LineJoinMode = Enum.LineJoinMode.Round, Parent = l })
	return l
end

function GroupRewardScreen.set(): boolean return (tonumber(Group.Id) or 0) > 0 end

function GroupRewardScreen.build(parent: Instance)
	local player = Players.LocalPlayer
	local window = Kit.window({ Name = "GroupReward", Title = " ", Icon = "SpinWheel", Width = W, Height = H, TitleX = 56, TitleWidth = 0, StudsTo = 0, Parent = parent, OnClose = function() ModalManager.close() end })
	local panel = window.Panel
	-- the header words: FREE white, SPINS pink, a sparkle
	local words = new("Frame", { Name = "Words", Position = UDim2.fromOffset(56, 0), Size = UDim2.new(0, 280, 1, 0), BackgroundTransparency = 1, ZIndex = 3, Parent = window.Header }, { Kit.list(Enum.FillDirection.Horizontal, 6, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Center) })
	line({ Name = "Free", Text = "FREE", FontFace = F.Heading, TextSize = 28, AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromOffset(0, 34), LayoutOrder = 1, ZIndex = 3, Parent = words }, 2.5)
	local spins = line({ Name = "Spins", Text = "SPINS", FontFace = F.Heading, TextSize = 28, AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromOffset(0, 34), LayoutOrder = 2, ZIndex = 3, Parent = words }, 2.5)
	new("UIGradient", { Name = "Shade", Rotation = 90, Color = ColorSequence.new(Color3.fromHex("FFD2F2"), Color3.fromHex("FF5FC8")), Parent = spins })
	local sparkBox = new("Frame", { Name = "Spark", Size = UDim2.fromOffset(26, 34), BackgroundTransparency = 1, LayoutOrder = 3, ZIndex = 3, Parent = words })
	local spark = sparkle(sparkBox, 22, UDim2.fromOffset(11, 15), 3)
	sparkle(sparkBox, 10, UDim2.fromOffset(21, 27), 3, "Small")
	Effects.breathe(spark, { scale = 1.25, seconds = 0.9 })

	-- the sky-blue body (his picture's backdrop is a painted temple; ours a soft sky until he sends it as a PNG)
	local bodyH = H - 47
	local sky = new("Frame", { Name = "Sky", Position = UDim2.fromOffset(4, 47), Size = UDim2.fromOffset(W - 8, bodyH - 4), BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, ZIndex = 2, Parent = panel }, { Kit.corner(4) })
	new("UIGradient", { Name = "Shade", Rotation = 90, Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, Color3.fromHex("78B4F4")), ColorSequenceKeypoint.new(0.55, Color3.fromHex("8C90DE")), ColorSequenceKeypoint.new(1, Color3.fromHex("5C5AA8")) }), Parent = sky })
	Effects.motes(sky, { colour = Color3.fromHex("FF9FD6"), shape = "petal", count = 9, area = Rect.new(10, 10, W - 18, bodyH - 14), rise = 70, z = 3, seed = 4 })
	-- the slot for his girl-and-player picture (empty until he sends it)
	new("Frame", { Name = "Pair", Position = UDim2.fromOffset(0, bodyH - 190), Size = UDim2.fromOffset(150, 186), BackgroundTransparency = 1, ZIndex = 4, Parent = sky })

	-- the wheel in a pink glow, with turning rays; a knife tile left, a coins tile right
	local CX, CY = W // 2, 47 + 104
	local rays = Effects.rays(panel, UDim2.fromOffset(CX, CY), 230, { color = Color3.fromHex("FF8AD8"), transparency = 0.45, seconds = 12, z = 3, name = "Rays" })
	-- a pink glow round the wheel: three soft rings, brightest inside
	for i, g in { { 160, 4, 0.05 }, { 172, 5, 0.5 }, { 186, 6, 0.78 } } do
		new("Frame", { Name = "Glow" .. i, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(CX, CY), Size = UDim2.fromOffset(g[1], g[1]), BackgroundTransparency = 1, ZIndex = 4, Parent = panel }, { Kit.corner(g[1] // 2), Kit.stroke(Color3.fromHex("FF6FD0"), g[2], g[3]) })
	end
	-- (it stays still, as in his picture: turning it turned its pointer away from the top too, Oct 23 17:48)
	local wheel = Kit.icon("SpinWheel", { Name = "Wheel", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(CX, CY), Size = UDim2.fromOffset(150, 150), ZIndex = 5, Parent = panel })
	Effects.breathe(wheel, { scale = 1.03, seconds = 1.6 })
	local spinning = false
	local function tile(name: string, x: number, tilt: number, delay: number)
		-- (a tilted holder, so the tile rocks round its tilt: Effects.rock sets the tile's own Rotation)
		-- (his picture: a deep navy tile lit purple at the top, a bright violet rim, a sparkle in its corner)
		local holder = new("Frame", { Name = name, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(x, CY - 14), Size = UDim2.fromOffset(92, 92), Rotation = tilt, BackgroundTransparency = 1, ZIndex = 4, Parent = panel })
		local t = new("Frame", { Name = "Tile", Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, ZIndex = 4, Parent = holder }, { Kit.corner(12), Kit.stroke(Color3.fromHex("A98BFF"), 3) })
		new("UIGradient", { Name = "Shade", Rotation = 90, Color = ColorSequence.new(Color3.fromHex("3A2C8C"), Color3.fromHex("141238")), Parent = t })
		sparkle(t, 16, UDim2.fromOffset(18, 18), 6, "Corner")
		Effects.rock(t, { degrees = 3, seconds = 1.8, delay = delay })
		return t
	end
	local knifeTile = tile("KnifeTile", CX - 150, -10, 0)
	-- (his knife picture has its own dark backdrop: it fills the tile, rounded like it, so no square shows past the rim)
	local knife = Kit.art("KnifeCovenKatana", { Name = "Knife", Size = UDim2.fromScale(1, 1), ScaleType = Enum.ScaleType.Crop, ZIndex = 5, Parent = knifeTile })
	Kit.attach(Kit.corner(12), knife)
	local corner = knifeTile:FindFirstChild("Corner")
	if corner and corner:IsA("GuiObject") then corner.ZIndex = 7; for _, d in corner:GetDescendants() do if d:IsA("GuiObject") then d.ZIndex = 7 end end end
	local coinTile = tile("CoinsTile", CX + 150, 10, 0.9)
	Kit.icon("CurrencyCoin", { Name = "Coins", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(62, 62), ZIndex = 5, Parent = coinTile })
	-- sparkles round the wheel, twinkling in turn
	for i, sp in { { CX + 96, CY - 70, 18 }, { CX - 92, CY + 62, 14 }, { CX + 88, CY + 58, 10 } } do
		local st = sparkle(panel, sp[3], UDim2.fromOffset(sp[1], sp[2]), 6, "Twinkle" .. i)
		Effects.breathe(st, { scale = 1.35, seconds = 0.8 + i * 0.25 })
	end

	-- +5 SPINS, the line, JOIN GROUP
	local amount = line({ Name = "Amount", Text = "+" .. Group.Spins .. " SPINS", FontFace = F.Heading, TextSize = 48, TextXAlignment = Enum.TextXAlignment.Center, Position = UDim2.fromOffset(16, CY + 82), Size = UDim2.fromOffset(W - 32, 50), ZIndex = 6, Parent = panel }, 3)
	new("UIGradient", { Name = "Shade", Rotation = 90, Color = ColorSequence.new(Color3.fromHex("FFE2F6"), Color3.fromHex("FF5FC8")), Parent = amount })
	local name = if Group.Name ~= "" then Group.Name else "our group"
	local about = line({ Name = "About", Text = "Join " .. name .. " and get " .. Group.Spins .. " free spins on the wheel!", FontFace = F.Name, TextSize = 17, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Center, Position = UDim2.fromOffset(110, CY + 130), Size = UDim2.fromOffset(W - 220, 42), ZIndex = 6, Parent = panel })
	local join = Kit.button({ Name = "Join", Text = "JOIN GROUP", Icon = "Players", IconSize = 32, Style = "Action", FontFace = F.Button, TextSize = 26, Corner = 9, RimThickness = 2.5, AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -14), Size = UDim2.fromOffset(W - 90, 50), ZIndex = 6, Parent = panel })

	local pending = false
	local function refresh()
		local got = State.data.GroupReward == true
		if not GroupRewardScreen.set() then
			join.setText("COMING SOON"); join.setStyle("Disabled"); join.setEnabled(false)
		elseif got then
			about.Text = "Thanks for joining! Your spins are on the wheel."
			join.setText("CLAIMED"); join.setStyle("Disabled"); join.setEnabled(false)
		else
			about.Text = "Join " .. name .. " and get " .. Group.Spins .. " free spins on the wheel!"
			join.setText(if pending then "..." else "JOIN GROUP"); join.setStyle("Action"); join.setEnabled(not pending)
		end
		rays.Visible = not got
	end

	-- Roblox's join prompt, then the claim (the server checks with Roblox); already in the group, it just claims
	local function claim()
		local ok, why = State.action("ClaimGroup")
		if ok then
			Toast.show("+" .. Group.Spins .. " spins on the wheel!")
			Motion.pop(amount)
		end
		return ok, why
	end
	join.onClick(function()
		if pending or State.data.GroupReward == true or not GroupRewardScreen.set() then return end
		pending = true
		refresh()
		task.spawn(function()
			local ok = claim() -- (already a member: done)
			if not ok then
				local opened = pcall(function() game:GetService("GroupService"):PromptJoinAsync(Group.Id) end)
				if opened then
					local done, why = claim()
					if not done then Toast.show(why or "Join the group, then press JOIN GROUP again to get your spins.") end
				else
					Toast.show("The join window can't open here. Find " .. name .. " on our game's page, join it, then press JOIN GROUP again.")
				end
			end
			pending = false
			refresh()
		end)
	end)

	local open = false
	ModalManager.register("GroupReward", {
		window = window,
		onOpen = function() open = true; spinning = true; refresh() end,
		onClose = function() open = false; spinning = false end,
		firstSelect = function() return join.Instance end,
	})
	State.changed(function() if open then refresh() end end)
	refresh()

	-- By itself: once per visit, PopupAfter seconds after the save loaded, in the lobby with nothing else open
	-- (if a round or a window is in the way, it waits for the lobby). Never live with no group set.
	local studio = game:GetService("RunService"):IsStudio()
	local shown, due, timer = false, nil, false
	local function free(): boolean
		local role = player:GetAttribute("HuzzRole")
		return ModalManager.current() == nil and role ~= "Runner" and role ~= "Catcher"
	end
	local function maybeOpen()
		if shown or timer or not State.data.Loaded or State.data.GroupReward == true then return end
		if not (GroupRewardScreen.set() or studio) then return end
		due = due or os.clock() + Group.PopupAfter
		timer = true
		task.delay(math.max(due - os.clock(), 0) + 0.05, function()
			timer = false
			if shown or State.data.GroupReward == true then return end
			if free() then -- (else the next lobby moment or closed window looks again)
				shown = true
				ModalManager.open("GroupReward")
			end
		end)
	end
	State.changed(maybeOpen)
	ModalManager.changed(function() task.defer(maybeOpen) end)
	player:GetAttributeChangedSignal("HuzzRole"):Connect(maybeOpen)
	maybeOpen()
	return window.Holder
end

return GroupRewardScreen

-- "Join our group" window (owner, Oct 22 19:09: "make a 'join the group' ui pop up for a reward in the style of our
-- ui, and make the reward 5 free spins on the wheel"). Laid out after his picture (Oct 23 16:26,
-- design/owner-oct23/free-spins-ref.png): FREE in white and SPINS in pink with a sparkle in the header; a sky-blue
-- body with pink petals drifting up; the wheel big in the middle in a pink glow and turning rays, a knife tile on its
-- left and a coins tile on its right (each tilted and rocking a little); "+5 SPINS" big and pink, one line, and one
-- wide JOIN GROUP button. JOIN GROUP opens Roblox's own join prompt (GroupService:PromptJoinAsync, guarded: not every
-- device or Studio has it), then claims by itself: the server checks with Roblox that you're in the group and gives
-- the spins once (ActionService "ClaimGroup" -> ProgressService.claimGroup); already in it, the same button claims.
-- Since Oct 23 19:33 laid out after his second picture (design/owner-oct23/group-reward-ref2.png): the scenery, the
-- girl hugging the player and the player with a red katana, four tiles round the wheel, a status line and two buttons
-- (JOIN GROUP and CLAIM SPINS). Since Oct 23 21:22 ("make it claim the spins only when you join the group, and make
-- them automatically add, so you cant just claim them") only JOIN GROUP: the server adds the spins by itself once
-- Roblox says you're in the group (HuzzServer/ProgressService.watchGroup), and this window just says so.
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

local W, H = 560, 386

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
	line({ Name = "Free", Text = "FREE", FontFace = F.Heading, TextSize = 32, AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromOffset(0, 34), LayoutOrder = 1, ZIndex = 3, Parent = words }, 2.5)
	local spins = line({ Name = "Spins", Text = "SPINS", FontFace = F.Heading, TextSize = 32, AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromOffset(0, 34), LayoutOrder = 2, ZIndex = 3, Parent = words }, 2.5)
	new("UIGradient", { Name = "Shade", Rotation = 90, Color = ColorSequence.new(Color3.fromHex("FFD2F2"), Color3.fromHex("FF5FC8")), Parent = spins })
	local sparkBox = new("Frame", { Name = "Spark", Size = UDim2.fromOffset(26, 34), BackgroundTransparency = 1, LayoutOrder = 3, ZIndex = 3, Parent = words })
	local spark = sparkle(sparkBox, 22, UDim2.fromOffset(11, 15), 3)
	sparkle(sparkBox, 10, UDim2.fromOffset(21, 27), 3, "Small")
	Effects.breathe(spark, { scale = 1.25, seconds = 0.9 })

	-- His second picture (Oct 23 19:33, design/owner-oct23/group-reward-ref2.png: "please use the reference to make the
	-- group join ui"), measured and scaled to this 560-wide window (his is 1240: x 0.4516, the body 14 higher for our
	-- shorter header). The scenery, the girl hugging the player (left) and the player with the red katana (right) are
	-- cut from his picture (tools/icons/make_group_art.py) until he sends them as transparent PNGs.
	local bodyH = H - 47
	local back = Kit.art("GroupBackdrop", { Name = "Backdrop", Position = UDim2.fromOffset(4, 47), Size = UDim2.fromOffset(W - 8, bodyH - 4), ScaleType = Enum.ScaleType.Crop, ZIndex = 2, Parent = panel })
	Kit.attach(Kit.corner(4), back)
	local sky = new("Frame", { Name = "Sky", Position = UDim2.fromOffset(4, 47), Size = UDim2.fromOffset(W - 8, bodyH - 4), BackgroundTransparency = 1, ZIndex = 2, Parent = panel })
	Effects.motes(sky, { colour = Color3.fromHex("FF9FD6"), shape = "petal", count = 9, area = Rect.new(10, 10, W - 18, bodyH - 14), rise = 70, z = 3, seed = 4 })
	local pair = Kit.art("GroupPair", { Name = "Pair", Position = UDim2.fromOffset(4, 71), Size = UDim2.fromOffset(159, 246), ScaleType = Enum.ScaleType.Fit, ZIndex = 4, Parent = panel })
	Effects.breathe(pair, { scale = 1.02, seconds = 2.2 })
	local fighter = Kit.art("GroupFighter", { Name = "Fighter", Position = UDim2.fromOffset(W - 4 - 146, 127), Size = UDim2.fromOffset(146, 217), ScaleType = Enum.ScaleType.Fit, ZIndex = 4, Parent = panel })
	Effects.breathe(fighter, { scale = 1.02, seconds = 2.6 })

	-- the wheel in a pink glow, with turning rays; four tilted tiles round it: a knife and a gem left, coins and a
	-- mystery "?" right (his picture)
	local CX, CY = 297, 145
	local rays = Effects.rays(panel, UDim2.fromOffset(CX, CY), 210, { color = Color3.fromHex("FF8AD8"), transparency = 0.45, seconds = 12, z = 3, name = "Rays" })
	for i, g in { { 144, 4, 0.05 }, { 154, 5, 0.5 }, { 166, 6, 0.78 } } do
		new("Frame", { Name = "Glow" .. i, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(CX, CY), Size = UDim2.fromOffset(g[1], g[1]), BackgroundTransparency = 1, ZIndex = 5, Parent = panel }, { Kit.corner(g[1] // 2), Kit.stroke(Color3.fromHex("FF6FD0"), g[2], g[3]) })
	end
	-- (it stays still, as in his picture: turning it turned its pointer away from the top too, Oct 23 17:48)
	local wheel = Kit.icon("SpinWheel", { Name = "Wheel", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(CX, CY), Size = UDim2.fromOffset(132, 132), ZIndex = 6, Parent = panel })
	Effects.breathe(wheel, { scale = 1.03, seconds = 1.6 })
	local spinning = false
	local function tile(name: string, x: number, y: number, size: number, tilt: number, delay: number)
		-- (a tilted holder, so the tile rocks round its tilt: Effects.rock sets the tile's own Rotation)
		-- (his picture: a deep navy tile lit purple at the top, a bright violet rim, a sparkle in its corner)
		local holder = new("Frame", { Name = name, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(x, y), Size = UDim2.fromOffset(size, size), Rotation = tilt, BackgroundTransparency = 1, ZIndex = 5, Parent = panel })
		local t = new("Frame", { Name = "Tile", Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, ZIndex = 5, Parent = holder }, { Kit.corner(8), Kit.stroke(Color3.fromHex("A98BFF"), 2.5) })
		new("UIGradient", { Name = "Shade", Rotation = 90, Color = ColorSequence.new(Color3.fromHex("3A2C8C"), Color3.fromHex("141238")), Parent = t })
		sparkle(t, 12, UDim2.fromOffset(13, 13), 8, "Corner")
		Effects.rock(t, { degrees = 3, seconds = 1.8, delay = delay })
		return t
	end
	local knifeTile = tile("KnifeTile", 183, 102, 60, -15, 0)
	-- (his knife picture has its own dark backdrop: it fills the tile, rounded like it, so no square shows past the rim)
	local knife = Kit.art("KnifeCovenKatana", { Name = "Knife", Size = UDim2.fromScale(1, 1), ScaleType = Enum.ScaleType.Crop, ZIndex = 6, Parent = knifeTile })
	Kit.attach(Kit.corner(8), knife)
	local gemTile = tile("GemTile", 200, 178, 50, -12, 0.5)
	Kit.icon("CurrencyGem", { Name = "Gem", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(32, 32), ZIndex = 6, Parent = gemTile })
	local coinTile = tile("CoinsTile", 410, 100, 60, 15, 0.9)
	Kit.icon("CurrencyCoin", { Name = "Coins", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(40, 40), ZIndex = 6, Parent = coinTile })
	local mysteryTile = tile("MysteryTile", 398, 178, 50, 12, 1.3)
	local mark = line({ Name = "Mystery", Text = "?", FontFace = F.Heading, TextSize = 34, TextXAlignment = Enum.TextXAlignment.Center, Size = UDim2.fromScale(1, 1), ZIndex = 6, Parent = mysteryTile }, 2.5)
	new("UIGradient", { Name = "Shade", Rotation = 90, Color = ColorSequence.new(Color3.fromHex("FFE2F6"), Color3.fromHex("C08BFF")), Parent = mark })
	for _, t in { knifeTile, gemTile, coinTile, mysteryTile } do
		local corner = t:FindFirstChild("Corner")
		if corner and corner:IsA("GuiObject") then corner.ZIndex = 8; for _, d in corner:GetDescendants() do if d:IsA("GuiObject") then d.ZIndex = 8 end end end
	end
	-- sparkles round the wheel, twinkling in turn
	for i, sp in { { CX + 38, CY - 78, 14 }, { CX + 54, CY - 70, 9 }, { CX - 30, CY - 80, 8 } } do
		local st = sparkle(panel, sp[3], UDim2.fromOffset(sp[1], sp[2]), 7, "Twinkle" .. i)
		Effects.breathe(st, { scale = 1.35, seconds = 0.8 + i * 0.25 })
	end

	-- +5 SPINS, the line, the status line, JOIN GROUP and CLAIM side by side
	local amount = line({ Name = "Amount", Text = "+" .. Group.Spins .. " SPINS", FontFace = F.Heading, TextSize = 46, TextXAlignment = Enum.TextXAlignment.Center, Position = UDim2.fromOffset(26, 206), Size = UDim2.fromOffset(W - 32, 50), ZIndex = 7, Parent = panel }, 3)
	new("UIGradient", { Name = "Shade", Rotation = 90, Color = ColorSequence.new(Color3.fromHex("FFE2F6"), Color3.fromHex("FF5FC8")), Parent = amount })
	local name = if Group.Name ~= "" then Group.Name else "our group"
	local about = line({ Name = "About", Text = "Join " .. name .. " and get " .. Group.Spins .. " free spins on the wheel!", FontFace = F.Name, TextSize = 16, TextXAlignment = Enum.TextXAlignment.Center, Position = UDim2.fromOffset(20, 261), Size = UDim2.fromOffset(W - 40, 22), ZIndex = 7, Parent = panel }, 2)
	local status = Kit.text({ Name = "Status", Text = "", FontFace = F.Body, TextSize = 14, TextXAlignment = Enum.TextXAlignment.Center, TextColor3 = Color3.fromHex("DCE6FF"), Position = UDim2.fromOffset(20, 286), Size = UDim2.fromOffset(W - 40, 18), ZIndex = 7, Parent = panel })
	new("UIStroke", { Name = "Outline", Color = Color3.fromHex("1A1F4A"), Thickness = 1, Transparency = 0.4, Parent = status })
	local join = Kit.button({ Name = "Join", Text = "JOIN GROUP", Icon = "Players", IconSize = 26, Style = "Action", FontFace = F.Button, TextSize = 22, Corner = 9, RimThickness = 2.5, Position = UDim2.fromOffset(130, 317), Size = UDim2.fromOffset(300, 56), ZIndex = 7, Parent = panel })
	Kit.place(join.Instance, UDim2.fromOffset(130, 317), UDim2.fromOffset(300, 56)) -- (saved places have it at the left)
	local oldClaim = panel:FindFirstChild("Claim") -- (the CLAIM SPINS button before: saved places still have it)
	if oldClaim then oldClaim:Destroy() end

	local pending = false
	local function refresh()
		local got = State.data.GroupReward == true
		if not GroupRewardScreen.set() then
			status.Text = "Our group is coming soon. Check back later!"
			join.setText("COMING SOON"); join.setStyle("Disabled"); join.setEnabled(false)
		elseif got then
			about.Text = "Thanks for joining " .. name .. "!"
			status.Text = "Your " .. Group.Spins .. " spins are on the wheel."
			join.setText("JOINED"); join.setStyle("Disabled"); join.setEnabled(false)
		else
			about.Text = "Join " .. name .. " and get " .. Group.Spins .. " free spins on the wheel!"
			status.Text = "Once you're in the group, your spins are added by themselves."
			join.setText(if pending then "..." else "JOIN GROUP"); join.setStyle("Action"); join.setEnabled(not pending)
		end
		rays.Visible = not got
	end

	-- JOIN GROUP: Roblox's join prompt; when it closes the server looks at once (it only gives the spins to a member;
	-- it also looks by itself every Group.CheckEvery seconds, for someone who joins on the group's page instead)
	join.onClick(function()
		if pending or State.data.GroupReward == true or not GroupRewardScreen.set() then return end
		pending = true
		refresh()
		task.spawn(function()
			local opened = pcall(function() game:GetService("GroupService"):PromptJoinAsync(Group.Id) end)
			if not opened then
				Toast.show("The join window can't open here. Find " .. name .. " on our game's page and join it: your spins come by themselves.")
			end
			State.action("ClaimGroup") -- (the server checks with Roblox; nothing for someone not in the group)
			pending = false
			refresh()
		end)
	end)
	-- the moment the server adds them: a toast and a pop (not when the save just loads with them)
	local had = State.data.Loaded == true and State.data.GroupReward == true
	local loaded = State.data.Loaded == true
	State.changed(function()
		local now = State.data.GroupReward == true
		if loaded and now and not had then
			Toast.show("Thanks for joining " .. name .. "! +" .. Group.Spins .. " spins on the wheel!")
			Motion.pop(amount)
		end
		had, loaded = now, State.data.Loaded == true
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

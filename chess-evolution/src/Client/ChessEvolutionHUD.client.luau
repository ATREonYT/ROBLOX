--!nonstrict
-- +1 Chess Evolution: drives StarterGui.ChessEvolutionUI (the Figma kit UI).
-- The server owns every number: this script shows State and sends the same requests the old
-- loop panels sent. Gameplay UI (TRAIN button, duels, guide, toasts, Chess Sets / Board /
-- Settings / Codes panels) stays in ChessClient and LoopClient; their old HUD chrome is hidden.
-- Changing text is drawn with GlyphText so it matches the baked label art. Errors: [ChessUI] lines.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local SocialService = game:GetService("SocialService")

local player = Players.LocalPlayer
local Kit = ReplicatedStorage:WaitForChild("Kit")
local Net = require(Kit:WaitForChild("Net"))
local Format = require(Kit:WaitForChild("Format"))
local Models = require(Kit:WaitForChild("Models"))
local Config = require(ReplicatedStorage:WaitForChild("ChessConfig"))
local UI = ReplicatedStorage:WaitForChild("ChessEvolutionUI")
local GT = require(UI:WaitForChild("GlyphText"))
local OpenPanel = UI:WaitForChild("OpenPanel") :: BindableEvent

local playerGui = player:WaitForChild("PlayerGui")
local gui = playerGui:WaitForChild("ChessEvolutionUI") :: ScreenGui
local HUD = gui:WaitForChild("HUD")

local function log(msg: string)
	print(`[ChessUI] {msg}`)
end

local IMG = {
	Check = "rbxassetid://79818029552460",
	Lock = "rbxassetid://120277075611058",
	Trophy = "rbxassetid://127446727256103",
	Gift = "rbxassetid://74465164792919",
	Cursor = "rbxassetid://80974016701834",
	EloCoin = "rbxassetid://76114510634179",
}
local GREEN = Color3.fromRGB(154, 255, 36)
local RED = Color3.fromRGB(255, 70, 72)
local GOLD = Color3.fromRGB(255, 206, 66)
local CYAN = Color3.fromRGB(53, 233, 255)

local S: any = { loaded = false }
local helloAt = os.clock()

local function fmt(n: number): string
	local ok, s = pcall(Format.Short, n)
	return if ok and s then s else tostring(math.floor(n))
end
local function mult(x: number): string
	local s = string.format("%.2f", x):gsub("0+$", ""):gsub("%.$", "")
	return s
end
local function commas(n: number): string
	local s = tostring(math.floor(n))
	while true do
		local k
		s, k = string.gsub(s, "^(%d+)(%d%d%d)", "%1,%2")
		if k == 0 then
			return s
		end
	end
end
local function eloName(label: string): string
	return (string.gsub(label, "Power", "Elo"))
end

---------------------------------------------------------------------------
-- Text and buttons
---------------------------------------------------------------------------
-- Writes text into a kit label: hides the baked image and draws the `_Live` twin with GlyphText.
local function text(screen: Instance, name: string, value: string, color: Color3?)
	local img = screen:FindFirstChild(name, true)
	local live = screen:FindFirstChild(name .. "_Live", true)
	if not live and img and img:IsA("TextLabel") then
		live = img
		img = nil
	end
	if not live then
		return
	end
	if img then
		(img :: GuiObject).Visible = false
	end
	local ok, err = pcall(GT.Set, live, value, color)
	if not ok then
		warn(`[ChessUI] text {name}: {err}`)
	end
end

local function image(screen: Instance, name: string, id: string)
	local o = screen:FindFirstChild(name, true)
	if o and (o:IsA("ImageLabel") or o:IsA("ImageButton")) then
		o.Image = id
		o.ScaleType = Enum.ScaleType.Fit
	end
end

local BACK = TweenInfo.new(0.28, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
local function button(screen: Instance, name: string, fn: () -> ())
	local b = screen:FindFirstChild(name, true)
	if not b or not b:IsA("GuiButton") then
		warn(`[ChessUI] no button {screen.Name}.{name}`)
		return
	end
	-- lihfolk-ignore: findfirstchild-chain (nil is handled on the next line)
	local scale = b:FindFirstChild("Press") :: UIScale?
	if not scale then
		scale = Instance.new("UIScale")
		scale.Name = "Press"
		scale.Parent = b
	end
	-- press feel like the reference: shrink the moment the finger goes down, spring back on release
	b.InputBegan:Connect(function(input: InputObject)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			TweenService:Create(scale, TweenInfo.new(0.06, Enum.EasingStyle.Quad), { Scale = 0.93 }):Play()
		end
	end)
	b.InputEnded:Connect(function(input: InputObject)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			TweenService:Create(scale, BACK, { Scale = 1 }):Play()
		end
	end)
	b.Activated:Connect(function()
		TweenService:Create(scale, BACK, { Scale = 1 }):Play()
		local ok, err = pcall(fn)
		if not ok then
			warn(`[ChessUI] {screen.Name}.{name}: {err}`)
		end
	end)
	b.MouseEnter:Connect(function()
		TweenService:Create(scale, TweenInfo.new(0.15, Enum.EasingStyle.Sine), { Scale = 1.04 }):Play()
	end)
	b.MouseLeave:Connect(function()
		TweenService:Create(scale, TweenInfo.new(0.15, Enum.EasingStyle.Sine), { Scale = 1 }):Play()
	end)
end

-- Toast: one short line above everything, drawn with GlyphText.
local toastFrame = Instance.new("Frame")
toastFrame.Name = "Toast"
toastFrame.BackgroundTransparency = 1
toastFrame.AnchorPoint = Vector2.new(0.5, 0.5)
toastFrame.Position = UDim2.fromScale(0.5, 0.2)
toastFrame.Size = UDim2.fromScale(0.6, 0.6)
toastFrame.ZIndex = 200
toastFrame.Visible = false
toastFrame:SetAttribute("BoxW", 1400)
toastFrame:SetAttribute("BoxH", 90)
toastFrame:SetAttribute("FitSize", 60)
local toastAspect = Instance.new("UIAspectRatioConstraint")
toastAspect.AspectRatio = 1400 / 90
toastAspect.Parent = toastFrame
toastFrame.Parent = gui
local toastPop = Instance.new("UIScale")
toastPop.Name = "Pop"
toastPop.Parent = toastFrame
local toastToken = 0
local function toast(msg: string, color: Color3?)
	toastToken += 1
	local token = toastToken
	GT.Set(toastFrame, msg, color or GOLD)
	toastFrame.Visible = true
	-- pop in (0.25 s back-out), shrink away at the end, like the reference's top banner
	toastPop.Scale = 0.6
	TweenService:Create(toastPop, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	task.delay(2.2, function()
		if toastToken == token then
			TweenService:Create(toastPop, TweenInfo.new(0.14, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Scale = 0 }):Play()
			task.delay(0.14, function()
				if toastToken == token then
					toastFrame.Visible = false
				end
			end)
		end
	end)
end

local WHY = {
	NeedPower = "Train more Elo first",
	NeedWins = "Win more duels first",
	Busy = "Finish your duel first",
	Claimed = "Already claimed",
	NotYet = "Not ready yet",
	ComingSoon = "Coming soon!",
	Owned = "You own this",
	NeedPass = "Needs the Auto Train pass",
	TooFast = "One moment...",
	NotLoaded = "Loading...",
}
local function why(r: any): string
	return WHY[r and r.code or ""] or "Try again"
end

---------------------------------------------------------------------------
-- Old HUD chrome: hidden for good (the new UI replaces it)
---------------------------------------------------------------------------
local function keepHidden(o: Instance?)
	if o and o:IsA("GuiObject") then
		o.Visible = false
		o:GetPropertyChangedSignal("Visible"):Connect(function()
			if o.Visible then
				o.Visible = false
			end
		end)
	end
end
task.spawn(function()
	local old = playerGui:WaitForChild("ChessHUD", 10)
	if old then
		for _, path in { "Rail", "TopBar", "Wheel", "SettingsButton", "RightOffers", "Invite", "Bottom.Power", "Bottom.Progress", "Bottom.Buy", "Bottom.Clicker" } do
			local o: Instance? = old
			for part in string.gmatch(path, "[^%.]+") do
				o = o and o:FindFirstChild(part)
			end
			keepHidden(o)
		end
	end
	local loop = playerGui:WaitForChild("ChessLoop", 10)
	if loop then
		keepHidden(loop:FindFirstChild("LoopRail", true))
	end
	-- No spin wheel or free auto clicker exists on the server yet: hide their shortcuts instead of
	-- showing a timer that only opens the gift page (master prompt §9). Put them back when they are real.
	local hud = gui:FindFirstChild("HUD")
	if hud then
		for _, name in { "SpinWheel", "SpinTimer", "SpinTimer_Live", "FreeAutoClicker", "FreeAutoClicker_Icon", "FreeAutoLabel", "FreeAutoLabel_Live", "FreeAutoTimer", "FreeAutoTimer_Live" } do
			keepHidden(hud:FindFirstChild(name, true))
		end
	end
end)

---------------------------------------------------------------------------
-- HUD groups (tutorial staging and duels hide whole groups)
---------------------------------------------------------------------------
local GROUPS = {
	wins = { "WinsIcon", "WinsValue", "RebirthIcon", "RebirthValue" },
	sets = { "Evolve" },
	promote = { "Rebirth" },
	rest = { "Shop", "Rewards", "Daily", "AutoWins", "AutoTrain", "SpinWheel", "SpinTimer", "Settings", "FreeGift", "GiftLabel", "PowerBoost", "WinsBoost", "InviteFriends", "InviteLabel", "InvitePlus" },
	bottom = { "PowerIcon", "PowerTotal", "ProgressTrack", "ProgressFill", "LevelLabel", "XPValue", "LevelPlus" },
	-- paid offers wait until the first win, so a new player's first screen is one goal (master prompt §3)
	offers = { "PowerPack", "MorePacks", "Pack", "OPAuto", "FreeAuto" },
}
-- prefixes that also cover longer names (AutoWinsState, Pack1Price, OPAutoLabel ...)
local LOOSE = { PowerPack = true, Pack = true, OPAuto = true, FreeAuto = true, AutoWins = true, AutoTrain = true, PowerBoost = true, WinsBoost = true, InvitePlus = true }
local groupFrames: { [string]: Frame } = {}
do
	local function groupOf(name: string): string?
		local base = string.gsub(name, "_Live$", "")
		for key, list in GROUPS do
			for _, prefix in list do
				if base == prefix or string.sub(base, 1, #prefix + 1) == prefix .. "_" or (LOOSE[prefix] and string.sub(base, 1, #prefix) == prefix) then
					return key
				end
			end
		end
		return nil
	end
	for key in GROUPS do
		local f = Instance.new("Frame")
		f.Name = "Group_" .. key
		f.BackgroundTransparency = 1
		f.Size = UDim2.fromScale(1, 1)
		f.ZIndex = 1
		f.Parent = HUD
		groupFrames[key] = f
	end
	for _, child in HUD:GetChildren() do
		if child:IsA("GuiObject") and not string.match(child.Name, "^Group_") then
			local key = groupOf(child.Name)
			if key then
				child.Parent = groupFrames[key]
			end
		end
	end
end

---------------------------------------------------------------------------
-- Screens: one at a time, pop open, close with X
---------------------------------------------------------------------------
local SCREENS = { "Daily", "Rewards", "Evolve", "Rebirth", "Shop", "ShopCatalog", "ShopWideOffers" }
local openName: string? = nil
local refresh: () -> ()
local function screen(name: string): Frame
	return gui:WaitForChild(name) :: Frame
end
for _, name in { "Daily", "Rewards", "Evolve", "Rebirth", "Shop", "ShopCatalog", "ShopWideOffers", "OfflineRewards", "SpinWheel" } do
	local f = gui:FindFirstChild(name)
	if f and f:IsA("GuiObject") then
		f.Visible = false
		local pop = Instance.new("UIScale")
		pop.Name = "Pop"
		pop.Parent = f
	end
end
local function close()
	if not openName then
		return
	end
	local f = screen(openName)
	openName = nil
	local pop = f:WaitForChild("Pop") :: UIScale
	TweenService:Create(pop, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Scale = 0.6 }):Play()
	task.delay(0.12, function()
		if openName ~= f.Name then
			f.Visible = false
		end
	end)
end
local function open(name: string)
	if S.battle then
		return
	end
	if openName == name then
		return
	end
	if openName then
		screen(openName).Visible = false
	end
	OpenPanel:Fire("Close") -- the old panels close when a new screen opens
	openName = name
	local f = screen(name)
	local pop = f:WaitForChild("Pop") :: UIScale
	-- measured on the reference (30 fps): menus grow from about half size, overshoot to ~105 % and settle in 0.3 s
	pop.Scale = 0.5
	f.Visible = true
	TweenService:Create(pop, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	refresh()
end
local function panel(name: string)
	close()
	OpenPanel:Fire(name)
end
for _, name in SCREENS do
	button(screen(name), "Close", close)
end

---------------------------------------------------------------------------
-- Requests
---------------------------------------------------------------------------
local function request(name: string, ...: any): any
	local r = Net.Request(name, ...)
	if not r.ok then
		toast(why(r), if r.code == "ComingSoon" then GOLD else RED)
	end
	return r
end
local function buyPass(key: string)
	if S.Passes and S.Passes[key] then
		if key == "AutoTrain" then
			request("SetAuto", not S.Auto)
		else
			toast("You own this!", GREEN)
		end
		return
	end
	request("BuyPass", key)
end
local function buyPack(key: string)
	request("BuyPack", key)
end
local function nextSet(): (string, string?)
	local cur = S.Equipped or Config.DefaultSet
	local curOrder = Config.Sets[cur].order
	local best: string? = nil
	for _, id in Config.SetOrder do
		local set = Config.Sets[id]
		if set.available and set.order > curOrder then
			best = id
			break
		end
	end
	return cur, best
end

---------------------------------------------------------------------------
-- HUD buttons
---------------------------------------------------------------------------
button(HUD, "Shop", function() open("Shop") end)
button(HUD, "Evolve", function() open("Evolve") end)
button(HUD, "Rebirth", function() open("Rebirth") end)
button(HUD, "Rewards", function() open("Rewards") end)
button(HUD, "Daily", function() open("Daily") end)
button(HUD, "LevelPlus", function() open("Rebirth") end)
button(HUD, "SpinWheel", function() open("Rewards") end)
button(HUD, "FreeGift", function() open("Rewards") end)
button(HUD, "FreeAutoClicker", function() open("Rewards") end)
button(HUD, "OPAutoClicker", function() open("Shop") end)
button(HUD, "PowerPack1", function() open("ShopCatalog") end)
button(HUD, "PowerPack2", function() open("ShopCatalog") end)
button(HUD, "PowerPack3", function() open("ShopCatalog") end)
button(HUD, "MorePacks", function() open("ShopWideOffers") end)
button(HUD, "PowerBoost", function() buyPass("DoublePower") end)
button(HUD, "WinsBoost", function() buyPass("DoubleWins") end)
button(HUD, "Settings", function() panel("Settings") end)
button(HUD, "AutoWins", function()
	player:SetAttribute("AutoWins", player:GetAttribute("AutoWins") ~= true)
end)
button(HUD, "AutoTrain", function()
	if S.Passes and S.Passes.AutoTrain then
		request("SetAuto", not S.Auto)
	else
		open("Shop")
	end
end)
local function invite()
	local ok, err = pcall(function()
		SocialService:PromptGameInvite(player)
	end)
	if not ok then
		warn(`[ChessUI] invite: {err}`)
	end
end
button(HUD, "InviteFriends", invite)
button(HUD, "InvitePlus", invite)
player:GetAttributeChangedSignal("AutoWins"):Connect(function()
	refresh()
end)

---------------------------------------------------------------------------
-- Screen buttons
---------------------------------------------------------------------------
-- Evolve = the next Chess Set (buy with Wins, then equip). The frames open the full Chess Sets list.
local evolveBusy = false
local evolveFlash = Instance.new("Frame")
evolveFlash.Name = "EvolveFlash"
evolveFlash.BackgroundColor3 = Color3.new(1, 1, 1)
evolveFlash.BackgroundTransparency = 1
evolveFlash.BorderSizePixel = 0
evolveFlash.Position = UDim2.fromOffset(0, -80)
evolveFlash.Size = UDim2.new(1, 0, 1, 160)
evolveFlash.ZIndex = 190
evolveFlash.Visible = false
evolveFlash.Parent = gui
button(screen("Evolve"), "EvolveAction", function()
	if evolveBusy then
		return
	end
	local cur, nxt = nextSet()
	if not nxt then
		toast("You have the best set!", GREEN)
		return
	end
	evolveBusy = true
	if not (S.Sets and S.Sets[nxt]) then
		local set = Config.Sets[nxt]
		if (S.Wins or 0) < set.price then
			evolveBusy = false
			toast(`Need {fmt(set.price)} Wins. Beat rivals to earn Wins!`, RED)
			return
		end
		local r = request("Buy", nxt)
		if not r.ok then
			evolveBusy = false
			return
		end
	end
	local r = request("Equip", nxt)
	evolveBusy = false
	if r.ok then
		-- reference evolve beat: menu closes, ONE white flash (in 0.1 s, hold 0.1 s, fade 0.75 s), then the banner
		close()
		evolveFlash.BackgroundTransparency = 1
		evolveFlash.Visible = true
		TweenService:Create(evolveFlash, TweenInfo.new(0.1, Enum.EasingStyle.Quad), { BackgroundTransparency = 0.05 }):Play()
		task.delay(0.2, function()
			local t = TweenService:Create(evolveFlash, TweenInfo.new(0.75, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { BackgroundTransparency = 1 })
			t.Completed:Connect(function()
				evolveFlash.Visible = false
			end)
			t:Play()
		end)
		-- show the real tap change (sets boost taps, not treadmills; same sum the server uses)
		local mult = Config.PowerMult(S.Promotions or 0, S.Passes)
		local before = Config.TapGain(cur) * mult
		local after = Config.TapGain(nxt) * mult
		task.delay(0.35, function()
			toast(`{Config.Sets[nxt].name} equipped! Tap: +{fmt(before)} -> +{fmt(after)} Elo per tap`, GOLD)
		end)
	end
end)
button(screen("Evolve"), "Skip", function() toast("Coming soon!") end)
local function framesOpenSets()
	for _, n in { "Before_Frame", "After_Frame" } do
		local f = screen("Evolve"):FindFirstChild(n)
		if f and f:IsA("ImageLabel") then
			local hit = Instance.new("TextButton")
			hit.Name = n .. "_Hit"
			hit.Text = ""
			hit.BackgroundTransparency = 1
			hit.Size = f.Size
			hit.Position = f.Position
			hit.ZIndex = 100
			hit.Parent = f.Parent
			hit.Activated:Connect(function()
				panel("Sets")
			end)
		end
	end
end
framesOpenSets()

button(screen("Rebirth"), "RebirthAction", function()
	local r = request("Promote")
	if r.ok then
		close()
		toast(`REBIRTH! +{math.floor(Config.Promotion.powerBonus * 100 * (r.data and r.data.promotions or 1))}% ELO`, GREEN)
	end
end)
button(screen("Rebirth"), "Skip", function() toast("Coming soon!") end)
button(screen("Rebirth"), "HeaderAction", function() toast("Coming soon!") end)

local DAILY_TILES = { "Day1", "Day2", "Day3", "Day4", "Day5", "Day6", "DailyGrandPrize" }
for i, name in DAILY_TILES do
	button(screen("Daily"), name, function()
		if S.DailyReady and i == S.DailyTile then
			local r = request("ClaimDaily")
			if r.ok then
				toast(`+{r.data.wins} Wins!`, GREEN)
			end
		elseif S.DailyTile and i < S.DailyTile then
			toast("Already claimed")
		else
			toast("Come back tomorrow!")
		end
	end)
end

local function age(): number
	return (S.SessionAge or 0) + (os.clock() - helloAt)
end
local function claimGift(i: number)
	local r = request("ClaimGift", i)
	if r.ok then
		toast(`+{r.data.wins} Wins!`, GREEN)
	end
end
for i in Config.Playtime do
	button(screen("Rewards"), "Reward" .. i, function()
		claimGift(i)
	end)
	button(screen("Rewards"), "Timer" .. i, function()
		claimGift(i)
	end)
end
button(screen("Rewards"), "FinalBundle", function()
	local total = 0
	for i, g in Config.Playtime do
		if not (S.GiftsClaimed and S.GiftsClaimed[i]) and age() >= g.min * 60 then
			local r = Net.Request("ClaimGift", i)
			if r.ok then
				total += r.data.wins
			end
			task.wait(1.05) -- the server allows about one claim a second
		end
	end
	toast(if total > 0 then `+{total} Wins!` else "Nothing ready yet", if total > 0 then GREEN else GOLD)
end)

-- Shop pages: Shop (passes) -> Packs -> More packs -> Codes
button(screen("Shop"), "VIP_Purchase", function() buyPass("DoublePower") end)
button(screen("Shop"), "Starter_Purchase", function() buyPass("AutoTrain") end)
button(screen("Shop"), "HeaderAction", function() open("ShopCatalog") end)
button(screen("ShopCatalog"), "TreadmillPrice1", function() buyPass("DoubleWins") end)
button(screen("ShopCatalog"), "TreadmillPrice2", function() buyPass("DoublePower") end)
button(screen("ShopCatalog"), "HeaderAction", function() open("ShopWideOffers") end)
for i = 1, 3 do
	button(screen("ShopCatalog"), "Pack" .. i, function() buyPack("Pack" .. i) end)
	button(screen("ShopCatalog"), "PackPrice" .. i, function() buyPack("Pack" .. i) end)
	button(screen("ShopWideOffers"), "WidePrice" .. i, function() buyPack("Pack" .. (i + 3)) end)
end
button(screen("ShopWideOffers"), "HeaderAction", function() panel("Codes") end)

---------------------------------------------------------------------------
-- Text that never changes (set once)
---------------------------------------------------------------------------
do
	local packs = Config.PowerPacks or {}
	local byKey = {}
	for _, p in packs do
		byKey[p.key] = p
	end
	for i, key in Config.HudPacks or {} do
		local h = byKey[key]
		if h then
			text(HUD, `PowerPack{i}_Label`, eloName(h.label))
			text(HUD, `Pack{i}Price`, tostring(h.price), GREEN)
		end
	end
	for i = 1, 3 do
		local p = packs[i]
		if p then
			text(screen("ShopCatalog"), `Pack{i}_Title`, eloName(p.label))
			text(screen("ShopCatalog"), `PackPrice{i}_Label`, `Buy  {commas(p.price)}`)
		end
		local w = packs[i + 3]
		if w then
			text(screen("ShopWideOffers"), `WideTitle{i}`, string.upper(eloName(w.label)))
			text(screen("ShopWideOffers"), `WidePrice{i}_Label`, `Buy  {commas(w.price)}`)
		end
	end
	text(HUD, "PowerBoost_Label", "×2 Elo")
	local shop = screen("Shop")
	text(shop, "HeaderActionLabel", "Packs")
	text(shop, "VIP_Title", "×2 Elo")
	text(shop, "VIP_Benefit1", "Double Elo every tap")
	text(shop, "VIP_Benefit2", "Stacks with Rebirth")
	text(shop, "VIP_Benefit3", "Yours forever")
	text(shop, "Starter_Title", "Auto Train")
	image(shop, "StarterArt1", IMG.Cursor)
	text(shop, "StarterReward1", "Auto Tap")
	text(shop, "StarterReward2", "4 Taps/sec")
	text(shop, "StarterReward3", "Hands Free")
	local cat = screen("ShopCatalog")
	text(cat, "HeaderActionLabel", "More")
	text(cat, "TreadmillTitle1", "×2 Wins Pass")
	text(cat, "TreadmillTitle2", "×2 Elo Pass")
	image(cat, "TreadmillArt1", IMG.Trophy)
	image(cat, "TreadmillArt2", IMG.EloCoin)
	text(screen("ShopWideOffers"), "HeaderActionLabel", "Codes")
	text(HUD, "Rebirth_Label", "Rebirth") -- Alex calls it Rebirth (Nov 8)
	text(HUD, "AutoTrain_Label", "Auto Train") -- taps for you anywhere now; treadmills already pay by themselves
	local rw = screen("Rewards")
	for i = 2, 4 do
		for _, n in { "BonusItem" .. i, "BonusAmount" .. i, "BonusAmount" .. i .. "_Live" } do
			local o = rw:FindFirstChild(n, true)
			if o then
				o:Destroy()
			end
		end
	end
	image(rw, "BonusItem1", IMG.Gift)
end

-- Evolve previews: a chess piece of the set (same look as the Chess Sets panel)
local previews: { [string]: string } = {}
local function preview(slotName: string, setId: string)
	local slot = screen("Evolve"):FindFirstChild(slotName, true)
	if not slot or previews[slotName] == setId then
		return
	end
	previews[slotName] = setId
	local old = slot:FindFirstChild("Viewport")
	if old then
		old:Destroy()
	end
	local set = Config.Sets[setId]
	local vf = Instance.new("ViewportFrame")
	vf.Name = "Viewport"
	vf.BackgroundTransparency = 1
	vf.Size = UDim2.fromScale(1, 0.8)
	vf.ZIndex = (slot :: GuiObject).ZIndex
	vf.Ambient = Color3.fromRGB(190, 190, 200)
	vf.LightDirection = Vector3.new(-1, -2, -1.5)
	local cam = Instance.new("Camera")
	cam.FieldOfView = 30
	cam.CFrame = CFrame.lookAt(Vector3.new(0, 4.6, -14), Vector3.new(0, 3.1, 0))
	cam.Parent = vf
	vf.CurrentCamera = cam
	local ok, err = pcall(function()
		local material = if setId == "Marble" then Enum.Material.Marble elseif setId == "Wooden" then Enum.Material.Wood else Enum.Material.SmoothPlastic
		local piece = Models.Piece(if set.order > 4 then "Queen" else "Knight", set.color, 1, CFrame.Angles(0, math.rad(200), 0), { trim = set.accent, material = material })
		local m = Instance.new("Model")
		for _, part in piece:GetChildren() do
			part.Parent = m
		end
		m.Parent = vf
	end)
	if not ok then
		warn(`[ChessUI] preview {setId}: {err}`)
	end
	vf.Parent = slot
end

-- Bars: stretch only the middle of the fill art so its rounded ends stay round.
local function bar(fill: Instance?, fullWidth: number, refWidth: number, p: number, sliceL: number, imgW: number, imgH: number)
	if not fill or not fill:IsA("ImageLabel") then
		return
	end
	fill.ScaleType = Enum.ScaleType.Slice
	fill.SliceCenter = Rect.new(sliceL, 0, imgW - sliceL, imgH)
	-- a real zero shows an empty track (the rounded ends would otherwise read as progress)
	fill.Visible = p > 0
	local minP = (sliceL * 2) / fullWidth
	fill.Size = UDim2.new(fullWidth * math.clamp(p, minP, 1) / refWidth, 0, fill.Size.Y.Scale, 0)
end

---------------------------------------------------------------------------
-- Showing State
---------------------------------------------------------------------------
local function nextGiftIn(): number?
	for i, g in Config.Playtime do
		if not (S.GiftsClaimed and S.GiftsClaimed[i]) then
			return math.max(0, g.min * 60 - age())
		end
	end
	return nil
end
local function priceText(key: string): string
	if S.Passes and S.Passes[key] then
		return "Owned"
	end
	return `Only {Config.Passes[key].price}`
end

-- The Elo counter rolls to the new number (0.35 s) and the coin and number bump on every gain
-- (vault 30 §6: counters roll, never jump; a gain bumps the counter).
local eloRoll = Instance.new("NumberValue")
local eloRollTween: Tween? = nil
local eloShownTarget: number? = nil
local eloLastBump = 0
local function renderElo(v: number)
	local eloWords = `{fmt(math.floor(v + 0.5))} Elo`
	text(HUD, "PowerTotal", eloWords)
	-- the Elo coin sits just left of the number, like the reference's Subscribers line
	local eloLive = HUD:FindFirstChild("PowerTotal_Live", true) :: GuiObject?
	local eloIcon = HUD:FindFirstChild("PowerIcon", true) :: GuiObject?
	if eloLive and eloIcon then
		local boxW = eloLive:GetAttribute("BoxW") or 520
		local ok, w = pcall(GT.Width, eloWords, eloLive:GetAttribute("FitSize") or 62)
		w = math.min(if ok then w else boxW * 0.6, boxW * 0.98)
		local cx = eloLive.Position.X.Scale + eloLive.Size.X.Scale / 2
		eloIcon.Position = UDim2.fromScale(cx - (w / 2 + 14) / 2048 - eloIcon.Size.X.Scale, eloIcon.Position.Y.Scale)
	end
end
eloRoll.Changed:Connect(function(v)
	local ok, err = pcall(renderElo, v)
	if not ok then
		warn(`[ChessUI] elo roll: {err}`)
	end
end)
local function bumpScale(o: Instance?, big: number)
	if not o then
		return
	end
	local sc = o:FindFirstChild("Bump") :: UIScale?
	if not sc then
		sc = Instance.new("UIScale")
		sc.Name = "Bump"
		sc.Parent = o
	end
	sc.Scale = big
	TweenService:Create(sc, TweenInfo.new(0.22, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
end
local function showElo(power: number)
	if eloShownTarget == nil or power < eloShownTarget then
		-- first state, or a reset (rebirth): no roll down
		if eloRollTween then
			eloRollTween:Cancel()
		end
		eloShownTarget = power
		eloRoll.Value = power
		renderElo(power)
		return
	end
	if power == eloShownTarget then
		return
	end
	eloShownTarget = power
	if eloRollTween then
		eloRollTween:Cancel()
	end
	eloRollTween = TweenService:Create(eloRoll, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Value = power })
	;(eloRollTween :: Tween):Play()
	if os.clock() - eloLastBump > 0.08 then
		eloLastBump = os.clock()
		bumpScale(HUD:FindFirstChild("PowerIcon", true), 1.22)
		bumpScale(HUD:FindFirstChild("PowerTotal_Live", true), 1.1)
	end
end

local function refreshHud()
	local n = S.Promotions or 0
	text(HUD, "WinsValue", fmt(S.Wins or 0))
	text(HUD, "RebirthValue", tostring(n))
	showElo(S.Power or 0)
	local lvl, prog, into, size = Config.Level(S.Power or 0, n)
	text(HUD, "LevelLabel", `Level {lvl}`)
	text(HUD, "XPValue", if size and size > 0 then `{fmt(into)}/{fmt(size)}` else "MAX")
	bar(HUD:FindFirstChild("ProgressFill", true), 914, 2048, prog or 0, 32, 793, 63)
	local autoWins = player:GetAttribute("AutoWins") == true
	text(HUD, "AutoWinsState", if autoWins then "ON" else "OFF", if autoWins then GREEN else RED)
	text(HUD, "AutoTrainState", if S.Auto then "ON" else "OFF", if S.Auto then GREEN else RED)
	local left = nextGiftIn()
	local words = if not left then "Done" elseif left <= 0 then "Ready!" else Format.Clock(left)
	text(HUD, "SpinTimer", words)
	text(HUD, "FreeAutoTimer", words)
	text(HUD, "PowerBoost_Label", `×2 Elo`) -- the pass doubles Elo (Config.PowerMult)
	text(HUD, "PowerBoostPrice", priceText("DoublePower"))
	text(HUD, "WinsBoostPrice", priceText("DoubleWins"))

	-- groups: tutorial staging and duels
	local done = S.TutorialDone == true or n >= 1
	local cleared1 = S.Cleared and S.Cleared.Stage1 == true
	-- the duel and its result card own the screen; the HUD comes back once, after the card closes
	local legacy = gui.Parent and gui.Parent:FindFirstChild("ChessHUD")
	local resultCard = legacy and legacy:FindFirstChild("ResultPanel")
	local inBattle = S.battle ~= nil or (resultCard ~= nil and resultCard:IsA("GuiObject") and resultCard.Visible)
	groupFrames.wins.Visible = not inBattle and (done or cleared1 or (S.Wins or 0) > 0)
	groupFrames.sets.Visible = not inBattle and (done or cleared1)
	groupFrames.promote.Visible = not inBattle and (done or (S.Sets and S.Sets.Marble == true))
	groupFrames.rest.Visible = not inBattle and done
	groupFrames.bottom.Visible = not inBattle
	groupFrames.offers.Visible = not inBattle and done -- paid offers stay in the Shop until the tutorial is done
	if inBattle and openName then
		close()
	end
end

local function refreshEvolve()
	local cur, nxt = nextSet()
	local curSet = Config.Sets[cur]
	local ev = screen("Evolve")
	text(ev, "Before_Rank", (string.gsub(curSet.name, " Set", "")), Color3.fromRGB(255, 153, 235))
	text(ev, "Before_Multiplier", `×{curSet.multiplier} Elo`)
	preview("Before_Image", cur)
	if nxt then
		local set = Config.Sets[nxt]
		text(ev, "After_Rank", (string.gsub(set.name, " Set", "")), Color3.fromRGB(255, 202, 96))
		text(ev, "After_Multiplier", `×{set.multiplier} Elo`)
		text(ev, "EvolveAction_Label", if S.Sets and S.Sets[nxt] then "Equip" else `{fmt(set.price)} Wins`)
		preview("After_Image", nxt)
	else
		text(ev, "After_Rank", "Max", Color3.fromRGB(255, 202, 96))
		text(ev, "After_Multiplier", `×{curSet.multiplier} Elo`)
		text(ev, "EvolveAction_Label", "Max")
		preview("After_Image", cur)
	end
end

local function refreshRebirth()
	local n = S.Promotions or 0
	local pb, wb = Config.Promotion.powerBonus, Config.Promotion.winsBonus
	local rb = screen("Rebirth")
	text(rb, "Before_Power_Label", `×{mult(1 + pb * n)} Elo`)
	text(rb, "After_Power_Label", `×{mult(1 + pb * (n + 1))} Elo`)
	text(rb, "Before_Speed_Label", `×{mult(1 + wb * n)} Wins`)
	text(rb, "After_Speed_Label", `×{mult(1 + wb * (n + 1))} Wins`)
	local pp, pw = S.PromoPower or 1, S.PromoWins or 1
	local progress = math.clamp(math.min((S.Power or 0) / pp, (S.Wins or 0) / pw), 0, 1)
	text(rb, "RebirthLevel", `{fmt(S.Power or 0)}/{fmt(pp)} Elo  {fmt(S.Wins or 0)}/{fmt(pw)} Wins`)
	-- what the next rebirth opens: the treadmill that needs exactly n + 1 rebirths
	local unlockName: string? = nil
	for _, id in Config.StationOrder do
		if Config.StationRebirths(id) == n + 1 then
			unlockName = Config.Stations[id].name
		end
	end
	text(rb, "ResetNotice", if unlockName then `Unlocks {unlockName}! Resets Elo and Wins, sets stay` else "Resets Elo and Wins. Sets and stages stay!", CYAN)
	bar(rb:FindFirstChild("RebirthProgressFill", true), 1365, 1600, progress, 50, 125, 110)
end

local function untilTomorrow(): number
	return 86400 - (os.time() % 86400)
end
local function refreshDaily()
	local n = S.Promotions or 0
	local d = screen("Daily")
	for i, name in DAILY_TILES do
		local amount = math.floor(Config.Daily[i] * (1 + Config.Promotion.winsBonus * n))
		local tile = S.DailyTile or 1
		local claimed = i < tile
		local current = i == tile
		text(d, name .. "_Title", `+{fmt(amount)} Wins`)
		local detail, art
		if claimed then
			detail, art = "Claimed", IMG.Check
		elseif current and S.DailyReady then
			detail, art = "Claim!", IMG.Trophy
		elseif current then
			detail, art = Format.Clock(untilTomorrow()), IMG.Lock
		else
			detail, art = `Day {i}`, IMG.Lock
		end
		text(d, name .. "_Detail", detail, if detail == "Claim!" then GREEN else nil)
		image(d, name .. "_Artwork", art)
	end
end

local function refreshRewards()
	local rw = screen("Rewards")
	local readyWins, nextLeft, allDone = 0, nil, true
	for i, g in Config.Playtime do
		local claimed = S.GiftsClaimed and S.GiftsClaimed[i]
		local left = math.max(0, g.min * 60 - age())
		text(rw, `Reward{i}_Title`, `+{g.wins} Wins`)
		local label, art
		if claimed then
			label, art = "Done", IMG.Check
		elseif left <= 0 then
			label, art = "Claim!", IMG.Gift
			readyWins += g.wins
			allDone = false
		else
			label, art = Format.Clock(left), IMG.Lock
			nextLeft = nextLeft or left
			allDone = false
		end
		text(rw, `Timer{i}_Label`, label, if label == "Claim!" then GREEN else nil)
		image(rw, `Reward{i}_Artwork`, art)
	end
	text(rw, "BonusAmount1", `+{readyWins}`)
	text(rw, "FinalTimer_Label", if readyWins > 0 then "Claim All" elseif allDone then "All Done" else Format.Clock(nextLeft or 0))
end

local function refreshShop()
	local shop = screen("Shop")
	local function passLabel(key: string): string
		if S.Passes and S.Passes[key] then
			if key == "AutoTrain" then
				return if S.Auto then "ON" else "OFF"
			end
			return "Owned"
		end
		return tostring(Config.Passes[key].price)
	end
	text(shop, "VIP_Purchase_Label", passLabel("DoublePower"))
	text(shop, "Starter_Purchase_Label", passLabel("AutoTrain"))
	local cat = screen("ShopCatalog")
	text(cat, "TreadmillPrice1_Label", passLabel("DoubleWins"))
	text(cat, "TreadmillPrice2_Label", passLabel("DoublePower"))
end

refresh = function()
	if not S.loaded then
		return
	end
	local ok, err = pcall(function()
		refreshHud()
		if openName == "Evolve" then
			refreshEvolve()
		elseif openName == "Rebirth" then
			refreshRebirth()
		elseif openName == "Daily" then
			refreshDaily()
		elseif openName == "Rewards" then
			refreshRewards()
		elseif openName == "Shop" or openName == "ShopCatalog" then
			refreshShop()
		end
	end)
	if not ok then
		warn(`[ChessUI] refresh: {err}`)
	end
end

local function apply(state: any)
	if type(state) ~= "table" then
		return
	end
	S = state
	if state.SessionAge then
		helloAt = os.clock()
	end
	refresh()
end
Net.On("State", apply)
task.spawn(function()
	-- hide/show the HUD with the duel result card
	local legacy = gui.Parent and gui.Parent:WaitForChild("ChessHUD", 20)
	local card = legacy and legacy:WaitForChild("ResultPanel", 20)
	if card and card:IsA("GuiObject") then
		card:GetPropertyChangedSignal("Visible"):Connect(refresh)
	end
end)
task.spawn(function()
	local r = Net.Request("Hello")
	if r.ok then
		apply(r.data)
	end
end)
task.spawn(function()
	while true do
		task.wait(1)
		refresh() -- timers
	end
end)
gui.Enabled = true
log("ready")

-- The Starter Pack window (owner, Oct 25 13:18: "can you make the starter pack pop up in the start"). What the pack
-- gives (Config/Products StarterPack: its knife's picture, its Benefits lines), its price and one green BUY button
-- that opens Roblox's own Game Pass prompt. The server gives everything (HuzzServer/ShopService, once per save).
-- It opens by itself once per visit, after your first game of the visit (owner, Oct 25 13:30: "make the starter pack
-- pop after one game is played by the user as there is a lot of things popping up on start up"): back in the lobby,
-- Config/Products.StarterPopupAfter seconds later, once the results and any other window but the map vote are closed
-- (it shows over the vote, which comes back after). Never for
-- someone who owns it, and never live while the pass has no ID (in Studio it still does, so you can see it):
-- with no ID BUY only says "coming soon".
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Products = require(Shared.Config.Products)
local CoinShop = require(Shared.Config.CoinShop)
local Net = require(Shared.Net)
local Format = require(Shared.Format)
local UI = script.Parent.Parent
local Theme = require(UI.Theme)
local Kit = require(UI.Kit)
local State = require(UI.State)
local Toast = require(UI.Toast)
local ModalManager = require(UI.ModalManager)
local Effects = require(UI.Effects)
local DailyLoginScreen = require(script.Parent.DailyLogin)

local new = Kit.new
local C, F = Theme.Colors, Theme.Fonts

local StarterPack = {}

local W, H = 560, 340

local function line(props: { [string]: any }, stroke: number?): TextLabel
	props.TextWrapped = props.TextWrapped == true
	local l = Kit.text(props)
	new("UIStroke", { Name = "Outline", Color = C.TitleStroke, Thickness = stroke or 1.5, LineJoinMode = Enum.LineJoinMode.Round, Parent = l })
	return l
end

function StarterPack.build(parent: Instance)
	local p = Products.get("StarterPack")
	if not p then return nil end
	local player = Players.LocalPlayer
	local accent = p.Accent or Color3.fromHex("FFC24A")
	local window = Kit.window({ Name = "StarterPack", Flat = true, Title = "STARTER PACK", Icon = "GiftAction", Width = W, Height = H, TitleX = 56, TitleWidth = 300, StudsTo = 0, Parent = parent, OnClose = function() ModalManager.close() end })
	local panel = window.Panel

	-- The knife, made to stand out (owner, Oct 25 14:52: "please make the picture of the knife look better right now it
	-- looks too plain and doesnt look attractive"): a backdrop in the knife's own colour (its Glow, Config/CoinShop),
	-- turning light rays and a breathing glow behind it, sparks rising round it, and the knife itself as its real 3D
	-- model turning slowly (remote KnifeView puts a copy in ReplicatedStorage > HuzzKnifeViews, as the Shop's knife
	-- cards do). Its flat picture shows until the model arrives (and in the offline preview, which can't draw 3D).
	local knifeItem = p.Gives and p.Gives.Knife and CoinShop.get(p.Gives.Knife)
	local glowColour = (knifeItem and knifeItem.Glow) or accent
	local artF = new("Frame", { Name = "Art", Position = UDim2.fromOffset(20, 47 + 14), Size = UDim2.fromOffset(200, 200), BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, ClipsDescendants = true, ZIndex = 3, Parent = panel }, { Kit.corner(10) })
	new("UIGradient", { Name = "Backdrop", Rotation = 90, Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, glowColour:Lerp(Color3.new(0, 0, 0), 0.55)), ColorSequenceKeypoint.new(0.55, glowColour:Lerp(Color3.new(0, 0, 0), 0.8)), ColorSequenceKeypoint.new(1, Color3.fromHex("0A0610")) }), Parent = artF })
	new("UIStroke", { Name = "Rim", Color = accent, Thickness = 2.5, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = artF })
	Effects.rays(artF, UDim2.fromScale(0.5, 0.5), 300, { color = glowColour:Lerp(Color3.new(1, 1, 1), 0.25), transparency = 0.55, seconds = 16, z = 3, name = "Rays" })
	-- a soft round glow: rings of the knife's colour, more see-through outwards
	local glow = new("Frame", { Name = "Glow", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(180, 180), BackgroundTransparency = 1, ZIndex = 3, Parent = artF })
	for i = 1, 8 do
		local d = 184 - (i - 1) * 20
		new("Frame", { Name = "Ring" .. i, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(d, d), BackgroundColor3 = glowColour:Lerp(Color3.new(1, 1, 1), 0.06 * (i - 1)), BackgroundTransparency = 0.9, BorderSizePixel = 0, ZIndex = 3, Parent = glow }, { Kit.corner(d // 2) })
	end
	Effects.breathe(glow, { scale = 1.15, seconds = 1.4 })
	local pic = Kit.art(p.Art, { Name = "Picture", Position = UDim2.fromOffset(6, 6), Size = UDim2.fromOffset(188, 188), ScaleType = Enum.ScaleType.Fit, ZIndex = 4, Parent = artF })
	Effects.rock(pic, { degrees = 3, seconds = 1.1 })
	Effects.motes(artF, { colour = glowColour:Lerp(Color3.new(1, 1, 1), 0.3), shape = "dot", count = 9, area = Rect.new(16, 30, 184, 196), z = 6, seed = 7 })
	Effects.shine(artF, { every = 3.5, corner = 10, z = 7 })
	-- the real knife, turning (made at run time, never saved)
	if knifeItem then
		task.spawn(function()
			local ok, model = pcall(function()
				local okAsk = (Net.get("KnifeView") :: RemoteFunction):InvokeServer(knifeItem.Key)
				local views = okAsk and game:GetService("ReplicatedStorage"):WaitForChild("HuzzKnifeViews", 8)
				return views and views:WaitForChild(knifeItem.Key, 8)
			end)
			if not (ok and typeof(model) == "Instance") then return end
			local copy = model:Clone()
			local handle = copy:FindFirstChild("Handle", true)
			if not (handle and handle:IsA("BasePart")) then copy:Destroy() return end
			-- tip up (the Handle's +Y), tilted a little, turning round the upright
			copy:PivotTo(handle.CFrame:Inverse() * copy:GetPivot())
			local centre, size = copy:GetBoundingBox()
			local length = math.max(size.X, size.Y, size.Z)
			local base = copy:GetPivot()
			local vf = new("ViewportFrame", { Name = "Knife3D", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 5, Ambient = Color3.fromRGB(190, 185, 195), LightColor = Color3.new(1, 1, 1), LightDirection = Vector3.new(-0.4, -1, -0.6), Parent = artF })
			vf:SetAttribute("NoSave", true)
			local cam = Instance.new("Camera")
			cam.FieldOfView = 30
			cam.CFrame = CFrame.lookAt(centre.Position + Vector3.new(0, 0, length * 2.1), centre.Position)
			cam.Parent = vf
			vf.CurrentCamera = cam
			copy.Parent = vf
			pic.Visible = false
			local tilt = CFrame.Angles(0, 0, math.rad(-25))
			game:GetService("RunService").RenderStepped:Connect(function()
				if not (window.Holder.Visible and window.Group.Visible and vf.Parent) then return end
				local yaw = (os.clock() * 0.9) % (math.pi * 2) -- (about one turn every 7 s)
				copy:PivotTo(CFrame.new(centre.Position) * tilt * CFrame.Angles(0, yaw, 0) * CFrame.new(-centre.Position) * base)
			end)
		end)
	end

	-- what you get, one line each (the Shop banner's lines)
	local x = 240
	for j, bf in p.Benefits or {} do
		local by = 47 + 22 + (j - 1) * 50
		Kit.icon(bf.Icon, { Name = "BenefitIcon" .. j, Position = UDim2.fromOffset(x, by), Size = UDim2.fromOffset(36, 36), ZIndex = 4, Parent = panel })
		local bt = line({ Name = "Benefit" .. j, Text = bf.Text, FontFace = F.Heading, TextSize = 21, TextXAlignment = Enum.TextXAlignment.Left, Position = UDim2.fromOffset(x + 46, by), Size = UDim2.fromOffset(W - x - 46 - 16, 36), ZIndex = 4, Parent = panel }, 2)
		Kit.fitLine(bt, W - x - 46 - 16, 21, 12, true)
	end
	line({ Name = "Once", Text = "Yours to keep. Buy it once.", FontFace = F.Name, TextSize = 16, TextColor3 = accent:Lerp(Color3.new(1, 1, 1), 0.4), TextXAlignment = Enum.TextXAlignment.Left, Position = UDim2.fromOffset(x, 47 + 22 + 3 * 50), Size = UDim2.fromOffset(W - x - 16, 22), ZIndex = 4, Parent = panel })

	-- BUY: Roblox's Game Pass prompt (the price shown until Roblox's own loads; the live price wins)
	local price = p.Price
	local buy = Kit.button({ Name = "Buy", Text = "", Style = "ShopGreen", FontFace = F.Button, TextSize = 26, Corner = 9, RimThickness = 2.5, AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -16), Size = UDim2.fromOffset(260, 52), ZIndex = 5, Parent = panel })
	local pending = false
	local function refresh()
		if State.owns(p.Key) then
			buy.setText("OWNED"); buy.setStyle("Disabled")
		elseif pending then
			buy.setText("..."); buy.setStyle("Disabled")
		else
			buy.setText(Format.RobuxMark .. " " .. Format.commas(price) .. "  BUY"); buy.setStyle("ShopGreen")
		end
	end
	buy.onClick(function()
		if pending or State.owns(p.Key) then return end
		local status = Products.status(p)
		if status ~= "Ready" then
			Toast.show(p.Name .. " is coming soon.") -- (no ID yet: never a purchase prompt)
			if status == "NoId" then warn("[Shop] StarterPack has no Game Pass ID in Shared/Config/Products.lua") end
			return
		end
		pending = true
		refresh()
		local ok = pcall(function() MarketplaceService:PromptGamePassPurchase(player, p.Id) end)
		if not ok then
			pending = false
			Toast.show("The purchase couldn't open. Try again.")
		end
		refresh()
	end)
	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(who, id, bought)
		if who ~= player or id ~= p.Id then return end
		pending = false
		refresh()
		if bought then ModalManager.close() end -- (the server's note says what you got)
	end)
	if p.Id ~= 0 then
		task.spawn(function()
			local ok, info = pcall(MarketplaceService.GetProductInfo, MarketplaceService, p.Id, Enum.InfoType.GamePass)
			if ok and type(info) == "table" and type(info.PriceInRobux) == "number" then
				price = info.PriceInRobux
				refresh()
			end
		end)
	end

	ModalManager.register("StarterPack", {
		window = window,
		onOpen = refresh,
		firstSelect = function() return buy.Instance end,
	})
	State.changed(refresh)
	refresh()

	-- By itself: once per visit, after your first game, in the lobby with nothing open.
	local studio = game:GetService("RunService"):IsStudio()
	local shown, due, timer = false, nil, false
	local inGame, played = false, false -- (played: a game of yours ended this visit)
	-- (the map vote counts as free: it opens straight after every game and stays up until the next one, so waiting for
	-- it to shut meant the pack never showed; owner, Oct 25 15:46: "it doesnt pop up". The vote comes back when the
	-- pack is closed, and the NEXT MAP panel takes votes meanwhile.)
	local round = Net.get("Round")
	local overVote = false
	local function free(): boolean
		local role = player:GetAttribute("HuzzRole")
		local open = ModalManager.current()
		return (open == nil or open == "MapVote") and role ~= "Runner" and role ~= "Catcher" and not DailyLoginScreen.waiting()
	end
	ModalManager.changed(function(name)
		if overVote and name ~= "StarterPack" then
			overVote = false
			if name == nil and round:GetAttribute("Stage") == "Voting" then
				task.defer(function()
					if ModalManager.current() == nil then ModalManager.open("MapVote") end
				end)
			end
		end
	end)
	local function maybeOpen()
		local role = player:GetAttribute("HuzzRole")
		if role == "Runner" or role == "Catcher" then inGame = true elseif inGame then inGame, played = false, true end
		if not played or shown or timer or not State.data.Loaded or State.owns(p.Key) then return end
		if not ((p.OnSale and p.Id ~= 0) or studio) then return end
		due = due or os.clock() + (Products.StarterPopupAfter or 8)
		timer = true
		task.delay(math.max(due - os.clock(), 0) + 0.05, function()
			timer = false
			if shown or State.owns(p.Key) then return end
			if free() then -- (else the next lobby moment or closed window looks again)
				shown = true
				overVote = ModalManager.current() == "MapVote"
				ModalManager.open("StarterPack")
			end
		end)
	end
	State.changed(maybeOpen)
	ModalManager.changed(function() task.defer(maybeOpen) end)
	player:GetAttributeChangedSignal("HuzzRole"):Connect(maybeOpen)
	maybeOpen()
	return window.Holder
end

return StarterPack

-- The Starter Pack window (owner, Oct 25 13:18: "can you make the starter pack pop up in the start"). What the pack
-- gives (Config/Products StarterPack: its knife's picture, its Benefits lines), its price and one green BUY button
-- that opens Roblox's own Game Pass prompt. The server gives everything (HuzzServer/ShopService, once per save).
-- It opens by itself once per visit, Config/Products.StarterPopupAfter seconds after the save loads, in the lobby with
-- nothing else open and after the daily reward's turn (like the group window, which then waits for this one). Never
-- for someone who owns it, and never live while the pass has no ID (in Studio it still does, so you can see it):
-- with no ID BUY only says "coming soon".
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Products = require(Shared.Config.Products)
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
	local window = Kit.window({ Name = "StarterPack", Title = "STARTER PACK", Icon = "GiftAction", Width = W, Height = H, TitleX = 56, TitleWidth = 300, StudsTo = 0, Parent = parent, OnClose = function() ModalManager.close() end })
	local panel = window.Panel

	-- the knife's picture in a soft glow of the pack's colour, rocking a little
	local artF = new("Frame", { Name = "Art", Position = UDim2.fromOffset(20, 47 + 14), Size = UDim2.fromOffset(200, 200), BackgroundColor3 = Color3.fromHex("1A1530"), BorderSizePixel = 0, ZIndex = 3, Parent = panel }, { Kit.corner(10) })
	new("UIStroke", { Name = "Rim", Color = accent, Thickness = 2, Parent = artF })
	local glow = new("Frame", { Name = "Glow", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(170, 170), BackgroundColor3 = accent, BorderSizePixel = 0, ZIndex = 3, Parent = artF }, { Kit.corner(85) })
	new("UIGradient", { Name = "Soft", Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.5, 0.6), NumberSequenceKeypoint.new(1, 1) }), Parent = glow })
	Effects.breathe(glow, { scale = 1.12, seconds = 1.4 })
	local pic = Kit.art(p.Art, { Name = "Picture", Position = UDim2.fromOffset(6, 6), Size = UDim2.fromOffset(188, 188), ScaleType = Enum.ScaleType.Fit, ZIndex = 4, Parent = artF })
	Effects.rock(pic, { degrees = 3, seconds = 1.1 })

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

	-- By itself: once per visit, after the daily reward's turn, in the lobby with nothing open.
	local studio = game:GetService("RunService"):IsStudio()
	local shown, due, timer = false, nil, false
	local function free(): boolean
		local role = player:GetAttribute("HuzzRole")
		return ModalManager.current() == nil and role ~= "Runner" and role ~= "Catcher" and not DailyLoginScreen.waiting()
	end
	local function maybeOpen()
		if shown or timer or not State.data.Loaded or State.owns(p.Key) then return end
		if not ((p.OnSale and p.Id ~= 0) or studio) then return end
		due = due or os.clock() + (Products.StarterPopupAfter or 8)
		timer = true
		task.delay(math.max(due - os.clock(), 0) + 0.05, function()
			timer = false
			if shown or State.owns(p.Key) then return end
			if free() then -- (else the next lobby moment or closed window looks again)
				shown = true
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

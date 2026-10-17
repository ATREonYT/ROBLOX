-- Checks the screens made from the owner's Oct 17 mockups (design/ui-oct17) through the real server + client code:
-- the Shop COINS cards. Run by check.sh; prints "oct17 screens: N ok, 0 failed".
local Players = game:GetService("Players")
local ok, failed = 0, 0
local function check(name, cond)
	if cond then ok += 1 else failed += 1; print("FAIL " .. name) end
end

local player = Instance.new("Player"); player.Name = "Tester"; player.UserId = 1; player.Parent = Players
Players.LocalPlayer = player
Instance.new("PlayerGui").Parent = player
__copyStarterGui(player)
__runScript(game.ServerScriptService.HuzzServer.Bootstrap)
task.wait(0.1)
__fireOn(Players, "PlayerAdded", player)
task.wait(0.2)
local HS = game.ServerScriptService.HuzzServer
local DataService = require(HS.DataService)
local profile = DataService.get(player)
__runScript(game.StarterPlayer.StarterPlayerScripts.HuzzClient.Main)
task.wait(0.3)
local UI = game.StarterPlayer.StarterPlayerScripts.HuzzClient.UI
local MM = require(UI.ModalManager)
local gui = player.PlayerGui.HuzzUI
local function click(btn) __fireOn(btn, "Activated"); task.wait(0.25) end
local function toast() return gui.Toast.Text end
-- Roblox stores whole pixels: every offset under a part must be a whole number (the preview would draw halves).
local function wholePixels(root: Instance): boolean
	for _, d in root:GetDescendants() do
		if d:IsA("GuiObject") then
			local p, s = d.Position, d.Size
			for _, v in { p.X.Offset, p.Y.Offset, s.X.Offset, s.Y.Offset } do
				if v ~= math.floor(v) then print("  half pixel: " .. d:GetFullName()); return false end
			end
		end
	end
	return true
end
-- a part's box in window px (offsets only, from its parent chain up to the window's panel)
local function box(inst: GuiObject, stop: Instance)
	local x, y = 0, 0
	local cur: Instance = inst
	while cur ~= stop and cur:IsA("GuiObject") do
		x += cur.Position.X.Offset - cur.AnchorPoint.X * cur.Size.X.Offset
		y += cur.Position.Y.Offset - cur.AnchorPoint.Y * cur.Size.Y.Offset
		cur = cur.Parent :: Instance
		local pad = cur:FindFirstChildOfClass("UIPadding")
		if pad then x += pad.PaddingLeft.Offset; y += pad.PaddingTop.Offset end
	end
	return x, y, inst.Size.X.Offset, inst.Size.Y.Offset
end

-- SHOP COINS: three cards, each with its title, its picture from the mockup and a Robux price button
-- open a window and let its slide-ins finish
local function open(name: string, tab: string?): boolean
	local okOpen = MM.open(name, tab) == true
	for _ = 1, 40 do __stepTweens(0.05) end
	task.wait(0.6)
	for _ = 1, 40 do __stepTweens(0.05) end
	return okOpen
end

check("Shop opens on COINS", open("Shop", "Coins") and gui.Shop.Visible)
local shop = gui.Shop.Group.Panel
local products = shop.Products
local Products = require(game.ReplicatedStorage.Shared.Config.Products)
local prompts = #(_G.__prompts or {})
for i, p in Products.Coins do
	local c = products:FindFirstChild(p.Key)
	check(p.Key .. " card shows", c ~= nil)
	if c then
		local title = c:FindFirstChild("Name") :: TextLabel?
		check(p.Key .. " title", title ~= nil and title.Text == p.Name)
		local pic = c:FindFirstChild("Art") and c.Art:FindFirstChild("Picture")
		check(p.Key .. " picture is the mockup's coin art", pic ~= nil and pic:GetAttribute("Art") == "CoinPack" .. p.Amount)
		local buy = c:FindFirstChild("Buy")
		local badge = buy and buy:FindFirstChild("RobuxBadge", true)
		check(p.Key .. " price button keeps the Robux mark (not a coin)", badge ~= nil and badge.Visible and buy:FindFirstChild("Icon", true) == nil)
		check(p.Key .. " price shows", buy ~= nil and buy.Content.Label.Text == tostring(p.Price))
		local x, y, w, h = box(c, shop)
		local inside = x >= 16 and y >= 85 and x + w <= 701 - 16 and y + h <= 320 - 8
		check(p.Key .. " card sits inside the window", inside)
		if not inside then print("  box", x, y, w, h) end
		if i == 1 then
			click(buy)
			check("a coin pack that isn't on sale says so and never opens a purchase", toast():find("coming soon") ~= nil and #(_G.__prompts or {}) == prompts)
		end
	end
end
check("COINS: whole pixels only", wholePixels(products))
check("tapping a coin pack grants nothing (only the server's receipt does)", profile.Data.Coins == 0)
MM.close()
task.wait(0.2)

print(string.format("oct17 screens: %d ok, %d failed", ok, failed))
return nil

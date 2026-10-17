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

-- DANCES: 3 column cards (glow + figure + name), the selected one highlighted, a preview with name, line, PLAY, STOP
local Dances = require(game.ReplicatedStorage.Shared.Config.Dances)
local State = require(UI.State)
for _, d in Dances.List do
	local b = d.Blurb or ""
	if not (Dances.Colors[d.Color] and #b > 8 and #b <= 44 and not b:find("%-") and not b:find("\226\128[\147\148]")) then
		check(d.Id .. " has a colour and a short blurb with no dashes", false)
	end
end
check("every dance has a colour and a short blurb", true)
check("Dances opens", open("Dances") and gui.Dances.Visible)
local dp = gui.Dances.Group.Panel
local grid = dp.Grid
local list = {}
for _, c in grid:GetChildren() do if c:IsA("TextButton") then table.insert(list, c) end end
table.sort(list, function(a, b) return a.LayoutOrder < b.LayoutOrder end)
check("all 25 dances have cards", #list == 25)
if #list >= 4 then
	local p1, p2, p3, p4 = list[1].Position, list[2].Position, list[3].Position, list[4].Position
	check("three cards to a row", p1.Y.Offset == p2.Y.Offset and p2.Y.Offset == p3.Y.Offset and p4.Y.Offset > p1.Y.Offset and p4.X.Offset == p1.X.Offset and p3.X.Offset > p2.X.Offset)
	local c1 = list[1]
	check("a card has the glow, notes, figure and name", c1:FindFirstChild("Glow") and c1.Glow:FindFirstChild("FxGlow") and c1.Glow:FindFirstChild("FxCore") and c1:FindFirstChild("Figure") and c1.Figure:GetAttribute("Art") == "DanceStill" .. c1.Name and (c1.Band:FindFirstChild("Name") :: any).Text == Dances.get(c1.Name).Name)
	check("the card glows in its dance's colour", c1.Glow.FxGlow.ImageColor3 == Dances.Colors[Dances.get(c1.Name).Color])
end
local selectedCount = 0
for _, c in list do if c.Halo.Visible then selectedCount += 1 end end
check("exactly one card is highlighted", selectedCount == 1)
local pv = dp.Preview
if pv.DanceName.Text ~= "Aerobics" then print("  preview shows: " .. pv.DanceName.Text .. " / " .. pv.Blurb.Text) end
check("an owned dance's preview shows its name and line", pv.DanceName.Text == "Aerobics" and pv.Blurb.Text == Dances.get("Aerobics").Blurb and grid.Aerobics.Halo.Visible)
click(grid.SwingTime)
check("a locked dance shows locked, a dark figure and a lock", pv.Blurb.Text:find("Locked") == 1 and grid.SwingTime:FindFirstChild("Lock") ~= nil and pv.ArtBox:FindFirstChild("Lock") ~= nil and grid.SwingTime.Halo.Visible and not grid.Aerobics.Halo.Visible)
check("PLAY and STOP sit inside the preview", dp.Play.Visible and dp.Stop.Visible and dp.Play.Position.X.Offset > pv.Position.X.Offset and dp.Stop.Position.X.Offset + dp.Stop.Size.X.Offset / 2 < pv.Position.X.Offset + pv.Size.X.Offset)
check("search, sort and the three tabs", dp.Header:FindFirstChild("Search") and dp.Header:FindFirstChild("Sort") and dp:FindFirstChild("AllTab") and dp:FindFirstChild("OwnedTab") and dp:FindFirstChild("FavouritesTab") and dp.SortMenu:FindFirstChild("AToZ") and dp.SortMenu:FindFirstChild("ZToA"))
check("DANCES: whole pixels only", wholePixels(gui.Dances))
-- favourites are saved by the server, checked and capped
local function act(...) local r, why = State.action(...); task.wait(0.2); return r, why end -- (the server refuses actions closer than 0.15 s)
check("favourite: unknown dance refused", (act("FavoriteDance", "NotADance", true)) == false and profile.Data.FavDances.NotADance == nil)
check("favourite: needs true or false", (act("FavoriteDance", "Floss", "yes")) == false and profile.Data.FavDances.Floss == nil)
for i = 1, Dances.MaxFavourites do act("FavoriteDance", Dances.List[i].Id, true) end
local n = 0
for _ in profile.Data.FavDances do n += 1 end
check("favourite: saved in the player's data", n == Dances.MaxFavourites)
task.wait(0.16)
local okCap, whyCap = act("FavoriteDance", Dances.List[Dances.MaxFavourites + 1].Id, true)
check("favourite: capped at " .. Dances.MaxFavourites, okCap == false and profile.Data.FavDances[Dances.List[Dances.MaxFavourites + 1].Id] == nil)
print("  cap: " .. tostring(whyCap))
task.wait(0.16)
check("favourite: taking one off works at the cap", (act("FavoriteDance", Dances.List[1].Id, false)) == true and profile.Data.FavDances[Dances.List[1].Id] == nil)
task.wait(0.3)
click(dp.FavouritesTab)
local favCards = 0
for _, c in grid:GetChildren() do if c:IsA("TextButton") then favCards += 1 end end
check("FAVOURITES tab lists the saved favourites", favCards == Dances.MaxFavourites - 1)
MM.close()
task.wait(0.2)

print(string.format("oct17 screens: %d ok, %d failed", ok, failed))
return nil

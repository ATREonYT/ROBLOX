-- Checks the screens made from the owner's Oct 17 mockups (design/ui-oct17) through the real server + client code:
-- the Shop COINS cards. Run by check.sh; prints "oct17 screens: N ok, 0 failed".
local Players = game:GetService("Players")
local ok, failed = 0, 0
local function check(name, cond)
	if cond then ok += 1 else failed += 1; print("FAIL " .. name) end
end

local P = game.ReplicatedStorage.Shared.Config.Products
-- (since Oct 21 the shipped config has the owner's real IDs: this check puts them back to 0 first, so it still tests
-- the "no ID yet: coming soon, never a purchase" path; tests/*.spec check the real IDs, and the Halloween knives as
-- the developer products they were)
P.Source = P.Source:gsub("Id = %d%d%d%d%d+", "Id = 0"):gsub("GamePass = true, ", "")
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

-- HOW TO PLAY: opens by itself on the first join, closing saves that, and the Menu opens it again
task.wait(1.6)
check("How to Play opens by itself on the first join", MM.current() == "HowToPlay" and gui.HowToPlay.Visible)
MM.close()
task.wait(0.4)
check("closing it saves that it was seen", profile.Data.Settings.TutorialDone == true)
-- then today's daily reward, by itself, right after the tutorial (owner, Oct 25: "pops up automatically when you join
-- the game after the tutorial")
task.wait(1.6)
check("the daily reward opens by itself after How to Play", MM.current() == "DailyLogin")
MM.close()
task.wait(0.4)
local menu = gui:FindFirstChild("Menu")
local entry = menu and menu:FindFirstChild("HowToPlay", true)
check("the Menu has a How to Play entry", entry ~= nil)
if entry then
	MM.open("Menu")
	task.wait(0.1)
	click(entry)
	for _ = 1, 40 do __stepTweens(0.05) end
end
check("the Menu's How to Play opens it", MM.current() == "HowToPlay")
local hp = gui.HowToPlay.Group.Panel
local titles = { "RUN ACROSS", "SAVE FRIENDS", "BE THE HERO" }
for i, t in titles do
	local c = hp:FindFirstChild("Card" .. i)
	check("card " .. i .. " " .. t, c ~= nil and c.Title.Text == t and c.Step.Digit.Text == tostring(i) and c.Picture:GetAttribute("Art") == "HowToPlay" .. i and #c.Blurb.Text > 20)
end
local keyText = {}
for _, d in hp.Keys:GetDescendants() do if d:IsA("TextLabel") then table.insert(keyText, d.Text) end end
local allKeys = table.concat(keyText, " | ")
check("keys: Space dashes (catchers dive)", hp.Keys.Key1.Cap.Key.Text == "Space" and hp.Keys.Key1.Label.Text == "Dash" and hp.Keys.Key1.Sub.Text:lower():find("dive") ~= nil)
check("keys: Q uses your ability", hp.Keys.Key2.Cap.Key.Text == "Q" and hp.Keys.Key2.Label.Text == "Ability")
check("keys: click stabs (catchers)", hp.Keys.Key3:FindFirstChild("Mouse") ~= nil and hp.Keys.Key3.Label.Text == "Click" and hp.Keys.Key3.Sub.Text == "Stab (Catchers)")
check("keys: Alt frees the mouse", hp.Keys.Key4.Cap.Key.Text == "Alt" and hp.Keys.Key4.Label.Text == "Free Mouse")
check("no jumping anywhere", not allKeys:lower():find("jump"))
local _, _, kw, kh = box(hp.Keys, hp)
local kx, ky = box(hp.Keys, hp)
check("the key row and cards sit inside the window", kx >= 12 and ky + kh <= 320 - 6 and kx + kw <= 701 - 12 and hp.Card3.Position.X.Offset + hp.Card3.Size.X.Offset <= 701 - 12)
check("HOW TO PLAY: whole pixels only", wholePixels(gui.HowToPlay))
MM.close()
task.wait(0.4)
check("it doesn't pop up again by itself", MM.current() == nil)

-- SHOP (owner, Oct 20 14:25 / 14:31: one page like his reference video, "all close to eachother"): one window, one
-- scrolling page, a jump button per section right of the window; COINS and AURA cards like the video's (251 x 338)
check("Shop opens at COINS", open("Shop", "Coins") and gui.Shop.Visible)
local shop = gui.Shop.Group.Panel
local products = shop.Products
local Products = require(game.ReplicatedStorage.Shared.Config.Products)
local prompts = #(_G.__prompts or {})
local order = { "Crates", "Dances", "Style", "Passes", "Aura", "Coins" } -- (Oct 21: knives and earned looks moved to the Inventory)
local okJ, lastY = true, -1
for _, k in order do
	local b = shop:FindFirstChild(k .. "Tab")
	if not b then okJ = false; continue end
	local x, y, w = box(b, shop)
	if x < 869 or x + w > 1005 or y <= lastY then okJ = false end
	lastY = y
end
check("the jump buttons right of the window, in the page's order", okJ)
local function atTop(key: string): boolean
	local h = products:FindFirstChild("Head" .. key)
	-- (since Oct 21 17:17 a jump lands on the cards, the header just above: owner, "show the crates straight away")
	local want = h and h.Position.Y.Offset + h.Size.Y.Offset + 4
	local maxY = math.max(0, products.CanvasSize.Y.Offset - products.Size.Y.Offset)
	return h ~= nil and math.abs(products.CanvasPosition.Y - math.min(want, maxY)) <= 1
end
check("opened at COINS: its cards at the top of the page", atTop("Coins"))
local inOrder, prevY = true, -1
for _, k in order do
	local h = products:FindFirstChild("Head" .. k)
	if not h or h.Position.Y.Offset <= prevY then inOrder = false end
	prevY = h and h.Position.Y.Offset or prevY
end
check("sections in order: crates, dances, style, passes, aura, coins", inOrder)
check("the featured banner on top: a real crate, no timer", products:FindFirstChild("Featured") ~= nil and products.Featured.Position.Y.Offset == 0 and products.Featured.Title.Text == "HALLOWEEN CRATE" and products.Featured:FindFirstChild("Timer", true) == nil)
for i, p in Products.Coins do
	local c = products:FindFirstChild(p.Key)
	check(p.Key .. " card shows", c ~= nil)
	if c then
		check(p.Key .. " title", c.Title.Text == p.Name)
		local pic = c:FindFirstChild("Picture")
		check(p.Key .. " picture is the mockup's coin art", pic ~= nil and pic:GetAttribute("Art") == "CoinPack" .. p.Amount)
		local buy = c:FindFirstChild("Buy")
		local badge = buy and buy:FindFirstChild("RobuxBadge", true)
		check(p.Key .. " price button keeps the Robux mark (not a coin)", badge ~= nil and badge.Visible and buy:FindFirstChild("Icon", true) == nil)
		check(p.Key .. " price shows", buy ~= nil and buy.Content.Label.Text == tostring(p.Price))
		check(p.Key .. " card is the video's size", c.Size == UDim2.fromOffset(251, 338))
		if i == 1 then
			click(buy)
			check("a coin pack that isn't on sale says so and never opens a purchase", toast():find("coming soon") ~= nil and #(_G.__prompts or {}) == prompts)
		end
	end
end
local c1, c2, c3 = products:FindFirstChild("Coins500"), products:FindFirstChild("Coins2000"), products:FindFirstChild("Coins5000")
check("COINS: three in a row, 14 px apart", c1 ~= nil and c2 ~= nil and c3 ~= nil and c1.Position.Y == c2.Position.Y and c2.Position.X.Offset - c1.Position.X.Offset == 265 and c3.Position.X.Offset - c2.Position.X.Offset == 265)
check("the page: whole pixels only", wholePixels(products))
check("tapping a coin pack grants nothing (only the server's receipt does)", profile.Data.Coins == 0)

-- AURA (owner, Oct 20 14:07: "make a buy section for aura"): 3 packs, Id 0 only says "coming soon"
local aura0 = profile.Data.Aura
click(shop.AuraTab)
for _ = 1, 40 do __stepTweens(0.05) end
task.wait(0.5)
check("the AURA jump button scrolls the page to AURA", atTop("Aura"))
check("... and wears the white rim", shop.AuraTab.Rim.Color == Color3.new(1, 1, 1) and shop.CoinsTab.Rim.Color ~= Color3.new(1, 1, 1))
check("AURA: 3 packs", #Products.Aura == 3)
for i, p in Products.Aura do
	local c = products:FindFirstChild(p.Key)
	check(p.Key .. " card shows", c ~= nil)
	if c then
		check(p.Key .. " title", c.Title.Text == p.Name)
		check(p.Key .. " picture is his Aura star", c:FindFirstChild("Star1") ~= nil)
		check(p.Key .. " price shows", c.Buy.Content.Label.Text == tostring(p.Price))
		check(p.Key .. " has no ID yet (never invented)", p.Id == 0)
		if i == 1 then
			click(c.Buy)
			check("an Aura pack without its ID only says coming soon, no purchase", toast():find("coming soon") ~= nil and #(_G.__prompts or {}) == prompts)
		end
	end
end
check("tapping an Aura pack grants nothing (only the server's receipt does)", profile.Data.Aura == aura0)
MM.close()
task.wait(0.2)
local hudPlus
for _, d in gui:GetDescendants() do
	if d.Name == "Plus" and d.Parent and d.Parent.Name == "Aura" and not d:IsDescendantOf(gui.Shop) then hudPlus = d; break end
end
check("the top bar has an Aura +", hudPlus ~= nil)
if hudPlus then click(hudPlus) end
check("the top bar's Aura + opens the Shop at AURA", MM.current() == "Shop" and atTop("Aura"))
open("Shop", "Coins")
click(shop.Header.Aura.Plus)
for _ = 1, 40 do __stepTweens(0.05) end
task.wait(0.5)
check("the Shop's own Aura + scrolls to AURA", atTop("Aura"))
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
check("all 38 dances have cards (the owner's 33 R6 ones and our 5, Oct 22)", #list == #Dances.List and #list == 38)
if #list >= 4 then
	local p1, p2, p3, p4 = list[1].Position, list[2].Position, list[3].Position, list[4].Position
	check("three cards to a row", p1.Y.Offset == p2.Y.Offset and p2.Y.Offset == p3.Y.Offset and p4.Y.Offset > p1.Y.Offset and p4.X.Offset == p1.X.Offset and p3.X.Offset > p2.X.Offset)
	local c1 = list[1]
	check("a card has the glow, notes, figure and name", c1:FindFirstChild("Glow") and c1.Glow:FindFirstChild("FxGlow") and c1.Glow:FindFirstChild("FxCore") and c1:FindFirstChild("Figure") and c1.Figure:GetAttribute("Art") == "DanceStill" .. c1.Name and (c1.Band:FindFirstChild("Name") :: any).Text == Dances.get(c1.Name).Name)
	do -- (yours bright in its colour, locked ones dimmed toward the card floor: Screens/Dances glow(), owner Oct 23 20:51)
		local col = Dances.Colors[Dances.get(c1.Name).Color] or Dances.Colors.Violet
		local h1 = col:ToHSV()
		local h2 = c1.Glow.FxGlow.ImageColor3:ToHSV()
		check("the card glows in its dance's colour", math.abs(h1 - h2) < 0.04 or math.abs(h1 - h2) > 0.96)
	end
end
local selectedCount = 0
for _, c in list do if c.Halo.Visible then selectedCount += 1 end end
check("exactly one card is highlighted", selectedCount == 1)
local pv = dp.Preview
if pv.DanceName.Text ~= "Beatbox" then print("  preview shows: " .. pv.DanceName.Text .. " / " .. pv.Blurb.Text) end
check("an owned dance's preview shows its name and line", pv.DanceName.Text == "Beatbox" and pv.Blurb.Text == Dances.get("Beatbox").Blurb and grid.Beatbox.Halo.Visible)
click(grid.Breakdance)
check("a locked dance shows locked, a dark figure and a lock", pv.Blurb.Text:find("Locked") == 1 and grid.Breakdance:FindFirstChild("Lock") ~= nil and pv.ArtBox:FindFirstChild("Lock") ~= nil and grid.Breakdance.Halo.Visible and not grid.Beatbox.Halo.Visible)
check("PLAY and STOP sit inside the preview", dp.Play.Visible and dp.Stop.Visible and dp.Play.Position.X.Offset > pv.Position.X.Offset and dp.Stop.Position.X.Offset + dp.Stop.Size.X.Offset / 2 < pv.Position.X.Offset + pv.Size.X.Offset)
check("search, sort and the three tabs", dp.Header:FindFirstChild("Search") and dp.Header:FindFirstChild("Sort") and dp:FindFirstChild("AllTab") and dp:FindFirstChild("OwnedTab") and dp:FindFirstChild("FavouritesTab") and dp.SortMenu:FindFirstChild("AToZ") and dp.SortMenu:FindFirstChild("ZToA"))
check("DANCES: whole pixels only", wholePixels(gui.Dances))
-- favourites are saved by the server, checked and capped
local function act(...) local r, why = State.action(...); task.wait(0.2); return r, why end -- (the server refuses actions closer than 0.15 s)
check("favourite: unknown dance refused", (act("FavoriteDance", "NotADance", true)) == false and profile.Data.FavDances.NotADance == nil)
check("favourite: needs true or false", (act("FavoriteDance", "OrangeSwing", "yes")) == false and profile.Data.FavDances.OrangeSwing == nil)
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

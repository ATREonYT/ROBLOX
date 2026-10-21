-- Checks the Shop's filters (owner, Oct 20 15:13: "add filters within the ui so people can find trails, titles, knifes
-- easier") through the real server + client code:
--   * KNIVES (only the knives you own since Oct 20 20:34: "make the knifes not be bought but opened from crates"):
--     rarity chips (ALL first, in rarity colours) and a search box, right under its header; a tap shows only what
--     matches at once, the grid closes up (rows of 5, no gaps), empty rarity headers hide,
--     "nothing matches" shows only when nothing does; the choice stays when the Shop is closed and opened again;
--   * COSMETICS: type chips (ALL, TRAILS, TITLES, NAME COLOURS, AURAS), rarity chips, OWNED / NOT OWNED, over both the
--     Robux looks and the coin looks;
--   * touch-sized chips (40 px high), whole pixels, inside the page;
--   * ABILITIES (UI/AbilityCards, Oct 20): its section shows both sides' cards (RUNNERS, CATCHERS) with its jump between
--     KNIVES and PASSES; without that module the section and its jump hide and PASSES moves up.
-- From tools/preview: lune run harness.luau ../../src - @check_filters.luau setup_ui.luau
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
local CoinShop = require(game.ReplicatedStorage.Shared.Config.CoinShop)
-- own the Dojo crate's ten knives (Common to Legendary) before the client starts
local Crates = require(game.ReplicatedStorage.Shared.Config.Crates)
local epic, common
local mine = {}
for _, it in Crates.get("Dojo").Items do
	local c = CoinShop.get(it.Id)
	mine[it.Id] = true
	if c.Rarity == "Epic" and not epic then epic = c end
	if c.Rarity == "Common" and not common then common = c end
end
DataService.update(player, function(d) for k in mine do d.Cosmetics[k] = true end end)
__runScript(game.StarterPlayer.StarterPlayerScripts.HuzzClient.Main)
task.wait(0.3)
local UI = game.StarterPlayer.StarterPlayerScripts.HuzzClient.UI
local MM = require(UI.ModalManager)
local gui = player.PlayerGui.HuzzUI
local function settle() for _ = 1, 40 do __stepTweens(0.05) end task.wait(0.3) end
local function click(btn) __fireOn(btn, "Activated"); task.wait(0.2) end
local function wholePixels(root: Instance): boolean
	for _, d in root:GetDescendants() do
		if d:IsA("GuiObject") then
			for _, v in { d.Position.X.Offset, d.Position.Y.Offset, d.Size.X.Offset, d.Size.Y.Offset } do
				if v ~= math.floor(v) then print("  half pixel: " .. d:GetFullName()); return false end
			end
		end
	end
	return true
end

MM.open("Shop", "Knives")
settle()
local panel = gui.Shop.Group.Panel
local body = panel.Products
local row = body:FindFirstChild("KnivesFilters")
check("KNIVES has its filter row", row ~= nil)
check("... right under its header", row ~= nil and row.Position.Y.Offset == body.HeadKnives.Position.Y.Offset + body.HeadKnives.Size.Y.Offset)
check("... and the page opens at KNIVES with the chips in view", row ~= nil and row.Position.Y.Offset - body.CanvasPosition.Y < 200)
local all = row and row:FindFirstChild("KnivesRarityAll")
check("rarity chips: ALL first, picked", all ~= nil and all.Position.X.Offset - all.Size.X.Offset / 2 == 0 and all:GetAttribute("Picked") == true)
local epicChip = row and row:FindFirstChild("KnivesRarityEpic")
check("an EPIC chip in Epic's colour", epicChip ~= nil and epicChip:FindFirstChild("Content").Label.Text == "EPIC")
check("a search box, no OWNED chips (they're all yours)", row ~= nil and row:FindFirstChild("KnivesOwnOwned") == nil and row:FindFirstChild("Search") ~= nil)
local inside, tall = true, true
for _, ch in (row and row:GetChildren() or {}) do
	if ch:IsA("GuiObject") then
		local left = ch.Position.X.Offset - ch.AnchorPoint.X * ch.Size.X.Offset
		if left < 0 or left + ch.Size.X.Offset > 795 then inside = false; print("  outside: " .. ch.Name) end
		if ch.Size.Y.Offset < 40 then tall = false end
	end
end
check("every chip and the box inside the page", inside)
check("touch-sized: 40 px high", tall)
check("whole pixels", row ~= nil and wholePixels(row))

-- the knife cards in KNIVES
local function knifeCards(): { GuiObject }
	local out = {}
	for _, it in CoinShop.Items do
		if it.Slot == "Knife" then
			local c = body:FindFirstChild(it.Key)
			if c then table.insert(out, c) end
		end
	end
	return out
end
local function shown(list) local n = 0 for _, c in list do if c.Visible then n += 1 end end return n end
local total = shown(knifeCards())
local onlyMine = true
for _, it in CoinShop.Items do
	if it.Slot == "Knife" and body:FindFirstChild(it.Key) and body[it.Key].Visible and not mine[it.Key] then onlyMine = false end
end
check(`ALL shows the knives you own, and only those ({total})`, total == 10 and onlyMine)
check("they wear, never buy", body[common.Key].Buy:FindFirstChild("Label", true).Text == "WEAR" or body[common.Key].Buy:FindFirstChild("Label", true).Text == "WEARING")

-- EPIC: only Epic knives, under the EPIC header; the other headers hide; the grid closes up
click(epicChip)
local onlyEpic, nEpic = true, 0
for _, it in CoinShop.Items do
	if it.Slot == "Knife" then
		local c = body:FindFirstChild(it.Key)
		if c and c.Visible then
			nEpic += 1
			if it.Rarity ~= "Epic" then onlyEpic = false end
		end
	end
end
check(`EPIC shows only Epic knives ({nEpic})`, onlyEpic and nEpic > 0)
check("EPIC is picked, ALL isn't", epicChip:GetAttribute("Picked") == true and all:GetAttribute("Picked") == false)
check("the EPIC header shows, COMMON's hides", body.HeadEpic.Visible and not body.HeadCommon.Visible)
-- tidy: the shown Epic cards sit in rows of 5 right under the EPIC header, 161 px apart
local cards = {}
for _, c in knifeCards() do if c.Visible then table.insert(cards, c) end end
table.sort(cards, function(a, b) return a.Position.Y.Offset < b.Position.Y.Offset or (a.Position.Y.Offset == b.Position.Y.Offset and a.Position.X.Offset < b.Position.X.Offset) end)
local tidy = #cards > 0 and cards[1].Position.Y.Offset == body.HeadEpic.Position.Y.Offset + body.HeadEpic.Size.Y.Offset
for i = 2, #cards do
	local a, b = cards[i - 1], cards[i]
	if (i - 1) % 5 ~= 0 then
		if b.Position.Y.Offset ~= a.Position.Y.Offset or b.Position.X.Offset - a.Position.X.Offset ~= 161 then tidy = false end
	elseif b.Position.Y.Offset ~= a.Position.Y.Offset + 236 then tidy = false end
end
check("the grid closes up: rows of 5, no gaps", tidy)
check("ABILITIES follows right after (no empty space)", body.HeadAbilities.Position.Y.Offset < cards[#cards].Position.Y.Offset + 224 + 200)

check("your Epic knife is there", body[epic.Key].Visible)

-- the search box: ALL + a word
click(all)
local word = string.lower(string.sub(common.Name, 1, 4))
row.Search.Box.Text = string.upper(word) -- (any case)
__fireOn(row.Search.Box, "Prop_Text") -- (the offline engine copy fires property signals only when asked)
task.wait(0.2)
local allMatch, nMatch = true, 0
for _, it in CoinShop.Items do
	if it.Slot == "Knife" then
		local c = body:FindFirstChild(it.Key)
		if c and c.Visible then
			nMatch += 1
			if not string.find(string.lower(it.Name), word, 1, true) then allMatch = false end
		end
	end
end
check(`search "{word}" shows only names with it ({nMatch})`, allMatch and nMatch >= 1 and body[common.Key].Visible)
check("the search hint hides while you type, the clear X shows", not row.Search.Hint.Visible and row.Search.Clear.Visible)
row.Search.Box.Text = "zzzz"
__fireOn(row.Search.Box, "Prop_Text")
task.wait(0.2)
check("nothing matches: no cards, one plain line", shown(knifeCards()) == 0 and body.NothingKnives.Visible)
click(row.Search.Clear)
__fireOn(row.Search.Box, "Prop_Text")
task.wait(0.1)
check("the X clears the search", row.Search.Box.Text == "" and shown(knifeCards()) == total and not body.NothingKnives.Visible)

-- remembered for the session: pick RARE, close, open again
click(row.KnivesRarityRare)
local nRare = shown(knifeCards())
MM.close()
task.wait(0.3)
MM.open("Shop", "Knives")
settle()
check(`RARE is still picked after closing the Shop ({nRare})`, row.KnivesRarityRare:GetAttribute("Picked") == true and shown(knifeCards()) == nRare)
click(all)

-- COSMETICS: type chips over the Robux looks and the coin looks
MM.open("Shop", "Cosmetics")
settle()
local crow = body:FindFirstChild("CosmeticsFilters")
check("COSMETICS has its filter row under its header", crow ~= nil and crow.Position.Y.Offset == body.HeadCosmetics.Position.Y.Offset + body.HeadCosmetics.Size.Y.Offset)
local names = {}
for _, k in { "All", "Trail", "Title", "Tag", "Aura" } do
	local b = crow and crow:FindFirstChild("CosmeticsType" .. k)
	if b then table.insert(names, b.Content.Label.Text) end
end
check(`type chips: {table.concat(names, ", ")}`, table.concat(names, ",") == "ALL,TRAILS,TITLES,NAME COLOURS,AURAS")
check("rarity chips and OWNED / NOT OWNED there too", crow ~= nil and crow:FindFirstChild("CosmeticsRarityAll") ~= nil and crow:FindFirstChild("CosmeticsOwnOwned") ~= nil)
local cinside = true
for _, ch in (crow and crow:GetChildren() or {}) do
	if ch:IsA("GuiObject") then
		local left = ch.Position.X.Offset - ch.AnchorPoint.X * ch.Size.X.Offset
		if left < 0 or left + ch.Size.X.Offset > 795 then cinside = false; print("  outside: " .. ch.Name) end
	end
end
check("the cosmetics chips fit the page", cinside and crow ~= nil and wholePixels(crow))
click(crow.CosmeticsTypeTrail)
local Products = require(game.ReplicatedStorage.Shared.Config.Products)
local onlyTrails, nT = true, 0
for _, it in CoinShop.Items do
	if it.Slot ~= "Knife" then
		local c = body:FindFirstChild(it.Key)
		if c and c.Visible then nT += 1; if it.Slot ~= "Trail" then onlyTrails = false end end
	end
end
for _, p in Products.Cosmetics do
	local c = body:FindFirstChild(p.Key)
	if c and c.Visible then nT += 1; if p.Slot ~= "Trail" then onlyTrails = false end end
end
check(`TRAILS shows only trails ({nT})`, onlyTrails and nT > 1 and body.SunsetTrail.Visible)
check("the knives aren't touched by the COSMETICS filters", shown(knifeCards()) == total)
click(crow.CosmeticsTypeTitle)
local onlyTitles = true
for _, it in CoinShop.Items do
	local c = it.Slot ~= "Knife" and body:FindFirstChild(it.Key)
	if c and c.Visible and it.Slot ~= "Title" then onlyTitles = false end
end
check("TITLES shows only titles", onlyTitles and not body.SunsetTrail.Visible)
click(crow.CosmeticsTypeAll)

-- the jump buttons (Oct 20 20:34): HALLOWEEN first, then CRATES, DANCES, KNIVES ... all inside the window's height
local order = { "Halloween", "Crates", "Dances", "Knives", "Abilities", "Passes", "Aura", "Coins", "Cosmetics" }
local inOrder, fits = true, true
for i, k in order do
	local b = panel:FindFirstChild(k .. "Tab")
	if not b or b.Position.Y.Offset ~= panel.HalloweenTab.Position.Y.Offset + (i - 1) * 49 then inOrder = false end
	if b and b.Position.Y.Offset + b.Size.Y.Offset / 2 > 550 then fits = false end
end
check("jump buttons: HALLOWEEN, CRATES, DANCES, KNIVES, ABILITIES, PASSES, AURA, COINS, COSMETICS", inOrder)
check("... all inside the window's height", fits)

-- DANCES (owner, Oct 20 20:34: "make a seperate section for dances ... make them be able to be bought there"): the
-- Dance Pack, then every dance with a coin price; a tap slides its panel in with a preview and BUY; BUY is checked on
-- the server (coins taken once, never twice)
local Dances = require(game.ReplicatedStorage.Shared.Config.Dances)
local sold, cardsOk = 0, true
for _, d in Dances.List do
	if d.Coins then
		sold += 1
		local c = body:FindFirstChild("Dance" .. d.Id)
		if not c or c.Position.Y.Offset < body.HeadDances.Position.Y.Offset or c.Position.Y.Offset > body.HeadKnives.Position.Y.Offset then cardsOk = false end
	elseif not d.Starter and not d.Pack then
		print("  not sold anywhere: " .. d.Id)
		cardsOk = false
	end
end
check(`DANCES: every dance that isn't free has its card there ({sold})`, cardsOk and sold >= 8) -- (the 4 Dance Pack ones are Robux only since Oct 21)
check("... the Dance Pack on top of it", body:FindFirstChild("DancePack") ~= nil and body.DancePack.Position.Y.Offset == body.HeadDances.Position.Y.Offset + body.HeadDances.Size.Y.Offset)
local zombie = Dances.get("ZombieGroove")
local zc = body.DanceZombieGroove
DataService.update(player, function(d) d.Coins = zombie.Coins + 100 end)
task.wait(0.2)
check(`a dance card shows its coin price ({zc.Buy:FindFirstChild("Label", true).Text})`, zc.Buy:FindFirstChild("Label", true).Text == "2,000")
click(zc.Tap)
settle()
local side = panel.Side
check("tapping a dance slides its panel in: its name, a preview, BUY", side.Visible and side.Panel.DanceView.Visible and side.Panel.Title.Text == "ZOMBIE GROOVE"
	and side.Panel.DanceView.Backdrop.Still:GetAttribute("Art") == "DanceStillZombieGroove" and side.Panel.DanceView.Buy:FindFirstChild("Label", true).Text == "BUY 2,000")
click(side.Panel.DanceView.Buy)
local data = DataService.get(player).Data
check(`BUY: the dance is yours, the coins taken once ({data.Coins})`, data.Dances.ZombieGroove == true and data.Coins == 100)
settle()
check("... and its card says OWNED", zc.Buy:FindFirstChild("Label", true).Text == "OWNED" and side.Panel.DanceView.Buy:FindFirstChild("Label", true).Text == "YOURS!")
local Action = game.ReplicatedStorage.Remotes.Action
task.wait(0.25)
local okA = Action:InvokeServer("BuyDance", "ZombieGroove")
task.wait(0.25)
local okB = Action:InvokeServer("BuyDance", "Floss")
task.wait(0.25)
DataService.update(player, function(d) d.Coins = 10 end)
local okC, whyC = Action:InvokeServer("BuyDance", "Robot")
check(`the server refuses a dance you own, a free one, and one you can't afford ({whyC})`, okA == false and okB == false and okC == false and data.Coins == 10 and data.Dances.Robot ~= true)
click(side.Shade)
settle()

-- ABILITIES: UI/AbilityCards builds both sides in its slot, its jump between KNIVES and PASSES
check("the ABILITIES jump shows, between KNIVES and PASSES", panel.AbilitiesTab.Visible and body.HeadAbilities.Visible
	and panel.AbilitiesTab.Position.Y.Offset == panel.KnivesTab.Position.Y.Offset + 49 and panel.PassesTab.Position.Y.Offset == panel.KnivesTab.Position.Y.Offset + 98)
local abSlot = body:FindFirstChild("AbilitiesSlot")
check("... its section holds the runner and the catcher cards", abSlot ~= nil and abSlot.Visible and abSlot:FindFirstChild("RunnerAbilities") ~= nil
	and abSlot:FindFirstChild("CatcherAbilities") ~= nil and abSlot.RunnerAbilities:FindFirstChild("Lasso") == nil and abSlot.CatcherAbilities:FindFirstChild("Lasso") ~= nil)
check("... sized to its cards, and PASSES comes after it", abSlot ~= nil and abSlot.Size.Y.Offset >= abSlot.CatcherAbilities.Position.Y.Offset + abSlot.CatcherAbilities.Size.Y.Offset
	and body.HeadPasses.Position.Y.Offset >= abSlot.Position.Y.Offset + abSlot.Size.Y.Offset)
-- without the builder, a fresh Shop hides the section and its jump, and PASSES moves up into its place
local real = UI:FindFirstChild("AbilityCards")
if real then real.Parent = nil end
local sg = Instance.new("ScreenGui"); sg.Name = "Fresh"; sg.Parent = player.PlayerGui
local okB, err = pcall(function() require(UI.Screens.Shop).build(sg) end)
check("a Shop builds without AbilityCards: " .. tostring(err), okB)
local fresh = sg:FindFirstChild("Shop")
local fp = fresh and fresh.Group.Panel
check("... no ABILITIES jump or section", fp ~= nil and not fp.AbilitiesTab.Visible and not fp.Products.HeadAbilities.Visible)
check("... PASSES' jump moves up into its place", fp ~= nil and fp.PassesTab.Position.Y.Offset == fp.KnivesTab.Position.Y.Offset + 49)
if real then real.Parent = UI end

print(string.format("filters: %d ok, %d failed", ok, failed))

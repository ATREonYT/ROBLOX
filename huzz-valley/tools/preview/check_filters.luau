-- Checks the Shop's filters (owner, Oct 20 15:13: "add filters within the ui so people can find trails, titles, knifes
-- easier") through the real server + client code:
--   * KNIVES: rarity chips (ALL first, in rarity colours), OWNED / NOT OWNED, a search box, right under its header;
--     a tap shows only what matches at once, the grid closes up (rows of 5, no gaps), empty rarity headers hide,
--     "nothing matches" shows only when nothing does; the choice stays when the Shop is closed and opened again;
--   * COSMETICS: type chips (ALL, TRAILS, TITLES, NAME COLOURS, AURAS), rarity chips, OWNED / NOT OWNED, over both the
--     Robux looks and the coin looks;
--   * touch-sized chips (40 px high), whole pixels, inside the page;
--   * ABILITIES: hidden (section and jump button) until UI/AbilityCards exists; with one, its section and jump show.
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
-- own two knives (an Epic and a Common) before the client starts
local epic, common
for _, it in CoinShop.Items do
	if it.Slot == "Knife" and not it.NotForSale and not it.Unlock and not it.Pass then
		if it.Rarity == "Epic" and not epic then epic = it end
		if it.Rarity == "Common" and not common then common = it end
	end
end
DataService.update(player, function(d) d.Cosmetics[epic.Key] = true; d.Cosmetics[common.Key] = true end)
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
check("OWNED / NOT OWNED and a search box", row ~= nil and row:FindFirstChild("KnivesOwnOwned") ~= nil and row:FindFirstChild("KnivesOwnNotOwned") ~= nil and row:FindFirstChild("Search") ~= nil)
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

-- the knife cards by section (the coin knives and the Halloween ones)
local function knifeCards(): { GuiObject }
	local out = {}
	for _, it in CoinShop.Items do
		if it.Slot == "Knife" then
			local c = body:FindFirstChild(it.Key) or body:FindFirstChild("Halloween" .. it.Key)
			if c then table.insert(out, c) end
		end
	end
	return out
end
local function shown(list) local n = 0 for _, c in list do if c.Visible then n += 1 end end return n end
local total = shown(knifeCards())
check(`ALL shows every knife on sale ({total})`, total > 30)

-- EPIC: only Epic knives, under the EPIC header; the other headers hide; the grid closes up
click(epicChip)
local onlyEpic, nEpic = true, 0
for _, it in CoinShop.Items do
	if it.Slot == "Knife" then
		local c = body:FindFirstChild(it.Key) or body:FindFirstChild("Halloween" .. it.Key)
		if c and c.Visible then
			nEpic += 1
			if it.Rarity ~= "Epic" then onlyEpic = false end
		end
	end
end
check(`EPIC shows only Epic knives ({nEpic})`, onlyEpic and nEpic > 0)
check("EPIC is picked, ALL isn't", epicChip:GetAttribute("Picked") == true and all:GetAttribute("Picked") == false)
check("the EPIC header shows, COMMON's hides", body.HeadEpic.Visible and not body.HeadCommon.Visible)
check("the Halloween knives' header hides (none is Epic)", not body.HeadHalloween.Visible)
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
check("ABILITIES / PASSES follow right after (no empty space)", body.HeadPasses.Position.Y.Offset < cards[#cards].Position.Y.Offset + 224 + 200)

-- OWNED on top: only your Epic knife
click(row.KnivesOwnOwned)
check(`EPIC + OWNED: only your Epic knife ({shown(knifeCards())})`, shown(knifeCards()) == 1 and body[epic.Key].Visible)
-- tap OWNED again: back to all Epic
click(row.KnivesOwnOwned)
check("OWNED again turns it off", shown(knifeCards()) == nEpic and row.KnivesOwnOwned:GetAttribute("Picked") == false)

-- the search box: ALL + a word
click(all)
local word = string.lower(string.sub(common.Name, 1, 4))
row.Search.Box.Text = string.upper(word) -- (any case)
__fireOn(row.Search.Box, "Prop_Text") -- (the offline engine copy fires property signals only when asked)
task.wait(0.2)
local allMatch, nMatch = true, 0
for _, it in CoinShop.Items do
	if it.Slot == "Knife" then
		local c = body:FindFirstChild(it.Key) or body:FindFirstChild("Halloween" .. it.Key)
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

-- ABILITIES: none yet, so hidden; the page has no gap for it
check("no ABILITIES jump button yet", not panel.AbilitiesTab.Visible and not body.HeadAbilities.Visible)
check("PASSES' jump button moves up into its place", panel.PassesTab.Position.Y.Offset == panel.KnivesTab.Position.Y.Offset + 49)
-- with a builder (another part of the game makes UI/AbilityCards), a fresh Shop shows the section and its jump
local m = Instance.new("ModuleScript"); m.Name = "AbilityCards"
m.Source = [[local M = {}
function M.build(parent)
	local f = Instance.new("Frame"); f.Name = "AbilityCard"; f.Size = UDim2.fromOffset(251, 338); f.Parent = parent
	return 338
end
return M]]
m.Parent = UI
local sg = Instance.new("ScreenGui"); sg.Name = "Fresh"; sg.Parent = player.PlayerGui
local okB, err = pcall(function() require(UI.Screens.Shop).build(sg) end)
check("a Shop builds with AbilityCards: " .. tostring(err), okB)
local fresh = sg:FindFirstChild("Shop")
local fp = fresh and fresh.Group.Panel
check("... its ABILITIES jump shows, between KNIVES and PASSES", fp ~= nil and fp.AbilitiesTab.Visible and fp.AbilitiesTab.Position.Y.Offset == fp.KnivesTab.Position.Y.Offset + 49 and fp.PassesTab.Position.Y.Offset == fp.KnivesTab.Position.Y.Offset + 98)
local slot = fp and fp.Products:FindFirstChild("AbilitiesSlot")
check("... and its section holds the cards", slot ~= nil and slot.Visible and slot.Size.Y.Offset == 338 and slot:FindFirstChild("AbilityCard") ~= nil and fp.Products.HeadAbilities.Visible)
m:Destroy()

print(string.format("filters: %d ok, %d failed", ok, failed))

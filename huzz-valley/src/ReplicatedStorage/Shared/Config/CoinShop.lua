--!strict
--[[
	The coin shop (owner's call: "make the coins usable"; they chose cosmetics): looks only, nothing that changes how
	the game plays. Bought and worn on the server (ActionService "BuyWithCoins" / "Wear"); shown to everyone.
	Every item is made from colours in code (no uploaded pictures needed), so all of it works today.
	  Slot   Trail = a streak behind you as you run; Tag = your name's colour over your head; Knife = the catcher's knife.
	  Colors two or three colours (a gradient); Rainbow = cycles through the colours.
	  Price  coins. Tune freely; the earn rate is in Config/Round (coins per round) and the quests.
	One item per slot is worn at a time; buying one wears it. Sunset Trail (a Robux cosmetic) is a Trail too.
]]
export type Item = { Key: string, Slot: "Trail" | "Tag" | "Knife", Name: string, Price: number, Colors: { Color3 }, Rainbow: boolean?, Order: number }

local rgb = Color3.fromRGB
local CoinShop = {}

CoinShop.Slots = { "Trail", "Tag", "Knife" }
CoinShop.SlotNames = { Trail = "TRAIL", Tag = "NAME COLOUR", Knife = "KNIFE" }

CoinShop.Items = {
	-- Trails
	{ Key = "MintTrail", Slot = "Trail", Name = "Mint Trail", Price = 400, Colors = { rgb(140, 255, 210), rgb(60, 200, 160) }, Order = 1 },
	{ Key = "OceanTrail", Slot = "Trail", Name = "Ocean Trail", Price = 750, Colors = { rgb(120, 220, 255), rgb(40, 110, 255) }, Order = 2 },
	{ Key = "CandyTrail", Slot = "Trail", Name = "Candy Trail", Price = 1000, Colors = { rgb(255, 150, 210), rgb(170, 120, 255) }, Order = 3 },
	{ Key = "GalaxyTrail", Slot = "Trail", Name = "Galaxy Trail", Price = 2500, Colors = { rgb(120, 90, 255), rgb(255, 90, 200), rgb(90, 220, 255) }, Rainbow = true, Order = 4 },
	-- Name colours
	{ Key = "TagPink", Slot = "Tag", Name = "Pink Name", Price = 300, Colors = { rgb(255, 130, 200), rgb(255, 130, 200) }, Order = 5 },
	{ Key = "TagSky", Slot = "Tag", Name = "Sky Name", Price = 300, Colors = { rgb(110, 210, 255), rgb(110, 210, 255) }, Order = 6 },
	{ Key = "TagLime", Slot = "Tag", Name = "Lime Name", Price = 300, Colors = { rgb(150, 245, 110), rgb(150, 245, 110) }, Order = 7 },
	{ Key = "TagRainbow", Slot = "Tag", Name = "Rainbow Name", Price = 1500, Colors = { rgb(255, 110, 110), rgb(255, 220, 90), rgb(110, 240, 140), rgb(110, 180, 255), rgb(200, 120, 255) }, Rainbow = true, Order = 8 },
	-- Knives (catchers)
	{ Key = "IceKnife", Slot = "Knife", Name = "Ice Knife", Price = 800, Colors = { rgb(170, 230, 255), rgb(60, 160, 255) }, Order = 9 },
	{ Key = "CandyKnife", Slot = "Knife", Name = "Candy Knife", Price = 800, Colors = { rgb(255, 160, 215), rgb(255, 90, 170) }, Order = 10 },
	{ Key = "ShadowKnife", Slot = "Knife", Name = "Shadow Knife", Price = 1500, Colors = { rgb(40, 34, 60), rgb(170, 90, 255) }, Order = 11 },
} :: { Item }

local byKey: { [string]: Item } = {}
for _, item in CoinShop.Items do
	assert(not byKey[item.Key], "duplicate coin item " .. item.Key)
	byKey[item.Key] = item
end

function CoinShop.get(key: string): Item?
	return byKey[key]
end

-- A ColorSequence through the item's colours (for trails, name gradients and previews).
function CoinShop.sequence(item: Item): ColorSequence
	local keys = {}
	local n = #item.Colors
	for i, c in item.Colors do
		table.insert(keys, ColorSequenceKeypoint.new(if n == 1 then 0 else (i - 1) / (n - 1), c))
	end
	if n == 1 then table.insert(keys, ColorSequenceKeypoint.new(1, item.Colors[1])) end
	return ColorSequence.new(keys)
end

return CoinShop

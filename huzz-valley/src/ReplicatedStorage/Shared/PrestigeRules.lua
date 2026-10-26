--[[
	Prestige (owner, Oct 19: "if you get more than one of the same girl, make a button which makes them prestige that
	gives them cooler vfx"). Pure rules (no Instances), used by ActionService ("Prestige"), RoundService (a won copy),
	Screens/Index (the PRESTIGE button) and Gameplay/Auras (her effects); tests/PrestigeRules.spec.
	  * Winning a girl you already own still pays her duplicate coins (Config/Round.DupeCoins, nothing taken away) AND
	    saves a copy (Shared/CombineRules: Copies[id].Normal += 1; the Combine machine spends copies too, Oct 20).
	  * PRESTIGE in the Index spends Cost spare Normal copies (never her last copy) and raises Prestige[id] by one,
	    up to Max (3).
	  * Her effects (on her and on you while she's equipped) then use a rarer tier's look: one tier up per level,
	    never past Mythic (the Secret look, crystals and butterflies, stays the Secret girls' own). A Mythic girl is
	    already at the top tier: her prestige shows only as PRESTIGE N/3 in the Index (a known gap).
]]
local CombineRules = require(script.Parent.CombineRules)

local PrestigeRules = {}

PrestigeRules.Max = 3
PrestigeRules.Cost = 1 -- copies per level
local ORDER = { "Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythic", "Secret", "Divine" }
local RANK = {}
for i, r in ORDER do RANK[r] = i end
local TOP = RANK.Mythic

function PrestigeRules.level(data: any, id: string): number
	return math.clamp(math.floor(tonumber((data and data.Prestige or {})[id]) or 0), 0, PrestigeRules.Max)
end

-- Her spare Normal copies: Normal ones, keeping her last copy of any grade (CombineRules).
function PrestigeRules.copies(data: any, id: string): number
	local normal = CombineRules.count(data, id, "Normal")
	return math.max(0, math.min(normal, CombineRules.total(data, id) - 1))
end

-- Whether PRESTIGE can be pressed: owned, a spare copy, below the top level. Returns ok and why not.
function PrestigeRules.can(data: any, id: any): (boolean, string?)
	if type(id) ~= "string" or not (data and data.Characters and data.Characters[id]) then return false, "You don't own her yet." end
	if PrestigeRules.level(data, id) >= PrestigeRules.Max then return false, "She's at top prestige!" end
	if PrestigeRules.copies(data, id) < PrestigeRules.Cost then return false, "Win her again to prestige her." end
	return true, nil
end

-- Spends the copies and raises her level. Returns the new level, or nil and why.
function PrestigeRules.apply(data: any, id: any): (number?, string?)
	local ok, why = PrestigeRules.can(data, id)
	if not ok then return nil, why end
	for _ = 1, PrestigeRules.Cost do CombineRules.take(data, id, "Normal") end
	data.Prestige = data.Prestige or {}
	data.Prestige[id] = PrestigeRules.level(data, id) + 1
	return data.Prestige[id], nil
end

-- A won copy of a girl (Shared/CombineRules.add: a Normal copy).
function PrestigeRules.addCopy(data: any, id: string)
	CombineRules.add(data, id, "Normal")
end

-- The tier whose effects she shows at this prestige level (one up per level, capped at Mythic; Secret stays Secret).
function PrestigeRules.effectRarity(rarity: string, level: number?): string
	local r = RANK[rarity]
	if not r or rarity == "Secret" or rarity == "Divine" then return rarity end
	local lv = math.clamp(math.floor(tonumber(level) or 0), 0, PrestigeRules.Max)
	return ORDER[math.min(math.max(r, math.min(r + lv, TOP)), #ORDER)]
end

-- "★★☆" style text is avoided (Gotham has no star glyph in Roblox): "PRESTIGE 2/3"
function PrestigeRules.label(level: number): string
	return `PRESTIGE {level}/{PrestigeRules.Max}`
end

return PrestigeRules

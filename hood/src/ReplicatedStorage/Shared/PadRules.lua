--!strict
-- The two pads before every gate (brief 23, the reference's "200K Wins / Return" and "2M Wins / 10x Wins"): pure rules
-- shared by StageService (which pays), the pads' labels and the unit tests.
--   Yellow "Return" pad: pays reward(stage, false) and takes you to the lobby (the run ends).
--   Magenta "10x Cash" pad: pays reward(stage, true) = TenX times that, with the 10x Cash game pass (Pass_TenXCash);
--     without it the pad shows the pass's purchase prompt and does nothing else.
--   Both only after that stage's goons are down, once per run per stage (STAGES' rules).
-- reward() is the pad's Cash BEFORE the 2x Cash and VIP passes: the server pays Boosts.cashFor(player, reward) like
-- every Cash reward. The numbers are Config/Balance.PadCash (Stage 1 = 10, growing every stage; 16 = the boss yard).
local Balance = require(script.Parent.Config.Balance)
local Format = require(script.Parent.Format)
local Products = require(script.Parent.Config.Products)

local PadRules = {}
PadRules.TenX = 10 -- the magenta pad pays this many times the yellow one
PadRules.Pass = 'TenXCash' -- its game pass (Config/Products.Passes)
PadRules.Stages = #Balance.PadCash

local function stageOf(stage: any): number
	if type(stage) ~= 'number' or stage ~= stage then return 1 end
	return math.clamp(math.floor(stage), 1, PadRules.Stages)
end

-- The pad's Cash at `stage` (junk and out-of-range stages are clamped to 1..Stages): x TenX on the magenta pad.
function PadRules.reward(stage: any, tenX: boolean?): number
	local base = Balance.PadCash[stageOf(stage)]
	return tenX == true and base * PadRules.TenX or base
end

-- Does this player own the 10x Cash pass? (The attribute StoreService sets on the server; a client can read it too.)
function PadRules.owns(player: any): boolean
	return typeof(player) == 'Instance' and (player :: any):GetAttribute('Pass_' .. PadRules.Pass) == true
end

-- '+10 Cash', '+1.5K Cash' (the currency's name is Balance.CashName).
function PadRules.text(amount: number): string
	return '+' .. Format.compact(math.max(0, math.floor(amount))) .. ' ' .. Balance.CashName
end

-- A pad's label lines: big, small, price.
--   kind 'Return': '+10 Cash', 'Return', nil
--   kind 'TenX':   '+100 Cash', '10x Cash', and while you don't own the pass its price: the Robux sign and the pass's
--                  Catalog price (Products.RobuxMark .. '199': U+E002, Roblox fonts' Robux sign, which a terminal
--                  prints as nothing); nil when `owned`.
function PadRules.labels(stage: any, kind: string, owned: boolean?): (string, string, string?)
	if kind == 'TenX' then
		local entry = Products.ByKey[PadRules.Pass]
		local tag = (not owned and entry and type(entry.Price) == 'number') and (Products.RobuxMark .. tostring(entry.Price)) or nil
		return PadRules.text(PadRules.reward(stage, true)), PadRules.TenX .. 'x ' .. Balance.CashName, tag
	end
	return PadRules.text(PadRules.reward(stage, false)), 'Return', nil
end

return PadRules

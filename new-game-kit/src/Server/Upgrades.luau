--!strict
-- New Game Kit: Upgrades
-- Install: ServerScriptService/Kit/Upgrades (ModuleScript)
--
-- Levels bought with a currency. Level i (0-based) costs floor(baseCost * growth^i).
-- Each upgrade has one effect:
--   { kind = "multiplier", currency = "Coins", perLevel = 0.1 }  -> earn x(1 + level * perLevel)
--   { kind = "stat", perLevel = 2, base = 16 }                   -> read with Upgrades.Value (walk speed, income/s, bag size)
-- keepOnRebirth = false resets the level when the player rebirths (Main wires that).
-- Remote: Upgrades.Buy(key) -> { level, cost }
-- Attributes: Upgrade_<key> = level (UI only)
-- Status: runs in the offline Lune harness (tools/test.luau, tools/sim.luau); not yet run in Studio.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Kit")
local Net = require(Shared:WaitForChild("Net"))
local Signal = require(Shared:WaitForChild("Signal"))
local PlayerData = require(script.Parent.PlayerData)
local Currency = require(script.Parent.Currency)

local T = Net.T

export type Effect = { kind: "multiplier", currency: string, perLevel: number } | { kind: "stat", perLevel: number, base: number? }
export type UpgradeDef = {
	name: string,
	currency: string, -- paid with
	baseCost: number,
	growth: number, -- >= 1
	maxLevel: number,
	effect: Effect,
	keepOnRebirth: boolean?, -- default true
}
export type Config = { upgrades: { [string]: UpgradeDef } }

local Upgrades = {}
Upgrades.Changed = Signal.new() -- (player, key, level)

local defs: { [string]: UpgradeDef } = {}
local MAX_SAFE = 2 ^ 53

-- Pure: cost of the next level when `level` levels are owned. math.huge if not representable.
function Upgrades.costAt(def: UpgradeDef, level: number): number
	local cost = def.baseCost * def.growth ^ level
	if cost ~= cost or cost >= MAX_SAFE then
		return math.huge
	end
	return math.floor(cost)
end

-- Pure: the effect value at a level.
function Upgrades.effectAt(def: UpgradeDef, level: number): number
	local effect = def.effect :: any
	if effect.kind == "multiplier" then
		return 1 + level * effect.perLevel
	end
	return (effect.base or 0) + level * effect.perLevel
end

function Upgrades.Level(player: Player, key: string): number
	local profile = PlayerData.Get(player)
	return if profile then profile.Data.Upgrades.Levels[key] or 0 else 0
end

-- The stat value for this player (for "stat" upgrades), or the multiplier.
function Upgrades.Value(player: Player, key: string): number
	local def = defs[key]
	assert(def, `Upgrades.Value: unknown upgrade {key}`)
	return Upgrades.effectAt(def, Upgrades.Level(player, key))
end

local function setLevel(player: Player, profile: PlayerData.Profile, key: string, level: number)
	profile.Data.Upgrades.Levels[key] = if level > 0 then level else nil
	PlayerData.MarkDirty(profile)
	player:SetAttribute(`Upgrade_{key}`, level)
	Upgrades.Changed:Fire(player, key, level)
end

local function buy(player: Player, key: string): Net.Result
	local def = defs[key]
	local profile = PlayerData.Get(player)
	if not profile then
		return Net.fail("NotReady")
	end
	local level = profile.Data.Upgrades.Levels[key] or 0
	if level >= def.maxLevel then
		return Net.fail("MaxReached")
	end
	local cost = Upgrades.costAt(def, level)
	if cost == math.huge or not Currency.Spend(player, def.currency, cost, `upgrade:{key}`) then
		return Net.fail("NotEnough")
	end
	setLevel(player, profile, key, level + 1)
	return Net.ok({ level = level + 1, cost = cost })
end

-- Reset every upgrade with keepOnRebirth = false (call from Rebirth.Rebirthed).
function Upgrades.ResetForRebirth(player: Player)
	local profile = PlayerData.Get(player)
	if not profile then
		return
	end
	for key, def in defs do
		if def.keepOnRebirth == false and (profile.Data.Upgrades.Levels[key] or 0) > 0 then
			setLevel(player, profile, key, 0)
		end
	end
end

function Upgrades.Init(config: Config)
	for key, def in config.upgrades do
		assert(string.match(key, "^[%w_]+$") and #key <= 32, `Upgrades: bad key '{key}'`)
		assert(Currency.Exists(def.currency), `Upgrades {key}: unknown currency {def.currency}`)
		assert(def.baseCost >= 1 and def.growth >= 1 and def.growth < 100, `Upgrades {key}: baseCost >= 1, growth 1..100`)
		assert(def.maxLevel >= 1 and math.floor(def.maxLevel) == def.maxLevel, `Upgrades {key}: maxLevel must be a whole number >= 1`)
		local effect = def.effect :: any
		assert(effect.kind == "multiplier" or effect.kind == "stat", `Upgrades {key}: effect.kind is multiplier or stat`)
		assert(type(effect.perLevel) == "number" and effect.perLevel >= 0, `Upgrades {key}: perLevel >= 0`)
		defs[key] = def
		if effect.kind == "multiplier" then
			assert(Currency.Exists(effect.currency), `Upgrades {key}: unknown effect currency {effect.currency}`)
			Currency.AddMultiplier(effect.currency, function(player: Player): number
				return Upgrades.effectAt(def, Upgrades.Level(player, key))
			end)
		end
	end

	PlayerData.RegisterSlice("Upgrades", function()
		return { Levels = {} }
	end)
	Net.Handle("Upgrades.Buy", {
		rate = { burst = 8, perSecond = 4 },
		args = { T.key(defs) },
		handler = buy,
	})
	PlayerData.Loaded:Connect(function(player: Player, profile: PlayerData.Profile)
		for key in defs do
			player:SetAttribute(`Upgrade_{key}`, profile.Data.Upgrades.Levels[key] or 0)
		end
	end)
end

return Upgrades

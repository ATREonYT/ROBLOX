--[[
	How hidden each body is on this screen, 0 (seen) .. 1 (gone), for the effects that hang off a body but aren't in
	it (the girl's aura in HuzzAuraFX: Gameplay/Auras; the knife's motes: Gameplay/KnifeFxRange). Gameplay/PowerEffects
	writes it every frame: an Invisible runner on other screens, and a runner inside a Smoke Bomb cloud (owner, Oct 21:
	"the invisible should be completely invisible"). A runner Radar spots shows again (PowerEffects caps it).
]]
local M = {}

local level = {} :: { [Instance]: number }

function M.set(character: Instance, value: number)
	level[character] = if value > 0 then value else nil
end

function M.of(character: Instance?): number
	return character and level[character] or 0
end

-- Hidden enough that the extras (auras, motes, trails) switch off.
function M.gone(character: Instance?): boolean
	return M.of(character) >= 0.5
end

function M.clear()
	table.clear(level)
end

return M

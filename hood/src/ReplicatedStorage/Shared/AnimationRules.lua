--!strict
-- The owner's movement pack on the characters (Config/Animations). Pure helpers, unit-tested (AnimationRules_Test):
--   AnimationRules.id(v)            'rbxassetid://N' for a number or a digit string (with or without the prefix), else nil
--   AnimationRules.Slots            each move's Animation objects inside Roblox's R15 Animate script
--   AnimationRules.apply(animate)   points the Animate script's Animations at the pack's moves (only the ones with an id);
--                                   returns how many it changed. Animate watches its values and reloads by itself.
--   AnimationRules.track(animator, move)  a looped AnimationTrack of a move for an NPC's Animator (nil without an id)
--   AnimationRules.oneShot(animator, move) a fight move (Punch, Kick) played once at Action priority (nil without an id)
local AnimationRules = {}
local okC, Config = pcall(function() return require(script.Parent.Config.Animations) end)
AnimationRules.Config = okC and type(Config) == 'table' and Config or {}

-- Roblox's R15 Animate script: a StringValue per move, its Animation children.
AnimationRules.Slots = {
	Idle = { idle = { 'Animation1', 'Animation2' } },
	Walk = { walk = { 'WalkAnim' } },
	Run = { run = { 'RunAnim' } },
	Jump = { jump = { 'JumpAnim' } },
	Fall = { fall = { 'FallAnim' } },
	Climb = { climb = { 'ClimbAnim' } },
	Swim = { swim = { 'Swim' }, swimidle = { 'SwimIdle' } },
}

-- (Oct 28, the feel round) moves Roblox's Animate script doesn't play: CharMotion.melee plays them (AnimationRules.oneShot)
AnimationRules.FightMoves = { Punch = true, Kick = true }

function AnimationRules.id(v: any): string?
	if type(v) == 'number' then
		if v > 0 and v % 1 == 0 then return 'rbxassetid://' .. string.format('%d', v) end
		return nil
	end
	if type(v) ~= 'string' then return nil end
	local digits = string.match(v, '^%s*rbxassetid://(%d+)%s*$') or string.match(v, '^%s*(%d+)%s*$')
	if not digits or tonumber(digits) == 0 then return nil end
	return 'rbxassetid://' .. digits
end

function AnimationRules.moveId(move: string, config: any?): string?
	local c = type(config) == 'table' and config or AnimationRules.Config
	return AnimationRules.id(c[move])
end

function AnimationRules.apply(animate: Instance?, config: any?): number
	if typeof(animate) ~= 'Instance' then return 0 end
	local changed = 0
	for move, sets in AnimationRules.Slots do
		local id = AnimationRules.moveId(move, config)
		if id then
			for setName, names in sets do
				local set = animate:FindFirstChild(setName)
				if set then
					for _, name in names do
						local anim = set:FindFirstChild(name)
						if anim and anim:IsA('Animation') and anim.AnimationId ~= id then
							anim.AnimationId = id
							changed += 1
						end
					end
				end
			end
		end
	end
	return changed
end

function AnimationRules.track(animator: Instance?, move: string, config: any?): any
	local id = AnimationRules.moveId(move, config)
	if not id or typeof(animator) ~= 'Instance' or not animator:IsA('Animator') then return nil end
	local anim = Instance.new('Animation')
	anim.AnimationId = id
	local ok, track = pcall(function() return (animator :: any):LoadAnimation(anim) end)
	if not ok or not track then return nil end
	track.Looped = move ~= 'Jump'
	return track
end

-- (Oct 28, the feel round) a fight move played once over everything else (Punch, Kick): nil without an id
function AnimationRules.oneShot(animator: Instance?, move: string, config: any?): any
	local id = AnimationRules.moveId(move, config)
	if not id or typeof(animator) ~= 'Instance' or not animator:IsA('Animator') then return nil end
	local anim = Instance.new('Animation')
	anim.AnimationId = id
	local ok, track = pcall(function() return (animator :: any):LoadAnimation(anim) end)
	if not ok or not track then return nil end
	track.Looped = false
	pcall(function() track.Priority = Enum.AnimationPriority.Action end)
	return track
end

return AnimationRules

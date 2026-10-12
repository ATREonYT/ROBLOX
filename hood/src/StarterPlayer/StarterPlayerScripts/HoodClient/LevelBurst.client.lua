-- (brief 30, FIGHTS) The reference's level-up in the world (bible 2.6 "Level up", F7; ref_W32.4_levelup_burst, W 32.0-32.8
-- s): a gold-white burst of light round you, radiating gold rays, and a column of white chevrons rising over your head,
-- about 0.8 s (Shared/FightFX.levelBurst). Progress.client's small "Level 6 > Level 7" toast at the top stays with it (the
-- reference shows both: the burst at Level 3, the toast at later levels). Levels come quickly at first (LevelRules: one
-- every 1.5x Power), so the burst plays at most once every Gap seconds; never with Reduced Motion.
local Players = game:GetService('Players')
local RS = game:GetService('ReplicatedStorage')
local LevelRules = require(RS.Shared.LevelRules)
local FightFX = require(RS.Shared.FightFX)

local player = Players.LocalPlayer
local Gap = 1.4
local lastLevel, lastBurst = nil, -10

local function onPower()
	local p = player:GetAttribute('Power')
	if type(p) ~= 'number' then return end
	local level = LevelRules.levelOf(p)
	local up = lastLevel ~= nil and level > lastLevel
	lastLevel = level -- (a rebirth lowers it: no burst, just the new base)
	if not up or player:GetAttribute('ReducedMotion') == true then return end
	if os.clock() - lastBurst < Gap then return end
	local c = player.Character
	local root = c and c:FindFirstChild('HumanoidRootPart')
	if not root then return end
	lastBurst = os.clock()
	FightFX.levelBurst(root)
end
player:GetAttributeChangedSignal('Power'):Connect(onPower)
onPower()

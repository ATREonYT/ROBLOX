-- Levels and ranks on the server (brief 29, P4; the rules are Shared/LevelRules). A ModuleScript: LobbyService calls
-- Levels.publish(player, data) four times a second for every loaded player, and RebirthService.publish calls it too.
--   * A level is only a curve over Power (LevelRules.levelOf(Rep)): nothing about it is stored, so the economy and the
--     gates are untouched. The player attributes Level, BestLevel, Rank (the name) and RankIndex follow it.
--   * The profile's BestLevel is the best level ever reached (a rebirth resets Power but never lowers it). When it rises
--     past a rank's level, that rank is reached: its Cash is paid ONCE (BestLevel is saved with the Cash, so it can't be
--     paid twice) and the remote RankUp { From, To, Name, FromName, Cash, Level } tells that player's client to show the
--     rank-up screen. A profile from before BestLevel gets it filled quietly at load (ProfileSchema.migrate): no pay.
local RS = game:GetService('ReplicatedStorage')
local LevelRules = require(RS.Shared.LevelRules)
local Net = require(RS.Shared.Net)

local Levels = {}

local function set(player, name, value)
	if player:GetAttribute(name) ~= value then player:SetAttribute(name, value) end
end

-- Moves BestLevel up to where the profile's data says (never down) and pays and announces the ranks crossed.
-- Returns the ranks crossed (a list of rank indices; usually empty).
function Levels.advance(player, data)
	local saved = math.clamp(math.floor(type(data.BestLevel) == 'number' and data.BestLevel == data.BestLevel and data.BestLevel or 1), 1, LevelRules.MaxLevel)
	local best = LevelRules.bestOf(data)
	if best <= saved then
		data.BestLevel = saved
		return {}
	end
	data.BestLevel = best
	local crossed = LevelRules.ranksCrossed(saved, best)
	if #crossed > 0 then
		local cash = 0
		for _, i in crossed do cash += LevelRules.Ranks[i].Cash end
		if cash > 0 then
			data.Cash = math.min(1e12, data.Cash + cash)
			set(player, 'Cash', data.Cash)
		end
		local from, to = LevelRules.rankIndex(saved), crossed[#crossed]
		Net.get('RankUp'):FireClient(player, {
			From = from, To = to, Name = LevelRules.Ranks[to].Name, FromName = LevelRules.Ranks[from].Name, Cash = cash, Level = best,
		})
	end
	return crossed
end

function Levels.publish(player, data)
	Levels.advance(player, data)
	local rank = LevelRules.rankOf(data.BestLevel)
	set(player, 'Level', LevelRules.levelOf(data.Rep))
	set(player, 'BestLevel', data.BestLevel)
	set(player, 'Rank', rank.Name)
	set(player, 'RankIndex', LevelRules.rankIndex(data.BestLevel))
end

return Levels

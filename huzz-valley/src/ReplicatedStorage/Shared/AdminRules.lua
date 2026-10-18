--[[
	Who may use the admin panel, and what it may do (pure; tests/AdminRules.spec.luau checks it). Owner, Oct 18: "give
	me a admin command panel or something so i can get any knife or any girl to spawn when i want it to do so".

	Only the game's owner: in Studio (his own testing) anyone, else the player whose UserId is the game's CreatorId
	(a game owned by him), or the group's owner (rank 255) when the game belongs to a group. No user IDs are typed
	anywhere: the place itself says who made it. The server decides (HuzzServer/AdminService); a client saying it's an
	admin changes nothing.

	info: { studio: boolean, userId: number, creatorId: number, creatorType: "User" | "Group" | string,
	        groupRank: number? (the player's rank in the creator group, when the game is a group's) }
]]
local AdminRules = {}

function AdminRules.isAdmin(info: { [string]: any }): boolean
	if info.studio == true then return true end
	local creator = tonumber(info.creatorId) or 0
	if creator <= 0 then return false end
	if info.creatorType == "User" then
		return tonumber(info.userId) == creator
	elseif info.creatorType == "Group" then
		return tonumber(info.groupRank) == 255
	end
	return false
end

-- The verbs the panel sends, each with one string argument: a Config/CoinShop knife key, or a girl's save id.
--   GiveKnife   adds the knife to your knives and wears it
--   SpawnGirl   adds the girl to your collection and makes her your companion (she appears behind you at once)
--   NextGirl    makes her the next game's girl (the roller stops on her; a Secret plays her cutscene)
AdminRules.VERBS = { GiveKnife = true, SpawnGirl = true, NextGirl = true }

-- Checks a request before anything happens. Returns ok, why. knives: Config/CoinShop.get; girls: id -> girl or nil.
function AdminRules.check(admin: boolean, verb: any, arg: any, getKnife: (string) -> any, getGirl: (string) -> any): (boolean, string?)
	if not admin then return false, "Only the game's owner can use this." end
	if type(verb) ~= "string" or not AdminRules.VERBS[verb] then return false, "Unknown command." end
	if type(arg) ~= "string" or arg == "" or #arg > 64 then return false, "Pick one from the list." end
	if verb == "GiveKnife" then
		local item = getKnife(arg)
		if not item or item.Slot ~= "Knife" then return false, "No knife called " .. arg .. "." end
	else
		if not getGirl(arg) then return false, "No girl called " .. arg .. " in this place." end
	end
	return true, nil
end

return AdminRules

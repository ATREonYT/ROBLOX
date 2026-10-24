--[[
	Who may use the admin panel, and what it may do (pure; tests/AdminRules.spec.luau checks it). Owner, Oct 18: "give
	me a admin command panel or something so i can get any knife or any girl to spawn when i want it to do so".

	Only the game's owner: in Studio (his own testing) anyone, else the player whose UserId is the game's CreatorId
	(a game owned by him), or the group's owner (rank 255) when the game belongs to a group. No user IDs are typed
	anywhere: the place itself says who made it. The server decides (HuzzServer/AdminService); a client saying it's an
	admin changes nothing.

	Oct 21 15:22 (owner: "give me and thebiglion12 admin commands in the actual roblox game"): also anyone on
	Config/Admins (by user ID, or by username until their ID is in).

	info: { studio: boolean, userId: number, creatorId: number, creatorType: "User" | "Group" | string,
	        groupRank: number? (the player's rank in the creator group, when the game is a group's),
	        name: string? (the player's username), admins: { UserIds: {number}, Names: {string} }? (Config/Admins) }
]]
local AdminRules = {}

function AdminRules.isAdmin(info: { [string]: any }): boolean
	if info.studio == true then return true end
	local list = info.admins
	if type(list) == "table" then
		for _, id in list.UserIds or {} do
			if tonumber(info.userId) == id and id > 0 then return true end
		end
		local name = if type(info.name) == "string" then string.lower(info.name) else nil
		for _, n in list.Names or {} do
			if name and name ~= "" and string.lower(n) == name then return true end
		end
	end
	local creator = tonumber(info.creatorId) or 0
	if creator <= 0 then return false end
	if info.creatorType == "User" then
		return tonumber(info.userId) == creator
	elseif info.creatorType == "Group" then
		return tonumber(info.groupRank) == 255
	end
	return false
end

-- The verbs the panel sends, each with one string argument (and, for the gifts, who gets it: HuzzServer/AdminService
-- finds that player; empty = you):
--   GiveKnife   a Config/CoinShop knife key: into their knives, and they wear it
--   AllKnives   "all": every knife in the shop into their knives
--   SpawnGirl   a girl's save id: into their collection, and she's their companion (she appears behind them at once)
--   NextGirl    a girl's save id: the next game's girl (the roller stops on her; a Secret plays her cutscene)
--   GivePass    a Config/Products game pass key: they get what the pass gives, kept in their save (the real Roblox
--               pass can only be bought from Roblox; this gives its perks and knife)
--   GiveCoins   a whole number from 1 to MAX: that many coins
--   GiveAura    a whole number from 1 to MAX: that much Aura
--   AllServersLuck  "<luck> <minutes>": every server of the game gets that luck for that long (owner, Oct 23 20:21:
--               "give admin panel a way to add all servers luck for a specific amount of time"); luck 2 to
--               LUCK_MAX, minutes 1 to MINUTES_MAX; "0 0" ends it now
--   EndGame     "now": ends the game on in this server (owner, Oct 24 06:57: "make a admin command to end the game"):
--               no winner, nobody gets the girl, everyone back to the lobby
AdminRules.VERBS = { GiveKnife = true, AllKnives = true, SpawnGirl = true, NextGirl = true, GivePass = true, GiveCoins = true, GiveAura = true, AllServersLuck = true, EndGame = true }
AdminRules.LUCK_MAX, AdminRules.MINUTES_MAX = 10, 1440

-- "<luck> <minutes>" -> luck, minutes (0, 0 = end it), or nil and why.
function AdminRules.luckTime(arg: any): (number?, number | string)
	local l, m = string.match(type(arg) == "string" and arg or "", "^%s*[xX]?(%d+)%s+(%d+)%s*$")
	local luck, minutes = tonumber(l), tonumber(m)
	if luck == 0 and minutes == 0 then return 0, 0 end
	if not luck or luck < 2 or luck > AdminRules.LUCK_MAX then return nil, `Type a luck from 2 to {AdminRules.LUCK_MAX}.` end
	if not minutes or minutes < 1 or minutes > AdminRules.MINUTES_MAX then return nil, `Type the minutes, 1 to {AdminRules.MINUTES_MAX}.` end
	return luck, minutes
end
AdminRules.MAX = 1000000

-- Checks a request before anything happens. Returns ok, why. knives: Config/CoinShop.get; girls: id -> girl or nil.
-- getPass (optional): Config/Products.get (a "Pass" kind is a game pass).
function AdminRules.check(admin: boolean, verb: any, arg: any, getKnife: (string) -> any, getGirl: (string) -> any, getPass: ((string) -> any)?): (boolean, string?)
	if not admin then return false, "Only the game's owner can use this." end
	if type(verb) ~= "string" or not AdminRules.VERBS[verb] then return false, "Unknown command." end
	if type(arg) ~= "string" or arg == "" or #arg > 64 then return false, "Pick one from the list." end
	if verb == "GiveCoins" or verb == "GiveAura" then
		local n = tonumber(arg)
		if not n or n ~= math.floor(n) or n < 1 or n > AdminRules.MAX then return false, "Type a whole number from 1 to 1,000,000." end
	elseif verb == "AllServersLuck" then
		local luck, why = AdminRules.luckTime(arg)
		if not luck then return false, why :: string end
	elseif verb == "AllKnives" then
		if arg ~= "all" then return false, "Unknown command." end
	elseif verb == "EndGame" then
		if arg ~= "now" then return false, "Unknown command." end
	elseif verb == "GivePass" then
		local pass = getPass and getPass(arg)
		if not pass or pass.Kind ~= "Pass" then return false, "No game pass called " .. arg .. "." end
	elseif verb == "GiveKnife" then
		local item = getKnife(arg)
		if not item or item.Slot ~= "Knife" then return false, "No knife called " .. arg .. "." end
	else
		if not getGirl(arg) then return false, "No girl called " .. arg .. " in this place." end
	end
	return true, nil
end

return AdminRules

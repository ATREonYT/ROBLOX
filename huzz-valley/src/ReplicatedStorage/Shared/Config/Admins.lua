--[[
	Who else gets the admin panel in the live game (owner, Oct 21 15:22: "give me and thebiglion12 admin commands in
	the actual roblox game, not studio"). The game's creator (and in Studio, anyone) already has it: Shared/AdminRules.
	UserIds is the safe list: a user ID never changes. Names is matched to the player's Roblox username (not the
	display name), ignoring capitals: a username is unique, but if someone renames their account, a new person could
	take the old name one day, so put their user ID in UserIds when you have it (it's the number in their profile's
	web address: roblox.com/users/<number>/profile) and take the name out.
]]
local Admins = {}

Admins.UserIds = {} -- e.g. { 123456789 }: nobody's ID is filled in yet (the owner sends them)
Admins.Names = { "ATRE_playzYT", "thebiglion12" }

return Admins

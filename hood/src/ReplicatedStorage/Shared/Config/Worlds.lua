--!strict
-- The worlds (Oct 27: World 2, Business District; hood/docs/WORLD2.md). Each world is its own place in the experience, running
-- these same scripts; the map built in that place says which world it is (the workspace attribute HoodWorld, set by the
-- map's Build). PlaceId: the place's id from Studio's Asset Manager (Places); 0 until the owner adds it (the portal
-- then says "coming soon"). Unlock: the World 1 boss yard beaten once, ever (the owner: "we need them to beat the
-- final boss to get to the next world").
return {
	{ Id = 1, Name = 'The Hood', PlaceId = 0 },
	{ Id = 2, Name = 'Business District', PlaceId = 0, UnlockedBy = { World = 1, Stage = 16 } },
}

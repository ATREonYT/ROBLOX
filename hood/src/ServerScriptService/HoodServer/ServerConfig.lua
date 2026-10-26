--!strict
return {
 -- Mock is isolated and ephemeral. Change to Persistent ONLY for published Studio save tests.
 StudioDataMode='Mock',
 LiveStoreName='HoodEvolutionProfiles', StudioStoreName='HoodEvolutionProfiles_Studio',
 -- 60, not 45: a player who hops servers waits for ProfileStore to take the save over from the old server (its steal
 -- comes at ~45 s), and a 45 s limit kicked them right then. (The owner's Huzz Valley hit this; it waits 60 s.)
 LoadTimeoutSeconds=60,
 -- (brief 29, P5) The Roblox group whose members can claim the one-time Group reward (Retention.client / RetentionService).
 -- 0 = off: the card is hidden. Put your group's id here.
 GroupId=0,
}

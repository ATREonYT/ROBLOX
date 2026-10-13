--!strict
return {
 -- Mock is isolated and ephemeral. Change to Persistent ONLY for published Studio save tests.
 StudioDataMode='Mock',
 LiveStoreName='HoodEvolutionProfiles', StudioStoreName='HoodEvolutionProfiles_Studio',
 LoadTimeoutSeconds=45,
 -- (brief 29, P5) The Roblox group whose members can claim the one-time Group reward (Retention.client / RetentionService).
 -- 0 = off: the card is hidden. Put your group's id here.
 GroupId=0,
}

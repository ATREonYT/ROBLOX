--!strict
return {
 -- Mock is isolated and ephemeral. Change to Persistent ONLY for published Studio save tests.
 StudioDataMode='Mock',
 LiveStoreName='HoodEvolutionProfiles', StudioStoreName='HoodEvolutionProfiles_Studio',
 LoadTimeoutSeconds=45,
}

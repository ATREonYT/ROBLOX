-- Huzz Valley: publish the game's animations (Studio Command Bar). The helper itself now lives in the place
-- (ServerStorage > HuzzStudioTools > PublishAnimations): it publishes every move and dance it can, takes any ID you
-- set yourself as an "AnimationId" attribute, writes them all into ReplicatedStorage > Shared > Config > AnimationIds
-- (which the game reads) and reports on [HuzzAnim] lines. Steps: docs/STUDIO-STEPS.md, Part 5.
-- Paste this one line into View > Command Bar (Studio, not while playing) and press Enter:
require(game.ServerStorage.HuzzStudioTools.PublishAnimations)()

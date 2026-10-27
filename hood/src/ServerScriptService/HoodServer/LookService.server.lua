-- The game's lighting and sky (Oct 27, the owner: "copy the huzz valley games lighting ... fix the sky block, make the
-- lighting the same"): applies ServerStorage.HoodLighting's Huzz preset when the server starts, as Huzz Valley's
-- LookService does, so a place saved with older Lighting or another skybox still looks right. Lighting replicates to
-- everyone. (Lighting.Technology can't be set by a running game: the place sets it, ShadowMap, in Properties.)
local ServerStorage = game:GetService('ServerStorage')
local PRESET = 'Huzz'

local ok, err = pcall(function()
	require(ServerStorage:WaitForChild('HoodLighting', 10)).Apply(PRESET)
end)
if not ok then warn('[LookService] lighting not applied: ' .. tostring(err)) end

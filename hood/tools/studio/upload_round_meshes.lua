-- upload_round_meshes.lua (Oct 28): uploads the shoes' two rounding meshes (Shared/RoundMesh: RoundBox, RoundWedge) to
-- Roblox and prints the lines for Shared/Config/RoundMeshIds.lua. With both ids there, every player sees soft-edged
-- shoes without the "Allow Mesh / Image APIs" setting, and the server's shoes are rounded too.
-- Use: open the place in Studio (signed in as the game's owner), paste this whole file into the command bar, press
-- Enter, then copy the two printed lines into RoundMeshIds.lua and rebuild the place. Uploading again makes new ids
-- (harmless). Nothing else is changed.
local AssetService = game:GetService('AssetService')
local RoundMesh = require(game:GetService('ReplicatedStorage').Shared.RoundMesh)
local lines = {}
for _, name in RoundMesh.Names do
	local ok, result, id = pcall(function()
		local em = RoundMesh.editable(name)
		return AssetService:CreateAssetAsync(em, Enum.AssetType.Mesh, {
			Name = 'Hood ' .. name,
			Description = 'Hood Evolution: a soft-edged block for the shoes (size 1).',
		})
	end)
	if ok and result == Enum.CreateAssetResult.Success and id then
		table.insert(lines, ('\t%s = %d,'):format(name, id))
	else
		warn(('[upload_round_meshes] %s failed: %s %s'):format(name, tostring(result), tostring(id)))
	end
end
print('[upload_round_meshes] paste into hood/src/ReplicatedStorage/Shared/Config/RoundMeshIds.lua:\n' .. table.concat(lines, '\n'))

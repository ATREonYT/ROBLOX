-- The uploaded rounding meshes (Oct 28: the shoes' blocks and wedges with soft edges, Shared/RoundMesh), one per mesh of
-- Models/RoundMeshData. They come from an upload: hood/tools/studio/upload_round_meshes.lua, run in Studio's command bar,
-- uploads both and prints the lines to paste here. While an id is 0, RoundMesh builds that mesh in game from the packed
-- data (an EditableMesh: Game Settings > Security > "Allow Mesh / Image APIs"); when it can't, the shoes keep their
-- sharp Part blocks. Never put an id in a comment.
return {
	RoundBox = 0,
	RoundWedge = 0,
}

--[[
	See-through copies of a body for the power effects (Gameplay/PowerEffects: Glitchy's two ghosts left behind, Body
	Double's afterimages): every visible part copied where it is now, anchored, in one glowing colour, with nothing on
	it that runs, joins or draws a picture (welds, motors, attachments, decals, its SurfaceAppearance, effects).
	A part's mesh stays: a classic hat's Handle draws its shape through a SpecialMesh child, and without it the copy
	drew the Handle's plain box, a bright block over the head (critic, Oct 20). The mesh keeps its shape but not its
	picture (TextureId cleared), so the colour shows as on the rest of the body.
]]
local Ghosts = {}

local MESHES = { SpecialMesh = true, BlockMesh = true, CylinderMesh = true, FileMesh = true }
Ghosts.MESHES = MESHES

-- Copies of a character's visible parts (not its root), parented to `parent`: { { part = copy, at = where it was } }.
function Ghosts.copy(character: Instance, color: Color3, parent: Instance): { { part: BasePart, at: CFrame } }
	local list = {}
	for _, d in character:GetDescendants() do
		if d:IsA("BasePart") and d.Name ~= "HumanoidRootPart" and d.Transparency < 0.9 then
			local ok, copy = pcall(function()
				local c = d:Clone()
				for _, k in c:GetChildren() do
					if MESHES[k.ClassName] then
						pcall(function() (k :: any).TextureId = "" end)
					else
						k:Destroy()
					end
				end
				return c
			end)
			if ok and copy then
				copy.Anchored, copy.CanCollide, copy.CanQuery, copy.CanTouch, copy.CastShadow = true, false, false, false, false
				copy.Material = Enum.Material.Neon
				copy.Color = color
				pcall(function() (copy :: any).TextureID = "" end)
				copy.Parent = parent
				table.insert(list, { part = copy, at = d.CFrame })
			end
		end
	end
	return list
end

return Ghosts

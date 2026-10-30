---------------------------------------------------------------------------------------------- the hall's studs (World 2)
-- (Oct 27, the owner's "C": the Oct 10 hall shows its studs on the walls, pillars and bands) After the look pass
-- (x_look: faint studs on the walkable ground and the 'Wall' parts), the hall's other studded shell parts take the same
-- faint stud texture on every face: the pillars, the wall bands, the exit bay's frames, the sills, the light bars.
local lookApply = Look.apply
City.HallStudNames = { '^Pillar', '^WallBase$', '^WallBand$', '^ExitFrame$', '^ExitPanelFrame$', '^WindowSill$', '^RoofLampBar$' }
function Look.apply(root)
	lookApply(root)
	local lobby = root:FindFirstChild('Lobby', true)
	local hall = lobby and lobby:FindFirstChild('Hall')
	local roof = lobby and lobby:FindFirstChild('Roof')
	for _, g in { hall, roof } do
		for _, p in g and g:GetDescendants() or {} do
			if p:IsA('BasePart') and p.Material ~= M.Neon and p.Transparency < 0.05 then
				for _, pat in City.HallStudNames do
					if p.Name:find(pat) then
						Look.faintStuds(p, { Enum.NormalId.Top, Enum.NormalId.Bottom, Enum.NormalId.Front, Enum.NormalId.Back, Enum.NormalId.Left, Enum.NormalId.Right })
						break
					end
				end
			end
		end
	end
end

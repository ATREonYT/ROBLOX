-- export_luau_parts.luau: dump part-built Luau models (ShoeModels shoes, BoxModels boxes) as JSON for icons_hd.py, which
-- re-renders them in the icon style (hdkit: glossy toon plastic, navy outline). Run through the preview harness:
--   cd hood/tools/preview && lune run harness.luau ../../src - "OUT='<file.json>' ALL=false $(cat ../blender/export_luau_parts.luau)"
-- Writes { models = { { id, kind, parts = { {cls, shape, size, cf (12), color, material, transparency, mesh, gui} } } } }.
local RS = game.ReplicatedStorage
local Shoes = require(RS.Shared.Config.Shoes)
local ShoeModels = require(RS.Shared.Models.ShoeModels)
local BoxModels = require(RS.Shared.Models.BoxModels)

local function rgb(c) return { math.floor(c.R * 255 + 0.5), math.floor(c.G * 255 + 0.5), math.floor(c.B * 255 + 0.5) } end

local function dump(id, kind, model)
	local parts = {}
	for _, p in model:GetDescendants() do
		if p:IsA('BasePart') and p.Transparency < 0.99 then
			local rec = {
				cls = p.ClassName, size = { p.Size.X, p.Size.Y, p.Size.Z }, cf = { p.CFrame:GetComponents() },
				color = rgb(p.Color), material = p.Material.Name, transparency = p.Transparency, name = p.Name,
			}
			if p:IsA('Part') then rec.shape = p.Shape.Name end
			local mesh = p:FindFirstChildOfClass('SpecialMesh')
			if mesh then rec.mesh = mesh.MeshType.Name; rec.meshScale = { mesh.Scale.X, mesh.Scale.Y, mesh.Scale.Z } end
			local gui = p:FindFirstChildOfClass('SurfaceGui')
			if gui then
				local lines = {}
				for _, l in gui:GetDescendants() do
					if l:IsA('TextLabel') and l.Text ~= '' then
						local stroke = l:FindFirstChildOfClass('UIStroke')
						table.insert(lines, { text = l.Text, color = rgb(l.TextColor3), y = l.Position.Y.Scale, h = l.Size.Y.Scale,
							stroke = stroke and rgb(stroke.Color) or nil })
					end
				end
				rec.gui = { face = gui.Face.Name, lines = lines }
			end
			table.insert(parts, rec)
		end
	end
	return { id = id, kind = kind, parts = parts }
end

local out = {}
-- ALL = true: every shoe of every box (all worlds), not only World 1's
local boxes = Shoes.boxesForWorld(1)
if ALL then boxes = Shoes.Boxes end
for _, box in boxes do
	for _, s in Shoes.List do
		if s.Box == box.Id then
			local m = ShoeModels.shoe(s.Id, 'R', 1)
			table.insert(out, dump('Shoe_' .. s.Id, 'shoe', m))
			m:Destroy()
		end
	end
	local b = BoxModels.build(box.Id, 1)
	table.insert(out, dump('Box_' .. box.Id, 'box', b))
	b:Destroy()
end
__fs.writeFile(OUT, __serde.encode('json', { models = out }))
return #out

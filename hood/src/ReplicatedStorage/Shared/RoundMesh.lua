-- RoundMesh (Oct 28, the owner: "keep the form, I mean just make them visibly look a bit better"): soft edges for the
-- shoes' blocks and wedges. Models/RoundMeshData holds two small meshes made in Blender
-- (hood/tools/blender/export_round_meshes.py): RoundBox (a block with rounded edges and corners) and RoundWedge (a
-- WedgePart rounded the same way), both size 1 in a Part's own axes, so a MeshPart of one, sized and placed like the
-- Part it stands for, is that Part with soft edges (ShoeModels).
-- Each mesh becomes one MeshPart template, which ShoeModels clones:
--   1. an uploaded mesh when Config/RoundMeshIds has its id (AssetService:CreateMeshPartAsync);
--   2. else built in game from the packed data (an EditableMesh; Roblox allows it only with Game Settings > Security >
--      "Allow Mesh / Image APIs" on, like the packed UI pictures, Shared/ImageLoader);
--   3. else nothing: RoundMesh.ready() stays false and the shoes keep their Part blocks. Nothing here ever errors to its
--      caller; a refusal is reported once in Output ([HoodShoes]).
-- The templates are built once per client, in the background (start(); ShoeModels starts it). On the server only once
-- both meshes are uploaded (a mesh built in game doesn't replicate), so the server's shoes stay Parts until then.
-- Shoes made before they are ready keep sharp blocks; RoundMesh.Ready fires when they are (ShoeModels.wear puts a worn
-- pair on again then).
--   RoundMesh.ready() -> boolean               RoundMesh.make(name) -> MeshPart?   (a fresh clone of a template)
--   RoundMesh.start()                          RoundMesh.Ready (an RBXScriptSignal, or nil where events can't be made)
--   RoundMesh.Names = { 'RoundBox', 'RoundWedge' }
--   RoundMesh.decode(name) -> verts, normals, tris   (Vector3 lists and { v0, v1, v2, n0, n1, n2 } 1-based; the checks)
--   RoundMesh.editable(name) -> EditableMesh   (also used by the Studio upload, hood/tools/studio)
--   RoundMesh.inject(templates)                (tests and previews: their own templates, ready at once; nil: idle again)
local RoundMesh = {}
RoundMesh.Names = { 'RoundBox', 'RoundWedge' }

local Shared = script.Parent
local function optional(...)
	local node = Shared
	for _, name in { ... } do
		node = node and node:FindFirstChild(name)
	end
	if not node then return nil end
	local ok, m = pcall(require, node)
	return ok and type(m) == 'table' and m or nil
end
local Data = optional('Models', 'RoundMeshData')
local Ids = optional('Config', 'RoundMeshIds') or {}
RoundMesh.Data = Data

local templates = {}
local state = Data and 'idle' or 'none' -- idle | building | ready | failed | none (no data)
local readyEvent
pcall(function()
	local e = Instance.new('BindableEvent')
	RoundMesh.Ready = e.Event
	readyEvent = e
end)

---------------------------------------------------------------------------------------------- decoding
local ALPHABET = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/'
local VALUE = {}
for i = 1, 64 do VALUE[string.byte(ALPHABET, i)] = i - 1 end
local function base64(s)
	local n = #s
	local pad = (string.sub(s, -2) == '==' and 2) or (string.sub(s, -1) == '=' and 1) or 0
	local len = n // 4 * 3 - pad
	local out = buffer.create(len)
	local o = 0
	for i = 1, n, 4 do
		local a, b, c, d = string.byte(s, i, i + 3)
		local v = VALUE[a] * 262144 + VALUE[b] * 4096 + (VALUE[c] or 0) * 64 + (VALUE[d] or 0)
		buffer.writeu8(out, o, v // 65536)
		if o + 1 < len then buffer.writeu8(out, o + 1, (v // 256) % 256) end
		if o + 2 < len then buffer.writeu8(out, o + 2, v % 256) end
		o += 3
	end
	return out
end

-- The mesh's vertices (about its centre, size 1), unit normals, and triangles { v0, v1, v2, n0, n1, n2 } (1-based).
function RoundMesh.decode(name)
	local m = Data and Data[name]
	assert(m, 'RoundMesh: no packed mesh ' .. tostring(name))
	local vb, nb, tb = base64(m.V), base64(m.N), base64(m.T)
	local hx, hy, hz = m.Size[1] / 2 / 32767, m.Size[2] / 2 / 32767, m.Size[3] / 2 / 32767
	local verts, normals, tris = table.create(m.Verts), table.create(m.Normals), table.create(m.Tris)
	for i = 0, m.Verts - 1 do
		verts[i + 1] = Vector3.new(buffer.readi16(vb, i * 6) * hx, buffer.readi16(vb, i * 6 + 2) * hy, buffer.readi16(vb, i * 6 + 4) * hz)
	end
	for i = 0, m.Normals - 1 do
		local n = Vector3.new(buffer.readi8(nb, i * 3), buffer.readi8(nb, i * 3 + 1), buffer.readi8(nb, i * 3 + 2))
		normals[i + 1] = n.Magnitude > 0 and n.Unit or Vector3.yAxis
	end
	for i = 0, m.Tris - 1 do
		local o = i * 12
		tris[i + 1] = {
			buffer.readu16(tb, o) + 1, buffer.readu16(tb, o + 2) + 1, buffer.readu16(tb, o + 4) + 1,
			buffer.readu16(tb, o + 6) + 1, buffer.readu16(tb, o + 8) + 1, buffer.readu16(tb, o + 10) + 1,
		}
	end
	return verts, normals, tris
end

-- A new EditableMesh of the packed mesh (errors where Roblox refuses).
function RoundMesh.editable(name)
	local verts, normals, tris = RoundMesh.decode(name)
	local em = game:GetService('AssetService'):CreateEditableMesh()
	assert(em, 'no EditableMesh (memory budget)')
	local vid, nid = table.create(#verts), table.create(#normals)
	for i, v in verts do vid[i] = em:AddVertex(v) end
	for i, n in normals do nid[i] = em:AddNormal(n) end
	for _, t in tris do
		local f = em:AddTriangle(vid[t[1]], vid[t[2]], vid[t[3]])
		em:SetFaceNormals(f, { nid[t[4]], nid[t[5]], nid[t[6]] })
	end
	return em
end

---------------------------------------------------------------------------------------------- the templates
local function finish(part, name)
	part.Name = name
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.Massless = true
	part.CastShadow = false
	part.Material = Enum.Material.SmoothPlastic
	pcall(function() part.DoubleSided = false end)
	return part
end

local function uploaded()
	for _, name in RoundMesh.Names do
		local id = tonumber(Ids[name])
		if not (id and id > 0) then return false end
	end
	return true
end

local function buildOne(name, inGame)
	local AssetService = game:GetService('AssetService')
	-- (Automatic: Roblox draws far shoes with fewer triangles)
	local opts = { CollisionFidelity = Enum.CollisionFidelity.Box, RenderFidelity = Enum.RenderFidelity.Automatic }
	local id = tonumber(Ids[name])
	if id and id > 0 then
		local ok, part = pcall(function() return AssetService:CreateMeshPartAsync(Content.fromAssetId(id), opts) end)
		if ok and part then return finish(part, name) end
	end
	assert(inGame, 'the uploaded mesh did not load')
	local em = RoundMesh.editable(name)
	return finish(AssetService:CreateMeshPartAsync(Content.fromObject(em), opts), name)
end

local warned = false
local function warnOnce(why)
	if warned then return end
	warned = true
	warn('[HoodShoes] the shoes keep sharp edges: turn on Game Settings > Security > "Allow Mesh / Image APIs", or upload the two rounding meshes (hood/tools/studio/upload_round_meshes.lua). (' .. tostring(why) .. ')')
end
local function build(inGame)
	local made = {}
	for _, name in RoundMesh.Names do
		local ok, part = pcall(buildOne, name, inGame)
		if not ok or typeof(part) ~= 'Instance' then
			state = 'failed'
			warnOnce(part)
			for _, p in made do p:Destroy() end
			return
		end
		made[name] = part
	end
	templates = made
	state = 'ready'
	if readyEvent then pcall(function() readyEvent:Fire() end) end
end

-- Starts building the templates (once; on a client, or on the server when both meshes are uploaded).
function RoundMesh.start()
	if state ~= 'idle' then return end
	local okClient, client = pcall(function() return game:GetService('RunService'):IsClient() end)
	local inGame = okClient and client == true
	if not inGame and not uploaded() then return end
	local okApi, api = pcall(function() return game:GetService('AssetService').CreateMeshPartAsync end)
	if not (okApi and api) then state = 'failed'; return end
	state = 'building'
	task.spawn(function()
		local ok, err = pcall(build, inGame)
		if not ok then
			state = 'failed'
			warnOnce(err)
		end
	end)
end

function RoundMesh.ready() return state == 'ready' end
function RoundMesh.state() return state end

-- A fresh MeshPart of one mesh (nil until ready).
function RoundMesh.make(name)
	local t = state == 'ready' and templates[name]
	return t and t:Clone() or nil
end

-- (tests and previews) Their own templates (name -> a BasePart), ready at once; nil puts it back to idle.
function RoundMesh.inject(map)
	if map == nil then
		templates, state = {}, Data and 'idle' or 'none'
		return
	end
	templates, state = map, 'ready'
end

return RoundMesh

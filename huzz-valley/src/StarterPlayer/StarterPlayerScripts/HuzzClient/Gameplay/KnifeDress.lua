--[[
	The 5 Game Pass knives drawn as the owner's own model on this screen (owner, Oct 19: "use the glb file to get them
	one to one, whenever you wear or use them"), until his import of design/knives/gamepass/Gamepass_Knives.glb is in
	ServerStorage/HuzzKnives (then the server uses his model and nothing here runs).
	- The server builds a pass knife from its plain-part stand-in (Shared/KnifeShapes: the right length, grip and
	  trail points) and tags it "GlbKnife" (HuzzServer/KnifeService.template). On this screen each tagged knife in the
	  Workspace (in a hand, on a back or hip, on a lobby stand) gets his model instead: every triangle and colour of
	  his .glb (Shared/KnifeGlb, baked by tools/knives/bake_pass_meshes.py), one MeshPart per look, welded to the
	  Handle, sized by the knife's Stretch (a stand's big copy); then the stand-in's parts are hidden on this screen.
	  Each look is the Roblox material nearest his .glb's (its mat / refl, from Shared/KnifeLook.glbMaterial: Neon for
	  his glowing parts, Metal for his metal, Plastic for matte grips). Nothing is laid over it (owner, Oct 19: "they
	  dont look as good as in the glb file": the old see-through glow shell on the stands is gone).
	- Roblox builds these meshes with EditableMesh (AssetService:CreateEditableMesh / CreateMeshPartAsync), on each
	  screen (the server's copies don't reach players). In Studio this works in Play. In the live game Roblox only
	  allows it when the owner (13+, ID-verified) turns on Game Settings > Security > "Allow Mesh / Image APIs".
	  Anything that fails (no permission, a phone out of mesh memory, an older Roblox) leaves the stand-in showing: a
	  knife is never half made (and the stand-in is cut from his .glb too: Shared/KnifeShapes). Output says once
	  "[HuzzKnife] pass knives as his model: ..." either way; in Studio a failure also shows in the small red problem
	  box on screen (UI/Report), so the owner can screenshot it (never in the live game: players don't need it).
	- Each look's mesh is made once per screen and shared by every knife that shows it.
]]
local M = {}

local TAG = "GlbKnife"

-- base64 -> buffer
local ALPHA = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
local VALUE = {}
for i = 1, 64 do VALUE[string.byte(ALPHA, i)] = i - 1 end
function M.decode64(s: string): buffer
	s = string.gsub(s, "[^%w%+/]", "")
	local n = #s
	local out = buffer.create(math.floor(n * 3 / 4))
	local o = 0
	for i = 1, n - 3, 4 do
		local a, b, c, d = VALUE[string.byte(s, i)], VALUE[string.byte(s, i + 1)], VALUE[string.byte(s, i + 2)], VALUE[string.byte(s, i + 3)]
		local x = a * 262144 + b * 4096 + c * 64 + d
		buffer.writeu8(out, o, bit32.rshift(x, 16)); o += 1
		buffer.writeu8(out, o, bit32.band(bit32.rshift(x, 8), 255)); o += 1
		buffer.writeu8(out, o, bit32.band(x, 255)); o += 1
	end
	local rest = n % 4
	if rest >= 2 then
		local i = n - rest + 1
		local a, b = VALUE[string.byte(s, i)], VALUE[string.byte(s, i + 1)]
		local c = if rest == 3 then VALUE[string.byte(s, i + 2)] else 0
		local x = a * 262144 + b * 4096 + c * 64
		buffer.writeu8(out, o, bit32.rshift(x, 16)); o += 1
		if rest == 3 then buffer.writeu8(out, o, bit32.band(bit32.rshift(x, 8), 255)); o += 1 end
	end
	return out
end

-- A baked mesh's vertices (in its box's own space: centred, studs) and triangles (1-based vertex numbers).
function M.unpack(g)
	local vb, tb = M.decode64(g.v), M.decode64(g.t)
	local lo, hi = Vector3.new(g.lo[1], g.lo[2], g.lo[3]), Vector3.new(g.hi[1], g.hi[2], g.hi[3])
	local span, mid = hi - lo, (lo + hi) / 2
	local verts = table.create(g.nv)
	for i = 0, g.nv - 1 do
		local q = Vector3.new(buffer.readu16(vb, i * 6), buffer.readu16(vb, i * 6 + 2), buffer.readu16(vb, i * 6 + 4)) / 65535
		verts[i + 1] = lo + span * q - mid
	end
	local tris = table.create(g.nt)
	for i = 0, g.nt - 1 do
		tris[i + 1] = { buffer.readu16(tb, i * 6) + 1, buffer.readu16(tb, i * 6 + 2) + 1, buffer.readu16(tb, i * 6 + 4) + 1 }
	end
	return verts, tris, mid, span
end

-- The baked meshes of a knife (Shared/KnifeGlb/<key>_<n>), in order; {} when there are none.
function M.meshesOf(folder: Instance, key: string)
	local list = {}
	local n = 1
	while true do
		local m = folder:FindFirstChild(key .. "_" .. n)
		if not m then break end
		table.insert(list, require(m))
		n += 1
	end
	return list
end

-- Puts a knife's dress on: one part per baked mesh (made by make(mesh) -> a MeshPart, or nil), placed in the
-- Handle's space times stretch, welded to the Handle; then hides the stand-in's own parts. All or nothing: nil when
-- any part couldn't be made (the stand-in stays as it is).
function M.dress(model: Instance, meshes, make)
	local handle = model:FindFirstChild("Handle", true)
	if not (handle and handle:IsA("BasePart")) or #meshes == 0 then return nil end
	if model:FindFirstChild("GlbDress") then return model:FindFirstChild("GlbDress") end
	local stretch = model:GetAttribute("Stretch")
	if typeof(stretch) ~= "Vector3" then stretch = Vector3.one * (model:GetAttribute("Scale") or 1) end
	local made = {}
	for _, g in meshes do
		local ok, part = pcall(make, g)
		if not ok or not part then
			for _, p in made do p:Destroy() end
			return nil, if ok then "no mesh" else tostring(part)
		end
		local lo, hi = Vector3.new(g.lo[1], g.lo[2], g.lo[3]), Vector3.new(g.hi[1], g.hi[2], g.hi[3])
		part.Name = if g.blade then "GlbBlade" else "GlbPart"
		part.Size = ((hi - lo) * stretch):Max(Vector3.one * 0.01)
		part.CFrame = handle.CFrame * CFrame.new((lo + hi) / 2 * stretch)
		part.Color = Color3.fromHex(g.col)
		part.Material = (Enum.Material :: any)[g.mat or (if g.glow then "Neon" else "SmoothPlastic")]
		part.Reflectance = g.refl or 0
		part.Anchored, part.CanCollide, part.CanQuery, part.CanTouch, part.Massless, part.CastShadow = false, false, false, false, true, false
		table.insert(made, part)
	end
	local folder = Instance.new("Folder")
	folder.Name = "GlbDress"
	for _, d in model:GetDescendants() do -- the stand-in hides, its grip (the Handle) too; its emitters, lights and trail points stay
		if d:IsA("BasePart") then d.Transparency = 1 end
	end
	for _, p in made do
		p.Parent = folder
		local w = Instance.new("WeldConstraint")
		w.Part0, w.Part1 = handle, p
		w.Parent = p
	end
	folder.Parent = model
	return folder
end

function M.start()
	local AssetService = game:GetService("AssetService")
	local CollectionService = game:GetService("CollectionService")
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local Workspace = game:GetService("Workspace")
	local RunService = game:GetService("RunService")
	local reported = false
	local function report(text, failed: boolean?)
		if reported then return end
		reported = true
		print("[HuzzKnife] pass knives as his model: " .. text)
		if failed and RunService:IsStudio() then -- (on screen too, once, for a screenshot)
			pcall(function()
				local Report = require(script.Parent.Parent:WaitForChild("UI"):WaitForChild("Report"))
				Report.problem("Pass knives as his model", text .. " (Game Settings > Security > Allow Mesh / Image APIs)")
			end)
		end
	end
	local folder = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("KnifeGlb", 10)
	if not folder then
		report("Shared/KnifeGlb is missing: the plain stand-ins show", true)
		return
	end

	local made = {} -- [baked mesh] = its EditableMesh, made once (false: it failed)
	local function fail(err)
		report("not available here (" .. tostring(err) .. "): the plain stand-ins show", true)
	end
	local function make(g)
		local em = made[g]
		if em == nil then
			em = false
			local ok, err = pcall(function()
				local verts, tris = M.unpack(g)
				local e = AssetService:CreateEditableMesh() -- (no FixedSize: a fixed-size mesh refuses AddVertex/AddTriangle)
				local ids = table.create(#verts)
				for i, v in verts do ids[i] = e:AddVertex(v) end
				for _, t in tris do e:AddTriangle(ids[t[1]], ids[t[2]], ids[t[3]]) end
				em = e
			end)
			if not ok then fail(err) end
			made[g] = em
		end
		if not em then return nil end
		-- a MeshPart of its own for each knife, sharing the one mesh (a box for touches: these never collide)
		local ok, part = pcall(function()
			return AssetService:CreateMeshPartAsync(Content.fromObject(em), { CollisionFidelity = Enum.CollisionFidelity.Box })
		end)
		if not ok then
			ok, part = pcall(function() return AssetService:CreateMeshPartAsync(Content.fromObject(em)) end)
		end
		if not ok then fail(part) return nil end
		return part
	end

	local busy = {}
	local function dress(model: Instance)
		if busy[model] or not model:IsDescendantOf(Workspace) or model:FindFirstChild("GlbDress") then return end
		local key = model:GetAttribute("Glb")
		if type(key) ~= "string" then return end
		busy[model] = true
		task.spawn(function()
			model:WaitForChild("Handle", 5) -- (a knife can arrive a part at a time)
			local meshes = M.meshesOf(folder, key)
			local ok, result, why = pcall(M.dress, model, meshes, make)
			if ok and result then
				report("on (" .. #meshes .. " meshes for " .. key .. ")")
				-- a stand-in part that arrives after the dress hides too
				model.DescendantAdded:Connect(function(d)
					if d:IsA("BasePart") and not d:IsDescendantOf(result) then d.Transparency = 1 end
				end)
			elseif not ok then
				report("failed (" .. tostring(result) .. "): the plain stand-ins show", true)
			elseif why then
				report("failed (" .. tostring(why) .. "): the plain stand-ins show", true)
			end
			busy[model] = nil
		end)
	end
	CollectionService:GetInstanceAddedSignal(TAG):Connect(dress)
	for _, m in CollectionService:GetTagged(TAG) do dress(m) end
	-- (a tagged knife can be made in ReplicatedStorage and only later go into the Workspace: a stand's copy)
	Workspace.DescendantAdded:Connect(function(d)
		if d:IsA("Model") and d:HasTag(TAG) then dress(d) end
	end)
end

return M

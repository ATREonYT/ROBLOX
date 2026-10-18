--[[
	[HuzzKnife] Studio helper: turns the owner's imported knives into the game's knife skins.
	Owner's steps (also in huzz-valley/CLAUDE.md, "Knives"):
	  1. In Studio: File (or the Home tab) > Import 3D, pick design/knives/Knives/All_Knives.glb, press Import.
	     (Or pick the 30 single files: either works.)
	  2. View > Command Bar. Paste this whole script (or, in the downloaded place, the one line
	     require(game.ServerStorage.HuzzStudioTools.SetupKnives)() ) and press Enter.
	  3. Output shows one [HuzzKnife] line per knife and "Done: 30 of 30". Take a screenshot if anything says "missing".
	  4. File > Save. Then right-click ServerStorage > HuzzKnives > Save to File, and send that file, so every new
	     download has the knives too.
	What it does for each knife: finds it by name, lines it up whatever way Studio imported it (from the parts' names
	and centres baked from the .glb), colours every part from the model's own colours (the .glb's tiny textures are
	single colours: the material names say which), sets the glowing parts (glow_glow_<colour>) to Neon, welds it all to
	an invisible Handle (+Y to the tip, X the blade's thin way), scales it to its length in studs (2.4 to 3.3 by its
	real length; Huss Valley's are 2.7 to 3.0), adds the Attachments the game uses (Grip in the middle of the grip,
	TrailBase at the guard, TrailTip at the tip) and moves it to ServerStorage > HuzzKnives > <its skin key>.
	Running it again is fine: a knife already set up is replaced when a new import of it is found.
	The game (HuzzServer/KnifeService) uses these models when they're there; until then it draws its own knife in
	each skin's colours.
]]
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

--@@KNIVES@@

local TAG = "[HuzzKnife]"
local RARITY = { Common = 1, Uncommon = 2, Rare = 3, Epic = 4, Legendary = 5, Mythic = 6 }

local function norm(s: string): string
	s = string.lower(s):gsub("[^%w]", "")
	s = s:gsub("^%d+", "")
	for word in RARITY do
		local w = string.lower(word)
		if s:sub(1, #w) == w then s = s:sub(#w + 1) break end
	end
	return s
end

local function partsOf(container: Instance): { BasePart }
	local list = {}
	if container:IsA("BasePart") then table.insert(list, container) end
	for _, d in container:GetDescendants() do
		if d:IsA("BasePart") then table.insert(list, d) end
	end
	return list
end

-- Each knife's imported container (a Model or Folder named like it), searched in Workspace and ServerStorage.
local function findImports(): { [string]: Instance }
	local wanted = {}
	for _, k in KNIVES do wanted[norm(k.node)] = k end
	local found = {}
	local done = ServerStorage:FindFirstChild("HuzzKnives")
	for _, root in { Workspace, ServerStorage } do
		for _, d in root:GetDescendants() do
			if (d:IsA("Model") or d:IsA("Folder") or d:IsA("BasePart")) and not (done and d:IsDescendantOf(done)) then
				local k = wanted[norm(d.Name)]
				if k and not found[k.key] and #partsOf(d) > 0 then
					found[k.key] = d
				end
			end
		end
	end
	return found
end

-- Where the knife's own frame (the .glb's units: +Y blade, X width, Z thickness) sits in Studio:
-- returns s (studs per unit), R (CFrame rotation: columns = the knife's X, Y, Z), t (Vector3), matched pairs, error.
local function lineUp(k, parts: { BasePart })
	local byName = {}
	for _, p in parts do
		byName[p.Name] = byName[p.Name] or p
		byName[string.lower(p.Name)] = byName[string.lower(p.Name)] or p
	end
	local A, B, P = {}, {}, {}
	for _, n in k.nodes do
		local p = byName[n[1]] or byName[string.lower(n[1])]
		if p then
			table.insert(A, Vector3.new(n[2], n[3], n[4]))
			table.insert(B, p.CFrame.Position)
			table.insert(P, { part = p, node = n })
		end
	end
	local function centre(list)
		local c = Vector3.zero
		for _, v in list do c += v end
		return c / math.max(1, #list)
	end
	local ca, cb = centre(A), centre(B)
	local syy, ymin, ymax = 0, math.huge, -math.huge
	for _, a in A do
		syy += (a.Y - ca.Y) ^ 2
		ymin, ymax = math.min(ymin, a.Y), math.max(ymax, a.Y)
	end
	if #A >= 2 and ymax - ymin > 0.25 * k.len then
		-- the blade's way: how the Studio centres move as the .glb's Y grows, with X and Z held still (a least-squares
		-- fit B = M A; M's Y column; a little damping where the knife has no spread, e.g. every part on its axis)
		local C = { { 0, 0, 0 }, { 0, 0, 0 }, { 0, 0, 0 } }
		local D = { Vector3.zero, Vector3.zero, Vector3.zero }
		for i, a in A do
			local d = { a.X - ca.X, a.Y - ca.Y, a.Z - ca.Z }
			for r = 1, 3 do
				for c = 1, 3 do C[r][c] += d[r] * d[c] end
				D[r] += (B[i] - cb) * d[r]
			end
		end
		local damp = 1e-3 * (C[1][1] + C[2][2] + C[3][3])
		for r = 1, 3 do C[r][r] += damp end
		local function cof(r, c)
			local rs, cs = {}, {}
			for i = 1, 3 do if i ~= r then table.insert(rs, i) end end
			for i = 1, 3 do if i ~= c then table.insert(cs, i) end end
			local v = C[rs[1]][cs[1]] * C[rs[2]][cs[2]] - C[rs[1]][cs[2]] * C[rs[2]][cs[1]]
			return if (r + c) % 2 == 0 then v else -v
		end
		local det = C[1][1] * cof(1, 1) + C[1][2] * cof(1, 2) + C[1][3] * cof(1, 3)
		local yv = Vector3.zero
		for r = 1, 3 do yv += D[r] * (cof(2, r) / det) end -- (M's Y column = D times the inverse's Y column)
		if yv.Magnitude > 1e-6 then
			local Y = yv.Unit
			local num = 0
			for i, a in A do num += (a.Y - ca.Y) * (B[i] - cb):Dot(Y) end
			local s = num / syy
			-- the blade's thin way (its Z): the blade part's thinnest side across the blade
			local blade, vol = nil, -1
			for _, pr in P do
				local sz = pr.part.Size
				if string.sub(string.lower(pr.part.Name), 1, 6) == "blade_" and sz.X * sz.Y * sz.Z > vol then
					blade, vol = pr.part, sz.X * sz.Y * sz.Z
				end
			end
			blade = blade or (P[1] and P[1].part)
			local Z = nil
			if blade then
				local cf, sz = blade.CFrame, blade.Size
				local best = math.huge
				for _, ax in { { cf.RightVector, sz.X }, { cf.UpVector, sz.Y }, { cf.LookVector, sz.Z } } do
					local v = ax[1] - Y * ax[1]:Dot(Y)
					if v.Magnitude > 0.7 and ax[2] < best then best, Z = ax[2], v.Unit end
				end
			end
			if not Z then
				local any = if math.abs(Y.Z) < 0.9 then Vector3.zAxis else Vector3.xAxis
				Z = (any - Y * any:Dot(Y)).Unit
			end
			-- two ways round the blade's axis: keep the one that fits the parts best (matters for one-sided knives)
			local bestFit
			for _, sign in { 1, -1 } do
				local Zs = Z * sign
				local X = Y:Cross(Zs)
				local R = CFrame.fromMatrix(Vector3.zero, X, Y, Zs)
				local t = cb - R:VectorToWorldSpace(ca) * s
				local err = 0
				for i, a in A do err += ((R:VectorToWorldSpace(a) * s + t) - B[i]).Magnitude ^ 2 end
				err = math.sqrt(err / #A) / (s * k.len)
				if not bestFit or err < bestFit.err then bestFit = { s = s, R = R, t = t, err = err } end
			end
			return bestFit.s, bestFit.R, bestFit.t, P, bestFit.err
		end
	end
	-- Fallback (the names didn't match): the import kept the .glb's axes (Studio's importer does: both are Y up);
	-- size and place from the parts' box.
	local lo, hi = Vector3.one * math.huge, -Vector3.one * math.huge
	for _, p in parts do
		local h = p.Size / 2
		lo, hi = lo:Min(p.CFrame.Position - h), hi:Max(p.CFrame.Position + h)
	end
	local s = (hi.Y - lo.Y) / math.max(1e-6, k.tip - (k.tip - k.len))
	local R = CFrame.identity
	local t = Vector3.new((lo.X + hi.X) / 2, lo.Y, (lo.Z + hi.Z) / 2) - Vector3.new(0, (k.tip - k.len) * s, 0)
	return s, R, t, P, nil
end

local function setUp(k, container: Instance, holder: Folder): string
	local parts = partsOf(container)
	local s, R, t, matched, err = lineUp(k, parts)
	local X, Y, Z = R.RightVector, R.UpVector, R.LookVector
	-- the Handle: an invisible part in the middle of the grip; +Y = the blade's way, X = the blade's thin way (Z of
	-- the .glb), so it matches the game's own knife (HuzzServer/KnifeService)
	local gripAt = t + Y * (k.grip * s)
	local model = Instance.new("Model")
	model.Name = k.key
	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.CFrame = CFrame.fromMatrix(gripAt, Z, Y)
	handle.Size = Vector3.new(0.1, 0.1, 0.1)
	handle.Transparency = 1
	handle.Parent = model
	local looks = {}
	for _, pr in matched do looks[pr.part] = pr.node end
	for _, p in parts do
		p.Parent = model
		local n = looks[p]
		if n then
			if p:IsA("MeshPart") then pcall(function() p.TextureID = "" end) end
			for _, d in p:GetChildren() do
				if d:IsA("SurfaceAppearance") then d:Destroy() end
			end
			p.Color = Color3.fromHex(n[5])
			p.Material = if n[6] == 1 then Enum.Material.Neon else Enum.Material.SmoothPlastic
			p.Reflectance = 0
		end
		for _, d in p:GetChildren() do
			if d:IsA("JointInstance") or d:IsA("WeldConstraint") then d:Destroy() end
		end
		local w = Instance.new("WeldConstraint")
		w.Part0, w.Part1 = handle, p
		w.Parent = p
	end
	for _, p in model:GetDescendants() do
		if p:IsA("BasePart") then
			p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.Massless, p.CastShadow = false, false, false, false, true, false
		end
	end
	model.PrimaryPart = handle
	-- pommel to tip = k.studs
	local factor = k.studs / (k.len * s)
	local ok = pcall(function() model:ScaleTo(model:GetScale() * factor) end)
	if not ok then
		for _, p in model:GetDescendants() do
			if p:IsA("BasePart") and p ~= handle then
				local rel = handle.CFrame:ToObjectSpace(p.CFrame)
				p.Size *= factor
				p.CFrame = handle.CFrame * (rel - rel.Position + rel.Position * factor)
			end
		end
	end
	handle.Size = Vector3.new(0.2, 0.7, 0.2)
	local per = k.studs / k.len -- studs per .glb unit now
	local function attach(name, y)
		local a = Instance.new("Attachment")
		a.Name = name
		a.Position = Vector3.new(0, y, 0)
		a.Parent = handle
	end
	attach("Grip", 0)
	attach("TrailBase", (0 - k.grip) * per)
	attach("TrailTip", (k.tip - k.grip) * per)
	model:SetAttribute("Skin", k.key)
	model:SetAttribute("KnifeName", k.name)
	model:SetAttribute("Rarity", k.rarity)
	model:SetAttribute("Studs", k.studs)
	if k.glow then model:SetAttribute("Glow", Color3.fromHex(k.glow)) end
	pcall(function() model:PivotTo(CFrame.new(0, 0, 0)) end) -- (tidy: all at the origin in ServerStorage)
	local old = holder:FindFirstChild(k.key)
	if old then old:Destroy() end
	model.Parent = holder
	-- tidy the import: drop its now-empty containers
	local c = container
	while c and c ~= Workspace and c ~= ServerStorage and c.Parent and #partsOf(c) == 0 do
		local up = c.Parent
		c:Destroy()
		c = up
	end
	local how = if err == nil then "names didn't match: placed from its box, check it" elseif err < 0.05 then "lined up" else string.format("lined up roughly (%.0f%% off), check it", err * 100)
	return string.format("%s %s (%s) -> ServerStorage/HuzzKnives/%s: %d parts, %d matched, %.1f studs, %s", TAG, k.name, k.rarity, k.key, #parts, #matched, k.studs, how)
end

local function run()
	local CHS = game:GetService("ChangeHistoryService")
	pcall(function() CHS:SetWaypoint("HuzzKnife setup") end)
	local holder = ServerStorage:FindFirstChild("HuzzKnives")
	if not holder then
		holder = Instance.new("Folder")
		holder.Name = "HuzzKnives"
		holder.Parent = ServerStorage
	end
	local found = findImports()
	local okCount, missing = 0, {}
	for _, k in KNIVES do
		local container = found[k.key]
		if container then
			local ok, msg = pcall(setUp, k, container, holder)
			if ok then
				okCount += 1
				print(msg)
			else
				warn(string.format("%s %s: couldn't set it up: %s", TAG, k.name, tostring(msg)))
			end
		elseif holder:FindFirstChild(k.key) then
			okCount += 1
			print(string.format("%s %s: already in ServerStorage/HuzzKnives/%s", TAG, k.name, k.key))
		else
			table.insert(missing, k.name)
		end
	end
	pcall(function() CHS:SetWaypoint("HuzzKnife setup done") end)
	print(string.format("%s Done: %d of %d knives are in ServerStorage > HuzzKnives.", TAG, okCount, #KNIVES))
	if #missing > 0 then
		warn(string.format("%s missing (not imported yet?): %s", TAG, table.concat(missing, ", ")))
		warn(TAG .. " Import design/knives/Knives/All_Knives.glb (File > Import 3D) and run this again.")
	else
		print(TAG .. " Next: File > Save, then right-click ServerStorage > HuzzKnives > Save to File and send it.")
	end
	return okCount
end

--@@RUN@@

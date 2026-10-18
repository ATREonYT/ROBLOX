--[[
	[HuzzKnife] Studio helper: turns the owner's imported knives into the game's knife skins.
	Owner's steps (also in huzz-valley/CLAUDE.md, "Knives"):
	  1. In Studio: File (or the Home tab) > Import 3D, pick design/knives/Knives/All_Knives.glb, press Import.
	     (Or pick the 30 single files: either works.) Then the same for the 5 Game Pass knives:
	     design/knives/gamepass/Gamepass_Knives.glb.
	  2. View > Command Bar. Paste this whole script (or, in the downloaded place, the one line
	     require(game.ServerStorage.HuzzStudioTools.SetupKnives)() ) and press Enter.
	  3. Output shows one [HuzzKnife] line per knife and "Done: 35 of 35". Take a screenshot if anything says "missing".
	  4. File > Save. Then right-click ServerStorage > HuzzKnives > Save to File, and send that file, so every new
	     download has the knives too.
	What it does for each knife: finds it by name, lines it up whatever way Studio imported it (from the parts' names
	and centres baked from the .glb), colours every part from the model's own colours (the .glb's tiny textures are
	single colours: the material names say which), sets the glowing parts (glow_glow_<colour>) to Neon, welds it all to
	an invisible Handle (+Y to the tip, X the blade's thin way), scales it to its length in studs (2.4 to 3.3 by its
	real length; Huss Valley's are 2.7 to 3.0), adds the Attachments the game uses (Grip in the middle of the grip,
	TrailBase at the guard, TrailTip at the tip) and moves it to ServerStorage > HuzzKnives > <its skin key>.
	Running it again is fine: a knife already set up is replaced when a new import of it is found, and one already in
	HuzzKnives that is the wrong size or way round, or has parts without their colour or glow, is lined up again from
	its own parts (the first Oct 18 run made 8 knives ~12x too big and sideways and left renamed parts uncoloured on all
	30: Studio had renamed parts, e.g. "blade_0" to "blade_05"; fixed Oct 18).
	The game (HuzzServer/KnifeService) uses these models when they're there; until then it draws its own knife in
	each skin's colours.
]]
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

--@@KNIVES@@

local TAG = "[HuzzKnife]"
local RARITY = { Common = 1, Uncommon = 2, Rare = 3, Epic = 4, Legendary = 5, Mythic = 6, Exclusive = 7 }

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

-- Which baked nodes a part can be. Studio's importer makes names unique across the whole import: the first knife's
-- "blade_0" stays "blade_0", the second knife's comes in as "blade_02", the fifth's as "blade_05", and a second part of
-- the same node gets one more digit ("blade_052"). So a part can be a node whose name is its name, or its name minus
-- trailing digits. (Matching exact names only found under 2 parts on 8 knives of the owner's Oct 18 setup; they fell
-- to the old box guess, which assumed the import stood upright, and came out ~12x too big and sideways.)
local function candidates(k, name: string): { number }
	name = string.lower(name)
	local list = {}
	for i, n in k.nodes do
		local nn = string.lower(n[1])
		if name == nn or (string.sub(name, 1, #nn) == nn and string.match(string.sub(name, #nn + 1), "^%d+$")) then
			table.insert(list, i)
		end
	end
	return list
end

-- The fit: where the knife's own frame (the .glb's units: +Y blade, X width, Z thickness) sits in Studio, from
-- matched pairs { part, node }. Returns s (studs per unit), R (CFrame rotation: columns = the knife's X, Y, Z), t, error;
-- nil when the pairs can't tell (fewer than 2, or all across the blade).
local function fit(k, matches)
	local A, B = {}, {}
	for _, pr in matches do
		table.insert(A, Vector3.new(pr.node[2], pr.node[3], pr.node[4]))
		table.insert(B, pr.part.CFrame.Position)
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
	if #A < 2 or ymax - ymin <= 0.25 * k.len then return nil end
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
	local damp = 1e-6 * (C[1][1] + C[2][2] + C[3][3])
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
	if yv.Magnitude <= 1e-6 then return nil end
	local Y = yv.Unit
	local num = 0
	for i, a in A do num += (a.Y - ca.Y) * (B[i] - cb):Dot(Y) end
	local s = num / syy
	if s <= 0 then return nil end
	-- the blade's thin way (its Z): the blade part's thinnest side across the blade
	local blade, vol = nil, -1
	for _, pr in matches do
		local sz = pr.part.Size
		if string.sub(string.lower(pr.node[1]), 1, 6) == "blade_" and sz.X * sz.Y * sz.Z > vol then
			blade, vol = pr.part, sz.X * sz.Y * sz.Z
		end
	end
	blade = blade or (matches[1] and matches[1].part)
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
	return bestFit
end

-- Lines the knife up: returns s, R, t (above), the matched pairs { part, node } and the fit's error (nil = guessed
-- from the box).
local function lineUp(k, parts: { BasePart })
	-- Parts are paired with nodes by name: parts of one name, shortest part name first ("blade_05" before "blade_052"),
	-- take that name's nodes in .glb order. Several nodes can share a name (a blade and its glowing edge are both
	-- "blade_2"); a part left over takes the last of them.
	local function pairUp(nameOf: { [BasePart]: string })
		local groups, order = {}, {}
		for _, p in parts do
			local key = nameOf[p]
			if key then
				if not groups[key] then groups[key] = {}; table.insert(order, key) end
				table.insert(groups[key], p)
			end
		end
		local list = {}
		for _, key in order do
			local group = groups[key]
			table.sort(group, function(a, b)
				if #a.Name ~= #b.Name then return #a.Name < #b.Name end
				return a.Name < b.Name
			end)
			local nodes = {}
			for _, n in k.nodes do
				if string.lower(n[1]) == key then table.insert(nodes, n) end
			end
			for i, p in group do table.insert(list, { part = p, node = nodes[math.min(i, #nodes)] }) end
		end
		return list
	end
	-- 1. a first guess: each part takes its longest candidate name
	local cands, guess = {}, {}
	for _, p in parts do
		local list = candidates(k, p.Name)
		cands[p] = list
		local best = list[1]
		for _, i in list do
			if #k.nodes[i][1] > #k.nodes[best][1] then best = i end
		end
		if best then guess[p] = string.lower(k.nodes[best][1]) end
	end
	local matches = pairUp(guess)
	local f = fit(k, matches)
	if f then
		-- 2. now that the knife's place is known, each part takes the name of its candidate node nearest to it (sorts
		-- out names that read two ways, like "rune_112" = rune_11 or rune_1 with digits added), and the fit runs again
		local near = {}
		for _, p in parts do
			local best, bestD = nil, math.huge
			for _, i in cands[p] do
				local n = k.nodes[i]
				local d = ((f.R:VectorToWorldSpace(Vector3.new(n[2], n[3], n[4])) * f.s + f.t) - p.CFrame.Position).Magnitude
				if d < bestD - 1e-9 then best, bestD = string.lower(n[1]), d end
			end
			near[p] = best
		end
		local again = pairUp(near)
		local f2 = fit(k, again)
		if f2 and f2.err <= f.err then f, matches = f2, again end
		return f.s, f.R, f.t, matches, f.err
	end
	-- 3. Fallback (too few names matched): the knife is the long way of the parts' box, its tip at the end its blade
	-- parts are nearer, its thin way the box's thinnest side. (Never assume the import stands upright: Studio laid the
	-- knives of All_Knives.glb flat.)
	local lo, hi = Vector3.one * math.huge, -Vector3.one * math.huge
	for _, p in parts do
		local h = p.Size / 2
		lo, hi = lo:Min(p.CFrame.Position - h), hi:Max(p.CFrame.Position + h)
	end
	local size, mid = hi - lo, (lo + hi) / 2
	local axes = { { Vector3.xAxis, size.X }, { Vector3.yAxis, size.Y }, { Vector3.zAxis, size.Z } }
	table.sort(axes, function(a, b) return a[2] > b[2] end)
	local Y, Z = axes[1][1], axes[3][1]
	local bladeAt, weight = Vector3.zero, 0
	for _, p in parts do
		if string.sub(string.lower(p.Name), 1, 5) == "blade" then
			local v = p.Size.X * p.Size.Y * p.Size.Z
			bladeAt += p.CFrame.Position * v
			weight += v
		end
	end
	if weight > 0 and (bladeAt / weight - mid):Dot(Y) < 0 then Y = -Y end
	local s = axes[1][2] / math.max(1e-6, k.len)
	local R = CFrame.fromMatrix(Vector3.zero, Y:Cross(Z), Y, Z)
	local t = mid - Y * (axes[1][2] / 2) - Y * ((k.tip - k.len) * s) -- (the box's pommel end is the .glb's tip - len)
	return s, R, t, matches, nil
end

-- Is a knife already in HuzzKnives the right size and way round? From the Handle: the part centres must reach from
-- the pommel's to the tip's baked centre along +Y in studs (within 15% of the knife), and stay within its width.
local function looksRight(k, model: Instance): boolean
	local handle = model:FindFirstChild("Handle")
	if not (handle and handle:IsA("BasePart")) then return false end
	local lo, hi, count = Vector3.one * math.huge, -Vector3.one * math.huge, 0
	for _, p in partsOf(model) do
		if p ~= handle then
			local c = handle.CFrame:PointToObjectSpace(p.CFrame.Position)
			lo, hi, count = lo:Min(c), hi:Max(c), count + 1
		end
	end
	if count == 0 then return false end
	local nlo, nhi = Vector3.one * math.huge, -Vector3.one * math.huge
	for _, n in k.nodes do
		local c = Vector3.new(n[2], n[3], n[4])
		nlo, nhi = nlo:Min(c), nhi:Max(c)
	end
	local per = k.studs / k.len
	local slack = 0.15 * k.studs
	local across = math.max(nhi.X - nlo.X, nhi.Z - nlo.Z) * per
	return math.abs(hi.Y - (nhi.Y - k.grip) * per) <= slack and math.abs(lo.Y - (nlo.Y - k.grip) * per) <= slack
		and math.max(hi.X - lo.X, hi.Z - lo.Z) <= across + slack
end

-- Has every part of a knife already in HuzzKnives got its colour and glow? (The first Oct 18 run missed every part
-- Studio had renamed, on all 30: they kept the import's texture, and glowing ones weren't Neon.)
local function coloured(k, model: Instance): boolean
	for _, p in partsOf(model) do
		if p.Name ~= "Handle" then
			local list = candidates(k, p.Name)
			local ok = #list == 0 -- (a part no node explains is left to the owner)
			for _, i in list do
				local n = k.nodes[i]
				if p:FindFirstChildOfClass("SurfaceAppearance") == nil and p.Color:ToHex():lower() == n[5]
					and (p.Material == Enum.Material.Neon) == (n[6] == 1) then
					ok = true
				end
			end
			if not ok then return false end
		end
	end
	return true
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
	for _, pr in matched do looks[pr.part] = looks[pr.part] or pr.node end
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
	if not looksRight(k, model) then how ..= "; WRONG SIZE OR WAY ROUND, send a screenshot" end
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
			local old = holder:FindFirstChild(k.key)
			local shaped, painted = looksRight(k, old), coloured(k, old)
			if shaped and painted then
				okCount += 1
				print(string.format("%s %s: already in ServerStorage/HuzzKnives/%s", TAG, k.name, k.key))
			else
				-- set up before, but the wrong size or way round, or with parts that missed their colour or glow (the
				-- first Oct 18 run did both): line it up again from its own parts, in place. Its old Handle goes; setUp
				-- makes a new one and replaces the model.
				local oldHandle = old:FindFirstChild("Handle")
				if oldHandle and oldHandle:IsA("BasePart") then oldHandle:Destroy() end
				local ok, msg = pcall(setUp, k, old, holder)
				if ok then
					okCount += 1
					local why = if shaped then "fixed colours and glow" else "repaired: it was the wrong size or way round"
					print(string.format("%s %s: %s", TAG, why, msg))
				else
					warn(string.format("%s %s: couldn't repair it: %s", TAG, k.name, tostring(msg)))
				end
			end
		else
			table.insert(missing, k.name)
		end
	end
	pcall(function() CHS:SetWaypoint("HuzzKnife setup done") end)
	print(string.format("%s Done: %d of %d knives are in ServerStorage > HuzzKnives.", TAG, okCount, #KNIVES))
	if #missing > 0 then
		warn(string.format("%s missing (not imported yet?): %s", TAG, table.concat(missing, ", ")))
		warn(TAG .. " Import design/knives/Knives/All_Knives.glb and design/knives/gamepass/Gamepass_Knives.glb (File > Import 3D) and run this again.")
	else
		print(TAG .. " Next: File > Save, then right-click ServerStorage > HuzzKnives > Save to File and send it.")
	end
	return okCount
end

--@@RUN@@

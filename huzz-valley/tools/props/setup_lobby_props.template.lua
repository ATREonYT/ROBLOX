--[[
	[HuzzProps] Studio helper: turns the owner's imported lobby props into the game's pad props (owner, Oct 18:
	"implementing these objects into the lobby on top of the already placed circles").
	Owner's steps (also in huzz-valley/CLAUDE.md, "Lobby props"):
	  1. In Studio: File (or the Home tab) > Import 3D, pick design/lobby/Lobby_Props.glb, press Import.
	  2. View > Command Bar. Paste this whole script (or, in the downloaded place, the one line
	     require(game.ServerStorage.HuzzStudioTools.SetupLobbyProps)() ) and press Enter.
	  3. Output shows one [HuzzProps] line per prop and "Done: 5 of 5". Take a screenshot if anything says "missing".
	  4. File > Save. Then right-click ServerStorage > HuzzLobbyProps > Save to File, and send that file, so every new
	     download has the real props too.
	What it does for each prop (Shop_Stall, Like_Reward_Gift, Pumpkin_Patch_Chest, Witch_Brew_Cauldron,
	Sweets_Treats_Coffin): finds it by name, works out which way round and how big Studio imported it (from its parts'
	names and centres, baked from the .glb), keeps his textures, makes the glowing parts (glow_*) Neon in their own
	colour (the SHOP sign and the LIKE tag keep their pictures), welds it to an invisible Root in the middle of the prop
	(1 stud = 1 unit of the .glb; the game scales it), and moves it to ServerStorage > HuzzLobbyProps > <name>. Then it
	swaps the plain-part stand-ins on the pads (Workspace > HuzzLobbyProps) for the real one, so you see it at once.
	Running it again is fine: a new import replaces the old copy.
	The game (HuzzServer/LobbyPropService) uses these models when they're there; until then it builds a stand-in from
	plain parts in his colours.
]]
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

--@@PROPS@@

local TAG = "[HuzzProps]"

local function norm(s: string): string
	return (string.lower(s):gsub("[^%w]", ""))
end

local function partsOf(container: Instance): { BasePart }
	local list = {}
	if container:IsA("BasePart") then table.insert(list, container) end
	for _, d in container:GetDescendants() do
		if d:IsA("BasePart") then table.insert(list, d) end
	end
	return list
end

-- Each prop's imported container (a Model or Folder named like it), in Workspace or ServerStorage, not one of ours.
local function findImports(): { [string]: Instance }
	local wanted = {}
	for _, p in PROPS do wanted[norm(p.key)] = p end
	local found = {}
	local done = ServerStorage:FindFirstChild("HuzzLobbyProps")
	local placed = Workspace:FindFirstChild("HuzzLobbyProps")
	for _, root in { Workspace, ServerStorage } do
		for _, d in root:GetDescendants() do
			if (d:IsA("Model") or d:IsA("Folder")) and not (done and d:IsDescendantOf(done)) and not (placed and d:IsDescendantOf(placed)) then
				local p = wanted[norm(d.Name)]
				if p and not found[p.key] and #partsOf(d) > 0 then found[p.key] = d end
			end
		end
	end
	return found
end

-- The baked node a part is: its own name, or its name minus digits Studio added to make names unique.
local function nodeOf(p, byName, name: string)
	local n = byName[name]
	if n then return n end
	local base = name
	while #base > 0 and base:sub(-1):match("%d") do
		base = base:sub(1, -2)
		n = byName[base]
		if n then return n end
	end
	return nil
end

-- Which way round and how big: the yaw (0, 90, 180 or 270 degrees), studs per .glb unit and the place of the .glb's
-- origin that put the baked centres closest to the parts' centres.
local function fit(pairs)
	local best
	for q = 0, 3 do
		local yaw = q * math.pi / 2
		local c, s = math.cos(yaw), math.sin(yaw)
		local B, P = {}, {}
		local bm, pm = Vector3.zero, Vector3.zero
		for i, pr in pairs do
			local b = pr.node
			B[i] = Vector3.new(c * b[2] + s * b[4], b[3], -s * b[2] + c * b[4])
			P[i] = pr.part.CFrame.Position
			bm += B[i]
			pm += P[i]
		end
		bm /= #pairs
		pm /= #pairs
		local num, den = 0, 0
		for i = 1, #pairs do
			num += (P[i] - pm):Dot(B[i] - bm)
			den += (B[i] - bm):Dot(B[i] - bm)
		end
		if den > 1e-6 and num > 0 then
			local scale = num / den
			local t = pm - bm * scale
			local err = 0
			for i = 1, #pairs do err += ((B[i] * scale + t) - P[i]).Magnitude ^ 2 end
			err = math.sqrt(err / #pairs)
			if not best or err < best.err then best = { yaw = yaw, scale = scale, t = t, err = err } end
		end
	end
	return best
end

local function setUp(p, container: Instance, holder: Folder): string
	local parts = partsOf(container)
	local byName = {}
	for _, n in p.nodes do byName[n[1]] = n end
	local pairs, looks = {}, {}
	for _, part in parts do
		local n = nodeOf(p, byName, part.Name)
		if n then
			table.insert(pairs, { part = part, node = n })
			looks[part] = n
		end
	end
	local f = if #pairs >= 3 then fit(pairs) else nil
	local yaw, scale, origin, how
	if f then
		yaw, scale, origin = f.yaw, f.scale, f.t
		how = if f.err / (scale * math.max(p.size[1], p.size[2], p.size[3])) < 0.05 then "lined up" else "lined up roughly, check it"
	else
		-- names didn't match: from its box, standing up as imported
		local lo, hi = Vector3.one * math.huge, -Vector3.one * math.huge
		for _, part in parts do
			lo = lo:Min(part.Position - part.Size / 2)
			hi = hi:Max(part.Position + part.Size / 2)
		end
		yaw, scale = 0, (hi.Y - lo.Y) / p.size[2]
		origin = Vector3.new((lo.X + hi.X) / 2, lo.Y, (lo.Z + hi.Z) / 2)
		how = "names didn't match: placed from its box, check it"
	end
	-- the Root: the middle of the prop's box; its axes are the .glb's (+Z = the prop's front)
	local model = Instance.new("Model")
	model.Name = p.key
	local root = Instance.new("Part")
	root.Name = "Root"
	root.Transparency = 1
	root.Anchored = true
	root.CanCollide, root.CanTouch, root.CanQuery = false, false, false
	root.Size = Vector3.new(p.size[1], p.size[2], p.size[3]) * scale
	root.CFrame = CFrame.new(origin) * CFrame.Angles(0, yaw, 0) * CFrame.new(0, p.size[2] * scale / 2, 0)
	root.Parent = model
	local neon = 0
	for _, part in parts do
		local n = looks[part]
		if n and n[6] == 1 then
			-- a glowing part: Neon in its own colour (its texture is one flat colour)
			if part:IsA("MeshPart") then pcall(function() part.TextureID = "" end) end
			for _, d in part:GetChildren() do
				if d:IsA("SurfaceAppearance") then d:Destroy() end
			end
			part.Color = Color3.fromHex(n[5])
			part.Material = Enum.Material.Neon
			neon += 1
		end
		for _, d in part:GetChildren() do
			if d:IsA("JointInstance") or d:IsA("WeldConstraint") then d:Destroy() end
		end
		part.Anchored, part.CanCollide, part.CanTouch, part.Massless = false, false, false, true
		part.CanQuery = true -- (clicking the prop opens its menu)
		part.Parent = model
		local w = Instance.new("WeldConstraint")
		w.Part0, w.Part1 = root, part
		w.Parent = part
	end
	model.PrimaryPart = root
	-- 1 stud = 1 unit of the .glb (the game scales it by Config/LobbyProps)
	local ok = pcall(function() model:ScaleTo(model:GetScale() / scale) end)
	if not ok then
		for _, part in parts do
			local rel = root.CFrame:ToObjectSpace(part.CFrame)
			part.Size /= scale
			part.CFrame = root.CFrame * (rel - rel.Position + rel.Position / scale)
		end
		root.Size /= scale
	end
	model:SetAttribute("Prop", p.key)
	model:SetAttribute("Glow", Color3.fromHex(p.glow))
	pcall(function() model:PivotTo(CFrame.new(0, p.size[2] / 2, 0)) end)
	local old = holder:FindFirstChild(p.key)
	if old then old:Destroy() end
	model.Parent = holder
	local c = container
	while c and c ~= Workspace and c ~= ServerStorage and c.Parent and #partsOf(c) == 0 do
		local up = c.Parent
		c:Destroy()
		c = up
	end
	return string.format("%s %s -> ServerStorage/HuzzLobbyProps/%s: %d parts, %d matched, %d glowing, %s", TAG, p.key, p.key, #parts, #pairs, neon, how)
end

-- The pads' stand-ins (Workspace > HuzzLobbyProps > LobbyProp > Prop) swapped for the real model, same place and size.
local function swapPlaced(holder: Folder): number
	local placed = Workspace:FindFirstChild("HuzzLobbyProps")
	if not placed then return 0 end
	local n = 0
	for _, lp in placed:GetChildren() do
		local key = lp:GetAttribute("Prop")
		local master = key and holder:FindFirstChild(key)
		local old = lp:FindFirstChild("Prop")
		if master and old and old:IsA("Model") then
			local copy = master:Clone()
			copy.Name = "Prop"
			copy:SetAttribute("StandIn", false)
			pcall(function() copy:ScaleTo(copy:GetScale() * (lp:GetAttribute("Scale") or 1)) end)
			copy:PivotTo(old:GetPivot())
			for _, d in old:GetChildren() do
				-- keep what the game added (the click, the sparkles)
				if d:IsA("ClickDetector") then d.Parent = copy end
			end
			local oldRoot = old.PrimaryPart
			if oldRoot and copy.PrimaryPart then
				for _, d in oldRoot:GetChildren() do
					if d:IsA("ParticleEmitter") or d:IsA("Light") then d.Parent = copy.PrimaryPart end
				end
			end
			old:Destroy()
			copy.Parent = lp
			n += 1
		end
	end
	return n
end

local function run()
	local CHS = game:GetService("ChangeHistoryService")
	pcall(function() CHS:SetWaypoint("HuzzProps setup") end)
	local holder = ServerStorage:FindFirstChild("HuzzLobbyProps")
	if not holder then
		holder = Instance.new("Folder")
		holder.Name = "HuzzLobbyProps"
		holder.Parent = ServerStorage
	end
	local found = findImports()
	local okCount, missing = 0, {}
	for _, p in PROPS do
		local container = found[p.key]
		if container then
			local ok, msg = pcall(setUp, p, container, holder)
			if ok then
				okCount += 1
				print(msg)
			else
				warn(string.format("%s %s: couldn't set it up: %s", TAG, p.key, tostring(msg)))
			end
		elseif holder:FindFirstChild(p.key) then
			okCount += 1
			print(string.format("%s %s: already in ServerStorage/HuzzLobbyProps", TAG, p.key))
		else
			table.insert(missing, p.key)
		end
	end
	local swapped = swapPlaced(holder)
	pcall(function() CHS:SetWaypoint("HuzzProps setup done") end)
	print(string.format("%s Done: %d of %d props are in ServerStorage > HuzzLobbyProps (%d pads in Workspace now show them).", TAG, okCount, #PROPS, swapped))
	if #missing > 0 then
		warn(string.format("%s missing (not imported yet?): %s", TAG, table.concat(missing, ", ")))
		warn(TAG .. " Import design/lobby/Lobby_Props.glb (File > Import 3D) and run this again.")
	else
		print(TAG .. " Next: File > Save, then right-click ServerStorage > HuzzLobbyProps > Save to File and send it.")
	end
	return okCount
end

--@@RUN@@

--[[
	HandEdits  (loaded by the install steps, Edit mode; not a Command Bar paste on its own)

	Alex, Oct 31: "if i change up some things will you keep them how they are after they were changed?"
	The builders (BuildWorld1, BuildLobbyExtras, BuildLobbyDressing, ...) delete and rebuild their folders, which
	would wipe anything Alex changed by hand inside them. So every install now goes:
	  1. snapshot the live folders (what is in Alex's Studio now) and back them up to ServerStorage.HandEditBackups
	  2. compare with the snapshot taken right after the last install (the "baseline", kept in the repo under
	     tools/studio/baseline/): every difference is a hand edit (moved, recoloured, resized, added or deleted)
	  3. run the builders, then put every hand edit back on top (apply), and save the edits in the repo
	     (tools/studio/hand_edits.json) so they are part of the game from then on
	  4. snapshot again: that is the new baseline

	local HE = loadstring(src)()   -- returns the functions below
	HE.snapshot(names)              -- { [key] = fingerprint } for the named Workspace folders/models
	HE.diff(baseline, live)         -- { changed = {...}, added = {...}, removed = {...} }
	HE.backup(names, tag)           -- clones the named folders into ServerStorage.HandEditBackups.<tag>
	HE.apply(edits, tag)            -- re-applies edits to the rebuilt folders (added ones come from the backup)

	A part's key is its path from Workspace with its build position, e.g.
	"LobbyDressing/Clump3/Bush@-133.2,5.1,12.8", so look-alike parts (flags, bushes) stay apart; a part
	Alex moved shows up as removed + added with the same name and parent, which diff pairs up as "changed".
]]

local HttpService = game:GetService("HttpService")
local ServerStorage = game:GetService("ServerStorage")

local HE = {}

local function r(n, d)
	local m = 10 ^ (d or 1)
	return math.floor(n * m + 0.5) / m
end
local function v3(v, d)
	return string.format("%s,%s,%s", r(v.X, d), r(v.Y, d), r(v.Z, d))
end
local function c3(c)
	return string.format("%d,%d,%d", math.floor(c.R * 255 + 0.5), math.floor(c.G * 255 + 0.5), math.floor(c.B * 255 + 0.5))
end

-- the properties that count as a hand edit, per kind of thing
local function fingerprint(inst)
	if inst:IsA("BasePart") then
		local f = {
			Class = inst.ClassName,
			Pos = v3(inst.Position, 1),
			Size = v3(inst.Size, 2),
			Rot = v3(inst.Orientation, 0),
			Color = c3(inst.Color),
			Material = inst.Material.Name,
			Transparency = r(inst.Transparency, 2),
			CanCollide = inst.CanCollide,
		}
		if inst:IsA("Part") then
			f.Shape = inst.Shape.Name
		end
		return f
	elseif inst:IsA("TextLabel") or inst:IsA("TextButton") then
		return { Class = inst.ClassName, Text = inst.Text, TextColor = c3(inst.TextColor3), Visible = inst.Visible }
	elseif inst:IsA("Light") then
		return { Class = inst.ClassName, Color = c3(inst.Color), Brightness = r(inst.Brightness, 2), Range = r(inst.Range, 1), Enabled = inst.Enabled }
	elseif inst:IsA("Fire") then
		return { Class = "Fire", Size = r(inst.Size, 1), Color = c3(inst.Color), Enabled = inst.Enabled }
	elseif inst:IsA("ParticleEmitter") then
		return { Class = "ParticleEmitter", Rate = r(inst.Rate, 1), Enabled = inst.Enabled }
	elseif inst:IsA("Model") or inst:IsA("Folder") or inst:IsA("SurfaceGui") or inst:IsA("BillboardGui") then
		return { Class = inst.ClassName }
	end
	return nil -- textures, welds, attachments, UI strokes: not tracked
end

-- a stable key: the parent's key plus the name, plus the position for parts (look-alikes stay apart)
local function keyOf(inst, parentKey, seen)
	local k = parentKey .. "/" .. inst.Name
	if inst:IsA("BasePart") then
		k ..= "@" .. v3(inst.Position, 1)
	end
	seen[k] = (seen[k] or 0) + 1
	if seen[k] > 1 then
		k ..= "#" .. seen[k]
	end
	return k
end

local function walk(inst, parentKey, out, seen, index)
	for _, child in ipairs(inst:GetChildren()) do
		local f = fingerprint(child)
		if f then
			local k = keyOf(child, parentKey, seen)
			out[k] = f
			if index then
				index[k] = child
			end
			walk(child, k, out, seen, index)
		end
	end
end

function HE.snapshot(names, root)
	root = root or workspace
	local out, seen = {}, {}
	for _, name in ipairs(names) do
		local top = root:FindFirstChild(name)
		if top then
			local k = name
			out[k] = fingerprint(top) or { Class = top.ClassName }
			if top:IsA("BasePart") then
				out[k] = fingerprint(top)
			end
			walk(top, k, out, seen)
		end
	end
	return out
end

local function index(names, root)
	local map, out, seen = {}, {}, {}
	for _, name in ipairs(names) do
		local top = root:FindFirstChild(name)
		if top then
			map[name] = top
			walk(top, name, out, seen, map)
		end
	end
	return map
end

local function same(a, b)
	for k, v in pairs(a) do
		if b[k] ~= v then
			return false
		end
	end
	for k in pairs(b) do
		if a[k] == nil then
			return false
		end
	end
	return true
end

local function parentOf(key)
	return key:match("^(.*)/[^/]*$") or ""
end
local function nameOf(key)
	return (key:match("/([^/@#]*)[^/]*$") or key)
end

-- what changed between the baseline (right after the last install) and the live Studio now
function HE.diff(base, live)
	local changed, added, removed = {}, {}, {}
	for k, f in pairs(live) do
		local b = base[k]
		if not b then
			table.insert(added, k)
		elseif not same(b, f) then
			table.insert(changed, { Key = k, From = b, To = f })
		end
	end
	for k in pairs(base) do
		if not live[k] then
			table.insert(removed, k)
		end
	end
	-- a moved part is removed + added with the same name, class and parent: pair them up as a change
	local moved = {}
	for ai = #added, 1, -1 do
		local a = added[ai]
		for ri = #removed, 1, -1 do
			local rk = removed[ri]
			if parentOf(rk) == parentOf(a) and nameOf(rk) == nameOf(a) and base[rk].Class == live[a].Class then
				table.insert(moved, { Key = rk, NewKey = a, From = base[rk], To = live[a] })
				table.remove(added, ai)
				table.remove(removed, ri)
				break
			end
		end
	end
	for _, m in ipairs(moved) do
		table.insert(changed, m)
	end
	-- things inside a moved part (a sign's text, a lamp's light) moved with it: compare them under the old key
	table.sort(moved, function(x, y)
		return #x.Key < #y.Key
	end)
	for _, m in ipairs(moved) do
		local prefix = m.NewKey .. "/"
		for ai = #added, 1, -1 do
			local a = added[ai]
			if a:sub(1, #prefix) == prefix then
				local was = m.Key .. "/" .. a:sub(#prefix + 1)
				local ri = table.find(removed, was)
				if ri then
					if not same(base[was], live[a]) then
						table.insert(changed, { Key = was, From = base[was], To = live[a] })
					end
					table.remove(added, ai)
					table.remove(removed, ri)
				end
			end
		end
	end
	-- only report the top of an added or removed branch (its children come with it)
	local function tops(list)
		local set = {}
		for _, k in ipairs(list) do
			set[k] = true
		end
		local res = {}
		for _, k in ipairs(list) do
			local p, top = parentOf(k), true
			while p ~= "" do
				if set[p] then
					top = false
					break
				end
				p = parentOf(p)
			end
			if top then
				table.insert(res, k)
			end
		end
		table.sort(res)
		return res
	end
	table.sort(changed, function(x, y)
		return x.Key < y.Key
	end)
	return { changed = changed, added = tops(added), removed = tops(removed) }
end

function HE.backup(names, tag)
	local all = ServerStorage:FindFirstChild("HandEditBackups") or Instance.new("Folder")
	all.Name = "HandEditBackups"
	all.Parent = ServerStorage
	local old = all:FindFirstChild(tag)
	if old then
		old:Destroy()
	end
	local box = Instance.new("Folder")
	box.Name = tag
	for _, name in ipairs(names) do
		local top = workspace:FindFirstChild(name)
		if top then
			top:Clone().Parent = box
		end
	end
	box.Parent = all
	return box
end

local function setProps(inst, to)
	if inst:IsA("BasePart") then
		local p = string.split(to.Pos, ",")
		local o = string.split(to.Rot, ",")
		inst.CFrame = CFrame.new(tonumber(p[1]), tonumber(p[2]), tonumber(p[3]))
			* CFrame.fromOrientation(math.rad(tonumber(o[1])), math.rad(tonumber(o[2])), math.rad(tonumber(o[3])))
		local s = string.split(to.Size, ",")
		inst.Size = Vector3.new(tonumber(s[1]), tonumber(s[2]), tonumber(s[3]))
		local c = string.split(to.Color, ",")
		inst.Color = Color3.fromRGB(tonumber(c[1]), tonumber(c[2]), tonumber(c[3]))
		inst.Material = Enum.Material[to.Material]
		inst.Transparency = to.Transparency
		inst.CanCollide = to.CanCollide
		if to.Shape and inst:IsA("Part") then
			inst.Shape = Enum.PartType[to.Shape]
		end
	elseif to.Text ~= nil then
		inst.Text = to.Text
		local c = string.split(to.TextColor, ",")
		inst.TextColor3 = Color3.fromRGB(tonumber(c[1]), tonumber(c[2]), tonumber(c[3]))
		inst.Visible = to.Visible
	elseif to.Brightness ~= nil then
		local c = string.split(to.Color, ",")
		inst.Color = Color3.fromRGB(tonumber(c[1]), tonumber(c[2]), tonumber(c[3]))
		inst.Brightness = to.Brightness
		inst.Range = to.Range
		inst.Enabled = to.Enabled
	elseif to.Class == "Fire" then
		inst.Size = to.Size
		inst.Enabled = to.Enabled
	elseif to.Class == "ParticleEmitter" then
		inst.Rate = to.Rate
		inst.Enabled = to.Enabled
	end
end

-- put the hand edits back on the freshly rebuilt folders; returns lines saying what was kept or couldn't be
function HE.apply(edits, tag, names)
	local report = {}
	local box = ServerStorage:FindFirstChild("HandEditBackups") and ServerStorage.HandEditBackups:FindFirstChild(tag)
	local live = index(names, workspace)
	local saved = box and index(names, box) or {}
	for _, ch in ipairs(edits.changed or {}) do
		local inst = live[ch.Key]
		if inst then
			local ok, err = pcall(setProps, inst, ch.To)
			table.insert(report, (ok and "kept change: " or "could not keep change: ") .. ch.Key .. (ok and "" or (" " .. tostring(err))))
		else
			table.insert(report, "the builder no longer makes " .. ch.Key .. " (change not re-applied)")
		end
	end
	local movedParents = {}
	for _, ch in ipairs(edits.changed or {}) do
		if ch.NewKey then
			movedParents[ch.Key] = true
		end
	end
	for _, k in ipairs(edits.removed or {}) do
		local inst = live[k]
		if inst and movedParents[parentOf(k)] then
			table.insert(report, "left in place (its parent was moved, not deleted): " .. k)
		elseif inst then
			inst:Destroy()
			table.insert(report, "kept deleted: " .. k)
		end
	end
	for _, k in ipairs(edits.added or {}) do
		local src = saved[k]
		local pk = parentOf(k)
		for _, ch in ipairs(edits.changed or {}) do
			if ch.NewKey and (pk == ch.NewKey or pk:sub(1, #ch.NewKey + 1) == ch.NewKey .. "/") then
				pk = ch.Key .. pk:sub(#ch.NewKey + 1) -- added inside a part Alex moved: the rebuilt part has its old key
			end
		end
		local parent = live[pk]
		if src and parent then
			src:Clone().Parent = parent
			table.insert(report, "kept added: " .. k)
		else
			table.insert(report, "could not put back added " .. k .. (src and " (its parent is gone)" or " (not in the backup)"))
		end
	end
	return report
end

-- fetch one builder from GitHub at a commit and run it (the same way the installs always have)
function HE.runBuilder(name, sha)
	local was = HttpService.HttpEnabled
	HttpService.HttpEnabled = true
	local ok, src = pcall(function()
		return HttpService:GetAsync("https://raw.githubusercontent.com/ATREonYT/ROBLOX/" .. sha .. "/cannon-evolution/src/tools/" .. name .. ".lua")
	end)
	HttpService.HttpEnabled = was
	if not ok then
		return false, "fetch failed: " .. tostring(src)
	end
	local cfg = loadstring(game.ReplicatedStorage.GameConfig.Source)()
	src = src:gsub("require%(game%.ReplicatedStorage%.GameConfig%)", "(...)")
	local f, err = loadstring(src)
	if not f then
		return false, "compile: " .. tostring(err)
	end
	return pcall(f, cfg)
end

-- the baseline lives in the place itself (ServerStorage.HandEditBaseline), one set of chunks per folder, so it
-- is saved with the place and always matches what the builders last made there
local CHUNK = 150000
function HE.saveBaseline(names)
	local holder = ServerStorage:FindFirstChild("HandEditBaseline") or Instance.new("Folder")
	holder.Name = "HandEditBaseline"
	holder.Parent = ServerStorage
	for _, name in ipairs(names) do
		local old = holder:FindFirstChild(name)
		if old then
			old:Destroy()
		end
		local s = HttpService:JSONEncode(HE.snapshot({ name }))
		local f = Instance.new("Folder")
		f.Name = name
		for i = 1, math.ceil(#s / CHUNK) do
			local v = Instance.new("StringValue")
			v.Name = string.format("Part%02d", i)
			v.Value = s:sub((i - 1) * CHUNK + 1, i * CHUNK)
			v.Parent = f
		end
		f.Parent = holder
	end
end
function HE.loadBaseline(names)
	local holder = ServerStorage:FindFirstChild("HandEditBaseline")
	if not holder then
		return nil
	end
	local all = {}
	for _, name in ipairs(names) do
		local f = holder:FindFirstChild(name)
		if not f then
			return nil
		end
		local parts = f:GetChildren()
		table.sort(parts, function(a, b)
			return a.Name < b.Name
		end)
		local s = ""
		for _, v in ipairs(parts) do
			s ..= v.Value
		end
		for k, v in pairs(HttpService:JSONDecode(s)) do
			all[k] = v
		end
	end
	return all
end

function HE.json(t)
	return HttpService:JSONEncode(t)
end
function HE.decode(s)
	return HttpService:JSONDecode(s)
end

return HE

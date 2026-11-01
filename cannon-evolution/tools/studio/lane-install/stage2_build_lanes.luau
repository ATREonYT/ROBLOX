local SKIP = {}
local NEW = "7d81642f253172feb4375cad04129ce10ccb79b2"
local OLD = "68f33c98c72bcd774c41ece257af918ada699117"
local HttpService = game:GetService("HttpService")
local SS = game:GetService("ServerStorage")
local function get(path, sha)
	local was = HttpService.HttpEnabled
	HttpService.HttpEnabled = true
	local ok, s = pcall(HttpService.GetAsync, HttpService, "https://raw.githubusercontent.com/ATREonYT/ROBLOX/" .. sha .. "/" .. path)
	HttpService.HttpEnabled = was
	assert(ok, "fetch " .. path .. ": " .. tostring(s))
	return s
end
local HE = loadstring(get("cannon-evolution/src/tools/HandEdits.lua", NEW))()
local NAMES = { "TrainingStations" }
local TAG = "Lanes-Nov1"
-- studs on the lanes only (BuildCartoonyMap scoped to TrainingStations, no cannon templates, no map)
local function studLanes(sha)
	local src = get("cannon-evolution/src/tools/BuildCartoonyMap.lua", sha)
	local n1, n2
	src, n1 = src:gsub("for _, r in ipairs%(roots%) do", "for _, r in ipairs({ workspace.TrainingStations }) do", 1)
	src, n2 = src:gsub("for _, r in ipairs%(cannonRoots%) do", "for _, r in ipairs({}) do", 1)
	assert(n1 == 1 and n2 == 1, "could not scope BuildCartoonyMap")
	assert(loadstring(src))()
end
-- put back everything else BuildWorld1 rebuilds, exactly as it was before the install
local function restoreOthers()
	local keep = SS:FindFirstChild("LaneInstallKeep")
	if not keep then
		return "nothing kept"
	end
	for _, o in ipairs(keep:GetChildren()) do
		if o:IsA("Instance") and not o:IsA("StringValue") then
			local now = workspace:FindFirstChild(o.Name)
			if now then
				now:Destroy()
			end
			o:Clone().Parent = workspace
		end
	end
	for _, n in ipairs({ "MyCannonSpot", "LaunchPoint" }) do
		local cf = keep:GetAttribute(n)
		local o = workspace:FindFirstChild(n)
		if cf and o then
			o.CFrame = cf
		end
	end
	local sp = workspace:FindFirstChildOfClass("SpawnLocation")
	if sp and keep:GetAttribute("Spawn") then
		sp.CFrame = keep:GetAttribute("Spawn")
	end
	return "others restored"
end
-- STAGE 2: build the new lanes, save the new baseline, put the chosen hand edits back, restore the rest
local keep = SS.LaneInstallKeep
local edits = HttpService:JSONDecode(keep.Edits.Value)
local function filter(list, getKey)
	local out = {}
	for _, e in ipairs(list or {}) do
		if not SKIP[getKey(e)] then
			table.insert(out, e)
		end
	end
	return out
end
edits.changed = filter(edits.changed, function(e) return e.Key end)
edits.added = filter(edits.added, function(k) return k end)
edits.removed = filter(edits.removed, function(k) return k end)
local ok, err = HE.runBuilder("BuildWorld1", NEW)
assert(ok, err)
ok, err = HE.runBuilder("BuildRebirthSigns", NEW)
assert(ok, err)
studLanes(NEW)
HE.saveBaseline(NAMES)
local report = HE.apply(edits, TAG, NAMES)
table.insert(report, restoreOthers())
-- the lanes' motion script (client)
local sps = game.StarterPlayer.StarterPlayerScripts
local ls = sps:FindFirstChild("LaneMotion") or Instance.new("LocalScript")
ls.Name = "LaneMotion"
ls.Source = get("cannon-evolution/src/client/LaneMotion.client.lua", NEW)
ls.Parent = sps
table.insert(report, "LaneMotion script in StarterPlayerScripts")
local n = 0
for _, s in ipairs(workspace.TrainingStations:GetChildren()) do
	if s:FindFirstChild("Booth") and s.Booth:FindFirstChild("Belt") then
		n += 1
	end
end
table.insert(report, 1, "[LaneInstall] stage 2: " .. n .. " lanes with belts")
return table.concat(report, "\n")

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
-- STAGE 1: snapshot and back up the live lanes, find Alex's hand edits, leave the workspace as it was
local keep = SS:FindFirstChild("LaneInstallKeep")
if keep then
	keep:Destroy()
end
keep = Instance.new("Folder")
keep.Name = "LaneInstallKeep"
for _, n in ipairs({ "TrainingShop", "LaunchZone" }) do
	local o = workspace:FindFirstChild(n)
	if o then
		o:Clone().Parent = keep
	end
end
for _, n in ipairs({ "MyCannonSpot", "LaunchPoint" }) do
	local o = workspace:FindFirstChild(n)
	if o then
		keep:SetAttribute(n, o.CFrame)
	end
end
local sp = workspace:FindFirstChildOfClass("SpawnLocation")
if sp then
	keep:SetAttribute("Spawn", sp.CFrame)
end
keep.Parent = SS

local live = HE.snapshot(NAMES)
HE.backup(NAMES, TAG)
local base = HE.loadBaseline(NAMES)
local how = "saved baseline"
if not base then
	how = "old build " .. OLD:sub(1, 8)
	local ok, err = HE.runBuilder("BuildWorld1", OLD)
	assert(ok, err)
	ok, err = HE.runBuilder("BuildRebirthSigns", OLD)
	assert(ok, err)
	studLanes(OLD)
	base = HE.snapshot(NAMES)
	workspace.TrainingStations:Destroy()
	SS.HandEditBackups[TAG].TrainingStations:Clone().Parent = workspace
	restoreOthers()
end
local edits = HE.diff(base, live)
local v = Instance.new("StringValue")
v.Name = "Edits"
v.Value = HttpService:JSONEncode(edits)
v.Parent = keep
local out = { "[LaneInstall] stage 1 via " .. how, ("changed %d, added %d, removed %d"):format(#(edits.changed or {}), #(edits.added or {}), #(edits.removed or {})) }
for _, c in ipairs(edits.changed or {}) do
	table.insert(out, "changed " .. c.Key .. (c.NewKey and (" -> " .. c.NewKey) or ""))
end
for _, k in ipairs(edits.added or {}) do
	table.insert(out, "added " .. k)
end
for _, k in ipairs(edits.removed or {}) do
	table.insert(out, "removed " .. k)
end
return table.concat(out, "\n", 1, math.min(#out, 120))

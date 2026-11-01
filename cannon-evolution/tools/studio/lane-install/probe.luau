-- read-only: what is live now
local out = {}
local function add(s) table.insert(out, s) end
local ts = workspace:FindFirstChild("TrainingStations")
add("TrainingStations: " .. (ts and #ts:GetChildren() or -1) .. " children")
if ts then
	for _, s in ipairs(ts:GetChildren()) do
		local b = s:FindFirstChild("Booth")
		add(("  %s %s booth=%d pool=%s belt=%s sign=%s"):format(s.Name, s.ClassName, b and #b:GetDescendants() or 0,
			tostring(b and b:FindFirstChild("Pool", true) ~= nil), tostring(b and b:FindFirstChild("Belt") ~= nil), tostring(s:FindFirstChild("RebirthSign") ~= nil)))
	end
end
local hb = game.ServerStorage:FindFirstChild("HandEditBaseline")
local names = {}
if hb then for _, c in ipairs(hb:GetChildren()) do table.insert(names, c.Name) end end
add("baseline folders: " .. (hb and table.concat(names, ",") or "none"))
local lz = workspace:FindFirstChild("LaunchZone")
local bb = lz and lz:FindFirstChildOfClass("BillboardGui")
add("LaunchZone label MaxDistance: " .. tostring(bb and bb.MaxDistance))
for _, n in ipairs({ "TrainingShop", "MyCannonSpot", "LaunchPoint", "LanePlatform" }) do
	add(n .. ": " .. tostring(workspace:FindFirstChild(n) ~= nil))
end
for _, c in ipairs(game.StarterPlayer.StarterPlayerScripts:GetChildren()) do add("SPS " .. c.Name .. " " .. c.ClassName) end
add("HttpEnabled " .. tostring(game:GetService("HttpService").HttpEnabled))
return table.concat(out, "\n")

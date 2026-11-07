--[[
	+1 Chess Evolution: Studio installer (Edit mode, Command Bar or the Studio MCP).

	1. Drag places/Install.rbxm into the Studio window (it lands as Workspace.ChessInstall).
	2. Run this. Each piece of the game replaces the copy with the same name in the
	   matching service, the map is swapped, and ChessInstall is removed.
	It only touches the names the bundle brings, so anything else you made stays.
	Output lines start with [ChessInstall].
]]
local bundle = workspace:FindFirstChild("ChessInstall") or game:GetService("ServerStorage"):FindFirstChild("ChessInstall")
if not bundle then
	warn("[ChessInstall] drag places/Install.rbxm into Studio first (Workspace.ChessInstall not found)")
	return
end
local moved = 0
local function place(src: Instance, dest: Instance)
	for _, child in src:GetChildren() do
		local old = dest:FindFirstChild(child.Name)
		local isContainer = child:IsA("Folder") and old and old:IsA("Folder") and child.Name ~= "Kit" and child.Name ~= "Chess" and child.Name ~= "ChessAssets"
		if child.ClassName == "StarterPlayerScripts" or (old and (old:IsA("StarterPlayerScripts"))) then
			place(child, old or dest)
		elseif isContainer then
			place(child, old)
		else
			if old then
				old:Destroy()
			end
			child.Parent = dest
			moved += 1
		end
	end
end
for _, svcFolder in bundle:GetChildren() do
	local ok, svc = pcall(function()
		return game:GetService(svcFolder.Name)
	end)
	if svcFolder.Name == "StarterPlayer" then
		local spsSrc = svcFolder:FindFirstChild("StarterPlayerScripts")
		if spsSrc then
			place(spsSrc, game:GetService("StarterPlayer"):FindFirstChildOfClass("StarterPlayerScripts"))
		end
	elseif ok and svc then
		place(svcFolder, svc)
	else
		warn("[ChessInstall] unknown service " .. svcFolder.Name)
	end
end
bundle:Destroy()
print(`[ChessInstall] installed {moved} pieces. Press Play to test.`)

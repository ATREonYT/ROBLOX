-- [MTL HoodLife] Installs ONLY the living-neighbourhood scripts (Edit mode). Other threads' scripts are never
-- overwritten: Studio is the source of truth for them, so the three shared scripts get a small in-place patch instead
-- (Client boot line, Main boot line, Actors.adopt). Needs the vault file server:
--   cd "~/ROBLOX/Miami Trap Life" && python3 -m http.server 34873 --bind 127.0.0.1
-- HTTP is switched on only while it runs.
local H = game:GetService("HttpService")
local BASE = "http://127.0.0.1:34873/"

local FILES = {
	{ "ReplicatedStorage/MTL/Config", "Ambient", "ModuleScript", "src/ReplicatedStorage/MTL/Config/Ambient.lua" },
	{ "ReplicatedStorage/MTL/Config", "AmbientMap", "ModuleScript", "src/ReplicatedStorage/MTL/Config/AmbientMap.lua" },
	{ "ReplicatedStorage/MTL/Config", "Outfits", "ModuleScript", "src/ReplicatedStorage/MTL/Config/Outfits.lua" },
	{ "ReplicatedStorage/MTL/Rules", "AmbientRules", "ModuleScript", "src/ReplicatedStorage/MTL/Rules/AmbientRules.lua" },
	{ "ServerScriptService/MTL/Services", "AmbientRigService", "ModuleScript", "src/ServerScriptService/MTL/Services/AmbientRigService.lua" },
	{ "StarterPlayer/StarterPlayerScripts/MTL/Controllers", "AmbientLife", "ModuleScript", "src/StarterPlayer/StarterPlayerScripts/MTL/Controllers/AmbientLife.lua" },
	{ "StarterPlayer/StarterPlayerScripts/MTL/Controllers", "AmbientPeople", "ModuleScript", "src/StarterPlayer/StarterPlayerScripts/MTL/Controllers/AmbientPeople.lua" },
	{ "StarterPlayer/StarterPlayerScripts/MTL/Controllers", "AmbientTraffic", "ModuleScript", "src/StarterPlayer/StarterPlayerScripts/MTL/Controllers/AmbientTraffic.lua" },
	{ "StarterPlayer/StarterPlayerScripts/MTL/Controllers", "AmbientBirds", "ModuleScript", "src/StarterPlayer/StarterPlayerScripts/MTL/Controllers/AmbientBirds.lua" },
	{ "StarterPlayer/StarterPlayerScripts/MTL/Controllers", "AmbientSound", "ModuleScript", "src/StarterPlayer/StarterPlayerScripts/MTL/Controllers/AmbientSound.lua" },
	{ "StarterPlayer/StarterPlayerScripts/MTL/Controllers", "AmbientWindows", "ModuleScript", "src/StarterPlayer/StarterPlayerScripts/MTL/Controllers/AmbientWindows.lua" },
}

local function at(path: string): Instance
	local cur: Instance = game
	for name in string.gmatch(path, "[^/]+") do
		local nxt = cur:FindFirstChild(name)
		if not nxt then
			if cur == game then
				nxt = game:GetService(name)
			else
				nxt = Instance.new("Folder")
				nxt.Name = name
				nxt.Parent = cur
			end
		end
		cur = nxt :: Instance
	end
	return cur
end

local function patch(script: LuaSourceContainer?, marker: string, find: string, replace: string): string
	if not script then
		return "missing"
	end
	local src = (script :: any).Source
	if string.find(src, marker, 1, true) then
		return "already"
	end
	local i, j = string.find(src, find, 1, true)
	if not i then
		return "ANCHOR NOT FOUND"
	end
	(script :: any).Source = string.sub(src, 1, i - 1) .. replace .. string.sub(src, j + 1)
	return "patched"
end

local report = {}
local was = H.HttpEnabled
H.HttpEnabled = true
local ok, err = pcall(function()
	for _, f in FILES do
		local src = H:GetAsync(BASE .. f[4]:gsub(" ", "%%20"), true)
		local parent = at(f[1])
		local s = parent:FindFirstChild(f[2])
		if s and s.ClassName ~= f[3] then
			s:Destroy()
			s = nil
		end
		s = s or Instance.new(f[3])
		s.Name = f[2]
		;(s :: any).Source = src
		s.Parent = parent
	end
	table.insert(report, "wrote " .. #FILES .. " scripts")
end)
H.HttpEnabled = was
if not ok then
	return "install failed: " .. tostring(err)
end

local SPS = game.StarterPlayer.StarterPlayerScripts.MTL
table.insert(report, "Client: " .. patch(SPS:FindFirstChild("Client") :: any, '"AmbientLife"',
	'\t"TutorialController", -- the new-player coach card (needs HUD, Phone, Menu, Cutscene)\n',
	'\t"TutorialController", -- the new-player coach card (needs HUD, Phone, Menu, Cutscene)\n\t"AmbientLife", -- the living neighbourhood: people, traffic, birds, world sound, night windows (helpers Ambient*; needs Lighting, Cutscene)\n'))
table.insert(report, "Main: " .. patch(game.ServerScriptService.MTL:FindFirstChild("Main") :: any, '"AmbientRigService"',
	'\t"GoalService", -- Piece 4: FreePlay goals + the objective line in free play\n',
	'\t"GoalService", -- Piece 4: FreePlay goals + the objective line in free play\n\t"AmbientRigService", -- living neighbourhood: builds the street people (Config/Outfits) for clients to clone\n'))
table.insert(report, "Actors: " .. patch(SPS.Controllers:FindFirstChild("Actors") :: any, "function Actors.adopt",
	'\tassert(model)\n\tstrip(model)\n',
	'\tassert(model)\n\treturn Actors.adopt(model, rigName, parent)\nend\n\n-- Turns any humanoid model (already cloned) into a puppet actor. AmbientPeople uses it for MTL_AmbientRigs clones.\nfunction Actors.adopt(model: Model, rigName: string, parent: Instance?): Actor?\n\tstrip(model)\n'))
return table.concat(report, " | ")

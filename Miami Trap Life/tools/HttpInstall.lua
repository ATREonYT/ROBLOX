-- [MTL Install] Pulls every script listed in tools/manifest.json from a local file server and writes it into
-- Studio (Edit mode). Start the server first on the Mac:
--   cd "~/ROBLOX/Miami Trap Life" && python3 -m http.server 34873 --bind 127.0.0.1
-- Then run this in the Command Bar. It turns HTTP on only while it runs and puts the setting back afterwards.
-- Only touches the MTL folders, then saves every UI/Build/<Name> screen into StarterGui.
local HttpService = game:GetService("HttpService")
local BASE = "http://127.0.0.1:34873/"

local function svc(path)
	local cur = game
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
		cur = nxt
	end
	return cur
end

local function urlPath(p)
	return (p:gsub(" ", "%%20"))
end

local wasEnabled = HttpService.HttpEnabled
HttpService.HttpEnabled = true
local ok, err = pcall(function()
	local manifest = HttpService:JSONDecode(HttpService:GetAsync(BASE .. "tools/manifest.json", true))
	local n = 0
	for _, e in manifest do
		local src = HttpService:GetAsync(BASE .. urlPath(e.file), true)
		local parent = svc(e.dir)
		local old = parent:FindFirstChild(e.name)
		if old and old.ClassName ~= e.class then
			old:Destroy()
			old = nil
		end
		local s = old or Instance.new(e.class)
		s.Name = e.name
		s.Source = src
		s.Parent = parent
		n += 1
	end
	print("[MTL Install] wrote " .. n .. " scripts")
end)
HttpService.HttpEnabled = wasEnabled
if not ok then
	error("[MTL Install] failed: " .. tostring(err))
end

-- save every UI/Build/<Name> screen (MTL_HUD, MTL_Phone, ...) into StarterGui as real instances
local tmp = game.ReplicatedStorage.MTL:Clone()
tmp.Name = "MTL_InstallTmp"
tmp.Parent = game.ServerStorage
local report = {}
for _, m in tmp.UI.Build:GetChildren() do
	if m:IsA("ModuleScript") then
		local okB, e2 = pcall(function()
			local gui = require(m).build()
			local old = game.StarterGui:FindFirstChild(gui.Name)
			if old then
				old:Destroy()
			end
			gui.Parent = game.StarterGui
		end)
		table.insert(report, m.Name .. "=" .. tostring(okB) .. (if okB then "" else " " .. tostring(e2)))
	end
end
tmp:Destroy()
print("[MTL Install] StarterGui: " .. table.concat(report, ", "))
return table.concat(report, ", ")

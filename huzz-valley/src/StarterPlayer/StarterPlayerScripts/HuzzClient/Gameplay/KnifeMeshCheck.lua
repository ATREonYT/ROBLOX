--[[
	Every knife shows in the live game (owner, Oct 20 15:13: "make it so that the knifes also appear inside of the
	actual roblox game"). His 30 imported knives are his uploaded meshes on an invisible Handle. Studio draws a mesh
	from its own copy right after his import; a live screen loads each from Roblox, and an upload Roblox hasn't
	finished or approved loads nothing, so that knife was simply gone. HuzzServer/KnifeService puts the plain cut of
	his own .glb, hidden, inside every copy of his knife (a Folder "KnifeBackup"; the model's "Backup" attribute names
	the knife). Here, on each screen, every such knife (in the Workspace: hands, backs, hips, stands; and in this
	player's PlayerGui: the 3D knife on a card, UI/ImageLoader) has its meshes loaded with ContentProvider:PreloadAsync:
	  * any of his meshes Failure or TimedOut: his parts hide on this screen and the backup shows (each part's own
	    Transparency, its "Shown" attribute);
	  * no answer within WAIT seconds: the backup shows meanwhile, and his model comes back if his meshes then load.
	Only his mesh IDs count (a texture that doesn't load leaves the plain-coloured mesh, which still shows). Nothing
	changes where his meshes load (Studio, and live once Roblox has them). Output says once per knife
	"[HuzzKnife] <key>: his mesh ... didn't load here ...: showing the plain cut of his knife" (docs/STUDIO-STEPS.md
	Part 6 says what he does then). Never on screen.
	tools/preview/smoke_knife_backup.luau runs it (preload swapped for a stub).
]]
local M = {}

M.WAIT = 8 -- seconds before the backup shows while his meshes are still loading
M.SETTLE = 0.5 -- seconds after a knife arrives before its parts are gathered
M.FOLDER = "KnifeBackup"
local BAD = { Failure = true, TimedOut = true }

-- ContentProvider:PreloadAsync (the smoke test swaps this): calls back (content id, Enum.AssetFetchStatus) per asset.
function M.preload(list: { Instance }, callback: (string, any) -> ())
	game:GetService("ContentProvider"):PreloadAsync(list, callback)
end

local told: { [string]: boolean } = {}
M.say = function(text: string) warn(text) end -- (the smoke test listens here)

-- His parts and the backup's parts of one knife copy.
function M.partsOf(model: Instance): ({ BasePart }, { BasePart })
	local folder = model:FindFirstChild(M.FOLDER)
	local his, backup = {}, {}
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			if folder and d:IsDescendantOf(folder) then
				table.insert(backup, d)
			elseif d:IsA("MeshPart") then
				table.insert(his, d)
			end
		end
	end
	return his, backup
end

-- Shows the backup (true) or his model (false) on this screen.
function M.show(model: Instance, useBackup: boolean)
	local his, backup = M.partsOf(model)
	for _, p in his do
		local was = p:GetAttribute("HisTransparency")
		if useBackup then
			if was == nil then p:SetAttribute("HisTransparency", p.Transparency) end
			p.Transparency = 1
		elseif type(was) == "number" then
			p.Transparency = was
			p:SetAttribute("HisTransparency", nil)
		end
	end
	for _, p in backup do
		local shown = p:GetAttribute("Shown")
		p.Transparency = if useBackup then (if type(shown) == "number" then shown else 0) else 1
	end
	model:SetAttribute("ShowingBackup", useBackup or nil)
end

local function digits(id: any): string?
	return if type(id) == "string" then string.match(id, "%d%d%d%d+") else nil
end

-- A MeshPart's mesh as "rbxassetid://<n>" (its MeshId, else its MeshContent's), or nil.
function M.meshIdOf(p: Instance): string?
	local okId, id = pcall(function() return (p :: any).MeshId end)
	local d = okId and digits(id)
	if not d then
		local okC, c = pcall(function() return tostring((p :: any).MeshContent) end)
		d = okC and digits(c)
	end
	return if d then "rbxassetid://" .. d else nil
end

-- Loads one knife's meshes and picks what it shows. Yields (until Roblox answers for each mesh).
function M.check(model: Instance)
	local his = M.partsOf(model)
	local ids, list = {}, {}
	for _, p in his do
		local d = digits(M.meshIdOf(p))
		if d then
			if not ids[d] then table.insert(list, p) end
			ids[d] = true
		end
	end
	if #list == 0 then return end
	local done = false
	task.delay(M.WAIT, function()
		if not done and model.Parent then M.show(model, true) end
	end)
	local bad: string? = nil
	local ok, err = pcall(M.preload, list, function(contentId, status)
		local d = digits(contentId)
		local name = if typeof(status) == "EnumItem" then status.Name else tostring(status)
		if d and ids[d] and BAD[name] and not bad then bad = "rbxassetid://" .. d .. " " .. name end
	end)
	done = true
	if not ok then bad = "couldn't ask Roblox (" .. tostring(err) .. ")" end
	if not model.Parent then return end
	M.show(model, bad ~= nil)
	local key = tostring(model:GetAttribute("Backup"))
	if bad and not told[key] then
		told[key] = true
		M.say(`[HuzzKnife] {key}: his mesh {bad} didn't load here: showing the plain cut of his knife (docs/STUDIO-STEPS.md Part 6)`)
	end
end

function M.start()
	local Players = game:GetService("Players")
	local Workspace = game:GetService("Workspace")
	local busy: { [Instance]: boolean } = {} -- (a plain table: weak keys on Instances drop entries at random)
	local function consider(d: Instance)
		if not d:IsA("Model") or d:GetAttribute("Backup") == nil or busy[d] then return end
		busy[d] = true
		local again = false
		local function run()
			task.wait(M.SETTLE) -- (a knife can arrive a part at a time)
			again = false
			local ok, err = pcall(M.check, d)
			if not ok then warn("[Huzz] KnifeMeshCheck: " .. tostring(err)) end
		end
		task.spawn(run)
		d.DescendantAdded:Connect(function(x) -- (one of his parts that streams in later: checked again, once)
			if x:IsA("MeshPart") and not again and not x:FindFirstAncestor(M.FOLDER) then
				again = true
				task.spawn(run)
			end
		end)
		d.Destroying:Connect(function() busy[d] = nil end)
	end
	Workspace.DescendantAdded:Connect(consider)
	for _, d in Workspace:GetDescendants() do consider(d) end
	local gui = Players.LocalPlayer:WaitForChild("PlayerGui")
	gui.DescendantAdded:Connect(consider)
	for _, d in gui:GetDescendants() do consider(d) end
end

return M

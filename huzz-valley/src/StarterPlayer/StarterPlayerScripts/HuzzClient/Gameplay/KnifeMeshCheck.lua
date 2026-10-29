--[[
	Every knife shows in the live game (owner, Oct 20 15:13: "make it so that the knifes also appear inside of the
	actual roblox game"). His 30 imported knives are his uploaded meshes on an invisible Handle. Studio draws a mesh
	from its own copy right after his import; a live screen loads each from Roblox, and an upload Roblox hasn't
	finished or approved loads nothing, so that knife was simply gone. HuzzServer/KnifeService marks every copy of his
	knife that has a plain cut of his own .glb (the model's "Backup" attribute = its key; the cut's data stays on the
	server, ServerStorage/HuzzKnifeBackups). Here, on each screen, every such knife (in the Workspace: hands, backs,
	hips, stands; and in this player's PlayerGui: the 3D knife on a card, UI/ImageLoader) has its meshes loaded with
	ContentProvider:PreloadAsync:
	  * any of his meshes Failure or TimedOut: this screen asks for the cut's data once a knife (remote KnifeBackup,
	    HuzzServer/KnifeGlbService), builds the cut on that copy (Shared/KnifeCut: a Folder "KnifeBackup" welded to
	    his Handle) and hides his parts;
	  * no answer within WAIT seconds: the same meanwhile, and if his meshes then load the cut is removed and his parts
	    come back.
	So the cut's parts exist only on a screen that needs them, never replicated (Oct 20 evening, critic: carrying it
	hidden in every copy was up to 199 extra parts a knife on every screen). Only his mesh IDs count (a texture that
	doesn't load leaves the plain-coloured mesh, which still shows). Nothing changes where his meshes load (Studio,
	and live once Roblox has them). Output says once per knife "[HuzzKnife] <key>: his mesh ... didn't load here ...:
	showing the plain cut of his knife" (docs/STUDIO-STEPS.md Part 6 says what he does then). Never on screen.
	tools/preview/smoke_knife_backup.luau runs it (Roblox's loader and the remote swapped for stubs).
]]
local KnifeCut = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("KnifeCut"))

local M = {}

M.WAIT = 8 -- seconds before the backup shows while his meshes are still loading
M.SETTLE = 0.5 -- seconds after a knife arrives before its parts are gathered
M.FOLDER = KnifeCut.FOLDER
local BAD = { Failure = true, TimedOut = true }

-- ContentProvider:PreloadAsync (the smoke test swaps this): calls back (content id, Enum.AssetFetchStatus) per asset.
function M.preload(list: { Instance }, callback: (string, any) -> ())
	game:GetService("ContentProvider"):PreloadAsync(list, callback)
end

-- A knife's cut data (its baked rows) from the server, or nil (the smoke test swaps this).
function M.fetch(key: string): any
	local Net = require(game:GetService("ReplicatedStorage").Shared.Net)
	local remote = Net.get("KnifeBackup") :: RemoteFunction
	return remote:InvokeServer(key)
end

local cuts: { [string]: any } = {} -- [knife key] = its baked rows, asked once a knife
local asking: { [string]: boolean } = {}
local function cutOf(key: string): any
	while asking[key] do task.wait(0.1) end
	if cuts[key] == nil then
		asking[key] = true
		local ok, baked = pcall(M.fetch, key)
		asking[key] = nil
		if ok and type(baked) == "table" and type(baked.parts) == "table" then cuts[key] = baked end
	end
	return cuts[key]
end

local told: { [string]: boolean } = {}
M.say = function(text: string) warn(text) end -- (the smoke test listens here)

-- His parts and the cut's parts (when it's built) of one knife copy.
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

-- Shows the cut (true: built now, on this screen only) or his model (false: the cut removed). False when there's no
-- cut to show (his parts are left as they are). Can yield (the cut's data, once a knife).
function M.show(model: Instance, useBackup: boolean): boolean
	local his = M.partsOf(model)
	if useBackup and not model:FindFirstChild(M.FOLDER) then
		local key = model:GetAttribute("Backup")
		local baked = type(key) == "string" and cutOf(key)
		local handle = model:FindFirstChild("Handle", true)
		if not (baked and handle and handle:IsA("BasePart") and model.Parent) then return false end
		if model:FindFirstChild(M.FOLDER) then return true end -- (built meanwhile)
		KnifeCut.build(baked, model, handle, KnifeCut.turned(baked, handle, his))
	elseif not useBackup then
		local cut = model:FindFirstChild(M.FOLDER)
		if cut then cut:Destroy() end
	end
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
	model:SetAttribute("ShowingBackup", useBackup or nil)
	return true
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
	local done, final = false, nil
	task.delay(M.WAIT, function()
		if done or not model.Parent then return end
		M.show(model, true)
		if final == false and model.Parent then M.show(model, false) end -- (his meshes loaded while the cut was being built)
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
	final = bad ~= nil
	local shown = M.show(model, final)
	local key = tostring(model:GetAttribute("Backup"))
	if bad and not told[key] then
		told[key] = true
		M.say(`[HuzzKnife] {key}: his mesh {bad} didn't load here: ` .. (if shown then "showing the plain cut of his knife"
			else "and its plain cut couldn't be fetched") .. " (docs/STUDIO-STEPS.md Part 6)")
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

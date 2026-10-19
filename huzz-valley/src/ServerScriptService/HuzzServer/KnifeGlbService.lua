--[[
	Hands each screen the owner's .glb knife meshes it needs, one at a time (Gameplay/KnifeDress draws them with
	EditableMesh until his own import of the file is in ServerStorage/HuzzKnives). The meshes (the Game Pass knives
	and his 18 Halloween knives, owner Oct 19: "make it one to one") are about 3.3 MB of baked data
	(ServerStorage/HuzzKnifeGlb/<Key>_<n>, tools/knives/bake_pass_meshes.py): kept on the server, so a player only
	downloads the knives a screen actually shows, never the whole set at join.
	Remote KnifeGlb (Shared/Net): (key, n) -> that knife's n-th mesh table, or nil when it has no n-th (the client
	asks 1, 2, 3 ... until nil), or false past MAX_CALLS a minute a player (a full lobby of knives is about 300): ask
	again later. Arguments checked.
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local KnifeGlbService = {}
KnifeGlbService.MAX_CALLS = 900 -- a minute, a player
KnifeGlbService.MAX_MESHES = 64 -- a knife

local cache: { [string]: any } = {} -- [module name] = its mesh table (false: none)
local calls: { [Player]: { at: number, n: number } } = {}

-- The n-th baked mesh of a knife, or nil.
function KnifeGlbService.mesh(key: any, n: any)
	if type(key) ~= "string" or #key > 40 or not string.match(key, "^%w+$") then return nil end
	if type(n) ~= "number" or n % 1 ~= 0 or n < 1 or n > KnifeGlbService.MAX_MESHES then return nil end
	local name = key .. "_" .. n
	if cache[name] == nil then
		local folder = ServerStorage:FindFirstChild("HuzzKnifeGlb")
		local m = folder and folder:FindFirstChild(name)
		local ok, g = false, nil
		if m and m:IsA("ModuleScript") then ok, g = pcall(require, m) end
		cache[name] = if ok and type(g) == "table" then g else false
	end
	return cache[name] or nil
end

function KnifeGlbService.start()
	local Net = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Net"))
	local remote = Net.get("KnifeGlb") :: RemoteFunction
	remote.OnServerInvoke = function(player, key, n)
		local now = os.clock()
		local c = calls[player]
		if not c or now - c.at > 60 then
			c = { at = now, n = 0 }
			calls[player] = c
		end
		c.n += 1
		if c.n > KnifeGlbService.MAX_CALLS then return false end -- (false = "ask again later", never "no more")
		return KnifeGlbService.mesh(key, n)
	end
	Players.PlayerRemoving:Connect(function(player) calls[player] = nil end)
end

return KnifeGlbService

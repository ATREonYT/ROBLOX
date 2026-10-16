-- One place that names every remote. The server creates them; clients wait for them.
--   State          RemoteEvent     server -> client: the player's saved state (coins, gems, owned, settings)
--   GetState       RemoteFunction  client -> server: ask for the current state (on join)
--   SetSetting     RemoteFunction  client -> server: (key, value) -> ok, message
--   BuyWithCoins   RemoteFunction  client -> server: (productKey) -> ok, message (no coin items yet; validated anyway)
--   Action         RemoteFunction  client -> server: (verb, ...) -> ok, message (equip, favourite, claim; see ActionService)
--   Round          RemoteEvent     server -> client: (kind, data) round moments; its attributes are the round state
--                                  (Stage, EndsAt, Round, Phase, Goal, GirlName, GirlRarity, HolderId, Map; and while
--                                  voting VoteA, VoteB, VoteCountA, VoteCountB; see RoundService and MapVoteService)
--   Vote           RemoteEvent     client -> server: (mapName) the player's map vote; a new vote replaces the old one
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = {}

local SPEC = {
	State = "RemoteEvent",
	GetState = "RemoteFunction",
	SetSetting = "RemoteFunction",
	BuyWithCoins = "RemoteFunction",
	Action = "RemoteFunction",
	Round = "RemoteEvent",
	Vote = "RemoteEvent",
	Stab = "RemoteEvent",
	Huss = "RemoteEvent",
	Power = "RemoteEvent",
	Hero = "RemoteEvent",
}

local folder: Folder
if RunService:IsServer() then
	folder = ReplicatedStorage:FindFirstChild("Remotes") :: Folder
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "Remotes"
		folder.Parent = ReplicatedStorage
	end
	for name, class in SPEC do
		if not folder:FindFirstChild(name) then
			local r = Instance.new(class)
			r.Name = name
			r.Parent = folder
		end
	end
else
	folder = ReplicatedStorage:WaitForChild("Remotes") :: Folder
end

function Net.get(name: string): Instance
	assert(SPEC[name], "unknown remote " .. name)
	return folder:WaitForChild(name)
end

return Net

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
--   Dance          RemoteEvent     client -> server: (danceId?, startAt) the dance you started (nil = stopped) and its
--                                  start in server time; ActionService puts both on your character (HuzzDance,
--                                  HuzzDanceAt) so people who start the same dance nearby dance in step
--   Spin           RemoteFunction  client -> server: (count) spin the wheel 1, 5 or 10 times -> ok, result or why
--   SpinOpen       RemoteEvent     server -> client: open the Spin the Wheel screen (you used the wheel in the lobby)
--   Admin          RemoteEvent     client -> server: (verb, key) the owner's admin panel (GiveKnife / SpawnGirl / NextGirl);
--                                  server -> client: (ok, message, verb, key). Owner only, checked by AdminService
--   KnifeGlb       RemoteFunction  client -> server: (key, n) -> the n-th baked .glb mesh of a knife, nil when none,
--                                  false to ask again later (HuzzServer/KnifeGlbService, Gameplay/KnifeDress)
--   KnifeView      RemoteFunction  client -> server: (knife key) -> true when a copy of that knife's model is in the
--                                  player's PlayerGui > HuzzKnifeViews (UI/ImageLoader's last fallback for a knife card
--                                  it can't draw; HuzzServer/KnifeGlbService)
--   HeadLook       RemoteEvent     client -> server: (turn, tilt) where your head looks, whole degrees, ~5 a second
--                                  (Gameplay/HeadAim); HuzzServer/HeadLookService puts it on your character (HuzzLook)
--   Place          RemoteEvent     server -> client: (character, CFrame) move your own body there (HuzzServer/PlaceService,
--                                  Gameplay/PlaceSelf: the owner of a body moves it, so every screen agrees)
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
	Power = "RemoteEvent",
	Hero = "RemoteEvent",
	Dash = "RemoteEvent",
	Dance = "RemoteEvent",
	Lunge = "RemoteEvent",
	Spin = "RemoteFunction",
	SpinOpen = "RemoteEvent",
	Admin = "RemoteEvent",
	KnifeGlb = "RemoteFunction",
	KnifeView = "RemoteFunction",
	HeadLook = "RemoteEvent",
	Place = "RemoteEvent",
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

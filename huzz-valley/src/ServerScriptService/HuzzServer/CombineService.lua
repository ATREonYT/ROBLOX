--[[
	The owner's Combine machine (owner, Oct 20 14:57: "can you please anime this combine machine, add a combine sign
	over it, and make it so that you can take two of the same girl, and then it creates the same skin, but first in
	silver, then gold, and then diamond"). His model is Workspace > Combine > Combine_Machine (513 parts: shrine
	tiers, altar, arch); this never moves or rebuilds his parts (each screen animates them: Gameplay/CombineMachine).
	It adds, on his parts:
	  * the prompt (on his altar, E, 12 studs): it opens the Combine window on that screen (attribute HuzzOpens,
	    Gameplay/LobbyProps opens it, not in a round or a cutscene);
	  * the sign over his arch: COMBINE, white with a dark outline, and one line under it (a BillboardGui, readable
	    from anywhere in the lobby; Config/Combine.Sign);
	  * the tag HuzzCombine on his machine model (every screen finds it by that), and Atomic streaming on his
	    Combine model so all its parts arrive together (it is animated as a whole).
	The merge (ActionService "Combine" -> CombineService.combine): checked here, all of it: the save is loaded, you
	stand by the machine, you aren't in a round, one merge at a time and a short cooldown, and Shared/CombineRules
	(two of the SAME girl at the SAME grade, Diamond the top). The save changes in one write; every screen is told
	(the Combine remote: who, her model, from, to, when) so everyone near sees the merge on the machine; the answer
	goes back only once the save holding it is stored (DataService.saveAndWait), so the result never shows unsaved.
	His machine stood beside a lobby copy the game puts away: Shared/LobbyLayout moves it (whole) to the same place
	beside the lobby the game keeps (KEEP), before this looks for it.
]]
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config.Combine)
local CombineRules = require(ReplicatedStorage.Shared.CombineRules)
local Characters = require(ReplicatedStorage.Shared.Config.Characters)
local Net = require(ReplicatedStorage.Shared.Net)
local DataService = require(script.Parent.DataService)

local CombineService = {}

local machine: Model? = nil
local busy: { [Player]: boolean } = {}
local lastAt: { [Player]: number } = {}

-- His part by its name without the number on the end ("altar_base_103" -> "altar_base").
local function partNamed(model: Instance, base: string): BasePart?
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") and string.gsub(d.Name, "_%d+$", "") == base then return d end
	end
	return nil
end
CombineService.partNamed = partNamed

-- The top of his model (studs, world Y) and its middle.
local function topOf(model: Instance): (number, Vector3)
	local top, sum, n = -math.huge, Vector3.zero, 0
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			local p = d.CFrame.Position
			top = math.max(top, p.Y + d.Size.Y / 2)
			sum += p
			n += 1
		end
	end
	return top, if n > 0 then sum / n else Vector3.zero
end

local function sign(altar: BasePart, model: Instance)
	if altar:FindFirstChild("HuzzCombineSign") then return end
	local S = Config.Sign
	local top = topOf(model)
	local bb = Instance.new("BillboardGui")
	bb.Name = "HuzzCombineSign"
	bb.Size = UDim2.fromScale(S.Width, S.Height)
	bb.StudsOffsetWorldSpace = Vector3.new(0, top - altar.CFrame.Position.Y + S.Above + S.Height / 2, 0)
	bb.LightInfluence = 0
	bb.MaxDistance = S.MaxDistance
	bb.AlwaysOnTop = false
	bb.ResetOnSpawn = false
	local gotham = "rbxasset://fonts/families/GothamSSm.json"
	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.BackgroundTransparency = 1
	title.Size = UDim2.fromScale(1, 0.7)
	title.Text = S.Text
	title.TextScaled = true
	title.FontFace = Font.new(gotham, Enum.FontWeight.Heavy)
	title.TextColor3 = Color3.new(1, 1, 1)
	local outline = Instance.new("UIStroke")
	outline.Color = Color3.fromHex("0B0F24") -- (the game's dark outline, UI/Theme TitleStroke)
	outline.Thickness = 3
	outline.LineJoinMode = Enum.LineJoinMode.Round
	outline.Parent = title
	title.Parent = bb
	local sub = Instance.new("TextLabel")
	sub.Name = "Line"
	sub.BackgroundTransparency = 1
	sub.Position = UDim2.fromScale(0.08, 0.72)
	sub.Size = UDim2.fromScale(0.84, 0.26)
	sub.Text = S.Sub
	sub.TextScaled = true
	sub.FontFace = Font.new(gotham, Enum.FontWeight.Bold)
	sub.TextColor3 = Color3.fromHex("F3D9FF")
	local subOutline = outline:Clone()
	subOutline.Thickness = 2
	subOutline.Parent = sub
	sub.Parent = bb
	bb.Parent = altar
end

local function hook(model: Model)
	if machine == model then return end
	local altar = partNamed(model, "altar_base")
	if not altar then return end -- (not all of it here yet: looked for again)
	machine = model
	pcall(function() model:AddTag(Config.Tag) end)
	pcall(function()
		local holder = model.Parent
		if holder and holder:IsA("Model") then (holder :: any).ModelStreamingMode = Enum.ModelStreamingMode.Atomic end
		(model :: any).ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	end)
	if not altar:FindFirstChild("HuzzCombinePrompt") then
		local prompt = Instance.new("ProximityPrompt")
		prompt.Name = "HuzzCombinePrompt"
		prompt.ActionText = Config.Prompt.Text
		prompt.ObjectText = ""
		prompt.KeyboardKeyCode = Enum.KeyCode.E
		prompt.HoldDuration = 0
		prompt.MaxActivationDistance = Config.Prompt.Distance
		prompt.RequiresLineOfSight = false
		prompt:SetAttribute("HuzzOpens", "Combine") -- (Gameplay/LobbyProps opens the window: UI/Screens/Combine)
		prompt.Parent = altar
	end
	pcall(sign, altar, model)
	print("[Huzz] Combine machine found:", model:GetFullName())
end

-- His machine: the tagged model, else Workspace > Combine > Combine_Machine (or any model of that name).
local function find(): Model?
	local ok, tagged = pcall(function() return CollectionService:GetTagged(Config.Tag) end)
	for _, m in (if ok then tagged else {}) do
		if m:IsA("Model") and m:IsDescendantOf(workspace) then return m end
	end
	local folder = workspace:FindFirstChild(Config.Folder)
	local m = folder and folder:FindFirstChild(Config.Model)
	if not m then m = workspace:FindFirstChild(Config.Model, true) end
	return if m and m:IsA("Model") then m else nil
end

function CombineService.machine(): Model?
	if machine and machine:IsDescendantOf(workspace) then return machine end
	local m = find()
	if m then hook(m) end
	return if machine and machine:IsDescendantOf(workspace) then machine else nil
end

-- Where the merge happens (his altar), or nil.
function CombineService.altar(): BasePart?
	local m = CombineService.machine()
	return m and partNamed(m, "altar_base")
end

-- Her model's key in ReplicatedStorage.HuzzGirls (the screens draw her from it).
local function keyOf(id: string): string?
	local c = Characters.get(id)
	return c and c.Model
end

-- The merge. Returns true and { id, name, model, from, to, saved }, or false and a short reason.
function CombineService.combine(player: Player, id: any, grade: any): (boolean, any)
	if busy[player] then return false, "One at a time!" end
	if lastAt[player] and os.clock() - lastAt[player] < Config.Cooldown then return false, "Too fast." end
	if type(id) ~= "string" or not CombineRules.valid(grade) then return false, "Pick a girl first." end
	local role = player:GetAttribute("HuzzRole")
	if role == "Runner" or role == "Catcher" then return false, "Not during a round." end
	local altar = CombineService.altar()
	if not altar then return false, "The machine isn't here." end
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not (root and root:IsA("BasePart")) or (root.CFrame.Position - altar.CFrame.Position).Magnitude > Config.Reach then
		return false, "Walk up to the machine."
	end
	local key = keyOf(id)
	if not key then return false, "Unknown girl." end
	busy[player] = true
	local up, why, made = nil, "Your save is still loading.", 0
	local okWrite = pcall(function()
		DataService.update(player, function(data)
			up, why = CombineRules.apply(data, id, grade)
			made = tonumber(data.Combines) or 0
		end)
	end)
	if not okWrite or not up then
		busy[player] = nil
		return false, why or "Couldn't combine. Try again."
	end
	-- everyone near sees it on the machine (the one who merged plays it already)
	pcall(function()
		(Net.get("Combine") :: RemoteEvent):FireAllClients(player.UserId, key, grade, up, workspace:GetServerTimeNow())
	end)
	local saved = DataService.saveAndWait(player, function(d) return (tonumber(d.Combines) or 0) >= made end, Config.SaveWait)
	if not saved then warn(`[Huzz] Combine: {player.Name}'s merge isn't stored yet (it saves with the next save)`) end
	busy[player] = nil
	if player.Parent then lastAt[player] = os.clock() end -- (left during the save wait: don't keep their entry)
	local c = Characters.get(id)
	return true, { id = id, name = c and c.Name or id, model = key, from = grade, to = up, saved = saved }
end

function CombineService.start()
	Players.PlayerRemoving:Connect(function(p)
		busy[p], lastAt[p] = nil, nil
	end)
	-- his machine: found now, or when it arrives (the lobby move, a late load)
	task.spawn(function()
		for _ = 1, 120 do
			if CombineService.machine() then return end
			task.wait(1)
		end
		warn("[Huzz] Combine machine not found (Workspace > Combine > Combine_Machine)")
	end)
end

return CombineService

--[[
	The anime girls in the world, on this screen (owner's call: "make the anime girl characters feel more
	included"):
	  - Your equipped girl (the player's HuzzCompanion attribute, CompanionService) floats beside you as a small
	    companion in the lobby, bobbing and leaning as you move, with her effects (Shared/AuraLook "Companion").
	    In a round she steps aside (the round's own girl is the prize).
	  - Equip a Rare or better girl and YOU get her aura, in the lobby and in rounds (the owner's reference:
	    flames on your hands, dark wisps, crescent slashes as she gets rarer; "Player").
	  - The big girl over the map wears her aura at 3x ("Showcase", tag HuzzShowcase).
	  - The round's girl, carried or following a catcher, glows with her "Companion" look.
	Everyone's are drawn by every client (Gameplay/AuraFX), only near the camera.
]]
local M = {}

function M.start()
	local CollectionService = game:GetService("CollectionService")
	local Players = game:GetService("Players")
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local RunService = game:GetService("RunService")
	local Workspace = game:GetService("Workspace")

	local Shared = ReplicatedStorage:WaitForChild("Shared")
	local AuraLook = require(Shared.AuraLook)
	local Looks = require(Shared.Config.GirlLooks)
	local Round = require(Shared.Config.Round)
	local AuraFX = require(script.Parent.AuraFX)

	local NEAR = 170 -- studs from the camera: effects further away are switched off
	local COMPANION_HEIGHT = 2.8 -- studs tall, about half your height (owner: "a smaller character")

	local rarityColor = {}
	for _, r in Round.Rarities do
		rarityColor[r.Name] = r.Color
	end
	local function lookOf(id, rarity)
		return AuraLook.lookFor(Looks, id, rarityColor[rarity or ""])
	end

	local folder = Instance.new("Folder")
	folder.Name = "HuzzCompanions"
	folder.Parent = Workspace

	local function near(position)
		local cam = Workspace.CurrentCamera
		return cam ~= nil and (cam.CFrame.Position - position).Magnitude < NEAR
	end

	-- Players: their aura and their companion.
	local states = {} -- Player -> { key, auraFor, aura, companion = {model, handle, pos, offset, size} }
	local function clearAura(s)
		if s.aura then
			s.aura.destroy()
			s.aura, s.auraFor = nil, nil
		end
	end
	local function clearCompanion(s)
		if s.companion then
			s.companion.handle.destroy()
			s.companion.model:Destroy()
			s.companion = nil
		end
	end

	local function makeCompanion(key, rarity)
		local girls = ReplicatedStorage:FindFirstChild("HuzzGirls")
		local source = girls and girls:FindFirstChild(key)
		if not (source and source:IsA("Model")) then
			return nil
		end
		local model = source:Clone()
		model.Name = "Companion"
		for _, d in model:GetDescendants() do
			if d:IsA("BasePart") then
				d.Anchored, d.CanCollide, d.CanQuery, d.CanTouch, d.CastShadow = true, false, false, false, false
			end
		end
		local _, size = model:GetBoundingBox()
		model:ScaleTo(model:GetScale() * COMPANION_HEIGHT / math.max(size.Y, 1))
		local box, newSize = model:GetBoundingBox()
		local offset = box:ToObjectSpace(model:GetPivot()) -- her pivot from her centre
		model.Parent = folder
		local spec = AuraLook.build(lookOf(source:GetAttribute("Id"), rarity), rarity, "Companion")
		spec.scale = COMPANION_HEIGHT / 5
		return { model = model, handle = AuraFX.attach(model, spec), offset = offset, size = newSize, pos = nil, face = nil, lean = 0 }
	end

	local function stateOf(p)
		local s = states[p]
		if not s then
			s = {}
			states[p] = s
		end
		return s
	end

	local clock = 0
	local function updatePlayer(p, s, dt)
		local character = p.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local root = humanoid and humanoid.RootPart
		local key = p:GetAttribute("HuzzCompanion") or ""
		local rarity = p:GetAttribute("HuzzCompanionRarity") or ""
		local alive = root ~= nil and humanoid.Health > 0
		local girls = ReplicatedStorage:FindFirstChild("HuzzGirls")
		local source = girls and key ~= "" and girls:FindFirstChild(key)

		-- the aura on the player (Rare and up)
		local wantAura = alive and source ~= nil and (AuraLook.RANK[rarity] or 0) >= 3
		local auraFor = wantAura and (key .. "|" .. tostring(character)) or nil
		if s.auraFor ~= auraFor then
			clearAura(s)
			if auraFor then
				local spec = AuraLook.build(lookOf(source:GetAttribute("Id"), rarity), rarity, "Player")
				if spec then
					s.aura, s.auraFor = AuraFX.attach(character, spec), auraFor
				end
			end
		end
		if s.aura then
			s.aura.setEnabled(near(root.Position) and character:GetAttribute("DownedAt") == nil)
			s.aura.step(dt)
		end

		-- the companion beside them (not in a round)
		local role = p:GetAttribute("HuzzRole")
		local inRound = role == "Runner" or role == "Catcher"
		local wantCompanion = alive and source ~= nil and not inRound and near(root.Position)
		if s.companion and (not wantCompanion or s.key ~= key) then
			clearCompanion(s)
		end
		s.key = key
		if wantCompanion and not s.companion then
			s.companion = makeCompanion(key, rarity)
		end
		local c = s.companion
		if c then
			-- over your right shoulder, a little behind, bobbing; she eases after you and leans as you move
			local bob = math.sin(clock * 2.2 + p.UserId % 7) * 0.25
			local target = (root.CFrame * CFrame.new(2.4, 0.9 + bob, 1.8)).Position
			local k = 1 - math.exp(-dt * 6)
			local before = c.pos or target
			c.pos = before:Lerp(target, k)
			local vel = (c.pos - before) / math.max(dt, 1 / 240)
			local flat = Vector3.new(vel.X, 0, vel.Z)
			local look = root.CFrame.LookVector
			local face = if flat.Magnitude > 2 then flat.Unit else Vector3.new(look.X, 0, look.Z).Unit
			c.face = if c.face then c.face:Lerp(face, k).Unit else face
			c.lean += (math.clamp(flat.Magnitude * 1.2, 0, 16) - c.lean) * k
			local cf = CFrame.lookAt(c.pos, c.pos + c.face) * CFrame.Angles(-math.rad(c.lean), 0, math.sin(clock * 1.3) * 0.05)
			c.model:PivotTo(cf * c.offset)
			c.handle.step(dt)
		end
	end

	-- Girl models in the world: the showcase over the map, the round's girl carried or following.
	local worldAuras = {} -- Model -> handle
	local function watchModel(model, kind)
		if worldAuras[model] or not model:IsA("Model") then
			return
		end
		local rarity = model:GetAttribute("Rarity")
		local spec = AuraLook.build(lookOf(model:GetAttribute("Id"), rarity), rarity, kind)
		if not spec then
			return
		end
		if kind == "Companion" then
			spec.scale = 1 -- (full size: the round's girl)
		end
		worldAuras[model] = AuraFX.attach(model, spec)
		model.AncestryChanged:Connect(function()
			if not model:IsDescendantOf(Workspace) and worldAuras[model] then
				worldAuras[model].destroy()
				worldAuras[model] = nil
			end
		end)
	end
	local function showcaseAdded(model)
		task.defer(watchModel, model, "Showcase")
	end
	CollectionService:GetInstanceAddedSignal("HuzzShowcase"):Connect(showcaseAdded)
	for _, m in CollectionService:GetTagged("HuzzShowcase") do
		showcaseAdded(m)
	end
	for _, name in { "HuzzCarried", "HuzzFollowers" } do
		task.spawn(function()
			local f = Workspace:WaitForChild(name, 30)
			if f then
				f.ChildAdded:Connect(function(m)
					task.delay(0.2, watchModel, m, "Companion")
				end)
				for _, m in f:GetChildren() do
					watchModel(m, "Companion")
				end
			end
		end)
	end

	Players.PlayerRemoving:Connect(function(p)
		local s = states[p]
		if s then
			clearAura(s)
			clearCompanion(s)
			states[p] = nil
		end
	end)

	RunService.RenderStepped:Connect(function(dt)
		clock += dt
		for _, p in Players:GetPlayers() do
			updatePlayer(p, stateOf(p), dt)
		end
		for model, handle in worldAuras do
			if model.Parent then
				local pivot = model:GetPivot().Position
				handle.setEnabled(near(pivot) or model:HasTag("HuzzShowcase"))
				handle.step(dt)
			end
		end
	end)
end

return M

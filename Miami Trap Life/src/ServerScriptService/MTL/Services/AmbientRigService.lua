--!strict
-- Builds the neighbourhood's people once per server: every Config/Outfits entry used by Config/Ambient.People.Roles
-- becomes a full R15 rig (catalog hair, face, clothes, hats, chains, bags, real skin tones) in
-- ReplicatedStorage.MTL_AmbientRigs.<OutfitId>. Clients clone these (Controllers/AmbientPeople), so nothing is
-- built while you play and spawns never hitch. Players:CreateHumanoidModelFromDescription only works on the server,
-- which is why this one small piece lives here; everything else about ambient life is client-only.
-- A rig Alex puts in MTL_AmbientRigs by hand is kept as-is (that's how real art drops in), unless it has no
-- Humanoid/HumanoidRootPart. Nothing without both is ever published: full outfit -> colours only -> skipped.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Outfits = require(ReplicatedStorage.MTL.Config.Outfits)
local Ambient = require(ReplicatedStorage.MTL.Config.Ambient)

local AmbientRigService = {}

local function log(...)
	print("[MTL Ambient]", ...)
end

local function library(): Folder
	local lib = ReplicatedStorage:FindFirstChild("MTL_AmbientRigs")
	if not lib then
		local f = Instance.new("Folder")
		f.Name = "MTL_AmbientRigs"
		f.Parent = ReplicatedStorage
		lib = f
	end
	return lib :: Folder
end

-- A rig is only worth publishing if a client can puppet it: Humanoid + HumanoidRootPart (as PrimaryPart) + a Head.
function AmbientRigService.valid(model: Instance?): boolean
	if not model or not model:IsA("Model") then
		return false
	end
	local root = model:FindFirstChild("HumanoidRootPart")
	return model:FindFirstChildOfClass("Humanoid") ~= nil
		and root ~= nil
		and root:IsA("BasePart")
		and model:FindFirstChild("Head") ~= nil
end

local function make(desc: HumanoidDescription): Model?
	local ok, model = pcall(function()
		return Players:CreateHumanoidModelFromDescription(desc, Enum.HumanoidRigType.R15)
	end)
	desc:Destroy()
	if ok and AmbientRigService.valid(model) then
		return model
	end
	if ok and model then
		model:Destroy() -- came back without a Humanoid/root: never publish half a person
	end
	return nil
end

function AmbientRigService.build(id: string, outfit: any): Model?
	-- full outfit, then colours only (a bad catalog id must never cost us the person), then give up on this one
	local model = make(Outfits.description(outfit))
	if not model then
		warn("[MTL Ambient] outfit failed, building plain:", id)
		model = make(Outfits.description(outfit, true))
	end
	if not model then
		warn("[MTL Ambient] skipped, no usable rig:", id)
		return nil
	end
	model.Name = id
	for _, d in model:GetDescendants() do
		if d:IsA("BaseScript") then
			d:Destroy()
		elseif d:IsA("BasePart") then
			d.CanCollide = false
			d.CanQuery = false
			d.CanTouch = false
		end
	end
	local hum = model:FindFirstChildOfClass("Humanoid") :: Humanoid
	hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	hum.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	model.PrimaryPart = model:FindFirstChild("HumanoidRootPart") :: BasePart
	if outfit.Height and outfit.Height ~= 1 then
		pcall(function()
			model:ScaleTo(outfit.Height)
		end)
	end
	if not AmbientRigService.valid(model) then
		warn("[MTL Ambient] skipped, rig broke while scaling:", id)
		model:Destroy()
		return nil
	end
	model:SetAttribute("Role", outfit.Role)
	-- clients wait for this many descendants before cloning, so they never copy a half-replicated rig
	model:SetAttribute("Parts", #model:GetDescendants())
	return model
end

function AmbientRigService.init()
	local lib = library()
	task.spawn(function()
		local made, kept, failed = 0, 0, 0
		for _, id in Outfits.ambientIds(Ambient.People.Roles) do
			local existing = lib:FindFirstChild(id)
			if existing and AmbientRigService.valid(existing) then
				kept += 1
				continue
			elseif existing then
				warn("[MTL Ambient] replacing broken rig (no Humanoid/HumanoidRootPart):", id)
				existing:Destroy()
			end
			local m = AmbientRigService.build(id, Outfits.List[id])
			if m then
				m.Parent = lib
				made += 1
			else
				failed += 1
			end
			task.wait() -- spread the catalog loads out
		end
		lib:SetAttribute("Ready", true)
		log(("rigs ready: %d built, %d kept, %d failed"):format(made, kept, failed))
	end)
end

return AmbientRigService

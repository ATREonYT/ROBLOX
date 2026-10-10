-- The equipped gun as a Tool the character holds (GunService gives it; Shoot.client equips it on a range and
-- fires it). Built from GunModels so the held gun is the same model as the armory's:
--   GunTool.build(id) -> Tool   named after the gun (the hotbar shows it), attribute GunId, Handle = the model's
--                               grip root, every part
--                               welded to it, unanchored and massless; Grip puts the muzzle forward along the
--                               raised arm; attachments Muzzle (flash and tracer start, -Z out of the barrel)
--                               and Eject (where shell casings fly out); CanBeDropped false
--   GunTool.sync(player, id)    makes the player hold or carry exactly one gun tool of gun `id`: an up-to-date
--                               one is kept, a stale one is replaced in the same place (still in the hand if
--                               it was held); returns the tool
--   GunTool.find(player)        the player's gun tool (in the character or the backpack) or nil
--   GunTool.held(character)     the gun tool in the character's hand, or nil
--   GunTool.is(inst)            true for a gun tool (a Tool with a GunId attribute)
--   GunTool.grip(id), GunTool.scale(id)
local RS = game:GetService('ReplicatedStorage')

local GunTool = {}

local function models()
	local shared = RS:FindFirstChild('Shared')
	local folder = shared and shared:FindFirstChild('Models')
	local module = folder and folder:FindFirstChild('GunModels')
	if not module then return nil end
	local ok, m = pcall(require, module)
	return ok and type(m) == 'table' and m.build and m or nil
end

-- Scale 1 is sized for a Roblox hand (GunModels' contract).
function GunTool.scale(_id: string): number
	return 1
end

-- The Handle's offset from the hand's RightGripAttachment. The model's origin is the grip and its muzzle points
-- -Z, which the grip attachment already turns forward along a raised arm; this only seats the grip in the palm.
function GunTool.grip(_id: string): CFrame
	return CFrame.new(0, -0.1, 0.1)
end

function GunTool.build(id: string)
	local Guns = require(RS.Shared.Config.Guns)
	local M = models()
	local gun = Guns.ById[id] or Guns.ById[Guns.Starter]
	local tool = Instance.new('Tool')
	tool.Name = gun.Name
	tool.ToolTip = gun.Name .. '  (x' .. gun.Multiplier .. ' Power)'
	tool.CanBeDropped = false
	tool.RequiresHandle = true
	tool.ManualActivationOnly = true -- Shoot.client fires on its own input; Activated would double up shots
	tool.Grip = GunTool.grip(gun.Id)
	tool:SetAttribute('GunId', gun.Id)
	local scale = GunTool.scale(gun.Id)
	local handle
	if M then
		local model = M.weld(M.build(gun.Id, scale))
		handle = model.PrimaryPart
		for _, child in model:GetChildren() do child.Parent = tool end
		model:Destroy()
		if M.Images and M.Images[gun.Id] and M.Images[gun.Id] ~= '' then tool.TextureId = M.Images[gun.Id] end
	else
		-- No model library: a plain dark block, muzzle forward.
		handle = Instance.new('Part')
		handle.Name = 'Handle'
		handle.Size = Vector3.new(0.3, 0.5, 1.4)
		handle.Color = gun.Color
		handle.Parent = tool
	end
	for _, p in tool:GetDescendants() do
		if p:IsA('BasePart') then
			p.Anchored, p.CanCollide, p.CanTouch, p.CanQuery, p.Massless = false, false, false, false, true
		end
	end
	local meta = M and M.Meta and M.Meta[gun.Id]
	local muzzle = Instance.new('Attachment')
	muzzle.Name = 'Muzzle'
	muzzle.CFrame = CFrame.new((meta and meta.Muzzle or Vector3.new(0, 0.1, -0.7)) * scale)
	muzzle.Parent = handle
	local eject = Instance.new('Attachment')
	eject.Name = 'Eject'
	eject.CFrame = CFrame.new(Vector3.new(0.1, (meta and meta.Muzzle.Y or 0.3) * 0.9, -0.25) * scale)
	eject.Parent = handle
	return tool
end

function GunTool.is(inst)
	return inst ~= nil and inst:IsA('Tool') and inst:GetAttribute('GunId') ~= nil
end
local function firstGun(container)
	if not container then return nil end
	for _, child in container:GetChildren() do
		if GunTool.is(child) then return child end
	end
	return nil
end
function GunTool.held(character) return firstGun(character) end

function GunTool.find(player)
	return firstGun(player.Character) or firstGun(player:FindFirstChildOfClass('Backpack'))
end

function GunTool.sync(player, id: string)
	local pack = player:FindFirstChildOfClass('Backpack')
	local old = GunTool.find(player)
	if old and old:GetAttribute('GunId') == id then
		-- Drop any stray second gun (a respawn race), keep this one.
		for _, c in { player.Character, pack } do
			for _, child in (c and c:GetChildren() or {}) do if child ~= old and GunTool.is(child) then child:Destroy() end end
		end
		return old
	end
	local where = old and old.Parent or pack
	if not where then return nil end -- no backpack yet: CharacterAdded will call again
	local tool = GunTool.build(id)
	if old then old:Destroy() end
	tool.Parent = where -- (parenting to the character keeps it in the hand)
	return tool
end

return GunTool

-- (brief 29) The user's enemies (ServerStorage/HoodEnemies, imported as they are): real Roblox avatars in catalog
-- clothes, built by EnemyLooks.build through Players:CreateHumanoidModelFromDescriptionAsync. That is slow and async, so
-- each look is built ONCE per server, in a background task, into a hidden template cache that every client can see:
-- ReplicatedStorage.HoodEnemyModels (not in Workspace, so nothing shows or collides). Each player's goons are drawn on
-- their own screen (Waves.client), which clones a template per goon and animates it there (Shared/EnemyRig).
--   EnemyModels.forStage(stage)   EnemyLooks.forStage for our stage (EnemyRules.RosterStage), or nil without EnemyLooks
--   EnemyModels.keysOf(world)     every look key in the world's crews, stage 1 first (the order they are built in)
--   EnemyModels.start(keys)       builds them in the background; returns the folder
--   EnemyModels.make(key, build?) one template (or nil, why)
-- Fallback: a look that can't be built (no HTTP in Studio, the offline harness, a moderated item that left it bare: no
-- Shirt and no Pants) is simply not in the folder, and the client draws today's goon (Shared/GoonRig) instead. The
-- folder's attributes say how it went: Built, Failed, Done.
local RS = game:GetService('ReplicatedStorage')
local SS = game:GetService('ServerStorage')
local EnemyRules = require(RS.Shared.EnemyRules)

local EnemyModels = {}
EnemyModels.FolderName = 'HoodEnemyModels'
EnemyModels.Workers = 2 -- looks built at once
-- Our size for a look, over the roster's own (the user's files stay as they made them). (brief 30, FIGHTS: the reference's
-- strongest stage enemies are "the same size as the player (about 1.0-1.1x)": strength reads from the name, the HP
-- number and the brick bar, never from size; World 1's last, the Harbor crew's strongest, "at most 1.3-1.5x" (bible
-- 2.4). Was 1.5 from the roster for every crew's strongest and 2.2 for the Harbor's.)
EnemyModels.Scale = {
	bullies_boss = 1.15, crooks_boss = 1.15, ballers_boss = 1.15, little_boss = 1.15,
	gangsters_boss = 1.15, muscle_boss = 1.15, dockhands_boss = 1.15, harbor_boss = 1.4,
}

local cached -- EnemyLooks, or false when it is missing or fails to load
function EnemyModels.looks()
	if cached == nil then
		local folder = SS:FindFirstChild('HoodEnemies')
		local module = folder and folder:FindFirstChild('EnemyLooks')
		local ok, result = false, nil
		if module then ok, result = pcall(require, module) end
		cached = (ok and type(result) == 'table' and result.build and result.forStage) and result or false
	end
	return cached or nil
end

function EnemyModels.forStage(stage: number): any
	local looks = EnemyModels.looks()
	if not looks then return nil end
	local ok, who = pcall(looks.forStage, EnemyRules.RosterStage[stage] or stage)
	return ok and who or nil
end

function EnemyModels.keysOf(world: { [number]: { any } }): { string }
	local stages = {}
	for stage in world do table.insert(stages, stage) end
	table.sort(stages)
	local keys, seen = {}, {}
	for _, stage in stages do
		for _, e in world[stage] do
			if e.Look and not seen[e.Look] then
				seen[e.Look] = true
				table.insert(keys, e.Look)
			end
		end
	end
	return keys
end

function EnemyModels.folder(): Folder
	local folder = RS:FindFirstChild(EnemyModels.FolderName)
	if not folder then
		folder = Instance.new('Folder')
		folder.Name = EnemyModels.FolderName
		folder.Parent = RS
	end
	return folder
end

-- One template: built, checked (dressed: a Shirt or Pants), made inert (no scripts, nothing collides, touches or is hit
-- by rays), named by its key with its display name as an attribute. `build` stands in for EnemyLooks.build in tests.
function EnemyModels.make(key: string, build: any): (Model?, string?)
	local looks = EnemyModels.looks()
	build = build or (looks and looks.build)
	if not build then return nil, 'no EnemyLooks' end
	local ok, model = pcall(build, key)
	if not ok then return nil, tostring(model) end
	if typeof(model) ~= 'Instance' or not model:IsA('Model') then return nil, 'not a model' end
	local hum = model:FindFirstChildOfClass('Humanoid')
	local root = model:FindFirstChild('HumanoidRootPart')
	local dressed = model:FindFirstChildOfClass('Shirt') or model:FindFirstChildOfClass('Pants')
	if not hum or not root or not model:FindFirstChild('Head') or not dressed then
		model:Destroy()
		return nil, 'undressed'
	end
	for _, d in model:GetDescendants() do
		if d:IsA('BaseScript') then
			d:Destroy()
		elseif d:IsA('BasePart') then
			d.CanCollide, d.CanTouch, d.CanQuery = false, false, false
			d.Massless = true
		end
	end
	hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	pcall(function() hum.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff end)
	model:SetAttribute('DisplayName', model.Name)
	if EnemyModels.Scale[key] then pcall(function() model:ScaleTo(EnemyModels.Scale[key]) end) end
	model:SetAttribute('EnemyKey', key)
	model.Name = key
	return model
end

local started
function EnemyModels.start(keys: { string }): Folder
	local folder = EnemyModels.folder()
	if started then return folder end
	started = true
	local queue, built, failed, busy = table.clone(keys), 0, 0, 0
	folder:SetAttribute('Built', 0)
	folder:SetAttribute('Failed', 0)
	folder:SetAttribute('Done', false)
	local function worker()
		busy += 1
		while #queue > 0 do
			local key = table.remove(queue, 1)
			if not folder:FindFirstChild(key) then
				local model, why = EnemyModels.make(key)
				if model then
					model.Parent = folder
					built += 1
				else
					failed += 1
					if failed == 1 then warn(('[EnemyModels] %s not built (%s): today\'s goons stand in'):format(key, tostring(why))) end
				end
				folder:SetAttribute('Built', built)
				folder:SetAttribute('Failed', failed)
			end
		end
		busy -= 1
		if busy == 0 then folder:SetAttribute('Done', true) end
	end
	for _ = 1, EnemyModels.Workers do task.spawn(worker) end
	return folder
end

return EnemyModels

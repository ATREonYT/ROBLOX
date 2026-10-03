-- Client-side idle motion for map decor. Map builders tag a Model or part 'HoodMotion' and set:
--   Spin      degrees per second around its pivot's Y axis
--   Bob       studs up and down, with BobPeriod seconds per cycle (default 2)
--   Hue       seconds per full trip around the colour wheel (rainbow ropes, the dance floor)
-- Runs only on clients, only for things within 180 studs of the camera. Untagged things are never touched.
local CollectionService = game:GetService('CollectionService')
local RunService = game:GetService('RunService')

local TAG = 'HoodMotion'
local RANGE = 180
local items = {}
local count = 0

local function track(inst)
	if items[inst] or not (inst:IsA('Model') or inst:IsA('BasePart')) then return end
	count += 1
	local entry = { base = inst:GetPivot(), phase = (count % 7) * 0.37, parts = {} }
	if inst:GetAttribute('Hue') then
		local list = inst:IsA('BasePart') and { inst } or inst:GetDescendants()
		for _, p in list do
			if p:IsA('BasePart') then
				local h, s, v = p.Color:ToHSV()
				table.insert(entry.parts, { part = p, h = h, s = s, v = v })
			end
		end
	end
	items[inst] = entry
end

for _, inst in CollectionService:GetTagged(TAG) do track(inst) end
CollectionService:GetInstanceAddedSignal(TAG):Connect(track)
CollectionService:GetInstanceRemovedSignal(TAG):Connect(function(inst) items[inst] = nil end)

-- A skybox with a Spin attribute (degrees per second, set by HoodLighting) turns slowly: an "active" sky
-- at almost no cost.
local Lighting = game:GetService('Lighting')
local function skySpin(t)
	local sky = Lighting:FindFirstChildOfClass('Sky')
	local rate = sky and sky:GetAttribute('Spin')
	if rate then pcall(function() sky.SkyboxOrientation = Vector3.new(0, (t * rate) % 360, 0) end) end
end

RunService.PreRender:Connect(function()
	local camera = workspace.CurrentCamera
	if not camera then return end
	local eye = camera.CFrame.Position
	local t = os.clock()
	skySpin(t)
	for inst, e in items do
		if not inst.Parent then
			items[inst] = nil
			continue
		end
		if (e.base.Position - eye).Magnitude > RANGE then continue end
		local spin, bob = inst:GetAttribute('Spin'), inst:GetAttribute('Bob')
		if spin or bob then
			local y = bob and math.sin((t + e.phase) * 2 * math.pi / (inst:GetAttribute('BobPeriod') or 2)) * bob or 0
			inst:PivotTo(e.base * CFrame.new(0, y, 0) * CFrame.Angles(0, spin and math.rad(spin) * t or 0, 0))
		end
		local hue = inst:GetAttribute('Hue')
		if hue then
			for _, r in e.parts do r.part.Color = Color3.fromHSV((r.h + t / hue) % 1, r.s, r.v) end
		end
	end
end)

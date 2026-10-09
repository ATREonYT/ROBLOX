-- The world's floating labels fade with the distance (BRIEF20): near you they are big and clear, walking away they fade
-- and shrink a little, walking back they fade in with a small pop. The rules, the kinds and their bands are in
-- Shared/LabelFade; this finds the labels and drives it: a decision pass ten times a second (distances, FadeHold, the
-- lanes' declutter) and, every frame, only the labels that are moving or inside a band.
-- Labels: the active map's BillboardGuis named Label (a lane's stack, on its Sign), GunLabel and WorldLabel, and any
-- BillboardGui tagged HoodFadeLabel; never the stage gates' GateSign (HoodClient/Stages grows it with the distance).
-- They are found as the map streams in, and let go when they stream out.
local RS = game:GetService('ReplicatedStorage')
local RunService = game:GetService('RunService')
local CollectionService = game:GetService('CollectionService')
local ActiveMap = require(RS.Shared.ActiveMap)
local LabelFade = require(RS.Shared.LabelFade)

local active = ActiveMap.wait(20)
if not active then return end
local fader = LabelFade.new()

local function consider(x)
	if x:IsA('BillboardGui') then fader:add(x) end
end
for _, d in active.Root:GetDescendants() do consider(d) end
active.Root.DescendantAdded:Connect(consider)
active.Root.DescendantRemoving:Connect(function(x)
	if x:IsA('BillboardGui') then fader:remove(x, true) end
end)
-- (a label outside the map can opt in with the tag)
local function tagged(x)
	if x:IsA('BillboardGui') and x:IsDescendantOf(workspace) then fader:add(x) end
end
for _, x in CollectionService:GetTagged(LabelFade.Tag) do tagged(x) end
CollectionService:GetInstanceAddedSignal(LabelFade.Tag):Connect(tagged)

local DECIDE = 0.1
local since = DECIDE -- (the first frame decides at once)
local profile = debug and debug.profilebegin and debug.profileend -- (the MicroProfiler shows it as LabelFade)
RunService.Heartbeat:Connect(function(dt)
	local cam = workspace.CurrentCamera
	if not cam then return end
	if profile then debug.profilebegin('LabelFade') end
	dt = dt or 1 / 60
	since += dt
	local cf = cam.CFrame
	if since >= DECIDE then
		since = 0
		local vp = cam.ViewportSize
		local h = (vp and vp.Y > 100) and vp.Y or 720 -- (ViewportSize can read 1 x 1 for a frame at startup)
		fader:decide(cf, h / (2 * math.tan(math.rad(cam.FieldOfView) / 2)))
	end
	fader:step(math.min(dt, 0.1), cf)
	if profile then debug.profileend() end
end)

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
local TextStyle = require(RS.Shared.TextStyle)

local active = ActiveMap.wait(20)
if not active then return end
local fader = LabelFade.new()

-- (B31, rule 27) A floating word's drop shadow (the map's dropShadow: a dark twin with attribute ShadowOf = the word's
-- name, ShadowDX / ShadowDY its offset in the gui's scale) follows the word's text, visibility, place and size, so the
-- scripts that rewrite a word (prices, OWNED, Locked / Unlocked, the chips' icons) never leave its shadow behind.
local function linkShadow(sh)
	local name = sh:GetAttribute('ShadowOf')
	local src = name and sh.Parent and sh.Parent:FindFirstChild(name)
	if not (src and src:IsA('TextLabel')) or sh:GetAttribute('ShadowLinked') then return end
	sh:SetAttribute('ShadowLinked', true)
	local dx, dy = sh:GetAttribute('ShadowDX') or 0, sh:GetAttribute('ShadowDY') or 0
	local function copy()
		sh.Text, sh.Visible = src.Text, src.Visible
		sh.Position, sh.Size = src.Position + UDim2.fromScale(dx, dy), src.Size
		sh.TextXAlignment, sh.TextYAlignment = src.TextXAlignment, src.TextYAlignment
	end
	copy()
	for _, prop in { 'Text', 'Visible', 'Position', 'Size', 'TextXAlignment', 'TextYAlignment' } do
		src:GetPropertyChangedSignal(prop):Connect(copy)
	end
end
-- (Oct 28, the owner: "make the text ... match the UI more ... more cartoony") Every floating word and sign in the map
-- gets the UI's cartoon look (TextStyle.world: lit from the top, deeper at the foot, round outline joins), and a
-- floating word's outline grows with its size on screen (TextStyle.outlineFor), so a near sign has the UI's thick
-- outline and a far one stays crisp. Not the gates' GateSign (Stages grows it) and not the drop shadows.
local cartoon = {} -- { label, ... } floating words whose outline follows their size (dropped once gone)
local function styleWord(x)
	if x:GetAttribute('Cartoon') or x:GetAttribute('ShadowOf') then return end
	local bb = x:FindFirstAncestorOfClass('BillboardGui')
	if bb and bb.Name == 'GateSign' then return end
	if not (bb or x:FindFirstAncestorOfClass('SurfaceGui')) then return end
	TextStyle.world(x)
	if bb and x:FindFirstChildOfClass('UIStroke') then table.insert(cartoon, x) end
end
local function consider(x)
	if x:IsA('BillboardGui') then fader:add(x) end
	if x:IsA('TextLabel') and x.Parent then
		pcall(styleWord, x)
		if x:GetAttribute('ShadowOf') then linkShadow(x) end
		local twin = x.Parent:FindFirstChild(x.Name .. 'Shadow')
		if twin and twin:IsA('TextLabel') and twin:GetAttribute('ShadowOf') == x.Name then linkShadow(twin) end
	end
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
local OUTLINE_EVERY = 0.3
local warnedOutline = false
local outlineSince = 0
local function outlines()
	local i = 1
	while i <= #cartoon do
		local x = cartoon[i]
		if x.Parent == nil then
			cartoon[i] = cartoon[#cartoon]
			cartoon[#cartoon] = nil
		else
			i += 1
			local bb = x:FindFirstAncestorOfClass('BillboardGui')
			if bb and bb.Enabled and x.Visible then
				local h = x.AbsoluteSize.Y
				local okB, tb = pcall(function() return x.TextBounds end)
				if okB and typeof(tb) == 'Vector2' and tb.Y > 0 then h = math.min(h, tb.Y) else h *= 0.8 end
				local want = TextStyle.outlineFor(h)
				local st = x:FindFirstChildOfClass('UIStroke')
				if st and math.abs(st.Thickness - want) > 0.25 then
					st.Thickness = want
					local twin = x.Parent and x.Parent:FindFirstChild(x.Name .. 'Shadow')
					local ts = twin and twin:FindFirstChildOfClass('UIStroke')
					if ts then ts.Thickness = want end
				end
			end
		end
	end
end
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
	outlineSince += dt
	if outlineSince >= OUTLINE_EVERY then
		outlineSince = 0
		local ok, err = pcall(outlines)
		if not ok and not warnedOutline then warnedOutline = true; warn('[LabelFade] ' .. tostring(err)) end
	end
	if profile then debug.profileend() end
end)

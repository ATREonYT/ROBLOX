-- integ_waves (COMBAT, brief 18; STAGES, brief 23): the built map's stage crews and pads against the real gates and
-- streets (run after Build in the same snippet). Every goon's spot stands on open ground inside its stage (no solid part
-- at body height), far enough from the gate that the crew sees you come in; every hangout prop stands off the road and
-- clear of the map's own parts; no old target remains; the run's gate rule (a gate opens when the crew before it is
-- down this run; Power opens nothing); and (brief 23) the two pads of every stage: one Return and one 10x Cash pad per
-- stage 1..16 (before gates 2..16, and the boss yard's pair), tagged, with Stage/Kind, touchable, no prompt, on the
-- sidewalk inside their stage, room to stand on them, a fading label (FadeNear/FadeFar) in a game font, no goon on them.
local RS = game.ReplicatedStorage
local ActiveMap = require(RS.Shared.ActiveMap)
local StageRules = require(RS.Shared.StageRules)
local W = require(RS.Shared.WaveRules)
local E = require(RS.Shared.EnemyRules)
local a = ActiveMap.get()
local function tagged(tag) local r = {}; for _, d in a.Root:GetDescendants() do if d:HasTag(tag) then table.insert(r, d) end end; return r end
local gates = StageRules.fromModels(tagged('HoodStageGate'))
local world, arenas = E.world(gates)
local out = { gates = #gates, oldTargets = #tagged('HoodWaveTarget') }
local origin = require(game.ServerStorage.TheBlockV2).Origin.Position
local function box(p)
	local cf, s = p.CFrame, p.Size
	local x, y, z, r00, r01, r02, r10, r11, r12, r20, r21, r22 = cf:GetComponents()
	local hx = (math.abs(r00) * s.X + math.abs(r01) * s.Y + math.abs(r02) * s.Z) / 2
	local hy = (math.abs(r10) * s.X + math.abs(r11) * s.Y + math.abs(r12) * s.Z) / 2
	local hz = (math.abs(r20) * s.X + math.abs(r21) * s.Y + math.abs(r22) * s.Z) / 2
	local c = Vector3.new(x, y, z) - origin
	return c - Vector3.new(hx, hy, hz), c + Vector3.new(hx, hy, hz)
end
local waves = a.Root:FindFirstChild('Waves')
local solids = {}
for _, d in a.Root:GetDescendants() do
	if d:IsA('BasePart') and (not waves or not d:IsDescendantOf(waves)) and d.Transparency < 0.95 and d.CanCollide then
		local lo, hi = box(d)
		if hi.Z < 20 and lo.Z > -1070 and math.min(math.abs(lo.X), math.abs(hi.X)) < 40 and (hi - lo).Magnitude < 400 then table.insert(solids, { p = d, lo = lo, hi = hi }) end
	end
end
-- What stands in a box (map frame): solid parts overlapping it (touching is fine).
local function inBox(lo, hi)
	local hits = {}
	for _, o in solids do
		if o.lo.X < hi.X and o.hi.X > lo.X and o.lo.Y < hi.Y and o.hi.Y > lo.Y and o.lo.Z < hi.Z and o.hi.Z > lo.Z then hits[o.p.Name] = true end
	end
	local n = {}
	for k in hits do table.insert(n, k) end
	table.sort(n)
	return n
end
local counts, issues = {}, {}
for stage = 1, #gates do
	local list = world[stage] or {}
	table.insert(counts, #list)
	local g = gates[stage]
	for i, e in list do
		local zp = g.Z - e.Home.Z
		if stage < #gates and zp < 30 then table.insert(issues, ('S%d#%d too near its gate (z\' %.1f)'):format(stage, i, zp)) end
		if W.stageAt(gates, Vector3.new(e.Home.X, 3, e.Home.Z)) ~= stage then table.insert(issues, ('S%d#%d outside its stage'):format(stage, i)) end
		-- a goon's body: 2 x 4.5 x 1.5 studs (Bruisers and the Boss wider) standing on the street
		local k = E.Kinds[e.Kind]
		local hw = 1.0 * k.Scale
		local hits = inBox(Vector3.new(e.Home.X - hw, 0.75, e.Home.Z - hw * 0.7), Vector3.new(e.Home.X + hw, 0.75 + 4.5 * k.Scale, e.Home.Z + hw * 0.7))
		if #hits > 0 then table.insert(issues, ('S%d#%d %s at (%.1f, z\' %.1f) stands in %s'):format(stage, i, e.Kind, e.Home.X, zp, table.concat(hits, ','))) end
	end
end
out.counts = table.concat(counts, ' ')
out.issues = #issues > 0 and issues or 'none'
-- The hangouts: off the road, clear of the map's solid parts (shrunk a little: touching is fine).
local clashes, hangouts = {}, 0
for _, grp in (waves and waves:GetChildren() or {}) do
	local lo, hi = Vector3.new(math.huge, math.huge, math.huge), -Vector3.new(math.huge, math.huge, math.huge)
	for _, p in grp:GetDescendants() do
		if p:IsA('BasePart') and p.Transparency < 0.95 then local l, h = box(p); lo, hi = lo:Min(l), hi:Max(h) end
	end
	hangouts += 1
	if lo.X < math.huge then
		local road = grp.Name ~= 'BossThrone' and math.min(math.abs(lo.X), math.abs(hi.X)) < 9 and lo.X * hi.X > 0
		local hits = inBox(lo + Vector3.new(0.3, 0.15, 0.3), hi - Vector3.new(0.3, 0.1, 0.3))
		if road or #hits > 0 then table.insert(clashes, ('%s [x %.1f..%.1f z %.1f..%.1f]%s %s'):format(grp.Name, lo.X, hi.X, lo.Z, hi.Z, road and ' on the road' or '', table.concat(hits, ','))) end
	end
end
out.hangouts = hangouts
out.clashes = #clashes > 0 and clashes or 'none'
-- Walking down the street in a run whose crews are down up to stage c (Power has no say any more).
local function walk(c)
	local n, b = StageRules.check(gates, Vector3.new(0, 3, -520), StageRules.runStage(c, #gates), {})
	return #n .. ' passed, blocked by ' .. (b and b.Stage or 'none')
end
out.walk_run0 = walk(0)
out.walk_run3 = walk(3)
out.walk_run16 = walk(16)
-- The pads.
local padIssues, kinds = {}, {}
local pads = tagged('HoodStagePad')
out.pads = #pads
for _, pad in pads do
	local stage, kind = pad:GetAttribute('Stage'), pad:GetAttribute('Kind')
	local tag = tostring(pad.Name) .. '@' .. tostring(stage)
	if type(stage) ~= 'number' or (kind ~= 'Return' and kind ~= 'TenX') then table.insert(padIssues, tag .. ' bad Stage/Kind') continue end
	kinds[stage] = kinds[stage] or {}
	kinds[stage][kind] = (kinds[stage][kind] or 0) + 1
	if not pad:IsA('BasePart') or not pad.CanTouch or not pad.CanCollide then table.insert(padIssues, tag .. ' not a touchable solid slab') end
	if pad:FindFirstChildWhichIsA('ProximityPrompt', true) or pad:HasTag('HoodTeleport') then table.insert(padIssues, tag .. ' still has a prompt') end
	local lo, hi = box(pad)
	local c = (lo + hi) / 2
	if math.min(math.abs(lo.X), math.abs(hi.X)) < 8.5 and lo.X * hi.X > 0 then table.insert(padIssues, tag .. ' on the road') end
	if stage <= 15 and W.stageAt(gates, Vector3.new(c.X, 3, c.Z)) ~= nil and W.stageAt(gates, Vector3.new(0, 3, c.Z)) ~= stage then table.insert(padIssues, tag .. ' outside its stage') end
	if stage <= 15 then
		local nextGate = gates[stage + 1]
		if not nextGate or c.Z < nextGate.Z or c.Z - nextGate.Z > 20 then table.insert(padIssues, tag .. ' not just before gate ' .. (stage + 1)) end
	elseif W.stageAt(gates, Vector3.new(0, 3, c.Z)) ~= 16 then table.insert(padIssues, tag .. ' not in the boss yard') end
	-- (room to stand: nothing solid over the pad up to a character's height, but its own slab)
	local over = inBox(Vector3.new(lo.X + 0.3, hi.Y + 0.2, lo.Z + 0.3), Vector3.new(hi.X - 0.3, hi.Y + 5.5, hi.Z - 0.3))
	if #over > 0 then table.insert(padIssues, tag .. ' covered by ' .. table.concat(over, ',')) end
	-- no goon stands on it, and (stages 1-15) the crew waits mid-street, at least 6 studs short of its pads, so the pads
	-- show clear from the stage's entry
	for _, e in world[stage] or {} do
		if e.Home.X > lo.X - 1 and e.Home.X < hi.X + 1 and e.Home.Z > lo.Z - 1 and e.Home.Z < hi.Z + 1 then table.insert(padIssues, tag .. ' has a goon on it') end
		-- (brief 30, FIGHTS: the reference's wave idles 8-12 studs before the next gate, on the road between its two pads;
		-- was "at least 6 studs short of its pads") a goon never stands on a pad nor beside one on its sidewalk
		if stage <= 15 and math.abs(e.Home.X) > math.min(math.abs(lo.X), math.abs(hi.X)) - 1 and e.Home.X * c.X > 0 and e.Home.Z > lo.Z - 1 and e.Home.Z < hi.Z + 1 then table.insert(padIssues, tag .. ' crew stands beside it on its sidewalk') end
	end
	-- its label: a WorldLabel on <Name>Label next to it, fading with the distance, in the game font (Montserrat since brief 28)
	local anchor = pad.Parent and pad.Parent:FindFirstChild(pad.Name .. 'Label')
	local gui = anchor and anchor:FindFirstChild('WorldLabel')
	if not gui then
		table.insert(padIssues, tag .. ' has no label')
	else
		local near, far = gui:GetAttribute('FadeNear'), gui:GetAttribute('FadeFar')
		if type(near) ~= 'number' or type(far) ~= 'number' or far <= near or far < 60 then table.insert(padIssues, tag .. ' label has no fade band reaching the stage entry (FadeFar >= 60)') end
		for _, n in { 'Title', 'Sub', 'Price' } do
			local t = gui:FindFirstChild(n)
			if not t or not string.find(t.FontFace.Family, 'Montserrat', 1, true) then table.insert(padIssues, tag .. ' label ' .. n .. ' missing or not the game font (Montserrat, brief 28)') end
		end
		local title = gui:FindFirstChild('Title')
		if title and not string.find(title.Text, 'Cash', 1, true) then table.insert(padIssues, tag .. ' label reads "' .. title.Text .. '"') end
	end
end
for stage = 1, #gates do
	local k = kinds[stage] or {}
	if k.Return ~= 1 or k.TenX ~= 1 then table.insert(padIssues, ('stage %d has %d Return / %d TenX pads'):format(stage, k.Return or 0, k.TenX or 0)) end
end
out.padIssues = #padIssues > 0 and padIssues or 'none'
-- No gate keeps a teleport prompt (only an older map's lobby pad may, until it is removed).
local gatePrompts = 0
for _, m in tagged('HoodStageGate') do for _, d in m:GetDescendants() do if d:IsA('ProximityPrompt') then gatePrompts += 1 end end end
out.gatePrompts = gatePrompts
-- The sign: guidance only ("Recommended / Power: N"; brief 30: in the sign's own Montserrat, like the reference).
local signs = 0
for _, m in tagged('HoodStageGate') do
	local sign = m:FindFirstChild('GateSign', true)
	local power = sign and sign:FindFirstChild('Power')
	if power and string.find(power.Text, '^Power: %d') and string.find(power.FontFace.Family, 'Montserrat', 1, true) then signs += 1 end
end
out.signsWithPower = signs
-- (brief 28) The world reads in one font: every gate sign's Title, Sub and Status in Montserrat (only Power: pixels).
local fontIssues = {}
for _, m in tagged('HoodStageGate') do
	local sign = m:FindFirstChild('GateSign', true)
	for _, n in { 'Title', 'Sub', 'Status' } do
		local t = sign and sign:FindFirstChild(n)
		if not t or not string.find(t.FontFace.Family, 'Montserrat', 1, true) then table.insert(fontIssues, tostring(m:GetAttribute('Stage')) .. ' ' .. n .. ' ' .. (t and t.FontFace.Family or 'missing')) end
	end
end
out.signFonts = #fontIssues > 0 and (#fontIssues .. ': ' .. table.concat(fontIssues, ', ', 1, math.min(4, #fontIssues))) or 'Montserrat'
return out

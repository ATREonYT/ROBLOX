---------------------------------------------------------------------------------------------- z-fighting
-- (P3, BRIEF29, the user: "fix the studs appearing and disappearing, make it all the same, also remove the overlays between
-- objects") Two blocks whose faces lie in the same plane, look the same way and overlap flicker against each other (and a
-- studded face flickers its studs). The builders stack parts freely (a wall piece butting into a pillar, a neon strip laid on a
-- channel, a trim over a body), so one pass after the build finds every such pair among the axis-aligned visible blocks and
-- lifts the smaller part's face out by 0.03 (twice that over a third part), so exactly one surface wins: the detail
-- over the body, never the reverse. Faces looking down are never seen and are left alone; a transparent part is not a surface.
local FIGHT_STEP, FIGHT_MIN = 0.03, 0.05
local function resolveCoplanar(root)
	local faces, byKey, parts = {}, {}, {}
	local order = 0
	local function key(a, d, plane) return a * 4 + d + 1, math.floor(plane * 100 + 0.5) end
	for _, p in root:GetDescendants() do
		if p.ClassName == 'Part' and p.Shape == Enum.PartType.Block and p.Transparency < 0.9 then
			local x, y, z, r00, r01, r02, r10, r11, r12, r20, r21, r22 = p.CFrame:GetComponents()
			local R = { { r00, r01, r02 }, { r10, r11, r12 }, { r20, r21, r22 } }
			local aligned = true
			for _, row in R do
				for _, v in row do
					local m = math.abs(v)
					if m > 0.001 and m < 0.999 then aligned = false end
				end
			end
			if aligned then
				local sz = p.Size
				local S = { sz.X, sz.Y, sz.Z }
				local c = { x, y, z }
				local h = {}
				local local_of = {}
				for a = 1, 3 do
					h[a] = (math.abs(R[a][1]) * S[1] + math.abs(R[a][2]) * S[2] + math.abs(R[a][3]) * S[3]) / 2
					for i = 1, 3 do if math.abs(R[a][i]) > 0.5 then local_of[a] = i end end
				end
				local vol = S[1] * S[2] * S[3]
				order += 1
				parts[p] = { vol = vol, local_of = local_of, idx = order }
				for a = 1, 3 do
					local o1, o2 = a % 3 + 1, (a + 1) % 3 + 1
					for _, d in { 1, -1 } do
						local plane = c[a] + d * h[a]
						if not (a == 2 and d == -1) then
							local f = { p = p, a = a, d = d, plane = plane, lo1 = c[o1] - h[o1], hi1 = c[o1] + h[o1], lo2 = c[o2] - h[o2], hi2 = c[o2] + h[o2], vol = vol }
							table.insert(faces, f)
							local kk, kp = key(a, d, plane)
							byKey[kk] = byKey[kk] or {}
							byKey[kk][kp] = byKey[kk][kp] or {}
							table.insert(byKey[kk][kp], f)
						end
					end
				end
			end
		end
	end
	-- the overlapping coplanar pairs: (a, d, plane +- 0.01) buckets, the smaller part lifts over the bigger
	local pairsList = {}
	for _, f in faces do
		local kk, kp = key(f.a, f.d, f.plane)
		for dk = -1, 1 do
			for _, g in (byKey[kk] and byKey[kk][kp + dk]) or {} do
				if g.p ~= f.p and f.vol > g.vol + 1e-6 then
					if math.abs(f.plane - g.plane) < 0.011 then
						local w = math.min(f.hi1, g.hi1) - math.max(f.lo1, g.lo1)
						local h = math.min(f.hi2, g.hi2) - math.max(f.lo2, g.lo2)
						if w > FIGHT_MIN and h > FIGHT_MIN then table.insert(pairsList, { big = f, small = g }) end
					end
				end
			end
		end
	end
	-- equal volumes: the pair is seen from both sides above and kept once (f.vol > g.vol is strict), so equals are lifted below
	for _, f in faces do
		local kk, kp = key(f.a, f.d, f.plane)
		for dk = -1, 1 do
			for _, g in (byKey[kk] and byKey[kk][kp + dk]) or {} do
				if g.p ~= f.p and math.abs(f.vol - g.vol) < 1e-6 and parts[f.p].idx < parts[g.p].idx and math.abs(f.plane - g.plane) < 0.011 then
					local w = math.min(f.hi1, g.hi1) - math.max(f.lo1, g.lo1)
					local h = math.min(f.hi2, g.hi2) - math.max(f.lo2, g.lo2)
					if w > FIGHT_MIN and h > FIGHT_MIN then table.insert(pairsList, { big = f, small = g }) end
				end
			end
		end
	end
	table.sort(pairsList, function(a, b) return a.big.vol > b.big.vol end)
	local lift = {} -- [face] = how far this face lifts
	for _ = 1, 4 do
		local changed = false
		for _, pr in pairsList do
			local need = (lift[pr.big] or 0) + FIGHT_STEP
			if (lift[pr.small] or 0) < need then lift[pr.small] = need changed = true end
		end
		if not changed then break end
	end
	local count = 0
	for f, amount in lift do
		local info = parts[f.p]
		local i = info.local_of[f.a]
		if i then
			local sz = f.p.Size
			local comp = { sz.X, sz.Y, sz.Z }
			comp[i] += amount
			local shift = Vector3.zero
			if f.a == 1 then shift = Vector3.new(f.d * amount / 2, 0, 0) elseif f.a == 2 then shift = Vector3.new(0, f.d * amount / 2, 0) else shift = Vector3.new(0, 0, f.d * amount / 2) end
			f.p.Size = Vector3.new(comp[1], comp[2], comp[3])
			f.p.CFrame = f.p.CFrame + shift
			count += 1
		end
	end
	return count, #pairsList
end
V2.ResolveCoplanar = resolveCoplanar

---------------------------------------------------------------------------------------------- build
-- The warehouse lobby's builder; V2.Lobby.Slots (name -> CFrame in the map frame) is filled by Build.
V2.Lobby = Lobby
function V2.Build()
	local skins = require(ReplicatedStorage.Shared.Config.Skins)
	SKINS = skins
	Props = require(game:GetService('ServerStorage').HoodProps)
	PROPS_KIT = { studs = studs, decor = decor, ghost = ghost, light = light, surface = surface, line = line, billboard = billboard, compact = compact, FONT = FONT }

	local old = workspace:FindFirstChild('TheBlockV2')
	if old then
		local backup = Instance.new('Folder')
		backup.Name = 'TheBlockV2_Before_' .. os.date('!%Y%m%d_%H%M%S')
		backup.Parent = game:GetService('ServerStorage')
		old.Parent = backup
	end
	local root = Instance.new('Model')
	root.Name = 'TheBlockV2'
	root:SetAttribute('BuildVersion', 'Hood Evolution W1 LOBBY6 VIP lanes, full armory side')
	root:SetAttribute('Origin', V2.Origin.Position)
	root:SetAttribute('LobbySpawn', Lobby.SpawnAt or SPAWN) -- (B31 PLAZA: on the south walk, the crossing just ahead)
	root:SetAttribute('LobbySpawnYaw', 0) -- facing north up the spine to the Stage 1 door (StageService's Lobby pads land you so)
	root:SetAttribute('MorphStand', false) -- no Morphs stands in the world any more: looks are equipped from the HUD's EVOLVE menu
	local ctx = newCtx(root, CFrame.new())

	buildGround(ctx)
	buildSpawn(ctx, skins)
	Look.apply(root) -- (B31 LOOK) the toy-plastic finish over the lobby: faint studs on the ground only, warm palette
	buildStages(ctx)
	if Waves then Waves.build(ctx) end -- each stage's target wave (f3_waves, MECHANICS)

	local lifted, fights = resolveCoplanar(root)
	for _ = 1, 2 do lifted += resolveCoplanar(root) end -- (a lift can land on a third part's plane: more passes settle the chains)
	root:SetAttribute('FaceFightsLifted', lifted)
	root.Parent = workspace
	local count = 0
	for _, d in root:GetDescendants() do if d:IsA('BasePart') then count += 1 end end
	pcall(function() game:GetService('ChangeHistoryService'):SetWaypoint('TheBlockV2 built') end)
	pcall(function() require(game:GetService('ServerStorage').HoodLighting).Apply(Look.Lighting[Look.Variant] or 'HoodSun') end) -- (B31: HoodToy, a real sun with shadows)
	V2.SetActive(true)
	print(string.format('[TheBlockV2] Built %d parts at %s. Press Play to spawn in the hood; select TheBlockV2 and press F to fly there.', count, tostring(V2.Origin.Position)))
	return { parts = count }
end

return V2

-- The anime girls' effects (Gameplay/AuraFX from Shared/AuraLook) build, play and clean up on a stand-in rig;
-- they grow with rarity (owner: "not so strong on commons, rares, epics, just little"); and the companion walks
-- on the ground behind you (Shared/FollowMotion with Config/GirlMotion.Companion; owner: "walk behind you, not fly").
-- Run from tools/preview: lune run harness.luau ../../src - "$(cat check_girl_fx.luau)" setup_ui.luau
local RS = game:GetService("ReplicatedStorage")
local AuraLook = require(RS.Shared.AuraLook)
local Looks = require(RS.Shared.Config.GirlLooks)
local FollowMotion = require(RS.Shared.FollowMotion)
local Companion = require(RS.Shared.Config.GirlMotion).Companion
local AuraFX = require(game.StarterPlayer.StarterPlayerScripts.HuzzClient.Gameplay.AuraFX)
local ok, failed = 0, 0
local function check(name, c) if c then ok += 1 else failed += 1; print("FAIL " .. name) end end
local function rig()
	local m = Instance.new("Model")
	for _, n in { "HumanoidRootPart", "UpperTorso", "Head", "RightHand", "LeftHand" } do
		local p = Instance.new("Part"); p.Name = n; p.Size = Vector3.new(1, 1, 1); p.Parent = m
	end
	m.Parent = workspace
	return m
end
for _, kind in { "Player", "Companion", "Showcase" } do
	for _, case in { { "CAC_R6_ixKatsu_358858", "Mythic" }, { "CAC_R6_GoodwinDakota422_AA2072", "Epic" }, { "nobody", "Secret" }, { "nobody", "Common" }, { "CAC_R6_GoodwinDakota422_AA2072", "Rare" } } do
		local spec = AuraLook.build(AuraLook.lookFor(Looks, case[1], Color3.new(1, 0, 0)), case[2], kind)
		local m = rig()
		local okAttach, handle = pcall(AuraFX.attach, m, spec)
		check(kind .. " " .. case[2] .. " builds", okAttach)
		if okAttach then
			local okStep, err = pcall(function() for _ = 1, 60 do handle.step(1 / 30) end end)
			check(kind .. " " .. case[2] .. " steps: " .. tostring(err), okStep)
			local emitters = 0
			for _, d in m:GetDescendants() do if d:IsA("ParticleEmitter") then emitters += 1 end end
			check(kind .. " " .. case[2] .. " has emitters", emitters >= 1)
			handle.setEnabled(false)
			handle.destroy()
			local left = 0
			for _, d in m:GetDescendants() do if d.Name:find("HuzzAura") or d.Name:find("HuzzSlash") or d.Name:find("HuzzOrb") then left += 1 end end
			check(kind .. " cleans up", left == 0)
		end
	end
end

-- The auras you wear (Shop: Blossom Aura; the girls' rewards): build, step (orbs circle, beats burst), clean up.
-- Before the owner uploads our pictures, the flat shapes (magic circle, rings, halo) and the lightning stay off.
do
	local m = rig()
	local handle = AuraFX.attach(m, AuraLook.worn("AuraSecret"))
	local flat = 0
	for _, d in m:GetDescendants() do
		if d:IsA("ParticleEmitter") and (d.Orientation == Enum.ParticleOrientation.VelocityPerpendicular or d.Name == "Crackle") then flat += 1 end
	end
	check("before the upload: no stand-in blobs for circles, rings or lightning", flat == 0)
	handle.destroy()
end
local ImageIds = require(RS.Shared.Config.ImageIds)
for _, name in { "Sigil", "RingSoft", "RingHard", "Bolt", "Streak" } do ImageIds["Fx/" .. name] = "1" end -- (as if uploaded)
for _, key in { "BlossomAura", "AuraLegend", "AuraMythic", "AuraSecret" } do
	local spec = AuraLook.worn(key)
	check(key .. " has a look", spec ~= nil)
	local m = rig()
	local okAttach, handle = pcall(AuraFX.attach, m, spec)
	check(key .. " builds", okAttach)
	if okAttach then
		local okStep, err = pcall(function() for _ = 1, 120 do handle.step(1 / 30) end end)
		check(key .. " steps: " .. tostring(err), okStep)
		local orbs, flat = 0, 0
		for _, d in m:GetDescendants() do
			if d:IsA("Trail") then orbs += 1 end
			if d:IsA("ParticleEmitter") and d.Orientation == Enum.ParticleOrientation.VelocityPerpendicular then flat += 1 end
		end
		check(key .. " orbs match the look", orbs == (if spec.orbs then spec.orbs.count else 0))
		check(key .. " flat layers lie flat", flat >= (if key == "AuraSecret" or key == "AuraMythic" then 2 else 1))
		handle.destroy()
		local left = 0
		for _, d in m:GetDescendants() do if d.Name:find("HuzzAura") or d.Name:find("HuzzSlash") or d.Name:find("HuzzOrb") then left += 1 end end
		check(key .. " cleans up", left == 0)
	end
end
for _, name in { "Sigil", "RingSoft", "RingHard", "Bolt", "Streak" } do ImageIds["Fx/" .. name] = nil end
check("an unknown worn aura draws nothing", AuraLook.worn("Nope") == nil)

-- The rarity ladder, for every element (and a girl with no look set).
local RARITIES = { "Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythic", "Secret" }
local looks = { AuraLook.lookFor(Looks, "nobody", Color3.new(1, 0.4, 0.2)) }
local seen = {}
for _, look in Looks do
	if not seen[look.Element] then
		seen[look.Element] = true
		table.insert(looks, look)
	end
end
local function has(spec, prefix)
	for _, e in spec.emitters do
		if string.sub(e.name, 1, #prefix) == prefix then return e end
	end
	return nil
end
local function total(spec)
	local r = 0
	for _, e in spec.emitters do r += e.rate end
	return r
end
local function biggest(spec)
	local s = 0
	for _, e in spec.emitters do for _, k in e.size do s = math.max(s, k[2]) end end
	return s
end
for _, look in looks do
	for _, kind in { "Player", "Companion" } do
		local tag = `{kind} {look.Element}`
		local last = -1
		for rank, rarity in RARITIES do
			local spec = AuraLook.build(look, rarity, kind)
			local rate = total(spec)
			check(`{tag} {rarity}: more than {RARITIES[rank - 1] or "nothing"} ({last} -> {rate})`, rate > last)
			last = rate
			check(`{tag} {rarity}: no slashes below Legendary`, rank >= 5 or spec.slashes == nil)
			check(`{tag} {rarity}: no hand flames below Epic`, rank >= 4 or has(spec, "Flame") == nil)
			check(`{tag} {rarity}: no wisps or shards below Legendary`, rank >= 5 or (has(spec, "Wisp") == nil and has(spec, "Shard") == nil))
			if rank <= 2 then
				check(`{tag} {rarity}: something, but tiny`, #spec.emitters >= 1 and rate <= 4 and biggest(spec) <= 0.35 and spec.light == nil)
				for _, e in spec.emitters do
					check(`{tag} {rarity}: {e.name} mostly see-through`, e.alpha[1][2] >= 0.4)
				end
			elseif rank == 3 then
				check(`{tag} Rare: soft (a few motes, a faint glow)`, rate <= 9 and spec.light ~= nil and spec.light.brightness <= 0.5)
			elseif rank == 4 then
				local flame = has(spec, "Flame")
				check(`{tag} Epic: small soft hand flames, no white cores`, flame ~= nil and flame.rate <= 10 and flame.alpha[1][2] >= 0.5 and has(spec, "Core") == nil)
				check(`{tag} Epic: small flames`, flame ~= nil and flame.size[2][2] <= 1.2)
			end
		end
	end
	local leg = AuraLook.build(look, "Legendary", "Player")
	check(`Player {look.Element} Legendary: hand flames, wisps, gentle slashes`, has(leg, "Flame") ~= nil and has(leg, "Wisp") ~= nil and leg.slashes ~= nil and leg.slashes.rate <= 1)
	local myth = AuraLook.build(look, "Mythic", "Player")
	check(`Player {look.Element} Mythic: the full look`, myth.slashes ~= nil and myth.slashes.rate >= 2 and has(myth, "Core") ~= nil)
	check(`Showcase {look.Element}: slashes capped at 1 a second`, AuraLook.build(look, "Secret", "Showcase").slashes.rate <= 1)
end
-- kid-safe: slashes fade in (never pop)
local _, _, _, _, _, _, _, alpha0 = AuraLook.slash(AuraLook.build(looks[1], "Mythic", "Player").slashes, 1, 0, Vector3.zero, 1)
check("slashes start invisible (fade in)", alpha0 >= 0.99)

-- The companion walks on the ground behind you.
do
	local root = Instance.new("Part")
	root.Parent = workspace
	local ROOT_H = 1.4
	local rec = FollowMotion.new({ root = root, motors = {}, rootHeight = ROOT_H, seed = 3, config = Companion })
	local leader = Vector3.new(0, 3, 0)
	local dt, t = 1 / 60, 0
	local onGround, maxGap, behind, rose = true, 0, true, false
	local function run(seconds, speed, check2)
		for _ = 1, math.floor(seconds / dt) do
			t += dt
			leader += Vector3.new(0, 0, -speed * dt) -- running toward -Z (forward)
			local cf = CFrame.new(leader)
			FollowMotion.step(rec, dt, t, cf, function() return 0 end, leader + Vector3.new(0, 1.5, 0))
			if check2 then check2(cf) end
		end
	end
	local function watch(cf)
		local y = root.CFrame.Position.Y
		if not rec.cheer and math.abs(y - ROOT_H) > 0.05 then onGround = false end
		local spot = (cf * CFrame.new(Companion.Offset)).Position
		local p = root.CFrame.Position
		maxGap = math.max(maxGap, (Vector3.new(p.X, 0, p.Z) - Vector3.new(spot.X, 0, spot.Z)).Magnitude)
	end
	run(0.5, 0, watch)
	run(3, 8, watch)
	check(`companion walks at your speed ({rec.speed} vs 8)`, math.abs(rec.speed - 8) < 1)
	run(3, 24, watch)
	check(`companion runs at your speed ({rec.speed} vs 24)`, math.abs(rec.speed - 24) < 2.5)
	local rel = CFrame.new(leader):PointToObjectSpace(root.CFrame.Position)
	behind = rel.Z > 2 and rel.Z < 10
	check(`companion is behind you while running (z = {rel.Z})`, behind)
	run(2, 0, watch)
	check(`companion stops when you stop ({rec.speed})`, rec.speed < 0.5)
	local still = CFrame.new(leader):PointToObjectSpace(root.CFrame.Position)
	check(`companion settles at her spot behind you ({still})`, (Vector3.new(still.X, 0, still.Z) - Companion.Offset).Magnitude < 1.2)
	check("companion feet stay on the ground", onGround)
	check(`companion never more than MaxLag from her spot ({maxGap})`, maxGap <= Companion.MaxLag + 0.01)
	-- a teleport (or a respawn) and she's straight back behind you
	leader += Vector3.new(120, 0, 0)
	run(dt, 0)
	local spot = (CFrame.new(leader) * CFrame.new(Companion.Offset)).Position
	check("companion pops back to you after a teleport", (Vector3.new(root.CFrame.Position.X, 0, root.CFrame.Position.Z) - Vector3.new(spot.X, 0, spot.Z)).Magnitude < 1)
	-- cheering: little hops that always land back on the ground
	rec.cheer = true
	local lowest, highest = math.huge, -math.huge
	run(2, 0, function()
		local y = root.CFrame.Position.Y
		lowest, highest = math.min(lowest, y), math.max(highest, y)
	end)
	rose = highest > ROOT_H + 0.2
	check(`companion hops when she cheers ({lowest} - {highest})`, rose and lowest < ROOT_H + 0.05 and highest <= ROOT_H + Companion.HopHeight + 0.01)
end

-- The Secret girl's arrival (Gameplay/SecretReveal): builds on a stand-in showcase, plays the whole timeline,
-- puts her back where she floats for the game, and cleans up.
do
	local Reveal = require(game.StarterPlayer.StarterPlayerScripts.HuzzClient.Gameplay.SecretReveal)
	local Timing = require(RS.Shared.SecretReveal)
	local m = rig()
	m.PrimaryPart = m.HumanoidRootPart
	local base = CFrame.new(0, 40, 0)
	m:PivotTo(base)
	-- the game's own look on Lighting (LookService), to check the cutscene puts every value back exactly
	local L = game.Lighting
	L.ClockTime, L.Brightness = 14.2, 2.8 -- (Lune's Lighting starts without them)
	L.Ambient, L.OutdoorAmbient = Color3.fromRGB(92, 96, 112), Color3.fromRGB(138, 140, 156)
	for _, c in L:GetChildren() do c:Destroy() end
	local atmo = Instance.new("Atmosphere")
	atmo.Density, atmo.Offset, atmo.Haze, atmo.Glare = 0.2, 0.1, 0.3, 0
	atmo.Color, atmo.Decay = Color3.fromRGB(199, 225, 255), Color3.fromRGB(106, 150, 220)
	atmo.Parent = L
	local bloom = Instance.new("BloomEffect")
	bloom.Intensity, bloom.Size, bloom.Threshold = 0.55, 22, 1.5
	bloom.Parent = L
	local function snapshot()
		local out = {}
		for _, key in { "ClockTime", "Brightness", "Ambient", "OutdoorAmbient" } do out["L." .. key] = L[key] end
		for _, key in { "Density", "Offset", "Haze", "Glare", "Color", "Decay" } do out["A." .. key] = atmo[key] end
		for _, key in { "Intensity", "Size", "Threshold" } do out["B." .. key] = bloom[key] end
		out.children = #L:GetChildren()
		return out
	end
	local before = snapshot()
	local okBuild, step, cleanup = pcall(Reveal.build, m, base)
	check("secret reveal builds: " .. tostring(step), okBuild)
	if okBuild then
		local hidden, lastH
		local okRun, err = pcall(function()
			for t = 0, Timing.LENGTH, 1 / 30 do
				local _, h = step(t, Vector3.new(0, 0, 1))
				if t < Timing.IMPACT then hidden = (hidden ~= false) and m:GetPivot().Position.Y < -1000 end
				lastH = h
			end
		end)
		check("secret reveal plays: " .. tostring(err), okRun)
		check("she's hidden until the impact", hidden == true)
		check("she ends at her height over the map", lastH ~= nil and math.abs(lastH - Timing.height(Timing.LENGTH, 34)) < 0.01)
		check("brightness pulses at most once a second (kid-safe)", (function()
			local starts, was = {}, false
			for t = 0, Timing.LENGTH, 1 / 60 do
				local _, _, _, p = Timing.grade(t)
				local on = p > 0.05
				if on and not was then table.insert(starts, t) end
				was = on
			end
			for i = 2, #starts do
				if starts[i] - starts[i - 1] < 1 then return false end
			end
			return #starts >= 1 and #starts <= 3
		end)())
		check("night during the build-up", Timing.clock(1, 14.2) == Timing.NIGHT and Timing.clock(Timing.LENGTH, 14.2) == 14.2)
		check("the sun comes back up evenly (no jump over dawn)", (function()
			local last = Timing.clock(Timing.DAWN, 14.2)
			for t = Timing.DAWN, Timing.DAWN + Timing.BACK, 1 / 60 do
				local c = Timing.clock(t, 14.2)
				if c >= 5.3 and c <= 7.1 and last >= 5.3 and c - last > 0.06 then return false end
				last = c
			end
			return true
		end)())
		local during = L.ClockTime
		step(5, Vector3.new(0, 0, 1))
		local nightOn = L.ClockTime == Timing.NIGHT and atmo.Haze > 1 and bloom.Intensity > 1
		cleanup()
		check("secret reveal cleans up", workspace:FindFirstChild("HuzzSecretReveal") == nil and game.Lighting:FindFirstChild("HuzzSecretGrade") == nil and #workspace.Terrain:GetChildren() == 0)
		check("the night look is on during the cutscene", nightOn and during ~= nil)
		local after = snapshot()
		local same = true
		for key, v in before do
			if after[key] ~= v then
				same = false
				print("  Lighting not restored: " .. key .. " " .. tostring(v) .. " -> " .. tostring(after[key]))
			end
		end
		check("Lighting restored exactly after the cutscene", same)
		-- at the end she's exactly where Gameplay/CarryAnimator floats her (no snap when it takes over)
		local S = require(RS.Shared.Config.Round).Showcase
		local function floatAt(now)
			return base * CFrame.new(0, math.sin(now * 1.1) * S.Bob, 0) * CFrame.Angles(0, (now * S.Spin) % (2 * math.pi), 0)
		end
		local okEnd, endStep, endCleanup = pcall(Reveal.build, m, base, 1000)
		if okEnd then
			endStep(Timing.LENGTH, Vector3.new(0, 0, 1))
			local d = m:GetPivot().Position - floatAt(1000 + Timing.LENGTH).Position
			local lookOff = (m:GetPivot().LookVector - floatAt(1000 + Timing.LENGTH).LookVector).Magnitude
			endCleanup()
			check("she hands over to the float without a snap", d.Magnitude < 0.01 and lookOff < 0.01)
		else
			check("she hands over to the float without a snap: " .. tostring(endStep), false)
		end
	end
	-- a Lighting without Atmosphere or Bloom: ours start from nothing (no sudden haze) and are removed after
	do
		for _, c in L:GetChildren() do c:Destroy() end
		local okN, stepN, cleanupN = pcall(Reveal.build, m, base)
		if okN then
			stepN(0, Vector3.new(0, 0, 1))
			local a0 = L:FindFirstChildOfClass("Atmosphere")
			local b0 = L:FindFirstChildOfClass("BloomEffect")
			local startsClear = a0 ~= nil and a0.Density == 0 and b0 ~= nil and b0.Intensity == 0
			stepN(5, Vector3.new(0, 0, 1))
			local on = a0.Density > 0.3
			cleanupN()
			check("a new Atmosphere and Bloom fade in from nothing and are removed", startsClear and on and #L:GetChildren() == 0)
		else
			check("secret reveal builds on a bare Lighting: " .. tostring(stepN), false)
		end
		-- a build that fails half way leaves nothing behind (no haze, no folder, no beams)
		Reveal.failForTest = true
		local okF = pcall(Reveal.build, m, base)
		Reveal.failForTest = nil
		check("a failed build cleans up after itself", not okF and #L:GetChildren() == 0 and workspace:FindFirstChild("HuzzSecretReveal") == nil and #workspace.Terrain:GetChildren() == 0)
	end
end

print(`fx smoke: {ok} ok, {failed} failed`)
return ""

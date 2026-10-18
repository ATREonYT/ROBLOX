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
-- her model's descendants plus our own parts (AuraFX keeps the floor pool, rings and orbiting lights in
-- Workspace.HuzzAuraFX, outside her model)
local function everything(m)
	local list = m:GetDescendants()
	local f = workspace:FindFirstChild("HuzzAuraFX")
	if f then
		for _, d in f:GetDescendants() do table.insert(list, d) end
	end
	return list
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
			for _, d in everything(m) do if d:IsA("ParticleEmitter") then emitters += 1 end end
			check(kind .. " " .. case[2] .. " has emitters", emitters >= 1)
			handle.setEnabled(false)
			handle.destroy()
			local left = 0
			for _, d in everything(m) do if d.Name:find("Huzz") then left += 1 end end
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
		for _, d in everything(m) do
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
	for _, kind in { "Player" } do
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

	-- The girls' own ladder (AuraLook.girl; owner: "effects tiny below Legendary"): each rarity adds a new layer,
	-- inside a budget (Common at most 2 emitters, Secret at most 12), and the beat stays kid-safe.
	for _, kind in { "Companion", "Showcase" } do
		local tag = `{kind} {look.Element}`
		local lastLayers, lastLive = -1, -1
		for rank, rarity in RARITIES do
			local spec = AuraLook.build(look, rarity, kind)
			local b = AuraLook.budget(spec)
			local layers = (spec.ground and 1 or 0) + (spec.ground and spec.ground.ring and 1 or 0)
				+ (spec.ground and spec.ground.runner and 1 or 0) + (spec.orbs and 1 or 0) + (spec.flames and 1 or 0)
				+ (spec.slashes and 1 or 0) + (spec.halo and 1 or 0) + (spec.ground and spec.ground.breathe > 0 and 1 or 0)
				+ (spec.beat and 1 or 0)
			local floor = if kind == "Showcase" then 3 else 1 -- (the prize always gets at least the Rare look)
			if rank > floor then
				check(`{tag} {rarity}: a new layer over {RARITIES[rank - 1]} ({lastLayers} -> {layers})`, layers > lastLayers)
				check(`{tag} {rarity}: no lighter than {RARITIES[rank - 1]} ({lastLive} -> {b.live})`, b.live >= lastLive)
			end
			lastLayers, lastLive = layers, b.live
			check(`{tag} {rarity}: on the floor (a light pool)`, spec.ground ~= nil and spec.ground.pool ~= nil)
			local r = spec.rank or rank -- (the look it gets)
			check(`{tag} {rarity}: emitters in budget ({b.emitters})`, b.emitters <= (if r <= 2 then 2 elseif r <= 4 then 4 elseif r <= 6 then 8 else 12))
			check(`{tag} {rarity}: particles alive in budget ({b.live})`, b.live <= (if r <= 2 then 5 else 75))
			if rank < 5 and kind == "Companion" then
				check(`{tag} {rarity}: tiny below Legendary (no beat, slashes or wake)`, spec.beat == nil and spec.slashes == nil and spec.wake == nil)
				-- owner picked "Small flames": Rare and Epic get a few small calm tongues, clearly under Legendary's
				local big = AuraLook.build(look, "Legendary", kind).flames
				local F = spec.flames
				if rank <= 2 then
					check(`{tag} {rarity}: no flames`, F == nil)
				else
					local function tallest(G)
						local top = -math.huge
						for i = 1, G.count do
							local _, p1 = AuraLook.flameAt(G, i, false, 0, 1, 0)
							top = math.max(top, p1.Y)
						end
						return top
					end
					check(`{tag} {rarity}: small flames, fewer, thinner, no white-hot core`, F ~= nil and F.count < big.count
						and F.core == 0 and F.width < big.width * 0.6 and F.soft == true)
					local top = if F then tallest(F) else 99
					check(`{tag} {rarity}: they end at her waist to chest ({top}), Legendary's over her head`, top < 1.2 and top > -0.6 and tallest(big) > 2.2)
				end
				check(`{tag} {rarity}: small floor glow`, spec.ground.radius <= 1.6)
			end
			if rank <= 2 and kind == "Companion" then
				check(`{tag} {rarity}: no light, no orbs, a calm pool`, spec.light == nil and spec.orbs == nil and spec.ground.pool[1] >= 0.75)
			end
			if spec.beat then
				check(`{tag} {rarity}: beats at least 2.4 s apart (kid-safe)`, spec.beat.every >= 2.4 and spec.beat.pre > 0)
			end
			if spec.slashes then
				check(`{tag} {rarity}: slashes only on the beat`, spec.slashes.onBeat == true and spec.slashes.rate <= 1 / 2.4)
			end
		end
	end
end

-- The beat: draws in before it flares (anticipation), the ring runs out once, and it settles back.
do
	local B = { every = 3, pre = 0.35 }
	local before = AuraLook.beatAt(B, 2.95)
	local flare = AuraLook.beatAt(B, 3.1)
	local after = AuraLook.beatAt(B, 4.4)
	local _, shockMid = AuraLook.beatAt(B, 3.4)
	local _, shockOff = AuraLook.beatAt(B, 5)
	check(`the beat draws in, flares, settles ({before} {flare} {after})`, before < 0.95 and flare > 1.15 and math.abs(after - 1) < 0.08)
	check("the floor ring runs out on the beat only", shockMid > 0 and shockMid < 1 and shockOff < 0)
	-- the flame tongues leave the floor at her feet, wrap round her and curl in; heights staggered
	local F = { count = 6, core = 3, radius = 1, height = 1.4, width = 1, twist = 1.1, spin = 0.5 }
	local tallest, lowest, wraps, curls, wide = -math.huge, math.huge, true, true, true
	for i = 1, F.count do
		local p0, p1, c0, _, w0, w1 = AuraLook.flameAt(F, i, false, 0.5, 1, 0)
		tallest, lowest = math.max(tallest, p1.Y), math.min(lowest, p1.Y)
		local a0, a1 = math.atan2(p0.Z, p0.X), math.atan2(p1.Z, p1.X)
		local turn = (a1 - a0 + math.pi) % (2 * math.pi) - math.pi
		if math.abs(turn - F.twist) > 0.05 then wraps = false end
		if Vector3.new(p1.X, 0, p1.Z).Magnitude >= Vector3.new(p0.X, 0, p0.Z).Magnitude then curls = false end
		if not (p0.Y < -2 and c0 > 0 and w0 > w1) then wide = false end
	end
	check(`flames: from her feet, wide at the bottom`, wide)
	check(`flames: staggered, some over her head and some at her shoulders ({lowest} .. {tallest})`, tallest > 2.2 and lowest < 2 and lowest > 0.8)
	check("flames: each wraps round her as it rises and curls in at the tip", wraps and curls)
	local q0 = AuraLook.flameAt(F, 1, false, 0, 1, 0)
	local q1 = AuraLook.flameAt(F, 1, false, 2, 1, 0)
	check("flames: the ring turns slowly", (q0 - q1).Magnitude > 0.3)
	-- orbiting lights pass in front of and behind her
	local O = { radius = 1.5, speed = 2.2, tilt = 20, bob = 0.25, height = 0.2 }
	local front, back = false, false
	for t = 0, 3, 0.05 do
		local v = AuraLook.orbitAt(O, 1, 2, t)
		if v.Z > 1 then front = true end
		if v.Z < -1 then back = true end
	end
	check("orbs go round in front of and behind her", front and back)
end

-- The girls' layers in the game (AuraFX): the floor pool follows her feet, flames sit behind her, trails come on
-- only while she walks, nothing new is made per frame, the carried girl has no pool, the cutscene hides the floor.
do
	local function legRig()
		local m = rig()
		local leg = Instance.new("Part"); leg.Name = "Left Leg"; leg.Size = Vector3.new(1, 2, 1); leg.CFrame = CFrame.new(0, -2, 0); leg.Parent = m
		local leg2 = Instance.new("Part"); leg2.Name = "Right Leg"; leg2.Size = Vector3.new(1, 2, 1); leg2.CFrame = CFrame.new(1, -2, 0); leg2.Parent = m
		for _, n in { "HumanoidRootPart", "UpperTorso" } do m[n].CFrame = CFrame.new(0, 0, 0) end
		m.Head.CFrame = CFrame.new(0, 1.5, 0)
		m.RightHand.CFrame = CFrame.new(1.5, -1, 0)
		m.LeftHand.CFrame = CFrame.new(-1.5, -1, 0)
		return m
	end
	local look = AuraLook.lookFor(Looks, "CAC_R6_ixKatsu_358858", nil)
	local m = legRig()
	local spec = AuraLook.build(look, "Secret", "Companion")
	local handle = AuraFX.attach(m, spec)
	local fxf = workspace:FindFirstChild("HuzzAuraFX")
	local pool = fxf and fxf:FindFirstChild("HuzzAuraPool")
	check("Secret girl: a light pool on the floor", pool ~= nil)
	local flames, outerOk, coreOk = 0, true, true
	for _, d in m:GetDescendants() do
		if d:IsA("Beam") and d.Name:find("HuzzFlame") then
			flames += 1
			if d.Name:find("Core") then
				if d.ZOffset > -1 then coreOk = false end
			elseif d.ZOffset >= 0 or d.ZOffset < -0.6 then
				outerOk = false
			end
		end
	end
	check(`Secret girl: flame tongues ({flames}) round her, a little back (in front of her legs, behind her face)`, flames == spec.flames.count + spec.flames.core and outerOk)
	check("Secret girl: the white-hot inner tongues drawn behind her", coreOk)
	local function count()
		return #everything(m)
	end
	for _ = 1, 5 do handle.step(1 / 30) end
	local before = count()
	-- she walks 6 studs to the side
	local wakeOn, orbTrailOn = false, false
	for i = 1, 60 do
		for _, p in m:GetChildren() do
			if p:IsA("BasePart") then p.CFrame = p.CFrame + Vector3.new(0.1, 0, 0) end
		end
		handle.step(1 / 30)
		for _, d in m:GetDescendants() do
			if d:IsA("Trail") and d.Name:find("HuzzWake") and d.Enabled then wakeOn = true end
		end
		if i > 30 then
			for _, d in fxf:GetDescendants() do
				if d:IsA("Trail") and d.Name:find("HuzzOrbTrail") and d.Enabled then orbTrailOn = true end
			end
		end
	end
	check("Secret girl: the orbs' trails stop while she walks (no long ribbon at chest height)", not orbTrailOn)
	check("Secret girl: nothing new made per frame", count() == before)
	check("Secret girl: trails on her feet while she walks", wakeOn)
	local pp = pool.CFrame.Position
	check(`the pool follows her feet ({pp})`, math.abs(pp.X - 6) < 0.3 and math.abs(pp.Y - (-3 + 0.04)) < 0.2)
	for _ = 1, 30 do handle.step(1 / 30) end
	local wakeOff = true
	for _, d in m:GetDescendants() do
		if d:IsA("Trail") and d.Name:find("HuzzWake") and d.Enabled then wakeOff = false end
	end
	check("the trails stop when she stops", wakeOff)
	local orbBack = false
	for _, d in fxf:GetDescendants() do
		if d:IsA("Trail") and d.Name:find("HuzzOrbTrail") and d.Enabled then orbBack = true end
	end
	check("and the orbs' trails come back when she stands", orbBack)
	m:SetAttribute("HuzzRevealing", true)
	for _ = 1, 20 do handle.step(1 / 30) end
	check("the floor layers hide while the Secret cutscene flies her", pool:FindFirstChildOfClass("SurfaceGui").Enabled == false)
	m:SetAttribute("HuzzRevealing", nil)
	for _ = 1, 20 do handle.step(1 / 30) end
	check("and come back after", pool:FindFirstChildOfClass("SurfaceGui").Enabled == true)
	handle.destroy()
	check("the girl's floor layers clean up", #fxf:GetChildren() == 0)
	local m2 = legRig()
	local h2 = AuraFX.attach(m2, spec, { lite = true, ground = false })
	check("the carried girl: no pool under her", fxf:FindFirstChild("HuzzAuraPool") == nil)
	local floaters = {}
	for _, d in everything(m2) do
		if (d:IsA("ParticleEmitter") and (d.Name == "Motes" or d.Name == "Steps" or d.Name == "Rising"))
			or (d:IsA("Trail") and d.Name:find("HuzzWakeFoot")) then
			table.insert(floaters, d.Name)
		end
	end
	check(`the carried girl: nothing from the floor or her feet floating in the air ({table.concat(floaters, ",")})`, #floaters == 0)
	h2.destroy()
	-- streaming takes her parts away but keeps the model: the handle says so (Auras rebuilds her effects later)
	local m3 = legRig()
	local h3 = AuraFX.attach(m3, spec)
	local aliveBefore = h3.alive()
	m3.UpperTorso.Parent = nil
	check("streamed-out parts: the effects know they lost her", aliveBefore and not h3.alive())
	h3.destroy()
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

-- The Secret cutscene's camera is one smooth move (owner, Oct 18: "a bit chopy still and the camera is still not
-- very logical"): sampled at 30 fps, outside the listed deliberate cuts the eye and the look point move at most 2.5
-- studs a frame (at the 3x scale), the view turns at most 4 degrees and the field of view at most 2.5 degrees a
-- frame, the eye's speed changes gently (no stop-start), it never goes behind her (she faces you) or under the
-- floor, cuts are few and far apart, and the shake is a slow, small wobble.
do
	local T = require(RS.Shared.SecretReveal)
	local dir, at, k, mid = Vector3.new(0, 0, 1), Vector3.zero, 1, 7.5
	local FR = 1 / 30
	local function crossesCut(t0, t1)
		for _, c in T.CUTS do
			if t0 < c and t1 >= c then return true end
		end
		return false
	end
	local worst = { eye = 0, look = 0, turn = 0, fov = 0, accel = 0, shake = 0 }
	local behind, under, jumps = 0, 0, {}
	local pe, pl, pd, pf, pv, prx
	for i = 0, math.floor(T.LENGTH * 30) do
		local t = i * FR
		local e, l = T.camera(t, at, dir, T.height(t, 34) or 34, k, mid)
		local f = T.fov(t, false)
		local d = (l - e).Unit
		if (e - at):Dot(dir) <= 1 then behind += 1 end
		if e.Y < 1.5 then under += 1 end
		local rx, ry = T.shakeAt(t, 17)
		if pe and not crossesCut(t - FR, t) then
			local step = {
				eye = (e - pe).Magnitude, look = (l - pl).Magnitude, fov = math.abs(f - pf),
				turn = math.deg(math.acos(math.clamp(d:Dot(pd), -1, 1))),
				accel = if pv and not crossesCut(t - 2 * FR, t - FR) then ((e - pe) - pv).Magnitude else 0,
				shake = math.deg(math.max(math.abs(rx - prx[1]), math.abs(ry - prx[2]))),
			}
			for key, v in step do
				if v > worst[key] then worst[key] = v end
			end
			if step.eye > 2.5 or step.look > 2.5 or step.turn > 4 or step.fov > 2.5 or step.accel > 0.6 then
				table.insert(jumps, string.format("%.2f", t))
			end
		end
		pv = if pe then e - pe else nil
		pe, pl, pd, pf, prx = e, l, d, f, { rx, ry }
	end
	local gaps = true
	local last = 0
	for _, c in T.CUTS do
		if c - last < 2 then gaps = false end
		last = c
	end
	print(string.format("  secret camera per frame: eye %.2f, look %.2f, turn %.2f deg, fov %.2f deg, speed change %.2f, shake %.2f deg",
		worst.eye, worst.look, worst.turn, worst.fov, worst.accel, worst.shake))
	check("secret camera glides (no jumps outside the listed cuts): " .. table.concat(jumps, " "), #jumps == 0)
	check("secret camera stays in front of her and over the floor", behind == 0 and under == 0)
	check("secret camera cuts are few and at least 2 s apart", #T.CUTS <= 2 and gaps and T.LENGTH - last >= 2)
	check("secret camera shake is a slow, small wobble", worst.shake <= 0.75)
	check("Reduced Motion: no field-of-view kick at the impact", math.abs(T.fov(T.IMPACT + 0.18, false) - T.fov(T.IMPACT + 0.18, true) - 8) < 0.01)
end

print(`fx smoke: {ok} ok, {failed} failed`)
return ""

--[[
	The lobby avatar stands' sword showcase (owner, Oct 18, about the stands: "for these make them showcase the swords
	that the gamepass includes. For example the swinging animation, make it look good though"). Replaces the
	run-in-place on a stand copy that holds a knife (HuzzClient/Gameplay/AvatarStands); stands without a knife keep
	the run.

	The loop (CYCLE seconds, every stand offset by its own seed so stands side by side never move together):
	  ready      a confident guard: feet apart (right foot back), knees soft, chest turned a little so the knife
	             side faces you, the knife hand low in front of the right hip with the blade slanting up and out to the
	             right (about 45 degrees), clear of the body, the face and the sign over the head; weight shifting
	             slowly side to side, breathing, the blade rocking.
	  a move     every loop one of three, in turn (ORDER, starting at the seed):
	             Combo     wind up across the body, a forehand sweep out to the right (the catcher's slash,
	                       Shared/StabMotion), a backhand return to the left, a twirl of the knife round the fist,
	                       back to ready.
	             Flourish  the knife up overhead, a twirl up there, a diagonal cut down across the body, back.
	             Rising    a crouch with the knife low behind, a rising cut up across to the left, a twirl in front.
	The slash trail shows only during the cuts (TRAIL windows). No flashes: the knife's rarity glow (KnifeLook) is
	steady.

	Oct 19 (owner: "make the knife animations look like the ones i have attached in the video ... better knife
	animations ... in the lobby"; design/lobby-ref/oct19-stands-ref.mp4): each Game Pass knife has its own STYLE, a
	hold and three moves in the reference's way (its PUMPKIN CLEAVER held low with big arcs and a spin slash, its VIP
	DAGGER's quick flicks, its VOWBREAKER's raised spin with a burst of petals):
	  holds      Guard (above) or Low: the big blade held low out to the right side, pointing down and forward.
	  Cleave     the blade up overhead and behind, then one big arc down in front, the body dropping into it.
	  Whirl      a coil to the left, then the whole body spins round once with the blade out level, ending in a
	             lunging slash to the right (the spin: `spin`, degrees of the whole body; the feet turn with it).
	  Scrape     (round 2: the reference's cleaver swept low) a crouch with the blade back low on the right, then one
	             big arc low across the front to the left, just over the floor.
	  Flick      the arm out, the wrist flicks the blade twice, then a twirl.
	  Bloom      the arm raised high, a spin round with the blade up, a burst of the knife's element (petals,
	             feathers, embers...) at the turn, then an arm-out slash.
	A move can name `burst` times: AvatarStands throws the knife's KnifeBurst particles then (calm: once a move).

	Pure joint maths (R15 first class; R6 a simpler version: one-part arms, so the elbow and wrist go into the
	shoulder and the grip), written straight into Motor6D.Transform: the stand copy has no Animator playing. Legs:
	R15 two-bone IK keeps the feet planted while the body dips and sways; R6 legs only lean. The twirl spins the knife
	in the fist: `grip` (degrees about the hand's X at the grip point) goes into the knife weld's C0
	(AvatarStands). The offline film (tools/preview/motion3d/stand_scene.luau) and tests/StandShowcase.spec run this
	exact code on mock rigs.

	Angles below are degrees in each joint's parent part space (x right, y up, -z forward). Arms are built as
	yaw * pitch * roll: roll first (+ = towards +x: out for the right arm, in for the left), then pitch (+ raises
	forward), then yaw (+ swings to the left). Elbows and wrists: + bends forward. Waist: + pitch leans back,
	+ yaw turns left.
]]
local CarryMath = require(script.Parent.CarryMath)

local StandShowcase = {}
local rad = math.rad

StandShowcase.CYCLE = 3.3 -- seconds a loop: ready, then one move
StandShowcase.START = 1.7 -- the move starts this far into the loop
StandShowcase.ORDER = { "Combo", "Flourish", "Rising" }
StandShowcase.NEAR = 160 -- (AvatarStands: copies further than this don't move)
StandShowcase.TRAIL_LIFETIME = 0.2 -- the slash smear (KnifeLook.TRAIL is 0.12 for a quick catch; this one shows off the big arcs; round 2: 0.24 washed a flat sweep out)

-- The ready guard. drop = how far the body sits down (studs: knees soft); grip = the knife's turn in the fist
-- (0 = KnifeLook.handC0's own angle; -30 = straight out of the fist along the forearm, the cutting angle).
-- twist = the knife's turn about its own blade (degrees about the Handle's Y, after the grip): round 3 (Oct 19, "in
-- the reference the cleaver held low shows its full face"): at rest each hold turns the blade's broad face out of the
-- stand, to whoever stands in front of it (measured on R15 and R6: the width axis was pointing at the viewer, so the
-- blade showed its edge). In a move the twist goes back to 0 (the edge leads the cut) and returns with the hold.
-- Knife check (Oct 19): the guard used to hold the blade straight up in front of the shoulder; at the stands' 4.4
-- studs its tip rose 2.6 studs over the head, into the sign, and the camera saw it end-on as a glowing blob. Now it
-- slants up and out to the right side (searched on R15 and R6 for that slant with the hand in front, the tip under the
-- sign and the broad face out; tests/StandShowcase.spec).
local READY = {
	arm = { 5, -57, -23 }, elbow = 97, wrist = -4, grip = 13, twist = -52,
	off = { 30, 16, -16 }, offElbow = 80,
	waist = { -3, 12, 0 }, neck = { -3, -10, 0 }, drop = 0.14, spin = 0,
}
StandShowcase.READY = READY
-- The low hold (the reference's cleaver): the arm down and out to the right, the blade hanging down and out to the
-- side (round 3: across the view, its broad face out of the stand), the free hand loose, knees bent a little more.
local LOW = {
	arm = { 14, -10, 54 }, elbow = 26, wrist = -6, grip = -38, twist = 80,
	off = { 14, 10, -16 }, offElbow = 34,
	waist = { -5, 16, 0 }, neck = { -3, -13, 0 }, drop = 0.2, spin = 0,
}
StandShowcase.HOLDS = { Guard = READY, Low = LOW }

-- Each knife's style: its hold and its three moves, in turn (stands without a style: the guard and the first three).
StandShowcase.STYLES = {
	Default = { hold = "Guard", moves = { "Combo", "Flourish", "Rising" } },
	DragonsMaw = { hold = "Low", moves = { "Whirl", "Scrape", "Cleave" } }, -- the pumpkin cleaver: low sweeps, a spin slash
	HollowEclipse = { hold = "Low", moves = { "Cleave", "Scrape", "Whirl" } }, -- the big cleaver: heavy arcs
	CrimsonRequiem = { hold = "Low", moves = { "Bloom", "Flick", "Combo" } }, -- the vowbreaker: a raised spin, petals
	CelestialSeraph = { hold = "Guard", moves = { "Flick", "Flourish", "Bloom" } }, -- the dagger's quick flicks
	FrostboundOath = { hold = "Guard", moves = { "Whirl", "Rising", "Flick" } },
}

-- Each move: keys (at = seconds from the move's start; ease = how the segment INTO that key moves; fields not given
-- keep the previous key's value) and trail windows (seconds).
local MOVES = {
	Combo = {
		keys = {
			{ at = 0 },
			-- wind up: knife across to the left, the chest turned into it
			{ at = 0.16, ease = "smooth", arm = { 82, 58, 4 }, elbow = 38, wrist = 0, grip = -26, waist = { -5, 26, 0 }, neck = { -2, -18, 0 },
				off = { 40, -10, -30 }, offElbow = 70, drop = 0.22 },
			-- the forehand sweep out to the right
			{ at = 0.34, ease = "smooth", arm = { 86, -72, 2 }, elbow = 10, wrist = -6, grip = -28, waist = { -6, -26, 0 }, neck = { -2, 16, 0 },
				off = { 70, 0, -10 }, offElbow = 20, drop = 0.26 },
			{ at = 0.46, ease = "out", arm = { 84, -84, 4 }, waist = { -6, -30, 0 } },
			-- the backhand return across to the left
			{ at = 0.66, ease = "smooth", arm = { 96, 62, 0 }, elbow = 16, wrist = 0, waist = { -4, 24, 0 }, neck = { -2, -14, 0 },
				off = { 30, 10, -26 }, offElbow = 70, drop = 0.24 },
			-- in front, ready for the twirl
			{ at = 0.84, ease = "smooth", arm = { 58, -4, 18 }, elbow = 74, wrist = -6, waist = { -3, 8, 0 }, neck = { -3, -6, 0 },
				off = { 30, 16, -16 }, offElbow = 80, drop = 0.16 },
			-- the twirl: the knife spins once round the fist
			{ at = 1.2, ease = "smooth", grip = -388, wrist = 4 },
			{ at = 1.46, ease = "smooth", ready = true, grip = -360 },
		},
		trail = { { 0.18, 0.5 }, { 0.5, 0.7 } },
	},
	Flourish = {
		keys = {
			{ at = 0 },
			-- up overhead, the free arm out for balance
			{ at = 0.24, ease = "smooth", arm = { 150, 8, 22 }, elbow = 30, wrist = 0, grip = 0, waist = { 5, 6, 0 }, neck = { 6, -6, 0 },
				off = { 20, 0, -50 }, offElbow = 20, drop = 0.1 },
			-- a twirl up there
			{ at = 0.6, ease = "smooth", grip = -360, wrist = 6 },
			-- the diagonal cut down across the body
			{ at = 0.8, ease = "smooth", arm = { 36, 34, 8 }, elbow = 10, wrist = -4, grip = -388, waist = { -9, 20, 0 }, neck = { -6, -14, 0 },
				off = { 40, -6, -24 }, offElbow = 60, drop = 0.3 },
			{ at = 1.0, ease = "out", arm = { 30, 40, 8 }, waist = { -10, 22, 0 } },
			{ at = 1.4, ease = "smooth", ready = true, grip = -360 },
		},
		trail = { { 0.6, 0.88 } },
	},
	Rising = {
		keys = {
			{ at = 0 },
			-- a crouch, the knife low behind on the right
			{ at = 0.2, ease = "smooth", arm = { -28, -22, 26 }, elbow = 14, wrist = 0, grip = -26, waist = { -10, -22, 0 }, neck = { -4, 18, 0 },
				off = { 46, 10, -20 }, offElbow = 60, drop = 0.36 },
			-- the rising cut up across to the left
			{ at = 0.43, ease = "smooth", arm = { 142, 36, 2 }, elbow = 10, wrist = 0, waist = { 5, 22, 0 }, neck = { 4, -14, 0 },
				off = { 20, -10, -40 }, offElbow = 30, drop = 0.1 },
			{ at = 0.57, ease = "out", arm = { 148, 42, 2 } },
			-- in front: a twirl
			{ at = 0.8, ease = "smooth", arm = { 64, 0, 16 }, elbow = 60, wrist = -4, grip = -26, waist = { -3, 8, 0 }, neck = { -3, -8, 0 },
				off = { 30, 16, -16 }, offElbow = 80, drop = 0.16 },
			{ at = 1.16, ease = "smooth", grip = -386, wrist = 4 },
			{ at = 1.42, ease = "smooth", ready = true, grip = -360 },
		},
		trail = { { 0.22, 0.6 } },
	},
	-- Oct 19, after the owner's reference video
	Cleave = {
		keys = {
			{ at = 0 },
			-- up overhead and behind, leaning back, the free arm out in front
			{ at = 0.3, ease = "smooth", arm = { 166, 12, 8 }, elbow = 34, wrist = 4, grip = -34, waist = { 9, 10, 0 }, neck = { 7, -6, 0 },
				off = { 50, -10, -34 }, offElbow = 40, drop = 0.06 },
			-- the big arc down in front, dropping into it
			{ at = 0.56, ease = "smooth", arm = { 24, 8, 6 }, elbow = 6, wrist = -6, grip = -12, waist = { -18, 4, 0 }, neck = { -8, -4, 0 },
				off = { 34, 10, -44 }, offElbow = 30, drop = 0.46 },
			{ at = 0.76, ease = "out", arm = { 18, 10, 6 }, waist = { -20, 4, 0 }, drop = 0.48 },
			{ at = 1.36, ease = "smooth", ready = true },
		},
		trail = { { 0.32, 0.7 } },
		burst = { 0.56 },
	},
	Whirl = {
		keys = {
			{ at = 0 },
			-- the coil: blade across to the left, chest turned into it
			{ at = 0.22, ease = "smooth", arm = { 74, 58, 4 }, elbow = 40, wrist = 0, grip = -20, waist = { -6, 30, 0 }, neck = { -2, -20, 0 },
				off = { 40, -10, -30 }, offElbow = 70, drop = 0.26, spin = 0 },
			-- the whole body spins round once to the right with the blade out level
			{ at = 0.82, ease = "smooth", arm = { 88, -64, 4 }, elbow = 8, wrist = -6, grip = -26, waist = { -8, -24, 0 }, neck = { -2, 16, 0 },
				off = { 60, 0, -20 }, offElbow = 20, drop = 0.22, spin = -360 },
			-- the lunging slash carries on out to the right
			{ at = 1.0, ease = "out", arm = { 86, -84, 4 }, waist = { -8, -30, 0 }, drop = 0.28 },
			{ at = 1.5, ease = "smooth", ready = true, spin = -360 },
		},
		trail = { { 0.3, 1.04 } },
		burst = { 0.6 },
	},
	Scrape = {
		keys = {
			{ at = 0 },
			-- a crouch, the blade back low on the right
			{ at = 0.22, ease = "smooth", arm = { -34, -36, 30 }, elbow = 12, wrist = 0, grip = -6, waist = { -12, -30, 0 }, neck = { -4, 22, 0 },
				off = { 40, 10, -30 }, offElbow = 50, drop = 0.44 },
			-- one big arc low across the front to the left
			{ at = 0.56, ease = "smooth", arm = { 26, 56, 12 }, elbow = 6, wrist = -4, grip = -30, waist = { -16, 30, 0 }, neck = { -6, -20, 0 },
				off = { 20, -10, -50 }, offElbow = 30, drop = 0.48 },
			{ at = 0.72, ease = "out", arm = { 28, 64, 12 }, waist = { -16, 34, 0 } },
			{ at = 1.3, ease = "smooth", ready = true },
		},
		trail = { { 0.24, 0.74 } },
		burst = { 0.48 },
	},
	Flick = {
		keys = {
			{ at = 0 },
			{ at = 0.14, ease = "smooth", arm = { 62, -34, 22 }, elbow = 46, wrist = -34, grip = -26, waist = { -4, -8, 0 }, neck = { -2, 6, 0 },
				off = { 34, 12, -20 }, offElbow = 70, drop = 0.18 },
			{ at = 0.26, ease = "smooth", wrist = 32, grip = 6 },
			{ at = 0.38, ease = "smooth", arm = { 66, -40, 22 }, wrist = -34, grip = -30 },
			{ at = 0.5, ease = "smooth", wrist = 30, grip = 4 },
			{ at = 0.66, ease = "smooth", arm = { 58, -20, 20 }, wrist = -4, grip = -26 },
			{ at = 1.0, ease = "smooth", grip = -386, wrist = 4 },
			{ at = 1.3, ease = "smooth", ready = true, grip = -360 },
		},
		trail = { { 0.12, 0.56 } },
	},
	Bloom = {
		keys = {
			{ at = 0 },
			-- the arm raised high, blade up, the free arm low and out
			{ at = 0.26, ease = "smooth", arm = { 158, 4, 30 }, elbow = 12, wrist = 0, grip = -30, waist = { 6, 4, 0 }, neck = { 6, -4, 0 },
				off = { 24, 0, -60 }, offElbow = 16, drop = 0.04, spin = 0 },
			-- a spin round with the blade up, the burst at the turn
			{ at = 0.84, ease = "smooth", arm = { 104, -30, 14 }, elbow = 10, grip = -30, waist = { 0, -10, 0 }, neck = { 0, 6, 0 },
				off = { 30, 0, -50 }, offElbow = 20, drop = 0.12, spin = -360 },
			-- the arm-out slash
			{ at = 1.04, ease = "smooth", arm = { 86, -84, 4 }, elbow = 8, wrist = -6, grip = -26, waist = { -6, -28, 0 }, neck = { -2, 18, 0 },
				off = { 70, 0, -10 }, offElbow = 20, drop = 0.24 },
			{ at = 1.14, ease = "out", arm = { 84, -90, 4 } },
			{ at = 1.52, ease = "smooth", ready = true, spin = -360 },
		},
		trail = { { 0.4, 0.86 }, { 0.88, 1.16 } },
		burst = { 0.56 },
	},
}
StandShowcase.MOVES = MOVES

local FIELDS = { "arm", "elbow", "wrist", "grip", "twist", "off", "offElbow", "waist", "neck", "drop", "spin" }
-- Each move for a hold: every key filled from the one before (the first from the hold); a `ready` key (the last)
-- is the hold itself, its grip plus whole twirls (grip -360 = one twirl ending where it began) and its spin.
local compiled = {}
function StandShowcase.compiled(holdName: string)
	if compiled[holdName] then return compiled[holdName] end
	local hold = StandShowcase.HOLDS[holdName] or READY
	local out = {}
	for name, move in MOVES do
		local keys, prev = {}, hold
		for _, src in move.keys do
			local key = { at = src.at, ease = src.ease }
			for _, f in FIELDS do
				if src.ready then
					if f == "grip" then key[f] = hold.grip + (src.grip or 0)
					elseif f == "spin" then key[f] = src.spin or 0
					else key[f] = hold[f] end
				elseif f == "twist" then key[f] = src.twist or (if src.at == 0 then hold.twist else 0) -- (edge into the cut)
				elseif src[f] ~= nil then key[f] = src[f]
				else key[f] = prev[f] end
			end
			table.insert(keys, key)
			prev = key
		end
		out[name] = { keys = keys, trail = move.trail, burst = move.burst or {}, length = keys[#keys].at }
	end
	compiled[holdName] = out
	return out
end
for name, move in StandShowcase.compiled("Guard") do MOVES[name].length = move.length end

-- A style by knife key (unknown: Default).
function StandShowcase.style(key: string?)
	return StandShowcase.STYLES[key or ""] or StandShowcase.STYLES.Default
end

local function smooth(x) return x * x * (3 - 2 * x) end
local EASE = {
	smooth = smooth,
	out = function(x) return 1 - (1 - x) * (1 - x) end, -- (a gentle settle; only after a fast segment)
}

local function mix(a, b, s)
	if type(a) == "table" then
		return { a[1] + (b[1] - a[1]) * s, a[2] + (b[2] - a[2]) * s, a[3] + (b[3] - a[3]) * s }
	end
	return a + (b - a) * s
end

-- Which move a loop plays, and where in the loop t is (and which loop). seed: any whole number (the stand's own);
-- order: the style's moves (default ORDER).
function StandShowcase.timing(seed: number, t: number, order: { string }?)
	local list = order or StandShowcase.ORDER
	local C = StandShowcase.CYCLE
	local shifted = t + (seed * 0.731) % C
	local loop = math.floor(shifted / C)
	local name = list[(loop + seed) % #list + 1]
	return name, shifted - loop * C - StandShowcase.START, loop
end

-- The pose at t seconds (pure numbers): the guard or a move, with the breathing and the weight shift on top.
-- Returns { arm, elbow, wrist, grip, twist, off, offElbow, waist, neck, drop, spin, sway (studs, +x), bob (studs), move (name
-- or nil), trail (bool), burst (which burst of the move has fired, or nil), loop }. styleKey: a knife key (STYLES).
function StandShowcase.sample(seed: number, t: number, styleKey: string?)
	local style = StandShowcase.style(styleKey)
	local name, mt, loop = StandShowcase.timing(seed, t, style.moves)
	local hold = StandShowcase.HOLDS[style.hold] or READY
	local move = StandShowcase.compiled(style.hold)[name]
	local pose, trail, playing, burst = hold, false, nil, nil
	if mt >= 0 and mt <= move.length then
		playing = name
		local keys = move.keys
		for i = 2, #keys do
			local a, b = keys[i - 1], keys[i]
			if mt <= b.at then
				local s = (EASE[b.ease] or smooth)(math.clamp((mt - a.at) / (b.at - a.at), 0, 1))
				pose = {}
				for _, f in FIELDS do pose[f] = mix(a[f], b[f], s) end
				break
			end
		end
		for _, w in move.trail do
			if mt >= w[1] and mt <= w[2] then trail = true end
		end
		for i, b in move.burst do
			if mt >= b then burst = i end
		end
	end
	local out = {}
	for _, f in FIELDS do out[f] = if type(pose[f]) == "table" then table.clone(pose[f]) else pose[f] end
	out.grip = out.grip % 360 -- (a full twirl ends where it began: -360 = 0, no jump)
	if out.grip > 180 then out.grip -= 360 end
	out.spin = out.spin % 360 -- (a full spin too)
	if out.spin > 180 then out.spin -= 360 end
	-- breathing (3.4 s) and the weight shift (5.6 s), always on, small; the stand's seed offsets them too
	local tt = t + seed * 1.37
	local breath = math.sin(tt * 2 * math.pi / 3.4)
	local shift = math.sin(tt * 2 * math.pi / 5.6)
	local rock = math.sin(tt * 2 * math.pi / 2.3)
	out.waist[1] += 1.6 * breath
	out.waist[3] -= 2 * shift
	out.neck[1] -= 1 * breath
	out.neck[3] += 1.5 * shift
	out.arm[1] += 2 * breath
	out.wrist += 3 * rock
	out.off[1] += 1.5 * breath
	out.bob = 0.03 * breath
	out.sway = 0.08 * shift
	out.move, out.trail, out.burst, out.loop = playing, trail, burst, loop
	return out
end

-- A joint by name, wherever the rig keeps it (Roblox: R15 joints sit in their Part1, R6's in the Torso / root).
local function find(model, name, part0, part1)
	for _, pn in { part1, part0 } do
		local p = model:FindFirstChild(pn)
		local m = p and p:FindFirstChild(name)
		if m then return CarryMath.joint(m) end
	end
	return nil
end

local function len(v) return v.Magnitude end

-- model: the stand copy (R15 or R6). seed: the stand's own whole number (timing offset, which move first).
-- knifeKey: the knife it holds (its STYLES entry: hold and moves).
function StandShowcase.new(model, seed: number?, knifeKey: string?)
	local rec = { model = model, seed = math.floor(seed or 0), j = {}, style = knifeKey }
	local j = rec.j
	if model:FindFirstChild("UpperTorso") then
		rec.kind = "R15"
		j.root = find(model, "Root", "HumanoidRootPart", "LowerTorso")
		j.waist = find(model, "Waist", "LowerTorso", "UpperTorso")
		j.neck = find(model, "Neck", "UpperTorso", "Head")
		for _, s in { "Right", "Left" } do
			j[s .. "Shoulder"] = find(model, s .. "Shoulder", "UpperTorso", s .. "UpperArm")
			j[s .. "Elbow"] = find(model, s .. "Elbow", s .. "UpperArm", s .. "LowerArm")
			j[s .. "Wrist"] = find(model, s .. "Wrist", s .. "LowerArm", s .. "Hand")
			j[s .. "Hip"] = find(model, s .. "Hip", "LowerTorso", s .. "UpperLeg")
			j[s .. "Knee"] = find(model, s .. "Knee", s .. "UpperLeg", s .. "LowerLeg")
			j[s .. "Ankle"] = find(model, s .. "Ankle", s .. "LowerLeg", s .. "Foot")
		end
		-- the legs' bone lengths, for the IK
		rec.legs = {}
		for _, s in { "Right", "Left" } do
			local hip, knee, ankle = j[s .. "Hip"], j[s .. "Knee"], j[s .. "Ankle"]
			if hip and knee and ankle then
				local thigh = len(knee.C0.Position - hip.C1.Position)
				local shin = len(ankle.C0.Position - knee.C1.Position)
				rec.legs[s] = { hip = hip, knee = knee, ankle = ankle, thigh = thigh, shin = shin, at = hip.C0.Position }
			end
		end
	elseif model:FindFirstChild("Torso") then
		rec.kind = "R6"
		j.root = find(model, "RootJoint", "HumanoidRootPart", "Torso")
		j.neck = find(model, "Neck", "Torso", "Head")
		for _, s in { "Right", "Left" } do
			j[s .. "Shoulder"] = find(model, s .. " Shoulder", "Torso", s .. " Arm")
			j[s .. "Hip"] = find(model, s .. " Hip", "Torso", s .. " Leg")
		end
		local leg = model:FindFirstChild("Right Leg")
		rec.legLength = if leg and leg.Size then leg.Size.Y else 2
	else
		return nil
	end
	return rec
end

local function swing(t) -- yaw * pitch * roll
	return CFrame.Angles(0, rad(t[2]), 0) * CFrame.Angles(rad(t[1]), 0, 0) * CFrame.Angles(0, 0, rad(t[3]))
end
StandShowcase.swing = swing

local function set(motor, rotation)
	if motor then motor.Transform = CarryMath.inJoint(motor, rotation) end
end

-- A move of the joint's child by `offset` (in the parent part's space) and a turn, as a Transform.
local function place(motor, offset: Vector3, rotation)
	if not motor then return end
	local r = motor.C0.Rotation
	motor.Transform = CFrame.new(r:VectorToObjectSpace(offset)) * CarryMath.inJoint(motor, rotation)
end

-- Where each foot stands (from the hip, straight down, then these): right foot a little out and back, left out
-- and forward, so the guard reads side-on.
StandShowcase.STANCE = { Right = Vector3.new(0.14, 0, 0.3), Left = Vector3.new(-0.12, 0, -0.24) }

-- R15 legs: the body moved by `body` (studs, LowerTorso space); each foot stays where it stood (two-bone IK) and flat.
local function legs(rec, body: Vector3)
	for side, L in rec.legs do
		local total = L.thigh + L.shin
		local foot = L.at + Vector3.new(0, -total, 0) + StandShowcase.STANCE[side]
		local v = foot - body - L.at -- hip to ankle, in LowerTorso space
		local d = math.clamp(v.Magnitude, total * 0.4, total * 0.999)
		local r = math.asin(math.clamp(v.X / d, -1, 1))
		local p = math.atan2(-v.Z, -v.Y)
		local a = math.acos(math.clamp((L.thigh ^ 2 + d ^ 2 - L.shin ^ 2) / (2 * L.thigh * d), -1, 1))
		local k = math.pi - math.acos(math.clamp((L.thigh ^ 2 + L.shin ^ 2 - d ^ 2) / (2 * L.thigh * L.shin), -1, 1))
		local hip = CFrame.Angles(p + a, 0, 0) * CFrame.Angles(0, 0, r)
		local knee = CFrame.Angles(-k, 0, 0)
		set(L.hip, hip)
		set(L.knee, knee)
		set(L.ankle, (hip * knee):Inverse()) -- (the foot flat on the floor, pointing ahead)
	end
end

-- Writes a pose (StandShowcase.sample) onto the rig.
function StandShowcase.apply(rec, pose)
	local j = rec.j
	if rec.kind == "R15" then
		local body = Vector3.new(pose.sway, pose.bob - pose.drop, 0)
		place(j.root, body, CFrame.Angles(0, rad(pose.spin), 0)) -- (a spin turns the whole body; the feet turn with it)
		set(j.waist, CFrame.Angles(0, rad(pose.waist[2]), 0) * CFrame.Angles(rad(pose.waist[1]), 0, rad(pose.waist[3])))
		set(j.neck, CFrame.Angles(0, rad(pose.neck[2]), 0) * CFrame.Angles(rad(pose.neck[1]), 0, rad(pose.neck[3])))
		set(j.RightShoulder, swing(pose.arm))
		set(j.RightElbow, CFrame.Angles(rad(pose.elbow), 0, 0))
		set(j.RightWrist, CFrame.Angles(rad(pose.wrist), 0, 0))
		set(j.LeftShoulder, swing(pose.off))
		set(j.LeftElbow, CFrame.Angles(rad(pose.offElbow), 0, 0))
		set(j.LeftWrist, CFrame.identity)
		legs(rec, body)
	else
		-- R6: no waist (the body turns a little at the root instead), no elbows (the shoulder takes 60% of the bend,
		-- the grip the rest, so the blade points the same way as on R15); the legs only lean to stand under the sway
		local turn = CFrame.Angles(0, rad(pose.waist[2] * 0.5), 0) * CFrame.Angles(rad(pose.waist[1] * 0.6), 0, rad(pose.waist[3]))
		place(j.root, Vector3.new(pose.sway, pose.bob, 0), CFrame.Angles(0, rad(pose.spin), 0) * turn)
		set(j.neck, CFrame.Angles(0, rad(pose.neck[2] + pose.waist[2] * 0.5), 0) * CFrame.Angles(rad(pose.neck[1]), 0, rad(pose.neck[3])))
		local arm = { pose.arm[1] + pose.elbow * 0.6, pose.arm[2], pose.arm[3] }
		set(j.RightShoulder, swing(arm))
		set(j.LeftShoulder, swing({ pose.off[1] + pose.offElbow * 0.5, pose.off[2], pose.off[3] }))
		local lean = math.asin(math.clamp(pose.sway / rec.legLength, -0.5, 0.5))
		local back = turn:Inverse() -- (the legs undo the body's turn, so the feet stay put; a spin they turn with)
		set(j.RightHip, back * CFrame.Angles(0, 0, -lean + rad(4)))
		set(j.LeftHip, back * CFrame.Angles(0, 0, -lean - rad(4)))
	end
end

-- The knife's turn in the fist for this pose (degrees about the hand's X at the grip point; AvatarStands puts it in
-- the knife weld's C0). R6 adds the elbow and wrist bend its arm can't make.
function StandShowcase.gripOf(rec, pose): number
	if rec.kind == "R6" then
		return pose.grip + pose.elbow * 0.4 + pose.wrist
	end
	return pose.grip
end

-- The knife's whole turn in the fist, after KnifeLook.handC0's rotation (AvatarStands' weld C0, the spec, the render):
-- the grip about the hand's X, then the twist about the blade.
function StandShowcase.knifeTurn(pose, handTurn: CFrame): CFrame
	return CFrame.Angles(math.rad(pose.gripAngle or pose.grip), 0, 0) * handTurn * CFrame.Angles(0, math.rad(pose.twist or 0), 0)
end

-- One frame: the pose at t seconds onto the rig. Returns the pose (pose.trail: show the slash trail now).
function StandShowcase.step(rec, t: number)
	local pose = StandShowcase.sample(rec.seed, t, rec.style)
	StandShowcase.apply(rec, pose)
	pose.gripAngle = StandShowcase.gripOf(rec, pose)
	return pose
end

-- Hands every joint back (the stand goes back to its run, or the copy is rebuilt).
function StandShowcase.release(rec)
	for _, m in rec.j do
		if m then m.Transform = CFrame.identity end
	end
end

return StandShowcase

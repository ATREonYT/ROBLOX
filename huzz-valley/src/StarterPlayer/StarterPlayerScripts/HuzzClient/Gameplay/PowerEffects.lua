--[[
	How the round powers look when they're used, drawn on every client from the server's "Power" messages on the
	Round remote (HuzzServer/PowerService). Owner: "make the usage of items smoother ... make it feel like the
	references"; Oct 20 15:13: "make them well made, right now they are kind of quick and feel cheap". Every power
	has four beats (Config/Powers.Fx):
	  1. the wind-up (0.1 to 0.45 s): the body strikes its cast pose (or the throw), a glow builds on it, white in the
	     middle, pink round it, with a soft light; for the longer ones a ring gathers in at the feet, little motes
	     spiral in and a soft riser plays (power_charge), so you see it coming;
	  2. one bright frame (at most one a second on a screen: kid-safe) and the power's own sound;
	  3. the effect, long enough to read (0.6 s), white core -> pink -> purple edges;
	  4. a soft fade (0.4 s), and a clean end of its own when it runs out: a shield fizzles, invisibility shimmers
	     back, a trap or peel folds away, a cloud thins out, a glow fades (power_end).
	The look is the one the powers had before the Oct 19 renames (owner, Oct 20: "bring back the nice effects with the
	power ups, because right now it just looks like a bare copy, i mean just keep the same effects, change the name"):
	pink and purple, with hearts. The new names and rules stay (Speed Boost only while carrying, the Bear Trap thrown).
	  Shield:      (was Heart Shield) the glow at the chest bursts into the pink bubble (the server's bubble shows from
	               that moment) with two rings round the middle and hearts; when it runs out it fizzles in a closing
	               ring (ShieldEnd).
	  Speed Boost: (was Rizz Rush) the glow at the feet bursts into a ring that stands up behind the runner and flies
	               back, a ring on the ground and white speed lines (the pink trail is the server's).
	  Bear Trap:   (was Love Trap) the catcher throws (Config/Run.Cast.Throw, Shared/RunMotion): the Love Trap's pink
	               heart disc with its 💘 sign (Shared/BearTrap) leaves the free hand small and flies in an arc, spinning
	               flat, to where the server says it lands; there a pink ring slams out round it and settles to its
	               size, with hearts (the server's disc shows from that moment), and a ring when it arms. It folds away
	               in a puff when it runs out (TrapGone).
	  Slow Wave:   (was Charm Wave) a ring gathers round the catcher, then a wave of two rings runs out to its reach,
	               with hearts (its slow lands on runners as it goes out: PowerService waits the wind-up).
	  Invisible:   the pink glow, then on your own screen a shimmering pink bubble shrinks into the body with a ring and
	               sparkles (other screens: only a faint ring and a few sparks, so it doesn't point at you), and the
	               body fades from the end of the wind-up (character InvisibleFrom; others see a faint shimmer, Seen;
	               you see yourself at Self); the name tag and team outline hide on other screens. Still catchable.
	               When it ends the body shimmers back in with a soft ring.
	  Glitchy:     a pink ring where you were; your screen pushes you forward (Distance in Time, the walls still stop
	               you); everyone sees two see-through ghosts of the body, cyan and magenta, left behind and fading (no
	               flicker), and a ring and sparks where you land.
	  Body Double: a pink ring and sparkles, then every screen makes its own copy of the runner that runs straight on
	               (Shared/RunMotion legs) for Lasts seconds with a pink shimmer over it (a Highlight, white outline,
	               one slow swell a second at most) and a fading afterimage every Powers.BodyDouble.AfterimageEvery
	               (1.2) seconds, never more than one a second (kid-safe), then vanishes in a puff. Only a look.
	  Banana Peel: (new Oct 20) the runner tosses it back over the shoulder (the throw pose): the peel
	               (Shared/BananaPeel) tumbles end over end in a little arc to where the server says, lands with a
	               yellow ring and 🍌; its ring brightens when it can trip someone. A catcher on it slips: a yellow ring, 🍌
	               popping, and three stars circling over the head while they're stuck (character SlipUntil; the
	               Practice Bot too).
	  Smoke Bomb:  (new Oct 20) a little ball dropped at the feet bursts into a big soft lilac cloud (plain balls, a
	               ring on the ground) that breathes slowly, hides the name tags of runners inside it on other screens,
	               and thins out over its last second.
	  Radar:       (new Oct 20) a ring gathers, then a wide ring sweeps out across the floor to its reach; every runner
	               it reaches glows through walls on every screen (a Highlight in its colour, a soft slow swell, never
	               a blink; character SpottedUntil) with a ring closing in at their feet, and fades when it ends.
	  Lasso:       (new Oct 20) the catcher throws (the throw pose); a rope with a loop flies straight ahead. A hit: the
	               loop tightens round the runner and the rope reels them in (their own screen moves them: data.dist
	               in data.time, a LinearVelocity, so walls still stop them; no other screen pushes anybody). A Shield
	               bounces it off in a pink ring. A miss: it reels back in.
	The ghosts and afterimages are Gameplay/Ghosts copies of the body: a hat keeps its mesh (no plain block).
	  ShieldPop:   a blocked stab: the bubble bursts in a pink ring with hearts.
	  TrapSprung:  as the Love Trap's: a ring closes in round the runner's feet and hearts pop.
	  Stun:        three cartoon stars circle slowly over the head of anyone stunned 1 s or more (character
	               StunnedFrom / StunnedUntil). A dive's 0.4 s stun shows none (owner Oct 20 15:13: "without a long
	               unconsiousness"; it was 2 s with stars). The same stars over a catcher who slipped on a peel.
	Each power has its own sound as it goes off (yours loud, others' from where they stand), and other players'
	powers pop their name over them once, above their name tag (your own shows on your card instead).
	Every piece is plain parts (Gameplay/Burst, Shared/BearTrap, Shared/BananaPeel), so it all looks right before any
	picture is uploaded.
]]
local M = {}

function M.start()
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local Workspace = game:GetService("Workspace")
	local Players = game:GetService("Players")
	local RunService = game:GetService("RunService")
	local Sfx = require(script.Parent.Sfx)
	local Burst = require(script.Parent.Burst)
	local Ghosts = require(script.Parent.Ghosts)

	local Shared = ReplicatedStorage:WaitForChild("Shared")
	local Net = require(Shared.Net)
	local Powers = require(Shared.Config.Powers)
	local BearTrap = require(Shared.BearTrap)
	local BananaPeel = require(Shared.BananaPeel)
	local okRun, RunMotion = pcall(require, Shared.RunMotion)
	local AbilityRules = require(Shared.AbilityRules)
	local RoundNet = Net.get("Round") :: RemoteEvent
	local FX = Powers.Fx
	local WHITE, PINK, PURPLE = FX.Core, FX.Glow, FX.Edge
	local UP = Vector3.new(0, 1, 0)
	local NEAR = 180 -- studs: casts further from the camera than this are skipped

	local function timing(name: string)
		local own = FX[name] or {}
		return own.WindUp or FX.WindUp, FX.Flash, own.Burst or FX.Burst, FX.Fade
	end

	local function rootOf(id: number?): BasePart?
		local p = id and Players:GetPlayerByUserId(id)
		local root = p and p.Character and p.Character:FindFirstChild("HumanoidRootPart")
		return if root and root:IsA("BasePart") then root else nil
	end

	local function near(at: Vector3): boolean
		local cam = Workspace.CurrentCamera
		return cam ~= nil and (cam.CFrame.Position - at).Magnitude < NEAR
	end

	local function flatLook(root: BasePart): Vector3
		local look = root.CFrame.LookVector
		local flat = Vector3.new(look.X, 0, look.Z)
		return if flat.Magnitude > 0.01 then flat.Unit else Vector3.new(0, 0, -1)
	end

	-- The free (left) hand, for throws.
	local function handOf(root: BasePart): () -> Vector3
		return function()
			local c = root.Parent
			local h = c and c:FindFirstChild("LeftHand")
			return if h and h:IsA("BasePart") then h.Position else root.Position + UP * 1.2 - root.CFrame.RightVector * 1.2
		end
	end

	-- Little glyphs flying out of a point and fading (emoji, so they read before any picture is uploaded).
	local function glyphs(at: Vector3, count: number, glyph: string, spread: number)
		for i = 1, count do
			local angle = (i / count) * math.pi * 2
			local out = Vector3.new(math.cos(angle) * spread, 1.6 + (i % 3) * 0.7, math.sin(angle) * spread)
			local holder = Instance.new("Part")
			holder.Anchored, holder.CanCollide, holder.CanQuery, holder.CanTouch = true, false, false, false
			holder.Transparency = 1
			holder.Size = Vector3.new(0.2, 0.2, 0.2)
			holder.CFrame = CFrame.new(at)
			holder.Parent = Burst.home()
			local gui = Instance.new("BillboardGui")
			gui.Size = UDim2.new(1.3, 0, 1.3, 0)
			gui.LightInfluence = 0
			gui.Parent = holder
			local label = Instance.new("TextLabel")
			label.Size = UDim2.fromScale(1, 1)
			label.BackgroundTransparency = 1
			label.Text = glyph
			label.TextScaled = true
			label.Parent = gui
			Burst.run(0.8, function(_, k)
				holder.CFrame = CFrame.new(at + out * Burst.ease(k))
				label.TextTransparency = math.clamp((k - 0.45) / 0.55, 0, 1)
			end, function() holder:Destroy() end)
		end
	end

	-- Small glowing motes (plain neon balls): `count` of them spiral from `spread` studs out into `to()` over `time`
	-- (gathering), or with outward = true drift up and away from it and fade (a puff). Seen in the film too.
	local function motes(to: () -> Vector3, count: number, spread: number, time: number, color: Color3, outward: boolean?)
		for i = 1, count do
			local mote = Burst.piece(if i % 2 == 0 then WHITE else color, Enum.PartType.Ball)
			local a0 = (i / count) * math.pi * 2
			local h0 = ((i * 37) % 5) * 0.35 - 0.6
			Burst.run(time, function(_, k)
				local e = if outward then Burst.ease(k) else 1 - Burst.ease(k, "in")
				local a = a0 + (if outward then 0.6 else 1.6) * k
				local r = spread * e
				local c = to()
				mote.CFrame = CFrame.new(c + Vector3.new(math.cos(a) * r, h0 * e + (if outward then 1.4 * k else 0), math.sin(a) * r))
				mote.Size = Vector3.one * (if outward then 0.28 * (1 - 0.6 * k) else 0.16 + 0.14 * k)
				mote.Transparency = if outward then 0.1 + 0.9 * k ^ 1.4 else 0.6 - 0.5 * k
			end, function() mote:Destroy() end)
		end
	end

	-- Hides parts on this screen until the bright frame (the server made them the moment you pressed).
	local function hideUntil(parts: { BasePart }, seconds: number)
		for _, p in parts do
			p.LocalTransparencyModifier = 1
		end
		task.delay(seconds, function()
			for _, p in parts do
				if p.Parent then p.LocalTransparencyModifier = 0 end
			end
		end)
	end

	-- The wind-up glow and the bright frame. `at` gives the glow's spot each frame. The effect itself starts after
	-- `wind` (the caller waits). With gather = the feet's height under the body, a ring closes in round the feet and
	-- motes spiral in to the glow too (the longer wind-ups: you see it coming).
	local function windUp(at: (number) -> Vector3, wind: number, flash: number, size: number, color: Color3, feet: (() -> CFrame)?)
		local bright = false
		if feet and wind >= 0.2 then
			Burst.ring(feet(), {
				r0 = 3.4, r1 = 0.9, time = wind + flash, ease = "in", width = 0.1, glow = 0.42, color = color, fade = 0.2,
				alpha = 0.25, follow = function() return feet() end, segs = 16,
			})
			motes(function() return at(1) end, 6, 2.6, wind, color)
		end
		return Burst.orb({
			at = at, time = wind + flash, color = color, range = 12, glowScale = 2,
			size = function(k)
				local t = k * (wind + flash)
				if t >= wind then
					if not bright then bright = Burst.flashOk() end
					return if bright then size * 2.4 else size
				end
				return size * (0.25 + 0.75 * Burst.ease(t / wind, "in"))
			end,
			alpha = function(k)
				local t = k * (wind + flash)
				return if t >= wind and bright then 0.3 else 0.85 - 0.3 * math.clamp(t / wind, 0, 1) -- (a see-through glow, never a solid ball)
			end,
			light = function(k)
				local t = k * (wind + flash)
				return if t >= wind and bright then 5 else 2.2 * math.clamp(t / wind, 0, 1)
			end,
		})
	end

	-- A clean end: a ring closing in and a few motes drifting up and fading where something ran out.
	local function fizzle(at: Vector3, color: Color3, size: number)
		Burst.ring(CFrame.new(at), {
			r0 = size, r1 = size * 0.25, time = 0.45, ease = "quart", width = 0.1, glow = 0.45, color = color, fade = 0.6, segs = 16,
		})
		motes(function() return at end, 5, size * 0.5, 0.7, color, true)
	end

	-- Copies of a character's visible parts, anchored where they are now, in one glowing colour: ghosts (Gameplay/Ghosts).
	local function ghostOf(character: Model, color: Color3): { { part: BasePart, at: CFrame } }
		return Ghosts.copy(character, color, Burst.home())
	end

	local function feetOf(root: BasePart, drop: number?): () -> CFrame
		return function() return CFrame.new(root.Position - UP * (drop or 2.8)) end
	end

	local CAST = {}

	function CAST.Shield(root: BasePart, _data, wind, flash, burst, fade, color)
		local bubble = Workspace:FindFirstChild("HuzzShields")
		local mine = {}
		if bubble then
			for _, b in bubble:GetChildren() do
				if b:IsA("BasePart") and (b.Position - root.Position).Magnitude < 1.5 then table.insert(mine, b) end
			end
		end
		hideUntil(mine, wind + flash + burst * 0.6)
		local chest = function() return root.Position + UP * 0.6 end
		windUp(chest, wind, flash, 0.9, color, feetOf(root))
		task.delay(wind + flash, function()
			if not root.Parent then return end
			-- the bubble grows out with a little overshoot, then the server's one takes over
			local shell = Burst.piece(color, Enum.PartType.Ball)
			shell.Material = Enum.Material.ForceField
			Burst.run(burst + fade, function(age, k)
				local g = math.clamp(age / burst, 0, 1)
				shell.CFrame = CFrame.new(root.Position)
				shell.Size = Vector3.one * (1.5 + 6.1 * Burst.ease(g, "back"))
				shell.Transparency = if age > burst then (age - burst) / fade else 0
				shell.Color = color:Lerp(PURPLE, k)
			end, function() shell:Destroy() end)
			Burst.ring(CFrame.new(root.Position), {
				r0 = 0.8, r1 = 4.4, time = burst + fade, ease = "quart", width = 0.16, glow = 0.6, color = color,
				fade = fade / (burst + fade) + 0.25, follow = function() return CFrame.new(root.Position) end,
			})
			task.delay(0.12, function() -- (a second, thinner ring a beat later: it lands with weight)
				Burst.ring(CFrame.new(root.Position + UP * 0.8), {
					r0 = 1, r1 = 5.2, time = burst + fade, ease = "quart", width = 0.08, glow = 0.4, color = PURPLE,
					fade = 0.55, alpha = 0.3, segs = 20, follow = function() return CFrame.new(root.Position + UP * 0.8) end,
				})
			end)
			glyphs(root.Position + UP, 6, "💖", 3)
		end)
	end

	function CAST.SpeedBoost(root: BasePart, _data, wind, flash, burst, fade, color)
		local feet = function() return root.Position - UP * 2.2 end
		windUp(feet, wind, flash, 0.8, color)
		task.delay(wind + flash, function()
			if not root.Parent then return end
			local look = flatLook(root)
			local start = root.Position
			-- a ring standing up across the run, flying back from the runner (its plane faces the way they run)
			local function standing(back: number): CFrame
				local c = start - look * back
				return CFrame.lookAt(c, c + look) * CFrame.Angles(math.rad(90), 0, 0)
			end
			Burst.ring(standing(0), {
				r0 = 1.2, r1 = 4.2, time = burst + fade, ease = "quart", width = 0.16, glow = 0.65, color = color,
				fade = fade / (burst + fade) + 0.3, follow = nil,
			})
			Burst.ring(CFrame.new(start - UP * 2.8), { -- (the push off the ground)
				r0 = 0.8, r1 = 3.2, time = 0.5, ease = "quart", width = 0.1, glow = 0.45, color = color, fade = 0.55, segs = 16,
			})
			-- white speed lines behind the body, thin, streaming back and fading
			local right = look:Cross(UP).Unit
			for i = 1, 6 do
				local line = Burst.piece(WHITE)
				local side = (i - 3.5) * 0.55
				local up = ((i * 37) % 5) * 0.45 - 1.2
				Burst.run(burst + fade, function(age, k)
					local base = root.Position - look * (1.2 + 3 * Burst.ease(k)) + right * side + UP * up
					line.Size = Vector3.new(0.08, 0.08, 3.6 * (1 - 0.5 * k))
					line.CFrame = CFrame.lookAt(base, base + look)
					line.Color = WHITE:Lerp(color, k)
					line.Transparency = 0.1 + 0.9 * k ^ 1.5
				end, function() line:Destroy() end)
			end
		end)
	end

	-- The throw: the trap leaves the free (left) hand at the end of the wind-up and flies in an arc to `data.at`,
	-- landing data.flight after the press (when the server's trap appears there), tumbling once on the way.
	function CAST.BearTrap(root: BasePart, data, wind, flash, _burst, _fade, color)
		local def = Powers.BearTrap
		local spot = if typeof(data.at) == "Vector3" then data.at else root.Position - UP * 3
		local flight = math.max((data.flight or def.Flight) - wind - flash, 0.15)
		local hand = handOf(root)
		windUp(hand, wind, flash, 0.5, color, feetOf(root))
		local dir = if typeof(data.dir) == "Vector3" then data.dir else flatLook(root)
		local yaw = math.atan2(-dir.X, -dir.Z)
		task.delay(wind + flash, function()
			local from = hand()
			local model = BearTrap.build(color)
			BearTrap.arm(model, false)
			model.Parent = Burst.home()
			local scale0 = 0.25 -- (small in the hand, full size as it lands)
			Burst.run(flight, function(age)
				local s = math.clamp(age / flight, 0, 1)
				local p = from:Lerp(spot, s) + UP * (def.Arc * 4 * s * (1 - s))
				local spin = CFrame.Angles(0, (1 - s) * math.pi * 3, 0) * CFrame.Angles(-(1 - s) * 0.5, 0, 0) -- (spins flat like a frisbee, tipped back, level as it lands)
				BearTrap.pose(model, CFrame.new(p) * CFrame.Angles(0, yaw, 0) * spin, 0, scale0 + (1 - scale0) * Burst.ease(s))
			end, function()
				model:Destroy()
				-- landed: the ring slams out round the trap and settles to its size, hearts, a clack; then it arms
				Burst.ring(CFrame.new(spot + UP * 0.15), {
					r0 = 0.6, r1 = def.Radius + 0.4, time = 0.6, ease = "back", width = 0.2, glow = 0.8, color = color,
					fade = 0.5,
				})
				glyphs(spot + UP * 0.8, 5, "💘", 1.8)
				if near(spot) then Sfx.play("trap_set", { at = root }) end
				task.delay(def.Arm, function()
					Burst.ring(CFrame.new(spot + UP * 0.08), {
						r0 = def.Radius + 0.6, r1 = def.Radius, time = 0.35, ease = "quart", width = 0.1, glow = 0.45,
						color = PURPLE, fade = 0.45, segs = 20,
					})
				end)
			end)
		end)
	end

	function CAST.SlowWave(root: BasePart, data, wind, flash, burst, fade, color)
		local radius = data.radius or Powers.SlowWave.Radius
		local ground = function() return CFrame.new(root.Position - UP * 2.8) end
		windUp(function() return root.Position + UP * 0.4 end, wind, flash, 0.9, color)
		-- the gather: a ring closing in round the catcher, motes spiralling in
		Burst.ring(ground(), {
			r0 = 4.5, r1 = 1.4, time = wind, ease = "in", width = 0.12, glow = 0.45, color = color, fade = 0.15,
			alpha = 0.2, follow = ground, segs = 16,
		})
		motes(function() return root.Position + UP * 0.4 end, 6, 3.5, wind, color)
		task.delay(wind + flash, function()
			if not root.Parent then return end
			local at = ground()
			Burst.ring(at, {
				-- (16 pieces a ring and no haze under it: it was ~200 neon parts moved one by one every frame)
				r0 = 1.4, r1 = radius, time = burst + fade, ease = "quart", width = 0.24, glow = 1.1, color = color,
				fade = fade / (burst + fade) + 0.3, segs = 16,
			})
			task.delay(0.09, function()
				Burst.ring(at, {
					r0 = 1, r1 = radius * 0.86, time = burst + fade, ease = "quart", width = 0.1, glow = 0.6,
					color = PURPLE, fade = fade / (burst + fade) + 0.35, segs = 16, alpha = 0.3,
				})
			end)
			glyphs(root.Position + UP, 6, "💞", 4)
		end)
	end

	function CAST.Invisible(root: BasePart, _data, wind, flash, burst, fade, color, mine)
		windUp(function() return root.Position + UP * 0.6 end, wind, flash, 0.8, color, if mine then feetOf(root) else nil)
		task.delay(wind + flash, function()
			if not root.Parent then return end
			if not mine then
				-- other screens: only a faint ring at the feet and a few sparks (a big bubble with hearts would
				-- point at the runner who is about to vanish)
				Burst.ring(CFrame.new(root.Position - UP * 2.6), {
					r0 = 0.8, r1 = 3.4, time = burst + fade, ease = "quart", width = 0.12, glow = 0.5, color = color,
					fade = 0.6, segs = 16, alpha = 0.25,
				})
				Burst.sparks(root.Position, { WHITE, color }, 8)
				return
			end
			-- your own screen: a shimmering bubble that shrinks into the body as it fades out of sight
			local shell = Burst.piece(color, Enum.PartType.Ball)
			shell.Material = Enum.Material.ForceField
			Burst.run(burst + fade, function(age, k)
				shell.CFrame = CFrame.new(root.Position)
				shell.Size = Vector3.one * (6.4 - 4.6 * Burst.ease(k))
				shell.Transparency = math.clamp((age - burst * 0.5) / (burst * 0.5 + fade), 0, 1)
				shell.Color = color:Lerp(PURPLE, k)
			end, function() shell:Destroy() end)
			Burst.ring(CFrame.new(root.Position - UP * 2.6), {
				r0 = 0.8, r1 = 3.4, time = burst + fade, ease = "quart", width = 0.14, glow = 0.6, color = color,
				fade = 0.6, segs = 16,
			})
			Burst.sparks(root.Position, { WHITE, color, PURPLE }, 12)
			glyphs(root.Position + UP, 5, "✨", 2.6)
		end)
	end

	-- Two ghosts of the body (cyan and magenta, a little apart) left where you were, fading; your own screen pushes
	-- you forward (the walls stop you, as with the huss).
	local CYAN, MAGENTA = Color3.fromRGB(78, 240, 224), Color3.fromRGB(255, 80, 200)
	function CAST.Glitchy(root: BasePart, data, wind, flash, _burst, _fade, color, mine)
		local def = Powers.Glitchy
		local character = root.Parent :: Model
		windUp(function() return root.Position + UP * 0.4 end, wind, flash, 0.6, color)
		task.delay(wind, function()
			if not (character and root.Parent) then return end
			local dir = if typeof(data.dir) == "Vector3" then data.dir else flatLook(root)
			local right = dir:Cross(UP).Unit
			Burst.ring(CFrame.new(root.Position - UP * 2.6), {
				r0 = 0.6, r1 = 3, time = 0.45, ease = "quart", width = 0.14, glow = 0.6, color = color, fade = 0.5, segs = 16,
			})
			task.delay(def.Time + 0.02, function() -- where you land: a ring and sparks
				if not root.Parent then return end
				Burst.sparks(root.Position, { WHITE, color, PURPLE }, 10)
				Burst.ring(CFrame.new(root.Position - UP * 2.6), {
					r0 = 2.6, r1 = 0.8, time = 0.35, ease = "quart", width = 0.12, glow = 0.5, color = CYAN, fade = 0.55, segs = 16,
				})
			end)
			for i, tint in { CYAN, MAGENTA } do
				local shift = right * (if i == 1 then -0.35 else 0.35)
				local ghosts = ghostOf(character, tint)
				Burst.run(0.45, function(_, k)
					for _, g in ghosts do
						g.part.CFrame = g.at + shift * (1 + k) - dir * (0.6 * k)
						g.part.Transparency = 0.55 + 0.45 * Burst.ease(k)
					end
				end, function()
					for _, g in ghosts do g.part:Destroy() end
				end)
			end
			-- thin glitch slivers across the start, cyan and magenta, sliding apart
			for i = 1, 5 do
				local bar = Burst.piece(if i % 2 == 0 then MAGENTA else CYAN)
				local y = (i - 3) * 0.7
				local at = root.Position + UP * y
				Burst.run(0.35, function(_, k)
					bar.Size = Vector3.new(2.6 * (1 - 0.4 * k), 0.08, 0.08)
					bar.CFrame = CFrame.lookAt(at, at + dir) * CFrame.new((i % 2 * 2 - 1) * 0.8 * k, 0, 0)
					bar.Transparency = 0.2 + 0.8 * k
				end, function() bar:Destroy() end)
			end
			if mine and not root.Anchored then
				-- the blink: a hard push along the ground for Time seconds (a LinearVelocity, so walls stop it)
				local attachment = Instance.new("Attachment")
				attachment.Name = "HuzzGlitch"
				attachment.Parent = root
				local lv = Instance.new("LinearVelocity")
				lv.Name = "HuzzGlitch"
				lv.Attachment0 = attachment
				lv.RelativeTo = Enum.ActuatorRelativeTo.World
				lv.VelocityConstraintMode = Enum.VelocityConstraintMode.Plane
				lv.PrimaryTangentAxis = Vector3.xAxis
				lv.SecondaryTangentAxis = Vector3.zAxis
				lv.MaxForce = 1e6
				local v = dir * (def.Distance / def.Time)
				lv.PlaneVelocity = Vector2.new(v.X, v.Z)
				lv.Parent = root
				task.delay(def.Time, function()
					lv:Destroy()
					attachment:Destroy()
				end)
			end
		end)
	end

	-- A copy of the runner that runs straight on, then vanishes in a puff (this screen only: a look).
	local DOUBLE_SWELL = 1.4 -- seconds a shimmer swell takes (kid-safe: slower than once a second)
	local DOUBLE_GHOST = math.max(1, Powers.BodyDouble.AfterimageEvery or 1.2) -- seconds between afterimages (one a second at most)
	function CAST.BodyDouble(root: BasePart, data, wind, flash, _burst, _fade, color)
		local def = Powers.BodyDouble
		local character = root.Parent :: Model
		windUp(function() return root.Position + UP * 0.6 end, wind, flash, 0.8, color, feetOf(root))
		task.delay(wind + flash, function()
			if not (character and character.Parent and root.Parent) then return end
			local was = character.Archivable
			character.Archivable = true
			local ok, copy = pcall(function() return character:Clone() end)
			character.Archivable = was
			if not ok or not copy then return end
			for _, d in copy:GetDescendants() do
				if d:IsA("BaseScript") or d:IsA("Sound") or d:IsA("LinearVelocity") or d:IsA("Constraint") and not d:IsA("Motor6D") then
					d:Destroy()
				elseif d:IsA("BasePart") then
					d.Anchored = d.Name == "HumanoidRootPart"
					d.CanCollide, d.CanQuery, d.CanTouch = false, false, false
				end
			end
			local h = copy:FindFirstChildOfClass("Humanoid")
			if h then
				h.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
				h.PlatformStand = true
				local animator = h:FindFirstChildOfClass("Animator")
				if animator then animator:Destroy() end
			end
			local copyRoot = copy:FindFirstChild("HumanoidRootPart") :: BasePart?
			if not copyRoot then copy:Destroy() return end
			copy.Name = "HuzzBodyDouble"
			for _, d in copy:GetDescendants() do -- (the runner's own name tag and outline stay off the copy)
				if (d:IsA("BillboardGui") and d.Name == "HuzzTag") or d:IsA("Highlight") then d:Destroy() end
			end
			-- the shimmer: a pink Highlight with a white outline, swelling softly (one swell in Swell seconds, never a blink)
			local glow = Instance.new("Highlight")
			glow.Name = "HuzzDoubleGlow"
			glow.FillColor, glow.OutlineColor = color, WHITE
			glow.FillTransparency, glow.OutlineTransparency = 0.7, 0.15
			glow.DepthMode = Enum.HighlightDepthMode.Occluded
			glow.Adornee = copy
			glow.Parent = copy
			copy.Parent = Burst.home()
			local dir = if typeof(data.dir) == "Vector3" then data.dir else flatLook(root)
			local speed = if type(data.speed) == "number" then data.speed else 24
			local params = RaycastParams.new()
			params.FilterType = Enum.RaycastFilterType.Exclude
			params.FilterDescendantsInstances = { character, copy, Burst.home() }
			params.RespectCanCollide = true
			local under = Workspace:Raycast(root.Position, Vector3.new(0, -12, 0), params)
			local height = if under then root.Position.Y - under.Position.Y else 3 -- (root above the floor)
			local pos = copyRoot.Position
			local yaw = math.atan2(-dir.X, -dir.Z)
			local motion = okRun and RunMotion.new(copy) or nil
			local lasts = if type(data.lasts) == "number" then data.lasts else def.Lasts
			local puffed = false
			local function puff()
				if puffed then return end
				puffed = true
				Burst.sparks(copyRoot.Position, { WHITE, color }, 12)
				Burst.ring(CFrame.new(copyRoot.Position - UP * (height - 0.2)), {
					r0 = 0.6, r1 = 3, time = 0.45, ease = "quart", width = 0.12, glow = 0.5, color = color, fade = 0.5, segs = 16,
				})
				motes(function() return copyRoot.Position end, 6, 1.6, 0.7, color, true)
				local parts = {}
				for _, d in copy:GetDescendants() do
					if d:IsA("BasePart") or d:IsA("Decal") then table.insert(parts, d) end
				end
				glyphs(copyRoot.Position + UP * 0.5, 4, "✨", 2)
				if near(copyRoot.Position) then Sfx.play("power_end", { at = copyRoot }) end
				Burst.run(0.35, function(_, k)
					for _, p in parts do p.LocalTransparencyModifier = 0.15 + 0.85 * k end
					glow.FillTransparency, glow.OutlineTransparency = 0.7 + 0.3 * k, 0.15 + 0.85 * k
				end, function() copy:Destroy() end)
			end
			for _, d in copy:GetDescendants() do -- (a touch see-through: a projection, not a person)
				if d:IsA("BasePart") or d:IsA("Decal") then d.LocalTransparencyModifier = 0.15 end
			end
			local t0 = os.clock()
			local nextGhost = 0.2
			local conn
			conn = RunService.Heartbeat:Connect(function(dt)
				if puffed or not copy.Parent then conn:Disconnect() return end
				local age = os.clock() - t0
				glow.FillTransparency = 0.7 - 0.12 * math.sin(age * 2 * math.pi / DOUBLE_SWELL) -- (a soft swell, slower than once a second)
				if age >= nextGhost then -- an afterimage left behind now and then, fading
					nextGhost += DOUBLE_GHOST
					local ghosts = ghostOf(copy, color)
					Burst.run(0.35, function(_, k)
						for _, g in ghosts do g.part.Transparency = 0.7 + 0.3 * k end
					end, function()
						for _, g in ghosts do g.part:Destroy() end
					end)
				end
				if os.clock() - t0 >= lasts then
					conn:Disconnect()
					puff()
					return
				end
				-- run on along the floor; a wall ahead ends it early
				local step = dir * speed * dt
				if Workspace:Raycast(pos, dir * (step.Magnitude + 1.2), params) then
					conn:Disconnect()
					puff()
					return
				end
				pos += step
				local floor = Workspace:Raycast(pos + UP * 2, Vector3.new(0, -8, 0), params)
				if floor then pos = Vector3.new(pos.X, floor.Position.Y + height, pos.Z) end
				copyRoot.CFrame = CFrame.new(pos) * CFrame.Angles(0, yaw, 0)
				if motion then RunMotion.step(motion, dt, speed, true, false) end
			end)
			Burst.sparks(root.Position, { WHITE, color, PURPLE }, 10)
			Burst.ring(CFrame.new(root.Position - UP * (height - 0.2)), {
				r0 = 0.6, r1 = 3.2, time = 0.5, ease = "quart", width = 0.14, glow = 0.6, color = color, fade = 0.5, segs = 16,
			})
			glyphs(root.Position + UP * 0.5, 4, "✨", 2.2)
		end)
	end

	-- The Banana Peel: tossed back over the shoulder from the free hand, tumbling in a little arc to data.at, landing
	-- data.land after the press (when the server's peel appears there) with a ring and 🍌.
	local YELLOW = Powers.BananaPeel.Accent
	function CAST.BananaPeel(root: BasePart, data, wind, flash, _burst, _fade, color)
		local def = Powers.BananaPeel
		local spot = if typeof(data.at) == "Vector3" then data.at else root.Position - UP * 3
		local hand = handOf(root)
		windUp(hand, wind, flash, 0.45, YELLOW, feetOf(root)) -- (its own colour, as the cards: the film showed pink)
		local dir = if typeof(data.dir) == "Vector3" then data.dir else flatLook(root)
		local yaw = math.atan2(-dir.X, -dir.Z)
		local flight = math.max((data.land or (wind + flash + 0.3)) - wind - flash, 0.15)
		task.delay(wind + flash, function()
			local from = hand()
			local model = BananaPeel.build()
			BananaPeel.arm(model, false)
			model.Parent = Burst.home()
			Burst.run(flight, function(age)
				local s = math.clamp(age / flight, 0, 1)
				local p = from:Lerp(spot, s) + UP * (2.2 * 4 * s * (1 - s))
				local tumble = CFrame.Angles((1 - s) * math.pi * 2, 0, 0) -- (one flip end over end, flat as it lands)
				BananaPeel.pose(model, CFrame.new(p) * CFrame.Angles(0, yaw, 0) * tumble, 0.45 + 0.55 * Burst.ease(s))
			end, function()
				model:Destroy()
				-- landed (the server's peel shows from now): a ring snaps out round it, 🍌, a soft plop
				Burst.ring(CFrame.new(spot + UP * 0.12), {
					r0 = 0.4, r1 = def.Radius + 0.3, time = 0.5, ease = "back", width = 0.14, glow = 0.6, color = YELLOW,
					edge = Color3.fromRGB(255, 170, 40), fade = 0.5, segs = 16,
				})
				glyphs(spot + UP * 0.6, 3, "🍌", 1.4)
				if near(spot) then Sfx.play("trap_set", { at = root, pitch = 1.05 }) end
				task.delay(def.Arm, function()
					Burst.ring(CFrame.new(spot + UP * 0.06), {
						r0 = def.Radius + 0.5, r1 = def.Radius, time = 0.35, ease = "quart", width = 0.08, glow = 0.35,
						color = YELLOW, fade = 0.45, segs = 16,
					})
				end)
			end)
		end)
	end

	-- Smoke clouds on this screen: { at, radius, from, untilT } (name tags of runners inside hide on other screens).
	local clouds = {}
	local LILAC = { Color3.fromRGB(196, 184, 226), Color3.fromRGB(226, 218, 244), Color3.fromRGB(176, 160, 212) }
	function CAST.SmokeBomb(root: BasePart, data, wind, flash, _burst, _fade, color)
		local def = Powers.SmokeBomb
		local radius = if type(data.radius) == "number" then data.radius else def.Radius
		local lasts = if type(data.lasts) == "number" then data.lasts else def.Lasts
		local at = if typeof(data.at) == "Vector3" then data.at else root.Position - UP * 3
		local hand = handOf(root)
		windUp(hand, wind, flash, 0.45, def.Accent or LILAC[1], feetOf(root))
		local t0 = Workspace:GetServerTimeNow()
		table.insert(clouds, { at = at, radius = radius, from = t0 + wind + flash, untilT = t0 + wind + flash + lasts })
		task.delay(wind + flash, function()
			-- the little ball drops from the hand to the feet
			local ball = Burst.piece(Color3.fromRGB(70, 56, 96), Enum.PartType.Ball)
			ball.Material = Enum.Material.SmoothPlastic
			ball.Size = Vector3.one * 0.6
			local from = hand()
			Burst.run(0.14, function(_, k)
				ball.CFrame = CFrame.new(from:Lerp(at + UP * 0.3, k * k))
			end, function() ball:Destroy() end)
			task.delay(0.14, function()
				Burst.ring(CFrame.new(at + UP * 0.15), {
					r0 = 1, r1 = radius + 1, time = 0.7, ease = "quart", width = 0.16, glow = 0.7, color = color, fade = 0.55, segs = 20,
				})
				-- the cloud: soft balls that puff out, breathe slowly while it lasts, then thin out over its last second
				local n = 13
				for i = 1, n do
					local puffPart = Burst.piece(LILAC[i % 3 + 1], Enum.PartType.Ball)
					puffPart.Material = Enum.Material.SmoothPlastic
					local a = i * 2.39996 -- (golden angle: spread evenly)
					local r = radius * 0.72 * math.sqrt(i / n)
					local home = at + Vector3.new(math.cos(a) * r, 1.4 + ((i * 53) % 7) * 0.5, math.sin(a) * r)
					local size = 4.6 + ((i * 29) % 5) * 0.7
					local life = lasts - 0.14
					Burst.run(life, function(age)
						local grow = Burst.ease(math.clamp(age / 0.5, 0, 1), "back")
						local out = math.clamp((age - (life - 1)) / 1, 0, 1) -- (the last second: thins out)
						local breathe = 1 + 0.05 * math.sin(age * 2 * math.pi / 2.4 + i)
						local drift = UP * (0.25 * age) + (home - at) * 0.04 * age
						puffPart.CFrame = CFrame.new(home + drift)
						puffPart.Size = Vector3.one * math.max(0.3, size * (0.15 + 0.85 * grow) * breathe * (1 + 0.15 * out))
						puffPart.Transparency = 0.12 + 0.2 * (i % 3) / 2 + 0.88 * out ^ 1.3
					end, function() puffPart:Destroy() end)
				end
			end)
		end)
	end

	-- Radar: a wide ring sweeps out over the floor to its reach (the glow on the runners is drawn every frame below,
	-- from their character SpottedUntil).
	local RADAR = Powers.Radar.Accent
	function CAST.Radar(root: BasePart, data, wind, flash, _burst, fade, color)
		local range = if type(data.range) == "number" then data.range else Powers.Radar.Range
		local sweep = if type(data.sweep) == "number" then data.sweep else Powers.Radar.Sweep
		windUp(function() return root.Position + UP * 1.2 end, wind, flash, 0.8, RADAR, feetOf(root))
		task.delay(wind + flash, function()
			if not root.Parent then return end
			local at = CFrame.new(root.Position - UP * 2.75)
			Burst.ring(at, {
				r0 = 1.5, r1 = range, time = sweep + fade, ease = "quad", width = 0.3, glow = 1.3, color = RADAR, edge = color,
				fade = fade / (sweep + fade) + 0.2, segs = 72, -- (40 broke into dots at 70 studs, film Oct 20)
			})
			task.delay(0.12, function()
				Burst.ring(at, {
					r0 = 1, r1 = range * 0.92, time = sweep + fade, ease = "quad", width = 0.1, glow = 0.5, color = WHITE,
					edge = RADAR, fade = 0.5, segs = 56, alpha = 0.4,
				})
			end)
			Burst.ring(CFrame.new(root.Position + UP * 2.6) * CFrame.Angles(math.rad(90), 0, 0), { -- (a pulse off the head)
				r0 = 0.4, r1 = 2.2, time = 0.5, ease = "quart", width = 0.08, glow = 0.4, color = RADAR, fade = 0.6, segs = 16,
			})
		end)
	end

	-- Lassos in flight on this screen, by catcher id: { rope, loop ring parts, state, ... }. States: "out" (flying),
	-- "hit" (the loop snaps tight round the runner while they're pulled in), "drop" (a miss: the loop falls to the
	-- floor with a puff and MISSED), "back" (reeling in).
	local ROPE = Color3.fromRGB(246, 196, 120) -- (a warm light rope, 0.4 thick to read across the field: critic Oct 20)
	local ROPE_W = 0.4
	local lassos = {}
	local function endLasso(id: number)
		local l = lassos[id]
		if not l then return end
		lassos[id] = nil
		l.done = true
	end
	function CAST.Lasso(root: BasePart, data, wind, flash, _burst, _fade, color, _mine, id)
		local def = Powers.Lasso
		local dir = if typeof(data.dir) == "Vector3" then data.dir else flatLook(root)
		local speed = if type(data.speed) == "number" then data.speed else def.Speed
		local range = if type(data.range) == "number" then data.range else def.Range
		local hand = handOf(root)
		local feet = feetOf(root)
		windUp(hand, wind, flash, 0.45, def.Accent, feet)
		task.delay(wind + flash, function()
			if not root.Parent then return end
			endLasso(id) -- (an old one still out ends)
			local floorY = feet().Position.Y
			local rope = Burst.piece(ROPE)
			rope.Material = Enum.Material.SmoothPlastic
			local loop = {}
			for i = 1, 14 do
				local seg = Burst.piece(ROPE)
				seg.Material = Enum.Material.SmoothPlastic
				loop[i] = seg
			end
			local l = { state = "out", t0 = os.clock(), tip = hand(), loopR = 1.1 }
			lassos[id] = l
			local maxLife = range / speed + 2
			Burst.run(maxLife, function(age)
				local h = hand()
				if l.state == "out" then
					local reach = math.min(age * speed, range)
					l.tip = h + dir * reach + UP * (-0.6 * reach / range) -- (it dips a little as it flies)
					if reach >= range or l.missed then l.state, l.from, l.dropT = "drop", l.tip, age end -- (a miss)
				elseif l.state == "hit" and l.target and l.target.Parent then
					l.tip = l.target.Position + UP * 0.2
					l.loopR = math.max(1.0, l.loopR - 0.08) -- (snaps tight in a few frames)
					if l.releaseAt and age >= l.releaseAt then l.state, l.from, l.backT = "back", l.tip, age end
				elseif l.state == "drop" then
					-- the loop falls to the floor (0.22 s), puffs with MISSED, lies a moment, then reels in
					local k = math.clamp((age - l.dropT) / 0.22, 0, 1)
					local ground = Vector3.new(l.from.X, floorY + 0.2, l.from.Z)
					l.tip = l.from:Lerp(ground, Burst.ease(k, "in"))
					l.loopR = 1.1 + 0.4 * k -- (it falls open)
					if k >= 1 and not l.landed then
						l.landed = true
						Burst.ring(CFrame.new(ground), {
							r0 = 0.8, r1 = 2.6, time = 0.4, ease = "quart", width = 0.16, glow = 0.3, color = Color3.fromRGB(214, 196, 170), fade = 0.6, segs = 16,
						})
						Burst.pop(ground + UP * 2.2, "MISSED", Color3.fromRGB(200, 200, 210), { height = 0.8, rise = 0.6, time = 0.8 })
						if near(ground) then Sfx.play("power_end", { at = rope }) end
					end
					if age >= l.dropT + 0.55 then l.state, l.from, l.backT = "back", l.tip, age end
				elseif l.state ~= "back" then
					l.state, l.from, l.backT = "back", l.tip, age
				end
				if l.state == "back" then
					local k = math.clamp((age - (l.backT or age)) / 0.3, 0, 1)
					l.tip = (l.from or l.tip):Lerp(h, Burst.ease(k, "in"))
					if k >= 1 then l.done = true end
				end
				local span = l.tip - h
				local len = math.max(span.Magnitude, 0.05)
				rope.Size = Vector3.new(ROPE_W, ROPE_W, len)
				rope.CFrame = CFrame.lookAt(h + span / 2, l.tip)
				rope.Transparency = if l.state == "back" then 0.4 else 0
				-- the snap: the rope and loop go white for a blink as it catches, then back to rope (no flash: a colour)
				local snapping = l.snapUntil ~= nil and os.clock() < l.snapUntil
				rope.Color = if snapping then WHITE else ROPE
				-- the loop: a flat ring of rope at the tip (tightening round a caught runner)
				local r = if l.state == "back" then 0.5 else l.loopR
				for i, seg in loop do
					local a = (i - 0.5) / #loop * math.pi * 2
					seg.Size = Vector3.new(ROPE_W + 0.04, ROPE_W + 0.04, 2 * math.pi * r / #loop * 1.15)
					seg.CFrame = CFrame.new(l.tip) * CFrame.Angles(0, -a, 0) * CFrame.new(r, 0, 0)
					seg.Transparency = rope.Transparency
					seg.Color = rope.Color
				end
				if l.done then error("done") end -- (ends this run; Burst stops it and tidies up)
			end, function()
				rope:Destroy()
				for _, seg in loop do seg:Destroy() end
				if lassos[id] == l then lassos[id] = nil end
			end)
		end)
	end

	-- Invisible bodies, every frame: others fade to Seen with a slow shimmer (once a second at most, a soft swell,
	-- never a blink); you see yourself at Self. Name tags and team outlines hide on other screens meanwhile.
	local faded = {} -- Model -> { mine } while it's invisible
	local function setFade(character: Model, value: number)
		for _, d in character:GetDescendants() do
			if d:IsA("BasePart") or d:IsA("Decal") then
				d.LocalTransparencyModifier = value
			end
		end
	end
	-- A stun of 1 s or more or a slip on a peel, on every screen: three little cartoon stars circling over the head (a
	-- dive's 0.4 s shows none; character StunnedFrom / StunnedUntil from HuzzServer/PowerService.stun, or SlipUntil).
	-- A slow steady turn, no blinking.
	local dazed = {} -- Model -> { holders }
	local STAR = Color3.fromRGB(255, 226, 92)
	local function starsOn(character: Model)
		local list = {}
		for i = 1, 3 do
			local holder = Instance.new("Part")
			holder.Name = "HuzzDazeStar"
			holder.Anchored, holder.CanCollide, holder.CanQuery, holder.CanTouch = true, false, false, false
			holder.Transparency = 1
			holder.Size = Vector3.new(0.2, 0.2, 0.2)
			holder.Parent = Burst.home()
			local gui = Instance.new("BillboardGui")
			gui.Size = UDim2.new(0.9, 0, 0.9, 0)
			gui.LightInfluence = 0
			gui.Parent = holder
			local label = Instance.new("TextLabel")
			label.Size = UDim2.fromScale(1, 1)
			label.BackgroundTransparency = 1
			label.Text = "⭐"
			label.TextColor3 = STAR
			label.TextScaled = true
			label.Parent = gui
			list[i] = holder
		end
		return list
	end
	local function starsOff(character: Model)
		for _, h in dazed[character] or {} do h:Destroy() end
		dazed[character] = nil
	end
	-- Radar's glow on spotted runners: Model -> { glow = Highlight, untilT }
	local spotted = {}
	local extra = {} -- bodies that aren't players' characters but can slip (the Practice Bot), Model -> true
	local tagsHidden = {} -- [Instance] = its own Enabled: name tags and outlines hidden on this screen (invisible, smoke)
	-- A character's name tag (NameTagService puts it on the head) and team outline, into `into`.
	local function hideTags(c: Model, into: { [Instance]: boolean })
		local head = c:FindFirstChild("Head")
		local tag = head and head:FindFirstChild("HuzzTag")
		if tag and tag:IsA("BillboardGui") then into[tag] = true end
		local outline = c:FindFirstChild("HuzzOutline", true)
		if outline and outline:IsA("Highlight") then into[outline] = true end
	end
	local function inCloud(pos: Vector3, t: number): boolean
		for _, c in clouds do
			if t >= c.from and t < c.untilT then
				local d = pos - c.at
				if Vector3.new(d.X, 0, d.Z).Magnitude <= c.radius and math.abs(d.Y) < 9 then return true end
			end
		end
		return false
	end
	local function daze(c: Model, t: number)
		local head = c:FindFirstChild("Head")
		local stunFrom, stunTo = c:GetAttribute("StunnedFrom"), c:GetAttribute("StunnedUntil")
		local slip = c:GetAttribute("SlipUntil")
		local on = (type(stunFrom) == "number" and type(stunTo) == "number" and t >= stunFrom and t < stunTo
			and stunTo - stunFrom >= 1) -- (not a dive's 0.4 s pop up: Config/Round.Lunge.Stun, owner Oct 20 15:13)
			or (type(slip) == "number" and t < slip)
		if head and head:IsA("BasePart") and on and near(head.Position) then
			dazed[c] = dazed[c] or starsOn(c)
			local spin = t * 2 * math.pi / 1.4
			for i, holder in dazed[c] do
				local a = spin + (i - 1) * 2 * math.pi / 3
				holder.CFrame = CFrame.new(head.Position + Vector3.new(math.cos(a) * 1.1, 1.3 + 0.15 * math.sin(a * 2), math.sin(a) * 1.1))
			end
		elseif dazed[c] then
			starsOff(c)
		end
	end
	RunService.Heartbeat:Connect(function()
		local t = Workspace:GetServerTimeNow()
		local me = Players.LocalPlayer
		local def = Powers.Invisible
		for i = #clouds, 1, -1 do
			if t >= clouds[i].untilT then table.remove(clouds, i) end
		end
		local hideNow = {}
		for _, p in Players:GetPlayers() do
			local c = p.Character
			if c then daze(c, t) end
			-- Radar: a glow through walls in its colour while SpottedUntil lasts (a slow swell, fading in and out)
			local spotUntil = c and c:GetAttribute("SpottedUntil")
			if c and type(spotUntil) == "number" and t < spotUntil + 0.3 then
				local rec = spotted[c]
				if not rec then
					local glow = Instance.new("Highlight")
					glow.Name = "HuzzSpotted"
					glow.FillColor, glow.OutlineColor = RADAR, Color3.new(1, 1, 1)
					glow.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
					glow.Adornee = c
					glow.Parent = c
					rec = { glow = glow, from = t }
					spotted[c] = rec
					local root = c:FindFirstChild("HumanoidRootPart")
					if root and root:IsA("BasePart") and near(root.Position) then
						Burst.ring(CFrame.new(root.Position - UP * 2.7), {
							r0 = 3.2, r1 = 1, time = 0.45, ease = "quart", width = 0.12, glow = 0.5, color = RADAR, fade = 0.5, segs = 16,
						})
						Burst.pop(root.Position + UP * 4.2, "📡", RADAR, { height = 1, rise = 0.8, time = 0.9 })
					end
				end
				local into = math.clamp((t - rec.from) / 0.25, 0, 1)
				local out = math.clamp((spotUntil + 0.3 - t) / 0.3, 0, 1)
				local k = math.min(into, out)
				rec.glow.FillTransparency = 1 - k * (0.32 + 0.1 * math.sin(t * 2 * math.pi / 1.6)) -- (one swell in 1.6 s)
				rec.glow.OutlineTransparency = 1 - k
			elseif c and spotted[c] then
				spotted[c].glow:Destroy()
				spotted[c] = nil
			end
			local untilT = c and c:GetAttribute("InvisibleUntil")
			local fromT = c and c:GetAttribute("InvisibleFrom")
			if c and type(untilT) == "number" and t < untilT then
				if not faded[c] then faded[c] = { mine = p == me } end
				if p ~= me then hideTags(c, hideNow) end
				local start = if type(fromT) == "number" then fromT else untilT - def.Lasts
				local fadeIn = math.clamp((t - start) / 0.25, 0, 1)
				local fadeOut = math.clamp((untilT - t) / 0.4, 0, 1)
				local target = if p == me then def.Self else def.Seen + 0.05 * math.sin(t * def.Shimmer * 2 * math.pi)
				setFade(c, target * math.min(fadeIn, fadeOut))
			elseif c and faded[c] then
				setFade(c, 0)
				-- the clean end: it shimmers back in with a soft ring and motes
				local root = c:FindFirstChild("HumanoidRootPart")
				if root and root:IsA("BasePart") and near(root.Position) then
					fizzle(root.Position - UP * 2.6, PINK, 3)
					if faded[c].mine then Sfx.play("power_end") end
				end
				faded[c] = nil
			end
			-- smoke: another player's name tag hides while they stand in a cloud
			if c and p ~= me and #clouds > 0 then
				local root = c:FindFirstChild("HumanoidRootPart")
				if root and root:IsA("BasePart") and inCloud(root.Position, t) then hideTags(c, hideNow) end
			end
		end
		-- (one table keeps each hidden tag's own setting, whichever reason hid it, and puts it back once none does)
		for d in hideNow do
			if tagsHidden[d] == nil then
				tagsHidden[d] = d.Enabled
				d.Enabled = false
			end
		end
		for d, was in tagsHidden do
			if not hideNow[d] then
				if d.Parent then d.Enabled = was end
				tagsHidden[d] = nil
			end
		end
		for body in extra do
			if body.Parent then daze(body, t) else extra[body] = nil; starsOff(body) end
		end
		for c in faded do
			if not c.Parent then faded[c] = nil end
		end
		for c in dazed do
			if not c.Parent then starsOff(c) end
		end
		for c, rec in spotted do
			if not c.Parent then rec.glow:Destroy(); spotted[c] = nil end
		end
	end)

	local SPOKEN = { Shield = true, SpeedBoost = true, BearTrap = true, SlowWave = true, Invisible = true, Glitchy = true, BodyDouble = true,
		BananaPeel = true, SmokeBomb = true, Radar = true, Lasso = true }

	-- The Lasso's pull on your own body (the server says how far, towards where, over how long): a LinearVelocity, so
	-- walls still stop you (as the huss and Glitchy move you). Only while you're still in play and the run is on
	-- (AbilityRules.pullHolds): it lets go the frame you're safe, caught or out, or the round ends.
	local function pullHolds(me): boolean
		return AbilityRules.pullHolds(me:GetAttribute("HuzzStatus"), RoundNet:GetAttribute("Stage"))
	end
	local function pullMe(data)
		local me = Players.LocalPlayer
		local root = me.Character and me.Character:FindFirstChild("HumanoidRootPart")
		if not (root and root:IsA("BasePart")) or root.Anchored or not pullHolds(me) then return end
		local toward, dist, time = data.toward, data.dist, data.time
		if typeof(toward) ~= "Vector3" or type(dist) ~= "number" or type(time) ~= "number" or dist <= 0 or time <= 0 then return end
		local flat = Vector3.new(toward.X - root.Position.X, 0, toward.Z - root.Position.Z)
		if flat.Magnitude < 0.5 then return end
		local v = flat.Unit * (math.min(dist, Powers.Lasso.Pull) / math.min(time, 1))
		local attachment = Instance.new("Attachment")
		attachment.Name = "HuzzLasso"
		attachment.Parent = root
		local lv = Instance.new("LinearVelocity")
		lv.Name = "HuzzLasso"
		lv.Attachment0 = attachment
		lv.RelativeTo = Enum.ActuatorRelativeTo.World
		lv.VelocityConstraintMode = Enum.VelocityConstraintMode.Plane
		lv.PrimaryTangentAxis = Vector3.xAxis
		lv.SecondaryTangentAxis = Vector3.zAxis
		lv.MaxForce = 1e6
		lv.PlaneVelocity = Vector2.new(v.X, v.Z)
		lv.Parent = root
		local stopAt = os.clock() + math.min(time, 1)
		local conn
		conn = RunService.Heartbeat:Connect(function()
			if os.clock() >= stopAt or not lv.Parent or not pullHolds(me) then
				conn:Disconnect()
				lv:Destroy()
				attachment:Destroy()
			end
		end)
	end

	RoundNet.OnClientEvent:Connect(function(kind, data)
		if kind ~= "Power" or type(data) ~= "table" or type(data.name) ~= "string" then return end
		local me = Players.LocalPlayer.UserId
		local mine = data.id == me
		local root = rootOf(data.id)
		if SPOKEN[data.name] and FX[data.name] and CAST[data.name] then
			local fx = FX[data.name]
			local def = Powers[data.name]
			local wind, flash, burst, fade = timing(data.name)
			-- the sound: the wind-up's riser now (the longer ones), the power's own as it goes off
			local heard = mine or (root ~= nil and near(root.Position))
			if heard then
				local volume = if mine then nil else 0.7
				local at = if mine then nil else root
				if fx.Charge then Sfx.play("power_charge", { volume = volume, at = at }) end
				task.delay(if wind >= 0.2 then wind else 0, function()
					Sfx.play(fx.Sound, { pitch = fx.Pitch, volume = volume, at = at })
				end)
			end
			if not root then return end
			-- (your own Glitchy always runs: it moves you)
			if not (near(root.Position) or (mine and data.name == "Glitchy")) then return end
			-- the cast pose for the wind-up (Shared/RunMotion via Gameplay/RunAnimator; local attributes, this screen)
			local body = root.Parent
			if body then
				body:SetAttribute("HuzzCastAt", Workspace:GetServerTimeNow())
				body:SetAttribute("HuzzCastLen", wind + flash)
				body:SetAttribute("HuzzCastKind", fx.Pose)
			end
			task.spawn(CAST[data.name], root, data, wind, flash, burst, fade, PINK, mine, data.id)
			if not mine then
				-- (root +7: clear above their name tag, which ends ~root +6)
				Burst.pop(root.Position + UP * 7, string.upper(def.Name), PINK, { height = 1.1, rise = 1.2, time = 1.2, onTop = false })
			end
			return
		end
		if data.name == "LassoHit" or data.name == "LassoMiss" then
			local l = lassos[data.id]
			if data.name == "LassoHit" and data.target == me and not data.blocked then pullMe(data) end
			local target = rootOf(data.target)
			if data.name == "LassoHit" and (mine or data.target == me or (target and near(target.Position))) then
				Sfx.play("lasso_hit", { at = if mine or data.target == me then nil else target })
			end
			if not l then return end
			if data.name == "LassoMiss" then
				if l.state == "out" then l.missed = true end -- (falls to the floor: CAST.Lasso's "drop")
			elseif data.blocked then
				l.state = "back"
				if target then
					Burst.ring(CFrame.new(target.Position), { r0 = 2.6, r1 = 4.6, time = 0.4, ease = "quart", width = 0.14, glow = 0.6, color = PINK, fade = 0.5, segs = 16 })
				end
			elseif target then
				-- the catch: the loop snaps tight round the waist (white for a blink), a ring slams out at the feet,
				-- YOINK! pops over them with a few sparks; one short glow only if no flash went in the last second
				local accent = Powers.Lasso.Accent
				l.state, l.target, l.loopR = "hit", target, 1.9
				l.snapUntil = os.clock() + 0.12
				l.releaseAt = (os.clock() - l.t0) + (if type(data.time) == "number" then data.time else 0.3) + 0.25
				Burst.ring(CFrame.new(target.Position + UP * 0.2), {
					r0 = 2.6, r1 = 1, time = 0.25, ease = "quart", width = 0.2, glow = 0.6, color = accent, fade = 0.5, segs = 16,
				})
				Burst.ring(CFrame.new(target.Position - UP * 2.8), {
					r0 = 1, r1 = 3.8, time = 0.45, ease = "quart", width = 0.22, glow = 0.6, color = accent, edge = WHITE, fade = 0.6, segs = 20,
				})
				Burst.pop(target.Position + UP * 4.4, "YOINK!", accent, { height = 1.1, rise = 1, time = 0.9 })
				Burst.sparks(target.Position, { accent, WHITE }, 10)
				if Burst.flashOk() then
					Burst.orb({
						at = function() return target.Position + UP * 0.2 end, time = 0.18, color = accent, range = 10, glowScale = 2.4,
						size = function(k) return 1.6 * (1 - k) end, alpha = function(k) return 0.5 + 0.5 * k end, light = function(k) return 1.5 * (1 - k) end,
					})
				end
			end
			return
		end
		local at = data.at
		if typeof(at) ~= "Vector3" or not near(at) then return end
		if data.name == "ShieldPop" then
			local color = PINK
			if mine or data.by == me then Sfx.play("heart_shield", { pitch = 0.9 }) end
			if Burst.flashOk() then
				Burst.orb({ at = function() return at end, time = 0.12, color = color, size = function(k) return 2.6 * (1 - k) + 0.4 end,
					alpha = function(k) return 0.2 + 0.8 * k end, light = function(k) return 4 * (1 - k) end })
			end
			Burst.ring(CFrame.new(at), { r0 = 3.2, r1 = 7.5, time = 0.5, ease = "quart", width = 0.2, glow = 0.8, haze = 2, color = color, fade = 0.5 })
			glyphs(at, 8, "💖", 3.5)
		elseif data.name == "ShieldEnd" then
			-- ran out without a stab: the bubble fizzles in a closing ring
			fizzle(at, PINK, 3.6)
			if mine then Sfx.play("power_end") end
		elseif data.name == "TrapSprung" then
			-- the Love Trap's spring, as it was: a ring closes in round the runner's feet and hearts pop (the server
			-- takes the disc away and pins the runner with its "💘 STUCK!" badge)
			if mine or data.by == me then Sfx.play("trap_snap") end
			Burst.ring(CFrame.new(at + UP * 0.15), { r0 = 4.2, r1 = 1.2, time = 0.35, ease = "in", width = 0.24, glow = 0.8, color = PINK, fade = 0.4 })
			glyphs(at + UP, 5, "💘", 2)
		elseif data.name == "PeelSlip" then
			-- a catcher on the peel: a yellow ring, bananas popping; the stars come from SlipUntil (or the bot's)
			if typeof(data.body) == "Instance" and data.body:IsA("Model") then extra[data.body] = true end
			if mine or data.by == me then Sfx.play("banana_slip") else Sfx.play("banana_slip", { volume = 0.6, at = rootOf(data.id) }) end
			Burst.ring(CFrame.new(at + UP * 0.12), { r0 = 0.8, r1 = 3.4, time = 0.45, ease = "quart", width = 0.16, glow = 0.6, color = YELLOW, edge = Color3.fromRGB(255, 170, 40), fade = 0.5, segs = 16 })
			glyphs(at + UP, 4, "🍌", 2.2)
		elseif data.name == "TrapGone" or data.name == "PeelGone" then
			-- ran out: it folds away in a small puff
			fizzle(at + UP * 0.1, if data.name == "PeelGone" then YELLOW else PINK, if data.name == "PeelGone" then 2 else 3)
			if mine then Sfx.play("power_end", { volume = 0.6 }) end
		end
	end)
end

return M

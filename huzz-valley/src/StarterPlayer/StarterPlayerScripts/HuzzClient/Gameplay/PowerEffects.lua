--[[
	How the round powers look when they're used, drawn on every client from the server's "Power" messages on the
	Round remote (HuzzServer/PowerService). Owner: "make the usage of items smoother ... make it feel like the
	references". Timed like the other game's ability (docs/feel-study.md section 6; Config/Powers.Fx):
	  1. wind-up (0.05 to 0.25 s): a glow builds on the user in the power's colour (Accent), with a soft light;
	  2. one bright frame (at most one a second on a screen: kid-safe);
	  3. the effect (0.35 s);
	  4. a 0.15 s fade.
	  Shield:      the glow at the chest bursts into the blue bubble (the server's bubble shows from that moment).
	  Speed Boost: a ring stands up behind the runner and flies back, with white speed lines (the trail is the server's).
	  Bear Trap:   the catcher throws (Config/Run.Cast.Throw, Shared/RunMotion): the trap (Shared/BearTrap) leaves the
	               free hand and flies in an arc, tumbling, to where the server says it lands; it lands open with a
	               dust ring (the server's trap shows from that moment) and a click and a ring when it arms.
	  Slow Wave:   a ring gathers round the catcher, then a wave of two rings runs out to its reach (its slow lands on
	               runners as it goes out: PowerService waits the wind-up).
	  Invisible:   a shimmer puff, then the body fades (others see a faint shimmer, Seen; you see yourself at Self);
	               the name tag and team outline hide on other screens. Still catchable.
	  Glitchy:     your screen pushes you forward (Distance in Time, the walls still stop you); everyone sees two
	               see-through ghosts of the body, cyan and magenta, left behind and fading (no flicker).
	  Body Double: every screen makes its own copy of the runner that runs straight on (Shared/RunMotion legs) for
	               Lasts seconds, then vanishes in a puff. Only a look.
	  ShieldPop:   a blocked stab: the bubble bursts in a blue ring.
	  TrapSprung:  the trap snaps shut round the runner's feet and holds for Hold seconds.
	  Dive stun:   (owner Oct 19: "after they use it they are stunned for 2 seconds") three cartoon stars circle slowly
	               over a stunned catcher's head while they lie dazed (character StunnedFrom / StunnedUntil).
	During the wind-up the user strikes a cast pose (arms forward and up, or the throw: Shared/RunMotion, on everyone).
	Each power has its own sound on press (yours loud, others' from where they stand), and other players' powers
	pop their name over them once, above their name tag (your own shows on your card instead).
	Every piece is plain parts (Gameplay/Burst, Shared/BearTrap), so it all looks right before any picture is uploaded.
]]
local M = {}

function M.start()
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local Workspace = game:GetService("Workspace")
	local Players = game:GetService("Players")
	local RunService = game:GetService("RunService")
	local Sfx = require(script.Parent.Sfx)
	local Burst = require(script.Parent.Burst)

	local Shared = ReplicatedStorage:WaitForChild("Shared")
	local Net = require(Shared.Net)
	local Powers = require(Shared.Config.Powers)
	local BearTrap = require(Shared.BearTrap)
	local okRun, RunMotion = pcall(require, Shared.RunMotion)
	local RoundNet = Net.get("Round") :: RemoteEvent
	local FX = Powers.Fx
	local WHITE, PURPLE = FX.Core, FX.Edge
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
			Burst.run(0.6, function(_, k)
				holder.CFrame = CFrame.new(at + out * Burst.ease(k))
				label.TextTransparency = math.clamp((k - 0.45) / 0.55, 0, 1)
			end, function() holder:Destroy() end)
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

	-- The wind-up glow and the bright frame. `at` gives the glow's spot each frame. Returns nothing; the
	-- effect itself starts after `wind` (the caller waits).
	local function windUp(at: (number) -> Vector3, wind: number, flash: number, size: number, color: Color3)
		local bright = false
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

	-- Copies of a character's visible parts (no joints, no scripts), anchored where they are now: ghosts.
	local function ghostOf(character: Model, color: Color3): { { part: BasePart, at: CFrame } }
		local list = {}
		for _, d in character:GetDescendants() do
			if d:IsA("BasePart") and d.Name ~= "HumanoidRootPart" and d.Transparency < 0.9 then
				local ok, copy = pcall(function()
					local c = d:Clone()
					c:ClearAllChildren()
					return c
				end)
				if ok and copy then
					copy.Anchored, copy.CanCollide, copy.CanQuery, copy.CanTouch, copy.CastShadow = true, false, false, false, false
					copy.Material = Enum.Material.Neon
					copy.Color = color
					pcall(function() (copy :: any).TextureID = "" end)
					copy.Parent = Burst.home()
					table.insert(list, { part = copy, at = d.CFrame })
				end
			end
		end
		return list
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
		windUp(chest, wind, flash, 0.9, color)
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
			end, function() shell:Destroy() end)
			Burst.ring(CFrame.new(root.Position), {
				r0 = 0.8, r1 = 4.4, time = burst + fade, ease = "quart", width = 0.16, glow = 0.6, color = color,
				fade = fade / (burst + fade) + 0.25, follow = function() return CFrame.new(root.Position) end,
			})
			glyphs(root.Position + UP, 5, "✨", 3)
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
		local hand = function()
			local c = root.Parent
			local h = c and c:FindFirstChild("LeftHand")
			return if h and h:IsA("BasePart") then h.Position else root.Position + UP * 1.2 - root.CFrame.RightVector * 1.2
		end
		windUp(hand, wind, flash, 0.5, color)
		local dir = if typeof(data.dir) == "Vector3" then data.dir else flatLook(root)
		local yaw = math.atan2(-dir.X, -dir.Z)
		task.delay(wind + flash, function()
			local from = hand()
			local model = BearTrap.build(color)
			model.Parent = Burst.home()
			local scale0 = 0.4 -- (small in the hand, full size as it lands)
			Burst.run(flight, function(age)
				local s = math.clamp(age / flight, 0, 1)
				local p = from:Lerp(spot, s) + UP * (def.Arc * 4 * s * (1 - s))
				local tumble = CFrame.Angles(-(1 - s) * math.pi * 2, 0, 0) -- (one turn forward, flat as it lands)
				BearTrap.pose(model, CFrame.new(p) * CFrame.Angles(0, yaw, 0) * tumble, 0, scale0 + (1 - scale0) * Burst.ease(s))
			end, function()
				model:Destroy()
				-- landed: a dust ring and a clack, then it arms (a click and a ring)
				Burst.ring(CFrame.new(spot + UP * 0.1), {
					r0 = 1.2, r1 = 3.2, time = 0.35, ease = "quart", width = 0.12, glow = 0.5, color = Color3.fromRGB(200, 190, 170),
					fade = 0.5, segs = 16, alpha = 0.3,
				})
				if near(spot) then Sfx.play("trap_set", { at = root }) end
				task.delay(def.Arm, function()
					Burst.ring(CFrame.new(spot + UP * 0.08), {
						r0 = def.Radius + 0.6, r1 = def.Radius, time = 0.3, ease = "quart", width = 0.1, glow = 0.45,
						color = color, fade = 0.45, segs = 20,
					})
				end)
			end)
		end)
	end

	function CAST.SlowWave(root: BasePart, data, wind, flash, burst, fade, color)
		local radius = data.radius or Powers.SlowWave.Radius
		local ground = function() return CFrame.new(root.Position - UP * 2.8) end
		windUp(function() return root.Position + UP * 0.4 end, wind, flash, 0.9, color)
		-- the gather: a ring closing in round the catcher
		Burst.ring(ground(), {
			r0 = 4.5, r1 = 1.4, time = wind, ease = "in", width = 0.12, glow = 0.45, color = color, fade = 0.15,
			alpha = 0.2, follow = ground, segs = 16,
		})
		task.delay(wind + flash, function()
			if not root.Parent then return end
			local at = ground()
			Burst.ring(at, {
				-- (16 pieces a ring and no haze under it: it was ~200 neon parts moved one by one every frame)
				r0 = 1.4, r1 = radius, time = burst + fade, ease = "quart", width = 0.24, glow = 1.1, color = color,
				fade = fade / (burst + fade) + 0.3, segs = 16,
			})
			task.delay(0.07, function()
				Burst.ring(at, {
					r0 = 1, r1 = radius * 0.86, time = burst + fade, ease = "quart", width = 0.1, glow = 0.6,
					color = PURPLE, fade = fade / (burst + fade) + 0.35, segs = 16, alpha = 0.3,
				})
			end)
		end)
	end

	function CAST.Invisible(root: BasePart, _data, wind, flash, burst, fade, color)
		windUp(function() return root.Position + UP * 0.6 end, wind, flash, 0.8, color)
		task.delay(wind + flash, function()
			if not root.Parent then return end
			Burst.ring(CFrame.new(root.Position - UP * 2.6), {
				r0 = 0.8, r1 = 3.4, time = burst + fade, ease = "quart", width = 0.12, glow = 0.5, color = color,
				fade = 0.6, segs = 16, alpha = 0.25,
			})
			Burst.sparks(root.Position, { WHITE, color }, 10)
		end)
	end

	-- Two ghosts of the body (cyan and magenta, a little apart) left where you were, fading; your own screen pushes
	-- you forward (the walls stop you, as with the huss).
	local CYAN, MAGENTA = Color3.fromRGB(78, 240, 224), Color3.fromRGB(255, 80, 200)
	function CAST.Glitchy(root: BasePart, data, wind, flash, _burst, _fade, color, mine)
		local def = Powers.Glitchy
		local character = root.Parent :: Model
		task.delay(wind, function()
			if not (character and root.Parent) then return end
			local dir = if typeof(data.dir) == "Vector3" then data.dir else flatLook(root)
			local right = dir:Cross(UP).Unit
			for i, tint in { CYAN, MAGENTA } do
				local shift = right * (if i == 1 then -0.35 else 0.35)
				local ghosts = ghostOf(character, tint)
				Burst.run(0.32, function(age, k)
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
				Burst.run(0.25, function(_, k)
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
	function CAST.BodyDouble(root: BasePart, data, wind, flash, _burst, _fade, color)
		local def = Powers.BodyDouble
		local character = root.Parent :: Model
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
					r0 = 0.6, r1 = 3, time = 0.35, ease = "quart", width = 0.12, glow = 0.5, color = color, fade = 0.5, segs = 16,
				})
				local parts = {}
				for _, d in copy:GetDescendants() do
					if d:IsA("BasePart") or d:IsA("Decal") then table.insert(parts, d) end
				end
				Burst.run(0.25, function(_, k)
					for _, p in parts do p.LocalTransparencyModifier = k end
				end, function() copy:Destroy() end)
			end
			local t0 = os.clock()
			local conn
			conn = RunService.Heartbeat:Connect(function(dt)
				if puffed or not copy.Parent then conn:Disconnect() return end
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
			Burst.sparks(root.Position, { WHITE, color }, 8)
		end)
	end

	-- Invisible bodies, every frame: others fade to Seen with a slow shimmer (once a second at most, a soft swell,
	-- never a blink); you see yourself at Self. Name tags and team outlines hide on other screens meanwhile.
	local faded = {} -- Model -> { hidden = { [Instance] = previous Enabled } }
	local function setFade(character: Model, value: number)
		for _, d in character:GetDescendants() do
			if d:IsA("BasePart") or d:IsA("Decal") then
				d.LocalTransparencyModifier = value
			end
		end
	end
	-- A dive's stun, on every screen: three little cartoon stars circling over the head while the catcher lies dazed
	-- (character StunnedFrom / StunnedUntil from HuzzServer/PowerService.stun). A slow steady turn, no blinking.
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
	RunService.Heartbeat:Connect(function()
		local t = Workspace:GetServerTimeNow()
		local me = Players.LocalPlayer
		local def = Powers.Invisible
		for _, p in Players:GetPlayers() do
			local c = p.Character
			local head = c and c:FindFirstChild("Head")
			local stunFrom, stunTo = c and c:GetAttribute("StunnedFrom"), c and c:GetAttribute("StunnedUntil")
			if c and head and head:IsA("BasePart") and type(stunFrom) == "number" and type(stunTo) == "number"
				and t >= stunFrom and t < stunTo and near(head.Position) then
				dazed[c] = dazed[c] or starsOn(c)
				local spin = t * 2 * math.pi / 1.4
				for i, holder in dazed[c] do
					local a = spin + (i - 1) * 2 * math.pi / 3
					holder.CFrame = CFrame.new(head.Position + Vector3.new(math.cos(a) * 1.1, 1.3 + 0.15 * math.sin(a * 2), math.sin(a) * 1.1))
				end
			elseif c and dazed[c] then
				starsOff(c)
			end
			local untilT = c and c:GetAttribute("InvisibleUntil")
			if c and type(untilT) == "number" and t < untilT then
				local rec = faded[c]
				if not rec then
					rec = { hidden = {} }
					faded[c] = rec
					if p ~= me then
						for _, d in c:GetDescendants() do
							if (d:IsA("BillboardGui") and d.Name == "HuzzTag") or (d:IsA("Highlight") and d.Name == "HuzzOutline") then
								rec.hidden[d] = d.Enabled
								d.Enabled = false
							end
						end
					end
				end
				local fadeIn = math.clamp((t - (untilT - def.Lasts)) / 0.25, 0, 1)
				local fadeOut = math.clamp((untilT - t) / 0.3, 0, 1)
				local target = if p == me then def.Self else def.Seen + 0.05 * math.sin(t * def.Shimmer * 2 * math.pi)
				setFade(c, target * math.min(fadeIn, fadeOut))
			elseif c and faded[c] then
				setFade(c, 0)
				for d, was in faded[c].hidden do
					if d.Parent then d.Enabled = was end
				end
				faded[c] = nil
			end
		end
		for c in faded do
			if not c.Parent then faded[c] = nil end
		end
		for c in dazed do
			if not c.Parent then starsOff(c) end
		end
	end)

	local SPOKEN = { Shield = true, SpeedBoost = true, BearTrap = true, SlowWave = true, Invisible = true, Glitchy = true, BodyDouble = true }

	RoundNet.OnClientEvent:Connect(function(kind, data)
		if kind ~= "Power" or type(data) ~= "table" or type(data.name) ~= "string" then return end
		local me = Players.LocalPlayer.UserId
		local mine = data.id == me
		local root = rootOf(data.id)
		if SPOKEN[data.name] and FX[data.name] and CAST[data.name] then
			local fx = FX[data.name]
			local def = Powers[data.name]
			if mine then
				Sfx.play(fx.Sound, { pitch = fx.Pitch })
			elseif root and near(root.Position) then
				Sfx.play(fx.Sound, { pitch = fx.Pitch, volume = 0.7, at = root })
			end
			if not root then return end
			-- (your own Glitchy always runs: it moves you)
			if not (near(root.Position) or (mine and data.name == "Glitchy")) then return end
			local wind, flash, burst, fade = timing(data.name)
			-- the cast pose for the wind-up (Shared/RunMotion via Gameplay/RunAnimator; local attributes, this screen)
			local body = root.Parent
			if body then
				body:SetAttribute("HuzzCastAt", Workspace:GetServerTimeNow())
				body:SetAttribute("HuzzCastLen", wind + flash)
				body:SetAttribute("HuzzCastKind", fx.Pose)
			end
			task.spawn(CAST[data.name], root, data, wind, flash, burst, fade, def.Accent, mine)
			if not mine then
				-- (root +7: clear above their name tag, which ends ~root +6)
				Burst.pop(root.Position + UP * 7, string.upper(def.Name), def.Accent, { height = 1.1, rise = 1.2, time = 1.1, onTop = false })
			end
			return
		end
		local at = data.at
		if typeof(at) ~= "Vector3" or not near(at) then return end
		if data.name == "ShieldPop" then
			local color = Powers.Shield.Accent
			if mine or data.by == me then Sfx.play("heart_shield", { pitch = 0.9 }) end
			if Burst.flashOk() then
				Burst.orb({ at = function() return at end, time = 0.12, color = color, size = function(k) return 2.6 * (1 - k) + 0.4 end,
					alpha = function(k) return 0.2 + 0.8 * k end, light = function(k) return 4 * (1 - k) end })
			end
			Burst.ring(CFrame.new(at), { r0 = 3.2, r1 = 7.5, time = 0.45, ease = "quart", width = 0.2, glow = 0.8, haze = 2, color = color, fade = 0.5 })
			glyphs(at, 6, "✨", 3.5)
		elseif data.name == "TrapSprung" then
			-- the trap snaps shut round the runner (0.08 s), holds while they're stuck, then fades
			local def = Powers.BearTrap
			if mine or data.by == me then Sfx.play("trap_snap") end
			local yaw = if type(data.yaw) == "number" then data.yaw else 0
			local model = BearTrap.build(def.Accent)
			model.Parent = Burst.home()
			local hold = if type(data.hold) == "number" then data.hold else def.Hold
			local parts = {}
			for _, d in model:GetDescendants() do
				if d:IsA("BasePart") and d.Name ~= "Glow" then table.insert(parts, d) end
			end
			Burst.run(hold + 0.3, function(age)
				local shut = math.clamp(age / 0.08, 0, 1)
				BearTrap.pose(model, CFrame.new(at) * CFrame.Angles(0, yaw, 0), 1 - (1 - shut) ^ 2)
				if age > hold then
					for _, p in parts do p.LocalTransparencyModifier = (age - hold) / 0.3 end
				end
			end, function() model:Destroy() end)
			Burst.ring(CFrame.new(at + UP * 0.15), { r0 = 3.2, r1 = 1.2, time = 0.25, ease = "in", width = 0.2, glow = 0.7, color = def.Accent, fade = 0.4, segs = 16 })
		end
	end)
end

return M

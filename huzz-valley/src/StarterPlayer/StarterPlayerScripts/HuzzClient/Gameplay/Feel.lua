--[[
	The small things that make running feel quick and expensive (owner: "make the running/game feel more
	premium... see the feel in Huss Valley"), on this screen only:
	  - the camera widens a touch (2 degrees) at full sprint (owner: "when you are running full speed make the screen
	    make you feel like you are running quick"), easing in and out. Huss Valley's camera stays calm (no visible
	    FOV change, no kick on the huss: docs/feel-study.md gap 6), so it was cut from 11 degrees and the 9 degree
	    huss kick and the screen-edge wind streaks and line ring are gone;
	  - a huss draws 5-6 thin white speed lines in the world behind whoever does it, for ~0.3 s (Config/Run.Dash.Lines;
	    everyone near sees them, like Huss Valley's), and nothing on the screen itself;
	  - every runner near you kicks up a little dust each step and a puff when they dash;
	  - footsteps are our own sound (Sfx "step"), lobby too, for you and anyone near; Roblox's own running sound
	    is muted (owner: "add a running sound, not the base sound running that roblox has").
	The sprint feel works in the lobby too; the dust only in a round. Never while the intro camera has the view, and
	off with the Reduced Motion setting (the camera; the lines and dust stay: they're in the world, not the view).
]]
local M = {}

function M.start()
	local Players = game:GetService("Players")
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local Workspace = game:GetService("Workspace")

	local Run = require(ReplicatedStorage:WaitForChild("Shared").Config.Run)
	local RunMotion = require(ReplicatedStorage.Shared.RunMotion)
	local State = require(script.Parent.Parent.UI.State)
	local Sfx = require(script.Parent.Sfx)
	local Frame = require(script.Parent.Frame)

	local player = Players.LocalPlayer
	local SPRINT_FOV = 2 -- extra degrees at full sprint (was 11; Huss Valley shows none: a calm camera)
	local NEAR = 120 -- studs: dust only for runners this close to the camera

	local function inRound(p)
		local role = p:GetAttribute("HuzzRole")
		return role == "Runner" or role == "Catcher"
	end
	local function calm()
		return State.setting("ReducedMotion") == true
	end

	-- a soft wind bed that rises with your speed (silent until the owner uploads speed_wind)
	local wind = Sfx.loop("speed_wind")
	local windLevel = if wind then wind.Volume else 0
	if wind then wind.Volume = 0 end

	-- The huss's speed lines (Config/Run.Dash.Lines, laid out by Shared/RunMotion.hussLines): 5-6 thin white Beams
	-- riding with whoever husses, trailing behind along the move, holding their length and then fading out,
	-- like Huss Valley's (docs/previews/feel-huss.jpg). Moved every frame below; gone after Lines.Time.
	local LINES = Run.Dash.Lines
	local terrain = Workspace:FindFirstChildOfClass("Terrain") or Workspace
	local hussing = {} -- { root, dir, at, beams = { {a0, a1, beam} } }
	local function hussLines(root: BasePart, dir: Vector3, at: number)
		local set = { root = root, dir = dir, at = at, beams = {} }
		for i = 1, #LINES do
			local a0, a1 = Instance.new("Attachment"), Instance.new("Attachment")
			a0.Name, a1.Name = "HuzzHussLine", "HuzzHussLine"
			a0.Parent, a1.Parent = terrain, terrain
			local b = Instance.new("Beam")
			b.Name = "HuzzHussLine" .. i
			b.Attachment0, b.Attachment1 = a0, a1
			b.FaceCamera = true
			b.Width0, b.Width1 = LINES.Width, LINES.Width * 0.7
			b.Segments = 1
			b.LightEmission = 0.3
			b.LightInfluence = 0
			b.Color = ColorSequence.new(Color3.new(1, 1, 1))
			b.Transparency = NumberSequence.new(1)
			b.Parent = a0
			set.beams[i] = { a0, a1, b }
		end
		table.insert(hussing, set)
	end
	local function moveLines(now: number)
		for i = #hussing, 1, -1 do
			local set = hussing[i]
			local lines = set.root.Parent and RunMotion.hussLines(set.root.CFrame, set.dir, now - set.at)
			if not lines then
				for _, b in set.beams do b[1]:Destroy(); b[2]:Destroy() end
				table.remove(hussing, i)
			else
				for k, l in lines do
					local b = set.beams[k]
					b[1].WorldPosition, b[2].WorldPosition = l.from, l.to
					b[3].Transparency = NumberSequence.new(1 - l.alpha, 1 - l.alpha * 0.25)
				end
			end
		end
	end

	-- Dust: one small emitter per character, at the feet, fired by hand (Emit) on each step.
	local dust = {} -- Player -> { character, emitter, travelled, side }
	local function dustFor(p, character, root)
		local d = dust[p]
		if d and d.character == character and d.emitter.Parent then
			return d
		end
		local att = Instance.new("Attachment")
		att.Name = "HuzzDust"
		att.Position = Vector3.new(0, -2.9, 0)
		att.Parent = root
		local e = Instance.new("ParticleEmitter")
		e.Name = "Dust"
		e.Texture = "rbxasset://textures/particles/smoke_main.dds"
		e.Color = ColorSequence.new(Color3.fromRGB(236, 222, 200), Color3.fromRGB(200, 186, 166))
		e.LightInfluence = 1
		e.Rate = 0
		e.Lifetime = NumberRange.new(0.35, 0.6)
		e.Speed = NumberRange.new(1.5, 3.5)
		e.SpreadAngle = Vector2.new(70, 70)
		e.Acceleration = Vector3.new(0, 2, 0)
		e.Drag = 4
		e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 1.6) })
		e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.55), NumberSequenceKeypoint.new(1, 1) })
		e.Rotation = NumberRange.new(0, 360)
		e.RotSpeed = NumberRange.new(-40, 40)
		e.Parent = att
		d = { character = character, emitter = e, travelled = 0, lastDash = nil }
		dust[p] = d
		return d
	end
	Players.PlayerRemoving:Connect(function(p)
		dust[p] = nil
	end)

	local camera = Workspace.CurrentCamera
	local extra = 0 -- the FOV we've added (eased)
	local heldSprint = 0 -- the sprint before a huss (held through it)
	local lastLines = {} -- Player -> the DashAt we drew lines for
	Players.PlayerRemoving:Connect(function(p) lastLines[p] = nil end)
	-- Roblox's default character sounds (RbxCharacterSounds) put a "Running" sound in every root part: keep it silent.
	local function muteRunning(character: Model)
		local function mute(s: Instance)
			if s:IsA("Sound") and s.Name == "Running" then
				s.Volume = 0
				s:GetPropertyChangedSignal("Volume"):Connect(function()
					if s.Volume ~= 0 then s.Volume = 0 end
				end)
			end
		end
		local root = character:WaitForChild("HumanoidRootPart", 10)
		if not root then return end
		for _, c in root:GetChildren() do mute(c) end
		root.ChildAdded:Connect(mute)
	end
	local function watchSounds(p: Player)
		p.CharacterAdded:Connect(function(c) task.spawn(muteRunning, c) end)
		if p.Character then task.spawn(muteRunning, p.Character) end
	end
	Players.PlayerAdded:Connect(watchSounds)
	for _, p in Players:GetPlayers() do watchSounds(p) end
	local STEP_NEAR = 70 -- studs: other players' footsteps are heard this close to the camera
	local stepped = {} -- Player -> studs since the last step
	Players.PlayerRemoving:Connect(function(p) stepped[p] = nil end)

	Frame.on(5, function(dt)
		dt = math.clamp(dt, 1 / 240, 1 / 15)
		local now = Workspace:GetServerTimeNow()
		if Workspace.CurrentCamera ~= camera then
			extra = 0 -- (a new camera starts clean: never take our extra off a camera we didn't add it to)
		end
		camera = Workspace.CurrentCamera
		local myRoot = nil

		for _, p in Players:GetPlayers() do
			local character = p.Character
			local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
			-- footsteps: one every half stride while moving on the ground; yours plain, others' from where they are
			if root and camera and not character:GetAttribute("DownedAt") then
				local v = root.AssemblyLinearVelocity
				local speed = Vector3.new(v.X, 0, v.Z).Magnitude
				local dashAt = RunMotion.dashAt(character)
				local dashing = type(dashAt) == "number" and now - dashAt < 0.35 -- (no quick-fire steps from the huss push)
				if speed > 4 and not dashing and math.abs(v.Y) < 8 and (p == player or (camera.CFrame.Position - root.Position).Magnitude < STEP_NEAR) then
					local t = (stepped[p] or 0) + speed * dt
					if t >= Run.Stride / 2 then
						t = 0
						if p == player then Sfx.play("step") else Sfx.play("step", { at = root, volume = 0.8 }) end
					end
					stepped[p] = t
				else
					stepped[p] = 0
				end
			end
			-- the huss's speed lines, lobby too (your own huss sets DashAt twice: here, then from the server; dashAt
			-- keeps your own local time for the second one)
			local hussAt = character and RunMotion.dashAt(character)
			local hussDir = character and character:GetAttribute("DashDir")
			if root and camera and type(hussAt) == "number" and typeof(hussDir) == "Vector3" then
				local last = lastLines[p]
				-- (others' huss reaches us a little late: draw what's left of it)
				if (last == nil or hussAt - last > 0.5) and now - hussAt < LINES.Time - 0.08
					and (camera.CFrame.Position - root.Position).Magnitude < NEAR then
					hussLines(root, hussDir, hussAt)
				end
				if last == nil or hussAt - last > 0.5 then
					lastLines[p] = hussAt
				end
			end
			if root and inRound(p) and not character:GetAttribute("DownedAt") and camera
				and (camera.CFrame.Position - root.Position).Magnitude < NEAR then
				local d = dustFor(p, character, root)
				local v = root.AssemblyLinearVelocity
				local speed = Vector3.new(v.X, 0, v.Z).Magnitude
				-- a puff each step (half a stride) while running on the ground
				if speed > Run.From and math.abs(v.Y) < 8 then
					d.travelled += speed * dt
					if d.travelled >= Run.Stride / 2 then
						d.travelled = 0
						d.emitter:Emit(2)
					end
				else
					d.travelled = 0
				end
				local dashAt = RunMotion.dashAt(character)
				if type(dashAt) == "number" and dashAt ~= d.lastDash then
					d.lastDash = dashAt
					if now - dashAt < 0.3 then
						d.emitter:Emit(8)
					end
				end
			end
			if p == player then
				myRoot = root
			end
		end

		moveLines(now)

		-- The camera: only our own, in a round, while the normal camera has the view.
		if not camera then
			return
		end
		local want = 0
		local sprint = 0 -- 0 = walking, 1 = flat out
		local character = player.Character
		local cinematic = player:GetAttribute("HuzzCinematic") == true or camera.CameraType == Enum.CameraType.Scriptable
		if myRoot and not cinematic and not calm() then
			local v = myRoot.AssemblyLinearVelocity
			local speed = Vector3.new(v.X, 0, v.Z).Magnitude
			local h = character and character:FindFirstChildOfClass("Humanoid")
			local cap = (h and h:GetAttribute("HuzzSpeed")) or (h and h.WalkSpeed) or 20
			sprint = math.clamp((speed - Run.From) / math.max(cap - Run.From, 4), 0, 1) ^ 1.4
			local dashAt = character and RunMotion.dashAt(character)
			if type(dashAt) == "number" and now - dashAt < Run.Dash.Length + 0.1 then
				sprint = heldSprint -- (the huss's burst of speed changes nothing: the camera stays steady)
			end
			heldSprint = sprint
			want = sprint * SPRINT_FOV
		end
		if wind then wind.Volume = windLevel * math.clamp((sprint - 0.4) / 0.6, 0, 1) end
		if cinematic then
			-- the intro camera sets its own view: hand back exactly what we added and stay out of its way
			if extra ~= 0 then
				camera.FieldOfView -= extra
				extra = 0
			end
			return
		end
		local k = 1 - math.exp(-dt * (if want > extra then 10 else 4)) -- quick out, gentle back
		local nextExtra = extra + (want - extra) * k
		if math.abs(nextExtra) < 0.01 and want == 0 then
			nextExtra = 0
		end
		camera.FieldOfView += nextExtra - extra
		extra = nextExtra
	end)
end

return M

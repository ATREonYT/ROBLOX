--[[
	How the round powers look when they're used, drawn on every client from the server's "Power" messages on the
	Round remote (HuzzServer/PowerService). Owner: "make the usage of items smoother ... make it feel like the
	references". Timed like the other game's ability (docs/feel-study.md section 6; Config/Powers.Fx):
	  1. wind-up (0.15 to 0.25 s): a glow builds on the user, white in the middle, pink round it, with a soft light;
	  2. one bright frame (at most one a second on a screen: kid-safe);
	  3. the effect (0.35 s), white core -> pink -> purple edges;
	  4. a 0.15 s fade to purple.
	  Heart Shield: the glow at the chest bursts into the pink bubble (the server's bubble shows from that moment)
	                with a ring round the middle and hearts.
	  Rizz Rush:    the glow at the feet bursts into a ring that stands up behind the runner and flies back, with
	                white speed lines (the pink trail is the server's).
	  Love Trap:    the glow drops to the floor and a ring slams out round the trap, then settles to its size
	                (the trap shows from that moment).
	  Charm Wave:   a ring gathers round the catcher, then a wave of two rings runs out to its reach (its slow lands
	                on runners as it goes out: PowerService waits the wind-up).
	  ShieldPop:    a blocked stab: the bubble bursts in a pink ring with hearts.
	  TrapSprung:   the trap snaps shut: a ring closes in and hearts pop.
	Each power has its own sound on press (yours loud, others' from where they stand), and other players' powers
	pop their name over them once (your own shows on your Q / E tile instead: nothing over your own character).
	Every piece is plain neon parts (Gameplay/Burst), so it all looks right before any effect picture is uploaded.
]]
local M = {}

function M.start()
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local Workspace = game:GetService("Workspace")
	local Players = game:GetService("Players")
	local Sfx = require(script.Parent.Sfx)
	local Burst = require(script.Parent.Burst)

	local Shared = ReplicatedStorage:WaitForChild("Shared")
	local Net = require(Shared.Net)
	local Powers = require(Shared.Config.Powers)
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

	-- Little hearts flying out of a point and fading (emoji, so they read before any picture is uploaded).
	local function hearts(at: Vector3, count: number, glyph: string, spread: number)
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
	local function partsOf(inst: Instance?): { BasePart }
		local list = {}
		if inst then
			if inst:IsA("BasePart") then table.insert(list, inst) end
			for _, d in inst:GetDescendants() do
				if d:IsA("BasePart") then table.insert(list, d) end
			end
		end
		return list
	end

	-- The wind-up glow and the bright frame. `at` gives the glow's spot each frame. Returns nothing; the
	-- effect itself starts after `wind` (the caller waits).
	local function windUp(at: (number) -> Vector3, wind: number, flash: number, size: number)
		local bright = false
		return Burst.orb({
			at = at, time = wind + flash, color = PINK, range = 12, glowScale = 2,
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

	local CAST = {}

	function CAST.HeartShield(root: BasePart, _data, wind, flash, burst, fade)
		local bubble = Workspace:FindFirstChild("HuzzShields")
		local mine = {}
		if bubble then
			for _, b in bubble:GetChildren() do
				if b:IsA("BasePart") and (b.Position - root.Position).Magnitude < 1.5 then table.insert(mine, b) end
			end
		end
		hideUntil(mine, wind + flash + burst * 0.6)
		local chest = function() return root.Position + UP * 0.6 end
		windUp(chest, wind, flash, 0.9)
		task.delay(wind + flash, function()
			if not root.Parent then return end
			-- the bubble grows out with a little overshoot, then the server's one takes over
			local shell = Burst.piece(PINK, Enum.PartType.Ball)
			shell.Material = Enum.Material.ForceField
			Burst.run(burst + fade, function(age, k)
				local g = math.clamp(age / burst, 0, 1)
				shell.CFrame = CFrame.new(root.Position)
				shell.Size = Vector3.one * (1.5 + 6.1 * Burst.ease(g, "back"))
				shell.Transparency = if age > burst then (age - burst) / fade else 0
				shell.Color = PINK:Lerp(PURPLE, k)
			end, function() shell:Destroy() end)
			Burst.ring(CFrame.new(root.Position), {
				r0 = 0.8, r1 = 4.4, time = burst + fade, ease = "quart", width = 0.16, glow = 0.6, color = PINK,
				fade = fade / (burst + fade) + 0.25, follow = function() return CFrame.new(root.Position) end,
			})
			hearts(root.Position + UP, 6, "💖", 3)
		end)
	end

	function CAST.RizzRush(root: BasePart, _data, wind, flash, burst, fade)
		local feet = function() return root.Position - UP * 2.2 end
		windUp(feet, wind, flash, 0.8)
		task.delay(wind + flash, function()
			if not root.Parent then return end
			local look = root.CFrame.LookVector
			local flatLook = Vector3.new(look.X, 0, look.Z)
			flatLook = if flatLook.Magnitude > 0.01 then flatLook.Unit else Vector3.new(0, 0, -1)
			local start = root.Position
			-- a ring standing up across the run, flying back from the runner (its plane faces the way they run)
			local function standing(back: number): CFrame
				local c = start - flatLook * back
				return CFrame.lookAt(c, c + flatLook) * CFrame.Angles(math.rad(90), 0, 0)
			end
			Burst.ring(standing(0), {
				r0 = 1.2, r1 = 4.2, time = burst + fade, ease = "quart", width = 0.16, glow = 0.65, color = PINK,
				fade = fade / (burst + fade) + 0.3, follow = nil,
			})
			-- white speed lines behind the body, thin, streaming back and fading
			local right = flatLook:Cross(UP).Unit
			for i = 1, 6 do
				local line = Burst.piece(WHITE)
				local side = (i - 3.5) * 0.55
				local up = ((i * 37) % 5) * 0.45 - 1.2
				Burst.run(burst + fade, function(age, k)
					local base = root.Position - flatLook * (1.2 + 3 * Burst.ease(k)) + right * side + UP * up
					line.Size = Vector3.new(0.08, 0.08, 3.6 * (1 - 0.5 * k))
					line.CFrame = CFrame.lookAt(base, base + flatLook)
					line.Color = WHITE:Lerp(PINK, k)
					line.Transparency = 0.1 + 0.9 * k ^ 1.5
				end, function() line:Destroy() end)
			end
		end)
	end

	function CAST.LoveTrap(root: BasePart, data, wind, flash, burst, fade)
		local spot = if typeof(data.at) == "Vector3" then data.at else root.Position - UP * 3
		local traps = Workspace:FindFirstChild("HuzzTraps")
		local hide = {}
		if traps then
			for _, t in traps:GetChildren() do
				local sign = t:FindFirstChild("Sign")
				if sign and sign:IsA("BasePart") and (sign.Position - (spot + UP * 1.2)).Magnitude < 1 then
					hide = partsOf(t)
					local gui = sign:FindFirstChildOfClass("BillboardGui")
					if gui then
						gui.Enabled = false
						task.delay(wind + flash, function() gui.Enabled = true end)
					end
				end
			end
		end
		hideUntil(hide, wind + flash)
		-- the glow builds in the catcher's hands, then drops to the floor
		windUp(function(k)
			local hand = root.Position + root.CFrame.LookVector * 0.8
			return hand:Lerp(spot + UP * 0.4, Burst.ease(math.clamp(k * (wind + flash) / wind, 0, 1), "in"))
		end, wind, flash, 0.7)
		task.delay(wind + flash, function()
			local radius = Powers.LoveTrap.Radius
			Burst.ring(CFrame.new(spot + UP * 0.15), {
				r0 = 0.6, r1 = radius + 0.4, time = burst + fade, ease = "back", width = 0.2, glow = 0.8, color = PINK,
				fade = fade / (burst + fade) + 0.2,
			})
			hearts(spot + UP * 0.8, 5, "💘", 1.8)
		end)
	end

	function CAST.CharmWave(root: BasePart, data, wind, flash, burst, fade)
		local radius = data.radius or Powers.CharmWave.Radius
		local ground = function() return CFrame.new(root.Position - UP * 2.8) end
		windUp(function() return root.Position + UP * 0.4 end, wind, flash, 0.9)
		-- the gather: a ring closing in round the catcher
		Burst.ring(ground(), {
			r0 = 4.5, r1 = 1.4, time = wind, ease = "in", width = 0.12, glow = 0.45, color = PINK, fade = 0.15,
			alpha = 0.2, follow = ground,
		})
		task.delay(wind + flash, function()
			if not root.Parent then return end
			local at = ground()
			Burst.ring(at, {
				r0 = 1.4, r1 = radius, time = burst + fade, ease = "quart", width = 0.24, glow = 1.1, haze = 2.6, color = PINK,
				fade = fade / (burst + fade) + 0.3, segs = 32,
			})
			task.delay(0.07, function()
				Burst.ring(at, {
					r0 = 1, r1 = radius * 0.86, time = burst + fade, ease = "quart", width = 0.1, glow = 0.6,
					color = PURPLE, fade = fade / (burst + fade) + 0.35, segs = 28, alpha = 0.3,
				})
			end)
			hearts(root.Position + UP, 6, "💞", 4)
		end)
	end

	local SPOKEN = { HeartShield = true, RizzRush = true, LoveTrap = true, CharmWave = true }

	RoundNet.OnClientEvent:Connect(function(kind, data)
		if kind ~= "Power" or type(data) ~= "table" or type(data.name) ~= "string" then return end
		local me = Players.LocalPlayer.UserId
		local mine = data.id == me
		local root = rootOf(data.id)
		if SPOKEN[data.name] and FX[data.name] then
			local fx = FX[data.name]
			if mine then
				Sfx.play(fx.Sound, { pitch = fx.Pitch })
			elseif root and near(root.Position) then
				Sfx.play(fx.Sound, { pitch = fx.Pitch, volume = 0.7, at = root })
			end
			if not (root and near(root.Position)) then return end
			local wind, flash, burst, fade = timing(data.name)
			task.spawn(CAST[data.name], root, data, wind, flash, burst, fade)
			if not mine then
				local def = Powers[data.name]
				Burst.pop(root.Position + UP * 3.4, string.upper(def.Name), PINK, { height = 1.1, rise = 1.2, time = 1.1, onTop = false })
			end
			return
		end
		local at = data.at
		if typeof(at) ~= "Vector3" or not near(at) then return end
		if data.name == "ShieldPop" then
			if mine or data.by == me then Sfx.play("heart_shield", { pitch = 0.9 }) end
			if Burst.flashOk() then
				Burst.orb({ at = function() return at end, time = 0.12, color = PINK, size = function(k) return 2.6 * (1 - k) + 0.4 end,
					alpha = function(k) return 0.2 + 0.8 * k end, light = function(k) return 4 * (1 - k) end })
			end
			Burst.ring(CFrame.new(at), { r0 = 3.2, r1 = 7.5, time = 0.45, ease = "quart", width = 0.2, glow = 0.8, haze = 2, color = PINK, fade = 0.5 })
			hearts(at, 8, "💖", 3.5)
		elseif data.name == "TrapSprung" then
			if mine or data.by == me then Sfx.play("trap_snap") end
			Burst.ring(CFrame.new(at + UP * 0.15), { r0 = 4.2, r1 = 1.2, time = 0.3, ease = "in", width = 0.24, glow = 0.8, color = PINK, fade = 0.4 })
			hearts(at + UP, 5, "💘", 2)
		end
	end)
end

return M

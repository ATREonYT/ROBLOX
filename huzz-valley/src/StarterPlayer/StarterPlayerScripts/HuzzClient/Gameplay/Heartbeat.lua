--[[
	The heartbeat (owner, Oct 19: "add a heartbeat effect when someone gets closer" and "add a heartbeat sound when your
	screen turns red from people getting closer"). While you're a runner still in the round, the nearest catcher (or the
	Practice Bot) inside Far studs makes the edges of your screen glow red and pulse with a heartbeat, stronger and a
	little faster the closer they get (full at Near studs).

	Kid-safe and calm: one soft swell per beat, at most one a second (Rate: 0.75 to 1 beats a second), never a flash
	or a full-screen colour; the middle of the screen stays clear. The sound (Sfx "heartbeat") plays once a beat,
	louder the closer they are. Built here at runtime in PlayerGui (a screen effect, like the round's centre words in
	Gameplay/RoundHud: nothing to edit in Studio), four edge frames with a red-to-clear gradient.
	Heartbeat.level / rate / glow and the beat clock (clock / tick: never two beats within MinGap 1 s) are pure maths
	(tests/Heartbeat.spec, the preview).
]]
local Heartbeat = {}

Heartbeat.Far = 30 -- studs: nothing further than this
Heartbeat.Near = 8 -- studs: full strength from here in
Heartbeat.Rate = { 0.75, 1.0 } -- beats a second, far .. near (never more than 1: at most one swell a second)
Heartbeat.Edge = 0.2 -- the glow reaches this share of the screen in from each edge, at full strength
Heartbeat.Color = Color3.fromRGB(215, 24, 48)
Heartbeat.Base = 0.22 -- how strong the steady glow is at full strength (0..1 opacity at the edge)
Heartbeat.Pulse = 0.33 -- how much each beat adds on top, at full strength

-- 0..1 from the nearest catcher's distance (studs).
function Heartbeat.level(distance: number?): number
	if not distance then
		return 0
	end
	local k = math.clamp((Heartbeat.Far - distance) / (Heartbeat.Far - Heartbeat.Near), 0, 1)
	return k * k * (3 - 2 * k)
end

-- Beats a second at level k.
function Heartbeat.rate(k: number): number
	return Heartbeat.Rate[1] + (Heartbeat.Rate[2] - Heartbeat.Rate[1]) * math.clamp(k, 0, 1)
end

-- The edge glow's opacity at level k, `age` seconds into a beat: a quick soft swell (0.12 s) easing back (0.5 s).
function Heartbeat.glow(k: number, age: number): number
	local swell
	if age < 0.12 then
		local x = age / 0.12
		swell = x * x * (3 - 2 * x)
	else
		swell = math.exp(-(age - 0.12) / 0.18)
	end
	return k * (Heartbeat.Base + Heartbeat.Pulse * swell)
end

-- The beat clock (pure: tests/Heartbeat.spec runs it). Never two beats closer than MinGap seconds, whatever the
-- level does. (Oct 19 evening, a fresh critic: the glow hid below 0.01 and the clock reset, so each time it rose back
-- over 0.01 it beat at once: a catcher hovering at the edge of Far made beats faster than one a second.) The clock
-- keeps counting while the glow is hidden, so coming back waits out the gap.
Heartbeat.MinGap = 1
function Heartbeat.clock()
	return { since = math.huge, wait = 0, age = math.huge }
end
-- Advances the clock dt seconds at level k; true when a beat starts this frame (then c.age is 0: the glow's age).
function Heartbeat.tick(c, dt: number, k: number): boolean
	c.since += dt
	c.age += dt
	c.wait -= dt
	if k < 0.01 then
		return false
	end
	if c.wait <= 0 and c.since >= Heartbeat.MinGap then
		c.since, c.age = 0, 0
		c.wait = 1 / Heartbeat.rate(k)
		return true
	end
	return false
end

function Heartbeat.start()
	local Players = game:GetService("Players")
	local RunService = game:GetService("RunService")
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local CollectionService = game:GetService("CollectionService")
	local Net = require(ReplicatedStorage:WaitForChild("Shared").Net)
	local Sfx = require(script.Parent.Sfx)
	local player = Players.LocalPlayer
	local round = Net.get("Round")

	local gui = Instance.new("ScreenGui")
	gui.Name = "HuzzHeartbeat"
	gui.IgnoreGuiInset = true
	gui.ResetOnSpawn = false
	gui.DisplayOrder = -1 -- (under the HUD and windows)
	gui.Enabled = false
	gui.Parent = player:WaitForChild("PlayerGui")
	local edges = {}
	-- top, bottom, left, right: each a red frame fading to clear toward the middle
	for i, e in {
		{ UDim2.fromScale(0, 0), UDim2.fromScale(1, Heartbeat.Edge), 90 },
		{ UDim2.fromScale(0, 1 - Heartbeat.Edge), UDim2.fromScale(1, Heartbeat.Edge), -90 },
		{ UDim2.fromScale(0, 0), UDim2.fromScale(Heartbeat.Edge * 0.62, 1), 0 },
		{ UDim2.fromScale(1 - Heartbeat.Edge * 0.62, 0), UDim2.fromScale(Heartbeat.Edge * 0.62, 1), 180 },
	} do
		local f = Instance.new("Frame")
		f.Name = "Edge" .. i
		f.Position, f.Size = e[1], e[2]
		f.BackgroundColor3 = Heartbeat.Color
		f.BorderSizePixel = 0
		f.BackgroundTransparency = 0
		local g = Instance.new("UIGradient")
		g.Rotation = e[3]
		g.Parent = f
		f.Parent = gui
		edges[i] = g
	end
	local function paint(alpha: number)
		-- (opaque `alpha` at the screen's edge, clear at the frame's inner side, eased)
		local seq = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1 - alpha),
			NumberSequenceKeypoint.new(0.45, 1 - alpha * 0.35),
			NumberSequenceKeypoint.new(1, 1),
		})
		for _, g in edges do
			g.Transparency = seq
		end
	end

	local function nearest(): number?
		local me = player.Character
		local root = me and me:FindFirstChild("HumanoidRootPart")
		if not (root and root:IsA("BasePart")) then
			return nil
		end
		local best = nil
		local function consider(model: Instance?)
			local r = model and model:FindFirstChild("HumanoidRootPart")
			if r and r:IsA("BasePart") then
				local d = (r.Position - root.Position).Magnitude
				if not best or d < best then best = d end
			end
		end
		for _, p in Players:GetPlayers() do
			if p ~= player and p:GetAttribute("HuzzRole") == "Catcher" and p:GetAttribute("HuzzFrozen") ~= true then
				consider(p.Character)
			end
		end
		for _, bot in CollectionService:GetTagged("HuzzBot") do
			consider(bot)
		end
		return best
	end

	local k = 0
	local beat = Heartbeat.clock()
	RunService.RenderStepped:Connect(function(dt)
		local stage = round:GetAttribute("Stage")
		local on = player:GetAttribute("HuzzRole") == "Runner" and player:GetAttribute("HuzzStatus") == "Active"
			and (stage == "Running" or stage == "HeroRun") and player:GetAttribute("HuzzCinematic") ~= true
		local target = if on then Heartbeat.level(nearest()) else 0
		k += (target - k) * (1 - math.exp(-dt * 5)) -- (eases in and out: no jumps when a catcher appears)
		local beats = Heartbeat.tick(beat, dt, k) -- (counts on while hidden: never two beats within MinGap)
		if k < 0.01 then
			gui.Enabled = false
			return
		end
		gui.Enabled = true
		if beats then
			Sfx.play("heartbeat", { volume = 0.35 + 0.65 * k })
			if not Sfx.has("heartbeat") then
				-- (the stand-in is one thump: the second, softer one makes the "lub-dub")
				task.delay(0.2, function()
					Sfx.play("heartbeat", { volume = (0.35 + 0.65 * k) * 0.7, pitch = 0.9 })
				end)
			end
		end
		paint(Heartbeat.glow(k, beat.age))
	end)
end

return Heartbeat

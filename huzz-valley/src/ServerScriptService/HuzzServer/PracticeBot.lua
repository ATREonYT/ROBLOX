--[[
	Practice Bot (owner picked "Yes, add bots": a round must work when you're alone). When a round has runners but
	no catcher (one player in the server, or the only catcher left), a plain blocky catcher named "Practice Bot"
	(Config/Round.Bot) joins: it waits in the middle like a catcher, then chases the nearest runner it may tag and
	stabs within Reach, with a short breather after each stab so a kid can get away (it is also a little slower than
	a sprinting runner, so the huss and a straight run beat it). Round walls and props it follows a PathfindingService
	path (worked out off the round's clock, so the round never waits for it). It is plainly a bot: its name tag says so, it is not a
	player, it never wins a girl and is never paid; if it downs every runner, nobody wins that game.
	RoundService drives it: spawn() at the line-up, setFrozen() with the catchers, step() while play is live,
	remove() when a real catcher exists or the game ends. The body is Roblox's default blocky one
	(Players:CreateHumanoidModelFromDescription), so no asset IDs; its run and idle play from the IDs inside that
	body's own Animate script (that LocalScript can't run on a model nobody owns). The sim swaps in a fake body
	(PracticeBot.makeBody) to test the chase.
]]
local CollectionService = game:GetService("CollectionService")
local PathfindingService = game:GetService("PathfindingService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage:WaitForChild("Shared").Config.Round)
local KnifeService = require(script.Parent.KnifeService)
local NameTags = require(script.Parent.NameTagService)

local PracticeBot = {}

local B = Config.Bot
local model, humanoid, root = nil, nil, nil
local home = nil -- where it waits (the middle of the field)
local frozen = true
local goAt, pauseUntil, nextThink = 0, 0, 0
local stuckAt, stuckPos, dodgeUntil, dodgeTo = 0, nil, 0, nil -- (walked into a wall: step round it for a moment)
local route, routeAt, routing, nextRoute = nil, 1, false, 0 -- a path round walls (PathfindingService waypoints)
local routeFor = nil -- the runner the current path leads to
local routeAsk = 0 -- bumped whenever a path in the works goes stale (moved, frozen, removed)
local tracks = {} -- { run = AnimationTrack?, idle = AnimationTrack? }
local warned = false

-- The default blocky body, in grey with a red shirt so it reads as "not a real player" at a glance.
function PracticeBot.makeBody(): Model
	local desc = Instance.new("HumanoidDescription")
	local skin, shirt, pants = Color3.fromRGB(150, 152, 160), Color3.fromRGB(205, 52, 66), Color3.fromRGB(40, 40, 56)
	desc.HeadColor, desc.LeftArmColor, desc.RightArmColor = skin, skin, skin
	desc.TorsoColor = shirt
	desc.LeftLegColor, desc.RightLegColor = pants, pants
	return Players:CreateHumanoidModelFromDescription(desc, Enum.HumanoidRigType.R15)
end

-- The run and idle from the body's own Animate script (taken out before it's in the world), played from the server
-- once the body is in Workspace (LoadAnimation needs that), so they show for everyone.
local function takeAnimations(m: Model): { [string]: Animation }
	local animateScript = m:FindFirstChild("Animate")
	local out = {}
	for _, folder in { "run", "idle" } do
		local f = animateScript and animateScript:FindFirstChild(folder)
		local a = f and f:FindFirstChildOfClass("Animation")
		if a and a.AnimationId ~= "" then out[folder] = a:Clone() end
	end
	if animateScript then animateScript:Destroy() end
	return out
end

local function animate(h: Humanoid, anims: { [string]: Animation })
	local animator = h:FindFirstChildOfClass("Animator") or Instance.new("Animator")
	animator.Parent = h
	for name, a in anims do
		local ok, track = pcall(function() return animator:LoadAnimation(a) end)
		if ok and track then
			track.Looped = true
			tracks[name] = track
		end
	end
	if tracks.idle then tracks.idle:Play() end
end

-- It adapts to the kids playing it (Config.Bot MinSpeed / MaxSpeed / Step): slower after it wins a game, faster
-- after it loses. Returns "slower" / "faster" when its speed changed (for the message line), else nil.
local speed = B.Speed
function PracticeBot.speed(): number
	return speed
end
function PracticeBot.result(botWon: boolean): string?
	local before = speed
	local step = B.Step or 0
	speed = math.clamp(speed + (if botWon then -step else step), B.MinSpeed or B.Speed, B.MaxSpeed or B.Speed)
	if speed == before then
		return nil
	end
	return if speed < before then "slower" else "faster"
end

local function setSpeed(on: boolean)
	if humanoid then humanoid.WalkSpeed = if on then speed else 0 end
	if not on and humanoid and root then humanoid:MoveTo(root.Position) end
end

function PracticeBot.active(): boolean
	return model ~= nil and root ~= nil and root.Parent ~= nil
end

-- Brings the bot into the round at `at` (a CFrame in the middle). True when it's there.
function PracticeBot.spawn(at: CFrame): boolean
	home = at
	if PracticeBot.active() then
		PracticeBot.place(at)
		return true
	end
	PracticeBot.remove()
	local ok, m = pcall(PracticeBot.makeBody)
	if not (ok and m) then
		if not warned then
			warned = true
			warn("[Huzz] The Practice Bot couldn't be made: " .. tostring(m))
		end
		return false
	end
	local h = m:FindFirstChildOfClass("Humanoid")
	local r = m:FindFirstChild("HumanoidRootPart")
	if not (h and r) then
		m:Destroy()
		return false
	end
	m.Name = B.Name
	h.DisplayName = B.Name
	h.WalkSpeed = 0
	pcall(function()
		h.UseJumpPower, h.JumpPower = true, 0 -- (no jumping anywhere)
		h:SetStateEnabled(Enum.HumanoidStateType.Jumping, false)
		h.BreakJointsOnDeath = false
		h.MaxHealth, h.Health = math.huge, math.huge -- (nothing in the game hurts it)
	end)
	m:SetAttribute("HuzzRole", "Catcher")
	m:SetAttribute("HuzzBot", true)
	pcall(function() CollectionService:AddTag(m, "HuzzBot") end)
	local okAnims, anims = pcall(takeAnimations, m)
	-- a faint red outline, the same as players who catch (RoundHud draws theirs)
	pcall(function()
		local outline = Instance.new("Highlight")
		outline.Name = "HuzzOutline"
		outline.FillTransparency, outline.OutlineTransparency = 1, 0.35
		outline.OutlineColor, outline.FillColor = Color3.fromRGB(255, 64, 64), Color3.fromRGB(255, 64, 64)
		outline.DepthMode = Enum.HighlightDepthMode.Occluded
		outline.Parent = m
	end)
	model, humanoid, root = m, h, r
	m.Parent = Workspace
	m:PivotTo(at)
	if okAnims then pcall(animate, h, anims) end
	pcall(function() r:SetNetworkOwner(nil) end) -- (the server moves it, so it never stutters between owners)
	pcall(NameTags.bot, m, B.Name)
	pcall(KnifeService.give, m) -- (catchers hold their knife in a round)
	frozen = true
	m:SetAttribute("HuzzFrozen", true)
	setSpeed(false)
	return true
end

function PracticeBot.place(at: CFrame)
	home = at
	route, nextRoute, routeAsk = nil, 0, routeAsk + 1 -- (an old path from where it was is no use now)
	if PracticeBot.active() then model:PivotTo(at) end
end

-- Frozen with the catchers (line-up, the pick, the countdown); when it may go, it reacts a moment later.
function PracticeBot.setFrozen(on: boolean)
	if on == frozen then return end
	frozen = on
	if not on then goAt = os.clock() + B.Reaction end
	route, nextRoute, routeAsk = nil, 0, routeAsk + 1
	if model then model:SetAttribute("HuzzFrozen", on) end -- (the red screen glow ignores it only while it waits)
	setSpeed(false)
end

function PracticeBot.remove()
	if model then model:Destroy() end
	model, humanoid, root = nil, nil, nil
	table.clear(tracks)
	frozen = true
	route, routeAsk = nil, routeAsk + 1
end

-- True when nothing solid stands between the bot and `to` (people don't count): then it just runs straight there.
local function clearLine(to: Vector3): boolean
	local ok, hit = pcall(function()
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		local skip = { model }
		for _, p in Players:GetPlayers() do
			if p.Character then table.insert(skip, p.Character) end
		end
		params.FilterDescendantsInstances = skip
		params.RespectCanCollide = true -- (zone boxes and see-through props don't block it)
		params.CollisionGroup = "Default"
		local from = root.Position
		local hit = Workspace:Raycast(from, to - from, params)
		return hit and hit.Instance.CanCollide and hit.Instance.Transparency < 1 -- (invisible walls are the field's edge)
	end)
	return not (ok and hit)
end

-- Works out a way round whatever is in the way, without holding up the round (ComputeAsync waits).
local function findRoute(to: Vector3)
	if routing then return end
	routing = true
	local ask = routeAsk
	task.spawn(function()
		local ok, waypoints = pcall(function()
			local path = PathfindingService:CreatePath({ AgentRadius = 2, AgentHeight = 5, AgentCanJump = false })
			path:ComputeAsync(root.Position, to)
			return if path.Status == Enum.PathStatus.Success then path:GetWaypoints() else nil
		end)
		routing = false
		if ok and waypoints and #waypoints > 1 and root and ask == routeAsk then
			route, routeAt = waypoints, 2
		end
	end)
end

-- One frame of play. targets = the runners it may chase (roots); stab(botRoot) tries a stab and says if it hit
-- someone (or a Heart Shield took it). fallY: below this it has fallen off the field and goes back home.
function PracticeBot.step(targets: { BasePart }, stab: (BasePart) -> boolean, fallY: number?)
	if not PracticeBot.active() then return end
	local now = os.clock()
	if fallY and root.Position.Y < fallY and home then
		model:PivotTo(home)
	end
	local moving = humanoid.WalkSpeed > 0
	local go = not frozen and now >= goAt and now >= pauseUntil
	if go ~= moving then setSpeed(go) end
	-- the run plays while it moves (sped up with its speed), the idle while it stands
	if tracks.run then
		local v = root.AssemblyLinearVelocity
		local speed = if typeof(v) == "Vector3" then Vector3.new(v.X, 0, v.Z).Magnitude else 0
		if speed > 2 and not tracks.run.IsPlaying then
			tracks.run:Play(0.2)
		elseif speed <= 2 and tracks.run.IsPlaying then
			tracks.run:Stop(0.2)
		end
		if tracks.run.IsPlaying then tracks.run:AdjustSpeed(math.clamp(speed / 16, 0.6, 1.8)) end
	end
	if not go then return end
	local best, bestD = nil, math.huge
	for _, t in targets do
		local d = (t.Position - root.Position).Magnitude
		if d < bestD then best, bestD = t, d end
	end
	if best and bestD <= B.Reach * speed / B.Speed then -- (its reach grows and shrinks with its speed)
		if stab(root) then
			pauseUntil = now + B.Pause -- (a breather after each stab: kids get a chance to run)
			setSpeed(false)
			return
		end
	end
	if now < nextThink then return end
	nextThink = now + B.Think
	-- Hardly moved for a second while chasing (a wall or a prop in the way): sidestep for half a second.
	if now >= stuckAt then
		if best and stuckPos and (root.Position - stuckPos).Magnitude < 2 and now >= dodgeUntil then
			local side = root.CFrame.RightVector * (if math.random() < 0.5 then -10 else 10)
			dodgeTo, dodgeUntil = root.Position + side - root.CFrame.LookVector * 3, now + 0.5
		end
		stuckAt, stuckPos = now + 1, root.Position
	end
	if now < dodgeUntil and dodgeTo then
		humanoid:MoveTo(dodgeTo)
		return
	end
	-- Something solid between it and the runner: follow a path round it (refreshed every second).
	if best ~= routeFor then -- (a different runner: the old path leads the wrong way)
		route, nextRoute, routeAsk, routeFor = nil, 0, routeAsk + 1, best
	end
	local goal = if best then best.Position else if home then home.Position else nil
	if goal and not clearLine(goal) then
		if now >= nextRoute then
			nextRoute = now + 1
			findRoute(goal)
		end
		while route and route[routeAt] and Vector3.new(route[routeAt].Position.X - root.Position.X, 0, route[routeAt].Position.Z - root.Position.Z).Magnitude < 3 do
			routeAt += 1
		end
		if route and route[routeAt] then
			humanoid:MoveTo(route[routeAt].Position)
			return
		end
	else
		route = nil
	end
	if best then
		-- aim a little ahead of where they're running (not too far: the huss should still fool it)
		local v = best.AssemblyLinearVelocity
		local lead = if typeof(v) == "Vector3" then Vector3.new(v.X, 0, v.Z) * math.min(B.Lead, bestD / 40) else Vector3.zero
		humanoid:MoveTo(best.Position + lead)
	elseif home then
		humanoid:MoveTo(home.Position) -- nobody to chase: back to the middle
	end
end

return PracticeBot

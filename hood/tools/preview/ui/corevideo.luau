-- corevideo.luau (SCENE=corevideo, Oct 27 round 6: the core loop's payoff and guide on video). Two parts:
--   1. the rebirth payoff: a real rebirth (the server's Rebirth remote with the Power to it), HoodHUD dumped every 1/30 s
--      of game time to <UI_OUT>/r_NNN.json (RFRAMES, default 100: 3.3 s); shoot.js draws them.
--   2. the lasting guide: the tutorial done and "Buy a gun" the goal, the player walks from the lobby's spawn toward the
--      ARMORY (GFRAMES, default 135: 4.5 s); each frame the real HoodClient/GoalGuide's parts (the arrow over the ARMORY,
--      the chevrons ahead of you) go to <UI_OUT>/guide_frames.dat (JSON: { route = 'x,z;x,z', frames = { parts... } } in
--      render14's part format), and render14's walk.js draws the hall with them (GUIDE=<that file>, WALK=<route>).
-- See the README's "Motion" section for the commands.
do
	local RF, GF = RFRAMES or 100, GFRAMES or 135
	local ok0 = waitFor(function() return P.PlayerGui:FindFirstChild('HoodHUD') ~= nil end, 30)
	print('[ui] clients up: ' .. tostring(ok0))
	data.Onboarding = type(data.Onboarding) == 'table' and data.Onboarding or {}
	data.Onboarding.Done, data.Onboarding.Gift = true, true
	data.Cash = 25300
	P:SetAttribute('Cash', data.Cash)
	sync()
	wall(1.5)
	-- 1. the rebirth
	local need = RebirthRules.need(data.Rebirths or 0)
	data.Rep = need + 3
	P:SetAttribute('Power', data.Rep)
	sync()
	wall(1.2)
	-- (task.delay runs on the wall clock here, and writing a frame takes longer than 1/30 s: for these frames it is put on
	-- the frames' own clock, so the moment's beats land where they do in the game)
	local realDelay = task.delay
	local vclock, queue = 0, {}
	local virtual = pcall(function()
		task.delay = function(t, fn, ...)
			table.insert(queue, { At = vclock + (tonumber(t) or 0), Fn = fn, Args = table.pack(...) })
		end
	end)
	local function runDue()
		for i = #queue, 1, -1 do
			local q = queue[i]
			if q.At <= vclock + 1e-6 then
				table.remove(queue, i)
				task.spawn(q.Fn, table.unpack(q.Args, 1, q.Args.n))
			end
		end
	end
	RS.HoodNet.Rebirth:FireServer()
	local hud = P.PlayerGui:FindFirstChild('HoodHUD')
	waitFor(function() runDue(); return hud:FindFirstChild('RebirthMoment', true) ~= nil end, 3)
	for i = 0, RF - 1 do
		local ok, err = pcall(__uiDump, hud, UI_OUT .. ('/r_%03d.json'):format(i))
		if not ok then print('[ui] rebirth frame ' .. i .. ' failed ' .. tostring(err)); break end
		frame(1 / 30)
		vclock += 1 / 30
		runDue()
	end
	if virtual then
		task.delay = realDelay
		for _, q in queue do task.spawn(q.Fn, table.unpack(q.Args, 1, q.Args.n)) end
	end
	print('[ui] rebirth: ' .. RF .. " frames (task.delay on the frames' clock: " .. tostring(virtual) .. ')')
	wall(1)
	-- 2. the guide: "Buy a gun", walking from the spawn toward the ARMORY
	data.Goals.Step = require(RS.Shared.GoalRules).ById.Gun.Step
	sync()
	wall(1.5)
	local m = require(RS.Shared.ActiveMap).get()
	local at = m.Root:GetAttribute('LobbySpawn')
	local spawn = typeof(at) == 'Vector3' and (m.Frame * at) or Vector3.new(2400, 0, 38)
	local armory = game:GetService('CollectionService'):GetTagged('HoodArmory')[1]
	local goal = armory and armory:GetPivot().Position or spawn + Vector3.new(40, 0, 0)
	local flat = Vector3.new(goal.X - spawn.X, 0, goal.Z - spawn.Z)
	local dir = flat.Unit
	local finish = Vector3.new(spawn.X, 0, spawn.Z) + dir * math.max(4, flat.Magnitude - 13)
	local start = Vector3.new(spawn.X, 0, spawn.Z) - dir * 16
	local route = ('%.2f,%.2f;%.2f,%.2f'):format(start.X - 2400, start.Z, finish.X - 2400, finish.Z)
	local root = P.Character and P.Character:FindFirstChild('HumanoidRootPart')
	local feetY = spawn.Y
	local yaw = math.atan2(dir.X, dir.Z)
	local frames = {}
	camFn = nil
	for i = 0, GF - 1 do
		local u = i / (GF - 1)
		local p = start + (finish - start) * u
		local pos = Vector3.new(p.X, feetY + 3, p.Z)
		if root then root.CFrame = CFrame.lookAt(pos, pos + dir) end
		local cam = workspace.CurrentCamera
		if cam then cam.CFrame = CFrame.lookAt(Vector3.new(p.X - math.sin(yaw) * 12, 9.2, p.Z - math.cos(yaw) * 12), Vector3.new(p.X + math.sin(yaw), 3.4, p.Z + math.cos(yaw))) end
		frame(1 / 30)
		local parts = {}
		local kids = {} -- (the arrow, and its trail of chevrons: their own Model since Oct 28)
		for _, name in { 'HoodGoalGuide', 'HoodGoalTrail' } do
			local g = workspace:FindFirstChild(name)
			for _, b in g and g:GetChildren() or {} do table.insert(kids, b) end
		end
		for _, b in kids do
			if b:IsA('BasePart') and b.Transparency < 0.99 then
				table.insert(parts, { n = b.Name, k = b.ClassName, s = { b.Size.X, b.Size.Y, b.Size.Z }, cf = { b.CFrame:GetComponents() }, c = { b.Color.R, b.Color.G, b.Color.B }, m = 'SmoothPlastic', t = b.Transparency, shadow = false, sh = b:IsA('Part') and 'Block' or nil })
			end
		end
		frames[i + 1] = parts
	end
	__fs.writeFile(UI_OUT .. '/guide_frames.dat', __serde.encode('json', { route = route, frames = frames }))
	local shown = 0
	for _, f in frames do if #f > 0 then shown += 1 end end
	print(('[ui] guide: %d frames, the guide drawn in %d, route %s'):format(GF, shown, route))
end

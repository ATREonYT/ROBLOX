-- firstvideo.luau (Oct 27, flow round): a fresh save's first VFRAMES / 30 seconds (default 1200: 40 s) as a 30 fps video,
-- offline. Not run on its own: firstvideo.sh puts it after dump.luau and prelude.luau and in front of feel_base's set-up
-- and tools/checks/route.luau, so the kid plays exactly first30's route (the welcome, BAY 1, Stage 1, the pad, the
-- ARMORY, Stage 2).
-- The game's scripts run on the frames' own clock here (their task.wait / task.delay / os.clock, through the harness's
-- _G.__vtask and _G.__vos), so a beat that lasts 2 s in the game lasts 60 frames in the video however slow the dump is.
-- (The server scripts start before this and keep the wall clock: their own delays, the pad's cash-out say, can land a
-- little early.)
-- Each frame: every enabled ScreenGui -> <UI_OUT>/u_NNNN.json (ui/index.html draws them); every STEP-th frame the
-- camera, the kid, and the parts the scripts add to the world (the guides' arrows, the crew, the effects) ->
-- <UI_OUT>/cams.json, which render14's walk.js draws in the hall (CAMS=<that file>).
do
	_G.__vclock = 0
	local rwait, rspawn, rclock = task.wait, task.spawn, os.clock
	local vt = setmetatable({}, { __index = task })
	local main = coroutine.running() -- (the play-test's own thread: only its frames move the clock, so it waits for real)
	vt.wait = function(t)
		if coroutine.running() == main then return rwait(t) end
		local t0 = _G.__vclock
		local target = t0 + math.max(tonumber(t) or 0, 1e-6)
		local stuck, said = rclock(), false
		repeat
			rwait(0.004)
			if not said and _G.__vclock == t0 and rclock() - stuck > 30 then said = true; print('[video] a wait with no frames for 30 s: ' .. debug.traceback()) end
		until _G.__vclock >= target - 1e-9
		return _G.__vclock - t0
	end
	vt.delay = function(t, fn, ...)
		local args = table.pack(...)
		return rspawn(function()
			vt.wait(t)
			rspawn(fn, table.unpack(args, 1, args.n))
		end)
	end
	_G.__vtask = vt
	_G.__vos = setmetatable({ clock = function() return _G.__vclock end }, { __index = os })
	os = _G.__vos -- (the play-test's own clock too: its waits and the kid clock count game time, not the slow dump's)

	local MAX, STEP = VFRAMES or 1200, VSTEP or 6
	local V = { n = 0, cams = {}, on = false }
	local function one(b, out)
		if #out >= 600 or not b:IsA('BasePart') or b.Transparency >= 0.99 then return end
		local ok, e = pcall(function()
			return { n = b.Name, k = b.ClassName, s = { b.Size.X, b.Size.Y, b.Size.Z }, cf = { b.CFrame:GetComponents() }, c = { b.Color.R, b.Color.G, b.Color.B }, m = 'SmoothPlastic', t = b.Transparency, shadow = false, sh = 'Block' }
		end)
		if ok then table.insert(out, e) end
	end
	local function partsOf(root, out)
		one(root, out)
		for _, b in root:GetDescendants() do one(b, out) end
	end
	__videoStep = function()
		if V.n >= MAX then return end
		local P = game:GetService('Players'):GetPlayers()[1]
		local pg = P and P:FindFirstChildOfClass('PlayerGui')
		local char = P and P.Character
		local root = char and char:FindFirstChild('HumanoidRootPart')
		if not (pg and root) then return end
		local guis = {}
		for _, g in pg:GetChildren() do
			if g:IsA('ScreenGui') and g.Enabled ~= false then table.insert(guis, g) end
		end
		table.sort(guis, function(a, b) return (a.DisplayOrder or 0) < (b.DisplayOrder or 0) end)
		local ok, err = pcall(__uiDumpAll, guis, UI_OUT .. ('/u_%04d.json'):format(V.n))
		if not ok and V.n % 100 == 0 then print('[video] ui dump ' .. V.n .. ': ' .. tostring(err)) end
		if V.n % STEP == 0 then
			local cam = workspace.CurrentCamera.CFrame
			local at = cam.Position + cam.LookVector * 10
			local r = root.CFrame
			local parts = {}
			local map = workspace:FindFirstChild('TheBlockV2')
			for _, c in workspace:GetChildren() do
				if c ~= map and c ~= char and not c:IsA('Camera') and not c:IsA('Terrain') then
					partsOf(c, parts)
				end
			end
			local goons = workspace:FindFirstChild('HoodGoons', true)
			if goons and map and goons:IsDescendantOf(map) then partsOf(goons, parts) end
			V.cams[V.n // STEP + 1] = { c = { cam.X, cam.Y, cam.Z }, l = { at.X, at.Y, at.Z }, a = { r.X, r.Y, r.Z, math.atan2(r.LookVector.X, r.LookVector.Z) }, p = parts }
		end
		V.n += 1
		if V.n % 120 == 0 or V.n == MAX then
			__fs.writeFile(UI_OUT .. '/cams.json', __serde.encode('json', { step = STEP, frames = V.cams }))
			print(('[video] %d frames'):format(V.n))
		end
	end
end

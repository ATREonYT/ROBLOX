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
		-- (Oct 28) VFROM: game frames to let pass unrecorded first (a later stretch, at VSTEP 1, drawn without the minutes
		-- before it)
		V.seen = (V.seen or 0) + 1
		if V.seen <= (VFROM or 0) then return end
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
		-- (Oct 28, feel round) the world's BillboardGuis (the fight's "+N", hit marks, stars, swooshes, the goons' tags, the
		-- pads' words): each projected through the game camera (FOV 70, 1280 x 720) and drawn as a flat box on one
		-- screen layer under the HUD, the farthest first. Not drawn: hiding behind walls (AlwaysOnTop off), LightInfluence.
		local okB, boards = pcall(function()
			local cam = workspace.CurrentCamera.CFrame
			local f = 360 / math.tan(math.rad((workspace.CurrentCamera.FieldOfView or 70) / 2))
			local list = {}
			-- (the map's own boards, the gate signs and pad words, are in render14's scene already; the goons' folder in it
			-- is the scripts')
			local map = workspace:FindFirstChild('TheBlockV2')
			local goons = map and map:FindFirstChild('HoodGoons', true)
			local function prop(i, k, d)
				local ok, v = pcall(function() return i[k] end)
				if ok and v ~= nil then return v end
				return d
			end
			for _, b in workspace:GetDescendants() do
				if b:IsA('BillboardGui') and prop(b, 'Enabled', true) and not (map and b:IsDescendantOf(map) and not (goons and b:IsDescendantOf(goons))) then
					pcall(function() -- (one board that can't be read leaves the others: Lune's instances lack some defaults)
						local host = prop(b, 'Adornee', nil) or b.Parent
						local at = host and ((host:IsA('BasePart') and host.CFrame.Position) or (host:IsA('Attachment') and (host.Parent.CFrame * host.CFrame).Position)) -- (Lune's parts keep CFrame, not Position)
						if not at then return end
						local so, sw = prop(b, 'StudsOffset', Vector3.zero), prop(b, 'StudsOffsetWorldSpace', Vector3.zero)
						at = at + sw + cam.RightVector * so.X + cam.UpVector * so.Y - cam.LookVector * so.Z
						local rel = cam:PointToObjectSpace(at)
						local d = -rel.Z
						local maxd = prop(b, 'MaxDistance', 0)
						if d <= 0.5 or (maxd > 0 and d > maxd) then return end
						local sz = prop(b, 'Size', UDim2.new())
						local w = sz.X.Scale * f / d + sz.X.Offset
						local h = sz.Y.Scale * f / d + sz.Y.Offset
						if w <= 1 or h <= 1 or w >= 4000 or h >= 4000 then return end
						local x, y = 640 + rel.X / d * f, 360 - rel.Y / d * f
						local n = __uiNode(b)
						table.insert(list, { d = d, node = { c = 'Frame', n = b.Name, pos = { 0, x, 0, y }, size = { 0, w, 0, h }, anchor = { 0.5, 0.5 }, bg = { 1, 1, 1 }, bgT = 1, vis = true, z = 1, order = 0, rot = 0, clip = false, auto = 'None', mods = {}, kids = n.kids } })
					end)
				end
			end
			table.sort(list, function(a, b) return a.d > b.d end)
			local kids = {}
			for _, e in list do table.insert(kids, e.node) end
			return { c = 'ScreenGui', n = 'Billboards', insets = 'None', ignoreInset = true, enabled = true, order = -100, zib = 'Sibling', kids = kids, mods = {} }
		end)
		local ok, err = pcall(function()
			local all = { okB and boards or nil }
			for _, g in guis do table.insert(all, __uiNode(g)) end
			__fs.writeFile(UI_OUT .. ('/u_%04d.json'):format(V.n), __serde.encode('json', all))
		end)
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
		if V.n % 30 == 0 or V.n == MAX then -- (often: the route can end a little before MAX)
			__fs.writeFile(UI_OUT .. '/cams.json', __serde.encode('json', { step = STEP, frames = V.cams }))
			print(('[video] %d frames'):format(V.n))
		end
	end
end

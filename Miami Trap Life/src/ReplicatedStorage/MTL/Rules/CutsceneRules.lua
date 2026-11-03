--!strict
-- Pure timeline maths for cutscenes (no Instances, unit-tested in tools/tests/test_story_rules.py).
-- A cutscene is data (ReplicatedStorage/MTL/Cutscenes/<Id>.lua); everything on screen is a function of the clock t,
-- so skipping or tap-advancing is just moving t. See CutsceneController for the data format.
local CutsceneRules = {}

CutsceneRules.MaxLength = 45 -- story scenes stay short (Research: Cutscenes)
CutsceneRules.CharsPerSecond = 40 -- typewriter speed
CutsceneRules.SkipGrace = 1 -- seconds before a skip is accepted (stops accidental skips)
CutsceneRules.SkipHold = 0.6 -- hold this long to skip; a tap only finishes / advances the line

local function clamp01(a: number): number
	if a < 0 then
		return 0
	elseif a > 1 then
		return 1
	end
	return a
end

-- Ease curves. Camera never uses Linear (robotic); it's here for props.
function CutsceneRules.ease(name: string?, a: number): number
	a = clamp01(a)
	if name == "Linear" then
		return a
	elseif name == "Quad" then
		if a < 0.5 then
			return 2 * a * a
		end
		local b = -2 * a + 2
		return 1 - b * b / 2
	elseif name == "QuadIn" then
		return a * a
	elseif name == "QuadOut" then
		return 1 - (1 - a) * (1 - a)
	elseif name == "Cubic" then
		if a < 0.5 then
			return 4 * a * a * a
		end
		local b = -2 * a + 2
		return 1 - b * b * b / 2
	elseif name == "Snap" then
		if a >= 1 then
			return 1
		end
		return 0
	end
	-- "Sine" (default): smooth in and out
	return -(math.cos(math.pi * a) - 1) / 2
end

-- Index of the item whose start time is the latest one <= t (items sorted by .t). 0 = none yet.
function CutsceneRules.indexAt(items: { any }, t: number): number
	local found = 0
	for i, it in items do
		if (it.t or 0) <= t then
			found = i
		else
			break
		end
	end
	return found
end

-- Eased progress (0..1) through a shot's move. Shots without dur hold still (1 = at `to`, or at `from`).
function CutsceneRules.shotAlpha(shot: any, t: number): number
	local dur = shot.dur
	if not dur or dur <= 0 then
		return 1
	end
	return CutsceneRules.ease(shot.ease, (t - (shot.t or 0)) / dur)
end

-- How long a subtitle line stays up: its own dur, or long enough to read.
function CutsceneRules.lineDuration(line: any): number
	if line.dur then
		return line.dur
	end
	return 1.2 + #(line.text or "") / 16
end

-- The line on screen at t (or nil), and its index.
function CutsceneRules.lineAt(lines: { any }, t: number): (any?, number)
	local i = CutsceneRules.indexAt(lines, t)
	local line = lines[i]
	if line and t < line.t + CutsceneRules.lineDuration(line) then
		return line, i
	end
	return nil, i
end

-- Characters of `text` shown at time t for a line that started at t0.
function CutsceneRules.typed(text: string, t0: number, t: number, cps: number?): number
	local n = math.floor((t - t0) * (cps or CutsceneRules.CharsPerSecond))
	return math.clamp(n, 0, #text)
end

-- Tap: if the current line is still typing, finish it (returns t unchanged + true); otherwise jump to the start
-- of the next line (or nil when there is none: let the scene play on).
function CutsceneRules.tapTarget(lines: { any }, t: number, cps: number?): (number?, boolean)
	local line = CutsceneRules.lineAt(lines, t)
	if line and CutsceneRules.typed(line.text, line.t, t, cps) < #line.text then
		return t, true
	end
	for _, l in lines do
		if l.t > t + 0.05 then
			return l.t, false
		end
	end
	return nil, false
end

-- Total length: scene.length, or the end of the last thing in it.
function CutsceneRules.length(scene: any): number
	if scene.length then
		return scene.length
	end
	local last = 0
	for _, s in scene.shots or {} do
		last = math.max(last, (s.t or 0) + (s.dur or 0))
	end
	for _, l in scene.lines or {} do
		last = math.max(last, l.t + CutsceneRules.lineDuration(l))
	end
	for _, a in scene.actions or {} do
		last = math.max(last, (a.t or 0) + (a.dur or 0))
	end
	return last
end

-- Actions that start in (from, to] (fired once while the clock passes them).
function CutsceneRules.crossed(actions: { any }, from: number, to: number): { any }
	local out = {}
	for _, a in actions do
		local at = a.t or 0
		if at > from and at <= to then
			table.insert(out, a)
		end
	end
	return out
end

local function sorted(items: { any }?): boolean
	local last = -math.huge
	for _, it in items or {} do
		if (it.t or 0) < last then
			return false
		end
		last = it.t or 0
	end
	return true
end

-- Checks a scene for mistakes. Returns a list of problems (empty = fine). Used by the tests and by the controller
-- (warns in Output, still plays).
-- a scene as it plays after the choice card picked `option` (lines/actions with another `when` dropped)
function CutsceneRules.branch(scene: any, option: string?): any
	local function keep(list: { any }?): { any }
		local out = {}
		for _, x in list or {} do
			if x.when == nil or x.when == option then
				table.insert(out, x)
			end
		end
		return out
	end
	local copy = table.clone(scene)
	copy.lines = keep(scene.lines)
	copy.actions = keep(scene.actions)
	copy.choice = nil
	return copy
end

function CutsceneRules.validate(scene: any, speakers: { [string]: any }?): { string }
	local problems = {}
	local function bad(msg: string)
		table.insert(problems, msg)
	end
	if type(scene) ~= "table" then
		return { "not a table" }
	end
	-- a scene with a choice card: check every branch as it will really play
	if type(scene.choice) == "table" then
		for _, o in scene.choice.options or {} do
			for _, msg in CutsceneRules.validate(CutsceneRules.branch(scene, o.id), speakers) do
				table.insert(problems, "[" .. tostring(o.id) .. "] " .. msg)
			end
		end
		return problems
	end
	if type(scene.shots) ~= "table" or #scene.shots == 0 then
		bad("no shots")
	end
	if not sorted(scene.shots) then
		bad("shots out of order")
	end
	if not sorted(scene.lines) then
		bad("lines out of order")
	end
	if not sorted(scene.actions) then
		bad("actions out of order")
	end
	local length = CutsceneRules.length(scene)
	if length > CutsceneRules.MaxLength then
		bad("too long: " .. length .. "s")
	end
	if (scene.shots and scene.shots[1] and (scene.shots[1].t or 0) ~= 0) then
		bad("first shot must start at t = 0")
	end
	for _, s in scene.shots or {} do
		if s.fov and (s.fov < 20 or s.fov > 80) then
			bad("fov out of range at t=" .. tostring(s.t))
		end
		if s.ease == "Linear" then
			bad("linear camera ease at t=" .. tostring(s.t))
		end
	end
	local lines = scene.lines or {}
	for i, l in lines do
		if type(l.text) ~= "string" or l.text == "" then
			bad("empty line at t=" .. tostring(l.t))
		end
		if speakers and l.who and not speakers[l.who] then
			bad("unknown speaker " .. tostring(l.who))
		end
		local nextLine = lines[i + 1]
		if nextLine and l.t + CutsceneRules.lineDuration(l) > nextLine.t + 0.01 then
			bad("line at t=" .. l.t .. " overlaps the next one")
		end
		if l.t + CutsceneRules.lineDuration(l) > length + 0.01 then
			bad("line at t=" .. l.t .. " runs past the end")
		end
		-- readable: at least 1 s per 15 characters once fully typed
		local typing = #l.text / CutsceneRules.CharsPerSecond
		if CutsceneRules.lineDuration(l) - typing < #l.text / 25 then
			bad("line at t=" .. l.t .. " is too short to read")
		end
	end
	local actors = scene.actors or {}
	for _, a in scene.actions or {} do
		if a.actor and not actors[a.actor] and not (scene.props and scene.props[a.actor]) then
			bad("action for unknown actor " .. tostring(a.actor))
		end
	end
	return problems
end

return CutsceneRules

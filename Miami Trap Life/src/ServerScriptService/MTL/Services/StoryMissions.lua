--!strict
-- Story missions after Act 1 (Config/Chapters; Story Bible §4, §6). Runs only once the stage machine reaches
-- FreePlay, so Act 1 is untouched. One mission at a time: the first open one in the chapter's list.
--   open    -> the giver's texts, the objective line and a waypoint (step 1 is usually "go")
--   go      -> server-checked arrival (WaypointService) moves on
--   scene   -> CutsceneService.play at the place's anchor; a choice card's pick is checked and saved in Choices
--   texts   -> phone texts, then move on
--   done    -> reward, banner, contacts, follow-up texts; the next mission opens
-- Save (data.Story.Data): Chapter = number, Missions = { [id] = step index | "done" }, Choices = { [key] = option }.
-- The phone's Story app reads the player attribute MTL_Story (JSON, see publish()).
-- Studio: _G.MTL.StoryMissions.debugStart(player, "KevKnows") jumps straight to a mission.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")

local Chapters = require(ReplicatedStorage.MTL.Config.Chapters)
local Story = require(ReplicatedStorage.MTL.Config.Story)
local DataService = require(script.Parent.DataService)
local EconomyService = require(script.Parent.EconomyService)
local StoryService = require(script.Parent.StoryService)
local WaypointService = require(script.Parent.WaypointService)
local PhoneService = require(script.Parent.PhoneService)
local CutsceneService = require(script.Parent.CutsceneService)
local StoryWelcome = require(script.Parent.StoryWelcome)
local Notify = require(script.Parent.Notify)
local Analytics = require(script.Parent.Analytics)

local StoryMissions = {}

local WAYPOINT = "StoryMission"
local running: { [Player]: string } = {} -- mission id whose step is being run right now (one runner per player)

local function log(...)
	print("[MTL StoryMissions]", ...)
end

local function sdata(player: Player): any?
	local data = DataService.get(player)
	if not data then
		return nil
	end
	local d = data.Story.Data
	d.Missions = d.Missions or {}
	d.Choices = d.Choices or {}
	return d
end

---------------------------------------------------------------- places

-- A set's anchor parts by name (without the prefix), as world positions. Missing set -> empty table.
local function setMarks(place: any): ({ [string]: Vector3 }, Instance?)
	local marks = {}
	local root = place.set and workspace:FindFirstChild(place.set, true)
	local folder = root and root:FindFirstChild("Anchors")
	if folder then
		for _, p in folder:GetChildren() do
			local pos: Vector3? = if p:IsA("BasePart") then p.Position elseif p:IsA("Attachment") then p.WorldPosition else nil
			if pos then
				local name = if place.prefix and string.sub(p.Name, 1, #place.prefix) == place.prefix then string.sub(p.Name, #place.prefix + 1) else p.Name
				marks[name] = pos
			end
		end
	end
	return marks, root
end

local function waypointOf(placeId: string): (Vector3, number)
	local place = Chapters.Places[placeId]
	if place.set then
		local marks = setMarks(place)
		local door = marks.AlleyDoor or marks.FireEscape_Bottom
		if door and place.waypoint and (door - place.waypoint).Magnitude < 40 then
			return Vector3.new(door.X, place.waypoint.Y, door.Z), place.radius or 10
		end
	end
	return place.waypoint or place.at, place.radius or 10
end

-- the anchor a scene plays at, and the marks it gets (set scenes: identity anchor, marks = world anchor points)
local function sceneAnchor(placeId: string): (CFrame, { [string]: Vector3 }?)
	local place = Chapters.Places[placeId]
	if place.store then
		return StoryWelcome.storeAnchor(), nil
	elseif place.set then
		local marks = setMarks(place)
		return CFrame.new(), if next(marks) then marks else nil
	end
	return CFrame.new(place.at), nil
end

---------------------------------------------------------------- gates

local function isDone(d: any, id: string): boolean
	return d.Missions[id] == "done"
end

local function allDone(d: any, ids: { string }?): boolean
	for _, id in ids or {} do
		if not isDone(d, id) then
			return false
		end
	end
	return true
end

-- why a mission isn't open yet (nil = open). Reasons are short, for the Story app.
local function gate(player: Player, data: any, d: any, id: string): string?
	local m = Chapters.Missions[id]
	if isDone(d, id) then
		return "done"
	end
	if (d.Chapter or 1) < m.chapter then
		return "chapter"
	end
	if m.path and data.Path ~= m.path then
		return "path"
	end
	if not allDone(d, m.needs) then
		return "needs"
	end
	if m.needsAny then
		local any = false
		for _, group in m.needsAny do
			if allDone(d, group) then
				any = true
			end
		end
		if not any then
			return "needs"
		end
	end
	if (data.Level or 1) < m.level then
		return "level"
	end
	return nil
end

local function chapterOf(n: number): any?
	for _, c in Chapters.List do
		if c.id == n then
			return c
		end
	end
	return nil
end

-- the mission to run now: one already in progress, else the first open one
local function current(player: Player): string?
	local data = DataService.get(player)
	local d = sdata(player)
	if not data or not d then
		return nil
	end
	local chapter = chapterOf(d.Chapter or 1)
	if not chapter then
		return nil
	end
	for _, id in chapter.missions do
		if type(d.Missions[id]) == "number" and gate(player, data, d, id) == nil then
			return id
		end
	end
	for _, id in chapter.missions do
		if gate(player, data, d, id) == nil then
			return id
		end
	end
	return nil
end

---------------------------------------------------------------- the Story app's data

local function objectiveOf(m: any, stepIndex: number): string
	for i = stepIndex, 1, -1 do
		local s = m.steps[i]
		if s.objective then
			return s.objective
		end
	end
	return m.title
end

-- Shape agreed with the phone thread (its Story app reads this; every field optional):
-- { chapter, chapterTitle, chapters = {{n, title, state}}, missions = {{id, title, state, giver, blurb, level, line}},
--   objective = { text, place? = Config/Phone.Places id }, cast = {{id, name, role}} }   state = "done"|"active"|"locked"
function StoryMissions.publish(player: Player)
	local data = DataService.get(player)
	local d = sdata(player)
	if not data or not d then
		return
	end
	local n = d.Chapter or 1
	local chapter = chapterOf(n)
	local out: { [string]: any } = { chapter = n, chapterTitle = if chapter then chapter.title else Chapters.Act1.title }
	out.chapters = { { n = 1, title = Chapters.Act1.title, state = if StoryService.stage(player) == "FreePlay" then "done" else "active" } }
	for _, c in Chapters.List do
		table.insert(out.chapters, { n = c.id, title = c.title, state = if n > c.id then "done" elseif n == c.id then "active" else "locked" })
	end
	if chapter then
		out.missions = {}
		local cur = current(player)
		for _, id in chapter.missions do
			local m = Chapters.Missions[id]
			local why = gate(player, data, d, id)
			local state = if why == "done" then "done" elseif id == cur then "active" else "locked"
			local blurb = m.blurb
			if state == "locked" then
				blurb = if why == "level" then string.format("Unlocks at Level %d.", m.level)
					elseif why == "path" then "Criminal path only."
					elseif why == "needs" then "Finish the missions before it first."
					else "Up next."
			end
			table.insert(out.missions, { id = id, title = m.title, state = state, giver = m.giver, blurb = blurb, level = m.level, line = m.line })
			if id == cur then
				local step = if type(d.Missions[id]) == "number" then d.Missions[id] else 1
				local place: string? = nil
				for i = step, 1, -1 do
					local st = m.steps[i]
					if st.kind == "go" then
						place = Chapters.Places[st.at] and Chapters.Places[st.at].phonePlace
						break
					end
				end
				out.objective = { text = objectiveOf(m, step), place = place }
			end
		end
	end
	-- cast: everyone you have a phone thread with (Story.Contacts ids), the story's people first
	out.cast = {}
	local contacts = data.Phone and data.Phone.Contacts or {}
	for _, id in { "Patel", "Dre", "Smoke", "Nina", "Kev", "Royce", "Rico", "Tasha" } do
		local c = (Story.Contacts :: any)[id]
		if c and contacts[id] then
			table.insert(out.cast, { id = id, name = c.Name, role = c.Subtitle })
		end
	end
	player:SetAttribute("MTL_Story", HttpService:JSONEncode(out))
end

---------------------------------------------------------------- running a mission

local runStep: (Player, string) -> ()

local function setStep(player: Player, id: string, step: number | string)
	local d = sdata(player)
	if d then
		d.Missions[id] = step
		DataService.push(player)
	end
	StoryMissions.publish(player)
end

local function sendTexts(player: Player, texts: { any }?, gap: number?)
	for i, t in texts or {} do
		if i > 1 then
			task.wait(gap or 1.4)
		end
		if not player.Parent then
			return
		end
		PhoneService.text(player, t[1], t[2])
	end
end

local function complete(player: Player, id: string)
	local m = Chapters.Missions[id]
	WaypointService.clear(player, WAYPOINT)
	setStep(player, id, "done")
	local r = m.reward or {}
	if r.cash and r.cash > 0 then
		EconomyService.addCash(player, r.cash, "Story:" .. id, true)
	end
	if r.xp and r.xp > 0 then
		EconomyService.addXP(player, r.xp, "Story:" .. id)
	end
	Notify.banner(player, "MISSION COMPLETE", m.title)
	Notify.objective(player, "")
	Analytics.custom(player, "StoryMission", 1, { Mission = id })
	log(player.Name, "done", id)
	task.delay(6, function()
		if not player.Parent then
			return
		end
		sendTexts(player, m.done)
		-- the chapter's end
		local d = sdata(player)
		local chapter = d and chapterOf(d.Chapter or 1)
		if d and chapter and allDone(d, { chapter.missions[#chapter.missions] }) then
			d.Chapter = (d.Chapter or 1) + 1
			DataService.push(player)
			StoryMissions.publish(player)
			if chapter.goal then
				Notify.toast(player, "New goal: " .. chapter.goal)
			end
		end
		StoryMissions.check(player)
	end)
end

local function startStep(player: Player, id: string, index: number)
	local m = Chapters.Missions[id]
	if index > #m.steps then
		complete(player, id)
		return
	end
	setStep(player, id, index)
	local s = m.steps[index]
	if s.kind == "go" then
		local pos, radius = waypointOf(s.at)
		Notify.objective(player, s.objective or m.title)
		WaypointService.set(player, WAYPOINT, pos, { label = s.label or m.title, radius = s.radius or radius })
		return -- WaypointService.Arrived moves on
	end
	running[player] = id
	task.spawn(function()
		local ok, err = pcall(runStep, player, id)
		if not ok then
			warn("[MTL StoryMissions]", id, "step", index, "failed:", err)
		end
		if running[player] == id then
			running[player] = nil
		end
	end)
end

-- runs the non-"go" step the save points at (scene / texts), then starts the next one
runStep = function(player: Player, id: string)
	local d = sdata(player)
	local m = Chapters.Missions[id]
	local index = d and d.Missions[id]
	if type(index) ~= "number" then
		return
	end
	local s = m.steps[index]
	if s.kind == "scene" then
		WaypointService.clear(player, WAYPOINT)
		Notify.objective(player, "")
		local anchor, marks = sceneAnchor(s.anchor)
		local _, _, choice = CutsceneService.play(player, s.id, { anchor = anchor, marks = marks })
		if not player.Parent then
			return
		end
		if s.choice then
			choice = choice or (d :: any).Choices[s.choice]
			local effect = choice and Chapters.ChoiceEffects[s.choice] and Chapters.ChoiceEffects[s.choice][choice]
			if effect and effect.cost then
				if not EconomyService.spend(player, effect.cost, "Story:" .. s.choice .. ":" .. choice) then
					Notify.toast(player, effect.short or ("You need $" .. effect.cost))
					-- back to the "go" before this scene: come back when you can pay (or pick something else)
					local back = index - 1
					while back > 1 and m.steps[back].kind ~= "go" do
						back -= 1
					end
					startStep(player, id, math.max(back, 1))
					return
				end
			end
			if choice then
				(d :: any).Choices[s.choice] = choice
				Analytics.custom(player, "StoryChoice", 1, { Key = s.choice, Option = choice })
				log(player.Name, "choice", s.choice, "=", choice)
			end
		end
	elseif s.kind == "texts" then
		sendTexts(player, s.texts, s.gap)
		task.wait(1)
	end
	if player.Parent then
		startStep(player, id, index + 1)
	end
end

-- opens / resumes whatever should be running for this player now
function StoryMissions.check(player: Player)
	local data = DataService.get(player)
	local d = sdata(player)
	if not data or not d or running[player] then
		return
	end
	if StoryService.stage(player) ~= "FreePlay" then
		return
	end
	-- the chapter opens at its level: a beat, then the giver's texts
	if (d.Chapter or 1) < 2 and (data.Level or 1) >= Chapters.List[1].level then
		d.Chapter = 2
		DataService.push(player)
		local c = Chapters.List[1]
		Notify.banner(player, "CHAPTER " .. c.id, c.title)
		log(player.Name, "chapter", c.id)
		task.wait(4)
	end
	StoryMissions.publish(player)
	local id = current(player)
	if not id then
		return
	end
	local m = Chapters.Missions[id]
	local step = d.Missions[id]
	if type(step) ~= "number" then
		-- a new mission: the giver texts you first
		setStep(player, id, 1)
		running[player] = id
		sendTexts(player, m.offer)
		running[player] = nil
		if not player.Parent then
			return
		end
		startStep(player, id, 1)
		return
	end
	-- resuming: a scene/texts step re-runs from the "go" before it (you walk back to where it happens)
	local back = step
	while back > 1 and m.steps[back].kind ~= "go" do
		back -= 1
	end
	startStep(player, id, back)
end

function StoryMissions.debugStart(player: Player, id: string)
	assert(RunService:IsStudio(), "[MTL StoryMissions] debugStart is Studio-only")
	local d = sdata(player)
	local m = Chapters.Missions[id]
	if not d or not m then
		return
	end
	d.Chapter = m.chapter
	for _, other in Chapters.List[1].missions do
		if other == id then
			break
		end
		d.Missions[other] = "done"
	end
	d.Missions[id] = 1
	running[player] = nil
	startStep(player, id, 1)
end

function StoryMissions.init()
	Players.PlayerRemoving:Connect(function(player)
		running[player] = nil
	end)
	WaypointService.Arrived:Connect(function(player, wpId)
		if wpId ~= WAYPOINT or running[player] then
			return
		end
		local id = current(player)
		local d = sdata(player)
		local step = id and d and d.Missions[id]
		if id and type(step) == "number" and Chapters.Missions[id].steps[step].kind == "go" then
			startStep(player, id, step + 1)
		end
	end)
	StoryService.onEnter("FreePlay", function(player)
		task.wait(3)
		StoryMissions.check(player)
	end)
	EconomyService.LevelUp:Connect(function(player)
		task.delay(5, function() -- after the level-up banner
			if player.Parent and not running[player] then
				local d = sdata(player)
				local id = current(player)
				-- only open something new (a mission in progress keeps its waypoint)
				if not (id and d and type(d.Missions[id]) == "number") then
					StoryMissions.check(player)
				else
					StoryMissions.publish(player)
				end
			end
		end)
	end)
	PhoneService.PathChanged:Connect(function(player)
		StoryMissions.publish(player)
	end)
	-- Studio only: a bridge for MCP / plugin tools, which run in another Lua VM and can't see _G.MTL.
	--   ServerStorage.MTL_StoryDebug:Invoke("start", "KevKnows")   jump the first player to that mission
	--   :Invoke("scene", "Cash4Gold", "Cash4Gold")                    play a scene at a place (no mission state)
	--   :Invoke("state")                                               stage, level, MTL_Story
	if RunService:IsStudio() then
		local bf = Instance.new("BindableFunction")
		bf.Name = "MTL_StoryDebug"
		bf.OnInvoke = function(cmd: string, a: any, b: any): any
			local player = Players:GetPlayers()[1]
			if not player then
				return "no player"
			end
			if cmd == "start" then
				if StoryService.stage(player) ~= "FreePlay" then
					StoryService.debugSet(player, "FreePlay")
				end
				task.spawn(StoryMissions.debugStart, player, a)
				return "started " .. tostring(a)
			elseif cmd == "scene" then
				local anchor, marks = sceneAnchor(b)
				task.spawn(function()
					local f, sk, ch = CutsceneService.play(player, a, { anchor = anchor, marks = marks })
					print("[MTL StoryMissions] debug scene", a, "finished", f, "skipped", sk, "choice", ch)
				end)
				return "playing " .. tostring(a)
			elseif cmd == "state" then
				local data = DataService.get(player)
				return string.format("stage=%s level=%s story=%s", tostring(StoryService.stage(player)), tostring(data and data.Level), tostring(player:GetAttribute("MTL_Story")))
			end
			return "unknown command"
		end
		bf.Parent = game:GetService("ServerStorage")
	end
end

return StoryMissions

--[[
	Takes away anything that hangs on or trails after a body without belonging to it (owner, Oct 20 20:34: "can you fix
	this, remove that black thing following my character please, i asked so many times"; his pictures
	design/owner-oct20/2034-*). The block's cause was never proven offline (docs/notes/knives.md, "Honest gaps"), so
	each screen now finds it and removes it by itself, on every player's body, about once a second:
	  (a) Joined: a visible part held to a body (a weld, motor or constraint, through any chain of them) that sits
	      outside that character's model.
	  (b) Following: a small visible part (no side over BIGGEST studs) outside every character that has stayed within
	      NEAR studs of a body while that body moved FOLLOW studs or more (and FOLLOW_TIME seconds or more).
	  (c) Loose inside (Oct 21, owner: "find what it is, and don't try to hide it, remove it"): a visible part INSIDE a
	      player's own character (his Studio picture design/owner-oct20/2034-black-block-close.png has the block
	      outlined together with his legs, so it is part of his character, which (a) and (b) never looked at) that is
	      not a body part and whose box sits more than LOOSE studs off every body part: removed (Destroy) on this
	      screen. Worn knives are checked too (a piece off the body is the bug, wherever it comes from); the knife in
	      a hand, the carried girl and a big accessory (wings, a long sword on the back) are not.
	(a) and (b) are hidden on this screen (LocalTransparencyModifier 1; Transparency 1 where that doesn't hold). Each
	gets ONE Output line: "[HuzzBlock] hid|removed <path> ..." with its class, size, colour, anchored, shadow, what
	holds it and its ancestry, so the real cause can still be named and fixed at its source.
	Never touched (tests/FollowGuard.spec puts each beside a body): anything inside a character or another Humanoid
	model (bots, girls, stand copies), the worn and held knives, the carried girl and a catcher's follower, the
	companion, the Shield bubble, the knife motes, the crown, the power effects and bursts, the aura, seats (a SeatWeld
	joins a seat to whoever sits), anchored parts in (a) (welded to the world, not carried) and anything with the
	attribute HuzzOnBody. Errors go to Output on "[Huzz] FollowGuard:" lines; one body's error never stops the others.
]]
local M = {}
M.EVERY = 1 -- seconds
M.NEAR = 4 -- studs from the body's root
M.FOLLOW = 12 -- studs the body moved while the part stayed near
M.FOLLOW_TIME = 2 -- seconds (a burst's sparks live less than that)
M.BIGGEST = 3 -- studs: a bigger part isn't the little block
M.SEE = 0.95 -- more see-through than this: already invisible
M.MAX_LINES = 12
-- (c) the loose-part rules are Shared/LooseParts (the server's HuzzServer/BlockSweep uses the same)
local LooseParts = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("LooseParts"))
M.LOOSE = LooseParts.KNIFE
M.LIMBS = LooseParts.LIMBS
-- The game's own things that are meant to be on or beside a body (a part inside one of these is never hidden).
M.ALLOW = {
	HuzzBackKnife = true, HuzzKnife = true, -- the worn and held knives (HuzzServer/KnifeService)
	HuzzCarried = true, HuzzFollowers = true, -- the round's girl, carried or following a catcher (HuzzServer/CarryService)
	HuzzCompanions = true, -- your girl walking behind you (Gameplay/Auras)
	HuzzShields = true, HuzzShield = true, -- the Shield bubble (HuzzServer/PowerService)
	HuzzKnifeMotes = true, -- a knife's ball motes (Gameplay/KnifeFxRange)
	HuzzCrown = true, -- the Crown Pose (Gameplay/CrownPose)
	HuzzBursts = true, -- the power effects, ghosts, Body Double and bursts (Gameplay/Burst.home)
	HuzzBodyDouble = true, HuzzAuraFX = true, HuzzAuraStars = true,
	HuzzAvatarStands = true, HuzzStandAvatars = true, -- the lobby stands and the copies on them
}

local function isA(x: any, class: string): boolean
	local ok, yes = pcall(function() return x:IsA(class) end)
	return ok and yes == true
end

local function read(x: any, key: string): any
	local ok, v = pcall(function() return x[key] end)
	return if ok then v else nil
end

-- Inside a model with a Humanoid (a character, a bot, a girl, a stand copy)?
local function inBody(p: Instance): boolean
	local x = p.Parent
	while x and not isA(x, "DataModel") do
		if isA(x, "Model") and x:FindFirstChildOfClass("Humanoid") then return true end
		x = x.Parent
	end
	return false
end
M.inBody = inBody

-- One of the game's own things meant to be on a body (M.ALLOW, the HuzzOnBody attribute) or a seat.
local function allowed(p: Instance): boolean
	if isA(p, "Seat") or isA(p, "VehicleSeat") then return true end
	local x = p
	while x and not isA(x, "DataModel") do
		if M.ALLOW[x.Name] or read(x, "GetAttribute") and x:GetAttribute("HuzzOnBody") == true then return true end
		x = x.Parent
	end
	return false
end
M.allowed = allowed

local function visible(p: BasePart): boolean
	local t = read(p, "Transparency") or 0
	local ltm = read(p, "LocalTransparencyModifier") or 0
	return t < M.SEE and ltm < M.SEE
end

local function biggest(p: BasePart): number
	local s = p.Size
	return math.max(s.X, s.Y, s.Z)
end

-- The two parts a joint holds (welds and motors name them; constraints name two Attachments).
local function ends(j: Instance): (Instance?, Instance?)
	local a, b = read(j, "Part0"), read(j, "Part1")
	if a ~= nil or b ~= nil then return a, b end
	local a0, a1 = read(j, "Attachment0"), read(j, "Attachment1")
	return a0 and a0.Parent, a1 and a1.Parent
end
M.ends = ends

-- What holds a part there, in words.
local function holders(p: BasePart, joints: (BasePart) -> { Instance }): string
	local list = {}
	for _, j in joints(p) do
		local a, b = ends(j)
		local other = if a == p then b else a
		table.insert(list, `{j.ClassName} {j.Name} -> {if other then other:GetFullName() else "nothing"}`)
	end
	if #list == 0 then return if p.Anchored then "nothing: anchored (moved by a script?)" else "nothing" end
	return table.concat(list, ", ")
end

local function ancestry(p: Instance): string
	local out = {}
	local x = p
	while x and not isA(x, "DataModel") do
		table.insert(out, 1, `{x.Name} ({x.ClassName})`)
		x = x.Parent
	end
	return table.concat(out, " > ")
end

-- The Output line for a part found (why: "joined to alex's body" / "followed alex 14 studs").
function M.line(p: BasePart, why: string, joints: (BasePart) -> { Instance }): string
	local s, c = p.Size, p.Color
	return string.format("[HuzzBlock] hid %s: %s; %s, size %.2f x %.2f x %.2f, colour %d,%d,%d, anchored %s, shadow %s; held by %s; in %s. Send Claude this line.",
		p:GetFullName(), why, p.ClassName, s.X, s.Y, s.Z, math.floor(c.R * 255 + 0.5), math.floor(c.G * 255 + 0.5), math.floor(c.B * 255 + 0.5),
		tostring(p.Anchored), if read(p, "CastShadow") == false then "off" else "on", holders(p, joints), ancestry(p))
end

-- A part that may be found: visible, outside every character and Humanoid model, not one of the game's own.
local function suspect(p: Instance): boolean
	return isA(p, "BasePart") and not isA(p, "Terrain") and visible(p :: BasePart) and not inBody(p) and not allowed(p)
end
M.suspect = suspect

--[[
	(a) The visible parts held to this body from outside its model. joints(part) -> the joints and constraints on that
	part (Roblox: part:GetJoints()); connected (optional): more parts in the body's assembly (root:GetConnectedParts).
	Anchored parts and seats aren't carried by the body (it's held to them), so they're left alone.
]]
function M.joined(character: Instance, joints: (BasePart) -> { Instance }, connected: { BasePart }?): { BasePart }
	local found, seen, queue = {}, {}, {}
	for _, d in character:GetDescendants() do
		if isA(d, "BasePart") then
			seen[d] = true
			table.insert(queue, d)
		end
	end
	local function consider(o: Instance?, via: Instance?)
		if not o or seen[o] or not isA(o, "BasePart") then return end
		seen[o] = true
		if o:IsDescendantOf(character) then table.insert(queue, o) return end
		if via and via.Name == "SeatWeld" then return end
		if (o :: BasePart).Anchored or allowed(o) or inBody(o) then return end
		if visible(o :: BasePart) then table.insert(found, o :: BasePart) end
		if #queue < 2000 then table.insert(queue, o) end -- (what hangs off it, too)
	end
	local i = 1
	while i <= #queue do
		local p = queue[i]
		i += 1
		for _, j in joints(p) do
			local a, b = ends(j)
			consider(a, j)
			consider(b, j)
		end
	end
	for _, p in connected or {} do consider(p, nil) end
	return found
end

--[[
	(b) Small parts that follow this body. rec: this body's memory between checks ({ [part] = { from, at } });
	pool: the small parts to look at (M.collect); at: the body's root position; now: seconds. Returns the parts that
	stayed within NEAR studs while the body moved FOLLOW studs over FOLLOW_TIME seconds or more, and how far it moved.
]]
function M.following(rec: { [BasePart]: any }, pool: { [BasePart]: boolean }, at: Vector3, now: number): { { part: BasePart, moved: number } }
	local out = {}
	local near = {}
	for p in pool do
		if p.Parent then
			local d = (p.CFrame.Position - at).Magnitude
			-- (a piece of something big, e.g. a moving platform he rides, moves with that, not with him)
			local holder = read(p, "AssemblyRootPart")
			local onBig = holder ~= nil and holder ~= p and isA(holder, "BasePart") and biggest(holder) > M.BIGGEST
			if d <= M.NEAR + biggest(p) / 2 and not onBig and suspect(p) then near[p] = true end
		end
	end
	for p in rec do
		if not near[p] then rec[p] = nil end
	end
	for p in near do
		local r = rec[p]
		if not r then
			rec[p] = { from = at, at = now }
		else
			local moved = (at - r.from).Magnitude
			if moved >= M.FOLLOW and now - r.at >= M.FOLLOW_TIME then table.insert(out, { part = p, moved = moved }) end
		end
	end
	return out
end

-- The small parts (b) looks at, from a Workspace (kept up to date in start()).
function M.fits(p: Instance): boolean
	return isA(p, "BasePart") and not isA(p, "Terrain") and biggest(p :: BasePart) <= M.BIGGEST and not inBody(p) and not allowed(p)
end
function M.collect(root: Instance): { [BasePart]: boolean }
	local pool = {}
	for _, d in root:GetDescendants() do
		if M.fits(d) then pool[d] = true end
	end
	return pool
end

-- (c) The visible parts inside this character that sit loose off its body: { { part, gap } } (Shared/LooseParts).
function M.loose(character: Instance): { { part: BasePart, gap: number } }
	return LooseParts.find(character)
end

-- Hidden on this screen only.
function M.hide(p: BasePart)
	local ok = pcall(function() p.LocalTransparencyModifier = 1 end)
	if not ok or (read(p, "LocalTransparencyModifier") or 0) < 1 then
		pcall(function() p.Transparency = 1 end)
	end
end

--[[
	One check of every body. bodies: { { name, character, root } }; state: kept between checks ({ recs, hidden, told });
	io: { joints, connected?, pool, say }. Returns the parts hidden or removed this time.
]]
function M.check(bodies, state, io, now: number): { BasePart }
	state.recs = state.recs or {}
	state.hidden = state.hidden or {}
	state.told = state.told or 0
	local hid = {}
	local function take(p: BasePart, why: string)
		if state.hidden[p] then
			if (read(p, "LocalTransparencyModifier") or 0) < 1 and (read(p, "Transparency") or 0) < 1 then M.hide(p) end -- (reset by something)
			return
		end
		state.hidden[p] = true
		if state.told < M.MAX_LINES then
			state.told += 1
			io.say(M.line(p, why, io.joints))
		end
		M.hide(p)
		table.insert(hid, p)
		pcall(function() p:Destroy() end) -- (owner, Oct 21: "don't try to hide it, remove it")
	end
	local function remove(p: BasePart, why: string)
		if state.told < M.MAX_LINES then
			state.told += 1
			io.say((string.gsub(M.line(p, why, io.joints), "^%[HuzzBlock%] hid ", "[HuzzBlock] removed ")))
		end
		table.insert(hid, p)
		pcall(function() p:Destroy() end)
	end
	for _, b in bodies do
		local ok, err = pcall(function()
			for _, p in M.joined(b.character, io.joints, io.connected and io.connected(b.root)) do
				take(p, `joined to {b.name}'s body`)
			end
			for _, l in M.loose(b.character) do
				remove(l.part, string.format("loose inside %s's character, %.1f studs off the body", b.name, l.gap))
			end
			local rec = state.recs[b.character] or {}
			state.recs[b.character] = rec
			for _, f in M.following(rec, io.pool, b.root.CFrame.Position, now) do
				take(f.part, string.format("followed %s for %.0f studs", b.name, f.moved))
			end
		end)
		if not ok then io.say("[Huzz] FollowGuard: " .. tostring(err)) end
	end
	for character in state.recs do
		if not character.Parent then state.recs[character] = nil end
	end
	for p in state.hidden do
		if not p.Parent then state.hidden[p] = nil end
	end
	return hid
end

function M.start()
	local Players = game:GetService("Players")
	local Workspace = game:GetService("Workspace")
	local pool = M.collect(Workspace)
	Workspace.DescendantAdded:Connect(function(d)
		if isA(d, "BasePart") then task.defer(function() if d.Parent and M.fits(d) then pool[d] = true end end) end
	end)
	Workspace.DescendantRemoving:Connect(function(d) pool[d] = nil end)
	local io = {
		joints = function(p: BasePart): { Instance }
			local ok, list = pcall(function() return p:GetJoints() end)
			return if ok and type(list) == "table" then list else {}
		end,
		connected = function(root: BasePart): { BasePart }
			local ok, list = pcall(function() return root:GetConnectedParts(true) end)
			return if ok and type(list) == "table" then list else {}
		end,
		pool = pool,
		say = function(s: string) warn(s) end,
	}
	local state = {}
	while true do
		task.wait(M.EVERY)
		local bodies = {}
		for _, player in Players:GetPlayers() do
			local character = player.Character
			local root = character and character:FindFirstChild("HumanoidRootPart")
			if root and root:IsA("BasePart") then
				table.insert(bodies, { name = player.Name, character = character, root = root })
			end
		end
		local ok, err = pcall(M.check, bodies, state, io, os.clock())
		if not ok then warn("[Huzz] FollowGuard: " .. tostring(err)) end
	end
end

return M

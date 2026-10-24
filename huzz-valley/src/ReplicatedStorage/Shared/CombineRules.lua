--[[
	The Combine machine's rules (owner, Oct 20 14:57: "make it so that you can take two of the same girl, and then it
	creates the same skin, but first in silver, then gold, and then diamond. make it so that you need to have both of
	the types to go up"). Pure (no Instances): HuzzServer/CombineService and ActionService ("Combine") apply them to
	the save, UI/Screens/Combine shows the same answers, tests/CombineRules.spec checks them.
	  * Every girl you own is a pile of copies by grade: data.Copies[id] = { Normal = n, Silver = n, Gold = n,
	    Diamond = n } (only grades you have are stored). data.Characters[id] still says you own her (first won).
	  * Two copies of the SAME girl at the SAME grade make one of her a grade up: Normal -> Silver -> Gold ->
	    Diamond. Diamond is the top. Winning her again in a round adds a Normal copy (add).
	  * She shows her best grade wherever she shows (your companion, the Index); equipping is still by girl, so
	    combining your equipped girl just makes her look better.
	  * Old saves (before Oct 20): each girl owned was one copy plus her spare copies (Dupes, from Prestige):
	    migrate() turns that into Copies[id].Normal = 1 + spares, once.
	  * Prestige (Oct 19) spends a spare Normal copy (one that isn't the last): Shared/PrestigeRules counts them here.
]]
local CombineRules = {}

CombineRules.Grades = { "Normal", "Silver", "Gold", "Diamond" }
CombineRules.Need = 2 -- copies per merge
local RANK = { Normal = 1, Silver = 2, Gold = 3, Diamond = 4 }

function CombineRules.valid(grade: any): boolean
	return type(grade) == "string" and RANK[grade] ~= nil
end

function CombineRules.rank(grade: any): number
	return if type(grade) == "string" and RANK[grade] then RANK[grade] else 0
end

-- The grade one up, or nil at the top (or for a name that isn't a grade).
function CombineRules.next(grade: any): string?
	local r = CombineRules.rank(grade)
	return if r >= 1 then CombineRules.Grades[r + 1] else nil
end

local function whole(n: any): number
	n = tonumber(n)
	if not n or n ~= n or n <= 0 then return 0 end
	return math.floor(n)
end

-- How many copies of her at this grade.
function CombineRules.count(data: any, id: any, grade: string): number
	local copies = type(id) == "string" and data and type(data.Copies) == "table" and data.Copies[id]
	return if type(copies) == "table" then whole(copies[grade]) else 0
end

-- Every grade's count: { Normal = n, Silver = n, Gold = n, Diamond = n } (zeros included).
function CombineRules.counts(data: any, id: any): { [string]: number }
	local out = {}
	for _, g in CombineRules.Grades do out[g] = CombineRules.count(data, id, g) end
	return out
end

function CombineRules.total(data: any, id: any): number
	local n = 0
	for _, g in CombineRules.Grades do n += CombineRules.count(data, id, g) end
	return n
end

function CombineRules.owns(data: any, id: any): boolean
	return type(id) == "string" and data and type(data.Characters) == "table" and data.Characters[id] ~= nil
end

-- The grade she shows: her best copy. nil when you don't own her; "Normal" for an owned girl with no copies counted
-- (a save that hasn't been migrated yet).
function CombineRules.best(data: any, id: any): string?
	if not CombineRules.owns(data, id) then return nil end
	for i = #CombineRules.Grades, 1, -1 do
		local g = CombineRules.Grades[i]
		if CombineRules.count(data, id, g) > 0 then return g end
	end
	return "Normal"
end

-- Can two of her at this grade be combined? Returns ok and, when not, a short reason for the window.
function CombineRules.can(data: any, id: any, grade: any): (boolean, string?)
	if type(id) ~= "string" or not CombineRules.owns(data, id) then return false, "You don't own her yet." end
	if not CombineRules.valid(grade) then return false, "Pick a girl first." end
	if CombineRules.next(grade) == nil then return false, "Diamond is the top!" end
	local have = CombineRules.count(data, id, grade)
	if have < CombineRules.Need then
		return false, `You need 2 {grade}. You have {have}.`
	end
	return true, nil
end

-- Takes two of her at this grade and gives one a grade up, in place. Returns the new grade, or nil and why.
-- data.Combines counts every merge (the server waits for the save holding it before answering).
function CombineRules.apply(data: any, id: any, grade: any): (string?, string?)
	local ok, why = CombineRules.can(data, id, grade)
	if not ok then return nil, why end
	local up = CombineRules.next(grade) :: string
	local copies = data.Copies[id]
	local left = CombineRules.count(data, id, grade) - CombineRules.Need
	copies[grade] = if left > 0 then left else nil
	copies[up] = CombineRules.count(data, id, up) + 1
	data.Combines = whole(data.Combines) + 1
	return up, nil
end

-- A copy of her into the save (a round win, the admin panel). Returns true when she is new to you.
function CombineRules.add(data: any, id: string, grade: string?, now: number?): boolean
	grade = if CombineRules.valid(grade) then grade else "Normal"
	data.Characters = data.Characters or {}
	data.Copies = data.Copies or {}
	local isNew = data.Characters[id] == nil
	if isNew then data.Characters[id] = now or os.time() end
	local copies = data.Copies[id]
	if type(copies) ~= "table" then
		copies = {}
		data.Copies[id] = copies
	end
	copies[grade :: string] = CombineRules.count(data, id, grade :: string) + 1
	return isNew
end

-- Takes one copy of her at this grade (Prestige spends a spare Normal one). Never takes her last copy.
function CombineRules.take(data: any, id: string, grade: string): boolean
	if CombineRules.count(data, id, grade) < 1 or CombineRules.total(data, id) < 2 then return false end
	local left = CombineRules.count(data, id, grade) - 1
	data.Copies[id][grade] = if left > 0 then left else nil
	return true
end

-- Old saves: each owned girl gets her copies (1 + her old spare copies, all Normal), once; copies of girls no longer
-- owned are dropped; an owned girl with no copies at all gets one. Safe to run on every load. Returns how many
-- girls it changed.
function CombineRules.migrate(data: any): number
	if type(data) ~= "table" then return 0 end
	if type(data.Characters) ~= "table" then data.Characters = {} end
	if type(data.Copies) ~= "table" then data.Copies = {} end
	local dupes = if type(data.Dupes) == "table" then data.Dupes else {}
	local changed = 0
	for id in data.Characters do
		local copies = data.Copies[id]
		if type(copies) ~= "table" then
			data.Copies[id] = { Normal = 1 + whole(dupes[id]) }
			changed += 1
		else
			for g, n in copies do -- (anything that isn't a grade with a whole count goes)
				if not RANK[g] or whole(n) == 0 then copies[g] = nil elseif n ~= whole(n) then copies[g] = whole(n) end
			end
			if next(copies) == nil then
				copies.Normal = 1
				changed += 1
			end
		end
		dupes[id] = nil
	end
	for id in data.Copies do
		if data.Characters[id] == nil then data.Copies[id] = nil end
	end
	if type(data.Dupes) == "table" and next(data.Dupes) == nil then data.Dupes = nil end
	return changed
end

-- What the window lists: every owned girl with each grade's count, and the first grade that can be combined.
-- girls: Config/Characters.List (only those with a Model, the anime girls). Sorted: girls ready to combine first,
-- then by name.
function CombineRules.choices(data: any, girls: { any }): { any }
	local out = {}
	for _, c in girls do
		if c.Model and CombineRules.owns(data, c.Id) then
			local counts = CombineRules.counts(data, c.Id)
			local ready = nil
			for _, g in CombineRules.Grades do
				if CombineRules.next(g) and counts[g] >= CombineRules.Need then ready = g; break end
			end
			table.insert(out, { id = c.Id, name = c.Name, model = c.Model, rarity = c.Rarity, counts = counts, ready = ready, best = CombineRules.best(data, c.Id) })
		end
	end
	table.sort(out, function(a, b)
		if (a.ready ~= nil) ~= (b.ready ~= nil) then return a.ready ~= nil end
		return a.name < b.name
	end)
	return out
end

-- "SILVER" etc. for badges and titles ("" for Normal: a normal girl has no badge).
function CombineRules.label(grade: any): string
	return if CombineRules.rank(grade) > 1 then string.upper(grade) else ""
end

return CombineRules

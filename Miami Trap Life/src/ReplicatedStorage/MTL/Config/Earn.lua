--!strict
-- Every way to earn money, for the phone's Money app. One list, built from three places:
--   * jobs       Config/Jobs (Order + Defs): pay per task averaged from Jobs.Tasks, or perMinute for post jobs
--   * crime      Config/Crime.EarnMethods (the crime-loop piece owns it; merged in when that file exists)
--   * extra      Earn.Methods below (hustles that belong to nobody else)
-- Entry shape (all pieces use it):
--   { id, title, kind = "Job" | "Crime" | "Hustle", pay = "$400-800" (display), perMinute = number? (sorting),
--     cooldown = seconds?, risk = "1 star"?, blurb, requires = { level?, path?, stage?, item?, itemLabel? },
--     location = Config/Locations key? (Vector3, or a table with Door / Position) | position = Vector3? }
-- Cooldowns: the save snapshot's Earn.Ready[id] = os.time() when the method can be done again (the piece that
-- runs the method writes it). The app's "Set GPS" sends the phone action "earnRoute" { id } (EarnService).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Jobs = require(ReplicatedStorage.MTL.Config.Jobs)

local Earn = {}

Earn.Methods = { -- extra hustles go here (same shape)
	-- CLOUT, the social app (Config/Social). Pay depends on followers and the day's market, so it's shown as a range.
	{ id = "Clout_Post", title = "Post on Clout", kind = "Hustle", pay = "Followers + XP · Creator Fund from 1K", perMinute = 0, risk = "Safe", blurb = "Shoot your car at a photo spot. Good spots, golden hour and trends go viral.", requires = { stage = "FreePlay" }, location = "EndsFlat" },
	{ id = "Clout_Deals", title = "Brand deals", kind = "Hustle", pay = "$60 at 1K followers · $1.5K at 100K", perMinute = 40, risk = "Safe", blurb = "Brands pay you to post at their spot. Bought followers cut the pay.", requires = { stage = "FreePlay" } },
	{ id = "Clout_Courses", title = "Sell courses", kind = "Hustle", pay = "Daily sales · different every day", perMinute = 120, risk = "Safe", blurb = "Record a course at your desk computer (10K followers, Level 12). It sells every day.", requires = { stage = "FreePlay", level = 12 } },
}

local function jobEntries(): { any }
	local out = {}
	for _, id in Jobs.Order or {} do
		local d = Jobs.Defs[id]
		if not d then
			continue
		end
		local pay, perMinute
		if d.kind == "post" and d.perMinute then
			pay = "$" .. tostring(d.perMinute) .. " / min"
			perMinute = d.perMinute
		else
			local sum, n = 0, 0
			for _, taskId in d.tasks or {} do
				local t = Jobs.Tasks and Jobs.Tasks[taskId]
				if t and type(t.pay) == "number" then
					sum += t.pay
					n += 1
				end
			end
			local avg = if n > 0 then math.floor(sum / n + 0.5) else 0
			pay = if avg > 0 then ("about $" .. avg .. " / task") else "per task"
			perMinute = avg * 3 -- a task takes ~20 s with walking
		end
		table.insert(out, {
			id = "Job_" .. id,
			jobId = id,
			title = (d.role or id) .. " at " .. (d.title or id),
			kind = "Job",
			pay = pay,
			perMinute = perMinute,
			risk = "Safe",
			blurb = d.blurb or "",
			requires = { level = d.level },
			location = d.site or d.place,
		})
	end
	return out
end

-- every method, jobs first then crime and hustles; safe to call on client and server
function Earn.all(): { any }
	local out = jobEntries()
	local crimeModule = ReplicatedStorage.MTL.Config:FindFirstChild("Crime")
	if crimeModule then
		local ok, Crime = pcall(require, crimeModule)
		if ok and type(Crime) == "table" and type((Crime :: any).EarnMethods) == "table" then
			for _, m in (Crime :: any).EarnMethods do
				if type(m) == "table" and type(m.id) == "string" then
					table.insert(out, m)
				end
			end
		end
	end
	for _, m in Earn.Methods do
		table.insert(out, m)
	end
	return out
end

function Earn.get(id: string): any?
	for _, m in Earn.all() do
		if m.id == id then
			return m
		end
	end
	return nil
end

return Earn

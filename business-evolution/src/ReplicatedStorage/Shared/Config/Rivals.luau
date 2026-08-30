--!strict
-- Rival ladders, one per floor (§5): six nameless desk-dwellers plus one named
-- boss. Each click against a rival applies playerProductivity × totalMultiplier
-- to its Workload — there is no combat system, only this comparison.
-- ⚠ Workload/Wins numbers are INVENTED (the brief defines the ladder shape,
-- not values); the first two floors are validated by the offline pacing sim.

export type RivalDef = {
	Title: string, -- job title shown over the desk
	Workload: number,
	Wins: number, -- awarded on defeat
	IsBoss: boolean?,
	BossName: string?, -- bosses get a name…
	BossLine: string?, -- …and one line of dialogue (§5)
}

export type FloorRivals = { RivalDef }

local ladder = function(workloads: { number }, wins: { number }): { RivalDef }
	local titles = { "Temp", "New Hire", "Colleague", "Rival Analyst", "The Overachiever", "Teacher's Pet" }
	local out: { RivalDef } = {}
	for i, title in titles do
		table.insert(out, { Title = title, Workload = workloads[i], Wins = wins[i] })
	end
	return out
end

local Rivals: { [string]: FloorRivals } = {}

Rivals.Mailroom = ladder({ 40, 120, 350, 900, 2000, 4500 }, { 3, 5, 8, 12, 18, 25 })
table.insert(Rivals.Mailroom, {
	Title = "Mailroom Manager",
	Workload = 12000,
	Wins = 80,
	IsBoss = true,
	BossName = "Gary",
	BossLine = "The mail stops for NO ONE.",
})

Rivals.CubicleFarm = ladder({ 6e3, 15e3, 40e3, 90e3, 200e3, 450e3 }, { 30, 45, 65, 90, 120, 160 })
table.insert(Rivals.CubicleFarm, {
	Title = "Middle Manager",
	Workload = 1.2e6,
	Wins = 450,
	IsBoss = true,
	BossName = "Deborah",
	BossLine = "Let's take this offline. Permanently.",
})

Rivals.OpenPlan = ladder({ 1.5e6, 4e6, 10e6, 25e6, 60e6, 130e6 }, { 200, 280, 380, 500, 650, 850 })
table.insert(Rivals.OpenPlan, {
	Title = "Floor Manager",
	Workload = 3.5e8,
	Wins = 2200,
	IsBoss = true,
	BossName = "Brett",
	BossLine = "This could have been a meeting.",
})

Rivals.Executive = ladder({ 2e9, 5e9, 1.2e10, 3e10, 8e10, 2e11 }, { 1200, 1600, 2100, 2800, 3600, 4600 })
table.insert(Rivals.Executive, {
	Title = "VP of Synergy",
	Workload = 6e11,
	Wins = 12000,
	IsBoss = true,
	BossName = "Preston",
	BossLine = "I optimize optimizers.",
})

Rivals.Penthouse = ladder({ 8e11, 1.8e12, 4e12, 9e12, 2e13, 4.5e13 }, { 6000, 8000, 11000, 14000, 18000, 23000 })
table.insert(Rivals.Penthouse, {
	Title = "C-Suite Gatekeeper",
	Workload = 1.2e14,
	Wins = 60000,
	IsBoss = true,
	BossName = "Maximilian",
	BossLine = "The board sees everything.",
})

Rivals.OrbitalHQ = ladder({ 8e13, 1.6e14, 3e14, 6e14, 1.2e15, 2.5e15 }, { 30000, 40000, 52000, 68000, 85000, 105000 })
table.insert(Rivals.OrbitalHQ, {
	Title = "Chairman Emeritus",
	Workload = 8e15,
	Wins = 300000,
	IsBoss = true,
	BossName = "The Chairman Emeritus",
	BossLine = "You cannot fire gravity.",
})

local RivalsModule = {}

RivalsModule.ByFloor = Rivals

-- Stable id for one placed rival: floor + ladder slot + copy within the pack
-- ("Mailroom_3_2" = second Colleague in the Mailroom wing).
function RivalsModule.rivalId(floorId: string, defIndex: number, copy: number): string
	return floorId .. "_" .. defIndex .. "_" .. copy
end

function RivalsModule.parse(rivalId: string): (string?, number?, number?)
	local floorId, defIndex, copy = rivalId:match("^(%w+)_(%d+)_(%d+)$")
	if floorId and defIndex and copy then
		return floorId, tonumber(defIndex), tonumber(copy)
	end
	return nil, nil, nil
end

function RivalsModule.get(floorId: string, index: number): RivalDef?
	local floor = Rivals[floorId]
	return if floor then floor[index] else nil
end

return RivalsModule

--!strict
--[[
	Daily quests (owner, Oct 19, with his picture design/owner-oct19/pic-d-quests.png: "add easy quests as in this photo
	and make new ones everyday then recycle them"). Like the picture: two daily quests, plus one that changes every
	2 hours and gives a spin. Easy targets that a normal session reaches. New ones each day at 00:00 UTC (shown
	as a real countdown); the pools below are used again and again in a shuffled order (Shared/DailyRules picks
	them from the day number, so every server and the client agree without saving the choice).
	Progress only counts from real events (ProgressService.addStat, the same stats as the story quests), and only
	from when the quest appears. Left out on purpose (kid-safe, plan-oct19.md): the picture's Robux "Refresh
	Quests" and "Auto Complete Quests" buttons.
	  Stat    a Config/Progression.Stats counter; Target how many; Reward Kind "Coins" / "Aura" / "Spin" with Amount.
]]
export type Reward = { Kind: "Coins" | "Aura" | "Spin", Amount: number }
export type Quest = { Id: string, Name: string, Stat: string, Target: number, Reward: Reward }

local DailyQuests = {}

DailyQuests.DayLength = 24 * 60 * 60 -- new daily quests every day at 00:00 UTC
DailyQuests.SlotLength = 2 * 60 * 60 -- the spin quest changes every 2 hours
DailyQuests.PerDay = 2

-- The daily pool (two a day, never two of the same stat on one day).
DailyQuests.Daily = {
	{ Id = "D_Play3", Name = "Play 3 games", Stat = "Rounds", Target = 3, Reward = { Kind = "Coins", Amount = 150 } },
	{ Id = "D_Cross5", Name = "Make 5 crossings", Stat = "Crossings", Target = 5, Reward = { Kind = "Aura", Amount = 15 } },
	{ Id = "D_Stars10", Name = "Collect 10 Aura stars", Stat = "AuraStars", Target = 10, Reward = { Kind = "Coins", Amount = 150 } },
	{ Id = "D_Catch2", Name = "Catch 2 runners", Stat = "Catches", Target = 2, Reward = { Kind = "Aura", Amount = 15 } },
	{ Id = "D_Win2", Name = "Win 2 games", Stat = "Wins", Target = 2, Reward = { Kind = "Coins", Amount = 200 } },
	{ Id = "D_Rescue1", Name = "Rescue a runner", Stat = "Rescues", Target = 1, Reward = { Kind = "Aura", Amount = 15 } },
	{ Id = "D_Hold30", Name = "Carry the girl for 30 seconds", Stat = "HoldSeconds", Target = 30, Reward = { Kind = "Coins", Amount = 200 } },
	{ Id = "D_Play5", Name = "Play 5 games", Stat = "Rounds", Target = 5, Reward = { Kind = "Aura", Amount = 20 } },
	{ Id = "D_Cross10", Name = "Make 10 crossings", Stat = "Crossings", Target = 10, Reward = { Kind = "Coins", Amount = 250 } },
	{ Id = "D_Stars20", Name = "Collect 20 Aura stars", Stat = "AuraStars", Target = 20, Reward = { Kind = "Aura", Amount = 20 } },
} :: { Quest }

-- The 2-hour spin quest pool (one at a time, +1 spin on the Spin the Wheel).
DailyQuests.Spin = {
	{ Id = "S_Play2", Name = "Play 2 games", Stat = "Rounds", Target = 2, Reward = { Kind = "Spin", Amount = 1 } },
	{ Id = "S_Cross3", Name = "Make 3 crossings", Stat = "Crossings", Target = 3, Reward = { Kind = "Spin", Amount = 1 } },
	{ Id = "S_Stars5", Name = "Collect 5 Aura stars", Stat = "AuraStars", Target = 5, Reward = { Kind = "Spin", Amount = 1 } },
	{ Id = "S_Win1", Name = "Win a game", Stat = "Wins", Target = 1, Reward = { Kind = "Spin", Amount = 1 } },
	{ Id = "S_Catch1", Name = "Catch a runner", Stat = "Catches", Target = 1, Reward = { Kind = "Spin", Amount = 1 } },
} :: { Quest }

local byId: { [string]: Quest } = {}
for _, list in { DailyQuests.Daily, DailyQuests.Spin } do
	for _, q in list do
		assert(not byId[q.Id], "duplicate daily quest " .. q.Id)
		byId[q.Id] = q
	end
end

function DailyQuests.get(id: string): Quest?
	return byId[id]
end

-- "+150 COINS", "+15 AURA", "+1 SPIN"
function DailyQuests.rewardText(r: Reward): string
	local word = if r.Kind == "Coins" then "COINS" elseif r.Kind == "Aura" then "AURA" else (if r.Amount == 1 then "SPIN" else "SPINS")
	return string.format("+%d %s", r.Amount, word)
end

return DailyQuests

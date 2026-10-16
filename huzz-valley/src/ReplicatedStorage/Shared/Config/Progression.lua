--!strict
-- Levels, the reward track and quests. All progress is counted and granted by the server (ProgressService).
local Progression = {}

Progression.XPPerLevel = 300 -- every level takes the same XP

-- Free reward track: reaching Level unlocks the reward; the player claims it.
--   Kind: "Coins" | "Aura" | "Dance" | "Outfit"   (Outfit rewards stay unavailable until the outfit exists)
Progression.Rewards = {
	{ Level = 1, Kind = "Coins", Amount = 100, Name = "100 Coins", Art = "CurrencyCoin" },
	{ Level = 2, Kind = "Aura", Amount = 25, Name = "25 Aura", Art = "CurrencyGem" },
	{ Level = 3, Kind = "Dance", Id = "Robot", Name = "Robot", Art = "DanceWave" },
	{ Level = 4, Kind = "Outfit", Id = "AikoStyle", Name = "Aiko Style", Art = "OutfitAiko", Unavailable = true },
}

-- Bonus cosmetics row: shown, but not obtainable yet (no system grants them).
Progression.Bonus = {
	{ Name = "Ren Outfit", Art = "BonusRenOutfit" },
	{ Name = "Sora", Art = "BonusSora" },
	{ Name = "Silver Hair", Art = "BonusSilverHair" },
	{ Name = "Aiko Outfit", Art = "BonusAikoOutfit" },
}

-- Quests count real match events reported by gameplay (ProgressService.addStat). They don't reset on a timer.
Progression.Quests = {
	{ Id = "Steals", Name = "Make 3 steals", Blurb = "Steal the lead from other players.", Stat = "Steals", Target = 3, XP = 100, Icon = "TagFist" },
	{ Id = "Hold", Name = "Hold the lead for 30s", Blurb = "Across matches.", Stat = "HoldSeconds", Target = 30, XP = 150, Icon = "Stopwatch" },
	{ Id = "Jukes", Name = "Break 5 ankles", Blurb = "Juke other players.", Stat = "Jukes", Target = 5, XP = 100, Icon = "Sneaker" },
	{ Id = "Rounds", Name = "Play 3 rounds", Blurb = "Complete 3 matches.", Stat = "Rounds", Target = 3, XP = 100, Icon = "Players" },
}
Progression.Stats = { "Steals", "HoldSeconds", "Jukes", "Rounds" }

-- Level and progress inside it, from total XP.
function Progression.level(xp: number): (number, number, number)
	local level = 1 + xp // Progression.XPPerLevel
	return level, xp % Progression.XPPerLevel, Progression.XPPerLevel
end

function Progression.reward(level: number)
	for _, r in Progression.Rewards do if r.Level == level then return r end end
	return nil
end

function Progression.quest(id: string)
	for _, q in Progression.Quests do if q.Id == id then return q end end
	return nil
end

return Progression

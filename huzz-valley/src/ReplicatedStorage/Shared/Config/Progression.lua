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
	{ Level = 4, Kind = "Coins", Amount = 250, Name = "250 Coins", Art = "CurrencyCoin" },
}

-- Bonus cosmetics row: things you can't earn yet. Empty, so the row is hidden (the kit's mock-up outfits were
-- placeholders). Add { Name, Art } entries once real ones exist.
Progression.Bonus = {}

-- Lore quests (owner: "add quests into the game for the lore. They give you rewards and help you progress").
-- The story of the valley in chapters; each chapter's quests open once the chapter before is claimed. Quests count
-- real match events reported by gameplay (ProgressService.addStat) and never reset on a timer.
--   Reward: Kind "Coins" / "Aura" (Amount) or "Knife" (Id = a Config/CoinShop quest knife), plus XP.
Progression.Chapters = {
	{
		Title = "Welcome to the Valley",
		Lore = "Every night the anime girls drift down over Huzz Valley. Learn the field, and the field learns you.",
		Quests = {
			{ Id = "Q1Rounds", Name = "Play 3 rounds", Blurb = "Join the games in the valley.", Stat = "Rounds", Target = 3, XP = 100, Icon = "Players", Reward = { Kind = "Coins", Amount = 150 } },
			{ Id = "Q1Cross", Name = "Cross safely 5 times", Blurb = "Reach the other side.", Stat = "Crossings", Target = 5, XP = 100, Icon = "Sneaker", Reward = { Kind = "Aura", Amount = 25 } },
		},
	},
	{
		Title = "Star Catcher",
		Lore = "Fallen stars float over the field: pieces of Aura. Gather them, and the valley starts to glow for you.",
		Quests = {
			{ Id = "Q2Stars", Name = "Collect 15 Aura stars", Blurb = "Run through the floating stars.", Stat = "AuraStars", Target = 15, XP = 150, Icon = "AuraStar", Reward = { Kind = "Knife", Id = "RookieKnife" } },
			{ Id = "Q2Hero", Name = "Survive a Hero run", Blurb = "Cross alone, and make it.", Stat = "Heroes", Target = 1, XP = 150, Icon = "Stopwatch", Reward = { Kind = "Coins", Amount = 300 } },
		},
	},
	{
		Title = "No One Left Behind",
		Lore = "Runners who fall can rise again, if a friend comes back for them. Catchers know it, and they hunt harder.",
		Quests = {
			{ Id = "Q3Rescue", Name = "Rescue 5 runners", Blurb = "Help downed runners up.", Stat = "Rescues", Target = 5, XP = 200, Icon = "TagFist", Reward = { Kind = "Aura", Amount = 60 } },
			{ Id = "Q3Hunt", Name = "Catch 10 runners", Blurb = "As a catcher, stab or lunge.", Stat = "Catches", Target = 10, XP = 200, Icon = "TagFist", Reward = { Kind = "Knife", Id = "HunterKnife" } },
		},
	},
	{
		Title = "Legend of the Valley",
		Lore = "Only one runner carries the girl home. Keep her safe, win again and again, and the valley will remember you.",
		Quests = {
			{ Id = "Q4Hold", Name = "Carry the girl 120 s", Blurb = "Total time with her on your shoulders.", Stat = "HoldSeconds", Target = 120, XP = 250, Icon = "Stopwatch", Reward = { Kind = "Coins", Amount = 500 } },
			{ Id = "Q4Wins", Name = "Win 10 games", Blurb = "With your side, runners or catchers.", Stat = "Wins", Target = 10, XP = 300, Icon = "Players", Reward = { Kind = "Knife", Id = "MoonlitKnife" } },
		},
	},
}
-- Every quest in story order (the server and the HUD read this), with its chapter number.
Progression.Quests = {}
for c, chapter in Progression.Chapters do
	for _, q in chapter.Quests do
		q.Chapter = c
		table.insert(Progression.Quests, q)
	end
end
Progression.Stats = { "Rounds", "Crossings", "AuraStars", "Heroes", "Rescues", "Catches", "HoldSeconds", "Wins", "Steals" }

-- The chapter you're on: the first with a quest not yet claimed (claimed = { [questId] = true }); #Chapters + 1
-- when the story is done.
function Progression.currentChapter(claimed: { [string]: boolean }): number
	for c, chapter in Progression.Chapters do
		for _, q in chapter.Quests do
			if not claimed[q.Id] then return c end
		end
	end
	return #Progression.Chapters + 1
end

-- What a quest gives, in words ("150 coins", "Rookie Knife").
function Progression.rewardText(q): string
	local r = q.Reward
	if not r then return q.XP .. " XP" end
	if r.Kind == "Coins" then return r.Amount .. " coins" end
	if r.Kind == "Aura" then return r.Amount .. " Aura" end
	if r.Kind == "Knife" then return (string.gsub(r.Id, "Knife$", " Knife")) end
	return ""
end

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

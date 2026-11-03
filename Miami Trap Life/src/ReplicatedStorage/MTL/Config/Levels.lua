--!strict
-- XP curve + what each level unlocks. need(L) = XP to go from level L to L+1.
-- 60, 105, 197, 322 ... -> Level 4 at ~362 XP (~6 min of first-job tasks, ~20 XP per 15 s task), Level 5 at ~684 XP (~10 min).
local Levels = {}

Levels.MaxLevel = 100
Levels.Base = 60
Levels.Scale = 45
Levels.Power = 1.6

Levels.CriminalCallLevel = 4 -- the unknown number calls at this level (Master Plan §1 stage 3), ~6 min into the first shift
Levels.CriminalTeaseLevel = 3 -- one short text from "Unknown" first (~3 min), so the call isn't out of nowhere (PhoneStory)
-- A/B test (research P0-6: competitors let you rob something within ~5 minutes). Each NEW player is put in A or B once
-- (saved in Story.Data.CallTest); B gets the call one level earlier (~3 min) and the tease one level earlier too.
-- Per-player value: StoryService.callLevel(player) / player attribute MTL_CallLevel. Set Enabled = false to end the test.
Levels.CallLevelTest = { Enabled = true, A = 4, B = 3, ShareB = 0.5 }

-- Shown on the level-up banner and as a phone ping. Systems that unlock things read these keys.
-- Every level in the first 10 should unlock something (Research: Jobs, Leveling and RP Game Feel).
Levels.Unlocks = {
	[2] = { "New task: Price gun" },
	[3] = { "Shift bonus: +25% when you finish a shift" },
	[4] = { "A call from an unknown number..." },
	[5] = { "Tips: PERFECT tasks pay +25%" },
	[6] = { "Pay raise: +10% at every job" },
	[7] = { "Quick hands: hold tasks 15% faster" },
	[8] = { "Job: Cashier", "Job: Car Wash", "Job: Valet" },
	[9] = { "Pay raise: +10% more at every job" },
	[10] = { "Big shift bonus: +50%" },
	[15] = { "Job: Security Guard", "Job: Trucker", "Job: Dockworker" },
}
-- (Jobs piece) the perks behind 2/3/6/7/9/10 live in Config/Jobs (PayRaises, QuickHandsLevel, Shift.BonusLevel...).
-- If you change a level there, change the line here too.

return Levels

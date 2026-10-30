--!strict
-- New Game Kit: HudStages (show the HUD a piece at a time, vault note 13 §2A and 14 §2)
-- Install: ReplicatedStorage/Kit/HudStages (ModuleScript)
-- A new player sees the verb and one bar; each tutorial step brings in only what it needs;
-- everything else pops in after TUTORIAL COMPLETE. Returning players get the last stage.
--   Config.HudStages = {
--     { Step = "Train",   Show = { "PowerBar" } },
--     { Step = "Launch",  Show = { "Coins" } },
--     { Step = "Hatch",   Show = { "Menu.Eggs" }, Spotlight = "Menu.Eggs" },
--     { Step = "Rebirth", Show = { "Menu.Rebirth", "TopBar.Rebirths" }, Spotlight = "Menu.Rebirth" },
--     { Step = "Done",    Show = "*" },   -- the rest, popped in one after another
--   }
--   HudStages.Visible(stages, stage, "Coins")  -> true / false
--   HudStages.Arriving(stages, from, to, all)  -> names to pop in, in order
--   HudStages.Spotlight(stages, stage)         -> name to light up (dim the rest), or nil
--   HudStages.StageFor(stages, stepsDone, tutorialDone) -> stage number
-- Status: covered by tests/HudStages.spec.luau (offline).

local HudStages = {}

export type Stage = { Step: string, Show: { string } | string, Spotlight: string? }

-- The stage an element first appears at; elements no stage names appear at the "*" stage (or the last).
function HudStages.FirstStage(stages: { Stage }, name: string): number
	local star = #stages
	for i, stage in stages do
		if stage.Show == "*" then
			star = math.min(star, i)
		elseif type(stage.Show) == "table" then
			for _, shown in stage.Show :: { string } do
				if shown == name then
					return i
				end
			end
		end
	end
	return star
end

function HudStages.Visible(stages: { Stage }, stage: number, name: string): boolean
	return stage >= HudStages.FirstStage(stages, name)
end

-- Elements that become visible going from stage `from` to `to`, in stage order then `all` order,
-- so the client can pop them in one after another (0.06 s apart, 14 §2).
function HudStages.Arriving(stages: { Stage }, from: number, to: number, all: { string }): { string }
	local out = {}
	for s = from + 1, to do
		for _, name in all do
			if HudStages.FirstStage(stages, name) == s then
				table.insert(out, name)
			end
		end
	end
	return out
end

function HudStages.Spotlight(stages: { Stage }, stage: number): string?
	local s = stages[stage]
	return if s then s.Spotlight else nil
end

-- stepsDone counts finished tutorial steps (0 at join). Anyone past the tutorial gets the full HUD.
function HudStages.StageFor(stages: { Stage }, stepsDone: number, tutorialDone: boolean): number
	if tutorialDone then
		return #stages
	end
	return math.clamp(stepsDone + 1, 1, #stages)
end

return HudStages

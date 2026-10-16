--!strict
-- Dances: 25 picked from the owner's 200-dance file (tools/anim/extract_anims.luau; the raw animation is
-- HuzzAnimations.Dance_<Id>). Names are our own (most of the originals are other games' emote names).
-- AnimationId = the published ID; "" plays the raw one in Studio (Shared/AnimationLibrary), and in the live game
-- the dance says it isn't ready until it's published (tools/studio/publish-animations.lua).
--   Starter = owned by everyone. Pack = granted by the Dance Pack pass. Robot = from the reward track (level 3).
export type Dance = { Id: string, Name: string, AnimationId: string, Art: string?, Starter: boolean?, Pack: boolean?, Order: number }

local Dances = {}

Dances.List = {
	{ Id = "Floss", Name = "Floss", AnimationId = "", Starter = true, Order = 1 },
	{ Id = "CitrusGroove", Name = "Citrus Groove", AnimationId = "", Starter = true, Order = 2 },
	{ Id = "HypeUp", Name = "Hype Up", AnimationId = "", Starter = true, Order = 3 },
	{ Id = "ShockShuffle", Name = "Shock Shuffle", AnimationId = "", Starter = true, Order = 4 },
	{ Id = "ClassicGroove", Name = "Classic Groove", AnimationId = "", Starter = true, Order = 5 },
	{ Id = "BoogieDown", Name = "Boogie Down", AnimationId = "", Starter = true, Order = 6 },
	{ Id = "SmoothMoves", Name = "Smooth Moves", AnimationId = "", Starter = true, Order = 7 },
	{ Id = "SoFresh", Name = "So Fresh", AnimationId = "", Starter = true, Order = 8 },
	{ Id = "PopLock", Name = "Pop Lock", AnimationId = "", Starter = true, Order = 9 },
	{ Id = "Robot", Name = "Robot", AnimationId = "", Order = 10 },
	{ Id = "PhoneCall", Name = "Phone Call", AnimationId = "", Starter = true, Order = 11 },
	{ Id = "RunningMan", Name = "Running Man", AnimationId = "", Starter = true, Order = 12 },
	{ Id = "CrazyFeet", Name = "Crazy Feet", AnimationId = "", Starter = true, Order = 13 },
	{ Id = "Breakdown", Name = "Breakdown", AnimationId = "", Starter = true, Order = 14 },
	{ Id = "SwingTime", Name = "Swing Time", AnimationId = "", Pack = true, Order = 15 },
	{ Id = "FreeFlow", Name = "Free Flow", AnimationId = "", Starter = true, Order = 16 },
	{ Id = "Freestyle", Name = "Freestyle", AnimationId = "", Starter = true, Order = 17 },
	{ Id = "CleanGroove", Name = "Clean Groove", AnimationId = "", Starter = true, Order = 18 },
	{ Id = "BounceBounce", Name = "Bounce Bounce", AnimationId = "", Pack = true, Order = 19 },
	{ Id = "Flapper", Name = "Flapper", AnimationId = "", Starter = true, Order = 20 },
	{ Id = "SquatKick", Name = "Squat Kick", AnimationId = "", Pack = true, Order = 21 },
	{ Id = "Sprinkler", Name = "Sprinkler", AnimationId = "", Starter = true, Order = 22 },
	{ Id = "CrabDance", Name = "Crab Dance", AnimationId = "", Starter = true, Order = 23 },
	{ Id = "Toprock", Name = "Toprock", AnimationId = "", Pack = true, Order = 24 },
	{ Id = "Aerobics", Name = "Aerobics", AnimationId = "", Starter = true, Order = 25 },
} :: { Dance }

local byId: { [string]: Dance } = {}
for _, d in Dances.List do byId[d.Id] = d end

function Dances.get(id: string): Dance?
	return byId[id]
end

return Dances

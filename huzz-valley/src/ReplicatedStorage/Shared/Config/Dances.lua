--!strict
-- Dances: 25 picked from the owner's 200-dance file (tools/anim/extract_anims.luau; the raw animation is
-- HuzzAnimations.Dance_<Id>). Names are our own (most of the originals are other games' emote names).
-- AnimationId = the published ID; "" plays the raw one in Studio (Shared/AnimationLibrary), and in the live game
-- the dance says it isn't ready until it's published (tools/studio/publish-animations.lua).
--   Starter = owned by everyone. Pack = granted by the Dance Pack pass. Robot = from the reward track (level 3).
--   Color = the card's glow (Dances.Colors, after the owner's Oct 17 mockup: Aerobics pink, Boogie Down blue, Bounce
--   Bounce green, Breakdown gold, Floss red, Hype violet). Blurb = the one line under the big picture (short, no dashes).
export type Dance = { Id: string, Name: string, AnimationId: string, Art: string?, Starter: boolean?, Pack: boolean?, Color: string, Blurb: string, Order: number }

local Dances = {}

-- The mockup's six card colours (measured on its glowing notes).
Dances.Colors = {
	Pink = Color3.fromHex("E56CFF"), Blue = Color3.fromHex("5AA6FF"), Green = Color3.fromHex("45E0A0"),
	Gold = Color3.fromHex("FFC24F"), Red = Color3.fromHex("FF5672"), Violet = Color3.fromHex("A066FF"),
} :: { [string]: Color3 }

Dances.MaxFavourites = 12 -- (the server's cap on a player's saved favourites)

Dances.List = {
	{ Id = "Floss", Name = "Floss", AnimationId = "", Starter = true, Color = "Red", Blurb = "Swing your arms and hips like a pro!", Order = 1 },
	{ Id = "CitrusGroove", Name = "Citrus Groove", AnimationId = "", Starter = true, Color = "Gold", Blurb = "A fresh and zesty groove to show off.", Order = 2 },
	{ Id = "HypeUp", Name = "Hype Up", AnimationId = "", Starter = true, Color = "Violet", Blurb = "Pump up the crowd before the run!", Order = 3 },
	{ Id = "ShockShuffle", Name = "Shock Shuffle", AnimationId = "", Starter = true, Color = "Blue", Blurb = "Quick feet that zap across the floor.", Order = 4 },
	{ Id = "ClassicGroove", Name = "Classic Groove", AnimationId = "", Starter = true, Color = "Pink", Blurb = "An old school groove that never gets old.", Order = 5 },
	{ Id = "BoogieDown", Name = "Boogie Down", AnimationId = "", Starter = true, Color = "Blue", Blurb = "Get down and boogie all night!", Order = 6 },
	{ Id = "SmoothMoves", Name = "Smooth Moves", AnimationId = "", Starter = true, Color = "Green", Blurb = "Glide around with silky smooth steps.", Order = 7 },
	{ Id = "SoFresh", Name = "So Fresh", AnimationId = "", Starter = true, Color = "Green", Blurb = "Show everyone how fresh you are.", Order = 8 },
	{ Id = "PopLock", Name = "Pop Lock", AnimationId = "", Starter = true, Color = "Red", Blurb = "Pop, freeze and lock to the beat.", Order = 9 },
	{ Id = "Robot", Name = "Robot", AnimationId = "", Color = "Blue", Blurb = "Beep boop! Move like a real robot.", Order = 10 },
	{ Id = "PhoneCall", Name = "Phone Call", AnimationId = "", Starter = true, Color = "Pink", Blurb = "Hello? The dance floor is calling!", Order = 11 },
	{ Id = "RunningMan", Name = "Running Man", AnimationId = "", Starter = true, Color = "Gold", Blurb = "Run in place right on the beat.", Order = 12 },
	{ Id = "CrazyFeet", Name = "Crazy Feet", AnimationId = "", Starter = true, Color = "Violet", Blurb = "Your feet go wild in every direction!", Order = 13 },
	{ Id = "Breakdown", Name = "Breakdown", AnimationId = "", Starter = true, Color = "Gold", Blurb = "Drop it low and break it down!", Order = 14 },
	{ Id = "SwingTime", Name = "Swing Time", AnimationId = "", Pack = true, Color = "Pink", Blurb = "Swing back in time with this classic.", Order = 15 },
	{ Id = "FreeFlow", Name = "Free Flow", AnimationId = "", Starter = true, Color = "Blue", Blurb = "Let the music move you.", Order = 16 },
	{ Id = "Freestyle", Name = "Freestyle", AnimationId = "", Starter = true, Color = "Red", Blurb = "No rules, just your own moves!", Order = 17 },
	{ Id = "CleanGroove", Name = "Clean Groove", AnimationId = "", Starter = true, Color = "Green", Blurb = "Neat, sharp steps that look super clean.", Order = 18 },
	{ Id = "BounceBounce", Name = "Bounce Bounce", AnimationId = "", Pack = true, Color = "Green", Blurb = "Bounce, bounce, bounce to the beat!", Order = 19 },
	{ Id = "Flapper", Name = "Flapper", AnimationId = "", Starter = true, Color = "Violet", Blurb = "Flap your arms in this fun old dance.", Order = 20 },
	{ Id = "SquatKick", Name = "Squat Kick", AnimationId = "", Pack = true, Color = "Red", Blurb = "Squat down low and kick it high!", Order = 21 },
	{ Id = "Sprinkler", Name = "Sprinkler", AnimationId = "", Starter = true, Color = "Blue", Blurb = "Spray your moves all over the place.", Order = 22 },
	{ Id = "CrabDance", Name = "Crab Dance", AnimationId = "", Starter = true, Color = "Red", Blurb = "Scuttle side to side like a crab!", Order = 23 },
	{ Id = "Toprock", Name = "Toprock", AnimationId = "", Pack = true, Color = "Gold", Blurb = "Rock your feet before the big moves.", Order = 24 },
	{ Id = "Aerobics", Name = "Aerobics", AnimationId = "", Starter = true, Color = "Pink", Blurb = "Get active with this energetic dance!", Order = 25 },
} :: { Dance }

local byId: { [string]: Dance } = {}
for _, d in Dances.List do byId[d.Id] = d end

function Dances.get(id: string): Dance?
	return byId[id]
end

return Dances

--!strict
-- Dances: 25 picked from the owner's 200-dance file (tools/anim/extract_anims.luau; the raw animation is
-- HuzzAnimations.Dance_<Id>). Names are our own (most of the originals are other games' emote names).
-- AnimationId = the published ID; "" plays the raw one in Studio (Shared/AnimationLibrary), and in the live game
-- the dance says it isn't ready until it's published (tools/studio/publish-animations.lua).
--   Starter = owned by everyone. Pack = granted by the Dance Pack pass. Robot = from the reward track (level 3).
--   Color = the card's glow (Dances.Colors, after the owner's Oct 17 mockup: Aerobics pink, Boogie Down blue, Bounce
--   Bounce green, Breakdown gold, Floss red, Hype violet). Blurb = the one line under the big picture (short, no dashes).
--   Music = the key of its song in Dances.Tracks (owner, Oct 19: "find the sounds we can use for all of the dances ...
--   logically select the best sounds/songs possible"): only you hear it, quieter than the background music, which
--   dips under it (Gameplay/Music.dance). Research and reasons: docs/sound-picks.md.
export type Dance = { Id: string, Name: string, AnimationId: string, Art: string?, Starter: boolean?, Pack: boolean?, Color: string, Blurb: string, Order: number, Music: string? }
export type Track = { Id: string, Name: string, By: string, Style: string, Source: string, Start: number? }

local Dances = {}

-- The mockup's six card colours (measured on its glowing notes).
Dances.Colors = {
	Pink = Color3.fromHex("E56CFF"), Blue = Color3.fromHex("5AA6FF"), Green = Color3.fromHex("45E0A0"),
	Gold = Color3.fromHex("FFC24F"), Red = Color3.fromHex("FF5672"), Violet = Color3.fromHex("A066FF"),
} :: { [string]: Color3 }

Dances.MaxFavourites = 12 -- (the server's cap on a player's saved favourites)

-- The dance songs. All from Roblox's licensed library (Monstercat and APM Music tracks that Roblox distributes for
-- free use in any experience, public, so nothing to upload). Id "" = no song for that dance (it dances in silence).
-- Every ID was seen on the Source page; none is invented. Start = seconds into the song to begin (0 until someone
-- listens in Studio and picks the moment the beat kicks in). One song serves several dances of the same kind.
Dances.Tracks = {
	CrabRave = { Id = "rbxassetid://5410086218", Name = "Crab Rave", By = "Noisestorm (Monstercat)", Style = "electro house, the meme-dance anthem",
		Source = "https://create.roblox.com/store/asset/5410086218/Noisestorm-Crab-Rave" },
	Shiawase = { Id = "rbxassetid://5409360995", Name = "Shiawase", By = "Dion Timmer (Monstercat)", Style = "kawaii future bass, 150 BPM",
		Source = "https://create.roblox.com/store/asset/5409360995/Dion-Timmer-Shiawase" },
	Moshi = { Id = "rbxassetid://7024340270", Name = "Moshi", By = "Pegboard Nerds & Tokyo Machine (Monstercat)", Style = "video-game electro",
		Source = "https://create.roblox.com/store/asset/7024340270/Pegboard-Nerds-Tokyo-Machine-Moshi" },
	Ascension = { Id = "rbxassetid://7029070008", Name = "Ascension", By = "Vintage & Morelli (Monstercat)", Style = "smooth progressive house",
		Source = "https://create.roblox.com/store/asset/7029070008" },
	HypeHorns = { Id = "rbxassetid://1840007010", Name = "Hype Horns", By = "APM Music (Juice Music, NON STOP POP 2)", Style = "sassy funky horns and slick synth beats",
		Source = "https://create.roblox.com/store/asset/1840007010" },
	StayUpbeat = { Id = "rbxassetid://9044014229", Name = "Stay Upbeat B", By = "APM Music (Sonoton, THE NEW 80s)", Style = "uptempo 80s radio pop, 126 BPM",
		Source = "https://create.roblox.com/store/asset/9044014229/Stay-Upbeat-B" },
	FunkyPeople = { Id = "rbxassetid://1835417126", Name = "Funky People", By = "APM Music (Themes International)", Style = "funky pop groove",
		Source = "https://create.roblox.com/store/asset/1835417126" },
	Downtown = { Id = "rbxassetid://1843479959", Name = "Downtown", By = "APM Music (HIP-HOP FUNK & GROOVE)", Style = "hip-hop funk groove",
		Source = "https://create.roblox.com/store/asset/1843479959/Downtown" },
	SwingWithMe = { Id = "rbxassetid://1838645022", Name = "Swing With Me (Electro Swing Mix)", By = "APM Music (Themes International)", Style = "electro swing",
		Source = "https://create.roblox.com/store/asset/1838645022" },
	Akim = { Id = "rbxassetid://1843270078", Name = "Akim", By = "APM Music (Justement Music)", Style = "breakbeat",
		Source = "https://create.roblox.com/store/asset/1843270078" },
	Jumpstyle = { Id = "rbxassetid://1839246711", Name = "Jumpstyle", By = "APM Music", Style = "jumpstyle techno (kicks on every beat)",
		Source = "https://create.roblox.com/store/asset/1839246711/Jumpstyle" },
} :: { [string]: Track }

Dances.MusicVolume = 0.22 -- each dance song before the sliders (the background songs are 0.3: this stays under them)
Dances.MusicDuck = 0.35 -- the background music drops to this share of its volume while you dance
Dances.MusicFadeIn = 0.4 -- seconds
Dances.MusicFadeOut = 0.8 -- seconds, when the dance stops

Dances.List = {
	{ Id = "Floss", Name = "Floss", AnimationId = "", Starter = true, Color = "Red", Blurb = "Swing your arms and hips like a pro!", Order = 1, Music = "CrabRave" },
	{ Id = "CitrusGroove", Name = "Citrus Groove", AnimationId = "", Starter = true, Color = "Gold", Blurb = "A fresh and zesty groove to show off.", Order = 2, Music = "FunkyPeople" },
	{ Id = "HypeUp", Name = "Hype Up", AnimationId = "", Starter = true, Color = "Violet", Blurb = "Pump up the crowd before the run!", Order = 3, Music = "HypeHorns" },
	{ Id = "ShockShuffle", Name = "Shock Shuffle", AnimationId = "", Starter = true, Color = "Blue", Blurb = "Quick feet that zap across the floor.", Order = 4, Music = "Moshi" },
	{ Id = "ClassicGroove", Name = "Classic Groove", AnimationId = "", Starter = true, Color = "Pink", Blurb = "An old school groove that never gets old.", Order = 5, Music = "FunkyPeople" },
	{ Id = "BoogieDown", Name = "Boogie Down", AnimationId = "", Starter = true, Color = "Blue", Blurb = "Get down and boogie all night!", Order = 6, Music = "FunkyPeople" },
	{ Id = "SmoothMoves", Name = "Smooth Moves", AnimationId = "", Starter = true, Color = "Green", Blurb = "Glide around with silky smooth steps.", Order = 7, Music = "Ascension" },
	{ Id = "SoFresh", Name = "So Fresh", AnimationId = "", Starter = true, Color = "Green", Blurb = "Show everyone how fresh you are.", Order = 8, Music = "Downtown" },
	{ Id = "PopLock", Name = "Pop Lock", AnimationId = "", Starter = true, Color = "Red", Blurb = "Pop, freeze and lock to the beat.", Order = 9, Music = "Moshi" },
	{ Id = "Robot", Name = "Robot", AnimationId = "", Color = "Blue", Blurb = "Beep boop! Move like a real robot.", Order = 10, Music = "Moshi" },
	{ Id = "PhoneCall", Name = "Phone Call", AnimationId = "", Starter = true, Color = "Pink", Blurb = "Hello? The dance floor is calling!", Order = 11, Music = "Shiawase" },
	{ Id = "RunningMan", Name = "Running Man", AnimationId = "", Starter = true, Color = "Gold", Blurb = "Run in place right on the beat.", Order = 12, Music = "CrabRave" },
	{ Id = "CrazyFeet", Name = "Crazy Feet", AnimationId = "", Starter = true, Color = "Violet", Blurb = "Your feet go wild in every direction!", Order = 13, Music = "CrabRave" },
	{ Id = "Breakdown", Name = "Breakdown", AnimationId = "", Starter = true, Color = "Gold", Blurb = "Drop it low and break it down!", Order = 14, Music = "Akim" },
	{ Id = "SwingTime", Name = "Swing Time", AnimationId = "", Pack = true, Color = "Pink", Blurb = "Swing back in time with this classic.", Order = 15, Music = "SwingWithMe" },
	{ Id = "FreeFlow", Name = "Free Flow", AnimationId = "", Starter = true, Color = "Blue", Blurb = "Let the music move you.", Order = 16, Music = "Ascension" },
	{ Id = "Freestyle", Name = "Freestyle", AnimationId = "", Starter = true, Color = "Red", Blurb = "No rules, just your own moves!", Order = 17, Music = "Akim" },
	{ Id = "CleanGroove", Name = "Clean Groove", AnimationId = "", Starter = true, Color = "Green", Blurb = "Neat, sharp steps that look super clean.", Order = 18, Music = "Downtown" },
	{ Id = "BounceBounce", Name = "Bounce Bounce", AnimationId = "", Pack = true, Color = "Green", Blurb = "Bounce, bounce, bounce to the beat!", Order = 19, Music = "Shiawase" },
	{ Id = "Flapper", Name = "Flapper", AnimationId = "", Starter = true, Color = "Violet", Blurb = "Flap your arms in this fun old dance.", Order = 20, Music = "SwingWithMe" },
	{ Id = "SquatKick", Name = "Squat Kick", AnimationId = "", Pack = true, Color = "Red", Blurb = "Squat down low and kick it high!", Order = 21, Music = "Jumpstyle" },
	{ Id = "Sprinkler", Name = "Sprinkler", AnimationId = "", Starter = true, Color = "Blue", Blurb = "Spray your moves all over the place.", Order = 22, Music = "CrabRave" },
	{ Id = "CrabDance", Name = "Crab Dance", AnimationId = "", Starter = true, Color = "Red", Blurb = "Scuttle side to side like a crab!", Order = 23, Music = "CrabRave" },
	{ Id = "Toprock", Name = "Toprock", AnimationId = "", Pack = true, Color = "Gold", Blurb = "Rock your feet before the big moves.", Order = 24, Music = "Akim" },
	{ Id = "Aerobics", Name = "Aerobics", AnimationId = "", Starter = true, Color = "Pink", Blurb = "Get active with this energetic dance!", Order = 25, Music = "StayUpbeat" },
} :: { Dance }

local byId: { [string]: Dance } = {}
for _, d in Dances.List do byId[d.Id] = d end

function Dances.get(id: string): Dance?
	return byId[id]
end

-- The song for this dance, or nil (an unknown dance, no Music, or a track whose Id is still "": it dances in silence).
function Dances.track(id: string): Track?
	local d = byId[id]
	local t = d and d.Music and Dances.Tracks[d.Music]
	if not t or type(t.Id) ~= "string" or t.Id == "" then return nil end
	return t
end

return Dances

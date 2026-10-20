--!strict
-- Dances: 25 picked from the owner's 200-dance file (tools/anim/extract_anims.luau; the raw animation is
-- HuzzAnimations.Dance_<Id>). Names are our own (most of the originals are other games' emote names).
-- AnimationId = the published ID; "" plays the raw one in Studio (Shared/AnimationLibrary), and in the live game
-- the dance says it isn't ready until it's published (tools/studio/publish-animations.lua).
--   Starter = owned by everyone. Pack = granted by the Dance Pack pass. Robot = from the reward track (level 3) or the
--   Dance Crate. Crate = only from the Dance Crate (Config/Crates).
--   Color = the card's glow (Dances.Colors, after the owner's Oct 17 mockup: Aerobics pink, Boogie Down blue, Bounce
--   Bounce green, Breakdown gold, Floss red, Hype violet). Blurb = the one line under the big picture (short, no dashes).
--   Music = the key of its song in Dances.Tracks (owner, Oct 19: "find the sounds we can use for all of the dances ...
--   logically select the best sounds/songs possible"): only you hear it, quieter than the background music, which
--   dips under it (Gameplay/Music.dance). Backup = the second pick for that dance (also a Dances.Tracks key): it
--   plays when the first pick's Id is "" (owner, Oct 20: "find popular audios we can use with these dances. But make
--   them logically fit the dances"; no Fortnite audio: it's Epic's, not ours to upload). Each dance's style, tempo
--   and both picks with their reasons: docs/dance-music.md. Older research: docs/sound-picks.md.
export type Dance = { Id: string, Name: string, AnimationId: string, Art: string?, Starter: boolean?, Pack: boolean?, Crate: boolean?, Color: string, Blurb: string, Order: number, Music: string?, Backup: string? }
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
	-- (was "Funky People" 1835417126: only a 32 s cut, so a dance heard its ending and a restart every 32 s)
	BigDeal = { Id = "rbxassetid://9039954904", Name = "Big Deal", By = "APM Music (Conroy, Sounds Funky - Pop Brass Background)", Style = "funky pop brass groove, 2:06",
		Source = "https://create.roblox.com/store/asset/9039954904/Big-Deal" },
	Downtown = { Id = "rbxassetid://1843479959", Name = "Downtown", By = "APM Music (HIP-HOP FUNK & GROOVE)", Style = "hip-hop funk groove",
		Source = "https://create.roblox.com/store/asset/1843479959/Downtown" },
	SwingWithMe = { Id = "rbxassetid://1838645022", Name = "Swing With Me (Electro Swing Mix)", By = "APM Music (Themes International)", Style = "electro swing",
		Source = "https://create.roblox.com/store/asset/1838645022" },
	Akim = { Id = "rbxassetid://1843270078", Name = "Akim", By = "APM Music (Justement Music)", Style = "breakbeat",
		Source = "https://create.roblox.com/store/asset/1843270078" },
	Jumpstyle = { Id = "rbxassetid://1839246711", Name = "Jumpstyle", By = "APM Music", Style = "jumpstyle techno (kicks on every beat)",
		Source = "https://create.roblox.com/store/asset/1839246711/Jumpstyle" },
	-- Oct 20 dance deep dive (docs/dance-music.md): a song per dance style, all by @APMOfficial, all seen on their page
	Kalinka = { Id = "rbxassetid://1845855354", Name = "Kalinka A", By = "APM Music (Igor Tuhmanov, Authentic Russia)", Style = "Russian folk dance, 2:03 (starts slow, then speeds up)",
		Source = "https://create.roblox.com/store/asset/1845855354/Kalinka" },
	BoogieWoogie = { Id = "rbxassetid://1839965449", Name = "Boogie Woogie", By = "APM Music (Juice Music, GUITAR USA 2)", Style = "rockabilly rock 'n' roll with a boogie bass, 1:38",
		Source = "https://create.roblox.com/store/asset/1839965449" },
	BoogieManBoogie = { Id = "rbxassetid://1841081879", Name = "Boogie Man Boogie", By = "APM Music (Kenny Graham, 50S AND 60S VINYL CLASSICS)", Style = "50s and 60s vinyl boogie, 1:38",
		Source = "https://create.roblox.com/store/asset/1841081879" },
	Speakeasy = { Id = "rbxassetid://1836714741", Name = "The Speakeasy", By = "APM Music", Style = "retro pastiche (Kitsch), 2:12",
		Source = "https://create.roblox.com/store/asset/1836714741" },
	CharlestonDolly = { Id = "rbxassetid://1844694201", Name = "Charleston Dolly", By = "APM Music (Edward Koebelin)", Style = "big band, the sound of 70s TV shows, 2:14",
		Source = "https://create.roblox.com/store/asset/1844694201" },
	HalloweenFunk = { Id = "rbxassetid://1841274055", Name = "Halloween Funk", By = "APM Music (KIDS CLUB)", Style = "kids' pop Halloween funk, 2:05",
		Source = "https://create.roblox.com/store/asset/1841274055/Halloween-Funk" },
	TrickOrTreat = { Id = "rbxassetid://1837467234", Name = "Trick or Treat", By = "APM Music (The Box, HALLOWEEN THEMES)", Style = "mischievous intro into a Halloween hip-hop beat, 2:00",
		Source = "https://create.roblox.com/store/asset/1837467234/Trick-or-Treat" },
	PunchingTheAir = { Id = "rbxassetid://1836723913", Name = "Punching The Air", By = "APM Music (David Hearn, AMERICAN ROAD TRIP)", Style = "rock, 2:12",
		Source = "https://create.roblox.com/store/asset/1836723913" },
	SkullCrusher = { Id = "rbxassetid://1838319914", Name = "Skull Crusher", By = "APM Music (Anthony Cossa, ROCK ATTACK)", Style = "hard rock, 2:15",
		Source = "https://create.roblox.com/store/asset/1838319914" },
	DoItYourSelf = { Id = "rbxassetid://1840412669", Name = "Do It Your Self", By = "APM Music (KPM Main Series, Quirky And Curious)", Style = "quirky jazz, 2:16",
		Source = "https://create.roblox.com/store/asset/1840412669" },
	ShakeSomethin = { Id = "rbxassetid://1841134586", Name = "Shake Somethin'", By = "APM Music (Drew Milligan, HIP HOP BEDS)", Style = "hip-hop beat, 2:40",
		Source = "https://create.roblox.com/store/asset/1841134586" },
} :: { [string]: Track }

Dances.MusicVolume = 0.22 -- each dance song before the sliders (the background songs are 0.3: this stays under them)
-- the background music drops to this share of its volume while you dance (0.15 = about 16 dB down: two songs in
-- different keys and tempos at similar levels clash, so the dance song has to clearly win; was 0.35)
Dances.MusicDuck = 0.15
Dances.MusicFadeIn = 0.4 -- seconds
Dances.MusicFadeOut = 0.8 -- seconds, when the dance stops

Dances.List = {
	{ Id = "Floss", Name = "Floss", AnimationId = "", Starter = true, Color = "Red", Blurb = "Swing your arms and hips like a pro!", Order = 1, Music = "CrabRave", Backup = "Shiawase" },
	{ Id = "CitrusGroove", Name = "Citrus Groove", AnimationId = "", Starter = true, Color = "Gold", Blurb = "A fresh and zesty groove to show off.", Order = 2, Music = "Shiawase", Backup = "BigDeal" },
	{ Id = "HypeUp", Name = "Hype Up", AnimationId = "", Starter = true, Color = "Violet", Blurb = "Pump up the crowd before the run!", Order = 3, Music = "HypeHorns", Backup = "ShakeSomethin" },
	{ Id = "ShockShuffle", Name = "Shock Shuffle", AnimationId = "", Starter = true, Color = "Blue", Blurb = "Quick feet that zap across the floor.", Order = 4, Music = "Moshi", Backup = "CrabRave" },
	{ Id = "ClassicGroove", Name = "Classic Groove", AnimationId = "", Starter = true, Color = "Pink", Blurb = "An old school groove that never gets old.", Order = 5, Music = "BigDeal", Backup = "HypeHorns" },
	{ Id = "BoogieDown", Name = "Boogie Down", AnimationId = "", Starter = true, Color = "Blue", Blurb = "Get down and boogie all night!", Order = 6, Music = "BigDeal", Backup = "Downtown" },
	{ Id = "SmoothMoves", Name = "Smooth Moves", AnimationId = "", Starter = true, Color = "Green", Blurb = "Glide around with silky smooth steps.", Order = 7, Music = "Ascension", Backup = "Downtown" },
	{ Id = "SoFresh", Name = "So Fresh", AnimationId = "", Starter = true, Color = "Green", Blurb = "Show everyone how fresh you are.", Order = 8, Music = "ShakeSomethin", Backup = "Downtown" },
	{ Id = "PopLock", Name = "Pop Lock", AnimationId = "", Starter = true, Color = "Red", Blurb = "Pop, freeze and lock to the beat.", Order = 9, Music = "Moshi", Backup = "Downtown" },
	{ Id = "Robot", Name = "Robot", AnimationId = "", Color = "Blue", Blurb = "Beep boop! Move like a real robot.", Order = 10, Music = "Moshi", Backup = "CrabRave" },
	{ Id = "PhoneCall", Name = "Phone Call", AnimationId = "", Starter = true, Color = "Pink", Blurb = "Hello? The dance floor is calling!", Order = 11, Music = "Shiawase", Backup = "StayUpbeat" },
	{ Id = "RunningMan", Name = "Running Man", AnimationId = "", Starter = true, Color = "Gold", Blurb = "Run in place right on the beat.", Order = 12, Music = "StayUpbeat", Backup = "CrabRave" },
	{ Id = "CrazyFeet", Name = "Crazy Feet", AnimationId = "", Starter = true, Color = "Violet", Blurb = "Your feet go wild in every direction!", Order = 13, Music = "CrabRave", Backup = "Jumpstyle" },
	{ Id = "Breakdown", Name = "Breakdown", AnimationId = "", Starter = true, Color = "Gold", Blurb = "Drop it low and break it down!", Order = 14, Music = "Akim", Backup = "ShakeSomethin" },
	{ Id = "SwingTime", Name = "Swing Time", AnimationId = "", Pack = true, Color = "Pink", Blurb = "Swing back in time with this classic.", Order = 15, Music = "SwingWithMe", Backup = "CharlestonDolly" },
	{ Id = "FreeFlow", Name = "Free Flow", AnimationId = "", Starter = true, Color = "Blue", Blurb = "Let the music move you.", Order = 16, Music = "Ascension", Backup = "ShakeSomethin" },
	{ Id = "Freestyle", Name = "Freestyle", AnimationId = "", Starter = true, Color = "Red", Blurb = "No rules, just your own moves!", Order = 17, Music = "Akim", Backup = "ShakeSomethin" },
	{ Id = "CleanGroove", Name = "Clean Groove", AnimationId = "", Starter = true, Color = "Green", Blurb = "Neat, sharp steps that look super clean.", Order = 18, Music = "ShakeSomethin", Backup = "Downtown" },
	{ Id = "BounceBounce", Name = "Bounce Bounce", AnimationId = "", Pack = true, Color = "Green", Blurb = "Bounce, bounce, bounce to the beat!", Order = 19, Music = "Shiawase", Backup = "CrabRave" },
	{ Id = "Flapper", Name = "Flapper", AnimationId = "", Starter = true, Color = "Violet", Blurb = "Flap your arms in this fun old dance.", Order = 20, Music = "SwingWithMe", Backup = "Speakeasy" },
	{ Id = "SquatKick", Name = "Squat Kick", AnimationId = "", Pack = true, Color = "Red", Blurb = "Squat down low and kick it high!", Order = 21, Music = "Kalinka", Backup = "Jumpstyle" },
	{ Id = "Sprinkler", Name = "Sprinkler", AnimationId = "", Starter = true, Color = "Blue", Blurb = "Spray your moves all over the place.", Order = 22, Music = "CrabRave", Backup = "Moshi" },
	{ Id = "CrabDance", Name = "Crab Dance", AnimationId = "", Starter = true, Color = "Red", Blurb = "Scuttle side to side like a crab!", Order = 23, Music = "CrabRave", Backup = "Shiawase" },
	{ Id = "Toprock", Name = "Toprock", AnimationId = "", Pack = true, Color = "Gold", Blurb = "Rock your feet before the big moves.", Order = 24, Music = "Akim", Backup = "ShakeSomethin" },
	{ Id = "Aerobics", Name = "Aerobics", AnimationId = "", Starter = true, Color = "Pink", Blurb = "Get active with this energetic dance!", Order = 25, Music = "StayUpbeat", Backup = "HypeHorns" },
	-- Crate dances (owner, Oct 19: "dances, from crates"): only the Dance Crate gives them (Config/Crates).
	{ Id = "BoogieBlast", Name = "Boogie Blast", AnimationId = "", Crate = true, Color = "Pink", Blurb = "Throw a party right where you stand!", Order = 26, Music = "BigDeal", Backup = "HypeHorns" },
	{ Id = "HeadBanger", Name = "Head Banger", AnimationId = "", Crate = true, Color = "Red", Blurb = "Nod along hard to the beat.", Order = 27, Music = "PunchingTheAir", Backup = "SkullCrusher" },
	{ Id = "TheTwist", Name = "The Twist", AnimationId = "", Crate = true, Color = "Blue", Blurb = "Twist and turn like it's the old days.", Order = 28, Music = "BoogieWoogie", Backup = "BoogieManBoogie" },
	{ Id = "ZanyZig", Name = "Zany Zig", AnimationId = "", Crate = true, Color = "Green", Blurb = "Silly steps that zig and zag.", Order = 29, Music = "DoItYourSelf", Backup = "Shiawase" },
	{ Id = "PowerMoves", Name = "Power Moves", AnimationId = "", Crate = true, Color = "Violet", Blurb = "Big strong moves for big wins.", Order = 30, Music = "Akim", Backup = "HypeHorns" },
	{ Id = "Showstopper", Name = "Showstopper", AnimationId = "", Crate = true, Color = "Gold", Blurb = "All eyes on you. Steal the show!", Order = 31, Music = "CharlestonDolly", Backup = "HypeHorns" },
	{ Id = "ZombieGroove", Name = "Zombie Groove", AnimationId = "", Crate = true, Color = "Green", Blurb = "Rise from the grave and dance!", Order = 32, Music = "HalloweenFunk", Backup = "TrickOrTreat" },
} :: { Dance }

local byId: { [string]: Dance } = {}
for _, d in Dances.List do byId[d.Id] = d end

function Dances.get(id: string): Dance?
	return byId[id]
end

local function playable(key: string?): Track?
	local t = key and Dances.Tracks[key]
	if not t or type(t.Id) ~= "string" or t.Id == "" then return nil end
	return t
end

-- The song for this dance: its first pick (Music), else its second (Backup) when the first's Id is "", else nil (an
-- unknown dance, or no song with an Id: it dances in silence).
function Dances.track(id: string): Track?
	local d = byId[id]
	if not d then return nil end
	return playable(d.Music) or playable(d.Backup)
end

return Dances

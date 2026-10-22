--!strict
-- Dances: the owner's own 33 R6 dances (Oct 22; tools/anim/extract_anims.luau R6_DANCES; the raw animation is
-- HuzzAnimations.Dance_<Id>). Names are our own (most of the originals are other games' emote names).
-- AnimationId = the published ID; "" plays the raw one in Studio (Shared/AnimationLibrary), and in the live game
-- it's drawn by hand on the dancer's joints from its moves (UI/DancePlayer, Gameplay/DanceSync) until it's
-- published (tools/studio/publish-animations.lua, which writes these IDs); never invent one.
--   Starter = owned by everyone. Pack = granted by the Dance Pack pass. Untouchable = also on the reward track (level 3; Config/Progression).
--   Coins = its price in the Shop's DANCES (owner, Oct 20 20:34: "make a seperate section for dances, so that the
--   dances you get by buying them individually ... make them be able to be bought there"; ActionService "BuyDance").
--   Claude's prices: 400 to 2000 by how fancy (the old Dance Crate's rarities), 600 Untouchable. The 4 Pack dances have
--   no Coins: Robux only, through the Dance Pack (owner, Oct 21: "make the dances be some for Robux, some for coins").
--   Color = the card's glow (Dances.Colors, after the owner's Oct 17 mockup: Aerobics pink, Boogie Down blue, Bounce
--   Bounce green, Breakdown gold, Floss red, Hype violet). Blurb = the one line under the big picture (short, no dashes).
--   Music = the key of its song in Dances.Tracks (owner, Oct 19: "find the sounds we can use for all of the dances ...
--   logically select the best sounds/songs possible"): only you hear it, quieter than the background music, which
--   dips under it (Gameplay/Music.dance). Backup = the second pick for that dance (also a Dances.Tracks key): it
--   plays when the first pick's Id is "" (owner, Oct 20: "find popular audios we can use with these dances. But make
--   them logically fit the dances"; no Fortnite audio: it's Epic's, not ours to upload). Each dance's style, tempo
--   and both picks with their reasons: docs/dance-music.md. Older research: docs/sound-picks.md.
export type Dance = { Id: string, Name: string, AnimationId: string, Art: string?, Starter: boolean?, Pack: boolean?, Coins: number?, Color: string, Blurb: string, Order: number, Music: string?, Backup: string? }
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

-- The owner's own R6 dances (Oct 22 13:24: "input these dances i found and remove the old ones"): his two R6 emote
-- packs, dances only (tools/anim/extract_anims.luau R6_DANCES: which of his is which). The old 32 are gone; coins
-- paid for old dances came back (HuzzServer/DataService OLD_DANCES). Same split as before: most for everyone, 4 in
-- the Dance Pack, 8 for coins (Untouchable also on the reward track at Level 3, where Robot was).
Dances.List = {
	{ Id = "OrangeSwing", Name = "Orange Swing", AnimationId = "", Starter = true, Color = "Red", Blurb = "Swing your arms and step side to side!", Order = 1, Music = "CrabRave", Backup = "Shiawase" },
	{ Id = "BoogieDown", Name = "Boogie Down", AnimationId = "", Starter = true, Color = "Blue", Blurb = "Get down and boogie all night!", Order = 2, Music = "BigDeal", Backup = "BoogieManBoogie" },
	{ Id = "ElBounce", Name = "L Bounce", AnimationId = "", Starter = true, Color = "Green", Blurb = "Bounce and show them who's winning.", Order = 3, Music = "Moshi", Backup = "CrabRave" },
	{ Id = "SquatKicks", Name = "Squat Kicks", AnimationId = "", Starter = true, Color = "Violet", Blurb = "Squat down low and kick it out!", Order = 4, Music = "Kalinka", Backup = "Jumpstyle" },
	{ Id = "HighRoller", Name = "High Roller", AnimationId = "", Starter = true, Color = "Gold", Blurb = "Smooth moves for a lucky winner.", Order = 5, Music = "SwingWithMe", Backup = "Speakeasy" },
	{ Id = "OfficeParty", Name = "Office Party", AnimationId = "", Starter = true, Color = "Blue", Blurb = "The whole team dances together!", Order = 6, Music = "StayUpbeat", Backup = "BigDeal" },
	{ Id = "ParrotWiggle", Name = "Parrot Wiggle", AnimationId = "", Starter = true, Color = "Green", Blurb = "Wiggle like a happy parrot.", Order = 7, Music = "Shiawase", Backup = "CrabRave" },
	{ Id = "KittyPaws", Name = "Kitty Paws", AnimationId = "", Starter = true, Color = "Pink", Blurb = "Cute paws, quick beats. Meow!", Order = 8, Music = "Shiawase", Backup = "Moshi" },
	{ Id = "CandyHop", Name = "Candy Hop", AnimationId = "", Starter = true, Color = "Pink", Blurb = "A sweet little hop to the beat.", Order = 9, Music = "Shiawase", Backup = "StayUpbeat" },
	{ Id = "Beatbox", Name = "Beatbox", AnimationId = "", Starter = true, Color = "Violet", Blurb = "Drop the beat right where you stand.", Order = 10, Music = "Akim", Backup = "ShakeSomethin" },
	{ Id = "SurfsUp", Name = "Surf's Up", AnimationId = "", Starter = true, Color = "Blue", Blurb = "Ride the wave all the way in.", Order = 11, Music = "StayUpbeat", Backup = "HypeHorns" },
	{ Id = "ElectroShuffle", Name = "Electro Shuffle", AnimationId = "", Starter = true, Color = "Blue", Blurb = "Quick feet that zap across the floor.", Order = 12, Music = "Moshi", Backup = "CrabRave" },
	{ Id = "JumpStyle", Name = "Jump Style", AnimationId = "", Starter = true, Color = "Gold", Blurb = "Kick and jump on every beat!", Order = 13, Music = "Jumpstyle", Backup = "Moshi" },
	{ Id = "QuickShuffle", Name = "Quick Shuffle", AnimationId = "", Starter = true, Color = "Red", Blurb = "Shuffle fast and never stop.", Order = 14, Music = "CrabRave", Backup = "Moshi" },
	{ Id = "ChillGroove", Name = "Chill Groove", AnimationId = "", Starter = true, Color = "Green", Blurb = "Nice and easy, just vibing.", Order = 15, Music = "Downtown", Backup = "Ascension" },
	{ Id = "SnappySkip", Name = "Snappy Skip", AnimationId = "", Starter = true, Color = "Gold", Blurb = "Skip along with a snap!", Order = 16, Music = "StayUpbeat", Backup = "BoogieWoogie" },
	{ Id = "CatDance", Name = "Cat Dance", AnimationId = "", Starter = true, Color = "Pink", Blurb = "Purrfect moves for cool cats.", Order = 17, Music = "Shiawase", Backup = "DoItYourSelf" },
	{ Id = "WavyGrooves", Name = "Wavy Grooves", AnimationId = "", Starter = true, Color = "Violet", Blurb = "Smooth waves from head to toe.", Order = 18, Music = "Ascension", Backup = "Downtown" },
	{ Id = "StepItUp", Name = "Step It Up", AnimationId = "", Starter = true, Color = "Red", Blurb = "Big steps, big energy!", Order = 19, Music = "HypeHorns", Backup = "ShakeSomethin" },
	{ Id = "SupremeGroove", Name = "Supreme Groove", AnimationId = "", Starter = true, Color = "Gold", Blurb = "The groove that tops them all.", Order = 20, Music = "ShakeSomethin", Backup = "Downtown" },
	{ Id = "PopStar", Name = "Pop Star", AnimationId = "", Starter = true, Color = "Pink", Blurb = "Shine like a pop star on stage.", Order = 21, Music = "StayUpbeat", Backup = "Shiawase" },
	-- the Dance Pack's (Robux only, through the pass)
	{ Id = "Breakdance", Name = "Breakdance", AnimationId = "", Pack = true, Color = "Gold", Blurb = "Spin and flip like a breaker!", Order = 22, Music = "Akim", Backup = "ShakeSomethin" },
	{ Id = "Superstar", Name = "Superstar", AnimationId = "", Pack = true, Color = "Violet", Blurb = "All eyes on you. Steal the show!", Order = 23, Music = "HypeHorns", Backup = "CharlestonDolly" },
	{ Id = "BlossomBreak", Name = "Blossom Break", AnimationId = "", Pack = true, Color = "Pink", Blurb = "A long, beautiful dance in bloom.", Order = 24, Music = "Ascension", Backup = "Shiawase" },
	{ Id = "WibblyWobbly", Name = "Wibbly Wobbly", AnimationId = "", Pack = true, Color = "Green", Blurb = "Wobble around like jelly!", Order = 25, Music = "DoItYourSelf", Backup = "Shiawase" },
	-- sold in the Shop's DANCES for coins (Untouchable also on the reward track at Level 3)
	{ Id = "Untouchable", Name = "Untouchable", AnimationId = "", Coins = 600, Color = "Blue", Blurb = "Too cool to catch. Nobody can touch you.", Order = 26, Music = "Moshi", Backup = "CrabRave" },
	{ Id = "LetsGo", Name = "Let's Go", AnimationId = "", Coins = 400, Color = "Red", Blurb = "Hype yourself up. Let's go!", Order = 27, Music = "ShakeSomethin", Backup = "HypeHorns" },
	{ Id = "LoseControl", Name = "Lose Control", AnimationId = "", Coins = 400, Color = "Violet", Blurb = "Go wild and let the beat take over.", Order = 28, Music = "PunchingTheAir", Backup = "SkullCrusher" },
	{ Id = "BoneGroove", Name = "Bone Groove", AnimationId = "", Coins = 600, Color = "Green", Blurb = "Rattle your bones to the beat.", Order = 29, Music = "HalloweenFunk", Backup = "TrickOrTreat" },
	{ Id = "SkeletonShake", Name = "Skeleton Shake", AnimationId = "", Coins = 800, Color = "Gold", Blurb = "Shake it like a spooky skeleton!", Order = 30, Music = "TrickOrTreat", Backup = "HalloweenFunk" },
	{ Id = "ZombieWalk", Name = "Zombie Walk", AnimationId = "", Coins = 1200, Color = "Green", Blurb = "Rise from the grave and dance!", Order = 31, Music = "HalloweenFunk", Backup = "TrickOrTreat" },
	{ Id = "Moongazer", Name = "Moongazer", AnimationId = "", Coins = 1200, Color = "Blue", Blurb = "Dance under the moonlight.", Order = 32, Music = "Ascension", Backup = "Downtown" },
	{ Id = "FlexTime", Name = "Flex Time", AnimationId = "", Coins = 2000, Color = "Gold", Blurb = "Show off every muscle you've got!", Order = 33, Music = "PunchingTheAir", Backup = "HypeHorns" },
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

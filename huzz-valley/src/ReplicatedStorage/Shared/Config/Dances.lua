--!strict
-- Dances: the owner's own 33 R6 dances (Oct 22; tools/anim/extract_anims.luau R6_DANCES; the raw animation is
-- HuzzAnimations.Dance_<Id>), and two measured off his videos (Balenci, SweetDancin: tools/anim/fit).
-- Names are our own (most of the originals are other games' emote names; the video two keep theirs).
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
export type Track = { Id: string, Name: string, By: string, Style: string, Source: string, Start: number?, Full: number?, First: number?, Loop: number? }

local Dances = {}

-- The mockup's six card colours (measured on its glowing notes).
Dances.Colors = {
	Pink = Color3.fromHex("E56CFF"), Blue = Color3.fromHex("5AA6FF"), Green = Color3.fromHex("45E0A0"),
	Gold = Color3.fromHex("FFC24F"), Red = Color3.fromHex("FF5672"), Violet = Color3.fromHex("A066FF"),
} :: { [string]: Color3 }

Dances.MaxFavourites = 12 -- (the server's cap on a player's saved favourites)

-- The dance songs: none for now (owner, Oct 23 21:11: "get rid of all emote sounds, completely, tomorrow i will add
-- new ones tuned for every dance"). Every dance plays in silence until its new song goes here and its Music names it
-- (Gameplay/Music.dance plays Dances.track(id); Start, Full, First and Loop work as before). The old picks are in
-- git history (Config/Dances before Oct 23 21:11, docs/dance-music.md).
Dances.Tracks = {} :: { [string]: Track }

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
	{ Id = "OrangeSwing", Name = "Orange Swing", AnimationId = "", Starter = true, Color = "Red", Blurb = "Swing your arms and step side to side!", Order = 1 },
	{ Id = "BoogieDown", Name = "Boogie Down", AnimationId = "", Starter = true, Color = "Blue", Blurb = "Get down and boogie all night!", Order = 2 },
	{ Id = "ElBounce", Name = "L Bounce", AnimationId = "", Starter = true, Color = "Green", Blurb = "Bounce and show them who's winning.", Order = 3 },
	{ Id = "SquatKicks", Name = "Squat Kicks", AnimationId = "", Starter = true, Color = "Violet", Blurb = "Squat down low and kick it out!", Order = 4 },
	{ Id = "HighRoller", Name = "High Roller", AnimationId = "", Starter = true, Color = "Gold", Blurb = "Smooth moves for a lucky winner.", Order = 5 },
	{ Id = "OfficeParty", Name = "Office Party", AnimationId = "", Starter = true, Color = "Blue", Blurb = "The whole team dances together!", Order = 6 },
	{ Id = "ParrotWiggle", Name = "Parrot Wiggle", AnimationId = "", Starter = true, Color = "Green", Blurb = "Wiggle like a happy parrot.", Order = 7 },
	{ Id = "KittyPaws", Name = "Kitty Paws", AnimationId = "", Starter = true, Color = "Pink", Blurb = "Cute paws, quick beats. Meow!", Order = 8 },
	{ Id = "CandyHop", Name = "Candy Hop", AnimationId = "", Starter = true, Color = "Pink", Blurb = "A sweet little hop to the beat.", Order = 9 },
	{ Id = "Beatbox", Name = "Beatbox", AnimationId = "", Starter = true, Color = "Violet", Blurb = "Drop the beat right where you stand.", Order = 10 },
	{ Id = "SurfsUp", Name = "Surf's Up", AnimationId = "", Starter = true, Color = "Blue", Blurb = "Ride the wave all the way in.", Order = 11 },
	{ Id = "ElectroShuffle", Name = "Electro Shuffle", AnimationId = "", Starter = true, Color = "Blue", Blurb = "Quick feet that zap across the floor.", Order = 12 },
	{ Id = "JumpStyle", Name = "Jump Style", AnimationId = "", Starter = true, Color = "Gold", Blurb = "Kick and jump on every beat!", Order = 13 },
	{ Id = "QuickShuffle", Name = "Quick Shuffle", AnimationId = "", Starter = true, Color = "Red", Blurb = "Shuffle fast and never stop.", Order = 14 },
	{ Id = "ChillGroove", Name = "Chill Groove", AnimationId = "", Starter = true, Color = "Green", Blurb = "Nice and easy, just vibing.", Order = 15 },
	{ Id = "SnappySkip", Name = "Snappy Skip", AnimationId = "", Starter = true, Color = "Gold", Blurb = "Skip along with a snap!", Order = 16 },
	{ Id = "CatDance", Name = "Cat Dance", AnimationId = "", Starter = true, Color = "Pink", Blurb = "Purrfect moves for cool cats.", Order = 17 },
	{ Id = "WavyGrooves", Name = "Wavy Grooves", AnimationId = "", Starter = true, Color = "Violet", Blurb = "Smooth waves from head to toe.", Order = 18 },
	{ Id = "StepItUp", Name = "Step It Up", AnimationId = "", Starter = true, Color = "Red", Blurb = "Big steps, big energy!", Order = 19 },
	{ Id = "SupremeGroove", Name = "Supreme Groove", AnimationId = "", Starter = true, Color = "Gold", Blurb = "The groove that tops them all.", Order = 20 },
	{ Id = "PopStar", Name = "Pop Star", AnimationId = "", Starter = true, Color = "Pink", Blurb = "Shine like a pop star on stage.", Order = 21 },
	-- the Dance Pack's (Robux only, through the pass)
	{ Id = "Breakdance", Name = "Breakdance", AnimationId = "", Pack = true, Color = "Gold", Blurb = "Spin and flip like a breaker!", Order = 22 },
	{ Id = "Superstar", Name = "Superstar", AnimationId = "", Pack = true, Color = "Violet", Blurb = "All eyes on you. Steal the show!", Order = 23 },
	{ Id = "BlossomBreak", Name = "Blossom Break", AnimationId = "", Pack = true, Color = "Pink", Blurb = "A long, beautiful dance in bloom.", Order = 24 },
	{ Id = "WibblyWobbly", Name = "Wibbly Wobbly", AnimationId = "", Pack = true, Color = "Green", Blurb = "Wobble around like jelly!", Order = 25 },
	-- sold in the Shop's DANCES for coins (Untouchable also on the reward track at Level 3)
	{ Id = "Untouchable", Name = "Untouchable", AnimationId = "", Coins = 600, Color = "Blue", Blurb = "Too cool to catch. Nobody can touch you.", Order = 26 },
	{ Id = "LetsGo", Name = "Let's Go", AnimationId = "", Coins = 400, Color = "Red", Blurb = "Hype yourself up. Let's go!", Order = 27 },
	{ Id = "LoseControl", Name = "Lose Control", AnimationId = "", Coins = 400, Color = "Violet", Blurb = "Go wild and let the beat take over.", Order = 28 },
	{ Id = "BoneGroove", Name = "Bone Groove", AnimationId = "", Coins = 600, Color = "Green", Blurb = "Rattle your bones to the beat.", Order = 29 },
	{ Id = "SkeletonShake", Name = "Skeleton Shake", AnimationId = "", Coins = 800, Color = "Gold", Blurb = "Shake it like a spooky skeleton!", Order = 30 },
	{ Id = "ZombieWalk", Name = "Zombie Walk", AnimationId = "", Coins = 1200, Color = "Green", Blurb = "Rise from the grave and dance!", Order = 31 },
	{ Id = "Moongazer", Name = "Moongazer", AnimationId = "", Coins = 1200, Color = "Blue", Blurb = "Dance under the moonlight.", Order = 32 },
	{ Id = "FlexTime", Name = "Flex Time", AnimationId = "", Coins = 2000, Color = "Gold", Blurb = "Show off every muscle you've got!", Order = 33 },
	-- the two from his videos (owner, Oct 22 15:28; tools/anim/fit): the Balenci spin and Sweet Dancin's arms-up bounce
	{ Id = "Balenci", Name = "Balenci", AnimationId = "", Coins = 2000, Color = "Pink", Blurb = "Hop, swing and spin all the way round!", Order = 34 },
	{ Id = "SweetDancin", Name = "Sweet Dancin", AnimationId = "", Coins = 800, Color = "Violet", Blurb = "Hands up and bounce to the beat.", Order = 35 },
	-- the hardtekk three (owner, Oct 22 16:00), each made beat by beat for one of his songs (tools/anim/fit/author_dances.py)
	{ Id = "TekkPump", Name = "Tekk Pump", AnimationId = "", Coins = 1200, Color = "Red", Blurb = "Pump your fist on every kick!", Order = 36 },
	{ Id = "HakkenStomp", Name = "Hakken Stomp", AnimationId = "", Coins = 1200, Color = "Gold", Blurb = "Stomp and kick at full speed.", Order = 37 },
	{ Id = "JumpstyleRave", Name = "Jumpstyle Rave", AnimationId = "", Coins = 1500, Color = "Blue", Blurb = "Jump, kick and spin with your hands up!", Order = 38 },
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

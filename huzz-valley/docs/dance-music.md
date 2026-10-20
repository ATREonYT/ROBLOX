# Dance music: a song that fits each dance (Oct 20)

The owner, word for word (Oct 20 15:13): "In general also do a deep dive on these dances as they are from fortnite,
the songs come from fortnite, then you either find the non copyright fortnite sounds, or find popular audios we can
use with these dances. But make them logically fit the dances that we have in game."

## The short answer

- **Fortnite's emote songs can't be used.** They belong to Epic Games (several are licensed from record labels).
  There is no "non copyright" version: a re-upload of them on Roblox is still their music. Roblox removes copyrighted
  uploads and can mute or strike the game. So none of them are in the game, and none will be.
- **What we use instead:** songs from **Roblox's own licensed library**: tracks uploaded by **@APMOfficial** (APM
  Music) and **@Monstercat**. Roblox licensed them for any Roblox game. They are public, so they play in Studio and in
  the live game, with nothing to upload and nothing to pay. (Why this is safe, with sources: `docs/sound-picks.md`
  section 1.)
- **"Popular":** real chart songs aren't in that library. The most famous one in it is **Crab Rave** (Monstercat), and
  it is already on the four meme dances. The rest are catchy production tracks picked for the *style* of each dance:
  the same idea Fortnite uses (each emote gets its own made-for-it song in that dance's genre).
- **Every dance has 2 picks, both with a real ID.** Pick 1 plays. Pick 2 plays only if pick 1's ID is emptied
  (`Config/Dances`: `Music` and `Backup`). 22 songs in all (11 new today), no song is pick 1 for more than 4 dances.

## How the fit was judged

1. **The dance's style**: what kind of dance it is and what its Fortnite emote sounds like (genre, era, mood).
   Fortnite's own pages (fortnite.fandom.com, fortnite.gg) can't be opened from the cloud session, so the "Fortnite"
   column is from what is widely known about each emote plus what web search showed (Squat Kick is "inspired by
   Slavic folk dance"; Fresh is the Carlton; Floss is the Backpack Kid's dance; Hype is BlocBoy JB's Shoot dance;
   Zany has "an electronic beat ... finished with a signature pop"). Our names are our own; where a dance is clearly a
   Fortnite emote, the emote is named.
2. **Its tempo, measured from our own animation** (`tools/preview/motion3d/dance_tempo.luau`: how fast the hands,
   feet, head and torso move over the loop, and how strongly that repeats). The number is beats per minute folded
   into 85-170. Only trust it when "strength" is above 0.4 (Floss, Flapper, Hype Up, Running Man, So Fresh, Sprinkler,
   Squat Kick, The Twist). A song can't be stretched to the animation in Roblox, so the fit is energy and feel, not
   exact beats.
3. **Kid-safe**: instrumental, no lyrics we can't check, no scary horror sounds, no dubstep drops.
4. **Long enough to loop**: full songs (1:38 to 3:37), not 30 s cuts with an ending.

## Every dance

Columns: our measured tempo (strength in brackets), then the two picks with their store page. "Seen" = the ID came
from the store page found by web search limited to create.roblox.com, which also read its title, uploader and
length off the page (the cloud can't open roblox.com directly). Nobody here has *heard* them: the owner's ear decides.

| Dance | Style (Fortnite's emote, and ours) / tempo | Pick 1 (plays) | Pick 2 (backup) | Why it fits |
|---|---|---|---|---|
| Floss | Fortnite's Floss: bouncy electronic pop. 112 BPM (1.16, reliable) | Crab Rave, Noisestorm, `5410086218`, [store](https://create.roblox.com/store/asset/5410086218/Noisestorm-Crab-Rave) | Shiawase, Dion Timmer, `5409360995`, [store](https://create.roblox.com/store/asset/5409360995/Dion-Timmer-Shiawase) | the internet's meme-dance anthem for the most famous meme dance |
| Citrus Groove | like Orange Justice: a bouncy, goofy electronic groove. 156 BPM (0.12, hint) | Shiawase, Dion Timmer, `5409360995`, [store](https://create.roblox.com/store/asset/5409360995/Dion-Timmer-Shiawase) | Big Deal, APM, `9039954904`, [store](https://create.roblox.com/store/asset/9039954904/Big-Deal) | cute, bouncy EDM at 150 BPM, right on this dance's fast bounce |
| Hype Up | Fortnite's Hype: hip-hop with horns (the Shoot dance). 151 BPM (0.73, reliable) | Hype Horns, APM, `1840007010`, [store](https://create.roblox.com/store/asset/1840007010) | Shake Somethin', APM, `1841134586`, [store](https://create.roblox.com/store/asset/1841134586) | "sassy and funky horns" = hype; pick 2 is a plain hip-hop beat |
| Shock Shuffle | like Electro Shuffle: electro house. 87 BPM (0.13, hint) | Moshi, Pegboard Nerds & Tokyo Machine, `7024340270`, [store](https://create.roblox.com/store/asset/7024340270/Pegboard-Nerds-Tokyo-Machine-Moshi) | Crab Rave, `5410086218`, [store](https://create.roblox.com/store/asset/5410086218/Noisestorm-Crab-Rave) | zappy electro for "quick feet that zap" |
| Classic Groove | an old-school funk groove. 125 BPM (0.38) | Big Deal, APM (Conroy), `9039954904`, [store](https://create.roblox.com/store/asset/9039954904/Big-Deal) | Hype Horns, `1840007010`, [store](https://create.roblox.com/store/asset/1840007010) | its 30 s cut is listed as a "funky disco bed, retro strings and horns, 123 bpm": the dance measures 125 |
| Boogie Down | Fortnite's Boogie Down: 70s disco funk. 109 BPM (0.31) | Big Deal, `9039954904`, [store](https://create.roblox.com/store/asset/9039954904/Big-Deal) | Downtown, APM, `1843479959`, [store](https://create.roblox.com/store/asset/1843479959/Downtown) | disco strings and horns for a disco dance |
| Smooth Moves | a smooth, gliding groove. 100 BPM (0.16) | Ascension, Vintage & Morelli, `7029070008`, [store](https://create.roblox.com/store/asset/7029070008) | Downtown, `1843479959`, [store](https://create.roblox.com/store/asset/1843479959/Downtown) | flowing, uplifting house for silky steps |
| So Fresh | Fortnite's Fresh (the Carlton): 90s fun. 95 BPM (0.43, reliable) | Shake Somethin', APM (Drew Milligan, HIP HOP BEDS), `1841134586`, [store](https://create.roblox.com/store/asset/1841134586) | Downtown, `1843479959`, [store](https://create.roblox.com/store/asset/1843479959/Downtown) | a hip-hop beat at a 90s hip-hop pace; full 2:40 (Downtown is only 1:00) |
| Pop Lock | popping and locking: electro funk. 119 BPM (0.12) | Moshi, `7024340270`, [store](https://create.roblox.com/store/asset/7024340270/Pegboard-Nerds-Tokyo-Machine-Moshi) | Downtown, `1843479959`, [store](https://create.roblox.com/store/asset/1843479959/Downtown) | robotic, choppy electro for pops and freezes |
| Robot | Fortnite's Robot: electro with beeps. 165 BPM (0.16) | Moshi, `7024340270`, [store](https://create.roblox.com/store/asset/7024340270/Pegboard-Nerds-Tokyo-Machine-Moshi) | Crab Rave, `5410086218`, [store](https://create.roblox.com/store/asset/5410086218/Noisestorm-Crab-Rave) | video-game synths = robot |
| Phone Call | a cute, chatty pop dance. 152 BPM (0.22) | Shiawase, `5409360995`, [store](https://create.roblox.com/store/asset/5409360995/Dion-Timmer-Shiawase) | Stay Upbeat B, APM, `9044014229`, [store](https://create.roblox.com/store/asset/9044014229/Stay-Upbeat-B) | cute anime-flavoured pop at about its tempo |
| Running Man | Fortnite's Running Man: late-80s/90s dance pop. 163 steps a minute (1.50, reliable) | Stay Upbeat B, APM (Sonoton, THE NEW 80s), `9044014229`, [store](https://create.roblox.com/store/asset/9044014229/Stay-Upbeat-B) | Crab Rave, `5410086218`, [store](https://create.roblox.com/store/asset/5410086218/Noisestorm-Crab-Rave) | 80s radio pop for an 80s dance |
| Crazy Feet | fast, wild footwork. 160 BPM (0.29) | Crab Rave, `5410086218`, [store](https://create.roblox.com/store/asset/5410086218/Noisestorm-Crab-Rave) | Jumpstyle, APM, `1839246711`, [store](https://create.roblox.com/store/asset/1839246711/Jumpstyle) | high-energy dance music for flailing feet |
| Breakdown | b-boy breaking. no clear beat (0.02) | Akim, APM (Justement Music), `1843270078`, [store](https://create.roblox.com/store/asset/1843270078) | Shake Somethin', `1841134586`, [store](https://create.roblox.com/store/asset/1841134586) | breaking was born on breakbeats |
| Swing Time | swing dance. 121 BPM (0.39) | Swing With Me (Electro Swing Mix), APM, `1838645022`, [store](https://create.roblox.com/store/asset/1838645022) | Charleston Dolly, APM, `1844694201`, [store](https://create.roblox.com/store/asset/1844694201) | swing on a modern beat; pick 2 is real big band |
| Free Flow | a loose, flowing freestyle. 122 BPM (0.21) | Ascension, `7029070008`, [store](https://create.roblox.com/store/asset/7029070008) | Shake Somethin', `1841134586`, [store](https://create.roblox.com/store/asset/1841134586) | "let the music move you": flowing house |
| Freestyle | hip-hop freestyle. 107 BPM (0.14) | Akim, `1843270078`, [store](https://create.roblox.com/store/asset/1843270078) | Shake Somethin', `1841134586`, [store](https://create.roblox.com/store/asset/1841134586) | breakbeat for b-boy freestyle |
| Clean Groove | Fortnite's Clean Groove: a crisp hip-hop groove. 120 BPM (0.17) | Shake Somethin', `1841134586`, [store](https://create.roblox.com/store/asset/1841134586) | Downtown, `1843479959`, [store](https://create.roblox.com/store/asset/1843479959/Downtown) | a clean hip-hop beat for "neat, sharp steps" |
| Bounce Bounce | bouncing on the spot. 85 (or 170) BPM (0.36) | Shiawase, `5409360995`, [store](https://create.roblox.com/store/asset/5409360995/Dion-Timmer-Shiawase) | Crab Rave, `5410086218`, [store](https://create.roblox.com/store/asset/5410086218/Noisestorm-Crab-Rave) | bouncy, cute EDM |
| Flapper | Fortnite's Flapper: the 1920s Charleston, hot jazz. 160 BPM (0.71, reliable) | Swing With Me (Electro Swing Mix), `1838645022`, [store](https://create.roblox.com/store/asset/1838645022) | The Speakeasy, APM, `1836714741`, [store](https://create.roblox.com/store/asset/1836714741) | electro swing is built on 1920s swing; pick 2 is named after the 1920s clubs (genre "Kitsch": listen first) |
| Squat Kick | Fortnite's Squat Kick: a Slavic folk dance (the Cossack kick). 150 BPM (1.22, reliable) | **Kalinka A**, APM (Igor Tuhmanov, Authentic Russia), `1845855354`, [store](https://create.roblox.com/store/asset/1845855354/Kalinka) | Jumpstyle, `1839246711`, [store](https://create.roblox.com/store/asset/1839246711/Jumpstyle) | the most famous Russian folk dance tune, for the Russian folk dance; it speeds up like the dance (Jumpstyle was louder and harder) |
| Sprinkler | the Sprinkler: a party/house dance. 146 BPM (0.45, reliable) | Crab Rave, `5410086218`, [store](https://create.roblox.com/store/asset/5410086218/Noisestorm-Crab-Rave) | Moshi, `7024340270`, [store](https://create.roblox.com/store/asset/7024340270/Pegboard-Nerds-Tokyo-Machine-Moshi) | party house for a party move |
| Crab Dance | a crab scuttle. 126 BPM (0.16) | Crab Rave, `5410086218`, [store](https://create.roblox.com/store/asset/5410086218/Noisestorm-Crab-Rave) | Shiawase, `5409360995`, [store](https://create.roblox.com/store/asset/5409360995/Dion-Timmer-Shiawase) | Crab Dance + Crab Rave (the song is about 125 BPM) |
| Toprock | b-boy toprock. 102 BPM (0.04) | Akim, `1843270078`, [store](https://create.roblox.com/store/asset/1843270078) | Shake Somethin', `1841134586`, [store](https://create.roblox.com/store/asset/1841134586) | breakbeat |
| Aerobics | 80s workout. 156 BPM (0.24) | Stay Upbeat B, `9044014229`, [store](https://create.roblox.com/store/asset/9044014229/Stay-Upbeat-B) | Hype Horns, `1840007010`, [store](https://create.roblox.com/store/asset/1840007010) | 80s pop is the sound of aerobics videos |
| Boogie Blast | a party dance. 133 BPM (0.31) | Big Deal, `9039954904`, [store](https://create.roblox.com/store/asset/9039954904/Big-Deal) | Hype Horns, `1840007010`, [store](https://create.roblox.com/store/asset/1840007010) | "throw a party": disco horns |
| Head Banger | head-banging: rock. 89 BPM (0.25) | **Punching The Air**, APM (David Hearn, AMERICAN ROAD TRIP), `1836723913`, [store](https://create.roblox.com/store/asset/1836723913) | Skull Crusher, APM (Anthony Cossa, ROCK ATTACK), `1838319914`, [store](https://create.roblox.com/store/asset/1838319914) | you headbang to rock guitars (it had breakbeat before); pick 2 is heavier |
| The Twist | the 1960s Twist: rock 'n' roll. 165 BPM (0.62, reliable; the famous Twist song is about 156) | **Boogie Woogie**, APM (Juice Music, GUITAR USA 2), `1839965449`, [store](https://create.roblox.com/store/asset/1839965449) | Boogie Man Boogie, APM (Kenny Graham, 50S AND 60S VINYL CLASSICS), `1841081879`, [store](https://create.roblox.com/store/asset/1841081879) | "rockabilly-style rock 'n' roll with a boogie-woogie bassline": the Twist's own era (it had electro swing before) |
| Zany Zig | Fortnite's Zany: a silly zig-zag dance on an electronic beat. 124 BPM (0.09) | **Do It Your Self**, APM (KPM, "Quirky And Curious"), `1840412669`, [store](https://create.roblox.com/store/asset/1840412669) | Shiawase, `5409360995`, [store](https://create.roblox.com/store/asset/5409360995/Dion-Timmer-Shiawase) | quirky, playful music for silly steps |
| Power Moves | b-boy power moves (spins). 131 BPM (0.09) | Akim, `1843270078`, [store](https://create.roblox.com/store/asset/1843270078) | Hype Horns, `1840007010`, [store](https://create.roblox.com/store/asset/1840007010) | power moves are breaking: breakbeat |
| Showstopper | a showbiz "big finish". 115 BPM (0.14) | **Charleston Dolly**, APM (Edward Koebelin), `1844694201`, [store](https://create.roblox.com/store/asset/1844694201) | Hype Horns, `1840007010`, [store](https://create.roblox.com/store/asset/1840007010) | "big band sound of the 70s TV programs": a show tune for "all eyes on you" |
| Zombie Groove | a spooky, Thriller-style groove. 85 BPM (0.05) | **Halloween Funk**, APM (KIDS CLUB, genre Kid's Pop), `1841274055`, [store](https://create.roblox.com/store/asset/1841274055/Halloween-Funk) | Trick or Treat, APM (The Box, HALLOWEEN THEMES), `1837467234`, [store](https://create.roblox.com/store/asset/1837467234/Trick-or-Treat) | spooky but made for kids, and funky; fits his Halloween lobby (it had a plain hip-hop beat before) |

**Bold** = a new pick today. Changed pick 1 today: Squat Kick (Jumpstyle to Kalinka), Head Banger (Akim to Punching
The Air), The Twist (Swing With Me to Boogie Woogie), Zany Zig (Shiawase to Do It Your Self), Showstopper (Stay
Upbeat B to Charleston Dolly), Zombie Groove (Downtown to Halloween Funk), Citrus Groove (Big Deal to Shiawase), Power
Moves (Hype Horns to Akim), So Fresh and Clean Groove (Downtown, 1:00, to Shake Somethin', 2:40).

## The songs (22)

| Key in `Config/Dances` | Song | By | Length | Pick 1 for | Pick 2 for |
|---|---|---|---|---|---|
| CrabRave | Noisestorm - Crab Rave | @Monstercat | 2:41 | Floss, Crazy Feet, Sprinkler, Crab Dance | Shock Shuffle, Robot, Running Man, Bounce Bounce |
| Shiawase | Dion Timmer - Shiawase | @Monstercat | 3:37 | Citrus Groove, Phone Call, Bounce Bounce | Floss, Crab Dance, Zany Zig |
| Moshi | Pegboard Nerds & Tokyo Machine - Moshi | @Monstercat | 3:34 | Shock Shuffle, Pop Lock, Robot | Sprinkler |
| Ascension | Vintage & Morelli - Ascension | @Monstercat | 3:29 | Smooth Moves, Free Flow | - |
| HypeHorns | Hype Horns | @APMOfficial | 2:29 | Hype Up | Classic Groove, Aerobics, Boogie Blast, Power Moves, Showstopper |
| StayUpbeat | Stay Upbeat B | @APMOfficial | 2:39 | Running Man, Aerobics | Phone Call |
| BigDeal | Big Deal | @APMOfficial | 2:06 | Classic Groove, Boogie Down, Boogie Blast | Citrus Groove |
| Downtown | Downtown | @APMOfficial | 1:00 | - | Boogie Down, Smooth Moves, So Fresh, Pop Lock, Clean Groove |
| SwingWithMe | Swing With Me (Electro Swing Mix) | @APMOfficial | 2:43 | Swing Time, Flapper | - |
| Akim | Akim | @APMOfficial | 3:01 | Breakdown, Freestyle, Toprock, Power Moves | - |
| Jumpstyle | Jumpstyle | @APMOfficial | 1:52 | - | Crazy Feet, Squat Kick |
| Kalinka | Kalinka A | @APMOfficial | 2:03 | Squat Kick | - |
| BoogieWoogie | Boogie Woogie | @APMOfficial | 1:38 | The Twist | - |
| BoogieManBoogie | Boogie Man Boogie | @APMOfficial | 1:38 | - | The Twist |
| Speakeasy | The Speakeasy | @APMOfficial | 2:12 | - | Flapper |
| CharlestonDolly | Charleston Dolly | @APMOfficial | 2:14 | Showstopper | Swing Time |
| HalloweenFunk | Halloween Funk | @APMOfficial | 2:05 | Zombie Groove | - |
| TrickOrTreat | Trick or Treat | @APMOfficial | 2:00 | - | Zombie Groove |
| PunchingTheAir | Punching The Air | @APMOfficial | 2:12 | Head Banger | - |
| SkullCrusher | Skull Crusher | @APMOfficial | 2:15 | - | Head Banger |
| DoItYourSelf | Do It Your Self | @APMOfficial | 2:16 | Zany Zig | - |
| ShakeSomethin | Shake Somethin' | @APMOfficial | 2:40 | So Fresh, Clean Groove | Hype Up, Breakdown, Free Flow, Freestyle, Toprock |

## Looked at and not picked

- Anything by an uploader other than @APMOfficial / @Monstercat / Roblox, even when titled "[Monstercat]": e.g.
  "Tokyo Machine - COOKIES [Monstercat]" (1539123469, uploaded by @zarkova, not for sale) and "[FULL] Tokyo Machine -
  EPIC" (2499459824, @crunch_bite). Fan uploads can be taken down and aren't licensed.
- "Russian Dance" (12240506410, @NoNoElevator): a community upload.
- 30-second cuts (they'd play their ending every 30 s): Funky Disco Beats 30 Second (9038367801), Big Deal 30
  (1839902280), Uptempo Swing b 30 (1841682103), 60's Fun (30s) (1838594262), Halloween (1835767261, 0:32).
- Electro Funk (1839088712): only 1:00, and its page mixes in another track's description.
- Stadium Rock A (1845804193): "hybrid rock and metal aggression", too harsh for kids.
- Zombie Clown Attack (1842688391): orchestral hybrid; its page's description belongs to another track.
- Pixel Terror & EMELINE - Chroma (Monstercat): has vocals we can't check.

## Honest gaps

- **Not heard by us.** Cloud sessions can't play Roblox audio. Descriptions come from the store pages (via search).
  The owner listens with `tools/studio/try-dance-songs.lua` (docs/STUDIO-STEPS.md Part 7) and says which to swap.
- **Most to check by ear:** Kalinka A (it starts slow: the dance may need `Start` set past the slow part), The
  Speakeasy (genre "Kitsch", no description we could trust), Skull Crusher (may be too heavy: it's only pick 2), Do It
  Your Self (quirky jazz: may be too calm for Zany Zig; pick 2 Shiawase is the safe swap), Shake Somethin' (tempo
  unknown).
- **Loudness:** Monstercat songs are usually much louder than APM ones; nothing evens them out yet.
- **`Start` is 0 for every song** (where the song starts when you dance): set it once someone has listened.
- Tempos with strength under 0.4 are hints only (see "How the fit was judged").

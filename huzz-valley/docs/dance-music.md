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

Oct 22: the owner's own 33 R6 dances replaced the old ones ("input these dances i found and remove the old ones").
Each keeps a song from the same licensed list below, matched by the dance's feel and name; the tempos of his
dances are not measured yet (the old table measured each one).

| Dance | His dance it comes from | Pick 1 (plays) | Pick 2 (backup) | Why it fits |
|---|---|---|---|---|
| Orange Swing | his "Orange Justice" (R6) | Crab Rave, Noisestorm (Monstercat), `5410086218`, [store](https://create.roblox.com/store/asset/5410086218/Noisestorm-Crab-Rave) | Shiawase, Dion Timmer (Monstercat), `5409360995`, [store](https://create.roblox.com/store/asset/5409360995/Dion-Timmer-Shiawase) | electro house, the meme-dance anthem, for "Swing your arms and step side to side!" (picked by feel; tempo not measured yet) |
| Boogie Down | his "Boogie Down" (R6) | Big Deal, APM Music (Conroy, Sounds Funky - Pop Brass Background), `9039954904`, [store](https://create.roblox.com/store/asset/9039954904/Big-Deal) | Boogie Man Boogie, APM Music (Kenny Graham, 50S AND 60S VINYL CLASSICS), `1841081879`, [store](https://create.roblox.com/store/asset/1841081879) | funky pop brass groove, 2:06, for "Get down and boogie all night!" (picked by feel; tempo not measured yet) |
| L Bounce | his "Take the L" (R6) | Moshi, Pegboard Nerds & Tokyo Machine (Monstercat), `7024340270`, [store](https://create.roblox.com/store/asset/7024340270/Pegboard-Nerds-Tokyo-Machine-Moshi) | Crab Rave, Noisestorm (Monstercat), `5410086218`, [store](https://create.roblox.com/store/asset/5410086218/Noisestorm-Crab-Rave) | video-game electro, for "Bounce and show them who's winning." (picked by feel; tempo not measured yet) |
| Squat Kicks | his "Kazotsky Kick" (R6) | Kalinka A, APM Music (Igor Tuhmanov, Authentic Russia), `1845855354`, [store](https://create.roblox.com/store/asset/1845855354/Kalinka) | Jumpstyle, APM Music, `1839246711`, [store](https://create.roblox.com/store/asset/1839246711/Jumpstyle) | Russian folk dance, 2:03 (starts slow, then speeds up), for "Squat down low and kick it out!" (picked by feel; tempo not measured yet) |
| High Roller | his "Gambler Dance" (R6) | Swing With Me (Electro Swing Mix), APM Music (Themes International), `1838645022`, [store](https://create.roblox.com/store/asset/1838645022) | The Speakeasy, APM Music, `1836714741`, [store](https://create.roblox.com/store/asset/1836714741) | electro swing, for "Smooth moves for a lucky winner." (picked by feel; tempo not measured yet) |
| Office Party | his "Company Dance" (R6) | Stay Upbeat B, APM Music (Sonoton, THE NEW 80s), `9044014229`, [store](https://create.roblox.com/store/asset/9044014229/Stay-Upbeat-B) | Big Deal, APM Music (Conroy, Sounds Funky - Pop Brass Background), `9039954904`, [store](https://create.roblox.com/store/asset/9039954904/Big-Deal) | uptempo 80s radio pop, 126 BPM, for "The whole team dances together!" (picked by feel; tempo not measured yet) |
| Parrot Wiggle | his "Parrot Wiggle" (R6) | Shiawase, Dion Timmer (Monstercat), `5409360995`, [store](https://create.roblox.com/store/asset/5409360995/Dion-Timmer-Shiawase) | Crab Rave, Noisestorm (Monstercat), `5410086218`, [store](https://create.roblox.com/store/asset/5410086218/Noisestorm-Crab-Rave) | kawaii future bass, 150 BPM, for "Wiggle like a happy parrot." (picked by feel; tempo not measured yet) |
| Kitty Paws | his "Neko Dance" (R6) | Shiawase, Dion Timmer (Monstercat), `5409360995`, [store](https://create.roblox.com/store/asset/5409360995/Dion-Timmer-Shiawase) | Moshi, Pegboard Nerds & Tokyo Machine (Monstercat), `7024340270`, [store](https://create.roblox.com/store/asset/7024340270/Pegboard-Nerds-Tokyo-Machine-Moshi) | kawaii future bass, 150 BPM, for "Cute paws, quick beats. Meow!" (picked by feel; tempo not measured yet) |
| Candy Hop | his "Candy Dance" (R6) | Shiawase, Dion Timmer (Monstercat), `5409360995`, [store](https://create.roblox.com/store/asset/5409360995/Dion-Timmer-Shiawase) | Stay Upbeat B, APM Music (Sonoton, THE NEW 80s), `9044014229`, [store](https://create.roblox.com/store/asset/9044014229/Stay-Upbeat-B) | kawaii future bass, 150 BPM, for "A sweet little hop to the beat." (picked by feel; tempo not measured yet) |
| Beatbox | his "Beatbox" (R6) | Akim, APM Music (Justement Music), `1843270078`, [store](https://create.roblox.com/store/asset/1843270078) | Shake Somethin', APM Music (Drew Milligan, HIP HOP BEDS), `1841134586`, [store](https://create.roblox.com/store/asset/1841134586) | breakbeat, for "Drop the beat right where you stand." (picked by feel; tempo not measured yet) |
| Surf's Up | his "Surfer" (R6) | Stay Upbeat B, APM Music (Sonoton, THE NEW 80s), `9044014229`, [store](https://create.roblox.com/store/asset/9044014229/Stay-Upbeat-B) | Hype Horns, APM Music (Juice Music, NON STOP POP 2), `1840007010`, [store](https://create.roblox.com/store/asset/1840007010) | uptempo 80s radio pop, 126 BPM, for "Ride the wave all the way in." (picked by feel; tempo not measured yet) |
| Electro Shuffle | his "Electro Shuffle" (R6) | Moshi, Pegboard Nerds & Tokyo Machine (Monstercat), `7024340270`, [store](https://create.roblox.com/store/asset/7024340270/Pegboard-Nerds-Tokyo-Machine-Moshi) | Crab Rave, Noisestorm (Monstercat), `5410086218`, [store](https://create.roblox.com/store/asset/5410086218/Noisestorm-Crab-Rave) | video-game electro, for "Quick feet that zap across the floor." (picked by feel; tempo not measured yet) |
| Jump Style | his "Jumpstyle" (R6) | Jumpstyle, APM Music, `1839246711`, [store](https://create.roblox.com/store/asset/1839246711/Jumpstyle) | Moshi, Pegboard Nerds & Tokyo Machine (Monstercat), `7024340270`, [store](https://create.roblox.com/store/asset/7024340270/Pegboard-Nerds-Tokyo-Machine-Moshi) | jumpstyle techno (kicks on every beat), for "Kick and jump on every beat!" (picked by feel; tempo not measured yet) |
| Quick Shuffle | his "Shuffle" (R6) | Crab Rave, Noisestorm (Monstercat), `5410086218`, [store](https://create.roblox.com/store/asset/5410086218/Noisestorm-Crab-Rave) | Moshi, Pegboard Nerds & Tokyo Machine (Monstercat), `7024340270`, [store](https://create.roblox.com/store/asset/7024340270/Pegboard-Nerds-Tokyo-Machine-Moshi) | electro house, the meme-dance anthem, for "Shuffle fast and never stop." (picked by feel; tempo not measured yet) |
| Chill Groove | his "Idle Dance" (R6) | Downtown, APM Music (HIP-HOP FUNK & GROOVE), `1843479959`, [store](https://create.roblox.com/store/asset/1843479959/Downtown) | Ascension, Vintage & Morelli (Monstercat), `7029070008`, [store](https://create.roblox.com/store/asset/7029070008) | hip-hop funk groove, for "Nice and easy, just vibing." (picked by feel; tempo not measured yet) |
| Snappy Skip | his "Snappy Skipping" (R6) | Stay Upbeat B, APM Music (Sonoton, THE NEW 80s), `9044014229`, [store](https://create.roblox.com/store/asset/9044014229/Stay-Upbeat-B) | Boogie Woogie, APM Music (Juice Music, GUITAR USA 2), `1839965449`, [store](https://create.roblox.com/store/asset/1839965449) | uptempo 80s radio pop, 126 BPM, for "Skip along with a snap!" (picked by feel; tempo not measured yet) |
| Cat Dance | his "CatDance" (R6) | Shiawase, Dion Timmer (Monstercat), `5409360995`, [store](https://create.roblox.com/store/asset/5409360995/Dion-Timmer-Shiawase) | Do It Your Self, APM Music (KPM Main Series, Quirky And Curious), `1840412669`, [store](https://create.roblox.com/store/asset/1840412669) | kawaii future bass, 150 BPM, for "Purr-fect moves for cool cats." (picked by feel; tempo not measured yet) |
| Wavy Grooves | his "Wavy Grooves" (R6) | Ascension, Vintage & Morelli (Monstercat), `7029070008`, [store](https://create.roblox.com/store/asset/7029070008) | Downtown, APM Music (HIP-HOP FUNK & GROOVE), `1843479959`, [store](https://create.roblox.com/store/asset/1843479959/Downtown) | smooth progressive house, for "Smooth waves from head to toe." (picked by feel; tempo not measured yet) |
| Step It Up | his "Marat" (R6) | Hype Horns, APM Music (Juice Music, NON STOP POP 2), `1840007010`, [store](https://create.roblox.com/store/asset/1840007010) | Shake Somethin', APM Music (Drew Milligan, HIP HOP BEDS), `1841134586`, [store](https://create.roblox.com/store/asset/1841134586) | sassy funky horns and slick synth beats, for "Big steps, big energy!" (picked by feel; tempo not measured yet) |
| Supreme Groove | his "E Dance Surpeme" (R6) | Shake Somethin', APM Music (Drew Milligan, HIP HOP BEDS), `1841134586`, [store](https://create.roblox.com/store/asset/1841134586) | Downtown, APM Music (HIP-HOP FUNK & GROOVE), `1843479959`, [store](https://create.roblox.com/store/asset/1843479959/Downtown) | hip-hop beat, 2:40, for "The groove that tops them all." (picked by feel; tempo not measured yet) |
| Pop Star | his "BTS Dance" (R6) | Stay Upbeat B, APM Music (Sonoton, THE NEW 80s), `9044014229`, [store](https://create.roblox.com/store/asset/9044014229/Stay-Upbeat-B) | Shiawase, Dion Timmer (Monstercat), `5409360995`, [store](https://create.roblox.com/store/asset/5409360995/Dion-Timmer-Shiawase) | uptempo 80s radio pop, 126 BPM, for "Shine like a pop star on stage." (picked by feel; tempo not measured yet) |
| Breakdance | his "Breakdance" (R6) | Akim, APM Music (Justement Music), `1843270078`, [store](https://create.roblox.com/store/asset/1843270078) | Shake Somethin', APM Music (Drew Milligan, HIP HOP BEDS), `1841134586`, [store](https://create.roblox.com/store/asset/1841134586) | breakbeat, for "Spin and flip like a b-boy!" (picked by feel; tempo not measured yet) |
| Superstar | his "The Star Emote" (R6) | Hype Horns, APM Music (Juice Music, NON STOP POP 2), `1840007010`, [store](https://create.roblox.com/store/asset/1840007010) | Charleston Dolly, APM Music (Edward Koebelin), `1844694201`, [store](https://create.roblox.com/store/asset/1844694201) | sassy funky horns and slick synth beats, for "All eyes on you. Steal the show!" (picked by feel; tempo not measured yet) |
| Blossom Break | his "Blossom Break" (R6) | Ascension, Vintage & Morelli (Monstercat), `7029070008`, [store](https://create.roblox.com/store/asset/7029070008) | Shiawase, Dion Timmer (Monstercat), `5409360995`, [store](https://create.roblox.com/store/asset/5409360995/Dion-Timmer-Shiawase) | smooth progressive house, for "A long, beautiful dance in bloom." (picked by feel; tempo not measured yet) |
| Wibbly Wobbly | his "Wibbly Wobbly" (R6) | Do It Your Self, APM Music (KPM Main Series, Quirky And Curious), `1840412669`, [store](https://create.roblox.com/store/asset/1840412669) | Shiawase, Dion Timmer (Monstercat), `5409360995`, [store](https://create.roblox.com/store/asset/5409360995/Dion-Timmer-Shiawase) | quirky jazz, 2:16, for "Wobble around like jelly!" (picked by feel; tempo not measured yet) |
| Untouchable | his "The Honored One" (R6) | Moshi, Pegboard Nerds & Tokyo Machine (Monstercat), `7024340270`, [store](https://create.roblox.com/store/asset/7024340270/Pegboard-Nerds-Tokyo-Machine-Moshi) | Crab Rave, Noisestorm (Monstercat), `5410086218`, [store](https://create.roblox.com/store/asset/5410086218/Noisestorm-Crab-Rave) | video-game electro, for "Too cool to catch. Nobody can touch you." (picked by feel; tempo not measured yet) |
| Let's Go | his "DaBaby Dance" (R6) | Shake Somethin', APM Music (Drew Milligan, HIP HOP BEDS), `1841134586`, [store](https://create.roblox.com/store/asset/1841134586) | Hype Horns, APM Music (Juice Music, NON STOP POP 2), `1840007010`, [store](https://create.roblox.com/store/asset/1840007010) | hip-hop beat, 2:40, for "Hype yourself up. Let's go!" (picked by feel; tempo not measured yet) |
| Lose Control | his "Lose it" (R6) | Punching The Air, APM Music (David Hearn, AMERICAN ROAD TRIP), `1836723913`, [store](https://create.roblox.com/store/asset/1836723913) | Skull Crusher, APM Music (Anthony Cossa, ROCK ATTACK), `1838319914`, [store](https://create.roblox.com/store/asset/1838319914) | rock, 2:12, for "Go wild and let the beat take over." (picked by feel; tempo not measured yet) |
| Bone Groove | his "Skeleton Grooves" (R6) | Halloween Funk, APM Music (KIDS CLUB), `1841274055`, [store](https://create.roblox.com/store/asset/1841274055/Halloween-Funk) | Trick or Treat, APM Music (The Box, HALLOWEEN THEMES), `1837467234`, [store](https://create.roblox.com/store/asset/1837467234/Trick-or-Treat) | kids' pop Halloween funk, 2:05, for "Rattle your bones to the beat." (picked by feel; tempo not measured yet) |
| Skeleton Shake | his "Skeleton" (R6) | Trick or Treat, APM Music (The Box, HALLOWEEN THEMES), `1837467234`, [store](https://create.roblox.com/store/asset/1837467234/Trick-or-Treat) | Halloween Funk, APM Music (KIDS CLUB), `1841274055`, [store](https://create.roblox.com/store/asset/1841274055/Halloween-Funk) | mischievous intro into a Halloween hip-hop beat, 2:00, for "Shake it like a spooky skeleton!" (picked by feel; tempo not measured yet) |
| Zombie Walk | his "Zombie Dance" (R6) | Halloween Funk, APM Music (KIDS CLUB), `1841274055`, [store](https://create.roblox.com/store/asset/1841274055/Halloween-Funk) | Trick or Treat, APM Music (The Box, HALLOWEEN THEMES), `1837467234`, [store](https://create.roblox.com/store/asset/1837467234/Trick-or-Treat) | kids' pop Halloween funk, 2:05, for "Rise from the grave and dance!" (picked by feel; tempo not measured yet) |
| Moongazer | his "Moongazer" (R6) | Ascension, Vintage & Morelli (Monstercat), `7029070008`, [store](https://create.roblox.com/store/asset/7029070008) | Downtown, APM Music (HIP-HOP FUNK & GROOVE), `1843479959`, [store](https://create.roblox.com/store/asset/1843479959/Downtown) | smooth progressive house, for "Dance under the moonlight." (picked by feel; tempo not measured yet) |
| Flex Time | his "Flexer" (R6) | Punching The Air, APM Music (David Hearn, AMERICAN ROAD TRIP), `1836723913`, [store](https://create.roblox.com/store/asset/1836723913) | Hype Horns, APM Music (Juice Music, NON STOP POP 2), `1840007010`, [store](https://create.roblox.com/store/asset/1840007010) | rock, 2:12, for "Show off every muscle you've got!" (picked by feel; tempo not measured yet) |

## His own songs (Oct 22)

The owner sent his own songs (16:00, then 16:17: "use these and match up the songs to the dances, and also make the
balenci balenci balenci song match to the dance you are making that is called balenci, and then the karamel dancen one
to the caramel dance"). They are pick 1 now; the library song that was pick 1 moved to pick 2 and plays until he
uploads his file (Id ""). Three library songs no dance used any more were dropped (Skull Crusher, Charleston Dolly,
The Speakeasy).

- **Which song is which:** his files are named by time only. The Balenci song is the one whose sound matches the music
  under his Balenci video (by far the closest of the eight). Caramelldansen goes on Sweet Dancin: its hands-up bounce
  is the Caramelldansen dance, and two of the song's beats are one loop (0.75 s). The other six by tempo.
- **On the beat:** each song's tempo is measured (tools/sfx/song_loops.py) and the file to upload is cut from its first
  beat to 1, 2, 4 or 8 bars, so it loops on the beat. Each dance's loop is stretched (at most 4.5%) to a whole number
  of its song's beats (tools/anim/extract_anims.luau ON_BEAT), so the steps stay on the music however long you dance.
- **Copyright:** some of these are commercial songs (Caramelldansen is). Roblox checks uploads and can reject or mute
  copyrighted audio; the library pick 2 keeps playing if that happens.
- Files to upload: project files `owner-audio-oct22/loops/<song>.ogg` (never the public repo).

| Dance | His song (pick 1) | Tempo | Beats a loop | Pick 2 (library) |
|---|---|---|---|---|
| Balenci | Balenci (17-47-31) | 119 | 6 | Downtown |
| Sweet Dancin | Caramelldansen (17-46-05) | 159.9 | 2 | Big Deal |
| Tekk Pump | Hardtekk 1 (18-08-42) | 150.9 | 16 | Jumpstyle |
| Hakken Stomp | Hardtekk 2 (18-09-22) | 199.75 | 16 | Jumpstyle |
| Jumpstyle Rave | Hardtekk 3 (18-10-52) | 179.75 | 16 | Jumpstyle |
| Candy Hop, Parrot Wiggle | Rush 180 B (17-44-03) | 179.75 | 2, 12 | Shiawase |
| Electro Shuffle, Flex Time | Rush 180 A (17-44-43) | 179.75 | 24, 48 | Moshi, Punching The Air |
| Wavy Grooves, Breakdance, Superstar, Step It Up | Bounce 98 (17-45-12) | 98.45 | 12, 8, 12, 6 | their old pick 1 |
| Lose Control, High Roller, Wibbly Wobbly, Chill Groove | Groove 107 (17-47-00) | 107.15 | 32, 16, 32, 2 | their old pick 1 |
| Let's Go, Cat Dance, Pop Star, Moongazer | Hype 125 (17-48-03) | 125.65 | 16, 12, 16, 24 | their old pick 1 |
| Supreme Groove, Jump Style, Surf's Up | Tick 138 (17-48-42) | 138.05 | 16, 12, 12 | their old pick 1 |

Still on library songs (waiting for his next batch): Orange Swing, Boogie Down, L Bounce, Squat Kicks (Kalinka, the
Russian folk dance, on purpose), Office Party, Kitty Paws, Beatbox, Quick Shuffle, Snappy Skip, Blossom Break,
Untouchable, and the Halloween three (Bone Groove, Skeleton Shake, Zombie Walk keep their spooky songs).

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

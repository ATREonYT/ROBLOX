# Sound picks: button clicks, the Secret cutscene, the dances (Oct 19)

The owner, word for word: "please find good sounds that fit the secret animation, that fit the clicking better, also
find the sounds we can use for all of the dances, but don't create random sound by yourself, do a research of what
sounds good and not, and then logically select the best sounds/songs possible for the game."

So these three jobs use **real, licensed sounds**. Nothing here is synthesized by `tools/sfx/make_sfx.py` any more
(it now skips `ui_click/hover/open/close` and `secret_*`). Every ID below was seen on the public page in its row. None
was made up. Cloud sessions can't reach Roblox, so **none was played or checked by us**: the owner confirms them with
`tools/studio/check-sound-picks.lua` (see "How the owner checks").

## 1. Where sounds may come from (licence)

| Route | What | Safe because | Upload? |
|---|---|---|---|
| **1. Roblox's licensed library** (first choice) | Tracks and effects uploaded by Roblox's partner accounts: **@Monstercat**, **@APMOfficial** (APM Music), **@ProSoundEffects** (titles end in "(SFX)") | Roblox licensed them for free use in any Roblox experience and keeps them public. When audio went private in 2022, Roblox said its "official licensed catalog of Music and SFX will remain Public and usable by developers in any of their experiences" (DevForum, [Upcoming Changes to Asset Privacy for Audio](https://devforum.roblox.com/t/1701697)); Monstercat's deal started in 2020 with tracks "available for Roblox developers to use for free in their games" ([Roblox press release](https://www.businesswire.com/news/home/20200728005353/en)) | No: use the ID |
| **2. CC0 packs** (second choice) | Kenney, freesound CC0, OpenGameArt CC0 | CC0 = public domain, commercial games allowed, no credit needed | Yes, by the owner (they become his private assets) |
| Never | Copyrighted pop songs, other games' sounds ("Minecraft UI Click" and the like), random community uploads of unknown origin | Not ours to use; can be taken down and mute the game | - |

How to tell the real partner uploads: the store page says **By @Monstercat**, **By @APMOfficial** or **By @ProSoundEffects**
("Sound effect courtesy of Pro Sound Effects"). Look-alikes exist: e.g. "Tokyo Machine - COOKIES [Monstercat]" (1539123469)
is a fan upload by @zarkova, not Monstercat's, so it was not picked.

**Audio privacy, in plain words** (DevForum [privacy change](https://devforum.roblox.com/t/1701697),
[permissions for audio](https://devforum.roblox.com/t/new-asset-privacy-and-permissions-features-for-audio-and-video/2725248),
[sharing with groups](https://devforum.roblox.com/t/asset-privacy-and-permissions-share-audio-and-video-with-groups/3269446)):
- Roblox's licensed library is public: it plays in Studio and in the live game with nothing to do.
- Audio the owner uploads is private by default: it plays only in experiences he owns. If the game is (or moves to)
  a **group**, upload the files to the group (Asset Manager in the group game) or share them with the group, or they
  stay silent there.
- Anything else private (someone else's upload) won't play in our game at all. That's why we never pick random uploads.

## 2. Button clicks (`ui_click`, `ui_hover`, `ui_open`, `ui_close`)

**What makes a UI sound feel premium (research):**
- **Short.** Taps and clicks 30-150 ms, most UI cues under 300 ms
  ([Violet Recording, How to design UI sounds](https://violetrecording.com/how-to-design-ui-sounds/)).
- **Soft front, no harsh peaks.** "Clean sound with minimal noise, controlled low end, no harsh peaks that fatigue the
  ear over hundreds of uses" (same guide). On phone and laptop speakers the tiring part is the hiss above ~4 kHz, so we
  measured it.
- **One family.** Sounds in one product should share "the same reverb, similar tone, a shared voice" (same guide);
  sounds that follow each other should have related timbre and envelope
  ([Material Design, sound choreography](https://m2.material.io/design/sound/sound-choreography.html)).
- **Meaning by direction.** Rising pitch reads as positive (open), falling as going away (close)
  ([IRPR, What is UI sound design](https://sounddesign.irpr.agency/guides/what-is-ui-sound-design/)).
- **Restraint.** The most common mistake is "generic, harsh or repetitive sounds that users mute"
  ([skills.sh UI sound design notes](https://www.skills.sh/jeremielim/skills/ui-sound-design)); hover must be barely there.
- Popular Roblox simulators use exactly this: a short soft "pop" for presses, a quieter tick for hover, a short swoosh
  up/down for windows.

**What we found in Roblox's library:** the licensed UI effects are mostly *many takes in one file* (e.g. "Push Buttons 6
(SFX)", 5.3 s of button pushes, [9117981543](https://create.roblox.com/store/asset/9117981543/Push-Buttons-6-SFX);
"Tonal Click, Blurp Tone ... Many Variations", 1.3 s, [9126109935](https://create.roblox.com/store/asset/9126109935/Tonal-Click-Blurp-Tone-Slightly-Metallic-Swi-SFX))
or bright synth beeps ("High Pitch Bell Tone", "High Pitch Synth Blip"). Playing a many-takes file plays all the takes,
and the owner already rejected "random high pitch sounds". Roblox's built-in `button.wav` is the stand-in he called
"glitchy". So the click family comes from route 2.

**Pick: Kenney "Interface Sounds" (CC0, 100 single-hit files, normalised)**: [OpenGameArt](https://opengameart.org/content/interface-sounds),
mirror [github.com/Calinou/kenney-interface-sounds](https://github.com/Calinou/kenney-interface-sounds) (licence: "Creative
Commons Zero, CC0 ... free to use in personal, educational and commercial projects"). We measured all 79 candidate files
with `tools/sfx/measure_sfx.py` and kept the ones that are short, soft-fronted, mid-pitched and have no hiss:

| Slot | Kenney file | Length | Attack | Brightness (centroid) | Energy above 4 kHz | Why |
|---|---|---|---|---|---|---|
| `ui_click` | `drop_002` | 83 ms | 2.0 ms | 817 Hz | 0.0% | a short round "bloop" (pitch lifts 770 to 1000 Hz): soft front, nothing hissy |
| `ui_hover` | `select_002` | 45 ms | 2.1 ms | 1164 Hz | 1.9% | a tiny tick in the same voice, played at a third of the click's level |
| `ui_open` | `maximize_009` | 205 ms | 22 ms | 1370 Hz | 0.0% | a soft swell rising 1100 to 1770 Hz (positive) |
| `ui_close` | `minimize_009` | 206 ms | 119 ms | 1368 Hz | 0.0% | the same swell falling 1800 to 1070 Hz (its mirror) |

Rejected, with numbers: Kenney's own `open_00x`/`close_00x` (centroid 7-12 kHz, 63-97% hiss: harsh); `click_004`
(76% above 4 kHz); `click_002/003/005` (10-14 ms, 0.4-1.7 ms attack: a dry tick that reads as a glitch);
`maximize_001-005` (25-79% hiss); `tick_00x` (49-66% hiss). Our old synthesized "tock" is retired by the owner's rule.

Files: `assets/sfx/ui_click.ogg` etc. (converted to mono OGG, sound unchanged), licence `assets/sfx/LICENSE-kenney.txt`.
Listen: `docs/previews/ui-sounds-oct19.ogg` (click x3, hover x2, open, close, at in-game levels). In-game levels
(`Gameplay/Sfx` LEVEL): click 0.28, hover 0.10, open 0.15, close 0.13 (Kenney files peak 2 dB hotter than ours, and
open/close are ~6 dB louder on average than the click, so they sit lower). **The IDs stay "" until the owner uploads
the 4 files**; until then Roblox's `button.wav` stands in (pitch 0.9, quiet).

## 3. The Secret cutscene

**What fits (research):** a reveal works as *tension, release, glow*: a rising build that stops exactly on the hit, a
hit with weight but no harsh crack, then something musical and sparkly while the camera holds on her. Material
Design calls these rare "hero sounds", the most prominent in a product, kept for pivotal moments
([Material, applying sound to UI](https://m2.material.io/design/sound/applying-sound-to-ui.html)). Kid-safe: no
jump-scare sting, no scream, no horror drone (Roblox's library has "Horrific Scream", "Eerie Ambience": avoided), even
loudness, nothing louder than the hit.

**Beats, not seconds.** The cutscene is being re-cut shorter (about 8-11 s, `docs/secret-beats.md`), so every sound is
keyed to a named beat in `Config/SecretSounds` and fitted to any length:

| Beat | When (in the shot) | Sounds that start | Sounds that fade |
|---|---|---|---|
| **Build** | the orb appears, night falls | riser, magic bed | - |
| **Burst** | the big impact, she appears | hit; sparkle tail 0.15 s later | riser (0.12 s: cut right under the hit) |
| **Reveal** | she has landed and holds her pose | the fantasy sting | - |
| **End** | the camera hands back | nothing | bed (1.2 s), sparkle tail (1.0 s), sting (2.0 s) |

`Gameplay/SecretReveal` calls `Sfx.beat("Build" | "Burst" | "Reveal" | "End")`. In today's 14.5 s cut that is
Build 0.3 s (orb), Burst 2.75 s (impact), Reveal 3.15 s (landing), End at the hand-back; the second impact at 12.25 s
still plays the hit alone. A riser that's longer than the build is simply cut under the burst, so it always "lands".

| Slot | Sound | ID | Source | Why | Licence |
|---|---|---|---|---|---|
| `secret_riser` (Build) | "Light Cone Suck, Synth and Reverse Cymbal Build, Disappear" (5.7 s, Energy) | `rbxassetid://9125626784` | [store page](https://create.roblox.com/store/asset/9125626784/Light-Cone-Suck-Synth-And-Reverse-Cymbal-Bui-SFX) | a reverse-cymbal build is the classic riser into a hit; synth, not scary | Pro Sound Effects via Roblox |
| `secret_shimmer` (Build) | "Sparkle Tone, Constant High End Shimmer, Sparkle, Glistening" (18 s) | `rbxassetid://9125986205` | [store page](https://create.roblox.com/store/asset/9125986205/Sparkle-Tone-Constant-High-End-Shimmer-Spark-SFX) | a steady glistening bed under the night, longer than any cut, so it never runs out; kept low (0.18) because it's bright | Pro Sound Effects via Roblox |
| `secret_impact` (Burst) | "Magic Burst 2" (1.8 s, Stings: a magic hit with weight) | `rbxassetid://9116384799` | [store page](https://create.roblox.com/store/asset/9116384799/Magic-Burst-2-SFX) | magic, not an explosion or gunshot; short, so it doesn't mask the sting | Pro Sound Effects via Roblox |
| `secret_sparkle` (Burst) | "Magic Insect Flying, Pixie Dust Twinkles 4" (8.6 s: twinkles with soft wing flutter) | `rbxassetid://9116397511` | [store page](https://create.roblox.com/store/asset/9116397511/Magic-Insect-Flying-Pixie-Dust-Twinkles-4-SFX) | the glittering tail after the hit; its flutter matches the cutscene's butterflies | Pro Sound Effects via Roblox |
| `secret_sting` (Reveal) | "Through the Looking Glass (sting)" (8 s, Juice Music FANTASIA: glockenspiel melody over orchestra) | `rbxassetid://1840018171` | [store page](https://create.roblox.com/store/asset/1840018171/Through-the-Looking-Glass-sting) | "exhilarating fantasy sting": a magical musical "ta-da" for a Secret girl; music, so it ends the cutscene on a melody instead of noise | APM Music via Roblox |

Considered and not picked: "Through the Looking Glass" won over "Mr Pumpkin Head (sting)" (9043603377, APM, "eerie":
spooky) and "Digital Underworld" (trailer choir, 139 s, sci-fi). "Spaceship Blast High Pitch Energy Charge Up" (1.9 s)
was too short and described as "ringy, piercing". "Synth Sparkle Tone High Pitch Bell Tone Burst" (1.4 s) was a candidate
for End, left out: "high pitch" is exactly what the owner disliked; End only fades.

Levels (first guesses, tune after hearing them): riser 0.45, bed 0.18, hit 0.55, tail 0.30, sting 0.50. The background
music is already faded out for the whole cutscene (`Music.quiet`). The descriptions come from the store listings; we
couldn't listen, so the owner's ear decides (swap any slot by changing its ID in `Config/SoundIds`).

## 4. The dances

**What fits (research and logic):**
- Each dance style has a home genre: meme and internet dances (Floss, Crab, Sprinkler, Running Man) live on electro
  house; b-boy moves (Toprock, Breakdown, Freestyle) on breakbeat; Swing and the Flapper (Charleston) on (electro) swing;
  Robot and Pop Lock on electro / video-game sounds; groove steps on funk; aerobics on 80s workout pop; a jump-kick
  dance on jumpstyle.
- Tempo. `tools/preview/motion3d/dance_tempo.luau` measured each dance's own beat from the animation (how its hands,
  feet, head and torso speed up and slow down over the loop). Where the dance repeats strongly the number is reliable:
  Floss ~112 BPM, Squat Kick ~150, Flapper ~160, Hype Up ~151, So Fresh ~95, Sprinkler ~146. Most others repeat
  weakly (strength under 0.3), so their numbers are hints only, and three (Aerobics, Breakdown, Clean Groove) barely
  move the probe's joints. The songs don't sync to the steps (Roblox can't stretch a song to an animation), so the
  match is about energy and feel, not exact beats.
- Upbeat, never harsh: no dubstep drops (Pixel Terror's "Enigma"/"Collapse", "Cobra" skipped), no lyrics we can't vet.
- Prefer the most recognisable kid-friendly track where one fits perfectly: **Crab Rave** for the Crab Dance.
- One song serves a family of similar dances, so the set stays small (11 songs for 25 dances) and each song is a
  clear "style".

**How it plays** (`Gameplay/Music.dance`, called by `UI/DancePlayer`): when your dance starts, its song starts for you
only, looped, fading in over 0.4 s at `Dances.MusicVolume` 0.22 (the background songs are 0.3), and the background dips
to 35% (`Dances.MusicDuck`) over ~0.4 s. When the dance stops (walking, another dance, respawn) the song fades out over
0.8 s and the background comes back. A dance whose track Id is "" dances in silence and doesn't dip anything. Background
Music OFF in Settings means no dance songs either. The Secret cutscene and the win song stop a dance song.
`Start` (seconds into the song) is 0 for every track: once someone listens in Studio, set it to the moment the beat
kicks in (long intros would otherwise fill a short dance).

| Track | ID | Source | Style | Dances | Why | Licence |
|---|---|---|---|---|---|---|
| Noisestorm - Crab Rave | `rbxassetid://5410086218` | [store page](https://create.roblox.com/store/asset/5410086218/Noisestorm-Crab-Rave) | electro house (Monstercat; a viral, kid-loved instrumental) | Crab Dance, Floss, Sprinkler, Running Man, Crazy Feet | the anthem of meme dances; Crab Dance + Crab Rave is the obvious match | Monstercat via Roblox |
| Dion Timmer - Shiawase | `rbxassetid://5409360995` | [store page](https://create.roblox.com/store/asset/5409360995/Dion-Timmer-Shiawase) | kawaii future bass, 150 BPM ([Beatport](https://www.beatport.com/track/-/10624798)) | Phone Call, Bounce Bounce | cute, bouncy, anime-flavoured: fits an anime-girls game; Phone Call hints at ~152 | Monstercat via Roblox |
| Pegboard Nerds & Tokyo Machine - Moshi | `rbxassetid://7024340270` | [store page](https://create.roblox.com/store/asset/7024340270/Pegboard-Nerds-Tokyo-Machine-Moshi) | electro with Tokyo Machine's video-game synths, 3:34 | Robot, Pop Lock, Shock Shuffle | robotic, zappy electro for the robotic and popping dances | Monstercat via Roblox |
| Vintage & Morelli - Ascension | `rbxassetid://7029070008` | [store page](https://create.roblox.com/store/asset/7029070008) | smooth progressive house | Smooth Moves, Free Flow | gliding, flowing steps get flowing, uplifting house | Monstercat via Roblox |
| Hype Horns | `rbxassetid://1840007010` | [store page](https://create.roblox.com/store/asset/1840007010) | "sassy and funky contemporary horns, percussion, and slick synth beats" (Juice Music, NON STOP POP 2, 2:29) | Hype Up | horns = hype; "pump up the crowd" | APM Music via Roblox |
| Stay Upbeat B | `rbxassetid://9044014229` | [store page](https://create.roblox.com/store/asset/9044014229/Stay-Upbeat-B) | uptempo 80s radio pop, 126 BPM (Sonoton, THE NEW 80s, 2:39) | Aerobics | 80s pop is the sound of aerobics | APM Music via Roblox |
| Funky People | `rbxassetid://1835417126` | [store page](https://create.roblox.com/store/asset/1835417126) | funky pop (Themes International, 97 s) | Classic Groove, Boogie Down, Citrus Groove | the old-school / disco-ish groove family | APM Music via Roblox |
| Downtown | `rbxassetid://1843479959` | [store page](https://create.roblox.com/store/asset/1843479959/Downtown) | hip-hop funk and groove (William Andrew Broad, 1:00) | So Fresh, Clean Groove | sharp, fresh hip-hop grooves (So Fresh measures ~95, a hip-hop tempo) | APM Music via Roblox |
| Swing With Me (Electro Swing Mix) | `rbxassetid://1838645022` | [store page](https://create.roblox.com/store/asset/1838645022) | electro swing (Themes International, 97 s) | Swing Time, Flapper | swing and Charleston moves on a modern swing beat | APM Music via Roblox |
| Akim | `rbxassetid://1843270078` | [store page](https://create.roblox.com/store/asset/1843270078) | breakbeat (Justement Music, 3:01) | Breakdown, Toprock, Freestyle | breaking was born on breakbeats | APM Music via Roblox |
| Jumpstyle | `rbxassetid://1839246711` | [store page](https://create.roblox.com/store/asset/1839246711/Jumpstyle) | jumpstyle techno (1:52, 96% liked) | Squat Kick | a kick on every beat for the kicking dance (it measures ~150, jumpstyle's tempo) | APM Music via Roblox |

Honest notes: tempos for Crab Rave and Moshi weren't on a page we could open (Crab Rave is commonly listed around
125 BPM); the APM listings for Funky People, Downtown, Akim and Jumpstyle give a genre but no description; Jumpstyle is
the hardest-hitting pick: if it's too much for kids, give Squat Kick `StayUpbeat` or `Shiawase` in `Config/Dances`.
The store pages showed "last updated October 2025" for the APM tracks we looked at (so still live), and the Monstercat
pages are the official account's.

## 5. How the owner checks (Studio)

1. Open the place in Studio. View > Command Bar. Paste all of `huzz-valley/tools/studio/check-sound-picks.lua`, Enter.
2. Output, for each pick: `[HuzzSfx] OK <slot> <id> <name> by <creator>` (Roblox knows it), then `PLAYS <slot> <n> s`
   (it loads, so it will play) or `WON'T PLAY` (private or removed). It plays each one for up to 4 s so you can judge
   it. Last line: `[HuzzSfx] Done: N play, N missing, N won't play`. Screenshot and send.
3. Button sounds: Asset Manager > Bulk Import `huzz-valley/assets/sfx/ui_click.ogg`, `ui_hover.ogg`, `ui_open.ogg`,
   `ui_close.ogg`; drag them into Workspace; Command Bar `require(game.ServerStorage.HuzzStudioTools.CollectSoundIds)()`;
   send the `[HuzzSfx]` lines (it keeps the picked Secret IDs as they are).
4. Then Play: open and close a window, hover, click; dance (G wheel); test the cutscene with
   `Config/Round.StudioTestRarity = "Secret"`.

## 6. Still open

- Nothing here has been heard by us: the store descriptions and our measurements are the evidence. The owner's ear
  is the final check; any slot is one ID to swap.
- `Start` offsets for the dance songs (skip long intros) need someone listening.
- Button sounds wait for the owner's upload (4 files).
- The new shorter cutscene: the coordinator aligns Build/Burst/Reveal/End to `docs/secret-beats.md` when merging.

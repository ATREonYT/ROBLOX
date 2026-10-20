# Sounds and music

Read before adding or changing any sound, the button sounds, dance music, background music or the audio settings.
Research, picks, sources and reasons for every licensed sound: `docs/sound-picks.md`. Recipe for a new made sound:
core `CLAUDE.md` section 6.

## Real, researched sounds for clicks, the Secret cutscene and the dances
- **Never synthesize these three again** (`make_sfx.py` skips them: `RETIRED`). Spec `tests/SoundPicks.spec` (every ID
  "" or rbxassetid with its store URL in the file and the doc, never invented).
- **Safe sources, in order:** (1) Roblox's licensed library: uploads by **@Monstercat**, **@APMOfficial**,
  **@ProSoundEffects** ("(SFX)" titles). Public, free in any experience, plays in Studio and live, nothing to upload.
  Check the uploader: look-alike fan uploads exist. (2) CC0 packs (Kenney, freesound CC0, OpenGameArt CC0): the owner
  uploads them, then they're private to him (a group game needs them uploaded to / shared with the group). Never pop
  songs, other games' sounds or random community uploads.
- Cloud sessions can't open roblox.com (WebFetch/curl blocked): find IDs with WebSearch limited to `create.roblox.com`
  (the result URLs carry the ID; ask it for the uploader and length, which it reads off the page); GitHub clones work
  for CC0 packs. The Oct 19 audit re-checked every ID this way: `docs/sound-picks.md` section 7.
- **Full-length songs only** for anything that loops (a 30 s library cut has an ending: "Funky People" 32 s was
  swapped for "Big Deal" 2:06), and no song for more than 4 dances.
- **Clicks:** Roblox's licensed UI files are many-takes-in-one or high beeps, so the family is Kenney's CC0 Interface
  Sounds picked by numbers (`tools/sfx/measure_sfx.py`: 30-150 ms, soft 2 ms front, centroid ~0.8-1.4 kHz, ~0% above
  4 kHz): click `drop_002`, hover `select_002`, open `maximize_009` (rises), close `minimize_009` (falls), in
  `assets/sfx/ui_*.ogg` + `LICENSE-kenney.txt`, made by `tools/sfx/import_kenney.py` (averages stereo to mono: a plain
  ffmpeg `-ac 1` mixes 3 dB hot, which made click and hover clip at +2 dBFS); listen `docs/previews/ui-sounds-oct19.ogg`.
  IDs "" until he uploads.
- **Secret cutscene:** keyed to beats, not seconds (`Config/SecretSounds`: Build 0.25 s = riser + glistening bed,
  Burst 3.42 s = magic hit + pixie-dust tail and the riser cut under it, Reveal 4.50 s (her name) = APM's 8 s fantasy
  sting, End = fades); `Gameplay/SecretReveal` calls `Sfx.beat(...)`, and `Sfx.beat("Build", time to the burst)` starts
  the riser partway in so its top (`Peak`, a 5.2 s guess) lands on the burst. Every sound with an ID is preloaded at
  start (a first play downloads first and starts late). Pro Sound Effects + APM IDs in `Config/SoundIds`. Beat times:
  `docs/secret-beats.md`.
- **Dances:** every one of the 32 dances has two picks, both with a real ID (`Config/Dances` `Music` = pick 1,
  `Backup` = pick 2, keys into `Tracks`; `Dances.track` plays pick 2 only when pick 1's Id is ""): 22 Monstercat/APM
  songs, each pick 1 for at most 4 dances, picked by the dance's style and its Fortnite emote's genre (Crab Rave for
  the meme dances, breakbeat for b-boy, Kalinka for the Cossack Squat Kick, rock 'n' roll for The Twist, rock for Head
  Banger, kids' Halloween funk for Zombie Groove, big band for Showstopper...). Table, reasons, rejected tracks and
  gaps: `docs/dance-music.md`. **Never Fortnite's own songs** (Epic's; a re-upload is still theirs). Dance tempos
  measured by `motion3d/dance_tempo.luau` (reliable only where it says strength > 0.4). The owner listens with
  `tools/studio/try-dance-songs.lua` (pick 1 then pick 2 per dance; `TRY` plays a Toolbox ID he found and prints a
  `[HuzzSfx] SEND` line for us; it can't change the game: Rojo would put files back), `docs/STUDIO-STEPS.md` Part 5. `Gameplay/Music.dance` plays it for you
  only, looped, at 0.22 (background 0.3) and dips the background to 15% (two songs at near the same level clash);
  `danceStop` fades it (DancePlayer calls both, also when the dance animation stops some other way). `Start` offsets
  are 0 until someone listens (set again once the song has downloaded).
- **Owner verifies:** paste `tools/studio/check-sound-picks.lua` in the Command Bar: `[HuzzSfx] OK/MISSING`,
  `NOT LICENSED?` (a pick not uploaded by Monstercat/APMOfficial/ProSoundEffects), `PLAYS/WON'T PLAY` per ID, each
  played for 4 s (dance songs from a quarter in), and his own songs in `Config/Music` checked. It can't judge the
  cutscene's timing: that needs Play with `Config/Round.StudioTestRarity = "Secret"`. Levels are first guesses.

## Button sounds
- One press = one sound. Kit buttons sound on `MouseButton1Down` (only the button on top gets it; `InputBegan` could
  also reach buttons behind an open window, so one click could sound 2-3 times a little out of step), touch on
  `Activated`; `Sfx` skips the same ui_* sound within `UI_GAP` (0.08 s for clicks), replays preloaded copies (never a
  cut-off), no pitch wobble, through the Interface group. Until he uploads the Kenney files Roblox's button.wav stands
  in at pitch 0.9, quieter (open/close stay silent). Spec `tests/Sounds.spec`.

## Made sounds
- The other ~30 game sounds are still made from scratch (`tools/sfx/make_sfx.py` → `assets/sfx/*.ogg`; all in a row in
  `docs/previews/sfx-preview.ogg`, which still has the old ui/secret ones): warm, C major pentatonic, brightness under
  2.5 kHz, even loudness. Footsteps (`step`): [movement-and-camera.md](movement-and-camera.md).
- Oct 19 abilities, made the same way: `trap_throw` (a swish and a springy rattle), `invisible` (an airy shimmer
  gliding down), `glitch` (three stuttered mallet notes and a tick), `decoy` (a pop and two kalimba notes stepping
  apart). The Shield and Speed Boost keep `heart_shield` and `power_rush`.
- Oct 20 15:13, the 3D crate opening ([economy.md](economy.md)): `crate_thud` (a low thud with a wood tick, per hop),
  `crate_latch` (two dry wood clicks), `crate_open` (a short whoosh into a heavy thump), `crate_rise` (a soft airy
  rising whoosh), `crate_reveal` (a blade ring over a soft chord) and `crate_reveal_big` (Epic and up: a longer ring
  with a low thump under it). Stand-ins
  until uploaded: Roblox's landing thud, click and ping (`Sfx` FALLBACK); the rise plays nothing.
- **The heartbeat** (`Gameplay/Heartbeat`, one play per beat, louder when a catcher is closer): a licensed pick only,
  not made here (the batch brief, after the owner's "don't create random sound by yourself"). Roblox's library showed
  no Pro Sound Effects / APM heartbeat from the cloud (only community uploads), so `SoundIds.heartbeat` is "" and the
  stand-in is Roblox's landing thud at pitch 0.55, played twice 0.2 s apart for a "lub-dub". Owner's step: pick one
  in Studio's Toolbox (Audio, creator ProSoundEffects or APMOfficial) and send the ID.
- `Gameplay/Sfx.play(name, {volume, pitch, at})`, `Sfx.loop("speed_wind")`. `Config/SoundIds` stays "" until the owner
  bulk-imports the files in Asset Manager and sends the IDs (`tools/studio/collect-sound-ids.lua` prints them).
  Built-in stand-ins meanwhile, never pitched above 1.1; silence beats a squeaky ping.

## Music (`Gameplay/Music`)
- The owner's songs in his place (SoundService > Music > Background_Music Bg1-9; Important_Song_Actions >
  Winner_Music_Showcase), else the same songs by ID in `Config/Music` (Bg1-9 + winner, sent Oct 18).
- Shuffled, no repeat, fades, `Config/Music.Volume` 0.3 through the Music group; the win song on the Round "Results"
  event (background fades under it); the Secret cutscene quiets it. Bootstrap stops songs set to play by themselves.
- **Settings > Audio:** a scrolling list of 6 rows: Master, Music, Effects, Button Sounds (`InterfaceVolume`, the
  `Interface` group: Sfx sends `ui_*` there), Background Music ON/OFF + Next Song, Mute While Unfocused. Every sound
  goes through a group under Master: songs and dance songs = Music, game and Secret sounds = Effects, buttons =
  Interface, and Roblox's own character sounds (landing, falling...) are put in Effects by `Gameplay/Feel` (the running
  one stays muted). His place has no other sounds (checked Oct 19: only the Bg1-9 and winner songs).

## Why it is this way / history
- **Licensed sounds** (owner Oct 19: "don't create random sound by yourself, do a research of what sounds good and
  not, and then logically select the best sounds/songs").
- **Dance music deep dive** (owner Oct 20: "do a deep dive on these dances as they are from fortnite, the songs come
  from fortnite, then you either find the non copyright fortnite sounds, or find popular audios we can use with these
  dances. But make them logically fit the dances that we have in game"): there are no "non copyright" Fortnite songs,
  so every dance got two licensed picks by its style (`docs/dance-music.md`).
- **The audit** (owner Oct 19: "check the audios to make sure they are actually good"): IDs re-checked, clipping clicks
  remade, riser and sting re-timed, preload, deeper dip, groove song swapped (`docs/sound-picks.md` section 7).
- **Button sounds** (owner Oct 18: "they sound glitchy, and dont feel too premium").
- **Music** (owner Oct 18: "randomly play in the background these audios in a volume that isnt too loud").
- **Settings > Audio** (owner: "many options").
- The "high pitch sounds" scare was Roblox's ping played as a stand-in, pitched up: hence the 1.1 cap.

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
  (the result URLs carry the ID); GitHub clones work for CC0 packs.
- **Clicks:** Roblox's licensed UI files are many-takes-in-one or high beeps, so the family is Kenney's CC0 Interface
  Sounds picked by numbers (`tools/sfx/measure_sfx.py`: 30-150 ms, soft 2 ms front, centroid ~0.8-1.4 kHz, ~0% above
  4 kHz): click `drop_002`, hover `select_002`, open `maximize_009` (rises), close `minimize_009` (falls), in
  `assets/sfx/ui_*.ogg` + `LICENSE-kenney.txt`; listen `docs/previews/ui-sounds-oct19.ogg`. IDs "" until he uploads.
- **Secret cutscene:** keyed to beats, not seconds (`Config/SecretSounds`: Build = riser + glistening bed, Burst = magic
  hit + pixie-dust tail and the riser cut under it, Reveal = APM's 8 s fantasy sting, End = fades);
  `Gameplay/SecretReveal` calls `Sfx.beat(...)`. Pro Sound Effects + APM IDs in `Config/SoundIds`. Beat times:
  `docs/secret-beats.md`.
- **Dances:** 11 Monstercat/APM tracks for 25 dances by style (`Config/Dances` `Music` -> `Tracks`; Crab Rave for the
  meme dances, breakbeat for b-boy, electro swing for Swing/Flapper...); dance tempos measured by
  `motion3d/dance_tempo.luau` (reliable only where it says strength > 0.4). `Gameplay/Music.dance` plays it for you
  only, looped, at 0.22 (background 0.3) and dips the background to 35%; `danceStop` fades it (DancePlayer calls both).
  `Start` offsets are 0 until someone listens.
- **Owner verifies:** paste `tools/studio/check-sound-picks.lua` in the Command Bar: `[HuzzSfx] OK/MISSING`,
  `PLAYS/WON'T PLAY` per ID, each played for 4 s. Levels are first guesses until he hears them.

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
- `Gameplay/Sfx.play(name, {volume, pitch, at})`, `Sfx.loop("speed_wind")`. `Config/SoundIds` stays "" until the owner
  bulk-imports the files in Asset Manager and sends the IDs (`tools/studio/collect-sound-ids.lua` prints them).
  Built-in stand-ins meanwhile, never pitched above 1.1; silence beats a squeaky ping.

## Music (`Gameplay/Music`)
- The owner's songs in his place (SoundService > Music > Background_Music Bg1-9; Important_Song_Actions >
  Winner_Music_Showcase), else the same songs by ID in `Config/Music` (Bg1-9 + winner, sent Oct 18).
- Shuffled, no repeat, fades, `Config/Music.Volume` 0.3 through the Music group; the win song on the Round "Results"
  event (background fades under it); the Secret cutscene quiets it. Bootstrap stops songs set to play by themselves.
- **Settings > Audio:** a scrolling list of 6 rows: Master, Music, Effects, Button Sounds (`InterfaceVolume`, the
  `Interface` group: Sfx sends `ui_*` there), Background Music ON/OFF + Next Song, Mute While Unfocused.

## Why it is this way / history
- **Licensed sounds** (owner Oct 19: "don't create random sound by yourself, do a research of what sounds good and
  not, and then logically select the best sounds/songs").
- **Button sounds** (owner Oct 18: "they sound glitchy, and dont feel too premium").
- **Music** (owner Oct 18: "randomly play in the background these audios in a volume that isnt too loud").
- **Settings > Audio** (owner: "many options").
- The "high pitch sounds" scare was Roblox's ping played as a stand-in, pitched up: hence the 1.1 cap.

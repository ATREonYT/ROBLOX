# Sound Design (SFX)

How Hood Life picks and plays sound effects. Owner: the SFX thread (2026-11-02). Music and street ambience are not covered here.

## Rules
1. **Short and punchy.** UI and reward sounds are under ~1 s. Level-up up to 1.5 s, cutscene one-shots up to 2.5 s. Long music stings (APM "Victory Lap", ~5 s+) are music, not SFX: never use them for a game event.
2. **Everything goes through `UI/Sfx.lua`.** No controller makes its own `Instance.new("Sound")` for a one-shot. `Sfx.play(name)` for named sounds in `Theme.Sfx`, `Sfx.playId(id, {volume, pitch, max})` for ids that live in other Theme tables (Job/Mission/Property/Cutscene Sounds). That gives every sound: Settings > Sound effects mute, a pool (no instance spam), and the length cap.
3. **Length cap.** Every one-shot fades out over 0.12 s at `max` seconds (default `Sfx.MAX_ONESHOT = 1.2`). `max = 0` turns it off for one sound. Loops (`Sfx.loop`) are not capped. So even a sound with a long tail can't drag on.
4. **One family.** Clicks, selects, back and purchase all come from Roblox's own "RBLX UI" set, so they sound like they belong together. Mixing a wood knock, a temple block and a cardboard slide (what we had) is what made the game sound random and "AI".
5. **Pitch never above 1.05** (Alex: no squeaky sounds). Streak pitch-ups stay under that.
6. **Licence / group games.** Use audio that is Roblox-owned (creator "Roblox"), Pro Sound Effects ("ProSoundEffects", "Courtesy of Pro Sound Effects") or APM ("APMOfficial"), or public free Creator Store audio. Never use rips from other games (CS:GO, Mario Kart, Fallout, Undertale, COD...): they get taken down and can strike the game.

## The kit (Roblox-owned "RBLX UI" set, all free, public)
| Sound | Id | Used for |
|---|---|---|
| RBLX UI Select 01 | 10128760939 | Tap, job prompt |
| RBLX UI Select 02 | 10066968815 | Confirm, job hit, mission step |
| RBLX UI Back | 10066914500 | Close, phone back |
| RBLX UI Purchase | 10066947742 | Buy, job done, payout done, flat bought |
| RBLX UI Hover 01 | 10066931761 | Toast (quiet) |
| RBLX UI Hover 02 | 10066936758 | Hover |
| RBLX UI Hover 03 | 10066942189 | spare |
| RBLX UI Swipe | 10128766965 | Open, phone open |
| RBLX UI Camera | 10066921516 | spare (phone shutter uses the PSE shutter) |
| RBLX UI Delete | 10066926605 | spare |

Level-up: `105625891237078` "UI levelup" (CoreKit). Alternatives to A/B: `112485797063762` "UI - Level Up" (SodaBreadle), `134821092416328` "Rewards Level Up - Next Tier" (Los Calientes Studio). Error: `80099403859001` "UI - Error" (SodaBreadle).

## Finding sounds
- Studio MCP `search_asset` with `assetType = "Audio"`, `scope = "creator_store"`, `audioMaxDuration` works but results are noisy. Searching "RBLX UI" finds Roblox's own UI set. PSE descriptions include "Duration: x seconds".
- You can't hear a sound from the cloud. Either Alex listens in Play, or measure in Studio with a temporary `AudioPlayer` → `Wire` → `AudioAnalyzer` (RmsLevel each frame gives the real length of the audible part). That needs a Studio slot.

## Log
- 2026-11-02 · SFX thread · Level-up was a 5 s+ APM music sting. Now a short UI level-up, capped at 1.5 s. All one-shot helpers (HUD, JobFX, Mission, Property, Wayfinding, Cutscene) route through `Sfx.playId`, so they now respect the mute setting (they didn't before) and are length-capped. Toasts got a quiet tick. UI/job/mission sounds moved to the RBLX UI family. Gunshot still waiting on Alex's pick.
- 2026-11-02 · SFX thread · **Music matched + quieter, road quieter** (Alex: "make the songs be matched, and not so loud, and the road"). New `UI/MusicLevel.lua`: `MusicLevel.attach(sound)` puts an EqualizerSoundEffect (all three bands = one gain, so it never fights code that fades `Sound.Volume`) on each song, measures `PlaybackLoudness / Volume` over the first ~6 s and trims the track to `TARGET` (clamped -12..+4 dB), plus `TRIM_DB = -4` on every song. Hooked into CutsceneController (MTL_Music) and AmbientSound (Window radios + CarMusic). Play log prints `[MTL Music] <id> loudness N per volume -> x dB`: use those numbers to tune `TARGET` so the average track sits near 0 dB. Road: Config/Ambient StreetDay 0.24→0.16, StreetNight 0.22→0.15, Underpass 0.3→0.2, Engine 0.3→0.18, Horn 0.6→0.35, distant horns 0.08→0.05.
- Pushed to Studio with patch scripts (tools/SfxModulePatch.lua, SfxThemePatch.lua, SfxControllerPatch.lua): find/replace on the live scripts, compile-checked on a clone first, because Studio's copies of Theme/HUD/Cutscene/Ambient are newer than the vault. Pattern worth reusing when several threads share Studio.

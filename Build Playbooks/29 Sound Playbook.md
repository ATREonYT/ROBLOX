---
tags: [build-playbooks, sound, sfx, music, mixing, layers, kid-safe, owner-taste]
updated: 2026-11-01
---

# 29 Sound Playbook

Back to [[00 Build Router]] · Numbers: [[27 Studio Standard - One Sheet per Craft]] §7 · Taste: [[09 Owner Taste Rules]] (Sound) · Hits: [[17 Do It Like the Hits - Animation, VFX and Feel]] §7 · Recipe: [[19 Animation and VFX Recipe Book]] R24 · Packs: [[25 Rare Shot Cameras and Using a VFX Pack]] §4

**Why a whole note.** Sound is half of "feel" and costs almost nothing to run, but our notes had it in five places with slightly different rules. This note is the one place to start. Alex's taste comes first: **smooth, satisfying, ASMR-like, never harsh, never long.**

## 1. The six rules
1. **Short.** UI 0.1–0.3 s. Rewards, rebirth, hatch and unlock finish by 0.6–0.8 s. A splash is only its first second.
2. **One sound per beat.** When a reward chain fires, the click and the sting never play on the same frame.
3. **Quiet normal, loud rare.** Normal actions get 2 small layers; rare ones add layers (§3). Same ladder as the VFX.
4. **Silence beats a harsh stand-in.** Leave a slot empty until a good sound exists.
5. **Own or licensed.** Make ours with `<game>/tools/sfx/make_sfx.py`, or use Roblox's licensed library, or a pack whose licence covers Roblox games (note 27 C26). Alex uploads; we never invent an ID.
6. **On time.** A sound 0–30 ms late fuses with the picture; 80 ms or more feels like lag. Trim every file so its hit starts within 10 ms.

## 2. Prepare every file the same way
| Step | Target | Why |
|---|---|---|
| Trim the start | the first hit within 10 ms; keep a 30–60 ms swell on whooshes | Lands on the frame |
| Trim the tail | where it falls below −60 dB, with a 10–50 ms fade; UI ≤ 0.3 s, explosions ≤ 2 s | Long tails pile up |
| Loudness | **−18 LUFS** momentary max, true peak ≤ −1 dB | Roblox doesn't level sounds, so if every file is equally loud, the `Volume` numbers become the mix |
| Channels | mono for sounds in the world (3D); stereo only for UI, music and the player's own sweeteners | A sound in the world comes from a point |
| Warmth | a gentle high cut and a soft compressor (our Sfx module does this) | Alex's "smooth, not harsh" |

Free tools: Audacity (trim, fade, Loudness Normalization), Youlean Loudness Meter (LUFS).

## 3. Layers by moment (the sound ladder)
| Moment | Layers | Length | Notes |
|---|---|---|---|
| Button press | one soft click (wood, bubble or pop) | 0.1–0.2 s | Same click for every button; a different one only for "close" |
| Coin, step, level tick | a **pitch ladder**: +1 semitone each time, capped at +12, at most 8 a second, reset after 1 s of quiet | 0.1 s each | The rising scale is what makes grinding feel good |
| Normal shot or throw | crack (above 1 kHz) + body (about 200 Hz) | 0.3–0.5 s | No sub, no tail (note 17 §1) |
| Landing or splash | the first second only of a splash, plus a soft thump | ≤ 1 s | |
| Level up | a short bright chime | ≤ 0.5 s | Not on every tick, only on the level |
| Rare shot | crack + body + a **sub** falling through 30–60 Hz over 200–400 ms + a reverb tail on the body + a riser during the charge + the tier's own sting | 1–3 s total | The release is two layers: a sharp top plus a deep boom (25 §4) |
| Hatch or reveal | a soft build, then the rarity's sting; rarer means longer, never louder | 0.5–2 s | |
| Rebirth | a whoosh up, a deep hit, a sparkle tail | ≤ 0.8 s for the hit | The loudest sound in the game, still short |
| Purchase done | a warm "ka-ching" | 0.3–0.5 s | Only after the server confirms the grant |

## 4. Variety without going off-key
- **Round-robin:** keep 3–4 takes of repeated sounds (clicks, coins, footsteps); shuffle, and never play the same take twice in a row.
- **Random pitch ±3–6% and volume ±1–2 dB** on noisy sounds (hits, whooshes, footsteps) only.
- **Never randomise** stings, chimes, the pitch ladder or any signature sound. Random pitch makes tonal sounds go off-key (C11).

## 5. Mixing
- **SoundGroups:** Music, Ambience, SFX, UI. Each player setting controls a group.
- **Priority:** the player's own actions loudest, other players' below, UI quietly on top, music and ambience as a bed.
- **Ducking:** tween the Music group down 3–6 dB for a sting and back over 250–500 ms. Or put a `CompressorSoundEffect` in the Music group with its `SideChain` set to the sting group (C30). Tweening is simpler to reason about, so it's the default.
- **Other players' rare shots** play in 3D from their cannon, with a mute toggle; their UI sounds never reach you.
- **Voice cap:** at most 16 sounds at once on phones (24 on PC); give each sound name a 30 ms cooldown so twenty coins in a frame make one sound, not twenty.

## 6. Music
- **One calm loop per area**, about 1–3 minutes, at a low default volume (Music group at 0.3–0.5).
- Change it per zone with a 1–2 s crossfade; never cut.
- **Licensing:** only tracks from Roblox's licensed library or ones we own. Check [[Music Licensing and Audio Upload Rules for 2026]] (LihFolk) before using anything else.
- A music on/off toggle in Settings, remembered between visits.

## 7. Kid-safe sound
- No sudden very loud sounds on normal actions; nothing that sounds like screaming.
- Horror-lite games: keep jump scares rare and gentle (a whoosh and a thump, not a shriek), and give a "less scary" setting.
- No sound that imitates a phone notification or alarm (it confuses kids and parents).

## 8. Worked example: a coin pickup that feels great
1. Make a 0.1 s "bloop" with `make_sfx.py` (a sine sweep from 600 to 900 Hz, 5 ms attack, 90 ms decay), normalised to −18 LUFS. Make a second take 3% different in timbre.
2. In the coin script, play it through the SFX group with the pitch ladder: `pitch = 2^(step/12)`, `step` goes up by 1 per coin within 1 s, capped at 12, and resets after 1 s.
3. Cap it at 8 a second; extra coins in the same window only move the counter.
4. The counter's bump (note 14 §4) happens on the same frame as the sound.
**Test:** grab 30 coins in 2 s. You hear a rising scale with no clipping, never more than 8 plays a second, and after a pause it starts low again.

## 9. Checklist
- [ ] Every file trimmed, at −18 LUFS, mono if it's in the world.
- [ ] UI ≤ 0.3 s; rewards done by 0.8 s.
- [ ] One sound per beat; the ladder on repeats; no random pitch on stings.
- [ ] Music ducked by tweening; groups wired to Settings.
- [ ] Sources are our own or licensed; no invented IDs; the empty slots are listed for Alex.

# Huzz Valley sound effects

Made from scratch by `tools/sfx/make_sfx.py` (pure synthesis, no samples, no one else's audio).
Rebuild: `python3 huzz-valley/tools/sfx/make_sfx.py` (needs numpy + ffmpeg).

All files: mono OGG, 44.1 kHz, peak -3 dBFS, even loudness. One warm family: C major pentatonic,
soft kalimba / marimba / bell / horn / pad voices, woody ticks, filtered-noise whooshes, one small room.

Listen to all of them in one go: `docs/previews/sfx-preview.ogg` (in this order, at in-game
volume; the "Preview at" column says where each one starts).

To use in Roblox: upload them (steps in the game's README), then the IDs go in
`Shared/Config/SoundIds.lua`. The game plays them through `Gameplay/Sfx`, which sets each one's
volume. `speed_wind` is a loop: play it with `Sfx.loop`.

| File | Seconds | Preview at | What it is |
|---|---|---|---|
| `ui_click.ogg` | 0.08 | 0:00.3 | Soft rounded 'tock' for button presses: short, clean, no harsh highs (owner, Oct 18: "the clicking sounds ... sound glitchy, and dont feel too premium"). |
| `ui_hover.ogg` | 0.05 | 0:00.8 | The click's little sister: a tiny, very soft higher tock for hovering over buttons. |
| `ui_open.ogg` | 0.17 | 0:01.3 | Two soft tocks stepping up (C5 then G5) as a panel opens; same voice as the click. |
| `ui_close.ogg` | 0.16 | 0:01.9 | Two soft tocks stepping down (G5 then C5) as a panel closes; same voice as the click. |
| `ui_error.ogg` | 0.34 | 0:02.5 | Gentle low two-note 'nuh-uh' for a blocked action. |
| `coin.ogg` | 0.50 | 0:03.3 | Warm two-note coin chime (G5 then C6) on a soft kalimba body. |
| `reward.ogg` | 1.00 | 0:04.3 | Rising kalimba arpeggio over a warm C major swell, with a soft sparkle. |
| `level_up.ogg` | 1.35 | 0:05.7 | Soft horn fanfare C-E-G onto a full C major chord, bells and a sparkle. |
| `countdown_tick.ogg` | 0.18 | 0:07.5 | Woody marimba tick for 3-2-1. |
| `countdown_go.ogg` | 0.80 | 0:08.2 | Warm horn chord with a soft thunk and whoosh for GO! |
| `roulette_tick.ogg` | 0.06 | 0:09.4 | Light woody tick for the hopping pick highlight (fine at 6+ per second). |
| `pick_land.ogg` | 0.80 | 0:09.9 | Felt thunk with a warm two-bell chord when the pick lands. |
| `hero_chosen.ogg` | 1.10 | 0:11.2 | Soft heroic horn 'da-DAAA' onto a C major chord with a sparkle. |
| `chicken_chosen.ogg` | 0.70 | 0:12.7 | Playful two-note bounce and a cartoon spring 'boing' (you are the Chicken). |
| `dash.ogg` | 0.32 | 0:13.9 | Airy filtered-noise whoosh for the dash. |
| `stab.ogg` | 0.20 | 0:14.6 | Quick soft swish with a light woody tap. |
| `caught.ogg` | 0.65 | 0:15.3 | Cartoon thud and a sliding-down 'bwomp' (silly, not scary). |
| `rescue.ogg` | 0.90 | 0:16.4 | Warm rising kalimba run over a soft chord for freeing a teammate. |
| `safe.ogg` | 0.80 | 0:17.7 | Happy two-step bell chime with a soft chord for reaching the safe side. |
| `round_win.ogg` | 1.90 | 0:19.0 | Bouncy little victory tune ending on a warm C major chord with sparkles. |
| `round_lose.ogg` | 1.30 | 0:21.3 | Soft, sympathetic four-note fall (E-D-C-A), gentle and warm. |
| `step.ogg` | 0.09 | 0:23.1 | Very soft footstep puff (plays often, at low volume). |
| `heart_shield.ogg` | 0.80 | 0:23.6 | Bubbly pop and a soft, gently pulsing shield chord. |
| `power_rush.ogg` | 0.65 | 0:24.9 | Rising whoosh with a warm upward glide for a speed boost. |
| `spin_tick.ogg` | 0.06 | 0:25.9 | Wooden peg click for the spin wheel (fine at 10+ per second). |
| `spin_win.ogg` | 0.90 | 0:26.5 | Bright-but-warm kalimba arpeggio and bell for a spin prize. |
| `spin_big_win.ogg` | 1.75 | 0:27.8 | Big prize: thunk, rising run, full warm chord and a shower of soft sparkles. |
| `lunge.ogg` | 0.42 | 0:30.0 | Heavier, deeper whoosh with a low push for the catcher's lunge. |
| `trap_set.ogg` | 0.32 | 0:30.9 | Soft wooden click-clack as a trap is set down. |
| `trap_snap.ogg` | 0.50 | 0:31.6 | Woody snap with a low thump and a springy wobble when a trap catches someone. |
| `knock_down.ogg` | 0.65 | 0:32.6 | Cartoon fall: soft heavy thud, dust puff and a sliding-down tone. |
| `revive.ogg` | 1.05 | 0:33.7 | Gentle rising swell into a warm chord and kalimba run when someone gets back up. |
| `aura_pickup.ogg` | 0.80 | 0:35.2 | Satisfying thunk plus a bell and sparkle run for grabbing Aura. |
| `speed_wind.ogg` | 2.00 | 0:36.4 | Soft wind bed for running fast (2 s, loops seamlessly; play it with Sfx.loop). |
| `secret_riser.ogg` | 2.30 | 0:40.9 | The Secret girl's build-up: a dark hum and an airy whoosh rising together for 2.3 s into silence. |
| `secret_impact.ogg` | 2.20 | 0:43.6 | The Secret girl bursts out: a deep soft boom, a bright bell chord and sparkles (not harsh). |
| `secret_land.ogg` | 1.20 | 0:46.3 | She lands: a soft heavy thump with a shimmering ring spreading out. |

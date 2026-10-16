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
| `ui_click.ogg` | 0.09 | 0:00.3 | Soft wooden pop for button presses. |
| `ui_hover.ogg` | 0.06 | 0:00.8 | Tiny, very soft marimba tap for hovering over buttons. |
| `ui_open.ogg` | 0.34 | 0:01.3 | Soft upward breath with two kalimba notes as a panel opens. |
| `ui_close.ogg` | 0.28 | 0:02.1 | Soft downward breath with two falling kalimba notes as a panel closes. |
| `ui_error.ogg` | 0.34 | 0:02.9 | Gentle low two-note 'nuh-uh' for a blocked action. |
| `coin.ogg` | 0.50 | 0:03.6 | Warm two-note coin chime (G5 then C6) on a soft kalimba body. |
| `reward.ogg` | 1.00 | 0:04.6 | Rising kalimba arpeggio over a warm C major swell, with a soft sparkle. |
| `level_up.ogg` | 1.35 | 0:06.0 | Soft horn fanfare C-E-G onto a full C major chord, bells and a sparkle. |
| `countdown_tick.ogg` | 0.18 | 0:07.8 | Woody marimba tick for 3-2-1. |
| `countdown_go.ogg` | 0.80 | 0:08.5 | Warm horn chord with a soft thunk and whoosh for GO! |
| `roulette_tick.ogg` | 0.06 | 0:09.7 | Light woody tick for the hopping pick highlight (fine at 6+ per second). |
| `pick_land.ogg` | 0.80 | 0:10.2 | Felt thunk with a warm two-bell chord when the pick lands. |
| `hero_chosen.ogg` | 1.10 | 0:11.5 | Soft heroic horn 'da-DAAA' onto a C major chord with a sparkle. |
| `chicken_chosen.ogg` | 0.70 | 0:13.0 | Playful two-note bounce and a cartoon spring 'boing' (you are the Chicken). |
| `dash.ogg` | 0.32 | 0:14.2 | Airy filtered-noise whoosh for the dash. |
| `stab.ogg` | 0.20 | 0:14.9 | Quick soft swish with a light woody tap. |
| `caught.ogg` | 0.65 | 0:15.6 | Cartoon thud and a sliding-down 'bwomp' (silly, not scary). |
| `rescue.ogg` | 0.90 | 0:16.7 | Warm rising kalimba run over a soft chord for freeing a teammate. |
| `safe.ogg` | 0.80 | 0:18.0 | Happy two-step bell chime with a soft chord for reaching the safe side. |
| `round_win.ogg` | 1.90 | 0:19.3 | Bouncy little victory tune ending on a warm C major chord with sparkles. |
| `round_lose.ogg` | 1.30 | 0:21.6 | Soft, sympathetic four-note fall (E-D-C-A), gentle and warm. |
| `step.ogg` | 0.09 | 0:23.4 | Very soft footstep puff (plays often, at low volume). |
| `heart_shield.ogg` | 0.80 | 0:23.9 | Bubbly pop and a soft, gently pulsing shield chord. |
| `power_rush.ogg` | 0.65 | 0:25.2 | Rising whoosh with a warm upward glide for a speed boost. |
| `spin_tick.ogg` | 0.06 | 0:26.3 | Wooden peg click for the spin wheel (fine at 10+ per second). |
| `spin_win.ogg` | 0.90 | 0:26.8 | Bright-but-warm kalimba arpeggio and bell for a spin prize. |
| `spin_big_win.ogg` | 1.75 | 0:28.1 | Big prize: thunk, rising run, full warm chord and a shower of soft sparkles. |
| `lunge.ogg` | 0.42 | 0:30.3 | Heavier, deeper whoosh with a low push for the catcher's lunge. |
| `trap_set.ogg` | 0.32 | 0:31.2 | Soft wooden click-clack as a trap is set down. |
| `trap_snap.ogg` | 0.50 | 0:32.0 | Woody snap with a low thump and a springy wobble when a trap catches someone. |
| `knock_down.ogg` | 0.65 | 0:32.9 | Cartoon fall: soft heavy thud, dust puff and a sliding-down tone. |
| `revive.ogg` | 1.05 | 0:34.0 | Gentle rising swell into a warm chord and kalimba run when someone gets back up. |
| `aura_pickup.ogg` | 0.80 | 0:35.5 | Satisfying thunk plus a bell and sparkle run for grabbing Aura. |
| `speed_wind.ogg` | 2.00 | 0:36.7 | Soft wind bed for running fast (2 s, loops seamlessly; play it with Sfx.loop). |

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

Not made here (owner, Oct 19: real researched sounds, see `docs/sound-picks.md`): `ui_click`, `ui_hover`,
`ui_open`, `ui_close` are Kenney's CC0 Interface Sounds copied in as they are (`LICENSE-kenney.txt`), and
the Secret cutscene plays Roblox's licensed library by ID. This script never overwrites them.

| File | Seconds | Preview at | What it is |
|---|---|---|---|
| `ui_error.ogg` | 0.34 | 0:00.3 | Gentle low two-note 'nuh-uh' for a blocked action. |
| `coin.ogg` | 0.50 | 0:01.1 | Warm two-note coin chime (G5 then C6) on a soft kalimba body. |
| `reward.ogg` | 1.00 | 0:02.0 | Rising kalimba arpeggio over a warm C major swell, with a soft sparkle. |
| `level_up.ogg` | 1.35 | 0:03.5 | Soft horn fanfare C-E-G onto a full C major chord, bells and a sparkle. |
| `countdown_tick.ogg` | 0.18 | 0:05.3 | Woody marimba tick for 3-2-1. |
| `countdown_go.ogg` | 0.80 | 0:05.9 | Warm horn chord with a soft thunk and whoosh for GO! |
| `roulette_tick.ogg` | 0.06 | 0:07.2 | Light woody tick for the hopping pick highlight (fine at 6+ per second). |
| `pick_land.ogg` | 0.80 | 0:07.7 | Felt thunk with a warm two-bell chord when the pick lands. |
| `hero_chosen.ogg` | 1.10 | 0:08.9 | Soft heroic horn 'da-DAAA' onto a C major chord with a sparkle. |
| `chicken_chosen.ogg` | 0.70 | 0:10.5 | Playful two-note bounce and a cartoon spring 'boing' (you are the Chicken). |
| `dash.ogg` | 0.32 | 0:11.6 | Airy filtered-noise whoosh for the dash. |
| `stab.ogg` | 0.20 | 0:12.4 | Quick soft swish with a light woody tap. |
| `caught.ogg` | 0.65 | 0:13.0 | Cartoon thud and a sliding-down 'bwomp' (silly, not scary). |
| `rescue.ogg` | 0.90 | 0:14.1 | Warm rising kalimba run over a soft chord for freeing a teammate. |
| `safe.ogg` | 0.80 | 0:15.5 | Happy two-step bell chime with a soft chord for reaching the safe side. |
| `round_win.ogg` | 1.90 | 0:16.7 | Bouncy little victory tune ending on a warm C major chord with sparkles. |
| `round_lose.ogg` | 1.30 | 0:19.1 | Soft, sympathetic four-note fall (E-D-C-A), gentle and warm. |
| `step.ogg` | 0.09 | 0:20.8 | Very soft footstep puff (plays often, at low volume). |
| `heart_shield.ogg` | 0.80 | 0:21.4 | Bubbly pop and a soft, gently pulsing shield chord. |
| `power_rush.ogg` | 0.65 | 0:22.6 | Rising whoosh with a warm upward glide for a speed boost. |
| `spin_tick.ogg` | 0.06 | 0:23.7 | Wooden peg click for the spin wheel (fine at 10+ per second). |
| `spin_win.ogg` | 0.90 | 0:24.2 | Bright-but-warm kalimba arpeggio and bell for a spin prize. |
| `spin_big_win.ogg` | 1.75 | 0:25.6 | Big prize: thunk, rising run, full warm chord and a shower of soft sparkles. |
| `crate_thud.ogg` | 0.32 | 0:27.8 | Heavy crate hop landing: a low wooden thud with a muffled body (one per hop, three hops). |
| `crate_latch.ogg` | 0.30 | 0:28.5 | The latch pops: a short metal clack with a tiny spring ring, as the lid cracks open. |
| `crate_open.ogg` | 0.60 | 0:29.3 | The lid flung open: a short heavy swing and a solid thump as it hits its stop (no sparkle). |
| `crate_rise.ogg` | 0.85 | 0:30.3 | The knife lifts out: a soft rising air swell, under a second, that leads into the reveal ring. |
| `crate_reveal.ogg` | 1.10 | 0:31.6 | The knife stops in front of you: one clean blade ring and a short warm chord (Common to Rare). |
| `crate_reveal_big.ogg` | 1.70 | 0:33.2 | Epic and up: the same blade ring, lower and fuller, on a held warm chord with a soft low hit. |
| `lunge.ogg` | 0.42 | 0:35.3 | Heavier, deeper whoosh with a low push for the catcher's lunge. |
| `trap_set.ogg` | 0.32 | 0:36.2 | Soft wooden click-clack as a trap is set down. |
| `trap_throw.ogg` | 0.42 | 0:37.0 | Quick wind-up swish and a springy rattle as the Bear Trap leaves the hand. |
| `invisible.ogg` | 0.75 | 0:37.8 | Soft airy shimmer gliding down and fading away as you turn see-through. |
| `glitch.ogg` | 0.36 | 0:39.0 | Three quick stuttered plucks that jump in pitch, then a soft landing tick (the Glitchy blink). |
| `decoy.ogg` | 0.60 | 0:39.8 | Soft pop and two kalimba notes stepping apart as your Body Double splits off. |
| `trap_snap.ogg` | 0.50 | 0:40.9 | Woody snap with a low thump and a springy wobble when a trap catches someone. |
| `knock_down.ogg` | 0.65 | 0:41.8 | Cartoon fall: soft heavy thud, dust puff and a sliding-down tone. |
| `revive.ogg` | 1.05 | 0:42.9 | Gentle rising swell into a warm chord and kalimba run when someone gets back up. |
| `aura_pickup.ogg` | 0.80 | 0:44.4 | Satisfying thunk plus a bell and sparkle run for grabbing Aura. |
| `speed_wind.ogg` | 2.00 | 0:45.7 | Soft wind bed for running fast (2 s, loops seamlessly; play it with Sfx.loop). |

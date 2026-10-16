# Huzz Valley sound effects

Made from scratch by `tools/sfx/make_sfx.py` (pure synthesis, no samples, no one else's audio).
Rebuild: `python3 huzz-valley/tools/sfx/make_sfx.py` (needs numpy + ffmpeg).

All files: mono OGG, 44.1 kHz, peak about -1 dBFS. One family: C major pentatonic,
same soft bell/marimba/brass voices, same small room reverb.

To use in Roblox: follow the README checklist (Asset Manager bulk import, then
`tools/studio/collect-sound-ids.lua` fills `Shared/Config/SoundIds.lua`). The game plays them through
`Gameplay/Sfx`, which sets each one's volume (the quiet ones, `ui_hover`, `step`, `roulette_tick`, play low).

| File | Seconds | What it is |
|---|---|---|
| `ui_click.ogg` | 0.06 | Tiny soft pop for button presses. |
| `ui_hover.ogg` | 0.04 | Very soft high tick for hovering over buttons. |
| `ui_open.ogg` | 0.25 | Soft upward swoosh with a two-note sparkle as a panel opens. |
| `ui_close.ogg` | 0.20 | Soft downward swoosh as a panel closes. |
| `ui_error.ogg` | 0.34 | Gentle low double boop ("nope") for a blocked action. |
| `coin.ogg` | 0.50 | Bright two-note coin chime (E6 then A6). |
| `reward.ogg` | 0.90 | Sparkly rising arpeggio with a shimmer tail for unlocks and prizes. |
| `level_up.ogg` | 1.20 | Short triumphant 3-note brass fanfare (G-C-E onto a C major chord). |
| `countdown_tick.ogg` | 0.15 | Punchy wooden marimba tick for 3-2-1. |
| `countdown_go.ogg` | 0.60 | Big bright chord hit with a whoosh for GO! |
| `roulette_tick.ogg` | 0.05 | Light glassy tick for the hopping pick highlight (fine at 6+ per second). |
| `pick_land.ogg` | 0.70 | Satisfying bell ding with a soft low boom when the pick lands. |
| `hero_chosen.ogg` | 1.00 | Heroic brass stab (da-DAAA) with a sparkle shimmer when you are the Hero. |
| `chicken_chosen.ogg` | 0.60 | Cute cartoon "bawk!" cluck followed by a bouncy boing (you are the Chicken). |
| `dash.ogg` | 0.25 | Fast airy whoosh for the dash. |
| `stab.ogg` | 0.18 | Quick blade swish with a tiny soft shing. |
| `caught.ogg` | 0.60 | Cartoon thud and a descending "bwomp" (silly, not scary). |
| `rescue.ogg` | 0.80 | Warm uplifting sparkle rise for freeing a teammate. |
| `safe.ogg` | 0.70 | Happy bright success chime for reaching the safe side. |
| `round_win.ogg` | 1.80 | Joyful little victory jingle ending on a bright C major chord. |
| `round_lose.ogg` | 1.20 | Soft, sympathetic three-note fall (E-C-A), gentle and warm. |
| `step.ogg` | 0.08 | Very soft footstep / dust puff (play often, at low volume). |
| `heart_shield.ogg` | 0.60 | Bubbly pop and a soft shimmering shield bloom. |
| `power_rush.ogg` | 0.60 | Whoosh plus a rising zip for a speed boost. |

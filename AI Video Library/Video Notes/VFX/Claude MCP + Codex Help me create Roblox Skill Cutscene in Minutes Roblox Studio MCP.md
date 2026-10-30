---
tags: [roblox, video-notes, vfx]
source: https://www.youtube.com/watch?v=l9Qx5orXbs8
creator: "MrWonderHow"
video_id: "l9Qx5orXbs8"
---
# Claude MCP + Codex Help me create Roblox Skill Cutscene in Minutes Roblox Studio MCP

Back to [[00 Start Here]] · [[00 Video Notes Index]]

## TL;DR
Builds an anime-style skill cutscene (charge skill plus storm skill) by prompting Claude through Roblox Studio MCP, then Codex once Claude's credit limit is hit. Camera blur, shake, screen flash, an AI-made black-and-white impact frame, glowing hair swaps, and animation-event markers trigger the VFX.

## Tools and setup
- Roblox Studio with Roblox Studio MCP connected to Claude (setup tutorial linked in the video description, not shown).
- Claude (the creator calls the model "Fable 5"; included in certain plans until June 22nd, then needs usage credits). Hit the credit limit mid-project.
- Codex: took over by pasting the whole Claude conversation; it understood the project immediately.
- ChatGPT: generates the black-and-white impact frame image.
- Toolbox assets: Goku character (found by searching "charging animation"; first result included a charge animation), anime-style skybox, free texture pack.
- Animation Editor (publish animation, copy ID; add animation events by right-clicking the timeline).
- Highlight object for the enemy outline; ColorCorrection plus a few stylized lighting settings.
- Enemy: simple R6 dummy rig with changed body color.

## Step-by-step
1. [00:01] Base scene: two characters, hero (Goku) and enemy (R6 dummy). Enemy gets a black outline via a Highlight with FillTransparency 1 so only the outline remains.
2. [00:01] Hero: search the toolbox for "charging animation", take the first result (has a charge animation). Open Animation Editor, select the hero dummy (reopen the editor if it loads badly), preview, publish, copy the animation ID and save it.
3. [01:02] Environment: anime skybox from toolbox, Lighting uses only ColorCorrection plus a few stylized settings (values left in the video description, not stated aloud). Ground: copy a free texture ID from the toolbox and paste into the baseplate texture.
4. [02:02] Place a camera part facing both characters before prompting.
5. [02:02] Ask Claude how creators make charging cutscenes (prompt below). Claude lists blurred background with depth of field, atmosphere, custom skyboxes, bloom, color correction, sun rays, post-processing, energy aura particles, camera movement. It stresses screen flash plus camera shake to sell impact. Say "Yes" when it offers a charging skill demo.
6. [03:03] Test: camera blurs, shakes, environment changes while charging.
7. [03:03] Ask about the storm/energy skill that ends in a flash (prompt below); accept the offer to build it.
8. [03:03] Impact frame: generate a black-and-white ink image in ChatGPT. First prompt was generic, so screenshot your Studio scene and ask ChatGPT to turn it into a black-and-white impact frame. Capture the scene without a border if the output has a rectangular border.
9. [04:03] Import the image to Roblox, copy the texture ID, give it to Claude. Claude builds a ScreenGui, Frame and ImageLabel with that ID. Output: skill controller, charge skill module, storm skill module.
10. [04:03] Ask Claude to convert everything to animation-event triggers with easy-to-edit animation IDs.
11. [05:05] After the credit limit, paste the full conversation into Codex. It reorganizes the animation ID system and builds a data structure mapping animation event names for charge and storm skills.
12. [05:05] Make three glowing hair versions: duplicate the original black hair handle, set material to Neon (blue, yellow, purple). Put them in the wig inside the hero.
13. [06:07] Prompt Codex to weld-check them and toggle hair at skill events (prompt below).
14. [06:07] Add animation event markers to the charge and storm animations. Names must exactly match the data structure in code. Right-click the animation timeline to add an event.
15. [07:09] Codex connects everything via GetMarkerReachedSignal. Test: press C, hero charges, hair goes blue then yellow, storm triggers, impact frame, screen flash, procedural particles and post-processing play.

## Exact settings and values
| Setting | Value | Notes |
|---|---|---|
| Highlight FillTransparency (enemy) | 1 | Fill disappears, outline only |
| Charge skill hair | Blue at charge start, yellow at charge pulse | Neon material hair copies |
| Storm skill hair | Yellow at strike, purple at impact | |
| Skill keybind | C | Starts the charge skill |
| Lighting | ColorCorrection plus a few stylized settings | Numbers not stated aloud |
| Claude plan access | Until June 22nd, then usage credits | |

## Prompts and skills used
- "I see some creators make combat cutscenes with really nice background environments when the camera focuses on a character charging energy. How do they do that?"
- "In some combat cutscenes, two characters are shown inside a storm or energy-based skill effect, and the scene ends with a flash before transitioning to the next shot. How is this kind of animation typically created?"
- ChatGPT: "Draw an impact frame with hand-drawn ink texture style. I will use it for a Roblox cutscene." Then with a Studio screenshot: "Let's turn this into a black-and-white impact frame."
- "Now I want to add custom animation and trigger VFX using animation events. Please edit the script for me so it's easy to add animation IDs and inside marker events trigger visual effects."
- To Codex: "I've added blue hair, yellow hair, and purple hair into the wig inside hero. Check if they're welded correctly. During charge skill, enable blue hair at charge start and yellow hair at charge pulse. During storm skill, enable yellow hair at strike and purple hair at impact."
- No named skills or links beyond the description-linked MCP tutorial.

## Gotchas and fixes
- Animation Editor sometimes fails to load: reopen it.
- First ChatGPT impact frame was generic: feed it a Studio screenshot.
- Impact image had a rectangular border: recapture the scene without the border.
- Claude credit limit hit: paste the full conversation into Codex to continue.
- Animation event names in the animation must match the code's data structure exactly.

## Use it in our games
- Add a screen flash plus camera shake plus blur burst when a player hits a rebirth or buys a big upgrade in a simulator (inferred).
- Use animation event markers to trigger +1 popups or particles at exact frames of a punch/grab animation instead of timers (inferred).
- Neon-material swap trick for rarity glow: toggle a glowing variant of a brainrot's accessory per tier in a steal game (inferred).
- Use the black-and-white ink impact frame flashed via ImageLabel for a "legendary steal" or boss-kill moment (inferred).
- Keep the conversation-paste handoff in mind when switching between Claude and Codex mid-project.

---
tags: [roblox, video-notes, systems]
source: https://www.youtube.com/watch?v=yoh499oTE3E
creator: "ScriptedOcean"
video_id: "yoh499oTE3E"
---
# How to Make a Gun in Roblox Studio Using Claude AI

Back to [[00 Start Here]] · [[00 Video Notes Index]]

## TL;DR
Set up a toolbox pistol with a Configuration folder of number values and a named sound, then give Claude one long, detailed prompt to build a full gun system: server-side raycast damage, headshots, reload, ammo GUI, tracers, recoil. Every script reads the config values, so you can tune the gun without opening code.

## Tools and setup
- Roblox Studio (new experience), Studio Assistant button available but Claude used instead.
- Toolbox: search "pistol" (first result) and "gun sound" (audio tab, first result).
- Claude desktop app with Roblox Studio connected (ask "Can you connect to my Roblox game?"). Click Allow whenever Claude asks permission.
- Model: Opus 4.8 (any Opus works). Not recommended: Opus 3, any Sonnet, any Haiku (bad at complex Roblox systems).
- Test avatar: Avatar tab, Character, "my avatar" to load a copy of your avatar as a target.

## Step-by-step
1. [00:00] Open Studio and create a new experience.
2. [00:40] Open the toolbox, search "pistol", pick the first, insert it, and put it in StarterPack.
3. [01:00] Clean the gun: drag it into Workspace, press F to focus, delete invisible parts (dispenser, shell, shop) and any scripts or sounds. Keep the visible slide. Drag it back to StarterPack.
4. [01:30] In the gun Tool click plus, add a Configuration, rename it "config".
5. [02:07] Toolbox, Audio, search "gun sound", insert the first, make sure it is inside the Handle, rename it "fire".
6. [02:40] Open Claude, choose Opus model, ask it to connect to your Roblox game.
7. [03:00] Paste the full gun prompt (below) and let it work; click Allow on permission requests (sped up in the video, finished around [07:58]).
8. [07:58] Back in Studio test: Avatar, Character, my avatar. Press Play in test mode, press 1 to equip, aim at the dummy.
9. [08:30] Verify: body shot deals 5, headshot deals 20, ammo GUI updates (10 out of 12), dummy dies after enough hits.
10. [09:00] Test reload by tapping/clicking the ammo counter and by pressing R. Both go back to 12 out of 12.
11. [09:30] Stop, edit the config values under the gun, play again to confirm changes.
12. [10:05] Optional: ask Claude for muzzle flash or bullet drop.

## Exact settings and values
| Setting | Value | Notes |
|---|---|---|
| Body shot damage | 5 | Default in prompt |
| Headshot damage | 20 | Default in prompt |
| Magazine size | 12 | Default seen in test |
| Config values | damage, headshot damage, fire rate, reload time, magazine size | Number values inside "config" |
| Fire rate meaning | seconds between shots | Lower = faster |
| Test damage | 10 | Changed from 5 |
| Test fire rate | 0.01 | Very fast, "looks so bad" |
| Test headshot | 30 | Changed from 20 |
| Test magazine | 30 | Loaded 30 out of 30 |
| Test reload time | 3 seconds | |
| Sound name | fire | Inside the tool Handle |
| Config name | config | Configuration object in the Tool |

## Prompts and skills used
Opening chat message: "Can you connect to my Roblox game?"

Main prompt (as said): "Find the gun tool in starter pack. Build a complete gun system for it with raycast shooting, a reload system, and server side damage. Body shots should deal five damage and head shots should deal 20 damage. Make the ray cast ignore accessory parts like hats and hair so they don't block head shot. If a bullet hits any part attached to a character, count it as hitting that character, even if that part is inside another model. Use the tool's activated event for firing so it works on PC, mobile, and console. Keep the fire rate check on the server, but give it a small tolerance for lag so legitimate shots are never silently rejected, and only play the gunshot effects when the server confirms the shot. Add a bullet tracer for every shot that every player in the game can see. Every shot must also push the camera up slightly like real gun recoil. Do not skip this. Play the sound named fire inside the tool's handle every time the gun shoots. Create a screen GUI that shows the current ammo out of the magazine size and update it when the player fires and reloads. The gun should reload when the player presses R on their keyboard and also when the player taps or clicks the ammo counter, so it works on mobile too. Inside the config in the tool, create number values named damage, headshot damage, fire rate, reload time, and magazine size, where fire rate means the number of seconds between shots, and make every script read from those values so the gun can be customized without touching any code."

Follow-up ideas: add a muzzle flash or a bullet drop.

## Gotchas and fixes
- Gun models from the toolbox contain junk (invisible parts, scripts, sounds): clean them first.
- Weak models (Sonnet, Haiku, Opus 3) fail at complex Roblox systems; use Opus.
- Accessories can block headshots, so the prompt tells raycast to ignore them and to treat any part attached to a character as that character.
- The fire-rate check stays on the server but with lag tolerance so valid shots are not rejected.
- Fire rate 0.01 looks terrible, but it proves the config works.

## Use it in our games
- Reuse the "config of number values read by every script" pattern for any tool: pickaxe, tap power, brainrot-steal tool cooldowns (inferred).
- Server-confirmed actions plus visual effects played only after confirmation is a good anti-exploit habit for steal games (inferred).
- Copy the tap-the-counter-to-reload idea for mobile-friendly UI buttons in simulators (inferred).
- Write long, specific prompts listing exact numbers (5 and 20 damage) and names of objects (fire, config) so Claude has nothing to guess.

<!-- related:start -->
## Related

- Hubs: [[00 Video Notes Index]] · [[00 Build Router]] · [[03 Scripting & Systems]]
- Playbooks: [[Blueprint - Plus One Evolution]]
- More in Systems: [[Build an RPG in Roblox Studio With Claude MCP — HP Bars, XP System, Stats Panel & Enemy Spawner]]
<!-- related:end -->

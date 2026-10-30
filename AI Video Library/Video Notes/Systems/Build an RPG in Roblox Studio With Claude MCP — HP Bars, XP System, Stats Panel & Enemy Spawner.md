---
tags: [roblox, video-notes, systems]
source: https://www.youtube.com/watch?v=LH4DYB92qJs
creator: "MrWonderHow"
video_id: "LH4DYB92qJs"
---
# Build an RPG in Roblox Studio With Claude MCP — HP Bars, XP System, Stats Panel & Enemy Spawner

Back to [[00 Start Here]] · [[00 Video Notes Index]]

## TL;DR
Short architecture walkthrough: Claude writes Lua directly into Studio through the MCP plugin to build HP/MP/XP bars, a config-driven attribute system, XP/leveling with a power-1.5 curve, a stats panel, and four procedural enemy types with patrol/chase/attack AI. Prompts are not shown, only the resulting design.

## Tools and setup
- Claude with the Roblox Studio MCP plugin (writes scripts directly, no copy-paste).
- Roblox Lua (ModuleScript, Script, LocalScript, RemoteEvent, TweenService-style tweens, UIGradient).
- No external models: enemies are built procedurally.

## Step-by-step
1. [00:00] Status bar UI: HP bar top left, mana bar below, mini map bottom left. Claude creates frames, fill bars with gradient colours and live text labels (health BG frame, health fill with UIGradient).
2. [00:00] Attribute system, three scripts:
   - AttributeConfig: ModuleScript in ReplicatedStorage defining base stats (max HP, max MP, defense, speed, attack damage) and per-level growth.
   - CharacterAttributes: server Script that applies values to the character as Roblox attributes on spawn and syncs HP to the humanoid so normal damage still works.
   - HUDController: LocalScript listening for stat changes and updating bars with smooth tweens.
3. [01:00] XP and leveling: XP curve = base XP multiplied by level to the power of 1.5. On enough XP, server levels up, recalculates stats, gives a partial HP/MP restore, and fires a level-up RemoteEvent to the client.
4. [02:00] XP bar under the MP bar, tweened smoothly. Fix: HP bar colour too dark, asked Claude to change it.
5. [02:00] Stats panel: toggled by a stats button under the HP bar with a slide animation; shows attack, defense, speed, max HP, max MP, each with coloured icon, value label and proportional mini progress bar; refreshes on stat change and level up; dark purple RPG style.
6. [02:00] Enemies: slime, goblin, skeleton, dark knight, built procedurally (body parts, eyes, welds, humanoid, billboard health bar).
7. [03:00] AI states: patrol, chase, attack. Aggro range triggers chase; close enough triggers attack; defense reduces damage. Death plays a shrink animation, awards XP, respawns after 8 seconds.
8. [03:00] Polish: floating damage numbers above enemies, golden "+XP" text above the player.

## Exact settings and values
| Setting | Value | Notes |
|---|---|---|
| XP formula | base XP x level^1.5 | Early levels easy, scales up |
| Enemy respawn time | 8 seconds | |
| Enemy types | 4 | slime, goblin, skeleton, dark knight |
| Enemy AI states | 3 | patrol, chase, attack |
| Base stats | max HP, max MP, defense, speed, attack damage | Numeric values not stated |
| Stats panel stats | 5 | attack, defense, speed, max HP, max MP |

## Prompts and skills used
- No literal prompts quoted. Described asks: generate GUI frames, fill bars and gradient colours; fix the dark HP bar colour.
- Next planned part: combat animations and damage system.

## Gotchas and fixes
- HP bar colour too dark: asked Claude to fix the colour.
- Keeping humanoid health in sync: CharacterAttributes writes HP to the built-in humanoid so Roblox damage still works.

## Use it in our games
- Config ModuleScript with base stats plus per-level growth is a clean template for any +1 / stat sim (inferred).
- XP = base x level^1.5 is a ready progression curve for rebirth/level gates.
- Billboard bars, floating damage numbers and "+XP" text are cheap feedback for steal/brainrot games (inferred).
- Server-authoritative stats mirrored as attributes, client HUD tweens them: a safe pattern for exploit resistance.

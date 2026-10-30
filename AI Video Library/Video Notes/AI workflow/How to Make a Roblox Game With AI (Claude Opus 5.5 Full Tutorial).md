---
tags: [roblox, video-notes, ai-workflow]
source: https://www.youtube.com/watch?v=afuKhenJldY
creator: "SyphoDev"
video_id: "afuKhenJldY"
---
# How to Make a Roblox Game With AI (Claude Opus 5.5 Full Tutorial)

Back to [[00 Start Here]] · [[00 Video Notes Index]]

## TL;DR
Instead of asking one AI to write everything as code, give Claude Code one *skill* per discipline (code, UI, map, VFX, sound, animation, 3D models) plus MCPs (Studio control) and APIs (other AIs for images/3D). A master "create Roblox game" skill manages research, design and assembly. Every failure gets written down as a rule so it never repeats.

## Tools and setup
- Claude Code via the Claude desktop app (not the chat website); needs a Claude Pro plan, about 18 to 20 GBP a month. Model used: Claude Opus (keeps track of many moving parts on long jobs).
- Skills: folder with SKILL.md (name + description at top; only descriptions are always loaded, full instructions and reference files load on demand), plus a scripts folder of tested Python. Built-in "skill creator" skill interviews you and writes a first draft.
- MCP: Roblox Studio built-in MCP server (create objects, set properties, run code, screenshots, start play test, proper play-mode tools). A third-party Roblox MCP is the fallback if the official one breaks (third-party could not reach the game during play).
- Rojo: code lives as files on the computer and syncs into Studio.
- Cloudflare Workers AI API, model Flux Schnell (free tier) for images and UI icons.
- Hi3DGen (open-source, MIT licensed) image-to-3D mesh, run on Kaggle (30 free GPU hours/week, about 100 GPU seconds per asset). Tencent Hunyuan 3D rejected: license excludes the UK.
- Blender run headless to decimate meshes and bake detail to texture.
- Roblox Open Cloud API (key from Creator Hub) to upload finished models/images to the account.
- Checks: Rojo build, tests, linter, formatter. Discord giveaway of skills promised at 1K subscribers.

## Step-by-step
1. [00:00] Understand the three building blocks: skills, MCPs, APIs. Run everything through Claude Code desktop.
2. [02:01] Make a skill: create `.claude/skills/<name>/` (said "include/skills"), add SKILL.md with name + description and how you want the job done; or invoke "skill creator", tell it what you want, then iterate/test. Add a scripts folder of Python that fixed past issues.
3. [04:04] Connect Studio MCP: in Studio click the Assistant logo, three dots, Manage MCP servers, enable Studio's MCP server, copy the "Claude Code CLI" command, then in a Claude Code session say "I have an MCP running. Use this to connect." and paste.
4. [05:04] Set up image API (Cloudflare Flux Schnell) and 3D API (Hi3DGen on Kaggle).
5. [08:07] Roblox API key: create.roblox.com, Creator Hub, All tools, Open Cloud, API Keys, follow steps. Do NOT paste the token into Claude. Ask Claude how to store it as a secret environment variable via terminal so it can access it without it appearing in chat.
6. [09:07] Code skill: game rules (damage, upgrade costs) in own folder as plain numbers, no Roblox objects, so they test off-Studio. Every project must pass 4 checks (Rojo build ~1 second, tests, linter, formatter); the empty starter project must pass all four before any game code is written.
7. [11:11] Five standard code rules: code in files never typed in Studio; every tweakable number (speed, damage, prices) in one config folder; all player/server messages through one file listing every message name; list of traps from past failures; (plus the checks above).
8. [11:11] UI skill: write one spec; it generates a preview image, the actual UI file, and a Studio build script, so they cannot disagree. Every panel gets the "depth stack". Icons generated with Flux, not emojis. Checker tests 4 screen sizes.
9. [14:12] Train the UI skill on UIs you like (copy a top game's UI as a template).
10. [14:12] Map skill: uses raycasts and the game's real movement config to verify reachability; nine checks; models are Blender/3D meshes not plain parts; style trained on screenshots of a liked game (he used Realm-style anime texturing); optimise each model before import.
11. [17:14] VFX skill: harvest free toolbox VFX packs, classify into building blocks (ball, flame, beam) and compose; verify with "phase freeze" (fire the effect, wait an exact time, freeze particles, check start/middle/end).
12. [19:19] Sound skill: reuse a pre-harvested, named library of sounds (boom, fire, gunshot) and combine them, because API uploads are limited per month.
13. [20:19] Animation skill: poses as data (joint, rotation, time), Blender builds an R15/R6 rig animation, renders frames into a contact sheet that Claude inspects. Needs lots of trial and error; train on existing Roblox animations.
14. [21:20] 3D model pipeline: Flux image, Claude checks and re-prompts until good, send to Kaggle notebook (Hi3DGen), Claude checks all angles and regenerates if bad, result about 600k faces, decimate about 60:1 to 6 to 10k faces, bake lost detail as texture, upload via Roblox API.
15. [23:25] "Create Roblox game" master skill owns research, design and final assembly and manages the other skills.

## Exact settings and values
| Setting | Value | Notes |
|---|---|---|
| Claude Pro plan | about 18 to 20 GBP/month | needed for Claude Code |
| Kaggle free GPU | 30 hours/week | one asset about 100 GPU seconds |
| Raw 3D gen face count | about 600,000 faces | too many |
| Roblox mesh limit | 20,000 triangles per mesh | as stated |
| Decimated target | about 6,000 triangles (later "6 to 10k", about 60:1) | detail baked back as texture |
| Rojo build check | about 1 second | catches broken files |
| UI checker screen sizes | 4, small phone to full HD monitor | thumb-sized buttons |
| Centering tolerance | within 1.5 pixels | "1 and half a pixels" |
| Map checks | 9 | floating platforms, unreachable ground, traps, sight lines, overlaps, uneven rings, short falls |
| UI depth stack | blue-tinted shadow underneath, face gradient, top lift, uniform outline thickness | mixed outline thickness = beginner/AI giveaway |
| Skills installed | about 20 without memory clutter | only descriptions always loaded |

## Prompts and skills used
- "I have an MCP running. Use this to connect." (after pasting the Claude Code CLI command).
- "I have a Roblox API key to allow you to import assets into my game. Tell me how to store it as a secret variable on my machine, allowing you to access it, but not store it in the chat."
- Skills named: code, UI, map, VFX collector, sound, animation, 3D model, "create Roblox game", skill creator.
- Links/places: create.roblox.com Creator Hub, Open Cloud API keys, Cloudflare Workers AI, Kaggle, Rojo.

## Gotchas and fixes
- Claude cannot see play mode; screenshots work only in edit mode; only the output log comes back from a running game. Fix: make as much as possible checkable at rest (pure-number rules tested locally).
- Studio and files drifting apart killed an earlier version; fix: code only in files via Rojo.
- Official Studio MCP sometimes breaks; fall back to third-party MCP.
- Pasting a token into Claude stores it in chat; use env variable instead.
- Detail lost in decimation; bake it as texture.
- Hard-edge props (crates, guns) built directly in Blender, not via image-to-3D.
- AI UI uses emojis for icons and random boxes around buttons; enforced by checker rules.
- Check model licenses (Hunyuan excludes UK).

## Use it in our games
- Put all tunables (+1 per second rate, upgrade costs, rebirth multipliers) in one config file and keep the economy math as plain-number Lua testable outside Studio (inferred).
- Build a checker skill for our UI: verify tap-size, spacing and centering at several screen sizes (the video's checker rules) for simulator shop and rebirth screens.
- For steal-a-brainrot style maps, run a reachability/raycast check (can you get there and back, fall length) on base plots and steal paths.
- Use the phase-freeze method to verify short pickup/steal VFX bursts, and the depth-stack for consistent cartoony buttons.
- Write every recurring bug as a rule in the skill so later sessions do not repeat it (inferred for our repo).

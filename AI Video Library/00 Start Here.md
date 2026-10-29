---
tags: [roblox, ai, video-library, index]
updated: 2026-10-29
---

# Roblox × AI Video Library: Start Here

A curated set of the best videos on building Roblox games with AI, split by discipline. The goal is to ship games fast.

> [!info] How this was built
> Collected from YouTube searches on 2026-10-29. Every entry was checked against its video page (title, creator, date, what it covers). The "Key takeaways" come from the video pages and descriptions. I did not watch the videos end to end, so take the notes as a guide to what's inside. YouTube often hides view counts from scrapers, so they're listed only where available.
> ⭐ = must-watch.

## Sections

- [[01 Setup & Workflow]]: connect Claude, Codex or Cursor to Studio (MCP, Rojo, skills)
- [[02 Full Game Builds]]: start-to-finish AI game builds you can copy
- [[03 Scripting & Systems]]: combat, RPG stats, guns, procedural systems
- [[04 Building, Maps & 3D Models]]: AI meshes, Blender MCP, maps, textures
- [[05 VFX]]: auras, slashes, anime skills, cutscenes
- [[06 Animation]]: AI keyframing, mocap from video, procedural IK
- [[07 UI & GUI]]: AI-generated GUIs and GUI art
- [[08 Thumbnails, Icons & Marketing]]: high-CTR thumbnails and icons with AI
- [[09 Audio]]: AI sound effects and music
- [[10 Business, Monetization & Case Studies]]: what actually made money
- [[11 Creators to Follow]]
- [[12 Official Docs & Tools]]

## The 10-video crash course (watch in this order)

1. ⭐ [How to Make a Roblox Game With AI (Claude Opus 5.5 Full Tutorial)](https://www.youtube.com/watch?v=afuKhenJldY), SyphoDev. The most complete modern pipeline: Claude Code, skills, Studio MCP, Rojo, Open Cloud, AI images and 3D.
2. ⭐ [How to Connect Claude & Codex to Roblox MCP Server (Official Built In Setup)](https://www.youtube.com/watch?v=a5Djoa_gUJs), MrWonderHow. Setup with Studio's built-in MCP, no third-party plugin.
3. ⭐ [Can AI Make an Entire Roblox Creature Capture Game?](https://www.youtube.com/watch?v=jJtZmZ3Hz9k), SyphoDev. Whole-game build: research, code, map, models, UI, sound.
4. ⭐ [I Tried Making a Viral Roblox Game With AI](https://www.youtube.com/watch?v=xxeNaxrfRVs), LanceyPoo (413K views). Plan, build, iterate with Claude, then test with paid ads.
5. ⭐ [How to Make VFX in Roblox with AI (Claude Opus 5.5 + FREE SKILL)](https://www.youtube.com/watch?v=-Ax_uc0x-UE), fwjelaa. Reference image + VFX skill gives an animated aura.
6. ⭐ [How to Make Roblox Animations With AI (R6 + R15)](https://www.youtube.com/watch?v=dlx_kf6jT08), SyphoDev. Claude writes keyframes, Blender checks them, Open Cloud uploads.
7. ⭐ [I Built a Roblox Pet RPG with Claude Opus 4 MCP + Roblox Studio MCP](https://www.youtube.com/watch?v=rMcsenUyOKY), MrWonderHow. Photo to 3D pet to rig to shop, summon and combat.
8. ⭐ [How I Make High Quality Roblox Thumbnails with AI](https://www.youtube.com/watch?v=az7em1IoBhA), Tizzy RBLX (47K views)
9. ⭐ [Roblox Studio Has Custom Skills Now](https://www.youtube.com/watch?v=5dY9z4gHIdY), ScriptedOcean. Reusable skills for Studio's own Assistant.
10. ⭐ [My Roblox Game Made $43,292 (Here's Exactly How to Monetize Yours)](https://www.youtube.com/watch?v=-PoyiiGhoNo), MoseyTube77

## The pattern every top video shares

1. **Agent + Studio MCP.** Claude Code, Codex or Cursor drives Studio directly: it reads the hierarchy, writes scripts, creates instances and runs playtests.
2. **Skills / SKILL.md files per discipline** (VFX, animation, UI, building). This is the biggest quality jump the creators show: "plain prompt vs. skill" comparisons win clearly for the skill.
3. **Rojo + Git** so code lives in files the agent can edit and you can roll back.
4. **Asset factory**: AI image (ChatGPT/GPT Image, Flux, Gemini), then image-to-3D (Meshy, Tripo, Hi3DGen, Roblox Cube), then Blender cleanup and decimation (often via Blender MCP), then Studio.
5. **Build one feature at a time, playtest, fix.** Keep backups before large automated changes.
6. **Ship and test with real players** (ads, short clips), then double down on what retains.

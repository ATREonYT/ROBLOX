---
tags: [build-playbooks, ai-tools, mcp, 2026-10]
updated: 2026-10-30
---

# 04 AI Tools Landscape October 2026

Back to [[00 Build Router]] · Deep notes: [[Roblox Studio MCP Server]], [[Roblox Studio Assistant]], [[Built-In Studio MCP vs Community MCP Servers - Migration Guide]], [[Evaluating AI Tools - A Practical Rubric]], [[01 Setup & Workflow]]

## Our stack (keep it)
1. **Claude Code + Roblox's official Studio MCP server** for anything inside Studio: read/edit scripts, run Luau, playtest, simulate player input, take screenshots, generate meshes and procedural models.
2. **Files in the repo** (Rojo layout, or our own "install into Studio" scripts like `cannon-evolution/`) so every change is in git and can be rolled back.
3. **Skills** in `.claude/skills/` + this vault for taste and rules.
4. **Blender (+ Blender MCP)** for props and pets; **Meshy/Tripo** image-to-3D only for organic shapes (remesh to about 3k triangles). See `blender-roblox-models` and [[Blender MCP]].
Third-party "AI game makers" mostly do the same thing with their own credits. They're only worth trying if a feature is missing from the stack above.

## Official Studio MCP: setup in 1 minute (Mac)
- Studio: Assistant > … > Manage MCP Servers > turn on **Enable Studio as MCP server**, then Quick connect your client.
- Or the JSON config: `"Roblox_Studio": { "command": "/Applications/RobloxStudio.app/Contents/MacOS/StudioMCP" }`.
- Green dot under "Enable Studio as MCP server" = connected. Restart both apps if not.
- Tools (Oct 2026): `script_read`, `multi_edit`, `script_search` (10 results), `script_grep` (50), `generate_mesh`, `generate_material`, `generate_procedural_model`, `search_asset`, `insert_asset`, `upload_image`, `store_image`, `subagent` (explore / playtest), `search_game_tree`, `inspect_instance`, `execute_luau`, `start_stop_play`, `get_console_output`, `screen_capture`, `character_navigation`, `user_keyboard_input`, `user_mouse_input`, `http_get` (Roblox docs only), `skill`, `list_roblox_studios`.
- Every call takes a `studio_id` (from `list_roblox_studios`). Connected clients can change your place, so connect only tools you trust.
- Source: [Connect to the Roblox Studio MCP server](https://create.roblox.com/docs/studio/mcp), read 2026-10-30.

## Roblox's own AI (built into Studio)
- **Assistant**: planning mode (asks questions, writes an editable plan), builds with Cube, playtests and self-corrects, has a built-in MCP client, and can use your own Anthropic/OpenAI/Gemini key. Procedural models are capped at 50 per 24 hours.
- **Cube 3D / 4D generation**: text to mesh; 4D adds working behaviour (Car-5, Body-1 schemas, beta).
- **Texture Generation Quality mode**: 4K PBR (beta, Oct 2026).
- **Scene Generator** and **NPC Dynamic Behavior**: late 2026. See [[03 What's New on Roblox - RDC 2026 and October]].
- **Roblox Build**: phone app maker for 2D/2.5D games (alpha in NZ, Serbia, Singapore). Not for us: editing in Studio removes Build status.

## Third-party tools (October 2026, prices as listed by their sites)
Compiled from [RoCode's 23-tool comparison](https://www.rocode.app/roblox-ai-plugin-alternatives) (RoCode is itself a vendor; treat it as a directory, not a review) and [Ropilot's comparison](https://ropilot.ai/blog/lemonade-vs-superbullet-vs-ropilot) (also a vendor).

| Tool | Type | Price (listed) | Note |
|---|---|---|---|
| BloxBot | Free desktop app → official MCP | Free, MIT | Bring your own AI; Win/Mac/Linux |
| ZeroScript | Browser extension + bridge → MCP | Free, GPL | Copycat sites exist; use the real repo |
| Ropilot | Desktop app + plugin | Plus $20/mo | Playtests, input sim, screenshots, Blender models and animations |
| SuperbulletAI | Desktop app, Rojo project on disk | 1M tokens/mo free; Pro $20 | Fits Rojo; video notes in [[Superbullet × Claude Opus 5.5 Is INSANE for Roblox Development]] |
| Lemonade | Prompt-to-game agent + plugin | No public prices | First drafts |
| RoCode | Web chat + plugin | 1 free credit/day; from $9.99 | No mesh generation |
| RoGenie | Plugin, 60+ models | Free tier; $5-99 | Widest tool list |
| Craftly | Plugin | Pro $14.99 | One-click undo of a whole build |
| Kiwari | Mac app, approve each change | Pro $19.99 | Mac only |
| Forge / ForgeBlox | Windows bridge | from $10 | Windows only |
| RoAgent | Windows app on your Claude/ChatGPT plan | 250 free actions | Windows only |
| HyperDevs, Picoo, Rebirth, Ropanion, RoAI, RoAssistant, RoStudio | assorted plugins and web apps | various | Check before paying; several say purchases are final |

**Rule:** never paste tokens or cookies into a chat; never install a plugin that asks for your Roblox cookie. See [[Safety Rules for AI Agents in Studio]] and [[Local vs Cloud AI - Keeping Unreleased Game Code Private]].

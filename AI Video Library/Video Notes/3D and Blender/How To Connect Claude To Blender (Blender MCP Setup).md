---
tags: [roblox, video-notes, 3d-blender]
source: https://www.youtube.com/watch?v=0PdIuWlxhHA
creator: "Think Tutorial"
video_id: "0PdIuWlxhHA"
---
# How To Connect Claude To Blender (Blender MCP Setup)

Back to [[00 Start Here]] · [[00 Video Notes Index]]

## TL;DR
Install the Blender connector in Claude Desktop, install the Blender MCP add-on by dragging the downloaded file into Blender, enable online access, start the MCP Bridge Server, then ask Claude to build things and iterate back and forth.

## Tools and setup
- Latest Blender (check Blender > About Blender; works on any version and OS).
- Claude (desktop app) Settings > Connectors (under Customize) > Add > Browse Connectors > search "Blender" > add > Install (may need a second Install click) > link button should show a check mark > enable toggle.
- Blender MCP add-on: search "Blender MCP" in a browser, open the MCP Server result with the Blender logo, scroll to "Add-on", Download.
- No prices stated.

## Step-by-step
1. [00:00] Update Blender; check version via About Blender.
2. [00:00] In Claude: Settings > Connectors > Add > Browse Connectors > search Blender > click + > Install.
3. [01:00] Confirm install progress completes, click the link button until it shows a check mark, ensure it is enabled.
4. [01:00] Click Configure to see permissions. Hand icon = ask first; check mark = always allow. Safer to set hand icons so it prompts before touching a project you have worked on for hours.
5. [02:00] Download the add-on. Do not open or extract it. Click-hold and drag the file into Blender; "Install from Disk, User Default" dialog appears; click OK.
6. [02:00] Verify: Edit > Preferences > Add-ons, search "MCP", checkbox should be ticked.
7. [03:00] If missing or not working, tick the box and drag the file again (may take two or three drags).
8. [03:00] Test by asking Claude "Are you connected to Blender?". If not, in Preferences > Add-ons, expand the MCP add-on and click "Start MCP Bridge Server".
9. [03:00] If it says online access must be enabled: Edit > Preferences > System > Network > Allow Online Access, then Add-ons > MCP > Start MCP Bridge Server again.
10. [04:01] Ask again; it should say it is connected.
11. [04:01] Ask Claude to build something (example: a simple house in the open project). Approve permission prompts. Claude asks clarifying questions (detail level: "basic block and roof"; delete default cube: yes).
12. [04:01] Iterate: ask for a bigger roof, different shape, color. Claude recaps and offers doors, windows, materials next.

## Exact settings and values
| Setting | Value | Notes |
|---|---|---|
| Permission icon: hand | Ask first | Recommended for safety |
| Permission icon: check mark | Always allow | e.g. Get Blend File Data Block Summary |
| Blender Preferences > System > Network | Allow Online Access | Required for the bridge |
| Install dialog | Install from Disk, User Default | Click OK |
| Add-on search term | MCP | Should show a check mark |

## Prompts and skills used
- "Are you connected to Blender?"
- Create a simple house structure in the current open project; answers: "basic block and roof", delete the default cube.
- Follow-ups like "No, I want the roof bigger", shape or color changes.

## Gotchas and fixes
- Do not extract or open the add-on download; drag the zip into Blender.
- Add-on may need dragging two or three times.
- Bridge server must be started manually via add-on > Start MCP Bridge Server.
- "Online access must be enabled" error: turn on Allow Online Access in System preferences.
- Default permissions auto-allow some actions; switch to hand icon to avoid damaging work.

## Use it in our games
- Use this connection to prototype low-poly props (crates, pets, base pieces) via prompt for our cartoony simulator (inferred).
- Iterate shapes conversationally, then export to Roblox as FBX (inferred; export not covered here).
- Keep the hand-icon permissions on while working in real project files (inferred).
- Good first test: ask Claude for a block-and-roof house, then a steal-game base plot piece (inferred).

<!-- related:start -->
## Related

- Hubs: [[00 Video Notes Index]] · [[00 Build Router]] · [[04 Building, Maps & 3D Models]]
- More in 3D and Blender: [[I Built a Roblox Pet RPG with Claude Opus 4 MCP + Roblox Studio MCP (Full Tutorial)]] · [[I Built a Roblox Vehicle Combat Builder Game Using Claude Opus 4.8 MCP + Roblox Studio AI]]
<!-- related:end -->

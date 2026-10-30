---
tags: [roblox, video-notes, ai-workflow]
source: https://www.youtube.com/watch?v=IJDg6tRJmHo
creator: "Leif"
video_id: "IJDg6tRJmHo"
---
# How Big Studios Develop on Roblox

Back to [[00 Start Here]] · [[00 Video Notes Index]]

## TL;DR
Set up a professional workflow: VS Code + Rojo (live sync to Studio), Rokit (toolchain manager), Wally (packages), Selene (linter), StyLua (formatter), and Git/GitHub (version control). Used on games with over 150 million plays.

## Tools and setup
- VS Code; Rokit (download from GitHub release, run .exe, restart PC); Rojo; Wally (package manager; wally-package-types); Selene; StyLua; Git; GitHub.
- VS Code extensions: Luau Language Server, Rojo, Selene, StyLua.
- Wally website for package paths (e.g. Promise; ProfileService server-only).

## Step-by-step
1. [02:00] Install VS Code, then Rokit (extract zip, run .exe, ignore unrecognized-app warning, restart).
2. [03:00] Create a Roblox Projects folder (e.g. in Documents) and a games folder; open it in VS Code.
3. [03:00] Install Luau Language Server and Rojo extensions.
4. [03:00] In the VS Code terminal: `rokit init`, `rokit add rojo`, `rojo init`.
5. [04:03] Edit default.project.json: remove everything under Workspace unless Rojo should control it. Code goes under src. File naming: `.server.luau` = Script, `.client.luau` = LocalScript, `.luau` = ModuleScript.
6. [04:03] Ctrl+Shift+P, search Rojo, open menu, install the Studio plugin (restart Studio), click the green arrow to start live sync, in Studio click the Rojo plugin and Connect; accept changes.
7. [05:04] Install Selene extension; create selene.toml with one line (given in description). Install StyLua.
8. [06:07] Ctrl+Shift+P, "user settings", JSON; paste the settings from the description so files auto-format on save.
9. [07:11] Luau Language Server settings: enable the Imports (auto-imports) option.
10. [07:11] Packages: `rokit add wally`, `rokit add wally-package-types`, `wally init`; edit wally.toml.
11. [08:11] Find packages on wally website, click install box to copy path, paste into the dependencies section (Pascal case names); server-only packages (e.g. ProfileService) go in a server-dependencies section.
12. [09:20] Run `wally install` (generates Packages and ServerPackages); add Packages under ReplicatedStorage and ServerPackages under ServerScriptService in the project JSON.
13. [10:21] Run the wally-package-types command to export types.
14. [10:21] Git: install, sign in once with the commands from the description (use the GitHub email); in Source Control initialize repository; add packages, sourcemap.json and wally.lock to .gitignore.
15. [12:27] Commit with a message, publish repository to GitHub; use feature branches (e.g. a tank class), pull requests, then pull merged changes locally.

## Exact settings and values
| Setting | Value | Notes |
|---|---|---|
| Rokit commands | `rokit init`, `rokit add rojo`, `rojo init` | |
| Wally commands | `rokit add wally`, `rokit add wally-package-types`, `wally init`, `wally install` | |
| File suffixes | `.server.luau`, `.client.luau`, `.luau` | Script, LocalScript, ModuleScript |
| Project JSON mapping | Packages in ReplicatedStorage, ServerPackages in ServerScriptService | |
| Gitignore | Packages, ServerPackages, sourcemap.json, wally.lock | |
| Selene config | one-line selene.toml (text in description, not read aloud) | |
| Experience scale | games with over 150 million plays | claim |

## Prompts and skills used
No AI prompts. Commands, settings JSON and links are in the video description (not read aloud). Tools named: Rokit, Rojo, Wally, Selene, StyLua, Git/GitHub.

## Gotchas and fixes
- Windows warns Rokit is unrecognized; ignore. Restart after installing Rokit.
- Restart Studio after installing the Rojo plugin.
- Wally does not export types automatically; run wally-package-types.
- Without version control, deleted work can't be recovered; multiple devs overwrite each other in Studio.
- Remove Workspace contents in the project JSON unless Rojo should manage them.

## Use it in our games
- This is the same Rojo file-based setup our AI workflow depends on (the AI-workflow videos use Rojo); keep code in files and sync to Studio.
- Add Selene and StyLua to catch errors and format on save before AI-written code reaches Studio (inferred).
- Use Git branches per feature (e.g. a new rebirth or steal mechanic) and commit restore points.
- Use Wally packages such as ProfileService for saving data in simulators (video names it as a server-only package).

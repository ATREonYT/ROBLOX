---
tags: [sector-brief, ai-tools, mcp, studio-assistant, tooling, rojo, testing, debugging, workflow]
updated: 2026-10-30
---
# Brief - AI Workflow, Tooling and Testing
Back to [[00 Build Router]] · All briefs: [[Sector Briefs Index]]

> TL;DR
> - **Our stack stays:** Claude Code + Studio's built-in MCP server for anything inside Studio; code as files in git (Rojo layout); offline Lune checks before every commit; a rebuilt `.rbxl` for the owner to test. The tool list and setup are in [[04 AI Tools Landscape October 2026]]; this brief covers how to work well with them.
> - **Every MCP call needs a `studio_id`.** Call `list_roblox_studios` first in every session and pick the window by place ID. The id changes when Studio restarts. `set_active_studio` was removed in August 2026.
> - **Name how each change was checked:** offline spec, Edit probe in Studio, MCP playtest, the owner in Play, or a live server. "Done" with no named check is a guess. MCP screenshots leave out BillboardGuis, ProximityPrompts and sometimes the HUD, so never judge UI from them.
> - **Playtests and Edit tools fight.** While Play runs, Edit-datamodel calls fail, and `start_stop_play` stops everyone's test. Check `get_studio_state` first, and never stop a test the owner started.
> - **Keep Studio calls short** (about 1.5 s or less each) and build big things in stages, with a resume index. Heavy logic belongs offline in Lune.
> - **New in Oct 2026:** Package Overrides (Studio beta, Oct 15), Device Simulator and Network Simulator out of beta (Oct 12-18 recap), early testers (up to 10 friends) before publishing. Announced for later: Observability Platform and Scene Generation (late 2026), Branch and Merge (early 2027).
> - **Skills are the lever.** Studio Assistant has creator-authored skills (July 2026). They also reach Claude Code through the MCP `skill` tool. Write the house rules once (kid-safe money, no invented IDs, server-only grants) as a skill and as `CLAUDE.md`.

## Current state (Oct 2026): what's new, renamed or deprecated

| Change | Status | Date and source | What it means for us |
|---|---|---|---|
| Built-in Studio MCP server | Live; the recommended path | DevForum, 5 Mar 2026 | No plugin needed. Turn it on in Assistant > ... > Manage MCP Servers > Enable Studio as MCP server |
| Open-source `Roblox/studio-rust-mcp-server` | Archived (read-only) | Vault note [[Roblox Studio MCP Server]] (3 Apr 2026) | Old tutorials use `run_code`, `insert_model`, `get_studio_mode`, `run_script_in_play_mode`. These tools no longer exist. Use `execute_luau`, `insert_asset`, `get_studio_state` and `start_stop_play` + `get_console_output` |
| `studio_id` on every call; `set_active_studio` removed; place ID in `list_roblox_studios` | Live | DevForum, 19 Aug 2026 | Restart Claude Code once after Studio updates itself so it picks up new tools |
| Connected-clients tooltip in Assistant Settings > MCP Servers | Live | DevForum, 19 Aug 2026 | First thing to check when the agent "stops responding" |
| Playtest automation tools (`start_stop_play`, `get_console_output`, `user_mouse_input`, `user_keyboard_input`, `character_navigation`) | Live | DevForum, 5 Mar 2026 | `character_navigation` moves the character directly and **bypasses the input system**. Use keyboard/mouse input to test real controls |
| `screen_capture` | Live; works in Edit and Play (docs) | Roblox docs; DevForum 19 Mar 2026 | Captures were switched to JPEG after they went over Claude's 1 MB tool-result limit |
| Playtest Agent (`subagent` type `playtest`) | **Beta**: File > Beta Features > Playtest Agent | DevForum, 9 Apr 2026 | Runs on a Roblox-hosted model, not your tokens. Has a daily cap. Returns Pass / Fail / Inconclusive / Error |
| Assistant: Planning Mode (`/plan`) | Live | Roblox docs (Assistant guide) | Plans are editable Markdown and run only when you click Build |
| Assistant: bring your own key (Anthropic, OpenAI, Gemini) | Live | DevForum, 21 Feb 2026 | ... > Manage API Keys. The key is stored on your device |
| Assistant: creator-authored Skills | Live | DevForum, 9 Jul 2026; Roblox docs | Tied to your account, not to a place. Place-scoped skills are on the roadmap |
| Assistant: MCP **client** (connecting Assistant to Blender, Figma and other servers) | **Unconfirmed** | Listed as "next up" in DevForum 21 Feb 2026. Tech press says it is built in. No docs page found | Don't plan around it. Claude Code already connects to both Studio and Blender |
| Texture Generation Quality mode (4K PBR) | Beta | DevForum recap, 12-18 Oct 2026 | `/generate_texture` in Assistant |
| New Device Simulator toolbar + Network Simulator | **Out of beta** (the docs page still says beta) | DevForum recap, 12-18 Oct 2026; announced 9 Sep 2026 | Switch devices mid-playtest; latency, jitter and loss profiles |
| Package Overrides | **Studio beta**, Studio 743+ | DevForum, 15 Oct 2026 | Local edits to a package survive source updates. Scripts are overridden whole, not merged |
| Early testing (invite up to 10 friends or group members before publishing) | Live | DevForum recap, 12-18 Oct 2026; RDC26 post | Lets kids test before launch without going public |
| Observability Platform (client session traces, logs, troubleshooting in Studio) | Announced, **late 2026** | DevForum "RDC26: What We Announced", 11 Sep 2026 | Not usable yet. Meanwhile use the Creator Hub error reports and our own tagged logs |
| Branch and Merge (place branches, merge at property and script-line level) | Announced, **early 2027** | Same RDC26 post | Until then: git for code, one Studio editor at a time for the world |
| Test Teleports (teleport between places in Studio) | Announced, early 2027 | Same RDC26 post | Multi-place games still need a live test |

## The recipes (how we build X)

### 1. Start every Studio session the same way
1. Make sure Studio is updated and the MCP toggle is on. Look for the green indicator with the client count.
2. `list_roblox_studios`: choose by **place ID**, not window title.
3. `get_studio_state`: you must be in **Edit**. If the owner is in Play, work offline and check again in a few minutes.
4. Make sure Version History has a fresh save (File > Save to Roblox) before any bulk change.
5. Read the game's `CLAUDE.md` and handoff/state file. Don't re-read whole folders.

Claude Code hookup on a Mac (CLI form of the docs' JSON entry; Claude Code also has Quick Connect):
```
claude mcp add Roblox_Studio -- /Applications/RobloxStudio.app/Contents/MacOS/StudioMCP
```
Tools then show up as `mcp__Roblox_Studio__execute_luau`, and so on. Write permission rules against those names.

### 2. Edit code: files first, Studio second
- **Source of truth is the repo.** Edit `src/` files, run the offline checks, rebuild the place file, commit. Use MCP `multi_edit` only for quick probes or when the owner is live in Studio. Then copy the change back into the repo in the same turn.
- Before using `multi_edit` on a script the owner may have touched, re-read it with `script_read` (a line range for big scripts).
- To audit, use `script_grep` (up to 50 matches) instead of reading scripts. To find a script by name, use `script_search` (up to 10).
- To read a module's **current** values after an edit, clone-require it. `require` caches per instance:
```lua
--!strict
local function freshRequire(module: ModuleScript): any
	local clone = module:Clone()
	clone.Parent = module.Parent -- keeps script.Parent lookups working
	local ok, result = pcall(require, clone)
	clone:Destroy()
	if not ok then error("fresh require failed: " .. tostring(result)) end
	return result
end
return freshRequire(game:GetService("ReplicatedStorage").Shared.GameConfig).Version
```

### 3. Build big things in stages (staged builds)
One giant `execute_luau` freezes Studio for everyone. Use one stage per call, each well under a time budget, and return a resume index:
```lua
--!strict
local BUDGET = 1.2 -- seconds; stays under the ~1.5 s rule (Vault note)
local function placeFrom(items: {BasePart}, startIndex: number, parent: Instance): string
	local t0 = os.clock()
	for i = startIndex, #items do
		items[i].Parent = parent
		if os.clock() - t0 > BUDGET then
			return ("[BUILD] stopped early resume=%d of %d"):format(i + 1, #items)
		end
	end
	return ("[BUILD] done %d"):format(#items)
end
```
For scripts too large for a tool call (100 KB and up), ship a **Command Bar script** or "Save as Local Plugin" script that the owner pastes once (repo rule in `CLAUDE.md`).

### 4. Scripts the owner runs in Studio (Command Bar pattern)
Every Studio-side helper reports on **tagged Output lines**, so the owner can screenshot one block. Never pop a red box on screen (the owner's rule, Oct 19). Wrap each part in `pcall` so one failure can't stop the rest:
```lua
--!strict
local TAG = "[EGGRUN-SETUP]"
local function step(name: string, fn: () -> ())
	local ok, err = pcall(fn)
	print(("%s %s %s"):format(TAG, ok and "OK" or "FAIL", name), ok and "" or tostring(err))
end
step("folders", function()
	local f = Instance.new("Folder")
	f.Name = "Eggs"
	f.Parent = workspace
end)
print(TAG, "finished")
```
To get the owner's Studio state, use `tools/export-for-claude.lua` (Command Bar), which writes `ServerStorage > ClaudeExport > PartN`.

### 5. Test ladder (cheapest first; always say which rung you reached)
1. **Offline compile + specs (Lune).** `bash tools/check.sh` in the game folder compiles every script and runs `tests/*.spec.luau` plus a full-loop sim. Install Lune 0.10.5 from the lune-org GitHub releases (line in the game's `CLAUDE.md`). Lune's copy of the Roblox API is out of date, so a clean run doesn't prove Studio works.
2. **UI checks + HTML preview** (`tools/preview/check.sh`, Playwright renderer) next to the reference picture.
3. **Edit probe via MCP:** `execute_luau` in Edit, `inspect_instance` to confirm an edit landed.
4. **MCP playtest:** `start_stop_play` → `user_keyboard_input` / `user_mouse_input` → `get_console_output` → stop. Or ask for the **playtest subagent** with one concrete scenario: "use the playtest subagent to check a player can buy the Common Egg and a pet appears". Treat Pass as a hint, not proof.
5. **Device + Network Simulator** (Test > Device Simulator): one phone, one tablet, then the "Bad Connection (3G)" profile.
6. **The owner in Play** (purchase prompts, look and feel), then a **private live server** for anything live-only: real asset IDs, DataStores, teleports, animation playback by uploaded ID.

Unit tests in Studio: the Roblox `rbx-unit-test` skill uses Jest-Lua or TestEZ if it finds one, and otherwise its own small harness. Test pure logic (odds, prices, rebirth formulas, save migrations), not glue code. Inject the clock and the RNG so tests are repeatable.

### 6. Debugging recipe
1. **Reproduce** in the smallest case. Read the Output with `get_console_output`.
2. Read the first error and its stack, not the last one. See [[Reading Luau Errors and Stack Traces]].
3. Check the data before you "fix" anything (repo rule 5): history, camera angle, an earlier request from the owner.
4. **Live:** Developer Console (F9). The server views need edit permission. Use the MicroProfiler (Ctrl+F6, or Ctrl+Alt+F6 on some doc pages) for hitches: capture 30-90 frames, not one.
5. Add tagged `print`s behind a debug flag rather than leaving noisy logs.

### 7. Skills and prompts that make AI output good
- **Studio Assistant skill format** (account-wide): one Markdown doc with single-line `name` (lowercase, no `rbx-` prefix), single-line `description`, optional `enabled`. Other frontmatter fields are ignored. The body holds the instructions. Assistant loads a skill when the request matches the description, or when you type `/` and pick it.
```markdown
---
name: kid-safe-shop
description: Use when adding or changing any shop, developer product, game pass, crate or paid random item.
---
- Grant only in the single server ProcessReceipt; once per PurchaseId; return PurchaseGranted only after the save.
- Never invent product, pass or asset IDs: leave 0 and list them for the owner.
- Paid random items show odds and a pity counter. No fake timers or stock.
- Items that do nothing yet show "coming soon" and never open a purchase.
```
- Built-in read-only skills: `rbx-create-skill`, `rbx-debug`, `rbx-device-simulator-lua`, `rbx-docs-search`, `rbx-perf-profiling`, `rbx-scene-analysis`, `rbx-unit-test`. To customize one, duplicate it. The copy stops getting Roblox updates.
- **Prompt shape that works:** context (game, file paths), rules (link the skill), API era ("Oct 2026: `*Async` APIs, `TextChatService`, `InputAction`"), and what "done" means ("compiles, spec X passes, report what was not play-tested").
- **Handoff notes:** end every session with a short state file. Cover what works and how it was verified, what is in progress, what is broken, decisions with dates, and do-not-touch items. See [[Agent Handoff Notes - Project State and Resume Templates]].
- **Checker rules beat instructions.** Turn a rule into a grep or spec that fails (for example: no `Enum.ProductPurchaseDecision.PurchaseGranted` before the save call; no non-zero asset IDs that aren't in the owner's list). Rules that only live in prose get forgotten.
- **Fresh critic:** a second agent compares against the reference and lists the worst gaps first, before the owner sees anything.

### 8. Rojo, packages and git
- Rojo maps **code containers only**. Never `$path` the whole Workspace unless `$ignoreUnknownInstances` is set. Set `servePlaceIds` to the dev place so a live sync can't hit the real game.
- `rojo sourcemap default.project.json -o sourcemap.json --watch` feeds luau-lsp. `rojo syncback` (Rojo 7.7) pulls instances from a place file into the project; review its diff.
- Pin tools in `rokit.toml` (Rokit also reads `aftman.toml` and `foreman.toml`). Commit `wally.lock`, `selene.toml`, `stylua.toml`, `.luaurc`. pesde is an alternative package manager; pick one per repo.
- **Packages for shared systems across our games** (for example one pet system): Package Overrides beta lets each game keep local tweaks and still get updates. Everyone in Team Create must enable the beta. Turning it off may lose recorded overrides. Script overrides are all-or-nothing.
- The owner commits with GitHub Desktop. Agents never commit `.rbxl` as the source of truth. The built place file in `<game>/places/` is a deliverable for testing.

## Numbers and limits

| Item | Value | Source |
|---|---|---|
| `script_search` results | up to 10 | Roblox docs (Studio MCP page) |
| `script_grep` matches | up to 50 | Roblox docs (Studio MCP page) |
| MCP quick-connect clients | Antigravity, Codex CLI, Claude Code, Claude Desktop, Cursor, Gemini CLI, VS Code | Roblox docs (Studio MCP page) |
| `screen_capture` result | switched to JPEG to fit a 1 MB client limit | DevForum (19 Mar 2026) |
| Playtest Agent run length | aborts after 50 turns; ends early on repeated identical calls | DevForum (9 Apr 2026) |
| Procedural models (Assistant) | 50 per rolling 24 h; up to 8 parts per model | Roblox docs (Assistant guide) |
| `/segment_mesh` | up to 5 part names per run | Roblox docs (Assistant guide) |
| Generated mesh triangles | default 10,000; small props 100s to 1K suggested | Roblox docs; DevForum (19 Mar 2026) |
| Time per `execute_luau` call | about 1.5 s or less, one call at a time | Vault note [[Roblox Studio MCP Server]] (measured) |
| Script `Source` size | 200,000 characters hard limit | Vault note [[Roblox Studio MCP Server]] (measured) |
| Script Sync | 10,000 scripts per synced root, 128 roots | Vault note [[External Tooling - Rojo Wally Selene StyLua]] (Docs) |
| Rojo default serve port | 34872 | Vault note [[External Tooling - Rojo Wally Selene StyLua]] |
| Package Overrides | Studio 743+; package version history now shows more than 50 versions | DevForum (15 Oct 2026) |
| Early testers before publish | up to 10 friends or group members | DevForum recap (12-18 Oct 2026) |
| Device Simulator custom device | pixel density 72-10,000; max 7680 x 4320 px | Roblox docs (Device Simulator) |
| Network Simulator "Bad Connection (3G)" | 150 ms / 70 ms jitter / 0.50% loss in; 180 / 90 / 0.50% out | Vault note [[Testing Modes - Play Run and Multi-Client]] (not re-verified) |
| MicroProfiler server capture | max 60 frames, max 4 s start delay | Vault note [[MicroProfiler Guide]] |
| MicroProfiler sample size to judge | 30-90 frames | Vault note [[MicroProfiler Guide]] (rule of thumb) |
| Lune version used by our harness | 0.10.5 | Repo `CLAUDE.md` / `huzz-valley/CLAUDE.md` |
| Render rounds per change | at most 2, one picture | Repo `CLAUDE.md` (owner rule) |

## Pitfalls (what AI models and beginners get wrong)
- **Stale tool names from 2025 tutorials:** `run_code`, `insert_model`, `get_studio_mode`, `run_script_in_play_mode`, `set_active_studio`. None of these exist on the built-in server.
- **Caching `studio_id`** across a Studio restart. You may end up talking to the wrong open place.
- **Calling `start_stop_play` while the owner is testing** ends his test. Users also report start/stop failing after several runs (DevForum, 19 Aug 2026). If it sticks, ask the owner to press Stop, then restart the client.
- **Trusting screenshots.** A black image means Studio wasn't in front. In Play, captures leave out BillboardGuis, default ProximityPrompts, the top bar and sometimes ScreenGui HUDs (DevForum bug report, 14-16 Jul 2026). Verify numerically and say so.
- **Using `character_navigation` as an input test.** It moves the character directly. Controls bugs only show with `user_keyboard_input` / `user_mouse_input`.
- **"Playtest agent passed, ship it."** Roblox itself warns about false passes. The agent isn't real-time, so it fails fast-reaction tasks, and it struggles with UI selection and the camera.
- **`require` in tool context returns old values** after an edit. Use clone-require.
- **One huge build call** freezes Studio. Use staged calls with resume indexes.
- **Studio-only success:** temporary `KeyframeSequenceProvider` animation IDs, mock ProfileStore, and local asset paths all work in Studio and fail live. Label them "Studio only" and give the owner a live checklist.
- **Clean Lune run ≠ working in Studio.** Lune's API dump is old. Start each UI piece separately and log failures on tagged lines.
- **Inventing IDs to make the code run.** Never. Use 0 or empty plus a checklist line (repo rule).
- **Inserting Creator Store assets** with `insert_asset` without reading their scripts.
- **Assuming Assistant skills are always on** like `CLAUDE.md`. They load only when the description matches. Write descriptions as "Use when ...".
- **Package edits without the beta** still fork the copy. With the beta, a changed script is skipped on updates rather than merged.
- **Network Simulator left on** makes every later test feel laggy. Reset it after the pass.
- **Committing secrets:** never paste API keys or `.ROBLOSECURITY` cookies into chats, skills or repos. Cloud sessions can't reach apis.roblox.com anyway.

## Checklist before shipping
- [ ] Offline: `tools/check.sh` and `tools/preview/check.sh` pass; the place file is rebuilt and the download link is given.
- [ ] Every change report says how it was verified (rung 1-6) and lists what was **not** play-tested.
- [ ] `script_grep` sweep: no `PurchaseGranted` before the save; exactly one `ProcessReceipt`; no hard-coded non-zero IDs except the owner's; no `KeyframeSequenceProvider` in live paths.
- [ ] MCP playtest of the core loop (spawn → earn → buy → rebirth) with real keyboard/mouse input, and Output clean of errors.
- [ ] Device Simulator: one phone, one tablet, one desktop; the Network Simulator 3G pass; simulator reset afterwards.
- [ ] Odds and pity visible on every paid random item; no fake timers; at most 1 flash per second.
- [ ] Owner checks purchase prompts and the look in Play; then a private live server for DataStores and real asset IDs.
- [ ] Early testers (up to 10) before going public, if the owner wants it.
- [ ] Developer Console (F9) on the live server: no server errors after the first round.
- [ ] Handoff/state file updated; tools, previews and notes committed (temp folders vanish).

## Go deeper
- MCP server tool by tool, gotchas: [[Roblox Studio MCP Server]] · migration from old servers: [[Built-In Studio MCP vs Community MCP Servers - Migration Guide]] · client setup: [[Setting Up MCP Clients]]
- Working rules and multi-agent: [[Safety Rules for AI Agents in Studio]], [[Multiple Agents in One Studio]], [[Agent Review Loops and Guardrails in Practice]], [[Agent Orchestration - Sub-Agents, Hooks and Skill Costs]]
- MCP workflows: [[MCP Workflows for Scripting and Debugging]], [[MCP Workflows for Building Worlds]], [[Studio Plugins and Local HTTP Bridges]]
- Assistant: [[Roblox Studio Assistant]], [[Roblox Built-In AI Tools Timeline 2023-2026]] · skills video: [[Roblox Studio Has Custom Skills Now (Here's How To Make One)]]
- Prompting and verification: [[Prompting and Verifying AI Output]], [[AI Pitfalls - Stale APIs and Luau]], [[What AI Models Get Wrong in Roblox]], [[Agent Handoff Notes - Project State and Resume Templates]], [[AI-Ready Project Boilerplate - Repo Layout Agents Navigate Well]]
- Tooling and git: [[External Tooling - Rojo Wally Selene StyLua]], [[Git and Source Control for Roblox]], [[Packages and Asset Reuse]], [[Packages and Shared Assets Across Places]], [[Command Bar and Studio Scripting]], [[Version History and Backups]]
- Testing: [[Automated Testing with TestEZ and Jest-Lua]], [[UI Automation with VirtualInput and StudioTestService]], [[Testing Modes - Play Run and Multi-Client]], [[Multi-Client and Device Playtesting Protocols]], [[Save Migration Tests - Fixture Saves and Golden Files]], [[Testing Time-Based Features with a Controllable Clock]], [[Automated Luau Checks - LihFolk Hook and Audit]], [[QA Checklists Before Release]]
- Debugging: [[Debugging Start Here]], [[The Debugging Method - Reproduce Isolate Bisect]], [[Reading Luau Errors and Stack Traces]], [[Debugging Client-Server Desync]], [[Debugging Live Servers]], [[Developer Console and Stats]], [[MicroProfiler Guide]], [[Crash and Error Telemetry]], [[Gated Tester Commands and Debug Panels]], [[Network Performance]]
- Videos and landscape: [[01 Setup & Workflow]], [[12 Official Docs & Tools]], [[How to Make a Roblox Game With AI (Claude Opus 5.5 Full Tutorial)]], [[04 AI Tools Landscape October 2026]], [[03 What's New on Roblox - RDC 2026 and October]]
- Privacy: [[Local vs Cloud AI - Keeping Unreleased Game Code Private]] · costs: [[Token Cost Benchmarks]]
- Repo skills: `.claude/skills/` (`roblox-cartoony-ui`, `roblox-cartoony-building`, `roblox-vfx`, `roblox-ai-animation`, `blender-roblox-models`), `LihFolk/skills/roblox-debugging`, `LihFolk/skills/roblox-monetization-compliance`. Harness examples: `huzz-valley/tools/check.sh`, `huzz-valley/tools/preview/`, `huzz-valley/tools/place/build_place.sh`.

## Sources
All read 2026-10-30.
- https://create.roblox.com/docs/studio/mcp (Connect to the Roblox Studio MCP server)
- https://create.roblox.com/docs/assistant/guide (Assistant guide: Planning Mode, slash commands, limits)
- https://create.roblox.com/docs/assistant/skills (Assistant skills)
- https://create.roblox.com/docs/studio/device-simulator (Device Simulator)
- https://devforum.roblox.com/t/studio-mcp-server-updates-and-external-llm-support-for-assistant/4415631 (21 Feb 2026)
- https://devforum.roblox.com/t/assistant-updates-studio-built-in-mcp-server-and-playtest-automation/4474643 (5 Mar 2026)
- https://devforum.roblox.com/t/assistant-updates-mesh-generation-new-mcp-server-tools-screenshot-tool-and-more/4527258 (19 Mar 2026)
- https://devforum.roblox.com/t/studio-beta-studio-assistant-mcp-playtest-agent/4566767 (9 Apr 2026)
- https://devforum.roblox.com/t/assistant-updates-introducing-creator-authored-skills/4728447 (9 Jul 2026)
- https://devforum.roblox.com/t/mcp-screencapture-omits-billboardgui-default-proximityprompt-and-roblox-top-bar-ui-during-play-mode/4736693 (14-16 Jul 2026)
- https://devforum.roblox.com/t/studio-mcp-multi-agent-improvements-and-connected-ai-clients/4820583 (19 Aug 2026)
- https://devforum.roblox.com/t/studio-beta-new-device-simulator-toolbar-and-network-simulator/4861695 (9 Sep 2026)
- https://devforum.roblox.com/t/rdc26-what-we-announced/4865880 (11 Sep 2026)
- https://devforum.roblox.com/t/studio-beta-package-overrides-and-usability-improvements/4936628 (15 Oct 2026)
- https://devforum.roblox.com/t/weekly-recap-october-12-18-2026/4938638 (Oct 2026)
- https://thenextweb.com/news/oblox-ai-assistant-agentic-tools-planning-procedural-models (2026, third-party)
- Not re-verified this pass (web fetch budget ran out): Rojo, Rokit, Wally, pesde, StyLua, Selene and luau-lsp release versions. These come from the vault note [[External Tooling - Rojo Wally Selene StyLua]].

## Vault corrections
- **[[Packages and Shared Assets Across Places]]**, **[[Team Collaboration Start Here]]**, **[[Team Create Permissions and Workflows]]**. Claim: package overrides and native branching are "unconfirmed" and come only from a third-party summary. Correction: Package Overrides is an official Studio beta (DevForum, 15 Oct 2026; Studio 743+, File > Beta Features > Package Overrides; scripts overridden whole). "Branch and Merge" is in the official "RDC26: What We Announced" post (11 Sep 2026), dated early 2027.
- **[[Testing Modes - Play Run and Multi-Client]]** (and the "beta" mention in Studio Settings and Shortcuts). Claim: the Network Simulator and new Device Simulator are beta, enabled via File > Beta Features. Correction: out of beta per the DevForum Weekly Recap of 12-18 Oct 2026. The docs page still says beta, so the beta toggle may no longer be needed.
- **[[Roblox Studio MCP Server]]** section 5.4. Claim: only AlwaysOnTop BillboardGuis are missing from captures. Correction: a 14-16 Jul 2026 bug report says Play-mode captures leave out BillboardGuis, default ProximityPrompts and the top bar, and sometimes ScreenGui HUDs. No staff fix was seen.
- **[[04 AI Tools Landscape October 2026]]**. Claim: Assistant "has a built-in MCP client". Correction: Roblox's own post (21 Feb 2026) listed it as "next up". Only third-party press says it shipped, and we found no docs page, so mark it unconfirmed. Also, that note's tool list leaves out `get_studio_state` and `wait_job_finished`, which are on the docs page.
- **[[Roblox Studio Assistant]]**. Gap: it doesn't cover creator-authored Skills (9 Jul 2026), the frontmatter rules (single-line `name`/`description`, no `rbx-` prefix, account-scoped) or the built-in `rbx-*` skills.

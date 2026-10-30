---
tags: [build-playbooks, ai-workflow, prompting, claude-code, process]
updated: 2026-10-30
---

# 08 Few-Prompt Game Building with AI

Back to [[00 Build Router]] · Tools and setup: [[04 AI Tools Landscape October 2026]] · Full workflow brief: [[Brief - AI Workflow, Tooling and Testing]] · New game starter: [[05 New Game Kit]]

**The owner's goal (Oct 30):** "produce good quality games within a few prompts".

AI output is only as good as three things:
1. **what it can read** (this vault);
2. **what it is asked** (the prompt);
3. **what it can check** (tests, previews, references).

This page makes all three cheap, so one short prompt is enough.

## 1. What the data says works (Anthropic, ~400,000 Claude Code sessions, Aug 2026)
From [Analytics Vidhya's write-up](https://www.analyticsvidhya.com/blog/2026/08/claude-code-best-practices-analysis/) and the [Claude Code power-user tips](https://support.claude.com/en/articles/14554000-claude-code-power-user-tips):
1. **Say what Claude can't guess:**
   - the file;
   - the scenario;
   - what "done" means;
   - which pattern to copy.
   
   Expert prompts got about 12 actions and 3,200 words of work per prompt; novice prompts about 5 and 600.
2. **Give it something it can check.** Claude stops when work *looks* finished. A pass/fail check (a test, a build, a preview next to a reference) lets it keep going on its own. The top tip in Anthropic's list.
3. **Correct early, then reset.** After **two failed corrections on the same issue**, start fresh (`/clear`) and rewrite the prompt. The old context is full of failed tries.
4. **Plan first for big jobs** (plan mode, Shift+Tab). Re-plan instead of patching mid-way. A second session can review the plan.
5. **After every correction, add a rule to `CLAUDE.md`,** so the mistake never comes back. This vault does this with the owner's taste: see [[09 Owner Taste Rules]].
6. **Any job you do more than once a day becomes a skill** (`.claude/skills/<name>/SKILL.md`).
7. **Raise the effort for hard work** (`/effort high` or `xhigh`); keep it normal for small edits.

## 2. The few-prompt pipeline (what each prompt should do)
| Prompt # | What you say | What Claude does (from the vault) |
|---|---|---|
| 1 | "New game: **<name>**, like **<reference game>**, our twist **<twist>**. Here's a recording." | Runs `new-game-kit`, picks the Blueprint from the Router, writes a one-page loop (phases, who moves, what text shows) from the recording, then builds the **golden slice**: one station, the payoff, the HUD. Measures against the reference (feel test, [[06 Beat the Hits - Polish Playbook]] §9) |
| 2 | "Yes, roll it out" (or 1–2 fixes) | Builds every system from the Blueprint's system list, copying from `cannon-evolution/` code, with Config numbers from the Blueprint; tests offline, rebuilds the place file |
| 3 | "Make it look like the hits" | Runs the skills (`roblox-cartoony-building`, `roblox-cartoony-ui`, `roblox-vfx`), [[16 Cartoony Kid-Appeal Checklist]] and the Borrow List; one side-by-side per screen |
| 4 | "Polish pass" | Runs the juice menu, sound rules and onboarding numbers from [[06 Beat the Hits - Polish Playbook]]; a fresh critic lists the worst 5 gaps; fix the top 3 |
| 5 | "Ship it" | [[02 Launch and Discovery Cheat Sheet]]: IDs list, passes, thumbnails, kid-safe check |

**This only works if the vault already holds the answers.** Every time the owner corrects something, it goes into a note, a skill or Config. Otherwise prompt 6 repeats prompt 2's mistake.

## 3. Prompt templates (copy, fill the <>)
**Reference first (any visual or feel change):**
> Match **<thing>** to the reference `<path to video or picture>`, our own look. Measure it first (<the numbers to measure>). Build it, then show ONE side-by-side at the same framing. List what's still worse than the reference. Done = <measurable target>.

**New system:**
> Add **<system>** to `<game>/`. Copy the pattern from `<file in cannon-evolution>`. Numbers go in GameConfig. Server decides, client draws. Kid-safe rules apply. Done = the offline check passes, plus a spec for <the rule>. Then say what only Studio can show.

**Feel bug ("it feels off"):**
> The **<moment>** feels worse than **<reference>**. Record both at 30 fps, and measure timing, speed curve, camera height and sounds. Tell me the 3 biggest differences with numbers *before* changing code.

**Studio work through MCP:**
> Studio is open on **<place>**. Use `list_roblox_studios` → `get_studio_state` (must be Edit). Save to Roblox first. Change <x> in the repo file, install it, playtest with the playtest subagent: "<one concrete scenario>". Report which test rung you reached.

**Research:**
> Research how **<hit game>** does **<system>**. Watch the owner's recording first, then wikis. Tag every fact [measured]/[wiki]/[guess]. Write it as a Borrow List row: idea, why it works, how in Roblox, kid-safe check.

## 4. Make every check automatic (so Claude can verify itself)
| Check | Tool | Exists? |
|---|---|---|
| Scripts compile, rules hold (prices, odds, rebirth maths) | Lune specs: `tools/check.sh` per game | ✓ new-game-kit, hood, huzz-valley |
| The UI looks like the reference | Playwright HTML preview next to the reference picture | ✓ (`tools/preview`) |
| Motion feels like the reference | 30 fps capture + frame measurements (`GAME-FEEL.md` §9) | ✓ huzz-valley; **add for launches** (counter speed, throw length) |
| Kid-safe money rules | grep checks (no PurchaseGranted before the save; no invented IDs; no crossed-out fake prices) | ½ make it one script |
| It runs in Studio | MCP `start_stop_play` + `user_*_input` + `get_console_output`, or the playtest subagent | ✓ |
| Phone layout | Device Simulator via the `rbx-device-simulator-lua` skill | ✓ |

**Hooks** turn rules into walls: a `Stop` hook that runs `tools/check.sh` makes Claude fix failures before it reports "done" (Claude Code ends a turn after 8 blocked stops). Put it in the game's `.claude/settings.json`.

## 5. Keep the context clean (cheaper and better)
- **The Router first, then only the rows you need.** Grep notes; don't read folders (repo rule).
- **One thread = one goal.** Unrelated asks go to a new thread.
- **End each session with a handoff:** what works and how it was checked, what's in progress, decisions with dates, do-not-touch. See [[Agent Handoff Notes - Project State and Resume Templates]].
- **Pictures beat words** for look and feel. Send a recording of the reference and of ours. Claude measures the frames.
- **Name the reference game every time.** "Like Stone Skipping's throw" is worth ten adjectives.

## 6. Building the vault so prompts stay short (next steps)
1. **A systems library:** each system from Cannon Evolution (eggs/pets, rebirth, shop, playtime, daily, codes, missions, leaderboard, tutorial, launch/flight, Sfx, UI Kit) as a drop-in module with its own spec and Config block, so a new game copies a folder instead of a game. `new-game-kit/` is the start.
2. **A reference pack per game family:** 2–3 measured recordings + a teardown note ([[Teardown - Stone Skipping]] is the model).
3. **The owner's taste rules in one place** ([[09 Owner Taste Rules]]), loaded for every UI, sound and feel job.
4. **One kid-safe check script** shared by all games.
5. **A "feel numbers" table per family** (throw length, counter speed, first rebirth time) that the feel test compares against.

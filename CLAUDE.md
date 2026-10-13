# Building Roblox games with the owner

This file loads in every session, so keep it short. Each game folder has its own `CLAUDE.md` with that game's details (for example `huzz-valley/CLAUDE.md`).

## The owner
- Kid-focused Roblox games in Luau. The owner uses Roblox Studio, GitHub Desktop and Rojo on a Mac, has no coding background, and judges by eye.
- Writes short messages and changes direction. For a real direction change, ask ONE multiple-choice question with the recommended option first. Otherwise act, then report.
- Use plain words and no jargon. Give status in short lines, and deliver one thing per change.
- **Credits matter.**
  - Grep instead of reading big files; read only the lines you need.
  - Use few agents and reuse them.
  - At most 2 render rounds per change, and one picture per change, only when there's something to judge.
  - Don't re-derive what this file or the game's `CLAUDE.md` already says.

## How we build
1. **Golden slice first.** Build the smallest piece that proves the look and feel, get a yes, then roll it out. Full builds that miss waste days.
2. **The reference is the authority.** Every visual change gets ONE side-by-side (ours next to the reference, same size and framing). Never say "matches" without that picture. Judge motion on a 30 fps video, not stills.
3. **A fresh critic before showing the owner.** Builders grade themselves too kindly: compare against the reference and list the worst gaps first.
4. **Be honest about gaps.**
   - Say what is still worse than the reference, what only Studio can show, and what is a placeholder.
   - Never claim a placeholder or a missing integration is finished.
5. **Check the data before "fixing" a scare.** Read the history and measure first; odd results are often a camera angle or an earlier request from the owner.
6. **When merging agents' work,** copy only the files each agent changed onto the current HEAD. Never copy an agent's older copy of a file that changed since.
7. **"One-to-one" means one-to-one.** Match the reference exactly (sizes, colours, textures, bevels, text treatment), not "close in spirit". Measure it, then check it with a fresh critic agent.
8. **Use the owner's own assets as they are** (icons, images, models from their kits). Don't redraw, regenerate or "clean up" them unless asked; say plainly what their limits are.
9. **Anything worth keeping goes in the repo.** The session's temp folder vanishes. Commit tools, previews and notes.

## Never
- **Never invent asset, product, Game Pass or animation IDs.** Leave them as 0 or empty with a clear note, and list them on the owner's checklist.
- **Kid-safe always:**
  - no fake timers, scarcity or stock;
  - at most 1 flash per second;
  - paid random items show their odds and a pity counter, and never have hidden odds;
  - never sell something that gives nothing yet. It may show its price, but tapping it only says "coming soon" and never opens a purchase.
- **Purchases are granted only on the server:**
  - one ProcessReceipt in the place;
  - grant once per PurchaseId;
  - answer "granted" only after the save;
  - game passes are checked with Roblox, never trusted from the client.

## Repo mechanics
- One folder per game, with a Rojo `default.project.json` mapping `src/` into Studio services. Setup for the owner is in `ROJO-SETUP.md`.
- **Getting the owner's Studio work:** they paste `tools/export-for-claude.lua` into Studio's Command Bar and send the `ServerStorage > ClaudeExport > PartN` text.
- In Studio, saves run in ProfileStore **Mock** mode, so progress resets on Stop. That is on purpose.
- **Offline tools** (no Studio needed) live in `<game>/tools/preview`:
  - a Lune harness runs the server and client code in a fake DataModel;
  - the checks assert the rules;
  - the HTML renderer draws exported ScreenGuis next to the reference.
  - Lune 0.10.5 comes from the lune-org GitHub releases. Playwright and Chromium are already installed in cloud sessions.
- Cloud sessions can't reach Studio. Only the owner can confirm the final look and the real purchase prompts.

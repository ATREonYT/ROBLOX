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

## Game feel
- Read `GAME-FEEL.md` before building a new game: copy the reference loop exactly, give each round a
  cinematic moment, use one message line, name tags, rescues, sharp controls and small UI.

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
10. **The owner tests a ready-made place file.** After every change, rebuild `<game>/places/<Game>.rbxl` and give the "Download raw file" link with the steps to try it.
11. **UI lives in StarterGui as real parts** (the owner's call), so the owner can see and edit it in Studio:
    - the code builds the UI and the place build saves it as `src/StarterGui/<Gui>.rbxm`;
    - at runtime the scripts reuse those saved parts instead of building a second copy;
    - see the game's `CLAUDE.md` for the rules.
12. **Get sharp art early.** Crops from a mockup page are blurry. Ask the owner for transparent PNGs of at least 256 px, named like the kit, and keep their zips in `design/`.
    - Pack icons at 192 px or more: the owner's Mac has a Retina screen.
    - Prefer one tiled texture over many small parts (the owner asked for this with the header studs).

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
- **Roblox UI rules the preview won't show you:**
  - UDim offsets are whole numbers, so never use half pixels;
  - ClipsDescendants clips square and ignores UICorner, so round the image itself;
  - a ScrollingFrame clips its children's outside UIStroke rims, so give them padding;
  - never key a weak table by Instance: entries vanish at random while the part still exists;
  - picture names are case-sensitive in Roblox, while the preview finds files regardless of case, so check names with a test;
  - Studio's editor only shows uploaded images (`rbxassetid`). Pixels drawn by scripts (EditableImage) appear only in Play, or through a Studio helper plugin.
- **A clean offline run doesn't prove Studio works:** Lune's copy of the Roblox API is outdated. Start each UI part separately, so one failure can't stop the rest, and show errors on screen, so the owner can screenshot them.
- **Cloud sessions can't reach Studio or Roblox's web APIs** (apis.roblox.com is blocked), so they can't upload images or check the real game.
  - Only the owner can confirm the final look and the real purchase prompts.
  - Anything that must run in Studio (uploads, helpers) ships as a Command Bar script or a "Save as Local Plugin" script. It reports in Output on lines starting with a tag, so the owner can screenshot the result.

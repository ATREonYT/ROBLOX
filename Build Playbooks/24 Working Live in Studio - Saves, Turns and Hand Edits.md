---
tags: [build-playbooks, studio, workflow, saving, team-create, hand-edits, merge, lessons]
updated: 2026-11-01
---

# 24 Working Live in Studio: Saves, Turns and Hand Edits

Back to [[00 Build Router]] · Code and release rules: [[18 Studio-Level Development Playbook]] · AI workflow: [[08 Few-Prompt Game Building with AI]]

**Why this note exists.** From Oct 30 to Nov 1, several threads worked on +1 Cannon Evolution straight inside Alex's open Studio, through the Studio connection on the Mac. It worked, but we nearly lost a day of work twice. These are the lessons, written so the next game never repeats them.

## 1. The five rules (read these if nothing else)
1. **Studio is the truth while it is open.** What is in Alex's Studio right now beats the repo. Read the live script before changing it, every time.
2. **Merge into the live script; never overwrite it.** Alex edits by hand (moves things, tweaks numbers, renames). A blind paste from the repo throws that away.
3. **Nothing is safe until it is saved.** Studio changes live in memory. A crash or a closed window loses them. Ask for a save before any big install, and after it.
4. **One thread in Studio at a time.** Two threads editing the same place at once overwrite each other. Take turns, and hand over in words: "I'm done, Studio is free."
5. **Bring Studio's changes back to the repo.** Anything done only in Studio is lost to every later session. Pull it into git the same day.

## 2. Saving: what each button really does
| Button | What it saves | When it fails | What to do |
|---|---|---|---|
| **Cmd+S** (File → Save) | Saves to wherever the place came from: Roblox if it was opened from Roblox, the file if opened from a file | Saving to Roblox can fail quietly (network, a big place, a Team Create hiccup). Check the save time in Version History. | Check the time after saving. If it didn't change, use Save to File As. |
| **File → Save to File As…** | A `.rbxl` on the Mac. Always works offline | Almost never | **The safe backup.** Ask for it before any big install: `CannonEvolution.rbxl` in the ROBLOX folder |
| **File → Save to Roblox** | The cloud copy that the live game and Team Create use | Can be blocked for hours. On Oct 31 Roblox still showed **Oct 30** as the last save after a whole day of work | Retry later. Until it works, the `.rbxl` file is the only real copy |
| **File → Publish to Roblox** | Makes the saved version live for players | Needs a working save first | Only Alex publishes, and only after testing |

**The check, in one line:** after any save, look at the place's Version History (Creator Dashboard → the place → Version History). If it did not move, the save did not happen.

**How a thread asks for it (copy this wording):** "Before I install, please do one thing: **File → Save to File As…** and save it as `CannonEvolution.rbxl` in your ROBLOX folder. Tell me when it's saved." One step, one file name, one place. Wait for the yes.

## 3. Taking turns between threads
- **Say who has Studio.** The thread installing says so at the start ("installing now") and at the end ("done, Studio is free").
- **Order big installs.** On Nov 1 the rare-shot rework went first, then the training lanes. The second thread waited for the first to finish *and* for Alex's save.
- **Keep each install narrow.** The lanes install only rebuilt `TrainingStations` and added one LocalScript (`LaneMotion`). A narrow install can't step on another thread's work, and it is easy to undo.
- **Play mode is not edit mode.** Changes made while Play is running vanish on Stop. Stop Play before installing; play-test after.
- **Team Create** lets Alex and a helper edit at once, but scripts can still clash: two people editing one script means the last save wins. Keep to one editor per script.

## 4. Keeping Alex's hand edits
Alex judges by eye and fixes things in Studio directly. Those edits are the most valuable thing in the place, because they are the owner's taste.
1. **Read before you write.** Pull the live script text first (`script_read`, or the export script `tools/export-for-claude.lua`).
2. **Diff it against the repo.** Anything in Studio that isn't in git is Alex's edit or another thread's install. Keep all of it.
3. **Change only your lines.** Insert or replace the smallest block that does your job. Never paste a whole file over a live one.
4. **Keep their numbers.** If Alex changed a size, a colour or a time, keep it even if our note says otherwise, and update our note.
5. **Tell them what you kept.** "I kept your camera height and your new sign text." It shows the edit was seen.

## 5. Getting Studio-only work back into git
On Oct 31 the repo was missing a whole day of Studio-only changes. A thread saved them as one diff file against commit `e60783e` (`studio-only-changes-vs-e60783e.diff`) so nothing was lost. Keep such a diff in the repo or the project files, never only in a session's temp folder.
- **At the end of each Studio session:** export the scripts that changed, compare with the repo, and commit Studio's version where it is newer.
- **Name the starting point.** Diff against a named commit (as above), so the next thread knows what "newer" means.
- **Models and UI** go back as `.rbxm` (right-click → Save to File) into the game's `src/` or `assets/` folder, as the game's `CLAUDE.md` says.
- **Never "fix" a gap by re-installing the repo over Studio.** That is how hand edits die.

## 6. When the Mac goes offline
The Studio connection drops when the Mac sleeps or the lid closes (on Oct 31–Nov 1 it went off and on about every 10 minutes).
- **Build in the repo while offline,** push it, and install when Studio is back. The rare-shot rework was finished and pushed this way, then waited for the save.
- **Re-read Studio after every reconnect.** Alex may have changed things in between.
- **Never leave a half install.** Install in one go when the connection is steady, then play-test.

## 7. Bringing in a pack (VFX, SFX, models)
- **You often don't need to import it.** We can read a pack file on the Mac and rebuild the effects we need in code (that is how `RareFXPack` was made). Then nothing extra sits in the place.
- **If Alex wants the raw pack in Studio** (to look or play):
  1. **File → Open from File…**, pick the pack (for example `Downloads/VFX PACK.rbxl`). It opens in its own tab.
  2. In that tab's Explorer, select the folders and press **Cmd+C**.
  3. Switch to the game's tab, click **ServerStorage**, and press **Cmd+V**. In ServerStorage it never shows in the game.
- **Check a pack before using it:** does it have scripts? (The Oct 31 VFX pack had none: good.) Are any textures ripped from other games? (We left those out.) Is the sound licensed? (SFX came from Roblox's licensed library.)
- More on using pack effects well: [[25 Rare Shot Cameras and Using a VFX Pack]].

## 8. Checklist before and after a live install
- [ ] Read the live version of every script you will touch.
- [ ] Alex has saved (Save to File As) and the time moved.
- [ ] No other thread is installing.
- [ ] Play mode is stopped.
- [ ] Install only your part; keep every hand edit.
- [ ] Play-test, then ask Alex to press **Cmd+S** again.
- [ ] Say "done, Studio is free" and commit Studio's final version to git.

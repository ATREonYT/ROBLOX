# Lessons from the owner's other games (Oct 26)

The owner asked to "use the mistakes I made with other games to our advantage". This file lists what went wrong in
those games and what Hood does about it. Sources: Huzz Valley (branch `HUZZ-VALLEY`: `GAME-FEEL.md`,
`huzz-valley/CLAUDE.md` section 2, `huzz-valley/docs/notes/`, about 400 commits) and the three early one-script
games in this repo (`plus-one-speed/`, `snatch-a-brainrot/`, `steal-an-egg/`). Look lessons are in `INSPIRATION.md`.

## A. Scripting mistakes that shipped once, and where Hood stands

| Mistake (where it happened) | Hood now |
|---|---|
| **Weak tables keyed by an Instance** lose entries at random while the part still exists (Huzz, Oct 19). | Fixed Oct 26: the 16 such tables use `Shared/InstanceMap` (unit-tested). **Never write `{ __mode = 'k' }` for instances.** |
| **Streaming: a Model arrives before its parts**, so a lookup done once finds nothing forever (Huzz's FREE SPIN line). | Fixed Oct 26: the pass boards and the World Boss board stream in whole (Atomic), and `HoodClient/Lobby` waits for a board's prompt before setting it up. Rule: a model the client reads is Atomic, or the client looks again until it's there. |
| **One error stops a whole loop** (Huzz: the game loop, the picture queue). | Fixed Oct 26: the 8 server loops (waves, stages, World Boss, goals, lobby, retention, HUD extras, boosts) carry on after an error and report it once in Output. Rule: every forever loop and every queue pcalls each tick or job. |
| **Joining kicked during the save hand-over** from another server (Huzz waits 60 s). | Fixed Oct 26: `ServerConfig.LoadTimeoutSeconds` 45 → 60 (ProfileStore takes a session over at ~45 s). |
| **Testing old code without knowing it** (Rojo on an old copy puts old scripts back). | Fixed Oct 26: `build_place.sh` writes `Shared/Config/Build`; Studio Play shows "UI OK · build <date> <commit>" top-right. |
| **"Save works?" tested in Studio**, where saves are a throwaway copy on purpose. | Fixed Oct 26 in `RELEASE.md`: the save test moved to the private published game. |
| **Saves with `SetAsync` and no session lock** (the 3 early games: lost progress on server hops). | Already right: ProfileStore with session locks, migrate on a copy, kick rather than run on unsaved data. |
| **Purchases granted on the client or twice** (risk in the early games). | Already right: one ProcessReceipt, once per PurchaseId, "granted" only after the save (`StoreReceipts`, tested). |
| **A 2,000-line single script per game** (early games): one typo breaks everything, nothing testable. | Already right: small services, pure rules modules, 399 unit tests and offline play runs. |
| **Spawning inside props** (Huzz: 23 % of lobby spots). | Not checked yet. Next: a test that every spawn and teleport point has floor under all four feet and nothing solid in the body's box. |
| **Raycasts miss invisible walls / low kerbs** (Huzz: the catch slide went through walls). | Check when adding any movement that uses rays: clamp to the area too, and cast near the floor. |
| **World prompts opening menus during a cinematic** (Huzz's Secret cutscene). | Open: hide the HUD and block prompts while the shoe box opens (already on the open-items list). |
| **The sim isn't deterministic** (table order over players). | Rule: loop a timing-sensitive check several times before calling a fix done (as `wb_play` already says). |

## B. Feel mistakes from Huzz Valley (each was wrong first, then fixed)
1. **An invented loop got "ehh".** Copy the reference loop exactly, then add our twist on top. For Hood the reference is
   +1 Soldier Evolution: write its loop down as phases before changing ours.
2. **Every round needs a moment.** Stage clears, the World Boss and box openings get a short cinematic with one sound per beat.
3. **One message line tells the story**, short and punchy, coloured by event. Big centre words only for big moments.
4. **Small UI.** The owner asked twice for smaller buttons. Start small.
5. **Calm camera, instant movement:** full speed in ~0.5 s, no zoom pulse, no shake.
6. **Mid-tone ground:** floor brightness ~0.6; a blown-out floor reads "bland".
7. **Effects with timing:** wind-up, one bright frame, the effect, a fade. One effect per event.
8. **Measure the feel against the reference, number by number** (`huzz-valley/docs/feel-study.md` is the worked
   example). Judge motion on a 30 fps video.

## C. Working mistakes (how sessions lost the owner's time)
1. **Losing track of a long message** ("i think you may be losing track midway", Oct 20). Save it word for word with a
   job table in `hood/docs/plan-<date>.md`, keep one checklist, tick every item before reporting.
2. **"I asked so many times."** A safety net isn't a fix: prove the cause; if it can't be proven offline, ship a guard
   that removes it and names it in Output.
3. **Telling the owner to do what he already did.** Check his place file and history first.
4. **Agents grading themselves.** A fresh critic before every report found real bugs every time.
5. **Merging an agent's old copy of a file** almost reverted the tutorial. Copy only the files each agent changed.
6. **The container restarts** and kills background work: commit and push after every merge.
7. **Decision cards wait for hours.** Go on with the recommended option and say so.

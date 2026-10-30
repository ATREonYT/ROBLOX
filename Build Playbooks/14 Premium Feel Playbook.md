---
tags: [build-playbooks, premium, game-feel, polish, ui-motion, tutorial, pipeline, kid-safe]
updated: 2026-10-31
---

# 14 Premium Feel Playbook

Back to [[00 Build Router]] · The measured reference: [[Teardown - Stone Skipping]] and [[13 Beat Stone Skipping - Tutorial, Pacing and Feel]] · Polish rules and the feel test: [[06 Beat the Hits - Polish Playbook]] · Taste: [[09 Owner Taste Rules]] · Loops: [[12 Game Loop Logic Playbook]] · Moments: [[11 VFX Moments Playbook]]

**Goal (owner, Oct 31):** turn games out fast, and make each one feel premium, "just like Stone Skipping". This note is the **premium layer**: the small, repeatable things that separate a front-page game from a cheap one, with exact numbers and the kit code that does them. Every game gets this layer by default, so no prompt has to ask for it.

**Tags:** [M] measured from the owner's recordings · [R] in our code or notes · [I] my starting estimate, to be measured.

## 1. What "premium" means (ten tells you can check)
A kid can't name them, but they feel every one. Each has a pass/fail test.

| # | Tell | Cheap version | Premium rule (test) |
|---|---|---|---|
| 1 | **First screen** | 20 buttons and an arrow | The verb and one bar. Everything else arrives on the step that needs it (§2). Count visible buttons at join: ≤ 3 |
| 2 | **Something every second** | A number creeps up | A level-up, pop or tick at least every 1–2 s while grinding (§3) |
| 3 | **One message line** | Toasts stacking everywhere | One line, top centre, each new event replaces the last [M] |
| 4 | **Same motion everywhere** | Each panel animates differently | Every button, panel and pop uses the motion table (§4) |
| 5 | **Rewards are chained** | A number changes silently | Fade → celebration → reveal → next goal, in ≤ 8 s (§5) [M] |
| 6 | **Calm camera** | Shake on every hit | No shake on repeat actions; speed comes from the world rushing past [M] |
| 7 | **Short sounds, layered** | One loud clip | A soft click + a pitch-ladder tick + a ≤ 0.8 s sting on big moments (§6) [R] |
| 8 | **Big numbers read instantly** | 1234567 | 1.23M, outlined, the counter is the biggest text on screen [M] |
| 9 | **Spotlight** | The tutorial points but the screen is busy | Dim everything but the one button the step needs [M] |
| 10 | **Nothing broken shows** | Placeholder emoji, error boxes, a buy button that does nothing | Our icons only; errors to Output; "Coming soon" instead of fake features [R] |

## 2. The first five minutes (script for any family)
Measured from Stone Skipping and built into Cannon on Oct 31 ([[13 Beat Stone Skipping - Tutorial, Pacing and Feel]]).

| Beat | Time from join | Screen shows | What fires |
|---|---|---|---|
| Intro | 0–15 s, with Skip | No HUD; the camera flies the whole spine once | Guide line in plain subtitles |
| Grind | 15–40 s | **Only the stat bar** and the quest bar | Level-ups every ~1 s (§3) |
| First payoff | ≤ 40 s | + the payout counter, as it is first earned | The verb's big moment; "+1" over the head; the quest ticks |
| First buy | ~55 s | + the one shop or stand it needs, **spotlit**, with a chain of arrows | "NEW …!" toast |
| First reset | ~85 s | **Dim the screen**; only the Rebirth tile lit at 100% | White fade 0.25 s in / 0.5 s held / 0.3 s out → TUTORIAL COMPLETE on rays |
| HUD reveal | on tap | Everything else **pops in one after another**, 0.06 s apart | Confetti; the multiplier shows ×2 |
| Return hook | +2 s | Daily Rewards opens by itself | Claim → big tick → "Next reward in 24:00:00" (a real timer) |
| Next run | +10 s | Full HUD | The first payoff after reset is visibly bigger (3 levels in one go) |

**Kit code:** `new-game-kit/src/Shared/HudStages.luau` holds the stage table and answers "is this element visible at this stage", "what arrives now" and "what to spotlight". Returning players (tutorial done or any rebirth) get the last stage. Write the stages in Config:
```lua
Config.HudStages = {
	{ Step = "Train",   Show = { "PowerBar" } },
	{ Step = "Launch",  Show = { "Coins" } },
	{ Step = "Hatch",   Show = { "Menu.Eggs" }, Spotlight = "Menu.Eggs" },
	{ Step = "Rebirth", Show = { "Menu.Rebirth", "TopBar.Rebirths" }, Spotlight = "Menu.Rebirth" },
	{ Step = "Done",    Show = "*" },
}
```
**Status (Oct 31): wired into the kit.** Every game started from `new-game-kit/` gets it with no prompt:
- `Config.HudStages` lists the steps; each has a `DoneWhen = { attr = "Coins", atLeast = 50 }` rule, so a returning player resumes where they left off, and anyone with a rebirth gets the full HUD.
- The client hides the staged pieces until the save loads, pops new ones in (0.25 s Back, 0.06 s apart), and gives the step's button a soft white rim that breathes once every 1.2 s (a glow, not a flash).
- The Rebirth tile shows how close the next rebirth is ("94%").
- The place build fails if a stage names a HUD piece that doesn't exist (exact case).
- Picture: `new-game-kit/previews/hud-stages.png`; make your own with `lune run tools/preview/export.luau out.json Stage1`.
- **Not yet:** the menu doesn't close up the gaps while pieces are hidden, and nothing has run in Studio yet. Cannon has its own version (`HUD.lua`, `applyStage`).

## 3. The grind rewards every second
- **Split the goal into ~20 small levels** inside each run (Level 20 = enough to rebirth, the bar says MAX LEVEL). Level sizes grow slowly (curve 1.3): Stone Skipping's go 10, 10, 10, 12, 14, 15, 17, 19, 22 [M].
- **Each level-up:** confetti on the character, "Level Up! [xN]" beside the bar (N counts level-ups within 1.5 s of each other), a soft tick that rises in pitch, and the quest number moves.
- **A display only.** It changes nothing the player earns, so it never breaks the pacing sim.
- **After a reset,** the first payoff crosses several levels at once. That's when the rebirth is felt.

**Kit code** (for games whose grind stat isn't spent, like Power or Skill; the kit's own coins get spent, so it isn't wired there): `new-game-kit/src/Shared/Progression.luau`: `Progression.Level(have, goal)` gives the level, the progress inside it and the level size, `LevelsGained(before, after, goal)` counts levels crossed in one tick, and `Progression.Streak(1.5)` gives the [xN] count. Cannon's version is `Config.PowerLevel` [R].

## 4. Motion table (every UI piece moves the same way)
Values from Cannon's `Kit.lua` and the new-game-kit client, which Alex approved by eye [R]. Use these and nothing else; a game feels premium when everything moves alike.

| Piece | Motion |
|---|---|
| Button hover | Scale 1 → 1.05–1.07, 0.3 s Back out; the icon tilts −8° over 0.12 s |
| Button release | Scale back to 1, 0.3 s Sine |
| Button press | Scale 0.9 in 0.03–0.08 s, then 1 in 0.28 s Back; content nudges 2 px down and back over 0.12 s |
| Close (X) hover | Scale 1.1 and rotate 8°, 0.12 s |
| Pop-in (new element, NEW! badge) | Scale 0.6 → 1, 0.25 s Back; stagger 0.06 s when several arrive |
| Panel open | Scale 0.85 → 1 with transparency 1 → 0, 0.2–0.25 s Back; blur the world behind [M]; timing [I] |
| Panel close | Scale 1 → 0.9, 0.12 s Quad in. Closing is always faster than opening [I] |
| Bar fill | 0.25 s Quad out, never a jump |
| Counter roll | Tween a parented NumberValue over 0.35–0.6 s; scale bump 1.15 → 1; a green flash 0.15 s ([[11 VFX Moments Playbook]] §4) |
| Message line | Slides in 0.15 s, holds 2–2.5 s, fades 0.3 s; a new message replaces it at once [M]; timing [I] |
| Toast (NEW STONE!) | Small, bottom-left of centre, 2 s [M] |
| Screen dim | Black at 0.45–0.55 transparency, 0.25–0.4 s in |
| White fade | 0.22–0.25 s in, 0.45–0.5 s held, 0.3–0.35 s out. **One per moment** (≤ 1 flash per second) [M][R] |

## 5. Reward beat chains
A big moment is a **chain of small gifts**, each 0.5–2 s, never one long animation. Total under 8 s, and the player can tap to speed it up after the first beat.

| Moment | Chain |
|---|---|
| Payoff (each launch/throw) | Counter stops → hard cut home → "+N" over the head → icons fly to the counter (0.35–0.5 s, staggered 0.04 s) → counter bump → quest tick. About 1.5 s, then the button is ready again [M] |
| Level up | Confetti on the character + "Level Up! [xN]" + tick. 0.5 s, no screen effect |
| First buy of a tier | Item spins in on a pedestal → NEW! pop → the message line → the arrow chain moves to the next goal |
| Egg hatch | Wobble → swell → one flash → reveal in the rarity colour → name slam. Length grows with rarity ([[11 VFX Moments Playbook]] §5) |
| Rebirth | Dim → Before → After card → tap → white fade → rays + "×2" → HUD reveal → (first time) Daily Rewards [M] |
| New zone | Banner grows beside the counter as you cross; the sky tints over 1 s [M] |
| New best | "NEW BEST!" slam + gold burst at the flag; slow motion 0.4 s only here |

## 6. Sound layering
- **Three layers, all short:** a UI click (0.1–0.3 s), a pitch-ladder tick for repeats (up a semitone each time, capped at 8 a second, reset after 1 s of quiet), and a sting for big moments (≤ 0.8 s) [R 09].
- **Every sound gets** the Sfx module's warm high cut and gentle compressor [R].
- **One sound per beat.** When the chain fires, don't play the click and the sting on the same frame.
- **Silence beats a harsh stand-in.** Leave the slot empty until a good sound exists; we make our own (`<game>/tools/sfx/make_sfx.py`), and the owner uploads them.

## 7. Feel numbers per family (what the feel test compares against)
The target for each family's core feel. A build passes when each number is within 30% of the target. Only family A is measured; the others are starting estimates until we record a reference.

| Number | A. +1 Launch/Throw | B. Egg Run | C. Stage lane | D. Roll & place |
|---|---|---|---|---|
| Verb cycle (press → payoff → ready again) | 5–6 s (4.5 s throw + 1 s home) [M] | 20–40 s per run [I] | 10–20 s per stage [I] | 1–3 s per roll [I] |
| Time to first payoff | ≤ 40 s [M] | ≤ 45 s (first egg home) [I] | ≤ 30 s (stage 1 pad) [I] | ≤ 10 s (first roll) [I] |
| Counter speed during the verb | ~60 m/s, near constant, slowing only in the last second [M] | Speed number visible while running [I] | Stage number + timer [I] | Reel 0.3 s (common) to 3–4 s (legendary) [R] |
| Level-up interval while grinding | ~1 s [M] | ~1–2 s on the treadmill [I] | ~1 s [I] | ~1 per roll [I] |
| First purchase | ~55 s [M] | ~2 min [I] | ~1 min [I] | ~30 s [I] |
| First reset | ~85 s [M] | ~5 min [I] | ~2 min [I] | ~3 min [I] |
| Camera during the verb | Chase or side-on; no shake [M] / Alex's side-on call [R] | Third person, slight FOV kick on speed [I] | Third person [I] | Fixed on the roll UI [I] |

**Measure, don't guess:** to fill a [I] cell, record the hit (30 fps), sample it at 2–4 fps as in [[Teardown - Stone Skipping]], and put the number here with [M].

## 8. Checks that run on every build
- **The kit's offline checks** (`sh tools/check.sh` in the game folder): unit specs, the pacing sim, the place build, then the kid-safe check.
- **Kid-safe check** (`python3 tools/kidsafe_check.py [game]` from the repo root, new Oct 31). It fails on:
  - more than one ProcessReceipt in a game, or one in client code;
  - a client granting on a purchase-finished event;
  - fake-pressure text in shop code: crossed-out prices, "only N left", "limited time", "ends in", "last chance", "hurry", "was R$".
  
  It warns on asset ids that look made up and on flash loops faster than once a second, and lists every asset id (`KIDSAFE=--ids`) so the owner can confirm each is theirs. All five games with a `src/` passed on Oct 31.
  
  It can't see on-screen odds, pity behaviour or real purchase prompts: those stay on the owner's Studio checklist.
- **The feel test** in [[06 Beat the Hits - Polish Playbook]] §9, compared against §7 above.

## 9. Fast and premium: five prompts per game
This replaces the pipeline in [[08 Few-Prompt Game Building with AI]] §2 when the game has a known family.

1. **"New <family> game called <Name>: <one-line theme>. Reference: <recording>."** Start from the kit (`new_game.sh`), pick the blueprint and family from [[12 Game Loop Logic Playbook]] §2, fill Config with the §3 pacing and §7 feel numbers. Done when the pacing sim passes.
2. **"Build the map."** [[10 Map Design Playbook]], template and zones; stop at the blockout picture.
3. **"Build the verb."** The family's core moment, with the camera, counter and payoff chain (§5), timed against §7. One side-by-side video with the reference.
4. **"Premium pass."** This note: staged HUD (§2), level-ups (§3), the motion table (§4), beat chains (§5), sounds (§6), the moments from [[11 VFX Moments Playbook]]. Then the owner's taste rules ([[09 Owner Taste Rules]]).
5. **"Feel test and ship."** The checks in §8, the feel test, a fresh critic against the reference, the place file and the owner's checklist (IDs to upload, passes to create).

## 10. Premium checklist
- [ ] At join: ≤ 3 buttons visible; everything else arrives on its tutorial step; returning players get the full HUD
- [ ] A level-up or tick at least every 1–2 s while grinding, with an [xN] streak
- [ ] One message line; toasts small and short
- [ ] Every button and panel uses the §4 motion table; closing is faster than opening
- [ ] Each big moment is a chain of short beats under 8 s, tappable after the first
- [ ] No shake on repeated actions; ≤ 1 flash per second
- [ ] Sounds ≤ 0.8 s, one per beat, all through the Sfx module
- [ ] Every §7 feel number for the family within 30% of target
- [ ] `tools/check.sh` green, including the kid-safe check
- [ ] Side-by-side with the reference at 30 fps, judged by a fresh critic, worst gaps listed first

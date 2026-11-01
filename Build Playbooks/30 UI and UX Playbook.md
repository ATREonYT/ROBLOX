---
tags: [build-playbooks, ui, ux, hud, onboarding, menus, mobile, motion, owner-taste, kit/HudStages]
updated: 2026-11-01
---

# 30 UI and UX Playbook

Back to [[00 Build Router]] · Numbers: [[27 Studio Standard - One Sheet per Craft]] §6 · Taste: [[09 Owner Taste Rules]] (UI) · Motion table: [[14 Premium Feel Playbook]] §4 · Hidden-UI tutorial: [[13 Beat Stone Skipping - Tutorial, Pacing and Feel]] · Skill: `roblox-cartoony-ui`

**Why a whole note.** UI is where Alex gives the most feedback ("smaller buttons", "too many buttons", "no emoji", "like their pictures"). Our UI rules were spread over the repo `CLAUDE.md`, note 09, note 13, note 14 and the skill. This note puts them in build order, adds the UX side (what the player sees when), and gives recipes.

## 1. The rules, in order of importance
1. **Alex's mockups and kits are the authority** (`<game>/design/`). Lay menus out like the pictures and use the kit's colours and icons as they are. No emoji in the final UI.
2. **Show almost nothing at first.** A new player sees at most 2 things to press in the first 30 s. Each part of the HUD appears when the tutorial needs it (kit `HudStages`).
3. **Small, premium buttons.** Start small (the Cannon UI went 18% smaller); phones keep about 44 px tap targets (C25).
4. **Everything moves the same way:** the motion table in note 14 §4, and nothing else.
5. **One message line** tells the story (GAME-FEEL.md): coloured text about 3.5% of the screen height, no panel, an instant swap.
6. **UI lives in StarterGui as real parts** that Alex can see and edit (repo rule 11). The code builds it once; the place build saves it as `.rbxm`; at runtime scripts reuse those parts.
7. **No red error box on screen.** Errors go to Output on tagged lines.

## 2. The HUD by stage (the UX timeline)
| When | On screen | Why |
|---|---|---|
| 0–30 s | The one main action (or the progress bar) and the quest line | One thing to learn |
| First reward | + the currency it gave, with a pop-in | You see it arrive |
| First purchase step | + the Shop button, with the arrow chain to it | Taught when it matters |
| First rebirth | the screen dims except the Rebirth tile | One choice, spotlighted |
| Tutorial complete | everything else pops in, staggered 0.06 s | A reward in itself |
| Returning player | the full HUD at once | No re-teaching |

## 3. Layout (phone first)
- **Thumb zones:** the main action bottom right; menus in a left column; currencies top centre or top left; nothing in the top 10% under Roblox's own buttons (use the safe area).
- **One dominant button per screen.** Everything else is visibly smaller.
- **Colour means something:** yellow main action, green confirm, red close, blue go somewhere. Rarity swaps the gradient on the same frame.
- **Text:** a chunky rounded built-in font (FredokaOne, Cartoon or LuckiestGuy), with an outline so it reads on any colour. Avoid `TextScaled` everywhere; size text to the frame.
- **Panels:** Alex's Oct 30 style pass chose **see-through panels with floating titles and studded flat buttons**, like Stone Skipping (C27: this beats the skill's "opaque toy panels" for Alex's games).
- **Whole pixels only:** UDim offsets are integers. Round every computed size.

## 4. The button recipe (Roblox parts)
1. A darker copy of the shape offset 3–4 px down: the "lip".
2. The main frame: UICorner 10, a vertical UIGradient.
3. A UIStroke on the outside (dark, 2–3 px). On a ScrollingFrame, add padding so the stroke isn't clipped.
4. The icon (Alex's, ≥ 192 px source) and short text.
5. One LocalScript gives every button the same hover, press and release motion, including buttons created later (`DescendantAdded`), and skips TextBoxes.
6. A soft click on press (note 29 §3), nothing on hover (or a very soft one).

## 5. Menus that kids understand
| Menu | Must have | Avoid |
|---|---|---|
| Shop | big pictures, the price in Robux from `GetProductInfoAsync`, "Owned" (or Alex's tick icon) for owned items, "Coming soon" for unbuilt ones | Hard-coded prices; more than 8 items on one page; any "VIP" |
| Inventory | a grid, "Equip Best", "Delete Mode", a filter, a close button | Tiny cells; no empty state |
| Daily rewards | the calendar, today highlighted, what tomorrow gives | Countdown pressure; a reset streak |
| Settings | Music, Sounds, Screen Shake, Flashes, Reduced Motion; remembered | Hiding them deep |
| Codes | one text box, a clear "Got 100 Coins!" or a friendly "That code didn't work" | Error codes |

**Open and close:** panels open in 0.2–0.25 s (Back) and close in 0.12 s (closing is always faster). Only one panel is open at a time; opening one closes the other.

## 6. Feedback the player can read
- Every button press shows something within 0.1 s (a press scale), even if the server answer comes later.
- **Server says no?** Show a friendly line on the message line ("Get closer!", "Not enough coins"), using `Interact.Lines` or the shop's reasons. Never a silent fail.
- Counters roll, never jump (0.35–0.6 s); a gain bumps the counter and flashes it green for 0.15 s.
- **Toasts only for a new item unlock** ("NEW STONE!", as in the reference: small, bottom-left of centre, 2 s, note 14 §4). Every other piece of feedback text goes through the one message line.

## 7. Accessibility for kids
- Read nothing to play: icons and arrows first, words second.
- Text at least 14 px on a phone; high contrast; colour is never the only signal (add an icon or a shape).
- Settings for Flashes, Shake and Reduced Motion are on by default to the gentle side when Roblox's Reduced Motion is on.
- Non-chat ways to talk in social games: emotes and a quick-phrase wheel with fixed phrases (note 26).

## 8. Worked example: adding a Shop button the right way
1. Ask for or find Alex's Shop icon in `design/`; if there isn't one, leave the icon empty and list it for Alex (no emoji, no invented ID).
2. Build the button with the recipe (§4) at the kit's size. Put it in the left column, under any existing tiles.
3. Give it a HUD stage: it appears when the first purchase step starts (`HudStages`), with a pop-in.
4. Pressing it opens the Shop panel with the standard open motion; prices come from `GetProductInfoAsync`; unbuilt passes say "Coming soon".
5. Save the GUI to `src/StarterGui/<Gui>.rbxm` through the place build, so Alex can edit it in Studio.
6. Phone screenshot plus one side-by-side with Alex's mockup, at the same size.

## 9. Checklist
- [ ] Matches Alex's mockup; their icons; no emoji.
- [ ] ≤ 2 buttons in the first 30 s; stages reveal the rest.
- [ ] Small buttons on desktop, about 44 px on phones; whole pixels.
- [ ] Every button uses the shared motion; panels close faster than they open.
- [ ] One message line for feedback; friendly reasons; no red error box.
- [ ] Shop prices from Roblox; "Coming soon" for anything unbuilt; no "VIP".
- [ ] Saved as real parts in StarterGui.

---
name: roblox-cartoony-ui
description: Use when designing or building UI for a kid-focused cartoony Roblox game (HUD, shop, inventory, pet frames, rebirth, popups, buttons), or when UI looks flat, dark, generic or "AI-made". Gives the toy-button recipe, layout rules, hover/press motion values and AI asset tips from the AI Video Library transcripts. The owner's reference and kit always win over these defaults.
---

# Cartoony "toy" UI

Sources: `AI Video Library/Video Notes/UI/` (4 transcript notes), `AI Video Library/14 Cartoony UI & Juice.md`,
`AI Video Library/16 Cartoony Kid-Appeal Checklist.md` (UI section). Repo UI rules (StarterGui as real parts,
side-by-side with the reference, whole-pixel offsets) are in `CLAUDE.md` and override this skill.

## 1. The button / frame recipe (Kek "Greatest Cartoony UI", Figma)
Stack, bottom to top:
1. Drop shadow: Y 0 (not Figma's default 4), larger blur.
2. **Fake 3D lip**: a darker solid duplicate of the shape, offset straight down a few pixels.
3. Main shape: vertical gradient fill, corner radius **10** on nearly everything.
4. Outline: flatten shape + lip into one vector, **black stroke 3 Outside**, and under it a **white stroke 6 Outside**.
5. Inner shadow: Y 0, blur up, about 30% opacity. Inner stroke 4 Inside where a frame needs a rim.
6. Highlights and halftone textures masked on top in **Soft Light** (Overlay on buttons).
- Text: chunky rounded font (Fredoka One in the video; in Roblox use a built-in rounded font such as FredokaOne/Cartoon/LuckiestGuy,
  never the removed Gotham), dark fill with a white or dark outline stroke so it reads on any colour.
- Rarity = swap the gradient colours (orange legendary, purple epic...) on the same frame.
- In Roblox: either export Figma slices as ImageLabels, or rebuild with UICorner + UIGradient + UIStroke + a darker offset frame for the lip.

## 2. Layout and colour
- Opaque toy panels, never dark see-through glass. One dominant button per screen.
- Colour = meaning: yellow primary, green confirm, red close, blue navigate.
- Inventory template from the video: grid of pet frames, plus "Equip Best", "Delete Mode", "Filter", "Exit".
- A left-side column of menu buttons (shop, quests, map...) is a proven sim HUD.
- Thumb-reachable on phones, clear of the top bar and safe area.
- AI-made UI habits to block: **emoji icons, random boxes around buttons, TextScaled everywhere**. Use the owner's icon set.
- Give Claude a reference screenshot of a top game's UI for every UI prompt; describing it in words gives generic results.

## 3. Motion (PineappleDev "SUPER smooth buttons")
- One LocalScript handles every button, including ones created later (listen to `PlayerGui.DescendantAdded`). Skip TextBoxes.
- Hover: TweenInfo **0.3 s, Back, Out** (overshoot then settle), grow a few percent.
- Unhover: TweenInfo about **0.3-0.5 s, Sine, Out**.
- Press: quick shrink then bounce back; click sound on press, soft sound on hover.
- Keep growth small so UIListLayouts don't jitter. Shine sweep only on the main call-to-action.

## 4. AI-generated UI art (Aero, GPT Image)
- Prompt for one element at a time ("premium Roblox sub button for my simulator game", "Roblox GUI panel background").
- Upscale to 2K, remove the background (clean leftovers by hand), download max quality, **compress** before upload.
- Pack icons at 192 px or more (owner's Retina Mac). Only the owner can upload; never invent asset IDs.

## 5. Check before showing the owner
- [ ] Side-by-side with the owner's reference at the same size (repo rule).
- [ ] Every button: outline, lit top, darker lip, hard shadow, press feedback.
- [ ] Readable on a phone screenshot; nothing under the top bar.
- [ ] No emoji, no Gotham, no TextScaled blanket, no half-pixel offsets.

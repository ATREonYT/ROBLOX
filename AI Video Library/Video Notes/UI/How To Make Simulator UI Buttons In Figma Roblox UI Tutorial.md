---
tags: [roblox, video-notes, ui]
source: https://www.youtube.com/watch?v=k69tudey-vs
creator: "voidryxUI"
video_id: "k69tudey-vs"
---
# How To Make Simulator UI Buttons In Figma Roblox UI Tutorial

Back to [[00 Start Here]] · [[00 Video Notes Index]]

## TL;DR
Build a rounded, gradient, stroked button with an inner shadow and outlined text in Figma, group it, then convert to Roblox Studio using a Figma plugin by tagging layers as frames, buttons and text. Short video with poor audio and captions, few specifics.

## Tools and setup
- Figma (free tier implied; not stated).
- A Figma-to-Roblox converter plugin (name unclear in captions, "get this thing called frame" and a Roblox Studio plugin); connect it to your Roblox account.
- Roblox Studio plugin to import.

## Step-by-step
1. [00:00] Make a Frame sized to your button.
2. [00:00] Set Fill to zero (no fill on the frame).
3. [00:00] Make a square inside, and add soft (rounded) corners.
4. [00:00] Give it a gradient fill; optionally add strokes.
5. [00:00] For a 3D look: add an Inner Shadow effect.
6. [01:03] Keep blur at zero for a hard edge, or add some blur; creator likes a bit of blur.
7. [01:03] Add text: font regular (caption "Sah", unclear), black fill, white stroke, not too large; resize with the corner handle.
8. [01:03] Group (Ctrl+G) text, icon and button; duplicate to make a set (settings, shop, etc.).
9. [02:04] Color gradients to match each icon for a nicer look; name layers yourself.
10. [02:04] To convert: use the Figma plugin and the Roblox Studio plugin; tag elements: containers as Frame, clickable ones as Button, text as Text. Connect your Roblox account and import.

## Exact settings and values
| Setting | Value | Notes |
|---|---|---|
| Frame fill | 0 | |
| Inner shadow blur | 0 or some blur | creator prefers a little blur |
| Text | black fill, white stroke | stroke "not too big"; no number |
| Other numbers | None stated in the video. | |

## Prompts and skills used
No AI prompts. Plugin names not clearly audible.

## Gotchas and fixes
- Creator apologizes for bad voice and captions; a full UI tutorial is promised later.
- Plugin name is unclear; verify against the video before relying on it.

## Use it in our games
- Gradient plus stroke plus inner shadow gives the chunky simulator button look for shop and rebirth buttons.
- Use the white-stroke black-fill text as a readable label for currency counters (inferred).
- Tag-based Figma to Studio export could speed up consistent menu sets (inferred).

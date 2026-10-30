---
tags: [roblox, video-notes, ui]
source: https://www.youtube.com/watch?v=2z4rebjBnQA
creator: "PineappleDev"
video_id: "2z4rebjBnQA"
---
# Make Your Roblox UI Buttons SUPER Smooth in 8 Minutes!

Back to [[00 Start Here]] · [[00 Video Notes Index]]

## TL;DR
One LocalScript gives every button a hover grow/shrink tween and hover/click sounds, including buttons created at runtime. Uses TweenService with a Back easing hover tween and a Sine unhover tween, stored per button in a table.

## Tools and setup
- Roblox Studio: ScreenGui containing a Frame, a UIListLayout, and several TextButtons.
- One LocalScript in the ScreenGui; sound objects (click, hover) placed under the script. Free sounds: toolbox Audio tab, search "click".
- TweenService, Players.LocalPlayer.PlayerGui.

## Step-by-step
1. [00:00] Setup: ScreenGui > Frame (positioned on the left) > UIListLayout > buttons. UIListLayout lets button size animate; buttons can differ in size.
2. [00:00] Add a LocalScript. Get TweenService and the player's PlayerGui.
3. [01:00] Get the click and hover sounds (under the script) and a variable for the left UI frame.
4. [01:00] hoverTweenInfo = TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out) (caption says "3 seconds"; must be 0.3, inferred). Back overshoots then settles.
5. [02:00] unhoverTweenInfo = TweenInfo.new(0.5 as heard, Enum.EasingStyle.Sine, Enum.EasingDirection.Out) (creator says to use a faster time; value is unclear in captions).
6. [02:00] Create a local table to store tweens.
7. [02:00] setupSounds(): loop PlayerGui:GetDescendants() and call linkButtonSound(ui).
8. [03:00] Also connect PlayerGui.DescendantAdded to linkButtonSound so runtime-created buttons (e.g. inventory) get sounds.
9. [03:00] linkButtonSound(button): if it is a TextButton or ImageButton (not a TextBox): MouseButton1Click plays click sound; MouseEnter plays hover sound. Skip TextBoxes unless you want click sounds there.
10. [04:00] setupButtons(): for each child of the frame that is a TextButton (add ImageButton with "or").
11. [05:02] inProps = { Size = button.Size + UDim2.new(0.16?, 0, 0.08?, 0) } as heard ("0.16 160 0.8 oh 08 then zero"; likely scale offsets like 0.016 and 0.008, unclear). Make X bigger for wider hover, Y bigger for taller.
12. [05:02] outProps = { Size = button.Size } to reset.
13. [06:04] tweens[button.Name.."Hover"] = TweenService:Create(button, hoverTweenInfo, inProps); tweens[button.Name.."Unhover"] = TweenService:Create(button, unhoverTweenInfo, outProps).
14. [06:04] button.MouseEnter plays the Hover tween; button.MouseLeave plays the Unhover tween (also usable on click if desired).
15. [07:06] Call setupSounds() and setupButtons() at the bottom. Test: sound plays on hover and button grows then shrinks.

## Exact settings and values
| Setting | Value | Notes |
|---|---|---|
| Hover TweenInfo time | 0.3 (caption: "3 seconds") | inferred decimal |
| Hover easing | Back, Out | overshoot then settle |
| Unhover TweenInfo time | 0.5 as heard | creator: "a little faster" |
| Unhover easing | Sine, Out | direction irrelevant for Sine |
| Hover size delta | UDim2.new(~0.16/0.08 scale as heard) | captions garbled; tune by eye |
| Tween keys | button.Name .. "Hover" / "Unhover" | |

## Prompts and skills used
No AI prompts. Toolbox Audio search "click" for sounds.

## Gotchas and fixes
- Buttons created at runtime get no sounds: fix with PlayerGui.DescendantAdded.
- TextBoxes should not play click sounds; filter them out.
- Tween needs a property table, hence inProps/outProps.
- If broken, creator says rewatch and check setup.

## Use it in our games
- Drop this script as-is into the shop, rebirth and upgrade menus for a polished feel in simulators.
- Runtime-added inventory or pet buttons get hover/click sound automatically thanks to DescendantAdded.
- Keep hover growth small (about a few percent) so layout does not jitter in UIListLayout (inferred).
- Store tweens by name to also play them on purchase success (inferred).

<!-- related:start -->
## Related

- Hubs: [[00 Video Notes Index]] · [[00 Build Router]] · [[07 UI & GUI]] · [[14 Cartoony UI & Juice]]
- Playbooks: [[16 Cartoony Kid-Appeal Checklist]]
- More in UI: [[How To Make Simulator UI Buttons In Figma Roblox UI Tutorial]] · [[Make INSANE Roblox GUI Assets with AI! (GPT Image 2)]] · [[The Greatest Cartoony UI Tutorial on Roblox (w Figma)]]
<!-- related:end -->

# Tutorial Arrows and Hint Cards

How popular Roblox games point new players at things, and what we built from it (2026-11-03, after Alex said the floor chevrons and the tall card "look bad, make it minimal, see how other games do it").

## What the big games do
- **Simulators and tycoons:** a client-side guide from the player to the goal, plus a bold arrow bouncing over the goal. The guide is either a Beam from an attachment on the HumanoidRootPart to one on the target, with an arrow texture scrolling along it, or a few chunky 3D arrows. The arrows are solid bright colours with a dark outline, which is the cartoon look. Nothing glows like a laser and nothing lies flat on the road.
- **City RP games:** the GPS line lives on the minimap or full map. In the world there's only a floating marker over the destination with a name and distance.
- **Hint cards:** small. Usually one bold line ("Go to the egg!"), sometimes a small key icon, and a tiny progress count. They sit near the top or on one side, never in the middle of the screen. The pointer goes on the real UI element, tight to its shape.
- Every guide is local to the player (a LocalScript); other players never see your arrows.

DevForum threads on the method: [follow the arrows system](https://devforum.roblox.com/t/how-is-this-follow-the-arrows-system-made/297875), [arrows that guide to a point of interest](https://devforum.roblox.com/t/how-to-make-arrows-that-guide-player-towards-a-point-of-interest/422775), [ArrowBeams module](https://devforum.roblox.com/t/arrowbeams-simple-solution-to-creating-objective-arrows/3045079), [3D arrow follow system](https://devforum.roblox.com/t/how-to-make-a-3d-arrow-follow-system/3603346), [dynamic trail to a part](https://devforum.roblox.com/t/how-to-make-a-dynamic-trail-that-leads-to-a-part/1785503).

## What we built (WayfindingController, Build/Tutorial, TutorialController)
- **Arrows:** 8 bold flat arrows (a thick shaft plus a square turned 45° for the head) in cartoon yellow (255, 214, 64). They float at waist height (2.6 studs) along the walkable path, tipped 22° up toward the camera so they read from third person. **One** Highlight on the `Arrows` model draws a dark outline around all of them (Occluded, so never through walls). A thin line (a 0.16-wide Beam) links them.
- **Destination:** a big arrow pointing down, made of two crossed copies so it reads from every side. It bounces and slowly turns 6-7 studs above the spot, with a soft ring opening on the ground.
- **Smooth, no lag:** the player's place on the path is a continuous projection onto the path line (not snapped to 2.5-stud samples), eased each frame. Each arrow eases toward its spot (`1 - exp(-dt * 14)`), and the path is recomputed every 3 s (or when you stray 10 studs) instead of every 1.5 s. A new path no longer makes everything jump.
- **Hint card:** a 236 px strip at the top left, just under Roblox's top bar (16, 64). It's a semi-transparent dark panel with a tiny step count, a bold 15 px title, a 13 px instruction, small key chips, tiny dots and a "Skip" link. There's no decoration; the old tall card came from a gold edge bar being laid out as a list item.
- **Rings on UI:** the ring's offset is the target's AbsolutePosition minus our ScreenGui's AbsolutePosition. AbsolutePosition is already in one shared space, and adding the other gui's origin put rings one top-bar height off. The ring takes the target's own UICorner radius plus 5 px.

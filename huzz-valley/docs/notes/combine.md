# The Combine machine

Read before touching the Combine machine, girl grades (Silver, Gold, Diamond), girl copies in the save, or the
Combine window. Prestige (which also spends copies): [economy.md](economy.md). The one lobby the machine stands
beside: [lobby.md](lobby.md).

## Why (owner's words)
- Oct 20 14:57: "can you please anime this combine machine, add a combine sign over it, and make it so that you can
  take two of the same girl, and then it creates the same skin, but first in silver, then gold, and then diamond.
  make it so that you need to have both of the types to go up. And make nice animations with vfx, gfx, sfx, and make
  a nice merging animation. Keep it smooth and tidy. and not too long. So please take you time on this, and make it
  well made, and then you make the girls in silver, gold, and diamond."
- Oct 20 14:58: "also give the effects around the machine animations".
- "anime" means animate. His machine is `Workspace > Combine > Combine_Machine` in `places/HUSSANIME.rbxl` (513
  MeshParts: three octagon tiers with trim and glowing inlays, stairs, two arch blades, a summon ring with a crystal
  blade in it, a lotus altar with a soul orb, two pads, seven spirit flames, ofuda, rope); his screenshot is
  `design/owner-oct20/1457-combine-machine.png`.

## Rules (`Shared/CombineRules`, spec `tests/CombineRules.spec`)
- Grades: Normal, Silver, Gold, Diamond (Diamond is the top). "Grade" is the combine step, not her rarity tier.
- Two of the SAME girl at the SAME grade make one of her a grade up ("you need to have both of the types to go up").
- Saved as `Copies[id] = { Normal = n, Silver = n, Gold = n, Diamond = n }` (only grades above 0 are kept) and
  `Combines` (merges made). `Characters[id]` still says she is owned. Every win adds a Normal copy
  (`CombineRules.add`: RoundService's winner, the admin's SpawnGirl).
- Old saves: `CombineRules.migrate` on every load (DataService) gives each owned girl `Normal = 1 + Dupes[id]` once,
  drops junk grades and copies of girls no longer owned, and removes the old `Dupes` table.
- She shows at her best grade (`CombineRules.best`): the Index card's badge and picture, the Index preview, your
  companion (`CompanionService` sets `HuzzCompanionGrade`; `Gameplay/Auras` dresses her).
- Prestige still spends a spare Normal copy (`PrestigeRules` uses `CombineRules.take`, never her last copy).

## Server (`HuzzServer/CombineService`, ActionService verb `Combine`)
- Finds his machine (tag `HuzzCombine`, else `Workspace > Combine > Combine_Machine`), adds the prompt on his
  `altar_base` (E, 12 studs, attribute `HuzzOpens = "Combine"`: `Gameplay/LobbyProps` opens the window, never in a
  round or a cutscene), the sign (a BillboardGui `HuzzCombineSign`, "COMBINE" white with the dark outline and the line
  "2 SAME GIRLS MAKE 1 BETTER", over the top of his arch, readable from 260 studs) and Atomic streaming on his model.
  It never moves or rebuilds his parts.
- A merge is checked here, all of it: save loaded, one at a time and 1.5 s apart, not a Runner or Catcher, within 30
  studs of his altar, a real grade, the rules above. One `DataService.update`, then the `Combine` remote tells every
  screen (who, her model, from, to, server time), then `DataService.saveAndWait` waits (up to 10 s) for the stored
  save holding the new `Combines`, and only then answers (so the result never shows before it is saved).
- His machine stood beside a lobby copy the game puts away; `Shared/LobbyLayout.KEEP` moves it (whole, same place
  relative to the floor) beside the lobby the game keeps, before the service looks for it. Measured on his place:
  it lands at about (-182, 10) on the plaza's stand side, his grave and lantern beside it as in his copy; the stand
  row starts 4 studs past it (the stands are placed after the move and step round anything in the way), the
  nearest prop pad (Dance Pack) is about 10 studs from its tiers, the spawn pad 35 studs away.

## On every screen (`Gameplay/CombineMachine`)
- Idle (`Config/Combine.Idle`), only while the camera is within 160 studs: the ring's ticks and gems turn one way
  (26 s a turn) and its arcs and dots the other (15 s); the floor ring's ticks turn round the altar (34 s); the crystal
  blade and the soul orb float (0.18 studs, 2.6 s) and the blade sways; his spirit flames drift; his glowing trim
  breathes (SurfaceAppearance EmissiveStrength, if Roblox lets a script set it); one soft magenta light over the
  altar, soft motes rising round it, sparkles in the ring. His parts are moved from where they stand relative to his
  base tier, so moving the whole model is fine.
- The merge (`Shared/CombineMotion`, 4 s): two copies of her (2.6 studs, in their grade) appear on his pads with a
  puff, rise into the ring and circle faster and closer while the ring spins up (x6), the trim brightens (x2.2) and
  motes are pulled in; ONE burst at 2.0 s in the new grade's colour (a glowing ball, a ring of light, sparkles; kid
  safe: one flash, `Burst.flashOk`); she rises out of it turning once to face you, floats, and sinks into the altar.
  The crystal blade hides while the girls are in the ring.
- Yours also takes the camera (in front of the machine, easing in) and holds your controls; it waits at the burst
  for the server's answer and goes on, or the copies drift back to the pads if it said no. Tap anywhere to skip
  (once the server said yes). Others' merges play on the machine for everyone near, without the camera.
- Sounds (`Config/Combine.Sounds`): `combine_charge` at the start, `combine_merge` at the burst, `combine_reveal` just
  after; made by `tools/sfx/make_sfx.py`, `Config/SoundIds` "" until uploaded (until then the burst borrows the
  licensed "Magic Burst 2", the reveal a soft low ping, the charge is silent: `Gameplay/Sfx` FALLBACK).

## The window (`UI/Screens/Combine`, Flat: the pictures are ViewportFrames)
- Left: your girls (ready to combine first, then by name), each with her copies ("Normal 3   Silver 1") and READY.
- Right: copy + copy = result (pictures in their grade, `UI/GirlPicture`), the result's name ("SILVER KURUMI"), the
  grade chips (NORMAL x3, SILVER x1, GOLD x0: the picked one purple), the line under them (what it makes, or why not:
  "You need 2 Normal. You have 1.") and COMBINE (green, or grey). Pressing it closes the window, plays the merge,
  shows "GOLD YUNO!" big at the burst, then opens the window again on her.
- Preview: `shots.sh combine`; check `tools/preview/check_combine.luau` (his real machine and a real girl: server
  rules, the window, the machine's idle and a whole merge).

## Grades on a girl (`Shared/GirlGrade`, `Config/Combine.Grades`)
- Her hair and accessories (not her face) take the grade's colour and material, their picture taken off so the
  colour reads: Silver D9E0EA metal, Gold F2BE3A metal, Diamond A6ECFF see-through glass. Her clothes keep their
  pictures, tinted (Shirt/Pants Color3). Skin and face stay.
- A small effect on world copies (companion, the merge), never in pictures: Silver a few white glints; Gold glints,
  gold motes and a soft light; Diamond more glints, icy motes and a light. Roblox's own particle pictures only.
- Gold is his ask, so it is gold, but only on the girl and her badge (the windows stay without gold).

## Film and pictures
- `docs/previews/combine-machine.mp4` (`tools/preview/motion3d/combine_scene.luau`, 30 fps): idle from the lobby
  with the sign, a whole merge (2 Silver into 1 Gold) with your camera, then one girl in her four grades. His parts
  are drawn as simple shapes picked by their names (the meshes and their colour pictures only show in Studio; the
  colours are matched by eye to his screenshot); the girls are the scenes' box girl in Yuno's colours.

## Honest gaps
- Not seen in Studio yet: the whole thing. The real look of Metal and Glass hair on his girls; whether a script can
  set SurfaceAppearance EmissiveStrength (if not, the trim keeps its own glow and only our light breathes).
- The round's carried girl (the prize) is not one of your copies, so she shows no grade.
- Prestige and Combine both spend copies. Question for the owner: let Combine replace Prestige? (our pick: yes).
- Sounds are made here and wait for his upload (README checklist).

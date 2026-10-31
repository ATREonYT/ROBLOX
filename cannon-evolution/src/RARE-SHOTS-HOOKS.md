# Rare shots: the hooks outside AnimeFX (installed in Studio, Oct 31)

Studio is the source of truth and other threads were editing these files at the same time, so here are the exact small edits. `GameClient/AnimeFX.lua` holds everything else.

- **GameConfig:** `Config.RareShots` = Divine / Secret / Mythic, rarest first, with `Distance`, `Reach` and `Cutscene` fields. `Config.FIRST_MYTHIC_AFTER = 7`. Data template: `FirstMythic = false`. New sound slots: RareCharge 9125980459, RareSting 1843648200, RareBlast 9120009740, RareBoom 9125401975, RarePoof 9116406151.
- **GameServer:**
  - New remote `RareShot` (player, rareId, origin, seconds).
  - In `launch()`:
    - The Studio-only `workspace:GetAttribute("ForceRareShot")` test hook.
    - The guaranteed first Mythic, then the roll.
    - A rare shot sets `distance = max(distance, min(distance * Distance, trackLength * Reach))`, recomputes `duration` and multiplies the cash. Secret and Divine are announced to everyone.
    - The server fires `RareShot` and waits `Cutscene` seconds before `LaunchPlayer`.
- **Effects:** `local muzzle = (rareId and ctx.RareMuzzle and ctx.RareMuzzle(rareId)) or (mine and fireMyCannon())`.
- **Sfx:**
  - LEVEL: RareCharge 0.25, RareSting 0.5, RareBlast 0.7, RareBoom 0.8, RarePoof 0.45.
  - CUT: 1.4 / 1.6 / 1.1 / 1.2 / 0.6 s.
  - WITH: `RareBlast = "RareBoom"`.
- **workspace.GrandCannon:** built by `tools/BuildGrandCannon.lua`. The old mesh nodes are in ServerStorage.GrandCannonOriginal.

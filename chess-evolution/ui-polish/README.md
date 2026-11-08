# Chess Evolution UI polish (Nov 8)

Installed live in Studio by the "Restyle UI to match reference" thread. These files rebuild the same changes.

- `install_hud_polish.command.lua` (Command Bar): patches `StarterPlayerScripts.ChessEvolutionHUD`.
  - Whole-button press: the plate, icon and label of each kit button move together inside `<Name>_Press`. It squashes to 0.95 in 70 ms, springs back with a 0.22 s Back, scales from the middle, and the hit area stays still.
  - Panels: fade plus 96 to 100 % over 0.2 s, close in 0.12 s, and a closing panel takes no presses.
  - Level bar: eases over 0.15 s and retargets on fast gains. A level-up fills to the end, then starts again from empty.
  - A screen tap bumps the Elo coin at once; the number still moves only on server State.
  - Separately (by hand): the Studio-only player attribute `DevFullHud` shows the whole HUD for UI checks.
- `install_guide_darts.command.lua`: adds `ReplicatedStorage.Kit.GuideDarts` (`GuideDarts.luau`, Cannon's dart chain) and swaps ChessClient's chevron arrows for it.
- `BuildLighting_from_cannon.command.lua`: Cannon's lighting, applied as is. The old Chess lighting is in `ServerStorage.OldLighting_Chess_Nov8`, and the old ChessGrade moved there too.

Backups in the place: `ServerStorage.UIPolishBackup_Nov8` (ChessEvolutionHUD and ChessClient before these edits).

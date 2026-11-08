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

## Readable numbers, Evolve purchase and glass panels (Nov 8, later)

- **Why the numbers were blank:** `GlyphText` drew every live number (Elo, level, progress, Wins, prices, button labels) from two glyph sheet images, `rbxassetid://121275995208927` and `129374761563746`. In Play both report `AssetFetchStatus.Failure`, so the text was simply never drawn.
- `install_live_text.command.lua` (Command Bar): replaces `GlyphText.Set` with a real outlined TextLabel (FredokaOne, dark outline, sized from the same BoxW/BoxH/FitSize). It also makes the panel fade treat live text as fully visible.
- Evolve panel, set in Studio by hand (the backup is `ServerStorage.UIPolishBackup_Nov8.Evolve_beforeMarbleFlow`):
  - The Buy button is 1.2× and Skip is 0.75× and greyed, so Skip is secondary.
  - New `WinsBalanceIcon` and `WinsBalance_Live` show the Wins balance in the header.
  - `refreshEvolve` in ChessEvolutionHUD now shows the set names, the real "+N Elo / tap" before and after (TapGain × PowerMult, the same sum the server uses), the Wins balance and "Buy Marble · 8 Wins". Purchase validation is unchanged: the server Buy and Equip.
- Glass panels (Alex picked them on Nov 8): every `GlassBody` is at 0.45 transparency, with a cyan `GlassTint` Frame behind it. `FADE_PROPS` now fades Frame backgrounds too.
- Checked in Play from a fresh profile:
  - 30 taps gave 30 Elo, and the numbers show from "0 Elo / Level 1 / 0/8".
  - Beating Pawn Pete gave 10 Wins, and the trophy shows 10.
  - Buying Marble left 2 Wins, and the next tap gave +2 Elo (149 → 151).
  - The Evolve, Skip and Close presses gave 0 Elo.

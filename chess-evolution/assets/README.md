# +1 Chess Evolution assets (models thread)

Made in Blender (bpy) by `tools/blender/rivals.py`, converted by `tools/blender/build_rivals.luau`.
Rebuild: `python3 chess-evolution/tools/blender/rivals.py` then `lune run chess-evolution/tools/blender/build_rivals.luau`.
Add `--render` (and `SHOT=lineup|duel|anim:Tap`) to the Python run for preview pictures in `previews/`.

## Rivals: real Roblox avatars (Alex asked for these, Nov 7)
The live rivals are real R15 Roblox avatars kept in Alex's place under `ServerStorage > ChessRivals`, one Model per
rival id. The blocky `Rivals.rbxm` below is only a fallback. Free "NPC rig" models from the Toolbox are NOT safe:
the ones we checked (Old Man Jack, Teacher, DJ, Woman NPC, Rig Girl, Pirate) all hid `Runtime` / `ScreenBuilder`
scripts inside their attachments, so they were deleted. Don't use Toolbox rigs.

## Rivals.rbxm (fallback, no uploads needed)
Folder `Rivals` with 7 R15 rigs made of plain Parts. Original characters, no real people.

| Stage | Model | Look |
|---|---|---|
| 1 | PawnPete | green hoodie kid, backwards cap |
| 2 | KnightNadia | cobalt jacket, ponytail, gold headband |
| 3 | RookRocco | red tracksuit, flat-top, shades |
| 4 | BishopBea | plum sweater, bun, round glasses |
| 5 | QueenQuinn | ivory and gold, long hair, tiara |
| 6 | KingKai | charcoal suit, gold tie, spiky hair, headphones |
| 7 | GrandmasterOrion | final boss, 1.3x size, silver hair, goatee, gold crown, red cape |

- Standard R15 part and Motor6D names (Root, Waist, Neck, Left/Right Shoulder, Elbow, Wrist, Hip, Knee, Ankle).
- `Humanoid` (R15, HipHeight set, name display off) with an `Animator`.
- HumanoidRootPart is the PrimaryPart and is Anchored; everything else is unanchored, Massless, CanCollide off, so animations play.
- The model pivot is at the feet: `rival:PivotTo(duelTable.SeatB.CFrame)` stands it at the table at any scale.
- Rigs face -Z. Attributes: RivalId, DisplayName, Stage, Scale.
- Anchors: `Head.OverheadAnchor` (name tag and move badges), `LeftHand.HitFX` and `RightHand.HitFX` (slap sparks).
- Outfit pieces live in the `Outfit` folder, welded to their limb.

## RivalAnims.rbxm
Folder of KeyframeSequences, keyed in Blender on the same rig:
- `Idle` (loop, 2 s): leaning over the board, breathing, glancing.
- `Tap` (loop, 0.36 s): frantic two-hand slapping of the clock and board. Speed it up with `track:AdjustSpeed()` as the clicks get faster.
- `Victory` (1.5 s): crouch, jump with both arms up, then fist pumps.
- `Defeat` (1.6 s): recoil, slump, hands on head.

They also play on players' R15 avatars, since the joint names are standard. In Studio, play them with
`KeyframeSequenceProvider:RegisterKeyframeSequence(ks)` (a temporary id, Studio only). For the live game Alex
publishes each one (right-click the KeyframeSequence > Save to Roblox) and sends back the ids.

## DuelTable.rbxm
A stand-up blitz table: wooden top with gold trim, an 8x8 board with a few pieces, and a chess clock.
Pivot at the table centre on the ground. Anchors (invisible parts):
- `SeatA` at +Z (player, hub side, facing -Z) and `SeatB` at -Z (rival, facing +Z), at ground level.
- `ClockButtonA` (green, player side) and `ClockButtonB` (red, rival side) are the neon clock buttons.
- `BoardTop` is the board's top surface centre.

## Treadmill and piece meshes (`meshes/`, need Alex to import)
Made by `tools/blender/kit.py` (`python3 kit.py --export --pieces`). The sizes and colours are in `meshes.json`.
- `meshes/<TreadmillId>.obj`: one object per colour: `_Chassis`, `_Rail`, `_Console`, `_Trim`, `_Screen` (Neon),
  `_Steel` (Metal), and `_Belt` (optional, since the game's own Belt part scrolls). Units are studs and Y is up.
  The runner faces -Z, the console is at the -Z end, and the origin is the deck centre on the ground, the same
  frame as `Models.Treadmill`. Keep the game's invisible anchors (Deck, Align, Console, Screen, LabelAnchor, FX).
  The meshes only replace the visible parts.
- `meshes/Piece_<Kind>.obj`: one closed mesh per piece (Pawn, Knight, Bishop, Rook, Queen, King), about 4 studs
  tall with the base on y = 0. Recolour each set (Wooden, Marble and so on) with MeshPart.Color and Material.
- Import: Studio > Avatar/Home > Import 3D, pick the .obj, and keep the scale at 1. It makes a Model of MeshParts
  named like the objects above. Then set each MeshPart's Color and Material from `meshes.json`.
- Every object stays under 6k triangles.

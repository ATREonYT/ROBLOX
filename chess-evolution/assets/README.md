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
Made by `tools/blender/kit.py` (`python3 kit.py --export --pieces`). The sizes, colours, triangle counts and prop spin data are in `meshes.json`.
They follow the vault's `Build Playbooks/23 Training Lane Style Guide` (checked side by side with sheet 1 in `previews/side_by_side_sheet1.png`):
- **Shared shape for every tier:** the body is dark (30, 34, 45), with thin neon lines on the rails, glowing corner blocks, slim uprights,
  a tall console with a dark glass screen and short handlebars with neon grips. The belt is dark and the rollers sit recessed.
- **One colour per lane plus white:** each tier has its own neon colour (`NEON` in kit.py), and its chess shape is white.
  - Pawn Mill: pawn handlebar caps.
  - Knight Sprint: two knights hold up the console.
  - Bishop Run: mitre finials.
  - Rook Rig: rook towers.
  - Queen Dash: crown console.
  - King's Endgame: stepped supports.
  - Castle Climb: castle gate.
  - Grandmaster Glide: a king and a queen as the uprights.
- **Higher tiers win by shape, not glow (§3):** from Queen Dash up, each lane adds a dark rubble "spill" with neon specks and one
  moving prop, `<Id>_Prop`. Spin the prop about Y once every 8 s around `spin.centre_roblox`. These meshes have no particles,
  no lights and no flashing.
- The game's code still does the motion (§2): the belt texture scrolls about 2 studs per second, the neon breathes between 0.8
  and 1.0 (once every 3 s, or 2.5 s on paid lanes), there are at most 3 moving things per lane, and the row stays under 150 particles.
- Objects in each `<Id>.obj`: `_Body`, `_Panel`, `_Chess`, `_Neon` (Neon), `_Steel` (Metal), `_Belt` (optional, since the game's Belt part scrolls),
  and on higher tiers `_Spill` and `_Prop`. Units are studs and Y is up. The runner faces -Z, the console is at the -Z end, and the origin
  is the deck centre on the ground. Keep the game's invisible anchors (Deck, Align, Console, Screen, LabelAnchor, FX).
- `meshes/Piece_<Kind>.obj`: one closed mesh per piece, about 4 studs tall, with the base on y = 0. Recolour each set with Color and Material.
- Import: Studio > Import 3D > the .obj, at scale 1. Then set each MeshPart's Color and Material from `meshes.json`.

## Animation rules used (vault notes 16, 17 and 19)
- `Tap` uses five poses per strike: anticipation (Cubic In), a contact in 1 frame (Linear), follow-through, then recovery (Cubic Out).
  The head lags the hands by a frame.
- `Idle` and `Tap` move only the torso, head and arms. The legs are Weight 0, so a player can walk while one plays.
- Hit-stop belongs in code, never in the clip: 30–60 ms on a confirmed hit.

## Treadmills v2: chess style (Nov 7, `meshes_v2/`, need Alex to import)
Made by `tools/blender/kit2.py` (`python3 kit2.py --export --render`). Same ids, size (about 11 x 8 x 14 studs) and axes as v1.
- Side rails are two chessboard ranks (8 ivory/dark squares each) over a neon strip in the lane colour.
- The console is a chess clock: two dials with a neon ring, two plunger buttons (the pressed one glows).
- Uprights are two big pieces of the lane's tier (Grandmaster: queen and king) on a podium with a neon foot ring.
- Paid tiers (Queen Dash and up) add captured pieces lying around the base and one floating piece `<Id>_Prop`
  (turn once per 8 s, bob 0.3 studs over 2 s, data in `meshes_v2.json`).
- Belt: `meshes_v2/BeltChecker.png` is a dark checker for the scrolling belt Texture (StudsPerTile 2.5). Needs upload.
- After Import 3D, paste `tools/studio/paint_treadmills_v2.lua` in the Command Bar to set every part's Color and Material.
- Preview: `previews/treadmills_v2.png`.

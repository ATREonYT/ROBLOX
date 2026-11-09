# Props in the screenshots (Phase 4 list)

Status: **built** = modelled in `scripts/build_scene.py`; **asset** = Alex's file placed unchanged; **UI** = a Roblox
BillboardGui or SurfaceGui text/icon that is part of the HUD layer, so it is not modelled; **skipped** = left out, with the reason.

## Treadmill view (terraceA_closeup) and the hub's left stand
| prop | status | notes |
|---|---|---|
| 8 treadmills | asset | From `ChessTreadmills/studded/`, matched by colour. **Front row:** KingsEndgame (yellow, left), RookRig twice (the red centre pair, two instances of one prototype), KnightSprint (blue, right). **Rear shelf:** QueenDash (x8), CosmicGrandmaster (x999, the gold ring), RoyalCastle (x99, white-gold), BishopRun (x12, purple). Scaled 1.4x to the stations' size in the screenshot and turned 90° so each entry faces the path. |
| purple/blue block on the right | built (already) | The World 2 portal, turned 45°. |
| machine name tags, prices, UNLOCKED/lock text | UI | BillboardGuis. |
| green shrub blocks by the path | built (already) | |
| chessboards (one per side) | skipped | Alex chose to skip them: no chessboard.blend exists in the ROBLOX folder. |

## Phone view (terraceB_closeup) and the hub's right stand
| prop | status | notes |
|---|---|---|
| 6 glowing gems on the top tier | built | One blocky crystal mesh shared by six linked duplicates, each with its own glow colour sampled from the screenshot (teal, ice, red, lime, gold, indigo). |
| 5 items on the middle-tier pads ("trophies") | built | One upright phone-slab mesh shared by five linked duplicates. Each glows gold or white, plus a bright screen. The screenshot's items are sparkly hologram phones; these are blocky stand-ins. |
| pedestals | built (already) | The six black plinths and five coloured pads (mint, cyan, red, black, black). |
| lock icons | built | One padlock mesh as 8 linked duplicates: one over each gem, plus two over the locked pads 4 and 5. In the game these are probably billboard icons; they are modelled because the brief asks for them. |
| "Wooden Phone / x1 / OWNED" etc. labels | UI | BillboardGuis. |
| big trees on both sides | built (Phase 3) | |

## Hub view (hub_overview)
| prop | status | notes |
|---|---|---|
| machines on the left stand | asset | The same 8 as above. |
| items on the right stand | built | The same gems, phones and locks. |
| "1 Like = 1 Sub" | built | Extruded white text on the front face of the block right of the lane mouth. Blender's default font stands in for the game's rounded font. |
| Hologram Phone pad | built | A purple glowing frame with a translucent cyan phone, at (-18, -45), back-projected. |
| spawn marker by the lane mouth | built | A dark square with a yellow glowing rim, at (18, 50.5), back-projected. |
| World 2 portal | built (already) | |
| water rails and stones | built (already) | |
| glowing yellow-to-magenta streak by the water | skipped | Looks like a moving trail effect, not a world part. |
| players, name tags, HUD | skipped | The brief says to ignore them. |

## Lane view (lane_view)
| prop | status | notes |
|---|---|---|
| coloured pads per bay (red mat with markers, yellow and magenta tiles) | built (already) | |
| colourful stacked frames at the far end | built (already) | The stage gates, cycling through the colours. Stages 2 and 3 are unlocked in this shot, so they are hidden in this view only. |
| "Stage N" labels on the gates | UI | |

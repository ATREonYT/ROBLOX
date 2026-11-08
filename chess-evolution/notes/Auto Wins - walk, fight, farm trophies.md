# Auto Wins: walk, fight, farm trophies (Nov 8)

Built live in the owner's Studio place (+1 Chess Evolution). The live Studio scripts are the
source of truth; this note records exactly what was added so it can be merged back into any
`src/` copy.

## What it does (clip 2 of the Nov 8 reference videos)
- **Auto Wins** switch in the top bar is free (it used to open the Shop). ON/OFF shows on the button,
  and one message line says "Auto Wins ON/OFF".
- While on, the character walks down the lane to the next rival it has not beaten.
  - Enough Power: it fights the rival on its own (taps at 6 a second, the same cap as a hand).
    The result panel closes by itself after 1.4 s and it carries on.
  - Not enough Power: it walks to the **trophy** of the newest rival it has beaten (that stage's
    Return pad), collects that stage's Wins, gets sent back to the hub, and walks again.
    Once a new rival is beaten, it farms that new trophy instead.
  - Nothing beaten yet and too weak: it waits near the first rival and says how much Power is needed.
- Return pads of beaten stages now show "Return" over "+N Wins" (like the reference's pads), and
  stepping on one by hand pays too, with a "+N Wins" toast.

## Rules kept
- Wins are paid only on the server (`Game.luau`, Return handler): the player must stand on a beaten
  stage's Return pad, and at most once per walk from the hub (distance to spawn / 22 s, at least 2 s).
- Pay = stage `reward` x `WinsMult` (promotions, 2x Wins pass), same as a fight win.
- Power still only comes from treadmills (and Auto Train / packs). Auto Wins farms Wins, it does not
  make Power, so a player who never trains will farm the same trophy until they train.

## Code added (live Studio)
### ServerScriptService.Chess.Game
- `local trophyAt: { [Player]: number } = {}` next to `battleSent`; cleared on PlayerRemoving.
- `Net.Handle("Return")`: before the teleport, loop `config.Stages`; if `d.Cleared[id]` and the root
  is inside that stage's `Return` part (`insideZone(root, pad, distanceSlack, 8)`) and the walk
  cooldown passed, add the Wins, `markDirty`, `updateLeaderstats`, log `trophy <id> +N wins`.
  Returns `Net.ok({ trophy = paid })`.

### StarterPlayerScripts.LoopClient
- `shortcut(hud.TopBar.AutoWins, "Shop")` replaced by a switch that flips the LocalPlayer attribute
  `AutoWins` and shows ON (priceGreen) / OFF (red) on `TopBar.AutoWins.State`.

### StarterPlayerScripts.ChessClient
- Return pad touch: shows `+N Wins` toast when the server paid a trophy.
- New block "Auto Wins" just above the "Frame loop" section: `lastCleared`, `trophyWins`,
  `refreshTrophies` (adds `Line2` to each `ReturnLabel`), `walkTowards` (keeps to the lane's centre
  line x = 0 until level with the target so it never clips an earlier Return pad), `stepAutoWins`,
  and a Heartbeat loop that auto-taps during a fight and steps the walk every 0.25 s.

## Tested in Studio (Play, Nov 8)
- From 99 Power: beat Stage 1 and Stage 2 on auto, then farmed Stage 2's trophy (+20 every ~12 s).
- From 231 Power: beat Stages 1-3 on auto, then farmed only Stage 3's trophy (+40 each lap).
- No errors in Output. First try clipped Stage 2's pad on the way to Stage 3; fixed by the centre-line walk.

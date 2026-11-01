# Training lanes install (Nov 1)

How the treadmill-style lanes went into Alex's Studio (cannonevo2.rbxl), through the Studio MCP `execute_luau` in Edit mode:

1. `probe.luau`: read-only look at what is live.
2. `stage1_find_hand_edits.luau`: backs up TrainingStations (ServerStorage.HandEditBackups.Lanes-Nov1), keeps TrainingShop, LaunchZone, the spawn, MyCannonSpot and LaunchPoint as they are (ServerStorage.LaneInstallKeep), rebuilds the old lanes once to diff against, then puts the live lanes back. Nov 1 result: 0 hand edits inside the lanes.
3. `stage2_build_lanes.luau` (set `SKIP` to hand-edit keys you do not want back): BuildWorld1 + BuildRebirthSigns at the new commit, studs on the lanes only, saves the hand-edit baseline for TrainingStations, puts hand edits back, restores the kept objects and adds StarterPlayerScripts.LaneMotion.

The baseline is now saved in the place, so the next lane install diffs against it directly. Change `NEW` to the commit you install.

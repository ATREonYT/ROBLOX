# Ready-to-open place file

`build_place.sh` writes `hood/places/HoodEvolution.rbxl`, a Roblox place you can open in Studio directly. It holds:

- every script from `hood/src`, laid out the way Rojo syncs them (`.meta.json` properties included, so the unit test
  runner stays disabled);
- The Block V2 already built in Workspace, set as the active map, with its Front-page Day lighting applied.

```sh
sh hood/tools/place/build_place.sh              # needs Lune: brew install lune (or rokit add lune-org/lune)
```

It runs the same offline harness as the previews (`hood/tools/preview/harness.luau`): the harness builds the map, then
saves the whole DataModel when `HOOD_PLACE_OUT` is set.

## Opening it
1. Double-click `HoodEvolution.rbxl`, or in Studio use File → Open from File.
2. Press Play. You spawn in the warehouse lobby.
   - The map sits at x = 2400, so if you want to look around in edit mode first, select `TheBlockV2` in the Explorer and press F.
3. To keep editing with Rojo, connect the Rojo plugin to `hood/default.project.json` as usual. It syncs the scripts on top
   of the same layout.

In Studio the game keeps your profile in memory only (`ServerConfig.StudioDataMode = 'Mock'`). It runs without
publishing or API access, and every Play starts fresh at 0 Power.

The place is a snapshot. After code changes, either rebuild it with this script, or in your own place run
`require(game.ServerStorage.TheBlockV2).Build()` in the Command Bar after Rojo syncs.

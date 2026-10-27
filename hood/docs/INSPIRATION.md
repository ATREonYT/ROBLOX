# Inspiration: the owner's other games (Oct 26)

Notes from two place files the owner sent, measured with Lune and drawn in our preview renderer. Pictures:
- `refs/inspo_alien_map_sheet.jpg`: the Alien map.
- `refs/inspo_huss_lobby_sheet.jpg`: the owner's own Huss game.

The preview can't draw MeshParts with their real textures, so Huss's meshes show as plain blocks. In the game they're fully textured; judge only layout and colour from that sheet.

## The owner's Huss game ("turned out quite good")

The full project is on branch `HUZZ-VALLEY` (`huzz-valley/`). Its lessons are in `GAME-FEEL.md` and `huzz-valley/docs/notes/` on that branch. The owner built it with the same `CLAUDE.md` way of working, and it turned out well.

Take general lessons from it. **Don't copy it one to one** (owner, Oct 26). The hood game keeps its own look: the soldier-game style, the warehouse, and the hood theme.

**The lobby** (`StartingPoint`: a ~124×136 plaza, about 560 parts):
1. **One hero centrepiece.** The character showcase sits on a wooden-railed stand lit by 4 lanterns, and every view lands on it. A lobby needs one clear focal point, with nothing competing.
2. **A raised, dressed edge.** Stepped dirt terraces ring the plaza. Theme props (trees, lanterns, graves, white fences) sit on the terraces, never on the floor. The middle stays calm and open.
3. **Floor colour fields.** A big red carpet over tan dirt, in irregular patches. A few big fields beat one uniform tile.
4. **Warm accent lights.** Small Neon lanterns mark entrances and the centrepiece. They're glows on objects, not light pools.
5. **The play area is visible from the lobby.** The game field sits right beside the plaza.

**Build and look:**
- Mostly smooth surfaces: studs on only ~12 % of part faces.
- Materials: Plastic, Metal, Wood, Pebble and Concrete. About 3,600 MeshParts, 589 of them with SurfaceAppearance.
- **Lighting** (`huzz-valley/docs/notes/look-and-lighting.md`): even, cartoony light, the owner's own request.
  - ShadowMap; a soft sun over a strong sky fill: Brightness 1.4, Ambient 150,150,160, OutdoorAmbient 210,210,218, EnvironmentDiffuseScale 1.
  - The result: a cast shadow keeps ~0.53 of the lit floor; the shade is slightly blue; lamps are turned down.
  - Sky: a blue Atmosphere plus real Terrain Clouds.

**Working style worth copying** (from that branch's notes):
- Leaderboards turn smoothly to face you and never clip into the build.
- Movement: walk first, then build up to a run; our own footsteps; the head follows the mouse.
- Spawns are checked for open ground (no edges, no props in the body's box).
- A small "build <date>" stamp in the corner, so any recording shows which code ran.
- Pure rules modules with unit tests, bot simulations, and camera maths kept pure so offline films match the game.

## The Alien map
Stage worlds in strips, each a themed colour (green Earth, orange, grey Moon).
- **One grid.** Every block is a multiple of ~8.2 studs; edges line up.
- **Terraces and framing.** 8-stud steps, tall clay cliff blocks with grass tops framing the walk, open sky.
- **Grass drips.** Green strips run down the brown cliff faces: a signature detail, and cheap.
- **The path.** A grey stone path (#A3A2A5) inset into the grass, with a darker edge.
- **Few materials and colours, no clutter.** A few rocks and trees on the terraces only.
- **Effects and gates.** White sparkle emitters rise from interactables; glass panels serve as barriers between areas.
- **Classic studs.** Plastic with all six faces Studs on 62 % of parts. The owner chose this for the hood game (Oct 26: "Classic studs everywhere"), replacing the earlier faint-studs rule.

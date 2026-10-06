# Offline preview: build the game's maps without Studio and render them

Two tools that let you (or Claude) check builders, props and effects without opening Roblox Studio.

## Setup (once)
- **Lune 0.10.5** (runs Luau with a Roblox instance library): download from
  https://github.com/lune-org/lune/releases (or `rokit add lune-org/lune@0.10.5`).
- **Renderer:** `cd hood/tools/preview/render && npm install` (three.js and Playwright). It drives a headless
  Chromium; set `CHROME=/path/to/chrome` if Playwright's own browser isn't installed.

## 1. Harness: run game code, export the scene
```sh
cd hood/tools/preview
lune run harness.luau ../../src out.json "return require(game.ServerStorage.TheBlockV2).Build()"
```
It builds a fake DataModel from `hood/src` (Rojo layout), runs the snippet, and writes every BasePart in
Workspace (plus ParticleEmitters, Beams, lights and GUI text) to `out.json`. Use `-` instead of a file name to
skip the export, e.g. for the unit tests:
```sh
lune run harness.luau ../../src - "return require(game.ServerStorage.UnitTest.RunUnitTest)()"
```
`lune run syntax.luau <file.lua> ...` compiles files and reports syntax errors.

## 2. Renderer: pictures of the exported scene
```sh
cd hood/tools/preview/render
W=1200 H=800 node shoot.js ../out.json views.json shots/
```
`views.json`: `{"options":{"time":3,"noFog":true},"views":[{"name":"spawn","pos":[x,y,z],"look":[x,y,z],"fov":60}]}`.
`time` is how many seconds the particle emitters have been running. `builtinOnly: true` shows the effects
with Roblox's built-in textures (the look before the PNGs in `hood/art/vfx` are uploaded). Effect textures
are read from `hood/art/vfx`; `render/vfx` only holds preview-only extras.

The renderer approximates Roblox: no bloom, simple lighting. Judge layout, proportions, colour and effect
density, then confirm the final look in Studio.

# Picture to 3D Model (blender-image-to-3d skill)

Added Nov 7, 2026. The skill files live in `.claude/skills/blender-image-to-3d/` (Obsidian hides that folder, so this note is the way in).

## What it does
Give Claude a picture (concept art, a screenshot, a sketch, a photo) and it builds the model in Blender, step by step:
1. Measures the picture and writes a short brief (sizes, parts, what is guessed).
2. Blocks out the rough shape and checks the outline against the picture from the same camera.
3. Adds shapes and detail only once the outline matches.
4. Cleans the mesh, bakes textures, and adds a rig if it moves.
5. Exports FBX or GLB, then re-imports it to check nothing broke.

It never says "looks fine" from the viewport: each step needs a render next to the picture.

## How to ask for it
- "Make this into a 3D model" plus the picture. Naming the skill is optional; Claude picks it up when you send a reference picture and ask for a model.
- Say what it is for: a pet, a sword, a car, a building.

## Getting it into Roblox
- Import the FBX in Studio with **3D Importer** (File > Import 3D). It becomes a MeshPart.
- The skill is not Roblox-specific: check the size in Studio, and keep it low-poly (Roblox caps a single mesh at 20,000 triangles).
- For the blocky, classic-stud look, `blender-roblox-models` is still the better fit.

## Limits (honest)
- Needs Blender. It works on your Mac with Blender installed. Cloud sessions don't have Blender yet, so Claude has to install it first.
- Not yet tested in this repo.
- From a third party: `majidmanzarpour/blender-game-skills` (MIT licence, copied unchanged, licence in the skill folder).

## Links
- [[00 Build Router]] (Blender models row)
- [[04 Building, Maps & 3D Models]]

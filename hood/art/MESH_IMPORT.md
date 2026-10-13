# Put your blocky models into the game (once, about 10 minutes)

These steps bring your designs into the game: the Robux pad prizes, the lobby pieces, the plaza trees and buildings, and the guns.
You only do this once. Until you do it, the game still works and shows the old block-built versions.

**You need:** Roblox Studio on your Mac, your game open in Studio, and this project folder on your Mac.

## Step 1: Import the 4 model files

1. In Studio, click **File** in the top menu bar, then **Import 3D...**
2. Go to the project folder, then `hood` > `art` > `models` > `items`.
3. Hold **Cmd** and click all four files: `Items_Pads.glb`, `Items_Lobby.glb`, `Items_Scenery.glb`, `Items_Guns.glb`.
   Click **Open**. (If Studio only takes one file, do steps 1 to 5 four times, once for each file.)
4. The import window has settings on the right. Check these and leave everything else as it is:

   | Setting | Set it to |
   |---|---|
   | Import Only As Model | **on** |
   | Upload to Roblox | **on** (this uploads the colours too) |
   | Set Pivot to Scene Origin | **on** |
   | Anchored | **on** |
   | World Forward | **Front** |
   | World Up | **Top** |
   | Scale Unit | **Stud** |
   | Merge Meshes | **off** |

5. Click **Import** (bottom right) and wait until it finishes.
   Rows of colourful models appear in the Workspace: a row of guns, a row of pad prizes, a row of lobby pieces and a row of trees and buildings.

## Step 2: Run the setup script

1. Click **View** in the top bar, then **Command Bar**. A long text box opens at the bottom of Studio.
2. On your Mac, open `hood/tools/blender/studio_item_meshes.lua` with **TextEdit**.
   Press **Cmd+A** (select all), then **Cmd+C** (copy).
3. Click into Studio's Command Bar, press **Cmd+V** (paste), then press **Return**.

The script tidies everything up. It moves every model into **ReplicatedStorage > HoodItemMeshes** and makes the glowing parts glow.
It also makes the big things (buildings, cliffs, the gate pillars, the stands) solid, and lets players walk through the small ones.

## Step 3: Check it worked

1. Click **View > Output**. You should see these two lines:
   `[HoodItemMeshes] done: 57 items ...` and `[HoodItemMeshes] all 57 items are in. Now File > Save to Roblox.`
   - If it says **still to import** with some names, one of the four files is missing. Do Step 1 for that file, then Step 2 again.
2. In the **Explorer**, open **ReplicatedStorage > HoodItemMeshes**. You should see `Gun_AK`, `Pad_VIP`, `Gate_Stage1`, `Scn_Tree_1` and more.
   Click `Pad_Base`: its ring is glowing blue.
3. Press **Play**. Your gun is the new blocky gun, and the gun stand shows the new guns.
4. Click **File > Save to Roblox** (or **Publish to Roblox**) so the models stay.

## If something looks wrong

- **A model is plain white or grey (no colours).** Its colour picture did not come in.
  1. Delete **ReplicatedStorage > HoodItemMeshes**.
  2. Do Step 1 again, and make sure **Upload to Roblox** is **on**. Then do Step 2.
  3. The Output names the parts without colours. They have a yellow line saying `came in without their colour texture`.
- **The colours look smeared or blurry at the edges.** Take a screenshot and send it to the developer. The colour pictures can be made sharper. Everything still works.
- **Something does not glow.** Run Step 2 again. It sets every `_Glow_` part to Neon again.
- **The Output says a model "came in turned or stretched".**
  1. Delete **ReplicatedStorage > HoodItemMeshes**.
  2. Do Step 1 again with **World Forward = Front** and **World Up = Top**, then do Step 2.
- **You want the old block versions back.** Delete **ReplicatedStorage > HoodItemMeshes**. Nothing else changes.

## Good to know

- Rojo never touches HoodItemMeshes. It only manages `ReplicatedStorage.Shared`.
- If a model changes later: import its file again, then run Step 2 again. Step 2 replaces the old copies.
- The chests (code chest, group chest and the shoe boxes) stay the block-built ones the game already has.
- The 5 Robux guns (Neon Viper, Galaxy Ray, Inferno Cannon, Frostbite and Royal Crown) come in too. They are not for sale in the game yet.

## For developers

```sh
# rebuild the package from the designer's folders (each holding Guns/ RobuxPads/ Lobby/ PlazaScenery/ ShootingRanges/ with glb/)
python3 hood/tools/blender/build_item_package.py --src <designs a> --src <designs r> --src <designs s>
#   -> hood/art/models/items/Items_{Pads,Lobby,Scenery,Guns}.glb + manifest.json,
#      hood/tools/blender/studio_item_meshes.lua (from the .template.lua) and ItemMeshes.Design in Shared/ItemMeshes.lua
$PY hood/tools/blender/icons_glb.py          # the Gun_* and pass icons from the GLBs -> hood/art/icons3d (then upload_assets.py)
```

- The code side is `Shared/ItemMeshes.lua`.
  - `ItemMeshes.place(id, cf, size?, parent, fallbackFn)` puts the model's bottom centre on `cf`. `size` can be a box (the model fits inside it, proportions kept), a number (its longest side), or nil (the design size). Without the import it calls the Part build instead.
  - `GunModels.build` returns the gun mesh when there is one, so the held gun, the hip gun and the gun stand use it.
- The mesh files are GLB (glTF), not FBX. Studio's importer reads glTF's embedded palette textures and node names directly, and it needs no unit fix.

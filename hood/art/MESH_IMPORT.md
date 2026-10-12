# Import the item meshes (once, about 5 minutes)

This turns the boxes, the product-pad items and the gun-stand guns into smooth, rounded 3D models.
You do it once. If you skip it, the game still works and shows the block-built versions.

You need: Roblox Studio on your Mac, your game place open, and this repo on your Mac.

## 1. Open the 3D Importer

1. In Studio, open your place.
2. Click **File** (top menu bar) > **Import 3D...**
3. Pick `hood/art/models/items/HoodItemMeshes.fbx` and click **Open**.

## 2. Settings (right-hand panel of the import window)

Set these, leave everything else as it is:

| Section | Setting | Value |
|---|---|---|
| File General | Import Only As Model | **on** |
| File General | Upload to Roblox | **on** |
| File General | Set Pivot to Scene Origin | **on** |
| File General | Anchored | **on** |
| File Transform | World Forward | **Front** |
| File Transform | World Up | **Top** |
| File Geometry | Scale Unit | **Stud** |
| File Geometry | Merge Meshes | **off** |

Click **Import** (bottom right). Wait until the spinner stops: there are about 180 pieces (25 items), so it can take a few minutes.
A big grey model appears in the Workspace, with the items standing in rows. Grey is fine: step 3 colours them.

## 3. Run the setup script

1. Click **View** (top bar) > **Command Bar**. A long text box opens at the bottom.
2. On your Mac, open `hood/tools/blender/studio_item_meshes.lua` in TextEdit.
   Press **Cmd+A**, then **Cmd+C**.
3. Click into Studio's Command Bar, press **Cmd+V**, then **Return**.

The script moves every item into **ReplicatedStorage > HoodItemMeshes** (one model per item), colours it, and
deletes the empty imported model.

## 4. Check it worked

1. Click **View > Output**. You should see:
   `[HoodItemMeshes] done: 25 items, 178 MeshParts in ReplicatedStorage.HoodItemMeshes`
   and `[HoodItemMeshes] all items have the right shape.`
2. In the **Explorer**, open **ReplicatedStorage > HoodItemMeshes**. You should see `Box_Street`, `Box_Grail`,
   `Pad_VIP`, `GunStand_AK` and the rest. Click `Box_Street`: it is red and white, and has a `Lid`.
3. Press **Play**. The boxes on the dais, the pad items and the guns now have smooth rounded edges.
4. **File > Save to Roblox** (or **Publish to Roblox**) so the meshes stay.

If the Output says an item "came in turned", delete the HoodItemMeshes folder, and do steps 1-3 again with
World Forward = Front and World Up = Top.

## Good to know

- To go back to the block-built items, delete **ReplicatedStorage > HoodItemMeshes**. Nothing else changes.
- Rojo sync leaves the folder alone (it only manages `ReplicatedStorage.Shared`).
- When the items change in Blender, re-export (below), import again, and run the script again: it replaces the old
  items.
- A place rebuilt from scratch with `tools/place/build_place.sh` has no meshes: import them again there.
- The meshes need no textures, so only the meshes are uploaded (step 2's "Upload to Roblox"). There is no
  `.rbxmx` route: a MeshPart cannot carry its mesh in a file without that upload. An Open Cloud upload script was not
  added either: it would upload the FBX as a Model asset that you then still have to insert into the place, so the
  importer is fewer steps.

## For developers

```sh
blenv/bin/python hood/tools/blender/export_item_meshes.py            # all items -> the FBX, manifest.json, the script
blenv/bin/python hood/tools/blender/export_item_meshes.py --list     # the item ids
blenv/bin/python hood/tools/blender/export_item_meshes.py --shoes    # also the 22 World 1 pairs (off by default: little gain)
blenv/bin/python hood/tools/blender/export_item_meshes.py Box_ --obj /tmp/meshes   # some items, + preview OBJs
```

The code side is `Shared/ItemMeshes.lua`: `ItemMeshes.place(id, cf, size, parent, fallbackFn)` clones the item (its
bottom centre on `cf`, fitted to `size`) or calls the Part build; `BoxModels.build` and `ShoeModels.pair` use the
mesh by themselves when it is there.

# Uploading the HUD icons and UI textures

Until these images are uploaded the game still works: `IconModels` shows each icon as a live 3D part model and `UIKit`
draws the studs with UI frames. Uploading swaps in the rendered PNGs, which look like the reference and cost far fewer
instances.

| Folder | What | Where the id goes |
|---|---|---|
| `hood/art/icons3d/<Id>.png` | 512x512 icons, transparent, navy outline baked in | `IconModels.Images.<Id>` in `src/ReplicatedStorage/Shared/Models/IconModels.lua` |
| `hood/art/ui/<file>.png` | tileable textures (studs, gloss) | the `UIKit.lua` line `Kit.<Name> = '' -- hood/art/ui/<file>.png` |

Every id is written as `'rbxassetid://<number>'`.

The icon PNGs are rendered by `hood/tools/blender/icons_hd.py`. The textures come from `hood/tools/make_ui_textures.py`.
You never need to run either of them to upload.

## A. With the tool (recommended)

`hood/tools/upload_assets.py` needs only plain `python3`, with no pip installs. It uploads through Roblox Open Cloud,
then writes the ids into the two Lua files.

### 1. Make an API key (once)
1. Open https://create.roblox.com/dashboard/credentials (Creator Dashboard > Open Cloud > API Keys) and click
   **Create API Key**.
2. **Access Permissions:** add **Assets API** and tick **Read** and **Write**.
3. **Security:** add your IP address to the allowed IPs. `0.0.0.0/0` allows any IP, but it is less safe.
4. Pick an expiration date. Create the key and copy it. Roblox shows the key only once.
5. If the game belongs to a **group**, make the key under that group. You also need permission there to create assets.

### 2. Find the creator id
- **Your own account:** use the number in your profile URL, `roblox.com/users/<id>/profile`.
- **A group:** use the number in the group URL, `roblox.com/groups/<id>/...`.

Upload to the same creator that owns the game. Otherwise the images might not load in it.

### 3. Run it
```sh
cd path/to/ROBLOX
export ROBLOX_API_KEY='paste-the-key'      # stays in this terminal only; the tool never prints it
export ROBLOX_CREATOR_ID=1234567
export ROBLOX_CREATOR_TYPE=User            # or Group
python3 hood/tools/upload_assets.py --dry-run   # the plan: what would upload and which lines change (no network)
python3 hood/tools/upload_assets.py             # upload + write the ids
```
After the upload, Rojo syncs the two Lua files into Studio. If you don't use Rojo, copy the changed lines into Studio by
hand.

- **Re-running is safe.** `hood/art/asset_ids.json` records each file's hash and asset id. Files that haven't changed
  are not uploaded again, and their ids are written again. A PNG that changed is uploaded as a new asset. Commit
  `asset_ids.json` along with the Lua files.
- `--only Basket,stud_bevel` uploads just those files (give the names without `.png`).
- `--force` uploads everything again.
- `--write-only` uploads nothing. It writes the ids from `asset_ids.json` into the Lua files, for example after a
  `git checkout` or after a new `Kit.` line was added.
- **Moderation:** a new image stays blank in game until Roblox approves it, usually within minutes. The tool prints the
  moderation state.

### Troubleshooting
- **`HTTP 401/403`:** the key needs **Assets API: Read + Write**. Your IP must be in the key's allowed list. The
  creator id and type must be you, or a group where you can upload.
- **`TLS certificate check failed` (Mac):** run `/Applications/Python 3.x/Install Certificates.command` once, or use
  `/usr/bin/python3`.
- **`UIKit.lua has no line for <file>`:** add `Kit.<Name> = '' -- hood/art/ui/<file>.png` to `UIKit.lua`, then run
  `--write-only`.
- **`HTTP 429`:** this is the rate limit. The tool waits and retries on its own.
- **`--asset-type Decal`:** this is a fallback for when the API refuses `Image`. A Decal id is not an image id. To get
  the image id, paste the decal id into any ImageLabel's **Image** property in Studio, and Studio converts it. Put that
  converted id in the Lua file.

## B. By hand in Studio
1. Open **View > Asset Manager > Images** and click **Bulk Import** (the upload icon). Select every PNG in
   `hood/art/icons3d/` and `hood/art/ui/`. Studio names each asset after its file.
2. When the upload finishes, right-click each image and choose **Copy Asset ID**.
3. Paste the ids:
   - **Icons:** in `IconModels.lua`, under `M.Images`, set `Basket = 'rbxassetid://123456789', -- Basket`, and so on.
     The key is the file name without `.png`.
   - **Textures:** in `UIKit.lua`, set the line whose comment names the file. For example:
     `Kit.StudBevel = 'rbxassetid://123456789' -- hood/art/ui/stud_bevel.png`.
4. Optionally, record the ids in `hood/art/asset_ids.json` too, so the tool knows they're done. The format is
   `{"icons3d/Basket.png": {"assetId": "123456789", "sha256": "<sha256 of the file>"}}`. Without the sha256, the tool
   uploads that file again.

Re-running `hood/tools/blender/export_luau.py` (which regenerates `IconModels.lua`) keeps every id already in
`M.Images`.

## The icons (file name = id)

**HUD column:**
- `Basket`: the orange Store square.
- `Rebirth`: the red-and-white ring of two arrows.
- `Sneaker`: Shoes, the Pets slot.
- `Gun`: Guns, the Items slot.
- `Quest`: the scroll.
- `Rewards`: the gift.

**Counters and the bottom bar:**
- `Rebirth`
- `Cash`
- `Muscle`: the flexed arm, used for Power.
- `Trophy`
- `PowerPack1`, `PowerPack2`, `PowerPack3`: the arm alone, then with one bolt, then with bolts and a glow.

**Offers and passes:**
- `DoubleCash`
- `DoublePower`: the gold studded dumbbell (no text: the UI adds the "2x" sticker).
- `AutoFight`
- `VIP`

**Windows:**
- `BasketRed`: the Store header.
- `RebirthSkip`: the green Skip Rebirth arrows.
- `Arrow`: the green arrow at 45 degrees.
- `Evolve`: the same arrow pointing up.
- `Shield`: the XP badge with an empty face.
- `XP`: the XP badge with its letters.
- `Skull`: the fight pill.
- `Robux`: a flat white face with dark-green lines, as on the reference's price buttons; ImageColor3 can still tint
  it gold or lime.

**Older ids, still in use as fallbacks:** `Shop`, `PVP`, `Power`.

## The textures
| File | UIKit line | How UIKit draws it |
|---|---|---|
| `stud_bevel.png` | `Kit.StudBevel` | one rounded raised stud a tile, pre-shaded (light rim top/right, dark rim left/bottom); ImageColor3 white |
| `stud_checker.png` | `Kit.StudChecker` | 2x2 rounded studs, raised and recessed (recessed face ~12% darker); TileSize = 2 x pitch |
| `stud_tile.png` | `Kit.StudTile` | one stud, greyscale; tinted with the block's lip colour |
| `gloss_band.png` | `Kit.GlossBand` | two diagonal light bands, stretched over a block |
| `gloss_stripes.png` | `Kit.GlossStripes` | seamless 45-degree stripe; ScaleType Tile over headers |

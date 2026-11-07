# The icon pack

The skill works without it. The pack is a separate zip of about 3,000 images and SVGs for menus, shared as `FOLK Icon Pack.zip`. People keep it in Downloads, Desktop or Documents, so they should not have to say where it is or unzip it.

## Using it

The images on disk have no Roblox IDs until they are uploaded. Never upload the whole pack: take only what the screen needs.

1. Find the icons. `icons.py` searches for the pack itself, and reads it without unzipping:

```bash
py scripts/icons.py find cash gem scroll
```

2. Choose by looking at them. Read the likely files with your image tool, and prefer `Glossy` and `Bold`, then `Outline`. Copy the choices out:

```bash
py scripts/icons.py get "<temp folder>" "<path from find>" "<path from find>"
```

3. Upload them as `references/studio-workflow.md` describes, and tell the user which ones you are uploading, because they go on the account signed in to Studio.
4. Put the IDs in the game's own config, in a `name = id` table, so they are never uploaded twice. Do not write them into the kit.

If the search finds no pack, say so once and carry on with the kit's placeholder icons. Use `--pack "<path>"` if the user names a place.

## What suits this style

| Need | Look for |
|---|---|
| Rail squares | Menu buttons: `Rebirth_Glossy`, `ShopBasket_Glossy`, `Backpack_Glossy`, `Trophy_Glossy` |
| Rewards and prices | `Cash_Glossy`, `CashBundle_`, `Gem_Blue_Bold` |
| Crates and eggs | The `Eggs` folder. Large files are shrunk to 1024 on upload, which is fine |
| Weapons and items | `Sword`, `Shield`, `Key`, with `Outline` in the name |
| Key prompts | `Keyboard Keys`, the `_4x` files only, because the others are too small |

- Avoid the small gamepass icons at hero size, because most are under 128 px and look soft. Anything shown over about 100 px needs a file of 256 px or larger.
- Files with `Flat` or `White` in the name are plain and look flat beside vivid cards. Use them only for small marks.
- The kit's `sticker` adds a black outline and shadow, so an icon that has no outline of its own still fits.
- SVG files are not images Roblox accepts. Use the PNG beside them.
- `Browse all icons.html` in the zip shows everything by name, if the user unzips it and wants to pick by eye.

## Licences

Only `Ranks` and `Keyboard Keys` come with a licence: CC0 from RhosGFX. The other folders have none in the pack, and its README names a community catalog as the source. Say this before someone ships them in a released game.

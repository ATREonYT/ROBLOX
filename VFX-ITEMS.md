# Effects for items (knives, swords, pets, anything you equip)

How we give items effects that fit the skin and read as "worth more" the rarer they are. Learned on Huzz Valley's
knives (Oct 20, owner: "make the vfx for some swords way better and more detailed, make them better for more high
end ones" ... "check out the references provided ... Make them fit and logically connected to the skin of the
sword"). The worked example: `huzz-valley/src/ReplicatedStorage/Shared/KnifeLook.lua` (`VFX`, `vfx`), `Shared/KnifeFx.lua`
(builds them), `huzz-valley/docs/notes/knives.md` ("Knife effects: the Huss Valley study").

## 1. Study the reference skin first
- Get the reference game's recording. Find frames where a high-end item is close and still, and crop to the item
  (same crop at 3 moments a fraction of a second apart, so you see what moves). Also one frame in a swing or use.
  Huzz Valley's tool: `huzz-valley/tools/preview/knife_vfx_reference.py`.
- For every high-end skin write one row: particle shape (dot, star, wisp, petal, flame), how many on screen at once,
  size against the item, how long each lives, speed and direction (rises, sinks, drifts, pulled in), its colour
  against the skin, any light or glow, whether it also shows when the item is worn or on a stand, and what changes
  when it's used.
- Write down what they don't do. Huss Valley's best skins have 2 or 3 small round motes in the gem's colour
  drifting slowly near the blade, a glowing gem, at most a soft haze; no spark shower, no big arc, no flash. That
  restraint is what makes them look expensive.

## 2. Tie each effect to its skin
- **Colour:** take it from the skin's accent, its gem or glowing part (not the main colour). A cyan gem on a white
  blade gives cyan motes. Start the particle a little lighter and end it in the accent colour.
- **Motif from the name:** fire = embers rising off the edge, ice = frost mist and snow sinking, void = motes pulled
  inward and a dark swirl, celestial = light motes rising and a glow at the halo, blood moon = red drips falling,
  sakura = petals drifting off sideways, storm = short electric wisps and tiny sparks, witch/candy/pumpkin = the
  matching colours with sparkles or wisps. Write a table: item key -> theme. Never guess a theme the name doesn't say.
- **Placement:** put each effect where the skin's detail is: the glint on the gem (the biggest glowing part that
  isn't the blade), a star at the tip, motes in one invisible box over the whole blade. One box, never the item's
  small slices: effects coming off a sliver read as "missing pixels".

## 3. The tier ladder
| Tier | Effect |
|---|---|
| Common, Uncommon | nothing but the use trail, faint |
| Rare | a few motes in the accent colour |
| Epic | + the theme's motif, a few sparkles on use |
| Legendary, Mythic, paid | + a glint on the gem, a faint haze, one soft light, a longer trail |
Where it shows: in hand the full set; on a shop stand a little more; worn about half, no light, no burst. Higher tiers
get more kinds of effect and better placement, not more particles.

## 4. Recipes that need no upload
Only use pictures that ship with Roblox, or none. An image id you haven't uploaded shows as a white square.
- `ParticleEmitter` with `Texture = "rbxasset://textures/particles/sparkles_main.dds"` (a star sparkle: glints,
  sparks), `fire_main.dds` (a soft flame: embers, small flames), `smoke_main.dds` (a soft round puff: motes, mist,
  haze, petals with Squash). Typical mote: Rate 1 to 3, Lifetime 1.2 to 1.8, Speed 0.2 to 0.4, Size 0.2 studs fading
  in and out (NumberSequence 0 -> 0.2 -> 0.08), Transparency 1 -> 0.05 -> 0.05 -> 1, LightEmission 1, LightInfluence 0,
  Drag 0.5, Shape Box / Volume on the invisible blade box.
  - Rising: Acceleration (0, 2, 0). Sinking: (0, -1, 0). Drips: (0, -6, 0) with Squash 1.2. Sideways drift: X accel.
  - Pulled in: an invisible ball round the item, Shape Sphere, ShapeStyle Surface, ShapeInOut Inward.
  - Stuck to the item while it swings: LockedToPart true (glints, halos, wisps).
  - Dark smoke: LightEmission 0, LightInfluence 1, a dark colour.
  - A burst on use: Rate 0 and `Emit(n)` from the use code, n stored as an attribute on the item.
- `Trail` with no Texture: a plain colour ribbon in the skin's two colours, Lifetime 0.2 to 0.35 s, on only in the swing.
- `Beam` with no Texture for a slash arc; a `Highlight` only for a short outline moment.
- `PointLight`: one per item at most, Brightness about 0.6, Range about 5, Shadows off, never blinking.
- Neon parts already glow; a gem in Neon is half the effect.

## 5. Kid-safe and performance limits
- At most one flash a second; glints at 0.6 a second or slower; nothing strobes or blinks.
- About 12 particles a second per item at most, 6 per emitter; one light at most; nothing running every frame
  (build the emitters once on the server, they replicate).
- Worn items: lighter, and switch them off past ~70 studs from the camera (one loop twice a second on the client).
- A test over every item: tier 0 plain, totals under the cap, only `rbxasset://` particle pictures, worn not more than
  in hand, light only at the top tier.

## 6. Pitfalls
- White squares: a Texture id that isn't uploaded yet. Use the built-in pictures above or leave Texture empty.
- "Missing pixels": stand-in slices of a model, or effects pinned to a thin slice, read as broken. Emit from one
  invisible box over the whole item.
- ViewportFrames (shop and crate previews) don't draw particles: use the item's glow and a backlight there.
- The offline preview draws look-alikes of Roblox's pictures; the real look, sizes and light are Studio's. Say so.
- Lune's Roblox API is old: set newer properties (ShapeInOut, ShapeStyle) inside pcall.

## Proposed line for the root CLAUDE.md "Game feel"
- Item effects: read `VFX-ITEMS.md`; study the reference skin frame by frame, tie each effect to the skin (accent colour, motif from the name, placed at its gem or edge), scale by tier with restraint, and use only Roblox's built-in pictures.

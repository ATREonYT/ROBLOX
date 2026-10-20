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
- **Match the reference's visibility, not just its restraint.** Measure each effect against the item (MELON5MAN:
  a mote 5% of the knife's length across, solid and saturated; the gem's glowing orb 15%; 2 to 4 motes on show at
  once) and check it in a side by side at the same framing before showing anyone. Our first pass copied "few and
  small" but not "clearly there": next to theirs it showed almost nothing, which an owner reads as "no effects".
  Few particles is fine; faint particles is not.

## 2. Tie each effect to its skin
- **Colour:** take it from the skin's accent, its gem or glowing part (not the main colour). A cyan gem on a white
  blade gives cyan motes. Keep that colour all the particle's life with little LightEmission (about 0.3): a bright,
  additive particle over sky or grass washes out to white and the colour is lost.
- **Motif from the name:** fire = embers rising off the edge, ice = frost mist and snow sinking, void = motes pulled
  inward and a dark swirl, celestial = light motes rising and a glow at the halo, blood moon = red drips falling,
  sakura = petals drifting off sideways, storm = short electric wisps and tiny sparks, witch/candy/pumpkin = the
  matching colours with sparkles or wisps. Write a table: item key -> theme. Never guess a theme the name doesn't say.
- **Placement:** put each effect where the skin's detail is: the glint and a glow on the gem (a part named gem,
  guard gem first; never the model's own baked effect bits such as aura rings or floating shards), a star at the tip, motes in one invisible box over the whole blade. One box, never the item's
  small slices: effects coming off a sliver read as "missing pixels".

## 3. The tier ladder
| Tier | Effect |
|---|---|
| Common, Uncommon | nothing but the use trail, faint |
| Rare | one or two faint motes in the accent colour |
| Epic | 2 crisp ball motes, the theme's motif, the gem glowing, a few sparkles on use |
| Legendary, Mythic, paid | the reference's level: 3 crisp ball motes (4 on a shop stand), the gem a solid glowing ball, the motif readable worn, a glint on the gem, one soft light, a longer trail |
Where it shows: in hand the full set; on a shop stand a little more; worn about 0.8, no light, no burst. Higher tiers
get more kinds of effect, better placement and a clearer gem, not a cloud of particles.

## 4. Recipes that need no upload
Only use pictures that ship with Roblox, or none. An image id you haven't uploaded shows as a white square.
- `ParticleEmitter` with `Texture = "rbxasset://textures/particles/sparkles_main.dds"` (a star sparkle: glints,
  sparks), `fire_main.dds` (a soft flame: embers, small flames), `smoke_main.dds` (a soft round puff: motes, mist,
  haze, petals with Squash). Typical top-tier mote on a 3-stud knife: Rate 2.5, Lifetime 1.2 to 1.8 (3 or 4 on
  show), Speed 0.15 to 0.35, Size 0.32 studs (smoke_main's bright middle is about half that) fading in and out
  (NumberSequence 0 -> 0.32 -> 0.13), Transparency 1 -> 0 -> 0 -> 1, Color the gem's colour start to end,
  LightEmission 0.3, LightInfluence 0, Drag 0.5, Shape Box / Volume on the invisible blade box.
  - Rising: Acceleration (0, 2, 0). Sinking: (0, -1, 0). Drips: (0, -6, 0) with Squash 1.2. Sideways drift: X accel.
  - Pulled in: an invisible ball round the item, Shape Sphere, ShapeStyle Surface, ShapeInOut Inward.
  - Stuck to the item while it swings: LockedToPart true (glints, halos, wisps).
  - Dark smoke: LightEmission 0, LightInfluence 1, a dark colour.
  - A burst on use: Rate 0 and `Emit(n)` from the use code, n stored as an attribute on the item.
- `Trail` with no Texture: a plain colour ribbon in the skin's two colours, Lifetime 0.2 to 0.35 s, on only in the swing.
- `Beam` with no Texture for a slash arc; a `Highlight` only for a short outline moment.
- `PointLight`: one per item at most, Brightness about 1, Range about 6, Shadows off, never blinking.
- A glowing gem: a SOLID Ball Part on the gem (Material Neon, the gem's colour, Transparency about 0.1, the gem's own
  size, welded to the gem, CanCollide / CanQuery / CanTouch off, Massless, CastShadow off), with the PointLight and
  the game's BloomEffect as its soft halo, plus a locked smoke_main puff on the gem (Rate 1.5, Size 0.9). Not a big
  see-through ball round the hilt: that reads as a pale bubble, "cheap". It never changes, so it's kid-safe.
  Anything that hides the item's stand-in parts must leave it showing. No gem part, no ball.
- Crisp motes (what soft particles can't do): 2 to 4 small Neon Ball Parts, about 5% of the item's length, in the
  gem's colour, Transparency 0.1 at full. Make them on each client only (server-made moving parts replicate every
  frame): the server just marks the item (a CollectionService tag + attributes: count, colour, size, drift, seed).
  One RenderStepped loop moves every marked item's balls with a pure path function (Huzz Valley:
  `huzz-valley/src/ReplicatedStorage/Shared/KnifeMotes.lua`): each floats a few seconds on a soft loop off the
  item's edges, never inside it, fading in and out over 0.8 s (smoothstep), staggered so 2 or 3 show at once,
  then starts a new path. Anchored, no shadow, collide, query or touch, in one folder. Every quarter second, drop
  the balls of items far from the camera (70 studs) or on an invisible player. Keep particle motes only as a light
  extra.

## 5. Kid-safe and performance limits
- At most one flash a second; glints at 0.5 a second or slower; nothing strobes or blinks.
- About 16 particles a second per item at most, 6 per emitter; one light at most; nothing running every frame
  (build the emitters once on the server, they replicate).
- Worn items: lighter, and switch them off past ~70 studs from the camera (one loop four times a second on the
  client). Switch every item's particles off while its owner is invisible: motes give a hidden player away.
- A test over every item: tier 0 plain, totals under the cap, only `rbxasset://` particle pictures, worn not more than
  in hand, light only at the top tier.

## 6. Pitfalls
- White squares: a Texture id that isn't uploaded yet. Use the built-in pictures above or leave Texture empty.
- "Missing pixels": stand-in slices of a model, or effects pinned to a thin slice, read as broken. Emit from one
  invisible box over the whole item.
- ViewportFrames (shop and crate previews) don't draw particles: use the item's glow and a backlight there.
- The offline preview draws look-alikes of Roblox's pictures; the real look, sizes and light are Studio's. Say so.
- Too faint to see is a failure too: "restraint" means few and slow, not pale and tiny. Check the side by side.
- The reference's crisp glowing dots are usually solid Neon balls, not particles: a soft built-in puff can't match a
  hard edge however you tune it.
- A model's own baked glow bits (aura rings, shards, sparks) are not its gem: pick the gem by name first.
- Lune's Roblox API is old: set newer properties (ShapeInOut, ShapeStyle) inside pcall.

## Proposed line for the root CLAUDE.md "Game feel"
- Item effects: read `VFX-ITEMS.md`; study the reference skin frame by frame, tie each effect to the skin (accent colour, motif from the name, placed at its gem or edge), scale by tier, match the reference's visibility as well as its restraint (check a side by side), and use only Roblox's built-in pictures.

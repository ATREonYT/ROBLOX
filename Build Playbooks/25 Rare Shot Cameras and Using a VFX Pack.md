---
tags: [build-playbooks, vfx, camera, cutscene, rare-reveal, vfx-pack, sfx, lessons]
updated: 2026-11-01
---

# 25 Rare Shot Cameras and Using a VFX Pack

Back to [[00 Build Router]] · The spec: [[22 Rare Shot VFX Spec from Alex's References]] · Reveal ladder: [[17 Do It Like the Hits - Animation, VFX and Feel]] §2 · Recipes: [[19 Animation and VFX Recipe Book]] (chase cam, ultimate cutscene) · Working in Studio: [[24 Working Live in Studio - Saves, Turns and Hand Edits]]

**What this is.** The lessons from building the Mythic, Secret and Divine cannon shots with Alex (Oct 30 to Nov 1): what Alex pushed back on, what fixed it, and how to use a bought or gifted effects pack without it looking copied. Numbers are the ones that shipped in the rework; Alex still has to judge them in Studio.

## 1. What Alex disliked, and the fix
| Alex saw | Why it looked wrong | The fix that worked |
|---|---|---|
| "Pill shapes" flying instead of a fireball | Plain stretched parts read as a placeholder | The pack's **fireball and projectile trail** (fire, smoke, sparks and a streak) ride the ball and **face where it flies** |
| A bubble ("egg") round the player | A sphere round the hero hides them and reads as a shield, not power | Removed. Power comes from **wind spiralling up** round the player and **energy gathering at the chest** |
| The camera stuck behind crates and walls | A scripted camera ignores the map | Every cutscene shot checks the path from the target to the camera and moves in front of anything in the way |
| The Secret ball dropped off the cliff | The launch angle was too flat for the big cannon | The ball **shoots up in a big arc** out of the golden cannon first, then falls |
| Divine felt short | The best shot had the least screen time | Divine is now **7 s** with a slow half-circle orbit to show off the angel cannon (wings that flap gently, a glowing halo) |
| "Are these the pack's effects or copies?" | It wasn't said plainly | Say it in the first message: same textures and settings from the pack, only colour, size and brightness changed (§4) |

## 2. The camera plan per tier
Normal shots never cut: a **chase camera** sits behind the ball, low over the water, and hands back the moment the ball lands (recipe in note 19). Rare shots earn cuts; the rarer the shot, the more angles.

| Tier | Shots, in order | Notes |
|---|---|---|
| Mythic | 1. **low hero shot** under the player · 2. **raised shot** with the player and cannon both in frame · 3. **over the cannon**, looking down the river as it fires | Three quick angles; the fire happens on angle 3 |
| Secret | 1. **slow orbit** round the golden cannon · 2. **low shot under the barrel** as it fires | The orbit sells the cannon's size |
| Divine | 1. **close-up** on the cannon · 2. **slow half-circle orbit** round the angel cannon · 3. wide for the finale | The longest and slowest; one big flash at most per second (note 22 §3) |

**Camera rules that held up:**
- **Every shot avoids walls.** Raycast from the subject to the planned camera spot; if something is hit, put the camera just in front of it.
- **Cuts, not spins.** Orbits are slow (a half circle over seconds); nothing spins fast. Spinning cameras make kids feel sick.
- **A rumble builds before every rare shot.** A small shake that grows over the charge, inside the `Setting_ScreenShake` limit, then one kick on the fire.
- **Colour grading shifts per tier:** magenta for Mythic, gold for Secret, navy turning to white-gold for Divine. Use one ColorCorrection, tween it in, and tween it fully back.
- **Always give the camera back** (`RareReveal` does it), and offer **Skip** after 1 s on Secret and Divine.

## 3. Using a VFX pack well
Alex's pack (`VFX PACK.rbxl`, about 330 effects, no scripts) was the source for the rare shots. What worked:
1. **Read the whole pack first** and list it (name, what it looks like, what textures it uses). Then pick a few per job. The rework uses **18** effects out of about 330.
2. **Pick by job, not by wow.** Every rare shot needs: a charge, a fire shockwave, a flash, an aura on the player, a ground crack, wind, an explosion or burst, and a flight trail. Divine adds a holy beam, stars and shine; Secret adds lightning.
3. **Leave out anything that looks ripped from another big game.** A few textures in the pack were clearly from other popular games; we skipped them (our own-assets rule).
4. **Rebuild in code instead of importing parts.** Store each effect as data (texture, flipbook, size, speed, lifetime, spin, emit timing) and build it at run time. The place stays clean, one module (`RareFXPack`) holds everything, and it can be tested offline.
5. **Change only three things:**
   - **Colour:** tint to the tier (pink, gold, white-gold); keep white parts white-hot.
   - **Size:** scale to the object it sits on (a bigger charge on the giant cannon).
   - **Brightness:** cap `Brightness` at **6**. Some pack effects run at 25, which blows out to plain white on a sunny map.
6. **Offer the originals.** "If you'd rather have any of them exactly as in the pack, tell me which." Alex decides.

## 4. Using a sound pack well
Alex's `SFX.zip` has **812** sounds. The rare shots use **5**, all from Roblox's licensed library:
- **Charge-up:** a rising electric charge.
- **Title card:** a short stinger.
- **Release:** a thruster blast, with a deep boom under it.
- **Roar:** short breathy magic bursts.

Lessons:
- **Layer two sounds for the big moment** (a sharp top sound plus a deep boom), not one loud one.
- **Fewer, better sounds.** Five well-placed sounds beat twenty. Normal shots stay quiet (note 17: Stone Skipping's normal throws are quiet).
- **Only licensed or our own sounds.** Our own come from `<game>/tools/sfx/make_sfx.py`; Alex uploads them and sends the IDs. Never invent an ID.

## 5. Saying it to Alex
- Name the effects by what they look like ("the fireball", "the holy beam"), not by file or script names.
- Say plainly what came from the pack and what was changed.
- Say what only Studio can show: real brightness on the map, phone speed, and whether the camera clears every wall from every spot.

## 6. Checklist for a rare shot
- [ ] Each tier has its own camera plan; nothing spins fast; walls are avoided.
- [ ] The ball shows a real fireball and trail facing its flight, never placeholder shapes.
- [ ] Nothing hides the player (no bubble).
- [ ] Pack effects are tinted, sized and capped at Brightness 6; ripped-looking textures are left out.
- [ ] At most one big flash per second; flashes-off and shake-off settings respected.
- [ ] The camera comes back, Skip shows after 1 s on Secret and Divine, and the grading tweens fully back.
- [ ] Two-layer sound on the fire; licensed or our own sounds only.

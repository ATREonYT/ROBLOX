---
tags: [build-playbooks, vfx, rare-reveal, cannon, anime, impact-frames, kid-safe, reference-study]
updated: 2026-10-31
---

# 22 Rare Shot VFX Spec from Alex's References

Back to [[00 Build Router]] · Ladder: [[17 Do It Like the Hits - Animation, VFX and Feel]] §2 · Recipes: [[19 Animation and VFX Recipe Book]] · Anime: [[15 Anime VFX and Animation Playbook]]

**What this is.** On Oct 31 Alex sent 4 VFX clips they love and asked us to make the rare cannon shots like them, using the VFX pack. This note is the frame-by-frame study and the build spec for **Mythic, Secret and Divine**.
- Frames: `research_notes/Alex VFX references Oct 31/frames/` (`contact_sheet.jpg` first).
- Everything was measured at 30 fps: brightness per frame with ffmpeg `signalstats` on the game area only, plus 12-frame strips around each big moment.
- **We copy the timing and the layering, never the art.** The clips use other creators' models (a dragon head, characters) and textures. We build with our own textures, `AnimeFX`, `RareReveal` and the effects in Alex's VFX pack that the rare-shot thread already cleared (charge-up, flame aura, ground crack, lightning, explosion, shockwave, holy beam aura, stars).

## 1. The four clips in one line each
| Clip | Colour | Length of the effect | What makes it |
|---|---|---|---|
| Ref 1 | Ice blue with a red rival | 16 s of fight | A rim-lit outline aura that never stops, and one-frame white "ink" bursts on each hit, followed by 2 flat rings on the ground |
| Ref 2 | Toxic green | 10 s | The whole screen turns one colour for 2 frames. Black lightning tendrils, grey frames, a dark "inhale", then vortex rings and a light pillar |
| Ref 3 | Purple and pink | 13.5 s, the most cinematic | Glowing eyes and a spiked halo, 3 black/white impact frames, streak lines and petals, and a final white starburst that blooms into a dome, then calm |
| Ref 4 | Violet with cyan | 8 s | Dark spikes growing, 2 white frames, a shock dome and pillar, a 4-blade pinwheel star, and lightning around a big head with laser eyes |

## 2. What they all do (the rules we take)
1. **Darken before the hit.** Brightness falls to about 30–45 (out of 255) just before every big hit. Ref 2 at 5.85 s has a 5-frame dark "inhale", then a +75 jump. **Contrast makes the hit, not size.**
2. **Impact frames are 1–3 frames of two-tone art:**
   - Ref 3 at 2.90 s: 3 frames of black ink on white, then the colour comes back.
   - Ref 2 at 0.50 s: 2 frames of flat green with a black silhouette.
   - Ref 1: a single white frame on each hit.
3. **Fast in, slow out.** After the peak, brightness falls over 5–6 frames (about 0.2 s), never in one step. For example, Ref 3 at 10.07 s goes 149 → 131 → 103 → 87 → 73.
4. **One hue plus white.** Each clip uses one saturated colour, a white-hot core and near-black shadows. Nothing else.
5. **Rim light on the character** (Ref 1 and Ref 3): a bright outline makes the hero readable against a dark sky.
6. **Ground answers the sky.** Every hit lands with 1–2 flat rings or a dome on the ground (Ref 1, Ref 4), plus debris (petals, shards) that lingers 0.5–1 s.
7. **Camera cuts, not one long shot.** Close-up, then wide, then a push-in. The biggest moment gets its own angle.
8. **End calm.** Ref 3 fades to a quiet sky for 0.5 s after the finale. The quiet ending sells the size.

## 3. Our kid-safe limits (these override the clips)
The clips flash 2–4 times a second (Ref 2 hits at 0.50, 1.03, 1.93 and 2.83 s). **We don't.**
- **At most one bright flash per second.** A 1–3 frame impact-frame burst counts as **one** flash. Gate every flash with `Emit.TryFlash()`, which also respects `Setting_Flashes`.
- **With flashes off:** swap each impact frame for a **dark** two-tone frame (black silhouette on the tier colour at 60% brightness). There is no brightness spike, and the beat still reads.
- Full-screen tint: at most 30% opacity, at most 0.1 s, except inside the impact frames themselves.
- Shake stays at Bump or below and follows `Setting_ScreenShake`. Camera cuts are fine; spinning is not.
- Every reveal gives the camera back (`RareReveal` already does), and Secret and Divine get a **Skip** button after 1 s.
- No horror faces. Ref 4's toothy dragon head is out for our kid game; we keep its *timing* (lightning, laser-eye lines, white ring), not the monster.

## 4. Build spec per tier
Times are from the moment the player fires. Frame counts are at 30 fps. Colours follow the tiers the rare-shot thread already uses.

| Tier | Main colour | Core | Shadow |
|---|---|---|---|
| Mythic | pink (255, 80, 170) | white | deep purple (40, 10, 50) |
| Secret | gold (255, 200, 60) | warm white | black-brown |
| Divine | white-gold (255, 240, 200) plus sky blue (150, 210, 255) | white | navy (15, 20, 50) |

### 4.1 Mythic: 3.0 s (the structure of Ref 1)
| Time | Frames | What happens | Build with |
|---|---|---|---|
| 0.00–0.40 | 12 | Charge at the cannon mouth; the world dims to 70% (ColorCorrection Brightness −0.15) | Pack **charge-up**; `RareReveal` wash |
| 0.40 | 1 | **Impact frame**: a white ink starburst behind the cannon, the cannon in black silhouette (one flash) | `AnimeFX.ImpactFrame(1/30)` with our `star6` and `slash_arc` textures |
| 0.43–0.65 | 7 | Fire, plus 2 flat rings on the water: the first grows 1×→4× in 0.3 s, the second starts 2 frames later, 1×→3× | `AnimeFX.Shockwave` ×2, `LaunchFX.Fire({ tier = "Mythic" })` |
| 0.40–3.0 | — | A pink **outline aura** on the cannon and the ball, pulsing slower than once a second | Highlight (OutlineColor pink, FillTransparency 1) plus pack **flame aura** at Rate 20 |
| 0.7–2.4 | — | Chase camera; the ball trails pink with white sparks | `LaunchFX.Flight` |
| 2.40 | 1 | Landing: dark "inhale" for 3 frames (brightness to 60%), then a crater and 2 rings, **no flash**: Mythic keeps its one flash for the shot | `AnimeFX.Crater`, `Shockwave` |
| 2.5–3.0 | 15 | Petals and sparks settle; the world brightens back over 0.3 s | Pack **stars**, Emit 12 |

### 4.2 Secret: 4.5 s (the structure of Ref 2, gold instead of green)
| Time | Frames | What happens | Build with |
|---|---|---|---|
| 0.00–0.50 | 15 | Gold **lightning** crawls up the cannon; the ground cracks under it | Pack **lightning** and **ground crack** |
| 0.50–0.57 | 2 | **Impact frames**: the whole screen flat gold, with the cannon and player as black silhouettes (one flash) | A ScreenGui frame plus `ImpactFrame` |
| 0.57–0.70 | 4 | Black lightning tendrils over a desaturated world (Saturation −1 for 4 frames) | Our `slash_arc` in black; ColorCorrection |
| 0.70–1.20 | 15 | Fire: shockwave dome plus explosion; slow-motion 0.5× for 0.2 s (catch-up after) | Pack **explosion** and **shockwave**; `LaunchFX` stop 0.12 |
| 1.2–2.9 | — | Flight with a gold beam trail and orbiting rings around the ball (2 rings, 1 turn every 1.2 s) | `LaunchFX.Flight`, Beams |
| 2.90–3.07 | 5 | **Inhale**: the world darkens to brightness 45 over 5 frames just before landing | ColorCorrection tween |
| 3.07 | 1–2 | Landing **burst**: a vortex of 3 gold rings plus a light **pillar** rising (the second flash, 2.5 s after the first) | `Shockwave` ×3, Beam pillar, pack **holy beam** recoloured gold |
| 3.1–4.5 | — | The pillar fades over 0.8 s; gold shards linger; Skip shows from 1.0 s | `Emit` shards, `RareReveal` skip |

### 4.3 Divine: 5.0 s (the structure of Ref 3, the most cinematic)
| Time | Frames | What happens | Build with |
|---|---|---|---|
| 0.00–0.60 | 18 | **Close-up** on the cannon: two glowing "eyes" (twin glints) light up on the barrel, a spiked halo ring grows behind it, and the sky darkens to navy | Camera cut (`RareReveal` orbit start), `star4` glints, `ring_broken` halo |
| 0.60–0.70 | 3 | **Impact frames**: black ink on white, 3 frames, the strongest moment (one flash) | `ImpactFrame(0.1)` with our ink shapes |
| 0.70–0.80 | 3 | Dark rim silhouette of the cannon with a sky-blue edge | Highlight outline |
| 0.80–1.40 | 18 | **Cut wide**. Fire: holy beam aura, white-gold streak lines shooting outward, petals start | Pack **holy beam aura** and **stars**, `AnimeFX.SpeedLines` |
| 1.4–3.4 | — | Flight; the camera pushes in slowly; a white-gold trail plus floating petals | `LaunchFX.Flight` |
| 3.40–3.53 | 4 | Inhale: everything darkens to brightness 40 | ColorCorrection |
| 3.53 | 2 | **Finale**: 2 white frames → a starburst (the second flash, 2.9 s after the first) | Pack **explosion** recoloured white, `star6` |
| 3.6–3.8 | 6 | The colour streaks fall away over 5 frames: 100% → 85% → 70% → 58% → 49% | `Emit` with a Size and Transparency curve |
| 3.8–4.4 | 18 | A bloom dome grows over the landing, then pops into petals and shards | Dome mesh (ForceField), `Emit` petals |
| 4.4–5.0 | 18 | **Calm**: the sky returns to normal over 0.5 s, the petals drift down, and the camera is returned | `RareReveal` restores the camera |

## 5. Five numbers to check on a 30 fps capture (the side-by-side)
1. Impact frames last **1–3 frames**, never more.
2. The brightness dip before a hit is **at least 4 frames**.
3. The fall after the peak takes **5–6 frames**, not 1.
4. Flashes are **at least 1 s apart** (count the white frames).
5. Each tier ends with **at least 0.4 s of calm** before the camera returns.

## 6. Honest gaps
- Brightness numbers were measured on screen recordings of Studio inside TikTok frames. The timing is reliable; the exact colours are not.
- The VFX pack's effect names come from the rare-shot thread, which read the whole pack on Alex's Mac (about 330 effects, no scripts) and uses 18. What shipped and why: [[25 Rare Shot Cameras and Using a VFX Pack]].
- Ref 4's monster head is left out on purpose (kid-safe and not ours).

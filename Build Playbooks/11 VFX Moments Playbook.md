---
tags: [build-playbooks, vfx, particles, juice, moments]
updated: 2026-10-30
---

# 11 VFX Moments Playbook

Back to [[00 Build Router]] · Layers, property cheat-sheet, tier ladder and budgets: skill `roblox-vfx` (sections 1–7) · Item effects: `VFX-ITEMS.md` · Juice sizes and timing: [[06 Beat the Hits - Polish Playbook]] §2 · APIs: [[Brief - VFX, Animation, Audio and Game Feel]]

The `roblox-vfx` skill covers **looping** effects (auras, station glows, item glows) in depth. This note covers the **moments**: one-shot effects that fire on a game event in kid simulators and +1 games. Each recipe lists:
- its layers, using the skill's layer names (core, volume, detail, sparkle, ground, light);
- starting values;
- timing;
- how it scales by tier.

**Rules for every recipe** (from the skill, repo rules and the owner):
- Pool the rig and fire it with `:Emit(n)`. Never create emitters per event.
- Always set `LightInfluence` (0 for glows).
- Fade in and out.
- Clouds use `LightEmission` 0–0.1 on bright maps; additive only for glows and sparks.
- **≤ 1 flash per second.** Reward effects fire only after the server confirms.
- Big quads (> 4 studs) ≤ ~25 per effect. Live particles on a phone ≤ 150–300 on screen.
- Textures: built-ins until the owner uploads ours: `rbxasset://textures/particles/sparkles_main.dds`, `smoke_main.dds`, `fire_main.dds`, `explosion01_shockwave_main.dds` and `rbxasset://textures/glow.png`. **Never invent an `rbxassetid`.**
- Owner taste: bloom nearly off, glow grows with tier, no floating orbs ([[09 Owner Taste Rules]]).

## 1. Launch / fire (cannon, throw, punch release)
**Timing:** anticipation 0.35 s, then the fire frame, then 0.4 s of follow-through.

| Layer | Recipe |
|---|---|
| Anticipation | Fuse sparkle: sparkles, Rate 25 for 0.35 s, Speed 2–4, Life 0.2–0.4, Size 0.3→0, colour white→tier. A PointLight in the muzzle tweens 0→1.5 Brightness |
| Core flash | glow.png, `Emit(1)`, Size 0→6→0 over Life 0.1, LightEmission 1, Brightness 2, ZOffset 1. **The one bright frame** |
| Smoke ring | shockwave, Orientation VelocityPerpendicular facing out of the muzzle, `Emit(1)`, Size 1→8, Life 0.45, Transparency 0.3→1, LightEmission 0, grey-white |
| Smoke puff | smoke, `Emit(10)`, Speed 8–14 forward, Spread (25,25), Drag 4, Size 2→5, Life 0.6–0.9, LightEmission 0.05 |
| Sparks | sparkles, VelocityParallel, Squash 1.5, `Emit(14)`, Speed 30–45, Drag 8, Spread (20,20), Life 0.15–0.3 |
| Light | the muzzle PointLight peaks at 3 for 1 frame, then drops to 0 over 0.25 s, Range 16, Shadows off |

**Tier scaling:** +10–20% size per tier. Add one channel per tier band: T3 coloured sparks, T5 an electric arc, T7 a second ring, T9 rainbow sparks.

## 2. Projectile trail (ball, stone, thrown thing)
- **A Trail** on two attachments ±0.6 studs apart: Lifetime 0.35, WidthScale 1→0, Transparency 0.2→1, LightEmission 0.5, colour by ball or tier, FaceCamera on.
- **Speed lines** (only for the local player's own flight): 6–10 white streak particles in screen space, or a ParticleEmitter 20 studs ahead of the camera. VelocityParallel, Squash 3, Life 0.2, Rate 30.
- **Tier ladder:** T1 white → T3 coloured trail → T5 a sparkle emitter on the ball (Rate 15) → T7 a second, wider faint trail → T9 rainbow `ColorSequence`.
- **Rare shots** (Golden 1/100, Mega 1/1000): Golden = gold trail + glitter Rate 30 + chime. Mega = rainbow trail + glitter + PointLight + a server-wide message. One look per rarity, never mixed.

## 3. Water skip, splash and landing
Cannon Evolution has the ripple rings built (Oct 30): a loop of rounded foam tubes that grows, thins, lifts and fades.

| Moment | Recipe |
|---|---|
| Skip | 1 ripple ring (radius 2→9 studs over 0.6 s) + droplets: `Emit(8)`, Speed 10–18 up, Spread (35,35), Accel (0,-60,0), Life 0.35–0.6, Size 0.4→0.1, white, LightInfluence 0.6 |
| Big skip (every 5th, or a crit) | 2 rings + droplets ×2 + a mist puff (smoke, Size 3→6, LightEmission 0) |
| Landing | **3 rings staggered 0.12 s** (done) + a tall splash column (droplets `Emit(30)`, Speed 25–40, Spread (15,15)) + a foam disc on the water fading over 1.2 s |
| Water life (ambient) | Caustics texture scrolling (`OffsetStudsU/V`), 1–2 slow foam lines along the banks. Client-side |

## 4. Coins and rewards
| Moment | Recipe |
|---|---|
| +number pop (world) | A pooled BillboardGui, AlwaysOnTop: rise 2 studs over 0.5 s with Back easing, then fade 0.3 s. Colour by currency (green cash, gold wins, blue gems). Random x offset ±1.5 |
| Coin burst (world) | 6–10 coin parts or particles (sparkles tinted gold) from the source, `Emit`, Speed 12–20 up and out, Accel (0,-40,0), Life 0.5, a glint at the end |
| Fly to HUD (screen) | 4–8 icon ImageLabels from the screen point of the event, each on a curved path (control point raised) to the counter over 0.35–0.5 s, staggered 0.04 s. On arrival: counter squash 1.15→1 and a chip sound at a rising pitch |
| Counter roll | Tween a NumberValue (parented!) and format each step; flash green 0.15 s; scale bump. Pitch-ladder ticks capped at 8 per second |

## 5. Egg hatch (the biggest repeat moment; the reveal decides the feel)
The server picks the result first. Reel or reveal length grows with rarity: common 0.3–0.5 s, legendary 3–4 s [R brief].

1. **Anticipation** (0.6–1.2 s, longer for rare eggs): the egg wobbles (±8° rotation tween, 3–5 shakes), then swells 1→1.15. Cracks appear (a decal swap) for Epic and above.
2. **Burst:**
   - one flash (glow Size 0→10, Life 0.12);
   - shell shards (8 parts or a shard flipbook, Speed 15–25, Accel (0,-50,0), spin);
   - a ring in the rarity colour (shockwave, Size 1→12, Life 0.4).
3. **Reveal:**
   - the pet pops in at scale 0.2 → 1.1 → 1 (0.35 s, Back);
   - rays behind it (a rotating sunburst ImageLabel in screen space, or 3 beams);
   - **colour = rarity** from `Config.Rarities`;
   - name and rarity text slam in (scale 1.6→1, 0.2 s).
4. **Rarity escalation:**
   - Common: burst only.
   - Rare: + rays.
   - Epic: + sparkle rain.
   - Legendary: + screen dim 40% + confetti + a gold glitter column.
   - Mythic/Secret: + a server-wide message + a 0.4 s slow beat.
5. **×3 / ×8 opens:** the eggs hatch in a quick cascade (0.08 s stagger), and the rarest result gets the solo reveal at the end.

## 6. Rebirth / evolution / level up
- **Level up (small, frequent):** a ring at the feet (shockwave on the ground, Size 2→10, Life 0.5, white→tier), a "Level Up!" text pop and a sparkle column `Emit(16)`. No screen effect.
- **Rebirth (big, rare):**
  - dim the screen 40% and rotate a sunburst behind a **Before → After** card (×2 → ×3);
  - a full-body glow on the character (Highlight FillTransparency 0.6→1 over 1 s; one Highlight, reused);
  - a pillar of light: beam up, Width 6, LightEmission 0.7, fades over 1.2 s;
  - confetti `Emit(60)`, LightInfluence 0.5;
  - one white flash;
  - a sting ≤ 0.8 s.
  
  Then "Tap to continue".
- **New cannon / new form unlocked:** the model spins in on a pedestal in a ViewportFrame (emitters don't draw in ViewportFrames: use glow parts there), plus a NEW! badge pop.

## 7. Zone entry, records and rare events
- **Zone border cross:** the wall shimmers (Transparency 0.6→0.3→0.6 over 0.3 s), the zone name banner pops, and the sky/ambient tints toward the zone colour over 1 s (client only).
- **New best:** gold burst at the flag, glitter, a cheer, "NEW BEST!" slam. Slow motion 0.4 s only here.
- **Distance milestone gate (every 1,000 m):** a ring of light the ball flies through, with sparkles `Emit(20)` as it passes.
- **Server-wide rare event** (Mega Shot, Secret pet): a top-centre message for everyone plus a firework emitter above the lobby landmark (3 bursts, 0.6 s apart, ≤ 1 flash per second).

## 8. Auras, trails and pets (persistent; see the skill for full layer recipes)
- **Auras:** use the skill's §3 aura recipe on the character's HumanoidRootPart, at most T1–T4 channels for players (they're everywhere on screen). Only your own aura gets the full set; other players' auras run at half density beyond 40 studs.
- **Player trails:** Trail on the waist attachments, Lifetime 0.5, rarity colour, and texture by tier.
- **Pets:**
  - a dust puff on each hop (Cannon has it, Oct 30);
  - a glint every 1.5 s or more on Epic and above (never faster: kid-safe flash rule);
  - a rarity-coloured soft glow under Legendary and above.

## 9. Checklist for any new effect
- [ ] Fires on the right frame: an animation marker or the server's confirm
- [ ] 4–7 layers with different jobs; the subject stays readable
- [ ] Pooled; `:Emit` bursts; no emitter writes per frame
- [ ] Scales by tier with **one new channel per tier**, not just more particles
- [ ] ≤ 1 flash per second; shake only on L/XL moments, with a toggle
- [ ] Phone: live particles within budget, big quads ≤ ~25, steady FPS at low quality
- [ ] Side-by-side with the reference at 30 fps (repo rule 2); judged moving, not as a still
- [ ] Built-in textures or the owner's uploaded IDs only

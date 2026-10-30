---
tags: [roblox, checklist, cartoony, style-bible]
updated: 2026-10-29
---

# 16 Cartoony Kid-Appeal Checklist

Back to [[00 Start Here]]

Run this before every launch. Each line links to where the detail lives. Numbers come from the vault's existing cartoony report ([[Cartoony Roblox building UI and animation]]) unless noted; treat proposals there as starting points to tune on a phone.

## Building
- [ ] **SmoothPlastic** for most surfaces; textures sparingly
- [ ] Faceted shapes: 6–8-sided columns and trunks; true balls and cylinders only for bubbly things (foliage, clouds, coins)
- [ ] **Chamfered tops** on platforms, walls and signs (bevel ≈ 8–15% of the smallest side)
- [ ] No flat walls: trims, pillars, insets, stripes, lights. Trims at least 0.5–1 stud thick so they read on a phone
- [ ] Stay in one style ("if you want low poly, stay low poly")
- [ ] Paths at least **10 studs** wide; core loop 30–80 studs from spawn (a 2–5 second walk)
- [ ] Hub and spoke: from spawn you can see the main action, the shop, the leaderboard and the first gate
- [ ] No empty area bigger than about 30×30 studs without props (rocks, bushes, crates); spawn plaza stays calm
- [ ] Dense, decorated map edges hide the boundary
- [ ] Videos: [[13 Cartoony & Low-Poly Building]]

## Color
- [ ] **Saturate what players touch** (signs, gates, pads, items: 75–100% saturation); **soften what they stand on** (ground and walls: 20–55%)
- [ ] 5–7 base colors per zone plus 1–2 accents; each zone has its own accent color
- [ ] Shadows lean blue-purple, highlights lean yellow; never pure grey or pure black

## Lighting
- [ ] `LightingStyle = Soft`, `PrioritizeLightingQuality = true` (set in the saved place, then check after publishing)
- [ ] ColorCorrection saturation **positive** (about +0.1 to +0.2), not negative
- [ ] Bloom threshold around 0.9–1.0 so neon signs glow
- [ ] Neon glows but doesn't light anything: add one warm PointLight per sign cluster
- [ ] Videos: Gamer M8 [cartoon lighting](https://www.youtube.com/watch?v=YIyir52FiYo), Develuper [10x better](https://www.youtube.com/watch?v=vkEXLmRAQgs)

## UI
- [ ] Opaque "toy" panels, never dark translucent glass
- [ ] Thick outline + lit top + darker lip + hard shadow on every button
- [ ] Color = meaning: yellow primary, green confirm, red close, blue navigate, one rarity ladder
- [ ] One dominant button per screen
- [ ] Press feedback on every button (shrink and bounce); shine sweep on the main call-to-action
- [ ] No emoji icons, no removed Gotham font, no `TextScaled` everywhere
- [ ] Thumb-reachable on phone, clear of the top bar and safe area
- [ ] Videos: [[14 Cartoony UI & Juice]]

## Feel
- [ ] Every reward: sound + particles + popup number + small camera or UI bounce
- [ ] Animations have anticipation, contact and settle; impact effects fire on one animation marker
- [ ] Cosmetic motion runs on the client
- [ ] Particle rates low (mobile caps at 100 per second)

## Loop & retention
- [ ] First reward in under 90 seconds
- [ ] Something visibly grows every few seconds
- [ ] Collection + rarity (pets, eggs, skins)
- [ ] Show-off items: leaderboards, auras, titles
- [ ] Come-back hooks: daily reward, playtime gifts, weekly event
- [ ] Monetize after retention works
- [ ] Videos: [[15 Kid Appeal & Game Design]], [[10 Business, Monetization & Case Studies]]

## Performance (kids play on phones)
- [ ] Decorative parts: Anchored, CanCollide/CanTouch/CanQuery off, CastShadow off on small details
- [ ] Reuse a small set of sizes, materials and colors (instancing)
- [ ] Split the map into small models for streaming; avoid one giant Persistent model
- [ ] Test on a real phone at low graphics quality

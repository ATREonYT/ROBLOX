---
tags: [miami-trap-life, research, guns, combat, game-feel]
updated: 2026-11-01
---
# Gun mechanics

Back to [[00 Master Plan]] · Related: [[How to Make a Gun in Roblox Studio Using Claude AI]] (config-driven gun), `hood/` (earlier gun shop + GunTool + ShotRules, cartoony models in `hood/art/models/roblox/`).

## Build or buy?
**Build our own first.** Free community kits (ACS, Carbon Engine, FE Gun Kit and similar) are first-person/milsim-first, heavy, hard to reskin, and older ones have a history of exploitable remotes. A third-person GTA-style system is a well-understood amount of work: hitscan + server checks + good feedback. If after the gun piece it still feels worse than top hood games, we look at a paid kit then, with a side-by-side video to decide.

## How it works (architecture)
**Client (`GunController`)**
- Tool equip → over-the-shoulder camera when aiming (hold right mouse / L2 / an on-screen aim button): `Humanoid.CameraOffset = (1.75, 0.4, 0)`, FOV 70 → 55 tween 0.15 s, character turns with the camera, walk speed ×0.6. Crosshair appears; hip-fire crosshair is wider.
- Fire: ray from the **camera** through the crosshair to find the aim point, then a second ray from the **muzzle** to that point (stops shooting around corners from a camera that sees past a wall).
- Spread: random cone, hip > moving > aiming > crouched. Spread "blooms" per shot and recovers.
- Plays its own effects **immediately** (no waiting for the server): muzzle flash, sound, tracer, shell, recoil, impact. Sends `GunFire {gunId, origin, dir, hitPart, hitPos, t = workspace:GetServerTimeNow()}`.
- Hitmarker + hit sound only when the server confirms damage (sent back as a light `GunFx` event), so the player never sees fake hits.

**Server (`GunService`)**
- Checks: the player is alive, holds that gun, has ammo, not in a safe zone, path allows PvP (Criminal or both flagged), fire rate (`now - lastShot >= 60/RPM * 0.85`, the 15% tolerance stops lagging players getting shots eaten), origin within 6 studs of their head/muzzle.
- **Lag compensation:** every Heartbeat at ~20 Hz keep 1 second of history of each character's HumanoidRootPart CFrame. Rewind the target to the client's shot time (clamped to at most 250 ms back), then check the claimed hit point is within the hitbox + tolerance (3 studs body, 1.5 studs head). Then re-raycast origin → hit point against the **map only** (ignore characters) to block wall shots.
- Damage: `base * (head ? HeadMult : 1) * falloff(distance)`; armour later. Accessories are ignored for headshots (any part whose ancestor model has a Humanoid counts as that character).
- Ammo and reloads are server-owned; the client only predicts the counter.
- Broadcasts `GunFx` (origin, end point, gun id) to other clients so everyone sees the tracer and hears the shot (3D sound at the shooter).

## Feel checklist (what makes guns feel good)
- **Recoil on the camera, with springs:** each shot kicks the camera up 0.6–2° and slightly sideways (pattern from config), using a spring that returns ~70% of the kick. Horizontal recovers faster than vertical, so bursts feel controllable but full-auto climbs ([The Astronauts, "making gun come to life"](https://www.theastronauts.com/2019/03/making-gun-come-to-life/)).
- **Gun kick:** the gun model itself snaps back 0.2 studs and rotates up 5–10°, recovering in ~0.1 s.
- **Muzzle flash** 1–2 frames (a PointLight + a flash billboard/particle), short muzzle smoke; **impact** = a spark/dust particle and a bullet-hole decal on parts (pooled, max ~40), puff of blood-red particles kept small and non-gory.
- **Sound layers:** shot (close), tail/echo (distance), mechanical click on empty, mag out/in on reload, distinct hit tick and a deeper kill sound.
- **Hitmarker:** small white X at the crosshair for 0.15 s; red on headshot; a slightly bigger one on kill.
- **Tracers:** a thin bright beam that lasts ~0.05 s (or a fast-moving part), every 1st shot for pistols, every 3rd for SMGs.
- **Damage feedback for the target:** red edge vignette from the hit direction, a small camera nudge, screen desaturates when low.
- **Reload:** R / tap the ammo counter (mobile); animation placeholder until Alex's animations; can't fire while reloading; interrupt on unequip.
- **Mobile:** fire button on the right thumb, aim toggle button, light aim assist (slow the camera slightly over a target's hitbox), never auto-fire.
- **Performance:** pool tracers/decals/particles, don't create Instances per shot on the server.

## Config per gun (`Config/Guns.lua`)
```lua
Pistol = {
  Display = "9mm", Model = "Pistol", Slot = "Secondary",
  Damage = 22, HeadMult = 1.8, RPM = 360, Auto = false,
  Mag = 12, Reserve = 48, Reload = 1.6,
  Range = 300, FalloffStart = 80, FalloffMin = 0.6,
  Spread = { Hip = 3.0, Aim = 0.8, Move = 1.5, Bloom = 0.6, Recover = 6 },
  Recoil = { Up = 1.2, Side = 0.35, Return = 0.7, Kick = 0.18 },
  AimFov = 55, Price = 1200, Level = 5,
}
```
Starter set for the first pass: Pistol (semi), Uzi (auto), Shotgun (8 pellets). Then Revolver, AK, Deagle, Tommy from the hood model set.

## RP rules for guns
- Guns can be carried by anyone after they're bought, but **only Criminal path players can shoot other players**; Civilians are protected and can't shoot players (they can still use ranges later).
- Safe zones (tag `MTL_SafeZone`): spawn lot, job interiors while on shift, inside your own flat.
- Knocked-down state first (crawl, can be helped up by a crewmate, bleed out after 20 s), then respawn at the nearest hospital later. Second chances keep the game friendly (GAME-FEEL §5).
- The first robbery uses the gun in **intimidate mode** (aim at the clerk to make them open the register; no damage to NPCs in the tutorial).

## Build notes (Piece 5, 2026-11-01)
What we built and the decisions behind it (code: `Config/Guns.lua`, `Rules/GunRules.lua`, `GunService`, `GunController` + `GunFX` + `GunPose`):
- **No Tools.** Guns are custom-equipped (a Motor6D from the right hand to the gun's Handle) so the weapon bar, phone and Alex's UI own the screen instead of the default backpack. The same model hangs on the hip/back when holstered.
- **Recoil that climbs but settles.** Roblox's default camera rebuilds itself from the camera's current look vector each frame, so rotating `Camera.CFrame` right after the camera update (`BindToRenderStep` at Camera+1) persists. Each kick is split: `1 - Return` is applied for good (full-auto climbs, the player pulls down), the rest goes through a damped spring that bounces back. Peak lands ~0.06 s after the shot.
- **Spread is a uniform disc**, not uniform angle (sqrt of the random radius), so the crosshair gap honestly matches where bullets go. Gap in pixels = tan(spread) / tan(fov/2) * screenHeight/2.
- **Fire rate on the server is a token bucket** (refill RPM/60 / 0.85, burst 2), not "time since last shot": bunched packets from a laggy client still count, spam still caps. Tested with ±40 ms jitter: zero legit shots eaten.
- **Lag compensation by window, not by one rewind point.** The server keeps 20 Hz root history and accepts a hit if ANY sample from (shot time − 0.25 s) to now puts the claimed point inside the part's box + tolerance. That covers both the shooter's latency and the victim's interpolation delay without needing to know either exactly. Never more than 0.4 s back.
- **Ray through scenery, stop on bodies.** Client rays skip non-colliding parts (zones, decor) but stop on any character part (R15 limbs don't collide, so `RespectCanCollide` alone would make arms bulletproof). Accessories resolve to the body part they're welded to. The server wall check uses `RespectCanCollide` and ignores characters, so both sides agree on what's a wall.
- **Arms posed in code** (Motor6D.Transform in `PreSimulation`, which runs after the Animator) until real animations exist. Other players' pitch comes from a throttled character attribute set by the server from an `UnreliableRemoteEvent`.
- **The phone wins.** A click that closes the phone never fires (0.2 s guard), opening it drops the aim, guns don't fire with it open.

**Build or buy, the verdict:** the code side doesn't need a kit; everything a kit gives (validation, recoil, spread, effects, ammo) is built and tested here. What separates this from the best hood games now is **assets, not code**: real gun sounds (shot + distant tail + reload foley), hold/aim/reload animations, and proper gun models. Those are worth buying or commissioning (sound packs, an animator) rather than a gun kit. Next code steps after a play-test: knocked-down/revive state, armour, a civilian gun range, and tuning numbers from the play-test.

Sources: [Server hit validation thread](https://devforum.roblox.com/t/firearm-system-server-hit-validation-problem/4111073), [Validating fire rate](https://devforum.roblox.com/t/how-do-validate-a-weapons-firerate-in-the-server/3047125), [FastCast + latency](https://devforum.roblox.com/t/solution-how-to-fight-latency-fastcast/3560228), [The Astronauts: making gun come to life](https://www.theastronauts.com/2019/03/making-gun-come-to-life/).

---
tags: [build-playbooks, realistic-rp, combat, weapons, hit-validation, anti-exploit]
updated: 2026-11-01
---

# 04 Combat - Fists, Weapons and Server Hit Validation

Back to [[00 Start Here - Realistic City RP]] · Deeper: LihFolk `22 Anti-Exploit and Security/Detecting Combat Exploits - Reach Rate and Aim`, `Autoclicker and Macro Detection for Combat Remotes`, `25 Physics and Vehicles/Projectiles and Ballistics` · Kit: `Shared/HitCheck.luau`

## 0. Rating and tone (decide first)
Realistic guns that damage players = **Moderate violence** (13+). Keep it **non-graphic**: no blood, no gore, no dismemberment; a hit is a white impact puff, a hit-marker tick and a stagger. Players are **knocked out**, not killed, wherever the design allows ([[05 Health, Stamina, Sprint and Knockouts]]). Weapons get fictional names and our own models. No real-world gun brands, no illegal modifications as items, no glorifying real shootings.

## 1. The model: client feels it, server decides it

```text
CLIENT (instant)                                   SERVER (authoritative)
press fire ─► muzzle flash, sound, recoil,        receive Fire{weaponId, origin, dir, t, hitPart?, hitPos?}
              tracer, ammo -1 (predicted)          ├─ rate limit + weapon owned + equipped + alive
local raycast ─► hit marker (predicted, grey)      ├─ HitCheck.Shot (rate, ammo, origin, angle, range,
send Fire ───────────────────────────────────────► │   target vs History:At(t), line of sight by server Raycast)
                                                   ├─ damage = HitCheck.Damage(...) → Humanoid:TakeDamage
◄──────── Confirm{hit=true, dmg} ─────────────────┘ ├─ replicate tracer to others (unreliable remote)
hit marker turns white + "tick" sound              └─ strike counter on refusals (never kick on one)
```
- The client predicts *effects only*. Health changes only on the server.
- Other players see your shot through a server **UnreliableRemoteEvent** fan-out (tracer + sound at origin), throttled to what's within 300 studs of them.
- Server Authority (July 2026) blocks movement hacks but **not** fake hit reports; Roblox's own note says remote events can be 40-50 ms off the simulation timeline and a server rewind API is "being explored". So we keep our own `HitCheck.History` rewind.

## 2. Server hit validation (kit `HitCheck`)

Per weapon config:
```lua
Weapons.Pistol = { range = 200, fireInterval = 0.2, spreadDeg = 2, magazine = 12, damage = 22, falloffStart = 60, reload = 1.6, price = 3500, level = 3 }
Weapons.Fists  = { melee = { range = 5, coneDeg = 90, cooldown = 0.45 }, damage = 8 }
```
Server handler (shape):
```lua
local HitCheck = require(ReplicatedStorage.Kit.HitCheck)
local histories = {} -- [character] = HitCheck.History.new(1)

RunService.Heartbeat:Connect(function()
	local now = workspace:GetServerTimeNow()
	for _, p in Players:GetPlayers() do
		local root = p.Character and p.Character:FindFirstChild("HumanoidRootPart")
		if root then
			histories[p.Character] = histories[p.Character] or HitCheck.History.new(1)
			histories[p.Character]:Push(now, root.Position)
		end
	end
end)

Net.On("Fire", function(player, weaponId, origin, dir, clientTime, hitInstance, hitPos)
	local w = Weapons[weaponId]; local state = Combat.State(player)   -- equipped, ammo, lastShotAt
	if not w or state.equipped ~= weaponId then return end
	local now = workspace:GetServerTimeNow()
	local t = math.clamp(clientTime, now - HitCheck.Tolerance.maxRewind, now)  -- never trust their clock
	local head = player.Character.Head.Position
	local targetChar = hitInstance and hitInstance:FindFirstAncestorOfClass("Model")
	local hist = targetChar and histories[targetChar]
	local los = true
	if hitPos then
		local params = RaycastParams.new()
		params.FilterDescendantsInstances = { player.Character, targetChar }
		los = workspace:Raycast(origin, hitPos - origin, params) == nil -- nothing static in between
	end
	local ok, why = HitCheck.Shot(w, { origin = origin, direction = dir.Unit, targetPos = hitPos }, {
		headPos = head, now = now, lastShotAt = state.lastShotAt, ammo = state.ammo,
		targetAt = hist and hist:At(t), lineOfSight = los, alive = Combat.Alive(player),
	})
	if why == "TooFast" or why == "NoAmmo" or why == "Dead" then return Combat.Strike(player, why) end
	state.lastShotAt = now; state.ammo -= 1             -- a valid shot, hit or miss, spends a round
	if ok and why == "Hit" and Combat.CanDamage(player, targetChar) then
		local dist = (hitPos - origin).Magnitude
		targetChar.Humanoid:TakeDamage(HitCheck.Damage(w, dist, hitInstance.Name))
		Net.Send(player, "Confirm", true)
	elseif not ok then
		Combat.Strike(player, why) -- logged; 10 strikes in 60 s → weapons disabled 30 s + flagged for review
	end
end)
```
`Combat.CanDamage` is where **safe zones, new-player protection, same-team police, jail and hospital** rules live ([[05 Health, Stamina, Sprint and Knockouts]] §4). Use `Humanoid:TakeDamage` (respects ForceFields), not `Health -=`.

Tolerances in `HitCheck.Tolerance` (origin 6 studs, +4° angle, target 7 studs, 15% early fire allowed, 0.4 s rewind). Loosen only with data from real servers (log the refusal reasons for a week before tightening).

## 3. Fists and melee (slot 1, always there)

- **Combo:** left jab → right jab → hook (3-hit chain; the 3rd hit knocks back 6 studs and costs 15 stamina). Input buffered 0.25 s so taps chain cleanly.
- **Animations:** 0.12 s windup, 0.08 s active, 0.25 s recovery. Studio-quality keyframes with anticipation and overshoot ([[16 Pro Animation and VFX Playbook]]). Camera micro-shake 0.05 on landing hits only.
- **Detection on the attacker's client** at the active frame with `workspace:GetPartBoundsInBox(root.CFrame * CFrame.new(0, 0, -3), Vector3.new(4, 5, 4), params)`, collect unique characters, send `Swing{comboIndex, targets}`. Avoid `.Touched` for melee (misses fast and overlapping parts).
- **Server** runs `HitCheck.Melee(move, ctx)` per target with server positions (range + 2.5 studs lag slack, front cone), applies damage, plays the hit sound for everyone.
- **Block:** hold F/right-click: 70% less damage, slower walk, blocks drain stamina. A perfect block (within 0.15 s of the hit) staggers the attacker: the skill moment.

## 4. Guns: feel without gore

| Feel element | How |
|---|---|
| Recoil | Camera kick up 1.2-2.5° on a spring (kit `Spring`), returns in 0.18 s; weapon viewmodel kicks back |
| Spread | Small random cone (`spreadDeg`), tighter when standing still and aiming |
| Tracer | Thin bright beam, 0.05 s, from the muzzle attachment (client-side for everyone) |
| Hit feedback | Hit marker cross + "tick"; head hits a higher tick; **no blood** — a white dust puff |
| Sound | Shot, mechanical click layer, tail echo by environment (street vs indoors) |
| Reload | 1.2-2.2 s anim with sound beats at mag-out / mag-in / rack |
| Aim | Right-click / left trigger → shoulder camera, FOV 70 → 55, slower walk |
| Mobile | Auto-aim assist *small* (3° magnetism near targets), a fire button on the right, aim button above it |

Projectiles: bullets are hitscan (raycast) up to 200 studs. Slow projectiles (thrown items, a fire-extinguisher foam) use a client-simulated projectile with server re-simulation of the start + time (LihFolk `Projectiles and Ballistics`).

Ammo is an inventory item (`Ammo_Pistol` ×60), bought at the weapon store; the server owns the count.

## 5. Where combat is allowed (this is what makes or breaks a hood RP)

Public servers of the hood games are "constant PvP" (their own fan guides). That scares off most players. Our rules:
- **Safe zones** (spawn, hospital, bank interior, dealership, job sites while on a task): `Combat.CanDamage` returns false; weapons auto-holster inside (with a small "Safe zone" chip).
- **New-player protection**: first 15 minutes of play time, can't be damaged and can't damage (a shield icon by the name). Ends early if they draw a weapon.
- **Consent by role**: civilians in legal jobs can only be damaged by police (non-lethal taser) or by players they hit first (a 60 s "fair fight" link). Crime-role players are open to police and to each other.
- **Random knockouts cost heat**: hitting a protected player gives the attacker Wanted heat (`Assault`), which makes police hunt them. Self-correcting.
- **Private servers** turn PvP rules to the owner's choice (Off / Fair fights / Open).

## 6. Exploit list for combat (test each one)
| Exploit | Stop |
|---|---|
| Kill-aura (hit everyone around) | Melee cone + range per target; max 3 targets per swing |
| Fire-rate hack | `fireInterval × 0.85` floor per shot; strike + log |
| Infinite ammo | Server ammo count; client count is only display |
| Silent aim (claims hit at an off-angle target) | Angle check vs claimed direction + target near the server's rewound position |
| Shooting through walls | Server `Raycast` line of sight from origin to hit point |
| Teleport-shoot | Origin must be within 6 studs of the server's head; Server Authority stops the teleport itself |
| God mode | Health is server-only; client `Humanoid.Health` writes don't replicate |
| Remote spam | kit `RateLimit` per player per remote (e.g. Fire 15/s, Swing 6/s) |

## Done when
- Shots feel instant at 200 ms ping in the network simulator, and a modified client can't damage through a wall, from 300 studs, or at 3× fire rate.
- A new player can walk from spawn to the first job without being knocked out by a stranger.

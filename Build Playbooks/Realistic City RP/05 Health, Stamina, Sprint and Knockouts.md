---
tags: [build-playbooks, realistic-rp, health, stamina, sprint, knockout, respawn]
updated: 2026-11-01
---

# 05 Health, Stamina, Sprint and Knockouts

Back to [[00 Start Here - Realistic City RP]] · Kit: `Shared/Stamina.luau`

## 1. Health

- 100 HP. Regen **2 HP/s after 8 s without damage**, up to 70; above 70 only food, bandages or a medic heal.
- The heart button's ring = health. At < 30: a soft red vignette (static, no pulsing faster than once a second), heartbeat sound at low volume.
- Food (24/7 store): +20 HP over 3 s; bandage: +35 HP over 4 s, can't use while sprinting; medic heal: full.
- Server owns `Humanoid.Health`; heals happen in server code when the item is consumed (item removed in the same step).

## 2. Stamina and sprint (kit `Stamina`)

- Walk 16, sprint 24 studs/s. A full bar = 8 s of sprinting; regen starts 0.8 s after the last spend at 20/s resting, 10/s walking; once empty you can't sprint again until 30%.
- **Same module on both sides.** The client runs `Stamina.Step` every frame and sets `WalkSpeed` (instant feel). The server runs the same numbers every 0.25 s from the player's sprint input state (sent as a tiny reliable "Sprint on/off" event, rate limited) and, if the character moves at sprint speed while the server copy is exhausted, puts `WalkSpeed` back to 16 and logs a strike. Same maths both sides means no false alarms.
- Stamina also pays for: the 3rd combo punch (15), blocking (5/s), vaulting a fence (10), a jump while sprinting (5).
- Optional hunger/energy (Tha Bronx-style): **don't** at launch. It adds chores. If added later, it only affects sprint regen (−50% when hungry), never health, and food is cheap and everywhere.

Client wiring with the Input Action System:
```lua
-- StarterPlayerScripts/Sprint.client.lua
local Stamina = require(ReplicatedStorage.Kit.Stamina)
local sprintAction = ReplicatedStorage.Inputs.OnFoot.Sprint -- InputAction (Bool): LeftShift, ButtonL3, UIButton = HUD sprint circle
local s = Stamina.new()
local wants = false
local touchToggle = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled

sprintAction.Pressed:Connect(function()
	if touchToggle then wants = not wants else wants = true end
	Net.Send("Sprint", wants)
end)
sprintAction.Released:Connect(function()
	if not touchToggle then wants = false; Net.Send("Sprint", false) end
end)

RunService.RenderStepped:Connect(function(dt)
	local hum = humanoid(); if not hum then return end
	local moving = hum.MoveDirection.Magnitude > 0.1
	hum.WalkSpeed = Stamina.Step(s, dt, wants, moving)
	SprintRing.Fill = s.value / Stamina.Rules.max          -- radial fill on the HUD circle
	camera.FieldOfView = 70 + (if s.sprinting then 6 else 0) -- through kit CameraMath's one FOV owner
end)
```

## 3. Knockouts instead of deaths (our default)

```text
HP hits 0 ─► KNOCKED OUT (ragdoll, 30 s timer, can't act, can crawl slowly)
              ├─ a medic or any player holds "Revive" 4 s ─► back up at 25 HP
              ├─ "Respawn at hospital" button after 10 s ─► hospital bed, 60 HP, bill ($100 or 5% of bank, smaller one)
              └─ timer ends ─► hospital respawn as above
```
- On knockout: `Wallet.KnockoutDrop` (10% of pocket cash, max $5,000) spawns a cash pickup; equipped weapon holsters (never lost, avoids rage-quits); Wanted heat stays; jobs pause.
- Ragdoll: on the server, set `Humanoid.BreakJointsOnDeath = false`, and on knockout set `Humanoid:ChangeState(Enum.HumanoidStateType.Physics)`, swap each `Motor6D` for a `BallSocketConstraint` with limits (`LimitsEnabled`, `TwistLimitsEnabled`, 30-45°). Recover: re-enable Motor6Ds, `ChangeState(GettingUp)`. Test under Server Authority (the animator has an 8-track limit there).
- "Downed" camera: slow desaturate to 40% over 1 s, muffled audio (EqualizerSoundEffect high cut), a big clear "Respawn" button after 10 s. No gore, no body left behind.
- Combat logging: leaving within 20 s of being hit → next join spawns at the hospital with the knockout drop applied (store a `combatLogAt` timestamp in the save).

## 4. `Combat.CanDamage(attacker, target)` rules (one function, used by fists, guns, cars)
Return false if any: target or attacker in a safe zone; either under new-player protection; target knocked out; target in jail; same police team; target is a civilian in a legal job and not in a "fair fight" link with the attacker and the attacker isn't police with a taser; private-server PvP off. Everything else: true. Vehicle ram damage goes through the same function (cars can't be used to bypass safe zones).

## Done when
- Sprint feels instant on a phone and an exploiter speed-hacking past the stamina rules is slowed back within 0.25 s.
- A knocked-out player is never stuck: revive, button or timer always gets them back within 30 s.

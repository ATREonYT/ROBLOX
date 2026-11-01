---
tags: [build-playbooks, realistic-rp, day-night, weather, traffic, npc, events]
updated: 2026-11-01
---

# 09 Day-Night, Weather and a Living City

Back to [[00 Start Here - Realistic City RP]] · Lighting looks: the world-building thread's notes and [[10 Map Design Playbook]] · Kit: `Shared/WorldClock.luau`

A realistic city must feel **alive with zero players nearby**: cars passing, people walking, lights clicking on at dusk, rain on the windshield. All of that is **client-side decoration** so it costs the server nothing.

## 1. One shared clock (kit `WorldClock`)
- Server sets `workspace:SetAttribute("ClockEpoch", workspace:GetServerTimeNow())` once at start. Every client computes `WorldClock.ClockTime(GetServerTimeNow() - epoch)` and sets `Lighting.ClockTime` each second (smoothly lerped every frame for a moving sun). No per-frame network traffic.
- 14-minute day, 6-minute night, server starts at 08:00.
- **Lighting per phase** (tween over 20 s at each boundary): `Atmosphere.Density`, `Haze`, `Color`; `Lighting.Ambient/OutdoorAmbient`; `ColorCorrection.TintColor` (warm gold at 17:00-18:30, cool blue at night); `Bloom` a touch stronger at night for neon. Keep `Technology = Future` on desktop; it falls back on phones automatically.
- **Street lights:** tag lamp parts `StreetLight`; on `WorldClock.IsNight(clock, wasNight)` change, turn their `PointLight/SpotLight.Enabled` and the bulb's `Material = Neon` on, *staggered* over 3 s by distance from the player (a wave of lights, not one pop). Lights with shadows off except 4-6 hero lights.
- Stores use `WorldClock.IsOpen(hours, clock)`: 24/7 always; clothing 08-22; a club-style venue 20-04 (no alcohol). Closed stores show a "Closed" sign and their icon goes grey.

## 2. Weather
- States: Clear (60%), Cloudy (20%), Rain (15%), Fog (5%), changed by the server every 6-10 min with a 30 s blend. Sent as one attribute `Weather`.
- Rain is **client-only**: a ParticleEmitter box that follows the camera (not the whole map), wet road look by lowering asphalt `Roughness` via a MaterialVariant swap or adding a reflective decal layer, rain loop sound with a "under roof" muffle (raycast up every 0.5 s).
- Gameplay touch: rain lowers car grip by 15% (server reads `Weather` in the chassis). Season icon (leaf) changes decorations monthly.

## 3. Traffic and pedestrians (client-only)
- Roblox's "City People Cars" tech demo showed a city full of walking and driving NPCs. The pattern: a **lane graph** (nodes with next-node lists, speed limits, stop lines at lights) and a **sidewalk graph**, both stored as data, and simple agents that follow them.
- Our rules:
  - **Spawned on each client only, around that client** (radius 250 studs), max 12 cars and 20 pedestrians on phones, 24/40 on PC. They despawn behind the camera.
  - Cars: anchored models moved by `PivotTo` along spline segments each frame (no physics), braking for the car ahead (distance check on the same lane), stopping at red lights (a shared light cycle from the `WorldClock` seconds, so every client agrees on the colour).
  - If a player's car gets within 6 studs of an NPC car, the NPC brakes and honks; NPC cars are **non-collidable with player cars** on clients but a local "bump" sound and nudge sells contact. (Real collisions with client-only NPCs would desync.)
  - Pedestrians: walk cycles from one AnimationController per model, 3 LODs (full rig < 60 studs, 6-part simplified 60-150, hidden beyond). Use `Model.LevelOfDetail` SLIM where supported.
- Server-side NPCs only where gameplay needs them (a shopkeeper with a prompt, a robbery target). Keep those few and static.

## 4. City events (the "something to do together" engine)
A server **Director** starts one event every 6-8 minutes, picked by who is online:

| Event | Needs | Everyone's role |
|---|---|---|
| Building fire | ≥ 1 firefighter or 3 players | Fire: hose; Police: cordon; Medic: treat NPCs; Civilians: carry hoses (paid helper task) |
| Delivery rush | always | Any driver gets 2× delivery pay for 3 min |
| Car meet | ≥ 6 players with cars | Park at the lot; players vote best car (rate 1-5); winner gets a plate frame |
| Street race (legal, on a closed track) | ≥ 4 drivers | Racers; police clear the track; others watch from stands |
| Power cut (night only) | ≥ 10 players | Lights out in one district for 2 min; electricians (any player) fix 3 boxes |
| Armoured truck (crime) | ≥ 2 police online | Criminals intercept; police escort |
Events show on the phone News app, as a pulsing world icon, and with one line in the message strip. Rewards are small and shared; the fun is the crowd.

## 5. Ambient sound (huge for realism)
- Zones (park, downtown, freeway, alley) with looping beds at 0.2-0.35 volume, crossfaded 1.5 s on entry: distant traffic, birds by day, crickets by night, a far siren every 3-6 min.
- Spot sounds on props: AC units hum, power-line buzz, flag flaps, store door chimes. All Roblox licensed library audio, short loops, `RollOffMaxDistance` 40-80.

## Done when
- With one player in the server, the street still has moving cars, walkers and lights that come on at dusk.
- The night/day switch never flickers lights, and all clients agree on the time and traffic-light colour.

---
tags: [build-playbooks, realistic-rp, vehicles, dealership, fuel, garage]
updated: 2026-11-01
---

# 03 Vehicles - Driving, Dealership, Garage and Fuel

Back to [[00 Start Here - Realistic City RP]] · Deep physics notes: LihFolk `25 Physics and Vehicles/` (start at `Physics and Vehicles Start Here`) · Kit: `Server/Garage.luau`, `Roleplay.CanSpawnVehicle`

Vehicles are the **most expensive system** in a city RP: physics, networking, streaming, models, sounds and the economy all meet here. They're also the main thing players want. Build them carefully, once.

## 1. Pick the chassis

| Option | Pros | Cons | Use when |
|---|---|---|---|
| **A-Chassis** (open source, MPL-2.0, [GitHub](https://github.com/lisphm/A-Chassis), v1.7.2) | Realistic gearbox, tune file, plugins, the genre standard | Heavy scripts per car, old code style, mobile controls need work, constraint-based so Server Authority needs testing | You want realism fast and accept its weight; keep the MPL notice |
| **Custom raycast suspension** (LihFolk "Choosing a Car Chassis") | Light, stable on bumps, one script for all cars, tunable feel | You write and maintain it | Our pick for a premium feel and 40-player servers |
| **Roblox Racing template car** | Official, works with **Server Authority** (prediction + rollback) | Arcade, needs reskin/tuning | Prototype; reference for Server Authority vehicles |

Recommendation: **custom raycast chassis**, one `VehicleController` module, cars as data (`Config/Cars.lua`: mass, torque curve, top speed, grip, brake, seats, fuel tank, price, level, colours). Every car shares the code; each model only carries parts, seats and attachments (`WheelFL`, `WheelFR`, ...).

## 2. Networking: who simulates the car?

- **Default model (no Server Authority):** when a driver sits, the server calls `chassis:SetNetworkOwner(driverPlayer)`. The driver's client simulates the car, so it feels instant. The server must *check*: speed under `topSpeed × 1.15`, no teleports (> 60 studs between two 0.25 s samples without a server-approved warp), car stays near its driver. On a fail: set network owner to server for 2 s, `PivotTo` the last good position, log a strike.
- **Server Authority (full release July 2026)**: set `Workspace.AuthorityMode = Server`; the engine predicts and rolls back, and rejects impossible movement for you. It auto-enables `StreamingEnabled`, `UseFixedSimulation`, `PlayerScriptsUseInputActionSystem`, `NextGenerationReplication` and Deferred signals. Vehicle physics are supported; old BodyMovers and some constraints may need rework; driving input must go through `InputAction`s and `BindToSimulation`. Test with the network simulator at 150 ms ([DevForum full release](https://devforum.roblox.com/t/full-release-ship-fair-and-competitive-games-with-server-authority/4727993)). It costs more server CPU; measure with 40 players and 20 cars before committing.
- Either way the **server owns** who may drive: `VehicleSeat` occupant changes are checked against `owner`/`allowedDrivers` (friends, job vehicles for that team); others are ejected with a toast "Locked".

## 3. Owning, spawning and despawning

```text
Dealership (buy) ─► Garage list (saved) ─► Phone "Garage" app or garage prompt ─► spawn at nearest free bay
     ▲                                                                                    │
     └──────── sell back 60% ◄── impound (fee) ◄── wrecked / abandoned 2 min ◄────────────┘
```
- Saved data: `Garage = { owned = { Sedan = { colour = "Midnight", plate = "7KQ-221", upgrades = {...} } }, lastSpawned = "Sedan" }`.
- Spawn rules (kit `Roleplay.CanSpawnVehicle`): one car per player, 20 per server, 10 s cooldown; spawning your car again **replaces** the old one (despawn it first).
- Spawn bay check: `workspace:GetPartBoundsInBox(bayCFrame, carSize, params)` must be empty of other cars and characters; try the next bay; never spawn on top of players.
- Despawn: owner left the server, or the car is empty and > 120 s unused and > 80 studs from its owner. Fade out over 0.5 s.
- Streaming: car models `ModelStreamingMode = Atomic`; call `player:RequestStreamAroundAsync(bayPosition)` before spawning so the driver sees it instantly ([[11 Streaming and Performance for a City]]).

## 4. Dealership

- A showroom with 4-6 hero cars on turntables + a kiosk UI with the full list (ViewportFrame previews, stats bars: speed, acceleration, handling, seats, tank).
- **Test drive**: 60 s on a closed loop behind the dealer, car can't leave the zone, auto-returns.
- Buy: client sends `Dealer.Buy(carId, colour)`; server runs `Garage.CanBuy(catalog, owned, id, level, hasPass)` → `Wallet.Pay(w, price, "card", "Dealer")` → add to `owned` → save → celebration (keys jingle, confetti once, camera orbit 2 s).
- Ladder (fictional brands, our own models): beater $0 (starter, free) → sedan $4k → hatch $9k → pickup $15k → muscle $40k → SUV $60k → sports $120k → super $250k. Levels gate the top three.

## 5. Fuel (a small, satisfying sink)

- Kit `Garage.Burn(fuel, studs, tank, throttle)`: the **server** measures the car's real travel each 0.5 s and burns fuel; coasting burns 25%. A 60-unit tank ≈ 10,000 studs ≈ 6-8 min of driving.
- Gauge on the car HUD (needle, turns amber at 25%, red + soft beep at 10%). Empty → engine cuts, car rolls; you can push it (low torque) or call a tow/mechanic from the phone.
- Pump: ProximityPrompt at each pump → hold to fill (fuel rises 10 units/s with a pump sound) → pays at release using `Garage.RefuelCost`. Card or cash.
- Electric cars (later update): charge points, slower but free at your house.

## 6. Damage, repair and tow

- Damage from collision summaries (Collision Summaries API, live 2026: impact speeds per contact) or a server-side speed-drop check; health 0-1. Visual: swap bumpers to dented meshes at 60% and 30%, smoke at 20%, won't start at 0.
- Mechanic job repairs (`Garage.RepairCost(price, health)` pays the mechanic, charged to the owner). Without a mechanic online, the garage prompt repairs at 1.5× cost.
- Impound: abandoned-in-road or wrecked cars are towed (tow truck job) and the owner pays `Garage.ImpoundFee(price)` to get them back.

## 7. Feel checklist (what makes a car feel premium)
- Engine sound with 3 layered loops (idle, mid, high) crossfaded by RPM, pitch 0.8-1.6; gear-shift "chunk"; tyre skid loop above slip 0.3; turn-signal tick. Roblox licensed library sounds only.
- Camera: 6° FOV widening with speed (65 → 71), slight lag on turns, look-behind button.
- Lights: headlights (`SpotLight`, `Shadows = false` on phones), brake lights brighten on brake, neon underglow as a cosmetic.
- Horn and radio: horn is a one-shot; radio plays our own licensed playlist, local only, volume setting.
- Mobile: on-screen throttle/brake pedals + steering by left-stick; handbrake button. Gamepad: triggers.
- Enter/exit: door opens (0.25 s hinge tween), character sits, door closes. 0.6 s total. Never teleport-snap into the seat.

## Done when
- A new player can test drive, buy, spawn from the phone and refuel in under 3 minutes.
- 20 cars driving with 40 players stays above 40 FPS on a mid phone and server heartbeat > 50 Hz.
- An exploiter teleporting their car is pulled back within 0.5 s and logged.

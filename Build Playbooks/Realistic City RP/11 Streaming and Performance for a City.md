---
tags: [build-playbooks, realistic-rp, streaming, performance, optimisation]
updated: 2026-11-01
---

# 11 Streaming and Performance for a City

Back to [[00 Start Here - Realistic City RP]] · General: [[Brief - Worlds, Lighting and Performance]], LihFolk `03 Architecture and Networking/Instance Streaming`, `25 Physics and Vehicles/Vehicles and StreamingEnabled` · Docs: [Streaming techniques](https://create.roblox.com/docs/workspace/streaming/techniques)

A realistic city is the heaviest kind of Roblox map: thousands of props, textures, lights, cars and 40 avatars. It only runs on phones with **streaming on and a budget enforced from day 1**.

## 1. Workspace settings (Roblox's recommended set, 2026)
| Property | Value |
|---|---|
| `StreamingEnabled` | true (Server Authority forces it anyway) |
| `ModelStreamingBehavior` | Improved |
| `StreamingIntegrityMode` | PauseOutsideLoadedArea |
| `StreamingMinRadius` | 64 (default) |
| `StreamingTargetRadius` | 1024 default; try 700 for a dense city and measure |
| `StreamOutBehavior` | Opportunistic |
| `EnableSLIMAvatars` | Enabled (light stand-ins for far avatars) |

## 2. How to build the map so streaming works
- **Group by place, small models:** each building = a Model; split big ones into ~64-stud chunks. Static props (benches, hydrants, lamp posts): `Model.LevelOfDetail = SLIM` for far views.
- **Atomic** for things scripts need whole: cars, a store's counter + prompt + door, a house interior.
- **Persistent** sparingly: only things every client needs all the time (the spawn's job board). Never nest Persistent inside Atomic.
- **Data, not parts, for global info:** world icon positions, the lane graph, ATM list, store hours live in `ReplicatedStorage.Config` modules. The client never searches the map for them.
- Client scripts use `WaitForChild(name, timeout)` for anything in the world; react to `CollectionService:GetInstanceAddedSignal(tag)` for tagged props (street lights, doors) because they stream in and out.
- Teleports (spawn at house, jail, hospital): server calls `player:RequestStreamAroundAsync(target)` first, then `PivotTo`, with a short fade.
- Server does the authoritative distance/raycast checks (the client only sees streamed-in parts).
- AI conversion: Roblox ships an `rbx-convert-to-streaming` Assistant skill (MCP-capable) for existing places; back up first.

## 3. Budgets (mid phone, 40 players)
| Thing | Budget |
|---|---|
| Frame time | ≤ 25 ms (40 FPS floor), target 16 ms |
| Client memory | ≤ 1.2 GB on phones (watch `Developer Console > Memory`) |
| Visible draw calls | ≤ 1,500 near downtown |
| Unique textures | atlas where possible; ≤ 1024² for buildings, 512² for props |
| Lights with shadows | ≤ 6 near the player |
| Client NPC cars / people | 12 / 20 on phones |
| Server heartbeat | ≥ 50 Hz with 40 players and 20 cars |
| Remote traffic | ≤ 50 KB/s per player average |

## 4. Common city-map killers and fixes
| Symptom | Cause | Fix |
|---|---|---|
| Phones crash after 10 min | Memory from never streaming out | `StreamOutBehavior = Opportunistic`, smaller models, fewer unique meshes |
| Stutter when driving fast | Streaming can't keep up | Lower target radius, `RequestStreamAroundAsync` ahead of fast cars every 2 s, simpler far buildings (SLIM) |
| Floating world icons with missing buildings | Icons read parts | Icons from config Vector3s (note 01) |
| Prompts don't appear at stores | Counter part streamed separately from the store | Put counter + prompt in an Atomic model |
| Server lag at 30+ players | Per-frame server loops over every part | Event-driven code; tagged sets; spatial hashes; move cosmetics to clients |
| 300k-triangle props | Unoptimised imports | LOD meshes, `RenderFidelity = Automatic`, collision `Box` for small props, `CanCollide/CanQuery/CanTouch` off where not needed |

## 5. Test routine (each map change)
1. Device Simulator (iPhone SE + a mid Android preset) with the **network simulator** at 150 ms.
2. Drive the whole loop road at top speed; watch MicroProfiler for streaming spikes.
3. Studio "SLIM debug tints" view (beta) to see what's SLIM vs full.
4. Test with `StreamingTargetRadius = 64` to catch missing `WaitForChild`.
5. A 40-bot load test (Studio's local server with 8 clients + server-side dummy characters) for heartbeat.

## Done when
- A mid phone drives the full map for 15 minutes without a crash, under 1.2 GB.
- Every script still works with the minimum streaming radius.

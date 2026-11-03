# Build List: LihFolk Upgrades

Written 2026-11-03. This list comes from reading the imported [[00 Start Here|LihFolk Vault V2]] against the game's current code in `Miami Trap Life/src` and the benchmark write-up in `benchmarks/analysis.md` (Urban Reload, OPPS, BlockSpin).

Related notes: [[Hood RP Systems Research]] · [[Asset Pack Picks]] · [[Lessons Learned]]

**How to read this.** Each item is one concrete change. **Owner** is the thread that should build it. "Now" means what I found in our code by searching, which is not a full review, so the owner checks it first. Items are ordered by impact for the effort.

---

## P0: cheap, big wins (do first)

### 1. Car anti-exploit and spawner limits
**Owner:** phone/garage
**Now:** `VehicleService.lua` checks speed only at spawn. I found no per-car driving check, and `SetNetworkOwner` appears in only one file.
**Change:**
- Parked and empty cars are always owned by the server. Give ownership to the driver only, and only on sit, then set it again after every unanchor.
- Run a check on each driven car 4 times a second. Use horizontal speed only, plus a hover check. Allow 3 bad readings in a row, then take ownership back (don't kick). Any speed-up the server causes, like boosts or teleports, calls `allow` first.
- Limits: 1 active car per player, about 1.2 × max players per server, a 3–5 s spawn cooldown, an abandon timer of 2 min, and a wreck timer of 20 s. Seat-eject everyone before you destroy a car.
- The garage is data, not instances: despawning never refunds and spawning never grants.
**Read:** [[Vehicle Ownership and Anti-Exploit - Server-Checked Driving]], [[Vehicle Spawner and Garage - Spawn, Ownership, Despawn and Limits]]

### 2. Close dupe holes in the money paths
**Owner:** crime loop (with apartment/desk PC for the safe)
**Now:** we have ProfileStore with session locking, and `LogEconomyEvent` for Cash and Dirty money.
**Change:**
- Every payout and spend does plan → validate → apply → record, with **no yield between the check and the write**. That covers robbery payouts, laundering, safe deposits and the gun shop.
- Each gun and rare item gets a GUID that never changes when it moves (we already call `GenerateGUID` in places).
- When a profile loads, check that every currency is a finite, non-negative integer under a cap, and flag an account that is a few days old but holds a lot of rare items.
- Daily rewards use server `os.time()`, and the profile is marked as claimed before the reward is granted.
**Read:** [[Economy Exploits - Dupes Races and Purchase Abuse]]

### 3. Camera shake and hit-stop on guns
**Owner:** guns
**Now:** there's no shake or trauma code anywhere in `src`.
**Change:** use one trauma-based shake system. Pistol shot is Medium (0.12 trauma), rifle burst is Heavy (0.25), shotgun or getting hit is Finisher (0.35). Shake felt = trauma². When aiming, scale rotation by `tan(FOV/2)/tan(35°)`, or a zoomed shake feels twice as hard. Cap hit-stop at 140 ms in any 0.6 s window. Add a shake slider (0–100%) in settings.
**Read:** [[Hit-Stop and Screen Shake Tuning by Numbers]], [[Projectile VFX - Muzzle, Travel and Impact]], [[Screen Damage Effects - Hit Flash, Low-Health Vignette and Blur]]

### 4. Downed → finish → ragdoll
**Owner:** guns (the downed state and ragdoll), crime loop (the drop and the payout)
**Now:** `CrimeRules.lua` already handles what a downed player drops. I found no ragdoll.
**Change:** at 0 HP the player is downed: they crawl, can't shoot, and bleed out after 20 s. Someone can **finish** them with a hold-E. Kill money and loot pay only on a finish, which is how Urban Reload does it. Ragdoll on death. Show a death recap with a "Respawn" button, plus spawn protection.
**Read:** [[Quick Respawn and Spawn Protection]], [[Gore Policy and Kid-Friendly Hit Feedback]]

### 5. Keybind hints that change with context
**Owner:** HUD
**Change:** a small list at the bottom left that changes with what you're doing. On foot: `Shift Sprint · RMB Aim · Q Swap shoulder · R Reload · C Crouch`. In a car: `Space Handbrake · E Exit · L Lock`. Hide it after 10 minutes of play, and let players turn it back on. BlockSpin is the market leader and does this.
**Read:** [[Skippable Tutorials and Replayable Tips]]

### 6. QoL batch (all small)
**Owner:** HUD (sliders and toasts), quality (the SoundGroup mix)
- A music slider and SFX slider, with every sound in a SoundGroup.
- A clear reason when an action is refused ("Need $120 more", "Robbery cooldown 2:14").
- A rejoin button, hold/toggle sprint and aim, and at most one popup in the first minute.
**Read:** [[Top 25 QoL Wins by Effort]], [[Audio Mixer Settings with SoundGroups]]

---

## P1: what makes it feel like a real hood RP

### 7. Visible wanted stars and police response tiers
**Owner:** crime loop
**Now:** heat exists in code. Make it something players can see and play around.
**Change:** show 1–5 stars at the top right, and have stars wear off only while no cop or camera can see you. Response by stars: 1 = cops on foot, 2 = patrol car, 3 = two cars plus a roadblock, 4 = a helicopter spotlight at night, 5 = SWAT. Lose them by driving through the car wash or a paint shop, or by hiding in your apartment.
Also gate robbery targets by **crime rank**, the way Southwest Florida does: gas station → pharmacy → supermarket → jeweller → bank. Each register takes about 80 s to rob, with a 5 min cooldown per register. The bank vault takes about 5 min, with a 30 min cooldown per server.
**Read:** [[Hood RP Systems Research]]

### 8. Crew turf
**Owner:** crime loop
**Change:** cut the map into 6–8 corners. A crew captures a corner by holding its zone with no rival inside for 60 s, and the corner pays the crew bank every 10 min. Show crew tags on name tags and a turf overlay on the minimap. Taking turf raises your stars, so cops show up at turf fights.

### 9. Car culture
**Owner:** phone/garage
**Change:** a handbrake drift with tyre smoke (check the existing drift code first), and engine pitch driven by RPM with tyre squeal driven by slip. Add underglow, wraps and rim choices. Add a night car-meet spot with a "rev" emote that plays when you're parked. Put a speed readout on the HUD. Make the controls work on a phone and a gamepad.
**Read:** [[Steering Geometry and Arcade Drifting - Ackermann, Slip and Grip Tuning]], [[Engine and Tyre Audio Driven by RPM and Slip]], [[Vehicle Controls on Phone and Gamepad - Input Actions for Throttle and Steer]], [[Vehicle Damage, Repair and Wreck States]]

### 10. Apartment safe and dropping items on death
**Owner:** apartment/desk PC
**Change:** you drop what you carry if you die while combat-tagged. What's in the safe is kept, and so are cars. Safe slots start at 10 and upgrade up to 25 with cash. Add a gun repair bench if guns get durability. Both BlockSpin and OPPS are built around this, and it's what makes going outside risky.

### 11. Economy you can tune without a publish
**Owner:** crime loop (wiring), quality (the dashboard)
**Change:** send `LogEconomyEvent` with custom fields: a level band ("lvl_10_19") and a config version ("econ_v3"). Watch three numbers: hours of income held (p50/p90), time to afford the next big buy, and any money sink that drops by more than half in a day. Move prices and payouts into `ConfigService` so tuning doesn't need a new publish.
**Read:** [[Economy Telemetry and Balancing Live]], [[Pricing Curves and Upgrade Costs]], [[Currency Architecture - Soft Hard and Event Currencies]]

### 12. Skies, haze and a real night
**Owner:** lighting
**Change:** use the pack's golden-hour and night skies (see [[Asset Pack Picks]]). Use Future lighting with Atmosphere haze, which OPPS does to look premium. Night gets a blue ambient light plus neon from the shops.
**Read:** [[Atmosphere Sky Clouds and Post-Processing]], [[Lighting Mood and Time of Day]], [[Stylized Lighting Recipes]]

### 13. Fix flat roads, bare roofs and missing trees
**Owner:** quality
**Change:** the pack has **no asphalt**, so roads need a custom MaterialVariant made with [[MaterialService and Custom Materials]]: asphalt with skid marks, crosswalks and lane paint as decals. Roofs get clutter (see [[Asset Pack Picks]]). Trees need palms, which the pack doesn't have, so we model or generate them.
**Read:** [[Tiling Trim Sheets and Decal Tricks]], [[SurfaceAppearance PBR Workflow]], [[Map and Building Quality - Lessons]]

### 14. Split-body aim and a tactical run
**Owner:** animations
**Change:** while aiming, rotate the Waist and Neck Motor6D toward the camera every frame, on top of the locomotion animation. Sprint uses a high-ready rifle pose. This is the thing that makes Urban Reload feel best. The pack's Walk, Run, Sprint and Idle clips are good fallback locomotion (scanned: animation keyframes only, no scripts).

### 15. Story delivery
**Owner:** story cutscenes
**Change:** keep each story beat to 3 lines of dialogue at most. Give every mission a one-line hook ("Patel's register got hit. Find out who."). Save story flags per chapter, and let groups skip cutscenes by vote.
**Read:** [[Quest Writing and Hooks]], [[Lore Delivery Without Walls of Text]], [[Story State Flags and Chapter Saves]], [[Multiplayer Cutscene Sync - Server Clock, Late Joiners and Skip Votes]]

### 16. Waypoints and a compass
**Owner:** minimap
**Change:** add a compass strip at the top centre with the objective marker, and floating 3D icons over the shops (OPPS does this). Add a "waypoint icons" toggle in settings.

---

## P2: once the core is fun

### 17. Live ops rhythm
**Owner:** coordinator to assign
A two-week event calendar. The first event is a block party or holiday event with a 3-tier quest and an exclusive car wrap. Add a patch notes board in the spawn area, and feature flags so risky changes can go out in stages.
**Read:** [[Event Calendars and Content Planning]], [[Patch Notes and Player Communication]], [[Feature Flags and Staged Rollouts]], [[Limited-Time Offers - Design and Ethics]]

### 18. Server Authority (watch it, don't adopt it yet)
**Owner:** phone/garage and guns, later
It's a Studio beta and can't be published yet. It needs StreamingEnabled, deferred signals, fixed physics stepping and the Input Action System, and under it `SetNetworkOwner` calls error. Build item 1 with the swap in mind: keep the drive logic in one module.

### 19. Monetization guardrails
**Owner:** coordinator
No guns sold for Robux, which is what hurt OPPS. A revenge pack (about R$25), car wraps, a subscription with a 1.5× cap and crew creation are all fair. Gun cases must show their odds.

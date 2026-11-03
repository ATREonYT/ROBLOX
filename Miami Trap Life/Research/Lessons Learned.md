# Lessons Learned

This is an ongoing log. Add a dated line whenever something new is learned from research, a playtest or a bug. Newest first.

## 2026-11-03: from importing the LihFolk vault
- **The LihFolk vault is broad Roblox craft, not hood RP.** It's strong on vehicles, anti-exploit, economy, QoL, game feel and lighting, and has nothing on crime, police or gangs. Use it for *how to build* things and our benchmarks for *what to build*. → [[Hood RP Systems Research]]
- **Parked cars must belong to the server.** Automatic network ownership hands a nearby car to an exploiter, who can throw it. → [[Vehicle Ownership and Anti-Exploit - Server-Checked Driving]]
- **Never yield between checking money and writing it.** Every dupe in a single server comes from that gap. → [[Economy Exploits - Dupes Races and Purchase Abuse]]
- **Camera shake depends on FOV, not screen size.** A shake tuned at FOV 70 is about twice as strong while zoomed to FOV 40, so scale it when aiming. → [[Hit-Stop and Screen Shake Tuning by Numbers]]
- **Hit-stop under about 66 ms is unreliable on 30 fps phones.**
- **Car templates belong in ServerStorage, not ReplicatedStorage**, or every player downloads every car when they join. Our `VehicleService` already does this.
- **Log economy events after the change is applied**, from one place, with SKU names that never change.
- **Server Authority is not publishable yet** (Studio beta). Design the drive logic as one module so we can switch later.
- **The LihFolk asset pack is mostly fantasy.** Skies, brick, metal, tile and grass materials, and crate/pipe/barrel props are useful. It has no asphalt, palms or street furniture. → [[Asset Pack Picks]]
- **Downloaded vaults can carry code.** This one had an Obsidian plugin (harmless) and a Claude Code hook that ran shell and PowerShell scripts. Import notes and assets only, never `.obsidian`, hooks or scripts.

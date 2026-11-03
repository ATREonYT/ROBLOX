# Hood RP Systems Research

These are things the LihFolk vault does not cover, because it has no crime, police, gang or hood-specific notes. They come from our own benchmark write-up (`benchmarks/analysis.md`) plus web research done on 2026-11-03. Linked from [[Build List - LihFolk Upgrades]].

## Crime progression (Southwest Florida)
- Criminals have no paycheck; income comes from robberies. **Five ranks** go up with each robbery you get away with: Thief → Grunt → Ring Leader → Felon → Crime Lord.
- The targets you unlock by rank are: diner and gas station → pharmacy and pizzeria → supermarket → café and restaurant → bank.
- Each cashier takes **80 s** to rob and then has a **300 s cooldown**. The bank vault takes **300 s**, with a cooldown of about 30 min.
- A victim can only be intimidated again after a cooldown. Hidden ammo boxes are scattered around the map. Crime Lords set up races and heists.
- **Takeaway:** a ladder of rank-gated targets gives crime a long-term goal, so it isn't just repeat robbing. See Build List item 7.

Source: [Sportskeeda: Southwest Florida Criminal Guide](https://sportskeeda.com/roblox-news/southwest-florida-criminal-guide)

## South Bronx
- Jobs are found at stores marked "hiring" with floating map labels, and you can hold **several jobs** at once.
- You can send cash to another player from the in-game phone, which fits our phone.
- Character creation is permanent: hair, face and name.

Source: [Sportskeeda: South Bronx guide](https://www.sportskeeda.com/roblox-news/south-bronx-guide)

## Patterns across the benchmarks (from `benchmarks/analysis.md`)
- **Death has stakes:** you drop what you carry when you die combat-tagged. The house safe keeps items, and vehicles are never lost.
- **Downed → finish:** kill rewards pay only on the finish.
- **Gun sources:** cases with posted odds, or a shop with a restock timer. Selling guns for Robux (OPPS) drew complaints.
- **Social:** crews with tags, and turf or "land fights". Voice chat is central.
- **What players love:** movement skill (Urban Reload), the "GTA on Roblox" feel and the farming grind (BlockSpin).

## Platform: Server Authority (2026)
- It's in **Studio beta and can't be published to live games yet**, and the API may change.
- It requires StreamingEnabled, deferred signals, fixed physics stepping, `UseFixedSimulation`, the Input Action System and Next Generation Replication.
- The client predicts and the server rolls back. It stops fly, walk-speed and property hacks out of the box.
- To migrate: put shared physics in one module run through `BindToSimulation`, and don't yield or touch GUI inside it. `SetNetworkOwner` calls error under it. Delay instant effects like explosions slightly so the client and server can line up.

Source: [Last Level: Server Authority, what developers need to know](https://lastlevel.pages.dev/blog/server-authority-what-developers-need-to-know). Also covered in the LihFolk note [[Server Authority and Input Migration 2026]].

## Still to research next
- Police as a **player role** (Southwest Florida and Da Hood both have one): arrest flow, jail time and anti-abuse rules for cops.
- Car meets and street racing as an RP activity, and how top games run them.
- What hood RP communities say they want (Reddit/YouTube comments) for the next update.

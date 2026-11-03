# Desk empire: wiring into existing files (apply on the Mac vault + Studio)

New files (copy as-is):
- Config: OS.lua, Coins.lua, Realty.lua, Freight.lua, ReUp.lua
- Rules: OSRules.lua, FreightRules.lua
- Services: DeskService, CoinMarket, CoinService, BankService, HomeUpgrades, RealtyService, FreightService,
  ReUpService, PlayerPrompt
- Controllers: DeskController, OS/LibertyOS, OS/Apps/{Mail,Bank,Home,CoinBay,Realty,Freight,ReUp}
- tools/BuildFlatInterior.lua (sync FROM Studio's ServerStorage.MTL_Tools.BuildFlatInterior first: Studio is newer)

Edits to existing files:
1. Net.lua: RemoteEvent DeskState, RemoteEvent DeskAction, RemoteFunction OSRequest. Master Plan §3.3 too.
2. Main.server.lua: DeskService.init() after PropertyService (app servers init from DeskService.init).
   CrimeService must init before DeskService (ReUp/PlayerPrompt use its prompt + minigame).
3. Client.client.lua: DeskController after PropertyController.
4. ProfileSchema: Desk = { Mail = {} }, Coins = { Pos = {}, Stats = { Trades=0, Best=0, Escaped=0, Realised=0 } },
   Home.Tier = 0, Realty = { Owned = {} }, Freight = {}, ReUp = {}, LastSeen (set on leave; FreightService raids).
5. EconomyService.transfer(player, delta, reason) -> bool: moves clean cash without 2x / Stats / "+$" pop, fires
   CashChanged, syncs leaderstats (BankService falls back to spend/addCash without it).
6. PropertyService:
   - buildRoom: prune folders whose MinTier/MaxTier exclude Home.Tier.
   - refreshTier(player): re-dress the live room (fade client side) - HomeUpgrades calls it when the player stands.
   - PC prompt (power on): DeskService.sit(player, Screen.Position, ChairSpot CFrame facing the desk).
   - Prompts for the Act_ anchors (fridge, stove, sink, shower, toilet, basin, TV, wardrobe, stash, window, switch,
     bath door) with poses + sounds.
7. PropertyController: PowerLight lights + PowerNeon parts follow power; Screen clock; TV news incl. CoinBay mood.
8. Client: hide ProximityPrompts whose MTL_Owner attribute isn't the local player (FreightService/PlayerPrompt fallback).
9. Phone Money app (Config/Earn): entries kind = "Business" for Freight / Re-Up / CoinBay.

Map checks (TODO(map check) in configs): Ends Lockup door, Brickell tower door, Star Island lot, Freight pickups +
buyer curbs, the Plug container, the 4 corners, the bulk meets. Stash interiors (Station, Safe points) later.

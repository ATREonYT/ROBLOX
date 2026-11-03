# Free car candidates (scanned 2026-11-03)

Every model was loaded into a detached container (parent nil, InsertService:LoadAsset, falling back to game:GetObjects), scanned in Edit and destroyed. None of them was ever parented into the place.

Each script was pattern-scanned for:
- `require(<number>)` and `require(x.Value)`
- getfenv, setfenv, loadstring
- string.char, string.byte, escaped-byte strings
- HttpService, MarketplaceService, InsertService, TeleportService, GetObjects
- IsStudio, CoreGui, "Roblox Studio" text, rbx-cdn, URLs
- lines longer than 400 characters

Each model was also scanned for:
- ObjectValue, RemoteEvent and RemoteFunction, BindableEvent and BindableFunction, Configuration, ScreenGui
- StringValues that hold code
- Number and IntValues above 1e8
- Row## or long string attributes

**Result:** no malware signatures in any of the 32 models.
- Nothing matched `require(number)` or `require(.Value)`, getfenv, setfenv, loadstring, obfuscation, IsStudio, CoreGui, rbx-cdn, Row## attributes or big-number values.
- The only flags are listed per car below.

Notes on the columns:
- **parts** counts every BasePart.
- **scripts** counts every LuaSourceContainer.
- **wheels** lists named wheel parts.

## Bike

**14052699364 "Old Motorcycle (Cafe Racer)"** (CoolBaconHairG) — PICK
- 23 parts, **0 scripts**
- wheels FrontWheel, RearWheel, Tire x2
- no seat

**187733249 "Motorcycle"** (NWSpacek, 1166 favs)
- 67 parts, 4 scripts, all clean bike chassis: Create Bike Motors, Bike FE Script, BikeSteering, Unanchor
- Tire/Wheel x2
- dated look

**684576618 "Yamaha R6"** (Deathwish2333)
- 187 parts, 13 scripts, all clean
- includes a 46.9k LocalScript GUI (strip)
- wheels fWheel, rWheel

**12875869842 "Dirt-Bike"** (JuanCool_2004)
- 75 parts, 6 scripts: the same clean bike chassis as 187733249, plus regen

Not recommended:
- **5069856716 "Mobility Scooter":** A-Chassis, 11 scripts, clean.
- 9482273043, 4837833123 and 998438527 are static scooter props with 0 scripts.

## Beater (~$2.5k)

**122745910070958 "1999 Oldsmobile Cutlass"** (yiypoo1024) — PICK
- 23 parts, **0 scripts**
- wheels not named
- no seat

**3118453325 "2011 Kia C'eed"** (xriaou, 5 favs)
- 53 parts, 31 A-Chassis scripts, all clean
- FL/FR/RL/RR wheels

**374305724 "2007 Toyota Corolla S"** (LARZYOG, 5 favs)
- 289 parts, 43 old-style scripts, all clean
- Wheel x4

Rejected:
- **5302086856 "old sedan":** 20 parts, a crude prop.
- **3117520098:** a broken orientation, 8x21x7.
- **2953573038:** 30x94x128 studs, not car-sized.

## Old SUV (~$6k)

**8115414542 "1989 Jeep Grand Wagoneer"** (AgentjAmEs86, 3 favs) — PICK
- 104 parts, **0 scripts**
- named wheel meshes

**1347328851 "1990 Ford Bronco"** (J_accc, 103 favs)
- 93 parts, 45 scripts
- FLAG: 4 disabled radio scripts (pop/rap/indie/past) call HttpService:GetAsync on api.trello.com and MarketplaceService:PromptProductPurchase. The radio also adds RemoteEvents (addSong, purchaseSong, vote*).
- the rest is clean A-Chassis plus doors; strip everything

**6418234850 "SUV"** (official Roblox, 246 favs)
- 3 colour variants, about 76 parts each
- Roblox vehicle-kit scripts (14 per car); HttpService is only GenerateGUID
- modern, not old

Rejected: **2493120228 "Escape":** 24x21x53 studs, odd scale.

## Muscle (~$15k)

**13443669407 "2020 Dodge Charger SRT Hellcat Widebody"** (JusRonan, 10 favs) — PICK
- 142 parts, 24 A-Chassis scripts, all clean

**3602145396 "Muscle Car"** (seemlymorty123, 6 favs)
- 22 parts, 32 scripts, clean
- A-Chassis Tune is nested twice (sloppy)

**3469030735 "Low-poly muscle car"** (hexuvium, 19 favs)
- 34 parts, **0 scripts**
- no seat, wheels not named

Also an option: **8615358980 "1970 Oldsmobile Cutlass 442"** (see Lowrider).

Rejected: **477067793:** a bare chassis.

## Lowrider (~$25k)

**13791818186 "Impala 64 SS (Lowrider)"** (Powering_BaconYT, 13 favs) — PICK
- 403 parts (over 300; it ships with an interior pack)
- 31 scripts, all clean; the top-level "Delete" script is only a credits comment

**10525968859 "Lowrider (Hydraulics)"** (KingNuke2493, 6 favs)
- 123 parts, 39 scripts, clean
- includes a music Tool and GUI

**8615358980 "1970 Oldsmobile Cutlass 442"** (58bbwapache, 7 favs)
- 175 parts, 30 scripts, clean

**327129409 "1964 Chevy Impala"** (DriftZillaa, 6 favs)
- 401 brick parts, 16 old scripts, clean

## Sports (~$60k)

**6788056772 "Nissan Skyline GTR R32 // Rosh"** (BadboyWestern, 155 favs) — PICK
- 268 parts, 25 scripts, clean

**6433323089 "Sports Car"** (official Roblox, 455 favs)
- 3 variants, about 59 parts each
- Roblox vehicle-kit scripts

**8573316692 "Drift Car"** (LebbiPlays, 23 favs)
- 107 parts, 18 scripts, clean

**15574301834 "Sports Car"** (Nobody12034)
- 183 parts, 0 scripts, no seat
- looks like a supercar

## Truck (bonus)

**6418225759 "Pickup Truck"** (official Roblox, 307 favs)
- 3 variants, about 71 parts each
- Roblox vehicle kit

**4518702166 "Old Pickup Truck & Tow Truck"**
- 54 parts, 0 scripts
- two vehicles in one model

**4734214382 "Pickup Truck 2004"**
- 2 meshes, 0 scripts
- wheels are not separate parts

Thumbnails: `<rung>-<id>.png` in this folder.

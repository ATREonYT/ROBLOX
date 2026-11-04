---
tags: [build-playbooks, realistic-rp, economy, jobs, stores, inventory]
updated: 2026-11-01
---

# 02 Economy, Jobs, Stores and Inventory

Back to [[00 Start Here - Realistic City RP]] · Deeper theory: [[Brief - Saving, Economy and Monetization]], LihFolk `48 Economy Design Deep Dive` · Kit: `Server/Wallet.luau`, `Server/Roleplay.luau` (jobs, paychecks), `Server/Inventory.luau`

## 1. Money model: two pockets

| Pocket | Shown | Comes from | Goes to | Risk |
|---|---|---|---|---|
| **Cash** | Big green HUD pill | ATM withdrawals, job tips, pickups, robbery takes (dirty-free: see §6) | Counters, vending, fines paid on the spot | 10% (max $5,000) drops on knockout as a pickup |
| **Bank** | Phone → Bank app, ATMs | Paychecks, sales, transfers, refunds | Card payments, dealership, house, transfers | Never drops |

Why two pockets: it creates a *decision* ("carry cash for the store, or keep it safe?"), gives ATMs a reason to exist (a social spot on every corner), and makes PvP stakes small and readable. Kit `Wallet` implements it: whole positive amounts only, named faucets with hourly caps, a 50-line ledger, daily transfer cap.

Server wiring (shape):
```lua
-- ServerScriptService/City/Money.server.lua
local Wallet = require(ServerScriptService.Kit.Wallet)
local function walletOf(player) return Wallet.new(PlayerData.Get(player).Wallet) end

local function publish(player) -- the HUD reads attributes; never trust them back
	local w = walletOf(player)
	player:SetAttribute("Cash", w.cash)
	player:SetAttribute("Bank", w.bank) -- only the owner needs it; fine as an attribute (or send via remote)
end

function Money.PayCheck(player, amount)
	local ok, why = Wallet.Earn(walletOf(player), amount, "Paycheck", os.time())
	if ok then PlayerData.MarkDirty(player); publish(player); Net.Toast(player, `+${amount} Paycheck`) end
	return ok, why
end
```
Rules: **only the server** calls `Wallet.*`. The client sends "I pressed Buy on item `Soda`"; the server looks up the price in its own catalog. Never a remote like `GiveCash(amount)`.

## 2. Faucets and sinks (the economy must drain as fast as it fills)

| Faucets (money in) | Typical | Sinks (money out) | Typical |
|---|---|---|---|
| Job task | $60-$150 / task | Cars | $4k → $250k ladder |
| Paycheck bonus for on-duty services (police, medic) | $150 / 3 min if a duty action happened | Fuel | $3/unit (~$180 a tank) |
| Selling to players (player-run store) | price set by owner | Repairs, impound | 25% of car price × damage; 5% impound |
| Robbery (opt-in crime) | $300-$2,500 | Clothes, haircuts | $50-$2,000 |
| Daily login gift | small | Weapons, ammo | $800-$6,000; ammo $2/round |
| Bounty (police) | $150 / star | Hospital bill on respawn | $100 or 5% of bank, whichever is smaller |
| | | House, furniture | $25k-$1M; furniture $50-$20k |
| | | Fines, bail | $50-$2,000 |

Tuning method: simulate an hour for three player types (legal grinder, criminal, social idler) with the kit's `tools/sim.luau` pattern; the idler must earn **~20%** of the grinder, the criminal **1.3-1.6×** the grinder *with* real risk of losing it. Target the **first car at 30-40 minutes**, first house at **3-5 hours**, a supercar at **20+ hours**. Track the money supply weekly (total cash + bank across active players); if it grows > 15%/week without new sinks, add a sink before a nerf.

## 3. Jobs that are fun (not chores)

The fan guides rate "mop the floor" jobs as the worst in the genre. Every job here must be **a 20-60 s mini-game, 3 presses deep, for someone else**, and pay more for skill.

| Job | Task loop (20-60 s) | Skill twist | Who it serves |
|---|---|---|---|
| Delivery driver | pick up box at depot → drive to marked house → hand over | time bonus, no-damage bonus | NPC homes + player stores restock |
| Mechanic | diagnose (pick the glowing part) → repair hold → test drive | perfect-timing hold bar | Players' damaged cars |
| Medic | respond to downed player → CPR rhythm → transport | rhythm accuracy | Knocked-out players |
| Police (opt-in, capped 25%) | respond to 911 → chase → cuff → book | arrests without collateral damage | The whole server |
| Firefighter | city event fires → hose → rescue NPC | spread control | City events |
| Taxi / rideshare | accept from phone → drive player → rating | smooth driving (no hard braking) | Players without cars |
| Construction | place beams on a pattern before the crane swings back | pattern speed | City "rebuild" event |
| Barber / stylist | player sits → pick style → cut mini-game | combo accuracy | Players' looks |
| Store clerk (player-run) | restock shelves, ring up players | pricing | Players |

Kit hooks: `Roleplay.CanJoin(jobs, name, counts)` (caps), `Roleplay.Paycheck(job, lastActive, now)` (pays only if the server saw work in the window). Job pay pattern:
```lua
-- On a SERVER-observed job action (package handed over at the right door, prompt hold completed):
local base = Jobs[job].taskPay                  -- e.g. 90
local skill = math.clamp(result.score, 0, 1)    -- from the mini-game, validated (e.g. time within limits)
local pay = math.floor(base * (0.8 + 0.6 * skill))
Wallet.Earn(w, pay, "Job", now)
lastActive[player] = now                        -- the 3-minute paycheck bonus needs this
```
Job ranks: 5 ranks per job (Trainee → Lead), each rank +10% pay and a cosmetic (uniform patch, vehicle livery). Ranks are the long goal for legal players.

Job uniforms: on the server, `humanoid:ApplyDescription(jobDescription)` with the player's own `HumanoidDescription` cloned and only shirt/pants/hat swapped; restore on leaving the job.

## 4. Stores and counters

- Every store is a **counter with a ProximityPrompt** → opens the store UI (grid of items with picture, name, price, "Buy" with cash/card toggle).
- The UI shows **what you can afford now** at full colour and the rest dimmed with the gap ("$40 more").
- Purchase remote: `Net` request `Store.Buy(storeId, itemId, method)`. Server checks: player within 12 studs of that store's counter (server position), store open (`WorldClock.IsOpen`), item in that store's catalog, `Wallet.Pay`, inventory space, then grants. Reply with the new balance; the client never assumes success.
- **24/7 store**: food (heals 15-30 HP over 3 s), drinks (stamina boost 20 s), phone credit, bandages.
- **Clothing**: try-on preview (local `HumanoidDescription` on a mannequin `WorldModel` in a ViewportFrame), buy saves to the outfit list.
- **Barber**: hair from a curated list of free catalog hair IDs → saved as outfit parts.
- **Weapon store**: tiers gated by level; see [[04 Combat - Fists, Weapons and Server Hit Validation]].
- **Gas station**: pump prompt → `Garage.RefuelCost` → pay → fuel set on the server.

## 5. Inventory and hotbar

- **Server owns the inventory** (kit `Server/Inventory.luau`): `{ slots = { [1] = "Fists", [2] = "Phone", ... }, bag = { itemId = count } }`.
- **Hotbar 6 slots**, fists fixed in slot 1. Bag 20 slots (a backpack upgrade or pass adds 10; it never sells items).
- Tools: keep weapon/tool *models* in `ServerStorage`; equip = server clones the Tool into the character. The client asks "equip slot 3"; the server checks the item is in slot 3.
- Stack limits (bandage ×5, soda ×5, ammo by weapon) are enforced on the server.
- **Trunk storage** in owned cars and a **house safe**: same inventory module, different container id; move items with one server function that removes from A and adds to B in the same step (no yield in between, so no dupes).

## 6. Crime money (kept kid-safe and simple)

Many hood games use "dirty money" you must launder. Don't: laundering is a real-world crime mechanic that adds busywork and a policy grey zone. Instead, **robbery payouts go straight to pocket cash**, which you can lose on knockout or arrest (the risk), and depositing it at an ATM is the "escape". Arrest takes **all** the robbery cash still in pocket plus a fine; that's tension enough.

## 7. Anti-exploit for money (summary; full list in [[10 Saving, Anti-Exploit and Admin]])
- No remote takes an amount the player receives. Prices and payouts come from server tables.
- Faucets are named and capped per hour (`Wallet.Rules.earnCapsPerHour`); a cap hit is logged with the player and reason.
- Player-to-player trades and transfers happen in one server step on loaded profiles; cross-server only through a receipt with an id saved on both sides.
- Pickups (dropped cash) are server parts with an owner window (2 s for the dropper's attacker, then anyone), touched-checked by server distance.

## Done when
- A new player earns their first $100 inside 90 s and can see what it buys.
- The sim shows first car ≈ 35 min for a grinder and the idler earning ≈ 20%.
- No remote in the game accepts a money amount from the client (grep `FireServer` payloads).

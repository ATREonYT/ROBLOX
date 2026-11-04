---
tags: [build-playbooks, realistic-rp, houses, property, furniture]
updated: 2026-11-01
---

# 06 Houses and Property

Back to [[00 Start Here - Realistic City RP]] · Already covered (don't repeat): [[26 Fun and Roleplay Playbook]] §6 and [[Blueprint - Roleplay Town]] §3-5 · Kit: `Roleplay.Houses` (claim, guests, kick, release; locking off by default)

What a realistic city adds on top of the kid-town house book:

## 1. Rent first, buy later
- **Apartment** (free, from minute 1): a small instanced room you reach through a door prompt in an apartment block. It's the "home" icon in your HUD. Holds outfits, a safe (inventory container), a bed spawn.
- **Houses on the map** (buy, $25k-$1M): a fixed number of plots per server (e.g. 24). Buying one on a server *claims* it for the session; the **purchase is saved**, so on any server you get the same style of house, placed on a free plot of that tier. If none is free, you get your apartment plus a "your house is busy on this server" toast and a button to join a server where it's free.
- This is how the genre gets "you own a house" without one player owning a plot forever.

## 2. Instanced interiors (performance and privacy)
- Exterior shells stay on the map; **interiors live far below the map** (or in a separate streaming area) and are loaded when you enter. Use `player:RequestStreamAroundAsync(interiorPos)` then `PivotTo` the character, with a 0.4 s fade.
- Up to 4 guests through the kit guest list. Kick sends a guest back to the front door.
- **Locking stays off** unless the age rating allows it: lockable rooms make it a "private space" (18+ ID-verified for hangouts). Bedrooms, bathrooms and romance props don't go in. Kitchens, garages, gyms, living rooms, gardens do.

## 3. Furniture placing (the long-term sink)
- Grid placement (1-stud grid, rotate by 45° with R / two-finger twist), preview ghost in green/red, server validates: inside your interior bounds, not overlapping (bounds box), prop cap 40 (`Roleplay.CanPlaceProp`), item owned in inventory.
- Saved layout: `{ itemId, x, y, z, rot }` relative to the interior's origin, max 200 entries, compressed as an array of numbers.
- Furniture catalogue by room, with sets (a full kitchen at a 15% set discount). Some pieces are **functional**: a stove (cook food for +HP), a gym bench (temporary +stamina regen), a garage lift (repair your car at home at 1.0× cost), a TV (plays the city news ticker).

## 4. Businesses (the step above houses)
A player-run store is the best long-term goal in the genre (our standout; see [[13 Beat the Top RP Games]]):
- Buy a storefront lease (weekly in-game rent), set item prices within a ±30% band of the city price, restock from the delivery job (other players), hire up to 3 players as clerks (their pay comes out of the till).
- The server owns stock and till; the owner withdraws to bank. A business with no stock or no rent closes automatically after 7 days offline.

## Done when
- A new player has a home within 60 s (the free apartment) and a reason to buy a real house within 2 hours.
- Placing 40 props is lag-free and survives a server move.

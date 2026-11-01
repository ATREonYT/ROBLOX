---
tags: [build-playbooks, realistic-rp, phone, ui, banking, text-filtering]
updated: 2026-11-01
---

# 07 Phone, Apps and Banking

Back to [[00 Start Here - Realistic City RP]] · UI rules: [[30 UI and UX Playbook]] · Kit: `Wallet.Transfer`, `WorldClock.Label`

The phone is the city RP's **main menu in disguise**. It keeps the HUD clean and makes menus feel in-world. ER:LC's 2026 summer update reworked theirs and added House, Mafia and a gadget store app; phones are where these games keep growing.

## 1. Shape and motion
- Portrait phone frame, 380×760 px at 1080p (on phones: 86% of screen height), bottom-right; slides up 0.28 s (Back easing out, small overshoot), slides down 0.2 s. Opens with **M** / the left menu button / gamepad Select.
- Lock-screen first for 0.3 s (clock from `WorldClock.Label`, wallpaper), then home grid 4×5 of app icons (72 px, rounded 22%).
- While open: the character keeps walking (phone held up, an animation), camera unchanged, world icons hide. In a car: phone opens docked to the side and the car keeps driving.
- Sound: soft "tap" per press, swoosh open/close. Battery and signal bars are decoration only.

## 2. Apps (launch set → later)

| App | What it does | Server calls |
|---|---|---|
| **Bank** | Cash/bank balances, last 20 ledger lines, transfer to a friend in this server | `Wallet.Transfer` (daily cap), ledger read |
| **Jobs** | Current job + rank, accept tasks, set GPS to the next stop, go off duty | `Roleplay.CanJoin` |
| **GPS / Map** | Top-down map with the same icons as the world; tap a place to track it (edge arrow in the world) | none (client), uses `Config.Places` |
| **Garage** | Owned cars; spawn at nearest bay; locate; call a tow | `Roleplay.CanSpawnVehicle`, `Garage` |
| **Calls / 911** | Call police / medic / mechanic / taxi: creates a job request with your position for on-duty players | request queue per service |
| **Messages** | Short messages to players in the server, **filtered** | `TextService:FilterStringAsync` |
| **Contacts** | Friends in server, recent players, block / report | `Players:ReportAbuse` flow via Roblox menu |
| **Wardrobe** | Saved outfits (5 free slots), job uniform toggle | `ApplyDescription` |
| **Settings** | Sound, music, graphics, world icons, PvP rules (private servers), reduced motion | settings save |
| **Shop** | Passes, starter pack, cash packs (if used) | `MarketplaceService` prompts; grants in `ProcessReceipt` |
| Later: **Bizz** (run your store), **News** (city events), **Camera** (photo mode, no uploads), **Music** | | |

## 3. Messages and any player text (must be filtered)
Any text one player writes that another player sees (messages, business names, house sign, plate text) must go through Roblox filtering **on the server**, every time it's shown to a new person:
```lua
local TextService = game:GetService("TextService")
local function filterFor(sender, text, recipient)
	local ok, result = pcall(function()
		return TextService:FilterStringAsync(text, sender.UserId, Enum.TextFilterContext.PrivateChat)
	end)
	if not ok then return nil end -- on failure, show nothing (never the raw text)
	local ok2, out = pcall(function() return result:GetChatForUserAsync(recipient.UserId) end)
	return ok2 and out or nil
end
-- Public text (a store sign everyone sees): Enum.TextFilterContext.PublicChat + result:GetNonChatStringForBroadcastAsync()
```
Respect chat restrictions: if `TextChatService` says a player can't chat (age checks, parental settings), their Messages app shows **Quick Words** only (set game-specific Quick Words in Creator Hub > Configure > Chat: "On my way", "Need a ride?", "Thanks!", "Where's the bank?"). Many players can't chat freely after the 2026 age checks; the phone must work without free text.

## 4. 911 and service calls (the social glue)
```text
Player taps "Call Medic" ─► server: CallQueue.Add{ service="Medic", from=userId, pos=serverPos, t=now }
   ─► every on-duty medic: phone buzz + toast "Call: knocked out near 24/7, 180 m" + Accept
   ─► first Accept wins (server lock) ─► caller sees "Medic on the way" + responder's icon tracked on both screens
   ─► arrive within 8 studs ─► job task completes ─► responder paid (Job faucet), call closed
```
Limits: one open call per player per service, calls expire after 120 s, 30 s cooldown after a call is cancelled. Prank calls cost nothing but the cooldown; repeated cancelled calls (5 in 10 min) mute the caller's calls for 10 min.

## 5. Banking rules (with the ATM)
- ATMs on every 2nd block (the screenshots show them as the bank icon): withdraw and deposit only at an ATM or bank counter (`Wallet.Deposit/Withdraw`, server checks distance to an ATM part).
- The phone Bank app can view balances and **transfer** (bank-to-bank) anywhere, but can't touch cash. That keeps ATMs meaningful.
- Robbing an ATM (crime role) is a 60 s hold with heat; it never takes money from a player, only from the city.

## Done when
- Every menu in the game opens from the phone in two taps or fewer.
- A chat-restricted player can call a medic, transfer money and message "Thanks!" with Quick Words.

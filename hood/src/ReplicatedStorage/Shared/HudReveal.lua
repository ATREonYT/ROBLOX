-- HudReveal (Oct 27, round 8: "teach each system when it first matters", "nothing pops up first"). Which parts of the
-- HUD a player sees, from what they have done. A first-join kid starts on a calm screen: the Shop, the counters and the
-- Power bar. The rest comes in one at a time, when it first means something:
--   Shoes     the first shoe (the tutorial's free gift flies its pair into this button) or the first box you can afford
--   Skins     a second gun to switch to (the first gun bought at the ARMORY)
--   Items     after the tutorial once you own a shoe, or as soon as a pass or a boost is yours (that is what it holds)
--   Rebirth   the first rebirth ready (or any rebirth done)
--   the Robux offers (x2 Cash / Power / Speed, the three Power packs, Auto Fight, the Starter Pack) and the Friend Boost
--   line: once the tutorial is over and its "YOU'RE READY!" has played; they slide in once
-- A part once shown stays for the visit. A returning player (not the save's first join) sees everything from the start.
-- HoodClient/HUD applies it and publishes each part as the PlayerGui attribute HudShown_<Part> for the play tests.
-- Pure: unit-tested (UnitTest/Cases/HudReveal_Test).
local HudReveal = {}

HudReveal.Offers = { 'Offers', 'PowerPacks', 'AutoFight', 'StarterPack', 'FriendBoost' }
HudReveal.Buttons = { 'Shoes', 'Skins', 'Items', 'Rebirth' }
HudReveal.All = { 'Shoes', 'Skins', 'Items', 'Rebirth', 'Offers', 'PowerPacks', 'AutoFight', 'StarterPack', 'FriendBoost' }
HudReveal.ReadyWait = 25 -- seconds after the tutorial's end at most before the offers come anyway (a lost moment)

local function num(v) return type(v) == 'number' and v == v and v or 0 end

-- What the state asks for now (not sticky). s fields (missing = 0 / false):
--   Returning      not the save's first join: everything
--   TutorialDone   the tutorial is over and its YOU'RE READY! has played (or was never due this visit)
--   Cash, CheapestBox, Shoes (pairs owned), Boxes (boxes opened), Unboxing (a box opening on screen)
--   Guns           guns owned
--   Passes, Boosts passes / running or queued boosts owned (the Items tab's contents)
--   Power, RebirthNeed, RebirthReady, Rebirths
-- Returns { [part] = true } for each part wanted.
function HudReveal.wants(s)
	s = type(s) == 'table' and s or {}
	local out = {}
	if s.Returning == true then
		for _, p in HudReveal.All do out[p] = true end
		return out
	end
	local shoe = num(s.Shoes) > 0 or num(s.Boxes) > 0 or s.Unboxing == true
	local box = num(s.CheapestBox) > 0 and num(s.Cash) >= num(s.CheapestBox)
	if shoe or box then out.Shoes = true end
	if num(s.Guns) >= 2 then out.Skins = true end
	if num(s.Passes) > 0 or num(s.Boosts) > 0 or (s.TutorialDone == true and shoe) or num(s.Rebirths) > 0 then out.Items = true end
	local ready = s.RebirthReady == true or (num(s.RebirthNeed) > 0 and num(s.Power) >= num(s.RebirthNeed))
	if ready or num(s.Rebirths) > 0 then out.Rebirth = true end
	if s.TutorialDone == true or num(s.Rebirths) > 0 then
		for _, p in HudReveal.Offers do out[p] = true end
	end
	return out
end

-- One step of the sticky set: `shown` ({ [part] = true }) gains what the state wants. Returns the parts newly shown,
-- in HudReveal.All's order (the offers last, so the buttons' "NEW!" lands first).
function HudReveal.step(shown, s)
	local fresh = {}
	if type(shown) ~= 'table' then return fresh end
	local want = HudReveal.wants(s)
	for _, p in HudReveal.All do
		if want[p] and not shown[p] then
			shown[p] = true
			table.insert(fresh, p)
		end
	end
	return fresh
end

-- Is `part` one of the buttons that wear a one-time "NEW!" when they appear?
function HudReveal.isButton(part)
	return table.find(HudReveal.Buttons, part) ~= nil
end

return HudReveal

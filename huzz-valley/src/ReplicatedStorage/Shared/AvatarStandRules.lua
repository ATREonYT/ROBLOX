--[[
	What a lobby avatar stand sells, pure (tests/Leaderboards.spec.luau checks it). Owner, Oct 18: "make the blocks i
	have in the lobby, next to the spin the wheel turn into my character and have like animated running ...
	selling a gamepass". The stand's "Pass" attribute (typed in Studio) is a Game Pass key from Config/Products
	("VIP", "DancePack") or a Game Pass ID number.

	The VIEW button opens Roblox's purchase only when BOTH are true (kid-safe: never sell something that gives
	nothing yet):
	  1. the Game Pass ID is a real number, not 0 (we never make IDs up: the owner pastes it into Config/Products);
	  2. the pass already gives something in the game: it's a Config/Products pass that is OnSale (ShopService checks
	     ownership with Roblox and the game grants it). A typed ID that isn't one of those passes gives nothing here.
	Otherwise the button says "SOON" (with its price, like the Shop) or "COMING SOON", and tapping it only shows a
	"coming soon" message. Owners see "OWNED".

	The knife in the copy's hand (owner: "gamepasses shown with the character of the person playing, equipped with
	some exclusive knifes"): one of the pass's own knives (Config/CoinShop items with Pass = that pass), so a stand
	never shows a knife the pass doesn't give. The stand's "Knife" attribute picks which (a knife key, e.g.
	"CelestialSeraph"); unset, stands take the pass's knives in turn.

	Which blocks are stands (findBlocks): in his place his six plain grey blocks (4 x 7.5 x 4.5, named "Part") stand
	beside the big spin wheels; the same rule is used by the place build and, in his own Rojo-synced place (where
	nothing renames them), by HuzzServer/AvatarStandService at game start.
]]
local AvatarStandRules = {}

export type Stand = {
	Status: "Ready" | "Soon",
	Key: string?, -- the Config/Products key, when it's one of the game's passes
	Id: number, -- the Game Pass ID (0 = none yet)
	Title: string,
	Subtitle: string,
	Tag: string,
	Price: number?, -- Robux shown (the live price replaces it once Roblox answers)
	Why: string, -- for the owner (Output): why it isn't on sale yet
}

local function oneLine(s: string?): string
	return (string.gsub(string.gsub(s or "", "%s*\n%s*", " "), "%s+$", ""))
end

-- attrs: the stand's attributes ({ Pass, Title, Subtitle, Tag, Price }); products: Config/Products; knife (optional):
-- the Config/CoinShop knife the copy holds (the subtitle names it when none is typed).
function AvatarStandRules.resolve(attrs: { [string]: any }, products, knife: any?): Stand
	local pass = attrs.Pass
	local product
	local id = 0
	if type(pass) == "number" then
		id = math.floor(pass)
	elseif type(pass) == "string" and pass ~= "" then
		local asNumber = tonumber((string.gsub(pass, "%s", "")))
		if asNumber then
			id = math.floor(asNumber)
		else
			product = products.get(pass)
			if product and product.Kind ~= "Pass" then product = nil end
		end
	end
	if not product and id ~= 0 then
		product = products.byPassId(id)
	end
	if product then id = product.Id end

	local status: "Ready" | "Soon" = "Soon"
	local why
	if not product then
		why = if id ~= 0 then "Game Pass " .. id .. " isn't one of the game's passes in Config/Products, so it gives nothing yet"
			elseif pass ~= nil and pass ~= "" then "no Game Pass called " .. tostring(pass) .. " in Config/Products"
			else "no Pass attribute"
	elseif not product.OnSale then
		why = product.Key .. " gives nothing yet (" .. (product.Why or "OnSale is false") .. ")"
	elseif (product.Id or 0) == 0 then
		why = product.Key .. " has no Game Pass ID yet (Config/Products Id = 0)"
	else
		status = "Ready"
		why = ""
	end

	local title = attrs.Title
	if type(title) ~= "string" or title == "" then title = if product then product.Name else "GAME PASS" end
	local subtitle = attrs.Subtitle
	if type(subtitle) ~= "string" or subtitle == "" then
		subtitle = if knife then "Exclusive knife: " .. knife.Name elseif product then oneLine(product.Blurb) else ""
	end
	local tag = attrs.Tag
	if type(tag) ~= "string" or tag == "" then tag = "GAME PASS" end
	local price = tonumber(attrs.Price) or (product and product.Price) or nil
	return {
		Status = status, Key = product and product.Key, Id = id, Title = string.upper(title), Subtitle = string.upper(subtitle),
		Tag = string.upper(tag), Price = price, Why = why,
	}
end

-- The button's words and whether the Robux mark goes in front: "1,799 · VIEW" (like theirs), "OWNED", and for a
-- pass that isn't on sale "199 · SOON" (the price may show, like the Shop) or "COMING SOON" without a price.
function AvatarStandRules.button(stand: Stand, owned: boolean, price: number?): (string, boolean)
	if owned then return "OWNED", false end
	local p = price or stand.Price
	if stand.Status ~= "Ready" then
		if p then return AvatarStandRules.robux(p) .. " · SOON", true end
		return "COMING SOON", false
	end
	if p then return AvatarStandRules.robux(p) .. " · VIEW", true end
	return "VIEW", false
end

-- 1799 -> "1,799"
function AvatarStandRules.robux(n: number): string
	local s = tostring(math.max(0, math.floor(n)))
	local out = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	return (string.gsub(out, "^,", ""))
end

--[[
	The knife a stand shows. passKey: the stand's pass (Stand.Key); typed: its "Knife" attribute; items: Config/CoinShop
	Items; turn: the stand's number among that pass's stands (1, 2, ...), so unset stands show the pass's knives in
	turn. Returns the knife key (nil: the pass gives none) and, when the typed one was refused, why (for Output).
]]
function AvatarStandRules.knife(passKey: string?, typed: any, items: { any }, turn: number): (string?, string?)
	local own = {}
	for _, item in items do
		if passKey and item.Pass == passKey and item.Slot == "Knife" then table.insert(own, item) end
	end
	table.sort(own, function(a, b) return a.Order < b.Order end)
	local why
	if type(typed) == "string" and typed ~= "" then
		local want = string.lower((string.gsub(typed, "[%s_%-']", "")))
		for _, item in own do
			if string.lower(item.Key) == want or string.lower((string.gsub(item.Name, "[%s_%-']", ""))) == want then return item.Key, nil end
		end
		why = "Knife " .. typed .. " isn't one the " .. tostring(passKey) .. " pass gives (Config/CoinShop Pass), so the stand shows the pass's own"
	end
	if #own == 0 then return nil, why end
	return own[(math.max(1, math.floor(turn)) - 1) % #own + 1].Key, why
end

--[[
	His grey stand blocks beside the big spin wheels (the place build and HuzzServer/AvatarStandService use the same
	rule). wheels: { { X, Y, Z } } centres of the spin wheel models taller than 5 studs (the small 3-stud one isn't a
	wheel stand); parts: { { ref, Name, Class, X, Y, Z, SX, SY, SZ } }. A block is a plain "Part" 3 to 5.5 studs wide
	and deep and 6 to 9 tall (his are 4 x 7.5 x 4.5) within 12 studs (X) and 45 studs (Z) of a wheel. Per wheel,
	nearest Z first, they take the passes in turn (VIP, DancePack) and each stand's number for its pass (`turn`,
	counted over the whole place, so the knives differ from lobby to lobby).
	Returns { { ref, Pass, Turn } } in that order.
]]
AvatarStandRules.PASSES = { "VIP", "DancePack" }
function AvatarStandRules.findBlocks(wheels: { any }, parts: { any }): { any }
	local out, turns, taken = {}, {}, {}
	for _, w in wheels do
		local near = {}
		for _, p in parts do
			if not taken[p.ref] and p.Class == "Part" and p.Name == "Part"
				and p.SX > 3 and p.SX < 5.5 and p.SZ > 3 and p.SZ < 5.5 and p.SY > 6 and p.SY < 9
				and math.abs(p.X - w.X) < 12 and math.abs(p.Z - w.Z) < 45 then
				table.insert(near, p)
			end
		end
		table.sort(near, function(a, b) return a.Z < b.Z end)
		for i, p in near do
			taken[p.ref] = true
			local pass = AvatarStandRules.PASSES[(i - 1) % #AvatarStandRules.PASSES + 1]
			turns[pass] = (turns[pass] or 0) + 1
			table.insert(out, { ref = p.ref, Pass = pass, Turn = turns[pass] })
		end
	end
	return out
end

-- May this stand open Roblox's purchase prompt?
function AvatarStandRules.canPrompt(stand: Stand, owned: boolean): boolean
	return stand.Status == "Ready" and stand.Id ~= 0 and not owned
end

return AvatarStandRules

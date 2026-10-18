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

-- attrs: the stand's attributes ({ Pass, Title, Subtitle, Tag, Price }); products: Config/Products.
function AvatarStandRules.resolve(attrs: { [string]: any }, products): Stand
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
	if type(subtitle) ~= "string" or subtitle == "" then subtitle = if product then oneLine(product.Blurb) else "" end
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

-- May this stand open Roblox's purchase prompt?
function AvatarStandRules.canPrompt(stand: Stand, owned: boolean): boolean
	return stand.Status == "Ready" and stand.Id ~= 0 and not owned
end

return AvatarStandRules

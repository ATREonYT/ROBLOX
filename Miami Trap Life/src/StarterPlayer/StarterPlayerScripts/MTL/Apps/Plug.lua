--!strict
-- Plug app (Piece 5): guns and ammo for the criminal path. Installed by GunService once the player is
-- Criminal (hidden before). Prices, levels and packs come from Config/Guns; the server re-checks everything.
--   GUNS   each gun: damage / fire rate / mag as plain bars, level + price, BUY (or OWNED / Level N)
--   AMMO   one row per ammo type you have a gun for: rounds you carry, +pack for $
-- Buttons: PhoneAction buyGun{gun} / buyAmmo{ammo}.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Guns = require(ReplicatedStorage.MTL.Config.Guns)
local GunRules = require(ReplicatedStorage.MTL.Rules.GunRules)
local Format = require(ReplicatedStorage.MTL.Format)

local App = { id = "Plug", title = "Plug" }

local player = Players.LocalPlayer

local function money(n: number): string
	return Format.cash(n)
end

-- Normalised 0..1 stats for the little bars (relative to the best gun in the list).
local function stats(id: string): (number, number, number)
	local def = Guns.Defs[id]
	local maxDps, maxRpm, maxMag = 0, 0, 0
	for _, g in Guns.Defs do
		maxDps = math.max(maxDps, g.Damage * (g.Pellets or 1))
		maxRpm = math.max(maxRpm, g.RPM)
		maxMag = math.max(maxMag, g.Mag)
	end
	return (def.Damage * (def.Pellets or 1)) / maxDps, def.RPM / maxRpm, def.Mag / maxMag
end

local function statBar(parent: Instance, ctx: any, label: string, v: number, order: number)
	local UIKit, Theme = ctx.UIKit, ctx.Theme
	local row = UIKit.new("Frame", { Name = "Stat_" .. label, LayoutOrder = order, Size = UDim2.new(1, 0, 0, 14), BackgroundTransparency = 1, Parent = parent })
	UIKit.label(row, label, { size = 11, dim = true }).Size = UDim2.new(0, 60, 1, 0)
	local track = UIKit.new("Frame", {
		Position = UDim2.new(0, 64, 0.5, -2),
		Size = UDim2.new(1, -64, 0, 4),
		BackgroundColor3 = Theme.Colors.Stroke,
		BackgroundTransparency = 0.85,
		BorderSizePixel = 0,
		Parent = row,
	}, { UIKit.corner(UDim.new(0, 1)) })
	UIKit.new("Frame", { Size = UDim2.fromScale(math.clamp(v, 0.05, 1), 1), BackgroundColor3 = Theme.Colors.Danger, BorderSizePixel = 0, Parent = track }, { UIKit.corner(UDim.new(0, 1)) })
end

local function render(ctx: any, d: any)
	ctx.clear()
	local UIKit, Theme = ctx.UIKit, ctx.Theme
	local C = Theme.Colors
	UIKit.header(ctx.frame, "Plug")
	local list = UIKit.scroll(ctx.frame, 44, "Plug")
	local inv = d.Inventory or {}
	local owned = inv.Guns or {}
	local ammo = inv.Ammo or {}
	local criminal = d.Path == "Criminal"

	if not criminal then
		local card = UIKit.card(list, 1)
		UIKit.label(card, "Plug only deals with the Criminal lifestyle.", { wrap = true, order = 1 })
		UIKit.label(card, "Switch in Settings > Lifestyle.", { wrap = true, dim = true, size = 12, order = 2 })
		return
	end

	UIKit.section(list, "Guns", 10)
	for i, id in Guns.Order do
		local def = Guns.Defs[id]
		local mine = owned[id] == true
		local card = UIKit.card(list, 10 + i, "Gun_" .. id)
		UIKit.label(card, def.Display, { size = 16, bold = true, order = 1 })
		local sub = (if def.Auto then "Full auto" elseif (def.Pellets or 1) > 1 then "Pump" else "Semi auto") .. " · " .. def.Mag .. " rounds · " .. def.Ammo
		UIKit.label(card, sub, { size = 12, dim = true, order = 2 })
		local dmg, rate, magV = stats(id)
		statBar(card, ctx, "Damage", dmg, 3)
		statBar(card, ctx, "Fire rate", rate, 4)
		statBar(card, ctx, "Mag", magV, 5)
		local ttk = GunRules.shotsToKill(def, 100, 20)
		UIKit.label(card, "Drops someone in " .. ttk .. (if ttk == 1 then " shot" else " shots") .. " up close", { size = 11, dim = true, order = 6 })
		local ok, why = GunRules.canBuyGun(def, d.Level, d.Cash, d.Path, mine)
		if mine then
			UIKit.button(card, "Owned", { style = "secondary", order = 7, disabled = true })
		elseif ok then
			UIKit.button(card, "Buy · " .. money(def.Price), {
				style = "danger",
				order = 7,
				onClick = function()
					ctx.action("buyGun", { gun = id })
				end,
			})
		else
			local text = if d.Level < (def.Level or 1) then ("Level " .. def.Level .. " · " .. money(def.Price)) else ((why or "Locked") .. " · " .. money(def.Price))
			UIKit.button(card, text, { style = "secondary", order = 7, disabled = true })
		end
	end

	UIKit.section(list, "Ammo", 40)
	local any = false
	local types: { string } = {}
	local seen: { [string]: boolean } = {}
	for _, id in Guns.Order do
		local def = Guns.Defs[id]
		if owned[id] and not seen[def.Ammo] then
			seen[def.Ammo] = true
			table.insert(types, def.Ammo)
		end
	end
	for i, a in types do
		any = true
		local pack = Guns.Ammo[a]
		if pack then
			local have = ammo[a] or 0
			local ok, why = GunRules.canBuyAmmo(pack, have, d.Cash, d.Path, true)
			UIKit.row(list, {
				title = pack.Display .. "  ·  " .. have .. " / " .. pack.Max,
				sub = "+" .. pack.Count .. " rounds",
				right = if ok then money(pack.Price) else (why or ""),
				rightColor = if ok then C.Accent else C.TextDim,
				order = 40 + i,
				name = "Ammo_" .. a,
				onClick = function()
					if ok then
						ctx.action("buyAmmo", { ammo = a })
					end
				end,
			})
		end
	end
	if not any then
		UIKit.empty(list, "Buy a gun first.", 41)
	end
	UIKit.label(list, "Guns stay holstered in safe zones and on shift. Civilians can't be shot.", { wrap = true, size = 11, dim = true, order = 60, align = Enum.TextXAlignment.Center })
end

function App.mount(_frame: Frame, ctx: any)
	local lastKey = ""
	ctx.onData(function(d: any)
		local inv = d.Inventory or {}
		local parts = { tostring(d.Path), tostring(d.Level), tostring(d.Cash) }
		for _, id in Guns.Order do
			table.insert(parts, tostring((inv.Guns or {})[id]))
		end
		for a in Guns.Ammo do
			table.insert(parts, a .. "=" .. tostring((inv.Ammo or {})[a]))
		end
		table.sort(parts)
		local k = table.concat(parts, "|")
		if k ~= lastKey then
			lastKey = k
			render(ctx, d)
		end
	end)
	local _ = player
end

return App

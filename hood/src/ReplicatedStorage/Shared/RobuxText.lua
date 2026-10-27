--!strict
-- RobuxText (brief 31, ROBUX): every Robux price the game shows goes through here, so each one wears the Robux sign right
-- before the number, like the reference ("ONLY ⬡79" on the x2 buttons, "⬡399" in the world, "⬡9 / ⬡40 / ⬡120" on the
-- bottom bar; ref_W01.0_spawn_view_north, ref_V3-03.5_store_passes).
--
--   RobuxText.Mark        U+E002, the character Roblox's fonts draw as the Robux icon, in the text's own colour and
--                         about its cap height (the same value as Products.RobuxMark; RebirthRules / PadRules use it).
--   RobuxText.commas(n)   '1,499' (the reference's thousands separators); a non-number comes back as text.
--   RobuxText.fmt(n)      Mark .. commas(n): '\u{E002}1,499'. For any TextLabel showing a Robux price.
--   RobuxText.icon(parent, props)
--                         the drawn Robux icon (UIKit's Robux mark: the uploaded art/icons3d/Robux.png tinted, the
--                         frame-built hexagon until it loads) for UI rows that lay the icon and the number out
--                         themselves (Kit.only, Kit.robuxButton). props: Size (px, default 20), Color, Position,
--                         AnchorPoint, ZIndex, LayoutOrder, Inner, Core, Edge. Returns the icon's holder Frame.
--
-- Cash prices never use this: they keep the Cash icon / the word Cash.
local Products = require(script.Parent.Config.Products)

local RobuxText = {}

RobuxText.Mark = Products.RobuxMark or utf8.char(0xE002)

function RobuxText.commas(n: any): string
	if type(n) ~= 'number' then
		local v = tonumber(n)
		if v == nil then return tostring(n or '') end
		n = v
	end
	local neg = n < 0
	local s = tostring(math.floor(math.abs(n) + 0.5))
	local out = s:reverse():gsub('(%d%d%d)', '%1,'):reverse():gsub('^,', '')
	return (neg and '-' or '') .. out
end

function RobuxText.fmt(n: any): string
	return RobuxText.Mark .. RobuxText.commas(n)
end

function RobuxText.icon(parent: Instance?, props: { [string]: any }?): Frame
	local p = props or {}
	local Kit = require(script.Parent.UIKit) -- (late: UIKit is client art; the rules modules only use fmt)
	local holder = Kit.robux(p.Size or 20, {
		Color = p.Color, Position = p.Position, AnchorPoint = p.AnchorPoint, ZIndex = p.ZIndex, LayoutOrder = p.LayoutOrder,
		Inner = p.Inner, Core = p.Core, Edge = p.Edge,
	})
	if p.Name then holder.Name = p.Name end
	if parent then holder.Parent = parent end
	return holder
end

return RobuxText

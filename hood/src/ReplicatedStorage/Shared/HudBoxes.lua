-- HudBoxes (Oct 28: "no HUD element may sit on another"): the boxes of the HUD's shown buttons on the screen, so the
-- things drawn over or under the HUD can keep clear of them: the world's floating words fade out under them
-- (HoodClient/LabelFade, LabelFade.underHud) and the guide's edge pointer slides off them (HoodClient/GoalGuide,
-- GuideArrow.clearOf).
-- A button is a shown child of one of HoodHUD's Root blocks (the Spin wheel's slot, the Shop column's buttons, the
-- counters' rows, the offer cards, the bottom bar's parts, the right column's slots); an empty slot is not one.
-- Boxes are in screen pixels from the top-left of the whole screen (Roblox's top bar included), padded by `pad`.
local GuiService = game:GetService('GuiService')

local HudBoxes = {}

local function shown(g)
	if not (g:IsA('GuiObject') and g.Visible) then return false end
	if g:IsA('TextLabel') or g:IsA('TextButton') then return g.TextTransparency < 0.9 or g.BackgroundTransparency < 0.9 end
	if g:IsA('ImageLabel') or g:IsA('ImageButton') then return g.ImageTransparency < 0.9 or g.BackgroundTransparency < 0.9 end
	if g.BackgroundTransparency < 0.9 then return true end
	for _, c in g:GetChildren() do -- (a frame: a button's body, a slot holding a picture; not an empty slot)
		if c:IsA('GuiObject') and c.Visible then return true end
	end
	return false
end

-- { { x0, y0, x1, y1 }, ... } (y down), or {} when the HUD isn't up.
function HudBoxes.get(playerGui, pad)
	pad = pad or 0
	local out = {}
	local hud = playerGui and playerGui:FindFirstChild('HoodHUD')
	local root = hud and hud.Enabled and hud:FindFirstChild('Root')
	if not (root and root:IsA('GuiObject') and root.Visible) then return out end
	local top = 0
	if not hud.IgnoreGuiInset then
		local okI, inset = pcall(function() return GuiService:GetGuiInset() end)
		top = okI and typeof(inset) == 'Vector2' and inset.Y or 0
	end
	for _, block in root:GetChildren() do
		if block:IsA('GuiObject') and block.Visible then
			for _, b in block:GetChildren() do
				if shown(b) then
					local pos, size = b.AbsolutePosition, b.AbsoluteSize
					if size.X > 2 and size.Y > 2 then
						table.insert(out, { x0 = pos.X - pad, y0 = pos.Y + top - pad, x1 = pos.X + size.X + pad, y1 = pos.Y + top + size.Y + pad })
					end
				end
			end
		end
	end
	return out
end

return HudBoxes

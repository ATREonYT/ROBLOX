-- The visible pity counters on screen (brief 30, PITY). Client-side pieces, kept out of Shoes.client so that screen only
-- calls them (the rules are Shared/PityRules; the server enforces the guarantee and keeps the ShoePity attribute these read):
--   PityUI.paint(label, boxId, player?)     sets a label to "Epic+ guaranteed in 7 opens" (lime on "...on your next open!")
--   PityUI.keyLine(panel) -> label          the line under the price of the E / R / T key panel (named 'PityLine'): moves the
--                                           panel's Card* children down and grows the panel to make room
--   PityUI.boardTab(gui, panel, boxId, player?) -> label   the tab hanging under a box's chances board (a BillboardGui and its
--                                           board frame): grows the gui by the tab's height, the board stays where it was
--   PityUI.revealTag(info, root, opts)      a small GUARANTEED! tag for the unboxing moment when the open was the guaranteed one
--                                           ("GUARANTEED x2!" when a batch had two): opts.job = the cinematic's job (timed by its
--                                           plan: the name's beat to the close), or opts.from / opts.to / opts.now (a clock in
--                                           seconds) for the 2D moment; opts.reduced = Reduced Motion (no pop)
--   PityUI.guaranteedCount(info) -> n       how many opens of a ShoeOpened payload were guaranteed
-- Any label named 'PityLine' can be painted with PityUI.paint: the box screens use the same call.
local Players = game:GetService('Players')
local RunService = game:GetService('RunService')

local Kit = require(script.Parent.UIKit)
local Pity = require(script.Parent.PityRules)
local Shoes = require(script.Parent.Config.Shoes)

local PityUI = {}

local okFonts, Fonts = pcall(require, script.Parent.Fonts)
local function title()
	return okFonts and type(Fonts) == 'table' and Fonts.Title or Kit.Font.display
end

PityUI.Count = Shoes.RarityById[Pity.rarityName()] and Shoes.RarityById[Pity.rarityName()].Color or Kit.hex('A64DFF')
PityUI.CountText = PityUI.Count:Lerp(Kit.Color.white, 0.4) -- (the line's colour while it counts down)
PityUI.NextText = Kit.hex('7CFF4F') -- (the next open is the guaranteed one)
PityUI.Gold = Kit.hex('FFC800') -- (the GUARANTEED! tag)
PityUI.TabHeight = 0.9 -- studs the odds board's tab hangs below the board

local function me(player)
	return player or Players.LocalPlayer
end

-- Opens left for this box, from the player's ShoePity attribute (the server's counter).
function PityUI.remaining(boxId, player)
	local p = me(player)
	return Pity.remaining(p and p:GetAttribute('ShoePity'), boxId)
end

function PityUI.paint(label, boxId, player)
	if not label then return end
	local left = PityUI.remaining(boxId, player)
	local text = Pity.boxLine(left)
	if label.Text ~= text then label.Text = text end
	label.TextColor3 = left <= 1 and PityUI.NextText or PityUI.CountText
end

-- A pity label; `props` over the defaults (Name 'PityLine').
local function line(props)
	props.Name = props.Name or 'PityLine'
	props.FontFace = props.FontFace or title()
	props.TextColor3 = props.TextColor3 or PityUI.CountText
	props.Stroke = props.Stroke or Kit.Color.ink
	return Kit.text(props)
end

function PityUI.keyLine(panel)
	local H = 26
	local price = panel:FindFirstChild('Price')
	local y = price and (price.Position.Y.Offset + price.Size.Y.Offset) or 80
	local label = line({ TextSize = 19, StrokeThickness = 4, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, y), Size = UDim2.fromOffset(470, H), Parent = panel })
	for _, c in panel:GetChildren() do
		if c ~= label and string.sub(c.Name, 1, 4) == 'Card' and c:IsA('GuiObject') then
			c.Position = c.Position + UDim2.fromOffset(0, H)
		end
	end
	panel.Size = panel.Size + UDim2.fromOffset(0, H)
	return label
end

function PityUI.boardTab(gui, panel, boxId, player)
	local H = PityUI.TabHeight
	local total = gui.Size.Y.Scale
	gui.Size = UDim2.fromScale(gui.Size.X.Scale, total + H)
	gui.StudsOffsetWorldSpace = gui.StudsOffsetWorldSpace - Vector3.new(0, H / 2, 0) -- (the board itself stays where it was)
	panel.Size = UDim2.fromScale(1, total / (total + H))
	local tab = Kit.new('Frame', { Name = 'Pity', BackgroundColor3 = Kit.Color.asphalt, BackgroundTransparency = 0.12, BorderSizePixel = 0, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, total / (total + H) - 0.012), Size = UDim2.fromScale(0.62, (H - 0.06) / (total + H)), Parent = gui })
	Kit.corner(UDim.new(0.5, 0)).Parent = tab
	Kit.stroke(Kit.Color.ink, 3, true).Parent = tab
	local label = line({ TextSize = 18, StrokeThickness = 3.5, Position = UDim2.fromScale(0.04, 0.08), Size = UDim2.fromScale(0.92, 0.84), ZIndex = 3, Parent = tab })
	label.TextScaled = true
	PityUI.paint(label, boxId, player)
	-- (it follows the counter while the board is up; it lets go with the board)
	local p = me(player)
	local okSignal, conn = pcall(function() return p:GetAttributeChangedSignal('ShoePity'):Connect(function() PityUI.paint(label, boxId, p) end) end)
	if okSignal and conn then
		local function release() conn:Disconnect() end
		local ok = pcall(function() tab.Destroying:Connect(release) end)
		if not ok then pcall(function() tab.AncestryChanged:Connect(function() if not tab:IsDescendantOf(game) then release() end end) end) end
	end
	return label
end

function PityUI.guaranteedCount(info)
	local n = 0
	if type(info) ~= 'table' then return 0 end
	if type(info.Shoes) == 'table' and #info.Shoes > 0 then
		for _, e in info.Shoes do
			if type(e) == 'table' and e.Guaranteed == true then n += 1 end
		end
	elseif info.Guaranteed == true then
		n = 1
	end
	return n
end

local function c01(x) return math.clamp(x, 0, 1) end
local function backOut(t)
	t = c01(t)
	local c = 1.70158
	return 1 + (c + 1) * (t - 1) ^ 3 + c * (t - 1) ^ 2
end

function PityUI.revealTag(info, root, opts)
	opts = opts or {}
	local n = PityUI.guaranteedCount(info)
	if n == 0 or not root then return nil end
	local from, to, now, finished = tonumber(opts.from) or 0, tonumber(opts.to), opts.now, function() return false end
	local job = opts.job
	if job then
		if job.Failed then return nil end
		local plan = job.Plan or {}
		from, to = tonumber(plan.nameT) or tonumber(plan.tap) or 3, tonumber(plan.out)
		now = function() return job.T or 0 end
		finished = function() return job.Done == true end
	end
	if type(now) ~= 'function' then return nil end
	local tag = Kit.text({ Name = 'GuaranteedTag', Text = n > 1 and ('GUARANTEED x' .. n .. '!') or 'GUARANTEED!', FontFace = title(), TextSize = 34, TextColor3 = PityUI.Gold, Stroke = Kit.Color.black, StrokeThickness = 5, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0, 52), Size = UDim2.fromOffset(460, 44), ZIndex = 34, Parent = root })
	local scale = Kit.new('UIScale', { Scale = 1, Parent = tag })
	local stroke = tag:FindFirstChildOfClass('UIStroke')
	local conn
	local function fade(a)
		tag.TextTransparency = a
		if stroke then stroke.Transparency = a end
	end
	local function stop()
		if conn then conn:Disconnect() conn = nil end
		if tag.Parent then tag:Destroy() end
	end
	fade(1)
	conn = RunService.PreRender:Connect(function()
		if not tag.Parent or not root.Parent or finished() then return stop() end
		local t = now()
		if to and t >= to then return stop() end
		local u = (t - from) / 0.3
		fade(u <= 0 and 1 or 1 - math.min(c01(u * 3), c01(((to or math.huge) - t) / 0.12)))
		scale.Scale = opts.reduced and 1 or (0.5 + 0.5 * backOut(u))
	end)
	return tag
end

return PityUI

-- The Shop's look for every menu (owner, Oct 20 14:25: "make our ui shop and in general make it like that"; Oct 21:
-- "restyle the shops so they have animations for the ui"): the chunky FredokaOne letters with a dark outline for
-- titles, names, buttons and numbers (lines you read stay Gotham, as in the Shop), chunky studded buttons, and the
-- cards popping in one after another when a menu opens. Screens/Shop is the golden slice; this is its toolbox.
-- ModalManager calls ShopStyle.restyle on every window it registers (once, plus anything added to it later) and
-- ShopStyle.popIn on every open. The round HUD isn't a menu and keeps Huss Valley's Gotham.
local UI = script.Parent
local Theme = require(UI.Theme)
local Kit = require(UI.Kit)
local Motion = require(UI.Motion)

local new = Kit.new
local WHITE = Color3.new(1, 1, 1)

local ShopStyle = {}

ShopStyle.FONT = Font.new("rbxasset://fonts/families/FredokaOne.json")
ShopStyle.INK = Color3.fromHex("101418") -- the dark outline round every chunky word
ShopStyle.STUDS = 0.42 -- a chunky button's studs (Kit's buttons are 0.22)
ShopStyle.POP = { From = 0.8, Time = 0.32, Max = 24 } -- a card's pop-in: from 80 %, with a small overshoot

-- White chunky words with the dark outline.
function ShopStyle.chunky(props: { [string]: any }, stroke: number?): TextLabel
	props.FontFace = props.FontFace or ShopStyle.FONT
	props.TextWrapped = false
	props.TextXAlignment = props.TextXAlignment or Enum.TextXAlignment.Center
	local l = Kit.text(props)
	new("UIStroke", { Name = "Outline", Color = ShopStyle.INK, Thickness = stroke or 2, LineJoinMode = Enum.LineJoinMode.Round, Parent = l })
	return l
end

-- A Kit button in the Shop's look: chunky label with a solid dark outline, clearly studded.
function ShopStyle.chunkyButton(b)
	local label = b.Instance:FindFirstChild("Label", true)
	if label and label:IsA("TextLabel") then
		label.FontFace = ShopStyle.FONT
		local o = label:FindFirstChild("Outline")
		if o and o:IsA("UIStroke") then o.Color, o.Thickness, o.Transparency, o.Enabled = ShopStyle.INK, 2, 0, true end
	end
	local studs = b.Instance:FindFirstChild("StudPattern")
	if studs and studs:IsA("ImageLabel") then studs.ImageTransparency = 1 - ShopStyle.STUDS end
	return b
end

-- A button look from three colours (fill, its lit top, its rim): white text.
function ShopStyle.look(fill: Color3, top: Color3, rim: Color3)
	return { Idle = fill, Hover = fill:Lerp(WHITE, 0.1), Pressed = fill:Lerp(Color3.new(0, 0, 0), 0.1), Text = WHITE, Top = top, Rim = rim }
end

-- The Shop's buttons, for every menu: green to buy or go, purple for Robux, blue for Aura, orange for Halloween.
local C = Theme.Colors
Kit.Styles.ShopGreen = ShopStyle.look(C.SelectedTab, C.SelectedTabTop, C.SelectedRim)
Kit.Styles.ShopPurple = ShopStyle.look(C.Action, C.ActionTop, C.ActionRim)
Kit.Styles.ShopAura = ShopStyle.look(Color3.fromHex("2A9FD8"), Color3.fromHex("8AD8FA"), Color3.fromHex("08304A"))
Kit.Styles.ShopOrange = ShopStyle.look(Color3.fromHex("E8661A"), Color3.fromHex("FFB36B"), Color3.fromHex("3E1405"))

-- Gotham Bold and Heavy (titles, names, tabs, buttons, numbers) become the chunky letters; Medium (lines you read)
-- stays. An outline that is there gets the Shop's dark ink. Nothing marked ShopStyleKeep (a measured picture-for-
-- picture layout) changes.
local function chunkyFont(t: Instance)
	if not (t:IsA("TextLabel") or t:IsA("TextButton") or t:IsA("TextBox")) then return end
	local f = (t :: any).FontFace
	if not f or not string.find(f.Family, "Gotham", 1, true) then return end
	if f.Weight ~= Enum.FontWeight.Bold and f.Weight ~= Enum.FontWeight.Heavy and f.Weight ~= Enum.FontWeight.ExtraBold then return end
	local x = t
	while x do
		if x:GetAttribute("ShopStyleKeep") then return end
		x = x.Parent
	end
	;(t :: any).FontFace = ShopStyle.FONT
	local o = t:FindFirstChild("Outline")
	if o and o:IsA("UIStroke") and o.Color ~= ShopStyle.INK then o.Color = ShopStyle.INK end
end

-- Puts a whole window in the Shop's look, and whatever is added to it later.
local styled: { [Instance]: boolean } = {}
function ShopStyle.restyle(root: Instance)
	if styled[root] then return end
	styled[root] = true
	for _, d in root:GetDescendants() do chunkyFont(d) end
	pcall(function()
		root.DescendantAdded:Connect(function(d)
			chunkyFont(d)
			task.defer(chunkyFont, d) -- (its font is often set right after it's parented)
		end)
	end)
end

-- What pops in when a menu opens: its rows and cards (a framed box, a rounded corner, at least 40 x 24), in reading
-- order, inside its body, on screen; at most POP.Max.
function ShopStyle.cards(window: GuiObject?): { GuiObject }
	local found = {}
	if not window then return found end
	local function walk(x: Instance, depth: number)
		for _, c in x:GetChildren() do
			if c:IsA("GuiObject") and c.Visible then
				local okBox, box = pcall(function() return c.AbsoluteSize end)
				if not okBox then box = Vector2.new(c.Size.X.Offset, c.Size.Y.Offset) end
				local framed = c:FindFirstChildOfClass("UICorner") ~= nil and (c:IsA("Frame") or c:IsA("TextButton") or c:IsA("ImageButton"))
				if framed and box.X >= 40 and box.Y >= 24 and c.Name ~= "Fill" and c.Name ~= "Header" and c.Name ~= "Panel" then
					table.insert(found, c)
				elseif depth < 4 then
					walk(c, depth + 1)
				end
			end
		end
	end
	walk(window, 0)
	local function at(g: GuiObject): Vector2
		local ok, p = pcall(function() return g.AbsolutePosition end)
		return if ok then p else Vector2.new(g.Position.X.Offset, g.Position.Y.Offset)
	end
	table.sort(found, function(a, b)
		local pa, pb = at(a), at(b)
		if math.abs(pa.Y - pb.Y) > 8 then return pa.Y < pb.Y end
		return pa.X < pb.X
	end)
	local out = {}
	for i = 1, math.min(#found, ShopStyle.POP.Max) do out[i] = found[i] end
	return out
end

-- The cards pop in one after another (Theme.Motion.Stagger apart). Reduced Motion: they just show. (A card's
-- PopScale is made at run time, like a picture's stand-in: never saved into StarterGui.)
function ShopStyle.popIn(items: { GuiObject })
	if Motion.reduced then return end
	for i, item in items do
		local s = item:FindFirstChild("PopScale")
		if not s then
			if item:FindFirstChildOfClass("UIScale") then continue end -- (it has its own scale: leave it be)
			s = new("UIScale", { Name = "PopScale", Parent = item })
		end
		s.Scale = ShopStyle.POP.From
		task.delay((i - 1) * Theme.Motion.Stagger, function()
			if s.Parent then Motion.tween(s, "pop", ShopStyle.POP.Time, { Scale = 1 }, Enum.EasingStyle.Back) end
		end)
	end
end

return ShopStyle

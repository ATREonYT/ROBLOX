--!nonstrict
-- New Game Kit: export the saved HUD (src/StarterGui/KitHUD.rbxm) to JSON for render.html.
-- Usage (from the kit folder): lune run tools/preview/export.luau <out.json> [Panel]
--   Panel = Shop / Eggs / Pets / Upgrades / Rebirth / Gifts / Codes / Settings / Popup (opens it with sample rows)
-- Then: node tools/preview/shoot.js <out.json> <out.png> 1280 720   (Playwright; NODE_PATH=$(npm root -g))
-- The exporter is copied from huzz-valley/tools/preview/harness.luau (exportUI).
local fs = require("@lune/fs")
local process = require("@lune/process")
local roblox = require("@lune/roblox")
local serde = require("@lune/serde")
local Color3, Enum = roblox.Color3, roblox.Enum

local function exportUI(result, OUT)
	local function rgb(c) return { c.R, c.G, c.B } end
	local UDim, UDim2, Vector2, ColorSequence, NumberSequence = roblox.UDim, roblox.UDim2, roblox.Vector2, roblox.ColorSequence, roblox.NumberSequence
	local function get(inst, prop, default)
		local ok, v = pcall(function() return inst[prop] end)
		if ok and v ~= nil then return v end
		return default
	end
	local function udim(u) return { u.Scale, u.Offset } end
	local function udim2(u) return { u.X.Scale, u.X.Offset, u.Y.Scale, u.Y.Offset } end
	local function seqColor(cs) local t = {}; for _, k in cs.Keypoints do table.insert(t, { k.Time, k.Value.R, k.Value.G, k.Value.B }) end; return t end
	local function seqNum(ns) local t = {}; for _, k in ns.Keypoints do table.insert(t, { k.Time, k.Value }) end; return t end
	local function gradient(g)
		local off = get(g, "Offset", Vector2.new(0, 0))
		return { c = seqColor(get(g, "Color", ColorSequence.new(Color3.new(1, 1, 1)))), tr = seqNum(get(g, "Transparency", NumberSequence.new(0))), rot = get(g, "Rotation", 0), off = { off.X, off.Y }, on = get(g, "Enabled", true) }
	end
	local function fontOf(inst)
		local okEnum, enumName = pcall(function() return inst.Font.Name end)
		local okFace, family, weight = pcall(function() return inst.FontFace.Family, inst.FontFace.Weight.Name, inst.FontFace.Style.Name end)
		local okStyle, style = pcall(function() return inst.FontFace.Style.Name end)
		-- Lune keeps Font and FontFace apart (Roblox syncs them); whichever the code set is readable.
		if okEnum then return { enum = enumName } end
		if okFace then return { family = family, weight = weight, style = okStyle and style or "Normal" } end
		return { enum = "SourceSans" }
	end
	local function node(inst)
		local n = { c = inst.ClassName, n = inst.Name, kids = {}, mods = {} }
		local okA, attrs = pcall(function() return inst:GetAttributes() end)
		if okA and next(attrs) then
			n.attrs = {}
			for k, v in attrs do if type(v) ~= "userdata" then n.attrs[k] = v end end -- (JSON can't hold UDim2 etc.)
		end
		if inst:IsA("GuiObject") then
			n.pos = udim2(get(inst, "Position", UDim2.new())); n.size = udim2(get(inst, "Size", UDim2.new()))
			local a = get(inst, "AnchorPoint", Vector2.new()); n.anchor = { a.X, a.Y }
			n.bg = rgb(get(inst, "BackgroundColor3", Color3.new(1, 1, 1))); n.bgT = get(inst, "BackgroundTransparency", 0)
			n.vis = get(inst, "Visible", true); n.z = get(inst, "ZIndex", 1); n.order = get(inst, "LayoutOrder", 0)
			n.rot = get(inst, "Rotation", 0); n.clip = get(inst, "ClipsDescendants", false)
			n.auto = get(inst, "AutomaticSize", Enum.AutomaticSize.None).Name
			if inst:IsA("CanvasGroup") then n.groupT = get(inst, "GroupTransparency", 0) end
			if inst:IsA("TextLabel") or inst:IsA("TextButton") or inst:IsA("TextBox") then
				n.text = {
					t = get(inst, "Text", ""), color = rgb(get(inst, "TextColor3", Color3.new(0, 0, 0))), size = get(inst, "TextSize", 14),
					scaled = get(inst, "TextScaled", false), wrap = get(inst, "TextWrapped", false), rich = get(inst, "RichText", false),
					xa = get(inst, "TextXAlignment", Enum.TextXAlignment.Center).Name, ya = get(inst, "TextYAlignment", Enum.TextYAlignment.Center).Name,
					tT = get(inst, "TextTransparency", 0), sC = rgb(get(inst, "TextStrokeColor3", Color3.new(0, 0, 0))), sT = get(inst, "TextStrokeTransparency", 1),
					lh = get(inst, "LineHeight", 1), font = fontOf(inst),
					trunc = get(inst, "TextTruncate", Enum.TextTruncate.None).Name,
				}
			end
			if inst:IsA("ImageLabel") or inst:IsA("ImageButton") then
				local r = get(inst, "SliceCenter", nil)
				n.img = { id = get(inst, "Image", ""), color = rgb(get(inst, "ImageColor3", Color3.new(1, 1, 1))), t = get(inst, "ImageTransparency", 0), st = get(inst, "ScaleType", Enum.ScaleType.Stretch).Name, tile = udim2(get(inst, "TileSize", UDim2.fromScale(1, 1))) }
			end
		else
			n.insets = get(inst, "ScreenInsets", Enum.ScreenInsets.CoreUISafeInsets).Name
			n.ignoreInset = get(inst, "IgnoreGuiInset", false); n.enabled = get(inst, "Enabled", true)
		end
		for _, ch in inst:GetChildren() do
			local cls = ch.ClassName
			if cls == "UICorner" then n.mods.corner = udim(get(ch, "CornerRadius", nil) or (ch:GetAttribute("HuzzRadius")) or get(ch, "TopLeftRadius", UDim.new(0, 8)))
			elseif cls == "UIStroke" then
				local g = ch:FindFirstChildOfClass("UIGradient")
				n.mods.stroke = { c = rgb(get(ch, "Color", Color3.new())), t = get(ch, "Transparency", 0), th = get(ch, "Thickness", 1), mode = get(ch, "ApplyStrokeMode", Enum.ApplyStrokeMode.Contextual).Name, on = get(ch, "Enabled", true), grad = g and gradient(g) or nil }
			elseif cls == "UIGradient" then n.mods.grad = gradient(ch)
			elseif cls == "UIPadding" then n.mods.pad = { udim(get(ch, "PaddingLeft", UDim.new())), udim(get(ch, "PaddingRight", UDim.new())), udim(get(ch, "PaddingTop", UDim.new())), udim(get(ch, "PaddingBottom", UDim.new())) }
			elseif cls == "UIListLayout" then
				n.mods.list = { dir = get(ch, "FillDirection", Enum.FillDirection.Vertical).Name, pad = udim(get(ch, "Padding", UDim.new())), h = get(ch, "HorizontalAlignment", Enum.HorizontalAlignment.Left).Name, v = get(ch, "VerticalAlignment", Enum.VerticalAlignment.Top).Name, sort = get(ch, "SortOrder", Enum.SortOrder.Name).Name }
			elseif cls == "UIGridLayout" then
				n.mods.grid = { cell = udim2(get(ch, "CellSize", UDim2.fromOffset(100, 100))), pad = udim2(get(ch, "CellPadding", UDim2.fromOffset(5, 5))), dir = get(ch, "FillDirection", Enum.FillDirection.Horizontal).Name, h = get(ch, "HorizontalAlignment", Enum.HorizontalAlignment.Left).Name, v = get(ch, "VerticalAlignment", Enum.VerticalAlignment.Top).Name, sort = get(ch, "SortOrder", Enum.SortOrder.Name).Name, max = get(ch, "FillDirectionMaxCells", 0) }
			elseif cls == "UIAspectRatioConstraint" then n.mods.aspect = { r = get(ch, "AspectRatio", 1), type = get(ch, "AspectType", Enum.AspectType.FitWithinMaxSize).Name, dom = get(ch, "DominantAxis", Enum.DominantAxis.Width).Name }
			elseif cls == "UIScale" then n.mods.scale = get(ch, "Scale", 1)
			elseif cls == "UISizeConstraint" then local mn, mx = get(ch, "MinSize", Vector2.new()), get(ch, "MaxSize", Vector2.new(math.huge, math.huge)); n.mods.sizeLimit = { mn.X, mn.Y, mx.X == math.huge and 1e9 or mx.X, mx.Y == math.huge and 1e9 or mx.Y }
			elseif cls == "UITextSizeConstraint" then n.mods.textLimit = { get(ch, "MinTextSize", 1), get(ch, "MaxTextSize", 100) }
			elseif ch:IsA("GuiObject") then table.insert(n.kids, node(ch))
			elseif cls == "Folder" then for _, sub in ch:GetChildren() do if sub:IsA("GuiObject") then table.insert(n.kids, node(sub)) end end -- (Roblox draws GUI inside Folders)
			end
		end
		return n
	end
	fs.writeFile(OUT, serde.encode("json", node(result)))
end

local OUT, PANEL = process.args[1], process.args[2]
local hud = roblox.deserializeModel(fs.readFile("src/StarterGui/KitHUD.rbxm"))[1]
local SAMPLES = {
	Shop = { { "SpeedPotion", "250 Coins", "Buy" }, { "DoubleCoins", "R$ 199", "Buy" }, { "Gems100", "R$ 49", "Buy" }, { "StarterPack", "R$ 99", "Buy" } },
	Eggs = { { "Basic Egg", "100 Coins", "Hatch" }, { "   Dog", "Common: 37.5%" }, { "   Bunny", "Rare: 22%" }, { "   Fox", "Legendary: 3%" } },
	Pets = { { "Boost x1.60", "Index: 3/6 pets found" }, { "Dog", "+10% coins", "Unequip" }, { "Fox", "+50% coins", "Equip" } },
	Upgrades = { { "More Coins/s  Lv 3", "123 Coins", "Buy" }, { "Coin Boost  Lv 0", "200 Coins", "Buy" }, { "Walk Speed  Lv 20", "MAX" } },
	Gifts = { { "Daily reward (day 2)", "200 Coins", "Claim" }, { "Gift 1", "Claimed" }, { "Gift 2", "3:12", "Claim" } },
	Settings = { { "Flashes", "On", "Turn off" }, { "Music", "On", "Turn off" }, { "LowGraphics", "Off", "Turn on" } },
}
if PANEL then
	local target = if PANEL == "Popup" then hud.Popup else hud.Panels[PANEL]
	target.Visible = true
	if PANEL == "Popup" then
		target.Body.Message.Text = "You earned 3.6K coins while you were away (1:00:00)."
	elseif PANEL == "Rebirth" then
		target.Body.Info.Text = "Costs 10K Coins.\nYour coins reset, your pets stay.\nBoost x1 -> x1.25"
	end
	local list = target:FindFirstChild("Body") and target.Body:FindFirstChild("List")
	for i, sample in SAMPLES[PANEL] or {} do
		local row = list.RowTemplate:Clone()
		row.Name = "Row"
		row.LayoutOrder = i
		row.Visible = true
		row.Title.Text = sample[1]
		row.Sub.Text = sample[2]
		if sample[3] then
			row.Action.Face.Label.Text = sample[3]
		else
			row.Action.Visible = false
		end
		row.Parent = list
	end
end
hud.TopBar.Coins.Amount.Text = "12.5K"
hud.TopBar.Gems.Amount.Text = "105"
hud.TopBar.Rebirths.Amount.Text = "1"
exportUI(hud, OUT)
print("[preview] wrote", OUT)

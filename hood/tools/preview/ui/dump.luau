-- dump.luau: walks a ScreenGui (or any GuiObject) to JSON for the offline UI renderer (ui/index.html). Not a script on
-- its own: shoot.sh puts it in front of a scenario snippet run by the Lune harness (tools/checks/harness_live.luau),
-- which provides __fs and __serde. Defines the global __uiDump(gui, path) (all in one do-block: the chunk it joins is
-- close to Luau's 200-locals limit).
--
-- Per node: c (class), n (name), pos / size (UDim2 as {xs, xo, ys, yo}), anchor, bg, bgT, vis, z, order, rot, clip,
-- auto (AutomaticSize), groupT (CanvasGroup), canvas (ScrollingFrame CanvasPosition), text {...}, img {...},
-- attrs (PreviewImage / IconId / Flat / Bare), mods (UICorner, UIStroke, UIGradient, UIPadding, UIListLayout,
-- UIGridLayout, UIAspectRatioConstraint, UIScale, UISizeConstraint, UITextSizeConstraint) and kids.
-- The ScreenGui itself: insets, ignoreInset, enabled, order (DisplayOrder), zib (ZIndexBehavior).
do
local function get(inst, prop, default)
	local ok, v = pcall(function() return inst[prop] end)
	if ok and v ~= nil then return v end
	return default
end
local function rgb(c) return { c.R, c.G, c.B } end
local function udim(u) return { u.Scale, u.Offset } end
local function udim2(u) return { u.X.Scale, u.X.Offset, u.Y.Scale, u.Y.Offset } end
local function enumName(v, default)
	if typeof(v) == 'EnumItem' then return v.Name end
	return default
end
local function gradient(g)
	local cs = get(g, 'Color', nil)
	local ns = get(g, 'Transparency', nil)
	local c, t = {}, {}
	if cs then for _, k in cs.Keypoints do table.insert(c, { k.Time, k.Value.R, k.Value.G, k.Value.B }) end end
	if ns then for _, k in ns.Keypoints do table.insert(t, { k.Time, k.Value }) end end
	local off = get(g, 'Offset', Vector2.new(0, 0))
	return { c = c, tr = t, rot = get(g, 'Rotation', 0), off = { off.X, off.Y }, on = get(g, 'Enabled', true) }
end
local function fontOf(inst)
	local okF, face = pcall(function() return inst.FontFace end)
	if okF and face then
		local okA, fam = pcall(function() return face.Family end)
		local okW, w = pcall(function() return face.Weight.Name end)
		local okS, st = pcall(function() return face.Style.Name end)
		if okA and fam then return { family = fam, weight = okW and w or 'Regular', style = okS and st or 'Normal' } end
	end
	local okE, e = pcall(function() return inst.Font.Name end)
	if okE then return { enum = e } end
	return { enum = 'SourceSans' }
end
local KEEP = { PreviewImage = true, IconId = true, Flat = true, Bare = true, PreviewT = true }
local function node(inst)
	local n = { c = inst.ClassName, n = inst.Name, kids = {}, mods = {} }
	local okA, attrs = pcall(function() return inst:GetAttributes() end)
	if okA then
		for k, v in attrs do
			if KEEP[k] then n.attrs = n.attrs or {}; n.attrs[k] = v end
		end
	end
	if inst:IsA('GuiObject') then
		n.pos = udim2(get(inst, 'Position', UDim2.new()))
		n.size = udim2(get(inst, 'Size', UDim2.new()))
		local a = get(inst, 'AnchorPoint', Vector2.zero)
		n.anchor = { a.X, a.Y }
		n.bg = rgb(get(inst, 'BackgroundColor3', Color3.new(1, 1, 1)))
		n.bgT = get(inst, 'BackgroundTransparency', 0)
		n.vis = get(inst, 'Visible', true)
		n.z = get(inst, 'ZIndex', 1)
		n.order = get(inst, 'LayoutOrder', 0)
		n.rot = get(inst, 'Rotation', 0)
		n.clip = get(inst, 'ClipsDescendants', false) or inst:IsA('ScrollingFrame')
		n.auto = enumName(get(inst, 'AutomaticSize', nil), 'None')
		if inst:IsA('CanvasGroup') then n.groupT = get(inst, 'GroupTransparency', 0) end
		if inst:IsA('ScrollingFrame') then
			local cp = get(inst, 'CanvasPosition', Vector2.zero)
			n.canvas = { cp.X, cp.Y }
		end
		if inst:IsA('TextLabel') or inst:IsA('TextButton') or inst:IsA('TextBox') then
			n.text = {
				t = get(inst, 'Text', ''), color = rgb(get(inst, 'TextColor3', Color3.new(0, 0, 0))), size = get(inst, 'TextSize', 14),
				scaled = get(inst, 'TextScaled', false), wrap = get(inst, 'TextWrapped', false), rich = get(inst, 'RichText', false),
				xa = enumName(get(inst, 'TextXAlignment', nil), 'Center'), ya = enumName(get(inst, 'TextYAlignment', nil), 'Center'),
				tT = get(inst, 'TextTransparency', 0), sC = rgb(get(inst, 'TextStrokeColor3', Color3.new(0, 0, 0))), sT = get(inst, 'TextStrokeTransparency', 1),
				lh = get(inst, 'LineHeight', 1), font = fontOf(inst),
			}
			if inst:IsA('TextBox') then
				n.text.ph = get(inst, 'PlaceholderText', '')
				n.text.phColor = rgb(get(inst, 'PlaceholderColor3', Color3.new(0.7, 0.7, 0.7)))
			end
		end
		if inst:IsA('ImageLabel') or inst:IsA('ImageButton') then
			local ts = get(inst, 'TileSize', UDim2.fromScale(1, 1))
			n.img = {
				id = get(inst, 'Image', ''), color = rgb(get(inst, 'ImageColor3', Color3.new(1, 1, 1))), t = get(inst, 'ImageTransparency', 0),
				scale = enumName(get(inst, 'ScaleType', nil), 'Stretch'), tile = udim2(ts),
			}
		end
	else
		n.insets = enumName(get(inst, 'ScreenInsets', nil), 'CoreUISafeInsets')
		n.ignoreInset = get(inst, 'IgnoreGuiInset', false)
		n.enabled = get(inst, 'Enabled', true)
		n.order = get(inst, 'DisplayOrder', 0)
		n.zib = enumName(get(inst, 'ZIndexBehavior', nil), 'Sibling')
	end
	for _, ch in inst:GetChildren() do
		local cls = ch.ClassName
		if cls == 'UICorner' then
			n.mods.corner = udim(get(ch, 'CornerRadius', UDim.new(0, 8)))
		elseif cls == 'UIStroke' then
			local g = ch:FindFirstChildOfClass('UIGradient')
			n.mods.stroke = { c = rgb(get(ch, 'Color', Color3.new())), t = get(ch, 'Transparency', 0), th = get(ch, 'Thickness', 1), mode = enumName(get(ch, 'ApplyStrokeMode', nil), 'Contextual'), on = get(ch, 'Enabled', true), grad = g and gradient(g) or nil }
		elseif cls == 'UIGradient' then
			n.mods.grad = gradient(ch)
		elseif cls == 'UIPadding' then
			n.mods.pad = { udim(get(ch, 'PaddingLeft', UDim.new())), udim(get(ch, 'PaddingRight', UDim.new())), udim(get(ch, 'PaddingTop', UDim.new())), udim(get(ch, 'PaddingBottom', UDim.new())) }
		elseif cls == 'UIListLayout' then
			n.mods.list = { dir = enumName(get(ch, 'FillDirection', nil), 'Vertical'), pad = udim(get(ch, 'Padding', UDim.new())), h = enumName(get(ch, 'HorizontalAlignment', nil), 'Left'), v = enumName(get(ch, 'VerticalAlignment', nil), 'Top'), sort = enumName(get(ch, 'SortOrder', nil), 'LayoutOrder'), wraps = get(ch, 'Wraps', false) }
		elseif cls == 'UIGridLayout' then
			n.mods.grid = { cell = udim2(get(ch, 'CellSize', UDim2.fromOffset(100, 100))), pad = udim2(get(ch, 'CellPadding', UDim2.fromOffset(5, 5))), dir = enumName(get(ch, 'FillDirection', nil), 'Horizontal'), h = enumName(get(ch, 'HorizontalAlignment', nil), 'Left'), v = enumName(get(ch, 'VerticalAlignment', nil), 'Top'), sort = enumName(get(ch, 'SortOrder', nil), 'LayoutOrder'), max = get(ch, 'FillDirectionMaxCells', 0) }
		elseif cls == 'UIAspectRatioConstraint' then
			n.mods.aspect = { r = get(ch, 'AspectRatio', 1), type = enumName(get(ch, 'AspectType', nil), 'FitWithinMaxSize'), dom = enumName(get(ch, 'DominantAxis', nil), 'Width') }
		elseif cls == 'UIScale' then
			n.mods.scale = get(ch, 'Scale', 1)
		elseif cls == 'UISizeConstraint' then
			local mn, mx = get(ch, 'MinSize', Vector2.zero), get(ch, 'MaxSize', Vector2.new(math.huge, math.huge))
			n.mods.sizeLimit = { mn.X, mn.Y, mx.X == math.huge and 1e9 or mx.X, mx.Y == math.huge and 1e9 or mx.Y }
		elseif cls == 'UITextSizeConstraint' then
			n.mods.textLimit = { get(ch, 'MinTextSize', 1), get(ch, 'MaxTextSize', 100) }
		elseif ch:IsA('GuiObject') then
			table.insert(n.kids, node(ch))
		end
	end
	return n
end
__uiDump = function(gui, path)
	__fs.writeFile(path, __serde.encode('json', node(gui)))
end
end

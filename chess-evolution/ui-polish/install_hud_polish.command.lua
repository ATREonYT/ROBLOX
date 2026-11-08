local s=game.StarterPlayer.StarterPlayerScripts.ChessEvolutionHUD
local src=s.Source
local function cut(a,bm)
  local i=string.find(src,a,1,true); assert(i,"missing "..a)
  local j=string.find(src,bm,i,true); assert(j,"missing "..bm)
  return i,j
end
local B=[==[local BACK = TweenInfo.new(0.28, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
-- Press feel (Alex's brief, Nov 8): the whole button (plate, icon, label) squashes to 95 % in 70 ms and
-- springs back with a tiny overshoot. The plate, icon and label are separate layers in the kit, so
-- they move together inside one "<Name>_Press" frame. The real button stays still and keeps
-- the hit area (its own art is redrawn by the "Art" layer inside the press frame).
local PRESS_DOWN = TweenInfo.new(0.07, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local PRESS_UP = TweenInfo.new(0.22, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
local HOVER = TweenInfo.new(0.12, Enum.EasingStyle.Sine, Enum.EasingDirection.Out)
local function pressGroup(b: GuiButton): UIScale
	local parent = b.Parent :: Instance
	local existing = parent:FindFirstChild(b.Name .. "_Press")
	if existing then
		return existing:FindFirstChild("Press") :: UIScale
	end
	local holder = Instance.new("Frame")
	holder.Name = b.Name .. "_Press"
	holder.BackgroundTransparency = 1
	-- scale about the middle (vault: LihFolk "UI and GUI Animation", zoom from the middle)
	holder.AnchorPoint = Vector2.new(0.5, 0.5)
	holder.Position = UDim2.new(
		b.Position.X.Scale + (0.5 - b.AnchorPoint.X) * b.Size.X.Scale, b.Position.X.Offset + math.round((0.5 - b.AnchorPoint.X) * b.Size.X.Offset),
		b.Position.Y.Scale + (0.5 - b.AnchorPoint.Y) * b.Size.Y.Scale, b.Position.Y.Offset + math.round((0.5 - b.AnchorPoint.Y) * b.Size.Y.Offset))
	holder.Size = b.Size
	holder.ZIndex = b.ZIndex
	holder.Visible = b.Visible
	local scale = Instance.new("UIScale")
	scale.Name = "Press"
	scale.Parent = holder
	if b:IsA("ImageButton") and b.Image ~= "" then
		local art = Instance.new("ImageLabel")
		art.Name = "Art"
		art.BackgroundTransparency = 1
		art.Size = UDim2.fromScale(1, 1)
		art.Image = b.Image
		art.ImageColor3 = b.ImageColor3
		art.ScaleType = b.ScaleType
		art.SliceCenter = b.SliceCenter
		art.SliceScale = b.SliceScale
		art.ImageTransparency = b.ImageTransparency
		art.ZIndex = b.ZIndex
		art.Parent = holder
		b.ImageTransparency = 1
		b:GetPropertyChangedSignal("Image"):Connect(function()
			art.Image = b.Image
		end)
		b:GetPropertyChangedSignal("ImageColor3"):Connect(function()
			art.ImageColor3 = b.ImageColor3
		end)
	end
	-- the button's own children (icons, glyphs) move into the press frame too
	for _, c in b:GetChildren() do
		if c:IsA("GuiObject") then
			c.Parent = holder
		end
	end
	-- sibling layers: <Name>_Icon, <Name>_Label, <Name>_Label_Live, <Name>Glyph
	local bx, by = b.Position.X.Scale - b.AnchorPoint.X * b.Size.X.Scale, b.Position.Y.Scale - b.AnchorPoint.Y * b.Size.Y.Scale
	local bw, bh = b.Size.X.Scale, b.Size.Y.Scale
	for _, c in parent:GetChildren() do
		if c ~= b and c:IsA("GuiObject") and (string.sub(c.Name, 1, #b.Name + 1) == b.Name .. "_" or c.Name == b.Name .. "Glyph") and c.Name ~= holder.Name then
			if bw > 0 and bh > 0 and c.Position.X.Offset == 0 and c.Size.X.Offset == 0 then
				c.Position = UDim2.fromScale((c.Position.X.Scale - bx) / bw, (c.Position.Y.Scale - by) / bh)
				c.Size = UDim2.fromScale(c.Size.X.Scale / bw, c.Size.Y.Scale / bh)
				c.Parent = holder
			end
		end
	end
	b:GetPropertyChangedSignal("Visible"):Connect(function()
		holder.Visible = b.Visible
	end)
	local top = b.ZIndex
	for _, d in holder:GetChildren() do
		if d:IsA("GuiObject") then
			top = math.max(top, d.ZIndex)
		end
	end
	holder.ZIndex = top
	holder.Parent = parent
	return scale
end
local function button(screen: Instance, name: string, fn: () -> ())
	local b = screen:FindFirstChild(name, true)
	if not b or not b:IsA("GuiButton") then
		warn(`[ChessUI] no button {screen.Name}.{name}`)
		return
	end
	local ok, scale = pcall(pressGroup, b)
	if not ok then
		warn(`[ChessUI] press group {name}: {scale}`)
		scale = Instance.new("UIScale")
		scale.Name = "Press"
		scale.Parent = b
	end
	local hovering, held = false, false
	local function rest()
		return if hovering then 1.04 else 1
	end
	local function isPress(input: InputObject): boolean
		return input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch
	end
	b.InputBegan:Connect(function(input: InputObject)
		if isPress(input) then
			held = true
			TweenService:Create(scale, PRESS_DOWN, { Scale = 0.95 }):Play()
		end
	end)
	b.InputEnded:Connect(function(input: InputObject)
		-- also runs for a cancelled touch or a press dragged off the button
		if isPress(input) and held then
			held = false
			TweenService:Create(scale, PRESS_UP, { Scale = rest() }):Play()
		end
	end)
	b.Activated:Connect(function()
		-- a panel that is closing takes no more presses (vault 08 "UI and GUI Animation": a closing menu stops eating input)
		if screen:GetAttribute("Closing") then
			return
		end
		held = false
		TweenService:Create(scale, PRESS_UP, { Scale = rest() }):Play()
		local fnOk, err = pcall(fn)
		if not fnOk then
			warn(`[ChessUI] {screen.Name}.{name}: {err}`)
		end
	end)
	b.MouseEnter:Connect(function()
		hovering = true
		if not held then
			TweenService:Create(scale, HOVER, { Scale = 1.04 }):Play()
		end
	end)
	b.MouseLeave:Connect(function()
		hovering = false
		held = false
		TweenService:Create(scale, HOVER, { Scale = 1 }):Play()
	end)
end
]==]
local SC=[==[-- Open: fade in and grow from 96 % to 100 % in 0.2 s. Close: quicker (0.12 s), then hidden for real,
-- so a closed panel never leaves an invisible layer that eats taps (Alex's brief, Nov 8).
local OPEN_INFO = TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local CLOSE_INFO = TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
local fadeToken: { [Instance]: number } = {}
local FADE_PROPS = { ImageLabel = "ImageTransparency", ImageButton = "ImageTransparency", TextLabel = "TextTransparency", TextButton = "TextTransparency", UIStroke = "Transparency", ViewportFrame = "ImageTransparency" }
-- every layer remembers its resting transparency once, so a fade can always go back to it
local function fadeTargets(f: Instance): { { Instance | string | number } }
	local list = {}
	for _, d in f:GetDescendants() do
		local prop = FADE_PROPS[d.ClassName]
		if prop then
			local base = d:GetAttribute("FadeBase")
			if base == nil then
				base = (d :: any)[prop]
				d:SetAttribute("FadeBase", base)
			end
			-- the real buttons are see-through hit areas; the glyph text hides its TextLabel
			if base < 1 then
				table.insert(list, { d, prop, base })
			end
		end
	end
	return list
end
local function fade(f: Instance, info: TweenInfo, show: boolean)
	for _, t in fadeTargets(f) do
		local d, prop, base = t[1] :: Instance, t[2] :: string, t[3] :: number
		if show then
			(d :: any)[prop] = 1
		end
		TweenService:Create(d, info, { [prop] = if show then base else 1 }):Play()
	end
end
local function close()
	if not openName then
		return
	end
	local f = screen(openName)
	openName = nil
	local token = (fadeToken[f] or 0) + 1
	fadeToken[f] = token
	f:SetAttribute("Closing", true)
	local pop = f:WaitForChild("Pop") :: UIScale
	TweenService:Create(pop, CLOSE_INFO, { Scale = 0.96 }):Play()
	fade(f, CLOSE_INFO, false)
	task.delay(CLOSE_INFO.Time, function()
		if fadeToken[f] == token and openName ~= f.Name then
			f.Visible = false
		end
	end)
end
local function open(name: string)
	if S.battle then
		return
	end
	if openName == name then
		return
	end
	if openName then
		local prev = screen(openName)
		fadeToken[prev] = (fadeToken[prev] or 0) + 1
		prev.Visible = false
	end
	OpenPanel:Fire("Close") -- the old panels close when a new screen opens
	openName = name
	local f = screen(name)
	fadeToken[f] = (fadeToken[f] or 0) + 1
	f:SetAttribute("Closing", false)
	refresh() -- fill the text first, so the new glyphs fade in with everything else
	local pop = f:WaitForChild("Pop") :: UIScale
	pop.Scale = 0.96
	f.Visible = true
	TweenService:Create(pop, OPEN_INFO, { Scale = 1 }):Play()
	fade(f, OPEN_INFO, true)
end
]==]
local BR=[==[-- The level bar eases to each new value in 0.15 s and retargets from where it is on fast gains.
-- A level-up fills to the end, then starts again from empty (Alex's brief, Nov 8).
local barShown = Instance.new("NumberValue")
local barLevel: number? = nil
local barTarget = 0
local barRolling = false
local BAR_INFO = TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local function drawBar(v: number)
	bar(HUD:FindFirstChild("ProgressFill", true), 914, 2048, v, 32, 793, 63)
end
barShown.Changed:Connect(function(v)
	local ok, err = pcall(drawBar, v)
	if not ok then
		warn(`[ChessUI] bar: {err}`)
	end
end)
local function smoothBar(p: number, lvl: number)
	barTarget = p
	if barLevel == nil or lvl < barLevel then
		-- first state or a rebirth: no animation backwards
		barLevel = lvl
		barShown.Value = p
		drawBar(p)
		return
	end
	if lvl > barLevel then
		barLevel = lvl
		barRolling = true
		local up = TweenService:Create(barShown, TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Value = 1 })
		up.Completed:Connect(function(state)
			if state ~= Enum.PlaybackState.Completed then
				return
			end
			barRolling = false
			barShown.Value = 0
			TweenService:Create(barShown, BAR_INFO, { Value = barTarget }):Play()
		end)
		up:Play()
		return
	end
	if not barRolling then
		TweenService:Create(barShown, BAR_INFO, { Value = p }):Play()
	end
end
]==]
local TP=[==[
-- A screen tap gets an instant answer on the Elo coin; the number itself only moves on the
-- server's confirmed State. UI taps never count (gameProcessed), same rule as ChessClient.
game:GetService("UserInputService").InputBegan:Connect(function(input: InputObject, gameProcessed: boolean)
	if gameProcessed or openName or S.battle then
		return
	end
	if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then
		return
	end
	bumpScale(HUD:FindFirstChild("PowerIcon", true), 1.15)
end)
]==]
local i,j=cut("local BACK = TweenInfo.new(0.28","-- Toast: one short line")
src=string.sub(src,1,i-1)..B.."\n"..string.sub(src,j)
i,j=cut("local function close()","local function panel(name: string)")
src=string.sub(src,1,i-1)..SC..string.sub(src,j)
local old='\tbar(HUD:FindFirstChild("ProgressFill", true), 914, 2048, prog or 0, 32, 793, 63)'
i=string.find(src,old,1,true); assert(i,"missing bar call")
src=string.sub(src,1,i-1)..'\tsmoothBar(prog or 0, lvl)'..string.sub(src,i+#old)
i=string.find(src,"local function refreshHud()",1,true); assert(i)
src=string.sub(src,1,i-1)..BR..TP.."\n"..string.sub(src,i)
local fn,err=loadstring(src) 
if not fn then return "COMPILE ERROR "..tostring(err) end
game:GetService("ScriptEditorService"):UpdateSourceAsync(s,function() return src end)
return "ok lines="..#string.split(src,"\n")

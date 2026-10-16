-- Fits windows and HUD groups to the screen. Windows are designed in reference px (a 768-wide page); at 1920x1080
-- they render about 1.82x that, matching the 1920 targets in design/specifications/PAGE-POSITIONS.md. Smaller
-- screens shrink them, but never below a readable floor, and never larger than the screen.
-- Workspace attribute "UIPreviewScale" (number) forces one scale everywhere (used by the offline preview).
local Scale = {}

local WINDOW_K = 1920 / 1056 -- reference window px -> 1920 px (1.82, from PAGE-POSITIONS.md)
local HUD_K = 1920 / 768 -- the HUD references are full screens 768 wide

local root: GuiBase2d? = nil

-- The area the UI may use: the ScreenGui's own size (below Roblox's top bar and inside a phone's safe area),
-- or the whole screen before the ScreenGui is known.
local function viewport(): Vector2
	local ok, size = pcall(function() return root and root.AbsoluteSize end) -- (the offline preview may not know it)
	if ok and size and size.X > 0 then return size end
	local cam = workspace.CurrentCamera
	return cam and cam.ViewportSize or Vector2.new(1920, 1080)
end

-- Main calls this with the UI's ScreenGui, so windows fit the space a phone really leaves them.
function Scale.setRoot(gui: GuiBase2d)
	root = gui
end

local function forced(): number?
	local v = workspace:GetAttribute("UIPreviewScale")
	return type(v) == "number" and v or nil
end

function Scale.window(w: number, h: number): number
	local f = forced()
	if f then return f end
	local vp = viewport()
	local screen = math.min(vp.X / 1920, vp.Y / 1080)
	local fit = math.min(vp.X * 0.96 / w, vp.Y * 0.94 / h)
	return math.min(fit, math.max(screen, 0.6) * WINDOW_K)
end

local HUD_SIZE = 0.55 -- the owner asked twice for smaller HUD buttons (1, then 0.72, now 0.55)

function Scale.hud(h: number): number
	local f = forced()
	if f then return f * HUD_SIZE end -- (the preview's 2x page = a 1536-wide screen: the same size as in the game)
	local vp = viewport()
	local screen = math.min(vp.X / 1920, vp.Y / 1080)
	return math.min(math.max(screen, 0.4) * HUD_K * HUD_SIZE, vp.Y / h)
end

-- For things sized in real screen points, like the top bar row that lines up with Roblox's own buttons.
function Scale.points(v: number): number
	return forced() or v
end

-- Keeps a UIScale updated as the screen changes. compute() returns the scale.
function Scale.bind(uiScale: UIScale, compute: () -> number)
	local function update() uiScale.Scale = compute() end
	update()
	local function hook()
		local cam = workspace.CurrentCamera
		if cam then cam:GetPropertyChangedSignal("ViewportSize"):Connect(update) end
	end
	hook()
	if root then root:GetPropertyChangedSignal("AbsoluteSize"):Connect(update) end
	workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function() hook(); update() end)
	workspace:GetAttributeChangedSignal("UIPreviewScale"):Connect(update)
end

return Scale

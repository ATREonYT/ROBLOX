--!strict
-- One look for every "go here / use this" cue (Alex: "make all of the arrows, all of the outlines perfect"):
-- the same warm gold as the HUD's level colour, outline only (no fill tint), never drawn through walls, and one
-- slow breathing pulse shared by every outline so nothing flickers or blinks out of step. Client only.
--   local h = Guide.outline(target, parent?)   a Highlight in the house style (pulses until destroyed)
--   Guide.Color / Guide.Dim                    for other cues (ground arrows, tutorial ring, markers)
local RunService = game:GetService("RunService")

local Theme = require(script.Parent.Theme)

local H = (Theme :: any).HUD or {}

local Guide = {}

Guide.Color = H.Gold or Color3.fromRGB(240, 192, 72)
Guide.Dim = Color3.fromRGB(120, 96, 36)
Guide.PulseHz = 0.7 -- under one pulse a second (Research: Onboarding Funnels)
Guide.OutlineMin = 0.05 -- outline transparency at the bright end of the pulse
Guide.OutlineMax = 0.45

local live: { Highlight } = {}
local loop: RBXScriptConnection? = nil

local function ensureLoop()
	if loop then
		return
	end
	loop = RunService.RenderStepped:Connect(function()
		local w = (math.sin(os.clock() * math.pi * 2 * Guide.PulseHz) + 1) / 2
		local tr = Guide.OutlineMin + (Guide.OutlineMax - Guide.OutlineMin) * w
		for i = #live, 1, -1 do
			local h = live[i]
			if h.Parent then
				h.OutlineTransparency = tr
			else
				table.remove(live, i)
			end
		end
		if #live == 0 and loop then
			loop:Disconnect()
			loop = nil
		end
	end)
end

-- Occluded: the outline shows on the visible edges only, so a shelf behind a wall doesn't glow through it.
-- (A cue for something hidden behind walls belongs to the waypoint marker, not the outline.)
function Guide.outline(target: Instance, parent: Instance?): Highlight
	local h = Instance.new("Highlight")
	h.Name = "MTL_GuideOutline"
	h.FillTransparency = 1
	h.OutlineColor = Guide.Color
	h.OutlineTransparency = Guide.OutlineMin
	h.DepthMode = Enum.HighlightDepthMode.Occluded
	h.Adornee = target
	h.Parent = parent or workspace
	table.insert(live, h)
	ensureLoop()
	return h
end

return Guide

-- [MTL HoodLife] Edit-mode screenshot helper (Command Bar / MCP). Only touches Lighting.ClockTime, and always puts it
-- back. Run order for a slot:
--   1. MODE = "set", HOUR = 14   (saves the original clock on Workspace.MTL_HoodLife, sets the hour)
--   2. tools/PreviewHoodLife.lua with FOCUS = a shot's focus (NIGHT = true for night shots)
--   3. MCP screen_capture from SHOTS[name].cam looking at SHOTS[name].look, save as
--      screens/life/hoodlife_v1_<name>_<day|night>.jpg
--   4. repeat with HOUR = 21
--   5. MODE = "restore" (clock back) and PreviewHoodLife with CLEAR = true
-- MODE = "list" returns the shot table as JSON.
local MODE: string = MODE or "list"
local HOUR: number = HOUR or 14
local L = game:GetService("Lighting")

local SHOTS = {
	spawn = { cam = Vector3.new(-1404, 11, -398), look = Vector3.new(-1442, 5, -350), focus = Vector3.new(-1432, 3, -368) },
	foodmart = { cam = Vector3.new(-1414, 8, -352), look = Vector3.new(-1444, 6, -324), focus = Vector3.new(-1442, 3, -330) },
	sidestreet = { cam = Vector3.new(-1240, 9, -290), look = Vector3.new(-1228, 5, -200), focus = Vector3.new(-1232, 3, -240) },
	corner = { cam = Vector3.new(-1326, 12, -446), look = Vector3.new(-1366, 4, -404), focus = Vector3.new(-1361, 3, -410) },
	park = { cam = Vector3.new(-1546, 16, -244), look = Vector3.new(-1582, 4, -198), focus = Vector3.new(-1580, 3, -200) },
}

local root = workspace:FindFirstChild("MTL_HoodLife")
if MODE == "list" then
	local out = {}
	for k, v in SHOTS do
		out[k] = { cam = { v.cam.X, v.cam.Y, v.cam.Z }, look = { v.look.X, v.look.Y, v.look.Z }, focus = { v.focus.X, v.focus.Y, v.focus.Z } }
	end
	return game:GetService("HttpService"):JSONEncode(out)
elseif MODE == "set" then
	if not root then
		return "run DressHoodLife first"
	end
	if root:GetAttribute("ClockBefore") == nil then
		root:SetAttribute("ClockBefore", L.ClockTime)
	end
	L.ClockTime = HOUR
	return ("clock %.2f (saved %.2f)"):format(L.ClockTime, root:GetAttribute("ClockBefore"))
elseif MODE == "restore" then
	local before = root and root:GetAttribute("ClockBefore")
	if before ~= nil then
		L.ClockTime = before
		root:SetAttribute("ClockBefore", nil)
		return ("clock restored to %.2f"):format(before)
	end
	return "nothing to restore"
end
return "unknown MODE"

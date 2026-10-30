-- The "HAS <HER NAME>" sign over whoever has the girl (owner, Oct 22 12:26; HuzzServer/GirlSign), at the game's sizes:
-- three runners in a row, the left two carrying a girl (Yui in her pink, Aqua in her blue: Config/GirlLooks), the
-- right one without. Each has the name tag the game draws (NameTagService: 5.6 x 2.6 studs, 3 studs over the head),
-- and the sign just over it. Seen from 3/4 front, as a player across the lobby would.
-- sh video.sh girl_sign_scene.luau out.mp4  (one second; take any frame)
local roblox = require("@lune/roblox")
local Vector3, CFrame = roblox.Vector3, roblox.CFrame
local Rig = require("./rig")
local Scene = require("./scene")
local Env = require("./env")
local Looks = Env.load("huzz-valley/src/ReplicatedStorage/Shared/Config/GirlLooks.lua")

local function hex(c) return string.format("#%02x%02x%02x", math.floor(c.R * 255 + 0.5), math.floor(c.G * 255 + 0.5), math.floor(c.B * 255 + 0.5)) end
local WHITE, INK = roblox.Color3.new(1, 1, 1), roblox.Color3.fromRGB(10, 20, 51)
local function look(who)
	for _, l in Looks do if l.Who == who then return l end end
	return nil
end

local scene = Scene.new()
local runners = {
	{ name = "Alex", girl = look("Yui"), shirt = "#3a5bd0", x = -6 },
	{ name = "Sam", girl = look("Aqua"), shirt = "#d04a6a", x = 0 },
	{ name = "Jo", girl = nil, shirt = "#3aa060", x = 6 },
}
local labels = {}
for _, r in runners do
	local rig = scene:addRig(Rig.r15(r.name, { shirt = r.shirt, pants = "#22232c" }))
	rig.root.CFrame = Rig.lookAt(Vector3.new(r.x, Rig.REST_HEIGHT, 0), Vector3.new(r.x, Rig.REST_HEIGHT, 1))
	Rig.fk(rig)
	local head = rig.parts.Head.CFrame.Position
	if r.girl then
		local g = scene:addRig(Rig.r6("Girl" .. r.name, { shirt = hex(r.girl.Colors[1]), pants = hex(r.girl.Colors[2]) }))
		Rig.scale(g, 0.5)
		-- lying across the shoulders, over the head (as CarryMath holds her)
		g.root.CFrame = CFrame.new(head + Vector3.new(0, 0.9, 0)) * CFrame.Angles(0, 0, math.rad(90))
		Rig.fk(g)
	end
	-- the name tag (NameTagService rows: title 0-0.2, name 0.22-0.66, level 0.68-0.86 of 2.6 studs, centred 3.0 up)
	local top = head.Y + 3.0 + 1.3
	table.insert(labels, { p = { r.x, top - 0.1 * 2.6, 0 }, text = "RUNNER", h = 0.36, c = "#6eb8ff", o = hex(INK) })
	table.insert(labels, { p = { r.x, top - 0.44 * 2.6, 0 }, text = r.name, h = 0.82, c = "#ffffff", o = hex(INK) })
	table.insert(labels, { p = { r.x, top - 0.77 * 2.6, 0 }, text = "Lv. 6 · 8 wins", h = 0.3, c = "#cdd2e6", o = hex(INK) })
	if r.girl then
		-- the sign (GirlSign: 4.75 studs over the head, text ~0.6 studs + the pixel floor; her gradient, outline in her deep colour)
		local bright, deep = r.girl.Colors[1], r.girl.Colors[2]
		table.insert(labels, { p = { r.x, head.Y + 4.75, 0 }, text = "HAS " .. string.upper(r.girl.Who), h = 0.62, c = hex(bright),
			g = { hex(bright:Lerp(WHITE, 0.35)), hex(bright), hex(bright:Lerp(deep, 0.55)) }, o = hex(deep:Lerp(INK, 0.6)) })
	end
end
local cam = Vector3.new(-5, 6.5, 17)
for _ = 1, 30 do
	scene:frame(cam, Vector3.new(0, 5.2, 0), { labels = labels, fov = 50 })
end
scene:save(nil, 30, 1280, 720)

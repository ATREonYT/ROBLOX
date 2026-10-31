--[[
	BuildGrandCannon  (run in Studio's Command Bar, Edit mode)

	The big golden cannon on the lobby crag, rebuilt blocky to fit the game (Alex, Oct 31: "render
	the golden cannon better to make it fit the game more, it doesnt fit the style, make it more
	blocky"). It is the blocky Golden cannon (BuildBlockyCannons) in an all-gold palette, scaled up
	9x, on a stepped gold plinth, its barrel along the launch direction. The Secret Shot fires
	from its "Bore" (GameClient.AnimeFX).

	The old smooth mesh nodes are moved to ServerStorage > GrandCannonOriginal, never deleted.
	Undo: run with UNDO = true.
]]

local UNDO = false
local NODES = { "Grand_Cannon_Grand_Cannon_1_Node", "Grand_Cannon_Grand_Cannon_1_2_Node", "Grand_Cannon_Grand_Cannon_2_Node", "Grand_Cannon_Grand_Cannon_2_2_Node" }
local SPOT = Vector3.new(-263, 44.25, 0) -- the top of the crag, under the old cannon

local SS = game:GetService("ServerStorage")
local lobby = workspace.CannonMap["01_Lobby"]
local backup = SS:FindFirstChild("GrandCannonOriginal") or Instance.new("Folder")
backup.Name = "GrandCannonOriginal"
backup.Parent = SS

local old = workspace:FindFirstChild("GrandCannon")
if old then
	old:Destroy()
end
if UNDO then
	for _, n in ipairs(NODES) do
		local m = backup:FindFirstChild(n)
		if m then
			m.Parent = lobby
		end
	end
	print("[BuildGrandCannon] restored the original")
	return
end
for _, n in ipairs(NODES) do
	local m = lobby:FindFirstChild(n)
	if m then
		m.Parent = backup
	end
end

local rgb = Color3.fromRGB
local PAL = {
	Body = rgb(205, 145, 35), BodyTrim = rgb(150, 95, 20), Trail = rgb(185, 125, 30), Cheek = rgb(225, 165, 40),
	Trunnion = rgb(255, 228, 140), Barrel = rgb(255, 205, 50), Ring = rgb(255, 228, 140), MuzzleRing = rgb(255, 214, 70),
	Breech = rgb(235, 175, 40), Knob = rgb(255, 228, 140), Wheel = rgb(170, 110, 25), Rim = rgb(120, 75, 15), Hub = rgb(255, 228, 140),
	Axle = rgb(140, 90, 20), Bore = rgb(60, 30, 10),
}
local m = game.ReplicatedStorage.Cannons.Cannon05_Golden:Clone()
m.Name = "GrandCannon"
for _, p in ipairs(m:GetDescendants()) do
	if p:IsA("BasePart") then
		p.Color = PAL[p.Name] or p.Color
		p.CanCollide = p.Name ~= "Bore"
		p.Material = p.Name == "Gem" and Enum.Material.Neon or Enum.Material.SmoothPlastic
	end
end
local Config = require(game.ReplicatedStorage.GameConfig)
local dir = Config.LAUNCH_DIRECTION.Unit
m:PivotTo(CFrame.lookAt(Vector3.zero, -dir)) -- the barrel's +Z along the launch direction
m:ScaleTo(9)
local cf, size = m:GetBoundingBox()
m:PivotTo(m:GetPivot() + (SPOT + Vector3.new(0, 2.6, 0) - Vector3.new(cf.X, cf.Y - size.Y / 2, cf.Z)))

-- a stepped gold plinth under it
local plinth = Instance.new("Model")
plinth.Name = "Plinth"
for _, s in ipairs({ { 51, 1.6, -0.2, rgb(200, 140, 30) }, { 46, 1.2, 1.4, rgb(255, 205, 50) } }) do
	local p = Instance.new("Part")
	p.Size = Vector3.new(s[1], s[2], s[1] * 0.75)
	p.CFrame = CFrame.new(SPOT.X - 3, SPOT.Y + s[3] + s[2] / 2, SPOT.Z)
	p.Color, p.Material, p.Anchored = s[4], Enum.Material.SmoothPlastic, true
	p.Parent = plinth
end
plinth.Parent = m
m:SetAttribute("Blocky", true)
m.Parent = workspace
print("[BuildGrandCannon] built the blocky Grand Cannon")

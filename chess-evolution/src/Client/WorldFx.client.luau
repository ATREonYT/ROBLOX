--!strict
-- +1 Chess Evolution: idle life for the treadmills (note 23 §2, "alive, but not too crazy").
-- One loop for every lane (§5.6): the neon strips breathe between 80% and 100% brightness,
-- one cycle every 3 s. Lanes more than 150 studs from the camera are skipped.
-- Nothing blinks faster than once a second. The belt scroll stays in ChessClient.
local RunService = game:GetService("RunService")

local map = workspace:WaitForChild("Map")
local PERIOD = 3

type Strip = { part: BasePart, color: Color3 }
local lanes: { { root: BasePart?, strips: { Strip } } } = {}

local function collect()
	table.clear(lanes)
	for _, folder in map:GetDescendants() do
		if folder:IsA("Folder") and folder.Name == "Neon" then
			local model = folder.Parent
			local strips = {}
			for _, p in folder:GetChildren() do
				if p:IsA("BasePart") then
					table.insert(strips, { part = p, color = p.Color })
				end
			end
			table.insert(lanes, { root = model and (model :: any).PrimaryPart, strips = strips })
		end
	end
end
collect()
task.delay(5, collect) -- the map may still be streaming in

local camera = workspace.CurrentCamera
local acc = 0
RunService.Heartbeat:Connect(function(dt)
	acc += dt
	if acc < 1 / 20 then
		return -- 20 updates a second is plenty for a 3 s breath
	end
	acc = 0
	local k = 0.9 + 0.1 * math.sin(os.clock() * 2 * math.pi / PERIOD) -- 0.8 .. 1.0
	local eye = camera.CFrame.Position
	for _, lane in lanes do
		if lane.root and (lane.root.Position - eye).Magnitude > 150 then
			continue
		end
		for _, s in lane.strips do
			s.part.Color = Color3.new(s.color.R * k, s.color.G * k, s.color.B * k)
		end
	end
end)
print("[ChessFx] treadmill neon breathing on " .. #lanes .. " lanes")

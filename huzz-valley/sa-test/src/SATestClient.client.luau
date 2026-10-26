-- SATestClient: your screen's half of the Server Authority test place (huzz-valley/sa-test). Runs the same
-- simulation as the server one step ahead (prediction), sends where the camera looks, and draws what the
-- simulation decided: a red glow on a caught body, one small line of status. Report lines start with [SATest].
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local me = Players.LocalPlayer
local HussSim = require(ReplicatedStorage:WaitForChild("HussSim"))
HussSim.Initialize()

-- the camera's look, as an input the server and every replay see the same (fired on change, kept alive)
local ctx = me:WaitForChild("HussContext")
local cameraDir = ctx:WaitForChild("CameraDir")
local lastFired, sinceFire = Vector3.zero, 0
RunService.RenderStepped:Connect(function(dt)
	local camera = Workspace.CurrentCamera
	if not camera then return end
	local dir = camera.CFrame.LookVector
	sinceFire += dt
	if (dir - lastFired).Magnitude > 0.02 or sinceFire > 0.5 then
		(cameraDir :: any):Fire(dir)
		lastFired, sinceFire = dir, 0
	end
end)

-- how often Roblox had to correct this screen
local rewinds = 0
local okWatch = pcall(function()
	RunService.Misprediction:Connect(function()
		rewinds += 1
	end)
end)
if not okWatch then print("[SATest] this Studio can't count corrections (no RunService.Misprediction)") end

-- one small status line (bottom left; the UI is saved in StarterGui, sa-test/build.luau)
local label = me:WaitForChild("PlayerGui"):WaitForChild("SATest"):WaitForChild("Status")

-- red glow on caught bodies (drawn from the simulation's state, so a rewound catch disappears again)
local glows = {}
local function glowFor(character)
	local h = glows[character]
	if not h or not h.Parent then
		h = Instance.new("Highlight")
		h.FillColor = Color3.fromRGB(255, 60, 60)
		h.OutlineTransparency = 1
		h.Parent = character
		glows[character] = h
	end
	return h
end

local nextReport = os.clock() + 10
RunService.RenderStepped:Connect(function()
	for _, p in Players:GetPlayers() do
		local c = p.Character
		local root = c and c:FindFirstChild("HumanoidRootPart")
		if root then
			local down = (root:GetAttribute("Down") or 0) > 0
			if down or glows[c] then glowFor(c).FillTransparency = if down then 0.45 else 1 end
		end
	end
	for c in glows do
		if not c.Parent then glows[c] = nil end
	end
	local root = me.Character and me.Character:FindFirstChild("HumanoidRootPart")
	local okPing, ping = pcall(function() return me:GetNetworkPing() end)
	local ms = if okPing and type(ping) == "number" then math.floor(ping * 1000 + 0.5) else 0
	local okStatus, status = pcall(function() return root and RunService:GetPredictionStatus(root) end)
	local statusName = if okStatus and status then status.Name else "?"
	local cd = root and root:GetAttribute("Cd") or 0
	label.Text = string.format("Space huss · E dive · %s · ping %d ms · you: %s", if cd > 0 then string.format("ready in %.1f s", cd) else "ready", ms, statusName)
	if os.clock() >= nextReport then
		nextReport = os.clock() + 10
		print(string.format("[SATest] ping %d ms | your body: %s | corrections in the last 10 s: %d", ms, statusName, rewinds))
		rewinds = 0
	end
end)
print("[SATest] your screen is running the simulation too")

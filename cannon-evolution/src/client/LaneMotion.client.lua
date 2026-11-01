--[[
	LaneMotion (client, StarterPlayerScripts): the training lanes' gentle life (Alex, Oct 31: "I want them to look
	like they have life, but also not too crazy at the same time"). One script for every lane (BuildWorld1 marks
	the parts), never more than three moving things a lane, nothing that flashes:
	  - Belt parts: their BeltStuds texture scrolls towards the target, BeltSpeed studs a second;
	  - neon parts marked Breathe: fade between their colour and 80% of it, one slow cycle every BreathePeriod
	    seconds (the Booth's attribute, 2.5 to 3 s);
	  - a Booth's Spin model: turns round its Axis part, one turn every SpinPeriod seconds.
	Lanes more than FAR studs from the camera are left still. Purely visual, on this client only.
]]
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local TAG = "[LaneMotion]"
local FAR = 160

local belts = {} -- { texture, part, speed }
local spins = {} -- { axis, period, parts = { { part, offset } } }

local function breathe(p, period)
	if p:GetAttribute("_Breathing") then
		return
	end
	p:SetAttribute("_Breathing", true)
	local c = p.Color
	local dim = Color3.new(c.R * 0.8, c.G * 0.8, c.B * 0.8)
	local info = TweenInfo.new(period / 2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true)
	TweenService:Create(p, info, { Color = dim }):Play()
end

local function setup(booth)
	if booth:GetAttribute("_LaneMotion") then -- set up already (an attribute: weak tables keyed by Instance lose entries)
		return
	end
	booth:SetAttribute("_LaneMotion", true)
	local period = booth:GetAttribute("BreathePeriod") or 3
	for _, d in ipairs(booth:GetDescendants()) do
		if d:IsA("BasePart") and d:GetAttribute("Breathe") then
			breathe(d, period)
		elseif d:IsA("Texture") and d.Name == "BeltStuds" and d.Parent:IsA("BasePart") then
			table.insert(belts, { tex = d, part = d.Parent, speed = d.Parent:GetAttribute("BeltSpeed") or 2 })
		elseif d:IsA("Model") and d.Name == "Spin" then
			local axis = d:FindFirstChild("Axis")
			if axis then
				local spin = { axis = axis.CFrame, centre = axis.Position, period = d:GetAttribute("SpinPeriod") or 9, parts = {} }
				for _, p in ipairs(d:GetDescendants()) do
					if p:IsA("BasePart") and p ~= axis then
						table.insert(spin.parts, { p, axis.CFrame:ToObjectSpace(p.CFrame) })
					end
				end
				table.insert(spins, spin)
			end
		end
	end
end

local function scan(folder)
	for _, station in ipairs(folder:GetChildren()) do
		local booth = station:FindFirstChild("Booth")
		if booth then
			local ok, err = pcall(setup, booth)
			if not ok then
				warn(TAG, "could not set up", station.Name, err)
			end
		end
	end
end

task.spawn(function()
	local folder = workspace:WaitForChild("TrainingStations", 60)
	if not folder then
		warn(TAG, "no TrainingStations in the workspace; lanes stay still")
		return
	end
	task.wait(1) -- let the lanes arrive
	scan(folder)
	folder.DescendantAdded:Connect(function()
		task.defer(scan, folder)
	end)
	print(TAG, ("%d belts, %d turning props"):format(#belts, #spins))
end)

local t = 0
RunService.RenderStepped:Connect(function(dt)
	t += dt
	local cam = workspace.CurrentCamera
	local eye = cam and cam.CFrame.Position or Vector3.zero
	for i = #belts, 1, -1 do
		local b = belts[i]
		if not b.tex.Parent then
			table.remove(belts, i)
		elseif (b.part.Position - eye).Magnitude < FAR then
			b.tex.OffsetStudsV = (b.tex.OffsetStudsV + b.speed * dt) % b.tex.StudsPerTileV
		end
	end
	for i = #spins, 1, -1 do
		local s = spins[i]
		if not s.parts[1] or not s.parts[1][1].Parent then
			table.remove(spins, i)
		elseif (s.centre - eye).Magnitude < FAR then
			local turn = s.axis * CFrame.Angles(0, 0, (t / s.period) * math.pi * 2)
			for _, entry in ipairs(s.parts) do
				entry[1].CFrame = turn * entry[2]
			end
		end
	end
end)

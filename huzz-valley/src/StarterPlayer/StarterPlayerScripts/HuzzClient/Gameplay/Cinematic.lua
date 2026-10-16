--[[
	The start-of-round camera (owner's call, as in Huss Valley). Everyone in the game sees the same shots,
	timed from the server's Round attributes (Stage, EndsAt, PickAt, PickId, LineCF, LineLength); the shots
	themselves are Shared/CinematicShot (pure, so the offline video films the same thing):
	  Lineup   the camera glides up behind the runners' line and looks across the field.
	  Picking  it swings round to the front of the line and slides along it, showing every runner, while a
	           gold highlight hops from runner to runner, slowing down, and lands on the picked one (the
	           server picked at random; the hops are worked out backwards so every screen lands on them).
	           Then it zooms in on their face and holds while they choose (Screens/HeroChoice).
	  Chosen   a little push in on them while HERO / CHICKEN shows over their head (the name tag).
	Then the camera glides back behind your own character and Roblox's camera takes over.
	Black bars slide in top and bottom while it plays. Players in the lobby keep their own camera.
	Sets the local player attribute "HuzzCinematic" while it plays (ShiftLock lets go of the mouse).
]]
local M = {}

function M.start()
	local Players = game:GetService("Players")
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local RunService = game:GetService("RunService")
	local TweenService = game:GetService("TweenService")
	local Workspace = game:GetService("Workspace")

	local Shared = ReplicatedStorage:WaitForChild("Shared")
	local Net = require(Shared.Net)
	local Config = require(Shared.Config.Round)
	local Shot = require(Shared.CinematicShot)
	local round = Net.get("Round") :: RemoteEvent
	local player = Players.LocalPlayer

	local SHOTS = { Lineup = true, Picking = true, Chosen = true }
	local GOLD = Color3.fromRGB(255, 214, 70)

	-- Letterbox bars.
	local gui = Instance.new("ScreenGui")
	gui.Name = "HuzzCinematic"
	gui.IgnoreGuiInset = true
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 3 -- under the round HUD, so its top message sits on the bar
	local bars = {}
	for i, anchor in { 0, 1 } do
		local f = Instance.new("Frame")
		f.Name = if i == 1 then "Top" else "Bottom"
		f.AnchorPoint = Vector2.new(0, anchor)
		f.Position = UDim2.fromScale(0, anchor)
		f.Size = UDim2.fromScale(1, 0)
		f.BackgroundColor3 = Color3.new(0, 0, 0)
		f.BorderSizePixel = 0
		f.Parent = gui
		bars[i] = f
	end
	gui.Parent = player:WaitForChild("PlayerGui")
	local barsOn = false
	local function setBars(on)
		if on == barsOn then
			return
		end
		barsOn = on
		for _, f in bars do
			TweenService:Create(f, TweenInfo.new(0.45, Enum.EasingStyle.Quint), { Size = UDim2.fromScale(1, if on then 0.085 else 0) }):Play()
		end
	end

	-- Small sounds from Roblox's own library (no uploaded IDs needed; swap in your own any time).
	local function sound(id, volume, pitch)
		local s = Instance.new("Sound")
		s.SoundId = id
		s.Volume = volume
		s.PlaybackSpeed = pitch or 1
		s.Parent = gui
		s:Play()
		s.Ended:Once(function()
			s:Destroy()
		end)
	end

	local function rootOf(p)
		local c = p and p.Character
		return c and c:FindFirstChild("HumanoidRootPart")
	end
	local function headOf(p)
		local c = p and p.Character
		return c and c:FindFirstChild("Head")
	end

	-- The runners on the line, left to right as the camera sees them from the front.
	local function lineRunners(line)
		local list = {}
		for _, p in Players:GetPlayers() do
			local r = rootOf(p)
			if r and p:GetAttribute("HuzzRole") == "Runner" and p:GetAttribute("HuzzStatus") == "Active" then
				table.insert(list, { player = p, x = line:PointToObjectSpace(r.Position).X })
			end
		end
		table.sort(list, function(a, b)
			return a.x > b.x
		end)
		return list
	end

	local highlight = Instance.new("Highlight")
	highlight.Name = "HuzzPickGlow"
	highlight.FillColor = GOLD
	highlight.FillTransparency = 0.55
	highlight.OutlineColor = Color3.new(1, 1, 1)
	highlight.OutlineTransparency = 0
	highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
	highlight.Enabled = false
	highlight.Parent = Workspace.CurrentCamera -- (local only; a Highlight draws from the 3D world)

	local camera = Workspace.CurrentCamera
	local playing = false
	local lastHop = 0
	-- Where the camera is (eye and the point it looks at), and the move from the last shot to this one.
	local eye, look = Vector3.zero, Vector3.zero
	local shotKey, fromEye, fromLook, moveStart = nil, nil, nil, 0
	local function current()
		local cf = camera.CFrame
		return cf.Position, cf.Position + cf.LookVector * 12
	end

	local function finish()
		if not playing then
			return
		end
		playing = false
		highlight.Enabled = false
		highlight.Adornee = nil
		setBars(false)
		-- Glide back behind our own character, then hand the camera back to Roblox.
		local head, root = headOf(player), rootOf(player)
		camera = Workspace.CurrentCamera
		-- Face the way the round runs (across the field), not back at the camera: runners look across, catchers
		-- look at the runners. HuzzCinematic stays on until the glide ends, so shift lock doesn't turn you first.
		local line = round:GetAttribute("LineCF")
		local facing = if typeof(line) ~= "CFrame" then (root and root.CFrame.LookVector or Vector3.zAxis)
			elseif player:GetAttribute("HuzzRole") == "Catcher" then -line.LookVector else line.LookVector
		if not (head and root) then
			camera.CameraType = Enum.CameraType.Custom
			player:SetAttribute("HuzzCinematic", false)
			return
		end
		local startEye, startLook = current()
		local start = os.clock()
		local conn
		conn = RunService.RenderStepped:Connect(function()
			local a = (os.clock() - start) / 0.8
			if playing then
				conn:Disconnect()
				return
			end
			local h = headOf(player)
			if h then
				local goalEye, goalLook = Shot.behind(facing, h.Position)
				local e, l = Shot.transition(startEye, startLook, goalEye, goalLook, math.min(a, 1))
				camera.CFrame = CFrame.lookAt(e, l)
			end
			if a >= 1 then
				conn:Disconnect()
				camera.CameraType = Enum.CameraType.Custom
				player:SetAttribute("HuzzCinematic", false)
			end
		end)
	end

	RunService:BindToRenderStep("HuzzCinematic", Enum.RenderPriority.Camera.Value + 2, function()
		camera = Workspace.CurrentCamera
		local stage = round:GetAttribute("Stage") or ""
		local role = player:GetAttribute("HuzzRole")
		local line = round:GetAttribute("LineCF")
		local want = SHOTS[stage] == true and (role == "Runner" or role == "Catcher") and typeof(line) == "CFrame"
			and player:GetAttribute("MenuOpen") ~= true
		if not want then
			finish()
			return
		end
		if not playing then
			playing = true
			shotKey = nil
			eye, look = current()
			player:SetAttribute("HuzzCinematic", true)
			setBars(true)
		end
		camera.CameraType = Enum.CameraType.Scriptable
		local half = math.clamp((round:GetAttribute("LineLength") or 40) / 2, 8, 40)
		local now = Workspace:GetServerTimeNow()
		local key, toEye, toLook

		if stage == "Lineup" then
			local t = now - (round:GetAttribute("EndsAt") or now) + Config.LineupTime
			key = "Lineup"
			toEye, toLook = Shot.lineup(line, t, Config.LineupTime)
			highlight.Enabled = false
		else
			local t = now - (round:GetAttribute("PickAt") or now)
			local roulette = Config.Pick.Roulette
			local runners = lineRunners(line)
			local picked = Players:GetPlayerByUserId(round:GetAttribute("PickId") or 0)
			local head = headOf(picked)
			if stage == "Picking" and t < roulette and #runners > 0 then
				-- Slide along the front of the line while the highlight hops between runners.
				key = "Sweep"
				toEye, toLook = Shot.sweep(line, half, t, roulette)
				local final = 1
				for i, r in runners do
					if r.player == picked then
						final = i
					end
				end
				local index, n = Shot.hopIndex(t, roulette, #runners, final)
				highlight.Adornee = runners[index].player.Character
				highlight.Enabled = true
				highlight.FillTransparency = 1 -- an outline while it hops (no flashing fill)
				if n ~= lastHop then
					lastHop = n
					sound("rbxasset://sounds/electronicpingshort.wav", 0.22, 0.9 + n * 0.025)
				end
			elseif head then
				-- Zoom in on the picked runner's face (a little closer once they've chosen).
				if lastHop ~= -1 then
					lastHop = -1
					sound("rbxasset://sounds/swoosh.wav", 0.45)
				end
				key = if stage == "Chosen" then "Chosen" else "Face"
				toEye, toLook = Shot.face(line, head.CFrame, stage == "Chosen")
				highlight.Adornee = picked.Character
				highlight.Enabled = true
				highlight.FillTransparency = 0.7 -- landed: a soft gold glow
			else
				key = "Sweep"
				toEye, toLook = Shot.sweep(line, half, 0.5, 1)
			end
		end
		-- A new shot: move over to it (up and over the runners); then the shot itself moves the camera.
		if key ~= shotKey then
			shotKey, fromEye, fromLook, moveStart = key, eye, look, os.clock()
		end
		local a = (os.clock() - moveStart) / Shot.TransitionTime
		if a < 1 then
			eye, look = Shot.transition(fromEye, fromLook, toEye, toLook, a)
		else
			eye, look = toEye, toLook
		end
		camera.CFrame = CFrame.lookAt(eye, look)
	end)
end

return M

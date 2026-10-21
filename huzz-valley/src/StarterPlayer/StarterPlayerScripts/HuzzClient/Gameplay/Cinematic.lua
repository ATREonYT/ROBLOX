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
	Then the camera swings back behind your own character and Roblox's camera takes over.
	Moves between shots are Huss Valley's (docs/feel-study.md gap 4): one quick 0.25 s swing that goes round and over
	the runners (Shot.transition), then the shot holds; the eye is pulled in front of any wall or the floor it would go
	behind (clear(), like Gameplay/SecretReveal's), so it never flies through the map, the runners or you.
	The hand-back lands exactly where Roblox's camera will be (Shot.behind: 12 studs back, 14 degrees down, the
	shift-lock offset only when Gameplay/ShiftLock will really turn on), with the zoom set to 12 for that moment,
	so nothing pops when it takes over. In a round the zoom is capped at 22 (Shot.RoundMaxZoom); the lobby keeps the
	place's own limits (gap 5).
	No black bars (owner: "when the cutscenes happen, the top and bottom of your screen dont cut out"): the
	shots use the whole screen. Players in the lobby keep their own camera.
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
	local GOLD = Color3.fromRGB(255, 255, 255) -- (the pick glow: clean white, owner: no gold)

	local Sfx = require(script.Parent.Sfx)
	local ShiftLock = require(script.Parent.ShiftLock)

	-- The zoom: the place's own limits in the lobby; capped in a round; pinned to RoundZoom for the hand-back.
	local lobbyMin, lobbyMax = player.CameraMinZoomDistance, player.CameraMaxZoomDistance
	local ROUND = { Lineup = true, Picking = true, Chosen = true, HeroRun = true, Countdown = true, Running = true, RoundOver = true }
	local pinned = false -- (the hand-back holds the zoom at RoundZoom for a moment)
	local function setZoom(min, max)
		if player.CameraMinZoomDistance ~= min or player.CameraMaxZoomDistance ~= max then
			pcall(function()
				player.CameraMaxZoomDistance = math.max(max, player.CameraMinZoomDistance)
				player.CameraMinZoomDistance = min
				player.CameraMaxZoomDistance = max
			end)
		end
	end
	local function zoomLimits()
		if pinned then
			return
		end
		local role = player:GetAttribute("HuzzRole")
		local inRound = (role == "Runner" or role == "Catcher") and ROUND[round:GetAttribute("Stage") or ""] == true
		if inRound then
			setZoom(math.min(lobbyMin, Shot.RoundZoom), math.min(lobbyMax, Shot.RoundMaxZoom))
		else
			setZoom(lobbyMin, lobbyMax)
		end
	end

	-- Pull an eye in front of anything solid between it and what it looks at (walls, props, the floor); runners and
	-- see-through or non-solid parts (zone boxes, the safe gate) don't count.
	local rayParams = RaycastParams.new()
	rayParams.FilterType = Enum.RaycastFilterType.Exclude
	local function clear(eye: Vector3, look: Vector3): Vector3
		local v = eye - look
		if v.Magnitude < 0.5 then
			return eye
		end
		local skip = {}
		for _, p in Players:GetPlayers() do
			if p.Character then table.insert(skip, p.Character) end
		end
		local bot = Workspace:FindFirstChild("HuzzBot", true)
		if bot then table.insert(skip, bot) end
		for _ = 1, 6 do
			rayParams.FilterDescendantsInstances = skip
			local ok, hit = pcall(function() return Workspace:Raycast(look, v, rayParams) end)
			if not (ok and hit) then
				return eye
			end
			local part = hit.Instance
			if part:IsA("BasePart") and (not part.CanCollide or part.Transparency > 0.9) then
				table.insert(skip, part) -- (look past it)
			else
				return hit.Position - v.Unit * 1
			end
		end
		return eye
	end
	local function clearY(line)
		return if typeof(line) == "CFrame" then line.Position.Y + 5.5 else nil -- (the runners' heads)
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
	-- (a thin outline and no fill, like Huss Valley's: the old solid rim on top of everything looked loud, feel study
	-- gap 11; white, not HV's yellow: the owner said no gold)
	highlight.FillColor = GOLD
	highlight.FillTransparency = 1
	highlight.OutlineColor = GOLD
	highlight.OutlineTransparency = 0.3
	highlight.DepthMode = Enum.HighlightDepthMode.Occluded
	highlight.Enabled = false
	highlight.Parent = Workspace.CurrentCamera -- (local only; a Highlight draws from the 3D world)

	local camera = Workspace.CurrentCamera
	local playing = false
	local lastHop = 0
	-- Where the camera is (eye and the point it looks at), and the move from the last shot to this one.
	local eye, look = Vector3.zero, Vector3.zero
	local shotKey, fromEye, fromLook, moveStart = nil, nil, nil, 0
	local frozen, chosenAt = nil, nil -- (the face shot's fixed spot for this pick; when Chosen started on this screen)
	local function current()
		local cf = camera.CFrame
		return cf.Position, cf.Position + cf.LookVector * 12
	end

	local function finish()
		if not playing then
			return
		end
		playing = false
		chosenAt = nil
		highlight.Enabled = false
		highlight.Adornee = nil
		-- Swing back behind our own character, then hand the camera back to Roblox.
		local root = rootOf(player)
		camera = Workspace.CurrentCamera
		-- Face the way the round runs (across the field), not back at the camera: runners look across, catchers
		-- look at the runners. HuzzCinematic stays on until the glide ends, so shift lock doesn't turn you first.
		local line = round:GetAttribute("LineCF")
		local facing = if typeof(line) ~= "CFrame" then (root and root.CFrame.LookVector or Vector3.zAxis)
			elseif player:GetAttribute("HuzzRole") == "Catcher" then -line.LookVector else line.LookVector
		if not root then
			camera.CameraType = Enum.CameraType.Custom
			player:SetAttribute("HuzzCinematic", false)
			pinned = false
			zoomLimits()
			return
		end
		-- Shift lock will put the camera over your right shoulder: aim for that spot, but only when it will really be
		-- on (Gameplay/ShiftLock's own test: a round stage, no Alt, no window open, no dance wheel, not on touch).
		-- Read every frame and eased, so pressing Alt mid-swing doesn't jump the camera.
		local function shoulderGoal()
			return if ShiftLock.wouldLock() then ShiftLock.OFFSET.X else 0
		end
		local shoulder = shoulderGoal()
		local flat = Vector3.new(facing.X, 0, facing.Z).Unit
		local right = Vector3.new(-flat.Z, 0, flat.X)
		local startEye, startLook = current()
		local floorY = clearY(line)
		local start = os.clock()
		local handed = 0 -- frames since the swing landed
		pinned = true
		setZoom(Shot.RoundZoom, Shot.RoundZoom) -- (Roblox's camera starts at exactly this distance: no pop)
		local conn
		conn = RunService.RenderStepped:Connect(function()
			if playing then
				conn:Disconnect()
				return
			end
			local a = (os.clock() - start) / Shot.HandBackTime
			local r = rootOf(player)
			if handed < 2 then
				local goal = shoulderGoal()
				shoulder = if a >= 1 then goal else shoulder + (goal - shoulder) * 0.35
			end
			if r and handed < 2 then -- (once Roblox's camera has it, never write over it)
				local focus = r.Position + Vector3.new(0, Shot.FocusHeight, 0) + right * shoulder
				local goalEye, goalLook = Shot.behind(facing, focus)
				local e, l = Shot.transition(startEye, startLook, goalEye, goalLook, math.min(a, 1), floorY)
				if a < 1 then
					e = clear(e, l)
				end
				camera.CFrame = CFrame.lookAt(e, l)
			end
			if a >= 1 then
				-- landed: let shift lock set itself up for a frame while we still hold the view, then hand over
				handed += 1
				if handed == 1 then
					player:SetAttribute("HuzzCinematic", false)
				elseif handed == 2 then
					camera.CameraType = Enum.CameraType.Custom
				elseif handed >= 4 then
					conn:Disconnect()
					pinned = false
					zoomLimits()
				end
			end
		end)
	end

	RunService:BindToRenderStep("HuzzCinematic", Enum.RenderPriority.Camera.Value + 2, function()
		camera = Workspace.CurrentCamera
		zoomLimits()
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
			pinned = true
			setZoom(Shot.RoundZoom, Shot.RoundZoom) -- (already at the round's distance when it hands back)
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
					Sfx.play("roulette_tick", { pitch = 0.92 + math.min(n, 12) * 0.012 })
				end
			elseif head then
				-- Zoom in on the picked runner's face (a little closer once they've chosen).
				if lastHop ~= -1 then
					lastHop = -1
					Sfx.play("pick_land")
				end
				-- Owner, Oct 21 ("when the hero or chicken animation is there, make the camera not be locked onto you
				-- moving with your characters movements, just keep it focused in one place, then zoom in and out"):
				-- the shot is set up once from where they stand when it lands on them (their head, their body's
				-- facing), so their pose, their head following the mouse or a step doesn't drag the camera. Then
				-- it only zooms: in on Chosen (eased over Shot.PushTime), back out on the hand-back.
				local pickAt = round:GetAttribute("PickAt")
				if not frozen or frozen.at ~= pickAt or frozen.id ~= picked.UserId then
					local body = picked.Character and picked.Character:FindFirstChild("HumanoidRootPart")
					local f = if body then body.CFrame.LookVector else head.CFrame.LookVector
					f = Vector3.new(f.X, 0, f.Z)
					f = if f.Magnitude > 0.01 then f.Unit else -line.LookVector
					frozen = { at = pickAt, id = picked.UserId, cf = CFrame.lookAt(head.Position, head.Position + f) }
				end
				key = "Face"
				toEye, toLook = Shot.face(line, frozen.cf, false)
				if stage == "Chosen" then
					chosenAt = chosenAt or os.clock()
					local inEye, inLook = Shot.face(line, frozen.cf, true)
					local x = math.clamp((os.clock() - chosenAt) / Shot.PushTime, 0, 1)
					x = x * x * (3 - 2 * x)
					toEye, toLook = toEye:Lerp(inEye, x), toLook:Lerp(inLook, x)
				else
					chosenAt = nil
				end
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
			eye, look = Shot.transition(fromEye, fromLook, toEye, toLook, a, clearY(line))
			eye = clear(eye, look)
		else
			eye, look = toEye, toLook
		end
		camera.CFrame = CFrame.lookAt(eye, look)
	end)
end

return M

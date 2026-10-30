--[[
	Where your head looks, and telling everyone (owner, Oct 19 19:48: "make the users head move but make it follow
	mouse movements so the head doesnt just stay in one place, make it like the references of huss valley").
	  - aim(root): the way to the point under the mouse (a ray from the camera through the cursor: the first thing it
	    hits past your head, your own body and see-through parts skipped, or 300 studs along it at the sky), as
	    (turn, tilt) from your body: turn + = to your right, tilt + = up, radians. On a touch screen or a gamepad
	    (no cursor) it is the camera's middle, the same as before. A point behind you (you face the camera) is
	    mirrored to the front (LocomotionMix.aimFrom: owner Oct 20 14:07, "it doesnt seem fixed": facing the camera,
	    the cursor is always past you and the head stayed still). Worked out once a frame; Gameplay/Locomotion and Gameplay/PlayerMoves spring the head toward
	    it (Shared/LocomotionMix.look: a neck's reach, Config/Run.Loco.Look).
	  - report(turn, tilt): the head's turn and tilt as your screen draws it this frame (after the spring and the
	    limits). start() sends it to the server (the HeadLook remote) Look.SendRate times a second at most, only when
	    it moved Look.SendStep degrees; HuzzServer/HeadLookService checks it and puts it on your character
	    (HuzzLook = Vector2 degrees), and every other screen springs your head to it (Gameplay/PlayerMoves). Your own
	    head never waits for the network.
]]
local HeadAim = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Run = require(Shared.Config.Run)
local Mix = require(Shared.LocomotionMix)

local LOOK = Run.Loco.Look
local FAR = 300 -- studs along the cursor's ray when it points at the sky
local HEAD = 1.5 -- studs from the root part's middle to the eyes (standard R15)
local NEAR = LOOK.Near or 40 -- studs: the head never aims at a point nearer than this past it (see target)

local params = nil -- (made on first use: the offline test harness has no RaycastParams)

local frameAt, lastTurn, lastTilt = -1, 0, 0
local shownTurn, shownTilt, shownAt = 0, 0, -math.huge

-- Does this screen have a cursor to follow? (a mouse, used last; touch and gamepads use the camera's middle)
local function usesMouse(): boolean
	local ok, kind = pcall(function() return UserInputService:GetLastInputType() end)
	if ok and kind then
		local name = kind.Name
		if name == "Touch" or string.sub(name, 1, 7) == "Gamepad" then
			return false
		end
	end
	return UserInputService.MouseEnabled
end

-- The point your head looks at this frame.
local function target(root: BasePart, cam: Camera): Vector3
	local ray = nil
	if usesMouse() then
		local ok, r = pcall(function()
			local m = UserInputService:GetMouseLocation()
			return cam:ViewportPointToRay(m.X, m.Y)
		end)
		if ok then ray = r end
	end
	local origin = if ray then ray.Origin else cam.CFrame.Position
	local dir = if ray then ray.Direction.Unit else cam.CFrame.LookVector
	if not params then
		params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.IgnoreWater = true
	end
	-- (see-through parts don't stop the look: the maps' zone boxes are invisible but can be hit by rays)
	local skip = { root.Parent :: Instance }
	local from, point = origin, origin + dir * FAR
	for _ = 1, 4 do
		params.FilterDescendantsInstances = skip
		local hit = Workspace:Raycast(from, origin + dir * FAR - from, params)
		if not hit then
			break
		end
		if hit.Instance.Transparency < 0.95 then
			point = hit.Position
			break
		end
		table.insert(skip, hit.Instance)
		from = hit.Position
	end
	-- Never closer than NEAR studs past your head along the ray (owner, Oct 21: "make it perfect so it doesnt seem
	-- weird in little angles"): with the cursor on the floor or a wall just past you, a tiny mouse move swung the head
	-- a long way and it jumped as the cursor crossed an edge. Past NEAR the head looks along the ray, as it does at
	-- the sky; nearer things just pull the point in to NEAR, so it moves smoothly.
	local eyes = root.Position + root.CFrame.UpVector * HEAD
	local depth = (point - origin):Dot(dir)
	local least = (eyes - origin):Dot(dir) + NEAR
	if depth < least then
		point = origin + dir * least
	end
	return point
end

-- (turn, tilt) from your body to where the mouse points; (0, 0) without a camera.
function HeadAim.aim(root: BasePart): (number, number)
	local now = os.clock()
	if now - frameAt < 0.004 then -- (once a frame: Locomotion and PlayerMoves both ask)
		return lastTurn, lastTilt
	end
	frameAt = now
	local cam = Workspace.CurrentCamera
	if not cam then
		lastTurn, lastTilt = 0, 0
		return 0, 0
	end
	local ok, point = pcall(target, root, cam)
	if not ok then
		lastTurn, lastTilt = 0, 0
		return 0, 0
	end
	local eyes = root.Position + root.CFrame.UpVector * HEAD
	-- (a point behind you, the camera in front: mirrored to the front, so the head still follows the cursor's side)
	lastTurn, lastTilt = Mix.aimFrom(root.CFrame:VectorToObjectSpace(point - eyes))
	return lastTurn, lastTilt
end

-- The head as your screen draws it this frame (radians), for the others.
function HeadAim.report(turn: number, tilt: number)
	shownTurn, shownTilt, shownAt = turn, tilt, os.clock()
end

function HeadAim.start()
	local remote = require(Shared.Net).get("HeadLook") :: RemoteEvent
	local sentTurn, sentTilt, sentAt = 0, 0, -math.huge
	RunService.Heartbeat:Connect(function()
		local now = os.clock()
		if now - sentAt < 1 / LOOK.SendRate then
			return
		end
		-- (nothing drawn for a while: the head is straight)
		local turn = if now - shownAt < 0.5 then math.deg(shownTurn) else 0
		local tilt = if now - shownAt < 0.5 then math.deg(shownTilt) else 0
		if math.abs(turn - sentTurn) < LOOK.SendStep and math.abs(tilt - sentTilt) < LOOK.SendStep then
			return
		end
		sentTurn, sentTilt, sentAt = turn, tilt, now
		remote:FireServer(math.floor(turn + 0.5), math.floor(tilt + 0.5))
	end)
end

return HeadAim

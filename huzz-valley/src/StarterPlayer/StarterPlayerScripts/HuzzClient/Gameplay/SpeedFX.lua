--[[
	Running at speed feels intense (owner, Oct 22 13:24: "add some effects when you are running and make it feel more
	intense, let me send you a video and reference it"; his clip: design/owner-oct22/video-1616), on this screen only:
	  - thin white wind streaks curl off the arms and legs of every runner going near flat out (yours and anyone near
	    the camera): short Trails at the hands, elbows, feet and knees, so they follow the limbs' swing like the clip's;
	    only once the body is really running (Config/Run.SpeedFX.RunFrom: never on a walk or the build-up, Oct 23);
	  - a blue glow round the left, right and top of your screen while you sprint (the clip's edges at full speed;
	    none at the bottom, none while walking), easing in and out, never flashing;
	  - the camera widens a little more at full speed (Feel adds Config/Run.SpeedFX.Fov to its sprint widening).
	Tuned in Config/Run.SpeedFX. Off on bodies that are hidden (Gameplay/Hidden), down, or dancing; the glow is off
	with the Reduced Motion setting and while the intro camera has the view.
]]
local M = {}

function M.start()
	local Players = game:GetService("Players")
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local Workspace = game:GetService("Workspace")

	local Run = require(ReplicatedStorage:WaitForChild("Shared").Config.Run)
	local State = require(script.Parent.Parent.UI.State)
	local Frame = require(script.Parent.Frame)
	local Hidden = require(script.Parent.Hidden)

	local FX = Run.SpeedFX
	local player = Players.LocalPlayer
	local NAME = "HuzzSpeedTrail"

	-- Where the streaks come off: a part and a point on it (R6, the game's bodies; R15 too).
	local POINTS_R6 = {
		{ "Right Leg", Vector3.new(0, -0.9, 0) }, { "Left Leg", Vector3.new(0, -0.9, 0) },
		{ "Right Leg", Vector3.new(0, 0, 0.35) }, { "Left Leg", Vector3.new(0, 0, 0.35) },
		{ "Right Arm", Vector3.new(0, -0.9, 0) }, { "Left Arm", Vector3.new(0, -0.9, 0) },
		{ "Right Arm", Vector3.new(0, 0, 0.35) }, { "Left Arm", Vector3.new(0, 0, 0.35) },
	}
	local POINTS_R15 = {
		{ "RightFoot", Vector3.zero }, { "LeftFoot", Vector3.zero },
		{ "RightLowerLeg", Vector3.new(0, 0.4, 0.3) }, { "LeftLowerLeg", Vector3.new(0, 0.4, 0.3) },
		{ "RightHand", Vector3.zero }, { "LeftHand", Vector3.zero },
		{ "RightLowerArm", Vector3.new(0, 0.3, 0.3) }, { "LeftLowerArm", Vector3.new(0, 0.3, 0.3) },
	}

	local function makeTrail(part: BasePart, at: Vector3): Trail
		-- (a Trail is drawn between two attachments: these sit Width apart along the limb, so it's a thin line)
		local a0 = Instance.new("Attachment")
		a0.Name = NAME .. "A"
		a0.Position = at
		a0.Parent = part
		local a1 = Instance.new("Attachment")
		a1.Name = NAME .. "B"
		a1.Position = at + Vector3.new(0, FX.Trails.Width, 0)
		a1.Parent = part
		local t = Instance.new("Trail")
		t.Name = NAME
		t.Attachment0, t.Attachment1 = a0, a1
		t.Color = ColorSequence.new(Color3.new(1, 1, 1))
		t.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, FX.Trails.See), NumberSequenceKeypoint.new(1, 1) })
		t.WidthScale = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(1, 0) })
		t.Lifetime = FX.Trails.Life
		t.MinLength = 0.05
		t.FaceCamera = true
		t.LightEmission = 0.4
		t.LightInfluence = 0
		t.Enabled = false
		t.Parent = part
		return t
	end

	local sets = {} -- Player -> { character, trails, on }
	Players.PlayerRemoving:Connect(function(p) sets[p] = nil end)
	local function trailsFor(p: Player, character: Model)
		local set = sets[p]
		if set and set.character == character then return set end
		if set then
			for _, t in set.trails do t.Enabled = false end
		end
		local r6 = character:FindFirstChild("Torso") ~= nil
		local trails = {}
		for _, pt in (if r6 then POINTS_R6 else POINTS_R15) do
			local part = character:FindFirstChild(pt[1])
			if part and part:IsA("BasePart") then
				local ok, t = pcall(makeTrail, part, pt[2])
				if ok then table.insert(trails, t) end
			end
		end
		set = { character = character, trails = trails, on = false }
		sets[p] = set
		return set
	end
	-- (checked on every trail each frame, not just on a change: PowerEffects switches a hidden body's trails off and
	-- back on as it fades, and that must never leave a streak running on a walking body)
	local function switch(set, on: boolean)
		set.on = on
		for _, t in set.trails do
			if t.Parent and t.Enabled ~= on then t.Enabled = on end
		end
	end

	-- How fast a body goes: 0 at FX.RunFrom (fully into the run), 1 at its top speed; 0 below RunFrom (a walk, the
	-- build-up) and 0 for yours with no key held (a halt still slides at speed).
	local function sprintOf(character: Model, root: BasePart): number
		local v = root.AssemblyLinearVelocity
		local speed = Vector3.new(v.X, 0, v.Z).Magnitude
		local h = character:FindFirstChildOfClass("Humanoid")
		if character == player.Character and (character:GetAttribute("HuzzHalt") == true or (h ~= nil and h.MoveDirection.Magnitude < 0.1)) then
			return 0
		end
		local from = FX.RunFrom or Run.From
		if speed < from then return 0 end
		local cap = (h and h:GetAttribute("HuzzSpeed")) or (h and h.WalkSpeed) or 20
		return math.clamp((speed - from) / math.max(cap - from, 4), 0, 1)
	end

	-- The blue glow: three soft gradients (left, right, top) under the HUD.
	local gui = Instance.new("ScreenGui")
	gui.Name = "HuzzSpeedGlow"
	gui.IgnoreGuiInset = true
	gui.ResetOnSpawn = false
	gui.DisplayOrder = -2 -- (under the HUD, the windows and the heartbeat / danger glows)
	local edges = {}
	local E = FX.Glow.Edge
	for _, e in {
		{ "Left", UDim2.fromScale(0, 0), UDim2.fromScale(E, 1), 0 },
		{ "Right", UDim2.fromScale(1 - E, 0), UDim2.fromScale(E, 1), 180 },
		{ "Top", UDim2.fromScale(0, 0), UDim2.fromScale(1, E * 1.4), 90 },
	} do
		local f = Instance.new("Frame")
		f.Name = e[1]
		f.Position, f.Size = e[2], e[3]
		f.BackgroundColor3 = FX.Glow.Color
		f.BackgroundTransparency = 1
		f.BorderSizePixel = 0
		f.Active = false
		local g = Instance.new("UIGradient")
		g.Rotation = e[4]
		g.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.4, 0.55), NumberSequenceKeypoint.new(1, 1) })
		g.Parent = f
		f.Parent = gui
		table.insert(edges, f)
	end
	gui.Parent = player:WaitForChild("PlayerGui")
	local glow = 0

	Frame.on(6, function(dt)
		dt = math.clamp(dt, 1 / 240, 1 / 15)
		local camera = Workspace.CurrentCamera
		local mine = 0
		for _, p in Players:GetPlayers() do
			local character = p.Character
			local root = character and character:FindFirstChild("HumanoidRootPart")
			local set = sets[p]
			if character and root and root:IsA("BasePart") then
				local h = character:FindFirstChildOfClass("Humanoid")
				local near = p == player or (camera ~= nil and (camera.CFrame.Position - root.Position).Magnitude < FX.Trails.Near)
				local sprint = sprintOf(character, root)
				local blocked = Hidden.gone(character) or character:GetAttribute("DownedAt") ~= nil
					or character:GetAttribute("HuzzDance") ~= nil or (h ~= nil and h.Health <= 0)
				local onGround = math.abs(root.AssemblyLinearVelocity.Y) < 30
				local on = near and not blocked and onGround and sprint >= FX.From
				if on or set then
					set = trailsFor(p, character)
					switch(set, on)
				end
				if p == player and not blocked then
					mine = math.clamp((sprint - FX.From) / (1 - FX.From), 0, 1)
				end
			elseif set then
				switch(set, false)
			end
		end
		local cinematic = player:GetAttribute("HuzzCinematic") == true or (camera ~= nil and camera.CameraType == Enum.CameraType.Scriptable)
		local want = if cinematic or State.setting("ReducedMotion") == true then 0 else mine
		local k = 1 - math.exp(-dt * (if want > glow then 4 else 3)) -- eased both ways: never a pop
		glow += (want - glow) * k
		if glow < 0.005 and want == 0 then glow = 0 end
		for _, f in edges do f.BackgroundTransparency = 1 - glow * FX.Glow.Strength end
		gui.Enabled = glow > 0
	end)
end

return M

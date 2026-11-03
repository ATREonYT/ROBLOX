--!strict
-- Swing doors (Quality pass). Any BasePart tagged "MTL_SwingDoor" is a door leaf placed CLOSED in the world.
-- Attributes on the leaf:
--   Hinge    Vector3  world point on the hinge edge (on the floor line is fine, only X/Z are used)
--   OpenDeg  number   how far it swings (default 95)
-- When the local character comes within Reach of the leaf it swings open, away from the side you are on, and
-- closes again behind you. Client side only: every player sees their own door, so there is nothing to sync, and
-- the leaf has CanCollide off so server NPCs are never blocked by it.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local SwingDoors = {}

local REACH = 7
local SPEED_OPEN = 5.5 -- 1/s: about 0.25 s to fully open
local SPEED_CLOSE = 2.2 -- closes slower, a little drift

type Door = { part: BasePart, closed: CFrame, hinge: Vector3, open: number, angle: number, side: number }
local doors: { [BasePart]: Door } = {}

local function add(p: Instance)
	if not p:IsA("BasePart") or doors[p] then
		return
	end
	local h = p:GetAttribute("Hinge")
	if typeof(h) ~= "Vector3" then
		return
	end
	p.CanCollide = false
	doors[p] = {
		part = p,
		closed = p.CFrame,
		hinge = Vector3.new(h.X, p.Position.Y, h.Z),
		open = math.rad(tonumber(p:GetAttribute("OpenDeg")) or 95),
		angle = 0,
		side = 1,
	}
end

function SwingDoors.init()
	for _, p in CollectionService:GetTagged("MTL_SwingDoor") do
		add(p)
	end
	CollectionService:GetInstanceAddedSignal("MTL_SwingDoor"):Connect(add)
	CollectionService:GetInstanceRemovedSignal("MTL_SwingDoor"):Connect(function(p)
		doors[p :: BasePart] = nil
	end)
	local plr = Players.LocalPlayer
	RunService.Heartbeat:Connect(function(dt)
		local char = plr.Character
		local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
		for p, d in doors do
			if not p.Parent then
				doors[p] = nil
				continue
			end
			local want = 0
			if root then
				local off = root.Position - d.closed.Position
				if off.Magnitude < REACH and math.abs(off.Y) < 6 then
					if d.angle == 0 then
						-- swing away from the player: which side of the closed leaf are they on?
						local n = d.closed.RightVector -- the leaf is thin along its local X
						local sideSign = if off:Dot(n) >= 0 then 1 else -1
						-- a small +angle about Y moves the free edge along Y x (hinge->edge); pick the sign that
						-- carries the leaf away from the player
						local edgeDir = (d.closed.Position - d.hinge) * Vector3.new(1, 0, 1)
						local swingDirPos = Vector3.yAxis:Cross(edgeDir) -- where the edge moves for a small +angle
						d.side = if swingDirPos:Dot(n) * sideSign > 0 then -1 else 1
					end
					want = d.open
				end
			end
			if d.angle ~= want then
				local speed = if want > d.angle then SPEED_OPEN else SPEED_CLOSE
				local step = d.open * speed * dt
				if want > d.angle then
					d.angle = math.min(want, d.angle + step)
				else
					d.angle = math.max(want, d.angle - step)
				end
				-- ease: sine on the 0..1 progress
				local k = d.angle / d.open
				local a = d.open * (0.5 - 0.5 * math.cos(k * math.pi)) * d.side
				local hc = CFrame.new(d.hinge)
				p.CFrame = hc * CFrame.Angles(0, a, 0) * hc:Inverse() * d.closed
			end
		end
	end)
end

return SwingDoors

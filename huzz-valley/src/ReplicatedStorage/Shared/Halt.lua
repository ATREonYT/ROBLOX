--[[
	The halt's push (owner, Oct 20 07:55: "after they randomly stop after fully running they move a little forward
	as a sort of "hault" like in the game Huss valley"). Let go from a full run and the body carries on along the
	ground, slowing from its speed to 0 over Config/Run.Halt.Time (Shared/RunMotion.haltPush / pushSpeed: ~2.3 studs at
	a runner's 28). It moves the real body with a LinearVelocity in the ground plane, like the huss (Gameplay/Dash),
	so walls stop it, gravity still pulls (off an edge it ends: it never pushes you along in the air), the server
	sees where the body really is (HuzzServer/HitHistory, pinpoint hits) and every screen sees the same slide.
	Used by Gameplay/Sprint (your own body, on your screen; the Practice Bot never halts: its stops are a stab breather).
	The legs plant at once while it lasts (Shared/LocomotionMix, input.halt), so it reads as a skid, not a run.
]]
local RunService = game:GetService("RunService")
local RunMotion = require(script.Parent.RunMotion)

local Halt = {}
Halt.NAME = "HuzzHalt"

-- Starts a halt on `root` along `dir` (flat) from `speed` studs/s. `keep()` is asked every frame: false ends it at
-- once (a key pressed, a huss, downed, frozen, off the floor). `onEnd` runs once when it ends, however it ends.
-- Returns a function that ends it early (safe to call more than once).
function Halt.start(root: BasePart, dir: Vector3, speed: number, keep: (() -> boolean)?, onEnd: (() -> ())?): () -> ()
	local flat = Vector3.new(dir.X, 0, dir.Z)
	local ended = false
	if flat.Magnitude < 1e-3 or speed <= 0 then
		if onEnd then onEnd() end
		return function() end
	end
	flat = flat.Unit
	local old = root:FindFirstChild(Halt.NAME)
	if old then
		old:Destroy() -- (an older halt's leftovers: one at a time)
	end
	local cfg = RunMotion.haltPush(speed)
	local attachment = Instance.new("Attachment")
	attachment.Name = Halt.NAME
	local lv = Instance.new("LinearVelocity")
	lv.Name = Halt.NAME
	lv.Attachment0 = attachment
	lv.RelativeTo = Enum.ActuatorRelativeTo.World
	lv.VelocityConstraintMode = Enum.VelocityConstraintMode.Plane
	lv.PrimaryTangentAxis = Vector3.xAxis
	lv.SecondaryTangentAxis = Vector3.zAxis
	lv.MaxForce = 1e6 -- (as the huss: wins over the Humanoid's own braking; walls still stop it)
	lv.Parent = attachment
	local started = os.clock()
	local conn: RBXScriptConnection? = nil
	local function finish()
		if ended then
			return
		end
		ended = true
		if conn then
			conn:Disconnect()
		end
		attachment:Destroy()
		if onEnd then
			onEnd()
		end
	end
	local function set()
		if ended then
			return
		end
		local v = RunMotion.pushSpeed(cfg, os.clock() - started)
		local ok = v ~= nil and root.Parent ~= nil
		if ok and keep then
			local fine, still = pcall(keep)
			ok = fine and still == true
		end
		if not ok then
			finish()
			return
		end
		lv.PlaneVelocity = Vector2.new(flat.X * v, flat.Z * v)
	end
	set()
	if not ended then
		attachment.Parent = root
		conn = RunService.Heartbeat:Connect(set)
	end
	return finish
end

return Halt

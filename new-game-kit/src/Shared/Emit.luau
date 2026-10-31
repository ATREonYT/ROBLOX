--!strict
-- New Game Kit: Emit (play a whole effect from one call; vault note 17 §3)
-- Install: ReplicatedStorage/Kit/Emit (ModuleScript)
-- Effects are templates (a Part or Attachment holding emitters, beams, trails and lights). Each
-- piece carries attributes the owner can tune in Studio's Properties panel, the same names the
-- VFX Forge plugin uses, so effects made there play here too:
--   ParticleEmitter  EmitCount (default 16), EmitDelay (s, default 0), EmitDuration (s: if set, the
--                    emitter is switched on for that long instead of one burst)
--   Beam / Trail     EmitDelay, EmitDuration (switched on for that long; default 0.3 s)
--   PointLight etc.  EmitDelay, EmitDuration (fades Brightness to 0 over it; default 0.12 s)
-- Usage (client):
--   Emit.Play(template:Clone(), CFrame.new(pos))   -- clones are cleaned up when the effect ends
--   Emit.Plan(template)                            -- the timeline as data (tests, previews)
-- Kid-safe and comfort gates live here, so every effect obeys them:
--   Emit.TryFlash()   true at most once per second, and never when Setting_Flashes is off
--   Emit.MotionScale() 0 when reduced motion or Setting_ScreenShake is off, else 1
--   Emit.InRange(pos) false for effects further than 300 studs from the camera (skip them)
-- Status: Plan and the gates are covered by tests/Emit.spec.luau; Play only runs in Studio/Play.

local Emit = {}

Emit.DEFAULT_COUNT = 16
Emit.MAX_DISTANCE = 300
Emit.FLASH_GAP = 1 -- seconds; house rule: at most one flash per second
Emit.Scale = 1 -- lower on weak phones (e.g. 0.5) to cut every burst

export type Step = { instance: Instance, at: number, count: number, duration: number, kind: string }

local function num(inst: Instance, name: string, default: number): number
	local v = inst:GetAttribute(name)
	return if type(v) == "number" then v else default
end

local function prop(inst: Instance, name: string): any
	local ok, v = pcall(function()
		return (inst :: any)[name]
	end)
	return if ok then v else nil
end

local function kindOf(inst: Instance): string?
	if inst:IsA("ParticleEmitter") then
		return "particles"
	elseif inst:IsA("Beam") or inst:IsA("Trail") then
		return "ribbon"
	elseif inst:IsA("Light") then
		return "light"
	end
	return nil
end

-- The effect's timeline, sorted by start time. `life` is when the last piece has finished.
function Emit.Plan(root: Instance): ({ Step }, number)
	local steps: { Step } = {}
	local life = 0
	local list = root:GetDescendants()
	table.insert(list, 1, root)
	for _, inst in list do
		local kind = kindOf(inst)
		if kind then
			local at = math.max(0, num(inst, "EmitDelay", 0))
			local duration, count = 0, 0
			if kind == "particles" then
				duration = math.max(0, num(inst, "EmitDuration", 0))
				count = if duration > 0 then 0 else math.max(0, math.floor(num(inst, "EmitCount", Emit.DEFAULT_COUNT) * Emit.Scale + 0.5))
				local lifetime = prop(inst, "Lifetime")
				local maxLife = if typeof(lifetime) == "NumberRange" then lifetime.Max else 1
				life = math.max(life, at + duration + maxLife)
			elseif kind == "ribbon" then
				duration = math.max(0, num(inst, "EmitDuration", 0.3))
				local trailLife = if inst:IsA("Trail") then prop(inst, "Lifetime") or 0 else 0
				life = math.max(life, at + duration + trailLife)
			else
				duration = math.max(0, num(inst, "EmitDuration", 0.12))
				life = math.max(life, at + duration)
			end
			table.insert(steps, { instance = inst, at = at, count = count, duration = duration, kind = kind })
		end
	end
	table.sort(steps, function(a, b)
		return a.at < b.at
	end)
	return steps, life
end

local function setting(key: string): boolean
	local ok, player = pcall(function()
		return (game:GetService("Players") :: any).LocalPlayer
	end)
	player = ok and player
	if not player then
		return true
	end
	return player:GetAttribute(key) ~= false
end

local lastFlash = -math.huge
function Emit.TryFlash(now: number?): boolean
	local t = now or os.clock()
	if not setting("Setting_Flashes") or t - lastFlash < Emit.FLASH_GAP then
		return false
	end
	lastFlash = t
	return true
end

function Emit.ResetFlash()
	lastFlash = -math.huge
end

function Emit.MotionScale(): number
	local ok, reduced = pcall(function()
		return (game:GetService("GuiService") :: any).ReducedMotionEnabled
	end)
	if (ok and reduced == true) or not setting("Setting_ScreenShake") then
		return 0
	end
	return 1
end

function Emit.InRange(position: Vector3, maxDistance: number?): boolean
	local camera = workspace.CurrentCamera
	if not camera then
		return true
	end
	return (camera.CFrame.Position - position).Magnitude <= (maxDistance or Emit.MAX_DISTANCE)
end

-- Play a template (a clone you own). Parent it at `where` (a CFrame or an Instance to attach to).
-- Returns the total life in seconds; the clone is destroyed after it unless keep is true.
function Emit.Play(effect: Instance, where: (CFrame | Instance)?, keep: boolean?): number
	if typeof(where) == "CFrame" then
		if effect:IsA("BasePart") then
			effect.CFrame = where
			effect.Anchored = true
			effect.CanCollide = false
			effect.CanQuery = false
			effect.Parent = workspace
		end
	elseif typeof(where) == "Instance" then
		effect.Parent = where
	end
	local steps, life = Emit.Plan(effect)
	for _, step in steps do
		local inst = step.instance :: any
		task.delay(step.at, function()
			if not inst.Parent then
				return
			end
			if step.kind == "particles" then
				if step.duration > 0 then
					inst.Enabled = true
					task.delay(step.duration, function()
						inst.Enabled = false
					end)
				elseif step.count > 0 then
					inst:Emit(step.count)
				end
			elseif step.kind == "ribbon" then
				inst.Enabled = true
				task.delay(step.duration, function()
					inst.Enabled = false
				end)
			else
				local TweenService = game:GetService("TweenService")
				local start = inst.Brightness
				inst.Enabled = true
				inst.Brightness = start
				TweenService:Create(inst, TweenInfo.new(step.duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Brightness = 0 }):Play()
			end
		end)
	end
	if not keep then
		task.delay(life + 0.1, function()
			effect:Destroy()
		end)
	end
	return life
end

return Emit

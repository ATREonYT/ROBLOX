-- Shared carry geometry: the server places the girl where the client's arm
-- pose puts the hands, so both read the same config through here.
local Carry = require(script.Parent.Config.Carry)

local CarryMath = {}
local rad, cos = math.rad, math.cos

-- Avatars on Roblox's newer joints use AnimationConstraints (attachments
-- instead of C0/C1). This makes one read and write like a Motor6D.
function CarryMath.joint(item)
	if not item or item.ClassName ~= "AnimationConstraint" then
		return item
	end
	return setmetatable({}, {
		__index = function(_, key)
			if key == "C0" then
				return item.Attachment0.CFrame
			elseif key == "C1" then
				return item.Attachment1.CFrame
			elseif key == "Part0" then
				return item.Attachment0 and item.Attachment0.Parent
			elseif key == "Part1" then
				return item.Attachment1 and item.Attachment1.Parent
			end
			return item[key]
		end,
		__newindex = function(_, key, value)
			item[key] = value
		end,
	})
end

-- Arm, waist and right hip joints of an R15 or R6 character. sign is -1 for the right
-- arm, +1 for the left, so mirrored angles share one formula.
function CarryMath.rig(character)
	local joint = CarryMath.joint
	local torso = character:FindFirstChild("UpperTorso")
	if torso then
		local function side(name, sign)
			local upper = character:FindFirstChild(name .. "UpperArm")
			local lower = character:FindFirstChild(name .. "LowerArm")
			local hand = character:FindFirstChild(name .. "Hand")
			return {
				sign = sign,
				upper = upper,
				hand = hand,
				shoulder = upper and joint(upper:FindFirstChild(name .. "Shoulder")),
				elbow = lower and joint(lower:FindFirstChild(name .. "Elbow")),
				wrist = hand and joint(hand:FindFirstChild(name .. "Wrist")),
			}
		end
		local thigh = character:FindFirstChild("RightUpperLeg")
		return {
			kind = "R15",
			torso = torso,
			head = character:FindFirstChild("Head"),
			waist = joint(torso:FindFirstChild("Waist")),
			arms = { side("Right", -1), side("Left", 1) },
			hip = joint(thigh and thigh:FindFirstChild("RightHip")), -- (his steps: CarryMotion)
		}
	end
	torso = character:FindFirstChild("Torso")
	if torso then
		local function side(name, sign)
			return { sign = sign, upper = character:FindFirstChild(name .. " Arm"), shoulder = joint(torso:FindFirstChild(name .. " Shoulder")) }
		end
		return { kind = "R6", torso = torso, head = character:FindFirstChild("Head"), arms = { side("Right", -1), side("Left", 1) },
			hip = joint(torso:FindFirstChild("Right Hip")) }
	end
	return nil
end

-- Rotations in torso space (x = right, y = up, -z = forward).
function CarryMath.shoulderPose(sign, weight)
	local a = Carry.Arms
	return CFrame.Angles(0, 0, rad(sign * a.Spread * weight)) * CFrame.Angles(rad(a.Raise * weight), 0, 0)
end

function CarryMath.elbowPose(sign, bendDegrees)
	return CFrame.Angles(0, 0, rad(sign * bendDegrees))
end

-- A rotation given in the joint's parent part space, as a Motor6D.Transform.
function CarryMath.inJoint(motor, rotation)
	local c0 = motor.C0.Rotation
	return c0:Inverse() * rotation * c0
end

-- Top of the head (plus room for hair) above the torso centre.
local function headTop(rig)
	local head = rig.head
	local neck = head and CarryMath.joint(head:FindFirstChild("Neck") or rig.torso:FindFirstChild("Neck"))
	if not neck then
		return rig.torso.Size.Y * 0.5 + 1.2
	end
	return neck.C0.Position.Y - neck.C1.Position.Y + head.Size.Y * 0.5 + Carry.HairRoom
end

-- Height of the girl's centre above the torso centre: where the hands reach,
-- but never low enough to sink into the carrier's head.
function CarryMath.holdHeight(rig, girlDepth)
	local a = Carry.Arms
	local tilt = cos(rad(180 - a.Raise))
	local arm = rig.arms[1]
	local shoulderY, reach
	if arm.shoulder and arm.elbow and arm.wrist and arm.hand then
		shoulderY = arm.shoulder.C0.Position.Y
		local upperLen = math.abs(arm.shoulder.C1.Position.Y - arm.elbow.C0.Position.Y)
		local lowerLen = math.abs(arm.elbow.C1.Position.Y - arm.wrist.C0.Position.Y) + arm.hand.Size.Y * 0.5
		reach = upperLen * tilt * cos(rad(a.Spread)) + lowerLen * tilt * cos(rad(a.ElbowBend - a.Spread))
	elseif arm.shoulder and arm.upper then
		shoulderY = arm.shoulder.C0.Position.Y
		reach = arm.upper.Size.Y * 0.8 * tilt
	else
		shoulderY = rig.torso.Size.Y * 0.5
		reach = 1.8
	end
	return math.max(shoulderY + reach - Carry.Sink, headTop(rig)) + girlDepth * 0.5
end

-- Her orientation in torso space: lying across the shoulders, face up.
function CarryMath.holdRotation()
	local head = if Carry.HeadToLeft then Vector3.new(-1, 0, 0) else Vector3.new(1, 0, 0)
	local back = Vector3.new(0, -1, 0)
	local base = CFrame.fromMatrix(Vector3.zero, head:Cross(back), head, back)
	local r = Carry.Rotation
	return CFrame.Angles(rad(r.X), rad(r.Y), rad(r.Z)) * base
end

function CarryMath.holdC0(rig, girlDepth)
	return CFrame.new(0, CarryMath.holdHeight(rig, girlDepth), Carry.Forward) * CarryMath.holdRotation()
end

return CarryMath

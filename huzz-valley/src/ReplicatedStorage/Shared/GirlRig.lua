--[[
	Makes a copy of one of the owner's girls ready to move by hand (GirlService.makeCopy for the carried, follower,
	prize and big showcase girls; Gameplay/Auras for your companion). His models stay as he built them; only the
	copies change:
	  toMotors(model)          Roblox's newer joints (AnimationConstraints, some doubled up, plus BallSockets) become
	                           one plain Motor6D per joint, which every pose in the game moves (Motor6D.Transform).
	  joinAccessories(model)   every hat, hair and face piece is welded to the body part it sits on (her Head for hair),
	                           so it turns with that part.
	Why (owner, Oct 19: "cc's head doesnt move, or in general it looks weird even in the animations"): C.C. (his R15
	Secret) holds her hair, face and hat on with AccessoryRigidConstraints, attachment joints the copies didn't count.
	They looked loose, so they were welded to her ROOT: her head turned under hair that stayed still, and on a
	carried girl the hair floated off her head as her body bent. The R6 girls use Welds to the Head and were fine,
	except one loose piece (Rize) that now goes on the body part it touches.
]]
local GirlRig = {}

local ATTACHMENT_JOINTS = { AccessoryRigidConstraint = true, RigidConstraint = true }

function GirlRig.toMotors(model: Model)
	local done = {}
	for _, d in model:GetDescendants() do
		if d.ClassName == "AnimationConstraint" then
			local a0, a1 = (d :: any).Attachment0, (d :: any).Attachment1
			local part0, part1 = a0 and a0.Parent, a1 and a1.Parent
			if part0 and part1 and part0:IsA("BasePart") and part1:IsA("BasePart") and not done[part1] then
				done[part1] = true
				local motor = Instance.new("Motor6D")
				motor.Name = d.Name
				motor.Part0, motor.Part1 = part0, part1
				motor.C0, motor.C1 = a0.CFrame, a1.CFrame
				motor.Parent = part1
			end
		end
	end
	for _, d in model:GetDescendants() do
		if d.ClassName == "AnimationConstraint" or d:IsA("BallSocketConstraint") or d:IsA("NoCollisionConstraint") then
			d:Destroy()
		end
	end
	-- (Oct 23, C.C.: "make cc's body move normally") If Roblox ever puts its own newer joints back on the copy (an R15
	-- body can rebuild them, e.g. after a resize), a limb would be held twice and the poses on the Motor6D might not
	-- show. Any that come back are removed, and Output says so once ([Huzz] line), so we know if it happens.
	if next(done) then
		pcall(function()
			local told = false
			model.DescendantAdded:Connect(function(d)
				if d.ClassName == "AnimationConstraint" or d:IsA("BallSocketConstraint") then
					task.defer(function()
						if d.Parent then
							d:Destroy()
						end
					end)
					if not told then
						told = true
						print(`[Huzz] {model.Name}: Roblox put its own {d.ClassName} ({d.Name}) back on her; removed so her moves show`)
					end
				end
			end)
		end)
	end
end

-- Body parts: every part not inside an accessory, and not the root (nothing should hang off the root but the body).
local function bodyParts(model)
	local out = {}
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") and d.Name ~= "HumanoidRootPart" and not d:FindFirstAncestorWhichIsA("Accoutrement") then
			table.insert(out, d)
		end
	end
	return out
end

local function weld(body, handle, c0, c1)
	local w = Instance.new("Weld")
	w.Name = "AccessoryWeld"
	w.Part0, w.Part1 = body, handle
	w.C0, w.C1 = c0, c1
	w.Parent = handle
	return w
end

-- Returns how many pieces it joined (for the spec).
function GirlRig.joinAccessories(model: Model): number
	local body = bodyParts(model)
	local isBody = {}
	for _, p in body do
		isBody[p] = true
	end
	local joined = 0
	for _, acc in model:GetDescendants() do
		local handle = acc:IsA("Accoutrement") and acc:FindFirstChild("Handle")
		if handle and handle:IsA("BasePart") then
			-- 1. already welded to the body: keep it; attachment joints (C.C.'s) become a Weld on the same two points
			local held = false
			for _, d in handle:GetDescendants() do
				if (d:IsA("JointInstance") or d:IsA("WeldConstraint")) and (isBody[(d :: any).Part0] or isBody[(d :: any).Part1]) then
					held = true
				end
			end
			for _, d in model:GetDescendants() do
				if ATTACHMENT_JOINTS[d.ClassName] then
					local a0, a1 = (d :: any).Attachment0, (d :: any).Attachment1
					local mine, theirs = nil, nil
					if a0 and a1 and a0.Parent == handle and isBody[a1.Parent] then
						mine, theirs = a0, a1
					elseif a0 and a1 and a1.Parent == handle and isBody[a0.Parent] then
						mine, theirs = a1, a0
					end
					if mine then
						if not held then
							weld(theirs.Parent, handle, theirs.CFrame, mine.CFrame)
							held = true
							joined += 1
						end
						d:Destroy()
					end
				end
			end
			if not held then
				-- 2. no joint: the body attachment with the same name (as Humanoid:AddAccessory does)
				local mine = handle:FindFirstChildWhichIsA("Attachment")
				local theirs = nil
				if mine then
					for _, p in body do
						local a = p:FindFirstChild(mine.Name)
						if a and a:IsA("Attachment") then
							theirs = a
							break
						end
					end
				end
				if theirs then
					weld(theirs.Parent, handle, theirs.CFrame, mine.CFrame)
				else
					-- 3. nothing to go by: the body part nearest to it, where it sits now
					local best, bestD = nil, math.huge
					local at = handle.CFrame.Position
					for _, p in body do
						local dist = (p.CFrame.Position - at).Magnitude
						if dist < bestD then
							best, bestD = p, dist
						end
					end
					if best then
						weld(best, handle, best.CFrame:ToObjectSpace(handle.CFrame), CFrame.new())
					end
				end
				joined += 1
			end
		end
	end
	return joined
end

return GirlRig

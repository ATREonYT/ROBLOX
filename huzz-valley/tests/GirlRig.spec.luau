--[[
	Shared/GirlRig on every girl in the owner's real place (places/HUSSANIME.rbxl, Workspace > ANIME GIRLS):
	after toMotors + joinAccessories every hat, hair and face piece is welded to a BODY part (never loose, never the
	root), where it already sat (no jump), and C.C.'s hair goes on her Head (owner, Oct 19: "cc's head doesnt move").
	Run from huzz-valley/: lune run tests/GirlRig.spec.luau
]]
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local roblox = require("@lune/roblox")

local passed, failed = 0, 0
local function check(name, ok)
	if ok then passed += 1 else failed += 1 print("FAIL " .. name) end
end

local source = fs.readFile("src/ReplicatedStorage/Shared/GirlRig.lua")
local GirlRig = luau.load(source, { debugName = "GirlRig", environment = { Instance = roblox.Instance, CFrame = roblox.CFrame } })()

local place = roblox.deserializePlace(fs.readFile("places/HUSSANIME.rbxl"))
local folder = place:GetService("Workspace"):FindFirstChild("ANIME GIRLS")
check("his ANIME GIRLS folder is there", folder ~= nil)

local function near(a, b)
	return (a.Position - b.Position).Magnitude < 0.01 and (a.LookVector - b.LookVector).Magnitude < 0.01
		and (a.UpVector - b.UpVector).Magnitude < 0.01
end

local girls, cc = 0, nil
for _, rarity in folder:GetChildren() do
	for _, original in rarity:GetChildren() do
		if original:IsA("Model") then
			girls += 1
			local m = original:Clone()
			local before = {}
			for _, d in m:GetDescendants() do
				if d:IsA("BasePart") then before[d] = d.CFrame end
			end
			GirlRig.toMotors(m)
			GirlRig.joinAccessories(m)
			local name = original.Name
			local loose = {}
			for _, acc in m:GetChildren() do
				local handle = acc:IsA("Accoutrement") and acc:FindFirstChild("Handle")
				if handle then
					local to, joint = nil, nil
					for _, d in handle:GetDescendants() do
						if d:IsA("JointInstance") and (d.Part0 == handle or d.Part1 == handle) then
							to, joint = if d.Part0 == handle then d.Part1 else d.Part0, d
						end
					end
					if not to or to.Name == "HumanoidRootPart" or to:FindFirstAncestorWhichIsA("Accoutrement") then
						table.insert(loose, acc.Name)
					elseif joint:IsA("Weld") then
						-- where the weld holds it = where it sat (Part0 * C0 = Part1 * C1)
						local held = if joint.Part1 == handle then before[to] * joint.C0 * joint.C1:Inverse() else nil
						check(`{name} {acc.Name} stays where it sat`, held == nil or near(held, before[handle]))
					end
					if name:find("TransportViewer") and acc.Name:find("Hair") then
						cc = to
					end
				end
			end
			check(`{name}: every accessory on a body part ({table.concat(loose, ", ")})`, #loose == 0)
			local left = 0
			for _, d in m:GetDescendants() do
				if d.ClassName == "AnimationConstraint" or d.ClassName == "AccessoryRigidConstraint" or d:IsA("BallSocketConstraint") then
					left += 1
				end
			end
			check(`{name}: no attachment joints left`, left == 0)
			local head = m:FindFirstChild("Head")
			local neck = nil
			for _, d in m:GetDescendants() do
				if d:IsA("Motor6D") and d.Part1 == head then neck = d end
			end
			check(`{name}: her head turns on a Motor6D`, neck ~= nil)
		end
	end
end
check(`all 35 girls checked ({girls})`, girls >= 35)
check("C.C.'s hair is on her Head", cc ~= nil and cc.Name == "Head")

print(`GirlRig: {passed} passed, {failed} failed`)
if failed > 0 then
	error("GirlRig spec failed")
end

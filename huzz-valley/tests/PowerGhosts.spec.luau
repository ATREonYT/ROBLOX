-- lune run tests/PowerGhosts.spec.luau   (from huzz-valley/)
-- The power effects' ghosts (Gameplay/Ghosts, used by Gameplay/PowerEffects for Glitchy's two ghosts and Body Double's
-- afterimages), on a made-up body with a classic hat (critic, Oct 20):
--   * every visible part is copied (not the root, not an invisible part), anchored where it was, glowing in one colour,
--     colliding with nothing;
--   * a classic hat's Handle keeps its SpecialMesh (its shape; without it the copy drew the Handle's plain box, a
--     bright block over the head), the mesh's picture cleared so the colour shows;
--   * nothing that joins, runs or draws comes along (welds, motors, attachments, decals, SurfaceAppearance);
--   * Body Double's afterimages come at most one a second (kid-safe: Config/Powers BodyDouble.AfterimageEvery, and
--     PowerEffects uses it, never a faster number of its own).
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local roblox = require("@lune/roblox")
local Instance, Vector3, CFrame, Color3 = roblox.Instance, roblox.Vector3, roblox.CFrame, roblox.Color3

local passed, failed = 0, 0
local function check(name, ok)
	if ok then passed += 1 else failed += 1 print("FAIL " .. name) end
end

local GAMEPLAY = "src/StarterPlayer/StarterPlayerScripts/HuzzClient/Gameplay/"
local Ghosts = luau.load(fs.readFile(GAMEPLAY .. "Ghosts.lua"), { debugName = "Ghosts", environment = {
	Enum = roblox.Enum, pcall = pcall, table = table,
} })()

-- a body: root, head with a face and its neck motor, an arm MeshPart with its look, a classic hat, an invisible part
local character = Instance.new("Model")
character.Name = "Body"
local function part(class, name, size, at, parent)
	local p = Instance.new(class)
	p.Name, p.Size, p.CFrame, p.Color = name, size, at, Color3.fromRGB(20, 20, 20)
	p.Parent = parent or character
	return p
end
local root = part("Part", "HumanoidRootPart", Vector3.new(2, 2, 1), CFrame.new(0, 3, 0))
root.Transparency = 1
local head = part("Part", "Head", Vector3.new(1.2, 1.2, 1.2), CFrame.new(0, 4.6, 0))
local face = Instance.new("Decal")
face.Name = "face"
face.Parent = head
local neck = Instance.new("Motor6D")
neck.Name, neck.Part0, neck.Part1 = "Neck", root, head
neck.Parent = head
local arm = part("MeshPart", "RightUpperArm", Vector3.new(1, 1.2, 1), CFrame.new(1.5, 3.4, 0) * CFrame.Angles(0, 0, 0.2))
Instance.new("SurfaceAppearance").Parent = arm
local hat = Instance.new("Accessory")
hat.Name = "ClassicHat"
hat.Parent = character
local handle = part("Part", "Handle", Vector3.new(1, 1, 1), CFrame.new(0, 5.6, 0) * CFrame.Angles(0.1, 0.4, 0), hat)
local mesh = Instance.new("SpecialMesh")
mesh.MeshType = roblox.Enum.MeshType.FileMesh
mesh.MeshId, mesh.TextureId = "rbxassetid://1", "rbxassetid://2"
mesh.Parent = handle
local hatAt = Instance.new("Attachment")
hatAt.Name = "HatAttachment"
hatAt.Parent = handle
local weld = Instance.new("Weld")
weld.Name, weld.Part0, weld.Part1 = "AccessoryWeld", head, handle
weld.Parent = handle
local hidden = part("Part", "Hidden", Vector3.new(1, 1, 1), CFrame.new(0, 0, 0))
hidden.Transparency = 1

local folder = Instance.new("Folder")
local pink = Color3.fromRGB(255, 80, 200)
local ghosts = Ghosts.copy(character, pink, folder)

check("three ghosts: head, arm, hat (not the root, not the invisible part) (" .. #ghosts .. ")", #ghosts == 3)
local byName, allOk = {}, true
for _, g in ghosts do
	local p = g.part
	byName[p.Name] = g
	allOk = allOk and p.Anchored and not p.CanCollide and not p.CanQuery and not p.CanTouch and p.Parent == folder
		and p.Material == roblox.Enum.Material.Neon and p.Color == pink
end
check("every ghost anchored, glowing in the one colour, colliding with nothing, in the effects folder", allOk)
for name, src in { Head = head, RightUpperArm = arm, Handle = handle } do
	local g = byName[name]
	check(name .. ": a ghost where the part was", g ~= nil and g.at == src.CFrame and (g.part.CFrame.Position - src.CFrame.Position).Magnitude < 1e-4)
end
local hg = byName.Handle and byName.Handle.part
local keptMesh = hg and hg:FindFirstChildOfClass("SpecialMesh")
check("the classic hat's ghost keeps its SpecialMesh (its shape, not a plain block)", keptMesh ~= nil and keptMesh.MeshId == "rbxassetid://1")
check("the hat's mesh picture is cleared (the colour shows)", keptMesh ~= nil and keptMesh.TextureId == "")
check("the hat's ghost has no weld or attachment", hg ~= nil and hg:FindFirstChildOfClass("Weld") == nil and hg:FindFirstChildOfClass("Attachment") == nil)
local headG = byName.Head and byName.Head.part
check("the head's ghost has no face decal or neck motor", headG ~= nil and #headG:GetChildren() == 0)
local armG = byName.RightUpperArm and byName.RightUpperArm.part
check("the arm's ghost has no SurfaceAppearance (the colour shows)", armG ~= nil and armG:FindFirstChildOfClass("SurfaceAppearance") == nil)
check("the body itself is untouched (hat mesh, weld, face still there)", mesh.Parent == handle and mesh.TextureId == "rbxassetid://2"
	and weld.Parent == handle and face.Parent == head)

-- Body Double's afterimages: at most one a second
local env = setmetatable({ Color3 = Color3 }, { __index = _G })
local Powers = luau.load(fs.readFile("src/ReplicatedStorage/Shared/Config/Powers.lua"), { debugName = "Powers", environment = env })()
local every = Powers.BodyDouble.AfterimageEvery
check("Body Double's afterimages at least 1 s apart (" .. tostring(every) .. ")", type(every) == "number" and every >= 1)
local src = fs.readFile(GAMEPLAY .. "PowerEffects.lua")
check("PowerEffects spaces them by that number (never under 1 s)",
	string.find(src, "DOUBLE_GHOST = math.max(1, Powers.BodyDouble.AfterimageEvery", 1, true) ~= nil)
check("PowerEffects makes its ghosts with Gameplay/Ghosts (one rule for the hat's mesh)",
	string.find(src, "Ghosts.copy(", 1, true) ~= nil and string.find(src, "ClearAllChildren", 1, true) == nil)

print(string.format("PowerGhosts: %d ok, %d failed", passed, failed))
if failed > 0 then error("PowerGhosts spec failed") end

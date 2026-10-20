--[[
	A worn knife never floats off its body on this screen (owner, Oct 20: "please remove that black thing that is
	attacthed to my character in the game"). His pictures show a dark block the size of the default knife's grip about
	3 studs from him, at his shins, and no knife on his body. Offline every knife sits on the body (tests/KnifeWear.spec:
	blocky, slim, big and wide bodies), so the cause is not proven. This makes it impossible anyway:
	twice a second, every player's worn knife (HuzzServer/KnifeService "HuzzBackKnife") is checked. Its grip (the
	Handle, welded to the body by its BackMount) more than KnifeLook.STRAY studs from where that weld holds it, or more
	than STRAY studs outside the body part it hangs from (a wrong offset): the whole knife is hidden on this screen
	(LocalTransparencyModifier 1). A piece more than STRAY studs farther from the grip than any piece was when the
	knife was made (the model's "Reach"): that piece is hidden. Each shows again as soon as it is back in place (a
	knife can sit at its build spot for a moment while a body loads). The first one hidden prints one
	"[HuzzKnife] hid ..." line in Output naming the part, so the real cause can be found. The knife in a catcher's
	hand is not checked.
	Errors go to Output on "[Huzz] KnifeGuard:" lines; one body's error never stops the others.
]]
local KnifeLook = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("KnifeLook"))

local M = {}

M.EVERY = 0.5 -- seconds
M.KNIFE = "HuzzBackKnife"

-- Checks one body's worn knife: hide(part, stray, studs) for each of its parts (stray: off its mount, off the body
-- part it hangs from, or off its grip; studs: by how much).
function M.scan(character: Instance, hide: (BasePart, boolean, number) -> ())
	local knife = character:FindFirstChild(M.KNIFE)
	local handle = knife and knife:FindFirstChild("Handle", true)
	local mount = handle and handle:FindFirstChild("BackMount")
	local torso = mount and (mount :: any).Part0
	if not (handle and handle:IsA("BasePart") and torso and torso:IsA("BasePart")) then return end
	local at = handle.CFrame.Position
	local gripAt = (handle.CFrame * (mount :: any).C1).Position -- (the point the weld joins: its Grip)
	local held = (torso.CFrame * (mount :: any).C0).Position -- (where the weld holds it)
	local clear = knife:GetAttribute("BackClear") -- (over a cape or long hair it sits that much farther out)
	local off = math.max((gripAt - held).Magnitude,
		KnifeLook.outside(torso.CFrame, torso.Size, gripAt) - (if type(clear) == "number" then clear else 0))
	local reach = knife:GetAttribute("Reach")
	for _, d in knife:GetDescendants() do
		if d:IsA("BasePart") then
			local apart = (d.CFrame.Position - at).Magnitude -- (a piece: never farther from its grip than when it was made)
			local loose = type(reach) == "number" and apart > reach + KnifeLook.STRAY
			hide(d, off > KnifeLook.STRAY or loose, if loose then apart - reach else off)
		end
	end
end

function M.start()
	local Players = game:GetService("Players")
	local hidden: { [BasePart]: boolean } = {} -- (a plain table: weak keys on Instances drop entries at random)
	local told = false
	local function hide(part: BasePart, stray: boolean, by: number)
		if stray and not hidden[part] then
			hidden[part] = true
			part.LocalTransparencyModifier = 1
			if not told then
				told = true
				local owner = part:FindFirstAncestorOfClass("Model")
				owner = owner and owner.Parent
				warn(string.format("[HuzzKnife] hid a worn knife part %.1f studs out of place on %s: %s (%s, size %s). Send Claude this line.",
					by, if owner then owner.Name else "?", part:GetFullName(), part.ClassName, tostring(part.Size)))
			end
		elseif not stray and hidden[part] then
			hidden[part] = nil
			if part.LocalTransparencyModifier == 1 then part.LocalTransparencyModifier = 0 end
		end
	end
	while true do
		task.wait(M.EVERY)
		for part in hidden do
			if not part.Parent then hidden[part] = nil end
		end
		for _, player in Players:GetPlayers() do
			local character = player.Character
			if character then
				local ok, err = pcall(M.scan, character, hide)
				if not ok then warn("[Huzz] KnifeGuard: " .. tostring(err)) end
			end
		end
	end
end

return M

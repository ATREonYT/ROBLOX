--[[
	Loose parts inside a character (owner, Oct 21: "the black object following every users character, find what it is,
	and don't try to hide it, remove it"). His close-up design/owner-oct20/2034-black-block-close.png has the block
	outlined together with his legs: Studio outlines the whole model you click, so the block is a part INSIDE his
	character. Used by the server (HuzzServer/BlockSweep: removed for everyone) and by each screen
	(Gameplay/FollowGuard (c): a part only that screen made). Pure: no services, works on any character model.
	A loose part: visible, inside the character, not one of its body parts, and its box more than a gap off every body
	part (its centre's distance to the nearest body part's box, less half its own diagonal, so a long part touching the
	body never counts):
	  * anything: OTHER studs (his block sits about 1.6 to 2.3 off his legs);
	  * never: the worn knife or the knife in a hand (owner, Oct 21 14:18: "the knfies dont load": removing a worn
	    knife's grip while it was still being put on took the whole knife with it, for good. A worn knife's stray piece
	    is only hidden, on each screen, by Gameplay/KnifeGuard), the carried girl or a follower, the companion, the
	    Shield, anything marked HuzzOnBody, an accessory piece bigger than SMALL_ACCESSORY (wings, long hair, a big
	    back item reach out).
]]
local LooseParts = {}

LooseParts.KNIFE = 1.75
LooseParts.OTHER = 1.2
LooseParts.SMALL_ACCESSORY = 1.5
LooseParts.SEE = 0.95 -- more see-through than this: already invisible
LooseParts.LIMBS = {
	Head = true, UpperTorso = true, LowerTorso = true, Torso = true,
	LeftUpperArm = true, LeftLowerArm = true, LeftHand = true, RightUpperArm = true, RightLowerArm = true, RightHand = true,
	LeftUpperLeg = true, LeftLowerLeg = true, LeftFoot = true, RightUpperLeg = true, RightLowerLeg = true, RightFoot = true,
	["Left Arm"] = true, ["Right Arm"] = true, ["Left Leg"] = true, ["Right Leg"] = true,
}
LooseParts.OK = { HuzzKnife = true, HuzzBackKnife = true, HuzzCarried = true, HuzzFollowers = true, HuzzCompanions = true, HuzzShields = true, HuzzShield = true }
LooseParts.KNIFE_MODEL = "HuzzBackKnife"

local function isA(x: any, class: string): boolean
	local ok, yes = pcall(function() return x:IsA(class) end)
	return ok and yes == true
end
local function read(x: any, key: string): any
	local ok, v = pcall(function() return x[key] end)
	return if ok then v else nil
end

-- How far a world point lies outside a box (0 inside).
function LooseParts.outside(cf: CFrame, size: Vector3, at: Vector3): number
	local p = cf:PointToObjectSpace(at)
	local h = size / 2
	local dx, dy, dz = math.max(math.abs(p.X) - h.X, 0), math.max(math.abs(p.Y) - h.Y, 0), math.max(math.abs(p.Z) - h.Z, 0)
	return math.sqrt(dx * dx + dy * dy + dz * dz)
end

local function visible(p: BasePart): boolean
	return (read(p, "Transparency") or 0) < LooseParts.SEE and (read(p, "LocalTransparencyModifier") or 0) < LooseParts.SEE
end

-- The loose parts inside this character: { { part, gap, limit } }. Nothing while it has no body parts (loading).
function LooseParts.find(character: Instance): { { part: BasePart, gap: number, limit: number } }
	local limbs = {}
	for _, c in character:GetChildren() do
		if isA(c, "BasePart") and LooseParts.LIMBS[c.Name] then table.insert(limbs, c) end
	end
	local out = {}
	if #limbs == 0 then return out end
	for _, d in character:GetDescendants() do
		if isA(d, "BasePart") and not (d.Parent == character and (LooseParts.LIMBS[d.Name] or d.Name == "HumanoidRootPart")) and visible(d) then
			local skip, knife = false, false
			local x = d.Parent
			while x and x ~= character do
				if LooseParts.OK[x.Name] or (read(x, "GetAttribute") and x:GetAttribute("HuzzOnBody") == true) then skip = true break end
				if isA(x, "Accessory") and math.max(d.Size.X, d.Size.Y, d.Size.Z) > LooseParts.SMALL_ACCESSORY then skip = true break end
				if x.Name == LooseParts.KNIFE_MODEL then knife = true end
				x = x.Parent
			end
			if not skip then
				local at, half = d.CFrame.Position, d.Size.Magnitude / 2
				local gap = math.huge
				for _, l in limbs do
					gap = math.min(gap, LooseParts.outside(l.CFrame, l.Size, at) - half)
				end
				local limit = if knife then LooseParts.KNIFE else LooseParts.OTHER
				if gap > limit then table.insert(out, { part = d, gap = gap, limit = limit }) end
			end
		end
	end
	return out
end

-- One line for Output, naming the part so its maker can be found.
function LooseParts.line(p: BasePart, who: string, gap: number, side: string): string
	local s, c = p.Size, p.Color
	local chain, x = {}, p
	while x and x.Parent and not isA(x, "DataModel") do
		table.insert(chain, 1, `{x.Name} ({x.ClassName})`)
		x = x.Parent
	end
	return string.format("[HuzzBlock] removed (%s) a loose part inside %s's character, %.1f studs off the body: %s; size %.2f x %.2f x %.2f, colour %d,%d,%d, in %s. Send Claude this line.",
		side, who, gap, p.Name, s.X, s.Y, s.Z, math.floor(c.R * 255 + 0.5), math.floor(c.G * 255 + 0.5), math.floor(c.B * 255 + 0.5), table.concat(chain, " > "))
end

return LooseParts

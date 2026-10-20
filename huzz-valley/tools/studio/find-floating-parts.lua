-- Huzz Valley: name the small things floating near your character (owner, Oct 20: "fix the little thing near the
-- chaaracter floating ( black block)", design/owner-oct19/2010-floating-block.png). One still picture can't say what
-- that block is; Studio can, in one go.
--
-- How: Play in Studio. Walk next to the block. Then View > Command Bar, paste ALL of this file, press Enter. Do it
-- twice: once as it is (the server's view) and once after switching the Command Bar to the client (the "Server" /
-- "Client" switch on the Home or Test tab while playing), because a screen can make parts the server never sees.
-- Output prints, nearest first, every small visible part within RANGE studs of your character that isn't part of
-- your body's own limbs (your hats and hair are listed too, near the top: skip those):
--   [HuzzFind] 3.2 studs  Workspace.<where it is>.<its name>  Part 0.45x1.20x0.30  colour 20,20,30  anchored  held by: ...
-- "held by" names what keeps it there (its welds, or "nothing: anchored"). Screenshot the Output and send it to
-- Claude: the line for the block says exactly what made it. Untested here (needs Studio).
local RANGE = 12 -- studs round your character
local BIGGEST = 4 -- studs: anything longer than this is a building, not the little block

local Players = game:GetService("Players")
local me = Players.LocalPlayer or Players:GetPlayers()[1]
local character = me and me.Character
local root = character and character:FindFirstChild("HumanoidRootPart")
if not root then
	warn("[HuzzFind] No character: press Play first, then run this again")
	return
end

local function holders(p)
	local list = {}
	for _, j in p:GetJoints() do
		local other = if j.Part0 == p then j.Part1 else j.Part0
		table.insert(list, j.ClassName .. "->" .. (if other then other:GetFullName() else "nothing (its part is gone)"))
	end
	if #list == 0 then return if p.Anchored then "nothing: anchored" else "nothing (falling?)" end
	return table.concat(list, ", ")
end

local found = {}
for _, d in workspace:GetDescendants() do
	if d:IsA("BasePart") and not d:IsA("Terrain") then
		local s = d.Size
		local onBody = d:IsDescendantOf(character) and d.Parent == character -- (your body's own limbs)
		local dist = (d.Position - root.Position).Magnitude
		if not onBody and dist <= RANGE and math.max(s.X, s.Y, s.Z) <= BIGGEST and d.Transparency < 0.95
			and d.LocalTransparencyModifier < 0.95 then
			table.insert(found, { d = d, dist = dist })
		end
	end
end
table.sort(found, function(a, b) return a.dist < b.dist end)
for _, f in found do
	local d, c = f.d, f.d.Color
	print(string.format("[HuzzFind] %.1f studs  %s  %s %.2fx%.2fx%.2f  colour %d,%d,%d  %s  held by: %s", f.dist,
		d:GetFullName(), d.ClassName, d.Size.X, d.Size.Y, d.Size.Z, c.R * 255, c.G * 255, c.B * 255,
		if d.Anchored then "anchored" else "loose", holders(d)))
end
print(string.format("[HuzzFind] Done: %d small parts within %d studs of %s (%s view)", #found, RANGE, me.Name,
	if game:GetService("RunService"):IsServer() then "server" else "client"))

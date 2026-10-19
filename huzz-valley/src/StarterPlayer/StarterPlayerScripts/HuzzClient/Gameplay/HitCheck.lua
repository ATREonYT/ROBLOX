--[[
	Pinpoint knife hits (owner, Oct 18: "make hitboxes pinpoint"): a catcher's stab or lunge hits only a runner
	whose body is inside the knife's reach ON THEIR OWN SCREEN: a box in front of the catcher, from their middle out
	to the knife's tip (Config/Round Stab/Lunge Reach and Width). Gameplay/Actions and Gameplay/Dash send the runner
	found (or false for a miss) and RoundService checks it's possible from where the server sees both of them; the old
	"nearest runner within 8.5 studs, almost all round you" is only for a client that sends nothing.
	Oct 19 (owner: "make the player to player touch WAY MORE accurate"): only the runner's own body counts (limbs,
	torso, head: Shared/TouchHit.isBody), never their hats, hair, wings or worn knife, and the box is the knife's real
	reach (Config/Round Stab 4.5 x 3.5). The server checks the same box against the runner where this screen showed them.
	Oct 19, 18:16 (owner: "make the player to player interactions pinpoint precise ... so people dont die and start
	compalining"): find() also returns what this screen showed at that moment, { seen = the runner's root as drawn
	here, mine = your own root }; the server judges exactly that (Shared/TouchHit.verify), only checking both lie on
	the real paths it has. So what the catcher saw is what counts, no more and no less.
]]
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local TouchHit = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared").TouchHit)

local HitCheck = {}

-- The closest active runner inside the box in front of root, as a UserId; nil if none; false if this Roblox build
-- can't check (then the caller sends nothing and the server does its own check).
-- dir (optional): the way the box points (a catcher's leap goes forward or sideways: Shared/KnifeLeap); else the
-- way root faces.
function HitCheck.find(root: BasePart, reach: number, width: number, dir: Vector3?): ((number | boolean)?, any)
	local me = Players.LocalPlayer
	local bodies = {}
	local now = Workspace:GetServerTimeNow()
	for _, p in Players:GetPlayers() do
		-- only runners the server would let the knife take: not waiting on the line (a Hero run's frozen runners)
		-- and not just rescued (critic: the closest body was a frozen runner, so the real target beside them was missed)
		if p ~= me and p.Character and p:GetAttribute("HuzzRole") == "Runner" and p:GetAttribute("HuzzStatus") == "Active"
			and p:GetAttribute("HuzzFrozen") ~= true and (p:GetAttribute("ProtectedUntil") or 0) <= now then
			table.insert(bodies, p.Character)
		end
	end
	if #bodies == 0 then
		return nil
	end
	local ok, parts = pcall(function()
		local params = OverlapParams.new()
		params.FilterType = Enum.RaycastFilterType.Include
		params.FilterDescendantsInstances = bodies
		-- from the catcher's middle out to the knife's tip; body height (a runner mid-huss crouches, a lunge hops)
		local way = dir or root.CFrame.LookVector
		local flat = CFrame.lookAt(root.Position, root.Position + Vector3.new(way.X, 0, way.Z))
		return Workspace:GetPartBoundsInBox(flat * CFrame.new(0, 0, -reach / 2), Vector3.new(width, 7, reach), params)
	end)
	if not ok or type(parts) ~= "table" then
		return false
	end
	local best, bestD, bestRoot = nil, math.huge, nil
	for _, part in parts do
		-- the body itself, a direct child of the character (an accessory's Handle sits in its Accessory)
		local model = part.Parent
		local p = model and model:IsA("Model") and TouchHit.isBody(part.Name) and Players:GetPlayerFromCharacter(model)
		local theirRoot = p and model:FindFirstChild("HumanoidRootPart")
		if p and theirRoot and theirRoot:IsA("BasePart") then
			local d = (part.Position - root.Position).Magnitude
			if d < bestD then
				best, bestD, bestRoot = p.UserId, d, theirRoot
			end
		end
	end
	if best and bestRoot then
		return best, { seen = bestRoot.CFrame, mine = root.CFrame } -- (exactly what this screen shows now)
	end
	return best
end

return HitCheck

--[[
	Pinpoint knife hits (owner, Oct 18: "make hitboxes pinpoint"): a catcher's stab or lunge hits only a runner
	whose body is inside the knife's reach ON THEIR OWN SCREEN: a box in front of the catcher, from their middle out
	to the knife's tip (Config/Round Stab/Lunge Reach and Width). Gameplay/Actions and Gameplay/Dash send the runner
	found (or false for a miss) and RoundService checks it's possible from where the server sees both of them; the old
	"nearest runner within 8.5 studs, almost all round you" is only for a client that sends nothing.
]]
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local HitCheck = {}

-- The closest active runner inside the box in front of root, as a UserId; nil if none; false if this Roblox build
-- can't check (then the caller sends nothing and the server does its own check).
function HitCheck.find(root: BasePart, reach: number, width: number): (number | boolean)?
	local me = Players.LocalPlayer
	local bodies = {}
	for _, p in Players:GetPlayers() do
		if p ~= me and p.Character and p:GetAttribute("HuzzRole") == "Runner" and p:GetAttribute("HuzzStatus") == "Active" then
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
		local flat = CFrame.lookAt(root.Position, root.Position + Vector3.new(root.CFrame.LookVector.X, 0, root.CFrame.LookVector.Z))
		return Workspace:GetPartBoundsInBox(flat * CFrame.new(0, 0, -reach / 2), Vector3.new(width, 7, reach), params)
	end)
	if not ok or type(parts) ~= "table" then
		return false
	end
	local best, bestD = nil, math.huge
	for _, part in parts do
		local model = part:FindFirstAncestorOfClass("Model")
		local p = model and Players:GetPlayerFromCharacter(model)
		if p then
			local d = (part.Position - root.Position).Magnitude
			if d < bestD then
				best, bestD = p.UserId, d
			end
		end
	end
	return best
end

return HitCheck

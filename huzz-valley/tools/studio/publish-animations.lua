-- Huzz Valley: publish the game's animations (Studio Command Bar). UNTESTED here: cloud sessions can't reach Roblox.
-- In Studio tests the game already plays the raw animations in ReplicatedStorage > HuzzAnimations (walk, run, dash,
-- the 25 dances). The live game needs them published under YOUR account (or your group, if the game is a group's).
-- This tries AssetService:CreateAssetAsync on each one and prints the filled-in config lines (lines starting with
-- [HuzzAnim]): send that Output to Claude. Anything it can't publish is listed; publish those by hand:
--   right-click it in ReplicatedStorage > HuzzAnimations > Save to Roblox..., then copy its ID into the lines.
local AssetService = game:GetService("AssetService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local folder = ReplicatedStorage:FindFirstChild("HuzzAnimations")
if not folder then
	warn("[HuzzAnim] ReplicatedStorage > HuzzAnimations is missing: open places/HuzzValley-yours.rbxl")
	return
end

local MOVES = { "Walk", "Run", "Idle", "Jump", "Fall", "Climb", "Dash" }
local ids, failed = {}, {}
for _, seq in folder:GetChildren() do
	if seq:IsA("KeyframeSequence") then
		local ok, result, id = pcall(function()
			return AssetService:CreateAssetAsync(seq, Enum.AssetType.Animation, { Name = "Huzz " .. seq.Name, Description = "Huzz Valley animation" })
		end)
		if ok and result == Enum.CreateAssetResult.Success and id then
			ids[seq.Name] = "rbxassetid://" .. tostring(id)
			print("[HuzzAnim] published " .. seq.Name .. " = " .. tostring(id))
		else
			table.insert(failed, seq.Name)
			warn("[HuzzAnim] couldn't publish " .. seq.Name .. ": " .. tostring(if ok then result else result))
		end
		task.wait(0.5)
	end
end

print("[HuzzAnim] --- Config/Animations.lua ---")
for _, name in MOVES do
	print(string.format('[HuzzAnim] \t%s = "%s",', name, ids[name] or ""))
end
print("[HuzzAnim] --- Config/Dances.lua (AnimationId per dance) ---")
for name, id in ids do
	local dance = string.match(name, "^Dance_(.+)$")
	if dance then
		print(string.format('[HuzzAnim] \t%s = "%s",', dance, id))
	end
end
print(if #failed == 0 then "[HuzzAnim] All published." else "[HuzzAnim] Not published: " .. table.concat(failed, ", "))

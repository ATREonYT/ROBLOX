-- Huzz Valley: publish the game's animations once (the moves and all the dances), so the live game plays them as real
-- animations. Without this the live game still works (owner, Oct 20 15:13: "inside the actual roblox game, not
-- studio, make it so that dances are available"): dances and moves are drawn by hand on each body. Published ones
-- are smoother and cost less, so do this once when you can.
-- How: open the Huzz Valley place in Studio (not while playing), paste the line below into View > Command Bar, press
-- Enter, and wait for the "[HuzzAnim] Done" line in Output:
--   require(game.ServerStorage.HuzzStudioTools.PublishAnimations)()
-- What it does:
--   1. for each animation in ServerStorage > HuzzAnimations without an ID yet, asks Roblox to publish it to your
--      account (or your group, if the game is a group's): AssetService:CreateAssetAsync. UNTESTED here (the cloud
--      can't reach Roblox), and Roblox may refuse animations from a script: then each line says "couldn't publish";
--   2. takes any ID you put on an animation yourself (the sure way, below): its "AnimationId" attribute;
--   3. writes every ID into ReplicatedStorage > Shared > Config > AnimationIds, which the game reads
--      (Shared/AnimationLibrary), and prints one [HuzzAnim] line each.
-- The sure way, if step 1 fails: in Explorer, ServerStorage > HuzzAnimations, right-click an animation > Save to
-- Roblox..., publish it, copy the number Roblox shows, then in Properties > Attributes add a string attribute named
-- AnimationId with that number. Do this for the dances you want first, then run the line above again.
-- Run it again any time: animations that already have an ID are skipped. Then File > Publish to Roblox.
return function()
	if _G.HuzzPublishingAnims then
		warn("[HuzzAnim] Already publishing: wait for the Done line.")
		return
	end
	_G.HuzzPublishingAnims = true
	local okAll, errAll = pcall(function()
		local AssetService = game:GetService("AssetService")
		local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
		local folder = game:GetService("ServerStorage"):FindFirstChild("HuzzAnimations")
		if not folder then
			warn("[HuzzAnim] ServerStorage > HuzzAnimations is missing: open places/HuzzValley-yours.rbxl and try again.")
			return
		end

		-- what's already there (read the text: a required ModuleScript would be stale after a re-run)
		local idsModule = Shared.Config:FindFirstChild("AnimationIds")
		local ids = {}
		if idsModule then
			for key, id in string.gmatch(idsModule.Source, '%["([^"]+)"%]%s*=%s*"([^"]*)"') do
				if id ~= "" then ids[key] = id end
			end
		end

		local function asId(v: any): string?
			local n = tonumber(string.match(tostring(v or ""), "(%d+)%s*$"))
			return if n and n > 0 then "rbxassetid://" .. tostring(n) else nil
		end

		print("[HuzzAnim] Publishing animations... (one line each)")
		local made, kept, typed, failed = 0, 0, 0, {}
		for _, seq in folder:GetChildren() do
			if seq:IsA("KeyframeSequence") then
				local name = seq.Name
				local own = asId(seq:GetAttribute("AnimationId"))
				if own then
					ids[name] = own
					typed += 1
					print("[HuzzAnim] " .. name .. " = " .. own .. " (your AnimationId attribute)")
				elseif ids[name] then
					kept += 1
				else
					local ok, result, id = pcall(function()
						return AssetService:CreateAssetAsync(seq:Clone(), Enum.AssetType.Animation,
							{ Name = "Huzz " .. name, Description = "Huzz Valley animation" })
					end)
					local got = ok and result == Enum.CreateAssetResult.Success and asId(id)
					if got then
						ids[name] = got
						made += 1
						print("[HuzzAnim] published " .. name .. " = " .. got)
					else
						table.insert(failed, name)
						warn("[HuzzAnim] couldn't publish " .. name .. ": " .. tostring(if ok then result else result))
					end
					task.wait(0.3)
				end
			end
		end

		-- write them where the game reads them
		local keys = {}
		for key in ids do table.insert(keys, key) end
		table.sort(keys)
		local lines = {
			"-- Published animation IDs, written by ServerStorage.HuzzStudioTools.PublishAnimations (docs/STUDIO-STEPS.md, Part 5).",
			"-- Keys are the KeyframeSequence names in ServerStorage > HuzzAnimations; Shared/AnimationLibrary reads them first.",
			"return {",
		}
		for _, key in keys do table.insert(lines, string.format('\t["%s"] = "%s",', key, ids[key])) end
		table.insert(lines, "}")
		if not idsModule then
			idsModule = Instance.new("ModuleScript")
			idsModule.Name = "AnimationIds"
			idsModule.Parent = Shared.Config
		end
		idsModule.Source = table.concat(lines, "\n") .. "\n"

		print(string.format("[HuzzAnim] Done: %d published now, %d from your attributes, %d already had IDs, %d not published.",
			made, typed, kept, #failed))
		if #failed > 0 then
			warn("[HuzzAnim] Not published (they still work live, drawn by hand): " .. table.concat(failed, ", "))
			warn("[HuzzAnim] The sure way for these: docs/STUDIO-STEPS.md Part 5 (Save to Roblox, then an AnimationId attribute).")
		end
		print("[HuzzAnim] Next: File > Save, then File > Publish to Roblox. If you use Rojo, send Claude the AnimationIds text so it goes in the repo too.")
	end)
	_G.HuzzPublishingAnims = false
	if not okAll then warn("[HuzzAnim] The publisher stopped with an error: " .. tostring(errAll)) end
end

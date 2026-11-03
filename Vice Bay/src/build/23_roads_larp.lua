-- 23 roads (Larp pass): rebuild the mainland streets with the reference markings, then re-apply the
-- sidewalk cuts other districts made, the rail crossing and the road wear.
return function(L)
	local G = L.G
	local VB = workspace.ViceBay
	local old = VB:FindFirstChild("Roads")
	if old then old:Destroy() end
	local lines = require(game.ServerStorage.VBBuild.lines:Clone())(L)
	local net = L.net(lines)
	L.seed(42)
	L.buildRoads(VB, net, "Roads")
	L.cutSidewalk(CFrame.new(-870, G + 0.5, -448), Vector3.new(30, 2, 12))
	L.cutSidewalk(CFrame.new(1472, G + 0.5, -830), Vector3.new(26, 3, 40))
	L.cutSidewalk(CFrame.new(-1826, G + 0.5, -410), Vector3.new(24, 3, 68))
	-- street props never block driving (poles, signals, signs, bins, hydrants, benches)
	local SOFT = { TrafficLight = true, StreetLight = true, StopSign = true, Hydrant = true, TrashCan = true, StreetFurniture = true, Bench = true, UtilityPole = true }
	for _, d in ipairs(VB.Roads:GetDescendants()) do
		if d:IsA("BasePart") then
			local mm = d.Parent
			if SOFT[d.Name] or (mm and SOFT[mm.Name]) then d.CanCollide = false end
		end
	end
	local parts = 0
	for _, d in ipairs(VB.Roads:GetDescendants()) do if d:IsA("BasePart") then parts += 1 end end
	return "roads rebuilt, parts " .. parts
end

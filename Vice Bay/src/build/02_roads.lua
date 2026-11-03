-- 02 roads: build the whole mainland street network
return function(L)
	local lines = require(game.ServerStorage.VBBuild.lines:Clone())(L)
	local net = L.net(lines)
	local VB = L.folder(workspace, "ViceBay")
	local old = VB:FindFirstChild("Roads")
	if old then old:Destroy() end
	L.seed(42)
	local t = os.clock()
	L.buildRoads(VB, net, "Roads")
	local parts = 0
	for _, d in ipairs(VB.Roads:GetDescendants()) do if d:IsA("BasePart") then parts += 1 end end
	return string.format("nodes %d edges %d parts %d (%.1fs)", #net.nodes, #net.edges, parts, os.clock() - t)
end

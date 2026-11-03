-- Vice Bay: scroll every stock ticker band locally (server only updates the text)
local RunService = game:GetService("RunService")
local labels = {}
local function scan()
	labels = {}
	for _, d in ipairs(workspace:GetDescendants()) do
		if d:IsA("TextLabel") and d.Name == "TickerScroll" then table.insert(labels, d) end
	end
end
scan()
workspace.DescendantAdded:Connect(function(d)
	if d:IsA("TextLabel") and d.Name == "TickerScroll" then table.insert(labels, d) end
end)
local SPEED = 0.06 -- label widths per second
RunService.RenderStepped:Connect(function(dt)
	for _, t in ipairs(labels) do
		if t.Parent then
			local x = t.Position.X.Scale - SPEED * dt
			if x < -2 then x = 1 end
			t.Position = UDim2.fromScale(x, 0)
		end
	end
end)

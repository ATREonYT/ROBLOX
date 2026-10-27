-- hud.luau (SCENE=hud): the scenario for the HUD alone, at the screen shoot.sh sets (SW x SH, NOTCH, TOUCH; a phone:
-- SW=844 SH=390 NOTCH=47 TOUCH=1). It gives the player a little progress (4 rebirths, Power 45% of the way, some Cash),
-- lets the HUD arrive, and dumps every enabled ScreenGui to <UI_OUT>/hud.json (dump.luau's __uiDumpAll). shoot.js then
-- draws it and lists what overlaps or runs off the screen (hud.layout.json beside the picture).
do
	local ok0 = waitFor(function() return P.PlayerGui:FindFirstChild('HoodHUD') ~= nil end, 30)
	print('[ui] clients up: ' .. tostring(ok0))
	wall(1)
	-- (Oct 27, round 8) a fresh save gets the welcome and a calm first screen (Shared/HudReveal): let the welcome pass,
	-- then draw a returning player's HUD, every part shown
	waitFor(function() return P.PlayerGui:FindFirstChild('HoodWelcome') == nil end, 12)
	P:SetAttribute('FirstJoin', false)
	local R = 4
	local need = RebirthRules.need(R)
	data.Rebirths = R
	data.Rep = math.floor(need * 0.45)
	data.Cash = 25300
	P:SetAttribute('Rebirths', R)
	P:SetAttribute('RebirthNeed', need)
	P:SetAttribute('RebirthMultiplier', RebirthRules.multiplier(R))
	P:SetAttribute('RebirthNextMultiplier', RebirthRules.multiplier(R + 1))
	P:SetAttribute('Power', data.Rep)
	P:SetAttribute('Cash', data.Cash)
	sync()
	wall(3)
	-- (the harness doesn't run Extras' fills of the right column's slots: an empty slot gets a see-through magenta stand-in
	-- of its own size, so the picture and the overlap list still show where Playtime, Missions and the Starter Pack go)
	local hud = P.PlayerGui:FindFirstChild('HoodHUD')
	local root = hud and hud:FindFirstChild('Root')
	for _, name in { 'PlaytimeSlot', 'MissionsSlot', 'StarterSlot' } do
		local slot = root and root:FindFirstChild(name)
		if slot and not slot:FindFirstChildWhichIsA('GuiObject') then
			local f = Instance.new('Frame')
			f.Name = 'StandIn'
			f.BackgroundColor3 = Color3.fromRGB(255, 0, 200)
			f.BackgroundTransparency = 0.55
			f.Size = UDim2.fromScale(1, 1)
			f.Parent = slot
			print('[ui] ' .. name .. ': empty here, drawn as a stand-in')
		end
	end
	local list = {}
	for _, g in P.PlayerGui:GetChildren() do
		if g:IsA('ScreenGui') and g.Enabled then table.insert(list, g) end
	end
	local ok, err = pcall(__uiDumpAll, list, UI_OUT .. '/hud.json')
	print('[ui] hud: ' .. (ok and ('dumped ' .. #list .. ' screens') or ('failed ' .. tostring(err))))
	print('[ui] done')
end

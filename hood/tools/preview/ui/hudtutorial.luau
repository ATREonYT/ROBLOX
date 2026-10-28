-- hudtutorial.luau (SCENE=hudtutorial, Oct 28): the screen of a fresh save in its first minute, at the screen shoot.sh
-- sets (a phone: SW=844 SH=390 NOTCH=47 TOUCH=1). The welcome passes at the spawn and the tutorial's
-- card and its loop strip come up, then every enabled ScreenGui is dumped to
-- <UI_OUT>/hud.json (and the welcome's words, 1.6 s in, to welcome.json); shoot.js draws it and lists what overlaps or runs off the screen (hud.layout.json).
do
	local ok0 = waitFor(function() return P.PlayerGui:FindFirstChild('HoodHUD') ~= nil end, 30)
	print('[ui] clients up: ' .. tostring(ok0))
	local SPL = workspace.TheBlockV2:GetAttribute('LobbySpawn') or Vector3.new(0, 0, 55)
	local okS = pcall(function()
		standMap(SPL.X, SPL.Z, workspace.TheBlockV2:GetAttribute('LobbySpawnYaw') or 0)
		camFn = follow(0, -1)
	end)
	print('[ui] at the spawn: ' .. tostring(okS))
	-- (the welcome's words, 1.6 s in: drawn as welcome.png)
	for _ = 1, 48 do frame(1 / 30) end
	local wg = P.PlayerGui:FindFirstChild('HoodWelcome')
	print('[ui] welcome up: ' .. tostring(wg ~= nil))
	if wg then pcall(__uiDumpAll, { wg }, UI_OUT .. '/welcome.json') end
	for _ = 1, 102 do frame(1 / 30) end -- (the rest of the welcome's 3.5 s on the frames' clock)
	waitFor(function() return P.PlayerGui:FindFirstChild('HoodWelcome') == nil end, 15)
	for _ = 1, 120 do frame(1 / 30) end -- (the tutorial's first line and its loop strip arrive)
	local hint = P.PlayerGui:FindFirstChild('HoodTutorialHint')
	local loop = hint and hint:FindFirstChild('Loop', true)
	print('[ui] tutorial card: ' .. tostring(hint ~= nil) .. ', loop strip shown: ' .. tostring(loop ~= nil and loop.Visible))
	local list = {}
	for _, g in P.PlayerGui:GetChildren() do
		if g:IsA('ScreenGui') and g.Enabled then table.insert(list, g) end
	end
	local ok, err = pcall(__uiDumpAll, list, UI_OUT .. '/hud.json')
	print('[ui] hud: ' .. (ok and ('dumped ' .. #list .. ' screens') or ('failed ' .. tostring(err))))
	print('[ui] done')
end

-- luck.luau (SCENE=luck, Oct 27, the luck round): the Shop opened on its Luck tab, twice: with no luck pass
-- (<UI_OUT>/luck.json: the odds hero marks Normal YOURS, both pass cards sell) and with 4x Luck owned
-- (<UI_OUT>/luck4.json: the 4x column YOURS, 4x Luck OWNED, 2x Luck says YOU HAVE 4x). Runs after feel_base's set-up.
do
	local ok0 = waitFor(function() return P.PlayerGui:FindFirstChild('HoodStore') ~= nil end, 30)
	print('[ui] clients up: ' .. tostring(ok0))
	wall(1)
	-- (round 8) a fresh save's welcome has the screen to itself: let it pass first
	waitFor(function() return P.PlayerGui:FindFirstChild('HoodWelcome') == nil end, 12)
	P:SetAttribute('FirstJoin', false)
	local function open(name)
		local g = P.PlayerGui:FindFirstChild('HoodStore')
		local e = g and g:FindFirstChild('Open')
		if not e then print('[ui] no Open on HoodStore'); return end
		__fireOn(e, 'Event', 'Luck')
		sync()
		wall(3)
		local ok, err = pcall(__uiDump, g, UI_OUT .. '/' .. name .. '.json')
		print('[ui] ' .. name .. ': ' .. (ok and 'dumped' or ('failed ' .. tostring(err))))
	end
	open('luck')
	P:SetAttribute('Pass_Luck4', true) -- (the Store rebuilds on a pass change)
	sync()
	wall(1.5)
	open('luck4')
end

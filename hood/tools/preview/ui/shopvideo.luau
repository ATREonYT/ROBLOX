-- shopvideo.luau (SCENE=shopvideo): the Shop's motion as frames, for a 30 fps video. It opens the Store the way the game
-- does (its Open event) and dumps HoodStore every 1/30 s of game time for FRAMES frames (default 210, 7 s) to
-- <UI_OUT>/f_NNN.json: the window's pop-in, the cards' stagger, the icons' idle motion (UIIdle), the shine sweeps, the
-- sparkles. (Oct 27, round 7) It then taps the Luck tab and the Gamepasses tab (the list scrolls there), rests the mouse
-- on a Gamepass price button (the hover pop) and presses it (the squash; the purchase prompt is refused offline). shoot.js draws every frame; then, from the out dir:
--   ffmpeg -framerate 30 -i f_%03d.png -c:v libx264 -pix_fmt yuv420p shop.mp4
do
	local N = FRAMES or 210
	local ok0 = waitFor(function() return P.PlayerGui:FindFirstChild('HoodStore') ~= nil end, 30)
	print('[ui] clients up: ' .. tostring(ok0))
	data.Cash = 25300
	P:SetAttribute('Cash', data.Cash)
	sync()
	wall(1)
	local g = P.PlayerGui:FindFirstChild('HoodStore')
	local e = g and g:FindFirstChild('Open')
	if not e then print('[ui] no Open on HoodStore'); return end
	__fireOn(e, 'Event')
	sync()
	local hit
	-- (Oct 27, round 7) the tab row: Luck at 28%, Gamepasses at 48% (each tab pressed and let go), then the mouse rests on
	-- the first Gamepass price button at 66% and presses it at 74%
	local function press(target, at, i)
		if not target then return end
		if i == at then __fireOn(target, 'MouseEnter'); __fireOn(target, 'MouseButton1Down')
		elseif i == at + 3 then __fireOn(target, 'MouseButton1Up'); __fireOn(target, 'Activated')
		elseif i == at + 6 then __fireOn(target, 'MouseLeave') end
	end
	local function tabHit(id)
		local pill = g:FindFirstChild('Tab_' .. id, true)
		return pill and pill:FindFirstChild('Hit', true)
	end
	local luckAt, passAt = math.floor(N * 0.28), math.floor(N * 0.48)
	local luckHit, passHit
	for i = 0, N - 1 do
		if i == luckAt - 1 then luckHit, passHit = tabHit('Luck'), tabHit('Gamepass') end
		press(luckHit, luckAt, i)
		press(passHit, passAt, i)
		if i == math.floor(N * 0.66) then
			local block = g:FindFirstChild('Gamepass', true)
			for _, d in (block or g):GetDescendants() do
				if d.Name == 'Buy' then hit = d:FindFirstChild('Hit', true); break end
			end
			if hit then __fireOn(hit, 'MouseEnter') end
		elseif hit and i == math.floor(N * 0.74) then
			__fireOn(hit, 'MouseButton1Down')
		elseif hit and i == math.floor(N * 0.74) + 4 then
			__fireOn(hit, 'MouseButton1Up')
		elseif hit and i == math.floor(N * 0.88) then
			__fireOn(hit, 'MouseLeave')
		end
		local ok, err = pcall(__uiDump, g, UI_OUT .. ('/f_%03d.json'):format(i))
		if not ok then print('[ui] frame ' .. i .. ' failed ' .. tostring(err)); break end
		frame(1 / 30)
	end
	print('[ui] shopvideo: ' .. N .. ' frames' .. (luckHit and ' (Luck tab)' or ' (no Luck tab)') .. (passHit and ' (Gamepass tab)' or '') .. (hit and ' (hover and press on a Gamepass price)' or ' (no price button found)'))
end

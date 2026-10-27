-- shopvideo.luau (SCENE=shopvideo): the Shop's motion as frames, for a 30 fps video. It opens the Store the way the game
-- does (its Open event) and dumps HoodStore every 1/30 s of game time for FRAMES frames (default 210, 7 s) to
-- <UI_OUT>/f_NNN.json: the window's pop-in, the cards' stagger, the icons' idle motion (UIIdle), the shine sweeps, the
-- sparkles and the green buttons' glow. Half way, the mouse rests on the Featured card's price button (the hover pop) and
-- presses it (the squash; the purchase prompt is refused offline). shoot.js draws every frame; then, from the out dir:
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
	for i = 0, N - 1 do
		if i == math.floor(N * 0.55) then
			-- (the first big price button that breathes: the Featured card's)
			for _, d in g:GetDescendants() do
				if d.Name == 'Buy' and d:FindFirstChild('Breathe') then hit = d:FindFirstChild('Hit', true); break end
			end
			if hit then __fireOn(hit, 'MouseEnter') end
		elseif hit and i == math.floor(N * 0.7) then
			__fireOn(hit, 'MouseButton1Down')
		elseif hit and i == math.floor(N * 0.7) + 4 then
			__fireOn(hit, 'MouseButton1Up')
		elseif hit and i == math.floor(N * 0.85) then
			__fireOn(hit, 'MouseLeave')
		end
		local ok, err = pcall(__uiDump, g, UI_OUT .. ('/f_%03d.json'):format(i))
		if not ok then print('[ui] frame ' .. i .. ' failed ' .. tostring(err)); break end
		frame(1 / 30)
	end
	print('[ui] shopvideo: ' .. N .. ' frames' .. (hit and ' (hover and press on the Featured price)' or ' (no price button found)'))
end

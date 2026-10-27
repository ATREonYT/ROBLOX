-- (B35) Shared/Config/Limiteds: the special-sale spots' third line. PLACEHOLDER until the real global stock and sale-end
-- timer exist: the static sample shows only with the flag on AND in Studio; with the flag off the line is hidden and
-- empty, so no fake stock or timer can reach a live server.
return function(t)
	local RS = game:GetService('ReplicatedStorage')
	local Limiteds = require(RS.Shared.Config.Limiteds)

	local function fakeLine()
		local root = Instance.new('Folder')
		local row = {}
		for _, n in { 'LimitedStock', 'LimitedTimer' } do
			local l = Instance.new('TextLabel')
			l.Name = n
			l.Text = ''
			l.Visible = false
			l.Parent = root
			row[n] = l
		end
		return root, row
	end

	t.test('flag off: the line stays hidden and empty', function()
		local was = Limiteds.ShowPlaceholders
		Limiteds.ShowPlaceholders = false
		local root, row = fakeLine()
		row.LimitedStock.Text, row.LimitedStock.Visible = 'stale', true
		t.expect.equal(Limiteds.placeholdersOn(), false)
		t.expect.equal(Limiteds.applyPlaceholders(root), 0)
		t.expect.equal(row.LimitedStock.Visible, false)
		t.expect.equal(row.LimitedStock.Text, '')
		t.expect.equal(row.LimitedTimer.Text, '')
		Limiteds.ShowPlaceholders = was
	end)

	t.test('flag on: the static sample shows only where IsStudio is true, and never counts', function()
		local was = Limiteds.ShowPlaceholders
		Limiteds.ShowPlaceholders = true
		local okS, isS = pcall(function() return game:GetService('RunService'):IsStudio() end)
		local studio = okS and isS == true
		t.expect.equal(Limiteds.placeholdersOn(), studio)
		local root, row = fakeLine()
		Limiteds.applyPlaceholders(root)
		t.expect.equal(row.LimitedStock.Visible, studio)
		t.expect.equal(row.LimitedTimer.Visible, studio)
		t.expect.equal(row.LimitedStock.Text, studio and '37/100 LEFT' or '')
		t.expect.equal(row.LimitedTimer.Text, studio and '23:59:59' or '')
		Limiteds.applyPlaceholders(root) -- (a second pass writes the same words: nothing decreases)
		t.expect.equal(row.LimitedStock.Text, studio and '37/100 LEFT' or '')
		Limiteds.ShowPlaceholders = was
	end)
end

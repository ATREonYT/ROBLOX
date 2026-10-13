-- (brief 28, STAGE28) The box opening's set (Shared/UnboxStage, "The Corner"): every set, the egg one and the Secret one
-- dressed in each of the 12 box themes, for a single box, the welcome gift's two, a Buy 3 and a Buy 8, stays inside the
-- phone budget (<= 250 parts, <= 3 PointLights), is anchored and untouchable, and keeps the anchor contract UnboxCinematic
-- reads (the pad, the floor, the posters and words, the sign, the lamps, the speakers, the box light, the volumes);
-- framePosters keeps the posters on their walls and no word cut by the frame's edge, floorAt finds the pad, the riser,
-- the walks and the road, night() puts every lit part back, the low close camera's ground in front of the pad stays
-- clear, and nothing is left behind when the folder goes.
return function(t)
	local RS = game.ReplicatedStorage
	local Stage = require(RS.Shared.UnboxStage)
	local Themes = require(RS.Shared.UnboxThemes)
	local e = t.expect
	local V3, CF = Vector3.new, CFrame.new
	local AT = CF(-2600, 250, -2600)
	-- the plan's layouts (UnboxCinematic's: pad radius, the Buy 8's riser)
	local LAYOUTS = {
		{ n = 1, padR = 6.7 },
		{ n = 2, padR = 9.4 },
		{ n = 3, padR = 14.65 },
		{ n = 8, padR = 14, riser = { w = 6.65 * 4 + 6, h = 1.6, d = 5.6, z = 5.2 } },
	}
	local function newJob(box, layout, premium)
		local folder = Instance.new('Folder')
		folder.Name = 'HoodUnboxStage'
		folder.Parent = workspace
		local P = { n = layout.n, padR = layout.padR, riser = layout.riser, G = 1.33, premium = premium == true, theme = Themes.get(box), box = box }
		return { P = P, folder = folder, O = AT, park = AT * CF(0, -400, 0) }
	end
	local function done(job) job.folder:Destroy() end

	t.test('every set (egg and Secret, 12 themes, single / gift / Buy 3 / Buy 8) is <= 250 parts and <= 3 PointLights', function()
		local worst = 0
		for _, box in Themes.Ids do
			for _, layout in LAYOUTS do
				for _, kind in { 'egg', 'secret' } do
					local job = newJob(box, layout, kind == 'secret')
					Stage.build(job, kind)
					local parts, lights = Stage.count(job)
					worst = math.max(worst, parts)
					e.truthy(parts <= Stage.MaxParts)
					e.truthy(lights <= Stage.MaxLights)
					e.equal(job.setParts, parts)
					e.equal(job.setKind, kind)
					done(job)
				end
			end
		end
		e.truthy(worst > 150) -- (and it is a real set, not an empty one)
	end)

	t.test('every part is anchored, untouchable and unqueryable; only the big blocks cast shadows', function()
		local job = newJob('Grail', LAYOUTS[4], true)
		Stage.build(job, 'secret')
		local shadows = 0
		for _, d in job.folder:GetDescendants() do
			if d:IsA('BasePart') then
				e.truthy(d.Anchored)
				e.falsy(d.CanCollide)
				e.falsy(d.CanTouch)
				e.falsy(d.CanQuery)
				if d.CastShadow then shadows += 1 end
			end
		end
		e.truthy(shadows <= 45)
		done(job)
	end)

	t.test('the anchor contract: pad, floor, posters, words, sign, lamps, speakers, box light, volumes, marks', function()
		for _, kind in { 'egg', 'secret' } do
			local job = newJob('Street', LAYOUTS[1], kind == 'secret')
			Stage.build(job, kind)
			e.truthy(job.anchor and job.anchor:IsA('BasePart') and job.anchor.Transparency == 1)
			e.near((job.anchor.CFrame.Position - AT.Position).Magnitude, 0, 1e-4)
			e.near(job.deckY, AT.Y, 1e-6)
			e.near(job.padTop, AT.Y + 0.22, 1e-6)
			e.truthy(job.padRim:IsA('BasePart') and job.padRim.Material == Enum.Material.Neon)
			local pad = job.folder:FindFirstChild('Pad')
			e.truthy(pad and pad:IsA('BasePart'))
			e.near(pad.CFrame.Position.Y + pad.Size.X / 2, job.padTop, 0.01) -- (a standing cylinder: its height is Size.X)
			e.truthy(#job.posterParts >= 4)
			e.equal(#job.wordParts, 2)
			e.equal(#job.posterLabels, 2)
			for _, l in job.posterLabels do
				e.truthy(l[1]:IsA('TextLabel') and l[2]:IsA('UIStroke'))
			end
			e.equal(#job.posterGroups, 2)
			for _, g in job.posterGroups do e.truthy(g.word and #g.parts >= 2) end
			e.truthy(job.wallInfo and job.wallInfo.face and job.wallInfo.w > 0 and job.wallInfo.h > 0)
			e.truthy(#job.signParts >= 1)
			e.equal(#job.signNeon, 4)
			e.truthy(job.signText:IsA('TextLabel') and job.signStroke:IsA('UIStroke'))
			e.equal(#job.lamps, 2)
			for _, l in job.lamps do
				e.truthy(l.head:IsA('BasePart') and l.light:IsA('PointLight') and typeof(l.color) == 'Color3')
			end
			e.truthy(#job.speakers >= 1)
			e.truthy(job.boxGlow:IsA('BasePart') and job.boxLight:IsA('PointLight'))
			for _, name in { 'back', 'sky', 'floor', 'around' } do
				e.truthy(job.volumes[name] and job.volumes[name]:IsA('BasePart') and job.volumes[name].Transparency == 1)
			end
			for _, name in { 'egg', 'heroLeft', 'heroRight', 'wide' } do
				local m = job.marks[name]
				e.truthy(m and typeof(m.eye) == 'Vector3' and typeof(m.at) == 'Vector3' and m.fov > 0)
				e.truthy(m.eye.Z < 0) -- (the camera stays on the -Z side, looking at the pad and down the street)
			end
			done(job)
		end
		-- a Buy 8 gets its riser, a single none
		local job = newJob('Galaxy', LAYOUTS[4])
		Stage.build(job)
		e.equal(job.riser, job.P.riser)
		e.truthy(job.folder:FindFirstChild('Riser'))
		e.equal(job.setKind, 'egg')
		done(job)
	end)

	t.test('the speakers bump about their base and come back to their exact sizes', function()
		local job = newJob('Street', LAYOUTS[1])
		Stage.build(job)
		local sp = job.speakers[1]
		local sizes = {}
		for i, p in sp.actor.parts do sizes[i] = p.Size end
		local cf0 = sp.actor.parts[1].CFrame
		sp.actor:pose(sp.base, 1.05)
		e.truthy(sp.actor.parts[1].Size.X > sizes[1].X)
		sp.actor:pose(sp.base, 1)
		for i, p in sp.actor.parts do e.truthy((p.Size - sizes[i]).Magnitude < 1e-4) end
		e.truthy((sp.actor.parts[1].CFrame.Position - cf0.Position).Magnitude < 1e-4)
		done(job)
	end)

	t.test('floorAt: the pad, the riser, the plaza and the roads a kerb below it', function()
		local job = newJob('Galaxy', LAYOUTS[4])
		Stage.build(job)
		local floor = Stage.floorAt(job)
		local L = job.layout
		e.near(floor((AT * CF(0, 5, -2)).Position), job.padTop, 1e-6)
		e.near(floor((AT * CF(0, 5, job.P.riser.z)).Position), job.deckY + job.P.riser.h, 1e-6)
		e.near(floor((AT * CF(L.RW + 2, 5, 3)).Position), job.deckY, 1e-6)
		e.near(floor((AT * CF(-(L.RW + 2), 5, -job.P.padR - 1)).Position), job.deckY, 1e-6)
		e.near(floor((AT * CF(3, 5, L.ZC - 3)).Position), job.deckY - L.KERB, 1e-6)
		e.near(floor((AT * CF(0, 5, L.ZS + 10)).Position), job.deckY - L.KERB, 1e-6)
		done(job)
	end)

	t.test('framePosters slides each side\'s posters along its own wall, never off it, and never leaves a word cut by the frame\'s edge', function()
		local tx = math.tan(math.rad(25)) * 16 / 9
		local cams = {
			{ V3(3.6, 7, -13.5), V3(0, 6.5, 0) }, { V3(-5.1, 8, -14), V3(0, 7.5, 0) }, { V3(-5.1, 11.8, -14), V3(0, 11.8, 0) },
			{ V3(-1.3, 8, -14.9), V3(0, 7.5, 0) }, { V3(0, 3.3, -15.5), V3(0, 2.6, 0) },
		}
		for _, cam in cams do
			local job = newJob('Graffiti', LAYOUTS[1], true)
			Stage.build(job, 'secret')
			local cf = CFrame.lookAt((AT * CF(cam[1])).Position, (AT * CF(cam[2])).Position)
			Stage.framePosters(job, cf, 50, 16 / 9, 0.22)
			for _, g in job.posterGroups do
				local x0, x1, y0, y1 = Stage.extents(AT, g.parts)
				e.truthy(x0 >= g.x0 - 0.01 and x1 <= g.x1 + 0.01)
				e.truthy(y0 >= g.y0 - 0.01 and y1 <= g.y1 + 0.01)
				for _, p in g.parts do
					e.near(AT:PointToObjectSpace(p.CFrame.Position).Z, job.wallInfo.face, 0.2) -- (still on the wall's face)
				end
				-- (the word whole in the frame or whole out of it)
				local q = cf:PointToObjectSpace(g.word.CFrame.Position)
				local c, h = math.abs(q.X / (-q.Z * tx)), g.word.Size.X * 0.5 / (-q.Z * tx)
				e.truthy(c + h <= 1 or c - h >= 1)
			end
			done(job)
		end
	end)

	t.test('night lights a few windows, dims the floor, lights the bulbs only on request, and puts every part back', function()
		local job = newJob('Galaxy', LAYOUTS[1], true)
		Stage.build(job, 'secret')
		local before, glows, dims, bulbs = {}, 0, 0, 0
		for i, n in job.nightParts do
			before[i] = { n[1].Color, n[1].Material, n[1].Transparency }
			if n.kind == 'dim' then dims += 1 elseif n.kind == 'bulb' then bulbs += 1 else glows += 1 end
		end
		e.truthy(dims >= 4 and bulbs >= 4 and glows >= 4)
		local gui = job.signText.Parent
		e.equal(gui.LightInfluence, 0)
		local words = {}
		for i, l in job.posterLabels do words[i] = l[1].TextColor3 end
		local signWords = job.signText.TextColor3
		Stage.night(job, 1)
		for i, n in job.nightParts do
			if n.kind == 'dim' then
				e.truthy(n[1].Color.R < before[i][1].R and n[1].Material == before[i][2])
			elseif n.kind == 'bulb' then
				e.equal(n[1].Material, before[i][2]) -- (the string lights stay off unless asked)
			else
				e.equal(n[1].Material, Enum.Material.Neon)
				e.truthy(n[1].Transparency < 1)
			end
		end
		e.equal(gui.LightInfluence, 1)
		for _, p in job.signNeon do e.equal(p.Material, Enum.Material.SmoothPlastic) end
		Stage.night(job, 1, 0.35)
		for _, n in job.nightParts do
			if n.kind == 'bulb' then e.equal(n[1].Material, Enum.Material.Neon) end
		end
		Stage.night(job, 0.5)
		Stage.night(job, 0)
		for i, n in job.nightParts do
			e.equal(n[1].Color, before[i][1])
			e.equal(n[1].Material, before[i][2])
			e.equal(n[1].Transparency, before[i][3])
		end
		e.equal(gui.LightInfluence, 0)
		for _, p in job.signNeon do e.equal(p.Material, Enum.Material.Neon) end
		for i, l in job.posterLabels do e.equal(l[1].TextColor3, words[i]) end
		e.equal(job.signText.TextColor3, signWords)
		done(job)
	end)

	t.test('the egg set never echoes the box: a pale pad lip, the hood\'s own poster colours and words', function()
		for _, box in { 'Street', 'Graffiti', 'Lava', 'Galaxy' } do
			local th = Themes.get(box)
			local job = newJob(box, LAYOUTS[1])
			Stage.build(job, 'egg')
			local _, s = job.padRim.Color:ToHSV()
			e.truthy(s <= 0.2)
			e.equal(job.posterLabels[1][1].Text, 'KICKS')
			e.equal(job.posterLabels[2][1].Text, 'HOOD')
			for _, p in job.posterParts do e.truthy(p.Color ~= th.Color) end
			Stage.dress(job)
			e.equal(job.padRim.Color, th.Rim)
			e.equal(job.posterLabels[1][1].Text, th.Tags[2])
			e.equal(job.posterLabels[2][1].Text, th.Tags[1])
			done(job)
		end
	end)

	t.test('dress turns the egg set into the Secret set once, in place, inside the budget', function()
		for _, box in Themes.Ids do
			local job = newJob(box, LAYOUTS[1])
			Stage.build(job, 'egg')
			local egg = Stage.count(job)
			Stage.dress(job)
			local dressed = Stage.count(job)
			Stage.dress(job)
			e.equal(Stage.count(job), dressed)
			e.truthy(dressed > egg and dressed - egg <= 35 and dressed <= Stage.MaxParts)
			local other = newJob(box, LAYOUTS[1], true)
			Stage.build(other, 'secret')
			e.equal(Stage.count(other), dressed)
			done(job)
			done(other)
		end
	end)

	t.test('the low close camera\'s ground in front of the pad (z -14 to -5, |x| < 7) stays clear in every set', function()
		-- (the Secret's charge shot stands there, looking up at the box: nothing but the floor and flat things on it)
		for _, box in Themes.Ids do
			for _, layout in LAYOUTS do
				for _, kind in { 'egg', 'secret' } do
					local job = newJob(box, layout, kind == 'secret')
					Stage.build(job, kind)
					local floorAt = Stage.floorAt(job)
					for _, p in job.folder:GetDescendants() do
						if p:IsA('BasePart') and p.Transparency < 0.95 and string.sub(p.Name, 1, 6) ~= 'Volume' then
							local cf, h = AT:ToObjectSpace(p.CFrame), p.Size / 2
							local x0, x1, z0, z1, top = math.huge, -math.huge, math.huge, -math.huge, -math.huge
							for _, a in { -1, 1 } do for _, b in { -1, 1 } do for _, c in { -1, 1 } do
								local q = (cf * CF(h.X * a, h.Y * b, h.Z * c)).Position
								x0, x1, z0, z1, top = math.min(x0, q.X), math.max(x1, q.X), math.min(z0, q.Z), math.max(z1, q.Z), math.max(top, q.Y)
							end end end
							if z1 > -14 and z0 < -5 and x1 > -7 and x0 < 7 then
								local under = AT:PointToObjectSpace(V3(0, floorAt((AT * CF(math.clamp(0, x0, x1), 0, math.clamp(-9, z0, z1))).Position), 0)).Y
								e.truthy(top <= under + 0.3)
							end
						end
					end
					done(job)
				end
			end
		end
	end)

	t.test('the set lives in the job folder: destroying it leaves nothing behind', function()
		local n0 = #workspace:GetDescendants()
		local job = newJob('Exclusive', LAYOUTS[3], true)
		Stage.build(job, 'secret')
		Stage.night(job, 1)
		e.truthy(#workspace:GetDescendants() > n0)
		job.folder:Destroy()
		e.equal(#workspace:GetDescendants(), n0)
	end)
end

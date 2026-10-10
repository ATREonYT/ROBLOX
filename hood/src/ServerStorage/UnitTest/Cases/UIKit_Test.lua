-- (brief 23, UI5) Uploaded images that never arrive (still in review, or rejected): the owner's Studio showed the World,
-- Shoes, Guns and Items squares blank. Kit.icon3d, Kit.robux and Kit.splat must swap such an image for its stand-in (brief
-- 24: the FLAT 2D stand-in, never a 3D model; the frame mark; the blobs), and keep an image that loads. Kit.Preloader is
-- replaced here, so these run the same in Studio and offline.
return function(t)
	local RS = game.ReplicatedStorage
	local Kit = require(RS.Shared.UIKit)
	local e = t.expect
	local seq = 0
	-- a content id no other test or screen has used (Kit.ImageStatus remembers each id's verdict)
	local function freshId()
		seq += 1
		return 'rbxassetid://' .. tostring(900000000000 + math.floor(os.clock() * 1000) % 100000000 * 100 + seq)
	end
	local function with(preloader, fn)
		local was, wait, grace, loaded = Kit.Preloader, Kit.ImageWait, Kit.ImageGrace, Kit.IsLoaded
		Kit.Preloader = preloader
		local ok, err = pcall(fn)
		Kit.Preloader, Kit.ImageWait, Kit.ImageGrace, Kit.IsLoaded = was, wait, grace, loaded
		assert(ok, err)
	end
	local function answers(status) return function(content, callback) callback(content, status) end end
	local function live(holder)
		return holder:FindFirstChild('Flat') ~= nil
	end
	local function viewports(holder)
		local n = 0
		for _, d in holder:GetDescendants() do
			if d:IsA('ViewportFrame') then n += 1 end
		end
		return n
	end

	t.test('an icon whose upload fails shows its flat 2D stand-in, never a blank square and never a 3D model', function()
		local models = Kit.iconModels()
		e.truthy(models and type(models.Images) == 'table')
		local saved = models.Images.World
		models.Images.World = freshId()
		with(answers(Enum.AssetFetchStatus.Failure), function()
			-- (brief 25) by default the stand-in is the bare glyph: no tile on a tile
			local plain = Kit.icon3d('World', 64)
			e.falsy(plain.Image.Visible)
			e.truthy(live(plain))
			e.falsy(plain.Flat:FindFirstChild('Block'))
			e.truthy(plain.Flat:FindFirstChild('Glyph'))
			local first = Kit.icon3d('World', 64, { Bare = false })
			e.falsy(first.Image.Visible)
			e.truthy(live(first))
			e.equal(viewports(first), 0)
			-- asked for (Bare = false): a rounded block in the icon's colour with the ink outline, and its glyph on top
			local block = first.Flat:FindFirstChild('Block')
			e.truthy(block)
			e.truthy(block:FindFirstChildOfClass('UICorner'))
			local ink = block:FindFirstChildOfClass('UIStroke')
			e.truthy(ink and ink.Color == Kit.FlatInk)
			e.truthy(first.Flat:FindFirstChild('Glyph'))
			local again = Kit.icon3d('World', 64) -- (the verdict is remembered: straight to the stand-in)
			e.falsy(again.Image.Visible)
			e.truthy(live(again))
		end)
		models.Images.World = saved
	end)

	t.test('an icon whose upload loads keeps its image and builds no model', function()
		local models = Kit.iconModels()
		local saved = models.Images.Gun
		models.Images.Gun = freshId()
		with(answers(Enum.AssetFetchStatus.Success), function()
			local h = Kit.icon3d('Gun', 64)
			e.truthy(h.Image.Visible)
			e.falsy(live(h))
		end)
		models.Images.Gun = saved
	end)

	t.test('no answer after Kit.ImageWait: the stand-in shows', function()
		local models = Kit.iconModels()
		local saved = models.Images.Backpack
		models.Images.Backpack = freshId()
		with(function() end, function()
			Kit.ImageWait = 0.05
			local h = Kit.icon3d('Backpack', 64)
			e.truthy(h.Image.Visible)
			task.wait(0.3)
			e.falsy(h.Image.Visible)
			e.truthy(live(h))
		end)
		models.Images.Backpack = saved
	end)

	t.test('on screen and not drawn after Kit.ImageGrace: the stand-in at once, the image back when the fetch succeeds', function()
		local models = Kit.iconModels()
		local saved = models.Images.Quest
		local content = freshId()
		models.Images.Quest = content
		local answer
		local gui = Instance.new('ScreenGui')
		gui.Parent = workspace
		with(function(_, callback) answer = callback end, function()
			Kit.ImageGrace = 0.05
			Kit.IsLoaded = function(label) return label.Image ~= content end
			local h = Kit.icon3d('Quest', 64)
			h.Parent = gui
			e.truthy(h.Image.Visible)
			task.wait(0.25)
			e.falsy(h.Image.Visible)
			e.truthy(live(h))
			e.truthy(answer)
			answer(content, Enum.AssetFetchStatus.Success)
			e.truthy(h.Image.Visible)
			e.falsy(live(h))
		end)
		gui:Destroy()
		models.Images.Quest = saved
	end)

	t.test('the Robux mark and the splat fall back to frames when their uploads fail', function()
		local models = Kit.iconModels()
		local savedRobux, savedSplat = models.Images.Robux, Kit.Splat
		models.Images.Robux = freshId()
		Kit.Splat = freshId()
		with(answers(Enum.AssetFetchStatus.Failure), function()
			local mark = Kit.robux(24)
			e.falsy(mark.Glyph.Visible)
			e.truthy(mark:FindFirstChild('Edge1'))
			local splat = Kit.splat(60, Color3.new(1, 0, 0))
			e.falsy(splat.Image.Visible)
			e.truthy(splat:FindFirstChild('Blob1'))
		end)
		models.Images.Robux, Kit.Splat = savedRobux, savedSplat
	end)

	-- (brief 24) "the UI shouldn't look 3D": nothing uploaded, every icon is a flat stand-in from IconModels.Fallback (or
	-- Kit.FlatDefault), the families from Config, a block with the ink outline and a glyph; no ViewportFrame anywhere.
	t.test('with no upload every icon is a flat stand-in: a block, its glyph, no ViewportFrame', function()
		local models = Kit.iconModels()
		for _, id in { 'Power', 'Cash', 'World', 'Shoe_RedRocket', 'Box_Street', 'Gun_Uzi', 'Lucky', 'NoSuchIcon' } do
			local saved = models.Images[id]
			models.Images[id] = nil
			local h = Kit.icon3d(id, 64, { Bare = false })
			e.truthy(live(h))
			e.equal(viewports(h), 0)
			e.truthy(h.Flat:FindFirstChild('Block'))
			e.truthy(h.Flat:FindFirstChild('Glyph'))
			models.Images[id] = saved
		end
	end)
	t.test('stand-ins take their colours from the row or the family', function()
		local Shoes = require(game.ReplicatedStorage.Shared.Config.Shoes)
		local Guns = require(game.ReplicatedStorage.Shared.Config.Guns)
		local shoe = Kit.flatSpec('Shoe_RedRocket')
		e.equal(shoe.Glyph, 'shoe')
		e.truthy(shoe.Ink == Shoes.ById.RedRocket.Colors.Main)
		e.truthy(shoe.Color == Shoes.RarityById[Shoes.ById.RedRocket.Rarity].Color)
		local box = Kit.flatSpec('Box_Graffiti')
		e.equal(box.Glyph, 'box')
		e.truthy(box.Color == Shoes.BoxById.Graffiti.Color)
		e.truthy(Kit.flatSpec('Gun_Deagle').Color == Guns.ById.Deagle.Color)
		e.equal(Kit.flatSpec('Gun_Deagle').Glyph, 'gun')
		local other = Kit.flatSpec('NoSuchIcon')
		e.equal(other.Glyph, 'text')
		e.equal(other.Text, 'N')
		-- every glyph a row names is one UIKit draws
		for id, row in Kit.FlatDefault do
			e.truthy(row.Glyph == 'text' or row.Glyph == 'star' or Kit.Glyphs[row.Glyph] ~= nil)
		end
		local rows = Kit.iconModels() and Kit.iconModels().Fallback
		if type(rows) == 'table' then
			for id, row in rows do
				e.truthy(typeof(row.Color) == 'Color3')
				e.truthy(row.Glyph == 'text' or row.Glyph == 'star' or Kit.Glyphs[row.Glyph] ~= nil)
			end
		end
	end)
	t.test('a bare stand-in has no block; a locked one is dark; locking after the fact rebuilds it', function()
		local models = Kit.iconModels()
		local saved = models.Images.Shoe_Checkmate
		models.Images.Shoe_Checkmate = nil
		local bare = Kit.icon3d('Shoe_Checkmate', 80, { Bare = true })
		e.falsy(bare.Flat:FindFirstChild('Block'))
		e.truthy(bare.Flat:FindFirstChild('Glyph'))
		local dark = Kit.icon3d('Shoe_Checkmate', 80, { Locked = true, Bare = false })
		e.truthy(dark.Flat.Block:FindFirstChildOfClass('UIGradient') ~= nil)
		Kit.setLocked(bare, true)
		e.truthy(live(bare))
		e.falsy(bare.Flat:FindFirstChild('Block'))
		models.Images.Shoe_Checkmate = saved
	end)

	-- (brief 25) "not in place, especially the pictures": a picture placed on a button by a Kit.Place rule fills the
	-- reference's box by its DRAWN content (IconModels.Bounds, or the stand-in's glyph), pops out over the top, and is bare
	t.test('a placed picture fills the reference box by its drawn content and pops out; its stand-in is bare', function()
		local models = Kit.iconModels()
		local rule = Kit.Place.hud
		e.truthy(rule)
		local function contentOf(h, b)
			local s = h.Size.X.Offset
			return h.Position.X.Offset + b[1] * s, h.Position.Y.Offset + b[2] * s, (b[3] - b[1]) * s, (b[4] - b[2]) * s
		end
		-- a wide PNG (a gun: 0.88 x 0.72 of its square)
		local savedImg, savedB = models.Images.Gun, models.Bounds
		models.Images.Gun = freshId()
		models.Bounds = { Gun = { 0.059, 0.141, 0.941, 0.859 } }
		with(answers(Enum.AssetFetchStatus.Success), function()
			local h = Kit.icon3d('Gun', nil, { Place = { Rule = 'hud', W = 81, H = 81 } })
			local x, y, w, hh = contentOf(h, models.Bounds.Gun)
			e.truthy(math.abs(w - rule.W * 81) < 1.5) -- (as wide as the reference's globe; whole pixels)
			e.truthy(hh <= rule.H * 81 + 1.5)
			e.truthy(y <= rule.Top * 81 + 1.5) -- (over the square's top)
			e.truthy(math.abs(x + w / 2 - 40.5) < 1.5) -- (centred)
		end)
		models.Images.Gun, models.Bounds = savedImg, savedB
		-- no upload: the bare glyph, placed the same way
		local saved = models.Images.Backpack
		models.Images.Backpack = nil
		local h = Kit.icon3d('Backpack', nil, { Place = { Rule = 'hud', W = 81, H = 81 } })
		e.truthy(live(h))
		e.truthy(h.Flat:GetAttribute('Bare'))
		e.falsy(h.Flat:FindFirstChild('Block'))
		local x, y, w, hh = contentOf(h, Kit.contentBounds('Backpack', false, true))
		e.truthy(y < 0)
		e.truthy(w <= rule.W * 81 + 1.5 and hh <= rule.H * 81 + 1.5)
		models.Images.Backpack = saved
	end)
end

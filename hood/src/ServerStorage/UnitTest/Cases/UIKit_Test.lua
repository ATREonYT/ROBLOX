-- (brief 23, UI5) Uploaded images that never arrive (still in review, or rejected): the owner's Studio showed the World,
-- Shoes, Guns and Items squares blank. Kit.icon3d, Kit.robux and Kit.splat must swap such an image for its stand-in (the
-- live 3D model, the frame mark, the blobs), and keep an image that loads. Kit.Preloader is replaced here, so these run
-- the same in Studio and offline.
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
		return holder:FindFirstChild('Model3D') ~= nil or holder:FindFirstChild('Fallback') ~= nil
	end

	t.test('an icon whose upload fails shows its live 3D model, never a blank square', function()
		local models = Kit.iconModels()
		e.truthy(models and type(models.Images) == 'table')
		local saved = models.Images.World
		models.Images.World = freshId()
		with(answers(Enum.AssetFetchStatus.Failure), function()
			local first = Kit.icon3d('World', 64)
			e.falsy(first.Image.Visible)
			e.truthy(first:FindFirstChild('Model3D'))
			local again = Kit.icon3d('World', 64) -- (the verdict is remembered: straight to the model)
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

	t.test('on screen and not drawn after Kit.ImageGrace: the model at once, the image back when the fetch succeeds', function()
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
end

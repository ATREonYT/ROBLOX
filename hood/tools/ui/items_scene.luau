-- items_scene.luau (render_items.sh runs it in render14's harness): builds every item that has no picture in
-- hood/art/icons3d yet (shoes as pairs, shoe boxes closed) side by side in an empty Workspace, from the same builders the
-- game uses (Shared/Models ShoeModels.pair, BoxModels.build), and writes a camera view per item to VIEWS for render14's
-- shoot.js. Globals set in front of this chunk: VIEWS (the views file), ICONS (hood/art/icons3d), ALL (true: every
-- item again, not only the missing ones).
local RS = game:GetService('ReplicatedStorage')
local ShoeModels = require(RS.Shared.Models.ShoeModels)
local BoxModels = require(RS.Shared.Models.BoxModels)
local Shoes = require(RS.Shared.Config.Shoes)
local views = {}
local x = 0
local CORNERS = { Vector3.new(-1, -1, -1), Vector3.new(1, 1, 1), Vector3.new(-1, 1, -1), Vector3.new(1, -1, 1), Vector3.new(1, 1, -1), Vector3.new(-1, -1, 1), Vector3.new(1, -1, -1), Vector3.new(-1, 1, 1) }
local function bounds(model)
	local lo, hi
	for _, p in model:GetDescendants() do
		if p:IsA('BasePart') and p.Transparency < 1 then
			local h = p.Size / 2
			for _, c in CORNERS do
				local w = p.CFrame * Vector3.new(h.X * c.X, h.Y * c.Y, h.Z * c.Z)
				lo = lo and Vector3.new(math.min(lo.X, w.X), math.min(lo.Y, w.Y), math.min(lo.Z, w.Z)) or w
				hi = hi and Vector3.new(math.max(hi.X, w.X), math.max(hi.Y, w.Y), math.max(hi.Z, w.Z)) or w
			end
		end
	end
	return lo, hi
end
local function place(model, name)
	local at = CFrame.new(x, 0, 0)
	for _, p in model:GetDescendants() do
		if p:IsA('BasePart') then p.CFrame = at * p.CFrame end
	end
	model.Parent = workspace
	local lo, hi = bounds(model)
	if not lo then return end
	local c = (lo + hi) / 2
	local r = (hi - lo).Magnitude / 2
	-- the icons' camera: front-left and a little above (the toes / the box's front face are -Z), a long lens
	local dir = Vector3.new(-0.62, 0.62, -1).Unit
	local fov = 26
	local dist = r / math.sin(math.rad(fov / 2)) * 1.02
	local pos = c + dir * dist
	table.insert(views, { name = name, pos = { pos.X, pos.Y, pos.Z }, look = { c.X, c.Y, c.Z }, fov = fov })
	x += math.max(40, (hi - lo).X + 30)
end
local need = {}
for id in Shoes.ById do table.insert(need, 'Shoe_' .. id) end
for k, b in Shoes.Boxes do table.insert(need, 'Box_' .. tostring(type(b) == 'table' and b.Id or k)) end
table.sort(need)
for _, name in need do
	if not ALL and __fs.isFile(ICONS .. '/' .. name .. '.png') then continue end
	local kind, id = string.match(name, '^(%a+)_(.+)$')
	local ok, m = pcall(function()
		if kind == 'Shoe' then return ShoeModels.pair(id, 1) end
		return BoxModels.build(id, 1)
	end)
	if ok and m then place(m, name) else print('[items] could not build ' .. name .. ': ' .. tostring(m)) end
end
__fs.writeFile(VIEWS, __serde.encode('json', { options = { transparent = true, lighting = 'HoodToy', time = 3, bloom = false, lights = 0 }, views = views }))
print('[items] views: ' .. #views)

--[[
	Catchers hold a knife in their right hand (as in the reference); everyone else wears theirs, always: lobby,
	runner, waiting (owner: "the catchers run with a knife, and everyone even the runners have a knife mounted on
	their backs"; Oct 18: "make the knifes please be equipped when you have them, like be shown on the back of the
	character"; "or even for the katanas you can make it be on the side of the person"). Oct 19: "make the knifes when equipped be worn either on the back of the character or on the side ... based on
	what knife/sword it is". Worn = long blades diagonal across the back, short knives at the right hip, as the shop
	table says (Config/CoinShop Wear, Shared/KnifeLook.wearOf); over a cape or long hair, at the hip under big wings
	(refit when an accessory loads in later). It's the knife skin you wear
	(Shared/KnifeLook.pick: the one picked in the shop, else your first owned knife, else the default knife).
	ONE knife per body: KnifeService.give (hand) and giveBack (worn) each remove the other first, so drawing it moves
	it from the back to the hand and the round's end puts it back. It's a model welded on by the server (everyone
	sees it), not a Tool, so there's nothing to equip or drop and no backpack. HuzzClient/Gameplay/Actions plays the
	stab and lights the blade's trail. RoundService.syncPlayer calls give/giveBack on every change and on spawn;
	Bootstrap's DataService.onChanged swaps the skin the moment you pick another in the shop.

	The owner's own knives (Oct 18, 30 models in design/knives/Knives): once he has imported them and run the setup
	(tools/knives/setup_knives.lua, also ServerStorage/HuzzStudioTools/SetupKnives), each skin is a Model in
	ServerStorage/HuzzKnives/<skin key> with an invisible part "Handle" (+Y to the tip, X the blade's thin way) and
	Attachments "Grip" (where the fist closes), "TrailBase" (guard) and "TrailTip" (tip). It's used as it is: already
	at its length, its glowing parts already Neon, plus a hidden plain cut of it that a screen shows where his
	uploaded meshes don't load (addBackup, Gameplay/KnifeMeshCheck: the live game, Oct 20 15:13). Until then (or for a skin with no model) the game draws its own
	knife below, painted in the skin's colours (Config/CoinShop Colors, Neon guard in its Glow colour), so nothing
	ever looks broken. A Model named "HuzzKnife" (in HuzzKnives, or ServerStorage as before) replaces the default.
	The five Game Pass knives get a better stand-in (owner, Oct 19: "right now its very small and you dont even
	notice it"): their card's shape from plain parts at their real length (Shared/KnifeShapes, buildRecipe).

	Oct 19 too: the lobby stands' copy (display) is scaled up to KnifeLook.STAND.Length (scale: by hand, no ScaleTo);
	a Game Pass knife's slash trail takes its element's colours (KnifeLook.ELEMENTS).
	Round 2 ("in the reference the knife is the first thing you see"): its slash starts halfway up the blade
	(StandTrailBase). In hand a long blade is held more forward (KnifeLook.handC0 with its reach) so its tip never
	goes into the floor. (The stand copy was also widened and wore a see-through Neon GlowShell, and every knife from
	Uncommon up had a white sheen glint: all three hid his model, owner Oct 19: "they dont look as good as in the glb
	file". Gone: every knife, worn, held or on a stand, is his model as it is, only scaled evenly.)

	Effects by rarity and theme (owner, Oct 20: "make the vfx for some swords way better and more detailed, make them
	better for more high end ones" ... "check out the references provided from Huss valley"): Shared/KnifeLook.vfx's
	numbers, built by Shared/KnifeFx once per knife (replicated), nothing runs every frame. Common and Uncommon stay
	plain; Rare a few motes; Epic its motif too; Legendary, Mythic and the pass knives the full theme. In hand the
	most, on a stand a little more, worn a lighter share (HuzzClient/Gameplay/KnifeFxRange switches worn ones off
	for far-away players).
	Where it sits: Shared/KnifeLook (hand: today's grip, offset by the model's Grip; worn: backC0 / sideC0, also on
	the model's Grip; its "Reach", how far its farthest piece is from the grip, lets each screen's
	HuzzClient/Gameplay/KnifeGuard hide a worn knife or piece that ends up off the body). A model in HuzzKnives whose size doesn't match its length (8 of the owner's Oct 18 file came
	out of the setup about 10 times too big and lying sideways) is not used: that skin shows our own knife in its
	colours instead, with one warning in Output, until the model is fixed.
]]
local ServerStorage = game:GetService("ServerStorage")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local KnifeLook = require(ReplicatedStorage.Shared.KnifeLook)
local KnifeShapes = require(ReplicatedStorage.Shared.KnifeShapes)
local KnifeFx = require(ReplicatedStorage.Shared.KnifeFx)

local KnifeService = {}
local NAME = "HuzzKnife"
local WHITE = Color3.new(1, 1, 1)

local function part(class, props)
	local p = Instance.new(class)
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.Massless = false, false, false, false, true
	p.CastShadow = false
	p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	for k, v in props do
		p[k] = v
	end
	return p
end

local function weld(a, b)
	local w = Instance.new("WeldConstraint")
	w.Part0, w.Part1 = a, b
	w.Parent = b
end

-- A dagger: dark grip with a pommel, a steel guard, a slim blade with a pointed tip.
local function build()
	local model = Instance.new("Model")
	local dark, steel = Color3.fromRGB(32, 30, 38), Color3.fromRGB(205, 212, 224)
	local handle = part("Part", { Name = "Handle", Size = Vector3.new(0.22, 0.75, 0.26), Color = dark, Material = Enum.Material.SmoothPlastic, Parent = model })
	local function add(class, props, offset)
		local p = part(class, props)
		p.CFrame = handle.CFrame * offset
		p.Parent = model
		weld(handle, p)
		return p
	end
	add("Part", { Name = "Pommel", Size = Vector3.new(0.26, 0.12, 0.3), Color = steel, Material = Enum.Material.Metal }, CFrame.new(0, -0.42, 0))
	add("Part", { Name = "Guard", Size = Vector3.new(0.24, 0.1, 0.62), Color = steel, Material = Enum.Material.Metal }, CFrame.new(0, 0.42, 0))
	local blade = add("Part", { Name = "Blade", Size = Vector3.new(0.07, 1.05, 0.3), Color = steel, Material = Enum.Material.Metal, Reflectance = 0.15 }, CFrame.new(0, 0.995, 0.02))
	-- WedgePart: its tall edge is at +Z, so the point sits over the blade's back (a dagger tip).
	add("WedgePart", { Name = "Tip", Size = Vector3.new(0.07, 0.42, 0.3), Color = steel, Material = Enum.Material.Metal, Reflectance = 0.15 }, CFrame.new(0, 1.73, 0.02))
	local base = Instance.new("Attachment")
	base.Name = "TrailBase"
	base.Position = Vector3.new(0, -0.4, 0)
	base.Parent = blade
	local tip = Instance.new("Attachment")
	tip.Name = "TrailTip"
	tip.Position = Vector3.new(0, 0.85, 0)
	tip.Parent = blade
	model.PrimaryPart = handle
	return model
end

-- A Game Pass knife's stand-in from plain parts (Shared/KnifeShapes: cut from his .glb, at its real length), used
-- until the owner's own model is in ServerStorage/HuzzKnives, and on screens that can't draw his model.
local MATERIAL = { Metal = Enum.Material.Metal, Neon = Enum.Material.Neon, Plastic = Enum.Material.Plastic,
	SmoothPlastic = Enum.Material.SmoothPlastic, Glass = Enum.Material.Glass, Fabric = Enum.Material.Fabric }
local function buildRecipe(recipe)
	local model = Instance.new("Model")
	local handle
	local made = {}
	for _, r in recipe.parts do
		local class = if r.kind == "Wedge" then "WedgePart" else "Part"
		local p = part(class, {
			Name = r.name, Size = Vector3.new(r.size[1], r.size[2], r.size[3]), Color = recipe.palette[r.paint] or WHITE,
			Material = MATERIAL[r.mat] or Enum.Material.SmoothPlastic,
		})
		if r.kind == "Cylinder" then p.Shape = Enum.PartType.Cylinder end
		p.Reflectance = r.refl or (if r.mat == "Metal" then 0.12 else 0)
		if r.mat == "Glass" then p.Transparency = 0.12 end
		if r.hidden then p.Transparency = 1 end
		local rot = r.rot or { 0, 0, 0 }
		p.CFrame = CFrame.new(r.at[1], r.at[2], r.at[3]) * CFrame.Angles(math.rad(rot[1]), math.rad(rot[2]), math.rad(rot[3]))
		p.Parent = model
		made[r.name] = p
		if r.name == "Handle" then handle = p end
	end
	for _, p in made do
		if p ~= handle then weld(handle, p) end
	end
	local blade = made.Blade or handle
	-- (the model is built round the Handle at the origin; the blade piece may be turned, a wedge: so in its own space)
	local base = Instance.new("Attachment")
	base.Name = "TrailBase"
	base.CFrame = CFrame.new(blade.CFrame:PointToObjectSpace(Vector3.new(0, recipe.trail[1], 0)))
	base.Parent = blade
	local tip = Instance.new("Attachment")
	tip.Name = "TrailTip"
	tip.CFrame = CFrame.new(blade.CFrame:PointToObjectSpace(Vector3.new(0, recipe.trail[2], 0)))
	tip.Parent = blade
	model.PrimaryPart = handle
	return model
end
KnifeService.buildRecipe = buildRecipe

-- Scales a knife model by f about its Handle (the lobby stands show their knife big: Shared/KnifeLook.STAND).
-- By hand, not Model:ScaleTo: every part's size and its offset from the Handle, attachments, welds' C0/C1, meshes
-- and lights. (An earlier try with ScaleTo lost the stand knife offline: the test harness has no ScaleTo, so the
-- stand's mount failed and three lobby checks broke. This runs the same everywhere.)
-- f: a number (the same every way), or a Vector3 of factors along the Handle's own axes (X thickness, Y length, Z
-- width: the stands' broader-than-life blades). Each part keeps its turn; its size grows by how much its own axes
-- stretch (exact for parts lined up with the Handle, close for tilted ones).
function KnifeService.scale(model, f: number | Vector3)
	local handle = model:FindFirstChild("Handle", true)
	local fv = if typeof(f) == "Vector3" then f else Vector3.new(f, f, f)
	if not (handle and handle:IsA("BasePart")) or (fv - Vector3.new(1, 1, 1)).Magnitude < 1e-3 then return model end
	local h = handle.CFrame
	local function stretch(rot: CFrame, v: Vector3): Vector3 -- a vector in a part's space, stretched in the Handle's
		return rot:VectorToObjectSpace(rot:VectorToWorldSpace(v) * fv)
	end
	local function axes(rot: CFrame): Vector3 -- how much a part's own X, Y, Z grow
		return Vector3.new((rot.RightVector * fv).Magnitude, (rot.UpVector * fv).Magnitude, (rot.LookVector * fv).Magnitude)
	end
	local rels = {}
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then rels[d] = h:ToObjectSpace(d.CFrame).Rotation end
	end
	local constraints = {}
	for _, d in model:GetDescendants() do
		if d:IsA("WeldConstraint") then -- (re-enabled after: it keeps the new offsets; pcall: Lune has no Enabled)
			local ok, on = pcall(function() return d.Enabled end)
			if not ok or on then
				pcall(function() d.Enabled = false end)
				table.insert(constraints, d)
			end
		end
	end
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			local rel = h:ToObjectSpace(d.CFrame)
			d.Size = d.Size * axes(rel.Rotation)
			d.CFrame = h * (CFrame.new(rel.Position * fv) * rel.Rotation)
		elseif d:IsA("Attachment") then
			local c = d.CFrame
			local rot = d.Parent and rels[d.Parent] or CFrame.identity
			d.CFrame = CFrame.new(stretch(rot, c.Position)) * c.Rotation
		elseif d:IsA("JointInstance") then
			local r0 = d.Part0 and rels[d.Part0] or CFrame.identity
			local r1 = d.Part1 and rels[d.Part1] or CFrame.identity
			d.C0 = CFrame.new(stretch(r0, d.C0.Position)) * d.C0.Rotation
			d.C1 = CFrame.new(stretch(r1, d.C1.Position)) * d.C1.Rotation
		elseif d:IsA("SpecialMesh") then
			local a = d.Parent and rels[d.Parent] and axes(rels[d.Parent]) or fv
			d.Scale = d.Scale * a
			d.Offset = d.Offset * a
		elseif d:IsA("PointLight") or d:IsA("SpotLight") then
			d.Range = math.min(d.Range * fv.Y, 16)
		end
	end
	for _, c in constraints do pcall(function() c.Enabled = true end) end
	local was = model:GetAttribute("Scale") or 1
	model:SetAttribute("Scale", was * fv.Y)
	local before = model:GetAttribute("Stretch") -- (every way: Gameplay/KnifeDress sizes a pass knife's .glb model by it)
	model:SetAttribute("Stretch", (if typeof(before) == "Vector3" then before else Vector3.new(was, was, was)) * fv)
	return model
end

-- The game's own knife in a skin's colours: blade in its blade colour, guard and pommel in its guard colour, and a
-- glowing (Neon) guard when the skin's model has glowing parts.
local function paint(model, skin)
	local blade, accent = skin.Colors[1], skin.Colors[#skin.Colors]
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			if d.Name == "Blade" or d.Name == "Tip" then
				d.Color = blade
			elseif d.Name == "Guard" then
				if skin.Glow then
					d.Color, d.Material = skin.Glow, Enum.Material.Neon
				else
					d.Color = accent
				end
			elseif d.Name == "Pommel" then
				d.Color = accent
			end
		end
	end
end

-- A knife model's size (Shared/KnifeLook.shape): every part in its Handle's space.
local function shapeOf(model)
	local handle = model:FindFirstChild("Handle", true)
	if not (handle and handle:IsA("BasePart")) then return nil end
	local parts = {}
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") and not string.find(d.Name, "^KnifeFx") and not string.find(d.Name, "^KnifeBackup") then -- (our effect boxes and his hidden backup aren't the knife)
			table.insert(parts, { name = d.Name, cf = handle.CFrame:ToObjectSpace(d.CFrame), size = d.Size })
		end
	end
	return KnifeLook.shape(parts)
end
KnifeService.shapeOf = shapeOf

-- True when a model is about its listed length (Studs attribute, else the shop's Studs) and shaped like a knife
-- (Shared/KnifeLook.sane): a setup that went wrong can leave one 10 times too big and lying sideways.
local warned = {}
local function fits(model, skin)
	return KnifeLook.sane(shapeOf(model), model:GetAttribute("Studs") or (skin and skin.Studs), model:GetAttribute("Wide") or (skin and skin.Wide))
end
KnifeService.fits = fits

-- His imported knife with its backup inside (owner, Oct 20 15:13: "make it so that the knifes also appear inside of
-- the actual roblox game"). His knives are his uploaded meshes on an invisible Handle: Studio shows a mesh from
-- its own copy right after his import, but a live screen has to load each one from Roblox, and an upload Roblox
-- hasn't finished or approved loads nothing there (his Oct 20 Output said that of some crate uploads: "being
-- generated", "not approved"), so the whole knife was gone with nothing in its place. So each copy carries the plain
-- cut of his own .glb (ServerStorage/HuzzKnifeBackups, tools/knives/bake_stand_ins.py: the same cut as the pass and
-- Halloween stand-ins), hidden (Transparency 1, each part's own in its "Shown" attribute), welded to his Handle in
-- the Handle's space, parts named KnifeBackup<n> (not the knife: shapeOf, KnifeFx and the trail skip them). Some of
-- his imports sit half a turn round about the Handle's length (Solar Reaper's blade curves the other way): the cut
-- turns with them, whichever way its width lines up with his (worked out once a knife).
-- Gameplay/KnifeMeshCheck shows it on a screen where any of his meshes doesn't load. Nothing when there's no backup.
KnifeService.BACKUP = "KnifeBackup"
local backups = {}
local turned: { [string]: boolean } = {}
-- How far a set of parts reaches across (the Handle's Z): lo, hi.
local function across(parts, frame)
	local lo, hi = math.huge, -math.huge
	for _, p in parts do
		local r = frame:ToObjectSpace(p.CFrame)
		local h = p.Size / 2
		local e = math.abs(r.RightVector.Z) * h.X + math.abs(r.UpVector.Z) * h.Y + math.abs(r.LookVector.Z) * h.Z
		lo, hi = math.min(lo, r.Position.Z - e), math.max(hi, r.Position.Z + e)
	end
	return lo, hi
end
local function backupRecipe(key: string)
	if backups[key] == nil then
		backups[key] = false
		local folder = ServerStorage:FindFirstChild("HuzzKnifeBackups")
		local m = folder and folder:FindFirstChild(key)
		if m then
			local ok, baked = pcall(require, m)
			if ok and type(baked) == "table" then backups[key] = KnifeShapes.fromBaked(baked) end
		end
	end
	return backups[key] or nil
end
local function addBackup(model, skin)
	local recipe = skin and backupRecipe(skin.Key)
	local handle = model:FindFirstChild("Handle", true)
	if not (recipe and handle and handle:IsA("BasePart")) or model:FindFirstChild(KnifeService.BACKUP) then return end
	local cut = buildRecipe(recipe)
	local cutHandle = cut.PrimaryPart
	if turned[skin.Key] == nil then
		local his, mine = {}, {}
		for _, d in model:GetDescendants() do
			if d:IsA("BasePart") and d ~= handle and d.Transparency < 1 then table.insert(his, d) end
		end
		for _, d in cut:GetDescendants() do
			if d:IsA("BasePart") and d ~= cutHandle then table.insert(mine, d) end
		end
		local hlo, hhi = across(his, handle.CFrame)
		local clo, chi = across(mine, cutHandle.CFrame)
		turned[skin.Key] = #his > 0 and math.abs(hlo + chi) + math.abs(hhi + clo) < math.abs(hlo - clo) + math.abs(hhi - chi)
	end
	local turn = if turned[skin.Key] then CFrame.Angles(0, math.pi, 0) else CFrame.identity
	local folder = Instance.new("Folder")
	folder.Name = KnifeService.BACKUP
	local n = 0
	for _, p in cut:GetDescendants() do
		if p:IsA("BasePart") and p ~= cutHandle then
			n += 1
			local at = turn * cutHandle.CFrame:ToObjectSpace(p.CFrame)
			for _, c in p:GetChildren() do c:Destroy() end -- (its weld to the cut's Handle, the trail points)
			p.Name = KnifeService.BACKUP .. n
			p:SetAttribute("Shown", p.Transparency)
			p.Transparency = 1
			p.CFrame = handle.CFrame * at
			local w = Instance.new("Weld")
			w.Part0, w.Part1, w.C0 = handle, p, at
			w.Parent = p
			p.Parent = folder
		end
	end
	cut:Destroy()
	folder.Parent = model
	model:SetAttribute("Backup", skin.Key)
end
KnifeService.addBackup = addBackup

-- The knife for a skin: the owner's model when it's been set up (true), else ours (false).
local function template(skin)
	local folder = ServerStorage:FindFirstChild("HuzzKnives")
	local own = skin and folder and folder:FindFirstChild(skin.Key)
	if own and own:IsA("Model") and own:FindFirstChild("Handle", true) then
		if fits(own, skin) then
			local copy = own:Clone()
			addBackup(copy, skin)
			return copy, true
		elseif not warned[skin.Key] then
			warned[skin.Key] = true
			warn(`[HuzzKnife] {skin.Key} in ServerStorage > HuzzKnives is the wrong size (run the knife setup again for it); showing the plain knife in its colours`)
		end
	end
	local custom = (folder and folder:FindFirstChild(NAME)) or ServerStorage:FindFirstChild(NAME)
	if custom and custom:IsA("Model") and custom:FindFirstChild("Handle", true) then
		return custom:Clone(), true
	end
	local recipe = skin and KnifeShapes.get(skin.Key)
	if recipe then
		-- each screen dresses it as the owner's own .glb model (Gameplay/KnifeDress, ServerStorage/HuzzKnifeGlb); the plain
		-- parts stay where that can't run
		local model = buildRecipe(recipe)
		model:SetAttribute("Glb", skin.Key)
		pcall(function() model:AddTag("GlbKnife") end)
		return model, false
	end
	local model = build()
	if skin then paint(model, skin) end
	return model, false
end
KnifeService.template = template

-- Anything a model came with (particles, sparkles, lights) is taken off (owner, Oct 20: "please fix the knifes
-- finally, they are still missing pixels, and please just make them be normal"); ours go on after (Shared/KnifeFx).
local function plain(model)
	for _, d in model:GetDescendants() do
		if d:IsA("ParticleEmitter") or d:IsA("Light") or d:IsA("Sparkles") or d:IsA("Fire") or d:IsA("Smoke") then d:Destroy() end
	end
end

-- Where the hand / back holds the knife, in the Handle's space: its Grip attachment, else the Handle's centre.
local function gripOf(handle)
	local grip = handle:FindFirstChild("Grip")
	return if grip and grip:IsA("Attachment") then grip.CFrame else CFrame.identity
end

-- Studs from the grip to the tip (KnifeLook.handC0 holds a long blade more forward, so it never sinks into the
-- floor): the TrailTip attachment when there is one, else the far end of the measured shape.
local function reachOf(model, handle)
	local grip = gripOf(handle).Position
	local tip = model:FindFirstChild("TrailTip", true)
	local holder = tip and tip.Parent
	if tip and tip:IsA("Attachment") and holder and holder:IsA("BasePart") then
		local at = handle.CFrame:PointToObjectSpace(holder.CFrame * tip.CFrame.Position)
		return at.Y - grip.Y
	end
	local shape = shapeOf(model)
	return if shape then shape.length * 0.8 else nil
end
KnifeService.reachOf = reachOf

local function loose(model)
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored, d.CanCollide, d.CanQuery, d.CanTouch, d.Massless = false, false, false, false, true
		end
	end
end

function KnifeService.has(character)
	return character ~= nil and character:FindFirstChild(NAME) ~= nil
end

local BACK = "HuzzBackKnife"
local function skinOf(skin) return if skin then skin.Key else "" end

-- True while a worn / held knife is still fixed to this body (a body part swapped out by an avatar reload leaves its
-- weld pointing at a part that's gone: then it's built again).
local function attached(model, character, mountName)
	local handle = model:FindFirstChild("Handle", true)
	local mount = handle and handle:FindFirstChild(mountName)
	local p0 = mount and (mount :: any).Part0
	return p0 ~= nil and p0.Parent == character
end

-- Back or Side for this knife: the shop table's Wear (Config/CoinShop, the owner's to change), else the model's Wear
-- attribute, else by its length (Shared/KnifeLook.wearOf).
local function wearOf(model, skin, shape)
	return KnifeLook.wearOf(skin and skin.Wear, shape or shapeOf(model), model:GetAttribute("Wear"))
end
KnifeService.wearOf = wearOf

local function isR6(character)
	return character:FindFirstChild("UpperTorso") == nil and character:FindFirstChild("Torso") ~= nil
end

-- The avatar's own accessories (capes, wings, long hair) as boxes in a torso's space, for KnifeLook.backClear.
local function accessoryBoxes(character, torso)
	local out = {}
	for _, a in character:GetChildren() do
		local h = a:IsA("Accessory") and a:FindFirstChild("Handle")
		if h and h:IsA("BasePart") then
			table.insert(out, { cf = torso.CFrame:ToObjectSpace(h.CFrame), size = h.Size })
		end
	end
	return out
end

-- Puts a worn knife where it goes on this body: its own place (the model's Wear0), over a cape or long hair on the
-- back, or at the hip when big wings fill the back (Shared/KnifeLook.backClear / wornAt).
local function fit(character, model, shape)
	local handle = model:FindFirstChild("Handle", true)
	local mount = handle and handle:FindFirstChild("BackMount")
	local base = model:GetAttribute("Wear0")
	if not (mount and base) then return end
	local r6 = isR6(character)
	local back = character:FindFirstChild(KnifeLook.mountPart("Back", r6))
	local clear = if back and back:IsA("BasePart") then KnifeLook.backClear(accessoryBoxes(character, back), back.Size) else 0
	local wear = KnifeLook.wornAt(base, clear)
	local torso = character:FindFirstChild(KnifeLook.mountPart(wear, r6))
	if not (torso and torso:IsA("BasePart")) then return end
	model:SetAttribute("WornAt", wear)
	model:SetAttribute("BackClear", clear)
	mount.Part0 = torso
	mount.C0 = KnifeLook.wornC0(wear, torso.Name, torso.Size, shape or shapeOf(model), clear)
end

-- Fits the worn knife again (an accessory loaded in or came off after the knife went on).
function KnifeService.refit(character)
	local model = character and character:FindFirstChild(BACK)
	if model then fit(character, model) end
end

-- Once per body: an accessory added or removed later (avatars load in bit by bit) fits the knife again.
local function watch(character)
	if character:GetAttribute("HuzzKnifeWatch") then return end
	character:SetAttribute("HuzzKnifeWatch", true)
	local function changed(child)
		if child:IsA("Accessory") then
			task.defer(KnifeService.refit, character)
		end
	end
	pcall(function() -- (the offline harness has no events)
		character.ChildAdded:Connect(changed)
		character.ChildRemoved:Connect(changed)
	end)
end

-- Your knife worn on your body, in your skin: long blades diagonal across the back, short knives at the right hip
-- (replaced when the skin changes). Takes a knife out of your hand first: one knife per body.
function KnifeService.giveBack(character, skin)
	if not character then return end
	local old = character:FindFirstChild(BACK)
	if old and old:GetAttribute("Skin") == skinOf(skin) and attached(old, character, "BackMount") then
		KnifeService.take(character)
		fit(character, old)
		return
	end
	if old then old:Destroy() end
	KnifeService.take(character)
	local model = template(skin)
	local shape = shapeOf(model)
	local wear = wearOf(model, skin, shape)
	local torso = character:FindFirstChild(KnifeLook.mountPart(wear, isR6(character)))
	local handle = model:FindFirstChild("Handle", true)
	if not (torso and torso:IsA("BasePart") and handle) then model:Destroy() return end
	model.Name = BACK
	model:SetAttribute("Skin", skinOf(skin))
	model:SetAttribute("Wear0", wear)
	model:SetAttribute("WornAt", wear)
	loose(model)
	for _, d in model:GetDescendants() do
		if d:IsA("Trail") or d:IsA("ParticleEmitter") or d:IsA("Light") then d:Destroy() end
	end
	plain(model)
	KnifeFx.add(model, skin, "back")
	-- how far its farthest piece is from its grip (each screen's Gameplay/KnifeGuard hides a piece that ends up farther)
	local reach = 0
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then reach = math.max(reach, (d.CFrame.Position - handle.CFrame.Position).Magnitude) end
	end
	model:SetAttribute("Reach", reach)
	local mount = Instance.new("Weld")
	mount.Name = "BackMount"
	mount.Part0 = torso
	mount.Part1 = handle
	mount.C0 = KnifeLook.wornC0(wear, torso.Name, torso.Size, shape)
	mount.C1 = gripOf(handle)
	mount.Parent = handle
	fit(character, model, shape)
	model.Parent = character
	watch(character)
end

function KnifeService.takeBack(character)
	local knife = character and character:FindFirstChild(BACK)
	if knife then knife:Destroy() end
end

-- Into the right hand, blade pointing down and a little forward (the slash sweeps it out).
-- skin (optional): a Config/CoinShop Knife item: its model (or ours in its colours), its effects, and the slash
-- trail in its colour (Epic and up) or a faint white smear. Takes the worn knife off first: one knife per body.
function KnifeService.give(character, skin)
	if not character then
		return
	end
	KnifeService.takeBack(character)
	local held = character:FindFirstChild(NAME)
	if held and (held:GetAttribute("Skin") or "") == skinOf(skin) and attached(held, character, "KnifeGrip") then
		return
	end
	if held then held:Destroy() end
	local hand = character:FindFirstChild("RightHand") or character:FindFirstChild("Right Arm")
	if not hand then
		return
	end
	local model = template(skin)
	model.Name = NAME
	model:SetAttribute("Skin", skinOf(skin)) -- (always: a custom knife with a skin isn't rebuilt every sync)
	local handle = model:FindFirstChild("Handle", true)
	if not handle then model:Destroy() return end
	loose(model)
	plain(model)
	local fx = KnifeFx.add(model, skin, "hand")
	local grip = hand:FindFirstChild("RightGripAttachment")
	local at = if grip then grip.Position else Vector3.new(0, -hand.Size.Y / 2 + 0.1, 0)
	local motor = Instance.new("Motor6D") -- a Motor6D (not a Weld) so it moves with the hand on every client at once
	motor.Name = "KnifeGrip"
	motor.Part0 = hand
	motor.Part1 = handle
	motor.C0 = KnifeLook.handC0(at, reachOf(model, handle)) -- Handle +Y (the blade) -> the hand's down-and-forward (more forward for a long blade)
	motor.C1 = gripOf(handle) -- (the fist on the model's Grip, not the Handle's centre)
	motor.Parent = handle
	-- The slash: a short smear round the blade, switched on by each client during a stab (Gameplay/Actions).
	local base, tip = model:FindFirstChild("TrailBase", true), model:FindFirstChild("TrailTip", true)
	if base and tip then
		local T = KnifeLook.TRAIL
		local look = KnifeLook.fx(skin and skin.Rarity)
		local colour = KnifeLook.colour(skin)
		local el = KnifeLook.element(skin and skin.Key)
		local tl = KnifeLook.trailLook(skin, el) -- (every skin's in its own colours; Common/Uncommon faint)
		local trail = Instance.new("Trail")
		trail.Name = "SlashTrail"
		trail.Attachment0, trail.Attachment1 = base, tip
		trail.Lifetime = if el or (fx and KnifeLook.vfx(skin, "hand").trail) then T.ElementLifetime else T.Lifetime
		trail.MinLength = 0
		trail.FaceCamera = false
		trail.LightEmission = tl.light
		trail.Color = ColorSequence.new(tl.colours[1], tl.colours[2])
		trail.Transparency = NumberSequence.new(tl.transparency[1], tl.transparency[2])
		pcall(function() trail.WidthScale = NumberSequence.new(1, 0.35) end) -- (a crescent: full at the blade, thin at the end)
		trail.Enabled = false
		trail.Parent = handle
		-- the catcher's slash arc (Gameplay/Actions) in this colour, Epic and up
		if look.arc and (el or colour) then model:SetAttribute("SlashColor", if el then el.trail[1] else colour) end
	end
	model.Parent = character
end

-- A loose copy of a skin's knife with its stand effects (KnifeFx "stand"), for showing off (the lobby avatar stands:
-- HuzzServer/AvatarStandService puts it in ReplicatedStorage, each screen welds it into the stand copy's hand by
-- its Handle's Grip attachment). Nothing anchored, nothing collides.
-- Big: scaled up to KnifeLook.STAND.Length (owner, Oct 19: "right now its very small and you dont even notice it"),
-- evenly, so it stays his model's shape (no widening, no glow shell over it: owner, Oct 19, "they dont look as good as
-- in the glb file").
function KnifeService.display(skin)
	local model = template(skin)
	local handle = model:FindFirstChild("Handle", true)
	if not handle then
		model:Destroy()
		return nil
	end
	loose(model)
	for _, d in model:GetDescendants() do -- (a model that came with its own effects gets ours, sized for the stand)
		if d:IsA("Trail") or d:IsA("ParticleEmitter") or d:IsA("Light") then d:Destroy() end
	end
	local shape = shapeOf(model)
	KnifeService.scale(model, KnifeLook.standScale(shape and shape.length))
	-- the stands' slash runs from halfway up the blade to the tip (a crescent, not a whole sheet)
	local base, tip = model:FindFirstChild("TrailBase", true), model:FindFirstChild("TrailTip", true)
	if base and tip and base:IsA("Attachment") and tip:IsA("Attachment") and tip.Parent and tip.Parent:IsA("BasePart") then
		local bw = (base.Parent :: BasePart).CFrame * base.CFrame.Position
		local tw = (tip.Parent :: BasePart).CFrame * tip.CFrame.Position
		local mid = Instance.new("Attachment")
		mid.Name = "StandTrailBase"
		mid.CFrame = CFrame.new((tip.Parent :: BasePart).CFrame:PointToObjectSpace(bw:Lerp(tw, 0.45)))
		mid.Parent = tip.Parent
	end
	plain(model)
	KnifeFx.add(model, skin, "stand")
	model:SetAttribute("Skin", skinOf(skin))
	model.PrimaryPart = handle
	return model
end

-- A plain copy of a skin's knife for a picture (UI/ImageLoader's last fallback for a knife card it can't draw, via
-- HuzzServer/KnifeGlbService): his model (or its stand-in) at its real size, no effects, nothing anchored or colliding.
function KnifeService.view(skin)
	local model = template(skin)
	local handle = model:FindFirstChild("Handle", true)
	if not handle then
		model:Destroy()
		return nil
	end
	loose(model)
	for _, d in model:GetDescendants() do
		if d:IsA("Trail") or d:IsA("ParticleEmitter") or d:IsA("Light") or d:IsA("Script") or d:IsA("LocalScript") then d:Destroy() end
	end
	plain(model)
	pcall(function() model:RemoveTag("GlbKnife") end)
	model.PrimaryPart = handle
	model.Name = skin.Key
	return model
end

function KnifeService.take(character)
	local knife = character and character:FindFirstChild(NAME)
	if knife then
		knife:Destroy()
	end
end

return KnifeService

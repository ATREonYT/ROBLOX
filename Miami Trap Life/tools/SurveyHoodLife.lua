-- [MTL HoodLife] Read-only survey of the hood for the living-neighbourhood layer (Edit mode, Command Bar / MCP).
-- Collects raw positions and POSTs them as JSON to a receiver on the Mac (tools/survey/*.json); then
-- `python3 tools/build_ambient_map.py` turns them into src/ReplicatedStorage/MTL/Config/AmbientMap.lua.
-- Receiver: python3 <scratch>/recv.py "~/ROBLOX/Miami Trap Life/tools/survey"   (port 34874)
-- Runs in chunks (the hood has ~52k parts; one big scan crashed Studio once). Changes nothing in the place.
-- Set PART = "roads" | "buildings" | "misc" and run once per part. HTTP is switched on only while posting.
local PART = PART or "roads"
local AREA = { x0 = -2100, x1 = -700, z0 = -1100, z1 = 400 }
local H = game:GetService("HttpService")

local function inArea(p: Vector3): boolean
	return p.X > AREA.x0 and p.X < AREA.x1 and p.Z > AREA.z0 and p.Z < AREA.z1
end
local function r1(x: number): number
	return math.floor(x * 10 + 0.5) / 10
end
local function yaw(cf: CFrame): number
	local _, y = cf:ToEulerAnglesYXZ()
	return r1(math.deg(y))
end
local function post(name: string, data: any): string
	local was = H.HttpEnabled
	H.HttpEnabled = true
	local ok, err = pcall(function()
		H:PostAsync("http://127.0.0.1:34874/" .. name, H:JSONEncode(data))
	end)
	H.HttpEnabled = was
	return if ok then "posted " .. name else "post failed: " .. tostring(err)
end

local VB = workspace.ViceBay
local out = {}

if PART == "roads" then
	-- Asphalt strips (centre, top y, width, length, yaw, street), Sidewalk strips, street lights, utility poles
	local A, S, L, P = {}, {}, {}, {}
	local n = 0
	for _, m in VB.Roads:GetChildren() do
		if inArea(m:GetPivot().Position) then
			for _, c in m:GetChildren() do
				if c:IsA("BasePart") then
					local p = c.Position
					if c.Name == "Asphalt" then
						table.insert(A, { r1(p.X), r1(p.Y + c.Size.Y / 2), r1(p.Z), r1(c.Size.X), r1(c.Size.Z), yaw(c.CFrame), m.Name })
					elseif c.Name == "Sidewalk" then
						table.insert(S, { r1(p.X), r1(p.Y + c.Size.Y / 2), r1(p.Z), r1(c.Size.X), r1(c.Size.Z), yaw(c.CFrame) })
					elseif c.Name == "UtilityPole" then
						-- the pole is a 36-long part lying along X: its top end is the wire height
						local top = c.CFrame * Vector3.new(c.Size.X / 2, 0, 0)
						local bot = c.CFrame * Vector3.new(-c.Size.X / 2, 0, 0)
						local t = if top.Y > bot.Y then top else bot
						table.insert(P, { r1(t.X), r1(t.Y), r1(t.Z), yaw(c.CFrame) })
					end
				elseif c:IsA("Model") and c.Name == "StreetLight" then
					local p = c:GetPivot().Position
					table.insert(L, { r1(p.X), r1(p.Y), r1(p.Z) })
				elseif c:IsA("Model") and (c.Name == "Plant" or c.Name == "Tree" or c.Name == "Palm") then
					local p = c:GetPivot().Position
					table.insert(out, { r1(p.X), r1(p.Y), r1(p.Z), c.Name })
				end
			end
			n += 1
			if n % 30 == 0 then
				task.wait()
			end
		end
	end
	return post("roads", { A = A, S = S, L = L, P = P, Plants = out })
elseif PART == "buildings" then
	-- every hood building: type, footprint frame, sign, murals, doors, window glass (outer face, facing out)
	local B = {}
	local n = 0
	for _, folderName in { "Hood", "HoodWest" } do
		local folder = VB.Buildings:FindFirstChild(folderName)
		for _, m in (if folder then folder:GetChildren() else {}) do
			if m:IsA("Model") then
				local fp = m:FindFirstChild("Footprint") :: BasePart?
				local frame = if fp then fp.CFrame else m:GetPivot()
				if inArea(frame.Position) then
					local b: any = { name = m.Name, style = m:GetAttribute("MTL_Style"), x = r1(frame.X), z = r1(frame.Z),
						y = r1(if fp then fp.Position.Y + fp.Size.Y / 2 else frame.Y), yaw = yaw(m:GetPivot()),
						sx = r1(if fp then fp.Size.X else 0), sz = r1(if fp then fp.Size.Z else 0), win = {}, murals = {}, doors = {} }
					local sign = m:FindFirstChild("Sign")
					if sign and sign:IsA("BasePart") then
						local g = sign:FindFirstChildOfClass("SurfaceGui")
						local face = if g then g.Face else Enum.NormalId.Front
						local nrm = sign.CFrame:VectorToWorldSpace(Vector3.fromNormalId(face))
						local half = (sign.Size * Vector3.fromNormalId(face)).Magnitude / 2
						local c = sign.Position + nrm * half
						b.sign = { r1(c.X), r1(c.Y), r1(c.Z), r1(math.deg(math.atan2(nrm.X, nrm.Z))), r1(sign.Size.X), r1(sign.Size.Y), r1(sign.Size.Z) }
					end
					local centre = frame.Position
					for _, d in m:GetDescendants() do
						if d:IsA("BasePart") then
							local nm = string.lower(d.Name)
							if d.Name == "Mural" then
								table.insert(b.murals, { r1(d.Position.X), r1(d.Position.Y), r1(d.Position.Z) })
							elseif string.find(nm, "door") then
								table.insert(b.doors, { r1(d.Position.X), r1(d.Position.Y - d.Size.Y / 2), r1(d.Position.Z) })
							elseif (d.Material == Enum.Material.Glass or string.find(nm, "window") or nm == "glass") and #b.win < 40 then
								local s = d.Size
								local thin = math.min(s.X, s.Y, s.Z)
								if thin < 0.8 and d.Position.Y > centre.Y + 3 then
									-- thin axis = the glass normal; pick the side facing away from the building centre
									local axis = if s.X == thin then d.CFrame.RightVector elseif s.Z == thin then d.CFrame.LookVector else d.CFrame.UpVector
									if math.abs(axis.Y) < 0.3 then
										local away = Vector3.new(d.Position.X - centre.X, 0, d.Position.Z - centre.Z)
										if axis:Dot(away) < 0 then
											axis = -axis
										end
										local w = if s.X == thin then s.Z else s.X
										local h = s.Y
										if w * h > 3 and w * h < 90 then
											local p = d.Position + axis * (thin / 2 + 0.03)
											table.insert(b.win, { r1(p.X), r1(p.Y), r1(p.Z), r1(math.deg(math.atan2(axis.X, axis.Z))), r1(w), r1(h) })
										end
									end
								end
							end
						end
					end
					-- decor others own: AC units (sound spots), graffiti (avoid with murals)
					for _, k in { "MTL_Decor", "MTL_Tags", "MTL_Fill" } do
						local f = m:FindFirstChild(k)
						if f then
							b[k] = r1(#f:GetChildren())
							if k == "MTL_Decor" then
								b.ac = {}
								for _, d in f:GetDescendants() do
									if d:IsA("BasePart") and string.find(string.lower(d.Name), "ac") and #b.ac < 3 then
										table.insert(b.ac, { r1(d.Position.X), r1(d.Position.Y), r1(d.Position.Z) })
									end
								end
							end
						end
					end
					table.insert(B, b)
					n += 1
					if n % 6 == 0 then
						task.wait()
					end
				end
			end
		end
	end
	return post("buildings", B)
elseif PART == "misc" then
	-- parked cars (don't double park), canal, landmarks, trees in the building lots, POIs
	local cars, canal, trees, pois = {}, {}, {}, {}
	local n = 0
	for _, d in VB.Buildings.Hood:GetDescendants() do
		if d:IsA("Model") and (d.Name == "Tree" or d.Name == "Palm") then
			local p = d:GetPivot().Position
			if inArea(p) then
				table.insert(trees, { r1(p.X), r1(p.Y), r1(p.Z), d.Name })
			end
		end
		n += 1
		if n % 4000 == 0 then
			task.wait()
		end
	end
	for _, d in workspace:GetDescendants() do
		if d:IsA("Model") and d.Name == "ParkedCar" then
			local p = d:GetPivot()
			if inArea(p.Position) then
				table.insert(cars, { r1(p.X), r1(p.Y), r1(p.Z), yaw(p) })
			end
		end
		n += 1
		if n % 6000 == 0 then
			task.wait()
		end
	end
	for _, m in VB.Canal:GetChildren() do
		local cf, size = m:GetBoundingBox()
		table.insert(canal, { m.Name, r1(cf.X), r1(cf.Y), r1(cf.Z), r1(size.X), r1(size.Z) })
	end
	for _, p in VB.POIs:GetChildren() do
		if p:IsA("BasePart") and inArea(p.Position) then
			table.insert(pois, { p.Name, r1(p.Position.X), r1(p.Position.Y), r1(p.Position.Z) })
		end
	end
	return post("misc", { cars = cars, canal = canal, trees = trees, pois = pois })
end
return "unknown PART"

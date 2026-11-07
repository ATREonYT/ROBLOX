--!nocheck
-- Turns .rbxm files into one Luau ModuleScript that rebuilds them in Studio.
-- Why: cloud sessions can't load files into Alex's open Studio, but they can paste code.
-- Usage (from chess-evolution/): lune run tools/rbxm_to_luau.luau out.luau a.rbxm b.rbxm ...
-- The module returns a function(parent) that recreates each file's top instance under parent.
local fs = require("@lune/fs")
local roblox = require("@lune/roblox")
local process = require("@lune/process")

local out = process.args[1]
local files = { table.unpack(process.args, 2) }

local function r(x: number): string
	local s = string.format("%.3f", x)
	s = string.gsub(s, "0+$", "")
	s = string.gsub(s, "%.$", "")
	if s == "-0" then
		s = "0"
	end
	return s
end
local function v3(v): string
	return `V({r(v.X)},{r(v.Y)},{r(v.Z)})`
end
local function cf(c): string
	local x, y, z, a, b, cc, d, e, f, g, h, i = c:GetComponents()
	if a == 1 and e == 1 and i == 1 and b == 0 and cc == 0 and d == 0 and f == 0 and g == 0 and h == 0 then
		return `P({r(x)},{r(y)},{r(z)})`
	end
	-- rotation as a quaternion: CFrame.new(x, y, z, qx, qy, qz, qw)
	local qw, qx, qy, qz
	local tr = a + e + i
	if tr > 0 then
		local S = math.sqrt(tr + 1) * 2
		qw, qx, qy, qz = 0.25 * S, (h - f) / S, (cc - g) / S, (d - b) / S
	elseif a > e and a > i then
		local S = math.sqrt(1 + a - e - i) * 2
		qw, qx, qy, qz = (h - f) / S, 0.25 * S, (b + d) / S, (cc + g) / S
	elseif e > i then
		local S = math.sqrt(1 + e - a - i) * 2
		qw, qx, qy, qz = (cc - g) / S, (b + d) / S, 0.25 * S, (f + h) / S
	else
		local S = math.sqrt(1 + i - a - e) * 2
		qw, qx, qy, qz = (d - b) / S, (cc + g) / S, (f + h) / S, 0.25 * S
	end
	local function q(v)
		local s = string.format("%.4f", v)
		s = string.gsub(s, "0+$", "")
		s = string.gsub(s, "%.$", "")
		return if s == "-0" then "0" else s
	end
	return `C({r(x)},{r(y)},{r(z)},{q(qx)},{q(qy)},{q(qz)},{q(qw)})`
end
local function col(c): string
	return `RGB({math.floor(c.R * 255 + 0.5)},{math.floor(c.G * 255 + 0.5)},{math.floor(c.B * 255 + 0.5)})`
end
local function str(s: string): string
	return string.format("%q", s)
end
local function value(v): string?
	local t = typeof(v)
	if t == "number" then
		return r(v)
	elseif t == "boolean" then
		return tostring(v)
	elseif t == "string" then
		return str(v)
	elseif t == "Vector3" then
		return v3(v)
	elseif t == "Color3" then
		return col(v)
	elseif t == "CFrame" then
		return cf(v)
	elseif t == "EnumItem" then
		local et = tostring(v.EnumType)
		return if string.sub(et, 1, 5) == "Enum." then `{et}.{v.Name}` else `Enum.{et}.{v.Name}`
	end
	return nil
end

local PROPS = {
	Part = { "Size", "CFrame", "Color", "Material", "Transparency", "Anchored", "CanCollide", "CanQuery", "CanTouch", "Massless", "Shape", "CastShadow" },
	Motor6D = { "C0", "C1" },
	Weld = { "C0", "C1" },
	Humanoid = { "RigType", "HipHeight", "DisplayDistanceType" },
	Attachment = { "CFrame" },
	Model = { "WorldPivot" },
	KeyframeSequence = { "Loop", "Priority" },
	Keyframe = { "Time" },
	Pose = { "CFrame", "Weight", "EasingStyle", "EasingDirection" },
}
local REFS = { Motor6D = { "Part0", "Part1" }, Weld = { "Part0", "Part1" }, Model = { "PrimaryPart" } }

local defaults = {}
local lines = {}
local index = {}
local refs = {}
local n = 0
local function emit(inst, parentIdx)
	n += 1
	local me = n
	index[inst] = me
	local props = {}
	local fresh = defaults[inst.ClassName]
	if fresh == nil and PROPS[inst.ClassName] then
		fresh = roblox.Instance.new(inst.ClassName)
		defaults[inst.ClassName] = fresh
	end
	for _, p in PROPS[inst.ClassName] or {} do
		local ok, v = pcall(function()
			return inst[p]
		end)
		if ok then
			local s = value(v)
			local d = fresh and value(fresh[p])
			if s and s ~= d then
				table.insert(props, `{p}={s}`)
			end
		end
	end
	local attrs = {}
	for k, v in inst:GetAttributes() do
		local s = value(v)
		if s then
			table.insert(attrs, `[{str(k)}]={s}`)
		end
	end
	table.insert(lines, `\{{parentIdx},{str(inst.ClassName)},{str(inst.Name)},\{{table.concat(props, ",")}\}{if #attrs > 0 then ",{" .. table.concat(attrs, ",") .. "}" else ""}\},`)
	if REFS[inst.ClassName] then
		table.insert(refs, inst)
	end
	for _, c in inst:GetChildren() do
		emit(c, me)
	end
end

for _, f in files do
	for _, inst in roblox.deserializeModel(fs.readFile(f)) do
		emit(inst, 0)
	end
end
local refLines = {}
for _, inst in refs do
	for _, p in REFS[inst.ClassName] do
		local target = inst[p]
		if target and index[target] then
			table.insert(refLines, `\{{index[inst]},{str(p)},{index[target]}\},`)
		end
	end
end

local body = table.concat(lines, "\n")
local ALIAS = {
	{ "Enum.Material.SmoothPlastic", "MS" }, { "Enum.PoseEasingStyle.Cubic", "EC" }, { "Enum.PoseEasingDirection.InOut", "EI" },
	{ "Enum.PoseEasingStyle.Linear", "EL" }, { "Enum.PoseEasingDirection.In", "EN" }, { "Enum.PoseEasingDirection.Out", "EO" },
	{ "CanCollide=false", "CC" }, { "Massless=true", "MT" },
}
local aliasLine = {}
for _, a in ALIAS do
	body = string.gsub(body, string.gsub(a[1], "%.", "%%."), a[2])
end
-- CC / MT are flags: expand back to key=value pairs inside the property tables
body = string.gsub(body, "([,{])CC([,}])", "%1CanCollide=false%2")
body = string.gsub(body, "([,{])MT([,}])", "%1Massless=true%2")
local src = table.concat({
	"-- Generated by tools/rbxm_to_luau.luau from: " .. table.concat(files, ", "),
	"local V,RGB=Vector3.new,Color3.fromRGB",
	"local function P(x,y,z) return CFrame.new(x,y,z) end",
	"local C=CFrame.new",
	"local MS,EC,EI,EL,EN,EO=Enum.Material.SmoothPlastic,Enum.PoseEasingStyle.Cubic,Enum.PoseEasingDirection.InOut,Enum.PoseEasingStyle.Linear,Enum.PoseEasingDirection.In,Enum.PoseEasingDirection.Out",
	"local D={",
	body,
	"}",
	"local R={",
	table.concat(refLines, "\n"),
	"}",
	"return function(parent)",
	"\tlocal made={}",
	"\tlocal tops={}",
	"\tfor i,d in D do",
	"\t\tlocal inst=Instance.new(d[2])",
	"\t\tinst.Name=d[3]",
	"\t\tfor k,v in d[4] do inst[k]=v end",
	"\t\tif d[5] then for k,v in d[5] do inst:SetAttribute(k,v) end end",
	"\t\tif inst:IsA(\"BasePart\") then inst.TopSurface=Enum.SurfaceType.Smooth inst.BottomSurface=Enum.SurfaceType.Smooth end",
	"\t\tmade[i]=inst",
	"\t\tif d[1]==0 then table.insert(tops,inst) end",
	"\tend",
	"\tfor _,x in R do made[x[1]][x[2]]=made[x[3]] end",
	"\tfor i,d in D do if d[1]~=0 then made[i].Parent=made[d[1]] end end",
	"\tfor _,t in tops do t.Parent=parent end",
	"\treturn tops",
	"end",
}, "\n")
fs.writeFile(out, src)
print(`[rbxm_to_luau] {n} instances -> {out} ({#src} bytes)`)

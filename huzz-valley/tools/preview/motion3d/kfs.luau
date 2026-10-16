-- Plays a Roblox KeyframeSequence (the owner's animation files) on a preview rig, as Roblox's Animator would:
-- each Pose's CFrame is its joint's Transform, between keyframes eased by the pose's EasingStyle.
-- KFS.load(keyframeSequence) -> anim { length, loop, tracks = { [partName] = { {t, cframe, style, dir} } } }
-- KFS.apply(anim, rig, t, weight?) sets rig motors' Transform (motor found by its Part1 name; weight blends
-- from the current Transform, for walk -> run fades).
local KFS = {}

function KFS.load(seq)
	local tracks, length = {}, 0
	for _, k in seq:GetChildren() do
		if k.ClassName == "Keyframe" then
			length = math.max(length, k.Time)
			for _, p in k:GetDescendants() do
				if p.ClassName == "Pose" then
					local ok, w = pcall(function() return p.Weight end)
					if not ok or w > 0 then
						local list = tracks[p.Name] or {}
						tracks[p.Name] = list
						local s1, style = pcall(function() return p.EasingStyle.Name end)
						local s2, dir = pcall(function() return p.EasingDirection.Name end)
						table.insert(list, { t = k.Time, cf = p.CFrame, style = s1 and style or "Linear", dir = s2 and dir or "In" })
					end
				end
			end
		end
	end
	for _, list in tracks do
		table.sort(list, function(a, b) return a.t < b.t end)
	end
	local ok, loop = pcall(function() return seq.Loop end)
	return { length = length, loop = ok and loop, tracks = tracks, name = seq.Name }
end

local function ease(style, dir, a)
	if style == "Constant" then return 0 end
	if style == "Linear" then return a end
	local function inn(x)
		if style == "Cubic" then return x * x * x end
		if style == "Elastic" then return x == 0 and 0 or -(2 ^ (10 * (x - 1))) * math.sin((x - 1.075) * (2 * math.pi) / 0.3) end
		if style == "Bounce" then
			local y = 1 - x
			local b
			if y < 1 / 2.75 then b = 7.5625 * y * y
			elseif y < 2 / 2.75 then y -= 1.5 / 2.75; b = 7.5625 * y * y + 0.75
			elseif y < 2.5 / 2.75 then y -= 2.25 / 2.75; b = 7.5625 * y * y + 0.9375
			else y -= 2.625 / 2.75; b = 7.5625 * y * y + 0.984375 end
			return 1 - b
		end
		return x
	end
	if dir == "In" then return inn(a) end
	if dir == "Out" then return 1 - inn(1 - a) end
	return if a < 0.5 then inn(a * 2) / 2 else 1 - inn((1 - a) * 2) / 2
end

function KFS.sample(anim, t)
	if anim.loop and anim.length > 0 then
		t = t % anim.length
	else
		t = math.clamp(t, 0, anim.length)
	end
	local out = {}
	for name, list in anim.tracks do
		local a, b = list[1], list[#list]
		for i = 1, #list - 1 do
			if list[i].t <= t and list[i + 1].t >= t then
				a, b = list[i], list[i + 1]
				break
			end
		end
		if t <= list[1].t then
			out[name] = list[1].cf
		elseif t >= list[#list].t then
			out[name] = list[#list].cf
		else
			local f = if b.t > a.t then (t - a.t) / (b.t - a.t) else 0
			out[name] = a.cf:Lerp(b.cf, ease(a.style, a.dir, f))
		end
	end
	return out
end

function KFS.apply(anim, rig, t, weight)
	local pose = KFS.sample(anim, t)
	for _, m in rig.motors do
		local cf = pose[m.Part1.Name]
		if cf then
			m.Transform = if weight and weight < 1 then m.Transform:Lerp(cf, weight) else cf
		end
	end
end

return KFS

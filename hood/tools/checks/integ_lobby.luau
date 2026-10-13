local RS = game.ReplicatedStorage
local ActiveMap = require(RS.Shared.ActiveMap)
local Rules = require(RS.Shared.LobbyRules)
local StageRules = require(RS.Shared.StageRules)
local function tagged(root, tag) local r = {}; for _, d in root:GetDescendants() do if d:HasTag(tag) then table.insert(r, d) end end; return r end
local out = {}
local a = ActiveMap.get()
out.active = a and a.Id
local zones = Rules.zonesFrom(a.Lobby, a.Frame)
local zl = {}
for _, z in zones do table.insert(zl, string.format('%s@(%.0f,%.0f)', z.Station.Id, z.X, z.Z)) end
out.zones = table.concat(zl, ' ')
local spawn = a.Root:FindFirstChild('Spawn', true)
local sp = a.Frame:PointToObjectSpace(spawn.CFrame.Position)
out.spawn = { sp.X, sp.Z, spawn.Enabled }
local gates = StageRules.fromModels(tagged(a.Root, 'HoodStageGate'))
local gl = {}
for _, g in gates do table.insert(gl, g.Stage .. ':' .. g.Z .. ':' .. g.Required) end
out.gates = table.concat(gl, ' ')
-- Walking down the middle with 1000 power: which gates clear, which one stops you.
local cleared = {}
local newly, blocked = StageRules.check(gates, Vector3.new(0, 3, -520), 1000, cleared)
out.walk1000 = #newly .. ' cleared, blocked by ' .. (blocked and blocked.Stage or 'none')
newly, blocked = StageRules.check(gates, Vector3.new(0, 3, -510), 1000, cleared)
out.slip = blocked and blocked.Stage or 'none'
local pads = tagged(a.Root, 'HoodFightPad')
out.fightPads = #pads
out.teleports = #tagged(a.Root, 'HoodTeleport')
do local m = a.Root:FindFirstChild('Morphs', true); local n = 0; if m then for _, c in m:GetChildren() do if c.Name:sub(1, 5) == 'Skin_' and c:FindFirstChild('Interact') then n += 1 end end end; out.morphs = n; local t = 0; for _, d in a.Root:GetDescendants() do if d.Name == 'TreadmillZone' then t += 1 end end; out.treadmills = t; out.morphStandAttr = a.Root:GetAttribute('MorphStand') end
local ring = a.Root:FindFirstChild('Training_Ring', true)
out.ring = ring and ring:FindFirstChild('TrainingZone', true) ~= nil
return out

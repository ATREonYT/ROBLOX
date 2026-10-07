local Skins=require(script.Parent.Config.Skins)
local Rules={}
-- A look you've unlocked equips at its display (within EquipRange of the stand's Interact point) or from the
-- EVOLVE panel anywhere within WardrobeRange of the stand's WardrobePoint (wardrobeDistance; nil without one).
Rules.EquipRange,Rules.WardrobeRange=14,30
local function within(d,range) return type(d)=='number' and d==d and d>=0 and d<=range end
function Rules.canEquip(power,id,distance,wardrobeDistance)
 return type(id)=='string' and Skins.available(power,id) and (within(distance,Rules.EquipRange) or within(wardrobeDistance,Rules.WardrobeRange))
end
-- Training zones are map-local rectangles: {Station,X,Z,HalfX,HalfZ,Top}. Rules.zonesFrom reads them off the
-- TrainingZone mats in the built lobby, so the server always trains on the mats players can actually see.
function Rules.training(power,localPosition,zones)
 for _,z in zones do
  local s=z.Station
  if math.abs(localPosition.X-z.X)<=z.HalfX and math.abs(localPosition.Z-z.Z)<=z.HalfZ and localPosition.Y>=z.Top-0.5 and localPosition.Y<=z.Top+8 then
   if power>=s.Required then return s.Multiplier,s.Id end
   return 1,'Locked:'..s.Id
  end
 end
 return 1,''
end
function Rules.zonesFrom(lobby,mapFrame)
 local zones={}
 for _,s in Skins.Stations do
  local station=lobby:FindFirstChild('Training_'..s.Id,true)
  local mat=station and station:FindFirstChild('TrainingZone')
  if mat then
   local x,y,z,r00,r01,r02,r10,r11,r12,r20,r21,r22=mapFrame:ToObjectSpace(mat.CFrame):GetComponents()
   local size=mat.Size
   table.insert(zones,{Station=s,X=x,Z=z,
    HalfX=(math.abs(r00)*size.X+math.abs(r01)*size.Y+math.abs(r02)*size.Z)/2,
    HalfZ=(math.abs(r20)*size.X+math.abs(r21)*size.Y+math.abs(r22)*size.Z)/2,
    Top=y+(math.abs(r10)*size.X+math.abs(r11)*size.Y+math.abs(r12)*size.Z)/2})
  end
 end
 return zones
end
return Rules

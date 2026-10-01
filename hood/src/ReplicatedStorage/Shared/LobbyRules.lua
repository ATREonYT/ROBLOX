local Skins=require(script.Parent.Config.Skins)
local Rules={}
function Rules.canEquip(power,id,distance)
 return type(id)=='string' and Skins.available(power,id) and type(distance)=='number' and distance==distance and distance<=14 and distance>=0
end
function Rules.training(power,localPosition)
 for _,s in Skins.Stations do
  if math.abs(localPosition.X-s.X)<=s.HalfX and math.abs(localPosition.Z-s.Z)<=s.HalfZ and localPosition.Y>=1 and localPosition.Y<=9 then
   if power>=s.Required then return s.Multiplier,s.Id end
   return 1,'Locked:'..s.Id
  end
 end
 return 1,''
end
return Rules

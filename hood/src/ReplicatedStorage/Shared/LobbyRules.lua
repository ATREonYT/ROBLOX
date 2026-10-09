local Skins=require(script.Parent.Config.Skins)
local RebirthRules=require(script.Parent.RebirthRules)
local Rules={}
-- Training zones are map-local rectangles: {Station,X,Z,HalfX,HalfZ,Top}. Rules.zonesFrom reads them off the
-- TrainingZone mats in the built map, so the server trains on the mats players can actually see.
-- Rules.training(rebirths, localPosition, zones): the lane you stand in. Returns (multiplier, station): an open lane
-- gives its Multiplier and its Id; a lane that needs more rebirths gives (0, 'Locked:<Id>') (its shots pay nothing);
-- off every lane (1, '') (the x1 a stage target pays).
function Rules.training(rebirths,localPosition,zones)
 for _,z in zones do
  local s=z.Station
  if math.abs(localPosition.X-z.X)<=z.HalfX and math.abs(localPosition.Z-z.Z)<=z.HalfZ and localPosition.Y>=z.Top-0.5 and localPosition.Y<=z.Top+8 then
   if RebirthRules.laneOpen(s,rebirths) then return s.Multiplier,s.Id end
   return 0,'Locked:'..s.Id
  end
 end
 return 1,''
end
-- Rebirths the lane in a TrainingStation value still needs ('Locked:<Id>'), else 0.
function Rules.need(station,rebirths)
 if type(station)~='string' then return 0 end
 local s=Skins.StationById[(station:gsub('^Locked:',''))]
 if not s or RebirthRules.laneOpen(s,rebirths) then return 0 end
 return RebirthRules.laneNeed(s)
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

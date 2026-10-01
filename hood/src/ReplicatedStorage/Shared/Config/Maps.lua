--!strict
local Balance = require(script.Parent.Balance)
local Maps = {}
-- Set real IDs after publishing four places inside ONE experience. Zero disables travel.
local placeIds = {Block = 0, Suburbs = 0, Uptown = 0, Hills = 0}
local definitions = {
 {Id='Block', Name='The Block', RepMultiplier=1, NextMap='Suburbs', Transit='Train', ClockTime=17.2, Accent={242,182,50}, AtmosphereDensity=0.3, Haze=1.7,
  Evolutions={'New Kid','Fresh Kicks','Block Famous','Neighborhood Hero','Borough Legend'},
  Walls={'Moving Boxes','Chain Link Fence','Delivery Truck','Hydrant Spray','Construction Barrier','Scaffolding','Food Cart Line','Block Party','Pigeon Flock','Station Turnstile'}},
 {Id='Suburbs', Name='The Suburbs', RepMultiplier=5, NextMap='Uptown', Transit='Car', ClockTime=10, Accent={111,175,78}, AtmosphereDensity=0.2, Haze=0.4,
  Evolutions={'New Neighbor','Lawn King','HOA Problem','Cul-de-sac Captain','Suburb Legend'},
  Walls={'Speed Bumps','Sprinklers','Lawn Mowers','School Bus','HOA Fence','Garage Band','Soccer Practice','Moving Truck','Toll Gate','Highway Ramp'}},
 {Id='Uptown', Name='Uptown', RepMultiplier=25, NextMap='Hills', Transit='Helicopter', ClockTime=18.6, Accent={96,172,255}, AtmosphereDensity=0.25, Haze=1,
  Evolutions={'Doorman Knows You','Rooftop Regular','Penthouse Tenant','Skyline Mogul','Uptown Legend'},
  Walls={'Velvet Ropes','Security Desk','Revolving Door','Window Washers','Rooftop Party','Skybridge Gate','Garden Reception','Pool Queue','Helipad Security','Helipad Gate'}},
 {Id='Hills', Name='The Hills', RepMultiplier=125, Transit='JetTeaser', ClockTime=18.1, Accent={255,138,76}, AtmosphereDensity=0.3, Haze=2,
  Evolutions={'Gated Guest','Hills Resident','Mansion Owner','Jet Setter','Made It From the Block'},
  Walls={'Estate Gate','Palm Drive','Guard Gate','Hedge Maze','Vineyard Gate','Car Show','Hilltop Checkpoint','Hangar Queue','Airstrip Security','Private Airstrip'}},
}
Maps.Ordered = {}
Maps.ById = {}
Maps.ByPlaceId = {}
for i, definition in ipairs(definitions) do
 local m = table.clone(definition)
 m.Index = i
 m.PlaceId = placeIds[m.Id]
 m.ArrivalSpawn = m.Id .. 'Arrival'
 m.BoxId = m.Id .. 'Box'
 m.RebirthRequirement = math.floor(Balance.RebirthBase * Balance.MapThresholdGrowth^(i-1))
 m.Lighting = {ClockTime=m.ClockTime, AtmosphereDensity=m.AtmosphereDensity, Haze=m.Haze, GlobalShadows=true}
 m.Walls = {}
 for j, name in ipairs(definition.Walls) do
  local threshold = Balance.wallThreshold(i,j)
  table.insert(m.Walls,{Id=m.Id..'Wall'..j, Name=name, Index=j, RequiredRep=threshold, CashReward=math.max(10,math.floor(threshold*0.2))})
 end
 m.Evolutions = {}
 local fractions = {0,0.005,0.04,0.25,1}
 local colors = {{210,218,225},{115,207,153},{87,170,240},{184,125,237},{242,182,50}}
 for j, name in ipairs(definition.Evolutions) do
  table.insert(m.Evolutions,{Id=m.Id..'Evolution'..j,Name=name,RequiredRep=math.floor(m.Walls[10].RequiredRep*fractions[j]),Multiplier=1+(j-1)*0.5,TitleColor=colors[j],OutfitKey=m.Id..'Outfit'..j,TrailKey=m.Id..'Trail'..j})
 end
 Maps.Ordered[i]=m
 Maps.ById[m.Id]=m
 if m.PlaceId > 0 then
  assert(not Maps.ByPlaceId[m.PlaceId], 'Duplicate PlaceId')
  Maps.ByPlaceId[m.PlaceId]=m
 end
end
function Maps.resolve(placeId: number, studio: boolean, developmentMap: string?)
 local map = Maps.ByPlaceId[placeId]
 if map then return map end
 if studio then
  local fallback = Maps.ById[developmentMap or 'Block']
  assert(fallback, 'Unknown development map')
  return fallback
 end
 error('Unconfigured published PlaceId: '..tostring(placeId)..'. Configure Maps before launch.')
end
return Maps

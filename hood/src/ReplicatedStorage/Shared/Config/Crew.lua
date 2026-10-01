--!strict
-- Exact normal/lucky odds total 100 for every box. All boxes disabled until milestone 5.
local Crew = {Members={}, Boxes={}}
local rows = {
 {'Block','Bodega Box',50,{'Bodega Cat','Stoop Pigeon','Delivery Pup','Court Captain'}},
 {'Suburbs','Garage Sale Box',2000,{'Garden Buddy','Mailbox Pup','Sprinkler Duck','Lawn Legend'}},
 {'Uptown','Gift Bag',80000,{'Lobby Cat','Rooftop Owl','Skyline Pup','Penthouse Pal'}},
 {'Hills','The Vault',3200000,{'Estate Pup','Palm Parrot','Pool Otter','Golden Companion'}},
}
local rarity={'Common','Uncommon','Rare','Epic'}
local odds={60,25,12,3}
local lucky={45,30,20,5}
for mapIndex,row in ipairs(rows) do
 local entries={}
 for i,name in ipairs(row[4]) do
  local id=row[1]..'Crew'..i
  Crew.Members[id]={Id=id,Name=name,Rarity=rarity[i],RepBonus=({0.5,1,2,4})[i]*mapIndex}
  table.insert(entries,{CrewId=id,Percent=odds[i],LuckyPercent=lucky[i]})
 end
 Crew.Boxes[row[1]..'Box']={Name=row[2],CashCost=row[3],Outcomes=entries,Enabled=false}
end
Crew.FirstFreeCrewId='BlockCrew1'
return Crew

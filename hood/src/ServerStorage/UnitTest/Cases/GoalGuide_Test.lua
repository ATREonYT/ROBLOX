return function(t)
 local RS=game:GetService('ReplicatedStorage')
 local G=require(RS.Shared.GoalRules)
 local R=require(RS.Shared.GuideRules)
 local Skins=require(RS.Shared.Config.Skins)
 t.test('the guide points every World 1 goal at a place to walk to, or at nothing when there is none',function()
  for _,g in G.List do
   local tg=R.target(g,{Rebirths=60,RunCleared=0,World=1})
   if g.Need.Rebirths then t.expect.equal(tg,nil) else t.expect.truthy(tg~=nil and R.Near[tg.Kind]~=nil) end
  end
  -- the first goal (Level 6 in BAY 1) is BAY 1's lane; buying a gun is the ARMORY; a shoe box is the boxes
  t.expect.equal(R.target(G.List[1],{}).Kind,'Lane');t.expect.equal(R.target(G.List[1],{}).Station,R.firstLane())
  t.expect.equal(R.target(G.ById.Gun,{}).Kind,'Armory');t.expect.equal(R.target(G.ById.Shoe,{}).Kind,'Boxes')
  -- the chain done: World 1 points at the portal, World 2 at nothing
  t.expect.equal(R.target(nil,{World=1}).Kind,'Portal');t.expect.equal(R.target(nil,{World=2}),nil)
 end)
 t.test('the guide sends you to the gate first, then the pad once the crew is beaten',function()
  local g=R.target(G.ById.Stage3,{});t.expect.equal(g.Kind,'Gate');t.expect.equal(g.Stage,3)
  t.expect.equal(R.target(G.ById.CashOut,{RunCleared=0}).Kind,'Gate')
  local p=R.target(G.ById.CashOut,{RunCleared=1});t.expect.equal(p.Kind,'Pad');t.expect.equal(p.Stage,1)
  t.expect.equal(R.target(G.ById.CashOut2,{RunCleared=1}).Kind,'Gate')
  t.expect.equal(R.target(G.ById.CashOut2,{RunCleared=2}).Kind,'Pad')
 end)
 t.test('a lane still locked gets no guide (the goal line says to rebirth), an open one does',function()
  for _,g in G.List do
   if g.Need.Range then
    local st=Skins.Stations[g.Need.Range]
    if (st.Rebirths or 0)>0 then t.expect.equal(R.target(g,{Rebirths=st.Rebirths-1}),nil) end
    local open=R.target(g,{Rebirths=st.Rebirths or 0});t.expect.equal(open.Kind,'Lane');t.expect.equal(open.Station,st.Id)
   end
  end
 end)
end

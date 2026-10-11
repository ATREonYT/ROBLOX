-- (brief 29) The user's enemies in the stages: the roster mapped onto our 16 stages (the spawner asks EnemyLooks.forStage,
-- the client works the same keys out itself), the template cache and its fallback to today's goon, the court's fence
-- and tunnel, and the bosses' big moves: a red telegraph at least a second before they land, phase 2 at half HP.
return function(t)
 local RS=game:GetService('ReplicatedStorage')
 local E=require(RS.Shared.EnemyRules)
 local W=require(RS.Shared.WaveRules)
 local Balance=require(RS.Shared.Config.Balance)
 local Looks=require(game:GetService('ServerStorage').HoodEnemies.EnemyLooks)
 local Models=require(game:GetService('ServerScriptService').HoodServer.EnemyModels)
 local function gates() local g={} for i=1,16 do table.insert(g,{Stage=i,WallId='HoodW1Stage'..i,Required=Balance.StagePower[i],Z=-(i-1)*64,HalfWidth=36}) end return g end

 t.test('the roster maps onto our 16 stages (the Ballers on the courts): three minions, and on a crew\'s 2nd stage its boss',function()
  t.expect.equal(#E.RosterStage,16)
  t.expect.equal(E.looksFor(11).crew,'ballers');t.expect.equal(E.looksFor(12).boss,'ballers_boss')
  local seen={}
  for s=1,16 do
   local r=E.RosterStage[s];t.expect.truthy(r>=1 and r<=16 and not seen[r]);seen[r]=true
   local srv,cli=Looks.forStage(r),E.looksFor(s)
   t.expect.equal(cli.crew..'',string.lower(srv.minions[1]):match('^(.-)_'))
   for i=1,3 do t.expect.equal(cli.minions[i],srv.minions[i]) end
   t.expect.equal(cli.boss,srv.boss)
   t.expect.equal(srv.boss~=nil,s%2==0)
  end
  -- the spawner's crews (WaveService: EnemyRules.world with EnemyModels.forStage) wear those looks
  local world=E.world(gates(),nil,Models.forStage)
  for s=1,16 do
   local who=Looks.forStage(E.RosterStage[s])
   for i,e in world[s] do
    t.expect.truthy(Looks.info(e.Look)~=nil)
    if e.Kind=='Boss' then t.expect.equal(e.Look,who.boss) else t.expect.truthy(table.find(who.minions,e.Look)~=nil) end
   end
  end
  -- the client's own world (no EnemyLooks there) matches the server's
  local mine=E.world(gates())
  for s=1,16 do for i,e in world[s] do t.expect.equal(mine[s][i].Look,e.Look) end end
  -- every boss has its moves, under its own name
  for _,crew in E.LookCrews do
   local b=E.Bosses[crew];t.expect.truthy(b~=nil)
   t.expect.equal(b.Title,Looks.info(crew..'_boss').name)
   t.expect.truthy(#b.Moves>=2 and E.Moves[b.Rage]~=nil)
   for _,m in b.Moves do t.expect.truthy(E.Moves[m]~=nil and b.Names[m]~=nil) end
  end
  t.expect.equal(world[16][1].Look,'harbor_boss') -- (the Boss Yard: World 1's final boss)
  t.expect.truthy(E.maxHp(16,'Boss')>E.maxHp(16,'Bruiser') and E.maxHp(2,'Boss')>E.maxHp(2,'Bruiser'))
 end)

 t.test('templates: built once, made inert; a look that can\'t be built leaves today\'s goon standing in',function()
  -- offline (here, or Studio without HTTP): EnemyLooks.build fails, nothing breaks
  local m,why=Models.make('bullies_1')
  t.expect.equal(m,nil);t.expect.truthy(type(why)=='string')
  t.expect.equal(Models.make('nope',function() error('no such look') end),nil)
  -- a bare avatar (its clothes failed to load) is not used either
  local function rig(dressed)
   local model=Instance.new('Model');model.Name='Recess Bully'
   local root=Instance.new('Part');root.Name='HumanoidRootPart';root.Size=Vector3.new(2,2,1);root.Parent=model
   local head=Instance.new('Part');head.Name='Head';head.Size=Vector3.new(2,1,1);head.CFrame=CFrame.new(0,2.5,0);head.Parent=model
   local hum=Instance.new('Humanoid');hum.Parent=model
   local j=Instance.new('Motor6D');j.Name='Neck';j.Part0=root;j.Part1=head;j.C0=CFrame.new(0,1.5,0);j.Parent=head
   if dressed then Instance.new('Shirt').Parent=model end
   Instance.new('Script').Parent=model
   return model
  end
  local _,bare=Models.make('bullies_1',function() return rig(false) end)
  t.expect.equal(bare,'undressed')
  local tpl=Models.make('bullies_1',function() return rig(true) end)
  t.expect.truthy(tpl~=nil)
  t.expect.equal(tpl.Name,'bullies_1');t.expect.equal(tpl:GetAttribute('DisplayName'),'Recess Bully')
  t.expect.equal(tpl:FindFirstChildOfClass('Script'),nil);t.expect.falsy(tpl.HumanoidRootPart.CanCollide)
  -- the client: no template yet -> today's goon; with one -> the avatar, posed from its joints
  local Rig=require(RS.Shared.EnemyRig)
  local folder=Instance.new('Folder');folder.Name=Rig.FolderName;folder.Parent=RS
  local holder=Instance.new('Folder')
  local old=Rig.build('crooks_1','Goon','Red',1,holder)
  t.expect.falsy(old.R15);t.expect.truthy(old.Model~=nil and old.Head~=nil)
  tpl.Parent=folder
  local new=Rig.build('bullies_1','Goon','Red',1,holder)
  t.expect.truthy(new.R15);t.expect.truthy(new.Root.Anchored)
  Rig.Solve=true
  local ok=pcall(Rig.pose,new,CFrame.new(10,0,0),{walk=1,stride=1,guard=1,move='Stomp',ready=0.5,flinch=0.3,idle=2})
  t.expect.truthy(ok)
  t.expect.truthy(math.abs(new.Root.CFrame.X-10)<1e-3 and new.Head.CFrame.Y>new.Root.CFrame.Y)
  Rig.Solve=false
  folder:Destroy();holder:Destroy()
  -- the curves: the strike snaps to 1, holds, overshoots back past 0 and settles; anticipation ends fully wound
  t.expect.equal(Rig.strike(0),0);t.expect.equal(Rig.strike(0.1),1);t.expect.equal(Rig.strike(Rig.StrikeTime+0.01),0)
  local least=1 for k=0,40 do least=math.min(least,Rig.strike(0.16+k*0.0105)) end
  t.expect.truthy(least<0 and least>-0.2)
  t.expect.equal(Rig.ready(1),1);t.expect.truthy(Rig.ready(0.3)<0.3)
 end)

 t.test('the court: goons go out through the fence\'s gateway, never through the wire; its crew walks out of the tunnel',function()
  local world,arenas=E.world(gates())
  for s=10,12 do
   local a=arenas[s];t.expect.truthy(a.Fences and #a.Fences==1 and a.Tunnel and a.Mouth)
   local n=0 for _,e in world[s] do if e.Walkout then n+=1;t.expect.truthy(e.Home.X>a.Fences[1].X) end end
   t.expect.truthy(n>=2)
  end
  t.expect.equal(arenas[9].Fences,nil)
  -- a goon on the court runs at you on the street: wherever it crosses the fence line, it is in the gateway
  local a=arenas[10];local f=a.Fences[1]
  for _,start in {Vector3.new(30,0,f.Z0+4),Vector3.new(28,0,f.Z1-3)} do
   local g=E.new('Goon',start,0);E.alert(g,0);g.State=E.Chase
   local you=Vector3.new(-4,0,(f.Z0+f.Z1)/2+9)
   local crossed=nil
   for _=1,200 do
    local before=g.Pos
    E.step(g,0.1,you,0,nil,a,{g})
    if (before.X-f.X)*(g.Pos.X-f.X)<0 then crossed=(before.Z+g.Pos.Z)/2 end
   end
   t.expect.truthy(crossed~=nil and crossed>=f.D0-0.5 and crossed<=f.D1+0.5)
  end
 end)

 t.test('a boss telegraphs every big move in red at least a second before it lands, and gets angry at half HP',function()
  for _,ph in {1,2} do t.expect.truthy(E.teleTime(ph)>=E.TeleMin and E.TeleMin>=1) end
  t.expect.truthy(E.teleTime(2)<E.teleTime(1) and E.bossRest(2)<E.bossRest(1))
  for crew,b in E.Bosses do
   for _,ph in (b.Final and {} or {1,2}) do -- (World 1's final boss has its own three phases: Finale29_Test)
    local g={Kind='Boss',Look=crew..'_boss',Pos=Vector3.new(0,0,-40),Phase=ph}
    local moves=E.movesOf(g)
    t.expect.equal(#moves,ph==1 and 2 or 3)
    for n=1,#moves do
     g.MoveN=n-1
     local atk=E.planAttack(g,Vector3.new(0,0,-34),nil)
     t.expect.truthy(atk~=nil and atk.Tele>=1.0 and atk.Damage>0 and atk.Damage<=E.MaxPunch)
     -- standing where it shows is a hit; well outside it is a miss
     local inside=atk.Shape=='Line' and atk.O+atk.D*4 or (atk.Shape=='Cone' and atk.O+atk.D*4) or atk.P[1]
     t.expect.truthy(E.inAttack(atk,inside))
     t.expect.falsy(E.inAttack(atk,atk.O+Vector3.new(60,0,0)))
    end
   end
  end
  -- a fight: the boss's first big move comes, then lands no sooner than its telegraph
  local world={[1]={{Kind='Boss',Home=Vector3.new(0,0,-40),Look='ballers_boss'}}}
  local c={t=0};local s=W.session(world,function() return c.t end);s:move(1)
  local you=Vector3.new(0,0,-30)
  local teleAt,blastAt,landed,atk
  for _=1,120 do
   c.t+=0.1
   for _,ev in s:tick(0.1,you) do
    if ev.Kind=='tele' and not teleAt then teleAt,atk=c.t,ev.Attack end
    if ev.Kind=='blast' and teleAt and not blastAt then blastAt,landed=c.t,ev.Landed end
   end
   if blastAt then break end
  end
  t.expect.truthy(teleAt~=nil and blastAt~=nil)
  t.expect.truthy(blastAt-teleAt>=1.0-1e-6)
  t.expect.truthy(landed==E.inAttack(atk,you))
  -- step out of the red as soon as it shows: it misses
  local s2=W.session(world,function() return c.t end);s2:move(1)
  local g2=s2:current().Goons[1];E.alert(g2,0)
  local dodged=nil
  local spot=you
  for _=1,150 do
   c.t+=0.1
   for _,ev in s2:tick(0.1,spot) do
    if ev.Kind=='tele' then
     local a=ev.Attack
     local side=Vector3.new(-a.D.Z,0,a.D.X)
     spot=(a.Shape=='Circle' and a.P[1] or a.O)+side*30
    end
    if ev.Kind=='blast' and dodged==nil then dodged=not ev.Landed end
   end
   if dodged~=nil then break end
  end
  t.expect.truthy(dodged==true)
  -- half its HP: phase 2, its rage move joins in
  local w=s:current();local b=w.Goons[1];c.t+=5
  t.expect.equal(b.Phase,nil)
  s:shoot(1,1,b.Pos+Vector3.new(0,0,5),math.floor(w.Max[1]*0.55))
  t.expect.equal(b.Phase,2);t.expect.truthy(table.find(E.movesOf(b),'Leap')~=nil)
  -- made whole again (you left): calm, phase 1
  W.restore(w);t.expect.equal(b.Phase,nil)
 end)
end

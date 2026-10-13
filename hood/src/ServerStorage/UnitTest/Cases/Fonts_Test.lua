return function(t)
 local Fonts=require(game.ReplicatedStorage.Shared.Fonts)
 local function label(size,scaled)
  local l=Instance.new('TextLabel');l.TextSize=size or 20;l.TextScaled=scaled or false;l.Text='Store'
  return l
 end
 local function strokes(l) local n=0;for _,c in l:GetChildren() do if c:IsA('UIStroke') then n+=1 end end;return n end

 t.test('every role is the one family, Black for titles and numbers, Bold for the rest',function()
  for _,role in Fonts.Roles do
   local f=Fonts[role];t.expect.equal(typeof(f),'Font');t.expect.equal(f.Family,Fonts.Family)
   t.expect.equal(typeof(Fonts.Enum[role]),'EnumItem')
  end
  t.expect.equal(Fonts.Family,'rbxasset://fonts/families/Montserrat.json')
  t.expect.equal(Fonts.Title.Weight,Enum.FontWeight.Heavy);t.expect.equal(Fonts.Number.Weight,Enum.FontWeight.Heavy)
  t.expect.equal(Fonts.Heading.Weight,Enum.FontWeight.Bold);t.expect.equal(Fonts.Body.Weight,Enum.FontWeight.Bold)
  t.expect.equal(Fonts.Italic.Style,Enum.FontStyle.Italic);t.expect.equal(Fonts.Title.Style,Enum.FontStyle.Normal)
  -- only the weights Roblox ships for the family (Bold and Black), so no role falls back to a guess
  for _,role in Fonts.Roles do local w=Fonts[role].Weight;t.expect.truthy(w==Enum.FontWeight.Bold or w==Enum.FontWeight.Heavy) end
 end)
 t.test('roles are found in any case, anything else is Body',function()
  t.expect.equal(Fonts.role('title'),'Title');t.expect.equal(Fonts.role('NUMBER'),'Number');t.expect.equal(Fonts.role('Heading'),'Heading')
  t.expect.equal(Fonts.role('Fancy'),'Body');t.expect.equal(Fonts.role(nil),'Body')
  t.expect.equal(Fonts.face('title'),Fonts.Title);t.expect.equal(Fonts.face(7),Fonts.Body)
 end)
 t.test('the house outline grows with the size and never gets too thin',function()
  t.expect.equal(Fonts.strokeFor(4,'Body'),Fonts.Outline.Min)
  t.expect.equal(Fonts.strokeFor(20,'Body'),2)
  t.expect.equal(Fonts.strokeFor(80,'Heading'),6);t.expect.equal(Fonts.strokeFor(40,'Title'),3.5)
  local last=0
  for s=8,120,4 do local w=Fonts.strokeFor(s,'Heading');t.expect.truthy(w>=last);t.expect.equal(w*2,math.floor(w*2));last=w end
  -- a window title's outline is no thicker for its size than a body line's
  t.expect.truthy(Fonts.strokeFor(60,'Heading')<=Fonts.strokeFor(60,'Body'))
 end)
 t.test('apply sets the face and adds one house outline, updated in place',function()
  local l=label(30);l.TextStrokeTransparency=0
  local same,s=Fonts.apply(l,'Title',{stroke=true})
  t.expect.equal(same,l);t.expect.equal(l.FontFace,Fonts.Title);t.expect.equal(strokes(l),1)
  t.expect.equal(s.Color,Fonts.Outline.Color);t.expect.equal(s.Thickness,Fonts.strokeFor(30,'Title'))
  t.expect.equal(s.LineJoinMode,Enum.LineJoinMode.Round);t.expect.equal(s.ApplyStrokeMode,Enum.ApplyStrokeMode.Contextual)
  t.expect.equal(l.TextStrokeTransparency,1)
  local _,s2=Fonts.apply(l,'Number',{stroke=4,strokeColor=Color3.new(1,0,0),transparency=0.2})
  t.expect.equal(s2,s);t.expect.equal(strokes(l),1);t.expect.equal(l.FontFace,Fonts.Number)
  t.expect.equal(s.Thickness,4);t.expect.equal(s.Color,Color3.new(1,0,0));t.expect.near(s.Transparency,0.2,1e-6)
 end)
 t.test('apply without a stroke leaves outlines alone',function()
  local l=label(18)
  local _,s=Fonts.apply(l,'Body');t.expect.equal(s,nil);t.expect.equal(strokes(l),0);t.expect.equal(l.FontFace,Fonts.Body)
  local own=Instance.new('UIStroke');own.Thickness=5;own.Parent=l
  local _,s2=Fonts.apply(l,'Heading');t.expect.equal(s2,own);t.expect.equal(own.Thickness,5)
 end)
 t.test('a scaled label gets the fixed outline unless it says its size',function()
  local l=label(14,true)
  local _,s=Fonts.apply(l,'Title',{stroke=true});t.expect.equal(s.Thickness,Fonts.Outline.Scaled)
  Fonts.apply(l,'Title',{stroke=true,size=60});t.expect.equal(s.Thickness,Fonts.strokeFor(60,'Title'))
 end)
 t.test('sweep moves other families over, big world text to Title',function()
  local m=Instance.new('Model')
  local p=Instance.new('Part');p.Parent=m
  local bb=Instance.new('BillboardGui');bb.Parent=p
  local sign=label(14,true);sign.Font=Enum.Font.FredokaOne;sign.Parent=bb
  local small=label(16);small.Font=Enum.Font.LuckiestGuy;small.Parent=bb
  local done=label(16);done.FontFace=Fonts.Heading;done.Parent=bb
  t.expect.equal(Fonts.sweep(m),2)
  t.expect.equal(sign.FontFace,Fonts.Title);t.expect.equal(small.FontFace,Fonts.Body);t.expect.equal(done.FontFace,Fonts.Heading)
  t.expect.equal(Fonts.sweep(m),0)
  small.FontFace=Font.new('rbxasset://fonts/families/FredokaOne.json')
  t.expect.equal(Fonts.sweep(m,'Number'),1);t.expect.equal(small.FontFace,Fonts.Number)
 end)
 t.test('sweep keeps the pixel Power line, monospaced logs and KeepFont text',function()
  local m=Instance.new('Folder')
  local power=label(14,true);power.Font=Enum.Font.Arcade;power.Parent=m
  local log=label(14);log.Font=Enum.Font.Code;log.Parent=m
  local own=label(20);own.Font=Enum.Font.FredokaOne;own:SetAttribute('KeepFont',true);own.Parent=m
  local pixel=label(20);pixel.FontFace=Font.new('rbxasset://fonts/families/PressStart2P.json');pixel.Parent=m
  local plain=label(20);plain.Font=Enum.Font.LuckiestGuy;plain.Parent=m
  t.expect.truthy(Fonts.keeps(power));t.expect.truthy(Fonts.keeps(log));t.expect.truthy(Fonts.keeps(own));t.expect.truthy(Fonts.keeps(pixel))
  t.expect.falsy(Fonts.keeps(plain))
  t.expect.equal(Fonts.sweep(m),1);t.expect.equal(plain.FontFace,Fonts.Body)
  t.expect.equal(power.Font,Enum.Font.Arcade);t.expect.equal(log.Font,Enum.Font.Code)
 end)
end

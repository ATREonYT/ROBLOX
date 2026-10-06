local Players=game:GetService('Players')
local RS=game:GetService('ReplicatedStorage')
local Data=require(script.Parent.DataService)
local Skins=require(RS.Shared.Config.Skins)
local Art=require(RS.Shared.SkinArt)
local Rules=require(RS.Shared.LobbyRules)
local Net=require(RS.Shared.Net)
local ActiveMap=require(RS.Shared.ActiveMap)
while not RS:GetAttribute('FoundationReady') do task.wait(.1) end
-- Runs on whichever map is active: the original Block's SimulatorLobby, or The Block V2.
local active=ActiveMap.get();if not active then return end
local f=active.Frame;local lobby=active.Lobby
local zones=Rules.zonesFrom(lobby,f)
if #zones<#Skins.Stations then warn('[LobbyService] Only '..#zones..' of '..#Skins.Stations..' training mats found; rebuild the lobby.') end
local remote=Net.get('EquipSkin');local cooldown={};local applied={}
-- Overhead tag, like the reference: "@username" small and grey, your look's name in its tier colour, then
-- "<Power> POWER" in yellow-green, all in LuckiestGuy with a dark outline. Sized in studs so it shrinks
-- with distance.
local Format=require(RS.Shared.Format)
local TIER_COLORS={Color3.fromRGB(210,218,225),Color3.fromRGB(115,207,153),Color3.fromRGB(87,170,240),Color3.fromRGB(184,125,237),Color3.fromRGB(242,182,50)}
local TAG_FONT=Font.new('rbxasset://fonts/families/LuckiestGuy.json')
local TAG_ROWS={
	{Name='User',Height=0.26,Color=Color3.fromRGB(205,210,220),Stroke=1.5},
	{Name='Title',Height=0.36,Color=Color3.new(1,1,1),Stroke=2},
	{Name='Power',Height=0.38,Color=Color3.fromRGB(205,245,70),Stroke=2},
}
local function overheadTag(player,skin,power)
	local c=player.Character
	local head=c and c:FindFirstChild('Head')
	if not head then return end
	local tag=head:FindFirstChild('HoodTag')
	if not tag then
		tag=Instance.new('BillboardGui')
		tag.Name='HoodTag'
		tag.Size=UDim2.fromScale(6,2.3)
		tag.StudsOffset=Vector3.new(0,3,0)
		tag.MaxDistance=120
		tag.LightInfluence=0
		local y=0
		for _,row in TAG_ROWS do
			local t=Instance.new('TextLabel')
			t.Name=row.Name
			t.BackgroundTransparency=1
			t.Position=UDim2.fromScale(0,y)
			t.Size=UDim2.fromScale(1,row.Height)
			t.FontFace=TAG_FONT
			t.TextScaled=true
			t.TextColor3=row.Color
			local st=Instance.new('UIStroke')
			st.Color=Color3.fromRGB(28,24,48)
			st.Thickness=row.Stroke
			st.LineJoinMode=Enum.LineJoinMode.Round
			st.Parent=t
			t.Parent=tag
			y+=row.Height
		end
		tag.User.Text='@'..player.Name
		tag.Parent=head
	end
	tag.Title.Text=skin.Name
	tag.Title.TextColor3=TIER_COLORS[math.clamp(math.ceil(skin.Index/3),1,#TIER_COLORS)]
	tag.Power.Text=Format.compact(power)..' POWER'
end
local function sync(player,profile,multiplier,station)
 local id=profile.Data.EquippedSkin;local s=Skins.ById[id] or Skins.List[1]
 player:SetAttribute('Power',profile.Data.Rep);player:SetAttribute('EquippedSkin',s.Id)
 player:SetAttribute('PowerRate',s.Gain*multiplier);player:SetAttribute('TrainingStation',station)
 -- The HUD's counters read these (and the REBIRTH % badge reads Rebirths).
 player:SetAttribute('Cash',profile.Data.Cash);player:SetAttribute('Rebirths',profile.Data.Rebirths)
 local stats=player:FindFirstChild('leaderstats')
 if not stats then stats=Instance.new('Folder');stats.Name='leaderstats';stats.Parent=player;local p=Instance.new('NumberValue');p.Name='Power';p.Parent=stats end
 stats.Power.Value=profile.Data.Rep
 overheadTag(player,s,profile.Data.Rep)
end
local function equipAppearance(player,id)
 local c=player.Character
 if not c or not c:FindFirstChild('Head') or not c:FindFirstChild('Humanoid') then return end
 if not player:HasAppearanceLoaded() then return end
 if applied[player]~=c or c:GetAttribute('BlockSkin')~=id then
  Art.equip(c,Skins.ById[id] or Skins.List[1]);c:SetAttribute('BlockSkin',id);applied[player]=c
 end
end
remote.OnServerEvent:Connect(function(player,id)
 if type(id)~='string' or not Skins.ById[id] then return end
 local now=os.clock();if now-(cooldown[player] or 0)<.35 then return end;cooldown[player]=now
 local profile=Data.get(player);local c=player.Character;local root=c and c:FindFirstChild('HumanoidRootPart');local h=c and c:FindFirstChild('Humanoid')
 if not profile or not root or not h or h.Health<=0 then return end
 local morphs=lobby:FindFirstChild('Morphs',true);local stand=morphs and morphs:FindFirstChild('Skin_'..id);local target=stand and stand:FindFirstChild('Interact')
 -- Maps without a morph stand (The Block V2) evolve at the EVOLVE booth instead.
 local booth=not target and lobby:FindFirstChild('EvolvePoint',true);target=target or booth
 if not target then return end
 local distance=(root.Position-target.Position).Magnitude
 if not Rules.canEquip(profile.Data.Rep,id,distance) then
  Net.get('Notice'):FireClient(player,distance>14 and (booth and 'Walk to the EVOLVE booth to evolve.' or 'Walk to this character display to equip it.') or ('Reach '..Skins.ById[id].Required..' Power to unlock this look.'));return
 end
 profile.Data.EquippedSkin=id;profile.Data.Onboarding.EquippedSkin=true
 equipAppearance(player,id);sync(player,profile,1,'');Data.push(player)
 Net.get('Notice'):FireClient(player,(booth and 'Evolved into ' or '')..Skins.ById[id].Name..(booth and '!' or ' equipped!')..' +'..Skins.ById[id].Gain..' Power / second.')
end)
-- Punching: while you train on a bag, each click or tap is a punch worth a tenth of your per-second gain
-- (at least 1) times your gun's multiplier, up to about 7 a second. The training mat check is the same one
-- the passive gain uses.
local RateLimiter=require(script.Parent.RateLimiter)
local punchLimit=RateLimiter.new(8,7)
Net.get('Punch').OnServerEvent:Connect(function(player)
 if not punchLimit.allow(player) then return end
 local profile=Data.get(player);local station=player:GetAttribute('TrainingStation') or ''
 if not profile or station=='' or station:find('Locked:') then return end
 local bonus=math.max(1,math.floor((player:GetAttribute('PowerRate') or 1)*0.1))*(player:GetAttribute('GunMultiplier') or 1)
 profile.Data.Rep=math.min(1e12,profile.Data.Rep+bonus)
end)
Players.PlayerRemoving:Connect(function(p) cooldown[p]=nil;applied[p]=nil;punchLimit.remove(p) end)
local boardTime=0
while task.wait(1) do
 local rows={}
 for _,player in Players:GetPlayers() do
  local profile=Data.get(player);local c=player.Character;local root=c and c:FindFirstChild('HumanoidRootPart');local h=c and c:FindFirstChild('Humanoid')
  if profile then
   local multiplier,station=1,''
   if root and h and h.Health>0 then
    multiplier,station=Rules.training(profile.Data.Rep,f:PointToObjectSpace(root.Position),zones)
    profile.Data.Rep=math.min(1e12,profile.Data.Rep+Skins.gain(profile.Data.EquippedSkin,multiplier))
    if multiplier>1 then profile.Data.Onboarding.Trained=true end
    equipAppearance(player,profile.Data.EquippedSkin)
   end
   sync(player,profile,multiplier,station)
   table.insert(rows,{Name=player.DisplayName,Power=profile.Data.Rep})
  end
 end
 boardTime+=1
 if boardTime%5==0 then
  table.sort(rows,function(a,b) return a.Power>b.Power end)
  local lines={'BLOCK LEADERS','THIS SERVER'}
  for i=1,math.min(#rows,5) do table.insert(lines,string.format('%d. %s  /  %s',i,rows[i].Name,tostring(math.floor(rows[i].Power)))) end
  if #rows==0 then table.insert(lines,'Be the first to train!') end
  local board=lobby:FindFirstChild('ServerLeaderboard',true);local label=board and board:FindFirstChild('TextLabel',true)
  if label then label.Text=table.concat(lines,'\n') end
 end
end

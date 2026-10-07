-- The fifteen looks, street kid to Kingpin. Id, Required and Gain are saved/balanced: never change them.
-- Everything else is art (Shared/SkinArt.lua reads it): Color = the main top (jacket/tee), Accent and Trim =
-- the look's second and third colours, Pants, Skin, Hair, Shirt; Style/Hat name the silhouette; Expression
-- the face; Pose the display pose (SkinArt.Poses). Look picks the recipe (defaults to Id).
local C=Color3.fromRGB
local S={List={}}
local rows={
 {Id='CornerKid',Name='Corner Kid',Required=0,Gain=1,Style='tee',Hat='backwards cap',Color=C(248,248,244),Accent=C(232,44,52),Trim=C(255,140,30),Pants=C(40,110,230),Skin=C(224,172,124),Hair=C(60,40,30),Expression='happy',Pose='carry'},
 {Id='Pickpocket',Name='Runner',Required=25,Gain=2,Style='track jacket',Hat='headphones',Color=C(130,220,50),Accent=C(36,36,44),Trim=C(255,120,40),Pants=C(50,52,62),Skin=C(120,78,50),Hair=C(30,22,18),Expression='smirk',Pose='wave'},
 {Id='Lookout',Name='Lookout',Required=75,Gain=3,Style='puffer',Hat='beanie',Color=C(255,128,30),Accent=C(30,190,200),Trim=C(210,150,70),Pants=C(100,110,70),Skin=C(255,214,170),Hair=C(150,90,40),Expression='worried',Pose='point'},
 {Id='Bandit',Name='Bandit',Required=150,Gain=4,Style='hoodie',Hat='hood and bandana',Color=C(150,60,220),Accent=C(30,30,36),Trim=C(214,178,120),Pants=C(52,98,178),Skin=C(198,140,95),Hair=C(40,30,24),Expression='sly',Pose='swagger'},
 {Id='Hustler',Name='Hustler',Required=300,Gain=6,Style='tracksuit',Hat='bucket hat',Color=C(0,180,190),Accent=C(250,250,246),Trim=C(255,196,48),Pants=C(0,180,190),Skin=C(100,64,42),Hair=C(25,20,18),Expression='cool',Pose='boss'},
 {Id='Crook',Name='Crook',Required=600,Gain=8,Style='leather jacket',Hat='bandana',Color=C(40,38,44),Accent=C(225,35,45),Trim=C(214,220,230),Pants=C(52,98,178),Skin=C(250,208,170),Hair=C(40,30,25),Expression='smug',Pose='boombox'},
 {Id='GetawayDriver',Name='Getaway Driver',Required=1000,Gain=10,Style='racing jacket',Hat='pompadour',Color=C(255,206,30),Accent=C(30,30,36),Trim=C(232,44,52),Pants=C(52,58,78),Skin=C(214,160,110),Hair=C(40,28,20),Expression='smirk',Pose='salute'},
 {Id='Enforcer',Name='Enforcer',Required=1500,Gain=12,Style='tank top',Hat='bald',Color=C(245,245,245),Accent=C(220,30,40),Trim=C(122,74,44),Pants=C(40,40,48),Skin=C(232,184,140),Hair=C(110,70,40),Expression='angry',Pose='cross'},
 {Id='StreetBoss',Name='OG',Required=2000,Gain=16,Style='fur coat',Hat='kangol',Color=C(20,160,90),Accent=C(250,250,245),Trim=C(150,30,60),Pants=C(30,30,36),Shirt=C(150,30,60),Skin=C(90,58,40),Hair=C(20,18,16),Expression='smug',Pose='boss'},
 {Id='Gangster',Name='Shot Caller',Required=3000,Gain=22,Style='zoot suit',Hat='wide brim',Color=C(35,95,225),Accent=C(250,250,245),Trim=C(232,44,52),Pants=C(35,95,225),Skin=C(205,150,105),Hair=C(30,25,20),Expression='smirk',Pose='swagger'},
 {Id='Capo',Name='Capo',Required=5000,Gain=30,Style='three-piece',Hat='fedora',Color=C(104,66,42),Accent=C(225,30,45),Trim=C(150,156,170),Pants=C(104,66,42),Skin=C(240,196,150),Hair=C(30,25,22),Expression='serious',Pose='carry'},
 {Id='Consigliere',Name='Consigliere',Required=8000,Gain=42,Style='double-breasted',Hat='silver hair',Color=C(140,26,50),Accent=C(255,196,48),Trim=C(110,66,40),Pants=C(140,26,50),Shirt=C(255,240,210),Skin=C(226,180,140),Hair=C(210,212,218),Expression='wise',Pose='easy'},
 {Id='Underboss',Name='Underboss',Required=12000,Gain=58,Style='overcoat',Hat='black fedora',Color=C(32,32,38),Accent=C(205,150,80),Trim=C(248,248,244),Pants=C(32,32,38),Skin=C(180,122,80),Hair=C(25,22,20),Expression='serious',Pose='boss'},
 {Id='TheDon',Name='The Don',Required=18000,Gain=80,Style='dinner jacket',Hat='silver hair',Color=C(250,246,232),Accent=C(220,20,50),Trim=C(28,28,34),Pants=C(30,30,36),Skin=C(236,192,150),Hair=C(200,202,208),Expression='wise',Pose='boss'},
 {Id='Kingpin',Name='Kingpin',Required=30000,Gain=110,Style='royal suit',Hat='crown',Color=C(110,40,200),Accent=C(200,20,40),Trim=C(255,196,48),Pants=C(110,40,200),Skin=C(150,98,62),Hair=C(20,18,16),Expression='smug',Pose='royal'},
}
for i,r in rows do
 r.Index=i;r.Look=r.Look or r.Id
 table.insert(S.List,r)
end
S.ById={};for _,s in S.List do S.ById[s.Id]=s end
-- The shooting ranges, in walking order from the entrance (the shot pays Multiplier times your look's gain, times
-- your gun). Where each shooter's box sits is read from the built lobby at runtime (Training_<Id>.TrainingZone),
-- so the lanes can be moved in Studio without code edits. Gear names the original Block's gym builders
-- (SimulatorLobby), so it keeps its old values.
S.Stations={
 {Id='Starter',Name='Bottle Fence',Gear='TireBag',Required=0,Multiplier=2,Color=C(150,156,166)},
 {Id='Tape',Name='Bullseye Lane',Gear='TapeBag',Required=50,Multiplier=3,Color=C(196,150,96)},
 {Id='Street',Name='Hot Plates',Gear='StreetBag',Required=150,Multiplier=4,Color=C(84,140,220)},
 {Id='Heavy',Name='Spinner Lane',Gear='HeavyBag',Required=500,Multiplier=6,Color=C(222,72,72)},
 {Id='Speed',Name='Shadow Range',Gear='SpeedBag',Required=1000,Multiplier=8,Color=C(246,136,52)},
 {Id='DoubleEnd',Name='Ice Lane',Gear='DoubleEndBag',Required=3000,Multiplier=12,Color=C(160,86,226)},
 {Id='Pro',Name='Toxic Yard',Gear='ProBag',Required=8000,Multiplier=18,Color=C(40,190,190)},
 {Id='Gold',Name='Gold Range',Gear='GoldBag',Required=20000,Multiplier=25,Color=C(240,192,56)},
 {Id='Ring',Name='Champ Ring',Gear='Ring',Required=50000,Multiplier=40,Color=C(230,60,140)},
}
S.StationById={};for _,s in S.Stations do S.StationById[s.Id]=s end
function S.available(power,id) local s=S.ById[id];return s~=nil and power>=s.Required end
function S.nextSkin(power) for _,s in S.List do if power<s.Required then return s end end end
function S.gain(id,multiplier) return (S.ById[id] or S.List[1]).Gain*multiplier end
return S

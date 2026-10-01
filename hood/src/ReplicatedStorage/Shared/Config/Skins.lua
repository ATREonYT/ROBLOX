-- Fifteen original morphs adapted from the supplied v5 reference pack.
local C=Color3.fromRGB
local S={List={}}
local rows={
 {'CornerKid','Corner Kid',0,1,'hoodie',C(173,177,184),C(242,125,105),C(239,211,173),C(107,144,182),'cap','happy'},
 {'Pickpocket','Pickpocket',25,2,'hoodie',C(112,130,75),C(230,228,198),C(235,215,175),C(73,73,80),'hood','sleepy'},
 {'Lookout','Lookout',75,3,'puffer',C(248,166,78),C(250,187,100),C(156,96,57),C(58,57,55),'beanie','worried'},
 {'Bandit','Bandit',150,4,'hoodie',C(51,50,56),C(174,178,188),C(227,181,106),C(79,88,106),'beanie','angry'},
 {'Hustler','Hustler',300,6,'tracksuit',C(146,75,185),C(237,194,66),C(240,222,181),C(146,75,185),'whitehat','smirk'},
 {'Crook','Crook',600,8,'trench',C(201,175,124),C(158,128,82),C(230,210,187),C(96,80,72),'flatcap','serious'},
 {'GetawayDriver','Getaway Driver',1000,10,'racer',C(221,62,66),C(219,226,232),C(153,98,66),C(57,57,66),'hair','smirk'},
 {'Enforcer','Enforcer',1500,12,'vest',C(61,59,72),C(216,221,228),C(239,222,181),C(103,111,87),'bald','angry'},
 {'StreetBoss','Street Boss',2000,16,'furcoat',C(44,45,52),C(246,241,219),C(233,187,116),C(43,44,52),'hair','smirk'},
 {'Gangster','Gangster',3000,22,'suit',C(56,67,106),C(224,64,72),C(229,205,179),C(56,67,106),'fedora','smirk'},
 {'Capo','Capo',5000,30,'suit',C(80,84,95),C(158,54,69),C(195,133,70),C(80,84,95),'hair','serious'},
 {'Consigliere','Consigliere',8000,42,'suit',C(166,171,181),C(64,100,152),C(239,225,204),C(166,171,181),'whitehair','sleepy'},
 {'Underboss','Underboss',12000,58,'suit',C(42,41,40),C(233,233,220),C(129,79,49),C(42,41,40),'blackhat','serious'},
 {'TheDon','The Don',18000,80,'suit',C(237,236,223),C(32,31,32),C(233,207,155),C(237,236,223),'whitehat','sleepy'},
 {'Kingpin','Kingpin',30000,110,'suit',C(41,40,41),C(228,190,72),C(198,131,67),C(41,40,41),'crown','happy'},
}
for i,r in rows do
 table.insert(S.List,{Id=r[1],Name=r[2],Required=r[3],Gain=r[4],Style=r[5],Color=r[6],Accent=r[7],Skin=r[8],Pants=r[9],Hat=r[10],Expression=r[11],Index=i})
end
S.ById={};for _,s in S.List do S.ById[s.Id]=s end
S.Stations={
 {Id='Starter',Name='Corner Gym',Required=0,Multiplier=2,Color=C(162,171,186),X=-29,Z=66,HalfX=8,HalfZ=8},
 {Id='Street',Name='Street Gym',Required=150,Multiplier=4,Color=C(112,165,199),X=-50,Z=66,HalfX=8,HalfZ=8},
 {Id='Boss',Name='Boss Gym',Required=1000,Multiplier=8,Color=C(218,190,98),X=-40,Z=43,HalfX=8,HalfZ=8},
}
S.StationById={};for _,s in S.Stations do S.StationById[s.Id]=s end
function S.available(power,id) local s=S.ById[id];return s~=nil and power>=s.Required end
function S.nextSkin(power) for _,s in S.List do if power<s.Required then return s end end end
function S.gain(id,multiplier) return (S.ById[id] or S.List[1]).Gain*multiplier end
return S

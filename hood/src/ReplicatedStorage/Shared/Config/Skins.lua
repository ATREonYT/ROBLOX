-- The fifteen looks, street kid to Kingpin: ART ONLY now. Players keep their own Roblox avatar (brief 17), so no look is
-- equipped, gives Power or changes walk speed. The rows stay for SkinArt (its mannequin renders, the shoe fit checks)
-- and the original Block's look stand (SimulatorLobby), and their ids stay valid in old saves (EquippedSkin).
-- Color = the main top (jacket/tee), Accent and Trim = the look's second and third colours, Pants, Skin, Hair, Shirt;
-- Style/Hat name the silhouette; Expression the face; Pose the display pose (SkinArt.Poses); Glow (tiers 11+) the
-- sparkle colour, with GlowRate/GlowSize climbing up the tiers and GlowLight a light round the Kingpin. Look picks the
-- recipe (defaults to Id). Required and Gain are the old ladder's numbers, printed by the old stand only.
local C=Color3.fromRGB
local S={List={}}
-- Skin tones are spread over the whole ladder (no tone belongs to a tier); on players Art.equip keeps the
-- player's own tone and only the displays and cards use these.
local A,B,Cc,D,E,F=C(246,204,160),C(240,196,150),C(214,160,110),C(178,120,78),C(124,82,54),C(92,60,40)
local rows={
 {Id='CornerKid',Name='Corner Kid',Required=0,Gain=1,Style='tee',Hat='backwards cap',Color=C(248,248,244),Accent=C(232,44,52),Trim=C(255,140,30),Pants=C(40,110,230),Skin=D,Hair=C(40,28,22),Expression='happy',Pose='carry'},
 {Id='Pickpocket',Name='Runner',Required=25,Gain=2,Style='track jacket',Hat='headphones',Color=C(130,220,50),Accent=C(36,36,44),Trim=C(255,120,40),Pants=C(50,52,62),Skin=A,Hair=C(120,70,30),Expression='smirk',Pose='wave'},
 {Id='Lookout',Name='Lookout',Required=75,Gain=3,Style='puffer',Hat='beanie',Color=C(255,128,30),Accent=C(30,190,200),Trim=C(210,150,70),Pants=C(100,110,70),Skin=E,Hair=C(30,22,18),Expression='worried',Pose='point'},
 {Id='Bandit',Name='Bandit',Required=150,Gain=4,Style='hoodie',Hat='hood and bandana',Color=C(150,60,220),Accent=C(30,30,36),Trim=C(214,178,120),Pants=C(52,98,178),Skin=Cc,Hair=C(40,30,24),Expression='sly',Pose='swagger'},
 {Id='Hustler',Name='Hustler',Required=300,Gain=6,Style='tracksuit',Hat='bucket hat',Color=C(0,180,190),Accent=C(250,250,246),Trim=C(255,196,48),Pants=C(0,180,190),Skin=B,Hair=C(60,40,26),Expression='cool',Pose='boss'},
 {Id='Crook',Name='Crook',Required=600,Gain=8,Style='leather jacket',Hat='bandana',Color=C(62,56,60),Accent=C(225,35,45),Trim=C(214,220,230),Pants=C(52,98,178),Skin=Cc,Hair=C(20,16,14),Expression='smug',Pose='carry'},
 {Id='GetawayDriver',Name='Getaway Driver',Required=1000,Gain=10,Style='racing jacket',Hat='pompadour',Color=C(255,206,30),Accent=C(30,30,36),Trim=C(232,44,52),Pants=C(52,58,78),Skin=F,Hair=C(40,28,20),Expression='smirk',Pose='salute'},
 {Id='Enforcer',Name='Enforcer',Required=1500,Gain=12,Style='leather vest',Hat='flat cap',Color=C(205,30,40),Accent=C(245,245,245),Trim=C(122,74,44),Pants=C(40,40,48),Skin=A,Hair=C(110,70,40),Expression='angry',Pose='hips'},
 {Id='StreetBoss',Name='OG',Required=2000,Gain=16,Style='fur coat',Hat='kangol',Color=C(20,160,90),Accent=C(250,250,245),Trim=C(150,30,60),Pants=C(30,30,36),Shirt=C(150,30,60),Skin=B,Hair=C(50,34,24),Expression='smug',Pose='boss'},
 {Id='Gangster',Name='Shot Caller',Required=3000,Gain=22,Style='zoot suit',Hat='wide brim',Color=C(35,95,225),Accent=C(250,250,245),Trim=C(232,44,52),Pants=C(35,95,225),Skin=E,Hair=C(20,16,14),Expression='smirk',Pose='swagger'},
 {Id='Capo',Name='Capo',Required=5000,Gain=30,Style='sharkskin suit',Hat='black fedora',Color=C(168,178,198),Accent=C(225,30,45),Trim=C(30,30,36),Pants=C(168,178,198),Skin=F,Hair=C(20,16,14),Expression='serious',Pose='carry',Glow=C(190,110,255),GlowRate=5,GlowSize=0.8},
 {Id='Consigliere',Name='Consigliere',Required=8000,Gain=42,Style='double-breasted',Hat='homburg',Color=C(150,20,62),Accent=C(255,196,48),Trim=C(110,66,40),Pants=C(150,20,62),Shirt=C(255,240,210),Skin=B,Hair=C(210,212,218),Expression='wise',Pose='easy',Glow=C(190,110,255),GlowRate=5,GlowSize=0.8},
 {Id='Underboss',Name='Underboss',Required=12000,Gain=58,Style='overcoat',Hat='camel fedora',Color=C(32,32,38),Accent=C(205,150,80),Trim=C(248,248,244),Pants=C(32,32,38),Skin=D,Hair=C(25,22,20),Expression='serious',Pose='boss',Glow=C(255,200,60),GlowRate=7,GlowSize=0.9},
 {Id='TheDon',Name='The Don',Required=18000,Gain=80,Style='dinner jacket',Hat='silver hair',Color=C(250,246,232),Accent=C(220,20,50),Trim=C(28,28,34),Pants=C(30,30,36),Skin=A,Hair=C(200,202,208),Expression='wise',Pose='boss',Glow=C(255,200,60),GlowRate=7,GlowSize=0.9},
 {Id='Kingpin',Name='Kingpin',Required=30000,Gain=110,Style='royal suit',Hat='crown',Color=C(88,30,170),Accent=C(200,20,40),Trim=C(255,196,48),Pants=C(88,30,170),Skin=E,Hair=C(20,18,16),Expression='cool',Pose='royal',Glow=C(255,200,60),GlowRate=9,GlowSize=1,GlowLight=true},
}
for i,r in rows do
 r.Index=i;r.Look=r.Look or r.Id
 table.insert(S.List,r)
end
S.ById={};for _,s in S.List do S.ById[s.Id]=s end
-- The shooting ranges (lanes), in walking order from the entrance (brief 23: the superhero game's ladder). A lane
-- multiplies every shot's Power by its Multiplier (Shared/ShotRules: base x lane x rebirth multiplier x gun x shoes).
--   Rebirth lanes open at a number of rebirths (Rebirths): BAY 1 at once, then every two rebirths up to BAY 6 (x50 at
--     10), and the Champ Ring in the boss yard at 12 (x75: the best free lane).
--   Robux lanes (PRO BAY x100, GOLD BAY x250) open with their game pass only, at any rebirth: Pass is the key in
--     Config/Products.Passes (ownership arrives as the player attribute Pass_<Key>), RobuxPrice the Robux price their
--     label shows (the same number as that pass's Catalog Price). Rebirths is 0 on them and means nothing.
-- Shared/RebirthRules.laneOpen decides (with the player's passes); LobbyService pays only in an open lane.
-- Where each shooter's box sits is read from the built map at runtime (Training_<Id>.TrainingZone), so lanes can move in
-- Studio without code edits; the Ids never change (the map and old saves name them).
-- Name is the lane's one player-facing name everywhere (labels, the HUD hint, the guide). Gear names the original
-- Block's gym builders (SimulatorLobby). Required is always 0: HoodProps' and SimulatorLobby's sign builders print it
-- (the old Power price); nothing gameplay reads it.
S.Stations={
 {Id='Starter',Name='BAY 1',Gear='TireBag',Rebirths=0,Multiplier=1,Required=0,Color=C(150,156,166)},
 {Id='Tape',Name='BAY 2',Gear='TapeBag',Rebirths=2,Multiplier=4,Required=0,Color=C(196,150,96)},
 {Id='Street',Name='BAY 3',Gear='StreetBag',Rebirths=4,Multiplier=10,Required=0,Color=C(84,140,220)},
 {Id='Heavy',Name='BAY 4',Gear='HeavyBag',Rebirths=6,Multiplier=20,Required=0,Color=C(222,72,72)},
 {Id='Speed',Name='BAY 5',Gear='SpeedBag',Rebirths=8,Multiplier=35,Required=0,Color=C(246,136,52)},
 {Id='DoubleEnd',Name='BAY 6',Gear='DoubleEndBag',Rebirths=10,Multiplier=50,Required=0,Color=C(160,86,226)},
 {Id='Pro',Name='PRO BAY',Gear='ProBag',Rebirths=0,Multiplier=100,Pass='RangeVIP1',RobuxPrice=99,Required=0,Color=C(40,190,190)},
 {Id='Gold',Name='GOLD BAY',Gear='GoldBag',Rebirths=0,Multiplier=250,Pass='RangeVIP2',RobuxPrice=249,Required=0,Color=C(240,192,56)},
 {Id='Ring',Name='Champ Ring',Gear='Ring',Rebirths=12,Multiplier=75,Required=0,Color=C(230,60,140)},
}
S.StationById={};for _,s in S.Stations do S.StationById[s.Id]=s end
return S

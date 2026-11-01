--[[
	RareFXPack (ModuleScript): effect templates from Alex's "VFX PACK.rbxl" (Oct 31), as data, built by
	AnimeFX at run time (scripts/genfx2.py made this file). Texture owners checked with GetProductInfo:
	community Creator Store uploads; textures that look ripped from commercial games (T_eff_*, Okami*) are left out.
	Keys: T texture id, Size/Tr/Sq {time, value, envelope, ...}, Col {time, r, g, b, ...}, Life/Rot/RotS/FbR/Spd {min, max},
	Spr {x, y}, Acc {x, y, z}, Dir/Ori/FbL/FbM/Shp enum values, Emit {Count, Delay, Duration} (VFX Forge attributes).
]]
return {
	Charge = {
		Att = {
			{P="Charge-01",At={0,0,0},E={{T=15041986621,LightEmission=1,Brightness=25,ZOffset=1,Size={0,3.687,0,1,1.125,0},Col={0,1,1,1,1,1,1,1},Life={0.3,0.3},Rot={-360,360},FbR={1,1},Spd={0.001,0.001},Spr={75,75},Dir=1,Ori=3,FbL=2,FbM=1,Emit={Count=0,Duration=0.5}},
				{T=15041986460,LightEmission=1,Brightness=25,ZOffset=1,Size={0,3.687,0,1,1.125,0},Col={0,1,1,1,1,1,1,1},Life={0.3,0.3},Rot={-360,360},FbR={1,1},Spd={0.001,0.001},Spr={75,75},Dir=1,Ori=3,FbL=2,FbM=1,Emit={Count=0,Duration=0.5}},
				{T=1084982817,Rate=150,LightEmission=1,Brightness=5,LockedToPart=true,Size={0,0.5,0,1,0.5,0},Col={0,1,1,1,1,1,1,1},Life={0.4,0.4},FbR={1,1},Spd={0.001,0.001},Dir=1}}},
		},
		Beams = {},
		Trails = {},
	},
	Shoot = {
		Att = {
			{P="Shoot-01",At={0,0,0},E={{T=16477162837,Rate=0.75,LightEmission=1,Brightness=5,ZOffset=1,LockedToPart=true,Size={0,0.437,0,0.497,3.75,0,1,5.125,0},Col={0,1,1,1,1,1,1,1},Life={0.5,0.5},Rot={-360,360},FbR={1,1},Spd={0.01,0.01},Dir=5,Ori=3,FbL=2,FbM=1,Emit={Count=1}}}},
		},
		Beams = {},
		Trails = {},
	},
	Stars = {
		Att = {
			{P="Stars-01",At={0,0,0},E={{T=1851669703,Rate=4,LightEmission=2,Brightness=10,LockedToPart=true,Size={0,2,1,1,2,1},Tr={0,1,0,0.499,0,0,1,1,0},Col={0,1,0.831,0.224,1,1,0.831,0.224},Life={1,1},Rot={-360,360},FbR={1,1},Spd={0.001,0.001},Dir=5,FbM=1,Emit={Count=10,Delay=0.1}},
				{T=1075864321,Rate=2,LightEmission=1,Brightness=10,LockedToPart=true,Size={0,4.5,0,1,4.5,0},Tr={0,1,0,0.499,0.736,0,1,1,0},Col={0,1,0.831,0.224,1,1,0.831,0.224},Life={1,1},Rot={-360,360},FbR={1,1},Spd={0.001,0.001},Dir=5,FbM=1,Emit={Count=10,Delay=0.1}}}},
		},
		Beams = {},
		Trails = {},
	},
	Shiny = {
		Att = {
			{P="Shiny-01",At={0,0,0},E={{T=1075864321,Rate=1.5,LightEmission=1,Brightness=5,ZOffset=1,LockedToPart=true,Size={0,1.5,0,1,1.5,0},Tr={0,1,0,0.5,0,0,1,1,0},Col={0,1,0.847,0.298,1,1,0.847,0.298},Life={2.5,2.5},FbR={1,1},Spd={0.001,0.001},Dir=1},
				{T=1053548563,Rate=100,LightEmission=1,ZOffset=0.2,LockedToPart=true,Size={0,2.188,1,1,3.5,1},Tr={0,1,0,0.5,0.7,0,1,1,0},Col={0,1,0.89,0.447,1,1,0.89,0.447},Life={1,1},Rot={-360,360},FbR={1,1},Spd={0,0},Dir=1}}},
		},
		Beams = {},
		Trails = {},
	},
	Lightning = {
		Att = {
			{P="Lighting-01",At={0,-0.6,0},E={{T=16954586568,Rate=15,LightEmission=1,ZOffset=0.5,LockedToPart=true,Size={0,8.751,0,1,13.369,0},Tr={0,1,0,0.2,0,0,0.5,0,0,0.801,0,0,1,1,0},Col={0,0.169,0.529,1,1,0.169,0.529,1},Life={0.3,0.3},Rot={-360,360},FbR={1,1},Spd={0.001,0.001},Spr={1,1},Dir=4,Ori=3,FbM=1,ShIO=1},
				{T=16670162492,Rate=15,LightEmission=1,ZOffset=0.5,LockedToPart=true,Size={0,8,0,1,8,0},Tr={0,1,0,0.2,0,0,0.5,0,0,0.801,0,0,1,1,0},Col={0,0.169,0.529,1,1,0.169,0.529,1},Life={0.3,0.3},Rot={-360,360},FbR={1,1},Spd={0.001,0.001},Spr={1,1},Dir=4,Ori=3,FbM=1,ShIO=1},
				{T=16954602535,Rate=15,LightEmission=1,ZOffset=1,LockedToPart=true,Size={0,20,0,1,20,0},Tr={0,1,0,0.2,0,0,0.5,0,0,0.801,0,0,1,1,0},Col={0,0.169,0.529,1,1,0.169,0.529,1},Life={0.3,0.3},Rot={-360,360},FbR={1,1},Spd={0.001,0.001},Dir=4,Ori=3,FbM=1,ShIO=1},
				{T=16664675233,Rate=15,LightEmission=1,Brightness=10,ZOffset=2,Drag=2,LockedToPart=true,Size={0,0,0,1,6.359,0},Tr={0,1,0,0.494,0,0,1,1,0},Col={0,0.169,0.529,1,1,0.169,0.529,1},Life={0.8,0.8},Rot={-360,360},FbR={1,1},Spd={15,15},Spr={60,60},Dir=4,FbL=2,FbM=1,ShIO=1}}},
			{P="Lighting-01",At={0,9.9,0},E={{T=13771290435,Rate=5,LightEmission=0.5,Brightness=5,ZOffset=1,Size={0,13,0,1,13,0},Col={0,0.169,0.529,1,1,0.169,0.529,1},Life={0.5,0.5},FbR={32,32},Spd={0.1,0.1},Dir=1,Ori=1,FbL=2,FbM=1,Emit={Count=1,Delay=0}}}},
		},
		Beams = {},
		Trails = {},
	},
	Lightning2 = {
		Att = {
			{P="Lighting-03",At={0,0,0},E={{T=16676250078,Rate=5.15,LightEmission=1,Brightness=5,Size={0,2,0,1,2,0},Tr={0,1,0,0.25,0,0,1,1,0},Sq={0,-0.2,0,1,-0.2,0},Col={0,0,0.518,1,1,0,0.518,1},Life={0.3,0.3},Rot={-360,360},FbR={1,1},Spd={0,0},Spr={-360,360},Dir=1,FbL=2,FbM=1},
				{T=16676262776,Rate=5.35,LightEmission=1,Brightness=5,Size={0,2,0,1,2,0},Tr={0,1,0,0.25,0,0,1,1,0},Sq={0,-0.2,0,1,-0.2,0},Col={0,0,0.518,1,1,0,0.518,1},Life={0.3,0.3},Rot={-360,360},FbR={1,1},Spd={0,0},Spr={-360,360},Dir=1,FbL=2,FbM=1},
				{T=16951501423,Rate=5.5,LightEmission=1,Brightness=5,Size={0,2,0,1,2,0},Tr={0,1,0,0.25,0,0,1,1,0},Sq={0,-0.2,0,1,-0.2,0},Col={0,0,0.518,1,1,0,0.518,1},Life={0.2,0.2},Rot={-360,360},FbR={1,1},Spd={0,0},Spr={-360,360},Dir=1,FbL=1,FbM=1},
				{T=16951505034,Rate=5.5,LightEmission=1,Brightness=5,Size={0,2,0,1,2,0},Tr={0,1,0,0.25,0,0,1,1,0},Sq={0,-0.2,0,1,-0.2,0},Col={0,0,0.518,1,1,0,0.518,1},Life={0.2,0.2},Rot={-360,360},FbR={1,1},Spd={0,0},Spr={-360,360},Dir=1,FbL=1,FbM=1}}},
		},
		Beams = {},
		Trails = {},
	},
	Explosion = {
		Att = {
			{P="Explosion-01",At={0,0,0},E={{T=11395090403,Rate=10,Brightness=4.2,ZOffset=1,Drag=5,Size={0,10.7,0.867,1,12.675,5.193},Tr={0,0,0,0.699,0,0,0.754,0.4,0,0.829,0.713,0,0.899,0.881,0,0.952,0.956,0,1,1,0},Sq={0,0,0,1,-0.12,0.24},Col={0,1,0.49,0.361,1,1,0.49,0.361},Life={0.5,0.5},Rot={-360,360},RotS={-30,30},FbR={30,30},Spd={20,20},Spr={-360,360},Dir=1,FbL=2,FbM=1},
				{T=11395089850,Rate=10,Brightness=4.2,ZOffset=1,Drag=5,Size={0,10.7,0.867,1,12.675,5.193},Tr={0,0,0,0.695,0,0,0.769,0.537,0,0.862,0.844,0,0.933,0.95,0,1,1,0},Sq={0,0,0,1,-0.12,0.24},Col={0,1,0.49,0.361,1,1,0.49,0.361},Life={0.5,0.5},Rot={-360,360},RotS={-30,30},FbR={30,30},Spd={20,20},Spr={-360,360},Dir=1,FbL=2,FbM=1},
				{T=10180479311,Rate=6.167,LightEmission=0.5,Brightness=4,Drag=1,Size={0,13.5,0,0.25,27,0.5,1,27,0},Tr={0,0.169,0.094,1,1,0},Col={0,0,0,0,1,0,0,0},Life={2,4},Rot={-360,360},RotS={-18,18},FbR={1,1},Spd={5,5},Spr={-360,360},Dir=1},
				{T=8068783649,Rate=250,LightEmission=1,Brightness=500,Drag=2,Size={0,0,0,0.401,0.688,0.688,0.67,0.055,0.055,1,0,0},Col={0,1,0.137,0.024,1,1,0.137,0.024},Life={0.8,2.5},Rot={0,360},RotS={-700,700},FbR={1,1},Spd={30,30},Spr={360,360},Dir=1,Ori=2},
				{T=11395118687,Rate=10,Brightness=4.2,ZOffset=1,Drag=5,Size={0,10.7,0.867,1,12.675,5.193},Tr={0,0,0,0.697,0,0,0.77,0.5,0,0.848,0.787,0,0.925,0.925,0,1,1,0},Sq={0,0,0,1,-0.12,0.24},Col={0,1,0.49,0.361,1,1,0.49,0.361},Life={0.5,0.5},Rot={-360,360},RotS={-30,30},FbR={30,30},Spd={20,20},Spr={-360,360},Dir=1,FbL=2,FbM=1}}},
		},
		Beams = {},
		Trails = {},
	},
	Crack = {
		Att = {
			{P="Big-Crack-01",At={0,-0.6,0},E={{T=17067057050,Rate=15,LightEmission=1,Brightness=2,ZOffset=1,LockedToPart=true,Size={0,12,0,1,12,0},Tr={0,1,0,0.2,0,0,0.5,0,0,0.801,0,0,1,1,0},Col={0,1,0.161,0.012,1,1,0.161,0.012},Life={0.3,0.3},Rot={-360,360},FbR={1,1},Spd={0.001,0.001},Dir=4,Ori=3,FbM=1,ShIO=1},
				{T=17067103637,Rate=15,ZOffset=0.5,LockedToPart=true,Size={0,20,0,1,20,0},Tr={0,1,0,0.2,0,0,0.5,0,0,0.801,0,0,1,1,0},Col={0,0,0,0,1,0,0,0},Life={0.3,0.3},Rot={-360,360},FbR={1,1},Spd={0.001,0.001},Dir=4,Ori=3,FbM=1,ShIO=1},
				{T=16955854038,Rate=250,Brightness=5,ZOffset=0.6,Drag=2,LockedToPart=true,FlipbookStartRandom=true,Size={0,0,0,0.252,0,0,0.458,3.446,0,1,0,0},Col={0,0,0,0,1,0,0,0},Life={0.5,0.5},Rot={-360,360},FbR={1,1},Spd={30,50},Spr={0,360},Dir=5,FbL=2,FbM=1,ShS=1},
				{T=13818306392,Rate=250,LightEmission=0.1,Brightness=5,ZOffset=0.7,Drag=2,LockedToPart=true,FlipbookStartRandom=true,Size={0,0,0,0.252,0,0,0.458,3.446,0,1,0,0},Col={0,1,0.208,0.047,1,1,0.208,0.047},Life={0.5,0.5},Rot={-360,360},FbR={1,1},Spd={30,50},Spr={0,360},Dir=5,FbL=2,FbM=1,ShS=1}}},
		},
		Beams = {},
		Trails = {},
	},
	HolyAura = {
		Att = {
			{P="Head",At={0,0.6,0},E={}},
			{P="Head",At={0,0.6,0},E={}},
			{P="Head",At={0,0,-0.6},E={}},
			{P="Head",At={0,0,0},E={}},
			{P="Torso",At={0,1,0},E={}},
			{P="Torso",At={0,0,-0.5},E={}},
			{P="Torso",At={0,0,0.5},E={}},
			{P="Torso",At={-1,1,0},E={}},
			{P="Torso",At={1,1,0},E={}},
			{P="Torso",At={0,-1,-0.5},E={}},
			{P="Torso",At={0,-1,0},E={}},
			{P="Torso",At={0,-1,0.5},E={}},
			{P="Left Arm",At={0,1,0},E={}},
			{P="Left Arm",At={0,-1,0},E={}},
			{P="Right Arm",At={0,1,0},E={}},
			{P="Right Arm",At={0,-1,0},E={}},
			{P="Left Leg",At={0,-1,0},E={}},
			{P="Right Leg",At={0,-1,0},E={}},
			{P="HumanoidRootPart",At={0,0,0},E={}},
			{P="HumanoidRootPart",At={-4.5,0.5,0},E={{T=14006783533,Rate=1.5,LightEmission=1,Brightness=5,ZOffset=2,LockedToPart=true,Size={0,2,0,1,2,0},Tr={0,1,0,0.293,0,0,0.497,0,0,0.701,0,0,1,1,0},Col={0,1,0.867,0.329,1,1,0.867,0.329},Life={1,1},FbR={1,1},Spd={0.001,0.001},Dir=1,FbM=1},
				{T=17086075673,Rate=1.5,LightEmission=1,Brightness=5,ZOffset=2,LockedToPart=true,Size={0,0,0,1,2.5,0},Tr={0,1,0,0.293,0,0,0.497,0,0,0.701,0,0,1,1,0},Col={0,1,0.867,0.329,1,1,0.867,0.329},Life={1,1},FbR={1,1},Spd={0.001,0.001},Dir=1,FbM=1}}},
			{P="HumanoidRootPart",At={0,5,0},E={{T=17086022111,Rate=5,LightEmission=1,Brightness=5,ZOffset=2,LockedToPart=true,Size={0,3,0,0.007,0,0,1,3.981,0},Tr={0,1,0,0.293,0,0,0.497,0,0,0.701,0,0,1,1,0},Col={0,1,0.867,0.329,1,1,0.867,0.329},Life={1,1},Rot={-360,360},RotS={-500,-500},FbR={1,1},Spd={0.001,0.001},Dir=1,FbM=1},
				{T=17087151546,Rate=15,LightEmission=1,Brightness=5,ZOffset=2,LockedToPart=true,Size={0,0,0,1,0.874,0},Tr={0,1,0,0.293,0,0,0.497,0,0,0.701,0,0,1,1,0},Col={0,1,0.867,0.329,1,1,0.867,0.329},Life={1,1},Rot={-360,360},FbR={1,1},Spd={4,4},Spr={360,360},Dir=1,FbM=1}}},
			{P="HumanoidRootPart",At={4.5,0.5,0},E={{T=14006783533,Rate=1.5,LightEmission=1,Brightness=5,ZOffset=2,LockedToPart=true,Size={0,2,0,1,2,0},Tr={0,1,0,0.293,0,0,0.497,0,0,0.701,0,0,1,1,0},Col={0,1,0.867,0.329,1,1,0.867,0.329},Life={1,1},FbR={1,1},Spd={0.001,0.001},Dir=1,FbM=1},
				{T=17086075673,Rate=1.5,LightEmission=1,Brightness=5,ZOffset=2,LockedToPart=true,Size={0,0,0,1,2.5,0},Tr={0,1,0,0.293,0,0,0.497,0,0,0.701,0,0,1,1,0},Col={0,1,0.867,0.329,1,1,0.867,0.329},Life={1,1},FbR={1,1},Spd={0.001,0.001},Dir=1,FbM=1}}},
		},
		Beams = {{A0=20,A1=21,B={T=12781800668,LightEmission=1,LightInfluence=0,Brightness=10,TextureLength=1,TextureSpeed=3,CurveSize0=0,CurveSize1=0,Width0=0.5,Width1=5,ZOffset=0,Segments=10,FaceCamera=true,Tr={0,0,0,1,0,0},Col={0,1,1,0.365,1,1,1,0.365},TM=0}},{A0=20,A1=21,B={T=17087331428,LightEmission=1,LightInfluence=0,Brightness=10,TextureLength=1,TextureSpeed=3,CurveSize0=0,CurveSize1=0,Width0=0.5,Width1=3,ZOffset=0,Segments=10,FaceCamera=true,Tr={0,0,0,1,0,0},Col={0,1,1,0.365,1,1,1,0.365},TM=0}},{A0=22,A1=21,B={T=17087331428,LightEmission=1,LightInfluence=0,Brightness=10,TextureLength=1,TextureSpeed=3,CurveSize0=0,CurveSize1=0,Width0=0.5,Width1=3,ZOffset=0,Segments=10,FaceCamera=true,Tr={0,0,0,1,0,0},Col={0,1,1,0.365,1,1,1,0.365},TM=0}},{A0=22,A1=21,B={T=12781800668,LightEmission=1,LightInfluence=0,Brightness=10,TextureLength=1,TextureSpeed=3,CurveSize0=0,CurveSize1=0,Width0=0.5,Width1=5,ZOffset=0,Segments=10,FaceCamera=true,Tr={0,0,0,1,0,0},Col={0,1,1,0.365,1,1,1,0.365},TM=0}}},
		Trails = {},
	},
	Ball = {
		Att = {
			{P="Ball-01",At={0,0,0},E={{T=11187840108,Rate=125,Brightness=5,Drag=1,LockedToPart=true,Size={0,0,0,0.257,2.718,0,1,0,0},Tr={0,1,0,0.293,0,0,1,0,0},Col={0,0.808,0.224,0.059,1,0.808,0.224,0.059},Life={0.5,0.75},FbR={1,1},Spd={-40,-40},Spr={20,20},Dir=5,ShS=1,Emit={Delay=0}}}},
			{P="Ball-01",At={0,0,-3.4},E={{T=13818306392,Rate=150,LightEmission=0.1,Brightness=5,ZOffset=0.5,Drag=1,LockedToPart=true,FlipbookStartRandom=true,Size={0,1.845,0,0.276,3.398,0,1,0,0},Col={0,1,0.208,0.047,1,1,0.208,0.047},Life={0.65,0.65},Rot={-360,360},FbR={1,1},Spd={20,20},Spr={0,360},Acc={0,0,200},Dir=1,FbL=2,FbM=1,ShS=1},
				{T=16955854038,Rate=150,LightEmission=0.1,Brightness=5,ZOffset=0.45,Drag=1,LockedToPart=true,FlipbookStartRandom=true,Size={0,1.845,0,0.276,3.398,0,1,0,0},Col={0,0,0,0,1,0,0,0},Life={0.65,0.65},Rot={-360,360},FbR={1,1},Spd={20,20},Spr={0,360},Acc={0,0,200},Dir=1,FbL=2,FbM=1,ShS=1}}},
			{P="Ball-01",At={0,0,-4.646},E={{T=17063107542,Rate=2,LightEmission=0.1,Brightness=10,ZOffset=1,Drag=1,LockedToPart=true,FlipbookStartRandom=true,Size={0,0,0,1,10,0},Tr={0,1,0,0.201,0,0,0.797,0,0,1,1,0},Col={0,1,0.208,0.047,1,1,0.208,0.047},Life={1,1},Rot={-360,360},FbR={1,1},Spd={-3,-3},Spr={5,5},Dir=5,Ori=3,FbM=1,ShS=1}}},
		},
		Beams = {},
		Trails = {},
	},
	Projectile = {
		Att = {
			{P="Projectile",At={-2.569,0,0},E={}},
			{P="Projectile",At={2.594,0,0},E={}},
			{P="Projectile",At={0,0,0},E={{T=11364555263,Rate=100,Brightness=5,ZOffset=0.395,Drag=10,Size={0,1.723,0,0.303,4.254,0.281,1,4.852,0.774},Tr={0,0.5,0,0.214,0,0,0.491,0,0,0.773,0,0,1,1,0},Col={0,1,1,1,0.216,0.667,0.333,1,1,0,0,0},Life={1,2},Rot={-360,360},FbR={1,1},Spd={0.563,11.251},Spr={-90,90},Dir=1,FbL=3,FbM=1,Emit={Count=5,Delay=0}},
				{T=11589526610,Rate=100,Brightness=100,ZOffset=0.459,Drag=100,LockedToPart=true,Size={0,0.337,0,0.301,1.146,0,1,1.146,0},Col={0,1,1,1,0.054,0.412,0.239,0.612,0.185,0.675,0.388,1,0.499,0.675,0.388,1,0.606,0.545,0.314,0.808,1,0,0,0},Life={0.3,0.7},Rot={-360,360},FbR={1,1},Spd={0.412,4.122},Spr={-90,90},Dir=1,FbL=2,FbM=1,Emit={Count=60,Delay=0}},
				{T=8037777212,Rate=31,LightEmission=0.5,Brightness=5,ZOffset=3,LockedToPart=true,Size={0,5,0,1,5,0},Tr={0,0,0,0.634,0,0,1,1,0},Sq={0,-1,0,1,-1,0},Col={0,0.675,0.384,1,1,0.675,0.384,1},Life={0.7,0.7},FbR={1,1},Spd={0,0},Dir=1,Emit={Count=1,Delay=0}},
				{T=8037777212,Rate=31,LightEmission=0.5,Brightness=5,ZOffset=3,LockedToPart=true,Size={0,5,0,1,5,0},Tr={0,0,0,0.634,0,0,1,1,0},Sq={0,-1,0,1,-1,0},Col={0,0.667,0.333,1,1,0.667,0.333,1},Life={0.7,0.7},Rot={90,90},FbR={1,1},Spd={0,0},Dir=1,Emit={Count=1,Delay=0}}}},
		},
		Beams = {},
		Trails = {{A0=2,A1=1,B={T=9035707329,LightEmission=0,LightInfluence=0,Brightness=4.5,Lifetime=0.25,TextureLength=1,MinLength=0.1,MaxLength=0,FaceCamera=true,Tr={0,0,0,1,0,0},W={0,0,0,0.044,0.188,0,0.164,1,0,0.285,0.287,0,0.421,0.131,0,1,0,0},Col={0,0,0,0,0.083,0.667,0.667,1,0.275,0.667,0.333,1,0.9,0.004,0.009,0.013,1,0,0,0},TM=0}}},
	},
	Tornado = {
		Att = {
			{P="Tornado-01",At={0,-0.6,0},E={{T=16669803246,Rate=100,LightEmission=0.75,ZOffset=1,LockedToPart=true,Size={0,0,0,1,14,0},Tr={0,0,0,0.801,0,0,1,1,0},Col={0,0.451,0.451,0.451,1,0.451,0.451,0.451},Life={1,1},Rot={-360,360},RotS={250,250},FbR={1,1},Spd={17.5,17.5},Spr={6,6},Dir=4,Ori=3,FbM=1,ShIO=1},
				{T=16957275379,Rate=15,LightEmission=1,ZOffset=1,LockedToPart=true,Size={0,4.312,0,1,13.028,0},Tr={0,1,0,0.2,0,0,0.5,0,0,0.801,0,0,1,1,0},Col={0,0.451,0.451,0.451,1,0.451,0.451,0.451},Life={0.3,0.3},Rot={-360,360},FbR={1,1},Spd={0.001,0.001},Spr={1,1},Dir=4,Ori=3,FbM=1,ShIO=1},
				{T=16669903446,Rate=100,LightEmission=0.75,ZOffset=1,LockedToPart=true,Size={0,0,0,1,14,0},Tr={0,0,0,0.801,0,0,1,1,0},Col={0,0.451,0.451,0.451,1,0.451,0.451,0.451},Life={1,1},Rot={-360,360},RotS={250,250},FbR={1,1},Spd={17.5,17.5},Spr={6,6},Dir=4,Ori=3,FbM=1,ShIO=1},
				{T=16670162492,Rate=15,LightEmission=1,ZOffset=1,LockedToPart=true,Size={0,2,0,1,10,0},Tr={0,1,0,0.2,0,0,0.5,0,0,0.801,0,0,1,1,0},Col={0,0.451,0.451,0.451,1,0.451,0.451,0.451},Life={0.3,0.3},Rot={-360,360},FbR={1,1},Spd={0.001,0.001},Spr={1,1},Dir=4,Ori=3,FbM=1,ShIO=1},
				{T=16669782675,Rate=100,LightEmission=0.75,ZOffset=1,LockedToPart=true,Size={0,0,0,1,9.146,0},Tr={0,1,0,0.2,0,0,0.5,0,0,0.801,0,0,1,1,0},Col={0,0.451,0.451,0.451,1,0.451,0.451,0.451},Life={1,1},Rot={-360,360},RotS={250,250},FbR={1,1},Spd={17.5,17.5},Spr={6,6},Dir=4,Ori=3,FbM=1,ShIO=1},
				{T=16669505937,Rate=40,ZOffset=1,LockedToPart=true,Size={0,0,0,1,14.97,0},Tr={0,1,0,0.498,0.869,0,1,1,0},Col={0,1,1,1,1,1,1,1},Life={1,1},Rot={-360,360},RotS={100,100},FbR={1,1},Spd={2,2},Spr={5,5},Dir=4,Ori=3,FbM=1,ShIO=1},
				{T=12685367098,Rate=10,LightEmission=1,Brightness=0.3,Drag=9,LockedToPart=true,Size={0,0,0,0.487,12.227,0,1,19.584,0},Tr={0,1,0,0.499,0,0,1,1,0},Col={0,0.325,0.325,0.325,1,0.325,0.325,0.325},Life={1,1},Rot={-360,360},RotS={100,100},FbR={1,1},Spd={0,9.585},Spr={1,1},Dir=1,Ori=3,FbM=1,Emit={Count=4,Delay=0.1}}}},
		},
		Beams = {},
		Trails = {},
	},
	Wind = {
		Att = {
			{P="Wind-02",At={0,0,0},E={{T=12144047227,Rate=10,Brightness=2,ZOffset=1.028,Drag=9,Size={0,4.061,0,1,4.061,0},Tr={0,1,0,0.247,0.864,0,1,1,0},Col={0,1,1,1,1,1,1,1},Life={0.3,1},Rot={-3603,60},FbR={1,1},Spd={30,30},Spr={0,360},Dir=5,FbL=2,FbM=1,Emit={Count=10,Delay=0.1}},
				{T=12685367098,Rate=10,LightEmission=1,Brightness=0.3,Drag=9,LockedToPart=true,Size={0,0,0,0.438,7.153,0,1,7.456,0},Tr={0,0,0,1,1,0},Col={0,0.325,0.325,0.325,1,0.325,0.325,0.325},Life={0.3,1},Rot={-360,360},RotS={-60,60},FbR={1,1},Spd={0,9.585},Spr={14,14},Dir=1,Ori=3,FbM=1,Emit={Count=4,Delay=0.1}},
				{T=14595543880,Rate=5,LightEmission=1,Size={0,7,0,1,7,0},Tr={0,1,0,0.276,0.725,0,1,1,0},Col={0,0.549,0.549,0.549,1,0.549,0.549,0.549},Life={0.6,0.6},Rot={-360,360},RotS={15,15},FbR={16,16},Spd={0.001,0.001},Spr={10,10},Dir=1,Ori=3,FbL=2,FbM=1,Emit={Count=1,Delay=0.1}}}},
		},
		Beams = {},
		Trails = {},
	},
	SlashImpact = {
		Att = {
			{P="Slash-Impact-01",At={0,0,0},E={{T=16923007448,Rate=10,LightEmission=1,Brightness=5,ZOffset=1,LockedToPart=true,Size={0,2,0,1,2,0},Tr={0,1,0,0.1,0,0,1,0,0},Col={0,1,1,1,1,1,1,1},Life={0.4,0.4},Rot={88,92},FbR={1,1},Spd={0.001,0.001},Spr={3,3},Dir=5,Ori=3,FbL=2,FbM=1,Emit={Count=10,Delay=0.1}},
				{T=16923007448,Rate=15,LightEmission=1,Brightness=5,ZOffset=1,LockedToPart=true,Size={0,0,0,1,2.67,0},Tr={0,1,0,0.499,0,0,1,1,0},Col={0,1,1,1,1,1,1,1},Life={0.4,0.4},Rot={85,95},FbR={1,1},Spd={10,10},Spr={5,0},Acc={0,0,-10},Ori=2,FbL=2,FbM=1,Emit={Count=10,Delay=0.1}},
				{T=16923007448,Rate=15,LightEmission=1,Brightness=5,ZOffset=1,LockedToPart=true,Size={0,0,0,1,2.67,0},Tr={0,1,0,0.499,0,0,1,1,0},Col={0,1,1,1,1,1,1,1},Life={0.4,0.4},Rot={85,95},FbR={1,1},Spd={10,10},Spr={5,0},Acc={0,0,-10},Dir=3,Ori=2,FbL=2,FbM=1,Emit={Count=10,Delay=0.1}}}},
		},
		Beams = {},
		Trails = {},
	},
	Burst = {
		Att = {
			{P="Explosion",At={0,0,0},E={{T=8888098483,Rate=5,LightInfluence=0.15,Size={0,0,0,0.054,9.509,0.851,0.189,16.754,2.038,0.398,22.188,2.703,0.633,26.037,3.328,1,31.244,4.981},Tr={0,1,0,0.088,0.519,0.087,1,1,0},Col={0,0,0,0,1,0,0,0},Life={0.65,1.45},Rot={-90,-90},FbR={1,1},Spd={0.05,0.05},Spr={360,360},Dir=5,Ori=3,Emit={Count=2,Delay=0}},
				{T=8904012224,Rate=8,LightEmission=1,LightInfluence=0.15,Brightness=5,TimeScale=0.9,Size={0,0,0,0.054,11.03,0.987,0.189,19.435,2.364,0.398,25.738,3.135,0.633,30.203,3.861,1,36.243,5.778},Tr={0,1,0,0.085,0.738,0.083,1,1,0},Col={0,0.675,0.384,1,1,0.675,0.384,1},Life={1,1.5},Rot={-360,360},FbR={1,1},Spd={0.058,0.058},Spr={360,360},Dir=1,Ori=3,Emit={Count=5,Delay=0}},
				{T=6862984716,Rate=25,Brightness=6,Size={0,0,0,0.082,15.937,0,0.231,33.748,4.389,0.491,49.685,7.316,1,59.06,10.242},Tr={0,0,0,0.317,0.675,0,0.5,0.85,0,1,1,0},Col={0,0,0,0,1,0,0,0},Life={0.5,1.5},Rot={-360,360},RotS={-1050,-700},FbR={1,1},Spd={0.001,0.001},Spr={360,360},Dir=1,Ori=3,Emit={Count=4,Delay=0}},
				{T=8048608283,Rate=10,LightInfluence=0.1,Drag=2,TimeScale=0.85,Size={0,1.132,0,0.083,12.867,2.768,0.371,28.159,5.273,1,49.21,7.046},Tr={0,0,0,0.269,0.512,0.037,0.528,0.8,0.027,1,1,0},Col={0,0,0,0,1,0,0,0},Life={0.2,0.5},Rot={-360,360},FbR={1,1},Spd={0.053,0.053},Spr={360,360},Dir=1,Ori=3,Emit={Count=5,Delay=0}},
				{T=8048608283,Rate=10,LightEmission=1,LightInfluence=0.1,Brightness=5,Drag=2,TimeScale=0.7,Size={0,0,0,0.081,15.306,3.968,0.261,27.211,4.315,0.463,33.447,4.716,1,39.683,5.669},Tr={0,0,0,0.137,0.069,0.018,0.241,0.306,0.024,0.309,0.6,0.029,0.407,0.769,0.028,0.557,0.856,0.037,1,1,0},Col={0,0.675,0.384,1,1,0.675,0.384,1},Life={0.2,0.35},Rot={-360,360},FbR={1,1},Spd={0.084,0.084},Spr={360,360},Dir=1,Ori=3,Emit={Count=7,Delay=0}},
				{T=10439119562,Rate=100,LightEmission=1,Brightness=5,Drag=10,LockedToPart=true,Size={0,0,0,0.251,10.21,3.565,1,0,0},Sq={0,0.188,0,1,0.075,2.925},Col={0,0.675,0.384,1,1,0.675,0.384,1},Life={0.3,0.45},Rot={90,90},FbR={1,1},Spd={158.498,256.549},Spr={-360,360},Dir=1,Ori=2,Emit={Count=35,Delay=0}},
				{T=10439119562,Rate=100,Brightness=5,Drag=10,LockedToPart=true,Size={0,0,0,0.251,10.21,3.565,1,0,0},Sq={0,0.188,0,1,0.075,2.925},Col={0,0,0,0,1,0,0,0},Life={0.3,0.45},Rot={90,90},FbR={1,1},Spd={158.498,256.549},Spr={-360,360},Dir=1,Ori=2,Emit={Count=35,Delay=0}},
				{T=11536435403,Rate=0,LightEmission=1,Brightness=5,ZOffset=5.587,Size={0,0,3.725,0.1,6.159,3.725,0.2,10.1,3.725,0.3,12.924,3.725,0.4,15.042,3.725,0.5,16.662,3.725,0.6,17.907,3.725,0.7,18.859,3.725,0.8,19.576,3.725,0.9,20.105,3.725,1,20.487,3.725},Tr={0,0,0,0.45,0,0,1,1,0},Col={0,0.675,0.384,1,1,0.675,0.384,1},Life={0.125,0.175},Rot={-360,360},FbR={1,1},Spd={0,0},Dir=1,Emit={Count=3,Delay=0}},
				{T=8037777212,Rate=31,LightEmission=1,Brightness=5,ZOffset=20,LockedToPart=true,Size={0,8.272,0,0.207,33.743,0,1,0,0},Tr={0,0,0,0.634,0,0,1,1,0},Sq={0,-1,0,1,-1,0},Col={0,0.675,0.384,1,1,0.675,0.384,1},Life={0.7,0.7},FbR={1,1},Spd={0,0},Dir=1,Emit={Count=1,Delay=0}},
				{T=8037777212,Rate=31,LightEmission=1,Brightness=5,ZOffset=20,LockedToPart=true,Size={0,8.272,0,0.207,33.743,0,1,0,0},Tr={0,0,0,0.634,0,0,1,1,0},Sq={0,-1,0,1,-1,0},Col={0,0.675,0.384,1,1,0.675,0.384,1},Life={0.7,0.7},Rot={90,90},FbR={1,1},Spd={0,0},Dir=1,Emit={Count=1,Delay=0}},
				{T=9997556038,Rate=40,LightEmission=1,Brightness=5,ZOffset=3.674,Drag=7,Size={0,0,0,0.25,4.582,0,1,0,0},Col={0,0.675,0.384,1,1,0.675,0.384,1},Life={1,2},Rot={-360,360},RotS={-360,360},FbR={1,1},Spd={70.497,158.618},Spr={-360,360},Dir=1,Emit={Count=35,Delay=0}},
				{T=9997556038,Rate=40,Brightness=5,ZOffset=3.674,Drag=7,Size={0,0,0,0.25,4.582,0,1,0,0},Col={0,0,0,0,1,0,0,0},Life={1,2},Rot={-360,360},RotS={-360,360},FbR={1,1},Spd={70.497,158.618},Spr={-360,360},Dir=1,Emit={Count=35,Delay=0}},
				{T=10632727506,Rate=100,LightEmission=1,Brightness=7.5,ZOffset=3.04,Drag=8,Size={0,0,0,0.25,1.368,1.368,1,0,0},Tr={0,0.15,0,1,0.15,0},Col={0,0.675,0.384,1,1,0.675,0.384,1},Life={0.45,0.8},Rot={-360,360},FbR={1,1},Spd={68.4,136.8},Spr={-360,360},Dir=1,Emit={Count=50,Delay=0}},
				{T=10632727506,Rate=100,LightInfluence=0.3,Brightness=7.5,ZOffset=3.723,Drag=8,Size={0,0,0,0.25,1.675,1.675,1,0,0},Tr={0,0.15,0,1,0.15,0},Col={0,0,0,0,1,0,0,0},Life={0.2,0.3},Rot={-360,360},FbR={1,1},Spd={83.756,167.513},Spr={-360,360},Dir=1,Emit={Count=50,Delay=0}},
				{T=10632727506,Rate=100,LightInfluence=0.3,Brightness=7.5,ZOffset=3.04,Drag=8,Size={0,0,0,0.25,1.368,1.368,1,0,0},Tr={0,0.15,0,1,0.15,0},Col={0,0,0,0,1,0,0,0},Life={0.2,0.3},Rot={-360,360},FbR={1,1},Spd={68.4,136.8},Spr={-360,360},Dir=1,Emit={Count=50,Delay=0}},
				{T=4963436775,Rate=10,LightEmission=1,Brightness=10,ZOffset=2,Drag=15,Size={0,0.984,0,0.544,2.732,0,0.687,2.404,0.107,0.753,1.148,0.099,0.837,2.623,0.079,0.899,0.984,0.06,0.96,1.093,0.044,1,0,0},Tr={0,0.24,0,1,0,0},Sq={0,-1.677,0,0.5,0,0,0.748,3,0,0.871,-2,0,1,3,0},Col={0,0.675,0.384,1,1,0.675,0.384,1},Life={0.4,0.6},FbR={1,1},Spd={150,250},Spr={360,360},Acc={0,-10,0},Dir=5,Ori=2,Emit={Count=35,Delay=0}},
				{T=10176632695,Rate=28,Brightness=0.68,ZOffset=8.227,Size={0,0,0,0.3,20.568,2.057,1,34.966,6.171},Tr={0,1,0,0.499,0.562,0,1,1,0},Col={0,0.247,0.247,0.247,1,0.247,0.247,0.247},Life={0.2,0.3},Rot={-360,360},FbR={1,1},Spd={0.004,0.004},Spr={-360,360},Dir=5,Ori=3,Emit={Count=7,Delay=0}},
				{T=10176632695,Rate=60,Brightness=10,ZOffset=6.875,Size={0,0,0,0.3,17.189,1.719,1,29.221,5.157},Tr={0,1,0,0.278,0.738,0,1,1,0},Col={0,0.675,0.384,1,1,0.675,0.384,1},Life={0.1,0.2},Rot={-360,360},FbR={1,1},Spd={0.003,0.003},Spr={-360,360},Dir=5,Ori=3,Emit={Count=7,Delay=0}},
				{T=10553903882,Rate=6,LightEmission=1,Brightness=5,ZOffset=1.19,Size={0,0,0,0.3,23.814,0,1,39.691,0},Tr={0,0.75,0,1,1,0},Col={0,0,0,0,1,0,0,0},Life={0.25,0.25},Rot={-360,360},FbR={1,1},Spd={0.006,0.006},Dir=5,Emit={Count=1,Delay=0}},
				{T=10598374841,Rate=100,LightEmission=1,Brightness=15,ZOffset=2,Drag=25,TimeScale=0.7,LockedToPart=true,FlipbookStartRandom=true,Size={0,0,0,0.291,0.312,0,0.36,13,0,0.662,0.31,0,1,0,0},Sq={0,0,0,0.349,0,0,0.351,-1,0,0.359,1,0,0.368,-1,0,0.37,0,0,1,0,0},Col={0,0.675,0.384,1,0.351,0.675,0.384,1,0.359,1,1,1,0.368,0.675,0.384,1,1,0.675,0.384,1},Life={0.2,0.5},FbR={30,30},Spd={300,700},Spr={360,360},Dir=1,Emit={Count=35,Delay=0}}}},
		},
		Beams = {},
		Trails = {},
	},
	FireAura = {T=16676455805,LightEmission=0.5,Brightness=2,ZOffset=-2,LockedToPart=true,Size={0,1.1,0,1,1.1,0},Tr={0,1,0,0.5,0,0,1,1,0},Col={0,1,0.314,0.082,1,1,0.314,0.082},Life={1,1},Rot={-360,360},FbR={1,1},Spd={0.001,0.001},Dir=1,FbL=2,FbM=1},
	Flash = {
		Att = {
			{P="Part",At={0,0,0},E={{T=11372772717,Rate=2,LightEmission=1,Brightness=10,ZOffset=3.3,Size={0,4,0,1,4,0},Col={0,1,1,1,1,1,1,1},Life={0.6,0.6},Rot={-360,360},FbR={1,1},Spd={0,0},Spr={-360,360},Dir=1,FbL=2,FbM=1,Emit={Count=10,Delay=0}}}},
		},
		Beams = {},
		Trails = {},
	},
}

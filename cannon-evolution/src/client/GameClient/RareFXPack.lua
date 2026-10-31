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
	},
	Shoot = {
		Att = {
			{P="Shoot-01",At={0,0,0},E={{T=16477162837,Rate=0.75,LightEmission=1,Brightness=5,ZOffset=1,LockedToPart=true,Size={0,0.437,0,0.497,3.75,0,1,5.125,0},Col={0,1,1,1,1,1,1,1},Life={0.5,0.5},Rot={-360,360},FbR={1,1},Spd={0.01,0.01},Dir=5,Ori=3,FbL=2,FbM=1,Emit={Count=1}}}},
		},
		Beams = {},
	},
	Stars = {
		Att = {
			{P="Stars-01",At={0,0,0},E={{T=1851669703,Rate=4,LightEmission=2,Brightness=10,LockedToPart=true,Size={0,2,1,1,2,1},Tr={0,1,0,0.499,0,0,1,1,0},Col={0,1,0.831,0.224,1,1,0.831,0.224},Life={1,1},Rot={-360,360},FbR={1,1},Spd={0.001,0.001},Dir=5,FbM=1,Emit={Count=10,Delay=0.1}},
				{T=1075864321,Rate=2,LightEmission=1,Brightness=10,LockedToPart=true,Size={0,4.5,0,1,4.5,0},Tr={0,1,0,0.499,0.736,0,1,1,0},Col={0,1,0.831,0.224,1,1,0.831,0.224},Life={1,1},Rot={-360,360},FbR={1,1},Spd={0.001,0.001},Dir=5,FbM=1,Emit={Count=10,Delay=0.1}}}},
		},
		Beams = {},
	},
	Shiny = {
		Att = {
			{P="Shiny-01",At={0,0,0},E={{T=1075864321,Rate=1.5,LightEmission=1,Brightness=5,ZOffset=1,LockedToPart=true,Size={0,1.5,0,1,1.5,0},Tr={0,1,0,0.5,0,0,1,1,0},Col={0,1,0.847,0.298,1,1,0.847,0.298},Life={2.5,2.5},FbR={1,1},Spd={0.001,0.001},Dir=1},
				{T=1053548563,Rate=100,LightEmission=1,ZOffset=0.2,LockedToPart=true,Size={0,2.188,1,1,3.5,1},Tr={0,1,0,0.5,0.7,0,1,1,0},Col={0,1,0.89,0.447,1,1,0.89,0.447},Life={1,1},Rot={-360,360},FbR={1,1},Spd={0,0},Dir=1}}},
		},
		Beams = {},
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
	},
	Lightning2 = {
		Att = {
			{P="Lighting-03",At={0,0,0},E={{T=16676250078,Rate=5.15,LightEmission=1,Brightness=5,Size={0,2,0,1,2,0},Tr={0,1,0,0.25,0,0,1,1,0},Sq={0,-0.2,0,1,-0.2,0},Col={0,0,0.518,1,1,0,0.518,1},Life={0.3,0.3},Rot={-360,360},FbR={1,1},Spd={0,0},Spr={-360,360},Dir=1,FbL=2,FbM=1},
				{T=16676262776,Rate=5.35,LightEmission=1,Brightness=5,Size={0,2,0,1,2,0},Tr={0,1,0,0.25,0,0,1,1,0},Sq={0,-0.2,0,1,-0.2,0},Col={0,0,0.518,1,1,0,0.518,1},Life={0.3,0.3},Rot={-360,360},FbR={1,1},Spd={0,0},Spr={-360,360},Dir=1,FbL=2,FbM=1},
				{T=16951501423,Rate=5.5,LightEmission=1,Brightness=5,Size={0,2,0,1,2,0},Tr={0,1,0,0.25,0,0,1,1,0},Sq={0,-0.2,0,1,-0.2,0},Col={0,0,0.518,1,1,0,0.518,1},Life={0.2,0.2},Rot={-360,360},FbR={1,1},Spd={0,0},Spr={-360,360},Dir=1,FbL=1,FbM=1},
				{T=16951505034,Rate=5.5,LightEmission=1,Brightness=5,Size={0,2,0,1,2,0},Tr={0,1,0,0.25,0,0,1,1,0},Sq={0,-0.2,0,1,-0.2,0},Col={0,0,0.518,1,1,0,0.518,1},Life={0.2,0.2},Rot={-360,360},FbR={1,1},Spd={0,0},Spr={-360,360},Dir=1,FbL=1,FbM=1}}},
		},
		Beams = {},
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
	},
	Crack = {
		Att = {
			{P="Big-Crack-01",At={0,-0.6,0},E={{T=17067057050,Rate=15,LightEmission=1,Brightness=2,ZOffset=1,LockedToPart=true,Size={0,12,0,1,12,0},Tr={0,1,0,0.2,0,0,0.5,0,0,0.801,0,0,1,1,0},Col={0,1,0.161,0.012,1,1,0.161,0.012},Life={0.3,0.3},Rot={-360,360},FbR={1,1},Spd={0.001,0.001},Dir=4,Ori=3,FbM=1,ShIO=1},
				{T=17067103637,Rate=15,ZOffset=0.5,LockedToPart=true,Size={0,20,0,1,20,0},Tr={0,1,0,0.2,0,0,0.5,0,0,0.801,0,0,1,1,0},Col={0,0,0,0,1,0,0,0},Life={0.3,0.3},Rot={-360,360},FbR={1,1},Spd={0.001,0.001},Dir=4,Ori=3,FbM=1,ShIO=1},
				{T=16955854038,Rate=250,Brightness=5,ZOffset=0.6,Drag=2,LockedToPart=true,FlipbookStartRandom=true,Size={0,0,0,0.252,0,0,0.458,3.446,0,1,0,0},Col={0,0,0,0,1,0,0,0},Life={0.5,0.5},Rot={-360,360},FbR={1,1},Spd={30,50},Spr={0,360},Dir=5,FbL=2,FbM=1,ShS=1},
				{T=13818306392,Rate=250,LightEmission=0.1,Brightness=5,ZOffset=0.7,Drag=2,LockedToPart=true,FlipbookStartRandom=true,Size={0,0,0,0.252,0,0,0.458,3.446,0,1,0,0},Col={0,1,0.208,0.047,1,1,0.208,0.047},Life={0.5,0.5},Rot={-360,360},FbR={1,1},Spd={30,50},Spr={0,360},Dir=5,FbL=2,FbM=1,ShS=1}}},
		},
		Beams = {},
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
	},
	FireAura = {T=16676455805,LightEmission=0.5,Brightness=2,ZOffset=-2,LockedToPart=true,Size={0,1.1,0,1,1.1,0},Tr={0,1,0,0.5,0,0,1,1,0},Col={0,1,0.314,0.082,1,1,0.314,0.082},Life={1,1},Rot={-360,360},FbR={1,1},Spd={0.001,0.001},Dir=1,FbL=2,FbM=1},
	Flash = {
		Att = {
			{P="Part",At={0,0,0},E={{T=11372772717,Rate=2,LightEmission=1,Brightness=10,ZOffset=3.3,Size={0,4,0,1,4,0},Col={0,1,1,1,1,1,1,1},Life={0.6,0.6},Rot={-360,360},FbR={1,1},Spd={0,0},Spr={-360,360},Dir=1,FbL=2,FbM=1,Emit={Count=10,Delay=0}}}},
		},
		Beams = {},
	},
}

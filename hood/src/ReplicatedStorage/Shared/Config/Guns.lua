--!strict
-- The gun ladder. Guns are bought with Cash at the lobby ARMORY and multiply the Power each
-- shot pays (the "x1 Power" in the hint line). The Rusty Pistol is free and equipped from the start.
-- Cash comes from first-time gate passes (about 27K across World 1), so the top gun is an end-of-world goal.
--   Look: the art direction for the model (Blender, low-poly blocky, studs on top faces).
local C = Color3.fromRGB
local Guns = { List = {}, ById = {} }
for i, r in {
	{ 'Pistol', 'Rusty Pistol', 1, 0, C(150, 156, 166), 'Chunky grey pistol, brown grip, a rust patch' },
	{ 'Revolver', 'Snub Revolver', 2, 10, C(76, 217, 100), 'Short revolver, big round cylinder, wooden grip' },
	{ 'Uzi', 'Street Uzi', 3, 60, C(64, 156, 255), 'Boxy black SMG, long mag through the grip, folded stock' },
	{ 'Shotgun', 'Pump Shotgun', 4, 200, C(170, 85, 255), 'Long double tube, wooden pump and stock, red shells on the side' },
	{ 'Tommy', 'Tommy Gun', 6, 600, C(255, 90, 200), 'Drum mag, wooden stock and front grip, finned barrel' },
	{ 'AK', 'Block AK', 8, 1500, C(60, 230, 255), 'Curved mag, wooden furniture, gas tube over the barrel' },
	{ 'Deagle', 'Gold Deagle', 12, 4000, C(255, 200, 60), 'Big gold pistol, black grip, triangle barrel' },
	{ 'Minigun', 'Mini Gun', 16, 10000, C(255, 60, 60), 'Six barrels round a hub, ammo box, carry handle' },
	{ 'Blaster', 'Neon Blaster', 24, 18000, C(160, 86, 226), 'Sci-fi blaster, glowing neon coils and fins' },
	{ 'Diamond', 'Diamond Cannon', 32, 25000, C(120, 230, 255), 'Huge cannon cut from blue diamond blocks, gold trim' },
} do
	local gun = { Id = r[1], Name = r[2], Multiplier = r[3], Cost = r[4], Color = r[5], Look = r[6], Tier = i }
	table.insert(Guns.List, gun)
	Guns.ById[gun.Id] = gun
end
Guns.Starter = 'Pistol'
-- (Oct 27, the owner: "Yes, at my suggested prices") The 5 Robux exclusive guns: the owner's designs (Shared/ItemMeshes,
-- Gun_<Id>), each a one-time game pass (Config/Products.Passes, key Pass = 'Gun' .. Id; no random chance), never sold
-- for Cash. They are not on the Cash ladder (Guns.List, the ARMORY's ten pads and the pacing sim stay as they were):
-- they live in Guns.Exclusive and Guns.ById. GunService adds one to your guns the moment its Pass_<Pass> is true.
Guns.Exclusive = {}
for i, r in {
	{ 'NeonViper', 'Neon Viper', 8, 149, C(80, 255, 170), 'Sleek neon green snake gun' },
	{ 'Frostbite', 'Frostbite', 12, 249, C(140, 220, 255), 'Ice blue blaster with frost crystals' },
	{ 'GalaxyRay', 'Galaxy Ray', 20, 399, C(150, 90, 255), 'Purple space ray gun with stars' },
	{ 'InfernoCannon', 'Inferno Cannon', 28, 599, C(255, 110, 40), 'Fiery orange cannon with flames' },
	{ 'RoyalCrown', 'Royal Crown', 40, 899, C(255, 205, 60), 'Gold and purple royal gun with a crown' },
} do
	local gun = { Id = r[1], Name = r[2], Multiplier = r[3], Robux = r[4], Cost = 0, Color = r[5], Look = r[6],
		Tier = #Guns.List + i, Exclusive = true, Pass = 'Gun' .. r[1] }
	table.insert(Guns.Exclusive, gun)
	Guns.ById[gun.Id] = gun
end
function Guns.multiplier(id: string?): number
	local gun = id and Guns.ById[id]
	return gun and gun.Multiplier or 1
end
return Guns

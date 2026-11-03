--!strict
-- Cars: what you can own, buy and spawn from the phone's Garage app. Tune here; VehicleService and the app read this.
-- Every car has a made-up name and maker (no real brands in the game). `id` is what the save uses
-- (Garage.Owned[id] = true). `template` = the model's name in ServerStorage.MTL_Cars (script-free bodies set up in
-- Studio; never a Workspace car). The Garage app shows ReplicatedStorage.MTL_CarPreviews.<template> when it exists.
--
--   starter = true   every save owns it (the free first rides)
--   price            dealer price in cash (nil = not for sale)
--   chassis          drive settings for our constraint chassis (Services/Chassis). No chassis = the model brings
--                    its own (the Oros keeps its A-Chassis).
--   speed            top speed shown on the dealer card (mph); chassis.maxSpeed is the real one, in studs/s
local Vehicles = {}

Vehicles.TemplateFolder = "MTL_Cars" -- ServerStorage.<this>.<template>
Vehicles.PreviewFolder = "MTL_CarPreviews" -- ReplicatedStorage.<this>.<template>: body-only copies for the app
Vehicles.SpawnFolder = "MTL_SpawnedCars" -- Workspace.<this>: live cars, one per player at most

-- Cheapest first: this is the dealer's order too.
Vehicles.Cars = {
	{
		id = "Cafe",
		name = "Café 250",
		maker = "Moretti",
		class = "Bike",
		blurb = "Old, light and free. Gets you to work.",
		template = "Cafe",
		starter = true,
		speed = 55,
		chassis = { bike = true, maxSpeed = 80, torque = 0.8, steer = 28 },
	},
	{
		id = "WorkTruck",
		name = "Hauler",
		maker = "Ridgeway",
		class = "Work truck",
		blurb = "Dented, slow, never quits. Free.",
		template = "WorkTruck",
		starter = true,
		speed = 45,
		chassis = { maxSpeed = 70, torque = 1.1, steer = 30 },
	},
	{
		id = "Cruiser",
		name = "Cruiser '99",
		maker = "Olmstead",
		class = "Sedan",
		blurb = "Your uncle's old car. It starts. Mostly.",
		template = "Cruiser",
		price = 2500,
		speed = 50,
		chassis = { maxSpeed = 75, torque = 0.9, steer = 32 },
	},
	{
		id = "Wanderer",
		name = "Wanderer '89",
		maker = "Jepson",
		class = "Old SUV",
		blurb = "Wood panels, room for the whole crew.",
		template = "Wanderer",
		price = 6000,
		speed = 55,
		chassis = { maxSpeed = 80, torque = 1.1, steer = 30 },
	},
	{
		id = "Hellhound",
		name = "Hellhound",
		maker = "Dorado",
		class = "Muscle",
		blurb = "Widebody, loud, all engine.",
		template = "Hellhound",
		price = 15000,
		speed = 75,
		chassis = { maxSpeed = 110, torque = 1.5, steer = 30 },
	},
	{
		id = "Imperio",
		name = "Imperio '64",
		maker = "Chevalier",
		class = "Lowrider",
		blurb = "Candy paint, wire wheels, slow and proud.",
		template = "Imperio",
		price = 25000,
		speed = 60,
		chassis = { maxSpeed = 90, torque = 1.1, steer = 30 },
	},
	{
		id = "Skyhawk",
		name = "Skyhawk R32",
		maker = "Nisaku",
		class = "Sports",
		blurb = "Light, quick, made for night runs.",
		template = "Skyhawk",
		price = 60000,
		speed = 85,
		chassis = { maxSpeed = 125, torque = 1.6, steer = 34 },
	},
	{
		id = "Oros",
		name = "Oros",
		maker = "Lamberti",
		class = "Super SUV",
		blurb = "Big, loud and fast. The top of the ladder.",
		template = "Oros", -- copy of the place's Urus model (brings its own A-Chassis)
		price = 150000,
		speed = 95,
	},
}

-- UserId -> car ids that account always owns, free. 11796601538 = Alex's Studio account (atredev).
Vehicles.Grants = {
	[11796601538] = { "Oros" },
}

Vehicles.Tuning = {
	SpawnCooldown = 6, -- seconds between spawns
	SpawnDistance = 12, -- studs from the player (tries right, left, front, behind until one is clear)
	SeatOnSpawn = false, -- true = put the player straight in the driver's seat
	PromptDistance = 10, -- the "Drive" prompt on the driver's seat
	MaxSpeedToSpawn = 30, -- studs/s: no spawning while falling or already flying along
	BuyConfirmSeconds = 3, -- the dealer's Buy button asks "Tap again to buy" for this long
}

-- Car style (Garage app > a car > Style): repaint the body, add underglow. Paid with game cash only.
-- Paint = every part that has the car's main body colour (the colour covering the most surface).
Vehicles.Style = {
	PaintPrice = 750,
	GlowPrice = 2000, -- first time per car; changing the glow colour after that is free
	Paints = {
		{ id = "Factory", name = "Factory", color = nil }, -- back to the car's own colour (free)
		{ id = "Midnight", name = "Midnight", color = Color3.fromRGB(22, 24, 30) },
		{ id = "Pearl", name = "Pearl", color = Color3.fromRGB(236, 236, 240) },
		{ id = "Candy", name = "Candy red", color = Color3.fromRGB(176, 16, 32) },
		{ id = "Ocean", name = "Ocean", color = Color3.fromRGB(18, 92, 196) },
		{ id = "Mint", name = "Mint", color = Color3.fromRGB(64, 220, 160) },
		{ id = "Sunset", name = "Sunset", color = Color3.fromRGB(255, 120, 40) },
		{ id = "Grape", name = "Grape", color = Color3.fromRGB(110, 50, 170) },
		{ id = "Lime", name = "Lime", color = Color3.fromRGB(150, 220, 40) },
		{ id = "Flamingo", name = "Flamingo", color = Color3.fromRGB(255, 92, 170) },
	},
	Glows = {
		{ id = "Off", name = "Off", color = nil },
		{ id = "Ice", name = "Ice", color = Color3.fromRGB(120, 200, 255) },
		{ id = "Miami", name = "Miami pink", color = Color3.fromRGB(255, 60, 170) },
		{ id = "Toxic", name = "Toxic", color = Color3.fromRGB(90, 255, 90) },
		{ id = "Purple", name = "Purple", color = Color3.fromRGB(150, 70, 255) },
		{ id = "Red", name = "Red", color = Color3.fromRGB(255, 40, 40) },
		{ id = "Gold", name = "Gold", color = Color3.fromRGB(255, 190, 40) },
	},
}

function Vehicles.paint(id: string): any?
	for _, p in Vehicles.Style.Paints do
		if p.id == id then
			return p
		end
	end
	return nil
end

function Vehicles.glow(id: string): any?
	for _, g in Vehicles.Style.Glows do
		if g.id == id then
			return g
		end
	end
	return nil
end

-- Car safety (VehicleService checks every live car 4 times a second). A parked car always belongs to the server.
Vehicles.Guard = {
	Hz = 4,
	SpeedSlack = 1.45, -- a strike above (top speed x this) + SpeedExtra studs/s; downhill and ramps stay legal
	SpeedExtra = 15,
	DefaultTopSpeed = 140, -- studs/s, for cars without a chassis spec (the Oros)
	TeleportStuds = 60, -- moved further than this in one check without the speed to do it = strike
	HoverSeconds = 2, -- no ground within HoverRay studs below, while not falling, for this long = strike
	HoverRay = 25,
	Strikes = 3, -- this many strikes = car impounded
	StrikeForgetSeconds = 60, -- one strike forgiven per this long
	AbandonSeconds = 150, -- nobody in it and the owner far away (or gone) this long = towed
	AbandonStuds = 220,
	FlippedSeconds = 4, -- upside down this long: with a driver it's set back on its wheels, empty it's towed
	EmptyFlippedSeconds = 12,
}

function Vehicles.get(id: string): any?
	for _, car in Vehicles.Cars do
		if car.id == id then
			return car
		end
	end
	return nil
end

-- The cheapest car for sale (the "Buy your first car" goal measures against it).
function Vehicles.cheapest(): any?
	local best = nil
	for _, car in Vehicles.Cars do
		if car.price and (best == nil or car.price < best.price) then
			best = car
		end
	end
	return best
end

return Vehicles

--[[
	GameConfig  (ModuleScript)
	Location: ReplicatedStorage > GameConfig

	All balance numbers live here. Server and client both read it.
]]

local Config = {}

-- Bump the suffix to wipe everyone's data (e.g. right before release).
Config.DATASTORE_NAME = "CannonEvo_v1"
Config.AUTOSAVE_INTERVAL = 120

---------------------------------------------------------------------------
-- Training stations (World 1)
-- Model    = name of the cannon model in ServerStorage > TrainingCannons.
-- Gain     = base Strength per shot (multiplied by the rebirth bonus).
-- Rebirths = rebirths needed to use it.
-- GamePass = gamepass id needed to use it (create it on the Creator Hub and
--            paste the id here; 0 = not set up yet, station stays locked).
---------------------------------------------------------------------------
Config.SHOT_INTERVAL = 0.8 -- seconds between shots while training
Config.STATION_LEAVE_COOLDOWN = 1.5

Config.Stations = {
	{ Id = 1, Name = "Starter Cannon",    Model = "Cannon01_Starter",    Gain = 1,   Rebirths = 0 },
	{ Id = 2, Name = "Iron Cannon",       Model = "Cannon02_Iron",       Gain = 3,   Rebirths = 2 },
	{ Id = 3, Name = "Steel Cannon",      Model = "Cannon03_Steel",      Gain = 8,   Rebirths = 4 },
	{ Id = 4, Name = "Heavy Cannon",      Model = "Cannon04_Heavy",      Gain = 20,  Rebirths = 6 },
	{ Id = 5, Name = "Industrial Cannon", Model = "Cannon06_Industrial", Gain = 50,  Rebirths = 8 },
	{ Id = 6, Name = "Golden Cannon",     Model = "Cannon05_Golden",     Gain = 125, Rebirths = 10 },
	{ Id = 7, Name = "Dragon Cannon",     Model = "Cannon19_Dragon",     Gain = 40,  Rebirths = 0, GamePass = 0 },
}

---------------------------------------------------------------------------
-- Rebirths: reset Strength to 0 for a permanent boost to every shot.
-- cost = REBIRTH_BASE_COST * REBIRTH_COST_GROWTH ^ rebirths
---------------------------------------------------------------------------
Config.REBIRTH_BASE_COST = 250
Config.REBIRTH_COST_GROWTH = 2
Config.REBIRTH_GAIN_BONUS = 0.5 -- +50% Strength per shot for each rebirth

function Config.RebirthCost(rebirths)
	return math.floor(Config.REBIRTH_BASE_COST * Config.REBIRTH_COST_GROWTH ^ rebirths)
end

function Config.ShotGain(station, rebirths)
	return math.floor(station.Gain * (1 + rebirths * Config.REBIRTH_GAIN_BONUS))
end

---------------------------------------------------------------------------
-- Grand Cannon launch
-- speed = BASE + PER_SQRT * sqrt(Strength), capped. Angle in degrees.
-- With these numbers ~0 Strength lands at the first zone and ~900K reaches
-- the end of the map (Sky Kingdom).
---------------------------------------------------------------------------
Config.LAUNCH_BASE_SPEED = 180
Config.LAUNCH_SPEED_PER_SQRT = 1.6
Config.LAUNCH_MAX_SPEED = 1800
Config.LAUNCH_ANGLE = 30
Config.LAUNCH_DIRECTION = Vector3.new(-1, 0, 0) -- zones run along -X
Config.LAUNCH_COOLDOWN = 2
Config.FLIGHT_TIMEOUT = 25
Config.RETURN_DELAY = 3 -- seconds after landing before going back to the lobby
Config.COINS_PER_STUD = 0.2

Config.DefaultData = {
	Strength = 0,
	Rebirths = 0,
	Coins = 0,
	BestDistance = 0,
	TotalLaunches = 0,
}

---------------------------------------------------------------------------

function Config.GetStation(id)
	return Config.Stations[id]
end

function Config.LaunchSpeed(strength)
	local speed = Config.LAUNCH_BASE_SPEED + math.sqrt(math.max(strength, 0)) * Config.LAUNCH_SPEED_PER_SQRT
	return math.min(speed, Config.LAUNCH_MAX_SPEED)
end

function Config.LaunchVelocity(strength)
	local angle = math.rad(Config.LAUNCH_ANGLE)
	local flat = Config.LAUNCH_DIRECTION.Unit
	local dir = (flat * math.cos(angle) + Vector3.yAxis * math.sin(angle)).Unit
	return dir * Config.LaunchSpeed(strength)
end

-- Max flat range for a launch (used by the server to sanity-check distance).
function Config.MaxRange(strength)
	local v = Config.LaunchSpeed(strength)
	return v * v * math.sin(2 * math.rad(Config.LAUNCH_ANGLE)) / workspace.Gravity
end

local SUFFIXES = { "", "K", "M", "B", "T", "Qa", "Qi", "Sx", "Sp", "Oc", "No", "Dc" }
function Config.Format(n)
	n = math.floor(n or 0)
	if math.abs(n) < 1000 then
		return tostring(n)
	end
	local i = 1
	while math.abs(n) >= 1000 and i < #SUFFIXES do
		n /= 1000
		i += 1
	end
	local fmt = n >= 100 and "%.0f%s" or (n >= 10 and "%.1f%s" or "%.2f%s")
	return string.format(fmt, n, SUFFIXES[i])
end

return Config

-- D2D (Dust to Dealership) - all game settings and the 120 cars.
-- Change numbers here to balance the game; no other script needs editing.

local Config = {}

Config.GameName = "D2D - Dust to Dealership"
Config.DataStoreName = "D2D_v1"
Config.MaxPlots = 6

---------------------------------------------------------------------
-- Rarities (index 1..7). Chance is per car, so 2 Commons = 45% together.
---------------------------------------------------------------------
Config.Rarities = {
	{ Name = "Common", Color = Color3.fromRGB(200, 200, 205), Chance = 22.5, BaseIncome = 1 },
	{ Name = "Rare", Color = Color3.fromRGB(70, 150, 255), Chance = 14, BaseIncome = 2.5 },
	{ Name = "Epic", Color = Color3.fromRGB(175, 90, 255), Chance = 7.5, BaseIncome = 6 },
	{ Name = "Legendary", Color = Color3.fromRGB(255, 190, 40), Chance = 4, BaseIncome = 15 },
	{ Name = "Mythic", Color = Color3.fromRGB(255, 60, 80), Chance = 1.75, BaseIncome = 40 },
	{ Name = "Diamond", Color = Color3.fromRGB(110, 240, 255), Chance = 0.45, BaseIncome = 120 },
	{ Name = "Millionaire's", Color = Color3.fromRGB(120, 255, 120), Chance = 0.05, BaseIncome = 500 },
}
-- position in a container (1..12) -> rarity index
Config.SlotRarity = { 1, 1, 2, 2, 3, 3, 4, 4, 5, 5, 6, 7 }

Config.ContainerMultiplier = 4 -- income x4 per container level

---------------------------------------------------------------------
-- Tires (rolled for free at the Tire Shop; a new roll replaces the old set)
-- The code calls them "engines" internally; players only ever see "tires".
---------------------------------------------------------------------
Config.Engines = {
	{ Name = "Worn Tires", Weight = 30, Mult = 1, Color = Color3.fromRGB(150, 150, 155) },
	{ Name = "Street Tires", Weight = 25, Mult = 1.2, Color = Color3.fromRGB(95, 170, 255) },
	{ Name = "Sport Rims", Weight = 21, Mult = 1.5, Color = Color3.fromRGB(230, 70, 60) },
	{ Name = "Performance Rims", Weight = 16.4, Mult = 2, Color = Color3.fromRGB(70, 210, 120) },
	{ Name = "Racing Slicks", Weight = 7, Mult = 3, Color = Color3.fromRGB(175, 95, 255) },
	{ Name = "Gold Rims", Weight = 0.5, Mult = 6, Color = Color3.fromRGB(255, 200, 50) },
	{ Name = "Diamond Rims", Weight = 0.1, Mult = 15, Color = Color3.fromRGB(140, 240, 255) },
}
Config.LuckyRollMinEngine = 4 -- Lucky Roll only rolls Performance Rims or better
Config.EngineLuckPerLevel = 0.1 -- +10% weight for Sport Rims and above per Tire Luck level
Config.MaxEngineLuck = 10
function Config.GetEngineLuckCost(level) -- cost to go from `level` to `level + 1`
	return math.floor(2000 * 4 ^ level)
end

---------------------------------------------------------------------
-- Progression. The showroom level is the main gate:
--   level L: 4L display spots, containers 1..2L, truck up to 3L (= 3+3L containers per delivery),
--   wash tools up to L+1.
-- Level 1 is a small garage; it grows into a big showroom.
---------------------------------------------------------------------
Config.MaxShowroomLevel = 5
Config.ShowroomNames = { "Garage", "Small Showroom", "Showroom", "Big Showroom", "Flagship Dealership" }
function Config.GetSpots(level)
	return 4 * level
end
function Config.GetShowroomCost(level) -- cost to reach `level`
	return ({ [2] = 2500, [3] = 250000, [4] = 40e6, [5] = 8e9 })[level] or math.huge
end
function Config.GetMaxContainer(showroomLevel)
	return math.min(2 * showroomLevel, 10)
end

Config.MaxTruckLevel = 15
function Config.GetMaxTruck(showroomLevel)
	return 3 * showroomLevel
end
function Config.GetContainersPerDelivery(truckLevel)
	return 3 + truckLevel
end
function Config.GetTruckCost(level) -- cost to reach truck `level`
	return math.floor(150 * 3 ^ (level - 2))
end

-- price to open a container; container 1 is free
function Config.GetContainerPrice(level)
	if level <= 1 then
		return 0
	end
	return math.floor(80 * 4.6 ^ (level - 1))
end

Config.DeliveryInterval = 180 -- seconds between deliveries
Config.FirstDeliveries = { 0, 60, 60 } -- a new player's first deliveries come faster
Config.YardCapacity = 24

Config.WashTools = {
	{ Name = "Bucket and Sponge", Radius = 1.6, Power = 1, Cost = 0 },
	{ Name = "Garden Hose", Radius = 2.2, Power = 1, Cost = 800 },
	{ Name = "Pressure Washer", Radius = 2.8, Power = 2, Cost = 40000 },
	{ Name = "Foam Cannon", Radius = 3.4, Power = 3, Cost = 5e6 },
	{ Name = "Wash Bay", Radius = 4.2, Power = 5, Cost = 900e6 },
	{ Name = "Automatic Car Wash", Radius = 6, Power = 8, Cost = 150e9, Auto = true },
}
function Config.GetMaxTool(showroomLevel)
	return math.min(showroomLevel + 1, #Config.WashTools)
end
Config.ScrubInterval = 0.08

Config.SellSeconds = 100 -- a car sells for 100 seconds of its income
Config.CompletionBonus = 0.05 -- +5% income per completed container
Config.TokensPerCompletion = 5
Config.OfflineRate = 0.25
Config.OfflineMaxSeconds = 8 * 3600

---------------------------------------------------------------------
-- Containers and the 120 cars. Each car: { name, shape }
-- Shapes are drawn by CarBuilder: mini, hatch, sedan, wagon, van, truck, suv,
-- bus, classic, muscle, coupe, racer, super, hyper, limo, open
---------------------------------------------------------------------
Config.Containers = {
	{ Name = "Scrapyard Finds", Color = Color3.fromRGB(150, 110, 75), Dirt = Color3.fromRGB(120, 95, 70), Cars = {
		{ "Puddle Pip", "mini" }, { "Rattler Rustbucket", "sedan" }, { "Haulman Postie", "van" }, { "Puddle Pip Cabrio", "mini" },
		{ "Rattler Wagon '82", "wagon" }, { "Haulman Tow-Tug", "truck" }, { "Rattler Hotshot", "hatch" }, { "Puddle Bubble", "mini" },
		{ "Haulman Ice Cream Van", "van" }, { "Rattler Taxi Classic", "sedan" }, { "Puddle Pip Gold Rally", "mini" }, { "Rattler Junkyard King", "muscle" },
	} },
	{ Name = "City Streets", Color = Color3.fromRGB(60, 150, 210), Dirt = Color3.fromRGB(90, 90, 95), Cars = {
		{ "Metrolux Commuter", "sedan" }, { "Sorano Kei", "mini" }, { "Metrolux Hatch GT", "hatch" }, { "Sorano Haru", "coupe" },
		{ "Metrolux Cab", "sedan" }, { "Sorano Pocket Rocket", "hatch" }, { "Sorano Drift-R", "coupe" }, { "Metrolux Police Cruiser", "sedan" },
		{ "Sorano Kei Turbo Widebody", "mini" }, { "Metrolux Limo Stretch", "limo" }, { "Sorano Neon Night", "coupe" }, { "Metrolux Executive Armored", "limo" },
	} },
	{ Name = "Family and Adventure", Color = Color3.fromRGB(110, 170, 90), Dirt = Color3.fromRGB(110, 80, 50), Cars = {
		{ "Bramble Trail", "suv" }, { "Haulman Family Van", "van" }, { "Bramble Pickup", "truck" }, { "Haulman Camper Mini", "van" },
		{ "Bramble Badger 4x4", "suv" }, { "Haulman Surf Bus", "bus" }, { "Bramble Rock Crawler", "suv" }, { "Haulman Mega Camper", "bus" },
		{ "Bramble Desert Raider", "truck" }, { "Bramble Six-Wheeler", "truck" }, { "Bramble Wildlands Black", "suv" }, { "Haulman Rolling Mansion", "bus" },
	} },
	{ Name = "Golden Age Classics", Color = Color3.fromRGB(230, 200, 120), Dirt = Color3.fromRGB(150, 140, 125), Cars = {
		{ "Bellwether Sedan '55", "classic" }, { "Bellwether Coupe '58", "classic" }, { "Bellwether Convertible '57", "open" }, { "Bellwether Diner Wagon", "wagon" },
		{ "Bellwether Tailfin '59", "classic" }, { "Bellwether Roadster", "open" }, { "Bellwether Moonglow", "classic" }, { "Bellwether Woodie Surf", "wagon" },
		{ "Bellwether Jet Age Concept", "super" }, { "Bellwether Pink Cadence", "open" }, { "Bellwether Royal Parade", "limo" }, { "Bellwether Golden Gleam", "classic" },
	} },
	{ Name = "Muscle Mayhem", Color = Color3.fromRGB(200, 70, 50), Dirt = Color3.fromRGB(60, 55, 50), Cars = {
		{ "Thunderjaw Brawler", "muscle" }, { "Rattler Sprint 70", "muscle" }, { "Thunderjaw Fastback 69", "muscle" }, { "Rattler Bandit", "muscle" },
		{ "Thunderjaw Hammerhead", "muscle" }, { "Rattler Pursuit", "sedan" }, { "Thunderjaw Supercharger", "muscle" }, { "Rattler Midnight Run", "muscle" },
		{ "Thunderjaw Drag King", "racer" }, { "Thunderjaw Twin-Blower", "muscle" }, { "Thunderjaw Inferno", "muscle" }, { "Thunderjaw Big Daddy Gold", "muscle" },
	} },
	{ Name = "Tuner Nights", Color = Color3.fromRGB(120, 110, 235), Dirt = Color3.fromRGB(45, 45, 50), Cars = {
		{ "Hikari Tsubame", "hatch" }, { "Sorano Shiro", "sedan" }, { "Hikari Kaze GT", "coupe" }, { "Sorano Spinner", "coupe" },
		{ "Hikari Touge", "coupe" }, { "Sorano Wing", "sedan" }, { "Hikari Kaze GT-Z", "coupe" }, { "Sorano Midnight Bay", "coupe" },
		{ "Hikari Raijin", "coupe" }, { "Sorano Spinner Twin-Rotor", "racer" }, { "Hikari Daimyo", "super" }, { "Sorano Neo-Tokyo", "super" },
	} },
	{ Name = "Euro Sport", Color = Color3.fromRGB(60, 160, 140), Dirt = Color3.fromRGB(200, 200, 205), Cars = {
		{ "Strassen Kompakt", "hatch" }, { "Lucenti Piccola", "mini" }, { "Strassen Coupe 3", "coupe" }, { "Lucenti Aria", "open" },
		{ "Strassen Bahnsturm", "coupe" }, { "Lucenti GT Classico", "classic" }, { "Strassen Flachbau", "racer" }, { "Lucenti Gran Turismo V8", "coupe" },
		{ "Strassen Ringmeister", "racer" }, { "Lucenti Rosso Fuoco", "super" }, { "Strassen Schwarzwald Black", "super" }, { "Lucenti Principessa", "coupe" },
	} },
	{ Name = "Race Legends", Color = Color3.fromRGB(200, 205, 222), Dirt = Color3.fromRGB(100, 75, 50), Cars = {
		{ "Vellora Club Racer", "racer" }, { "Strassen Touring Cup", "sedan" }, { "Vellora Rally Stage", "hatch" }, { "Strassen Endurance '72", "racer" },
		{ "Vellora Le Grand", "racer" }, { "Strassen Group-B Monster", "hatch" }, { "Vellora Open-Wheel 90", "racer" }, { "Strassen Hillclimb Beast", "racer" },
		{ "Vellora Prototype X", "hyper" }, { "Strassen Endurance Hybrid", "racer" }, { "Vellora Championship Winner", "racer" }, { "Vellora Golden Trophy", "racer" },
	} },
	{ Name = "Supercars", Color = Color3.fromRGB(255, 120, 30), Dirt = Color3.fromRGB(210, 180, 120), Cars = {
		{ "Vellora Furia", "super" }, { "Lucenti Veloce", "coupe" }, { "Vellora Furia Spider", "super" }, { "Lucenti Tempesta", "super" },
		{ "Vellora Falco", "super" }, { "Lucenti Ombra", "super" }, { "Vellora Saetta", "super" }, { "Lucenti Vortice", "super" },
		{ "Vellora Falco Ultimo", "super" }, { "Lucenti Fulmine", "super" }, { "Vellora Carbonio", "super" }, { "Vellora Imperatore", "super" },
	} },
	{ Name = "Hypercars and Future", Color = Color3.fromRGB(196, 62, 200), Dirt = Color3.fromRGB(150, 120, 200), Cars = {
		{ "Quasar Watt", "hatch" }, { "Quasar Pulse", "sedan" }, { "Quasar Ionic GT", "coupe" }, { "Gilded Aero", "coupe" },
		{ "Quasar Photon", "hyper" }, { "Gilded Oasis", "hyper" }, { "Quasar Singularity", "hyper" }, { "Gilded Regent", "limo" },
		{ "Quasar Hover Prototype", "hyper" }, { "Gilded Midas", "hyper" }, { "Quasar Diamond Edge", "hyper" }, { "Gilded Fortune One", "hyper" },
	} },
}

-- Body colors for cars (picked per car so every car looks different)
local palette = {
	Color3.fromRGB(220, 50, 50), Color3.fromRGB(40, 110, 220), Color3.fromRGB(240, 200, 40), Color3.fromRGB(40, 170, 90),
	Color3.fromRGB(245, 245, 245), Color3.fromRGB(30, 30, 35), Color3.fromRGB(250, 130, 30), Color3.fromRGB(140, 60, 200),
	Color3.fromRGB(110, 200, 230), Color3.fromRGB(150, 150, 160), Color3.fromRGB(255, 120, 170), Color3.fromRGB(120, 80, 50),
}

-- Build the flat car list: id "c3_7" = container 3, slot 7
Config.Cars = {}
Config.CarsById = {}
for c, container in ipairs(Config.Containers) do
	container.Index = c
	container.CarIds = {}
	for slot, entry in ipairs(container.Cars) do
		local rarity = Config.SlotRarity[slot]
		local car = {
			Id = "c" .. c .. "_" .. slot,
			Name = entry[1],
			Shape = entry[2],
			Container = c,
			Slot = slot,
			Rarity = rarity,
			Color = palette[((c * 5 + slot * 7) % #palette) + 1],
		}
		car.BaseIncome = Config.Rarities[rarity].BaseIncome * Config.ContainerMultiplier ^ (c - 1)
		table.insert(Config.Cars, car)
		Config.CarsById[car.Id] = car
		table.insert(container.CarIds, car.Id)
	end
end

---------------------------------------------------------------------
-- Helpers
---------------------------------------------------------------------
function Config.WeightedIndex(weights, rng)
	local total = 0
	for _, w in ipairs(weights) do
		total = total + w
	end
	local roll = rng:NextNumber() * total
	for i, w in ipairs(weights) do
		roll = roll - w
		if roll <= 0 then
			return i
		end
	end
	return #weights
end

-- Rolls which car comes out of a container of this level
function Config.RollCar(containerLevel, rng)
	local weights = {}
	for slot = 1, 12 do
		weights[slot] = Config.Rarities[Config.SlotRarity[slot]].Chance
	end
	local slot = Config.WeightedIndex(weights, rng)
	return "c" .. containerLevel .. "_" .. slot
end

-- Engine weights with Engine Luck applied (normal roll) or Lucky Roll
function Config.GetEngineWeights(luckLevel, lucky)
	local weights = {}
	for i, engine in ipairs(Config.Engines) do
		local w = engine.Weight
		if i >= 3 then
			w = w * (1 + Config.EngineLuckPerLevel * luckLevel)
		end
		if lucky and i < Config.LuckyRollMinEngine then
			w = 0
		end
		weights[i] = w
	end
	return weights
end

function Config.GetEngineChances(luckLevel, lucky)
	local weights = Config.GetEngineWeights(luckLevel, lucky)
	local total = 0
	for _, w in ipairs(weights) do
		total = total + w
	end
	local chances = {}
	for i, w in ipairs(weights) do
		chances[i] = total > 0 and (w / total * 100) or 0
	end
	return chances
end

function Config.GetCarIncome(carId, engineIndex)
	local car = Config.CarsById[carId]
	if not car then
		return 0
	end
	local engine = Config.Engines[engineIndex or 1] or Config.Engines[1]
	return car.BaseIncome * engine.Mult
end

function Config.GetOddsText(carId)
	local car = Config.CarsById[carId]
	local chance = Config.Rarities[car.Rarity].Chance
	local oneIn = 100 / chance
	if oneIn >= 1000 then
		return string.format("1 in %s", Config.FormatNumber(oneIn))
	end
	return "1 in " .. math.floor(oneIn + 0.5)
end

local suffixes = { "", "K", "M", "B", "T", "Qa", "Qi" }
function Config.FormatNumber(n)
	n = tonumber(n) or 0
	if n < 1000 then
		if n == math.floor(n) then
			return tostring(math.floor(n))
		end
		return string.format("%.1f", n)
	end
	local i = 1
	while n >= 1000 and i < #suffixes do
		n = n / 1000
		i = i + 1
	end
	if n >= 100 then
		return string.format("%d%s", math.floor(n), suffixes[i])
	elseif n >= 10 then
		return string.format("%.1f%s", n, suffixes[i])
	end
	return string.format("%.2f%s", n, suffixes[i])
end

function Config.FormatTime(seconds)
	seconds = math.max(0, math.floor(seconds))
	return string.format("%02d:%02d", math.floor(seconds / 60), seconds % 60)
end

return Config

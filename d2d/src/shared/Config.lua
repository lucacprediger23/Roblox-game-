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
-- how long the container-opening reveal runs for a car of this rarity (client and server agree on it):
-- one beat per rarity it climbs through, plus a long suspense hold for Epic and up
function Config.RevealSeconds(rarity)
	return 1.0 + 0.55 * (rarity - 1) + (rarity >= 3 and 1.4 or 0) + (rarity >= 4 and 1.0 or 0)
end
-- position in a container (1..12) -> rarity index
Config.SlotRarity = { 1, 1, 2, 2, 3, 3, 4, 4, 5, 5, 6, 7 }

Config.ContainerMultiplier = 10 -- income x10 per container level (matches the x10 container prices)

---------------------------------------------------------------------
-- Paint Shop: the car gets a random paint finish (a gacha spin). Rarer finishes multiply what
-- every customer pays to look at the car. Rerolls cost cash and only ever upgrade the paint;
-- a token buys a Lucky Roll (best of three). Paint Luck (the old Service Tools pad) makes rare
-- finishes more likely.
-- (Saved data calls the finish "Engine" for compatibility with older saves.)
---------------------------------------------------------------------
Config.Paints = {
	{ Name = "Factory Paint", Rarity = 1, Weight = 0, Mult = 1, Color = Color3.fromRGB(170, 175, 185) },
	{ Name = "Fresh Gloss", Rarity = 1, Weight = 38, Mult = 1.3, Color = Color3.fromRGB(205, 215, 230), Keep = true, Reflectance = 0.12 },
	{ Name = "Matte Black", Rarity = 1, Weight = 24, Mult = 1.6, Color = Color3.fromRGB(110, 110, 120), Paint = Color3.fromRGB(30, 30, 34), Reflectance = 0 },
	{ Name = "Metallic Blue", Rarity = 2, Weight = 16, Mult = 2, Color = Color3.fromRGB(80, 150, 255), Paint = Color3.fromRGB(35, 85, 200), Reflectance = 0.22 },
	{ Name = "Army Camo", Rarity = 2, Weight = 10, Mult = 2.6, Color = Color3.fromRGB(130, 160, 90), Camo = { Color3.fromRGB(78, 92, 52), Color3.fromRGB(52, 62, 38), Color3.fromRGB(120, 110, 76), Color3.fromRGB(90, 72, 50) }, Material = Enum.Material.Fabric },
	{ Name = "Candy Red", Rarity = 3, Weight = 6, Mult = 3.3, Color = Color3.fromRGB(255, 70, 90), Paint = Color3.fromRGB(205, 18, 40), Reflectance = 0.32 },
	{ Name = "Mirror Chrome", Rarity = 3, Weight = 3.5, Mult = 4.5, Color = Color3.fromRGB(215, 225, 240), Paint = Color3.fromRGB(205, 210, 220), Material = Enum.Material.Foil, Reflectance = 0.6 },
	{ Name = "24K Gold", Rarity = 4, Weight = 1.8, Mult = 6, Color = Color3.fromRGB(255, 200, 60), Paint = Color3.fromRGB(235, 180, 40), Material = Enum.Material.Foil, Reflectance = 0.45 },
	{ Name = "Galaxy", Rarity = 5, Weight = 0.7, Mult = 9, Color = Color3.fromRGB(190, 110, 255), Paint = Color3.fromRGB(62, 28, 130), Reflectance = 0.35, Sparkle = true },
}
Config.Tunes = Config.Paints -- old name
Config.Engines = Config.Tunes -- old name, still used by a few helpers
Config.MaxEngineLuck = 10 -- Paint Luck levels
-- roll a paint finish; luck (0..10) shifts the odds toward the rare finishes
function Config.RollPaint(luck, rng)
	local w = {}
	for i, p in ipairs(Config.Paints) do
		w[i] = p.Weight * (1 + 0.15 * (luck or 0)) ^ math.max(0, i - 2)
	end
	return math.max(2, Config.WeightedIndex(w, rng))
end
-- how long the paint spin runs before landing (rare finishes hang on longer)
function Config.PaintSpinSeconds(rarity)
	return 1.6 + (rarity >= 3 and 1.3 or 0) + (rarity >= 4 and 1.0 or 0)
end
-- cash cost of a reroll: about three views of the car
function Config.PaintRerollCost(carId)
	local car = Config.CarsById[carId]
	return math.max(25, math.floor((car and car.BaseIncome or 1) * Config.ViewSeconds * 3))
end
function Config.GetEngineLuckCost(level) -- cost of the next Service Tools level
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
-- level 1 is a one-car garage
Config.SpotsPerLevel = { 1, 4, 8, 14, 20 }
function Config.GetSpots(level)
	return Config.SpotsPerLevel[level] or 1
end
function Config.GetShowroomCost(level) -- cost to reach `level`
	return ({ [2] = 2500, [3] = 500000, [4] = 250e6, [5] = 200e9 })[level] or math.huge
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
	return math.floor(150 * 5 ^ (level - 2))
end

-- price to open a container: $20 for container 1, x10 per level, $20B for container 10
function Config.GetContainerPrice(level)
	return 20 * 10 ^ (level - 1)
end
Config.StartingCash = 100

Config.DeliveryInterval = 180 -- seconds between deliveries
Config.FirstDeliveries = { 0, 60, 60 } -- a new player's first deliveries come faster
Config.YardCapacity = 24

Config.WashTools = {
	-- rust removal: the starter brush is small and slow on purpose, so every upgrade feels great
	{ Name = "Wire Brush", Radius = 1.1, Power = 1, Cost = 0 },
	{ Name = "Sanding Block", Radius = 1.7, Power = 1, Cost = 1500 },
	{ Name = "Pressure Washer", Radius = 2.5, Power = 2, Cost = 300000 },
	{ Name = "Rust Remover Foam", Radius = 3.3, Power = 3, Cost = 100e6 },
	{ Name = "Sandblaster", Radius = 4.2, Power = 5, Cost = 50e9 },
	{ Name = "Automatic Restoration Bay", Radius = 6, Power = 8, Cost = 20e12, Auto = true },
}
function Config.GetMaxTool(showroomLevel)
	return math.min(showroomLevel + 1, #Config.WashTools)
end
Config.ScrubInterval = 0.08

Config.SellSeconds = 100 -- a car sells for 100 seconds of its income
-- Customers: money only comes when a customer looks at a displayed car
Config.ViewSeconds = 12 -- one view pays 12 seconds' worth of the car's income value
Config.CustomerEvery = 5 -- a new customer can walk in every 5 seconds
Config.InventorySize = 10 -- cars you can carry in the toolbar
Config.StorageSize = 60 -- cars you can keep in the Storage Unit
Config.StarterCar = "c1_1"
Config.CompletionBonus = 0.05 -- +5% income per completed container
Config.TokensPerCompletion = 5
Config.OfflineRate = 0.25
Config.OfflineMaxSeconds = 8 * 3600

---------------------------------------------------------------------
-- Containers and the 120 cars. Each car: { name, shape }
-- Shapes are drawn by CarBuilder: mini, hatch, sedan, wagon, van, truck, suv,
-- bus, classic, muscle, coupe, racer, super, hyper, limo, open
---------------------------------------------------------------------
-- Ten containers = a timeline of the car, from the first horseless carriages to the future.
-- Each car: { name, body shape (size), generated model key }
Config.Containers = {
	{ Name = "Brass Era Barn Finds", Era = "1900s-1920s", Color = Color3.fromRGB(232, 184, 116), Dirt = Color3.fromRGB(120, 95, 70), Cars = {
		{ "Puttering Pioneer", "open", "brass" }, { "Tin Can Tourer", "classic", "vintage20s" }, { "Boneshaker Runabout", "open", "brass" }, { "Parlor Coach '24", "classic", "vintage20s" },
		{ "Brasslamp Phaeton", "open", "brass" }, { "Doctor's Coupe", "classic", "vintage20s" }, { "Crank-Start Roadster", "open", "brass" }, { "Gilded Age Limousine", "limo", "vintage20s" },
		{ "Speedster 1912", "open", "brass" }, { "Silver Whisper Tourer", "classic", "vintage20s" }, { "Royal Carriage Motor", "limo", "vintage20s" }, { "Golden Brass Runabout", "open", "brass" },
	} },
	{ Name = "Roaring Thirties", Era = "1930s", Color = Color3.fromRGB(226, 124, 52), Dirt = Color3.fromRGB(90, 80, 70), Cars = {
		{ "Depot Delivery Sedan", "classic", "sedan30s" }, { "Breadline Coupe", "coupe", "streamline30s" }, { "Mob Boss Sedan", "classic", "sedan30s" }, { "Slipstream Arrow", "coupe", "streamline30s" },
		{ "Speakeasy Special", "classic", "sedan30s" }, { "Deco Teardrop", "coupe", "streamline30s" }, { "Getaway Twelve", "classic", "sedan30s" }, { "Breeze Streamliner", "coupe", "streamline30s" },
		{ "Pinstripe Phantom", "limo", "sedan30s" }, { "Silver Bullet Coupe", "coupe", "streamline30s" }, { "Grand Ballroom V16", "limo", "sedan30s" }, { "Gold Deco Dream", "coupe", "streamline30s" },
	} },
	{ Name = "Fifties Diner Drive-In", Era = "1950s", Color = Color3.fromRGB(136, 82, 54), Dirt = Color3.fromRGB(110, 90, 70), Cars = {
		{ "Milkshake Pickup", "truck", "pickup50s" }, { "Sock Hop Sedan", "classic", "tailfin50s" }, { "Farm Fresh Hauler", "truck", "pickup50s" }, { "Jukebox Cruiser", "classic", "tailfin50s" },
		{ "Drive-In Deluxe", "classic", "tailfin50s" }, { "Rockabilly Pickup", "truck", "pickup50s" }, { "Rocket Fin '57", "classic", "tailfin50s" }, { "Chrome Canyon Hauler", "truck", "pickup50s" },
		{ "Pink Cadence Convertible", "classic", "tailfin50s" }, { "Atomic Age Cruiser", "classic", "tailfin50s" }, { "Stardust Supreme", "classic", "tailfin50s" }, { "Golden Jet Fin", "classic", "tailfin50s" },
	} },
	{ Name = "Swinging Sixties", Era = "1960s", Color = Color3.fromRGB(188, 194, 206), Dirt = Color3.fromRGB(120, 110, 95), Cars = {
		{ "Flower Power Bus", "van", "microbus60s" }, { "Riviera Roadster", "open", "convertible60s" }, { "Surf Safari Van", "van", "microbus60s" }, { "Monaco Spider", "open", "convertible60s" },
		{ "Peace Wagon", "van", "microbus60s" }, { "Le Mans Roadster", "open", "convertible60s" }, { "Woodstock Camper", "van", "microbus60s" }, { "Grand Tourer '66", "open", "convertible60s" },
		{ "Spy Car Silver", "open", "convertible60s" }, { "Psychedelic Splitscreen", "van", "microbus60s" }, { "Jet Set Convertible", "open", "convertible60s" }, { "Golden Summer Bus", "van", "microbus60s" },
	} },
	{ Name = "Seventies Muscle", Era = "1970s", Color = Color3.fromRGB(60, 120, 225), Dirt = Color3.fromRGB(80, 70, 60), Cars = {
		{ "Bandit Brawler", "muscle", "muscle70s" }, { "Doorstop Wedge", "coupe", "wedge70s" }, { "Stripe Hammer", "muscle", "muscle70s" }, { "Disco Wedge", "coupe", "wedge70s" },
		{ "Big Block Bruiser", "muscle", "muscle70s" }, { "Origami GT", "coupe", "wedge70s" }, { "Thunder Scoop 454", "muscle", "muscle70s" }, { "Prism Pointer", "coupe", "wedge70s" },
		{ "Blaze Inferno", "muscle", "muscle70s" }, { "Laser Wedge Turbo", "coupe", "wedge70s" }, { "Twin Blower Beast", "muscle", "muscle70s" }, { "Golden Eagle Muscle", "muscle", "muscle70s" },
	} },
	{ Name = "Neon Eighties", Era = "1980s", Color = Color3.fromRGB(64, 182, 96), Dirt = Color3.fromRGB(70, 70, 80), Cars = {
		{ "Boombox Hatch", "hatch", "hatch80s" }, { "Pop-Up Prowler", "coupe", "popup80s" }, { "Arcade Hatch GT", "hatch", "hatch80s" }, { "Synthwave Coupe", "coupe", "popup80s" },
		{ "Mixtape Hot Hatch", "hatch", "hatch80s" }, { "Night Runner", "coupe", "popup80s" }, { "Cassette Turbo", "hatch", "hatch80s" }, { "Miami Nights Coupe", "coupe", "popup80s" },
		{ "Group B Hatch", "hatch", "hatch80s" }, { "Outrun Redhead", "coupe", "popup80s" }, { "Neon Grid Racer", "coupe", "popup80s" }, { "Gold Laserdisc GT", "coupe", "popup80s" },
	} },
	{ Name = "Nineties Tuners", Era = "1990s", Color = Color3.fromRGB(150, 82, 225), Dirt = Color3.fromRGB(60, 60, 70), Cars = {
		{ "Mountain Pass Hatch", "hatch", "rally90s" }, { "Wing King Coupe", "coupe", "tuner90s" }, { "Gravel Stage Hatch", "hatch", "rally90s" }, { "Touge Drifter", "coupe", "tuner90s" },
		{ "Rally Blue Rocket", "hatch", "rally90s" }, { "Street Spec R", "coupe", "tuner90s" }, { "Snowstage Hatch", "hatch", "rally90s" }, { "Midnight Highway", "coupe", "tuner90s" },
		{ "Widebody Monster", "coupe", "tuner90s" }, { "Championship Rally", "hatch", "rally90s" }, { "Twin Turbo Legend", "coupe", "tuner90s" }, { "Gold Wing Spec", "coupe", "tuner90s" },
	} },
	{ Name = "Modern Streets", Era = "2010s-2020s", Color = Color3.fromRGB(218, 56, 56), Dirt = Color3.fromRGB(150, 140, 125), Cars = {
		{ "Volt Commuter", "sedan", "ev2020" }, { "Family Crossover", "suv", "suv2020" }, { "Silent Sedan", "sedan", "ev2020" }, { "Trailhead SUV", "suv", "suv2020" },
		{ "Overdrive Performance", "sedan", "ev2020" }, { "Summit Explorer", "suv", "suv2020" }, { "Autopilot Luxe", "sedan", "ev2020" }, { "Highland Ranger", "suv", "suv2020" },
		{ "Hyperdrive Sedan", "sedan", "ev2020" }, { "Black Edition SUV", "suv", "suv2020" }, { "Executive Electric", "sedan", "ev2020" }, { "Golden Crossover", "suv", "suv2020" },
	} },
	{ Name = "Supercars", Era = "Today's fastest", Color = Color3.fromRGB(242, 192, 50), Dirt = Color3.fromRGB(210, 180, 120), Cars = {
		{ "Furia Spider", "super", "supercar" }, { "Tempesta GT", "super", "supercar" }, { "Saetta V10", "super", "supercar" }, { "Aero Wing", "hyper", "hypercar" },
		{ "Falco Ultimo", "super", "supercar" }, { "Vortice Hybrid", "hyper", "hypercar" }, { "Carbonio R", "super", "supercar" }, { "Velocita 1500", "hyper", "hypercar" },
		{ "Imperatore V12", "super", "supercar" }, { "Track Monster", "hyper", "hypercar" }, { "Record Breaker", "hyper", "hypercar" }, { "Golden Hypercar", "hyper", "hypercar" },
	} },
	{ Name = "The Future", Era = "2050+", Color = Color3.fromRGB(44, 46, 60), Dirt = Color3.fromRGB(150, 120, 200), Cars = {
		{ "Cyber Hauler", "truck", "cybertruck" }, { "Hover Pod", "super", "hover" }, { "Angular Mk.II", "truck", "cybertruck" }, { "Maglev Glider", "super", "hover" },
		{ "Mars Rover XL", "truck", "cybertruck" }, { "Antigrav Cruiser", "super", "hover" }, { "Stainless Brute", "truck", "cybertruck" }, { "Quantum Drift", "super", "hover" },
		{ "Orbital Interceptor", "super", "hover" }, { "Warp Hauler", "truck", "cybertruck" }, { "Singularity", "super", "hover" }, { "Golden Future One", "super", "hover" },
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
			Model = entry[3],
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

---------------------------------------------------------------------
-- Token Shop (in the lot, unlocks at showroom level 3): trophies shown on pedestals in the
-- showroom. Each one makes every customer pay a bit more per view.
---------------------------------------------------------------------
Config.TrophyUnlockLevel = 3
Config.Trophies = {
	{ Id = "silver", Name = "Silver Cup", Model = "XTrophySilver", Cost = 5, Bonus = 0.05, Height = 2.2 },
	{ Id = "gold", Name = "Gold Cup", Model = "XTrophyGold", Cost = 12, Bonus = 0.1, Height = 2.4 },
	{ Id = "star", Name = "Star Award", Model = "XTrophyStar", Cost = 25, Bonus = 0.15, Height = 2.4 },
	{ Id = "belt", Name = "Champion Belt", Model = "XTrophyBelt", Cost = 45, Bonus = 0.2, Width = 3 },
	{ Id = "car", Name = "Golden Car Trophy", Model = "XTrophyCar", Cost = 80, Bonus = 0.3, Height = 2.6 },
	{ Id = "crown", Name = "Royal Crown", Model = "XTrophyCrown", Cost = 150, Bonus = 0.5, Height = 1.8 },
}
Config.TrophiesById = {}
for _, t in ipairs(Config.Trophies) do
	Config.TrophiesById[t.Id] = t
end

---------------------------------------------------------------------
-- Robux shop. Fill in the real ids after publishing (Creator Hub -> Monetization).
-- An id of 0 means "not set up yet": the button says so instead of prompting.
---------------------------------------------------------------------
Config.Robux = {
	-- cash packs pay a number of minutes of your current income (with a minimum)
	Cash = {
		{ Key = "cash1", ProductId = 0, Price = 29, Name = "Stack of Cash", Minutes = 15, Min = 1000 },
		{ Key = "cash2", ProductId = 0, Price = 99, Name = "Bag of Cash", Minutes = 60, Min = 6000 },
		{ Key = "cash3", ProductId = 0, Price = 299, Name = "Briefcase", Minutes = 240, Min = 30000 },
		{ Key = "cash4", ProductId = 0, Price = 799, Name = "Bank Vault", Minutes = 720, Min = 120000 },
	},
	Tokens = {
		{ Key = "tok1", ProductId = 0, Price = 49, Name = "10 Tokens", Tokens = 10 },
		{ Key = "tok2", ProductId = 0, Price = 129, Name = "30 Tokens", Tokens = 30 },
		{ Key = "tok3", ProductId = 0, Price = 349, Name = "100 Tokens", Tokens = 100 },
	},
	Passes = {
		{ Key = "x2cash", PassId = 0, Price = 249, Name = "2x Cash", Text = "Customers pay double, forever." },
		{ Key = "luckypaint", PassId = 0, Price = 149, Name = "Lucky Painter", Text = "+3 Paint Luck: rare paint way more often." },
		{ Key = "bigstorage", PassId = 0, Price = 99, Name = "Big Storage", Text = "+60 Storage Unit slots." },
	},
	-- one time only, for new players
	Starter = { Key = "starter", ProductId = 0, Price = 49, WasPrice = 199, Name = "STARTER PACK", Cash = 10000, Tokens = 15 },
}

return Config

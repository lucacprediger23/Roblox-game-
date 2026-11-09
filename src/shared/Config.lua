-- Config: every number and every squishy in the game lives here.
-- Change values in this file to balance the game without touching the scripts.

local Config = {}

---------------------------------------------------------------------
-- General
---------------------------------------------------------------------
Config.GameName = "Steal a Squishy Egg"
Config.DataStoreName = "SquishyEgg_v1"
Config.StartingCoins = 0
Config.MaxPetsPerBase = 10 -- pedestals per base
Config.MaxPlots = 8 -- set Max Players to 8 in Game Settings

---------------------------------------------------------------------
-- Movement and speed upgrades
---------------------------------------------------------------------
Config.BaseWalkSpeed = 16
Config.SpeedPerLevel = 1.5
Config.MaxSpeedLevel = 25
Config.SpeedCostBase = 20
Config.SpeedCostGrowth = 1.55
Config.CarrySpeedMultiplier = 0.8 -- carrying an egg or pet slows you down

function Config.GetSpeedCost(level)
	-- cost to go from `level` to `level + 1`
	return math.floor(Config.SpeedCostBase * Config.SpeedCostGrowth ^ level)
end

function Config.GetWalkSpeed(level)
	return Config.BaseWalkSpeed + Config.SpeedPerLevel * level
end

---------------------------------------------------------------------
-- Base lock
---------------------------------------------------------------------
Config.BaseLockDuration = 30 -- seconds the base is protected
Config.BaseLockCooldown = 60 -- seconds before you can lock again (counted from locking)

---------------------------------------------------------------------
-- Rarities (Order is used for sorting, Color for eggs and labels)
---------------------------------------------------------------------
Config.Rarities = {
	Common = { Order = 1, Color = Color3.fromRGB(235, 235, 225), HatchTime = 5, HoldTime = 0.4 },
	Uncommon = { Order = 2, Color = Color3.fromRGB(120, 220, 120), HatchTime = 8, HoldTime = 0.6 },
	Rare = { Order = 3, Color = Color3.fromRGB(90, 170, 255), HatchTime = 12, HoldTime = 0.9 },
	Epic = { Order = 4, Color = Color3.fromRGB(190, 110, 255), HatchTime = 18, HoldTime = 1.2 },
	Legendary = { Order = 5, Color = Color3.fromRGB(255, 200, 60), HatchTime = 25, HoldTime = 1.6 },
	Secret = { Order = 6, Color = Color3.fromRGB(255, 80, 160), HatchTime = 40, HoldTime = 2.0 },
}

---------------------------------------------------------------------
-- Mutations (rolled when an egg hatches)
---------------------------------------------------------------------
Config.Mutations = {
	{ Name = "Normal", Weight = 84, Multiplier = 1 },
	{ Name = "Glitter", Weight = 8, Multiplier = 2 },
	{ Name = "Frozen", Weight = 4, Multiplier = 3 },
	{ Name = "Spicy", Weight = 3, Multiplier = 4 },
	{ Name = "Rainbow", Weight = 1, Multiplier = 6 },
}

function Config.GetMutation(name)
	for _, m in ipairs(Config.Mutations) do
		if m.Name == name then
			return m
		end
	end
	return Config.Mutations[1]
end

---------------------------------------------------------------------
-- Zones (the egg field). Farther zones = rarer eggs + faster guardians.
-- ZStart/ZEnd are world Z positions; the field runs toward negative Z.
---------------------------------------------------------------------
Config.Zones = {
	{
		Name = "Candy Meadow",
		ZStart = -20,
		ZEnd = -140,
		FloorColor = Color3.fromRGB(170, 230, 160),
		Nests = 8,
		EggWeights = { Common = 75, Uncommon = 25 },
		Guardian = { Name = "Chef Bear", PatrolSpeed = 8, ChaseSpeed = 14, ChaseRange = 35, Color = Color3.fromRGB(160, 110, 70) },
	},
	{
		Name = "Kitchen Canyon",
		ZStart = -150,
		ZEnd = -280,
		FloorColor = Color3.fromRGB(240, 200, 150),
		Nests = 7,
		EggWeights = { Uncommon = 40, Rare = 45, Epic = 15 },
		Guardian = { Name = "Grumpy Rolling Pin", PatrolSpeed = 10, ChaseSpeed = 22, ChaseRange = 40, Color = Color3.fromRGB(200, 150, 90) },
	},
	{
		Name = "Starlight Bakery",
		ZStart = -290,
		ZEnd = -420,
		FloorColor = Color3.fromRGB(200, 180, 255),
		Nests = 6,
		EggWeights = { Rare = 30, Epic = 50, Legendary = 18, Secret = 2 },
		Guardian = { Name = "Snow Yeti", PatrolSpeed = 12, ChaseSpeed = 30, ChaseRange = 45, Color = Color3.fromRGB(235, 245, 255) },
	},
}
Config.FieldHalfWidth = 150 -- the field spans X from -150 to 150
Config.EggRespawnTime = 4 -- seconds before an empty nest gets a new egg

---------------------------------------------------------------------
-- Squishies
-- Parts are built by PetModels. Kinds: Ellipsoid, Ball, Block, Cylinder (vertical), Wedge.
-- Size is in studs. Offset is from the center of the squishy.
-- Face = where the eyes go (front of the squishy faces -Z).
---------------------------------------------------------------------
local cream = Color3.fromRGB(245, 235, 215)

Config.Pets = {
	-- Common
	{
		Id = "Dumpy", Name = "Dumpy", Rarity = "Common", Income = 1,
		Face = Vector3.new(0, 0, -1.5),
		Parts = {
			{ Kind = "Ellipsoid", Size = Vector3.new(3.2, 2.2, 3), Color = cream, Body = true },
			{ Kind = "Ellipsoid", Size = Vector3.new(1, 0.8, 1), Offset = Vector3.new(0, 1.15, 0), Color = cream },
			{ Kind = "Ellipsoid", Size = Vector3.new(0.5, 0.6, 0.5), Offset = Vector3.new(-0.7, 0.9, 0), Color = cream },
			{ Kind = "Ellipsoid", Size = Vector3.new(0.5, 0.6, 0.5), Offset = Vector3.new(0.7, 0.9, 0), Color = cream },
		},
	},
	{
		Id = "MochiMo", Name = "Mochi Mo", Rarity = "Common", Income = 2,
		Face = Vector3.new(0, 0, -1.5),
		Parts = {
			{ Kind = "Ellipsoid", Size = Vector3.new(3, 2.6, 3), Color = Color3.fromRGB(255, 190, 210), Body = true },
			{ Kind = "Ellipsoid", Size = Vector3.new(0.9, 0.3, 0.5), Offset = Vector3.new(0.4, 1.35, 0), Color = Color3.fromRGB(120, 200, 110) },
		},
	},
	{
		Id = "Toasty", Name = "Toasty", Rarity = "Common", Income = 2,
		Face = Vector3.new(0, 0.1, -0.62),
		Parts = {
			{ Kind = "Block", Size = Vector3.new(3, 3.2, 1.2), Color = Color3.fromRGB(240, 200, 130), Body = true },
			{ Kind = "Block", Size = Vector3.new(3.3, 3.5, 1.05), Offset = Vector3.new(0, 0, 0.12), Color = Color3.fromRGB(200, 135, 65) },
			{ Kind = "Block", Size = Vector3.new(1, 0.3, 0.8), Offset = Vector3.new(0, 1.85, 0), Color = Color3.fromRGB(255, 230, 120) },
		},
	},

	-- Uncommon
	{
		Id = "BobaBub", Name = "Boba Bub", Rarity = "Uncommon", Income = 4,
		Face = Vector3.new(0, 0.3, -1.3),
		Parts = {
			{ Kind = "Cylinder", Size = Vector3.new(2.6, 3.2, 2.6), Color = Color3.fromRGB(225, 190, 150), Body = true },
			{ Kind = "Ellipsoid", Size = Vector3.new(2.7, 0.9, 2.7), Offset = Vector3.new(0, 1.6, 0), Color = Color3.fromRGB(250, 250, 255), Transparency = 0.3 },
			{ Kind = "Cylinder", Size = Vector3.new(0.3, 2, 0.3), Offset = Vector3.new(0.5, 2.5, 0), Color = Color3.fromRGB(255, 120, 170) },
			{ Kind = "Ball", Size = Vector3.new(0.5, 0.5, 0.5), Offset = Vector3.new(-0.6, -1.3, -1.15), Color = Color3.fromRGB(40, 25, 20) },
			{ Kind = "Ball", Size = Vector3.new(0.5, 0.5, 0.5), Offset = Vector3.new(0, -1.35, -1.25), Color = Color3.fromRGB(40, 25, 20) },
			{ Kind = "Ball", Size = Vector3.new(0.5, 0.5, 0.5), Offset = Vector3.new(0.6, -1.3, -1.15), Color = Color3.fromRGB(40, 25, 20) },
		},
	},
	{
		Id = "SushiRolly", Name = "Sushi Roll-y", Rarity = "Uncommon", Income = 5,
		Face = Vector3.new(0, 0.35, -1.4),
		Parts = {
			{ Kind = "Cylinder", Size = Vector3.new(2.8, 2.4, 2.8), Color = Color3.fromRGB(250, 250, 245), Body = true },
			{ Kind = "Cylinder", Size = Vector3.new(2.95, 1, 2.95), Offset = Vector3.new(0, -0.7, 0), Color = Color3.fromRGB(30, 60, 40) },
			{ Kind = "Ellipsoid", Size = Vector3.new(2.4, 0.6, 2.4), Offset = Vector3.new(0, 1.25, 0), Color = Color3.fromRGB(250, 130, 90) },
		},
	},
	{
		Id = "Puddin", Name = "Puddin'", Rarity = "Uncommon", Income = 5,
		Face = Vector3.new(0, -0.1, -1.4),
		Parts = {
			{ Kind = "Cylinder", Size = Vector3.new(2.8, 2.4, 2.8), Color = Color3.fromRGB(250, 215, 120), Body = true },
			{ Kind = "Ellipsoid", Size = Vector3.new(2.6, 0.6, 2.6), Offset = Vector3.new(0, 1.2, 0), Color = Color3.fromRGB(150, 80, 30) },
			{ Kind = "Cylinder", Size = Vector3.new(3.6, 0.25, 3.6), Offset = Vector3.new(0, -1.3, 0), Color = Color3.fromRGB(255, 255, 255) },
			{ Kind = "Ball", Size = Vector3.new(0.6, 0.6, 0.6), Offset = Vector3.new(0, 1.6, 0), Color = Color3.fromRGB(220, 30, 50) },
		},
	},

	-- Rare
	{
		Id = "TacoTilly", Name = "Taco Tilly", Rarity = "Rare", Income = 12,
		Face = Vector3.new(0, -0.1, -0.8),
		Parts = {
			{ Kind = "Ellipsoid", Size = Vector3.new(3.4, 2.6, 1.6), Color = Color3.fromRGB(240, 200, 90), Body = true },
			{ Kind = "Ellipsoid", Size = Vector3.new(3, 0.6, 1.2), Offset = Vector3.new(0, 1.15, 0), Color = Color3.fromRGB(110, 190, 70) },
			{ Kind = "Ball", Size = Vector3.new(0.5, 0.5, 0.5), Offset = Vector3.new(-0.8, 1.35, 0), Color = Color3.fromRGB(230, 50, 50) },
			{ Kind = "Ball", Size = Vector3.new(0.5, 0.5, 0.5), Offset = Vector3.new(0.7, 1.35, 0), Color = Color3.fromRGB(230, 50, 50) },
		},
	},
	{
		Id = "RamenBear", Name = "Ramen Noodle-Bear", Rarity = "Rare", Income = 15,
		Face = Vector3.new(0, 0.9, -1.2),
		Parts = {
			{ Kind = "Ellipsoid", Size = Vector3.new(2.6, 2.4, 2.4), Offset = Vector3.new(0, 0.9, 0), Color = Color3.fromRGB(230, 190, 140), Body = true },
			{ Kind = "Cylinder", Size = Vector3.new(3.4, 1.8, 3.4), Offset = Vector3.new(0, -0.6, 0), Color = Color3.fromRGB(200, 50, 50) },
			{ Kind = "Ball", Size = Vector3.new(0.8, 0.8, 0.8), Offset = Vector3.new(-0.9, 2, 0), Color = Color3.fromRGB(230, 190, 140) },
			{ Kind = "Ball", Size = Vector3.new(0.8, 0.8, 0.8), Offset = Vector3.new(0.9, 2, 0), Color = Color3.fromRGB(230, 190, 140) },
			{ Kind = "Cylinder", Size = Vector3.new(0.15, 3, 0.15), Offset = Vector3.new(1.3, 1, 0.6), Color = Color3.fromRGB(120, 80, 40) },
			{ Kind = "Cylinder", Size = Vector3.new(0.15, 3, 0.15), Offset = Vector3.new(1.55, 1, 0.6), Color = Color3.fromRGB(120, 80, 40) },
		},
	},

	-- Epic
	{
		Id = "DinoDumpling", Name = "Dino-Dumpling", Rarity = "Epic", Income = 40,
		Face = Vector3.new(0, 0, -1.6),
		Parts = {
			{ Kind = "Ellipsoid", Size = Vector3.new(3.4, 2.4, 3.2), Color = Color3.fromRGB(150, 210, 120), Body = true },
			{ Kind = "Wedge", Size = Vector3.new(0.3, 0.8, 0.8), Offset = Vector3.new(0, 1.25, -0.5), Color = Color3.fromRGB(255, 150, 60) },
			{ Kind = "Wedge", Size = Vector3.new(0.3, 0.8, 0.8), Offset = Vector3.new(0, 1.2, 0.3), Color = Color3.fromRGB(255, 150, 60) },
			{ Kind = "Wedge", Size = Vector3.new(0.3, 0.7, 0.7), Offset = Vector3.new(0, 0.95, 1.05), Color = Color3.fromRGB(255, 150, 60) },
			{ Kind = "Ellipsoid", Size = Vector3.new(0.8, 0.8, 1.6), Offset = Vector3.new(0, -0.4, 1.9), Color = Color3.fromRGB(150, 210, 120) },
		},
	},
	{
		Id = "CupcakeCat", Name = "Cupcake Cat", Rarity = "Epic", Income = 50,
		Face = Vector3.new(0, 0.5, -1.5),
		Parts = {
			{ Kind = "Ellipsoid", Size = Vector3.new(3, 2.2, 3), Offset = Vector3.new(0, 0.5, 0), Color = Color3.fromRGB(255, 245, 250), Body = true },
			{ Kind = "Cylinder", Size = Vector3.new(2.6, 1.6, 2.6), Offset = Vector3.new(0, -0.9, 0), Color = Color3.fromRGB(240, 120, 160) },
			{ Kind = "Ellipsoid", Size = Vector3.new(0.7, 0.9, 0.4), Offset = Vector3.new(-0.8, 1.65, 0), Color = Color3.fromRGB(255, 170, 200) },
			{ Kind = "Ellipsoid", Size = Vector3.new(0.7, 0.9, 0.4), Offset = Vector3.new(0.8, 1.65, 0), Color = Color3.fromRGB(255, 170, 200) },
			{ Kind = "Ball", Size = Vector3.new(0.6, 0.6, 0.6), Offset = Vector3.new(0, 1.65, 0.3), Color = Color3.fromRGB(220, 30, 50) },
		},
	},

	-- Legendary
	{
		Id = "StarlightMochi", Name = "Starlight Mochi", Rarity = "Legendary", Income = 150,
		Face = Vector3.new(0, 0, -1.6), Glow = Color3.fromRGB(200, 170, 255),
		Parts = {
			{ Kind = "Ellipsoid", Size = Vector3.new(3.2, 2.8, 3.2), Color = Color3.fromRGB(190, 150, 255), Body = true },
			{ Kind = "Cylinder", Size = Vector3.new(2.4, 0.15, 2.4), Offset = Vector3.new(0, 2.1, 0), Color = Color3.fromRGB(255, 230, 120), Material = "Neon" },
			{ Kind = "Ball", Size = Vector3.new(0.4, 0.4, 0.4), Offset = Vector3.new(-1.3, 1.2, -0.6), Color = Color3.fromRGB(255, 255, 200), Material = "Neon" },
			{ Kind = "Ball", Size = Vector3.new(0.3, 0.3, 0.3), Offset = Vector3.new(1.4, 0.9, -0.5), Color = Color3.fromRGB(255, 255, 200), Material = "Neon" },
		},
	},

	-- Secret
	{
		Id = "GoldenMegaDumpling", Name = "Golden Mega Dumpling", Rarity = "Secret", Income = 1000,
		Face = Vector3.new(0, 0, -2.1), FaceScale = 1.4, Glow = Color3.fromRGB(255, 210, 80), Sparkle = true,
		Parts = {
			{ Kind = "Ellipsoid", Size = Vector3.new(4.5, 3.1, 4.2), Color = Color3.fromRGB(255, 200, 40), Body = true, Reflectance = 0.3 },
			{ Kind = "Ellipsoid", Size = Vector3.new(1.4, 1.1, 1.4), Offset = Vector3.new(0, 1.6, 0), Color = Color3.fromRGB(255, 200, 40), Reflectance = 0.3 },
			{ Kind = "Cylinder", Size = Vector3.new(1.6, 0.8, 1.6), Offset = Vector3.new(0, 2.4, 0), Color = Color3.fromRGB(255, 230, 90), Material = "Neon" },
		},
	},
}

-- Quick lookups
Config.PetsById = {}
Config.PetsByRarity = {}
for _, pet in ipairs(Config.Pets) do
	Config.PetsById[pet.Id] = pet
	Config.PetsByRarity[pet.Rarity] = Config.PetsByRarity[pet.Rarity] or {}
	table.insert(Config.PetsByRarity[pet.Rarity], pet)
end

-- Picks a random key from a { key = weight } table
function Config.WeightedPick(weights, rng)
	rng = rng or Random.new()
	local total = 0
	for _, w in pairs(weights) do
		total = total + w
	end
	local roll = rng:NextNumber() * total
	for key, w in pairs(weights) do
		roll = roll - w
		if roll <= 0 then
			return key
		end
	end
	local last
	for key in pairs(weights) do
		last = key
	end
	return last
end

function Config.RollMutation(rng)
	local weights = {}
	for _, m in ipairs(Config.Mutations) do
		weights[m.Name] = m.Weight
	end
	return Config.WeightedPick(weights, rng)
end

function Config.RollPetForRarity(rarity, rng)
	rng = rng or Random.new()
	local list = Config.PetsByRarity[rarity]
	return list[rng:NextInteger(1, #list)]
end

function Config.GetPetIncome(petId, mutationName)
	local pet = Config.PetsById[petId]
	if not pet then
		return 0
	end
	return pet.Income * Config.GetMutation(mutationName).Multiplier
end

function Config.FormatNumber(n)
	n = math.floor(n)
	if n >= 1e9 then
		return string.format("%.1fB", n / 1e9)
	elseif n >= 1e6 then
		return string.format("%.1fM", n / 1e6)
	elseif n >= 1e4 then
		return string.format("%.1fK", n / 1e3)
	end
	return tostring(n)
end

return Config

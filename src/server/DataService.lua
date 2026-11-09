-- DataService: loads and saves each player's coins, speed and squishies.
-- In Studio, saving only works if "Enable Studio Access to API Services" is turned on
-- (Game Settings > Security). Without it the game still runs, it just won't remember progress.

local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local DataService = {}

local store
local storeOk, storeErr = pcall(function()
	store = DataStoreService:GetDataStore(Config.DataStoreName)
end)
if not storeOk then
	warn("[DataService] Saving is off: " .. tostring(storeErr))
end

local profiles = {} -- [player] = data table

local function defaultData()
	return {
		Coins = Config.StartingCoins,
		SpeedLevel = 0,
		Pets = {}, -- list of { Id = "Dumpy", Mutation = "Normal" }
	}
end

local function sanitize(data)
	local clean = defaultData()
	if type(data) ~= "table" then
		return clean
	end
	if type(data.Coins) == "number" then
		clean.Coins = math.max(0, math.floor(data.Coins))
	end
	if type(data.SpeedLevel) == "number" then
		clean.SpeedLevel = math.clamp(math.floor(data.SpeedLevel), 0, Config.MaxSpeedLevel)
	end
	if type(data.Pets) == "table" then
		for _, pet in ipairs(data.Pets) do
			if type(pet) == "table" and Config.PetsById[pet.Id] and #clean.Pets < Config.MaxPetsPerBase then
				table.insert(clean.Pets, { Id = pet.Id, Mutation = Config.GetMutation(pet.Mutation).Name })
			end
		end
	end
	return clean
end

function DataService.Load(player)
	local data
	if store then
		local ok, result = pcall(function()
			return store:GetAsync("player_" .. player.UserId)
		end)
		if ok then
			data = result
		else
			warn("[DataService] Could not load data for " .. player.Name .. ": " .. tostring(result))
		end
	end
	local profile = sanitize(data)
	profiles[player] = profile
	return profile
end

function DataService.Get(player)
	return profiles[player]
end

-- `pets` is the current list of squishies in the player's base (eggs still hatching count too,
-- so nobody loses them by leaving early)
function DataService.Save(player, pets)
	local profile = profiles[player]
	if not profile or not store then
		return
	end
	if pets then
		profile.Pets = pets
	end
	local toSave = {
		Coins = profile.Coins,
		SpeedLevel = profile.SpeedLevel,
		Pets = profile.Pets,
	}
	local ok, err = pcall(function()
		store:SetAsync("player_" .. player.UserId, toSave)
	end)
	if not ok then
		warn("[DataService] Could not save data for " .. player.Name .. ": " .. tostring(err))
	end
end

function DataService.Release(player)
	profiles[player] = nil
end

return DataService

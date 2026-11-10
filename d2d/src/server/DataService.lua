-- DataService: loads and saves each player's progress.
-- Saving in Studio needs Game Settings > Security > "Enable Studio Access to API Services".

local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local DataService = {}

local store
local ok, err = pcall(function()
	store = DataStoreService:GetDataStore(Config.DataStoreName)
end)
if not ok then
	warn("[D2D] Saving is off: " .. tostring(err))
end

local profiles = {}

local function default()
	return {
		Cash = 0,
		Tokens = 0,
		ShowroomLevel = 1,
		TruckLevel = 1,
		ToolLevel = 1,
		EngineLuck = 0,
		Display = {}, -- { {Id=, Engine=, Spot=} }
		Discovered = {}, -- [carId] = true
		Claimed = {}, -- [carId] = true
		Completed = {}, -- [containerIndex as string] = true
		Yard = {}, -- { {Kind="Container", Level=} or {Kind="Car", Id=} }
		DeliveriesDone = 0,
		LastOnline = 0,
		IncomeRate = 0,
	}
end

local function num(v, lo, hi, fallback)
	if type(v) ~= "number" or v ~= v then
		return fallback
	end
	return math.clamp(math.floor(v), lo, hi)
end

local function sanitize(data)
	local p = default()
	if type(data) ~= "table" then
		return p
	end
	if type(data.Cash) == "number" and data.Cash == data.Cash then
		p.Cash = math.max(0, data.Cash)
	end
	p.Tokens = num(data.Tokens, 0, 1e6, 0)
	p.ShowroomLevel = num(data.ShowroomLevel, 1, Config.MaxShowroomLevel, 1)
	p.TruckLevel = num(data.TruckLevel, 1, Config.GetMaxTruck(p.ShowroomLevel), 1)
	p.ToolLevel = num(data.ToolLevel, 1, Config.GetMaxTool(p.ShowroomLevel), 1)
	p.EngineLuck = num(data.EngineLuck, 0, Config.MaxEngineLuck, 0)
	p.DeliveriesDone = num(data.DeliveriesDone, 0, 1e9, 0)
	p.LastOnline = type(data.LastOnline) == "number" and data.LastOnline or 0
	p.IncomeRate = type(data.IncomeRate) == "number" and math.max(0, data.IncomeRate) or 0
	local maxSpots = Config.GetSpots(p.ShowroomLevel)
	if type(data.Display) == "table" then
		local used = {}
		for _, d in ipairs(data.Display) do
			if type(d) == "table" and Config.CarsById[d.Id] and type(d.Spot) == "number" then
				local spot = math.floor(d.Spot)
				if spot >= 1 and spot <= maxSpots and not used[spot] then
					used[spot] = true
					table.insert(p.Display, { Id = d.Id, Engine = num(d.Engine, 1, #Config.Engines, 1), Spot = spot })
				end
			end
		end
	end
	for _, key in ipairs({ "Discovered", "Claimed" }) do
		if type(data[key]) == "table" then
			for id, v in pairs(data[key]) do
				if v and Config.CarsById[id] then
					p[key][id] = true
				end
			end
		end
	end
	if type(data.Completed) == "table" then
		for k, v in pairs(data.Completed) do
			if v and tonumber(k) then
				p.Completed[tostring(k)] = true
			end
		end
	end
	if type(data.Yard) == "table" then
		for _, y in ipairs(data.Yard) do
			if #p.Yard >= Config.YardCapacity then
				break
			end
			if type(y) == "table" then
				if y.Kind == "Container" and type(y.Level) == "number" and Config.Containers[y.Level] then
					table.insert(p.Yard, { Kind = "Container", Level = y.Level })
				elseif y.Kind == "Car" and Config.CarsById[y.Id] then
					table.insert(p.Yard, { Kind = "Car", Id = y.Id })
				end
			end
		end
	end
	return p
end

function DataService.Load(player)
	local data
	if store then
		local success, result = pcall(function()
			return store:GetAsync("player_" .. player.UserId)
		end)
		if success then
			data = result
		else
			warn("[D2D] Load failed for " .. player.Name .. ": " .. tostring(result))
		end
	end
	local profile = sanitize(data)
	profiles[player] = profile
	return profile
end

function DataService.Get(player)
	return profiles[player]
end

function DataService.Save(player)
	local profile = profiles[player]
	if not profile or not store then
		return
	end
	local success, result = pcall(function()
		store:SetAsync("player_" .. player.UserId, profile)
	end)
	if not success then
		warn("[D2D] Save failed for " .. player.Name .. ": " .. tostring(result))
	end
end

function DataService.Release(player)
	profiles[player] = nil
end

return DataService

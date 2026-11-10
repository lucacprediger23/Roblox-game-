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
		Cash = Config.StartingCash or 100,
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
		Inventory = {}, -- { {Id=, Engine=} } finished cars carried in the toolbar
		Storage = {}, -- { {Id=, Engine=} } cars kept in the Storage Unit
		GarageClaimed = false, -- opened their garage door for the first time
		TutorialDone = false,
		Trophies = {}, -- [trophyId] = true, bought in the Token Shop
		StarterBought = false, -- the one-time Robux starter pack
		Receipts = {}, -- recent Robux purchase ids (so a purchase is never granted twice)
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
	local overflow = {}
	if type(data.Display) == "table" then
		local used = {}
		for _, d in ipairs(data.Display) do
			if type(d) == "table" and Config.CarsById[d.Id] and type(d.Spot) == "number" then
				local spot = math.floor(d.Spot)
				local entry = { Id = d.Id, Engine = num(d.Engine, 1, #Config.Tunes, 1), Spot = spot, Views = num(d.Views, 0, 1e12, 0) }
				if spot >= 1 and spot <= maxSpots and not used[spot] then
					used[spot] = true
					table.insert(p.Display, entry)
				else
					-- more cars than spots (the garage got smaller): keep them in the toolbar
					table.insert(overflow, { Id = d.Id, Engine = entry.Engine })
				end
			end
		end
	end
	if type(data.Inventory) == "table" then
		for _, c in ipairs(data.Inventory) do
			if type(c) == "table" and Config.CarsById[c.Id] then
				table.insert(overflow, 1, { Id = c.Id, Engine = num(c.Engine, 1, #Config.Tunes, 1) })
			end
		end
	end
	if type(data.PendingLift) == "table" and Config.CarsById[data.PendingLift.Id] then
		table.insert(overflow, 1, { Id = data.PendingLift.Id, Engine = num(data.PendingLift.Engine, 1, #Config.Tunes, 1) })
	end
	for _, c in ipairs(overflow) do
		if #p.Inventory < Config.InventorySize then
			table.insert(p.Inventory, c)
		end
	end
	if type(data.Storage) == "table" then
		for _, c in ipairs(data.Storage) do
			if type(c) == "table" and Config.CarsById[c.Id] and #p.Storage < Config.StorageSize * 2 then
				table.insert(p.Storage, { Id = c.Id, Engine = num(c.Engine, 1, #Config.Tunes, 1) })
			end
		end
	end
	local veteran = next(p.Display) ~= nil or (type(data.Discovered) == "table" and next(data.Discovered) ~= nil)
	p.GarageClaimed = data.GarageClaimed == true or veteran
	p.TutorialDone = data.TutorialDone == true or veteran
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
	if type(data.Trophies) == "table" then
		for id, v in pairs(data.Trophies) do
			if v and Config.TrophiesById[id] then
				p.Trophies[id] = true
			end
		end
	end
	p.StarterBought = data.StarterBought == true
	if type(data.Receipts) == "table" then
		for _, r in ipairs(data.Receipts) do
			if type(r) == "string" and #p.Receipts < 50 then
				table.insert(p.Receipts, r)
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

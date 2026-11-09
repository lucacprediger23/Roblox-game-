-- GameServer: the main game loop for Steal a Squishy Egg.
-- Bases, egg spawning, carrying, hatching, stealing, guardians, income and saving all live here.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local PetModels = require(Shared:WaitForChild("PetModels"))
local DataService = require(script.Parent:WaitForChild("DataService"))
local MapBuilder = require(script.Parent:WaitForChild("MapBuilder"))

local rng = Random.new()

---------------------------------------------------------------------
-- Remotes
---------------------------------------------------------------------
local remotes = Instance.new("Folder")
remotes.Name = "Remotes"
remotes.Parent = ReplicatedStorage

local NotifyEvent = Instance.new("RemoteEvent")
NotifyEvent.Name = "Notify"
NotifyEvent.Parent = remotes

local BuySpeedFunction = Instance.new("RemoteFunction")
BuySpeedFunction.Name = "BuySpeed"
BuySpeedFunction.Parent = remotes

local LockBaseFunction = Instance.new("RemoteFunction")
LockBaseFunction.Name = "LockBase"
LockBaseFunction.Parent = remotes

local function notify(player, text, color)
	NotifyEvent:FireClient(player, text, color or Color3.new(1, 1, 1))
end

local function notifyAll(text, color)
	NotifyEvent:FireAllClients(text, color or Color3.new(1, 1, 1))
end

local function now()
	return workspace:GetServerTimeNow()
end

---------------------------------------------------------------------
-- Map and state
---------------------------------------------------------------------
local map = MapBuilder.Build()

local eggsFolder = Instance.new("Folder")
eggsFolder.Name = "Eggs"
eggsFolder.Parent = map.Folder

local petsFolder = Instance.new("Folder")
petsFolder.Name = "Pets"
petsFolder.Parent = map.Folder

local carriedFolder = Instance.new("Folder")
carriedFolder.Name = "Carried"
carriedFolder.Parent = map.Folder

local plotOwner = {} -- [plotIndex] = player
local playerPlot = {} -- [player] = plot
local slots = {} -- [plotIndex] = { [slotIndex] = slot }
local stored = {} -- [plotIndex] = coins waiting on the collect pad
local lockedUntil = {} -- [plotIndex] = server time
local carrying = {} -- [player] = carry info
local lastCaught = {} -- [player] = time a guardian last caught them

for i = 1, #map.Plots do
	slots[i] = {}
	stored[i] = 0
	lockedUntil[i] = 0
end

---------------------------------------------------------------------
-- Helpers
---------------------------------------------------------------------
local function getRoot(player)
	local character = player.Character
	return character and character:FindFirstChild("HumanoidRootPart")
end

local function getHumanoid(player)
	local character = player.Character
	return character and character:FindFirstChildOfClass("Humanoid")
end

local function setCoins(player, amount)
	local profile = DataService.Get(player)
	if not profile then
		return
	end
	profile.Coins = math.max(0, math.floor(amount))
	local leaderstats = player:FindFirstChild("leaderstats")
	if leaderstats and leaderstats:FindFirstChild("Coins") then
		leaderstats.Coins.Value = profile.Coins
	end
end

local function addCoins(player, amount)
	local profile = DataService.Get(player)
	if profile then
		setCoins(player, profile.Coins + amount)
	end
end

local function updateWalkSpeed(player)
	local humanoid = getHumanoid(player)
	local profile = DataService.Get(player)
	if not humanoid or not profile then
		return
	end
	local speed = Config.GetWalkSpeed(profile.SpeedLevel)
	if carrying[player] then
		speed = speed * Config.CarrySpeedMultiplier
	end
	humanoid.WalkSpeed = speed
end

local function isInside(position, area, margin)
	margin = margin or 0
	return position.X >= area.MinX - margin and position.X <= area.MaxX + margin
		and position.Z >= area.MinZ - margin and position.Z <= area.MaxZ + margin
end

local function countUsedSlots(plot)
	local count = 0
	for i = 1, Config.MaxPetsPerBase do
		if slots[plot.Index][i] then
			count = count + 1
		end
	end
	return count
end

local function findFreeSlot(plot)
	for i = 1, Config.MaxPetsPerBase do
		if not slots[plot.Index][i] then
			return i
		end
	end
	return nil
end

local function rarityColor(rarity)
	return Config.Rarities[rarity].Color
end

local function petDisplayName(petId, mutation)
	local def = Config.PetsById[petId]
	if mutation and mutation ~= "Normal" then
		return mutation .. " " .. def.Name
	end
	return def.Name
end

---------------------------------------------------------------------
-- Pedestal contents
---------------------------------------------------------------------
local onPetStealTriggered -- defined further down

local function clearSlotModel(slot)
	if slot and slot.Model then
		slot.Model:Destroy()
		slot.Model = nil
	end
end

local function showPetInSlot(plot, slotIndex, slot)
	clearSlotModel(slot)
	local def = Config.PetsById[slot.PetId]
	local model = PetModels.BuildPet(slot.PetId, slot.Mutation)
	local pedestal = plot.Pedestals[slotIndex]
	PetModels.PlaceOnSurface(model, pedestal.Surface)
	model:SetAttribute("RestPivot", model:GetPivot())
	CollectionService:AddTag(model, "SquishyPet")

	local income = Config.GetPetIncome(slot.PetId, slot.Mutation)
	PetModels.AddLabel(
		model,
		petDisplayName(slot.PetId, slot.Mutation),
		def.Rarity .. "  •  $" .. Config.FormatNumber(income) .. "/s",
		rarityColor(def.Rarity),
		PetModels.GetHeight(model) / 2 + 2.5
	)

	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Steal"
	prompt.ObjectText = def.Name
	prompt.HoldDuration = Config.Rarities[def.Rarity].HoldTime * 2
	prompt.MaxActivationDistance = 9
	prompt.RequiresLineOfSight = false
	local owner = plotOwner[plot.Index]
	if owner then
		prompt:SetAttribute("OwnerUserId", owner.UserId)
	end
	CollectionService:AddTag(prompt, "StealPrompt")
	prompt.Triggered:Connect(function(thief)
		onPetStealTriggered(thief, plot, slotIndex, slot)
	end)
	prompt.Parent = model.PrimaryPart

	model.Parent = petsFolder
	slot.Model = model
end

local function showEggInSlot(plot, slotIndex, slot)
	clearSlotModel(slot)
	local model = PetModels.BuildEgg(slot.Rarity)
	PetModels.PlaceOnSurface(model, plot.Pedestals[slotIndex].Surface)
	local _, _, subtitle = PetModels.AddLabel(model, slot.Rarity .. " Egg", "Hatching...", rarityColor(slot.Rarity), 3.2)
	slot.Label = subtitle
	model.Parent = petsFolder
	slot.Model = model
end

local function putPetInBase(plot, petId, mutation)
	local index = findFreeSlot(plot)
	if not index then
		return false
	end
	local slot = { State = "Pet", PetId = petId, Mutation = mutation }
	slots[plot.Index][index] = slot
	showPetInSlot(plot, index, slot)
	return true
end

local function putEggInBase(plot, rarity)
	local index = findFreeSlot(plot)
	if not index then
		return false
	end
	local slot = { State = "Egg", Rarity = rarity, HatchAt = now() + Config.Rarities[rarity].HatchTime }
	slots[plot.Index][index] = slot
	showEggInSlot(plot, index, slot)
	return true
end

local function hatch(plot, slotIndex, slot)
	local pet = Config.RollPetForRarity(slot.Rarity, rng)
	local mutation = Config.RollMutation(rng)
	slot.State = "Pet"
	slot.PetId = pet.Id
	slot.Mutation = mutation
	slot.Rarity = nil
	slot.HatchAt = nil
	slot.Label = nil
	showPetInSlot(plot, slotIndex, slot)

	local owner = plotOwner[plot.Index]
	local name = petDisplayName(pet.Id, mutation)
	if owner then
		notify(owner, "You hatched " .. name .. " (" .. pet.Rarity .. ")!", rarityColor(pet.Rarity))
		if Config.Rarities[pet.Rarity].Order >= 5 then
			notifyAll(owner.DisplayName .. " hatched a " .. string.upper(pet.Rarity) .. " " .. name .. "!", rarityColor(pet.Rarity))
		end
	end
end

-- Pets to save: hatched pets, plus eggs that are still hatching (rolled now so they aren't lost)
local function collectPetsForSave(plot)
	local list = {}
	for i = 1, Config.MaxPetsPerBase do
		local slot = slots[plot.Index][i]
		if slot then
			if slot.State == "Pet" then
				table.insert(list, { Id = slot.PetId, Mutation = slot.Mutation })
			elseif slot.State == "Egg" then
				local pet = Config.RollPetForRarity(slot.Rarity, rng)
				table.insert(list, { Id = pet.Id, Mutation = Config.RollMutation(rng) })
			end
		end
	end
	return list
end

---------------------------------------------------------------------
-- Carrying eggs and stolen pets
---------------------------------------------------------------------
local function attachToPlayer(player, model)
	local root = getRoot(player)
	if not root then
		model:Destroy()
		return false
	end
	local primary = model.PrimaryPart
	model:PivotTo(root.CFrame * CFrame.new(0, 4.5 + PetModels.GetHeight(model) / 2, 0))
	model.Parent = carriedFolder -- still anchored here, so nothing falls
	for _, item in ipairs(model:GetDescendants()) do
		if item:IsA("BasePart") then
			item.CanCollide = false
			item.CanTouch = false
			item.CanQuery = false
			item.Massless = true
			if item ~= primary then
				local weld = Instance.new("WeldConstraint")
				weld.Part0 = primary
				weld.Part1 = item
				weld.Parent = item
			end
		end
	end
	local carryWeld = Instance.new("WeldConstraint")
	carryWeld.Name = "CarryWeld"
	carryWeld.Part0 = root
	carryWeld.Part1 = primary
	carryWeld.Parent = primary
	for _, item in ipairs(model:GetDescendants()) do
		if item:IsA("BasePart") then
			item.Anchored = false
		end
	end
	return true
end

local function returnStolenPet(carry)
	local owner = carry.FromPlayer
	if owner and owner.Parent == Players and playerPlot[owner] == carry.FromPlot then
		if putPetInBase(carry.FromPlot, carry.PetId, carry.Mutation) then
			notify(owner, "Your " .. petDisplayName(carry.PetId, carry.Mutation) .. " came back home!", Color3.fromRGB(120, 255, 150))
			return
		end
	end
end

-- Drops whatever the player carries. Stolen pets go back to their owner.
local function dropCarry(player)
	local carry = carrying[player]
	if not carry then
		return
	end
	carrying[player] = nil
	if carry.Model then
		carry.Model:Destroy()
	end
	player:SetAttribute("Carrying", nil)
	updateWalkSpeed(player)
	if carry.Kind == "Pet" and carry.FromPlayer then
		returnStolenPet(carry)
	end
end

local function startCarry(player, carry, model)
	if not attachToPlayer(player, model) then
		return false
	end
	carry.Model = model
	carrying[player] = carry
	player:SetAttribute("Carrying", carry.Label)
	updateWalkSpeed(player)
	return true
end

local function deliver(player, plot)
	local carry = carrying[player]
	local ok
	if carry.Kind == "Egg" then
		ok = putEggInBase(plot, carry.Rarity)
	else
		ok = putPetInBase(plot, carry.PetId, carry.Mutation)
	end
	if not ok then
		if not carry.WarnedFull then
			carry.WarnedFull = true
			notify(player, "Your base is full!", Color3.fromRGB(255, 120, 120))
		end
		return
	end
	carrying[player] = nil
	carry.Model:Destroy()
	player:SetAttribute("Carrying", nil)
	updateWalkSpeed(player)
	if carry.Kind == "Egg" then
		notify(player, "Egg is hatching!", rarityColor(carry.Rarity))
	else
		local def = Config.PetsById[carry.PetId]
		notify(player, "You stole " .. petDisplayName(carry.PetId, carry.Mutation) .. "!", rarityColor(def.Rarity))
		if carry.FromPlayer and carry.FromPlayer.Parent == Players then
			notify(carry.FromPlayer, player.DisplayName .. " got away with your " .. def.Name .. "!", Color3.fromRGB(255, 120, 120))
		end
	end
end

---------------------------------------------------------------------
-- Eggs in the field
---------------------------------------------------------------------
local function onEggTriggered(player, zone, nest, eggModel)
	if nest.Egg ~= eggModel then
		return
	end
	if carrying[player] then
		notify(player, "Your hands are full!", Color3.fromRGB(255, 200, 120))
		return
	end
	local plot = playerPlot[player]
	if not plot then
		return
	end
	if countUsedSlots(plot) >= Config.MaxPetsPerBase then
		notify(player, "Your base is full! (" .. Config.MaxPetsPerBase .. " squishies max)", Color3.fromRGB(255, 120, 120))
		return
	end
	local rarity = eggModel:GetAttribute("Rarity")
	nest.Egg = nil
	nest.NextSpawn = now() + Config.EggRespawnTime
	eggModel:Destroy()

	local carried = PetModels.BuildEgg(rarity)
	if startCarry(player, { Kind = "Egg", Rarity = rarity, Label = rarity .. " Egg" }, carried) then
		notify(player, "Got a " .. rarity .. " Egg! Run back to your base!", rarityColor(rarity))
	end
end

local function spawnEgg(zone, nest)
	local rarity = Config.WeightedPick(zone.Config.EggWeights, rng)
	local model = PetModels.BuildEgg(rarity)
	PetModels.PlaceOnSurface(model, nest.Surface)
	PetModels.AddLabel(model, rarity .. " Egg", "", rarityColor(rarity), 3.2)

	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Grab Egg"
	prompt.ObjectText = rarity
	prompt.HoldDuration = Config.Rarities[rarity].HoldTime
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt.Triggered:Connect(function(player)
		onEggTriggered(player, zone, nest, model)
	end)
	prompt.Parent = model.PrimaryPart

	model.Parent = eggsFolder
	nest.Egg = model
end

---------------------------------------------------------------------
-- Stealing pets from other bases
---------------------------------------------------------------------
onPetStealTriggered = function(thief, plot, slotIndex, slot)
	local owner = plotOwner[plot.Index]
	if not owner or owner == thief then
		return
	end
	if slots[plot.Index][slotIndex] ~= slot or slot.State ~= "Pet" then
		return
	end
	if now() < lockedUntil[plot.Index] then
		notify(thief, "This base is locked!", Color3.fromRGB(255, 120, 120))
		return
	end
	if carrying[thief] then
		notify(thief, "Your hands are full!", Color3.fromRGB(255, 200, 120))
		return
	end
	local thiefPlot = playerPlot[thief]
	if not thiefPlot or countUsedSlots(thiefPlot) >= Config.MaxPetsPerBase then
		notify(thief, "Your base is full!", Color3.fromRGB(255, 120, 120))
		return
	end

	slots[plot.Index][slotIndex] = nil
	clearSlotModel(slot)

	local carried = PetModels.BuildPet(slot.PetId, slot.Mutation)
	local carry = {
		Kind = "Pet",
		PetId = slot.PetId,
		Mutation = slot.Mutation,
		FromPlayer = owner,
		FromPlot = plot,
		Label = Config.PetsById[slot.PetId].Name,
	}
	if startCarry(thief, carry, carried) then
		local name = petDisplayName(slot.PetId, slot.Mutation)
		notify(thief, "You grabbed " .. name .. "! Run to your base!", Color3.fromRGB(255, 220, 120))
		notify(owner, thief.DisplayName .. " is stealing your " .. name .. "! Catch them!", Color3.fromRGB(255, 90, 90))
	else
		-- could not carry (no character): put it straight back
		putPetInBase(plot, slot.PetId, slot.Mutation)
	end
end

---------------------------------------------------------------------
-- Guardians
---------------------------------------------------------------------
local guardians = {}

local function buildGuardian(zone)
	local g = zone.Config.Guardian
	local model = Instance.new("Model")
	model.Name = g.Name

	local function gpart(kind, size, offset, color)
		local p = Instance.new("Part")
		p.Anchored = true
		p.CanCollide = false
		p.CanTouch = false
		p.Material = Enum.Material.SmoothPlastic
		p.Color = color
		if kind == "Ball" then
			p.Shape = Enum.PartType.Ball
			p.Size = size
		elseif kind == "Ellipsoid" then
			p.Size = size
			local mesh = Instance.new("SpecialMesh")
			mesh.MeshType = Enum.MeshType.Sphere
			mesh.Parent = p
		elseif kind == "Cylinder" then
			p.Shape = Enum.PartType.Cylinder
			p.Size = Vector3.new(size.Y, size.X, size.Z)
		else
			p.Size = size
		end
		local cf = CFrame.new(offset)
		if kind == "Cylinder" then
			cf = cf * CFrame.Angles(0, 0, math.rad(90))
		end
		p.CFrame = cf
		p.Parent = model
		return p
	end

	local body = gpart("Ellipsoid", Vector3.new(7, 8, 6), Vector3.new(0, 4, 0), g.Color)
	body.Name = "Body"
	gpart("Ball", Vector3.new(5, 5, 5), Vector3.new(0, 9.5, 0), g.Color)
	gpart("Ball", Vector3.new(1.8, 1.8, 1.8), Vector3.new(-2, 11.6, 0), g.Color)
	gpart("Ball", Vector3.new(1.8, 1.8, 1.8), Vector3.new(2, 11.6, 0), g.Color)
	gpart("Ball", Vector3.new(0.9, 0.9, 0.9), Vector3.new(-0.9, 10, -2.2), Color3.fromRGB(30, 25, 30))
	gpart("Ball", Vector3.new(0.9, 0.9, 0.9), Vector3.new(0.9, 10, -2.2), Color3.fromRGB(30, 25, 30))
	gpart("Ellipsoid", Vector3.new(1.8, 1.2, 1), Vector3.new(0, 9.1, -2.3), g.Color:Lerp(Color3.new(1, 1, 1), 0.5))
	-- angry eyebrows
	local brow1 = gpart("Block", Vector3.new(1.2, 0.25, 0.3), Vector3.new(-0.9, 10.8, -2.3), Color3.fromRGB(30, 25, 30))
	brow1.CFrame = brow1.CFrame * CFrame.Angles(0, 0, math.rad(-20))
	local brow2 = gpart("Block", Vector3.new(1.2, 0.25, 0.3), Vector3.new(0.9, 10.8, -2.3), Color3.fromRGB(30, 25, 30))
	brow2.CFrame = brow2.CFrame * CFrame.Angles(0, 0, math.rad(20))
	-- chef hat
	gpart("Cylinder", Vector3.new(3.4, 1.6, 3.4), Vector3.new(0, 12.6, 0), Color3.new(1, 1, 1))
	gpart("Ball", Vector3.new(4, 4, 4), Vector3.new(0, 14, 0), Color3.new(1, 1, 1))

	model.PrimaryPart = body
	model.WorldPivot = CFrame.new(0, 0, 0) -- pivot at the feet

	local gui = PetModels.AddLabel(model, g.Name, "Guards the eggs!", Color3.fromRGB(255, 90, 90), 13)
	gui.MaxDistance = 120

	local start = Vector3.new(0, 0, (zone.MinZ + zone.MaxZ) / 2)
	model:PivotTo(CFrame.new(start))
	model.Parent = map.Folder

	return {
		Zone = zone,
		Model = model,
		Position = start,
		Target = start,
	}
end

for _, zone in ipairs(map.Zones) do
	table.insert(guardians, buildGuardian(zone))
end

local function randomPointIn(zone)
	return Vector3.new(
		rng:NextNumber(zone.MinX + 15, zone.MaxX - 15),
		0,
		rng:NextNumber(zone.MinZ + 10, zone.MaxZ - 10)
	)
end

local function updateGuardian(guardian, dt)
	local zone = guardian.Zone
	local g = zone.Config.Guardian

	-- find the closest player carrying something inside this zone
	local chaseTarget, chasePlayer
	local closest = g.ChaseRange
	for player in pairs(carrying) do
		local root = getRoot(player)
		if root and isInside(root.Position, zone, 5) then
			local flat = Vector3.new(root.Position.X, 0, root.Position.Z)
			local distance = (flat - guardian.Position).Magnitude
			if distance < closest then
				closest = distance
				chaseTarget = flat
				chasePlayer = player
			end
		end
	end

	local speed
	local target
	if chaseTarget then
		target = chaseTarget
		speed = g.ChaseSpeed
	else
		if (guardian.Target - guardian.Position).Magnitude < 3 then
			guardian.Target = randomPointIn(zone)
		end
		target = guardian.Target
		speed = g.PatrolSpeed
	end

	local offset = target - guardian.Position
	local distance = offset.Magnitude
	if distance > 0.05 then
		local direction = offset.Unit
		local step = math.min(distance, speed * dt)
		local newPos = guardian.Position + direction * step
		newPos = Vector3.new(
			math.clamp(newPos.X, zone.MinX + 3, zone.MaxX - 3),
			0,
			math.clamp(newPos.Z, zone.MinZ + 3, zone.MaxZ - 3)
		)
		guardian.Position = newPos
		local bob = math.abs(math.sin(os.clock() * 8)) * 0.6
		guardian.Model:PivotTo(CFrame.lookAt(newPos, newPos + Vector3.new(direction.X, 0, direction.Z)) + Vector3.new(0, bob, 0))
	end

	-- caught!
	if chasePlayer and closest < 5.5 then
		local t = now()
		if not lastCaught[chasePlayer] or t - lastCaught[chasePlayer] > 2 then
			lastCaught[chasePlayer] = t
			local carry = carrying[chasePlayer]
			local what = carry and carry.Label or "it"
			dropCarry(chasePlayer)
			notify(chasePlayer, g.Name .. " caught you and took back the " .. what .. "!", Color3.fromRGB(255, 90, 90))
		end
	end
end

---------------------------------------------------------------------
-- Players joining and leaving
---------------------------------------------------------------------
local function setupCharacter(player, character)
	local root = character:WaitForChild("HumanoidRootPart", 10)
	local humanoid = character:WaitForChild("Humanoid", 10)
	if not root or not humanoid then
		return
	end
	task.wait()
	local plot = playerPlot[player]
	if plot then
		character:PivotTo(plot.SpawnCFrame)
	end
	updateWalkSpeed(player)
	humanoid.Died:Connect(function()
		dropCarry(player)
	end)
end

local function onPlayerAdded(player)
	local profile = DataService.Load(player)
	if player.Parent ~= Players then
		return
	end

	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"
	local coins = Instance.new("IntValue")
	coins.Name = "Coins"
	coins.Value = profile.Coins
	coins.Parent = leaderstats
	leaderstats.Parent = player

	player:SetAttribute("SpeedLevel", profile.SpeedLevel)
	player:SetAttribute("LockedUntil", 0)
	player:SetAttribute("LockReadyAt", 0)

	-- give the player a free base
	local plot
	for i, p in ipairs(map.Plots) do
		if not plotOwner[i] then
			plot = p
			break
		end
	end
	if plot then
		plotOwner[plot.Index] = player
		playerPlot[player] = plot
		player:SetAttribute("PlotIndex", plot.Index)
		plot.SignLabel.Text = player.DisplayName .. "'s Base"

		-- welcome gift for brand new players
		if #profile.Pets == 0 and profile.Coins == 0 and profile.SpeedLevel == 0 then
			table.insert(profile.Pets, { Id = "Dumpy", Mutation = "Normal" })
			task.delay(3, function()
				if player.Parent == Players then
					notify(player, "Welcome! Here's a free Dumpy to start your collection!", Color3.fromRGB(255, 200, 230))
				end
			end)
		end
		for _, pet in ipairs(profile.Pets) do
			putPetInBase(plot, pet.Id, pet.Mutation)
		end
	else
		notify(player, "All bases are taken, sorry! Try another server.", Color3.fromRGB(255, 120, 120))
	end

	player.CharacterAdded:Connect(function(character)
		setupCharacter(player, character)
	end)
	if player.Character then
		task.spawn(setupCharacter, player, player.Character)
	end
end

local function onPlayerRemoving(player)
	dropCarry(player)
	carrying[player] = nil
	lastCaught[player] = nil

	-- thieves carrying this player's pets keep them if they make it home
	for _, carry in pairs(carrying) do
		if carry.FromPlayer == player then
			carry.FromPlayer = nil
		end
	end

	local plot = playerPlot[player]
	local pets
	if plot then
		addCoins(player, stored[plot.Index])
		pets = collectPetsForSave(plot)
	end
	DataService.Save(player, pets)

	if plot then
		for i = 1, Config.MaxPetsPerBase do
			clearSlotModel(slots[plot.Index][i])
			slots[plot.Index][i] = nil
		end
		stored[plot.Index] = 0
		lockedUntil[plot.Index] = 0
		plot.Barrier.Transparency = 1
		plot.CollectLabel.Text = "Collect: 0"
		plot.SignLabel.Text = "Empty Base"
		plotOwner[plot.Index] = nil
		playerPlot[player] = nil
	end
	DataService.Release(player)
end

Players.PlayerAdded:Connect(onPlayerAdded)
for _, player in ipairs(Players:GetPlayers()) do
	task.spawn(onPlayerAdded, player)
end
Players.PlayerRemoving:Connect(onPlayerRemoving)

game:BindToClose(function()
	local running = 0
	for _, player in ipairs(Players:GetPlayers()) do
		running = running + 1
		task.spawn(function()
			local plot = playerPlot[player]
			if plot then
				addCoins(player, stored[plot.Index])
				stored[plot.Index] = 0
			end
			DataService.Save(player, plot and collectPetsForSave(plot) or nil)
			running = running - 1
		end)
	end
	local waited = 0
	while running > 0 and waited < 25 do
		waited = waited + task.wait(0.5)
	end
end)

---------------------------------------------------------------------
-- Collect pads
---------------------------------------------------------------------
for _, plot in ipairs(map.Plots) do
	plot.CollectPad.Touched:Connect(function(hit)
		local player = Players:GetPlayerFromCharacter(hit.Parent)
		if not player or playerPlot[player] ~= plot then
			return
		end
		local amount = math.floor(stored[plot.Index])
		if amount <= 0 then
			return
		end
		stored[plot.Index] = stored[plot.Index] - amount
		addCoins(player, amount)
		plot.CollectLabel.Text = "Collect: 0"
		notify(player, "+$" .. Config.FormatNumber(amount), Color3.fromRGB(255, 230, 90))
	end)
end

---------------------------------------------------------------------
-- Remotes: speed upgrade and base lock
---------------------------------------------------------------------
BuySpeedFunction.OnServerInvoke = function(player)
	local profile = DataService.Get(player)
	if not profile then
		return false, "Still loading..."
	end
	if profile.SpeedLevel >= Config.MaxSpeedLevel then
		return false, "You're already at max speed!"
	end
	local cost = Config.GetSpeedCost(profile.SpeedLevel)
	if profile.Coins < cost then
		return false, "You need $" .. Config.FormatNumber(cost) .. " for the next speed level."
	end
	setCoins(player, profile.Coins - cost)
	profile.SpeedLevel = profile.SpeedLevel + 1
	player:SetAttribute("SpeedLevel", profile.SpeedLevel)
	updateWalkSpeed(player)
	return true, "Speed level " .. profile.SpeedLevel .. "!"
end

LockBaseFunction.OnServerInvoke = function(player)
	local plot = playerPlot[player]
	if not plot then
		return false, "You don't have a base."
	end
	local t = now()
	local readyAt = player:GetAttribute("LockReadyAt") or 0
	if t < readyAt then
		return false, "Lock ready in " .. math.ceil(readyAt - t) .. "s"
	end
	lockedUntil[plot.Index] = t + Config.BaseLockDuration
	player:SetAttribute("LockedUntil", lockedUntil[plot.Index])
	player:SetAttribute("LockReadyAt", t + Config.BaseLockCooldown)
	plot.Barrier.Transparency = 0.4
	return true, "Base locked for " .. Config.BaseLockDuration .. "s!"
end

---------------------------------------------------------------------
-- Main loops
---------------------------------------------------------------------

-- Every frame: guardians move, carriers get checked
RunService.Heartbeat:Connect(function(dt)
	for _, guardian in ipairs(guardians) do
		updateGuardian(guardian, dt)
	end

	for player, carry in pairs(carrying) do
		local root = getRoot(player)
		if root then
			-- delivered home?
			local plot = playerPlot[player]
			if plot and isInside(root.Position, plot) then
				deliver(player, plot)
			elseif carry.Kind == "Pet" and carry.FromPlayer then
				-- the owner can tag the thief to get the pet back
				local ownerRoot = getRoot(carry.FromPlayer)
				if ownerRoot and (ownerRoot.Position - root.Position).Magnitude < 6 then
					notify(player, carry.FromPlayer.DisplayName .. " caught you!", Color3.fromRGB(255, 90, 90))
					dropCarry(player)
				end
			end
		end
	end
end)

-- Every quarter second: eggs spawn and hatch, locked bases push intruders out
task.spawn(function()
	while true do
		local t = now()

		for _, zone in ipairs(map.Zones) do
			for _, nest in ipairs(zone.Nests) do
				if not nest.Egg and t >= (nest.NextSpawn or 0) then
					spawnEgg(zone, nest)
				end
			end
		end

		for _, plot in ipairs(map.Plots) do
			for i = 1, Config.MaxPetsPerBase do
				local slot = slots[plot.Index][i]
				if slot and slot.State == "Egg" then
					local left = slot.HatchAt - t
					if left <= 0 then
						hatch(plot, i, slot)
					elseif slot.Label then
						slot.Label.Text = "Hatching in " .. math.ceil(left) .. "s"
					end
				end
			end

			if lockedUntil[plot.Index] > 0 then
				if t >= lockedUntil[plot.Index] then
					lockedUntil[plot.Index] = 0
					plot.Barrier.Transparency = 1
				else
					local owner = plotOwner[plot.Index]
					for _, player in ipairs(Players:GetPlayers()) do
						if player ~= owner then
							local root = getRoot(player)
							if root and isInside(root.Position, plot) then
								player.Character:PivotTo(CFrame.new(root.Position.X, root.Position.Y, plot.FrontZ - 8))
								notify(player, "That base is locked!", Color3.fromRGB(255, 120, 120))
							end
						end
					end
				end
			end
		end

		task.wait(0.25)
	end
end)

-- Every second: squishies earn coins
task.spawn(function()
	while true do
		task.wait(1)
		for _, plot in ipairs(map.Plots) do
			if plotOwner[plot.Index] then
				local income = 0
				for i = 1, Config.MaxPetsPerBase do
					local slot = slots[plot.Index][i]
					if slot and slot.State == "Pet" then
						income = income + Config.GetPetIncome(slot.PetId, slot.Mutation)
					end
				end
				stored[plot.Index] = stored[plot.Index] + income
				plot.CollectLabel.Text = "Collect: $" .. Config.FormatNumber(stored[plot.Index])
			end
		end
	end
end)

-- Autosave every 2 minutes
task.spawn(function()
	while true do
		task.wait(120)
		for _, player in ipairs(Players:GetPlayers()) do
			local plot = playerPlot[player]
			if plot then
				task.spawn(DataService.Save, player, collectPetsForSave(plot))
			end
		end
	end
end)

print("[" .. Config.GameName .. "] Server ready!")

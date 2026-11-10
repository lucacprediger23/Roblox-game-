-- D2D (Dust to Dealership) - main server script.
-- Truck delivers containers -> open -> wash to 100% -> roll tires -> display -> NPC customers pay.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local CollectionService = game:GetService("CollectionService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local CarBuilder = require(Shared:WaitForChild("CarBuilder"))
local DataService = require(script.Parent:WaitForChild("DataService"))
local MapBuilder = require(script.Parent:WaitForChild("MapBuilder"))

local rng = Random.new()

---------------------------------------------------------------------
-- Remotes
---------------------------------------------------------------------
local remotes = Instance.new("Folder")
remotes.Name = "Remotes"
remotes.Parent = ReplicatedStorage
local function remote(className, name)
	local r = Instance.new(className)
	r.Name = name
	r.Parent = remotes
	return r
end
local NotifyEvent = remote("RemoteEvent", "Notify")
local ScrubEvent = remote("RemoteEvent", "Scrub")
local RevealEvent = remote("RemoteEvent", "Reveal")
local OpenEngineEvent = remote("RemoteEvent", "OpenEngine")
local GoHomeEvent = remote("RemoteEvent", "GoHome")
local EngineAction = remote("RemoteFunction", "EngineAction")
local ClaimToken = remote("RemoteFunction", "ClaimToken")
local YardAction = remote("RemoteEvent", "YardAction")
local OfflineEvent = remote("RemoteEvent", "Offline")

local GOLD = Color3.fromRGB(255, 220, 80)
local RED = Color3.fromRGB(255, 110, 110)
local GREEN = Color3.fromRGB(120, 255, 150)

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
local carsFolder = Instance.new("Folder")
carsFolder.Name = "Cars"
carsFolder.Parent = map.Folder
local dirtFolder = Instance.new("Folder")
dirtFolder.Name = "Dirt"
dirtFolder.Parent = map.Folder
local npcFolder = Instance.new("Folder")
npcFolder.Name = "NPCs"
npcFolder.Parent = map.Folder

local plotOwner = {} -- [plotIndex] = player
local playerPlot = {} -- [player] = plot
local state = {} -- [plotIndex] = { Spots, Yard, Wash, Lift, NPCs }
local lastScrub = {}

for i = 1, #map.Plots do
	state[i] = { Spots = {}, Yard = {}, Wash = nil, Lift = nil, NPCs = 0 }
end

---------------------------------------------------------------------
-- Helpers
---------------------------------------------------------------------
local function getRoot(player)
	local c = player.Character
	return c and c:FindFirstChild("HumanoidRootPart")
end

local function rarityOf(carId)
	return Config.Rarities[Config.CarsById[carId].Rarity]
end

local function setCash(player, amount)
	local profile = DataService.Get(player)
	if not profile then
		return
	end
	profile.Cash = math.max(0, amount)
	local ls = player:FindFirstChild("leaderstats")
	if ls and ls:FindFirstChild("Cash") then
		ls.Cash.Value = profile.Cash
	end
end
local function addCash(player, amount)
	local profile = DataService.Get(player)
	if profile then
		setCash(player, profile.Cash + amount)
	end
end

local function completedCount(profile)
	local n = 0
	for _ in pairs(profile.Completed) do
		n = n + 1
	end
	return n
end

local function syncAttributes(player)
	local profile = DataService.Get(player)
	if not profile then
		return
	end
	player:SetAttribute("Tokens", profile.Tokens)
	player:SetAttribute("ShowroomLevel", profile.ShowroomLevel)
	player:SetAttribute("TruckLevel", profile.TruckLevel)
	player:SetAttribute("ToolLevel", profile.ToolLevel)
	player:SetAttribute("EngineLuck", profile.EngineLuck)
	player:SetAttribute("Completed", completedCount(profile))
	local d, c = {}, {}
	for id in pairs(profile.Discovered) do
		table.insert(d, id)
	end
	for id in pairs(profile.Claimed) do
		table.insert(c, id)
	end
	player:SetAttribute("Discovered", table.concat(d, ","))
	player:SetAttribute("Claimed", table.concat(c, ","))
	local ls = player:FindFirstChild("leaderstats")
	if ls and ls:FindFirstChild("Cars") then
		ls.Cars.Value = #d
	end
end

-- Small world tag: a dark rounded pill with a title and an optional second line.
-- Sized in studs (shrinks with distance) and only visible up close, so the world stays clean.
local function addLabel(adornee, title, subtitle, color, offsetY, maxDist)
	local gui = Instance.new("BillboardGui")
	gui.Name = "Label"
	local twoLines = subtitle and subtitle ~= ""
	gui.Size = UDim2.new(7, 0, twoLines and 1.9 or 1.15, 0)
	gui.StudsOffset = Vector3.new(0, offsetY or 6, 0)
	gui.MaxDistance = maxDist or 24
	gui.LightInfluence = 0
	local bg = Instance.new("Frame")
	bg.AnchorPoint = Vector2.new(0.5, 0.5)
	bg.Position = UDim2.new(0.5, 0, 0.5, 0)
	bg.Size = UDim2.new(1, 0, 1, 0)
	bg.BackgroundColor3 = Color3.fromRGB(24, 26, 34)
	bg.BackgroundTransparency = 0.25
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0.3, 0)
	c.Parent = bg
	bg.Parent = gui
	local t = Instance.new("TextLabel")
	t.BackgroundTransparency = 1
	t.Position = UDim2.new(0.06, 0, 0.08, 0)
	t.Size = UDim2.new(0.88, 0, twoLines and 0.5 or 0.84, 0)
	t.Font = Enum.Font.FredokaOne
	t.TextScaled = true
	t.TextColor3 = color or Color3.new(1, 1, 1)
	t.Text = title
	t.Parent = bg
	local sl = Instance.new("TextLabel")
	sl.BackgroundTransparency = 1
	sl.Position = UDim2.new(0.06, 0, 0.56, 0)
	sl.Size = UDim2.new(0.88, 0, 0.36, 0)
	sl.Font = Enum.Font.GothamBold
	sl.TextScaled = true
	sl.TextColor3 = Color3.fromRGB(230, 232, 240)
	sl.Text = subtitle or ""
	sl.Visible = twoLines
	sl.Parent = bg
	gui.Parent = adornee
	return gui, t, sl
end

local function addPrompt(parentPart, action, object, hold, owner, callback)
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = action
	prompt.ObjectText = object or ""
	prompt.HoldDuration = hold or 0
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	if owner then
		prompt:SetAttribute("OwnerUserId", owner.UserId)
		CollectionService:AddTag(prompt, "OwnerPrompt")
	end
	prompt.Triggered:Connect(callback)
	prompt.Parent = parentPart
	return prompt
end

local function carTitle(carId)
	return Config.CarsById[carId].Name
end

local function carSubtitle(carId, engineIndex)
	local r = rarityOf(carId)
	local s = string.upper(r.Name) .. " · " .. Config.GetOddsText(carId)
	if engineIndex then
		s = s .. " · $" .. Config.FormatNumber(Config.GetCarIncome(carId, engineIndex)) .. "/s"
	end
	return s
end

---------------------------------------------------------------------
-- Showroom spots
---------------------------------------------------------------------
local function maxSpots(profile)
	return Config.GetSpots(profile.ShowroomLevel)
end

local function refreshSpotPads(plot, profile)
	local open = profile and maxSpots(profile) or 0
	for i, spot in ipairs(plot.Spots) do
		local unlocked = i <= open
		spot.Pad.Transparency = unlocked and 0 or 1
		for _, trim in ipairs(spot.Trims or {}) do
			trim.Transparency = unlocked and 0 or 0.75
		end
	end
end

local sellSpot -- forward declaration
local applyShowroom -- forward declaration

local function showSpot(plot, spotIndex, entry)
	local owner = plotOwner[plot.Index]
	if entry.Model then
		entry.Model:Destroy()
	end
	local model = CarBuilder.BuildCar(entry.Id, { Tires = entry.Engine })
	model:PivotTo(plot.Spots[spotIndex].CFrame)
	addLabel(model.PrimaryPart, carTitle(entry.Id), "$" .. Config.FormatNumber(Config.GetCarIncome(entry.Id, entry.Engine)) .. "/s", rarityOf(entry.Id).Color, 6.5, 22)
	local value = Config.GetCarIncome(entry.Id, entry.Engine) * Config.SellSeconds
	addPrompt(model:FindFirstChild("Body"), "Sell $" .. Config.FormatNumber(value), carTitle(entry.Id), 1, owner, function(player)
		sellSpot(player, plot, spotIndex, entry)
	end)
	model.Parent = carsFolder
	entry.Model = model
end

-- (re)builds the showroom for the owner's level and puts the displayed cars back on their spots
applyShowroom = function(plot, player, profile)
	plot.BuildShowroom(profile.ShowroomLevel)
	plot.SetSign(string.upper(player.DisplayName) .. "'S " .. string.upper(Config.ShowroomNames[profile.ShowroomLevel]))
	for i, entry in pairs(state[plot.Index].Spots) do
		if plot.Spots[i] then
			showSpot(plot, i, entry)
		end
	end
	refreshSpotPads(plot, profile)
end

local function freeSpot(plot, profile)
	for i = 1, maxSpots(profile) do
		if not state[plot.Index].Spots[i] then
			return i
		end
	end
	return nil
end

sellSpot = function(player, plot, spotIndex, entry)
	if plotOwner[plot.Index] ~= player or state[plot.Index].Spots[spotIndex] ~= entry then
		return
	end
	state[plot.Index].Spots[spotIndex] = nil
	if entry.Model then
		entry.Model:Destroy()
	end
	local value = Config.GetCarIncome(entry.Id, entry.Engine) * Config.SellSeconds
	addCash(player, value)
	notify(player, "Sold " .. carTitle(entry.Id) .. " for $" .. Config.FormatNumber(value), GOLD)
end

---------------------------------------------------------------------
-- Discovery and the Index
---------------------------------------------------------------------
local function discover(player, carId)
	local profile = DataService.Get(player)
	local isNew = not profile.Discovered[carId]
	profile.Discovered[carId] = true
	if isNew then
		local car = Config.CarsById[carId]
		local key = tostring(car.Container)
		if not profile.Completed[key] then
			local all = true
			for _, id in ipairs(Config.Containers[car.Container].CarIds) do
				if not profile.Discovered[id] then
					all = false
					break
				end
			end
			if all then
				profile.Completed[key] = true
				profile.Tokens = profile.Tokens + Config.TokensPerCompletion
				notify(player, "Container " .. car.Container .. " COMPLETE! +5% income and +" .. Config.TokensPerCompletion .. " tokens", GOLD)
			end
		end
	end
	syncAttributes(player)
	return isNew
end

ClaimToken.OnServerInvoke = function(player, carId)
	local profile = DataService.Get(player)
	if not profile or type(carId) ~= "string" or not profile.Discovered[carId] or profile.Claimed[carId] then
		return false
	end
	profile.Claimed[carId] = true
	profile.Tokens = profile.Tokens + 1
	syncAttributes(player)
	return true
end

---------------------------------------------------------------------
-- Yard: containers and opened cars
---------------------------------------------------------------------
local spawnYardCar -- forward declaration
local sendToWash -- forward declaration

local function freeYardSlot(plot)
	for i = 1, #plot.YardSlots do
		if not state[plot.Index].Yard[i] then
			return i
		end
	end
	return nil
end

local function yardCount(plot)
	local n = 0
	for i = 1, #plot.YardSlots do
		if state[plot.Index].Yard[i] then
			n = n + 1
		end
	end
	return n
end

-- the crate shakes, glowing cracks spread, it bursts apart with a flash
local function crackOpen(model, color)
	local cf, size = model:GetBoundingBox()
	local prompt = model:FindFirstChildWhichIsA("ProximityPrompt", true)
	if prompt then
		prompt:Destroy()
	end
	local label = model.PrimaryPart and model.PrimaryPart:FindFirstChild("Label")
	if label then
		label:Destroy()
	end
	local glow = color:Lerp(Color3.new(1, 1, 1), 0.55)
	local cracks = {}
	local base = model:GetPivot()
	for step = 1, 14 do
		-- shake
		local k = step / 14
		local offset = Vector3.new(rng:NextNumber(-1, 1), 0, rng:NextNumber(-1, 1)) * (0.12 + 0.25 * k)
		model:PivotTo(base * CFrame.new(offset) * CFrame.Angles(0, rng:NextNumber(-0.04, 0.04) * (1 + k * 2), 0))
		-- a new crack on a random side every other step
		if step % 2 == 0 then
			local face = rng:NextInteger(1, 4)
			local normal = ({ Vector3.xAxis, -Vector3.xAxis, Vector3.zAxis, -Vector3.zAxis })[face]
			local half = size / 2
			local surface = cf.Position + cf:VectorToWorldSpace(normal * ((face <= 2) and half.X or half.Z) * 1.02)
			local c = Instance.new("Part")
			c.Name = "Crack"
			c.Anchored = true
			c.CanCollide = false
			c.CanQuery = false
			c.Material = Enum.Material.Neon
			c.Color = glow
			c.Size = Vector3.new(0.18, rng:NextNumber(1.2, 3.2), 0.18)
			c.CFrame = CFrame.lookAt(surface, surface + cf:VectorToWorldSpace(normal)) * CFrame.new(rng:NextNumber(-half.X * 0.6, half.X * 0.6), rng:NextNumber(-half.Y * 0.5, half.Y * 0.5), 0) * CFrame.Angles(0, 0, rng:NextNumber(-0.9, 0.9))
			c.Parent = model
			table.insert(cracks, c)
		end
		task.wait(0.07)
	end
	-- flash
	local flash = Instance.new("Part")
	flash.Shape = Enum.PartType.Ball
	flash.Anchored = true
	flash.CanCollide = false
	flash.CanQuery = false
	flash.Material = Enum.Material.Neon
	flash.Color = Color3.new(1, 1, 1)
	flash.Size = Vector3.new(2, 2, 2)
	flash.CFrame = CFrame.new(cf.Position)
	flash.Parent = carsFolder
	local light = Instance.new("PointLight")
	light.Range = 24
	light.Brightness = 4
	light.Parent = flash
	TweenService:Create(flash, TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Size = Vector3.new(14, 14, 14), Transparency = 1 }):Play()
	task.delay(0.5, function()
		flash:Destroy()
	end)
	-- burst into pieces that fly out and fade
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") and d.Transparency < 1 then
			d.Anchored = false
			d.CanCollide = true
			d.CanQuery = false
			local out = (d.Position - cf.Position)
			out = Vector3.new(out.X, 0, out.Z)
			out = out.Magnitude > 0.01 and out.Unit or Vector3.new(rng:NextNumber(-1, 1), 0, rng:NextNumber(-1, 1)).Unit
			d.AssemblyLinearVelocity = out * rng:NextNumber(14, 26) + Vector3.new(0, rng:NextNumber(16, 28), 0)
			d.AssemblyAngularVelocity = Vector3.new(rng:NextNumber(-8, 8), rng:NextNumber(-8, 8), rng:NextNumber(-8, 8))
			TweenService:Create(d, TweenInfo.new(1.4, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Transparency = 1 }):Play()
		end
	end
	model.Parent = workspace
	task.delay(1.5, function()
		model:Destroy()
	end)
end

local function openContainer(player, plot, slot, entry)
	if plotOwner[plot.Index] ~= player or state[plot.Index].Yard[slot] ~= entry or entry.Opening then
		return
	end
	local price = Config.GetContainerPrice(entry.Level)
	local profile = DataService.Get(player)
	if price > 0 then
		if not profile or profile.Cash < price then
			notify(player, "You need $" .. Config.FormatNumber(price) .. " to open this container.", RED)
			return
		end
		setCash(player, profile.Cash - price)
	end
	entry.Opening = true
	local model = entry.Model
	crackOpen(model, Config.Containers[entry.Level].Color)
	if state[plot.Index].Yard[slot] ~= entry then
		return
	end
	state[plot.Index].Yard[slot] = nil
	local carId = Config.RollCar(entry.Level, rng)
	local isNew = discover(player, carId)
	spawnYardCar(plot, slot, carId)
	RevealEvent:FireClient(player, carId, isNew)
	local car = Config.CarsById[carId]
	if car.Rarity >= 6 then
		notifyAll(player.DisplayName .. " found a " .. string.upper(rarityOf(carId).Name) .. " car: " .. car.Name .. "!", rarityOf(carId).Color)
	end
end

-- a quick dust/sparkle burst at a point
local function puff(pos, color, count)
	local a = Instance.new("Part")
	a.Anchored, a.CanCollide, a.CanQuery, a.CanTouch, a.Transparency = true, false, false, false, 1
	a.Size = Vector3.new(1, 1, 1)
	a.Position = pos
	local e = Instance.new("ParticleEmitter")
	e.Texture = "rbxasset://textures/particles/smoke_main.dds"
	e.Color = ColorSequence.new(color)
	e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.2), NumberSequenceKeypoint.new(1, 4.5) })
	e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.35), NumberSequenceKeypoint.new(1, 1) })
	e.Lifetime = NumberRange.new(0.5, 0.9)
	e.Speed = NumberRange.new(6, 12)
	e.SpreadAngle = Vector2.new(180, 180)
	e.Drag = 4
	e.LightInfluence = 0.3
	e.Enabled = false
	e.Parent = a
	a.Parent = workspace
	e:Emit(count or 12)
	Debris:AddItem(a, 1.5)
end

-- an unopened container that expired: it squashes, fades and vanishes in a puff
local function vanish(model)
	if not model or not model.Parent then
		return
	end
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("ProximityPrompt") or d:IsA("BillboardGui") then
			d:Destroy()
		end
	end
	local base = model:GetPivot()
	local v = Instance.new("NumberValue")
	v.Value = 0
	v.Changed:Connect(function(t)
		if model.Parent then
			-- a little hop, then shrink to nothing
			local hop = math.sin(math.min(t, 0.4) / 0.4 * math.pi) * 1.6
			model:ScaleTo(math.max(0.05, 1 - math.max(0, t - 0.3) / 0.7))
			model:PivotTo(base * CFrame.new(0, hop, 0) * CFrame.Angles(0, t * 2.5, 0))
		end
	end)
	local tw = TweenService:Create(v, TweenInfo.new(0.75, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Value = 1 })
	tw:Play()
	tw.Completed:Connect(function()
		puff(base.Position + Vector3.new(0, 2, 0), Color3.fromRGB(255, 255, 255), 16)
		v:Destroy()
		model:Destroy()
	end)
end

local function expireContainers(plot)
	local yard = state[plot.Index].Yard
	local n = 0
	for slot, entry in pairs(yard) do
		if entry.Kind == "Container" and not entry.Opening then
			yard[slot] = nil
			vanish(entry.Model)
			n = n + 1
		end
	end
	return n
end

local function spawnContainer(plot, slot, level, drop)
	local owner = plotOwner[plot.Index]
	local entry = { Kind = "Container", Level = level }
	local model = CarBuilder.BuildContainer(level)
	local target = plot.YardSlots[slot] * CFrame.Angles(0, math.rad(rng:NextNumber(-28, 28)), 0)
	model:SetAttribute("OwnerUserId", owner and owner.UserId or 0)
	model:SetAttribute("YardSlot", slot)
	model:SetAttribute("Kind", "Container")
	model:SetAttribute("Level", level)
	model:PivotTo(drop and (target + Vector3.new(0, 40, 0)) or target)
	local price = Config.GetContainerPrice(level)
	local priceText = price > 0 and ("$" .. Config.FormatNumber(price)) or "FREE"
	model:SetAttribute("Price", price)
	local _, tl = addLabel(model.PrimaryPart, priceText, nil, Color3.fromRGB(110, 240, 120), 8.4, 30)
	tl.Parent.Parent.Size = UDim2.new(3.6, 0, 1.15, 0)
	addPrompt(model:FindFirstChild("Box"), "Open · " .. priceText, "Container " .. level, 0.6, owner, function(player)
		openContainer(player, plot, slot, entry)
	end)
	model.Parent = carsFolder
	entry.Model = model
	state[plot.Index].Yard[slot] = entry
	if drop then
		-- pops out of the truck and flies in an arc into its yard slot
		local from = plot.TruckDrop or (target + Vector3.new(0, 40, 0))
		local p0, p2 = from.Position, target.Position
		local p1 = (p0 + p2) / 2 + Vector3.new(0, 26 + (p0 - p2).Magnitude * 0.18, 0)
		local spin = rng:NextNumber(-1, 1) * math.pi * 2
		model:PivotTo(from)
		model:ScaleTo(0.4)
		local alpha = Instance.new("NumberValue")
		alpha.Changed:Connect(function(t)
			if not model.Parent then
				return
			end
			local a = (1 - t) * (1 - t) * p0 + 2 * (1 - t) * t * p1 + t * t * p2
			model:ScaleTo(0.4 + 0.6 * math.min(1, t * 1.6))
			model:PivotTo(CFrame.new(a) * (target - target.Position) * CFrame.Angles(0, spin * (1 - t), 0))
		end)
		local tween = TweenService:Create(alpha, TweenInfo.new(1.15, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), { Value = 1 })
		tween:Play()
		tween.Completed:Connect(function()
			alpha:Destroy()
			if model.Parent then
				model:ScaleTo(1)
				model:PivotTo(target)
				puff(target.Position, Color3.fromRGB(235, 225, 205), 14)
			end
		end)
	end
end

spawnYardCar = function(plot, slot, carId)
	local owner = plotOwner[plot.Index]
	local entry = { Kind = "Car", Id = carId }
	local model = CarBuilder.BuildCar(carId)
	model:PivotTo(plot.YardSlots[slot])
	model:SetAttribute("OwnerUserId", owner and owner.UserId or 0)
	model:SetAttribute("YardSlot", slot)
	model:SetAttribute("Kind", "Car")
	-- a dusty look until it's washed
	for _, p in ipairs(model:GetDescendants()) do
		if p:IsA("BasePart") and p.Name ~= "Root" then
			local dust = Color3.fromRGB(196, 178, 150):Lerp(Config.Containers[Config.CarsById[carId].Container].Dirt, 0.25)
			p.Color = p.Color:Lerp(dust, 0.5)
		end
	end
	addLabel(model.PrimaryPart, carTitle(carId), "dirty · wash me", rarityOf(carId).Color, 6, 18)
	addPrompt(model:FindFirstChild("Body"), "Send to Wash Bay", carTitle(carId), 0.3, owner, function(player)
		sendToWash(player, plot, slot, entry)
	end)
	model.Parent = carsFolder
	entry.Model = model
	state[plot.Index].Yard[slot] = entry
end

---------------------------------------------------------------------
-- Wash bay
---------------------------------------------------------------------
local moveToLift -- forward declaration

local function dirtHealth(containerLevel)
	return math.min(4, math.ceil(containerLevel / 3))
end

local function setWashProgress(plot, value)
	local owner = plotOwner[plot.Index]
	if owner then
		owner:SetAttribute("WashProgress", value)
	end
	-- the paint shines back through as the dust comes off
	local wash = state[plot.Index] and state[plot.Index].Wash
	if value and wash and wash.Paint then
		local k = 0.45 * math.max(0, 1 - value * 1.15)
		for part, color in pairs(wash.Paint) do
			if part.Parent then
				part.Color = color:Lerp(wash.DustColor, k)
			end
		end
		for _, f in ipairs(wash.Film or {}) do
			f.Transparency = math.min(1, 0.3 + 0.8 * value)
		end
	end
	if value then
		plot.WashLabel.Text = "WASHING  " .. math.floor(value * 100) .. "%"
	else
		plot.WashLabel.Text = "WASH SPOT"
	end
end

local function finishWash(plot)
	local wash = state[plot.Index].Wash
	if not wash or wash.Done then
		return
	end
	wash.Done = true
	for _, b in ipairs(wash.Blobs) do
		b.Part:Destroy()
	end
	wash.Blobs = {}
	for part, color in pairs(wash.Paint or {}) do
		if part.Parent then
			part.Color = color
		end
	end
	for _, f in ipairs(wash.Film or {}) do
		f:Destroy()
	end
	setWashProgress(plot, nil)
	plot.WashLabel.Text = "SPARKLING CLEAN!"
	local owner = plotOwner[plot.Index]
	if owner then
		notify(owner, "Sparkling clean! " .. carTitle(wash.Id) .. " is ready for new tires.", GREEN)
	end
	local sparkles = Instance.new("Sparkles")
	sparkles.Parent = wash.Model:FindFirstChild("Body")
	if not state[plot.Index].Lift then
		task.delay(1.2, function()
			moveToLift(plot)
		end)
	else
		addPrompt(wash.Model:FindFirstChild("Body"), "Move to Tire Shop", carTitle(wash.Id), 0, owner, function(player)
			if plotOwner[plot.Index] == player then
				if state[plot.Index].Lift then
					notify(player, "The tire shop is busy. Finish that car first!", RED)
				else
					moveToLift(plot)
				end
			end
		end)
	end
end

local function startWash(plot, carId)
	local car = Config.CarsById[carId]
	local model = CarBuilder.BuildCar(carId)
	model:PivotTo(plot.WashCFrame)
	model.Parent = carsFolder
	local health = dirtHealth(car.Container)
	local dirtColor = Config.Containers[car.Container].Dirt
	-- dust is a pale, sandy grey (not dark mud) tinted a little by the container
	local dustColor = Color3.fromRGB(196, 178, 150):Lerp(dirtColor, 0.25)
	-- the paint itself starts dull and dusty and comes back as you scrub
	local paint = {}
	local film = {}
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") and d.Name ~= "Root" and d.Transparency < 0.9 then
			paint[d] = d.Color
			d.Color = d.Color:Lerp(dustColor, 0.45)
		end
	end
	-- a soft, even film of dust hugging the whole car (a slightly larger see-through copy of each part)
	for part in pairs(paint) do
		if part.Transparency < 0.3 and part.Size.Magnitude > 0.8 then
			local f = part:Clone()
			f:ClearAllChildren()
			f.Name = "DustFilm"
			if f:IsA("MeshPart") then
				f.TextureID = ""
			end
			f.Size = part.Size * 1.025 + Vector3.new(0.04, 0.04, 0.04)
			f.CFrame = part.CFrame
			f.Color = dustColor
			f.Material = Enum.Material.SmoothPlastic
			f.Reflectance = 0
			f.Transparency = 0.3
			f.Anchored = true
			f.CanCollide = false
			f.CanQuery = false
			f.CanTouch = false
			f.CastShadow = false
			f.Parent = model
			table.insert(film, f)
		end
	end
	local boxCF, size = model:GetBoundingBox()
	local hx, hy, hz = size.X / 2, size.Y / 2, size.Z / 2
	local blobs = {}
	-- only the visible parts of the car catch dirt
	local visible = {}
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") and d.Transparency < 0.9 then
			table.insert(visible, d)
		end
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = visible
	local taken = {}
	local function blob(fromLocal, dirLocal)
		local origin = boxCF:PointToWorldSpace(fromLocal)
		local dir = boxCF:VectorToWorldSpace(dirLocal)
		local hit = workspace:Raycast(origin, dir, params)
		if not hit then
			return
		end
		local pos = hit.Position
		local key = math.floor(pos.X / 1.2) .. "," .. math.floor(pos.Y / 1.2) .. "," .. math.floor(pos.Z / 1.2)
		if taken[key] then
			return
		end
		taken[key] = true
		-- scrub target lying flat on the paint
		local sz = rng:NextNumber(1.7, 2.2)
		local p = Instance.new("Part")
		p.Name = "Dirt"
		p.Shape = Enum.PartType.Cylinder
		p.Size = Vector3.new(0.04, sz, sz)
		p.CFrame = CFrame.lookAt(pos + hit.Normal * 0.03, pos + hit.Normal * 2) * CFrame.Angles(0, math.rad(90), 0) * CFrame.Angles(rng:NextNumber(0, 6.28), 0, 0)
		p.Anchored = true
		p.CanCollide = false
		p.CanTouch = false
		p.CastShadow = false
		p.Material = Enum.Material.SmoothPlastic
		p.Color = dustColor
		p.Transparency = 1 -- invisible scrub target; the visible dust is the film over the paint
		p.Parent = dirtFolder
		table.insert(blobs, { Part = p, Health = health, StartSize = sz })
	end
	-- shoot rays at the car from above and from all four sides; dirt sticks where they land
	local spacing = 1.05
	local reach = 2 * math.max(hx, hy, hz) + 4
	for x = -hx + 0.6, hx - 0.6, spacing do
		for z = -hz + 0.6, hz - 0.6, spacing do
			blob(Vector3.new(x + rng:NextNumber(-0.4, 0.4), hy + 2, z + rng:NextNumber(-0.4, 0.4)), Vector3.new(0, -reach, 0))
		end
	end
	for y = -hy + 0.8, hy - 0.4, spacing do
		for z = -hz + 0.6, hz - 0.6, spacing do
			blob(Vector3.new(hx + 2, y, z), Vector3.new(-reach, 0, 0))
			blob(Vector3.new(-hx - 2, y, z), Vector3.new(reach, 0, 0))
		end
		for x = -hx + 0.6, hx - 0.6, spacing do
			blob(Vector3.new(x, y, hz + 2), Vector3.new(0, 0, -reach))
			blob(Vector3.new(x, y, -hz - 2), Vector3.new(0, 0, reach))
		end
	end
	local wash = {
		Id = carId,
		Model = model,
		Blobs = blobs,
		Total = #blobs * health,
		Remaining = #blobs * health,
		Health = health,
		Paint = paint,
		Film = film,
		DustColor = dustColor,
		Done = false,
	}
	state[plot.Index].Wash = wash
	setWashProgress(plot, 0)

	-- the Automatic Car Wash cleans by itself
	local owner = plotOwner[plot.Index]
	local profile = owner and DataService.Get(owner)
	if profile and Config.WashTools[profile.ToolLevel].Auto then
		task.spawn(function()
			local steps = 40
			for i = 1, steps do
				task.wait(8 / steps)
				if state[plot.Index].Wash ~= wash or wash.Done then
					return
				end
				local removeCount = math.ceil(#wash.Blobs / (steps - i + 1))
				for _ = 1, removeCount do
					local b = table.remove(wash.Blobs)
					if b then
						b.Part:Destroy()
					end
				end
				setWashProgress(plot, i / steps)
			end
			finishWash(plot)
		end)
	end
end

sendToWash = function(player, plot, slot, entry)
	if plotOwner[plot.Index] ~= player or state[plot.Index].Yard[slot] ~= entry then
		return
	end
	if state[plot.Index].Wash then
		notify(player, "The wash bay is busy. Finish washing the current car first!", RED)
		return
	end
	state[plot.Index].Yard[slot] = nil
	entry.Model:Destroy()
	startWash(plot, entry.Id)
	-- bring the player to the wash bay so they can start scrubbing right away
	local char = player.Character
	if char then
		local stand = plot.WashCFrame:PointToWorldSpace(Vector3.new(10.5, 3, -4))
		char:PivotTo(CFrame.lookAt(stand, Vector3.new(plot.WashCFrame.X, stand.Y, plot.WashCFrame.Z)))
	end
end

ScrubEvent.OnServerEvent:Connect(function(player, hitPosition)
	if typeof(hitPosition) ~= "Vector3" then
		return
	end
	local t = os.clock()
	if lastScrub[player] and t - lastScrub[player] < Config.ScrubInterval * 0.6 then
		return
	end
	lastScrub[player] = t
	local plot = playerPlot[player]
	local wash = plot and state[plot.Index].Wash
	local profile = DataService.Get(player)
	if not wash or wash.Done or not profile then
		return
	end
	local root = getRoot(player)
	local center = plot.WashCFrame.Position
	if not root or (root.Position - center).Magnitude > 40 or (hitPosition - center).Magnitude > 22 then
		return
	end
	local tool = Config.WashTools[profile.ToolLevel]
	for i = #wash.Blobs, 1, -1 do
		local b = wash.Blobs[i]
		if (b.Part.Position - hitPosition).Magnitude <= tool.Radius + b.Part.Size.Y / 2 then
			local dmg = math.min(tool.Power, b.Health)
			b.Health = b.Health - dmg
			wash.Remaining = wash.Remaining - dmg
			if b.Health <= 0 then
				b.Part:Destroy()
				table.remove(wash.Blobs, i)
			end
		end
	end
	local progress = 1 - wash.Remaining / math.max(1, wash.Total)
	setWashProgress(plot, progress)
	if #wash.Blobs == 0 or progress >= 0.94 then
		finishWash(plot)
	end
end)

---------------------------------------------------------------------
-- Engine lift
---------------------------------------------------------------------
local function rebuildLift(plot)
	local lift = state[plot.Index].Lift
	if not lift then
		return
	end
	if lift.Model then
		lift.Model:Destroy()
	end
	local owner = plotOwner[plot.Index]
	local model = CarBuilder.BuildCar(lift.Id, { Tires = lift.Engine })
	model:PivotTo(plot.LiftCFrame)
	model:SetAttribute("OwnerUserId", owner and owner.UserId or 0)
	model:SetAttribute("Kind", "Lift")
	addPrompt(model:FindFirstChild("Body"), "Change Tires", carTitle(lift.Id), 0, owner, function(player)
		if plotOwner[plot.Index] == player and state[plot.Index].Lift == lift then
			OpenEngineEvent:FireClient(player, lift.Id, lift.Engine)
		end
	end)
	model.Parent = carsFolder
	lift.Model = model
end

moveToLift = function(plot)
	local wash = state[plot.Index].Wash
	if not wash or not wash.Done or state[plot.Index].Lift then
		return
	end
	wash.Model:Destroy()
	state[plot.Index].Wash = nil
	plot.WashLabel.Text = "WASH SPOT"
	state[plot.Index].Lift = { Id = wash.Id, Engine = nil }
	rebuildLift(plot)
	plot.LiftLabel.Text = "TIRE SHOP"
	local owner = plotOwner[plot.Index]
	if owner then
		OpenEngineEvent:FireClient(owner, wash.Id, nil)
	end
end

local function rollEngine(profile, lucky)
	local weights = Config.GetEngineWeights(profile.EngineLuck, lucky)
	return Config.WeightedIndex(weights, rng)
end

EngineAction.OnServerInvoke = function(player, action)
	local plot = playerPlot[player]
	local profile = DataService.Get(player)
	local lift = plot and state[plot.Index].Lift
	if not profile or not lift then
		return { Ok = false, Message = "There's no car in the tire shop." }
	end
	if action == "Roll" or action == "Lucky" then
		if action == "Lucky" then
			if profile.Tokens < 1 then
				return { Ok = false, Message = "You need 1 token. Collect tokens in the Index!" }
			end
			profile.Tokens = profile.Tokens - 1
			syncAttributes(player)
		end
		lift.Engine = rollEngine(profile, action == "Lucky")
		rebuildLift(plot)
		local engine = Config.Engines[lift.Engine]
		if lift.Engine >= 6 then
			notifyAll(player.DisplayName .. " rolled a " .. engine.Name .. "!", engine.Color)
		end
		return { Ok = true, Engine = lift.Engine, Income = Config.GetCarIncome(lift.Id, lift.Engine) }
	elseif action == "Done" then
		if not lift.Engine then
			return { Ok = false, Message = "Roll a set of tires first!" }
		end
		local spot = freeSpot(plot, profile)
		if not spot then
			return { Ok = false, Message = "Your showroom is full! Sell a car or upgrade the showroom." }
		end
		lift.Model:Destroy()
		state[plot.Index].Lift = nil
		local entry = { Id = lift.Id, Engine = lift.Engine }
		state[plot.Index].Spots[spot] = entry
		showSpot(plot, spot, entry)
		notify(player, carTitle(lift.Id) .. " is on display! Customers are on the way.", GREEN)
		if state[plot.Index].Wash and state[plot.Index].Wash.Done then
			task.delay(0.5, function()
				moveToLift(plot)
			end)
		end
		return { Ok = true, Done = true }
	elseif action == "Sell" then
		local value = Config.GetCarIncome(lift.Id, lift.Engine or 1) * Config.SellSeconds
		lift.Model:Destroy()
		state[plot.Index].Lift = nil
		addCash(player, value)
		notify(player, "Sold " .. carTitle(lift.Id) .. " for $" .. Config.FormatNumber(value), GOLD)
		if state[plot.Index].Wash and state[plot.Index].Wash.Done then
			task.delay(0.5, function()
				moveToLift(plot)
			end)
		end
		return { Ok = true, Done = true }
	end
	return { Ok = false }
end

---------------------------------------------------------------------
-- Upgrade pads
---------------------------------------------------------------------
local function setPad(pad, levelText, price, stateName)
	pad.Label.Text = levelText
	if stateName == "max" then
		pad.Price.Text = "MAX"
		pad.Plate.Color = Color3.fromRGB(150, 160, 190)
	elseif stateName == "locked" then
		pad.Price.Text = price
		pad.Plate.Color = Color3.fromRGB(225, 70, 70)
	else
		pad.Price.Text = "$" .. Config.FormatNumber(price)
		pad.Plate.Color = Color3.fromRGB(60, 200, 80)
	end
end

local function refreshPads(plot)
	local owner = plotOwner[plot.Index]
	local profile = owner and DataService.Get(owner)
	local pads = plot.Pads
	if not profile then
		for _, pad in pairs(pads) do
			setPad(pad, "", "FOR SALE", "locked")
		end
		return
	end
	local L = profile.ShowroomLevel
	if L >= Config.MaxShowroomLevel then
		setPad(pads.Showroom, Config.ShowroomNames[L], 0, "max")
	else
		setPad(pads.Showroom, Config.ShowroomNames[L] .. " -> " .. Config.ShowroomNames[L + 1], Config.GetShowroomCost(L + 1))
	end
	local per = Config.GetContainersPerDelivery(profile.TruckLevel)
	if profile.TruckLevel >= Config.MaxTruckLevel then
		setPad(pads.Truck, "Level " .. profile.TruckLevel .. " · " .. per .. " per delivery", 0, "max")
	elseif profile.TruckLevel + 1 > Config.GetMaxTruck(L) then
		setPad(pads.Truck, "Level " .. profile.TruckLevel .. " · " .. per .. " per delivery", "UPGRADE SHOWROOM", "locked")
	else
		setPad(pads.Truck, "Level " .. profile.TruckLevel .. " · " .. per .. " per delivery", Config.GetTruckCost(profile.TruckLevel + 1))
	end
	local tool = Config.WashTools[profile.ToolLevel]
	if profile.ToolLevel >= #Config.WashTools then
		setPad(pads.Wash, tool.Name, 0, "max")
	elseif profile.ToolLevel + 1 > Config.GetMaxTool(L) then
		setPad(pads.Wash, tool.Name, "UPGRADE SHOWROOM", "locked")
	else
		setPad(pads.Wash, tool.Name .. " -> " .. Config.WashTools[profile.ToolLevel + 1].Name, Config.WashTools[profile.ToolLevel + 1].Cost)
	end
	if profile.EngineLuck >= Config.MaxEngineLuck then
		setPad(pads.Engine, "Level " .. profile.EngineLuck, 0, "max")
	else
		setPad(pads.Engine, "Level " .. profile.EngineLuck, Config.GetEngineLuckCost(profile.EngineLuck))
	end
end

local function tryBuy(player, cost, apply)
	local profile = DataService.Get(player)
	if profile.Cash < cost then
		notify(player, "You need $" .. Config.FormatNumber(cost) .. ".", RED)
		return
	end
	setCash(player, profile.Cash - cost)
	apply(profile)
	syncAttributes(player)
	local plot = playerPlot[player]
	if plot then
		refreshPads(plot)
		refreshSpotPads(plot, profile)
	end
end

for _, plot in ipairs(map.Plots) do
	local function padPrompt(padKey, handler)
		addPrompt(plot.Pads[padKey].Part, "Upgrade", "", 0.4, nil, function(player)
			if playerPlot[player] ~= plot then
				notify(player, "That's someone else's upgrade pad.", RED)
				return
			end
			handler(player, DataService.Get(player))
		end)
	end
	padPrompt("Showroom", function(player, profile)
		if profile.ShowroomLevel >= Config.MaxShowroomLevel then
			return notify(player, "Your showroom is maxed!", GOLD)
		end
		tryBuy(player, Config.GetShowroomCost(profile.ShowroomLevel + 1), function(p)
			p.ShowroomLevel = p.ShowroomLevel + 1
			applyShowroom(plot, player, p)
			notify(player, "Your " .. Config.ShowroomNames[p.ShowroomLevel] .. " is open! " .. maxSpots(p) .. " display spots, containers up to " .. Config.GetMaxContainer(p.ShowroomLevel) .. ".", GREEN)
		end)
	end)
	padPrompt("Truck", function(player, profile)
		local nextLevel = profile.TruckLevel + 1
		if nextLevel > Config.MaxTruckLevel then
			return notify(player, "Your truck is maxed!", GOLD)
		end
		if nextLevel > Config.GetMaxTruck(profile.ShowroomLevel) then
			return notify(player, "Upgrade your showroom first to unlock a bigger truck.", RED)
		end
		tryBuy(player, Config.GetTruckCost(nextLevel), function(p)
			p.TruckLevel = nextLevel
			notify(player, "Truck level " .. nextLevel .. "! " .. Config.GetContainersPerDelivery(nextLevel) .. " containers per delivery.", GREEN)
		end)
	end)
	padPrompt("Wash", function(player, profile)
		if profile.ToolLevel >= #Config.WashTools then
			return notify(player, "Your car wash is maxed!", GOLD)
		end
		if profile.ToolLevel + 1 > Config.GetMaxTool(profile.ShowroomLevel) then
			return notify(player, "Upgrade your showroom first to unlock a better car wash.", RED)
		end
		local t = Config.WashTools[profile.ToolLevel + 1]
		tryBuy(player, t.Cost, function(p)
			p.ToolLevel = p.ToolLevel + 1
			plot.SetWashTier(p.ToolLevel)
			notify(player, "New tool: " .. t.Name .. "!", GREEN)
		end)
	end)
	padPrompt("Engine", function(player, profile)
		if profile.EngineLuck >= Config.MaxEngineLuck then
			return notify(player, "Tire Luck is maxed!", GOLD)
		end
		tryBuy(player, Config.GetEngineLuckCost(profile.EngineLuck), function(p)
			p.EngineLuck = p.EngineLuck + 1
			notify(player, "Tire Luck level " .. p.EngineLuck .. "! Better tires are more likely.", GREEN)
		end)
	end)
	refreshPads(plot)
	refreshSpotPads(plot, nil)
end

---------------------------------------------------------------------
-- Hotbar: click a card to open that container or wash that car
---------------------------------------------------------------------
YardAction.OnServerEvent:Connect(function(player, slot)
	local plot = playerPlot[player]
	if not plot or typeof(slot) ~= "number" then
		return
	end
	local entry = state[plot.Index].Yard[slot]
	if not entry or not entry.Model then
		return
	end
	if entry.Kind == "Container" then
		-- walk up to the crate first, then open it
		local char = player.Character
		if char then
			local p = entry.Model:GetPivot().Position
			local dir = (plot.SpawnCFrame.Position - p) * Vector3.new(1, 0, 1)
			dir = dir.Magnitude > 0.1 and dir.Unit or Vector3.zAxis
			local stand = p + dir * 7
			char:PivotTo(CFrame.lookAt(Vector3.new(stand.X, p.Y + 3, stand.Z), Vector3.new(p.X, p.Y + 3, p.Z)))
		end
		task.spawn(openContainer, player, plot, slot, entry)
	elseif entry.Kind == "Car" then
		sendToWash(player, plot, slot, entry)
	end
end)

---------------------------------------------------------------------
-- Truck deliveries
---------------------------------------------------------------------
local function scheduleNext(player)
	local profile = DataService.Get(player)
	local delay = Config.FirstDeliveries[profile.DeliveriesDone + 1] or Config.DeliveryInterval
	player:SetAttribute("NextDelivery", now() + delay)
end

local function rollContainerLevel(profile)
	return rng:NextInteger(1, Config.GetMaxContainer(profile.ShowroomLevel))
end

local delivering = {}
local function deliver(player)
	local plot = playerPlot[player]
	local profile = DataService.Get(player)
	if not plot or not profile or delivering[player] then
		return
	end
	delivering[player] = true
	-- last delivery's unopened containers expire before the new ones arrive
	local expired = expireContainers(plot)
	if expired > 0 then
		notify(player, expired .. " unopened container" .. (expired > 1 and "s" or "") .. " expired.", Color3.fromRGB(255, 190, 120))
		task.wait(1)
	end
	local delivered = 0
	for k = 1, Config.GetContainersPerDelivery(profile.TruckLevel) do
		if playerPlot[player] ~= plot then
			break
		end
		local slot = freeYardSlot(plot)
		if not slot then
			break
		end
		-- every delivery brings at least one free Container 1, so nobody can get stuck with $0
		spawnContainer(plot, slot, k == 1 and 1 or rollContainerLevel(profile), true)
		delivered = delivered + 1
		task.wait(0.14)
	end
	if delivered > 0 then
		profile.DeliveriesDone = profile.DeliveriesDone + 1
		notify(player, "New containers delivered!", GOLD)
		player:SetAttribute("YardFull", false)
	else
		player:SetAttribute("YardFull", true)
	end
	if player.Parent and DataService.Get(player) then
		scheduleNext(player)
	end
	delivering[player] = nil
end

task.spawn(function()
	while true do
		task.wait(0.5)
		local t = now()
		for player in pairs(playerPlot) do
			local nextAt = player:GetAttribute("NextDelivery")
			if nextAt and t >= nextAt then
				task.spawn(deliver, player)
			end
		end
	end
end)

---------------------------------------------------------------------
-- Income (every second) and NPC customers
---------------------------------------------------------------------
local function plotIncome(plot, profile)
	local total = 0
	for _, entry in pairs(state[plot.Index].Spots) do
		total = total + Config.GetCarIncome(entry.Id, entry.Engine)
	end
	return total * (1 + Config.CompletionBonus * completedCount(profile))
end

task.spawn(function()
	while true do
		task.wait(1)
		for player, plot in pairs(playerPlot) do
			local profile = DataService.Get(player)
			if profile then
				local income = plotIncome(plot, profile)
				profile.IncomeRate = income
				player:SetAttribute("IncomeRate", income)
				if income > 0 then
					addCash(player, income)
				end
			end
		end
	end
end)

local function buildNPC()
	local model = Instance.new("Model")
	model.Name = "Customer"
	local shirt = Color3.fromHSV(rng:NextNumber(), 0.6, 0.9)
	local body = Instance.new("Part")
	body.Name = "Body"
	body.Size = Vector3.new(2, 2, 1)
	body.Color = shirt
	body.Anchored = true
	body.CanCollide = false
	body.Parent = model
	local function attach(name, size, offset, color, shape)
		local p = Instance.new("Part")
		p.Name = name
		if shape then
			p.Shape = shape
		end
		p.Size = size
		p.Color = color
		p.CFrame = body.CFrame * CFrame.new(offset)
		p.Anchored = false
		p.CanCollide = false
		p.Massless = true
		local w = Instance.new("WeldConstraint")
		w.Part0 = body
		w.Part1 = p
		w.Parent = p
		p.Parent = model
		return p
	end
	local skins = { Color3.fromRGB(255, 214, 170), Color3.fromRGB(235, 180, 130), Color3.fromRGB(190, 130, 90), Color3.fromRGB(120, 80, 55) }
	local skin = skins[rng:NextInteger(1, #skins)]
	local pants = Color3.fromHSV(rng:NextNumber(), 0.4, rng:NextNumber(0.25, 0.5))
	local hair = Color3.fromHSV(rng:NextNumber(0.02, 0.12), 0.6, rng:NextNumber(0.15, 0.6))
	body.Material = Enum.Material.SmoothPlastic
	attach("Head", Vector3.new(1.5, 1.5, 1.5), Vector3.new(0, 1.8, 0), skin, Enum.PartType.Ball)
	attach("Hair", Vector3.new(1.6, 0.6, 1.6), Vector3.new(0, 2.35, 0.1), hair)
	for _, x in ipairs({ -0.3, 0.3 }) do
		attach("Eye", Vector3.new(0.18, 0.28, 0.1), Vector3.new(x, 1.9, -0.72), Color3.fromRGB(20, 20, 25))
		attach("Arm", Vector3.new(0.6, 1.9, 0.6), Vector3.new(x > 0 and 1.3 or -1.3, -0.05, 0), shirt:Lerp(skin, 0.15))
		attach("Hand", Vector3.new(0.55, 0.45, 0.55), Vector3.new(x > 0 and 1.3 or -1.3, -1.15, 0), skin)
		attach("Leg", Vector3.new(0.9, 1.8, 0.95), Vector3.new(x > 0 and 0.5 or -0.5, -1.9, 0), pants)
		attach("Shoe", Vector3.new(0.95, 0.35, 1.2), Vector3.new(x > 0 and 0.5 or -0.5, -2.85, -0.1), Color3.fromRGB(240, 240, 240))
	end
	model.PrimaryPart = body
	return model, body
end

-- Real Roblox characters as customers (R15 rig with random skin and clothes colors).
-- Falls back to the simple block customer if the rig can't be made.
local WALK_ANIM = "rbxassetid://507777826" -- Roblox's default R15 walk
local IDLE_ANIM = "rbxassetid://507766388" -- Roblox's default R15 idle
local function buildRigNPC()
	local desc = Instance.new("HumanoidDescription")
	local skins = { Color3.fromRGB(255, 214, 170), Color3.fromRGB(234, 184, 146), Color3.fromRGB(196, 140, 100), Color3.fromRGB(124, 84, 60) }
	local skin = skins[rng:NextInteger(1, #skins)]
	local shirt = Color3.fromHSV(rng:NextNumber(), rng:NextNumber(0.35, 0.7), rng:NextNumber(0.6, 0.95))
	local pants = Color3.fromHSV(rng:NextNumber(), rng:NextNumber(0.2, 0.5), rng:NextNumber(0.2, 0.45))
	desc.HeadColor = skin
	desc.LeftArmColor = skin
	desc.RightArmColor = skin
	desc.TorsoColor = shirt
	desc.LeftLegColor = pants
	desc.RightLegColor = pants
	local model = Players:CreateHumanoidModelFromDescription(desc, Enum.HumanoidRigType.R15)
	model.Name = "Customer"
	local root = model:FindFirstChild("HumanoidRootPart")
	local hum = model:FindFirstChildOfClass("Humanoid")
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") then
			d.CanCollide = false
			d.CanQuery = false
			d.CanTouch = false
			d.Massless = true
		end
	end
	root.Anchored = true
	hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	hum.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	model.PrimaryPart = root
	local animator = hum:FindFirstChildOfClass("Animator") or Instance.new("Animator", hum)
	local tracks = {}
	for name, id in pairs({ Walk = WALK_ANIM, Idle = IDLE_ANIM }) do
		local anim = Instance.new("Animation")
		anim.AnimationId = id
		local ok, track = pcall(function()
			return animator:LoadAnimation(anim)
		end)
		if ok then
			track.Looped = true
			tracks[name] = track
		end
	end
	model:SetAttribute("Rig", true)
	local height = hum.HipHeight + root.Size.Y / 2
	return model, root, tracks, height
end

local function walk(body, target, speed)
	local from = body.Position
	local dist = (target - from).Magnitude
	if dist < 0.1 then
		return
	end
	local look = Vector3.new(target.X, from.Y, target.Z)
	if (look - from).Magnitude > 0.1 then
		body.CFrame = CFrame.lookAt(from, look)
	end
	local tween = TweenService:Create(body, TweenInfo.new(dist / speed, Enum.EasingStyle.Linear), { CFrame = CFrame.lookAt(target, target + (target - from).Unit) })
	tween:Play()
	tween.Completed:Wait()
end

local function runCustomer(plot)
	local spots = {}
	for i, entry in pairs(state[plot.Index].Spots) do
		table.insert(spots, { Index = i, Entry = entry })
	end
	if #spots == 0 then
		return
	end
	local pick = spots[rng:NextInteger(1, #spots)]
	local model, body, tracks, height
	local ok0 = pcall(function()
		model, body, tracks, height = buildRigNPC()
	end)
	if not ok0 or not model then
		model, body = buildNPC()
		tracks, height = {}, 2.95
	end
	local y = 1 + height
	local function play(name)
		for n, t in pairs(tracks) do
			if n == name then
				if not t.IsPlaying then
					t:Play(0.2)
				end
			else
				t:Stop(0.2)
			end
		end
	end
	body.CFrame = CFrame.new(plot.DoorOutside.X + rng:NextNumber(-4, 4), y, plot.DoorOutside.Z)
	model.Parent = npcFolder
	state[plot.Index].NPCs = state[plot.Index].NPCs + 1
	local ok = pcall(function()
		local inside = Vector3.new(plot.DoorInside.X, y, plot.DoorInside.Z)
		local front = plot.Spots[pick.Index].Front.Position
		play("Walk")
		walk(body, inside, 9)
		walk(body, Vector3.new(front.X + rng:NextNumber(-2, 2), y, front.Z), 9)
		play("Idle")
		-- admire the car and pay
		local entry = state[plot.Index].Spots[pick.Index]
		if entry then
			local amount = Config.GetCarIncome(entry.Id, entry.Engine) * 3
			local gui, t = addLabel(body, "+$" .. Config.FormatNumber(amount), nil, GREEN, 3, 40)
			t.TextColor3 = GREEN
			task.wait(2.5)
			gui:Destroy()
		else
			task.wait(1)
		end
		play("Walk")
		walk(body, inside, 9)
		walk(body, Vector3.new(plot.DoorOutside.X + rng:NextNumber(-6, 6), y, plot.DoorOutside.Z), 9)
	end)
	if not ok then
		warn("[D2D] customer walk failed")
	end
	model:Destroy()
	state[plot.Index].NPCs = state[plot.Index].NPCs - 1
end

task.spawn(function()
	while true do
		task.wait(3)
		for player, plot in pairs(playerPlot) do
			local profile = DataService.Get(player)
			if profile then
				local limit = math.min(1 + math.floor(profile.ShowroomLevel / 2), 6)
				if state[plot.Index].NPCs < limit and next(state[plot.Index].Spots) then
					task.spawn(runCustomer, plot)
				end
			end
		end
	end
end)

---------------------------------------------------------------------
-- Players joining and leaving
---------------------------------------------------------------------
local function setupCharacter(player, character)
	local root = character:WaitForChild("HumanoidRootPart", 10)
	if not root then
		return
	end
	-- the plots are big: walk a bit faster so getting around feels snappy
	local hum = character:FindFirstChildOfClass("Humanoid")
	if hum then
		hum.WalkSpeed = 24
		hum.JumpPower = 50
	end
	task.wait()
	local plot = playerPlot[player]
	if plot then
		character:PivotTo(plot.SpawnCFrame)
	end
end

local function onPlayerAdded(player)
	local profile = DataService.Load(player)
	if player.Parent ~= Players then
		return
	end
	local ls = Instance.new("Folder")
	ls.Name = "leaderstats"
	local cash = Instance.new("NumberValue")
	cash.Name = "Cash"
	cash.Value = profile.Cash
	cash.Parent = ls
	local cars = Instance.new("IntValue")
	cars.Name = "Cars"
	cars.Parent = ls
	ls.Parent = player

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
		player:SetAttribute("WashFocus", plot.WashCFrame)
		player:SetAttribute("LiftFocus", plot.LiftCFrame)
		for _, d in ipairs(profile.Display) do
			state[plot.Index].Spots[d.Spot] = { Id = d.Id, Engine = d.Engine }
		end
		applyShowroom(plot, player, profile)
		plot.SetWashTier(profile.ToolLevel)
		for i, y in ipairs(profile.Yard) do
			if y.Kind == "Container" then
				spawnContainer(plot, i, y.Level, false)
			else
				spawnYardCar(plot, i, y.Id)
			end
		end
		refreshPads(plot)
		refreshSpotPads(plot, profile)
	else
		notify(player, "All showrooms are taken, sorry! Try another server.", RED)
	end
	syncAttributes(player)

	-- offline earnings
	if profile.LastOnline > 0 and profile.IncomeRate > 0 then
		local away = math.min(os.time() - profile.LastOnline, Config.OfflineMaxSeconds)
		local earned = math.floor(away * profile.IncomeRate * Config.OfflineRate)
		if earned >= 1 then
			addCash(player, earned)
			task.delay(3, function()
				if player.Parent == Players then
					OfflineEvent:FireClient(player, earned)
				end
			end)
		end
	end
	if plot then
		scheduleNext(player)
	end

	player.CharacterAdded:Connect(function(character)
		setupCharacter(player, character)
	end)
	if player.Character then
		task.spawn(setupCharacter, player, player.Character)
	end
end

local function collectSave(player)
	local profile = DataService.Get(player)
	local plot = playerPlot[player]
	if not profile or not plot then
		return
	end
	local s = state[plot.Index]
	profile.Display = {}
	for spot, entry in pairs(s.Spots) do
		table.insert(profile.Display, { Id = entry.Id, Engine = entry.Engine, Spot = spot })
	end
	profile.Yard = {}
	-- cars in the wash bay or on the lift go back to the yard
	if s.Lift then
		table.insert(profile.Yard, { Kind = "Car", Id = s.Lift.Id })
	end
	if s.Wash then
		table.insert(profile.Yard, { Kind = "Car", Id = s.Wash.Id })
	end
	for i = 1, #plot.YardSlots do
		local y = s.Yard[i]
		if y and #profile.Yard < Config.YardCapacity then
			if y.Kind == "Container" then
				table.insert(profile.Yard, { Kind = "Container", Level = y.Level })
			else
				table.insert(profile.Yard, { Kind = "Car", Id = y.Id })
			end
		end
	end
	profile.LastOnline = os.time()
end

local function clearPlot(plot)
	local s = state[plot.Index]
	for _, entry in pairs(s.Spots) do
		if entry.Model then
			entry.Model:Destroy()
		end
	end
	for _, entry in pairs(s.Yard) do
		if entry.Model then
			entry.Model:Destroy()
		end
	end
	if s.Wash then
		for _, b in ipairs(s.Wash.Blobs) do
			b.Part:Destroy()
		end
		s.Wash.Model:Destroy()
	end
	if s.Lift and s.Lift.Model then
		s.Lift.Model:Destroy()
	end
	state[plot.Index] = { Spots = {}, Yard = {}, Wash = nil, Lift = nil, NPCs = s.NPCs }
	plot.BuildShowroom(1)
	plot.SetSign("FOR SALE")
	plot.SetWashTier(1)
	plot.WashLabel.Text = "WASH SPOT"
	plot.LiftLabel.Text = "TIRE SHOP"
end

local function onPlayerRemoving(player)
	collectSave(player)
	DataService.Save(player)
	local plot = playerPlot[player]
	if plot then
		clearPlot(plot)
		plotOwner[plot.Index] = nil
		playerPlot[player] = nil
		refreshPads(plot)
		refreshSpotPads(plot, nil)
	end
	lastScrub[player] = nil
	DataService.Release(player)
end

Players.PlayerAdded:Connect(onPlayerAdded)
for _, player in ipairs(Players:GetPlayers()) do
	task.spawn(onPlayerAdded, player)
end
Players.PlayerRemoving:Connect(onPlayerRemoving)

GoHomeEvent.OnServerEvent:Connect(function(player)
	local plot = playerPlot[player]
	if plot and player.Character then
		player.Character:PivotTo(plot.SpawnCFrame)
	end
end)

game:BindToClose(function()
	local running = 0
	for _, player in ipairs(Players:GetPlayers()) do
		running = running + 1
		task.spawn(function()
			collectSave(player)
			DataService.Save(player)
			running = running - 1
		end)
	end
	local waited = 0
	while running > 0 and waited < 25 do
		waited = waited + task.wait(0.5)
	end
end)

task.spawn(function()
	while true do
		task.wait(120)
		for _, player in ipairs(Players:GetPlayers()) do
			collectSave(player)
			task.spawn(DataService.Save, player)
		end
	end
end)

print("[D2D] Server ready!")

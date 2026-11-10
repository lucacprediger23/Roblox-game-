-- MapBuilder: builds the world and the 6 player plots when the server starts.
-- Plots face each other across a boulevard. Each plot: a showroom that grows with its level
-- (level 1 is a small garage), a large yard beside it with the upgrade stations, the parking lot
-- for containers, the wash spot (more gear appears as the car wash is upgraded) and the tire shop.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Lighting = game:GetService("Lighting")
local CollectionService = game:GetService("CollectionService")
local TweenService = game:GetService("TweenService")
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local Props = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Props"))
local Icons = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Icons"))
local LightingPresets = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("LightingPresets"))

local MapBuilder = {}

local FLOOR_Y = 1
local rng = Random.new(2026)

-- palette
local PLASTER = Color3.fromRGB(212, 209, 200)
local PLASTER_SHADE = Color3.fromRGB(214, 210, 200)
local NAVY = Color3.fromRGB(34, 44, 64)
local STONE = Color3.fromRGB(150, 150, 155)
local TILE = Color3.fromRGB(172, 178, 190)
local GROUT = Color3.fromRGB(120, 128, 146)
local WOOD = Color3.fromRGB(232, 200, 150)
local GLASS = Color3.fromRGB(150, 190, 215)
local LAMP = Color3.fromRGB(255, 250, 238)
local ASPHALT = Color3.fromRGB(78, 79, 82)
local CONCRETE = Color3.fromRGB(160, 158, 154)
local LEAF = { Color3.fromRGB(70, 110, 52), Color3.fromRGB(82, 122, 58), Color3.fromRGB(62, 98, 46), Color3.fromRGB(90, 128, 62) }
local GOLD = Color3.fromRGB(255, 205, 80)

local function part(props, parent)
	local p = Instance.new("Part")
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Material = Enum.Material.SmoothPlastic
	if props.Shape then
		p.Shape = props.Shape
	end
	for k, v in pairs(props) do
		if k ~= "Shape" then
			p[k] = v
		end
	end
	-- real materials (brick, concrete, asphalt, marble...) only where a piece asks for one;
	-- everything else stays smooth. Metal never mirrors the sky.
	if p.Material == Enum.Material.Metal or p.Material == Enum.Material.DiamondPlate or p.Material == Enum.Material.CorrodedMetal then
		p.Reflectance = 0
	end
	p.Parent = parent
	return p
end

-- solid building piece
local function box(parent, name, size, cf, color, material, extra)
	local props = { Name = name, Size = size, CFrame = cf, Color = color, Material = material or Enum.Material.SmoothPlastic }
	if extra then
		for k, v in pairs(extra) do
			props[k] = v
		end
	end
	return part(props, parent)
end

-- decoration: no collisions, no raycasts, never blocks the camera
local function deco(parent, name, size, cf, color, material, extra)
	local props = { Name = name, Size = size, CFrame = cf, Color = color, Material = material or Enum.Material.SmoothPlastic, CanCollide = false, CanQuery = false, CanTouch = false }
	if extra then
		for k, v in pairs(extra) do
			props[k] = v
		end
	end
	return part(props, parent)
end

-- upright cylinder
local function column(parent, name, height, diameter, cf, color, material, solid)
	local p = part({
		Name = name,
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(height, diameter, diameter),
		CFrame = cf * CFrame.Angles(0, 0, math.rad(90)),
		Color = color,
		Material = material or Enum.Material.SmoothPlastic,
		CanCollide = solid or false,
		CanQuery = solid or false,
	}, parent)
	p.Size = Vector3.new(height, diameter, diameter)
	return p
end

local function ball(parent, name, d, cf, color, material)
	local p = part({ Name = name, Shape = Enum.PartType.Ball, Size = Vector3.new(d, d, d), CFrame = cf, Color = color, Material = material or Enum.Material.SmoothPlastic, CanCollide = false, CanQuery = false }, parent)
	p.Size = Vector3.new(d, d, d)
	return p
end

local function addStroke(l, thickness)
	local s = Instance.new("UIStroke")
	s.Thickness = thickness or 2.5
	s.Color = Color3.fromRGB(20, 20, 30)
	s.Parent = l
end

-- floating text sized in studs, only visible up close
local function label(adornee, text, color, offsetY, width, maxDist)
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.new((width or 220) / 36, 0, 1.4, 0)
	gui.StudsOffset = Vector3.new(0, offsetY or 4, 0)
	gui.MaxDistance = maxDist or 34
	gui.LightInfluence = 0
	local l = Instance.new("TextLabel")
	l.Size = UDim2.new(1, 0, 1, 0)
	l.BackgroundTransparency = 1
	l.Font = Enum.Font.GothamBold
	l.TextScaled = true
	l.TextColor3 = color or Color3.new(1, 1, 1)
	l.Text = text
	addStroke(l, 2)
	l.Parent = gui
	gui.Parent = adornee
	return l
end

local function surfaceText(p, face, text, color, pps, font)
	local gui = Instance.new("SurfaceGui")
	gui.Face = face
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = pps or 30
	gui.LightInfluence = 0.2
	local l = Instance.new("TextLabel")
	l.Size = UDim2.new(1, 0, 1, 0)
	l.BackgroundTransparency = 1
	l.Font = font or Enum.Font.GothamBold
	l.TextScaled = true
	l.TextColor3 = color or Color3.new(1, 1, 1)
	l.Text = text
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0.05, 0)
	pad.PaddingRight = UDim.new(0.05, 0)
	pad.PaddingTop = UDim.new(0.14, 0)
	pad.PaddingBottom = UDim.new(0.14, 0)
	pad.Parent = l
	l.Parent = gui
	gui.Parent = p
	return l
end

local function light(parent, range, brightness, color)
	local l = Instance.new("PointLight")
	l.Color = color or Color3.fromRGB(255, 244, 225)
	l.Range = range or 28
	l.Brightness = brightness or 1
	l.Shadows = false
	l.Parent = parent
	return l
end

---------------------------------------------------------------------
-- Building parts
---------------------------------------------------------------------

-- A window: glass with a navy frame and mullions. `cf` is the window center, facing -Z.
local function window(parent, cf, width, height, cols, rows, glassTransparency, glassColor)
	deco(parent, "Glass", Vector3.new(width, height, 0.2), cf, glassColor or GLASS, Enum.Material.Glass, { Transparency = glassTransparency or 0.4, Reflectance = 0.2 })
	-- slim aluminium storefront frames (thin profiles read as a real, modern building)
	local t = 0.2
	local FRAME = Color3.fromRGB(58, 62, 70)
	deco(parent, "Frame", Vector3.new(width + t, t, 0.3), cf * CFrame.new(0, height / 2, 0), FRAME, Enum.Material.Metal)
	deco(parent, "Frame", Vector3.new(width + t, t, 0.3), cf * CFrame.new(0, -height / 2, 0), FRAME, Enum.Material.Metal)
	deco(parent, "Frame", Vector3.new(t, height + t, 0.3), cf * CFrame.new(-width / 2, 0, 0), FRAME, Enum.Material.Metal)
	deco(parent, "Frame", Vector3.new(t, height + t, 0.3), cf * CFrame.new(width / 2, 0, 0), FRAME, Enum.Material.Metal)
	for c = 1, cols - 1 do
		deco(parent, "Mullion", Vector3.new(0.12, height, 0.24), cf * CFrame.new(-width / 2 + c * width / cols, 0, 0), FRAME, Enum.Material.Metal)
	end
	for r = 1, rows - 1 do
		deco(parent, "Mullion", Vector3.new(width, 0.12, 0.24), cf * CFrame.new(0, -height / 2 + r * height / rows, 0), FRAME, Enum.Material.Metal)
	end
end

local function lowPolyTree(parent, pos, scale)
	scale = scale or 1
	local name = Props.Pick({ "RealTree2", "RealTree2", "RealPine" }, rng)
	if name and Props.Place(name, parent, CFrame.new(pos) * CFrame.Angles(0, rng:NextNumber(0, 6.28), 0), { Height = (name == "RealPine" and 24 or 20) * scale, Ground = true }) then
		return
	end
	local trunkColor = Color3.fromRGB(120, 78, 52)
	local h = 7 * scale
	local lean = rng:NextNumber(-0.12, 0.12)
	deco(parent, "Trunk", Vector3.new(1.1 * scale, h, 1.1 * scale), CFrame.new(pos + Vector3.new(0, h / 2, 0)) * CFrame.Angles(lean, rng:NextNumber(0, 6), 0), trunkColor)
	deco(parent, "Branch", Vector3.new(0.7 * scale, 3 * scale, 0.7 * scale), CFrame.new(pos + Vector3.new(0.8 * scale, h * 0.75, 0)) * CFrame.Angles(0, 0, math.rad(-35)), trunkColor)
	local top = pos + Vector3.new(0, h + 1.2 * scale, 0)
	local pieces = {
		{ Vector3.new(0, 0, 0), 6.2 },
		{ Vector3.new(2.3, -0.8, 0.8), 4.2 },
		{ Vector3.new(-2.1, -0.6, -0.9), 4.4 },
		{ Vector3.new(0.4, 2, -0.4), 4 },
		{ Vector3.new(-0.6, -0.4, 2.2), 3.6 },
	}
	for _, pc in ipairs(pieces) do
		local s = pc[2] * scale
		local color = LEAF[rng:NextInteger(1, #LEAF)]
		deco(parent, "Leaves", Vector3.new(s, s * 0.85, s), CFrame.new(top + pc[1] * scale) * CFrame.Angles(rng:NextNumber(-0.5, 0.5), rng:NextNumber(0, 6.28), rng:NextNumber(-0.5, 0.5)), color)
	end
end

local function cypress(parent, pos, height)
	height = height or 6
	local green = Color3.fromRGB(58, 92, 46)
	column(parent, "Cypress", height, 2.2, CFrame.new(pos + Vector3.new(0, height / 2 + 0.6, 0)), green, Enum.Material.LeafyGrass)
	ball(parent, "CypressTop", 2.2, CFrame.new(pos + Vector3.new(0, height + 0.6, 0)), green, Enum.Material.LeafyGrass)
	ball(parent, "CypressBottom", 2.2, CFrame.new(pos + Vector3.new(0, 0.6 + 1.1, 0)), green, Enum.Material.LeafyGrass)
end

local function planter(parent, cf, length, withCypress)
	box(parent, "Planter", Vector3.new(length, 1.6, 2.4), cf * CFrame.new(0, 0.8, 0), NAVY)
	deco(parent, "Soil", Vector3.new(length - 0.4, 0.1, 2), cf * CFrame.new(0, 1.62, 0), Color3.fromRGB(80, 60, 45))
	local n = math.max(1, math.floor(length / 2.6))
	for i = 1, n do
		local x = -length / 2 + (i - 0.5) * length / n
		if withCypress and (i == 1 or i == n) then
			cypress(parent, (cf * CFrame.new(x, 1, 0)).Position, 5)
		elseif not Props.Place("NoSuchBush", parent, cf * CFrame.new(x, 1.6, 0) * CFrame.Angles(0, rng:NextNumber(0, 6.28), 0), { Width = 2.6 }) then
			ball(parent, "Shrub", 2.4, cf * CFrame.new(x, 2.2, 0), LEAF[rng:NextInteger(1, #LEAF)], Enum.Material.LeafyGrass)
		end
	end
end

local function streetLamp(parent, pos, facing)
	if Props.Place("StreetLamp", parent, CFrame.new(pos) * CFrame.Angles(0, facing > 0 and math.pi or 0, 0), { Height = 14, Solid = true }) then
		return
	end
	column(parent, "LampPole", 13, 0.5, CFrame.new(pos + Vector3.new(0, 6.5, 0)), NAVY, Enum.Material.Metal, true)
	deco(parent, "LampArm", Vector3.new(0.35, 0.35, 2.6), CFrame.new(pos + Vector3.new(0, 12.9, facing * 1.2)), NAVY, Enum.Material.Metal)
	local head = deco(parent, "LampHead", Vector3.new(1.3, 0.5, 1.8), CFrame.new(pos + Vector3.new(0, 12.7, facing * 2.4)), NAVY, Enum.Material.Metal)
	deco(parent, "LampBulb", Vector3.new(1.1, 0.1, 1.5), head.CFrame * CFrame.new(0, -0.28, 0), LAMP, Enum.Material.Neon)
end

local function bench(parent, cf)
	deco(parent, "BenchSeat", Vector3.new(6, 0.4, 1.8), cf * CFrame.new(0, 1.6, 0), WOOD, Enum.Material.Wood)
	deco(parent, "BenchBack", Vector3.new(6, 1.4, 0.3), cf * CFrame.new(0, 2.6, 0.8) * CFrame.Angles(math.rad(-10), 0, 0), WOOD, Enum.Material.Wood)
	for _, x in ipairs({ -2.6, 2.6 }) do
		deco(parent, "BenchLeg", Vector3.new(0.3, 1.5, 1.8), cf * CFrame.new(x, 0.75, 0), NAVY, Enum.Material.Metal)
	end
end

local function cardboardBox(parent, cf, s)
	deco(parent, "Box", Vector3.new(s, s * 0.8, s), cf, Color3.fromRGB(196, 150, 100), Enum.Material.Cardboard)
	deco(parent, "Tape", Vector3.new(0.3, s * 0.81, s * 1.01), cf, Color3.fromRGB(225, 200, 150))
end

local function truck(parent, cf, color)
	local function at(x, y, z)
		return cf * CFrame.new(x, y, z)
	end
	box(parent, "TruckCab", Vector3.new(8, 6.5, 6.5), at(0, 4.6, -11.5), color, nil, { Reflectance = 0.1 })
	deco(parent, "TruckRoof", Vector3.new(7.6, 1.2, 4), at(0, 8.4, -11), color)
	deco(parent, "TruckWindow", Vector3.new(7, 2.4, 0.2), at(0, 6.4, -14.8), Color3.fromRGB(40, 55, 80), Enum.Material.Glass, { Reflectance = 0.3 })
	deco(parent, "TruckGrille", Vector3.new(6, 2.2, 0.2), at(0, 2.8, -14.8), Color3.fromRGB(60, 60, 65), Enum.Material.Metal)
	deco(parent, "TruckBumper", Vector3.new(8.2, 0.9, 0.6), at(0, 1.5, -14.9), Color3.fromRGB(200, 200, 205), Enum.Material.Metal)
	for _, x in ipairs({ -3, 3 }) do
		deco(parent, "TruckLight", Vector3.new(1.3, 0.8, 0.2), at(x, 2.9, -14.9), Color3.fromRGB(255, 250, 225), Enum.Material.Neon)
	end
	box(parent, "TruckBed", Vector3.new(8, 1, 18), at(0, 2, 2), Color3.fromRGB(60, 60, 66), Enum.Material.DiamondPlate)
	for _, z in ipairs({ -11.5, -2, 6.5 }) do
		for _, x in ipairs({ -3.7, 3.7 }) do
			local w = part({ Name = "TruckWheel", Shape = Enum.PartType.Cylinder, Size = Vector3.new(1.2, 3, 3), CFrame = at(x, 1.5, z), Color = Color3.fromRGB(25, 25, 28), Material = Enum.Material.Rubber, CanCollide = false }, parent)
			w.Size = Vector3.new(1.2, 3, 3)
		end
	end
	local c = box(parent, "TruckContainer", Vector3.new(7.6, 7, 16), at(0, 6, 2.5), Color3.fromRGB(232, 236, 244), Enum.Material.SmoothPlastic)
	surfaceText(c, Enum.NormalId.Left, "D2D LOGISTICS", Color3.fromRGB(40, 60, 100), 20)
	surfaceText(c, Enum.NormalId.Right, "D2D LOGISTICS", Color3.fromRGB(40, 60, 100), 20)
end

---------------------------------------------------------------------
-- Light and sky
---------------------------------------------------------------------
local function buildLighting()
	LightingPresets.Apply(LightingPresets.Default)
end

---------------------------------------------------------------------
-- Layout
--   A wide boulevard runs along X at z = 0 with a planted median.
--   3 plots on the north side and 3 on the south side face each other across it.
--   Plot-local frame: origin at the plot's front edge (by the sidewalk), +Z goes away from the road.
--   Showroom in front (grows toward the road), container lot behind it, truck backed into the lot.
---------------------------------------------------------------------
local ROAD_HALF = 18 -- road from z -18 to 18
local SIDEWALK = 8
local PLOT_FRONT = ROAD_HALF + SIDEWALK -- plot front edge at |z| = 26
local PLOT_DEPTH = 206
-- turn (radians) that makes each store prop face -Z (toward the showroom front); set after looking at them in Studio
-- turn that makes each town model face the road (set after looking at them in Studio)
local TOWN_FRONT = {
	ShopA = 0,
	ShopB = 0,
	ShopC = math.pi,
	HouseA = 0,
	HouseB = math.pi,
	GasStation = 0,
	Warehouse = 0,
	BusStop = 0,
	TrafficLight = 0,
}
local PROP_FRONT = {
	Workbench = 0,
	ToolCabinet = 0,
	TireRack = 0,
	Compressor = 0,
	OilDrum = 0,
	GarageShelf = 0,
	ShowroomDesk = 0,
	Plant = 0,
	DeliveryTruck = 0,
	CarWashBay = 0,
	WashMachine = 0,
	PressureWasher = 0,
	HoseReel = 0,
	Bucket = 0,
	TireShop = 0,
	ChainFence = 0,
	Dumpster = 0,
	Pallets = 0,
	RoofAC = 0,
	Awning = 0,
	DealerFlags = 0,
	TubeMan = 0,
	ConcretePlanter = 0,
	TrafficBarrier = 0,
	Bollard = 0,
	WoodCrate = 0,
	Barrier = 0,
	CarLift = math.pi / 2,
}
local NORTH_X = { -180, 30, 240 }

local function plotFrame(index)
	if index <= 3 then
		return CFrame.new(NORTH_X[index], 0, PLOT_FRONT)
	end
	-- south side: turned around and shifted so the showrooms sit exactly opposite each other
	return CFrame.new(NORTH_X[index - 3], 0, -PLOT_FRONT) * CFrame.Angles(0, math.pi, 0)
end

---------------------------------------------------------------------
-- Terrain: grass ground, terraced blue cliffs around the town
---------------------------------------------------------------------
local function buildTerrain(map)
	-- real Roblox terrain: grass with grass blades, soft rolling hills, realistic trees
	local terrain = workspace.Terrain
	terrain:Clear()
	pcall(function()
		terrain.Decoration = true
	end)
	terrain:SetMaterialColor(Enum.Material.Grass, Color3.fromRGB(86, 108, 56))
	terrain:SetMaterialColor(Enum.Material.Ground, Color3.fromRGB(102, 92, 76))
	terrain:SetMaterialColor(Enum.Material.Asphalt, Color3.fromRGB(70, 70, 74))
	-- smooth terrain samples voxel centres, so a fill that ends at y = -2 gives a surface at about y = 0
	terrain:FillBlock(CFrame.new(0, -6, 0), Vector3.new(1800, 8, 1400), Enum.Material.Grass)
	-- no grass blades under the thin paved parts (roads, the lot, the walk) - they would poke through
	local function paved(cx, cz, sx, sz)
		terrain:FillBlock(CFrame.new(cx, -4, cz), Vector3.new(sx, 4, sz), Enum.Material.Ground)
	end
	paved(0, 0, 800, 2 * (PLOT_FRONT + 1))
	for _, sz in ipairs({ -1, 1 }) do
		paved(0, sz * (PLOT_FRONT + PLOT_DEPTH + 10), 800, 20)
		for _, x in ipairs(NORTH_X) do
			-- the container lot and the walk from the sidewalk to the garage
			paved(x, sz * (PLOT_FRONT + 165), 128, 86)
			paved(x, sz * (PLOT_FRONT + 62), 14, 126)
		end
	end
	-- rolling hills beyond the town: overlapping terrain domes with trees on top
	local function hill(x, z, r)
		terrain:FillBall(Vector3.new(x, -2 - 0.45 * r, z), r, Enum.Material.Grass)
		local count = math.floor(r / 30)
		for _ = 1, count do
			local a = rng:NextNumber(0, math.pi * 2)
			local d = rng:NextNumber(0, r * 0.6)
			local px, pz = x + math.cos(a) * d, z + math.sin(a) * d
			local h = math.sqrt(math.max(0, r * r - d * d)) - 0.45 * r - 2
			if h > 2 then
				local name = rng:NextNumber() < 0.6 and "RealTree2" or "RealPine"
				Props.Place(name, map, CFrame.new(px, h, pz) * CFrame.Angles(0, rng:NextNumber(0, 6.28), 0), { Height = rng:NextNumber(20, 30), Ground = true })
			end
		end
	end
	for _, sz in ipairs({ -1, 1 }) do
		for x = -700, 700, 85 do
			hill(x + rng:NextNumber(-25, 25), sz * rng:NextNumber(330, 360), rng:NextNumber(38, 55))
			hill(x + 40 + rng:NextNumber(-25, 25), sz * rng:NextNumber(430, 480), rng:NextNumber(55, 80))
		end
	end
	for _, sx in ipairs({ -1, 1 }) do
		for z = -320, 320, 80 do
			hill(sx * rng:NextNumber(450, 490), z + rng:NextNumber(-20, 20), rng:NextNumber(40, 58))
			hill(sx * rng:NextNumber(570, 620), z + 40 + rng:NextNumber(-20, 20), rng:NextNumber(55, 80))
		end
	end
end

---------------------------------------------------------------------
-- Boulevard, sidewalks, back service roads, scenery
---------------------------------------------------------------------
local function buildWorld(map)
	local baseplate = workspace:FindFirstChild("Baseplate")
	if baseplate then
		baseplate:Destroy()
	end
	buildTerrain(map)
	local LEN = 760
	-- two carriageways with a planted median
	for _, sz in ipairs({ -1, 1 }) do
		box(map, "Road", Vector3.new(LEN, 0.4, 14), CFrame.new(0, 0.2, sz * 10), ASPHALT, Enum.Material.Asphalt)
		for x = -LEN / 2 + 6, LEN / 2 - 6, 16 do
			deco(map, "LaneLine", Vector3.new(7, 0.05, 0.45), CFrame.new(x, 0.42, sz * 10), Color3.fromRGB(245, 245, 245))
		end
		deco(map, "EdgeLine", Vector3.new(LEN, 0.05, 0.35), CFrame.new(0, 0.42, sz * 16.6), Color3.fromRGB(245, 245, 245))
		box(map, "Curb", Vector3.new(LEN, 0.8, 0.8), CFrame.new(0, 0.4, sz * (ROAD_HALF - 0.4)), Color3.fromRGB(205, 205, 210), Enum.Material.Concrete)
		box(map, "Sidewalk", Vector3.new(LEN, 0.6, SIDEWALK), CFrame.new(0, 0.3, sz * (ROAD_HALF + SIDEWALK / 2)), CONCRETE, Enum.Material.Concrete)
		-- back service road behind the yards
		local backZ = sz * (PLOT_FRONT + PLOT_DEPTH + 10)
		box(map, "ServiceRoad", Vector3.new(LEN, 0.4, 16), CFrame.new(0, 0.2, backZ), ASPHALT, Enum.Material.Asphalt)
		for x = -LEN / 2 + 6, LEN / 2 - 6, 16 do
			deco(map, "LaneLine", Vector3.new(7, 0.05, 0.45), CFrame.new(x, 0.42, backZ), Color3.fromRGB(245, 210, 70))
		end
		-- street lamps and trees along the sidewalk
		for x = -LEN / 2 + 40, LEN / 2 - 40, 90 do
			streetLamp(map, Vector3.new(x, 0.6, sz * (ROAD_HALF + 1.5)), -sz)
		end
	end
	-- median: grass strip with trees, shrubs and lamps
	box(map, "Median", Vector3.new(LEN, 0.7, 6), CFrame.new(0, 0.35, 0), Color3.fromRGB(205, 205, 210), Enum.Material.Concrete)
	deco(map, "MedianGrass", Vector3.new(LEN - 1, 0.1, 5), CFrame.new(0, 0.75, 0), Color3.fromRGB(92, 118, 60), Enum.Material.Grass)
	for x = -LEN / 2 + 30, LEN / 2 - 30, 140 do
		lowPolyTree(map, Vector3.new(x, 0.7, 0), 0.8)
	end
	-- crosswalks between facing plots
	for _, x in ipairs(NORTH_X) do
		for s = -5, 5, 2 do
			deco(map, "Crosswalk", Vector3.new(1.2, 0.05, 32), CFrame.new(x + s, 0.43, 0), Color3.fromRGB(245, 245, 245))
		end
	end
	-- the town around the plots: real store buildings in the gaps between plots and at the ends
	local TOWN = {
		{ "ShopA", -75, 1 }, { "HouseB", 135, 1 }, { "GasStation", -320, 1 }, { "HouseB", 335, 1 },
		{ "HouseB", -75, -1 }, { "ShopA", 135, -1 }, { "HouseB", -320, -1 }, { "GasStation", 335, -1 },
	}
	for _, b in ipairs(TOWN) do
		local name, x, sz = b[1], b[2], b[3]
		local width = (math.abs(x) > 300) and 64 or 56
		local cf = CFrame.new(x, 0, sz * (PLOT_FRONT + 40)) * CFrame.Angles(0, (sz > 0 and math.pi or 0) + (TOWN_FRONT[name] or 0), 0)
		Props.Place(name, map, cf, { Width = width, Solid = true })
	end
	-- a fire hydrant here and there on the sidewalk (not too many)
	for _, sz in ipairs({ -1, 1 }) do
		for _, x in ipairs({ -110, 100 }) do
			Props.Place("FireHydrant", map, CFrame.new(x, 0.6, sz * (ROAD_HALF + 2)), { Height = 2.4 })
		end
	end
	-- trees between the plots and on the edges
	for _, sz in ipairs({ -1, 1 }) do
		for x = -370, 370, 90 do
			lowPolyTree(map, Vector3.new(x + rng:NextNumber(-6, 6), 0, sz * (PLOT_FRONT + PLOT_DEPTH + 32 + rng:NextNumber(0, 12))), rng:NextNumber(1, 1.4))
		end
	end
	-- invisible walls around the play area
	for _, w in ipairs({
		{ Vector3.new(4, 120, 640), Vector3.new(-385, 60, 0) },
		{ Vector3.new(4, 120, 640), Vector3.new(385, 60, 0) },
		{ Vector3.new(780, 120, 4), Vector3.new(0, 60, -270) },
		{ Vector3.new(780, 120, 4), Vector3.new(0, 60, 270) },
	}) do
		box(map, "Boundary", w[1], CFrame.new(w[2]), Color3.new(1, 1, 1), nil, { Transparency = 1, CanQuery = false })
	end
	local spawn = Instance.new("SpawnLocation")
	spawn.Anchored = true
	spawn.Size = Vector3.new(8, 1, 8)
	spawn.CFrame = CFrame.new(0, 0.5, 22)
	spawn.Transparency = 1
	spawn.CanCollide = false
	spawn.Duration = 0
	spawn.Parent = map
end

---------------------------------------------------------------------
-- One plot
---------------------------------------------------------------------
local function buildPlot(index, parent)
	local plotCF = plotFrame(index)
	local m = Instance.new("Model")
	m.Name = "Plot" .. index
	m.Parent = parent
	local function at(x, y, z)
		return plotCF * CFrame.new(x, y, z)
	end
	local function v(x, y, z)
		return at(x, y, z).Position
	end
	local plot = { Index = index, Model = m, Frame = plotCF }

	-- Layout (plot-local): road side at z = 0. The showroom's back wall is fixed at ZB and it grows
	-- toward the road. Through an open doorway in the back wall you walk straight into the
	-- container lot; the delivery truck is backed into the far end of the lot.
	local ZB = 124
	local LOT_Z0, LOT_Z1, LOT_HALF = ZB + 2, PLOT_DEPTH - 2, 62

	-- a plain path from the sidewalk to the showroom
	deco(m, "Walk", Vector3.new(12, 0.2, ZB), at(0, 0.1, ZB / 2), CONCRETE, Enum.Material.Pavement)
	-- the front lawn: clipped hedges along the plot edges, trees along the path, shrubs by the building
	local HEDGE = Color3.fromRGB(54, 82, 44)
	for _, side in ipairs({ -1, 1 }) do
		box(m, "Hedge", Vector3.new(2.2, 3, ZB - 8), at(side * (LOT_HALF - 1), 1.5, 4 + (ZB - 8) / 2), HEDGE, Enum.Material.LeafyGrass)
	end

	--=========================== SHOWROOM (rebuilt per level) ===========================
	local showroomModel = nil
	local signText = "FOR SALE"
	local signLabels = {}
	local function applySign()
		for _, l in ipairs(signLabels) do
			if l.Parent then
				l.Text = signText
			end
		end
	end
	function plot.SetSign(text)
		signText = text
		applySign()
	end

	-- the roll-up door of the one-car garage: slats roll up into the top when it opens
	plot.DoorOpen = false
	function plot.SetDoor(open, animate)
		plot.DoorOpen = open
		for i, sl in ipairs(plot.DoorSlats or {}) do
			local p = sl.Part
			if p.Parent then
				local goal = open and { CFrame = sl.Open, Transparency = 1 } or { CFrame = sl.Closed, Transparency = 0 }
				p.CanCollide = not open
				if animate then
					TweenService:Create(p, TweenInfo.new(0.5 + i * 0.05, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut), goal):Play()
				else
					p.CFrame = goal.CFrame
					p.Transparency = goal.Transparency
				end
			end
		end
	end

	function plot.BuildShowroom(level)
		level = math.clamp(level or 1, 1, Config.MaxShowroomLevel)
		if showroomModel then
			showroomModel:Destroy()
		end
		table.clear(signLabels)
		local sm = Instance.new("Model")
		sm.Name = "Showroom"
		sm.Parent = m
		showroomModel = sm
		-- level 1 is a small one-car garage; then the cars line both walls
		local spotCount = Config.GetSpots(level)
		local single = spotCount == 1
		local perSide = math.ceil(spotCount / 2)
		local W = single and 28 or (42 + 8 * (level - 1))
		local D = single and 30 or (24 + 10 * perSide)
		local H = level == 1 and 11 or (14 + 2 * (level - 2))
		local WT = 0.6 -- wall thickness: thin walls, not bulky blocks
		local garage = level == 1
		local Z0 = ZB - D
		local function s(x, y, z)
			return at(x, y, Z0 + z)
		end
		-- every showroom level has its own style: street garage -> workshop -> dealership -> luxury -> future
		local THEMES = {
			{ Name = "street", WallMat = Enum.Material.Brick, FloorMat = Enum.Material.Concrete, RoofMat = Enum.Material.Concrete, Wall = Color3.fromRGB(150, 92, 74), Floor = Color3.fromRGB(92, 94, 100), Trim = Color3.fromRGB(46, 48, 56), Ceiling = Color3.fromRGB(150, 150, 154), Light = Color3.fromRGB(255, 236, 210), Front = Color3.fromRGB(150, 92, 74) },
			{ Name = "workshop", WallMat = Enum.Material.Concrete, FloorMat = Enum.Material.Concrete, RoofMat = Enum.Material.Concrete, Wall = Color3.fromRGB(196, 198, 202), Floor = Color3.fromRGB(110, 120, 134), Trim = Color3.fromRGB(40, 90, 170), Ceiling = Color3.fromRGB(200, 202, 208), Light = LAMP, Front = Color3.fromRGB(196, 198, 202) },
			{ Name = "dealer", FloorMat = Enum.Material.Marble, RoofMat = Enum.Material.Concrete, Wall = PLASTER, Floor = TILE, Trim = NAVY, Ceiling = Color3.fromRGB(226, 226, 230), Light = LAMP, Front = PLASTER },
			{ Name = "luxury", WallMat = Enum.Material.WoodPlanks, FloorMat = Enum.Material.Marble, RoofMat = Enum.Material.Concrete, Wall = Color3.fromRGB(120, 80, 56), Floor = Color3.fromRGB(44, 42, 48), Trim = Color3.fromRGB(222, 180, 90), Ceiling = Color3.fromRGB(236, 226, 210), Light = Color3.fromRGB(255, 226, 170), Front = Color3.fromRGB(70, 52, 44) },
			{ Name = "future", Wall = Color3.fromRGB(214, 220, 232), Floor = Color3.fromRGB(70, 78, 94), Trim = Color3.fromRGB(40, 220, 255), Ceiling = Color3.fromRGB(240, 244, 250), Light = Color3.fromRGB(190, 245, 255), Front = Color3.fromRGB(232, 236, 244) },
		}
		local theme = THEMES[level]
		-- the lot behind follows the same style
		local LOT = { Color3.fromRGB(64, 64, 68), Color3.fromRGB(80, 84, 92), ASPHALT, Color3.fromRGB(44, 44, 50), Color3.fromRGB(176, 184, 198) }
		if plot.LotPart then
			plot.LotPart.Color = LOT[level]
			for _, f in ipairs(plot.FenceParts) do
				f.Color = theme.Name == "street" and Color3.fromRGB(70, 78, 96) or theme.Trim
				f.Material = theme.Name == "future" and Enum.Material.Neon or Enum.Material.SmoothPlastic
			end
		end
		local wallColor = theme.Wall
		local trim = theme.Trim

		-- no grass blades under the floor (they would poke through it)
		do
			local c = s(0, 0, D / 2)
			workspace.Terrain:FillBlock(CFrame.new(c.X, -4, c.Z) * c.Rotation, Vector3.new(W + 3, 4, D + 3), Enum.Material.Ground)
		end
		-- floor, walls, roof
		local wallMat = theme.WallMat
		box(sm, "Floor", Vector3.new(W, FLOOR_Y, D), s(0, FLOOR_Y / 2, D / 2), theme.Floor, theme.FloorMat, { Reflectance = theme.Name == "luxury" and 0.08 or 0 })
		for _, side in ipairs({ -1, 1 }) do
			box(sm, "Wall", Vector3.new(WT, H, D), s(side * W / 2, FLOOR_Y + H / 2, D / 2), wallColor, wallMat)
		end
		box(sm, "Roof", Vector3.new(W + WT, 0.4, D + WT), s(0, FLOOR_Y + H + 0.2, D / 2), Color3.fromRGB(84, 88, 98), theme.RoofMat)
		-- a thin metal coping along the roof edge
		for _, side in ipairs({ -1, 1 }) do
			deco(sm, "Coping", Vector3.new(0.3, 0.5, D + WT), s(side * (W / 2 + 0.15), FLOOR_Y + H + 0.45, D / 2), trim, Enum.Material.Metal)
		end
		deco(sm, "Coping", Vector3.new(W + WT, 0.5, 0.3), s(0, FLOOR_Y + H + 0.45, D + 0.15), trim, Enum.Material.Metal)
		deco(sm, "Ceiling", Vector3.new(W - 1.2, 0.4, D - 1.2), s(0, FLOOR_Y + H - 0.2, D / 2), theme.Ceiling)

		-- back wall with a wide open doorway into the lot
		local backDoor = single and 12 or 18
		local backH = math.min(10, H - 1.5)
		local bw = (W - backDoor) / 2
		for _, side in ipairs({ -1, 1 }) do
			box(sm, "BackWall", Vector3.new(bw, H, WT), s(side * (backDoor / 2 + bw / 2), FLOOR_Y + H / 2, D), wallColor, wallMat)
		end
		box(sm, "BackHeader", Vector3.new(backDoor, H - backH, WT), s(0, FLOOR_Y + backH + (H - backH) / 2, D), wallColor, wallMat)
		local lotSign = box(sm, "LotSign", Vector3.new(math.min(backDoor - 2, 12), 1.1, 0.15), s(0, FLOOR_Y + backH + 0.75, D - WT / 2 - 0.1), trim)
		surfaceText(lotSign, Enum.NormalId.Front, "CONTAINER LOT", Color3.new(1, 1, 1), 24)

		-- front: a wide door with the sign above it
		local doorW = garage and 16 or 16
		local doorH = garage and 8.5 or 10
		local sideW = (W - doorW) / 2
		for _, side in ipairs({ -1, 1 }) do
			if garage then
				box(sm, "Front", Vector3.new(sideW, H, WT), s(side * (doorW / 2 + sideW / 2), FLOOR_Y + H / 2, 0), wallColor, wallMat)
			else
				box(sm, "FrontPier", Vector3.new(0.7, H, 0.7), s(side * (W / 2 - 0.05), FLOOR_Y + H / 2, 0), theme.Front)
				box(sm, "DoorPier", Vector3.new(0.5, doorH, 0.5), s(side * (doorW / 2 + 0.25), FLOOR_Y + doorH / 2, 0), theme.Front)
				window(sm, s(side * (doorW / 2 + sideW / 2), FLOOR_Y + doorH / 2, 0), sideW - 1.4, doorH, 3, 1, 0.55)
			end
		end
		box(sm, "Header", Vector3.new(W - (garage and 0 or 1.4), H - doorH, WT), s(0, FLOOR_Y + doorH + (H - doorH) / 2, 0), theme.Front, garage and wallMat or nil)
		-- the sign: slim letters board on the header, not a bulky band
		local signBoard = box(sm, "SignBoard", Vector3.new(math.min(W - 6, 30), math.min(1.8, H - doorH - 0.6), 0.15), s(0, FLOOR_Y + doorH + (H - doorH) / 2, -WT / 2 - 0.08), trim)
		table.insert(signLabels, surfaceText(signBoard, Enum.NormalId.Front, signText, GOLD, 26))

		-- one-car garage: a corrugated roll-up door that opens when the player claims the garage
		plot.DoorSlats = {}
		plot.DoorPrompt = nil
		if garage then
			local slatH = 0.85
			local n = math.ceil(doorH / slatH)
			for i = 1, n do
				local y = FLOOR_Y + (i - 0.5) * slatH
				local slat = box(sm, "DoorSlat", Vector3.new(doorW, slatH - 0.06, 0.18), s(0, y, -0.05), Color3.fromRGB(196, 200, 206), Enum.Material.Metal)
				table.insert(plot.DoorSlats, { Part = slat, Closed = slat.CFrame, Open = s(0, FLOOR_Y + doorH - 0.3, -0.05) })
			end
			plot.DoorPrompt = deco(sm, "DoorPrompt", Vector3.new(2, 2, 0.2), s(0, FLOOR_Y + 3, -0.6), Color3.new(1, 1, 1), nil, { Transparency = 1 })
			plot.SetDoor(plot.DoorOpen == true, false)
		end

		-- a few soft ceiling lights
		local k = 0
		for z = 10, D - 8, 16 do
			k = k + 1
			-- interiors need their own light (the sun can't reach in): soft ceiling panels that light the
			-- floor and the cars evenly, with real shadows under the cars - like a real dealership
			for _, x in ipairs(W > 34 and { -W / 4, W / 4 } or { 0 }) do
				local l = deco(sm, "CeilingLight", Vector3.new(6, 0.12, 2), s(x, FLOOR_Y + H - 0.45, z), theme.Light, Enum.Material.Neon)
				local sl = Instance.new("SurfaceLight")
				sl.Face = Enum.NormalId.Bottom
				sl.Angle = 150
				sl.Range = math.max(18, H + 8)
				sl.Brightness = (theme.Name == "street" or theme.Name == "workshop") and 0.9 or 1.1
				sl.Color = theme.Light
				sl.Shadows = true
				sl.Parent = l
			end
		end

		-- style details for each level
		local function decal(id, size, cf, face)
			local panelPart = deco(sm, "Art", size, cf, Color3.new(1, 1, 1), nil, { Transparency = 1 })
			local d = Instance.new("Decal")
			d.Texture = "rbxassetid://" .. id
			d.Face = face
			d.Parent = panelPart
			return panelPart
		end
		local GRAFFITI = { "94240820734263", "131777455527155", "70627886445938" }
		if theme.Name == "street" then
			-- spray-painted walls inside and out, bare warm bulbs
			for i, side in ipairs({ -1, 1 }) do
				for k2, z in ipairs({ D * 0.3, D * 0.7 }) do
					local id = GRAFFITI[(i + k2) % #GRAFFITI + 1]
					decal(id, Vector3.new(0.1, 5, 8.5), s(side * (W / 2 - 0.4), FLOOR_Y + 5, z), side < 0 and Enum.NormalId.Right or Enum.NormalId.Left)
				end
			end
			local sw = (W - doorW) / 2
			if sw >= 5 then
				decal(GRAFFITI[1], Vector3.new(sw - 1.2, 4.5, 0.1), s(-(doorW / 2 + sw / 2), FLOOR_Y + 4.5, -0.4), Enum.NormalId.Front)
				decal(GRAFFITI[3], Vector3.new(sw - 1.2, 4.5, 0.1), s(doorW / 2 + sw / 2, FLOOR_Y + 4.5, -0.4), Enum.NormalId.Front)
			end
			decal(GRAFFITI[2], Vector3.new(12, 6, 0.1), s(-W / 2 - 0.4, FLOOR_Y + 4.5, D * 0.5) * CFrame.Angles(0, math.rad(90), 0), Enum.NormalId.Front)
		elseif theme.Name == "workshop" then
			-- yellow safety lines and a blue stripe along the walls
			for _, side in ipairs({ -1, 1 }) do
				deco(sm, "SafetyLine", Vector3.new(0.5, 0.04, D - 4), s(side * (W / 2 - 4), FLOOR_Y + 0.02, D / 2), Color3.fromRGB(250, 200, 40))
				deco(sm, "WallStripe", Vector3.new(0.2, 1.2, D - 2), s(side * (W / 2 - 0.65), FLOOR_Y + 4, D / 2), trim)
			end
		elseif theme.Name == "luxury" then
			-- gold trim lines, warm light
			for _, side in ipairs({ -1, 1 }) do
				deco(sm, "GoldTrim", Vector3.new(0.2, 0.3, D - 2), s(side * (W / 2 - 0.65), FLOOR_Y + H - 2, D / 2), trim, Enum.Material.Neon)
				deco(sm, "GoldBase", Vector3.new(0.3, 0.5, D - 2), s(side * (W / 2 - 0.7), FLOOR_Y + 0.25, D / 2), trim)
			end
			deco(sm, "Carpet", Vector3.new(8, 0.05, D - 6), s(0, FLOOR_Y + 0.03, D / 2), Color3.fromRGB(120, 24, 36))
		elseif theme.Name == "future" then
			-- glowing cyan lines on the floor edges and ceiling, floor grid
			for _, side in ipairs({ -1, 1 }) do
				deco(sm, "NeonEdge", Vector3.new(0.3, 0.06, D - 2), s(side * (W / 2 - 1.2), FLOOR_Y + 0.03, D / 2), trim, Enum.Material.Neon)
				deco(sm, "NeonCeil", Vector3.new(0.3, 0.2, D - 2), s(side * (W / 2 - 1.2), FLOOR_Y + H - 0.5, D / 2), trim, Enum.Material.Neon)
			end
			deco(sm, "RoofGlow", Vector3.new(W + 1.8, 0.4, 0.4), s(0, FLOOR_Y + H + 1, -0.9), trim, Enum.Material.Neon)
			for _, side in ipairs({ -1, 1 }) do
				deco(sm, "CornerGlow", Vector3.new(0.4, H, 0.4), s(side * (W / 2 + 0.9), FLOOR_Y + H / 2, -0.9), trim, Enum.Material.Neon)
			end
			for z = 12, D - 6, 12 do
				deco(sm, "GridLine", Vector3.new(W - 4, 0.04, 0.12), s(0, FLOOR_Y + 0.02, z), Color3.fromRGB(150, 230, 255), Enum.Material.Neon)
			end
		end

		-- real Creator Store furniture in the free corners behind the last cars (never in the aisle)
		-- footprint of a model in the showroom's own frame (x across, z from front to back)
		local frame = s(0, 0, 0)
		local function footprint(model)
			local minX, maxX, minZ, maxZ = math.huge, -math.huge, math.huge, -math.huge
			for _, p in ipairs(model:GetDescendants()) do
				if p:IsA("BasePart") and p.Transparency < 1 then
					local h = p.Size / 2
					for _, cx in ipairs({ -1, 1 }) do
						for _, cz in ipairs({ -1, 1 }) do
							for _, cy in ipairs({ -1, 1 }) do
								local w = frame:PointToObjectSpace(p.CFrame:PointToWorldSpace(Vector3.new(cx * h.X, cy * h.Y, cz * h.Z)))
								minX, maxX = math.min(minX, w.X), math.max(maxX, w.X)
								minZ, maxZ = math.min(minZ, w.Z), math.max(maxZ, w.Z)
							end
						end
					end
				end
			end
			return minX, maxX, minZ, maxZ
		end
		local inX = W / 2 - WT / 2 - 0.12 -- inner face of the side walls
		local inZ = D - WT / 2 - 0.12 -- inner face of the back wall
		-- place a store prop and make sure it sits fully inside the room: against its wall when it
		-- has one (long side along that wall), never poking through a wall
		local function furnish(name, x, z, faceYaw, opts, wall)
			local turn = PROP_FRONT[name] or 0
			local m0 = Props.Place(name, sm, s(x, FLOOR_Y, z) * CFrame.Angles(0, faceYaw + turn, 0), opts)
			if not m0 then
				return nil
			end
			local x0, x1, z0, z1 = footprint(m0)
			local alongZ = wall == "left" or wall == "right"
			if wall and ((alongZ and (x1 - x0) > (z1 - z0)) or (not alongZ and (z1 - z0) > (x1 - x0))) then
				m0:PivotTo(m0:GetPivot() * CFrame.Angles(0, math.pi / 2, 0))
				x0, x1, z0, z1 = footprint(m0)
			end
			local dx, dz = 0, 0
			if wall == "left" then
				dx = -inX - x0
			elseif wall == "right" then
				dx = inX - x1
			elseif wall == "back" then
				dz = inZ - z1
			end
			-- then clamp inside all walls
			if x0 + dx < -inX then
				dx = -inX - x0
			elseif x1 + dx > inX then
				dx = inX - x1
			end
			if z1 + dz > inZ then
				dz = inZ - z1
			elseif z0 + dz < 0.4 then
				dz = 0.4 - z0
			end
			if dx ~= 0 or dz ~= 0 then
				m0:PivotTo(m0:GetPivot() + frame:VectorToWorldSpace(Vector3.new(dx, 0, dz)))
			end
			return m0
		end
		local backZ = D - 0.8 -- just inside the back wall
		local cornerX = W / 2 - 1 -- just inside the side walls
		local FACE_FRONT, FACE_RIGHT, FACE_LEFT = 0, -math.pi / 2, math.pi / 2
		if single then
			-- one-car garage: workbench and tool cabinet on the left wall, tyres and compressor on the right
			furnish("Workbench", -(W / 2 - 1.8), D * 0.45, FACE_RIGHT, { Width = 6.5 }, "left")
			furnish("ToolCabinet", -(W / 2 - 1.5), D - 4.5, FACE_RIGHT, { Height = 4 }, "left")
			furnish("TireRack", W / 2 - 1.6, D * 0.42, FACE_LEFT, { Width = 6 }, "right")
			furnish("Compressor", W / 2 - 1.8, D - 4.5, FACE_LEFT, { Height = 3.2 }, "right")
			furnish("OilDrum", W / 2 - 1.6, 3.5, 0.4, { Height = 3 }, "right")
		elseif theme.Name == "street" or theme.Name == "workshop" then
			-- left corner: workbench on the back wall, tool cabinet on the side wall
			furnish("Workbench", -(backDoor / 2 + 5.5), backZ - 1.6, FACE_FRONT, { Width = 7.5 }, "back")
			furnish("ToolCabinet", -(cornerX - 1.6), backZ - 6.5, FACE_RIGHT, { Height = 4.4 }, "left")
			-- right corner: tyre rack, compressor and oil drums
			furnish("TireRack", backDoor / 2 + 5.5, backZ - 1.4, FACE_FRONT, { Width = 7 }, "back")
			furnish("Compressor", cornerX - 1.8, backZ - 6, FACE_LEFT, { Height = 3.4 }, "right")
			furnish("OilDrum", cornerX - 1.4, backZ - 9.2, 0.4, { Height = 3 }, "right")
			if theme.Name == "workshop" then
				furnish("GarageShelf", -(cornerX - 1.2), backZ - 11, FACE_RIGHT, { Height = 7 }, "left")
				furnish("OilDrum", cornerX - 3.6, backZ - 9.6, 1.3, { Height = 3 })
			end
		else
			-- dealership: a sales desk with plants, and plants by the entrance
			furnish("ShowroomDesk", -(backDoor / 2 + 6), backZ - 3.2, FACE_FRONT, { Width = 8 })
			furnish("Plant", -(cornerX - 1.6), backZ - 1.6, 0, { Height = 5.5 }, "back")
			furnish("Plant", backDoor / 2 + 2, backZ - 1.6, 1, { Height = 5.5 }, "back")
			for _, side in ipairs({ -1, 1 }) do
				furnish("Plant", side * (doorW / 2 + 2.4), 3.2, side, { Height = 5 })
			end
		end

		-- the front lawn in front of this level's building: trees along the path
		local lawn = Random.new(index * 31 + level)
		for z = 14, Z0 - 14, 36 do
			for _, side in ipairs({ -1, 1 }) do
				Props.Place(lawn:NextNumber() < 0.75 and "RealTree2" or "RealPine", sm, at(side * 12, 0, z) * CFrame.Angles(0, lawn:NextNumber(0, 6.28), 0), { Height = lawn:NextNumber(17, 22), Ground = true })
			end
		end

		-- outside: real store pieces that grow with the business (street garage -> dealership)
		local function outside(name, x, y, z, faceYaw, opts)
			local turn = PROP_FRONT[name] or 0
			return Props.Place(name, sm, s(x, y, z) * CFrame.Angles(0, faceYaw + turn, 0), opts)
		end
		local FACE_STREET = math.pi -- the front of a prop toward the road
		if level >= 2 then
			for _, side in ipairs({ -1, 1 }) do
				outside("RoofAC", side * W / 4, FLOOR_Y + H + 0.4, D * 0.62, 0, { Height = 3 })
			end
		end
		if theme.Name == "street" then
			outside("Dumpster", W / 2 + 4.5, 0, D - 7, -math.pi / 2, { Width = 7 })
			outside("Pallets", W / 2 + 3.5, 0, D - 15, 0.3, { Height = 3 })
			outside("TrafficBarrier", -(W / 2 + 3.5), 0, 6, math.pi / 2, { Width = 7 })
		elseif theme.Name == "workshop" then
			for _, side in ipairs({ -1, 1 }) do
				outside("Awning", side * (doorW / 2 + sideW / 2), FLOOR_Y + doorH - 2.6, -1.2, FACE_STREET, { Width = sideW - 3 })
				outside("Bollard", side * (doorW / 2 + 1.5), 0, -3.5, 0, { Height = 3.2 })
			end
		else
			for _, side in ipairs({ -1, 1 }) do
				outside("DealerFlags", side * (W / 2 + 3), 0, -5, FACE_STREET, { Height = 16 })
				outside("ConcretePlanter", side * (doorW / 2 + 3.5), 0, -3.5, 0, { Height = 4.5 })
			end
			if theme.Name == "dealer" then
				outside("TubeMan", -(W / 2 + 7), 0, -9, FACE_STREET, { Height = 13 })
			end
		end

		-- the showroom gets nicer with every level: real store furniture and lights
		if theme.Name == "dealer" or theme.Name == "luxury" or theme.Name == "future" then
			-- a customer lounge by the back wall: sofa, coffee table and a rug
			local lx = backDoor / 2 + 7
			furnish("XRug", lx, backZ - 6, FACE_FRONT, { Width = 8 })
			furnish("XSofa", lx, backZ - 2.2, FACE_FRONT + math.pi, { Width = 7 }, "back")
			furnish("XCoffeeTable", lx, backZ - 6, FACE_FRONT, { Width = 3.6 })
			-- framed art on the side walls between the cars
			for _, side in ipairs({ -1, 1 }) do
				for i = 1, math.max(1, perSide - 1) do
					Props.Place("XWallArt", sm, s(side * (W / 2 - WT / 2 - 0.25), FLOOR_Y + 6, 17 + (i - 1) * 10) * CFrame.Angles(0, (side < 0 and 0 or math.pi) + (PROP_FRONT.XWallArt or 0), 0), { Width = 4.5 })
				end
			end
			-- velvet rope along the entrance aisle
			for _, side in ipairs({ -1, 1 }) do
				furnish("XRopeBarrier", side * 4.2, 8, FACE_RIGHT, { Width = 4 })
			end
		end
		if theme.Name == "luxury" then
			-- crystal chandeliers down the middle
			for z = 12, D - 10, 16 do
				local ch = Props.Place("XChandelier", sm, s(0, FLOOR_Y + H - 0.5, z), { Height = 3.2 })
				if ch then
					ch:PivotTo(ch:GetPivot() * CFrame.new(0, -3.2, 0))
				end
			end
		elseif theme.Name == "future" then
			-- spotlights on the side walls aimed at the cars, and a turntable stage in the middle
			for _, side in ipairs({ -1, 1 }) do
				for i = 1, perSide do
					Props.Place("XSpotlight", sm, s(side * (W / 2 - 1.2), FLOOR_Y + H - 3, 12 + (i - 1) * 10) * CFrame.Angles(0, side < 0 and FACE_RIGHT or FACE_LEFT, 0), { Height = 1.8 })
				end
			end
			-- a glowing turntable stage in the middle of the aisle
			local stage = deco(sm, "Turntable", Vector3.new(0.5, 9, 9), s(0, FLOOR_Y + 0.25, D * 0.55) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(40, 44, 54), Enum.Material.Metal)
			stage.Shape = Enum.PartType.Cylinder
			local ring = deco(sm, "TurntableRing", Vector3.new(0.3, 9.6, 9.6), s(0, FLOOR_Y + 0.15, D * 0.55) * CFrame.Angles(0, 0, math.rad(90)), trim, Enum.Material.Neon)
			ring.Shape = Enum.PartType.Cylinder
		end
		-- pedestals for Token Shop trophies, in front of the windows by the entrance
		plot.TrophySpots = {}
		plot.TrophyParent = sm
		if level >= Config.TrophyUnlockLevel then
			for k2 = 0, 2 do
				for _, side in ipairs({ -1, 1 }) do
					local x = side * (doorW / 2 + 4.6 + k2 * 3.4)
					if math.abs(x) < W / 2 - 2 then
						table.insert(plot.TrophySpots, s(x, FLOOR_Y, 4.6) * CFrame.Angles(0, math.pi, 0))
					end
				end
			end
		end

		-- display spots along the left and right walls, angled toward the aisle (no floor platforms)
		local spots = {}
		if single then
			local cf = s(0, FLOOR_Y + 0.02, D / 2 + 1)
			table.insert(spots, { CFrame = cf, Front = s(0, FLOOR_Y, D / 2 - 8.5) })
		end
		for i = 1, single and 0 or perSide do
			for _, side in ipairs({ -1, 1 }) do
				-- nose to the aisle, nearly square to the wall, so parked cars never touch their neighbours
				local x = side * (W / 2 - 9)
				local z = 12 + (i - 1) * 10
				local dir = Vector3.new(-side, 0, -0.18)
				local yaw = math.atan2(-dir.X, -dir.Z)
				local cf = s(x, FLOOR_Y + 0.02, z) * CFrame.Angles(0, yaw, 0)
				table.insert(spots, { CFrame = cf, Front = s(side * 4, FLOOR_Y, z - 2) })
			end
		end
		while #spots > spotCount do
			table.remove(spots)
		end
		-- a glowing outline for every spot; only shown (on the client) while you hold a car
		for i, spot in ipairs(spots) do
			local marker = deco(sm, "SpotMarker", Vector3.new(7.4, 0.1, 14.5), spot.CFrame * CFrame.new(0, 0.07, 0), Color3.fromRGB(90, 220, 255), Enum.Material.Neon, { Transparency = 1 })
			marker:SetAttribute("SpotIndex", i)
			marker:SetAttribute("PlotIndex", index)
			CollectionService:AddTag(marker, "SpotMarker")
			spot.Marker = marker
		end
		plot.Spots = spots
		plot.DoorOutside = s(0, FLOOR_Y + 2.5, -10).Position
		plot.DoorInside = s(0, FLOOR_Y + 2.5, 6).Position
		plot.SpawnCFrame = CFrame.lookAt(v(0, 3, Z0 - 8), v(0, 3, Z0 + 10))
		applySign()
		return spots
	end

	--=========================== CONTAINER LOT (behind the showroom) ===========================
	local lotD = LOT_Z1 - LOT_Z0
	plot.LotPart = box(m, "Lot", Vector3.new(LOT_HALF * 2, 0.4, lotD), at(0, 0.2, (LOT_Z0 + LOT_Z1) / 2), ASPHALT, Enum.Material.Asphalt)
	plot.FenceParts = {}
	-- low fence on the sides; the back stays open where the truck backs in
	local function fenceRun(from, to)
		local dir = to - from
		local len = dir.Magnitude
		local mid = (from + to) / 2
		local cf = CFrame.lookAt(mid, mid + dir.Unit)
		if Props.Has("ChainFence") then
			-- real chain-link sections, end to end
			local n = math.max(1, math.floor(len / 8 + 0.5))
			local seg = len / n
			for i = 1, n do
				local pos = from + dir.Unit * (seg * (i - 0.5))
				Props.Place("ChainFence", m, CFrame.lookAt(pos, pos + dir.Unit) * CFrame.Angles(0, PROP_FRONT.ChainFence or 0, 0), { Length = seg, LongZ = true, Solid = true })
			end
			return
		end
		for _, y in ipairs({ 1.6, 3.2 }) do
			table.insert(plot.FenceParts, box(m, "FenceRail", Vector3.new(0.3, 0.5, len), cf * CFrame.new(0, y - mid.Y, 0), Color3.fromRGB(70, 78, 96)))
		end
		local posts = math.max(1, math.floor(len / 12))
		for i = 0, posts do
			table.insert(plot.FenceParts, deco(m, "FencePost", Vector3.new(0.5, 4, 0.5), cf * CFrame.new(0, 2 - mid.Y, -len / 2 + i * len / posts), Color3.fromRGB(70, 78, 96)))
		end
	end
	for _, sx in ipairs({ -1, 1 }) do
		fenceRun(v(sx * LOT_HALF, 0, LOT_Z0), v(sx * LOT_HALF, 0, LOT_Z1))
		fenceRun(v(sx * LOT_HALF, 0, LOT_Z1), v(sx * 14, 0, LOT_Z1))
	end
	-- painted parking bays under the container slots, and lamp posts on the lot corners
	for _, z in ipairs({ 150, 162, 174, 186 }) do
		for x = -30, 30, 10 do
			deco(m, "BayLine", Vector3.new(0.25, 0.04, 10.5), at(x, 0.42, z), Color3.fromRGB(232, 232, 228))
		end
	end
	for _, c in ipairs({ { -LOT_HALF + 3, LOT_Z0 + 18 }, { LOT_HALF - 3, LOT_Z0 + 18 }, { -LOT_HALF + 3, LOT_Z1 - 6 }, { LOT_HALF - 3, LOT_Z1 - 6 } }) do
		Props.Place("StreetLamp", m, at(c[1], 0.4, c[2]) * CFrame.Angles(0, c[1] < 0 and -math.pi / 2 or math.pi / 2, 0), { Height = 13, Solid = true })
	end
	-- container slots: a tidy grid in front of the truck
	local yardSlots = {}
	for _, z in ipairs({ 150, 162, 174, 186 }) do
		for _, x in ipairs({ -25, -15, -5, 5, 15, 25 }) do
			table.insert(yardSlots, at(x, 0.4, z))
		end
	end
	-- the delivery truck, backed in with its open rear toward the lot
	local TRUCK_Z = LOT_Z1 + 6
	if not Props.Place("DeliveryTruck", m, at(0, 0, TRUCK_Z) * CFrame.Angles(0, math.pi + (PROP_FRONT.DeliveryTruck or 0), 0), { Length = 30, LongZ = true, Solid = true }) then
		truck(m, at(0, 0, TRUCK_Z) * CFrame.Angles(0, math.pi, 0), Color3.fromRGB(236, 239, 245))
	end
	plot.TruckDrop = at(0, 7, TRUCK_Z - 11.5)

	--=========================== WASH SPOT (left side of the lot) ===========================
	local WX, WZ = -48, 176
	local washCF = at(WX, 0.42, WZ)
	local washPad = box(m, "WashPad", Vector3.new(14, 0.1, 20), at(WX, 0.42, WZ), Color3.fromRGB(96, 104, 118), nil, { CanCollide = false })
	local washTiers = {}
	local function tier(n)
		local t = Instance.new("Model")
		t.Name = "WashTier" .. n
		washTiers[n] = t
		return t
	end
	-- real store equipment when it's there, the simple built version otherwise
	local function washProp(t, name, x, z, yaw, opts)
		return Props.Place(name, t, at(WX + x, 0.45, WZ + z) * CFrame.Angles(0, yaw + (PROP_FRONT[name] or 0), 0), opts)
	end
	do -- 1: bucket and sponge
		local t = tier(1)
		if not washProp(t, "Bucket", 8.5, -6, 0, { Height = 1.9 }) then
			column(t, "Bucket", 1.6, 1.6, at(WX + 8.5, 1.2, WZ - 6), Color3.fromRGB(60, 130, 220), nil, true)
			deco(t, "Water", Vector3.new(0.05, 1.4, 1.4), at(WX + 8.5, 2, WZ - 6) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(160, 210, 255), Enum.Material.Glass, { Shape = Enum.PartType.Cylinder, Transparency = 0.2 })
			deco(t, "Sponge", Vector3.new(1, 0.6, 0.7), at(WX + 7.4, 0.75, WZ - 6.3), Color3.fromRGB(255, 220, 60))
		end
	end
	do -- 2: garden hose reel
		local t = tier(2)
		if not washProp(t, "HoseReel", -8.6, -7, math.pi / 2, { Height = 3.2 }) then
			box(t, "ReelStand", Vector3.new(0.4, 3, 2.4), at(WX - 8.5, 1.9, WZ - 7), Color3.fromRGB(40, 140, 60))
			local reel = part({ Name = "Reel", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.9, 2.6, 2.6), CFrame = at(WX - 8.2, 2.6, WZ - 7), Color = Color3.fromRGB(60, 170, 70), CanCollide = false, CanQuery = false }, t)
			reel.Size = Vector3.new(0.9, 2.6, 2.6)
		end
	end
	do -- 3: pressure washer cart
		local t = tier(3)
		if not washProp(t, "PressureWasher", 8.8, 6, -math.pi / 2, { Height = 3.2 }) then
			box(t, "Washer", Vector3.new(2.4, 2.2, 3.2), at(WX + 8.6, 1.6, WZ + 6), Color3.fromRGB(250, 200, 40))
			deco(t, "WasherTop", Vector3.new(2.5, 0.3, 3.3), at(WX + 8.6, 2.8, WZ + 6), Color3.fromRGB(40, 40, 45))
		end
	end
	do -- 4: foam cannon on a stand and blue tiles
		local t = tier(4)
		deco(t, "BlueTiles", Vector3.new(14, 0.08, 20), at(WX, 0.5, WZ), Color3.fromRGB(110, 175, 230))
		box(t, "FoamStand", Vector3.new(0.5, 6, 0.5), at(WX - 8.6, 3.4, WZ + 6), Color3.fromRGB(220, 220, 228), Enum.Material.Metal)
		deco(t, "FoamCannon", Vector3.new(0.9, 0.9, 2.6), at(WX - 8.1, 6.3, WZ + 5.2) * CFrame.Angles(math.rad(-25), 0, 0), Color3.fromRGB(240, 90, 160))
	end
	do -- 5: covered wash bay
		local t = tier(5)
		if not washProp(t, "CarWashBay", 0, 0, 0, { Length = 24, LongZ = true }) then
			for _, x in ipairs({ -7.6, 7.6 }) do
				for _, z in ipairs({ -9.6, 9.6 }) do
					box(t, "BayPost", Vector3.new(0.9, 11, 0.9), at(WX + x, 5.9, WZ + z), Color3.fromRGB(240, 242, 246), Enum.Material.Metal)
				end
			end
			deco(t, "BayRoof", Vector3.new(17, 0.8, 21.6), at(WX, 11.6, WZ), Color3.fromRGB(60, 130, 220))
			local sign = deco(t, "BaySign", Vector3.new(10, 2, 0.3), at(WX, 13, WZ - 10.4), Color3.fromRGB(30, 80, 160))
			surfaceText(sign, Enum.NormalId.Front, "CAR WASH", Color3.new(1, 1, 1), 24)
		end
	end
	do -- 6: automatic car wash brushes
		local t = tier(6)
		if not washProp(t, "WashMachine", 0, -3, 0, { Width = 15 }) then
			for _, x in ipairs({ -6.4, 6.4 }) do
				local b = part({ Name = "Brush", Shape = Enum.PartType.Cylinder, Size = Vector3.new(8, 2.4, 2.4), CFrame = at(WX + x, 4.8, WZ - 3) * CFrame.Angles(0, 0, math.rad(90)), Color = Color3.fromRGB(60, 120, 235), Material = Enum.Material.Fabric, CanCollide = false, CanQuery = false }, t)
				b.Size = Vector3.new(8, 2.4, 2.4)
			end
			deco(t, "TopBrush", Vector3.new(12, 2, 2), at(WX, 9.6, WZ + 3), Color3.fromRGB(60, 120, 235), Enum.Material.Fabric)
		end
	end
	function plot.SetWashTier(level)
		for n, t in ipairs(washTiers) do
			t.Parent = (n <= level) and m or nil
		end
	end
	plot.SetWashTier(1)
	local washLabel = label(washPad, "WASH SPOT", Color3.fromRGB(150, 220, 255), 9, 240)
	washLabel.Parent.Enabled = false

	--=========================== TIRE SHOP (right side of the lot, open toward the middle) ===========================
	local TX, TZ = 47, 176
	local tW, tD, tH = 26, 22, 11
	local tireBase = at(TX, 0, TZ) * CFrame.Angles(0, math.pi / 2, 0)
	local function t(x, y, z)
		return tireBase * CFrame.new(x, y, z)
	end
	local BRICK = Color3.fromRGB(162, 84, 66)
	box(m, "TireFloor", Vector3.new(tW, FLOOR_Y, tD), t(0, FLOOR_Y / 2, 0), Color3.fromRGB(140, 142, 148), Enum.Material.Concrete)
	for _, side in ipairs({ -1, 1 }) do
		box(m, "TireWall", Vector3.new(0.5, tH, tD), t(side * tW / 2, FLOOR_Y + tH / 2, 0), BRICK, Enum.Material.Brick)
	end
	box(m, "TireBack", Vector3.new(tW, tH, 0.5), t(0, FLOOR_Y + tH / 2, tD / 2), BRICK, Enum.Material.Brick)
	box(m, "TireRoof", Vector3.new(tW + 0.6, 0.35, tD + 0.6), t(0, FLOOR_Y + tH + 0.18, 0), Color3.fromRGB(78, 80, 86), Enum.Material.Concrete)
	-- the open front reads as a garage: a rolled-up shutter box and steel door frame
	deco(m, "ShutterBox", Vector3.new(tW - 1, 0.9, 0.9), t(0, FLOOR_Y + tH - 0.45, -tD / 2 + 0.6), Color3.fromRGB(150, 156, 166), Enum.Material.Metal)
	for _, side in ipairs({ -1, 1 }) do
		deco(m, "DoorFrame", Vector3.new(0.8, tH, 0.8), t(side * (tW / 2 - 0.4), FLOOR_Y + tH / 2, -tD / 2), Color3.fromRGB(60, 64, 72), Enum.Material.Metal)
	end
	local shopSign = box(m, "TireSign", Vector3.new(10, 1.5, 0.15), t(0, FLOOR_Y + tH - 0.9, -tD / 2 - 0.1), NAVY)
	surfaceText(shopSign, Enum.NormalId.Front, "PAINT SHOP", GOLD, 22)
	local lightPart = deco(m, "ShopLight", Vector3.new(8, 0.3, 1), t(0, FLOOR_Y + tH - 0.5, 0), LAMP, Enum.Material.Neon)
	light(lightPart, 24, 0.5)
	local lift = box(m, "TireLift", Vector3.new(12, 0.12, 18), t(0, FLOOR_Y + 0.06, 0), Color3.fromRGB(120, 124, 132), nil, { CanCollide = false })
	if not Props.Place("CarLift", m, t(0, FLOOR_Y, 0) * CFrame.Angles(0, PROP_FRONT.CarLift or 0, 0), { Height = 10.5 }) then
		for _, x in ipairs({ -6.6, 6.6 }) do
			box(m, "LiftPost", Vector3.new(1.2, 10, 1.4), t(x, FLOOR_Y + 5, 0), Color3.fromRGB(250, 195, 40))
		end
		deco(m, "LiftTop", Vector3.new(14.4, 0.8, 1.2), t(0, FLOOR_Y + 10.2, 0), Color3.fromRGB(250, 195, 40))
	end
	-- a working tyre shop: racks of tyres on the back wall, a tool cabinet in the corner
	Props.Place("TireRack", m, t(-7, FLOOR_Y, tD / 2 - 1.6) * CFrame.Angles(0, PROP_FRONT.TireRack or 0, 0), { Width = 7 })
	Props.Place("TireStack", m, t(tW / 2 - 2.4, FLOOR_Y, tD / 2 - 2.4), { Height = 4 })
	Props.Place("ToolCabinet", m, t(7, FLOOR_Y, tD / 2 - 1.4) * CFrame.Angles(0, PROP_FRONT.ToolCabinet or 0, 0), { Height = 4.2 })
	local liftLabel = label(lift, "PAINT SHOP", Color3.fromRGB(255, 215, 100), 10, 240)
	liftLabel.Parent.Enabled = false

	--=========================== SELL STATION + STORAGE UNIT (right behind the garage) ===========================
	local function iconBoard(parentPart, imageKey, height)
		local id = Icons.Images[imageKey]
		if not id then
			return
		end
		local bb = Instance.new("BillboardGui")
		bb.Name = "IconBoard"
		bb.Size = UDim2.new(3.6, 0, 3.6, 0)
		bb.StudsOffset = Vector3.new(0, height, 0)
		bb.LightInfluence = 0
		bb.MaxDistance = 140
		local img = Instance.new("ImageLabel")
		img.BackgroundTransparency = 1
		img.Size = UDim2.new(1, 0, 1, 0)
		img.Image = "rbxassetid://" .. id
		img.Parent = bb
		bb.Parent = parentPart
	end
	do -- Sell Station: an open kiosk with a counter, facing the middle of the lot
		local base = at(-19, 0.4, LOT_Z1 - 4.5)
		local function k(x, y, z)
			return base * CFrame.new(x, y, z)
		end
		local GREENK = Color3.fromRGB(46, 150, 84)
		box(m, "SellSlab", Vector3.new(7, 0.25, 5.4), k(0, 0.12, 0), Color3.fromRGB(150, 152, 156), Enum.Material.Concrete)
		local counter = box(m, "SellCounter", Vector3.new(6, 3.1, 1.2), k(0, 1.8, -1.9), GREENK, Enum.Material.SmoothPlastic)
		deco(m, "SellCounterTop", Vector3.new(6.3, 0.18, 1.6), k(0, 3.42, -1.9), Color3.fromRGB(230, 230, 228), Enum.Material.Marble)
		for _, x in ipairs({ -3.2, 3.2 }) do
			for _, z in ipairs({ -2.4, 2.4 }) do
				deco(m, "SellPost", Vector3.new(0.22, 6.6, 0.22), k(x, 3.4, z), Color3.fromRGB(60, 64, 72), Enum.Material.Metal)
			end
		end
		deco(m, "SellRoof", Vector3.new(7.4, 0.22, 5.6), k(0, 6.8, 0), GREENK, Enum.Material.Metal)
		local sign = deco(m, "SellSign", Vector3.new(5.4, 1.2, 0.12), k(0, 7.6, -2.6), Color3.fromRGB(28, 32, 40))
		surfaceText(sign, Enum.NormalId.Front, "SELL CARS", Color3.fromRGB(120, 255, 150), 26)
		iconBoard(counter, "Cash", 6.8)
		plot.SellPart = counter
		plot.SellCFrame = k(0, 2, -3)
		-- the dealer: a shady guy in a suit behind the counter who buys any car, no questions asked
		local npc = Props.Place("XMafiaNPC", m, k(0, 0.25, 0.3) * CFrame.Angles(0, PROP_FRONT.XMafiaNPC or 0, 0), { Height = 5.6 })
		if npc then
			for _, d in ipairs(npc:GetDescendants()) do
				if d:IsA("Humanoid") then
					d.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
				end
			end
			-- a suspicious face: narrowed shifty eyes and a smirk on the head
			local head = npc:FindFirstChild("Head", true)
			if head and head:IsA("BasePart") then
				for _, d in ipairs(head:GetChildren()) do
					if d:IsA("Decal") then
						d:Destroy()
					end
				end
				-- the round head mesh bulges in front of the head part, so the face goes on a thin
				-- invisible plate just in front of it
				local plate = Instance.new("Part")
				plate.Name = "FacePlate"
				plate.Size = Vector3.new(1.2 * head.Size.Y, head.Size.Y, 0.05)
				plate.CFrame = head.CFrame * CFrame.new(0, 0, -head.Size.Z * 0.62)
				plate.Transparency = 1
				plate.Anchored = true
				plate.CanCollide = false
				plate.CanQuery = false
				plate.CanTouch = false
				plate.Parent = npc
				local face = Instance.new("SurfaceGui")
				face.Face = Enum.NormalId.Front
				face.CanvasSize = Vector2.new(120, 100)
				face.LightInfluence = 0.6
				face.Parent = plate
				local function bar(x, y, w, h, rot, color)
					local f = Instance.new("Frame")
					f.BorderSizePixel = 0
					f.BackgroundColor3 = color or Color3.fromRGB(20, 18, 18)
					f.AnchorPoint = Vector2.new(0.5, 0.5)
					f.Position = UDim2.new(0, x, 0, y)
					f.Size = UDim2.new(0, w, 0, h)
					f.Rotation = rot
					f.Parent = face
					return f
				end
				-- (the hat brim covers the top of the head, so the face sits low)
				bar(42, 63, 26, 4, 16) -- heavy brows just under the brim
				bar(78, 63, 26, 4, -16)
				bar(42, 71, 24, 5, 10) -- narrow squinting eyes, angled in
				bar(78, 71, 24, 5, -10)
				bar(48, 71, 4, 3, 0, Color3.fromRGB(235, 235, 235)) -- a glint, eyes to the side
				bar(84, 71, 4, 3, 0, Color3.fromRGB(235, 235, 235))
				bar(64, 87, 26, 4, -10) -- a crooked smirk
				bar(78, 84, 7, 3, -35)
				bar(30, 79, 4, 12, 18, Color3.fromRGB(150, 40, 40)) -- an old scar
				for i = 0, 5 do -- stubble
					bar(48 + i * 5, 94 + (i % 2) * 2, 3, 3, 0, Color3.fromRGB(80, 64, 54))
				end
			end
		end
	end
	do -- Storage Unit: a self-storage unit with an orange roll-up door
		local base = at(-33, 0.4, LOT_Z1 - 4.5)
		local function k(x, y, z)
			return base * CFrame.new(x, y, z)
		end
		local SHELL = Color3.fromRGB(196, 200, 208)
		local uw, ud, uh = 8, 6.5, 6.5
		box(m, "StorageFloor", Vector3.new(uw, 0.25, ud), k(0, 0.12, 0), Color3.fromRGB(150, 152, 156), Enum.Material.Concrete)
		for _, x in ipairs({ -uw / 2, uw / 2 }) do
			box(m, "StorageWall", Vector3.new(0.3, uh, ud), k(x, uh / 2, 0), SHELL, Enum.Material.Metal)
		end
		box(m, "StorageBack", Vector3.new(uw, uh, 0.3), k(0, uh / 2, ud / 2), SHELL, Enum.Material.Metal)
		box(m, "StorageRoof", Vector3.new(uw + 0.6, 0.3, ud + 0.6), k(0, uh + 0.15, 0), Color3.fromRGB(120, 124, 132), Enum.Material.Metal)
		local door = box(m, "StorageDoor", Vector3.new(uw - 0.6, uh - 1.2, 0.2), k(0, (uh - 1.2) / 2 + 0.25, -ud / 2), Color3.fromRGB(230, 120, 40), Enum.Material.Metal)
		for y = 0.8, uh - 1.6, 0.7 do
			deco(m, "StorageRib", Vector3.new(uw - 0.7, 0.08, 0.06), k(0, y, -ud / 2 - 0.12), Color3.fromRGB(196, 96, 30), Enum.Material.Metal)
		end
		local sign = deco(m, "StorageSign", Vector3.new(uw - 1, 0.9, 0.12), k(0, uh - 0.45, -ud / 2 - 0.1), Color3.fromRGB(28, 32, 40))
		surfaceText(sign, Enum.NormalId.Front, "STORAGE", Color3.new(1, 1, 1), 26)
		iconBoard(door, "Crate", 5.6)
		plot.StoragePart = door
		plot.StorageCFrame = k(0, 2, -ud / 2 - 2)
	end
	do -- Token Shop: a trophy kiosk next to the storage unit
		local base = at(-46, 0.4, LOT_Z1 - 4.5)
		local function k(x, y, z)
			return base * CFrame.new(x, y, z)
		end
		local PURPLE = Color3.fromRGB(110, 70, 200)
		box(m, "TokenSlab", Vector3.new(7, 0.25, 5.4), k(0, 0.12, 0), Color3.fromRGB(150, 152, 156), Enum.Material.Concrete)
		local kiosk = Props.Place("XTokenKiosk", m, k(0, 0.25, 0.4) * CFrame.Angles(0, PROP_FRONT.XTokenKiosk or 0, 0), { Height = 6.5 })
		local counter = box(m, "TokenCounter", Vector3.new(6, 3.1, 1.2), k(0, 1.8, -1.9), PURPLE, Enum.Material.SmoothPlastic)
		deco(m, "TokenCounterTop", Vector3.new(6.3, 0.18, 1.6), k(0, 3.42, -1.9), Color3.fromRGB(245, 215, 120), Enum.Material.Metal)
		if not kiosk then
			for _, x in ipairs({ -3.2, 3.2 }) do
				for _, z in ipairs({ -2.4, 2.4 }) do
					deco(m, "TokenPost", Vector3.new(0.22, 6.6, 0.22), k(x, 3.4, z), Color3.fromRGB(60, 64, 72), Enum.Material.Metal)
				end
			end
		end
		deco(m, "TokenRoof", Vector3.new(7.4, 0.22, 5.6), k(0, 6.8, 0), PURPLE, Enum.Material.Metal)
		local sign = deco(m, "TokenSign", Vector3.new(5.4, 1.2, 0.12), k(0, 7.6, -2.6), Color3.fromRGB(28, 32, 40))
		surfaceText(sign, Enum.NormalId.Front, "TOKEN SHOP", Color3.fromRGB(255, 215, 100), 26)
		Props.Place("XTrophyGold", m, k(-1.8, 3.5, -1.9), { Height = 1.4 })
		Props.Place("XTrophyStar", m, k(1.8, 3.5, -1.9), { Height = 1.4 })
		iconBoard(counter, "Coin", 6.8)
		plot.TokenPart = counter
		plot.TokenCFrame = k(0, 2, -3)
	end

	--=========================== UPGRADE STATIONS (a row just behind the showroom) ===========================
	local function icon(kind, at0)
		local mdl = Instance.new("Model")
		mdl.Name = "StationIcon"
		-- the painted icon artwork floating over the pad
		local imageId = Icons.Images[({ Showroom = "Showroom", Truck = "Truck", Wash = "Sponge", Engine = "Upgrade" })[kind] or ""]
		if imageId and imageId ~= "" then
			local anchor = deco(mdl, "IconAnchor", Vector3.new(0.2, 0.2, 0.2), at0, Color3.new(1, 1, 1), nil, { Transparency = 1 })
			local bb = Instance.new("BillboardGui")
			bb.Name = "IconBoard" -- always visible (the label declutter skips it)
			bb.Size = UDim2.new(4.6, 0, 4.6, 0)
			bb.LightInfluence = 0
			bb.MaxDistance = 140
			local img = Instance.new("ImageLabel")
			img.BackgroundTransparency = 1
			img.Size = UDim2.new(1, 0, 1, 0)
			img.Image = "rbxassetid://" .. imageId
			img.Parent = bb
			bb.Parent = anchor
			mdl.PrimaryPart = anchor
			mdl.Parent = m
			CollectionService:AddTag(mdl, "StationIcon")
			return mdl
		end
		local function ip(size, off, color, mat, shape)
			local q = deco(mdl, "IconPart", size, at0 * off, color, mat or Enum.Material.SmoothPlastic)
			if shape then
				q.Shape = shape
				q.Size = size
			end
			return q
		end
		if kind == "Showroom" then
			ip(Vector3.new(3, 1.6, 2), CFrame.new(0, 0, 0), Color3.fromRGB(240, 225, 190))
			for x = -1.1, 1.1, 0.73 do
				ip(Vector3.new(0.35, 1.5, 0.35), CFrame.new(x, 0, -1.1), Color3.fromRGB(250, 245, 230))
			end
			ip(Vector3.new(3.4, 0.35, 2.6), CFrame.new(0, 0.95, -0.15), Color3.fromRGB(200, 160, 90))
			local roof = Instance.new("WedgePart")
			roof.Anchored, roof.CanCollide, roof.CanQuery = true, false, false
			roof.Size = Vector3.new(3.4, 0.9, 1.3)
			roof.Color = Color3.fromRGB(200, 160, 90)
			roof.CFrame = at0 * CFrame.new(0, 1.55, -0.8)
			roof.Parent = mdl
			ip(Vector3.new(3.6, 0.3, 2.8), CFrame.new(0, -0.95, -0.2), Color3.fromRGB(220, 205, 170))
		elseif kind == "Wash" then
			ip(Vector3.new(2.8, 1.5, 1.9), CFrame.new(0, 0, 0), Color3.fromRGB(255, 220, 60))
			for _, h in ipairs({ { -0.7, 0.3 }, { 0.5, -0.2 }, { 0.9, 0.4 }, { -0.2, -0.3 } }) do
				ip(Vector3.new(0.12, 0.45, 0.45), CFrame.new(h[1], h[2], -0.96) * CFrame.Angles(0, math.rad(90), 0), Color3.fromRGB(220, 170, 30), nil, Enum.PartType.Cylinder)
			end
			for _, b in ipairs({ { -1.3, 1, 0.5 }, { 1.2, 1.1, 0.4 }, { 0, 1.3, 0.6 } }) do
				ip(Vector3.new(b[3], b[3], b[3]), CFrame.new(b[1], b[2], 0), Color3.fromRGB(220, 240, 255), Enum.Material.Glass, Enum.PartType.Ball)
			end
		elseif kind == "Engine" then
			ip(Vector3.new(2.6, 1.4, 1.6), CFrame.new(0, -0.1, 0), Color3.fromRGB(205, 60, 50), Enum.Material.Metal)
			for x = -0.9, 0.9, 0.6 do
				ip(Vector3.new(0.45, 0.8, 0.45), CFrame.new(x, 0.9, 0), Color3.fromRGB(200, 200, 210), Enum.Material.Metal)
			end
			for k, c in ipairs({ { 0.9, 0.9 }, { 1.35, 0.55 }, { 0.95, 0.35 } }) do
				ip(Vector3.new(0.6, 0.6, 0.6), CFrame.new(c[1], c[2] + 0.4, -0.9), Color3.fromRGB(60, 190, 70), nil, Enum.PartType.Ball)
				if k == 1 then
					ip(Vector3.new(0.12, 0.6, 0.12), CFrame.new(1.05, 0.3, -0.9), Color3.fromRGB(40, 140, 50))
				end
			end
		elseif kind == "Truck" then
			ip(Vector3.new(1.9, 1.7, 2.6), CFrame.new(0, 0.2, 0.5), Color3.fromRGB(235, 240, 248))
			ip(Vector3.new(1.8, 1.2, 1), CFrame.new(0, -0.05, -1.3), Color3.fromRGB(110, 170, 240))
			ip(Vector3.new(1.4, 0.5, 0.05), CFrame.new(0, 0.2, -1.82), Color3.fromRGB(40, 60, 90), Enum.Material.Glass)
			for _, w in ipairs({ { -0.95, -1.2 }, { 0.95, -1.2 }, { -0.95, 1.1 }, { 0.95, 1.1 } }) do
				ip(Vector3.new(0.3, 0.75, 0.75), CFrame.new(w[1], -0.7, w[2]), Color3.fromRGB(30, 30, 32), nil, Enum.PartType.Cylinder)
			end
		end
		mdl.Parent = m
		CollectionService:AddTag(mdl, "StationIcon")
		return mdl
	end
	local function pad(name, x, z, y, kind, facing)
		y = y or FLOOR_Y
		local base = at(x, y, z) * CFrame.Angles(0, facing or 0, 0)
		-- a low concrete plinth with a dark inset plate and a thin painted border: reads like a real
		-- floor marking instead of a glowing slab
		box(m, name .. "Plinth", Vector3.new(6.4, 0.3, 6.4), base * CFrame.new(0, 0.15, 0), Color3.fromRGB(170, 172, 176), Enum.Material.Concrete, { CanCollide = false })
		local p = box(m, name, Vector3.new(5.4, 0.06, 5.4), base * CFrame.new(0, 0.33, 0), Color3.fromRGB(46, 50, 58), Enum.Material.SmoothPlastic, { CanCollide = false })
		for _, e in ipairs({ { 0, 2.55, 5.4, 0.3 }, { 0, -2.55, 5.4, 0.3 }, { 2.55, 0, 0.3, 5.4 }, { -2.55, 0, 0.3, 5.4 } }) do
			deco(m, name .. "Edge", Vector3.new(e[3], 0.07, e[4]), base * CFrame.new(e[1], 0.34, e[2]), Color3.fromRGB(80, 200, 120))
		end
		local ic = icon(kind, base * CFrame.new(0, 4.4, 0))
		-- the name above the icon and the level under it
		local anchor = deco(m, name .. "Anchor", Vector3.new(0.2, 0.2, 0.2), base * CFrame.new(0, 4.4, 0), Color3.new(1, 1, 1), nil, { Transparency = 1 })
		local title = label(anchor, name, Color3.new(1, 1, 1), 2.6, 140, 45)
		title.Parent.Size = UDim2.new(3.9, 0, 0.95, 0)
		local lv = label(anchor, "Level 1", Color3.fromRGB(255, 225, 120), -2.2, 120, 30)
		lv.Parent.Size = UDim2.new(3.3, 0, 0.7, 0)
		-- price plate on the floor, angled up toward the player
		local plate = box(m, name .. "Price", Vector3.new(4.6, 0.12, 1.4), base * CFrame.new(0, 0.22, -4.3) * CFrame.Angles(math.rad(-8), 0, 0), Color3.fromRGB(60, 200, 80), nil, { CanCollide = false })
		local priceGui = Instance.new("SurfaceGui")
		priceGui.Face = Enum.NormalId.Top
		priceGui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		priceGui.PixelsPerStud = 40
		priceGui.LightInfluence = 0
		local priceText = Instance.new("TextLabel")
		priceText.BackgroundTransparency = 1
		priceText.Size = UDim2.new(1, 0, 1, 0)
		priceText.Font = Enum.Font.GothamBold
		priceText.TextScaled = true
		priceText.TextColor3 = Color3.new(1, 1, 1)
		priceText.Rotation = 180
		priceText.Text = "$0"
		addStroke(priceText, 3)
		priceText.Parent = priceGui
		priceGui.Parent = plate
		return { Part = p, Label = lv, Title = title, Plate = plate, Price = priceText, Icon = ic }
	end
	local pads = {
		Showroom = pad("Showroom Size", -46, 138, 0.4, "Showroom"),
		Truck = pad("Truck Tier", -32, 138, 0.4, "Truck"),
		Wash = pad("Car Wash", 32, 138, 0.4, "Wash"),
		Engine = pad("Paint Luck", 46, 138, 0.4, "Engine"),
	}

	plot.WashCFrame = washCF
	plot.LiftCFrame = t(0, FLOOR_Y + 1.4, 0)
	plot.WashLabel = washLabel
	plot.LiftLabel = liftLabel
	plot.YardSlots = yardSlots
	plot.Pads = pads
	plot.BuildShowroom(1)
	return plot
end

function MapBuilder.Build()
	buildLighting()
	local map = Instance.new("Folder")
	map.Name = "Map"
	map.Parent = workspace
	buildWorld(map)
	local plots = {}
	for i = 1, Config.MaxPlots do
		plots[i] = buildPlot(i, map)
	end
	return { Folder = map, Plots = plots }
end

return MapBuilder

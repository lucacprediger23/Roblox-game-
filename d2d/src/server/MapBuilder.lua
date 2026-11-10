-- MapBuilder: builds the world and the 6 player plots when the server starts.
-- Plots face each other across a boulevard. Each plot: a showroom that grows with its level
-- (level 1 is a small garage), a large yard beside it with the upgrade stations, the parking lot
-- for containers, the wash spot (more gear appears as the car wash is upgraded) and the tire shop.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Lighting = game:GetService("Lighting")
local CollectionService = game:GetService("CollectionService")
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
	-- clean, smooth look everywhere (no grainy tiled textures), like Clean a Painting
	if p.Material ~= Enum.Material.Glass and p.Material ~= Enum.Material.Neon then
		if p.Material == Enum.Material.Metal or p.Material == Enum.Material.DiamondPlate or p.Material == Enum.Material.CorrodedMetal then
			p.Reflectance = 0
		end
		p.Material = Enum.Material.SmoothPlastic
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
	l.Font = Enum.Font.FredokaOne
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
	l.Font = font or Enum.Font.FredokaOne
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
	local t = 0.45
	deco(parent, "Frame", Vector3.new(width + t, t, 0.5), cf * CFrame.new(0, height / 2, 0), NAVY)
	deco(parent, "Frame", Vector3.new(width + t, t, 0.5), cf * CFrame.new(0, -height / 2, 0), NAVY)
	deco(parent, "Frame", Vector3.new(t, height + t, 0.5), cf * CFrame.new(-width / 2, 0, 0), NAVY)
	deco(parent, "Frame", Vector3.new(t, height + t, 0.5), cf * CFrame.new(width / 2, 0, 0), NAVY)
	for c = 1, cols - 1 do
		deco(parent, "Mullion", Vector3.new(0.22, height, 0.35), cf * CFrame.new(-width / 2 + c * width / cols, 0, 0), NAVY)
	end
	for r = 1, rows - 1 do
		deco(parent, "Mullion", Vector3.new(width, 0.22, 0.35), cf * CFrame.new(0, -height / 2 + r * height / rows, 0), NAVY)
	end
	-- stone sill under the window
	deco(parent, "Sill", Vector3.new(width + 1, 0.35, 1.1), cf * CFrame.new(0, -height / 2 - 0.4, -0.3), PLASTER_SHADE)
end

local function lowPolyTree(parent, pos, scale)
	scale = scale or 1
	local name = Props.Pick({ "Tree2" }, rng)
	if name and Props.Place(name, parent, CFrame.new(pos) * CFrame.Angles(0, rng:NextNumber(0, 6.28), 0), { Height = 17 * scale }) then
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
	-- smooth flat ground and clean terraced cliffs built from parts (terrain textures look grainy)
	local terrain = workspace.Terrain
	terrain:Clear()
	local GRASS = Color3.fromRGB(104, 178, 74)
	box(map, "Ground", Vector3.new(1800, 2, 1400), CFrame.new(0, -1, 0), GRASS)
	-- rolling green hills with tree lines around the town, so the sky stays open to the horizon
	local HILLS = { Color3.fromRGB(98, 172, 70), Color3.fromRGB(110, 182, 78), Color3.fromRGB(88, 160, 66), Color3.fromRGB(120, 188, 86) }
	local TREES = { Color3.fromRGB(56, 128, 58), Color3.fromRGB(66, 140, 62), Color3.fromRGB(48, 116, 54), Color3.fromRGB(78, 150, 66) }
	local function blob(name, size, cf, color)
		local p = deco(map, name, size, cf, color)
		local mesh = Instance.new("SpecialMesh")
		mesh.MeshType = Enum.MeshType.Sphere
		mesh.Parent = p
		return p
	end
	local function hill(x, z, rx, rz, h)
		blob("Hill", Vector3.new(rx * 2, h * 2, rz * 2), CFrame.new(x, 0, z) * CFrame.Angles(0, rng:NextNumber(-0.3, 0.3), 0), HILLS[rng:NextInteger(1, #HILLS)])
		-- a scatter of round trees on the hillside
		local count = math.floor(rx * rz / 380)
		for _ = 1, count do
			local u, v = rng:NextNumber(-0.85, 0.85), rng:NextNumber(-0.85, 0.85)
			local k = 1 - u * u - v * v
			if k > 0.05 then
				local y = h * math.sqrt(k)
				local sz = rng:NextNumber(7, 12)
				local pos = Vector3.new(x + u * rx, y, z + v * rz)
				deco(map, "HillTrunk", Vector3.new(1.2, sz * 0.6, 1.2), CFrame.new(pos + Vector3.new(0, sz * 0.25, 0)), Color3.fromRGB(110, 76, 52))
				blob("HillTree", Vector3.new(sz, sz * 1.15, sz), CFrame.new(pos + Vector3.new(0, sz * 0.75, 0)), TREES[rng:NextInteger(1, #TREES)])
			end
		end
	end
	-- behind the back service roads (north and south)
	for _, sz in ipairs({ -1, 1 }) do
		for x = -680, 680, 70 do
			hill(x + rng:NextNumber(-20, 20), sz * rng:NextNumber(310, 335), rng:NextNumber(45, 70), rng:NextNumber(28, 40), rng:NextNumber(10, 18))
			hill(x + 35 + rng:NextNumber(-20, 20), sz * rng:NextNumber(395, 440), rng:NextNumber(60, 90), rng:NextNumber(40, 60), rng:NextNumber(22, 36))
			hill(x + rng:NextNumber(-30, 30), sz * rng:NextNumber(500, 545), rng:NextNumber(80, 120), rng:NextNumber(50, 70), rng:NextNumber(35, 55))
		end
	end
	-- at both ends of the boulevard (east and west)
	for _, sx in ipairs({ -1, 1 }) do
		for z = -300, 300, 60 do
			if math.abs(z) > 30 then
				hill(sx * rng:NextNumber(430, 460), z + rng:NextNumber(-15, 15), rng:NextNumber(30, 45), rng:NextNumber(40, 60), rng:NextNumber(10, 18))
			end
			hill(sx * rng:NextNumber(530, 580), z + 30 + rng:NextNumber(-15, 15), rng:NextNumber(50, 80), rng:NextNumber(50, 70), rng:NextNumber(24, 40))
			hill(sx * rng:NextNumber(640, 690), z + rng:NextNumber(-20, 20), rng:NextNumber(70, 100), rng:NextNumber(60, 80), rng:NextNumber(35, 55))
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
	deco(map, "MedianGrass", Vector3.new(LEN - 1, 0.1, 5), CFrame.new(0, 0.75, 0), Color3.fromRGB(96, 170, 68), Enum.Material.Grass)
	for x = -LEN / 2 + 30, LEN / 2 - 30, 70 do
		lowPolyTree(map, Vector3.new(x, 0.7, 0), 0.8)
	end
	-- crosswalks between facing plots
	for _, x in ipairs(NORTH_X) do
		for s = -5, 5, 2 do
			deco(map, "Crosswalk", Vector3.new(1.2, 0.05, 32), CFrame.new(x + s, 0.43, 0), Color3.fromRGB(245, 245, 245))
		end
	end
	-- trees between the plots and on the edges
	for _, sz in ipairs({ -1, 1 }) do
		for x = -370, 370, 40 do
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
	deco(m, "Walk", Vector3.new(12, 0.2, ZB), at(0, 0.1, ZB / 2), CONCRETE)

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
		local perSide = 2 * level
		local W = 42 + 8 * (level - 1)
		local D = 24 + 10 * perSide
		local H = level == 1 and 13 or (16 + 2 * (level - 2))
		local garage = level == 1
		local Z0 = ZB - D
		local function s(x, y, z)
			return at(x, y, Z0 + z)
		end
		local wallColor = garage and Color3.fromRGB(200, 196, 188) or PLASTER
		local trim = garage and Color3.fromRGB(70, 78, 96) or NAVY

		-- floor, walls, roof
		box(sm, "Floor", Vector3.new(W, FLOOR_Y, D), s(0, FLOOR_Y / 2, D / 2), garage and Color3.fromRGB(150, 152, 156) or TILE)
		for _, side in ipairs({ -1, 1 }) do
			box(sm, "Wall", Vector3.new(1.2, H, D), s(side * W / 2, FLOOR_Y + H / 2, D / 2), wallColor)
		end
		box(sm, "Roof", Vector3.new(W + 1.6, 1, D + 1.6), s(0, FLOOR_Y + H + 0.5, D / 2), Color3.fromRGB(84, 88, 98))
		deco(sm, "Ceiling", Vector3.new(W - 1.2, 0.4, D - 1.2), s(0, FLOOR_Y + H - 0.2, D / 2), Color3.fromRGB(214, 214, 218))

		-- back wall with a wide open doorway into the lot
		local backDoor = 18
		local bw = (W - backDoor) / 2
		for _, side in ipairs({ -1, 1 }) do
			box(sm, "BackWall", Vector3.new(bw, H, 1.2), s(side * (backDoor / 2 + bw / 2), FLOOR_Y + H / 2, D), wallColor)
		end
		box(sm, "BackHeader", Vector3.new(backDoor, H - 11, 1.2), s(0, FLOOR_Y + 11 + (H - 11) / 2, D), wallColor)
		local lotSign = box(sm, "LotSign", Vector3.new(14, 1.6, 0.4), s(0, FLOOR_Y + 11.9, D - 0.9), trim)
		surfaceText(lotSign, Enum.NormalId.Front, "CONTAINER LOT", Color3.new(1, 1, 1), 24)

		-- front: a wide door with the sign above it
		local doorW = garage and 20 or 16
		local doorH = garage and 10 or 11
		local sideW = (W - doorW) / 2
		for _, side in ipairs({ -1, 1 }) do
			if garage then
				box(sm, "Front", Vector3.new(sideW, H, 1.2), s(side * (doorW / 2 + sideW / 2), FLOOR_Y + H / 2, 0), wallColor)
			else
				box(sm, "FrontPier", Vector3.new(1.6, H, 1.6), s(side * (W / 2 - 0.2), FLOOR_Y + H / 2, 0), PLASTER)
				box(sm, "DoorPier", Vector3.new(1.6, H, 1.6), s(side * (doorW / 2 + 0.8), FLOOR_Y + H / 2, 0), PLASTER)
				window(sm, s(side * (doorW / 2 + sideW / 2), FLOOR_Y + 0.5 + (H - 4) / 2, 0), sideW - 3, H - 4, 2, 1, 0.6)
			end
		end
		box(sm, "Header", Vector3.new(doorW, H - doorH, 1.2), s(0, FLOOR_Y + doorH + (H - doorH) / 2, 0), garage and wallColor or PLASTER)
		if not garage then
			box(sm, "SignBand", Vector3.new(W + 1, 3, 1.4), s(0, FLOOR_Y + H - 1.5, 0), PLASTER)
		end
		local signBoard = box(sm, "SignBoard", Vector3.new(math.min(W - 8, 34), 2.6, 0.4), s(0, FLOOR_Y + (garage and doorH + 1.5 or H - 1.5), -0.9), trim)
		table.insert(signLabels, surfaceText(signBoard, Enum.NormalId.Front, signText, GOLD, 26))

		-- a few soft ceiling lights
		local k = 0
		for z = 10, D - 8, 16 do
			k = k + 1
			local l = deco(sm, "CeilingLight", Vector3.new(6, 0.12, 2), s(0, FLOOR_Y + H - 0.45, z), LAMP, Enum.Material.Neon)
			if k % 2 == 1 then
				light(l, 28, 0.35)
			end
		end

		-- display spots along the left and right walls, angled toward the aisle (no floor platforms)
		local spots = {}
		for i = 1, perSide do
			for _, side in ipairs({ -1, 1 }) do
				local x = side * (W / 2 - 9)
				local z = 12 + (i - 1) * 10
				local dir = Vector3.new(-side, 0, -0.6)
				local yaw = math.atan2(-dir.X, -dir.Z)
				local cf = s(x, FLOOR_Y + 0.02, z) * CFrame.Angles(0, yaw, 0)
				table.insert(spots, { CFrame = cf, Front = s(side * 4, FLOOR_Y, z - 2) })
			end
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
	box(m, "Lot", Vector3.new(LOT_HALF * 2, 0.4, lotD), at(0, 0.2, (LOT_Z0 + LOT_Z1) / 2), ASPHALT)
	-- low fence on the sides; the back stays open where the truck backs in
	local function fenceRun(from, to)
		local dir = to - from
		local len = dir.Magnitude
		local mid = (from + to) / 2
		local cf = CFrame.lookAt(mid, mid + dir.Unit)
		for _, y in ipairs({ 1.6, 3.2 }) do
			box(m, "FenceRail", Vector3.new(0.3, 0.5, len), cf * CFrame.new(0, y - mid.Y, 0), Color3.fromRGB(70, 78, 96))
		end
		local posts = math.max(1, math.floor(len / 12))
		for i = 0, posts do
			deco(m, "FencePost", Vector3.new(0.5, 4, 0.5), cf * CFrame.new(0, 2 - mid.Y, -len / 2 + i * len / posts), Color3.fromRGB(70, 78, 96))
		end
	end
	for _, sx in ipairs({ -1, 1 }) do
		fenceRun(v(sx * LOT_HALF, 0, LOT_Z0), v(sx * LOT_HALF, 0, LOT_Z1))
		fenceRun(v(sx * LOT_HALF, 0, LOT_Z1), v(sx * 14, 0, LOT_Z1))
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
	truck(m, at(0, 0, TRUCK_Z) * CFrame.Angles(0, math.pi, 0), Color3.fromRGB(236, 239, 245))
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
	do -- 1: bucket and sponge
		local t = tier(1)
		column(t, "Bucket", 1.6, 1.6, at(WX + 8.5, 1.2, WZ - 6), Color3.fromRGB(60, 130, 220), nil, true)
		deco(t, "Water", Vector3.new(0.05, 1.4, 1.4), at(WX + 8.5, 2, WZ - 6) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(160, 210, 255), Enum.Material.Glass, { Shape = Enum.PartType.Cylinder, Transparency = 0.2 })
		deco(t, "Sponge", Vector3.new(1, 0.6, 0.7), at(WX + 7.4, 0.75, WZ - 6.3), Color3.fromRGB(255, 220, 60))
	end
	do -- 2: garden hose reel
		local t = tier(2)
		box(t, "ReelStand", Vector3.new(0.4, 3, 2.4), at(WX - 8.5, 1.9, WZ - 7), Color3.fromRGB(40, 140, 60))
		local reel = part({ Name = "Reel", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.9, 2.6, 2.6), CFrame = at(WX - 8.2, 2.6, WZ - 7), Color = Color3.fromRGB(60, 170, 70), CanCollide = false, CanQuery = false }, t)
		reel.Size = Vector3.new(0.9, 2.6, 2.6)
	end
	do -- 3: pressure washer cart
		local t = tier(3)
		box(t, "Washer", Vector3.new(2.4, 2.2, 3.2), at(WX + 8.6, 1.6, WZ + 6), Color3.fromRGB(250, 200, 40))
		deco(t, "WasherTop", Vector3.new(2.5, 0.3, 3.3), at(WX + 8.6, 2.8, WZ + 6), Color3.fromRGB(40, 40, 45))
	end
	do -- 4: foam cannon on a stand and blue tiles
		local t = tier(4)
		deco(t, "BlueTiles", Vector3.new(14, 0.08, 20), at(WX, 0.5, WZ), Color3.fromRGB(110, 175, 230))
		box(t, "FoamStand", Vector3.new(0.5, 6, 0.5), at(WX - 8.6, 3.4, WZ + 6), Color3.fromRGB(220, 220, 228), Enum.Material.Metal)
		deco(t, "FoamCannon", Vector3.new(0.9, 0.9, 2.6), at(WX - 8.1, 6.3, WZ + 5.2) * CFrame.Angles(math.rad(-25), 0, 0), Color3.fromRGB(240, 90, 160))
	end
	do -- 5: covered wash bay
		local t = tier(5)
		for _, x in ipairs({ -7.6, 7.6 }) do
			for _, z in ipairs({ -9.6, 9.6 }) do
				box(t, "BayPost", Vector3.new(0.9, 11, 0.9), at(WX + x, 5.9, WZ + z), Color3.fromRGB(240, 242, 246), Enum.Material.Metal)
			end
		end
		deco(t, "BayRoof", Vector3.new(17, 0.8, 21.6), at(WX, 11.6, WZ), Color3.fromRGB(60, 130, 220))
		local sign = deco(t, "BaySign", Vector3.new(10, 2, 0.3), at(WX, 13, WZ - 10.4), Color3.fromRGB(30, 80, 160))
		surfaceText(sign, Enum.NormalId.Front, "CAR WASH", Color3.new(1, 1, 1), 24)
	end
	do -- 6: automatic car wash brushes
		local t = tier(6)
		for _, x in ipairs({ -6.4, 6.4 }) do
			local b = part({ Name = "Brush", Shape = Enum.PartType.Cylinder, Size = Vector3.new(8, 2.4, 2.4), CFrame = at(WX + x, 4.8, WZ - 3) * CFrame.Angles(0, 0, math.rad(90)), Color = Color3.fromRGB(60, 120, 235), Material = Enum.Material.Fabric, CanCollide = false, CanQuery = false }, t)
			b.Size = Vector3.new(8, 2.4, 2.4)
		end
		deco(t, "TopBrush", Vector3.new(12, 2, 2), at(WX, 9.6, WZ + 3), Color3.fromRGB(60, 120, 235), Enum.Material.Fabric)
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
	local tW, tD, tH = 26, 22, 12
	local tireBase = at(TX, 0, TZ) * CFrame.Angles(0, math.pi / 2, 0)
	local function t(x, y, z)
		return tireBase * CFrame.new(x, y, z)
	end
	box(m, "TireFloor", Vector3.new(tW, FLOOR_Y, tD), t(0, FLOOR_Y / 2, 0), Color3.fromRGB(140, 142, 148))
	for _, side in ipairs({ -1, 1 }) do
		box(m, "TireWall", Vector3.new(1, tH, tD), t(side * tW / 2, FLOOR_Y + tH / 2, 0), Color3.fromRGB(190, 72, 62))
	end
	box(m, "TireBack", Vector3.new(tW, tH, 1), t(0, FLOOR_Y + tH / 2, tD / 2), Color3.fromRGB(190, 72, 62))
	box(m, "TireRoof", Vector3.new(tW + 2, 0.8, tD + 2), t(0, FLOOR_Y + tH + 0.4, 0), Color3.fromRGB(70, 74, 84))
	local shopSign = box(m, "TireSign", Vector3.new(14, 2.6, 0.4), t(0, FLOOR_Y + tH - 1.2, -tD / 2 - 0.3), NAVY)
	surfaceText(shopSign, Enum.NormalId.Front, "TIRE SHOP", GOLD, 26)
	local lightPart = deco(m, "ShopLight", Vector3.new(8, 0.3, 1), t(0, FLOOR_Y + tH - 0.5, 0), LAMP, Enum.Material.Neon)
	light(lightPart, 24, 0.5)
	local lift = box(m, "TireLift", Vector3.new(12, 0.12, 18), t(0, FLOOR_Y + 0.06, 0), Color3.fromRGB(120, 124, 132), nil, { CanCollide = false })
	for _, x in ipairs({ -6.6, 6.6 }) do
		box(m, "LiftPost", Vector3.new(1.2, 10, 1.4), t(x, FLOOR_Y + 5, 0), Color3.fromRGB(250, 195, 40))
	end
	deco(m, "LiftTop", Vector3.new(14.4, 0.8, 1.2), t(0, FLOOR_Y + 10.2, 0), Color3.fromRGB(250, 195, 40))
	local liftLabel = label(lift, "TIRE SHOP", Color3.fromRGB(255, 215, 100), 10, 240)
	liftLabel.Parent.Enabled = false

	--=========================== UPGRADE STATIONS (a row just behind the showroom) ===========================
	local function icon(kind, at0)
		local mdl = Instance.new("Model")
		mdl.Name = "StationIcon"
		-- the painted icon artwork floating over the pad
		local imageId = Icons.Images[({ Showroom = "Showroom", Truck = "Truck", Wash = "Sponge", Engine = "Tire" })[kind] or ""]
		if imageId and imageId ~= "" then
			local anchor = deco(mdl, "IconAnchor", Vector3.new(0.2, 0.2, 0.2), at0, Color3.new(1, 1, 1), nil, { Transparency = 1 })
			local bb = Instance.new("BillboardGui")
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
		box(m, name .. "Plinth", Vector3.new(6.6, 0.5, 6.6), base * CFrame.new(0, 0.25, 0), Color3.fromRGB(176, 184, 196), Enum.Material.Concrete, { CanCollide = false })
		local p = box(m, name, Vector3.new(5.6, 0.18, 5.6), base * CFrame.new(0, 0.55, 0), Color3.fromRGB(90, 215, 130), Enum.Material.Neon, { CanCollide = false, Transparency = 0.55 })
		local glow = Instance.new("PointLight")
		glow.Color = Color3.fromRGB(150, 255, 190)
		glow.Range = 9
		glow.Brightness = 0.4
		glow.Parent = p
		local ic = icon(kind, base * CFrame.new(0, 4.4, 0))
		-- the name above the icon and the level under it
		local anchor = deco(m, name .. "Anchor", Vector3.new(0.2, 0.2, 0.2), base * CFrame.new(0, 4.4, 0), Color3.new(1, 1, 1), nil, { Transparency = 1 })
		local title = label(anchor, name, Color3.new(1, 1, 1), 2.6, 140, 45)
		title.Parent.Size = UDim2.new(3.9, 0, 0.95, 0)
		local lv = label(anchor, "Level 1", Color3.fromRGB(255, 225, 120), -2.2, 120, 30)
		lv.Parent.Size = UDim2.new(3.3, 0, 0.7, 0)
		-- price plate on the floor, angled up toward the player
		local plate = box(m, name .. "Price", Vector3.new(5.2, 0.35, 1.8), base * CFrame.new(0, 0.35, -4.9) * CFrame.Angles(math.rad(-14), 0, 0), Color3.fromRGB(60, 200, 80), nil, { CanCollide = false })
		local priceGui = Instance.new("SurfaceGui")
		priceGui.Face = Enum.NormalId.Top
		priceGui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		priceGui.PixelsPerStud = 40
		priceGui.LightInfluence = 0
		local priceText = Instance.new("TextLabel")
		priceText.BackgroundTransparency = 1
		priceText.Size = UDim2.new(1, 0, 1, 0)
		priceText.Font = Enum.Font.FredokaOne
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
		Engine = pad("Tire Luck", 46, 138, 0.4, "Engine"),
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

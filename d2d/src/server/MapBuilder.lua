-- MapBuilder: builds the world and the 6 player plots when the server starts.
-- Style: clean realistic-cartoon town (white plaster buildings, navy trim, black-framed windows,
-- wood ceilings with recessed lights, low-poly trees, terraced cliffs).
-- Each plot, front to back: showroom (by the street) -> workshop (wash bay, engine lift) -> backyard lot.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Lighting = game:GetService("Lighting")
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local MapBuilder = {}

local PLOT_SPACING = 110
local FLOOR_Y = 1
local rng = Random.new(2026)

-- palette
local PLASTER = Color3.fromRGB(236, 233, 224)
local PLASTER_SHADE = Color3.fromRGB(214, 210, 200)
local NAVY = Color3.fromRGB(34, 44, 64)
local STONE = Color3.fromRGB(150, 150, 155)
local TILE = Color3.fromRGB(188, 193, 202)
local GROUT = Color3.fromRGB(140, 146, 158)
local WOOD = Color3.fromRGB(205, 165, 115)
local GLASS = Color3.fromRGB(150, 190, 215)
local LAMP = Color3.fromRGB(255, 250, 238)
local ASPHALT = Color3.fromRGB(96, 98, 104)
local CONCRETE = Color3.fromRGB(196, 196, 200)
local LEAF = { Color3.fromRGB(86, 150, 62), Color3.fromRGB(104, 168, 70), Color3.fromRGB(74, 134, 58), Color3.fromRGB(120, 176, 78) }
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

local function label(adornee, text, color, offsetY, width, maxDist)
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.new(0, width or 220, 0, 48)
	gui.StudsOffset = Vector3.new(0, offsetY or 4, 0)
	gui.MaxDistance = maxDist or 90
	gui.LightInfluence = 0
	local l = Instance.new("TextLabel")
	l.Size = UDim2.new(1, 0, 1, 0)
	l.BackgroundTransparency = 1
	l.Font = Enum.Font.FredokaOne
	l.TextScaled = true
	l.TextColor3 = color or Color3.new(1, 1, 1)
	l.Text = text
	addStroke(l, 2.5)
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
	local green = Color3.fromRGB(80, 140, 70)
	column(parent, "Cypress", height, 2.2, CFrame.new(pos + Vector3.new(0, height / 2 + 0.6, 0)), green, Enum.Material.Grass)
	ball(parent, "CypressTop", 2.2, CFrame.new(pos + Vector3.new(0, height + 0.6, 0)), green, Enum.Material.Grass)
	ball(parent, "CypressBottom", 2.2, CFrame.new(pos + Vector3.new(0, 0.6 + 1.1, 0)), green, Enum.Material.Grass)
end

local function planter(parent, cf, length, withCypress)
	box(parent, "Planter", Vector3.new(length, 1.6, 2.4), cf * CFrame.new(0, 0.8, 0), NAVY)
	deco(parent, "Soil", Vector3.new(length - 0.4, 0.1, 2), cf * CFrame.new(0, 1.62, 0), Color3.fromRGB(80, 60, 45))
	local n = math.max(1, math.floor(length / 2.6))
	for i = 1, n do
		local x = -length / 2 + (i - 0.5) * length / n
		if withCypress and (i == 1 or i == n) then
			cypress(parent, (cf * CFrame.new(x, 1, 0)).Position, 5)
		else
			ball(parent, "Shrub", 2.4, cf * CFrame.new(x, 2.2, 0), LEAF[rng:NextInteger(1, #LEAF)], Enum.Material.Grass)
		end
	end
end

local function streetLamp(parent, pos, facing)
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
	local c = box(parent, "TruckContainer", Vector3.new(7.6, 7, 16), at(0, 6, 2.5), Color3.fromRGB(200, 120, 50), Enum.Material.DiamondPlate)
	surfaceText(c, Enum.NormalId.Left, "D2D LOGISTICS", Color3.new(1, 1, 1), 20)
	surfaceText(c, Enum.NormalId.Right, "D2D LOGISTICS", Color3.new(1, 1, 1), 20)
end

---------------------------------------------------------------------
-- Light and sky
---------------------------------------------------------------------
local function buildLighting()
	Lighting.ClockTime = 13.6
	Lighting.GeographicLatitude = 30
	Lighting.Brightness = 2.6
	Lighting.Ambient = Color3.fromRGB(110, 112, 125)
	Lighting.OutdoorAmbient = Color3.fromRGB(150, 152, 165)
	Lighting.EnvironmentDiffuseScale = 1
	Lighting.EnvironmentSpecularScale = 0.6
	Lighting.ExposureCompensation = 0
	Lighting.ShadowSoftness = 0.2
	for _, c in ipairs(Lighting:GetChildren()) do
		if c:IsA("PostEffect") or c:IsA("Atmosphere") then
			c:Destroy()
		end
	end
	local a = Instance.new("Atmosphere")
	a.Density = 0.22
	a.Offset = 0.15
	a.Color = Color3.fromRGB(205, 225, 255)
	a.Decay = Color3.fromRGB(140, 165, 210)
	a.Glare = 0.1
	a.Haze = 0.6
	a.Parent = Lighting
	local bloom = Instance.new("BloomEffect")
	bloom.Intensity = 0.25
	bloom.Size = 20
	bloom.Threshold = 2.5
	bloom.Parent = Lighting
	local cc = Instance.new("ColorCorrectionEffect")
	cc.Saturation = 0.1
	cc.Contrast = 0.06
	cc.Parent = Lighting
	local rays = Instance.new("SunRaysEffect")
	rays.Intensity = 0.04
	rays.Spread = 0.5
	rays.Parent = Lighting
end

---------------------------------------------------------------------
-- Terrain: grass ground and terraced blue-grey cliffs all around
---------------------------------------------------------------------
local function buildTerrain()
	local terrain = workspace.Terrain
	terrain:Clear()
	terrain:SetMaterialColor(Enum.Material.Grass, Color3.fromRGB(106, 170, 76))
	terrain:SetMaterialColor(Enum.Material.LeafyGrass, Color3.fromRGB(96, 160, 70))
	terrain:SetMaterialColor(Enum.Material.Rock, Color3.fromRGB(118, 128, 152))
	terrain:SetMaterialColor(Enum.Material.Slate, Color3.fromRGB(110, 120, 145))
	terrain:SetMaterialColor(Enum.Material.Ground, Color3.fromRGB(120, 100, 75))
	pcall(function()
		terrain.Decoration = true -- little grass blades
	end)
	-- the ground: terrain surfaces sit about 2 studs above a filled block, so fill to y = -2 to get ground at y = 0
	terrain:FillBlock(CFrame.new(0, -6, 0), Vector3.new(1600, 8, 1200), Enum.Material.Grass)

	-- terraces: each step is rock with a grass top
	local function step(center, size)
		terrain:FillBlock(CFrame.new(center), size, Enum.Material.Rock)
		local top = center + Vector3.new(0, size.Y / 2 + 2, 0)
		terrain:FillBlock(CFrame.new(top), Vector3.new(size.X, 4, size.Z), Enum.Material.Grass)
	end
	-- behind the yards
	step(Vector3.new(0, 10, 150), Vector3.new(1200, 20, 40))
	step(Vector3.new(0, 22, 185), Vector3.new(1200, 44, 40))
	step(Vector3.new(0, 34, 230), Vector3.new(1300, 68, 60))
	-- across the road
	step(Vector3.new(0, 8, -175), Vector3.new(1200, 16, 30))
	step(Vector3.new(0, 18, -205), Vector3.new(1200, 36, 40))
	step(Vector3.new(0, 30, -250), Vector3.new(1300, 60, 60))
	-- left and right ends
	for _, sx in ipairs({ -1, 1 }) do
		step(Vector3.new(sx * 440, 10, -20), Vector3.new(40, 20, 420))
		step(Vector3.new(sx * 475, 24, -20), Vector3.new(40, 48, 460))
		step(Vector3.new(sx * 520, 36, -20), Vector3.new(60, 72, 520))
	end

	-- clouds
	if not terrain:FindFirstChildOfClass("Clouds") then
		local clouds = Instance.new("Clouds")
		clouds.Cover = 0.55
		clouds.Density = 0.6
		clouds.Color = Color3.fromRGB(255, 255, 255)
		clouds.Parent = terrain
	end
end

---------------------------------------------------------------------
-- Street and scenery
---------------------------------------------------------------------
local function buildWorld(map)
	local baseplate = workspace:FindFirstChild("Baseplate")
	if baseplate then
		baseplate:Destroy()
	end
	buildTerrain()
	box(map, "Road", Vector3.new(840, 0.4, 26), CFrame.new(0, 0.2, -108), ASPHALT, Enum.Material.Asphalt)
	for x = -410, 410, 16 do
		deco(map, "RoadLine", Vector3.new(7, 0.05, 0.5), CFrame.new(x, 0.42, -108), Color3.fromRGB(250, 250, 250))
	end
	for _, z in ipairs({ -95.4, -120.6 }) do
		deco(map, "EdgeLine", Vector3.new(840, 0.05, 0.4), CFrame.new(0, 0.42, z), Color3.fromRGB(250, 250, 250))
	end
	box(map, "Sidewalk", Vector3.new(840, 0.8, 8), CFrame.new(0, 0.4, -91.5), CONCRETE, Enum.Material.Concrete)
	box(map, "FarSidewalk", Vector3.new(840, 0.8, 8), CFrame.new(0, 0.4, -125), CONCRETE, Enum.Material.Concrete)
	for x = -416, 416, 8 do
		deco(map, "SidewalkJoint", Vector3.new(0.15, 0.05, 8), CFrame.new(x, 0.81, -91.5), GROUT)
		deco(map, "SidewalkJoint", Vector3.new(0.15, 0.05, 8), CFrame.new(x, 0.81, -125), GROUT)
	end
	for i = 1, Config.MaxPlots - 1 do
		local x = -((Config.MaxPlots - 1) * PLOT_SPACING) / 2 + (i - 0.5) * PLOT_SPACING
		for s = -6, 6, 2 do
			deco(map, "Crosswalk", Vector3.new(1.2, 0.05, 18), CFrame.new(x + s, 0.42, -108), Color3.fromRGB(250, 250, 250))
		end
	end
	for x = -385, 385, 55 do
		streetLamp(map, Vector3.new(x, 0.8, -95), -1)
		streetLamp(map, Vector3.new(x + 27, 0.8, -121.5), 1)
	end
	-- trees along the far sidewalk and behind the yards
	for x = -400, 400, 16 do
		lowPolyTree(map, Vector3.new(x + rng:NextNumber(-3, 3), 0, -137 - rng:NextNumber(0, 10)), rng:NextNumber(0.9, 1.25))
	end
	for x = -400, 400, 14 do
		lowPolyTree(map, Vector3.new(x + rng:NextNumber(-3, 3), 0, 104 + rng:NextNumber(0, 18)), rng:NextNumber(1, 1.4))
	end
	for _, sx in ipairs({ -1, 1 }) do
		for z = -90, 90, 14 do
			lowPolyTree(map, Vector3.new(sx * (395 + rng:NextNumber(0, 15)), 0, z), rng:NextNumber(1, 1.3))
		end
	end
	-- invisible walls around the play area
	for _, w in ipairs({
		{ Vector3.new(4, 80, 260), Vector3.new(-380, 40, -20) },
		{ Vector3.new(4, 80, 260), Vector3.new(380, 40, -20) },
		{ Vector3.new(760, 80, 4), Vector3.new(0, 40, -131) },
		{ Vector3.new(760, 80, 4), Vector3.new(0, 40, 100) },
	}) do
		box(map, "Boundary", w[1], CFrame.new(w[2]), Color3.new(1, 1, 1), nil, { Transparency = 1, CanQuery = false })
	end
	local spawn = Instance.new("SpawnLocation")
	spawn.Anchored = true
	spawn.Size = Vector3.new(8, 1, 8)
	spawn.CFrame = CFrame.new(0, 0.5, -100)
	spawn.Transparency = 1
	spawn.CanCollide = false
	spawn.Duration = 0
	spawn.Parent = map
end

---------------------------------------------------------------------
-- One plot
---------------------------------------------------------------------
local function buildPlot(index, parent)
	local cx = -((Config.MaxPlots - 1) * PLOT_SPACING) / 2 + (index - 1) * PLOT_SPACING
	local m = Instance.new("Model")
	m.Name = "Plot" .. index
	m.Parent = parent
	local function at(x, y, z)
		return CFrame.new(cx + x, y, z)
	end
	local function v(x, y, z)
		return Vector3.new(cx + x, y, z)
	end

	-- grass strip, hedge and trees between plots
	for _, side in ipairs(index == 1 and { -1, 1 } or { 1 }) do
		local hx = side * 55
		deco(m, "Hedge", Vector3.new(3, 3, 140), at(hx, 1.5, -12), Color3.fromRGB(78, 140, 62), Enum.Material.Grass)
		for z = -80, 64, 24 do
			lowPolyTree(m, v(hx + side * 5, 0, z + rng:NextNumber(-4, 4)), rng:NextNumber(0.9, 1.15))
		end
	end

	--=============== SHOWROOM (x -45..45, z -88..-8) ===============
	local TOP = 28 -- building height
	local CEIL = FLOOR_Y + 16 -- showroom ceiling
	box(m, "ShowroomFloor", Vector3.new(90, FLOOR_Y, 80), at(0, FLOOR_Y / 2, -48), TILE)
	-- floor tiles: grout lines every 8 studs and a darker border row
	for x = -40, 40, 8 do
		deco(m, "Grout", Vector3.new(0.18, 0.04, 80), at(x, FLOOR_Y + 0.02, -48), GROUT)
	end
	for z = -84, -12, 8 do
		deco(m, "Grout", Vector3.new(90, 0.04, 0.18), at(0, FLOOR_Y + 0.02, z), GROUT)
	end
	for _, z in ipairs({ -85, -11 }) do
		deco(m, "BorderTiles", Vector3.new(88, 0.03, 4), at(0, FLOOR_Y + 0.015, z), Color3.fromRGB(120, 128, 142))
	end

	-- outer walls: side walls, back wall with a doorway
	for _, x in ipairs({ -45, 45 }) do
		box(m, "Wall", Vector3.new(1.2, TOP - FLOOR_Y, 80), at(x, FLOOR_Y + (TOP - FLOOR_Y) / 2, -48), PLASTER, Enum.Material.Plaster)
		-- inside: pilasters every 16 studs and a navy baseboard
		local inward = x > 0 and -1 or 1
		for z = -80, -16, 16 do
			deco(m, "Pilaster", Vector3.new(1.4, 15.8, 2.2), at(x + inward * 0.9, FLOOR_Y + 7.9, z), PLASTER_SHADE, Enum.Material.Plaster)
		end
		deco(m, "Baseboard", Vector3.new(0.4, 0.8, 80), at(x + inward * 0.75, FLOOR_Y + 0.4, -48), NAVY)
		-- outside: a cornice band
		deco(m, "Cornice", Vector3.new(1.8, 1.2, 80.6), at(x, CEIL + 0.6, -48), PLASTER_SHADE, Enum.Material.Plaster)
	end
	for _, x in ipairs({ -26.5, 26.5 }) do
		box(m, "Wall", Vector3.new(37, TOP - FLOOR_Y, 1.2), at(x, FLOOR_Y + (TOP - FLOOR_Y) / 2, -8), PLASTER, Enum.Material.Plaster)
	end
	box(m, "Wall", Vector3.new(16, TOP - 13, 1.2), at(0, 13 + (TOP - 13) / 2, -8), PLASTER, Enum.Material.Plaster)
	-- doorway frame into the workshop
	for _, x in ipairs({ -8.3, 8.3 }) do
		deco(m, "DoorFrame", Vector3.new(0.7, 12, 1.6), at(x, FLOOR_Y + 6, -8), NAVY)
	end
	deco(m, "DoorFrame", Vector3.new(17.3, 0.7, 1.6), at(0, 13, -8), NAVY)
	local serviceSign = deco(m, "ServiceSign", Vector3.new(10, 1.8, 0.2), at(0, 14.6, -8.7), NAVY)
	surfaceText(serviceSign, Enum.NormalId.Front, "WORKSHOP", GOLD)

	-- the front facade: plinth, pilasters, big windows, cornices, parapet
	local FZ = -88
	box(m, "Plinth", Vector3.new(91, 1.2, 1.6), at(0, FLOOR_Y + 0.6, FZ), STONE, Enum.Material.Concrete)
	for _, x in ipairs({ -44.6, -27, -9, 9, 27, 44.6 }) do
		box(m, "Pilaster", Vector3.new(2.4, TOP - FLOOR_Y, 1.8), at(x, FLOOR_Y + (TOP - FLOOR_Y) / 2, FZ), PLASTER, Enum.Material.Plaster)
		deco(m, "PilasterCap", Vector3.new(3, 0.8, 2.3), at(x, CEIL - 0.4, FZ), PLASTER_SHADE, Enum.Material.Plaster)
	end
	local bays = { { -35.8, 15.2 }, { -18, 15.6 }, { 18, 15.6 }, { 35.8, 15.2 } }
	for _, b in ipairs(bays) do
		-- ground floor: tall shop window
		box(m, "Sill", Vector3.new(b[2], 1, 1.2), at(b[1], FLOOR_Y + 1.7, FZ), PLASTER, Enum.Material.Plaster)
		window(m, at(b[1], FLOOR_Y + 8.3, FZ), b[2] - 0.4, 12.2, 3, 2, 0.55)
		box(m, "Lintel", Vector3.new(b[2], CEIL - (FLOOR_Y + 14.4), 1.2), at(b[1], (CEIL + FLOOR_Y + 14.4) / 2, FZ), PLASTER, Enum.Material.Plaster)
		-- upper floor: smaller dark windows
		window(m, at(b[1], CEIL + 5.3, FZ), b[2] - 3, 6.4, 3, 1, 0.12, Color3.fromRGB(70, 95, 120))
	end
	-- infill walls on the upper floor between and around the windows
	box(m, "UpperWall", Vector3.new(90, TOP - CEIL, 1), at(0, CEIL + (TOP - CEIL) / 2, FZ + 0.7), PLASTER, Enum.Material.Plaster)
	-- cornices and parapet
	deco(m, "Cornice", Vector3.new(92, 1.4, 2.6), at(0, CEIL + 0.7, FZ - 0.2), PLASTER_SHADE, Enum.Material.Plaster)
	deco(m, "Cornice", Vector3.new(92.5, 1.2, 2.8), at(0, TOP - 0.6, FZ - 0.2), PLASTER_SHADE, Enum.Material.Plaster)
	box(m, "Roof", Vector3.new(91, 1, 81), at(0, TOP + 0.5, -48), Color3.fromRGB(70, 72, 80), Enum.Material.Concrete)
	for _, e in ipairs({ { 0, FZ, 92, 1.4 }, { 0, -8, 92, 1.4 }, { -45.3, -48, 1.4, 81 }, { 45.3, -48, 1.4, 81 } }) do
		deco(m, "RoofCap", Vector3.new(e[3], 0.9, e[4]), at(e[1], TOP + 1.3, e[2]), NAVY)
	end
	-- entrance: glass doors (open), transom, canopy with recessed lights
	window(m, at(0, FLOOR_Y + 13.3, FZ), 15.6, 2.4, 2, 1, 0.5)
	box(m, "EntranceLintel", Vector3.new(16, CEIL - (FLOOR_Y + 14.5), 1.2), at(0, (CEIL + FLOOR_Y + 14.5) / 2, FZ), PLASTER, Enum.Material.Plaster)
	for _, side in ipairs({ -1, 1 }) do
		local hinge = at(side * 7.9, FLOOR_Y + 6, FZ + 0.2)
		local leaf = hinge * CFrame.Angles(0, math.rad(side * 70), 0) * CFrame.new(-side * 3.9, 0, 0)
		deco(m, "DoorGlass", Vector3.new(7.6, 11.6, 0.2), leaf, GLASS, Enum.Material.Glass, { Transparency = 0.55, Reflectance = 0.2 })
		deco(m, "DoorFrame", Vector3.new(7.8, 0.4, 0.35), leaf * CFrame.new(0, 5.8, 0), NAVY)
		deco(m, "DoorFrame", Vector3.new(7.8, 0.4, 0.35), leaf * CFrame.new(0, -5.8, 0), NAVY)
		deco(m, "DoorHandle", Vector3.new(0.2, 3, 0.3), leaf * CFrame.new(side * 3.2, 0, -0.3), Color3.fromRGB(210, 210, 215), Enum.Material.Metal)
	end
	deco(m, "Canopy", Vector3.new(22, 1, 7.5), at(0, FLOOR_Y + 14.9, FZ - 3.6), NAVY)
	for _, x in ipairs({ -6, 0, 6 }) do
		local d = deco(m, "CanopyLight", Vector3.new(1.6, 0.1, 1.6), at(x, FLOOR_Y + 14.35, FZ - 4), LAMP, Enum.Material.Neon)
		if x == 0 then
			light(d, 16, 0.8)
		end
	end
	for _, x in ipairs({ -10.5, 10.5 }) do
		box(m, "CanopyPost", Vector3.new(0.8, 14.4, 0.8), at(x, FLOOR_Y + 7.2, FZ - 6.9), NAVY)
	end
	-- the name sign on the upper floor, in the middle bay
	local signBoard = box(m, "SignBoard", Vector3.new(16.6, 7.6, 0.6), at(0, CEIL + 5.3, FZ - 0.4), NAVY)
	deco(m, "SignTrim", Vector3.new(17.4, 8.4, 0.4), at(0, CEIL + 5.3, FZ - 0.25), GOLD, Enum.Material.Metal)
	local signLabel = surfaceText(signBoard, Enum.NormalId.Front, "FOR SALE", GOLD, 24)
	signBoard.CFrame = at(0, CEIL + 5.3, FZ - 0.5)
	-- front steps, planters, bollards
	box(m, "Step", Vector3.new(26, 0.4, 3), at(0, 0.9, FZ - 1.8), CONCRETE, Enum.Material.Concrete)
	for _, x in ipairs({ -35.8, -18, 18, 35.8 }) do
		planter(m, at(x, 0.8, FZ - 2.4), 12, true)
	end

	-- inside: wood ceiling with white coffer beams and recessed lights
	box(m, "Ceiling", Vector3.new(89, 1, 79), at(0, CEIL + 0.5, -48), WOOD, Enum.Material.WoodPlanks)
	for x = -40, 40, 16 do
		deco(m, "CofferBeam", Vector3.new(1.2, 1.2, 79), at(x, CEIL - 0.6, -48), PLASTER)
	end
	for z = -80, -16, 16 do
		deco(m, "CofferBeam", Vector3.new(89, 1.2, 1.2), at(0, CEIL - 0.6, z), PLASTER)
	end
	local lightIndex = 0
	for x = -32, 32, 16 do
		for z = -72, -24, 16 do
			lightIndex = lightIndex + 1
			local d = deco(m, "RecessedLight", Vector3.new(2.4, 0.1, 2.4), at(x, CEIL - 0.05, z), LAMP, Enum.Material.Neon)
			if lightIndex % 3 == 1 then
				light(d, 30, 0.4)
			end
		end
	end
	-- track lights along the walls
	for _, x in ipairs({ -40, 40 }) do
		deco(m, "Track", Vector3.new(0.4, 0.3, 70), at(x, CEIL - 0.2, -48), NAVY)
		for z = -78, -18, 10 do
			local spot = deco(m, "TrackSpot", Vector3.new(0.7, 1.1, 0.7), at(x, CEIL - 0.9, z) * CFrame.Angles(0, 0, math.rad(x > 0 and 25 or -25)), NAVY, Enum.Material.Metal)
			deco(m, "TrackBulb", Vector3.new(0.5, 0.1, 0.5), spot.CFrame * CFrame.new(0, -0.56, 0), LAMP, Enum.Material.Neon)
		end
	end
	-- reception desk, benches, plants
	box(m, "Desk", Vector3.new(9, 3.4, 2.6), at(30, FLOOR_Y + 1.7, -84.6), Color3.fromRGB(245, 245, 245))
	deco(m, "DeskTop", Vector3.new(9.4, 0.3, 3), at(30, FLOOR_Y + 3.55, -84.6), WOOD, Enum.Material.Wood)
	deco(m, "Monitor", Vector3.new(2.4, 1.6, 0.2), at(30, FLOOR_Y + 4.6, -84.2), Color3.fromRGB(25, 25, 30))
	deco(m, "Screen", Vector3.new(2.1, 1.3, 0.05), at(30, FLOOR_Y + 4.6, -84.32), Color3.fromRGB(150, 205, 255), Enum.Material.Neon)
	local logo = deco(m, "DeskLogo", Vector3.new(5, 1.4, 0.1), at(30, FLOOR_Y + 1.9, -85.95), NAVY)
	surfaceText(logo, Enum.NormalId.Front, "D2D MOTORS", GOLD, 30)
	for _, p in ipairs({ { -42, -85 }, { 42, -11 }, { -42, -11 }, { 20, -85 } }) do
		local pot = v(p[1], FLOOR_Y, p[2])
		column(m, "Pot", 2, 2.4, CFrame.new(pot + Vector3.new(0, 1, 0)), NAVY, nil, true)
		cypress(m, pot + Vector3.new(0, 1.4, 0), 4)
	end

	-- display podiums: 8 columns x 5 rows, filled from the front row, center outward
	local spots = {}
	local cols = { -5, 5, -15, 15, -25, 25, -35, 35 }
	local rows = { -74, -60, -46, -32, -18 }
	for _, z in ipairs(rows) do
		for _, x in ipairs(cols) do
			local pad = box(m, "Spot", Vector3.new(8.4, 0.35, 12.8), at(x, FLOOR_Y + 0.18, z), Color3.fromRGB(246, 246, 248), nil, { CanCollide = false, Reflectance = 0.05 })
			local trims = {}
			for _, e in ipairs({ { 0, -6.45, 8.6, 0.2 }, { 0, 6.45, 8.6, 0.2 }, { -4.25, 0, 0.2, 13 }, { 4.25, 0, 0.2, 13 } }) do
				table.insert(trims, deco(m, "SpotTrim", Vector3.new(e[3], 0.38, e[4]), at(x + e[1], FLOOR_Y + 0.19, z + e[2]), NAVY))
			end
			table.insert(spots, { Pad = pad, Trims = trims, CFrame = at(x, FLOOR_Y + 0.36, z), Front = at(x, FLOOR_Y, z - 10) })
		end
	end

	--=============== WORKSHOP (x -45..45, z -8..28) ===============
	local WTOP = FLOOR_Y + 13
	box(m, "WorkshopFloor", Vector3.new(90, FLOOR_Y, 36), at(0, FLOOR_Y / 2, 10), Color3.fromRGB(190, 192, 196), Enum.Material.Concrete)
	for _, x in ipairs({ -45, 45 }) do
		local inward = x > 0 and -1 or 1
		-- wall with a long window strip
		box(m, "Wall", Vector3.new(1.2, 4, 36), at(x, FLOOR_Y + 2, 10), PLASTER_SHADE, Enum.Material.Plaster)
		box(m, "Wall", Vector3.new(1.2, WTOP - (FLOOR_Y + 11), 36), at(x, (WTOP + FLOOR_Y + 11) / 2, 10), PLASTER, Enum.Material.Plaster)
		for _, z in ipairs({ -6.5, 26.5 }) do
			box(m, "Wall", Vector3.new(1.2, 7, 3), at(x, FLOOR_Y + 7.5, z), PLASTER, Enum.Material.Plaster)
		end
		window(m, at(x, FLOOR_Y + 7.5, 10) * CFrame.Angles(0, math.rad(90), 0), 30, 7, 5, 1, 0.45)
		deco(m, "Wainscot", Vector3.new(0.3, 4, 36), at(x + inward * 0.75, FLOOR_Y + 2, 10), Color3.fromRGB(150, 156, 168))
	end
	-- back wall into the yard with a big garage door opening
	for _, x in ipairs({ -36, 36 }) do
		box(m, "Wall", Vector3.new(18, WTOP - FLOOR_Y, 1.2), at(x, FLOOR_Y + (WTOP - FLOOR_Y) / 2, 28), PLASTER, Enum.Material.Plaster)
	end
	box(m, "Wall", Vector3.new(54, 3, 1.2), at(0, WTOP - 1.5, 28), PLASTER, Enum.Material.Plaster)
	local roll = part({ Name = "RollDoor", Shape = Enum.PartType.Cylinder, Size = Vector3.new(54, 2.2, 2.2), CFrame = at(0, WTOP - 3.6, 27), Color = Color3.fromRGB(150, 155, 165), Material = Enum.Material.Metal, CanCollide = false, CanQuery = false }, m)
	roll.Size = Vector3.new(54, 2.2, 2.2)
	for _, x in ipairs({ -27.3, 27.3 }) do
		deco(m, "DoorRail", Vector3.new(0.6, WTOP - FLOOR_Y - 3, 0.8), at(x, FLOOR_Y + (WTOP - FLOOR_Y - 3) / 2, 28.6), NAVY)
	end
	local yardSign = deco(m, "YardSign", Vector3.new(12, 1.8, 0.2), at(0, WTOP - 1.5, 28.7), NAVY)
	surfaceText(yardSign, Enum.NormalId.Back, "BACKYARD", GOLD)
	-- roof and wood ceiling with hanging tube lights
	box(m, "Roof", Vector3.new(91, 1, 37), at(0, WTOP + 0.5, 10), Color3.fromRGB(70, 72, 80), Enum.Material.Concrete)
	deco(m, "Ceiling", Vector3.new(89, 0.4, 35), at(0, WTOP - 0.2, 10), WOOD, Enum.Material.WoodPlanks)
	for _, e in ipairs({ { 0, 28.4, 92, 1.2 }, { -45.3, 10, 1.2, 37 }, { 45.3, 10, 1.2, 37 } }) do
		deco(m, "RoofCap", Vector3.new(e[3], 0.9, e[4]), at(e[1], WTOP + 1.3, e[2]), NAVY)
	end
	for _, x in ipairs({ -30, -15, 0, 15, 30 }) do
		for _, z in ipairs({ 2, 18 }) do
			local tube = deco(m, "TubeLight", Vector3.new(7, 0.35, 0.7), at(x, WTOP - 2.2, z), LAMP, Enum.Material.Neon)
			deco(m, "TubeHousing", Vector3.new(7.3, 0.3, 1), at(x, WTOP - 1.9, z), Color3.fromRGB(220, 222, 228), Enum.Material.Metal)
			for _, w in ipairs({ -3, 3 }) do
				deco(m, "Wire", Vector3.new(0.08, 1.8, 0.08), at(x + w, WTOP - 1, z), Color3.fromRGB(40, 40, 45))
			end
			if x % 30 == 0 then
				light(tube, 26, 0.7)
			end
		end
	end
	-- pegboard with tools, shelves with boxes, a workbench
	deco(m, "Pegboard", Vector3.new(0.3, 5, 12), at(-44.2, FLOOR_Y + 8, 20), Color3.fromRGB(60, 65, 75))
	for i = 0, 5 do
		local z = 15 + i * 2
		deco(m, "Tool", Vector3.new(0.2, 1.8 + (i % 3) * 0.4, 0.25), at(-43.95, FLOOR_Y + 8, z), Color3.fromRGB(205, 205, 210), Enum.Material.Metal)
		deco(m, "ToolGrip", Vector3.new(0.25, 0.8, 0.35), at(-43.9, FLOOR_Y + 7.1 - (i % 3) * 0.2, z), i % 2 == 0 and Color3.fromRGB(220, 60, 50) or Color3.fromRGB(240, 190, 40))
	end
	for _, z in ipairs({ 6, 13 }) do
		for _, y in ipairs({ 0.8, 3.4, 6 }) do
			deco(m, "Shelf", Vector3.new(2.4, 0.2, 6), at(43, FLOOR_Y + y, z), Color3.fromRGB(110, 115, 125), Enum.Material.Metal)
		end
		for _, dz in ipairs({ -3, 3 }) do
			deco(m, "ShelfPost", Vector3.new(0.25, 6.6, 0.25), at(42, FLOOR_Y + 3.3, z + dz), NAVY)
			deco(m, "ShelfPost", Vector3.new(0.25, 6.6, 0.25), at(44, FLOOR_Y + 3.3, z + dz), NAVY)
		end
		cardboardBox(m, at(43, FLOOR_Y + 1.7, z - 1.3), 1.8)
		cardboardBox(m, at(43, FLOOR_Y + 1.6, z + 1.4), 1.6)
		cardboardBox(m, at(43, FLOOR_Y + 4.2, z), 1.9)
		cardboardBox(m, at(43, FLOOR_Y + 6.8, z + 1.2), 1.5)
	end
	box(m, "Workbench", Vector3.new(10, 0.5, 3), at(-28, FLOOR_Y + 3.2, -5.5), WOOD, Enum.Material.Wood)
	for _, x in ipairs({ -32.5, -23.5 }) do
		deco(m, "BenchLeg", Vector3.new(0.5, 3, 2.6), at(x, FLOOR_Y + 1.5, -5.5), NAVY, Enum.Material.Metal)
	end
	deco(m, "Vise", Vector3.new(1, 0.8, 1), at(-31, FLOOR_Y + 3.85, -5.5), Color3.fromRGB(60, 90, 160), Enum.Material.Metal)
	cardboardBox(m, at(-25, FLOOR_Y + 4.1, -5.6), 1.4)
	box(m, "ToolCabinet", Vector3.new(2.2, 4.4, 5), at(42.8, FLOOR_Y + 2.2, -2.5), Color3.fromRGB(205, 45, 45), nil, { Reflectance = 0.08 })
	for i = 0, 3 do
		deco(m, "Drawer", Vector3.new(0.1, 0.12, 4.4), at(41.65, FLOOR_Y + 1 + i, -2.5), Color3.fromRGB(225, 225, 230), Enum.Material.Metal)
	end
	for i = 1, 4 do
		local t = part({ Name = "Tire", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.9, 2.6, 2.6), CFrame = at(-42.4, FLOOR_Y + i - 0.5, 5) * CFrame.Angles(0, 0, math.rad(90)), Color = Color3.fromRGB(28, 28, 30), Material = Enum.Material.Rubber, CanCollide = true }, m)
		t.Size = Vector3.new(0.9, 2.6, 2.6)
	end

	-- wash bay: tiled floor, drain, wash gantry with brushes
	local wash = box(m, "WashBay", Vector3.new(14, 0.12, 22), at(-15, FLOOR_Y + 0.06, 10), Color3.fromRGB(150, 200, 230), nil, { CanCollide = false })
	for x = -6, 6, 2 do
		deco(m, "WashGrout", Vector3.new(0.12, 0.13, 22), at(-15 + x, FLOOR_Y + 0.07, 10), Color3.fromRGB(110, 160, 200))
	end
	for z = -10, 10, 2 do
		deco(m, "WashGrout", Vector3.new(14, 0.13, 0.12), at(-15, FLOOR_Y + 0.07, 10 + z), Color3.fromRGB(110, 160, 200))
	end
	deco(m, "Drain", Vector3.new(1.4, 0.14, 12), at(-15, FLOOR_Y + 0.08, 10), Color3.fromRGB(70, 75, 85), Enum.Material.DiamondPlate)
	for _, x in ipairs({ -7.4, 7.4 }) do
		box(m, "GantryPost", Vector3.new(1, 10, 1.4), at(-15 + x, FLOOR_Y + 5, -0.5), Color3.fromRGB(240, 242, 246), Enum.Material.Metal)
		local brush = part({ Name = "Brush", Shape = Enum.PartType.Cylinder, Size = Vector3.new(7, 2, 2), CFrame = at(-15 + x * 0.86, FLOOR_Y + 3.8, 1.6) * CFrame.Angles(0, 0, math.rad(90)), Color = Color3.fromRGB(60, 120, 230), Material = Enum.Material.Fabric, CanCollide = false, CanQuery = false }, m)
		brush.Size = Vector3.new(7, 2, 2)
	end
	deco(m, "GantryTop", Vector3.new(16, 1.6, 1.8), at(-15, FLOOR_Y + 10.6, -0.5), Color3.fromRGB(240, 242, 246), Enum.Material.Metal)
	deco(m, "GantryStripe", Vector3.new(16.1, 0.5, 1.85), at(-15, FLOOR_Y + 10.3, -0.5), Color3.fromRGB(60, 120, 230))
	local washSign = deco(m, "WashSign", Vector3.new(9, 1.4, 0.2), at(-15, FLOOR_Y + 10.6, 0.5), Color3.fromRGB(60, 120, 230))
	surfaceText(washSign, Enum.NormalId.Back, "CAR WASH", Color3.new(1, 1, 1))
	local washLabel = label(wash, "WASH BAY", Color3.fromRGB(150, 220, 255), 9, 240)

	-- engine lift: two yellow posts with arms
	local lift = box(m, "EngineLift", Vector3.new(14, 0.12, 22), at(15, FLOOR_Y + 0.06, 10), Color3.fromRGB(120, 124, 132), Enum.Material.DiamondPlate, { CanCollide = false })
	for _, x in ipairs({ -7.4, 7.4 }) do
		box(m, "LiftPost", Vector3.new(1.4, 11, 1.6), at(15 + x, FLOOR_Y + 5.5, 10), Color3.fromRGB(250, 195, 40))
		deco(m, "LiftBase", Vector3.new(2.6, 0.4, 2.6), at(15 + x, FLOOR_Y + 0.2, 10), NAVY)
		for _, z in ipairs({ 6.5, 13.5 }) do
			deco(m, "LiftArm", Vector3.new(4.4, 0.35, 0.6), at(15 + x * 0.72, FLOOR_Y + 1.25, z), Color3.fromRGB(60, 62, 70), Enum.Material.Metal)
		end
	end
	deco(m, "LiftTop", Vector3.new(16.2, 0.9, 1.4), at(15, FLOOR_Y + 11.3, 10), Color3.fromRGB(250, 195, 40))
	for _, z in ipairs({ -1, 21 }) do
		deco(m, "HazardLine", Vector3.new(14, 0.13, 0.5), at(15, FLOOR_Y + 0.07, z), Color3.fromRGB(250, 195, 40))
	end
	local liftLabel = label(lift, "ENGINE LIFT", Color3.fromRGB(255, 215, 100), 10, 240)

	--=============== BACKYARD LOT (z 28..70) ===============
	box(m, "Yard", Vector3.new(90, 0.4, 42), at(0, 0.2, 49), ASPHALT, Enum.Material.Asphalt)
	local yardSlots = {}
	for _, z in ipairs({ 40, 59 }) do
		for _, x in ipairs({ -28, -14, 0, 14, 28 }) do
			table.insert(yardSlots, at(x, 0.4, z))
		end
		for _, x in ipairs({ -35, -21, -7, 7, 21, 35 }) do
			deco(m, "LotLine", Vector3.new(0.35, 0.05, 15), at(x, 0.42, z), Color3.fromRGB(245, 245, 245))
		end
	end
	-- curb and modern slat fence
	for _, x in ipairs({ -45, 45 }) do
		box(m, "Curb", Vector3.new(1, 0.8, 42), at(x, 0.4, 49), CONCRETE, Enum.Material.Concrete)
	end
	local function fenceRun(from, to)
		local dir = (to - from)
		local len = dir.Magnitude
		local mid = (from + to) / 2
		local cf = CFrame.lookAt(mid, mid + dir.Unit)
		for _, y in ipairs({ 1.4, 2.6, 3.8, 5 }) do
			box(m, "FenceSlat", Vector3.new(0.3, 0.7, len), cf * CFrame.new(0, y - mid.Y, 0), Color3.fromRGB(55, 62, 78))
		end
		local posts = math.floor(len / 7)
		for i = 0, posts do
			deco(m, "FencePost", Vector3.new(0.5, 6, 0.5), cf * CFrame.new(0, 3 - mid.Y, -len / 2 + i * len / posts), NAVY, Enum.Material.Metal)
		end
	end
	fenceRun(v(-45, 0, 28.6), v(-45, 0, 70))
	fenceRun(v(45, 0, 28.6), v(45, 0, 70))
	fenceRun(v(-45, 0, 70), v(-12, 0, 70))
	fenceRun(v(12, 0, 70), v(45, 0, 70))
	for _, x in ipairs({ -12, 12 }) do
		box(m, "GatePost", Vector3.new(1.2, 7, 1.2), at(x, 3.5, 70), NAVY)
	end
	for _, x in ipairs({ -40, -20, 20, 40 }) do
		box(m, "Bollard", Vector3.new(0.8, 2.4, 0.8), at(x, 1.2, 30), Color3.fromRGB(250, 200, 40))
	end
	-- the delivery truck waiting behind the gate
	box(m, "Driveway", Vector3.new(22, 0.3, 30), at(0, 0.15, 85), ASPHALT, Enum.Material.Asphalt)
	truck(m, at(0, 0, 86) * CFrame.Angles(0, math.rad(180), 0), Color3.fromRGB(230, 70, 60))

	-- upgrade pads: like Clean a Painting, a soft glowing pad on the floor
	local function pad(name, x, z, color, y)
		y = y or FLOOR_Y + 0.08
		local p = box(m, name, Vector3.new(6, 0.16, 6), at(x, y, z), color, Enum.Material.Neon, { CanCollide = false, Transparency = 0.2 })
		deco(m, name .. "Edge", Vector3.new(6.6, 0.12, 6.6), at(x, y - 0.03, z), Color3.fromRGB(255, 255, 255))
		local l = label(p, name, Color3.new(1, 1, 1), 4.5, 260, 60)
		return { Part = p, Label = l }
	end
	local pads = {
		Showroom = pad("Showroom", -36, 0, Color3.fromRGB(120, 230, 150)),
		Wash = pad("Wash Tools", -36, 20, Color3.fromRGB(120, 200, 255)),
		Engine = pad("Engine Luck", 36, 20, Color3.fromRGB(255, 200, 90)),
		Truck = pad("Truck", 36, 34, Color3.fromRGB(255, 130, 120), 0.48),
	}

	return {
		Index = index,
		CenterX = cx,
		Model = m,
		Spots = spots,
		WashCFrame = at(-15, FLOOR_Y + 0.12, 10),
		LiftCFrame = at(15, FLOOR_Y + 1.4, 10),
		WashLabel = washLabel,
		LiftLabel = liftLabel,
		YardSlots = yardSlots,
		Pads = pads,
		SignLabel = signLabel,
		SpawnCFrame = CFrame.lookAt(Vector3.new(cx, 4, 31), Vector3.new(cx, 4, 60)),
		DoorOutside = Vector3.new(cx, FLOOR_Y + 2.5, -96),
		DoorInside = Vector3.new(cx, FLOOR_Y + 2.5, -84),
	}
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

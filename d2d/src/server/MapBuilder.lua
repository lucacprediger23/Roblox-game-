-- MapBuilder: builds the street and the 6 player plots when the server starts.
-- Each plot, front to back: showroom (by the street) -> service (wash bay, engine lift) -> backyard.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Lighting = game:GetService("Lighting")
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local MapBuilder = {}

local PLOT_SPACING = 110
local FLOOR_Y = 1

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

local function label(adornee, text, color, offsetY, width, maxDist)
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.new(0, width or 220, 0, 50)
	gui.StudsOffset = Vector3.new(0, offsetY or 4, 0)
	gui.MaxDistance = maxDist or 90
	gui.LightInfluence = 0
	local l = Instance.new("TextLabel")
	l.Size = UDim2.new(1, 0, 1, 0)
	l.BackgroundTransparency = 1
	l.Font = Enum.Font.FredokaOne
	l.TextScaled = true
	l.TextColor3 = color or Color3.new(1, 1, 1)
	l.TextStrokeTransparency = 0.2
	l.Text = text
	l.Parent = gui
	gui.Parent = adornee
	return l
end

local function surfaceText(p, face, text, color)
	local gui = Instance.new("SurfaceGui")
	gui.Face = face
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 30
	gui.LightInfluence = 0
	local l = Instance.new("TextLabel")
	l.Size = UDim2.new(1, 0, 1, 0)
	l.BackgroundTransparency = 1
	l.Font = Enum.Font.FredokaOne
	l.TextScaled = true
	l.TextColor3 = color or Color3.new(1, 1, 1)
	l.TextStrokeTransparency = 0.3
	l.Text = text
	l.Parent = gui
	gui.Parent = p
	return l
end

local function buildLighting()
	Lighting.ClockTime = 14.5
	Lighting.Brightness = 2.5
	Lighting.OutdoorAmbient = Color3.fromRGB(140, 140, 150)
	if not Lighting:FindFirstChildOfClass("Atmosphere") then
		local a = Instance.new("Atmosphere")
		a.Density = 0.2
		a.Color = Color3.fromRGB(220, 230, 245)
		a.Parent = Lighting
	end
end

local function buildWorld(map)
	-- remove the default baseplate if the place has one
	local baseplate = workspace:FindFirstChild("Baseplate")
	if baseplate then
		baseplate:Destroy()
	end
	part({ Name = "Ground", Size = Vector3.new(760, 4, 260), CFrame = CFrame.new(0, -2, -25), Color = Color3.fromRGB(110, 170, 90), Material = Enum.Material.Grass }, map)
	part({ Name = "Road", Size = Vector3.new(760, 0.2, 26), CFrame = CFrame.new(0, 0.1, -108), Color = Color3.fromRGB(55, 55, 60), Material = Enum.Material.Asphalt }, map)
	for x = -360, 360, 20 do
		part({ Name = "RoadLine", Size = Vector3.new(8, 0.05, 0.6), CFrame = CFrame.new(x, 0.22, -108), Color = Color3.fromRGB(240, 220, 90) }, map)
	end
	part({ Name = "Sidewalk", Size = Vector3.new(760, 0.6, 8), CFrame = CFrame.new(0, 0.3, -91), Color = Color3.fromRGB(190, 190, 195), Material = Enum.Material.Concrete }, map)
	local walls = {
		{ Vector3.new(4, 60, 260), Vector3.new(-380, 30, -25) },
		{ Vector3.new(4, 60, 260), Vector3.new(380, 30, -25) },
		{ Vector3.new(760, 60, 4), Vector3.new(0, 30, -125) },
		{ Vector3.new(760, 60, 4), Vector3.new(0, 30, 105) },
	}
	for _, w in ipairs(walls) do
		part({ Name = "Boundary", Size = w[1], CFrame = CFrame.new(w[2]), Transparency = 1 }, map)
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

local function buildPlot(index, parent)
	local cx = -((Config.MaxPlots - 1) * PLOT_SPACING) / 2 + (index - 1) * PLOT_SPACING
	local m = Instance.new("Model")
	m.Name = "Plot" .. index
	m.Parent = parent
	local function at(x, y, z)
		return CFrame.new(cx + x, y, z)
	end
	local white = Color3.fromRGB(240, 240, 240)
	local glassColor = Color3.fromRGB(170, 210, 240)

	-- SHOWROOM (z -88 .. -8)
	part({ Name = "ShowroomFloor", Size = Vector3.new(90, FLOOR_Y, 80), CFrame = at(0, FLOOR_Y / 2, -48), Color = Color3.fromRGB(225, 225, 230), Material = Enum.Material.Marble }, m)
	part({ Name = "Wall", Size = Vector3.new(1, 14, 80), CFrame = at(-45, 8, -48), Color = white }, m)
	part({ Name = "Wall", Size = Vector3.new(1, 14, 80), CFrame = at(45, 8, -48), Color = white }, m)
	-- glass front with a door gap
	for _, x in ipairs({ -26.5, 26.5 }) do
		part({ Name = "Glass", Size = Vector3.new(37, 14, 0.6), CFrame = at(x, 8, -88), Color = glassColor, Material = Enum.Material.Glass, Transparency = 0.6 }, m)
	end
	part({ Name = "DoorFrame", Size = Vector3.new(16, 3, 0.8), CFrame = at(0, 13.5, -88), Color = white }, m)
	-- back wall with an opening into the service area
	for _, x in ipairs({ -26.5, 26.5 }) do
		part({ Name = "Wall", Size = Vector3.new(37, 14, 1), CFrame = at(x, 8, -8), Color = white }, m)
	end
	local sign = part({ Name = "Sign", Size = Vector3.new(40, 6, 0.5), CFrame = at(0, 19, -88.4), Color = Color3.fromRGB(30, 30, 40) }, m)
	local signLabel = surfaceText(sign, Enum.NormalId.Front, "FOR SALE", Color3.fromRGB(255, 210, 60))

	-- display spots: 8 columns x 5 rows, filled from the front row, center outward
	local spots = {}
	local cols = { -5, 5, -15, 15, -25, 25, -35, 35 }
	local rows = { -74, -60, -46, -32, -18 }
	for _, z in ipairs(rows) do
		for _, x in ipairs(cols) do
			local pad = part({ Name = "Spot", Size = Vector3.new(8.5, 0.2, 15), CFrame = at(x, FLOOR_Y + 0.1, z), Color = Color3.fromRGB(60, 60, 70), CanCollide = false }, m)
			table.insert(spots, { Pad = pad, CFrame = at(x, FLOOR_Y + 0.2, z), Front = at(x, FLOOR_Y, z - 10) })
		end
	end

	-- SERVICE (z -8 .. 28)
	part({ Name = "ServiceFloor", Size = Vector3.new(90, FLOOR_Y, 36), CFrame = at(0, FLOOR_Y / 2, 10), Color = Color3.fromRGB(150, 150, 155), Material = Enum.Material.Concrete }, m)
	part({ Name = "Wall", Size = Vector3.new(1, 10, 36), CFrame = at(-45, 6, 10), Color = Color3.fromRGB(200, 200, 205) }, m)
	part({ Name = "Wall", Size = Vector3.new(1, 10, 36), CFrame = at(45, 6, 10), Color = Color3.fromRGB(200, 200, 205) }, m)
	local wash = part({ Name = "WashBay", Size = Vector3.new(12, 0.4, 20), CFrame = at(-15, FLOOR_Y + 0.2, 10), Color = Color3.fromRGB(70, 160, 230), CanCollide = false }, m)
	local washLabel = label(wash, "WASH BAY", Color3.fromRGB(120, 210, 255), 9, 240)
	local lift = part({ Name = "EngineLift", Size = Vector3.new(12, 0.4, 20), CFrame = at(15, FLOOR_Y + 0.2, 10), Color = Color3.fromRGB(230, 170, 40), CanCollide = false }, m)
	for _, x in ipairs({ -7, 7 }) do
		part({ Name = "LiftPost", Size = Vector3.new(0.8, 8, 0.8), CFrame = at(15 + x, FLOOR_Y + 4, 10), Color = Color3.fromRGB(230, 170, 40), Material = Enum.Material.Metal }, m)
	end
	local liftLabel = label(lift, "ENGINE LIFT", Color3.fromRGB(255, 210, 90), 9, 240)

	-- BACKYARD (z 28 .. 70)
	part({ Name = "Yard", Size = Vector3.new(90, 0.4, 42), CFrame = at(0, 0.2, 49), Color = Color3.fromRGB(165, 155, 140), Material = Enum.Material.Pebble }, m)
	for _, x in ipairs({ -45, 45 }) do
		part({ Name = "Fence", Size = Vector3.new(0.5, 4, 42), CFrame = at(x, 2, 49), Color = Color3.fromRGB(120, 90, 60), Material = Enum.Material.Wood }, m)
	end
	part({ Name = "Fence", Size = Vector3.new(90, 4, 0.5), CFrame = at(0, 2, 70), Color = Color3.fromRGB(120, 90, 60), Material = Enum.Material.Wood }, m)
	local yardSlots = {}
	for _, z in ipairs({ 40, 59 }) do
		for _, x in ipairs({ -28, -14, 0, 14, 28 }) do
			table.insert(yardSlots, at(x, 0.4, z))
		end
	end

	-- upgrade pads
	local function pad(name, x, z, color)
		local p = part({ Name = name, Size = Vector3.new(6, 0.4, 6), CFrame = at(x, FLOOR_Y + 0.2, z), Color = color, Material = Enum.Material.Neon, CanCollide = false }, m)
		local l = label(p, name, Color3.new(1, 1, 1), 4.5, 260, 60)
		return { Part = p, Label = l }
	end
	local pads = {
		Showroom = pad("Showroom", -36, 0, Color3.fromRGB(90, 220, 120)),
		Wash = pad("Wash Tools", -36, 20, Color3.fromRGB(70, 170, 255)),
		Engine = pad("Engine Luck", 36, 20, Color3.fromRGB(255, 180, 40)),
		Truck = pad("Truck", 36, 33, Color3.fromRGB(240, 90, 90)),
	}
	pads.Truck.Part.CFrame = at(36, 0.6, 33)

	return {
		Index = index,
		CenterX = cx,
		Model = m,
		Spots = spots,
		WashCFrame = at(-15, FLOOR_Y + 0.4, 10),
		LiftCFrame = at(15, FLOOR_Y + 0.4, 10),
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

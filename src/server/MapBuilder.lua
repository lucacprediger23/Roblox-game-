-- MapBuilder: builds the whole map from code when the server starts.
-- Bases sit in a row at the south end; the egg field stretches north (toward negative Z)
-- through three zones that get rarer and more dangerous the farther you go.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Lighting = game:GetService("Lighting")
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local MapBuilder = {}

local PLOT_SIZE = 40
local PLOT_SPACING = 50
local PLOT_Z = 70 -- centre of the plot row
local FLOOR_TOP = 1 -- plots are 1 stud above the ground

local plotColors = {
	Color3.fromRGB(255, 205, 220),
	Color3.fromRGB(205, 230, 255),
	Color3.fromRGB(255, 240, 190),
	Color3.fromRGB(210, 245, 210),
	Color3.fromRGB(235, 215, 255),
	Color3.fromRGB(255, 220, 190),
	Color3.fromRGB(200, 245, 240),
	Color3.fromRGB(245, 245, 245),
}

local function part(props, parent)
	local p = Instance.new(props.ClassName or "Part")
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Material = Enum.Material.SmoothPlastic
	for key, value in pairs(props) do
		if key ~= "ClassName" and key ~= "Shape" then
			p[key] = value
		end
	end
	if props.Shape then
		p.Shape = props.Shape
		if props.Size then
			p.Size = props.Size
		end
	end
	p.Parent = parent
	return p
end

-- Vertical cylinder centred at `pos`
local function cylinder(name, diameter, height, pos, color, parent)
	local p = part({
		Name = name,
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(height, diameter, diameter),
		CFrame = CFrame.new(pos) * CFrame.Angles(0, 0, math.rad(90)),
		Color = color,
	}, parent)
	return p
end

local function addSignText(signPart, face, text, textColor)
	local gui = Instance.new("SurfaceGui")
	gui.Face = face
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	gui.LightInfluence = 0
	local label = Instance.new("TextLabel")
	label.Name = "Text"
	label.Size = UDim2.new(1, 0, 1, 0)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.Text = text
	label.TextColor3 = textColor or Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0.3
	label.Parent = gui
	gui.Parent = signPart
	return label
end

local function buildLighting()
	Lighting.ClockTime = 14
	Lighting.Brightness = 2.5
	Lighting.OutdoorAmbient = Color3.fromRGB(150, 140, 160)
	if not Lighting:FindFirstChildOfClass("Atmosphere") then
		local atmosphere = Instance.new("Atmosphere")
		atmosphere.Density = 0.25
		atmosphere.Color = Color3.fromRGB(255, 230, 245)
		atmosphere.Decay = Color3.fromRGB(200, 180, 255)
		atmosphere.Parent = Lighting
	end
end

local function buildGround(map)
	part({
		Name = "Ground",
		Size = Vector3.new(800, 4, 800),
		CFrame = CFrame.new(0, -2, -150),
		Color = Color3.fromRGB(150, 215, 140),
		Material = Enum.Material.Grass,
	}, map)

	-- Path between the bases and the field
	part({
		Name = "Path",
		Size = Vector3.new(2 * Config.FieldHalfWidth + 60, 0.2, 70),
		CFrame = CFrame.new(0, 0.1, 15),
		Color = Color3.fromRGB(250, 235, 210),
	}, map)

	-- Invisible walls so nobody wanders off the map
	local walls = {
		{ Vector3.new(4, 60, 560), Vector3.new(-215, 30, -165) },
		{ Vector3.new(4, 60, 560), Vector3.new(215, 30, -165) },
		{ Vector3.new(434, 60, 4), Vector3.new(0, 30, -445) },
		{ Vector3.new(434, 60, 4), Vector3.new(0, 30, 113) },
	}
	for _, w in ipairs(walls) do
		part({ Name = "Boundary", Size = w[1], CFrame = CFrame.new(w[2]), Transparency = 1 }, map)
	end

	local spawn = Instance.new("SpawnLocation")
	spawn.Anchored = true
	spawn.Size = Vector3.new(8, 1, 8)
	spawn.CFrame = CFrame.new(0, 0.5, 20)
	spawn.Duration = 0
	spawn.Transparency = 1
	spawn.CanCollide = false
	spawn.Parent = map
end

local function buildPlot(index, parent)
	local cx = -((Config.MaxPlots - 1) * PLOT_SPACING) / 2 + (index - 1) * PLOT_SPACING
	local folder = Instance.new("Model")
	folder.Name = "Plot" .. index
	folder.Parent = parent

	local color = plotColors[(index - 1) % #plotColors + 1]
	local frontZ = PLOT_Z - PLOT_SIZE / 2
	local backZ = PLOT_Z + PLOT_SIZE / 2

	part({
		Name = "Floor",
		Size = Vector3.new(PLOT_SIZE, FLOOR_TOP, PLOT_SIZE),
		CFrame = CFrame.new(cx, FLOOR_TOP / 2, PLOT_Z),
		Color = color,
	}, folder)

	-- Low walls on the sides and back
	local wallColor = color:Lerp(Color3.new(0, 0, 0), 0.15)
	part({ Name = "Wall", Size = Vector3.new(1, 4, PLOT_SIZE), CFrame = CFrame.new(cx - PLOT_SIZE / 2, FLOOR_TOP + 2, PLOT_Z), Color = wallColor }, folder)
	part({ Name = "Wall", Size = Vector3.new(1, 4, PLOT_SIZE), CFrame = CFrame.new(cx + PLOT_SIZE / 2, FLOOR_TOP + 2, PLOT_Z), Color = wallColor }, folder)
	part({ Name = "Wall", Size = Vector3.new(PLOT_SIZE, 4, 1), CFrame = CFrame.new(cx, FLOOR_TOP + 2, backZ), Color = wallColor }, folder)

	-- Owner sign on the back wall
	local sign = part({
		Name = "Sign",
		Size = Vector3.new(18, 4, 0.5),
		CFrame = CFrame.new(cx, FLOOR_TOP + 6.5, backZ - 0.2),
		Color = Color3.fromRGB(255, 255, 255),
	}, folder)
	local signLabel = addSignText(sign, Enum.NormalId.Front, "Empty Base", Color3.fromRGB(255, 120, 170))

	-- Lock barrier across the open front (only visible while locked)
	local barrier = part({
		Name = "Barrier",
		Size = Vector3.new(PLOT_SIZE, 8, 0.6),
		CFrame = CFrame.new(cx, FLOOR_TOP + 4, frontZ),
		Color = Color3.fromRGB(255, 70, 110),
		Material = Enum.Material.ForceField,
		Transparency = 1,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
	}, folder)

	-- Pedestals: two rows of five
	local pedestals = {}
	local xs = { -14, -7, 0, 7, 14 }
	local rows = { PLOT_Z - 6, PLOT_Z + 10 }
	for _, z in ipairs(rows) do
		for _, xOffset in ipairs(xs) do
			local pedestalTop = FLOOR_TOP + 1
			local ped = cylinder("Pedestal", 4.5, 1, Vector3.new(cx + xOffset, FLOOR_TOP + 0.5, z), Color3.fromRGB(255, 255, 255), folder)
			table.insert(pedestals, {
				Part = ped,
				Surface = CFrame.new(cx + xOffset, pedestalTop, z),
			})
		end
	end

	-- Collect pad near the entrance
	local pad = part({
		Name = "CollectPad",
		Size = Vector3.new(6, 0.3, 6),
		CFrame = CFrame.new(cx, FLOOR_TOP + 0.15, frontZ + 6),
		Color = Color3.fromRGB(90, 230, 120),
		Material = Enum.Material.Neon,
		CanCollide = false,
	}, folder)
	local padGui = Instance.new("BillboardGui")
	padGui.Size = UDim2.new(0, 160, 0, 40)
	padGui.StudsOffset = Vector3.new(0, 3, 0)
	padGui.MaxDistance = 70
	padGui.LightInfluence = 0
	local padLabel = Instance.new("TextLabel")
	padLabel.Size = UDim2.new(1, 0, 1, 0)
	padLabel.BackgroundTransparency = 1
	padLabel.Font = Enum.Font.FredokaOne
	padLabel.TextScaled = true
	padLabel.TextColor3 = Color3.fromRGB(255, 230, 90)
	padLabel.TextStrokeTransparency = 0.2
	padLabel.Text = "Collect: 0"
	padLabel.Parent = padGui
	padGui.Parent = pad

	return {
		Index = index,
		Model = folder,
		CenterX = cx,
		Pedestals = pedestals,
		CollectPad = pad,
		CollectLabel = padLabel,
		SignLabel = signLabel,
		Barrier = barrier,
		SpawnCFrame = CFrame.lookAt(Vector3.new(cx, FLOOR_TOP + 3, PLOT_Z + 4), Vector3.new(cx, FLOOR_TOP + 3, 0)),
		MinX = cx - PLOT_SIZE / 2,
		MaxX = cx + PLOT_SIZE / 2,
		MinZ = frontZ,
		MaxZ = backZ,
		FrontZ = frontZ,
	}
end

local function decorate(zoneIndex, zone, folder, rng)
	local count = 10
	for _ = 1, count do
		local x = rng:NextNumber(-Config.FieldHalfWidth + 5, Config.FieldHalfWidth - 5)
		local z = rng:NextNumber(zone.ZEnd + 5, zone.ZStart - 5)
		-- keep decorations near the edges so the middle stays open
		if math.abs(x) < 60 then
			x = x < 0 and x - 70 or x + 70
		end
		if zoneIndex == 1 then
			-- giant lollipop
			local height = rng:NextNumber(8, 14)
			cylinder("Stick", 0.8, height, Vector3.new(x, height / 2, z), Color3.new(1, 1, 1), folder)
			local candyColors = { Color3.fromRGB(255, 120, 170), Color3.fromRGB(120, 200, 255), Color3.fromRGB(255, 220, 90) }
			part({
				Name = "Lollipop",
				Shape = Enum.PartType.Ball,
				Size = Vector3.new(6, 6, 6),
				CFrame = CFrame.new(x, height + 2.5, z),
				Color = candyColors[rng:NextInteger(1, #candyColors)],
			}, folder)
		elseif zoneIndex == 2 then
			-- giant cupcake
			cylinder("CupcakeBase", 7, 4, Vector3.new(x, 2, z), Color3.fromRGB(240, 130, 160), folder)
			local top = part({
				Name = "Frosting",
				Size = Vector3.new(8, 5, 8),
				CFrame = CFrame.new(x, 5.5, z),
				Color = Color3.fromRGB(255, 245, 250),
			}, folder)
			local mesh = Instance.new("SpecialMesh")
			mesh.MeshType = Enum.MeshType.Sphere
			mesh.Parent = top
		else
			-- glowing star crystal
			local height = rng:NextNumber(6, 12)
			part({
				Name = "Crystal",
				Size = Vector3.new(2.5, height, 2.5),
				CFrame = CFrame.new(x, height / 2, z) * CFrame.Angles(0, rng:NextNumber(0, math.pi), math.rad(rng:NextNumber(-10, 10))),
				Color = Color3.fromRGB(200, 170, 255),
				Material = Enum.Material.Neon,
				Transparency = 0.2,
			}, folder)
		end
	end
end

local function buildZone(zoneIndex, zone, parent, rng)
	local folder = Instance.new("Folder")
	folder.Name = zone.Name
	folder.Parent = parent

	local length = zone.ZStart - zone.ZEnd
	local centerZ = (zone.ZStart + zone.ZEnd) / 2
	part({
		Name = "ZoneFloor",
		Size = Vector3.new(Config.FieldHalfWidth * 2, 0.2, length),
		CFrame = CFrame.new(0, 0.1, centerZ),
		Color = zone.FloorColor,
	}, folder)

	-- Archway sign at the start of the zone
	local postColor = Color3.fromRGB(255, 255, 255)
	part({ Name = "Post", Size = Vector3.new(2, 18, 2), CFrame = CFrame.new(-24, 9, zone.ZStart), Color = postColor }, folder)
	part({ Name = "Post", Size = Vector3.new(2, 18, 2), CFrame = CFrame.new(24, 9, zone.ZStart), Color = postColor }, folder)
	local sign = part({
		Name = "ZoneSign",
		Size = Vector3.new(50, 6, 1),
		CFrame = CFrame.new(0, 19, zone.ZStart),
		Color = zone.FloorColor:Lerp(Color3.new(0, 0, 0), 0.25),
	}, folder)
	local rarityText = {}
	for rarity in pairs(zone.EggWeights) do
		table.insert(rarityText, rarity)
	end
	table.sort(rarityText, function(a, b)
		return Config.Rarities[a].Order < Config.Rarities[b].Order
	end)
	addSignText(sign, Enum.NormalId.Back, zone.Name .. "  (" .. table.concat(rarityText, ", ") .. ")")
	addSignText(sign, Enum.NormalId.Front, zone.Name)

	-- Nests, spread out so they never overlap
	local nests = {}
	local attempts = 0
	while #nests < zone.Nests and attempts < 500 do
		attempts = attempts + 1
		local pos = Vector3.new(
			rng:NextNumber(-Config.FieldHalfWidth + 20, Config.FieldHalfWidth - 20),
			0,
			rng:NextNumber(zone.ZEnd + 12, zone.ZStart - 12)
		)
		local tooClose = false
		for _, other in ipairs(nests) do
			if (other.Position - pos).Magnitude < 22 then
				tooClose = true
				break
			end
		end
		if not tooClose then
			local nestPart = cylinder("Nest", 5, 0.8, pos + Vector3.new(0, 0.4, 0), Color3.fromRGB(140, 95, 55), folder)
			nestPart.Material = Enum.Material.WoodPlanks
			table.insert(nests, {
				Position = pos,
				Surface = CFrame.new(pos + Vector3.new(0, 0.8, 0)) * CFrame.Angles(0, rng:NextNumber(0, 2 * math.pi), 0),
				Egg = nil,
			})
		end
	end

	decorate(zoneIndex, zone, folder, rng)

	return {
		Index = zoneIndex,
		Config = zone,
		Folder = folder,
		Nests = nests,
		MinX = -Config.FieldHalfWidth,
		MaxX = Config.FieldHalfWidth,
		MinZ = zone.ZEnd,
		MaxZ = zone.ZStart,
	}
end

function MapBuilder.Build()
	buildLighting()

	local map = Instance.new("Folder")
	map.Name = "Map"
	map.Parent = workspace

	buildGround(map)

	local plotsFolder = Instance.new("Folder")
	plotsFolder.Name = "Plots"
	plotsFolder.Parent = map
	local plots = {}
	for i = 1, Config.MaxPlots do
		plots[i] = buildPlot(i, plotsFolder)
	end

	local zonesFolder = Instance.new("Folder")
	zonesFolder.Name = "Zones"
	zonesFolder.Parent = map
	local rng = Random.new(2026) -- fixed seed: the map looks the same every time
	local zones = {}
	for i, zone in ipairs(Config.Zones) do
		zones[i] = buildZone(i, zone, zonesFolder, rng)
	end

	return {
		Folder = map,
		Plots = plots,
		Zones = zones,
	}
end

return MapBuilder

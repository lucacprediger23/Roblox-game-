-- MapBuilder: builds the street and the 6 player plots when the server starts.
-- Each plot, front to back: showroom (by the street) -> service (wash bay, engine lift) -> backyard.
-- Look: bright, glossy cartoon dealership. Every plot has its own accent color.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Lighting = game:GetService("Lighting")
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local MapBuilder = {}

local PLOT_SPACING = 110
local FLOOR_Y = 1
local rng = Random.new(2026)

local ACCENTS = {
	Color3.fromRGB(235, 60, 70), -- red
	Color3.fromRGB(50, 130, 255), -- blue
	Color3.fromRGB(40, 200, 110), -- green
	Color3.fromRGB(160, 80, 240), -- purple
	Color3.fromRGB(255, 140, 30), -- orange
	Color3.fromRGB(20, 190, 200), -- teal
}

local WHITE = Color3.fromRGB(245, 245, 248)
local DARK = Color3.fromRGB(32, 34, 42)

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

-- decoration: no collisions, no camera blocking, no raycasts
local function deco(props, parent)
	props.CanCollide = false
	props.CanQuery = false
	props.CanTouch = false
	return part(props, parent)
end

local function wedge(props, parent)
	local w = Instance.new("WedgePart")
	w.Anchored = true
	w.TopSurface = Enum.SurfaceType.Smooth
	w.BottomSurface = Enum.SurfaceType.Smooth
	w.Material = Enum.Material.SmoothPlastic
	for k, v in pairs(props) do
		w[k] = v
	end
	w.Parent = parent
	return w
end

local function cylinder(props, parent)
	-- a cylinder standing up: props.Height, props.Diameter
	local h, d = props.Height, props.Diameter
	props.Height, props.Diameter = nil, nil
	props.Shape = Enum.PartType.Cylinder
	props.Size = Vector3.new(h, d, d)
	props.CFrame = props.CFrame * CFrame.Angles(0, 0, math.rad(90))
	local p = part(props, parent)
	p.Size = Vector3.new(h, d, d)
	return p
end

local function ball(props, parent)
	local d = props.Diameter
	props.Diameter = nil
	props.Shape = Enum.PartType.Ball
	props.Size = Vector3.new(d, d, d)
	local p = part(props, parent)
	p.Size = Vector3.new(d, d, d)
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
	l.Text = text
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 2.5
	stroke.Color = Color3.new(0, 0, 0)
	stroke.Parent = l
	l.Parent = gui
	gui.Parent = adornee
	return l
end

local function surfaceText(p, face, text, color, pps)
	local gui = Instance.new("SurfaceGui")
	gui.Face = face
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = pps or 30
	gui.LightInfluence = 0
	local l = Instance.new("TextLabel")
	l.Size = UDim2.new(1, 0, 1, 0)
	l.BackgroundTransparency = 1
	l.Font = Enum.Font.FredokaOne
	l.TextScaled = true
	l.TextColor3 = color or Color3.new(1, 1, 1)
	l.Text = text
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 4
	stroke.Color = Color3.new(0, 0, 0)
	stroke.Parent = l
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0.04, 0)
	pad.PaddingRight = UDim.new(0.04, 0)
	pad.PaddingTop = UDim.new(0.1, 0)
	pad.PaddingBottom = UDim.new(0.1, 0)
	pad.Parent = l
	l.Parent = gui
	gui.Parent = p
	return l
end

local function pointLight(parent, color, range, brightness)
	local l = Instance.new("PointLight")
	l.Color = color or Color3.fromRGB(255, 240, 220)
	l.Range = range or 30
	l.Brightness = brightness or 1
	l.Shadows = false
	l.Parent = parent
	return l
end

---------------------------------------------------------------------
-- Sky and light: warm afternoon, a little haze, soft glow on neon
---------------------------------------------------------------------
local function buildLighting()
	Lighting.ClockTime = 14.8
	Lighting.GeographicLatitude = 35
	Lighting.Brightness = 2.4
	Lighting.Ambient = Color3.fromRGB(95, 95, 110)
	Lighting.OutdoorAmbient = Color3.fromRGB(135, 135, 150)
	Lighting.EnvironmentDiffuseScale = 1
	Lighting.EnvironmentSpecularScale = 1
	Lighting.ExposureCompensation = -0.1
	Lighting.ShadowSoftness = 0.25
	for _, c in ipairs(Lighting:GetChildren()) do
		if c:IsA("PostEffect") or c:IsA("Atmosphere") then
			c:Destroy()
		end
	end
	local a = Instance.new("Atmosphere")
	a.Density = 0.28
	a.Offset = 0.2
	a.Color = Color3.fromRGB(210, 228, 255)
	a.Decay = Color3.fromRGB(120, 140, 190)
	a.Glare = 0.25
	a.Haze = 1.2
	a.Parent = Lighting
	local bloom = Instance.new("BloomEffect")
	bloom.Intensity = 0.35
	bloom.Size = 24
	bloom.Threshold = 2.2
	bloom.Parent = Lighting
	local cc = Instance.new("ColorCorrectionEffect")
	cc.Saturation = 0.18
	cc.Contrast = 0.08
	cc.Brightness = 0.02
	cc.TintColor = Color3.fromRGB(255, 250, 245)
	cc.Parent = Lighting
	local rays = Instance.new("SunRaysEffect")
	rays.Intensity = 0.06
	rays.Spread = 0.6
	rays.Parent = Lighting
end

---------------------------------------------------------------------
-- Props
---------------------------------------------------------------------
local function tree(parent, pos, scale)
	scale = scale or 1
	local trunkH = 6 * scale
	cylinder({ Name = "Trunk", Height = trunkH, Diameter = 1.4 * scale, CFrame = CFrame.new(pos + Vector3.new(0, trunkH / 2, 0)), Color = Color3.fromRGB(110, 75, 50), Material = Enum.Material.Wood, CanCollide = true }, parent)
	local green = Color3.fromHSV(rng:NextNumber(0.24, 0.33), 0.65, rng:NextNumber(0.55, 0.75))
	local blobs = {
		{ Vector3.new(0, trunkH + 2.5 * scale, 0), 7 },
		{ Vector3.new(1.8, trunkH + 1.2 * scale, 1), 5 },
		{ Vector3.new(-1.8, trunkH + 1.4 * scale, -0.8), 5.2 },
		{ Vector3.new(0.4, trunkH + 4.6 * scale, -0.3), 4.6 },
	}
	for _, b in ipairs(blobs) do
		ball({ Name = "Leaves", Diameter = b[2] * scale, CFrame = CFrame.new(pos + b[1] * Vector3.new(scale, 1, scale)), Color = green:Lerp(Color3.new(1, 1, 1), rng:NextNumber(0, 0.08)), Material = Enum.Material.Grass, CanCollide = false, CanQuery = false }, parent)
	end
end

local function bush(parent, pos, size)
	ball({ Name = "Bush", Diameter = size, CFrame = CFrame.new(pos + Vector3.new(0, size * 0.3, 0)), Color = Color3.fromRGB(70, 150, 70), Material = Enum.Material.Grass, CanCollide = false, CanQuery = false }, parent)
end

local function plant(parent, pos)
	cylinder({ Name = "Pot", Height = 2, Diameter = 2.4, CFrame = CFrame.new(pos + Vector3.new(0, 1, 0)), Color = WHITE, CanCollide = true }, parent)
	for i = 1, 4 do
		local angle = i * math.pi / 2
		ball({ Name = "Leaf", Diameter = 1.8, CFrame = CFrame.new(pos + Vector3.new(math.cos(angle) * 0.5, 2.8 + i * 0.3, math.sin(angle) * 0.5)), Color = Color3.fromRGB(60, 160, 80), Material = Enum.Material.Grass, CanCollide = false, CanQuery = false }, parent)
	end
end

local function streetLamp(parent, pos, facing)
	cylinder({ Name = "LampPole", Height = 14, Diameter = 0.6, CFrame = CFrame.new(pos + Vector3.new(0, 7, 0)), Color = DARK, Material = Enum.Material.Metal, CanCollide = true }, parent)
	deco({ Name = "LampArm", Size = Vector3.new(0.4, 0.4, 3), CFrame = CFrame.new(pos + Vector3.new(0, 13.8, facing * 1.4)), Color = DARK, Material = Enum.Material.Metal }, parent)
	local bulb = deco({ Name = "LampBulb", Size = Vector3.new(1.4, 0.5, 1.8), CFrame = CFrame.new(pos + Vector3.new(0, 13.4, facing * 2.6)), Color = Color3.fromRGB(255, 240, 200), Material = Enum.Material.Neon }, parent)
	pointLight(bulb, Color3.fromRGB(255, 230, 180), 24, 0.8)
end

local function flag(parent, pos, color)
	cylinder({ Name = "FlagPole", Height = 12, Diameter = 0.35, CFrame = CFrame.new(pos + Vector3.new(0, 6, 0)), Color = WHITE, Material = Enum.Material.Metal }, parent)
	deco({ Name = "Flag", Size = Vector3.new(0.1, 6, 2.2), CFrame = CFrame.new(pos + Vector3.new(0, 8.6, 1.2)), Color = color, Material = Enum.Material.Fabric }, parent)
	deco({ Name = "FlagStripe", Size = Vector3.new(0.12, 6, 0.5), CFrame = CFrame.new(pos + Vector3.new(0, 8.6, 0.3)), Color = WHITE, Material = Enum.Material.Fabric }, parent)
end

local function tireStack(parent, pos, count)
	for i = 1, count do
		cylinder({ Name = "Tire", Height = 0.9, Diameter = 2.6, CFrame = CFrame.new(pos + Vector3.new(0, i - 0.5, 0)), Color = Color3.fromRGB(28, 28, 30), Material = Enum.Material.Rubber, CanCollide = true }, parent)
	end
end

local function truck(parent, cf, color)
	-- parked delivery truck: cab, flatbed, and a container on the back
	local function at(x, y, z)
		return cf * CFrame.new(x, y, z)
	end
	part({ Name = "TruckCab", Size = Vector3.new(8, 7, 7), CFrame = at(0, 4.5, -11), Color = color, Reflectance = 0.15 }, parent)
	wedge({ Name = "TruckNose", Size = Vector3.new(8, 2, 2), CFrame = at(0, 8.99, -13.5) * CFrame.Angles(0, math.rad(180), 0), Color = color, Reflectance = 0.15 }, parent)
	deco({ Name = "TruckWindow", Size = Vector3.new(7, 2.6, 0.2), CFrame = at(0, 6.3, -14.55), Color = Color3.fromRGB(40, 60, 90), Material = Enum.Material.Glass, Reflectance = 0.3, Transparency = 0.1 }, parent)
	deco({ Name = "TruckGrille", Size = Vector3.new(6, 2, 0.2), CFrame = at(0, 2.6, -14.55), Color = Color3.fromRGB(190, 190, 200), Material = Enum.Material.Metal }, parent)
	for _, x in ipairs({ -2.9, 2.9 }) do
		deco({ Name = "TruckLight", Size = Vector3.new(1.2, 0.8, 0.2), CFrame = at(x, 2.6, -14.6), Color = Color3.fromRGB(255, 250, 220), Material = Enum.Material.Neon }, parent)
	end
	part({ Name = "TruckBed", Size = Vector3.new(8, 1, 18), CFrame = at(0, 2, 2), Color = DARK, Material = Enum.Material.DiamondPlate }, parent)
	for _, z in ipairs({ -11, -2, 6 }) do
		for _, x in ipairs({ -3.6, 3.6 }) do
			local w = cylinder({ Name = "TruckWheel", Height = 1.2, Diameter = 3, CFrame = at(x, 1.5, z) * CFrame.Angles(0, 0, math.rad(90)), Color = Color3.fromRGB(25, 25, 28), Material = Enum.Material.Rubber, CanCollide = false }, parent)
			w.CFrame = at(x, 1.5, z)
			w.Size = Vector3.new(1.2, 3, 3)
		end
	end
	local box = part({ Name = "TruckContainer", Size = Vector3.new(7.6, 7, 16), CFrame = at(0, 6, 2.5), Color = Color3.fromRGB(200, 120, 50), Material = Enum.Material.DiamondPlate }, parent)
	for _, face in ipairs({ Enum.NormalId.Left, Enum.NormalId.Right }) do
		surfaceText(box, face, "D2D LOGISTICS", WHITE, 20)
	end
end

---------------------------------------------------------------------
-- The street and the scenery around the plots
---------------------------------------------------------------------
local function buildWorld(map)
	local baseplate = workspace:FindFirstChild("Baseplate")
	if baseplate then
		baseplate:Destroy()
	end
	part({ Name = "Ground", Size = Vector3.new(1400, 4, 900), CFrame = CFrame.new(0, -2, 0), Color = Color3.fromRGB(105, 185, 85), Material = Enum.Material.Grass }, map)
	-- road with curbs, dashes and crosswalks
	part({ Name = "Road", Size = Vector3.new(1400, 0.2, 26), CFrame = CFrame.new(0, 0.1, -108), Color = Color3.fromRGB(52, 54, 60), Material = Enum.Material.Asphalt }, map)
	for x = -690, 690, 16 do
		deco({ Name = "RoadLine", Size = Vector3.new(7, 0.05, 0.6), CFrame = CFrame.new(x, 0.22, -108), Color = Color3.fromRGB(255, 220, 70) }, map)
	end
	for _, z in ipairs({ -94.9, -121.1 }) do
		part({ Name = "Curb", Size = Vector3.new(1400, 0.7, 0.8), CFrame = CFrame.new(0, 0.35, z), Color = Color3.fromRGB(225, 225, 230), Material = Enum.Material.Concrete }, map)
	end
	part({ Name = "Sidewalk", Size = Vector3.new(1400, 0.6, 7.5), CFrame = CFrame.new(0, 0.3, -91), Color = Color3.fromRGB(200, 200, 206), Material = Enum.Material.Concrete }, map)
	part({ Name = "FarSidewalk", Size = Vector3.new(1400, 0.6, 7), CFrame = CFrame.new(0, 0.3, -125), Color = Color3.fromRGB(200, 200, 206), Material = Enum.Material.Concrete }, map)
	for i = 1, Config.MaxPlots - 1 do
		local x = -((Config.MaxPlots - 1) * PLOT_SPACING) / 2 + (i - 0.5) * PLOT_SPACING
		for s = -5, 5, 2 do
			deco({ Name = "Crosswalk", Size = Vector3.new(1.4, 0.05, 20), CFrame = CFrame.new(x + s, 0.22, -108), Color = WHITE }, map)
		end
	end
	-- street lamps on both sides
	for x = -330, 330, 55 do
		streetLamp(map, Vector3.new(x, 0.6, -93.5), -1)
		streetLamp(map, Vector3.new(x + 27, 0.6, -126), 1)
	end
	-- a line of trees across the road, and a forest behind the yards
	for x = -390, 390, 14 do
		tree(map, Vector3.new(x + rng:NextNumber(-3, 3), 0, -133 - rng:NextNumber(0, 6)), rng:NextNumber(0.9, 1.3))
	end
	for x = -390, 390, 12 do
		tree(map, Vector3.new(x + rng:NextNumber(-3, 3), 0, 86 + rng:NextNumber(0, 14)), rng:NextNumber(1, 1.5))
	end
	-- soft green hills on the horizon
	for i = 1, 26 do
		local side = i % 2 == 0 and 1 or -1
		local x = rng:NextNumber(-650, 650)
		local z = side > 0 and rng:NextNumber(180, 300) or rng:NextNumber(-320, -200)
		local d = rng:NextNumber(90, 170)
		ball({ Name = "Hill", Diameter = d, CFrame = CFrame.new(x, -d * 0.3, z), Color = Color3.fromRGB(95, 170, 85):Lerp(Color3.fromRGB(70, 140, 90), rng:NextNumber()), Material = Enum.Material.Grass, CanCollide = false, CanQuery = false }, map)
	end
	for _, x in ipairs({ -420, 420 }) do
		for z = -80, 80, 12 do
			tree(map, Vector3.new(x + rng:NextNumber(-4, 4), 0, z), rng:NextNumber(1, 1.4))
		end
	end
	-- invisible walls around the play area
	local walls = {
		{ Vector3.new(4, 80, 260), Vector3.new(-380, 40, -20) },
		{ Vector3.new(4, 80, 260), Vector3.new(380, 40, -20) },
		{ Vector3.new(760, 80, 4), Vector3.new(0, 40, -130) },
		{ Vector3.new(760, 80, 4), Vector3.new(0, 40, 110) },
	}
	for _, w in ipairs(walls) do
		part({ Name = "Boundary", Size = w[1], CFrame = CFrame.new(w[2]), Transparency = 1, CanQuery = false }, map)
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
	local accent = ACCENTS[(index - 1) % #ACCENTS + 1]
	local accentDark = accent:Lerp(Color3.new(0, 0, 0), 0.35)
	local m = Instance.new("Model")
	m.Name = "Plot" .. index
	m.Parent = parent
	local function at(x, y, z)
		return CFrame.new(cx + x, y, z)
	end
	local function v(x, y, z)
		return Vector3.new(cx + x, y, z)
	end

	-- hedges and trees between plots
	for _, side in ipairs(index == 1 and { -1, 1 } or { 1 }) do
		local hx = side * 55
		deco({ Name = "Hedge", Size = Vector3.new(4, 3.5, 150), CFrame = at(hx, 1.75, -7), Color = Color3.fromRGB(60, 140, 65), Material = Enum.Material.Grass }, m)
		for z = -80, 66, 24 do
			tree(m, v(hx, 0, z), 0.9)
		end
	end

	---------------- SHOWROOM (z -88 .. -8) ----------------
	part({ Name = "ShowroomFloor", Size = Vector3.new(90, FLOOR_Y, 80), CFrame = at(0, FLOOR_Y / 2, -48), Color = Color3.fromRGB(60, 62, 72) }, m)
	-- glossy checker tiles
	for tx = -40, 40, 10 do
		for tz = -83, -13, 10 do
			local light = ((tx + tz) / 10) % 2 == 0
			deco({ Name = "Tile", Size = Vector3.new(10, 0.1, 10), CFrame = at(tx, FLOOR_Y + 0.05, tz), Color = light and Color3.fromRGB(80, 82, 92) or Color3.fromRGB(60, 62, 72), Reflectance = 0.08, Material = Enum.Material.SmoothPlastic }, m)
		end
	end
	-- side walls: white with an accent band and a neon line
	for _, x in ipairs({ -45, 45 }) do
		part({ Name = "Wall", Size = Vector3.new(1, 16, 80), CFrame = at(x, FLOOR_Y + 8, -48), Color = WHITE }, m)
		deco({ Name = "WallBand", Size = Vector3.new(1.3, 3, 80), CFrame = at(x, FLOOR_Y + 12.5, -48), Color = accent, Reflectance = 0.1 }, m)
		deco({ Name = "WallNeon", Size = Vector3.new(1.4, 0.3, 80), CFrame = at(x, FLOOR_Y + 10.7, -48), Color = accent:Lerp(WHITE, 0.4), Material = Enum.Material.Neon }, m)
		deco({ Name = "Skirting", Size = Vector3.new(1.3, 1, 80), CFrame = at(x, FLOOR_Y + 0.5, -48), Color = DARK }, m)
	end
	-- back wall with a doorway into the service area
	for _, x in ipairs({ -26.5, 26.5 }) do
		part({ Name = "Wall", Size = Vector3.new(37, 16, 1), CFrame = at(x, FLOOR_Y + 8, -8), Color = WHITE }, m)
		deco({ Name = "WallBand", Size = Vector3.new(37, 3, 1.3), CFrame = at(x, FLOOR_Y + 12.5, -8), Color = accent, Reflectance = 0.1 }, m)
	end
	part({ Name = "Lintel", Size = Vector3.new(16, 6, 1), CFrame = at(0, FLOOR_Y + 13, -8), Color = WHITE }, m)
	local serviceSign = deco({ Name = "ServiceSign", Size = Vector3.new(12, 2.4, 0.2), CFrame = at(0, FLOOR_Y + 12.4, -8.7), Color = DARK }, m)
	surfaceText(serviceSign, Enum.NormalId.Front, "SERVICE", accent:Lerp(WHITE, 0.3))

	-- glass front: white pillars, tall glass, an entrance canopy
	for _, x in ipairs({ -44.5, -30, -16, 16, 30, 44.5 }) do
		part({ Name = "Pillar", Size = Vector3.new(2, 16, 2), CFrame = at(x, FLOOR_Y + 8, -88), Color = WHITE }, m)
	end
	for _, seg in ipairs({ { -37.25, 12.5 }, { -23, 12 }, { 23, 12 }, { 37.25, 12.5 } }) do
		part({ Name = "Glass", Size = Vector3.new(seg[2], 15, 0.4), CFrame = at(seg[1], FLOOR_Y + 7.5, -88), Color = Color3.fromRGB(180, 220, 245), Material = Enum.Material.Glass, Transparency = 0.75, Reflectance = 0.1 }, m)
		deco({ Name = "GlassFrame", Size = Vector3.new(seg[2], 0.5, 0.6), CFrame = at(seg[1], FLOOR_Y + 0.25, -88), Color = DARK }, m)
	end
	deco({ Name = "EntranceHeader", Size = Vector3.new(32, 2, 1.2), CFrame = at(0, FLOOR_Y + 15, -88), Color = WHITE }, m)
	deco({ Name = "Canopy", Size = Vector3.new(22, 0.8, 9), CFrame = at(0, FLOOR_Y + 11.5, -92), Color = DARK, Reflectance = 0.1 }, m)
	deco({ Name = "CanopyNeon", Size = Vector3.new(22.2, 0.3, 0.3), CFrame = at(0, FLOOR_Y + 11.2, -96.5), Color = accent:Lerp(WHITE, 0.3), Material = Enum.Material.Neon }, m)
	for _, x in ipairs({ -10, 10 }) do
		cylinder({ Name = "CanopyPost", Height = 11.1, Diameter = 0.6, CFrame = at(x, FLOOR_Y + 5.55, -96), Color = Color3.fromRGB(200, 200, 210), Material = Enum.Material.Metal }, m)
	end
	local canopyLight = deco({ Name = "CanopyLight", Size = Vector3.new(6, 0.2, 2), CFrame = at(0, FLOOR_Y + 11, -92), Color = Color3.fromRGB(255, 245, 225), Material = Enum.Material.Neon }, m)
	pointLight(canopyLight, Color3.fromRGB(255, 235, 200), 18, 1)
	-- welcome mat and red carpet into the showroom
	deco({ Name = "Carpet", Size = Vector3.new(6, 0.12, 12), CFrame = at(0, FLOOR_Y + 0.12, -83), Color = Color3.fromRGB(200, 30, 45), Material = Enum.Material.Fabric }, m)
	deco({ Name = "Mat", Size = Vector3.new(10, 0.1, 6), CFrame = at(0, 0.65, -92), Color = DARK, Material = Enum.Material.Fabric }, m)

	-- the big sign on top of the facade
	part({ Name = "SignBack", Size = Vector3.new(54, 8, 1.2), CFrame = at(0, FLOOR_Y + 20.5, -88), Color = accent, Reflectance = 0.1 }, m)
	local sign = deco({ Name = "Sign", Size = Vector3.new(50, 6, 0.4), CFrame = at(0, FLOOR_Y + 20.5, -88.8), Color = DARK }, m)
	local signLabel = surfaceText(sign, Enum.NormalId.Front, "FOR SALE", Color3.fromRGB(255, 215, 60))
	for _, edge in ipairs({ { 0, 3.15, 50.4, 0.3 }, { 0, -3.15, 50.4, 0.3 }, { -25.1, 0, 0.3, 6.6 }, { 25.1, 0, 0.3, 6.6 } }) do
		deco({ Name = "SignNeon", Size = Vector3.new(edge[3], edge[4], 0.3), CFrame = at(edge[1], FLOOR_Y + 20.5 + edge[2], -89), Color = accent:Lerp(WHITE, 0.45), Material = Enum.Material.Neon }, m)
	end
	for _, x in ipairs({ -20, 20 }) do
		deco({ Name = "SignPost", Size = Vector3.new(1, 4, 1), CFrame = at(x, FLOOR_Y + 15.5, -88), Color = DARK }, m)
	end

	-- glass roof on white beams (see-through, never blocks the camera)
	deco({ Name = "RoofGlass", Size = Vector3.new(90, 0.3, 80), CFrame = at(0, FLOOR_Y + 16.2, -48), Color = Color3.fromRGB(200, 230, 255), Material = Enum.Material.Glass, Transparency = 0.85 }, m)
	for z = -88, -8, 16 do
		deco({ Name = "RoofBeam", Size = Vector3.new(90, 1, 1), CFrame = at(0, FLOOR_Y + 16, z), Color = WHITE }, m)
	end
	for _, x in ipairs({ -45, -15, 15, 45 }) do
		deco({ Name = "RoofBeam", Size = Vector3.new(1, 1, 80), CFrame = at(x, FLOOR_Y + 16, -48), Color = WHITE }, m)
	end
	-- light strips hanging under the beams, and a few real lights
	for _, z in ipairs({ -72, -56, -40, -24 }) do
		local strip = deco({ Name = "LightStrip", Size = Vector3.new(60, 0.3, 0.8), CFrame = at(0, FLOOR_Y + 15.3, z), Color = Color3.fromRGB(255, 250, 240), Material = Enum.Material.Neon }, m)
		pointLight(strip, Color3.fromRGB(255, 244, 228), 34, 0.35)
	end

	-- reception desk and plants
	part({ Name = "Desk", Size = Vector3.new(9, 3.4, 2.4), CFrame = at(31, FLOOR_Y + 1.7, -85), Color = WHITE, Reflectance = 0.1 }, m)
	deco({ Name = "DeskFront", Size = Vector3.new(9.1, 1, 2.5), CFrame = at(31, FLOOR_Y + 2.2, -85), Color = accent, Reflectance = 0.1 }, m)
	deco({ Name = "Monitor", Size = Vector3.new(2.4, 1.6, 0.2), CFrame = at(31, FLOOR_Y + 4.3, -84.6), Color = DARK }, m)
	deco({ Name = "Screen", Size = Vector3.new(2.1, 1.3, 0.05), CFrame = at(31, FLOOR_Y + 4.3, -84.72), Color = Color3.fromRGB(110, 190, 255), Material = Enum.Material.Neon }, m)
	for _, p in ipairs({ { -42, -85 }, { 42, -11 }, { -42, -11 }, { 20, -85 } }) do
		plant(m, v(p[1], FLOOR_Y, p[2]))
	end

	-- display spots: 8 columns x 5 rows, filled from the front row, center outward
	local spots = {}
	local cols = { -5, 5, -15, 15, -25, 25, -35, 35 }
	local rows = { -74, -60, -46, -32, -18 }
	for _, z in ipairs(rows) do
		for _, x in ipairs(cols) do
			local pad = part({ Name = "Spot", Size = Vector3.new(8.6, 0.3, 13), CFrame = at(x, FLOOR_Y + 0.25, z), Color = Color3.fromRGB(38, 40, 50), Reflectance = 0.25, CanCollide = false }, m)
			local trims = {}
			for _, e in ipairs({ { 0, -6.6, 8.8, 0.25 }, { 0, 6.6, 8.8, 0.25 }, { -4.4, 0, 0.25, 13.4 }, { 4.4, 0, 0.25, 13.4 } }) do
				table.insert(trims, deco({ Name = "SpotTrim", Size = Vector3.new(e[3], 0.32, e[4]), CFrame = at(x + e[1], FLOOR_Y + 0.26, z + e[2]), Color = accent:Lerp(WHITE, 0.35), Material = Enum.Material.Neon }, m))
			end
			table.insert(spots, { Pad = pad, Trims = trims, CFrame = at(x, FLOOR_Y + 0.4, z), Front = at(x, FLOOR_Y, z - 10) })
		end
	end

	---------------- SERVICE (z -8 .. 28) ----------------
	part({ Name = "ServiceFloor", Size = Vector3.new(90, FLOOR_Y, 36), CFrame = at(0, FLOOR_Y / 2, 10), Color = Color3.fromRGB(78, 82, 92), Reflectance = 0.08 }, m)
	for _, x in ipairs({ -45, 45 }) do
		part({ Name = "Wall", Size = Vector3.new(1, 12, 36), CFrame = at(x, FLOOR_Y + 6, 10), Color = Color3.fromRGB(170, 90, 70), Material = Enum.Material.Brick }, m)
		deco({ Name = "WallCap", Size = Vector3.new(1.4, 0.8, 36), CFrame = at(x, FLOOR_Y + 12.2, 10), Color = DARK }, m)
	end
	-- steel beams overhead with work lamps
	for _, z in ipairs({ -1, 10, 21 }) do
		deco({ Name = "Beam", Size = Vector3.new(90, 1.2, 1), CFrame = at(0, FLOOR_Y + 12, z), Color = Color3.fromRGB(60, 62, 70), Material = Enum.Material.Metal }, m)
	end
	for _, x in ipairs({ -15, 15 }) do
		local lamp = deco({ Name = "WorkLamp", Size = Vector3.new(4, 0.4, 1.2), CFrame = at(x, FLOOR_Y + 11.2, 10), Color = Color3.fromRGB(255, 252, 240), Material = Enum.Material.Neon }, m)
		pointLight(lamp, Color3.fromRGB(255, 248, 235), 26, 1.1)
	end
	-- gate into the yard
	deco({ Name = "GateBeam", Size = Vector3.new(90, 2.4, 1.2), CFrame = at(0, FLOOR_Y + 12, 28), Color = DARK }, m)
	for x = -44, 44, 4 do
		deco({ Name = "Hazard", Size = Vector3.new(2, 2.42, 1.22), CFrame = at(x, FLOOR_Y + 12, 28), Color = Color3.fromRGB(255, 200, 30) }, m)
	end

	-- wash bay: blue tiles, a gantry with a neon sign, spinning-brush towers
	local wash = part({ Name = "WashBay", Size = Vector3.new(14, 0.3, 22), CFrame = at(-15, FLOOR_Y + 0.15, 10), Color = Color3.fromRGB(60, 150, 230), Reflectance = 0.2, CanCollide = false }, m)
	for _, e in ipairs({ { -7, 0, 0.3, 22.3 }, { 7, 0, 0.3, 22.3 }, { 0, -11, 14.3, 0.3 }, { 0, 11, 14.3, 0.3 } }) do
		deco({ Name = "WashTrim", Size = Vector3.new(e[3], 0.32, e[4]), CFrame = at(-15 + e[1], FLOOR_Y + 0.17, 10 + e[2]), Color = Color3.fromRGB(255, 255, 255), Material = Enum.Material.Neon }, m)
	end
	deco({ Name = "Drain", Size = Vector3.new(3, 0.32, 3), CFrame = at(-15, FLOOR_Y + 0.17, 10), Color = Color3.fromRGB(40, 45, 55), Material = Enum.Material.DiamondPlate }, m)
	for _, x in ipairs({ -7.6, 7.6 }) do
		part({ Name = "GantryPost", Size = Vector3.new(1.2, 10, 1.2), CFrame = at(-15 + x, FLOOR_Y + 5, 1), Color = Color3.fromRGB(230, 235, 245), Material = Enum.Material.Metal }, m)
		local brush = cylinder({ Name = "Brush", Height = 6.5, Diameter = 2, CFrame = at(-15 + x * 0.88, FLOOR_Y + 3.6, 3), Color = Color3.fromRGB(70, 110, 255), Material = Enum.Material.Fabric, CanCollide = false }, m)
		brush.CanQuery = false
		deco({ Name = "BrushStripe", Size = Vector3.new(2.1, 0.4, 2.1), CFrame = at(-15 + x * 0.88, FLOOR_Y + 5, 3), Color = Color3.fromRGB(255, 220, 60) }, m)
	end
	deco({ Name = "GantryTop", Size = Vector3.new(16.4, 1.6, 1.6), CFrame = at(-15, FLOOR_Y + 10.4, 1), Color = Color3.fromRGB(230, 235, 245), Material = Enum.Material.Metal }, m)
	local washSign = deco({ Name = "WashSign", Size = Vector3.new(10, 2.2, 0.3), CFrame = at(-15, FLOOR_Y + 12.4, 1), Color = Color3.fromRGB(20, 60, 120) }, m)
	surfaceText(washSign, Enum.NormalId.Back, "CAR WASH", Color3.fromRGB(140, 220, 255))
	surfaceText(washSign, Enum.NormalId.Front, "CAR WASH", Color3.fromRGB(140, 220, 255))
	pointLight(washSign, Color3.fromRGB(120, 200, 255), 18, 1)
	for i = 1, 5 do
		local d = rng:NextNumber(1.5, 3.5)
		deco({ Name = "Puddle", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.05, d, d), CFrame = at(-15 + rng:NextNumber(-9, 9), FLOOR_Y + 0.03, 10 + rng:NextNumber(-12, 12)) * CFrame.Angles(0, 0, math.rad(90)), Color = Color3.fromRGB(150, 200, 240), Material = Enum.Material.Glass, Transparency = 0.4, Reflectance = 0.4 }, m).Size = Vector3.new(0.05, d, d)
	end
	local washLabel = label(wash, "WASH BAY", Color3.fromRGB(140, 220, 255), 9, 240)

	-- engine lift: a two-post lift, a tool cabinet and tires
	local lift = part({ Name = "EngineLift", Size = Vector3.new(14, 0.3, 22), CFrame = at(15, FLOOR_Y + 0.15, 10), Color = Color3.fromRGB(60, 62, 70), Material = Enum.Material.DiamondPlate, CanCollide = false }, m)
	for x = -6, 6, 3 do
		deco({ Name = "LiftHazard", Size = Vector3.new(1.5, 0.32, 22.3), CFrame = at(15 + x, FLOOR_Y + 0.17, 10), Color = Color3.fromRGB(255, 200, 30) }, m).Transparency = 0.2
	end
	for _, x in ipairs({ -7.5, 7.5 }) do
		part({ Name = "LiftPost", Size = Vector3.new(1.4, 10, 1.4), CFrame = at(15 + x, FLOOR_Y + 5, 10), Color = Color3.fromRGB(255, 190, 30), Reflectance = 0.1 }, m)
		deco({ Name = "LiftBase", Size = Vector3.new(2.4, 0.4, 2.4), CFrame = at(15 + x, FLOOR_Y + 0.2, 10), Color = DARK }, m)
		deco({ Name = "LiftArm", Size = Vector3.new(4, 0.4, 0.6), CFrame = at(15 + x * 0.75, FLOOR_Y + 0.9, 7), Color = Color3.fromRGB(50, 52, 60), Material = Enum.Material.Metal }, m)
		deco({ Name = "LiftArm", Size = Vector3.new(4, 0.4, 0.6), CFrame = at(15 + x * 0.75, FLOOR_Y + 0.9, 13), Color = Color3.fromRGB(50, 52, 60), Material = Enum.Material.Metal }, m)
	end
	deco({ Name = "LiftTop", Size = Vector3.new(16.4, 1, 1), CFrame = at(15, FLOOR_Y + 10.5, 10), Color = Color3.fromRGB(255, 190, 30) }, m)
	local liftSign = deco({ Name = "LiftSign", Size = Vector3.new(10, 2.2, 0.3), CFrame = at(15, FLOOR_Y + 12.4, 10), Color = Color3.fromRGB(60, 40, 10) }, m)
	surfaceText(liftSign, Enum.NormalId.Back, "ENGINES", Color3.fromRGB(255, 210, 80))
	surfaceText(liftSign, Enum.NormalId.Front, "ENGINES", Color3.fromRGB(255, 210, 80))
	part({ Name = "ToolCabinet", Size = Vector3.new(2.2, 4.5, 5), CFrame = at(42.8, FLOOR_Y + 2.25, 2), Color = Color3.fromRGB(210, 40, 40), Reflectance = 0.15 }, m)
	for i = 0, 3 do
		deco({ Name = "Drawer", Size = Vector3.new(0.1, 0.12, 4.4), CFrame = at(41.65, FLOOR_Y + 1 + i, 2), Color = Color3.fromRGB(220, 220, 225), Material = Enum.Material.Metal }, m)
	end
	tireStack(m, v(-42, FLOOR_Y, 4), 4)
	tireStack(m, v(-42, FLOOR_Y, 7.2), 3)
	local liftLabel = label(lift, "ENGINE LIFT", Color3.fromRGB(255, 210, 90), 9, 240)

	---------------- BACKYARD (z 28 .. 70) ----------------
	part({ Name = "Yard", Size = Vector3.new(90, 0.4, 42), CFrame = at(0, 0.2, 49), Color = Color3.fromRGB(175, 165, 150), Material = Enum.Material.Pebble }, m)
	-- wooden fence on three sides
	local fenceColor = Color3.fromRGB(150, 105, 70)
	for _, x in ipairs({ -45, 45 }) do
		part({ Name = "Fence", Size = Vector3.new(0.5, 5, 42), CFrame = at(x, 2.5, 49), Color = fenceColor, Material = Enum.Material.WoodPlanks }, m)
		for z = 28, 70, 7 do
			deco({ Name = "FencePost", Size = Vector3.new(0.9, 5.6, 0.9), CFrame = at(x, 2.8, z), Color = fenceColor:Lerp(Color3.new(0, 0, 0), 0.3), Material = Enum.Material.Wood }, m)
		end
	end
	for _, seg in ipairs({ { -28, 34 }, { 28, 34 } }) do
		part({ Name = "Fence", Size = Vector3.new(seg[2], 5, 0.5), CFrame = at(seg[1], 2.5, 70), Color = fenceColor, Material = Enum.Material.WoodPlanks }, m)
	end
	-- a gate in the back fence where the truck comes in
	for _, x in ipairs({ -11, 11 }) do
		part({ Name = "GatePost", Size = Vector3.new(1.2, 8, 1.2), CFrame = at(x, 4, 70), Color = DARK }, m)
	end
	deco({ Name = "GateTop", Size = Vector3.new(23.2, 1.2, 1.2), CFrame = at(0, 8.6, 70), Color = DARK }, m)
	local gateSign = deco({ Name = "GateSign", Size = Vector3.new(12, 2, 0.3), CFrame = at(0, 10.4, 70), Color = accent }, m)
	surfaceText(gateSign, Enum.NormalId.Front, "DELIVERIES", WHITE)
	surfaceText(gateSign, Enum.NormalId.Back, "DELIVERIES", WHITE)
	-- flood lights in the back corners
	for _, x in ipairs({ -42, 42 }) do
		cylinder({ Name = "FloodPole", Height = 13, Diameter = 0.6, CFrame = at(x, 6.5, 67), Color = DARK, Material = Enum.Material.Metal, CanCollide = true }, m)
		local head = deco({ Name = "FloodLight", Size = Vector3.new(2.2, 1.2, 0.6), CFrame = at(x, 13, 66.6), Color = Color3.fromRGB(255, 250, 230), Material = Enum.Material.Neon }, m)
		pointLight(head, Color3.fromRGB(255, 245, 220), 30, 0.8)
	end
	-- the delivery truck parked behind the gate
	truck(m, at(0, 0, 84) * CFrame.Angles(0, math.rad(180), 0), accent)
	part({ Name = "Driveway", Size = Vector3.new(22, 0.2, 30), CFrame = at(0, 0.1, 85), Color = Color3.fromRGB(70, 72, 78), Material = Enum.Material.Asphalt }, m)
	local yardSlots = {}
	for _, z in ipairs({ 40, 59 }) do
		for _, x in ipairs({ -28, -14, 0, 14, 28 }) do
			table.insert(yardSlots, at(x, 0.4, z))
			deco({ Name = "SlotMark", Size = Vector3.new(10, 0.05, 16), CFrame = at(x, 0.42, z), Color = Color3.fromRGB(150, 140, 125), Material = Enum.Material.Concrete }, m)
		end
	end

	-- out front: flags and bushes
	for _, x in ipairs({ -40, -26, 26, 40 }) do
		flag(m, v(x, 0.6, -94), accent)
	end
	for _, x in ipairs({ -36, -22, 22, 36 }) do
		bush(m, v(x, 0.4, -89.8), 3)
	end

	-- upgrade pads: glowing circles with a ring
	local function pad(name, x, z, color, y)
		y = y or FLOOR_Y + 0.2
		local base = cylinder({ Name = name .. "Base", Height = 0.3, Diameter = 7.4, CFrame = at(x, y - 0.05, z), Color = DARK, CanCollide = false }, m)
		base.CanQuery = false
		local p = cylinder({ Name = name, Height = 0.4, Diameter = 6, CFrame = at(x, y, z), Color = color, Material = Enum.Material.Neon, CanCollide = false }, m)
		pointLight(p, color, 12, 1.2)
		local l = label(p, name, Color3.new(1, 1, 1), 4.5, 260, 60)
		return { Part = p, Label = l }
	end
	local pads = {
		Showroom = pad("Showroom", -36, 0, Color3.fromRGB(90, 220, 120)),
		Wash = pad("Wash Tools", -36, 20, Color3.fromRGB(70, 170, 255)),
		Engine = pad("Engine Luck", 36, 20, Color3.fromRGB(255, 180, 40)),
		Truck = pad("Truck", 36, 33, Color3.fromRGB(240, 90, 90), 0.6),
	}

	return {
		Index = index,
		CenterX = cx,
		Model = m,
		Accent = accent,
		Spots = spots,
		WashCFrame = at(-15, FLOOR_Y + 0.3, 10),
		LiftCFrame = at(15, FLOOR_Y + 1.6, 10),
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

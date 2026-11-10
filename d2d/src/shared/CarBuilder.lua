-- CarBuilder: builds placeholder cars, engines and containers out of plain parts.
-- These stand in until the real 3D models (from Roblox's AI generator) are ready:
-- swap BuildCar's body for a mesh later and everything else keeps working.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local CarBuilder = {}

-- length, width, body height, cabin height, cabin length, cabin z-offset, wheel diameter, hood length, wing
local SHAPES = {
	mini = { 8, 4.6, 1.6, 1.6, 4.5, 0.4, 1.6, 2.0 },
	hatch = { 9.5, 5, 1.7, 1.6, 5, 1.5, 1.8, 2.6 },
	sedan = { 11, 5.2, 1.6, 1.6, 5, 0.6, 1.8, 3 },
	wagon = { 11.5, 5.2, 1.6, 1.7, 7, 1.6, 1.8, 3 },
	van = { 11, 5.4, 2.4, 2.0, 8.5, 1.0, 1.9, 2 },
	truck = { 12.5, 5.6, 2.0, 1.8, 4, -1.5, 2.4, 3.2 },
	suv = { 11, 5.6, 2.2, 1.9, 6.5, 0.9, 2.4, 3 },
	bus = { 15, 6, 2.6, 2.4, 13, 0.6, 2.2, 1.4 },
	classic = { 13, 5.4, 1.5, 1.5, 5, 0.8, 1.8, 4 },
	muscle = { 12, 5.4, 1.6, 1.4, 4.5, 1.2, 2.0, 4 },
	coupe = { 10.5, 5.2, 1.4, 1.3, 4.2, 1.0, 1.9, 3.2 },
	racer = { 12, 5.4, 1.2, 1.0, 3, 0.5, 2.0, 3.5, true },
	super = { 11.5, 5.6, 1.2, 1.1, 4, -0.2, 2.0, 3 },
	hyper = { 12, 5.8, 1.1, 1.0, 4.2, 0, 2.1, 3.2, true },
	limo = { 17, 5.4, 1.7, 1.6, 11, 1.0, 1.9, 3 },
	open = { 10, 5, 1.5, 0.9, 1.0, -1.2, 1.9, 3 },
}

local function newPart(model, name, size, cf, color, props)
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.CanCollide = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Material = Enum.Material.SmoothPlastic
	p.Size = size
	p.CFrame = cf
	p.Color = color
	if props then
		for k, v in pairs(props) do
			p[k] = v
		end
	end
	p.Parent = model
	return p
end

function CarBuilder.GetShape(carId)
	local car = Config.CarsById[carId]
	return SHAPES[car and car.Shape or "sedan"] or SHAPES.sedan
end

-- Builds an engine model sized for a car; its pivot is the bottom center.
function CarBuilder.BuildEngine(engineIndex, width, length, silhouette)
	local engine = Config.Engines[engineIndex] or Config.Engines[1]
	local model = Instance.new("Model")
	model.Name = "Engine"
	local color = silhouette and Color3.new(0, 0, 0) or engine.Color
	local w, l = width * 0.55, length * 0.7
	local block = newPart(model, "EngineBlock", Vector3.new(w, 0.6, l), CFrame.new(0, 0.3, 0), color, {
		Material = engineIndex >= 6 and Enum.Material.Neon or Enum.Material.Metal,
	})
	model.PrimaryPart = block
	if engineIndex >= 3 and not silhouette then
		-- intake pipe for turbo and up
		newPart(model, "Pipe", Vector3.new(0.4, 0.4, l * 0.8), CFrame.new(w * 0.45, 0.75, 0), Color3.fromRGB(60, 140, 255), { Material = Enum.Material.Metal })
	end
	if engineIndex >= 4 and not silhouette then
		-- two rows of cylinders
		for _, side in ipairs({ -1, 1 }) do
			for i = 0, 3 do
				local cyl = newPart(model, "Cylinder", Vector3.new(0.4, 0.5, 0.5),
					CFrame.new(side * w * 0.25, 0.85, -l * 0.35 + i * l * 0.23) * CFrame.Angles(0, 0, math.rad(90)),
					Color3.fromRGB(230, 230, 240), { Material = Enum.Material.Metal, Shape = Enum.PartType.Cylinder })
				cyl.Size = Vector3.new(0.4, 0.5, 0.5)
			end
		end
	end
	if engineIndex >= 5 and not silhouette then
		for _, side in ipairs({ -1, 1 }) do
			local turbo = newPart(model, "Turbo", Vector3.new(0.8, 0.8, 0.8), CFrame.new(side * w * 0.55, 0.6, l * 0.3), Color3.fromRGB(70, 70, 75), { Shape = Enum.PartType.Ball, Material = Enum.Material.Metal })
			turbo.Size = Vector3.new(0.8, 0.8, 0.8)
		end
	end
	if engineIndex >= 6 and not silhouette then
		local light = Instance.new("PointLight")
		light.Color = engine.Color
		light.Range = 10
		light.Brightness = 2
		light.Parent = block
	end
	if engineIndex >= 7 and not silhouette then
		local fire = Instance.new("Fire")
		fire.Size = 2
		fire.Heat = 4
		fire.Color = Color3.fromRGB(255, 140, 40)
		fire.SecondaryColor = Color3.fromRGB(255, 230, 80)
		fire.Parent = block
	end
	return model
end

-- Builds a car. Front of the car faces -Z. Pivot = ground center.
-- opts.Engine = engine index to show under an open hood; opts.Silhouette = all black
---------------------------------------------------------------------
-- AI-generated car models (ReplicatedStorage.Assets.Cars.<name>)
-- Each generated model has sub-models "body", "hood" and four wheels, each holding a MeshPart.
---------------------------------------------------------------------
-- which generated model each body shape uses, in order of preference
local ASSET_FOR_SHAPE = {
	mini = { "mini", "hatch" },
	hatch = { "hatch" },
	sedan = { "sedan", "hatch" },
	wagon = { "wagon", "sedan", "hatch" },
	van = { "van", "suv", "hatch" },
	truck = { "truck", "suv", "hatch" },
	suv = { "suv", "hatch" },
	bus = { "bus", "van", "suv", "hatch" },
	classic = { "classic", "sedan", "hatch" },
	muscle = { "muscle", "sedan", "hatch" },
	coupe = { "coupe", "muscle", "sedan", "hatch" },
	racer = { "racer", "super", "muscle", "hatch" },
	super = { "super", "muscle", "hatch" },
	hyper = { "hyper", "super", "muscle", "hatch" },
	limo = { "limo", "sedan", "hatch" },
	open = { "open", "super", "muscle", "hatch" },
}

local function findAsset(car)
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local cars = assets and assets:FindFirstChild("Cars")
	if not cars then
		return nil
	end
	-- a model made for this exact car wins, then one for its body shape
	local exact = cars:FindFirstChild(car.Id)
	if exact then
		return exact
	end
	for _, name in ipairs(ASSET_FOR_SHAPE[car.Shape] or { "hatch" }) do
		local m = cars:FindFirstChild(name)
		if m then
			return m
		end
	end
	return nil
end

local function stripTexture(p)
	for _, c in ipairs(p:GetChildren()) do
		if c:IsA("SurfaceAppearance") then
			c:Destroy()
		end
	end
	pcall(function()
		p.TextureID = ""
	end)
end

local function buildFromAsset(car, source, opts)
	local L = CarBuilder.GetShape(car.Id)[1]
	local sil = opts.Silhouette
	local rarity = car.Rarity
	local clone = source:Clone()

	-- flatten: every MeshPart goes to the top level with a simple name
	local model = Instance.new("Model")
	model.Name = car.Name
	local parts = {}
	for _, d in ipairs(clone:GetDescendants()) do
		if d:IsA("BasePart") then
			local group = (d.Parent and d.Parent ~= clone and d.Parent.Name or d.Name):lower()
			local name = "Trim"
			if group:find("body") then
				name = "Body"
			elseif group:find("hood") then
				name = "Hood"
			elseif group:find("wheel") then
				name = "Wheel"
			end
			d.Name = name
			d.Anchored = true
			d.CanCollide = name == "Body"
			d.CanTouch = false
			d.Parent = model
			table.insert(parts, d)
		end
	end
	clone:Destroy()
	local body = model:FindFirstChild("Body") or parts[1]
	local hood = model:FindFirstChild("Hood")

	-- world-space box around a set of parts (GetBoundingBox follows the model's own rotation, which can be anything)
	local function worldBox()
		local minV = Vector3.new(math.huge, math.huge, math.huge)
		local maxV = -minV
		for _, p in ipairs(parts) do
			local cf, h = p.CFrame, p.Size / 2
			local r, u, l = cf.RightVector, cf.UpVector, cf.LookVector
			local ext = Vector3.new(
				math.abs(r.X) * h.X + math.abs(u.X) * h.Y + math.abs(l.X) * h.Z,
				math.abs(r.Y) * h.X + math.abs(u.Y) * h.Y + math.abs(l.Y) * h.Z,
				math.abs(r.Z) * h.X + math.abs(u.Z) * h.Y + math.abs(l.Z) * h.Z
			)
			minV = minV:Min(cf.Position - ext)
			maxV = maxV:Max(cf.Position + ext)
		end
		return (minV + maxV) / 2, maxV - minV, minV
	end

	-- turn it so the front (where the hood is) faces -Z
	local center, size = worldBox()
	local alongX = size.X > size.Z
	local front
	if hood then
		local d = hood.Position - center
		if alongX then
			front = Vector3.new(d.X >= 0 and 1 or -1, 0, 0)
		else
			front = Vector3.new(0, 0, d.Z >= 0 and 1 or -1)
		end
	else
		front = alongX and Vector3.new(-1, 0, 0) or Vector3.new(0, 0, -1)
	end
	model.WorldPivot = CFrame.lookAt(center, center + front)
	model:PivotTo(CFrame.new())
	-- scale to the length of this car's shape
	local _, size2 = worldBox()
	pcall(function()
		-- AI cars are taller and rounder than the old block cars, so make them a bit longer to read well
		model:ScaleTo(math.min(L * 1.25, 14.5) / math.max(size2.Z, 0.1))
	end)
	-- sit on the ground, centered
	local c3, _, min3 = worldBox()
	model.WorldPivot = CFrame.new(c3.X, min3.Y, c3.Z)
	model:PivotTo(CFrame.new())

	-- special paint jobs and silhouettes
	for _, p in ipairs(parts) do
		if sil then
			stripTexture(p)
			p.Color = Color3.new(0, 0, 0)
			p.Material = Enum.Material.SmoothPlastic
		elseif p.Name ~= "Wheel" and rarity == 6 then
			stripTexture(p)
			p.Material = Enum.Material.Glass
			p.Color = Color3.fromRGB(150, 230, 255)
			p.Transparency = 0.15
			p.Reflectance = 0.3
		elseif p.Name ~= "Wheel" and rarity == 7 then
			stripTexture(p)
			p.Material = Enum.Material.Metal
			p.Color = Color3.fromRGB(255, 200, 50)
			p.Reflectance = 0.4
		end
	end
	if not sil and rarity >= 6 and body then
		local sparkles = Instance.new("Sparkles")
		sparkles.SparkleColor = Config.Rarities[rarity].Color
		sparkles.Parent = body
		local light = Instance.new("PointLight")
		light.Color = Config.Rarities[rarity].Color
		light.Range = 14
		light.Brightness = 1.5
		light.Parent = body
	end

	-- invisible root at the ground center (labels and prompts hang on it)
	local root = newPart(model, "Root", Vector3.new(1, 1, 1), CFrame.new(0, 0.5, 0), Color3.new(0, 0, 0), { Transparency = 1, CanQuery = false })
	model.PrimaryPart = root

	-- open hood with the engine showing
	if opts.Engine and hood then
		local cf, half = hood.CFrame, hood.Size / 2
		local r, u, l = cf.RightVector, cf.UpVector, cf.LookVector
		local ext = Vector3.new(
			math.abs(r.X) * half.X + math.abs(u.X) * half.Y + math.abs(l.X) * half.Z,
			math.abs(r.Y) * half.X + math.abs(u.Y) * half.Y + math.abs(l.Y) * half.Z,
			math.abs(r.Z) * half.X + math.abs(u.Z) * half.Y + math.abs(l.Z) * half.Z
		)
		local hp = hood.Position
		local engine = CarBuilder.BuildEngine(opts.Engine, ext.X * 2, ext.Z * 2, sil)
		engine:PivotTo(CFrame.new(0, hp.Y - ext.Y, hp.Z))
		engine.Parent = model
		-- hinge on the hood's rear edge (front of the car is -Z, so the rear edge is +Z)
		local hinge = CFrame.new(0, hp.Y, hp.Z + ext.Z)
		local relative = hinge:ToObjectSpace(cf)
		hood.CFrame = hinge * CFrame.Angles(math.rad(65), 0, 0) * relative
	end

	model:SetAttribute("CarId", car.Id)
	return model
end

function CarBuilder.BuildCar(carId, opts)
	opts = opts or {}
	local car = Config.CarsById[carId]
	local asset = car and findAsset(car)
	if asset then
		local ok, result = pcall(buildFromAsset, car, asset, opts)
		if ok and result then
			return result
		end
		warn("[D2D] could not use model for " .. carId .. ": " .. tostring(result))
	end
	local s = CarBuilder.GetShape(carId)
	local L, W, H, cabH, cabL, cabZ, wheelD, hoodL, wing = s[1], s[2], s[3], s[4], s[5], s[6], s[7], s[8], s[9]
	local sil = opts.Silhouette
	local black = Color3.new(0, 0, 0)

	local model = Instance.new("Model")
	model.Name = car and car.Name or "Car"

	local root = newPart(model, "Root", Vector3.new(1, 1, 1), CFrame.new(0, 0.5, 0), black, { Transparency = 1 })
	model.PrimaryPart = root

	local clearance = wheelD * 0.35
	local top = clearance + H
	local bodyColor = sil and black or car.Color
	local rarity = car and car.Rarity or 1

	local bodyProps = { CanCollide = true }
	if not sil and rarity == 6 then
		bodyProps.Material = Enum.Material.Glass
		bodyProps.Transparency = 0.15
		bodyColor = Color3.fromRGB(150, 230, 255)
	elseif not sil and rarity == 7 then
		bodyProps.Reflectance = 0.35
		bodyProps.Material = Enum.Material.Metal
		bodyColor = Color3.fromRGB(255, 200, 50)
	end
	if not sil and rarity < 6 then
		bodyProps.Reflectance = 0.2 -- glossy paint
	end
	local body = newPart(model, "Body", Vector3.new(W, H, L), CFrame.new(0, clearance + H / 2, 0), bodyColor, bodyProps)
	local trimColor = sil and black or Color3.fromRGB(30, 30, 34)
	local chrome = sil and black or Color3.fromRGB(215, 218, 225)
	local chromeProps = sil and nil or { Material = Enum.Material.Metal, Reflectance = 0.35 }

	-- bumpers, side skirts and grille
	for _, sz in ipairs({ -1, 1 }) do
		newPart(model, "Bumper", Vector3.new(W + 0.1, H * 0.38, 0.5), CFrame.new(0, clearance + H * 0.19, sz * (L / 2 + 0.05)), trimColor)
	end
	for _, sx in ipairs({ -1, 1 }) do
		newPart(model, "Skirt", Vector3.new(0.2, H * 0.22, L * 0.62), CFrame.new(sx * (W / 2 + 0.05), clearance + H * 0.11, 0), trimColor)
	end
	newPart(model, "Grille", Vector3.new(W * 0.45, H * 0.4, 0.15), CFrame.new(0, clearance + H * 0.55, -L / 2 - 0.08), trimColor)
	if not sil then
		newPart(model, "GrilleBar", Vector3.new(W * 0.47, 0.12, 0.2), CFrame.new(0, clearance + H * 0.62, -L / 2 - 0.12), chrome, chromeProps)
		for _, sz in ipairs({ -1, 1 }) do
			newPart(model, "Plate", Vector3.new(1.6, 0.5, 0.06), CFrame.new(0, clearance + H * 0.22, sz * (L / 2 + 0.33)), Color3.fromRGB(245, 245, 235))
		end
		for _, sx in ipairs({ -1, 1 }) do
			local pipe = newPart(model, "Exhaust", Vector3.new(0.7, 0.35, 0.35), CFrame.new(sx * W * 0.28, clearance + 0.1, L / 2 + 0.25) * CFrame.Angles(0, math.rad(90), 0), chrome, { Shape = Enum.PartType.Cylinder, Material = Enum.Material.Metal, Reflectance = 0.35 })
			pipe.Size = Vector3.new(0.7, 0.35, 0.35)
		end
	end

	-- cabin: tinted glass with a sloped windshield and back window, and a painted roof
	local glass = sil and black or Color3.fromRGB(25, 40, 65)
	local glassProps = {
		Transparency = sil and 0 or 0.1,
		Material = sil and Enum.Material.SmoothPlastic or Enum.Material.Glass,
		Reflectance = sil and 0 or 0.3,
	}
	local isOpen = car and car.Shape == "open"
	if isOpen then
		-- convertible: just a windshield and seats
		newPart(model, "Windshield", Vector3.new(W * 0.85, cabH, 0.2), CFrame.new(0, top + cabH / 2, cabZ - 0.5) * CFrame.Angles(math.rad(-20), 0, 0), glass, glassProps)
		for _, sx in ipairs({ -1, 1 }) do
			newPart(model, "Seat", Vector3.new(W * 0.32, 1.2, 1.2), CFrame.new(sx * W * 0.2, top + 0.4, cabZ + 1.2), sil and black or Color3.fromRGB(120, 60, 40))
		end
	else
		local front = cabL >= 3 and math.min(1.6, cabL * 0.3) or 0
		local back = cabL >= 3 and math.min(1.2, cabL * 0.22) or 0
		local midL = cabL - front - back
		local cabFront = cabZ - cabL / 2
		local midZ = cabFront + front + midL / 2
		newPart(model, "Cabin", Vector3.new(W * 0.86, cabH, midL), CFrame.new(0, top + cabH / 2, midZ), glass, glassProps)
		if front > 0 then
			local w = Instance.new("WedgePart")
			w.Name = "Windshield"
			w.Anchored = true
			w.CanCollide = false
			w.Size = Vector3.new(W * 0.86, cabH, front)
			w.CFrame = CFrame.new(0, top + cabH / 2, cabFront + front / 2)
			w.Color = glass
			for k, v in pairs(glassProps) do
				w[k] = v
			end
			w.Parent = model
		end
		if back > 0 then
			local w = Instance.new("WedgePart")
			w.Name = "RearWindow"
			w.Anchored = true
			w.CanCollide = false
			w.Size = Vector3.new(W * 0.86, cabH, back)
			w.CFrame = CFrame.new(0, top + cabH / 2, cabFront + cabL - back / 2) * CFrame.Angles(0, math.rad(180), 0)
			w.Color = glass
			for k, v in pairs(glassProps) do
				w[k] = v
			end
			w.Parent = model
		end
		newPart(model, "Roof", Vector3.new(W * 0.88, 0.22, midL + 0.1), CFrame.new(0, top + cabH + 0.08, midZ), bodyColor, {
			Material = bodyProps.Material or Enum.Material.SmoothPlastic,
			Reflectance = bodyProps.Reflectance or 0,
			Transparency = bodyProps.Transparency or 0,
		})
		-- mirrors
		for _, sx in ipairs({ -1, 1 }) do
			newPart(model, "Mirror", Vector3.new(0.5, 0.35, 0.3), CFrame.new(sx * (W * 0.43 + 0.3), top + 0.35, cabFront + front + 0.2), bodyColor)
		end
	end

	-- wheels: rubber tire, shiny rim, colored hub
	local wheelColor = sil and black or Color3.fromRGB(22, 22, 25)
	local hubColor = sil and black or (rarity >= 4 and Config.Rarities[rarity].Color or Color3.fromRGB(70, 70, 80))
	for _, sx in ipairs({ -1, 1 }) do
		for _, sz in ipairs({ -1, 1 }) do
			local wcf = CFrame.new(sx * (W / 2 - 0.25), wheelD / 2, sz * (L / 2 - wheelD * 0.75))
			local wheel = newPart(model, "Wheel", Vector3.new(0.9, wheelD, wheelD), wcf, wheelColor, { Shape = Enum.PartType.Cylinder, Material = sil and Enum.Material.SmoothPlastic or Enum.Material.Rubber })
			wheel.Size = Vector3.new(0.9, wheelD, wheelD)
			if not sil then
				local rim = newPart(model, "Rim", Vector3.new(0.95, wheelD * 0.62, wheelD * 0.62), wcf, chrome, { Shape = Enum.PartType.Cylinder, Material = Enum.Material.Metal, Reflectance = 0.4 })
				rim.Size = Vector3.new(0.95, wheelD * 0.62, wheelD * 0.62)
				local hub = newPart(model, "Hub", Vector3.new(1.0, wheelD * 0.25, wheelD * 0.25), wcf, hubColor, { Shape = Enum.PartType.Cylinder })
				hub.Size = Vector3.new(1.0, wheelD * 0.25, wheelD * 0.25)
			end
			-- dark wheel arch above each wheel
			newPart(model, "Arch", Vector3.new(0.25, 0.3, wheelD * 1.25), CFrame.new(sx * (W / 2 + 0.06), clearance + H * 0.62, sz * (L / 2 - wheelD * 0.75)), trimColor)
		end
	end

	-- lights
	if not sil then
		for _, sx in ipairs({ -1, 1 }) do
			newPart(model, "Headlight", Vector3.new(W * 0.2, 0.4, 0.2), CFrame.new(sx * W * 0.34, clearance + H * 0.68, -L / 2 - 0.05), Color3.fromRGB(255, 250, 225), { Material = Enum.Material.Neon })
			newPart(model, "Taillight", Vector3.new(W * 0.22, 0.35, 0.2), CFrame.new(sx * W * 0.32, clearance + H * 0.7, L / 2 + 0.05), Color3.fromRGB(230, 25, 35), { Material = Enum.Material.Neon })
		end
		if car and (car.Shape == "super" or car.Shape == "hyper" or car.Shape == "racer") then
			newPart(model, "LightBar", Vector3.new(W * 0.8, 0.12, 0.2), CFrame.new(0, clearance + H * 0.85, -L / 2 - 0.06), Color3.fromRGB(200, 240, 255), { Material = Enum.Material.Neon })
		end
	end

	-- racing wing
	if wing then
		newPart(model, "Wing", Vector3.new(W * 0.9, 0.2, 1.2), CFrame.new(0, top + 1.2, L / 2 - 0.8), sil and black or Color3.fromRGB(30, 30, 30))
		for _, sx in ipairs({ -1, 1 }) do
			newPart(model, "WingPost", Vector3.new(0.2, 1.1, 0.4), CFrame.new(sx * W * 0.3, top + 0.6, L / 2 - 0.8), sil and black or Color3.fromRGB(30, 30, 30))
		end
	end

	-- stripe for Legendary and up
	if not sil and rarity >= 4 and rarity <= 5 then
		newPart(model, "Stripe", Vector3.new(0.8, 0.05, L * 0.98), CFrame.new(0, top + 0.03, 0), Config.Rarities[rarity].Color, { Material = Enum.Material.Neon })
	end
	if not sil and rarity >= 6 then
		local sparkles = Instance.new("Sparkles")
		sparkles.SparkleColor = Config.Rarities[rarity].Color
		sparkles.Parent = body
		local light = Instance.new("PointLight")
		light.Color = Config.Rarities[rarity].Color
		light.Range = 14
		light.Brightness = 1.5
		light.Parent = body
	end

	-- hood: closed, or open with the engine showing
	local hoodZ0 = -L / 2 -- front edge
	local hingeZ = -L / 2 + hoodL -- rear edge of the hood (the hinge)
	local hoodColor = bodyColor
	if opts.Engine then
		local engine = CarBuilder.BuildEngine(opts.Engine, W, hoodL, sil)
		engine:PivotTo(CFrame.new(0, top, (hoodZ0 + hingeZ) / 2))
		engine.Parent = model
		local hinge = CFrame.new(0, top + 0.15, hingeZ)
		local hood = newPart(model, "Hood", Vector3.new(W * 0.96, 0.25, hoodL), CFrame.new(0, top + 0.15, (hoodZ0 + hingeZ) / 2), hoodColor, {
			Material = bodyProps.Material or Enum.Material.SmoothPlastic,
			Reflectance = bodyProps.Reflectance or 0,
		})
		-- swing the hood up around its rear edge
		local relative = hinge:ToObjectSpace(hood.CFrame)
		hood.CFrame = hinge * CFrame.Angles(math.rad(70), 0, 0) * relative
	else
		newPart(model, "Hood", Vector3.new(W * 0.96, 0.25, hoodL), CFrame.new(0, top + 0.12, (hoodZ0 + hingeZ) / 2), hoodColor, {
			Material = bodyProps.Material or Enum.Material.SmoothPlastic,
		})
	end

	model:SetAttribute("CarId", carId)
	return model
end

-- Shipping container in the color of its level. Pivot = ground center.
function CarBuilder.BuildContainer(level)
	local info = Config.Containers[level]
	local model = Instance.new("Model")
	model.Name = "Container" .. level
	local root = newPart(model, "Root", Vector3.new(1, 1, 1), CFrame.new(0, 0.5, 0), Color3.new(0, 0, 0), { Transparency = 1 })
	model.PrimaryPart = root
	-- a realistic container model from the Creator Store, with a painted band in the level's color
	local Props = require(ReplicatedStorage.Shared:WaitForChild("Props"))
	if Props.Has("ShippingContainer") then
		local mesh = Props.Place("ShippingContainer", model, CFrame.new(), { Length = 14, LongZ = true })
		if mesh then
			-- remove any printed logos/text and paint it in the level's color
			for _, d in ipairs(mesh:GetDescendants()) do
				if d:IsA("Decal") or d:IsA("Texture") or d:IsA("SurfaceGui") then
					d:Destroy()
				elseif d:IsA("SpecialMesh") then
					d.TextureId = ""
				elseif d:IsA("BasePart") then
					stripTexture(d)
					d.Color = info.Color
					d.Material = Enum.Material.CorrodedMetal
				end
			end
			local box = newPart(model, "Box", Vector3.new(8, 7, 14), CFrame.new(0, 3.5, 0), info.Color, { Transparency = 1, CanCollide = true })
			box.Name = "Box"
			for _, x in ipairs({ -1, 1 }) do
				local _, size = mesh:GetBoundingBox()
				local band = newPart(model, "LevelBand", Vector3.new(0.12, 1.4, 13), CFrame.new(x * (size.X / 2 + 0.06), size.Y * 0.62, 0), info.Color, { Material = Enum.Material.SmoothPlastic })
				local gui = Instance.new("SurfaceGui")
				gui.Face = x > 0 and Enum.NormalId.Right or Enum.NormalId.Left
				gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
				gui.PixelsPerStud = 30
				local t = Instance.new("TextLabel")
				t.BackgroundTransparency = 1
				t.Size = UDim2.new(1, 0, 1, 0)
				t.Font = Enum.Font.GothamBlack
				t.TextScaled = true
				t.TextColor3 = Color3.new(1, 1, 1)
				t.Text = "D2D LOGISTICS  ·  LEVEL " .. level
				t.Parent = gui
				gui.Parent = band
			end
			model:SetAttribute("ContainerLevel", level)
			return model
		end
	end
	local box = newPart(model, "Box", Vector3.new(8, 7, 14), CFrame.new(0, 3.5, 0), info.Color, { Material = Enum.Material.DiamondPlate, CanCollide = true })
	box.Name = "Box"
	local darker = info.Color:Lerp(Color3.new(0, 0, 0), 0.3)
	for _, z in ipairs({ -6.8, -2.3, 2.3, 6.8 }) do
		newPart(model, "Rib", Vector3.new(8.2, 7.1, 0.3), CFrame.new(0, 3.5, z), darker, { Material = Enum.Material.Metal })
	end
	-- door bars at the back
	for _, x in ipairs({ -1.5, 1.5 }) do
		newPart(model, "Bar", Vector3.new(0.2, 6.5, 0.2), CFrame.new(x, 3.5, 7.15), Color3.fromRGB(200, 200, 200), { Material = Enum.Material.Metal })
	end
	-- corner castings, top rails and a painted level number
	for _, x in ipairs({ -4.05, 4.05 }) do
		for _, z in ipairs({ -7.05, 7.05 }) do
			newPart(model, "Corner", Vector3.new(0.5, 7.3, 0.5), CFrame.new(x, 3.6, z), darker:Lerp(Color3.new(0, 0, 0), 0.3), { Material = Enum.Material.Metal })
		end
		newPart(model, "Rail", Vector3.new(0.4, 0.4, 14.2), CFrame.new(x, 7.1, 0), darker, { Material = Enum.Material.Metal })
	end
	for _, x in ipairs({ -0.6, 0.6 }) do
		newPart(model, "Handle", Vector3.new(0.15, 1.2, 0.15), CFrame.new(x, 3.2, 7.25), Color3.fromRGB(240, 200, 60), { Material = Enum.Material.Metal })
	end
	for _, face in ipairs({ Enum.NormalId.Left, Enum.NormalId.Right }) do
		local gui = Instance.new("SurfaceGui")
		gui.Face = face
		gui.LightInfluence = 0.3
		gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		gui.PixelsPerStud = 20
		local t = Instance.new("TextLabel")
		t.BackgroundTransparency = 1
		t.AnchorPoint = Vector2.new(0.5, 0.5)
		t.Position = UDim2.new(0.5, 0, 0.32, 0)
		t.Size = UDim2.new(0.5, 0, 0.26, 0)
		t.Font = Enum.Font.FredokaOne
		t.TextScaled = true
		t.TextColor3 = Color3.new(1, 1, 1)
		t.TextTransparency = 0.1
		t.Text = "D2D  #" .. level
		t.Parent = gui
		gui.Parent = box
	end
	model:SetAttribute("ContainerLevel", level)
	return model
end

return CarBuilder

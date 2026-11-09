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
function CarBuilder.BuildCar(carId, opts)
	opts = opts or {}
	local car = Config.CarsById[carId]
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
	local body = newPart(model, "Body", Vector3.new(W, H, L), CFrame.new(0, clearance + H / 2, 0), bodyColor, bodyProps)

	-- cabin / windows
	local glass = sil and black or Color3.fromRGB(40, 60, 90)
	newPart(model, "Cabin", Vector3.new(W * 0.85, cabH, cabL), CFrame.new(0, top + cabH / 2, cabZ), glass, {
		Transparency = sil and 0 or 0.15,
		Material = sil and Enum.Material.SmoothPlastic or Enum.Material.Glass,
	})
	if car and car.Shape == "open" then
		model.Cabin.Transparency = sil and 0 or 0.4
	end

	-- wheels
	local wheelColor = sil and black or Color3.fromRGB(25, 25, 28)
	for _, sx in ipairs({ -1, 1 }) do
		for _, sz in ipairs({ -1, 1 }) do
			local wheel = newPart(model, "Wheel", Vector3.new(0.9, wheelD, wheelD),
				CFrame.new(sx * (W / 2 - 0.25), wheelD / 2, sz * (L / 2 - wheelD * 0.75)), wheelColor,
				{ Shape = Enum.PartType.Cylinder })
			wheel.Size = Vector3.new(0.9, wheelD, wheelD)
			if not sil then
				newPart(model, "Rim", Vector3.new(0.95, wheelD * 0.55, wheelD * 0.55), wheel.CFrame, Color3.fromRGB(200, 200, 210), { Shape = Enum.PartType.Cylinder, Material = Enum.Material.Metal }).Size = Vector3.new(0.95, wheelD * 0.55, wheelD * 0.55)
			end
		end
	end

	-- lights
	if not sil then
		for _, sx in ipairs({ -1, 1 }) do
			newPart(model, "Headlight", Vector3.new(1, 0.4, 0.2), CFrame.new(sx * W * 0.32, clearance + H * 0.65, -L / 2 - 0.05), Color3.fromRGB(255, 250, 220), { Material = Enum.Material.Neon })
			newPart(model, "Taillight", Vector3.new(1, 0.4, 0.2), CFrame.new(sx * W * 0.32, clearance + H * 0.65, L / 2 + 0.05), Color3.fromRGB(220, 30, 30), { Material = Enum.Material.Neon })
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
	model:SetAttribute("ContainerLevel", level)
	return model
end

return CarBuilder

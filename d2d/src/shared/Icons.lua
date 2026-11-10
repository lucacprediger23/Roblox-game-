-- Icons: small 3D models rendered in ViewportFrames, used as the game's UI icons
-- (cash stack, coin, index book, house, tire, truck, crate, gear, car, sponge, showroom, clover).
-- Rendered like Clean a Painting's chunky 3D icons, with no image uploads needed.

local Icons = {}

local function p(model, size, cf, color, material, shape)
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = false
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	if shape then
		part.Shape = shape
	end
	part.Size = size
	part.CFrame = cf
	part.Color = color
	part.Material = material or Enum.Material.SmoothPlastic
	part.Parent = model
	return part
end

local function wedge(model, size, cf, color)
	local w = Instance.new("WedgePart")
	w.Anchored = true
	w.Size = size
	w.CFrame = cf
	w.Color = color
	w.Material = Enum.Material.SmoothPlastic
	w.Parent = model
	return w
end

local CYL = Enum.PartType.Cylinder
local BALL = Enum.PartType.Ball
local R = CFrame.Angles

local builders = {}

builders.Cash = function(m)
	local green, light, band = Color3.fromRGB(70, 170, 80), Color3.fromRGB(150, 220, 140), Color3.fromRGB(245, 235, 205)
	for i = 0, 3 do
		local cf = CFrame.new(0, i * 0.42, 0) * R(0, math.rad(i * 4 - 6), 0)
		p(m, Vector3.new(4.2, 0.38, 2.1), cf, green)
		p(m, Vector3.new(3.2, 0.4, 1.3), cf, light)
		p(m, Vector3.new(0.9, 0.42, 0.9), cf, green, nil, CYL).CFrame = cf * R(0, 0, math.rad(90))
	end
	p(m, Vector3.new(0.9, 1.9, 2.25), CFrame.new(0, 0.62, 0), band)
end

builders.Coin = function(m)
	local gold, dark = Color3.fromRGB(255, 200, 40), Color3.fromRGB(215, 150, 20)
	p(m, Vector3.new(0.6, 4, 4), R(0, math.rad(90), 0), dark, Enum.Material.Metal, CYL)
	p(m, Vector3.new(0.7, 3.3, 3.3), R(0, math.rad(90), 0), gold, Enum.Material.Metal, CYL)
	-- a star made of two crossed wedges pairs
	for k = 0, 4 do
		local a = math.rad(k * 72)
		p(m, Vector3.new(0.5, 1.3, 0.75), CFrame.new(0.42, 0, 0) * R(a, 0, 0) * CFrame.new(0, 0.6, 0), dark, Enum.Material.Metal).CFrame = CFrame.new(0, 0, 0.42) * R(0, 0, a) * CFrame.new(0, 0.6, 0)
	end
	p(m, Vector3.new(0.9, 0.9, 0.5), CFrame.new(0, 0, 0.45), dark, Enum.Material.Metal, BALL)
end

builders.Book = function(m)
	local blue, page, gold = Color3.fromRGB(40, 110, 230), Color3.fromRGB(250, 245, 230), Color3.fromRGB(255, 200, 50)
	p(m, Vector3.new(3.4, 4.2, 0.8), CFrame.new(), blue)
	p(m, Vector3.new(3.1, 3.9, 0.9), CFrame.new(0.2, 0, 0), page)
	p(m, Vector3.new(3.4, 4.2, 0.2), CFrame.new(0, 0, 0.5), blue)
	-- picture on the cover
	p(m, Vector3.new(2.2, 2, 0.1), CFrame.new(0, 0.2, 0.62), Color3.fromRGB(150, 210, 255))
	p(m, Vector3.new(2.2, 0.8, 0.12), CFrame.new(0, -0.4, 0.63), Color3.fromRGB(90, 190, 80))
	p(m, Vector3.new(0.8, 0.8, 0.13), CFrame.new(0.4, 0.15, 0.64), Color3.fromRGB(60, 150, 60), nil, BALL)
	for _, c in ipairs({ { -1.6, 2 }, { 1.6, 2 }, { -1.6, -2 }, { 1.6, -2 } }) do
		p(m, Vector3.new(0.6, 0.6, 0.3), CFrame.new(c[1], c[2], 0.55), gold, Enum.Material.Metal)
	end
end

builders.Home = function(m)
	p(m, Vector3.new(3.6, 2.6, 3), CFrame.new(0, -0.6, 0), Color3.fromRGB(250, 240, 215))
	wedge(m, Vector3.new(4.2, 1.6, 1.8), CFrame.new(0, 1.5, 0.85) * R(0, math.pi, 0), Color3.fromRGB(220, 70, 55))
	wedge(m, Vector3.new(4.2, 1.6, 1.8), CFrame.new(0, 1.5, -0.85), Color3.fromRGB(220, 70, 55))
	p(m, Vector3.new(0.9, 1.5, 0.1), CFrame.new(0, -1.15, 1.52), Color3.fromRGB(150, 95, 55))
	p(m, Vector3.new(0.8, 0.8, 0.1), CFrame.new(1.1, -0.3, 1.52), Color3.fromRGB(120, 190, 240))
	p(m, Vector3.new(0.8, 0.8, 0.1), CFrame.new(-1.1, -0.3, 1.52), Color3.fromRGB(120, 190, 240))
end

builders.Tire = function(m)
	p(m, Vector3.new(1.6, 4, 4), R(0, math.rad(90), 0), Color3.fromRGB(35, 35, 38), Enum.Material.Rubber, CYL)
	p(m, Vector3.new(1.7, 2.4, 2.4), R(0, math.rad(90), 0), Color3.fromRGB(200, 205, 215), Enum.Material.Metal, CYL)
	p(m, Vector3.new(1.8, 0.8, 0.8), R(0, math.rad(90), 0), Color3.fromRGB(60, 60, 66), Enum.Material.Metal, CYL)
	for k = 0, 4 do
		p(m, Vector3.new(0.25, 1.1, 0.3), CFrame.new(0, 0, 0.88) * R(0, 0, math.rad(k * 72)) * CFrame.new(0, 0.6, 0), Color3.fromRGB(150, 155, 165), Enum.Material.Metal)
	end
end

builders.Truck = function(m)
	p(m, Vector3.new(4.2, 2.6, 2.2), CFrame.new(-0.6, 0.4, 0), Color3.fromRGB(240, 242, 248))
	p(m, Vector3.new(1.6, 1.8, 2.1), CFrame.new(2.3, 0, 0), Color3.fromRGB(80, 150, 240))
	p(m, Vector3.new(0.1, 0.8, 1.6), CFrame.new(3.12, 0.35, 0), Color3.fromRGB(40, 60, 90))
	for _, x in ipairs({ -2, 0.4, 2.3 }) do
		for _, z in ipairs({ -1.1, 1.1 }) do
			p(m, Vector3.new(0.4, 1.1, 1.1), CFrame.new(x, -1.05, z) * R(0, math.rad(90), 0), Color3.fromRGB(30, 30, 32), nil, CYL)
		end
	end
end

builders.Crate = function(m)
	local wood, dark = Color3.fromRGB(240, 150, 40), Color3.fromRGB(180, 90, 25)
	p(m, Vector3.new(3.4, 3.4, 3.4), CFrame.new(), wood, Enum.Material.WoodPlanks)
	for _, a in ipairs({ -1, 1 }) do
		for _, b in ipairs({ -1, 1 }) do
			p(m, Vector3.new(3.6, 0.45, 0.45), CFrame.new(0, a * 1.55, b * 1.55), dark)
			p(m, Vector3.new(0.45, 3.6, 0.45), CFrame.new(a * 1.55, 0, b * 1.55), dark)
			p(m, Vector3.new(0.45, 0.45, 3.6), CFrame.new(a * 1.55, b * 1.55, 0), dark)
		end
	end
	p(m, Vector3.new(0.4, 4.2, 0.2), CFrame.new(0, 0, 1.75) * R(0, 0, math.rad(45)), dark)
	p(m, Vector3.new(0.2, 4.2, 0.4), CFrame.new(1.75, 0, 0) * R(math.rad(45), 0, 0), dark)
end

builders.Gear = function(m)
	local steel, dark = Color3.fromRGB(110, 150, 220), Color3.fromRGB(70, 100, 170)
	p(m, Vector3.new(1, 3.4, 3.4), R(0, math.rad(90), 0), steel, Enum.Material.Metal, CYL)
	for k = 0, 7 do
		p(m, Vector3.new(0.95, 0.9, 1), R(0, 0, math.rad(k * 45)) * CFrame.new(0, 1.9, 0), steel, Enum.Material.Metal)
	end
	p(m, Vector3.new(1.1, 1.4, 1.4), R(0, math.rad(90), 0), dark, Enum.Material.Metal, CYL)
end

builders.Car = function(m)
	local red = Color3.fromRGB(230, 60, 55)
	p(m, Vector3.new(5, 1.2, 2.4), CFrame.new(0, 0, 0), red)
	p(m, Vector3.new(2.6, 1, 2.2), CFrame.new(-0.3, 1.05, 0), Color3.fromRGB(60, 80, 120), Enum.Material.Glass)
	p(m, Vector3.new(2.7, 0.2, 2.25), CFrame.new(-0.3, 1.6, 0), red)
	for _, x in ipairs({ -1.6, 1.6 }) do
		for _, z in ipairs({ -1.2, 1.2 }) do
			p(m, Vector3.new(0.5, 1.3, 1.3), CFrame.new(x, -0.55, z) * R(0, math.rad(90), 0), Color3.fromRGB(30, 30, 32), nil, CYL)
		end
	end
	p(m, Vector3.new(0.1, 0.35, 0.6), CFrame.new(2.52, 0.2, 0.75), Color3.fromRGB(255, 245, 200), Enum.Material.Neon)
	p(m, Vector3.new(0.1, 0.35, 0.6), CFrame.new(2.52, 0.2, -0.75), Color3.fromRGB(255, 245, 200), Enum.Material.Neon)
end

builders.Sponge = function(m)
	p(m, Vector3.new(3.6, 1.8, 2.4), CFrame.new(), Color3.fromRGB(255, 215, 60))
	for _, h in ipairs({ { -1, 0.5 }, { 0.6, -0.2 }, { 1.2, 0.5 }, { -0.2, -0.4 } }) do
		p(m, Vector3.new(0.2, 0.5, 0.5), CFrame.new(h[1], h[2], 1.2) * R(0, math.rad(90), 0), Color3.fromRGB(220, 170, 30), nil, CYL)
	end
	for _, b in ipairs({ { -1.6, 1.3, 0.7 }, { 1.4, 1.4, 0.6 }, { 0, 1.5, 0.8 } }) do
		p(m, Vector3.new(b[3], b[3], b[3]), CFrame.new(b[1], b[2], 0), Color3.fromRGB(220, 240, 255), Enum.Material.Glass, BALL)
	end
end

builders.Showroom = function(m)
	p(m, Vector3.new(4.4, 2.4, 2.6), CFrame.new(0, -0.4, 0), Color3.fromRGB(245, 235, 210))
	for x = -1.6, 1.6, 0.8 do
		p(m, Vector3.new(0.4, 2.2, 0.4), CFrame.new(x, -0.4, 1.35), Color3.fromRGB(255, 250, 240))
	end
	wedge(m, Vector3.new(4.8, 1.2, 1.5), CFrame.new(0, 1.4, 0.7) * R(0, math.pi, 0), Color3.fromRGB(205, 160, 90))
	wedge(m, Vector3.new(4.8, 1.2, 1.5), CFrame.new(0, 1.4, -0.7), Color3.fromRGB(205, 160, 90))
	p(m, Vector3.new(4.8, 0.3, 3), CFrame.new(0, 0.95, 0), Color3.fromRGB(205, 160, 90))
	p(m, Vector3.new(5, 0.3, 3.2), CFrame.new(0, -1.7, 0), Color3.fromRGB(220, 205, 170))
end

builders.Clover = function(m)
	local g = Color3.fromRGB(60, 190, 70)
	for _, c in ipairs({ { 0, 0.8 }, { 0.8, 0 }, { 0, -0.8 }, { -0.8, 0 } }) do
		p(m, Vector3.new(1.4, 1.4, 0.5), CFrame.new(c[1], c[2], 0), g, nil, BALL)
	end
	p(m, Vector3.new(0.3, 1.6, 0.3), CFrame.new(0.5, -1.4, 0) * R(0, 0, math.rad(25)), Color3.fromRGB(40, 140, 50))
end

-- Returns a ViewportFrame showing the icon. props are applied to the frame.
function Icons.Make(kind, props)
	local vp = Instance.new("ViewportFrame")
	vp.BackgroundTransparency = 1
	vp.Ambient = Color3.fromRGB(170, 170, 180)
	vp.LightColor = Color3.fromRGB(255, 250, 240)
	vp.LightDirection = Vector3.new(-1, -1.4, -1.2)
	for k, v in pairs(props or {}) do
		vp[k] = v
	end
	local model = Instance.new("Model")
	local build = builders[kind] or builders.Crate
	build(model)
	model.Parent = vp
	local cf, size = model:GetBoundingBox()
	local cam = Instance.new("Camera")
	cam.FieldOfView = 26
	local radius = size.Magnitude / 2
	local dist = radius / math.tan(math.rad(cam.FieldOfView / 2)) * 1.02
	local dir = Vector3.new(0.45, 0.42, 1).Unit
	cam.CFrame = CFrame.lookAt(cf.Position + dir * dist, cf.Position)
	cam.Parent = vp
	vp.CurrentCamera = cam
	return vp
end

return Icons

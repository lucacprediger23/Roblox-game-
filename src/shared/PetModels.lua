-- PetModels: builds the squishies and eggs out of plain parts, using the specs in Config.
-- No meshes or uploads are needed, so the game works straight away.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local PetModels = {}

local function applyCommon(part)
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Material = Enum.Material.SmoothPlastic
end

-- Builds one part from a spec table. Returns the part (positioned relative to the origin).
local function makePart(spec, scale)
	local className = "Part"
	if spec.Kind == "Wedge" then
		className = "WedgePart"
	end
	local part = Instance.new(className)
	applyCommon(part)

	local size = spec.Size * scale
	local offset = (spec.Offset or Vector3.new(0, 0, 0)) * scale
	local cf = CFrame.new(offset)

	if spec.Kind == "Ellipsoid" then
		part.Size = size
		local mesh = Instance.new("SpecialMesh")
		mesh.MeshType = Enum.MeshType.Sphere
		mesh.Parent = part
	elseif spec.Kind == "Ball" then
		part.Shape = Enum.PartType.Ball
		part.Size = size
	elseif spec.Kind == "Cylinder" then
		-- Roblox cylinders lie along X, so turn them upright
		part.Shape = Enum.PartType.Cylinder
		part.Size = Vector3.new(size.Y, size.X, size.Z)
		cf = cf * CFrame.Angles(0, 0, math.rad(90))
	else
		part.Size = size
	end

	part.Color = spec.Color or Color3.new(1, 1, 1)
	if spec.Material and Enum.Material[spec.Material] then
		part.Material = Enum.Material[spec.Material]
	end
	part.Transparency = spec.Transparency or 0
	part.Reflectance = spec.Reflectance or 0
	part.CFrame = cf
	return part
end

-- Adds cute eyes, blush and a mouth at `facePos`
local function addFace(model, facePos, s)
	local function facePart(kind, size, pos, color)
		local p = makePart({ Kind = kind, Size = size, Color = color }, 1)
		p.CFrame = CFrame.new(pos)
		p.Name = "Face"
		p:SetAttribute("Face", true)
		p.Parent = model
		return p
	end
	local black = Color3.fromRGB(30, 25, 30)
	local white = Color3.new(1, 1, 1)
	local pink = Color3.fromRGB(255, 140, 170)
	for _, side in ipairs({ -1, 1 }) do
		local eyePos = facePos + Vector3.new(0.42 * s * side, 0.1 * s, 0)
		facePart("Ball", Vector3.new(0.45, 0.45, 0.45) * s, eyePos, black)
		facePart("Ball", Vector3.new(0.15, 0.15, 0.15) * s, eyePos + Vector3.new(0.08 * s, 0.1 * s, -0.18 * s), white)
		facePart("Ellipsoid", Vector3.new(0.45, 0.22, 0.1) * s, facePos + Vector3.new(0.85 * s * side, -0.25 * s, -0.02), pink)
	end
	facePart("Ellipsoid", Vector3.new(0.35, 0.15, 0.1) * s, facePos + Vector3.new(0, -0.3 * s, -0.03), black)
end

local function applyMutation(model, body, mutationName)
	if mutationName == "Glitter" then
		local sparkles = Instance.new("Sparkles")
		sparkles.SparkleColor = Color3.fromRGB(255, 240, 255)
		sparkles.Parent = body
	elseif mutationName == "Frozen" then
		for _, part in ipairs(model:GetDescendants()) do
			if part:IsA("BasePart") and not part:GetAttribute("Face") then
				part.Color = part.Color:Lerp(Color3.fromRGB(170, 220, 255), 0.55)
				part.Material = Enum.Material.Ice
			end
		end
	elseif mutationName == "Spicy" then
		local fire = Instance.new("Fire")
		fire.Size = 3
		fire.Heat = 4
		fire.Color = Color3.fromRGB(255, 120, 30)
		fire.SecondaryColor = Color3.fromRGB(255, 220, 60)
		fire.Parent = body
	elseif mutationName == "Rainbow" then
		-- The client colour-cycles any model with this attribute
		model:SetAttribute("Rainbow", true)
	end
end

-- Builds a squishy. Returns a Model whose PrimaryPart is the body.
function PetModels.BuildPet(petId, mutationName)
	local def = Config.PetsById[petId]
	assert(def, "Unknown pet " .. tostring(petId))
	local model = Instance.new("Model")
	model.Name = def.Name

	local body
	for _, spec in ipairs(def.Parts) do
		local part = makePart(spec, 1)
		part.Name = spec.Body and "Body" or "Detail"
		part.Parent = model
		if spec.Body then
			body = part
		end
	end
	body = body or model:FindFirstChildWhichIsA("BasePart")
	model.PrimaryPart = body

	addFace(model, def.Face or Vector3.new(0, 0, -1.5), def.FaceScale or 1)

	if def.Glow then
		local light = Instance.new("PointLight")
		light.Color = def.Glow
		light.Range = 12
		light.Brightness = 1.5
		light.Parent = body
	end
	if def.Sparkle then
		local sparkles = Instance.new("Sparkles")
		sparkles.SparkleColor = Color3.fromRGB(255, 230, 120)
		sparkles.Parent = body
	end

	applyMutation(model, body, mutationName)
	model:SetAttribute("PetId", petId)
	model:SetAttribute("Mutation", mutationName or "Normal")
	return model
end

-- Builds an egg in the colour of its rarity.
function PetModels.BuildEgg(rarity)
	local info = Config.Rarities[rarity]
	local model = Instance.new("Model")
	model.Name = rarity .. " Egg"

	local shell = makePart({ Kind = "Ellipsoid", Size = Vector3.new(2, 2.6, 2), Color = info.Color }, 1)
	shell.Name = "Shell"
	shell.Parent = model
	model.PrimaryPart = shell

	local spotColor = info.Color:Lerp(Color3.new(1, 1, 1), 0.6)
	local spots = {
		Vector3.new(-0.45, 0.5, -0.85),
		Vector3.new(0.5, -0.1, -0.88),
		Vector3.new(-0.2, -0.6, -0.9),
		Vector3.new(0.6, 0.7, 0.75),
	}
	for _, pos in ipairs(spots) do
		local spot = makePart({ Kind = "Ellipsoid", Size = Vector3.new(0.5, 0.55, 0.2), Color = spotColor }, 1)
		spot.Name = "Spot"
		spot.CFrame = CFrame.lookAt(pos, pos * 2)
		spot.Parent = model
	end

	if info.Order >= 5 then
		local light = Instance.new("PointLight")
		light.Color = info.Color
		light.Range = 14
		light.Brightness = 2
		light.Parent = shell
	end
	if rarity == "Secret" then
		local sparkles = Instance.new("Sparkles")
		sparkles.SparkleColor = info.Color
		sparkles.Parent = shell
	end

	model:SetAttribute("Rarity", rarity)
	return model
end

-- Puts a floating name tag above a model. Returns the BillboardGui and its two labels.
function PetModels.AddLabel(model, title, subtitle, titleColor, heightOffset)
	local adornee = model.PrimaryPart
	local gui = Instance.new("BillboardGui")
	gui.Name = "Label"
	gui.Size = UDim2.new(0, 220, 0, 54)
	gui.StudsOffset = Vector3.new(0, heightOffset or 3, 0)
	gui.MaxDistance = 80
	gui.LightInfluence = 0
	gui.Adornee = adornee

	local titleLabel = Instance.new("TextLabel")
	titleLabel.Name = "Title"
	titleLabel.BackgroundTransparency = 1
	titleLabel.Size = UDim2.new(1, 0, 0.55, 0)
	titleLabel.Font = Enum.Font.FredokaOne
	titleLabel.TextScaled = true
	titleLabel.TextColor3 = titleColor or Color3.new(1, 1, 1)
	titleLabel.TextStrokeTransparency = 0.2
	titleLabel.Text = title
	titleLabel.Parent = gui

	local subLabel = Instance.new("TextLabel")
	subLabel.Name = "Subtitle"
	subLabel.BackgroundTransparency = 1
	subLabel.Position = UDim2.new(0, 0, 0.55, 0)
	subLabel.Size = UDim2.new(1, 0, 0.45, 0)
	subLabel.Font = Enum.Font.GothamBold
	subLabel.TextScaled = true
	subLabel.TextColor3 = Color3.new(1, 1, 1)
	subLabel.TextStrokeTransparency = 0.3
	subLabel.Text = subtitle or ""
	subLabel.Parent = gui

	gui.Parent = adornee
	return gui, titleLabel, subLabel
end

-- Moves a model so its bottom rests on `surfaceCFrame` (a point on top of a floor or pedestal)
function PetModels.PlaceOnSurface(model, surfaceCFrame)
	local bottomOffset = model:GetAttribute("BottomOffset")
	if not bottomOffset then
		local pivot = model:GetPivot()
		local boxCFrame, boxSize = model:GetBoundingBox()
		bottomOffset = pivot.Position.Y - (boxCFrame.Position.Y - boxSize.Y / 2)
		model:SetAttribute("BottomOffset", bottomOffset)
	end
	model:PivotTo(surfaceCFrame * CFrame.new(0, bottomOffset, 0))
end

-- Height of a model in studs (used to place labels)
function PetModels.GetHeight(model)
	local _, size = model:GetBoundingBox()
	return size.Y
end

return PetModels

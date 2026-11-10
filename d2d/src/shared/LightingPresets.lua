-- LightingPresets: the game's look (sky, sun, haze, colour grading) in one place.
-- LightingPresets.Apply("CleanDay") swaps everything at once, so looks can be compared live.

local Lighting = game:GetService("Lighting")

local LightingPresets = {}

-- Optional painted skyboxes (6 faces each). Empty = Roblox's default sky.
-- (Creator Store cartoon skies)
LightingPresets.Skies = {
	CartoonA = { Bk = "rbxassetid://158516797", Dn = "rbxassetid://158516788", Ft = "rbxassetid://158516797", Lf = "rbxassetid://158516797", Rt = "rbxassetid://158516797", Up = "rbxassetid://158516792" },
	CartoonB = { Bk = "rbxassetid://13523725319", Dn = "rbxassetid://13523743919", Ft = "rbxassetid://13523725319", Lf = "rbxassetid://13523725319", Rt = "rbxassetid://13523725319", Up = "rbxassetid://13523746141" },
	CartoonC = { Bk = "rbxassetid://13107325341", Dn = "rbxassetid://13107329809", Ft = "rbxassetid://13107334845", Lf = "rbxassetid://13107337703", Rt = "rbxassetid://13107340396", Up = "rbxassetid://13107344387" },
}

LightingPresets.Presets = {
	-- Bright, soft, clean daylight (Clean a Painting style)
	CleanDay = {
		Sky = "Default",
		ClockTime = 13.4,
		Latitude = 30,
		Brightness = 2.6,
		Ambient = Color3.fromRGB(118, 122, 134),
		OutdoorAmbient = Color3.fromRGB(168, 172, 184),
		Exposure = 0.2,
		ShadowSoftness = 0.4,
		Diffuse = 1,
		Specular = 0.7,
		Atmosphere = { Density = 0.26, Offset = 0.22, Color = Color3.fromRGB(205, 222, 240), Decay = Color3.fromRGB(150, 175, 210), Glare = 0, Haze = 0.7 },
		Bloom = { Intensity = 0.32, Size = 26, Threshold = 1.7 },
		Color = { Saturation = 0.12, Contrast = 0.04, Brightness = 0.02, Tint = Color3.fromRGB(255, 253, 248) },
		SunRays = { Intensity = 0.02, Spread = 0.5 },
		Clouds = { Cover = 0.45, Density = 0.5 },
	},
	-- Punchy simulator look: deeper blue sky, saturated colours, crisper shadows
	VividSim = {
		Sky = "CartoonA",
		ClockTime = 14,
		Latitude = 25,
		Brightness = 2.4,
		Ambient = Color3.fromRGB(100, 106, 124),
		OutdoorAmbient = Color3.fromRGB(132, 142, 168),
		Exposure = -0.1,
		ShadowSoftness = 0.22,
		Diffuse = 0.8,
		Specular = 0.3,
		Atmosphere = { Density = 0.18, Offset = 0.3, Color = Color3.fromRGB(190, 215, 245), Decay = Color3.fromRGB(120, 160, 220), Glare = 0, Haze = 0.5 },
		Bloom = { Intensity = 0.12, Size = 20, Threshold = 2.6 },
		Color = { Saturation = 0.22, Contrast = 0.1, Brightness = -0.02, Tint = Color3.fromRGB(250, 252, 255) },
		SunRays = { Intensity = 0.03, Spread = 0.4 },
		Clouds = { Cover = 0.55, Density = 0.65 },
	},
	-- Natural, professionally balanced daylight: neutral grade, real sky light (Future lighting),
	-- soft but defined shadows, no blown-out whites and no crushed blacks
	Studio = {
		Sky = "Default",
		ClockTime = 16.3, -- afternoon sun: warm key light, long soft shadows that give depth
		Latitude = 41,
		Brightness = 3.4,
		Ambient = Color3.fromRGB(78, 78, 86), -- even fill indoors (no black corners)
		OutdoorAmbient = Color3.fromRGB(118, 116, 124),
		Exposure = 0.05,
		ShadowSoftness = 0.12,
		Diffuse = 1,
		Specular = 1,
		Atmosphere = { Density = 0.3, Offset = 0.12, Color = Color3.fromRGB(214, 196, 176), Decay = Color3.fromRGB(120, 98, 82), Glare = 0.25, Haze = 0.9 },
		Bloom = { Intensity = 0.35, Size = 28, Threshold = 1.6 },
		Color = { Saturation = 0.1, Contrast = 0.14, Brightness = 0.01, Tint = Color3.fromRGB(255, 246, 236) },
		SunRays = { Intensity = 0.06, Spread = 0.5 },
		Clouds = { Cover = 0.5, Density = 0.55 },
		NoDof = true,
	},
	-- Warm late-afternoon light with long soft shadows
	GoldenHour = {
		Sky = "Default",
		ClockTime = 16.7,
		Latitude = 35,
		Brightness = 2.4,
		Ambient = Color3.fromRGB(120, 110, 108),
		OutdoorAmbient = Color3.fromRGB(170, 152, 140),
		Exposure = 0.25,
		ShadowSoftness = 0.35,
		Diffuse = 1,
		Specular = 0.8,
		Atmosphere = { Density = 0.3, Offset = 0.2, Color = Color3.fromRGB(235, 215, 195), Decay = Color3.fromRGB(200, 150, 120), Glare = 0.3, Haze = 1.1 },
		Bloom = { Intensity = 0.4, Size = 28, Threshold = 1.5 },
		Color = { Saturation = 0.15, Contrast = 0.1, Brightness = 0.01, Tint = Color3.fromRGB(255, 244, 228) },
		SunRays = { Intensity = 0.08, Spread = 0.6 },
		Clouds = { Cover = 0.5, Density = 0.55 },
	},
}

LightingPresets.Default = "Studio"

local function fresh(className)
	for _, c in ipairs(Lighting:GetChildren()) do
		if c.ClassName == className then
			c:Destroy()
		end
	end
	local obj = Instance.new(className)
	obj.Parent = Lighting
	return obj
end

function LightingPresets.Apply(name, skyOverride)
	local p = LightingPresets.Presets[name] or LightingPresets.Presets[LightingPresets.Default]
	Lighting.GlobalShadows = true
	Lighting.ClockTime = p.ClockTime
	Lighting.GeographicLatitude = p.Latitude
	Lighting.Brightness = p.Brightness
	Lighting.Ambient = p.Ambient
	Lighting.OutdoorAmbient = p.OutdoorAmbient
	Lighting.ExposureCompensation = p.Exposure
	Lighting.ShadowSoftness = p.ShadowSoftness
	Lighting.EnvironmentDiffuseScale = p.Diffuse
	Lighting.EnvironmentSpecularScale = p.Specular

	local sky = fresh("Sky")
	sky.SunAngularSize = 14
	sky.StarCount = 0
	local faces = LightingPresets.Skies[skyOverride or p.Sky]
	if faces then
		sky.SkyboxBk, sky.SkyboxDn, sky.SkyboxFt = faces.Bk, faces.Dn, faces.Ft
		sky.SkyboxLf, sky.SkyboxRt, sky.SkyboxUp = faces.Lf, faces.Rt, faces.Up
		sky.CelestialBodiesShown = faces.Sun ~= false
	end

	local a = fresh("Atmosphere")
	for k, v in pairs(p.Atmosphere) do
		a[k] = v
	end
	local bloom = fresh("BloomEffect")
	bloom.Intensity, bloom.Size, bloom.Threshold = p.Bloom.Intensity, p.Bloom.Size, p.Bloom.Threshold
	local cc = fresh("ColorCorrectionEffect")
	cc.Saturation, cc.Contrast, cc.Brightness, cc.TintColor = p.Color.Saturation, p.Color.Contrast, p.Color.Brightness, p.Color.Tint
	local rays = fresh("SunRaysEffect")
	rays.Intensity, rays.Spread = p.SunRays.Intensity, p.SunRays.Spread
	local dof = fresh("DepthOfFieldEffect")
	dof.FarIntensity, dof.FocusDistance, dof.InFocusRadius, dof.NearIntensity = 0.12, 60, 140, 0
	dof.Enabled = not p.NoDof

	local clouds = workspace.Terrain:FindFirstChildOfClass("Clouds") or Instance.new("Clouds")
	clouds.Cover = p.Clouds.Cover
	clouds.Density = p.Clouds.Density
	clouds.Color = Color3.new(1, 1, 1)
	clouds.Parent = workspace.Terrain
	Lighting:SetAttribute("Preset", name)
end

return LightingPresets

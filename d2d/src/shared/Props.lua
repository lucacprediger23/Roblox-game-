-- Props: places 3D models from the Creator Store (saved in ReplicatedStorage.Assets.Props).
-- Every prop is cleaned (no scripts), anchored, scaled to a target size and set on the ground.
-- If a prop is missing, Place returns nil so the caller can build its own fallback.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Props = {}

local folder = nil
local function getFolder()
	if folder == nil then
		local assets = ReplicatedStorage:FindFirstChild("Assets")
		folder = assets and assets:FindFirstChild("Props") or false
	end
	return folder or nil
end

function Props.Has(name)
	local f = getFolder()
	return f ~= nil and f:FindFirstChild(name) ~= nil
end

-- world-space box around all parts of a model
local function worldBox(model)
	local minV = Vector3.new(math.huge, math.huge, math.huge)
	local maxV = -minV
	local any = false
	for _, p in ipairs(model:GetDescendants()) do
		if p:IsA("BasePart") and p.Transparency < 1 then
			any = true
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
	end
	if not any then
		return Vector3.zero, Vector3.one, Vector3.zero
	end
	return (minV + maxV) / 2, maxV - minV, minV
end

-- a prepared, normalized copy of each prop (cleaned, base at the origin), made once
local cache = {}
local function prepared(name)
	if cache[name] ~= nil then
		return cache[name] or nil
	end
	local f = getFolder()
	local src = f and f:FindFirstChild(name)
	if not src then
		cache[name] = false
		return nil
	end
	local m = src:Clone()
	if not m:IsA("Model") then
		local wrap = Instance.new("Model")
		m.Parent = wrap
		m = wrap
	end
	for _, d in ipairs(m:GetDescendants()) do
		if d:IsA("LuaSourceContainer") or d:IsA("ProximityPrompt") or d:IsA("ClickDetector") or d:IsA("Sound") then
			d:Destroy()
		elseif d:IsA("BasePart") then
			d.Anchored = true
			d.CanCollide = false
			d.CanTouch = false
			d.CanQuery = false
			d.CastShadow = true
		elseif d:IsA("JointInstance") or d:IsA("WeldConstraint") or d:IsA("Constraint") then
			d:Destroy()
		elseif d:IsA("Light") then
			-- props' lamps glow softly in daylight
			d.Brightness = math.min(d.Brightness, 0.8)
			d.Shadows = false
		end
	end
	m.PrimaryPart = nil
	local center, _, minV = worldBox(m)
	m.WorldPivot = CFrame.new(center.X, minV.Y, center.Z)
	m:PivotTo(CFrame.new())
	cache[name] = m
	return m
end

-- opts.Height / opts.Width / opts.Length: target size in studs (pick one; Height is the default)
-- opts.Solid: players bump into it
-- opts.Ground: drop it onto whatever is below (terrain or parts)
-- opts.Name: name of the new model
function Props.Place(name, parent, cf, opts)
	opts = opts or {}
	local base = prepared(name)
	if not base then
		return nil
	end
	local m = base:Clone()
	m.Name = opts.Name or name
	local _, size = worldBox(m)
	local scale
	if opts.Width then
		scale = opts.Width / math.max(size.X, size.Z, 0.05)
	elseif opts.Length then
		scale = opts.Length / math.max(size.Z, 0.05)
	else
		scale = (opts.Height or size.Y) / math.max(size.Y, 0.05)
	end
	if math.abs(scale - 1) > 0.01 then
		pcall(function()
			m:ScaleTo(scale)
		end)
	end
	if opts.Ground then
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.FilterDescendantsInstances = { m }
		local hit = workspace:Raycast(cf.Position + Vector3.new(0, 200, 0), Vector3.new(0, -400, 0), params)
		if hit then
			cf = CFrame.new(cf.X, hit.Position.Y, cf.Z) * cf.Rotation
		end
	end
	m:PivotTo(cf)
	if opts.Solid then
		for _, d in ipairs(m:GetDescendants()) do
			if d:IsA("BasePart") then
				d.CanCollide = true
				d.CanQuery = true
			end
		end
	end
	m.Parent = parent
	return m
end

-- pick one of several props that exist
function Props.Pick(names, rng)
	local have = {}
	for _, n in ipairs(names) do
		if Props.Has(n) then
			table.insert(have, n)
		end
	end
	if #have == 0 then
		return nil
	end
	return have[rng and rng:NextInteger(1, #have) or math.random(1, #have)]
end

return Props

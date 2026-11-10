-- Juice: small, layered, short-lived feedback (client only).
-- Principles (from game-feel research): exaggerate briefly then return to rest, ease everything,
-- and scale the feedback to how important the moment is (small / medium / large tiers).

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Juice = {}

-- Camera shake driven by decaying "trauma" (shake = trauma^2), applied to Humanoid.CameraOffset
-- so the camera moves but the character/physics never do.
local trauma = 0
local t = 0
local DECAY = 1.6
local MAX_OFFSET = Vector3.new(0.6, 0.45, 0)
local running = false

local function step(dt)
	local char = Players.LocalPlayer.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	trauma = math.max(0, trauma - DECAY * dt)
	t = t + dt * 28
	local s = trauma * trauma
	if hum then
		hum.CameraOffset = Vector3.new(MAX_OFFSET.X * s * math.sin(t * 1.7), MAX_OFFSET.Y * s * math.sin(t * 2.3), 0)
	end
	return trauma > 0
end

function Juice.Shake(amount)
	trauma = math.clamp(trauma + amount, 0, 1)
	if running then
		return
	end
	running = true
	local conn
	conn = RunService.RenderStepped:Connect(function(dt)
		if not step(dt) then
			conn:Disconnect()
			running = false
		end
	end)
end

-- Squash-and-overshoot "pop" on any GuiObject (adds/reuses a UIScale).
function Juice.Pop(gui, strength)
	if not gui then
		return
	end
	strength = strength or 0.18
	local scale = gui:FindFirstChild("JuiceScale") or Instance.new("UIScale")
	scale.Name = "JuiceScale"
	scale.Parent = gui
	scale.Scale = 1 + strength
	TweenService:Create(scale, TweenInfo.new(0.28, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
end

-- One call per event; the tier keeps the whole game proportional.
function Juice.Feedback(tier, gui)
	if tier == "small" then
		Juice.Pop(gui, 0.12)
	elseif tier == "medium" then
		Juice.Pop(gui, 0.2)
		Juice.Shake(0.3)
	elseif tier == "large" then
		Juice.Pop(gui, 0.3)
		Juice.Shake(0.6)
	end
end

return Juice

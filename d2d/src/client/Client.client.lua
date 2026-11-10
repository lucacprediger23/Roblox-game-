-- D2D client: HUD, delivery timer, wash view (scrubbing), tire view, Index and messages.
-- UI style: cream panels with brown borders, chunky colored buttons, icon buttons on the left.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local CollectionService = game:GetService("CollectionService")
local GuiService = game:GetService("GuiService")
local SoundService = game:GetService("SoundService")

local player = Players.LocalPlayer
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local CarBuilder = require(Shared:WaitForChild("CarBuilder"))
local Icons = require(Shared:WaitForChild("Icons"))
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local NotifyEvent = remotes:WaitForChild("Notify")
local ScrubEvent = remotes:WaitForChild("Scrub")
local RevealEvent = remotes:WaitForChild("Reveal")
local OpenEngineEvent = remotes:WaitForChild("OpenEngine")
local GoHomeEvent = remotes:WaitForChild("GoHome")
local EngineAction = remotes:WaitForChild("EngineAction")
local ClaimToken = remotes:WaitForChild("ClaimToken")
local YardAction = remotes:WaitForChild("YardAction")
local OfflineEvent = remotes:WaitForChild("Offline")

---------------------------------------------------------------------
-- Theme
---------------------------------------------------------------------
local CREAM = Color3.fromRGB(255, 244, 222)
local CREAM_DARK = Color3.fromRGB(246, 226, 190)
local BROWN = Color3.fromRGB(128, 82, 46)
local TEXT_DARK = Color3.fromRGB(92, 58, 32)
local GREEN_TEXT = Color3.fromRGB(40, 150, 60)
local WHITE = Color3.new(1, 1, 1)
local BLACK = Color3.fromRGB(25, 20, 18)
local GOLD = Color3.fromRGB(255, 205, 60)
local BTN = {
	Green = Color3.fromRGB(90, 200, 90),
	Orange = Color3.fromRGB(255, 150, 50),
	Red = Color3.fromRGB(240, 85, 75),
	Blue = Color3.fromRGB(80, 160, 255),
	Yellow = Color3.fromRGB(255, 205, 60),
	Cream = CREAM_DARK,
}

local function corner(p, r)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, r or 12)
	c.Parent = p
end
local function stroke(p, color, t)
	local s = Instance.new("UIStroke")
	s.Color = color or BLACK
	s.Thickness = t or 3
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.Parent = p
	return s
end
local function textStroke(l, t)
	local s = Instance.new("UIStroke")
	s.Color = BLACK
	s.Thickness = t or 2
	s.Parent = l
	return s
end
local function shine(p, amount)
	local g = Instance.new("UIGradient")
	local a = amount or 0.2
	g.Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.new(1 - a, 1 - a, 1 - a))
	g.Rotation = 90
	g.Parent = p
	return g
end
-- outlined white text (for text over the 3D world)
local function text(parent, props)
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Font = Enum.Font.FredokaOne
	l.TextColor3 = WHITE
	l.TextScaled = true
	textStroke(l, props.StrokeThickness or 2)
	props.StrokeThickness = nil
	for k, v in pairs(props) do
		l[k] = v
	end
	l.Parent = parent
	return l
end
-- flat dark-brown text (for text on cream panels)
local function inkText(parent, props)
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Font = Enum.Font.FredokaOne
	l.TextColor3 = TEXT_DARK
	l.TextScaled = true
	for k, v in pairs(props) do
		l[k] = v
	end
	l.Parent = parent
	return l
end

local function playSound(id, volume)
	if id == "" then
		return
	end
	local snd = Instance.new("Sound")
	snd.SoundId = id
	snd.Volume = volume or 0.5
	snd.Parent = SoundService
	SoundService:PlayLocalSound(snd)
	task.delay(3, function()
		snd:Destroy()
	end)
end
-- sound ids: fill these with sounds from the Creator Store (Toolbox > Audio) that the game may use
local SOUND_CLICK, SOUND_PING, SOUND_SWOOSH = "", "", ""

local function juicy(b)
	local scale = Instance.new("UIScale")
	scale.Parent = b
	local function to(v)
		TweenService:Create(scale, TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Scale = v }):Play()
	end
	b.MouseEnter:Connect(function()
		to(1.06)
	end)
	b.MouseLeave:Connect(function()
		to(1)
	end)
	b.MouseButton1Down:Connect(function()
		to(0.92)
	end)
	b.MouseButton1Up:Connect(function()
		to(1.06)
	end)
	b.Activated:Connect(function()
		playSound(SOUND_CLICK, 0.4)
	end)
end

-- 3D push button like Clean a Painting: a darker "lip" underneath, a glossy face on top that
-- presses down when clicked, white outlined text. Setting button.Text / TextColor3 later still works.
local function button(parent, props, color)
	color = color or BTN.Green
	local b = Instance.new("TextButton")
	b.AutoButtonColor = false
	b.BackgroundColor3 = color:Lerp(Color3.new(0, 0, 0), 0.38)
	b.TextTransparency = 1
	b.Text = ""
	corner(b, 14)
	stroke(b, BLACK, 3)
	local face = Instance.new("Frame")
	face.Name = "Face"
	face.BorderSizePixel = 0
	face.Size = UDim2.new(1, 0, 1, -6)
	face.BackgroundColor3 = WHITE
	corner(face, 13)
	local g = Instance.new("UIGradient")
	g.Rotation = 90
	g.Color = ColorSequence.new(color:Lerp(WHITE, 0.22), color)
	g.Parent = face
	local gloss = Instance.new("Frame")
	gloss.Name = "Gloss"
	gloss.BackgroundColor3 = WHITE
	gloss.BackgroundTransparency = 0.8
	gloss.BorderSizePixel = 0
	gloss.Position = UDim2.new(0, 6, 0, 4)
	gloss.Size = UDim2.new(1, -12, 0.38, 0)
	corner(gloss, 9)
	gloss.Parent = face
	local label = Instance.new("TextLabel")
	label.Name = "Label"
	label.BackgroundTransparency = 1
	label.Position = UDim2.new(0, 10, 0.16, 0)
	label.Size = UDim2.new(1, -20, 0.68, 0)
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = WHITE
	textStroke(label, 2.5)
	label.Parent = face
	face.Parent = b
	for k, v in pairs(props) do
		if k == "Text" then
			label.Text = v
		elseif k == "TextColor3" then
			label.TextColor3 = v
		else
			b[k] = v
		end
	end
	b:GetPropertyChangedSignal("Text"):Connect(function()
		label.Text = b.Text
	end)
	b:GetPropertyChangedSignal("TextColor3"):Connect(function()
		label.TextColor3 = b.TextColor3
	end)
	b.MouseButton1Down:Connect(function()
		face.Position = UDim2.new(0, 0, 0, 4)
	end)
	local function release()
		face.Position = UDim2.new(0, 0, 0, 0)
	end
	b.MouseButton1Up:Connect(release)
	b.MouseLeave:Connect(release)
	juicy(b)
	b.Parent = parent
	return b
end

-- the little white key badge ("E", "Q") on a button
local function keyBadge(b, key)
	local k = Instance.new("TextLabel")
	k.AnchorPoint = Vector2.new(0, 0.5)
	k.Position = UDim2.new(0, -2, 0.5, 0)
	k.Size = UDim2.new(0, 34, 0, 34)
	k.BackgroundColor3 = WHITE
	k.Font = Enum.Font.FredokaOne
	k.TextScaled = true
	k.TextColor3 = BLACK
	k.Text = key
	k.ZIndex = 5
	corner(k, 8)
	stroke(k, BLACK, 2)
	k.Parent = b
	return k
end

-- cream "paper" panel: warm gradient, thick brown border and a thin inner highlight line
local function panel(parent, props)
	local f = Instance.new("Frame")
	f.BackgroundColor3 = WHITE
	f.BorderSizePixel = 0
	for k, v in pairs(props) do
		f[k] = v
	end
	corner(f, 20)
	stroke(f, BROWN, 5)
	local g = Instance.new("UIGradient")
	g.Rotation = 90
	g.Color = ColorSequence.new(Color3.fromRGB(255, 249, 236), Color3.fromRGB(250, 233, 200))
	g.Parent = f
	local inner = Instance.new("Frame")
	inner.Name = "InnerLine"
	inner.BackgroundTransparency = 1
	inner.Position = UDim2.new(0, 8, 0, 8)
	inner.Size = UDim2.new(1, -16, 1, -16)
	corner(inner, 14)
	local is = stroke(inner, Color3.fromRGB(226, 192, 140), 2)
	is.Transparency = 0.2
	inner.Parent = f
	f.Parent = parent
	return f
end

local gui = Instance.new("ScreenGui")
gui.Name = "D2D"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
pcall(function()
	gui.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets
end)
gui.Parent = player:WaitForChild("PlayerGui")
-- scale the whole UI with the screen so it fits phones and big monitors alike (designed at 1080p)
local uiScale = Instance.new("UIScale")
uiScale.Parent = gui
local function fitScale()
	local vs = workspace.CurrentCamera.ViewportSize
	uiScale.Scale = math.clamp(math.min(vs.X / 1700, vs.Y / 950), 0.55, 1.15)
end
workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(fitScale)
fitScale()

---------------------------------------------------------------------
-- HUD: cash and tokens (top left), delivery timer (top center), icon buttons (left)
---------------------------------------------------------------------
local hud = Instance.new("Frame")
hud.BackgroundTransparency = 1
hud.Size = UDim2.new(1, 0, 1, 0)
hud.Parent = gui

local function pill(y, width, icon, color, strokeColor)
	local f = Instance.new("Frame")
	f.Position = UDim2.new(0, 46, 0, y)
	f.Size = UDim2.new(0, width, 0, 50)
	f.BackgroundColor3 = WHITE
	corner(f, 14)
	stroke(f, BROWN, 3)
	local g = Instance.new("UIGradient")
	g.Rotation = 90
	g.Color = ColorSequence.new(Color3.fromRGB(255, 249, 234), Color3.fromRGB(246, 224, 182))
	g.Parent = f
	f.Parent = hud
	Icons.Make(icon, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0, 2, 0.5, 0), Size = UDim2.new(0, 78, 0, 78), ZIndex = 3 }).Parent = f
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Position = UDim2.new(0, 40, 0, 6)
	l.Size = UDim2.new(1, -52, 1, -12)
	l.Font = Enum.Font.FredokaOne
	l.TextScaled = true
	l.TextColor3 = color
	l.Text = "0"
	textStroke(l, 1.5).Color = strokeColor or Color3.fromRGB(255, 250, 235)
	l.Parent = f
	return f, l
end
local cashPill, cashLabel = pill(64, 250, "Cash", GREEN_TEXT, Color3.fromRGB(230, 255, 230))
local _, tokenLabel = pill(124, 160, "Coin", TEXT_DARK)
local incomeLabel = text(hud, { Position = UDim2.new(0, 306, 0, 78), Size = UDim2.new(0, 200, 0, 26), Text = "", TextColor3 = Color3.fromRGB(130, 255, 140), TextXAlignment = Enum.TextXAlignment.Left })

text(hud, { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 14), Size = UDim2.new(0, 260, 0, 18), Text = "CONTAINER DELIVERY", StrokeThickness = 1.5 })
local timerLabel = text(hud, { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 34), Size = UDim2.new(0, 200, 0, 36), Text = "--:--", StrokeThickness = 2.5 })

-- left icon buttons
local function iconButton(y, icon, caption)
	local b = Instance.new("TextButton")
	b.BackgroundTransparency = 1
	b.Text = ""
	b.Position = UDim2.new(0, 12, 0.5, y)
	b.Size = UDim2.new(0, 104, 0, 112)
	b.Parent = hud
	local vp = Icons.Make(icon, { Size = UDim2.new(1, 0, 0, 88) })
	vp.Parent = b
	text(b, { Position = UDim2.new(0, -12, 0, 80), Size = UDim2.new(1, 24, 0, 30), Text = caption, StrokeThickness = 3 })
	b.MouseEnter:Connect(function()
		TweenService:Create(vp, TweenInfo.new(0.15), { Rotation = -8 }):Play()
	end)
	b.MouseLeave:Connect(function()
		TweenService:Create(vp, TweenInfo.new(0.15), { Rotation = 0 }):Play()
	end)
	juicy(b)
	return b
end
local indexButton = iconButton(-130, "Book", "Index")
local homeButton = iconButton(-10, "Home", "Home")
local indexDot = Instance.new("TextLabel")
indexDot.Size = UDim2.new(0, 26, 0, 26)
indexDot.Position = UDim2.new(1, -24, 0, 2)
indexDot.BackgroundColor3 = Color3.fromRGB(240, 60, 60)
indexDot.Text = "!"
indexDot.TextScaled = true
indexDot.Font = Enum.Font.FredokaOne
indexDot.TextColor3 = WHITE
indexDot.Visible = false
corner(indexDot, 13)
stroke(indexDot, WHITE, 2)
indexDot.Parent = indexButton

homeButton.MouseButton1Click:Connect(function()
	GoHomeEvent:FireServer()
end)

-- cash counter with a floating "+$X"
local lastCash = 0
local function floatGain(amount)
	local l = text(hud, { Position = UDim2.new(0, 306, 0, 52), Size = UDim2.new(0, 240, 0, 34), Text = "+$" .. Config.FormatNumber(amount), TextColor3 = Color3.fromRGB(130, 255, 140), TextXAlignment = Enum.TextXAlignment.Left })
	local tw = TweenService:Create(l, TweenInfo.new(1.2), { Position = UDim2.new(0, 306, 0, 18), TextTransparency = 1 })
	tw:Play()
	tw.Completed:Connect(function()
		l:Destroy()
	end)
end
task.spawn(function()
	local cash = player:WaitForChild("leaderstats"):WaitForChild("Cash")
	local function update()
		cashLabel.Text = "$" .. Config.FormatNumber(cash.Value)
		local diff = cash.Value - lastCash
		if diff > 0 and lastCash > 0 then
			floatGain(diff)
		end
		lastCash = cash.Value
	end
	cash.Changed:Connect(update)
	update()
end)

local function idSet(attr)
	local set, n = {}, 0
	for id in string.gmatch(player:GetAttribute(attr) or "", "[^,]+") do
		set[id] = true
		n = n + 1
	end
	return set, n
end
local function refreshTokens()
	tokenLabel.Text = tostring(player:GetAttribute("Tokens") or 0)
	local claimed = idSet("Claimed")
	local discovered = idSet("Discovered")
	local unclaimed = 0
	for id in pairs(discovered) do
		if not claimed[id] then
			unclaimed = unclaimed + 1
		end
	end
	indexDot.Visible = unclaimed > 0
end
player:GetAttributeChangedSignal("Tokens"):Connect(refreshTokens)
player:GetAttributeChangedSignal("Claimed"):Connect(refreshTokens)
player:GetAttributeChangedSignal("Discovered"):Connect(refreshTokens)
refreshTokens()

RunService.Heartbeat:Connect(function()
	local nextAt = player:GetAttribute("NextDelivery")
	if player:GetAttribute("YardFull") then
		timerLabel.Text = "YARD FULL!"
		timerLabel.TextColor3 = Color3.fromRGB(255, 120, 110)
	elseif nextAt then
		timerLabel.Text = Config.FormatTime(nextAt - workspace:GetServerTimeNow())
		timerLabel.TextColor3 = WHITE
	end
	local rate = player:GetAttribute("IncomeRate") or 0
	incomeLabel.Text = rate > 0 and ("$" .. Config.FormatNumber(rate) .. "/s") or ""
end)

---------------------------------------------------------------------
-- Messages
---------------------------------------------------------------------
local notifyList = Instance.new("Frame")
notifyList.BackgroundTransparency = 1
notifyList.AnchorPoint = Vector2.new(0.5, 0)
notifyList.Position = UDim2.new(0.5, 0, 0, 80)
notifyList.Size = UDim2.new(0, 640, 0, 200)
notifyList.Parent = gui
local nl = Instance.new("UIListLayout")
nl.Padding = UDim.new(0, 4)
nl.HorizontalAlignment = Enum.HorizontalAlignment.Center
nl.SortOrder = Enum.SortOrder.LayoutOrder
nl.Parent = notifyList
local notifyCount = 0
local function showNotification(message, color)
	notifyCount = notifyCount + 1
	local l = text(notifyList, { Size = UDim2.new(1, 0, 0, 28), Text = message, TextColor3 = color or WHITE, LayoutOrder = notifyCount })
	local labels = {}
	for _, c in ipairs(notifyList:GetChildren()) do
		if c:IsA("TextLabel") then
			table.insert(labels, c)
		end
	end
	if #labels > 4 then
		table.sort(labels, function(a, b)
			return a.LayoutOrder < b.LayoutOrder
		end)
		labels[1]:Destroy()
	end
	task.delay(4, function()
		if l.Parent then
			local tw = TweenService:Create(l, TweenInfo.new(0.5), { TextTransparency = 1 })
			tw:Play()
			tw.Completed:Wait()
			l:Destroy()
		end
	end)
end
NotifyEvent.OnClientEvent:Connect(showNotification)

---------------------------------------------------------------------
-- Reveal splash when a container is opened
---------------------------------------------------------------------
local function reveal(carId, isNew)
	local car = Config.CarsById[carId]
	local rarity = Config.Rarities[car.Rarity]
	playSound(SOUND_PING, 0.7)
	local f = Instance.new("Frame")
	f.BackgroundTransparency = 1
	f.AnchorPoint = Vector2.new(0.5, 0.5)
	f.Position = UDim2.new(0.5, 0, 0.4, 0)
	f.Size = UDim2.new(0, 680, 0, 250)
	f.Parent = gui
	text(f, { Size = UDim2.new(1, 0, 0.3, 0), Text = isNew and "NEW CAR!" or "YOU GOT", TextColor3 = GOLD, StrokeThickness = 3 })
	text(f, { Position = UDim2.new(0, 0, 0.3, 0), Size = UDim2.new(1, 0, 0.3, 0), Text = car.Name, StrokeThickness = 3 })
	text(f, { Position = UDim2.new(0, 0, 0.62, 0), Size = UDim2.new(1, 0, 0.18, 0), Text = string.upper(rarity.Name), TextColor3 = rarity.Color, StrokeThickness = 3 })
	text(f, { Position = UDim2.new(0, 0, 0.8, 0), Size = UDim2.new(1, 0, 0.32, 0), Text = Config.GetOddsText(carId), TextColor3 = Color3.fromRGB(130, 255, 120), StrokeThickness = 4 })
	local scale = Instance.new("UIScale")
	scale.Scale = 0.2
	scale.Parent = f
	TweenService:Create(scale, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	task.delay(3, function()
		local tw = TweenService:Create(scale, TweenInfo.new(0.25), { Scale = 0 })
		tw:Play()
		tw.Completed:Wait()
		f:Destroy()
	end)
end
RevealEvent.OnClientEvent:Connect(reveal)

---------------------------------------------------------------------
-- Camera views (wash and engine), like the close-up screens in Clean a Painting
---------------------------------------------------------------------
local camera = workspace.CurrentCamera
local currentView = nil -- "Wash" | "Engine" | nil

-- hide floating world labels while a close-up view is open
local hiddenLabels = {}
local function hideWorldLabels(hidden)
	if hidden then
		for _, g in ipairs(workspace:GetDescendants()) do
			if g:IsA("BillboardGui") and g.Enabled then
				g.Enabled = false
				table.insert(hiddenLabels, g)
			end
		end
	else
		for _, g in ipairs(hiddenLabels) do
			if g.Parent then
				g.Enabled = true
			end
		end
		hiddenLabels = {}
	end
end

local function hideMyCharacter(hidden)
	local char = player.Character
	if not char then
		return
	end
	for _, d in ipairs(char:GetDescendants()) do
		if d:IsA("BasePart") or d:IsA("Decal") then
			d.LocalTransparencyModifier = hidden and 1 or 0
		end
	end
end

local function setCamera(cf, focus, instant)
	hideMyCharacter(true)
	hideWorldLabels(true)
	camera.CameraType = Enum.CameraType.Scriptable
	local target = CFrame.lookAt(cf, focus)
	if instant then
		camera.CFrame = target
	else
		TweenService:Create(camera, TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { CFrame = target }):Play()
	end
end

local function restoreCamera()
	currentView = nil
	hideMyCharacter(false)
	hideWorldLabels(false)
	camera.CameraType = Enum.CameraType.Custom
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if hum then
		camera.CameraSubject = hum
	end
	hud.Visible = true
end

---------------------------------------------------------------------
-- Wash view: orbit the car in the wash bay and scrub the dirt off
---------------------------------------------------------------------
local washUi = Instance.new("Frame")
washUi.BackgroundTransparency = 1
washUi.Size = UDim2.new(1, 0, 1, 0)
washUi.Visible = false
washUi.Parent = gui
local washPercent = text(washUi, { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 22), Size = UDim2.new(0, 260, 0, 46), Text = "0.0%", StrokeThickness = 3 })
local washBar = Instance.new("Frame")
washBar.AnchorPoint = Vector2.new(0.5, 0)
washBar.Position = UDim2.new(0.5, 0, 0, 74)
washBar.Size = UDim2.new(0, 360, 0, 16)
washBar.BackgroundColor3 = Color3.fromRGB(40, 40, 50)
corner(washBar, 8)
stroke(washBar, BLACK, 2)
washBar.Parent = washUi
local washFill = Instance.new("Frame")
washFill.Size = UDim2.new(0, 0, 1, 0)
washFill.BackgroundColor3 = Color3.fromRGB(110, 210, 255)
corner(washFill, 8)
washFill.Parent = washBar
text(washUi, { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -110), Size = UDim2.new(0, 520, 0, 26), Text = "Hold the mouse and drag over the dirt", TextColor3 = Color3.fromRGB(220, 240, 255) })
local turnLeft = button(washUi, { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, -70, 1, -28), Size = UDim2.new(0, 120, 0, 66), Text = "◀ TURN" }, BTN.Blue)
local turnRight = button(washUi, { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 70, 1, -28), Size = UDim2.new(0, 120, 0, 66), Text = "TURN ▶" }, BTN.Blue)
local washCancel = button(washUi, { AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -40, 1, -28), Size = UDim2.new(0, 230, 0, 70), Text = "      CANCEL" }, BTN.Red)
keyBadge(washCancel, "Q")
local continueWash = button(hud, { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -136), Size = UDim2.new(0, 280, 0, 68), Text = "KEEP WASHING", Visible = false }, BTN.Blue)

local washAngle = 0
local function washFocusCF()
	return player:GetAttribute("WashFocus")
end
local function updateWashCamera(instant)
	local cf = washFocusCF()
	if not cf then
		return
	end
	local focus = cf.Position + Vector3.new(0, 2.4, 0)
	local offset = (cf.Rotation * CFrame.Angles(0, math.rad(washAngle), 0)):VectorToWorldSpace(Vector3.new(11, 7.5, -6))
	setCamera(focus + offset, focus, instant)
end
local function enterWashView()
	if currentView == "Wash" or not washFocusCF() then
		return
	end
	currentView = "Wash"
	washAngle = 0
	hud.Visible = false
	washUi.Visible = true
	updateWashCamera(false)
	playSound(SOUND_SWOOSH, 0.5)
end
local function exitWashView()
	if currentView ~= "Wash" then
		return
	end
	washUi.Visible = false
	restoreCamera()
end
turnLeft.MouseButton1Click:Connect(function()
	washAngle = washAngle - 90
	updateWashCamera(false)
end)
turnRight.MouseButton1Click:Connect(function()
	washAngle = washAngle + 90
	updateWashCamera(false)
end)
washCancel.MouseButton1Click:Connect(exitWashView)
continueWash.MouseButton1Click:Connect(enterWashView)

local function refreshWash()
	local p = player:GetAttribute("WashProgress")
	if p then
		washPercent.Text = string.format("%.1f%%", p * 100)
		washFill.Size = UDim2.new(math.clamp(p, 0, 1), 0, 1, 0)
		if currentView == nil then
			enterWashView()
		end
	else
		if currentView == "Wash" then
			washPercent.Text = "100%"
			washFill.Size = UDim2.new(1, 0, 1, 0)
			task.delay(0.6, exitWashView)
		end
	end
	continueWash.Visible = p ~= nil and currentView ~= "Wash"
end
player:GetAttributeChangedSignal("WashProgress"):Connect(refreshWash)

-- scrubbing input: mouse held down or a finger on the screen
local touchHolding = false
local touchPos = Vector2.new()
UserInputService.InputBegan:Connect(function(input, processed)
	if input.UserInputType == Enum.UserInputType.Touch and not processed then
		touchHolding = true
		touchPos = Vector2.new(input.Position.X, input.Position.Y)
	end
end)
UserInputService.InputChanged:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.Touch then
		touchPos = Vector2.new(input.Position.X, input.Position.Y)
	end
end)
UserInputService.InputEnded:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.Touch then
		touchHolding = false
	end
end)
local function overOurGui(x, y)
	for _, obj in ipairs(player.PlayerGui:GetGuiObjectsAtPosition(x, y - GuiService:GetGuiInset().Y)) do
		if obj:IsDescendantOf(gui) and obj.Visible and (obj:IsA("GuiButton") or obj.BackgroundTransparency < 1) then
			return true
		end
	end
	return false
end
local function scrubPoint()
	if touchHolding then
		return Vector2.new(touchPos.X, touchPos.Y + GuiService:GetGuiInset().Y)
	end
	if UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) then
		local m = UserInputService:GetMouseLocation()
		if not overOurGui(m.X, m.Y) then
			return m
		end
	end
	return nil
end

-- a sponge ring that follows the mouse in wash view
local sponge = Instance.new("Frame")
sponge.AnchorPoint = Vector2.new(0.5, 0.5)
sponge.Size = UDim2.new(0, 70, 0, 70)
sponge.BackgroundTransparency = 1
corner(sponge, 35)
stroke(sponge, WHITE, 2)
sponge.Visible = false
sponge.Parent = gui

local function bubbles(position)
	for _ = 1, 3 do
		local b = Instance.new("Part")
		b.Shape = Enum.PartType.Ball
		b.Size = Vector3.new(0.5, 0.5, 0.5)
		b.Material = Enum.Material.Glass
		b.Transparency = 0.3
		b.Color = Color3.fromRGB(225, 245, 255)
		b.Anchored = true
		b.CanCollide = false
		b.CanQuery = false
		b.CFrame = CFrame.new(position + Vector3.new(math.random() - 0.5, 0, math.random() - 0.5))
		b.Parent = workspace
		local tw = TweenService:Create(b, TweenInfo.new(0.8), { CFrame = b.CFrame + Vector3.new(0, 2.5, 0), Transparency = 1, Size = Vector3.new(1, 1, 1) })
		tw:Play()
		tw.Completed:Connect(function()
			b:Destroy()
		end)
	end
end

local lastSent = 0
RunService.RenderStepped:Connect(function()
	if currentView then
		hideMyCharacter(true)
		if os.clock() % 0.5 < 0.02 then
			hideWorldLabels(true)
		end
	end
	local washing = player:GetAttribute("WashProgress") ~= nil
	sponge.Visible = washing and currentView == "Wash"
	if sponge.Visible then
		local m = UserInputService:GetMouseLocation()
		sponge.Position = UDim2.new(0, m.X, 0, m.Y)
	end
	if not washing then
		return
	end
	local point = scrubPoint()
	if not point then
		return
	end
	local t = os.clock()
	if t - lastSent < Config.ScrubInterval then
		return
	end
	local dirt = workspace:FindFirstChild("Map") and workspace.Map:FindFirstChild("Dirt")
	if not dirt then
		return
	end
	local ray = camera:ViewportPointToRay(point.X, point.Y)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { dirt }
	local result = workspace:Raycast(ray.Origin, ray.Direction * 300, params)
	if result then
		lastSent = t
		ScrubEvent:FireServer(result.Position)
		bubbles(result.Position)
	end
end)

---------------------------------------------------------------------
-- Engine view: the car on the lift with its hood open, roll for an engine
---------------------------------------------------------------------
local engineUi = Instance.new("Frame")
engineUi.BackgroundTransparency = 1
engineUi.Size = UDim2.new(1, 0, 1, 0)
engineUi.Visible = false
engineUi.Parent = gui
text(engineUi, { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 20), Size = UDim2.new(0, 420, 0, 36), Text = "Choose your tires", TextColor3 = Color3.fromRGB(170, 220, 255), StrokeThickness = 2.5 })
local engineCar = text(engineUi, { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 58), Size = UDim2.new(0, 520, 0, 30), Text = "" })
local engineValue = text(engineUi, { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 92), Size = UDim2.new(0, 420, 0, 30), Text = "$0/s -> ?", TextColor3 = Color3.fromRGB(140, 255, 150) })
local engineCurrent = text(engineUi, { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -128), Size = UDim2.new(0, 520, 0, 40), Text = "", StrokeThickness = 3 })
text(engineUi, { Position = UDim2.new(0, 40, 0.5, -170), Size = UDim2.new(0, 280, 0, 30), Text = "TIRE CHANCES", TextColor3 = GOLD })
local chanceRows = {}
for i, engine in ipairs(Config.Engines) do
	local y = -130 + (i - 1) * 40
	local swatch = Instance.new("Frame")
	swatch.Position = UDim2.new(0, 40, 0.5, y)
	swatch.Size = UDim2.new(0, 30, 0, 30)
	swatch.BackgroundColor3 = engine.Color
	corner(swatch, 6)
	stroke(swatch, BLACK, 2)
	swatch.Parent = engineUi
	local name = text(engineUi, { Position = UDim2.new(0, 82, 0.5, y + 3), Size = UDim2.new(0, 170, 0, 24), Text = engine.Name, TextXAlignment = Enum.TextXAlignment.Left })
	local pct = text(engineUi, { Position = UDim2.new(0, 250, 0.5, y + 3), Size = UDim2.new(0, 80, 0, 24), Text = "", TextXAlignment = Enum.TextXAlignment.Right })
	chanceRows[i] = { Name = name, Pct = pct }
end
local rollButton = button(engineUi, { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, -150, 1, -40), Size = UDim2.new(0, 260, 0, 70), Text = "      ROLL TIRES" }, BTN.Orange)
keyBadge(rollButton, "E")
local luckyButton = button(engineUi, { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 150, 1, -40), Size = UDim2.new(0, 260, 0, 70), Text = "    LUCKY ROLL" }, WHITE)
do
	-- rainbow like the Lucky Roll in Clean a Painting
	Icons.Make("Clover", { Position = UDim2.new(0, 6, 0, 2), Size = UDim2.new(0, 56, 0, 56), ZIndex = 5 }).Parent = luckyButton
	local g = luckyButton.Face:FindFirstChildOfClass("UIGradient")
	g.Rotation = 0
	g.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 150, 60)),
		ColorSequenceKeypoint.new(0.35, Color3.fromRGB(240, 110, 200)),
		ColorSequenceKeypoint.new(0.7, Color3.fromRGB(120, 170, 255)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(120, 230, 120)),
	})
end
local luckyInfo = text(engineUi, { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 150, 1, -12), Size = UDim2.new(0, 260, 0, 24), Text = "" })
local doneButton = button(engineUi, { AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -40, 1, -40), Size = UDim2.new(0, 230, 0, 70), Text = "      DONE" }, BTN.Green)
keyBadge(doneButton, "Q")
local sellButton = button(engineUi, { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -100, 0, 24), Size = UDim2.new(0, 190, 0, 52), Text = "SELL" }, BTN.Red)
local closeButton = button(engineUi, { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -30, 0, 24), Size = UDim2.new(0, 56, 0, 52), Text = "X" }, BTN.Red)

local engineCarId, engineIndex = nil, nil
local busy = false

local function refreshEngineScreen()
	if not engineCarId then
		return
	end
	local car = Config.CarsById[engineCarId]
	local base = Config.GetCarIncome(engineCarId, 1)
	engineCar.Text = car.Name .. "  ·  " .. Config.Rarities[car.Rarity].Name
	engineCar.TextColor3 = Config.Rarities[car.Rarity].Color
	if engineIndex then
		local e = Config.Engines[engineIndex]
		engineValue.Text = "$" .. Config.FormatNumber(base) .. "/s  ->  $" .. Config.FormatNumber(Config.GetCarIncome(engineCarId, engineIndex)) .. "/s"
		engineCurrent.Text = e.Name .. "  (x" .. e.Mult .. ")"
		engineCurrent.TextColor3 = e.Color:Lerp(WHITE, 0.35)
		sellButton.Text = "SELL $" .. Config.FormatNumber(Config.GetCarIncome(engineCarId, engineIndex) * Config.SellSeconds)
	else
		engineValue.Text = "$" .. Config.FormatNumber(base) .. "/s  ->  ?"
		engineCurrent.Text = "Roll a set of tires!"
		engineCurrent.TextColor3 = WHITE
		sellButton.Text = "SELL $" .. Config.FormatNumber(base * Config.SellSeconds)
	end
	local chances = Config.GetEngineChances(player:GetAttribute("EngineLuck") or 0, false)
	for i, row in ipairs(chanceRows) do
		row.Pct.Text = string.format("%.2f%%", chances[i])
		row.Name.TextColor3 = (i == engineIndex) and GOLD or WHITE
	end
	luckyInfo.Text = (player:GetAttribute("Tokens") or 0) .. " tokens · Performance Rims or better"
end

local function liftFocus()
	return player:GetAttribute("LiftFocus")
end
local function enterEngineView()
	local focus = liftFocus()
	if not focus then
		return
	end
	if currentView == "Wash" then
		washUi.Visible = false
	end
	if currentView ~= "Engine" then
		playSound(SOUND_SWOOSH, 0.5)
	end
	currentView = "Engine"
	hud.Visible = false
	engineUi.Visible = true
	-- side-on view so the wheels and rims are the star
	setCamera(focus:PointToWorldSpace(Vector3.new(-8.5, 4.2, -14)), focus:PointToWorldSpace(Vector3.new(0, 0.4, -0.5)), false)
end
local function exitEngineView()
	engineUi.Visible = false
	engineCarId, engineIndex = nil, nil
	if currentView == "Engine" then
		restoreCamera()
	end
end

OpenEngineEvent.OnClientEvent:Connect(function(carId, current)
	engineCarId, engineIndex = carId, current
	enterEngineView()
	refreshEngineScreen()
end)

local function doAction(action)
	if busy or not engineCarId then
		return
	end
	busy = true
	if action == "Roll" or action == "Lucky" then
		for _ = 1, 9 do
			local i = math.random(1, #Config.Engines)
			engineCurrent.Text = Config.Engines[i].Name .. "..."
			engineCurrent.TextColor3 = Config.Engines[i].Color:Lerp(WHITE, 0.3)
			task.wait(0.07)
		end
	end
	local result = EngineAction:InvokeServer(action)
	if result and result.Ok then
		if result.Done then
			exitEngineView()
		elseif result.Engine then
			engineIndex = result.Engine
			refreshEngineScreen()
			local e = Config.Engines[engineIndex]
			showNotification("You got: " .. e.Name .. "!", e.Color:Lerp(WHITE, 0.35))
		end
	elseif result and result.Message then
		showNotification(result.Message, Color3.fromRGB(255, 130, 120))
		refreshEngineScreen()
	end
	busy = false
end
rollButton.MouseButton1Click:Connect(function()
	doAction("Roll")
end)
luckyButton.MouseButton1Click:Connect(function()
	doAction("Lucky")
end)
doneButton.MouseButton1Click:Connect(function()
	doAction("Done")
end)
sellButton.MouseButton1Click:Connect(function()
	doAction("Sell")
end)
closeButton.MouseButton1Click:Connect(exitEngineView)
UserInputService.InputBegan:Connect(function(input, processed)
	if processed then
		return
	end
	if currentView == "Engine" then
		if input.KeyCode == Enum.KeyCode.E then
			doAction("Roll")
		elseif input.KeyCode == Enum.KeyCode.Q then
			doAction("Done")
		end
	elseif currentView == "Wash" and input.KeyCode == Enum.KeyCode.Q then
		exitWashView()
	end
end)
player:GetAttributeChangedSignal("Tokens"):Connect(refreshEngineScreen)

---------------------------------------------------------------------
-- Index (collection book)
---------------------------------------------------------------------
local indexFrame = panel(gui, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.5, 10), Size = UDim2.new(0, 900, 0, 560), Visible = false })
Icons.Make("Book", { Position = UDim2.new(0, 14, 0, -6), Size = UDim2.new(0, 84, 0, 84) }).Parent = indexFrame
text(indexFrame, { Position = UDim2.new(0, 104, 0, 14), Size = UDim2.new(0, 220, 0, 52), Text = "INDEX", TextXAlignment = Enum.TextXAlignment.Left, StrokeThickness = 4 })
local indexTotal = inkText(indexFrame, { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -96, 0, 28), Size = UDim2.new(0, 320, 0, 26), Text = "", TextXAlignment = Enum.TextXAlignment.Right })
local indexClose = button(indexFrame, { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 18, 0, -18), Size = UDim2.new(0, 64, 0, 64), Text = "X" }, BTN.Red)
inkText(indexFrame, { Position = UDim2.new(0, 34, 0, 84), Size = UDim2.new(0, 180, 0, 20), Text = "CONTAINERS", TextXAlignment = Enum.TextXAlignment.Left })
local containerList = Instance.new("ScrollingFrame")
containerList.BackgroundTransparency = 1
containerList.Position = UDim2.new(0, 24, 0, 110)
containerList.Size = UDim2.new(0, 200, 1, -130)
containerList.CanvasSize = UDim2.new(0, 0, 0, #Config.Containers * 64)
containerList.ScrollBarThickness = 6
containerList.ScrollBarImageColor3 = BROWN
containerList.Parent = indexFrame
local cl = Instance.new("UIListLayout")
cl.Padding = UDim.new(0, 8)
cl.Parent = containerList
local clPad = Instance.new("UIPadding")
clPad.PaddingLeft = UDim.new(0, 4)
clPad.PaddingTop = UDim.new(0, 4)
clPad.Parent = containerList

local page = Instance.new("Frame")
page.Position = UDim2.new(0, 240, 0, 84)
page.Size = UDim2.new(1, -264, 1, -104)
page.BackgroundColor3 = CREAM_DARK
corner(page, 14)
stroke(page, BROWN, 3)
page.Parent = indexFrame
local headerLabel = inkText(page, { Position = UDim2.new(0, 16, 0, 10), Size = UDim2.new(0.6, 0, 0, 26), Text = "", TextColor3 = Color3.fromRGB(40, 90, 170), TextXAlignment = Enum.TextXAlignment.Left })
local bonusLabel = inkText(page, { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -16, 0, 12), Size = UDim2.new(0.38, 0, 0, 22), Text = "", TextXAlignment = Enum.TextXAlignment.Right })
local grid = Instance.new("ScrollingFrame")
grid.BackgroundTransparency = 1
grid.Position = UDim2.new(0, 10, 0, 44)
grid.Size = UDim2.new(1, -20, 1, -54)
grid.ScrollBarThickness = 6
grid.ScrollBarImageColor3 = BROWN
grid.Parent = page
local gl = Instance.new("UIGridLayout")
gl.CellSize = UDim2.new(0.25, -10, 0, 200)
gl.CellPadding = UDim2.new(0, 10, 0, 10)
gl.SortOrder = Enum.SortOrder.LayoutOrder
gl.Parent = grid
gl:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
	grid.CanvasSize = UDim2.new(0, 0, 0, gl.AbsoluteContentSize.Y + 10)
end)

local selectedContainer = 1
local containerButtons = {}

local function makeCard(carId, discovered, claimed, order)
	local car = Config.CarsById[carId]
	local rarity = Config.Rarities[car.Rarity]
	local card = Instance.new("Frame")
	card.BackgroundColor3 = CREAM
	card.LayoutOrder = order
	corner(card, 12)
	stroke(card, discovered and rarity.Color:Lerp(BROWN, 0.3) or BROWN, 3)
	card.Parent = grid
	local photo = Instance.new("Frame")
	photo.Position = UDim2.new(0, 8, 0, 8)
	photo.Size = UDim2.new(1, -16, 0, 92)
	photo.BackgroundColor3 = discovered and Color3.fromRGB(205, 225, 245) or Color3.fromRGB(200, 190, 175)
	corner(photo, 8)
	stroke(photo, BROWN, 2)
	photo.Parent = card
	local vp = Instance.new("ViewportFrame")
	vp.BackgroundTransparency = 1
	vp.Size = UDim2.new(1, 0, 1, 0)
	vp.Ambient = Color3.fromRGB(200, 200, 210)
	vp.LightColor = Color3.fromRGB(255, 250, 240)
	vp.Parent = photo
	local model = CarBuilder.BuildCar(carId, { Silhouette = not discovered })
	model:PivotTo(CFrame.new(0, 0, 0) * CFrame.Angles(0, math.rad(35), 0))
	model.Parent = vp
	local cam = Instance.new("Camera")
	cam.FieldOfView = 30
	local _, size = model:GetBoundingBox()
	local dist = math.max(size.X, size.Z) * 1.5 + 2
	cam.CFrame = CFrame.lookAt(Vector3.new(dist * 0.55, dist * 0.38, -dist * 0.75), Vector3.new(0, size.Y * 0.4, 0))
	cam.Parent = vp
	vp.CurrentCamera = cam
	inkText(card, { Position = UDim2.new(0, 6, 0, 104), Size = UDim2.new(1, -12, 0, 22), Text = discovered and car.Name or "???" })
	inkText(card, { Position = UDim2.new(0, 6, 0, 128), Size = UDim2.new(1, -12, 0, 18), Text = rarity.Name .. " · " .. Config.GetOddsText(carId), TextColor3 = rarity.Color:Lerp(Color3.new(0, 0, 0), 0.25) })
	if discovered and not claimed then
		local b = button(card, { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -8), Size = UDim2.new(1, -16, 0, 38), Text = "COLLECT" }, BTN.Yellow)
		b.MouseButton1Click:Connect(function()
			b.Active = false
			if ClaimToken:InvokeServer(carId) then
				showNotification("+1 token!", GOLD)
			end
		end)
	else
		inkText(card, { Position = UDim2.new(0, 6, 0, 152), Size = UDim2.new(1, -12, 0, 22), Text = "$" .. Config.FormatNumber(car.BaseIncome) .. "/s", TextColor3 = GREEN_TEXT })
	end
end

local function refreshIndex()
	if not indexFrame.Visible then
		return
	end
	local discovered, total = idSet("Discovered")
	local claimed = idSet("Claimed")
	indexTotal.Text = total .. " / " .. #Config.Cars .. " discovered"
	for c, b in ipairs(containerButtons) do
		local n = 0
		for _, id in ipairs(Config.Containers[c].CarIds) do
			if discovered[id] then
				n = n + 1
			end
		end
		b.Text = "Container " .. c .. "\n" .. n .. " / 12"
		b.BackgroundColor3 = (c == selectedContainer) and BTN.Green or Color3.fromRGB(255, 225, 170)
		b.TextColor3 = (c == selectedContainer) and WHITE or TEXT_DARK
	end
	for _, child in ipairs(grid:GetChildren()) do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end
	local container = Config.Containers[selectedContainer]
	local found = 0
	for slot, id in ipairs(container.CarIds) do
		if discovered[id] then
			found = found + 1
		end
		makeCard(id, discovered[id], claimed[id], slot)
	end
	headerLabel.Text = "CONTAINER " .. selectedContainer .. " · " .. string.upper(container.Name)
	bonusLabel.Text = found == 12 and "COMPLETE: +5% income ✅" or (found .. " / 12 · complete for +5% income")
end

for c = 1, #Config.Containers do
	local b = Instance.new("TextButton")
	b.Size = UDim2.new(1, -14, 0, 56)
	b.Font = Enum.Font.FredokaOne
	b.TextScaled = true
	b.TextColor3 = TEXT_DARK
	b.BackgroundColor3 = Color3.fromRGB(255, 225, 170)
	b.AutoButtonColor = false
	b.LayoutOrder = c
	b.Text = "Container " .. c
	corner(b, 12)
	stroke(b, BROWN, 3)
	shine(b, 0.12)
	local pad = Instance.new("UIPadding")
	pad.PaddingTop = UDim.new(0, 6)
	pad.PaddingBottom = UDim.new(0, 6)
	pad.Parent = b
	juicy(b)
	b.Parent = containerList
	b.MouseButton1Click:Connect(function()
		selectedContainer = c
		refreshIndex()
	end)
	containerButtons[c] = b
end

local indexScale = Instance.new("UIScale")
indexScale.Parent = indexFrame
local baseScale = 1
local function setIndexOpen(open)
	if open then
		indexFrame.Visible = true
		indexScale.Scale = baseScale * 0.6
		TweenService:Create(indexScale, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = baseScale }):Play()
		refreshIndex()
		playSound(SOUND_SWOOSH, 0.5)
	else
		indexFrame.Visible = false
	end
end
indexButton.MouseButton1Click:Connect(function()
	setIndexOpen(not indexFrame.Visible)
end)
indexClose.MouseButton1Click:Connect(function()
	setIndexOpen(false)
end)
player:GetAttributeChangedSignal("Claimed"):Connect(refreshIndex)
player:GetAttributeChangedSignal("Discovered"):Connect(refreshIndex)

-- keep the Index readable on small screens
local function fitIndex()
	local vs = camera.ViewportSize
	baseScale = math.min(1, (vs.X - 40) / 900, (vs.Y - 60) / 560)
	if indexFrame.Visible then
		indexScale.Scale = baseScale
	end
end
camera:GetPropertyChangedSignal("ViewportSize"):Connect(fitIndex)
fitIndex()

---------------------------------------------------------------------
-- Only the owner sees prompts on their own cars and containers
---------------------------------------------------------------------
local function checkPrompt(prompt)
	local owner = prompt:GetAttribute("OwnerUserId")
	if owner and owner ~= player.UserId then
		prompt.Enabled = false
	end
end
for _, p in ipairs(CollectionService:GetTagged("OwnerPrompt")) do
	checkPrompt(p)
end
CollectionService:GetInstanceAddedSignal("OwnerPrompt"):Connect(checkPrompt)

player.CharacterAdded:Connect(function()
	if currentView then
		task.wait()
		restoreCamera()
		washUi.Visible = false
		engineUi.Visible = false
	end
end)

---------------------------------------------------------------------
-- Hotbar: every container and dirty car in your yard as a card (click to open / wash)
---------------------------------------------------------------------
local hotbar = Instance.new("ScrollingFrame")
hotbar.BackgroundTransparency = 1
hotbar.BorderSizePixel = 0
hotbar.AnchorPoint = Vector2.new(0.5, 1)
hotbar.Position = UDim2.new(0.5, 0, 1, -8)
hotbar.Size = UDim2.new(0, 10 * 112, 0, 116)
hotbar.ScrollingDirection = Enum.ScrollingDirection.X
hotbar.AutomaticCanvasSize = Enum.AutomaticSize.X
hotbar.CanvasSize = UDim2.new(0, 0, 0, 0)
hotbar.ScrollBarThickness = 4
hotbar.Parent = hud
local hl = Instance.new("UIListLayout")
hl.FillDirection = Enum.FillDirection.Horizontal
hl.HorizontalAlignment = Enum.HorizontalAlignment.Center
hl.Padding = UDim.new(0, 8)
hl.SortOrder = Enum.SortOrder.LayoutOrder
hl.Parent = hotbar
local cards = {}
local function cardFor(model)
	local kind = model:GetAttribute("Kind")
	local slot = model:GetAttribute("YardSlot")
	local b = Instance.new("TextButton")
	b.Size = UDim2.new(0, 104, 0, 104)
	b.AutoButtonColor = false
	b.Text = ""
	b.LayoutOrder = slot
	corner(b, 12)
	stroke(b, Color3.fromRGB(110, 40, 30), 3)
	shine(b, 0.15)
	local title = inkText(b, { Position = UDim2.new(0, 6, 0, 12), Size = UDim2.new(1, -12, 0, 52), TextColor3 = Color3.fromRGB(70, 30, 20), TextWrapped = true })
	local sub = text(b, { Position = UDim2.new(0, 4, 1, -28), Size = UDim2.new(1, -8, 0, 22), TextColor3 = Color3.fromRGB(120, 255, 120), StrokeThickness = 2 })
	local tc = Instance.new("UITextSizeConstraint")
	tc.MaxTextSize = 18
	tc.Parent = title
	if kind == "Container" then
		local level = model:GetAttribute("Level")
		b.BackgroundColor3 = Config.Containers[level].Color:Lerp(Color3.new(1, 1, 1), 0.25)
		title.Text = "Container " .. level .. " (unopened)"
		local price = model:GetAttribute("Price") or 0
		sub.Text = price > 0 and ("$" .. Config.FormatNumber(price)) or "FREE"
	else
		local id = model:GetAttribute("CarId")
		local car = Config.CarsById[id]
		b.BackgroundColor3 = Color3.fromRGB(240, 110, 90)
		title.Text = (car and car.Name or "Car") .. " (dirty)"
		sub.Text = car and ("$" .. Config.FormatNumber(car.BaseIncome) .. "/s") or ""
	end
	juicy(b)
	b.MouseButton1Click:Connect(function()
		YardAction:FireServer(slot)
	end)
	b.Parent = hotbar
	return b
end
local function refreshHotbar()
	local folder = workspace:FindFirstChild("Map") and workspace.Map:FindFirstChild("Cars")
	local seen = {}
	if folder then
		for _, m in ipairs(folder:GetChildren()) do
			if m:GetAttribute("OwnerUserId") == player.UserId and m:GetAttribute("YardSlot") then
				seen[m] = true
				if not cards[m] then
					cards[m] = cardFor(m)
				end
			end
		end
	end
	for m, b in pairs(cards) do
		if not seen[m] then
			b:Destroy()
			cards[m] = nil
		end
	end
	hotbar.Visible = currentView == nil
end
task.spawn(function()
	while true do
		refreshHotbar()
		task.wait(0.4)
	end
end)

---------------------------------------------------------------------
-- Station icons float and spin
---------------------------------------------------------------------
local icons = {}
local function addIcon(m)
	icons[m] = m:GetPivot()
end
for _, m in ipairs(CollectionService:GetTagged("StationIcon")) do
	addIcon(m)
end
CollectionService:GetInstanceAddedSignal("StationIcon"):Connect(addIcon)
CollectionService:GetInstanceRemovedSignal("StationIcon"):Connect(function(m)
	icons[m] = nil
end)
RunService.RenderStepped:Connect(function()
	local t = os.clock()
	for m, base in pairs(icons) do
		if m.Parent then
			m:PivotTo(base * CFrame.new(0, math.sin(t * 2) * 0.25, 0) * CFrame.Angles(0, t * 0.9, 0))
		end
	end
end)

---------------------------------------------------------------------
-- "While you were away" popup
---------------------------------------------------------------------
OfflineEvent.OnClientEvent:Connect(function(amount)
	local f = panel(gui, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.48, 0), Size = UDim2.new(0, 640, 0, 360) })
	inkText(f, { Position = UDim2.new(0, 40, 0, 30), Size = UDim2.new(0, 400, 0, 40), Text = "WHILE YOU WERE AWAY", TextXAlignment = Enum.TextXAlignment.Left })
	Icons.Make("Cash", { Position = UDim2.new(0, 50, 0, 90), Size = UDim2.new(0, 140, 0, 140) }).Parent = f
	text(f, { Position = UDim2.new(0, 200, 0, 115), Size = UDim2.new(0, 400, 0, 90), Text = "+$" .. Config.FormatNumber(amount), TextColor3 = Color3.fromRGB(40, 170, 60), StrokeThickness = 3, TextXAlignment = Enum.TextXAlignment.Left })
	local collect = button(f, { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -30), Size = UDim2.new(0, 520, 0, 72), Text = "COLLECT", TextColor3 = Color3.fromRGB(50, 40, 20) }, Color3.fromRGB(140, 210, 80))
	local close = button(f, { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -16, 0, 16), Size = UDim2.new(0, 64, 0, 64), Text = "X" }, BTN.Red)
	local scale = Instance.new("UIScale")
	scale.Scale = 0.6
	scale.Parent = f
	TweenService:Create(scale, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	local function done()
		floatGain(amount)
		f:Destroy()
	end
	collect.MouseButton1Click:Connect(done)
	close.MouseButton1Click:Connect(done)
end)

task.delay(2, function()
	showNotification("Welcome to D2D! Your first container is landing in your backyard.", GOLD)
end)

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
local Juice = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Juice"))
local Icons = require(Shared:WaitForChild("Icons"))
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local NotifyEvent = remotes:WaitForChild("Notify")
local ScrubEvent = remotes:WaitForChild("Scrub")
local RevealEvent = remotes:WaitForChild("Reveal")
local GoHomeEvent = remotes:WaitForChild("GoHome")
local ClaimToken = remotes:WaitForChild("ClaimToken")
local OfflineEvent = remotes:WaitForChild("Offline")
local OpenWashEvent = remotes:WaitForChild("OpenWash")
local WashFinish = remotes:WaitForChild("WashFinish")
local OpenTuneEvent = remotes:WaitForChild("OpenTune")
local TuneAction = remotes:WaitForChild("TuneAction")
local EquipCar = remotes:WaitForChild("EquipCar")
local OpenSellEvent = remotes:WaitForChild("OpenSell")
local OpenStorageEvent = remotes:WaitForChild("OpenStorage")
local SellAction = remotes:WaitForChild("SellAction")
local StorageAction = remotes:WaitForChild("StorageAction")
local HttpService = game:GetService("HttpService")
local StarterGui = game:GetService("StarterGui")
-- our own toolbar replaces Roblox's backpack bar
task.spawn(function()
	for _ = 1, 20 do
		if pcall(function()
			StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)
		end) then
			break
		end
		task.wait(0.5)
	end
end)

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

-- Painted UI kit (generated art, 9-sliced so it stretches to any size without blurring corners)
local UI_ART = {
	Green = { Id = "rbxassetid://112756175701104", W = 749, H = 298 },
	Blue = { Id = "rbxassetid://131173130754843", W = 755, H = 305 },
	Red = { Id = "rbxassetid://139684477436323", W = 759, H = 291 },
	Gold = { Id = "rbxassetid://119845650258438", W = 759, H = 328 },
	Panel = { Id = "rbxassetid://119283926119895", W = 748, H = 738 },
	Bar = { Id = "rbxassetid://130594728260397", W = 750, H = 149 },
	Close = "rbxassetid://105507747717488",
}
local function artFor(color)
	if color == BTN.Green then
		return UI_ART.Green
	elseif color == BTN.Blue then
		return UI_ART.Blue
	elseif color == BTN.Red then
		return UI_ART.Red
	elseif color == BTN.Yellow or color == BTN.Orange then
		return UI_ART.Gold
	end
	return nil
end
-- a pill image sliced so its round caps keep their shape at any button size
local function slicedPill(parent, art)
	local img = Instance.new("ImageLabel")
	img.Name = "Art"
	img.BackgroundTransparency = 1
	img.Size = UDim2.new(1, 0, 1, 0)
	img.Image = art.Id
	img.ScaleType = Enum.ScaleType.Slice
	local cap = math.floor(art.H / 2)
	img.SliceCenter = Rect.new(cap, math.floor(art.H * 0.3), art.W - cap, math.floor(art.H * 0.7))
	local function fit()
		local h = img.AbsoluteSize.Y
		if h > 0 then
			-- caps are half the image height; scale them to half the button height
			img.SliceScale = math.max(0.05, h / art.H)
		end
	end
	img:GetPropertyChangedSignal("AbsoluteSize"):Connect(fit)
	task.defer(fit)
	img.Parent = parent
	return img
end

-- Glossy push button: painted pill art, white outlined text, presses down when clicked.
-- Setting button.Text / TextColor3 later still works.
local function button(parent, props, color)
	color = color or BTN.Green
	local art = artFor(color)
	local isClose = props.Text == "X"
	local b = Instance.new("TextButton")
	b.AutoButtonColor = false
	b.BackgroundTransparency = 1
	b.TextTransparency = 1
	b.Text = ""
	local face
	if isClose then
		face = Instance.new("ImageLabel")
		face.Name = "Face"
		face.BackgroundTransparency = 1
		face.Image = UI_ART.Close
		face.ScaleType = Enum.ScaleType.Fit
		face.Size = UDim2.new(1, 0, 1, 0)
	elseif art then
		face = Instance.new("Frame")
		face.Name = "Face"
		face.BackgroundTransparency = 1
		face.Size = UDim2.new(1, 0, 1, 0)
		slicedPill(face, art)
	else
		-- plain colours (cream etc.) keep the drawn style
		b.BackgroundTransparency = 0
		b.BackgroundColor3 = color:Lerp(Color3.new(0, 0, 0), 0.38)
		corner(b, 14)
		stroke(b, BLACK, 3)
		face = Instance.new("Frame")
		face.Name = "Face"
		face.BorderSizePixel = 0
		face.Size = UDim2.new(1, 0, 1, -6)
		face.BackgroundColor3 = WHITE
		corner(face, 13)
		local g = Instance.new("UIGradient")
		g.Rotation = 90
		g.Color = ColorSequence.new(color:Lerp(WHITE, 0.22), color)
		g.Parent = face
	end
	local label = Instance.new("TextLabel")
	label.Name = "Label"
	label.BackgroundTransparency = 1
	label.Position = UDim2.new(0, 14, 0.2, 0)
	label.Size = UDim2.new(1, -28, 0.56, 0)
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = WHITE
	label.ZIndex = 3
	label.Visible = not isClose
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
	local pressScale = Instance.new("UIScale")
	pressScale.Parent = face
	b.MouseButton1Down:Connect(function()
		TweenService:Create(pressScale, TweenInfo.new(0.06), { Scale = 0.92 }):Play()
	end)
	local function release()
		TweenService:Create(pressScale, TweenInfo.new(0.18, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
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

-- cream "paper" panel: the painted panel art, 9-sliced so the thick rounded frame keeps its shape
local function panel(parent, props)
	local f = Instance.new("ImageLabel")
	f.BackgroundTransparency = 1
	f.Image = UI_ART.Panel.Id
	f.ScaleType = Enum.ScaleType.Slice
	f.SliceCenter = Rect.new(110, 110, UI_ART.Panel.W - 110, UI_ART.Panel.H - 110)
	f.SliceScale = 0.32
	for k, v in pairs(props) do
		f[k] = v
	end
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
	local f = Instance.new("ImageLabel")
	f.BackgroundTransparency = 1
	f.Position = UDim2.new(0, 46, 0, y)
	f.Size = UDim2.new(0, width, 0, 52)
	f.Image = UI_ART.Panel.Id
	f.ScaleType = Enum.ScaleType.Slice
	f.SliceCenter = Rect.new(110, 110, UI_ART.Panel.W - 110, UI_ART.Panel.H - 110)
	f.SliceScale = 0.2
	f.Parent = hud
	Icons.Make(icon, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0, 2, 0.5, 0), Size = UDim2.new(0, 64, 0, 64), ZIndex = 3 }).Parent = f
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
local _, tokenLabel = pill(136, 160, "Coin", TEXT_DARK)
local incomeLabel = text(hud, { Position = UDim2.new(0, 306, 0, 78), Size = UDim2.new(0, 200, 0, 26), Text = "", TextColor3 = Color3.fromRGB(130, 255, 140), TextXAlignment = Enum.TextXAlignment.Left })

do
	-- dark glossy capsule behind the delivery timer
	local timerBack = Instance.new("Frame")
	timerBack.Name = "TimerBack"
	timerBack.AnchorPoint = Vector2.new(0.5, 0)
	timerBack.Position = UDim2.new(0.5, 0, 0, 8)
	timerBack.Size = UDim2.new(0, 250, 0, 68)
	timerBack.BackgroundTransparency = 1
	timerBack.Parent = hud
	slicedPill(timerBack, UI_ART.Bar)
end
local timerTitle = text(hud, { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 14), Size = UDim2.new(0, 260, 0, 18), Text = "CONTAINER DELIVERY", StrokeThickness = 1.5 })
local timerLabel = text(hud, { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 34), Size = UDim2.new(0, 200, 0, 36), Text = "--:--", StrokeThickness = 2.5 })
local timerBackFrame = timerTitle.Parent:FindFirstChild("TimerBack")
-- the delivery timer only matters once the truck starts coming (after the tutorial)
local function timerGroupVisible(v)
	timerTitle.Visible = v
	timerLabel.Visible = v
	if timerBackFrame then
		timerBackFrame.Visible = v
	end
end

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
			-- big gains get more feedback than the steady per-second income
			if diff >= math.max(50, lastCash * 0.25) then
				Juice.Feedback("medium", cashPill)
			elseif diff >= lastCash * 0.05 then
				Juice.Feedback("small", cashPill)
			end
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
	timerGroupVisible(player:GetAttribute("Tutorial") ~= true)
	if player:GetAttribute("YardFull") then
		timerLabel.Text = "YARD FULL!"
		timerLabel.TextColor3 = Color3.fromRGB(255, 120, 110)
	elseif nextAt then
		timerLabel.Text = Config.FormatTime(nextAt - workspace:GetServerTimeNow())
		timerLabel.TextColor3 = WHITE
	end
	incomeLabel.Text = ""
end)

---------------------------------------------------------------------
-- Messages
---------------------------------------------------------------------
local notifyList = Instance.new("Frame")
notifyList.BackgroundTransparency = 1
notifyList.AnchorPoint = Vector2.new(0.5, 0)
notifyList.Position = UDim2.new(0.5, 0, 0, 140)
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
	-- rarer cars hit harder
	Juice.Shake(car.Rarity >= 4 and 0.7 or (car.Rarity >= 2 and 0.45 or 0.3))
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

local ProximityPromptService = game:GetService("ProximityPromptService")
local function setViewChrome(inView)
	ProximityPromptService.Enabled = not inView
	pcall(function()
		StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList, not inView)
	end)
end
local function setCamera(cf, focus, instant)
	setViewChrome(true)
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
	setViewChrome(false)
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
local washCancel = button(washUi, { AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -40, 1, -28), Size = UDim2.new(0, 200, 0, 64), Text = "      LEAVE" }, BTN.Red)
keyBadge(washCancel, "Q")
-- appears once the car is clean enough; the player decides when the wash is done
local finishWash = button(washUi, { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 104), Size = UDim2.new(0, 300, 0, 74), Text = "FINISH", Visible = false }, BTN.Green)

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
finishWash.MouseButton1Click:Connect(function()
	WashFinish:FireServer()
	finishWash.Visible = false
end)
OpenWashEvent.OnClientEvent:Connect(enterWashView)
local function refreshFinish()
	local ready = player:GetAttribute("WashReady") == true
	if ready and not finishWash.Visible then
		finishWash.Visible = true
		Juice.Pop(finishWash)
		playSound(SOUND_SWOOSH, 0.4)
	elseif not ready then
		finishWash.Visible = false
	end
end
player:GetAttributeChangedSignal("WashReady"):Connect(refreshFinish)

local function refreshWash()
	local p = player:GetAttribute("WashProgress")
	if p then
		washPercent.Text = string.format("%.1f%%", p * 100)
		washFill.Size = UDim2.new(math.clamp(p, 0, 1), 0, 1, 0)
	else
		if currentView == "Wash" then
			washPercent.Text = "100%"
			washFill.Size = UDim2.new(1, 0, 1, 0)
			task.delay(0.6, exitWashView)
		end
	end
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
-- Service view: the tune-up mini-game. Stop the needle in the green zone (gold = perfect),
-- three rounds. The result multiplies what every customer pays to look at the car.
---------------------------------------------------------------------
local tuneUi = Instance.new("Frame")
tuneUi.BackgroundTransparency = 1
tuneUi.Size = UDim2.new(1, 0, 1, 0)
tuneUi.Visible = false
tuneUi.Parent = gui
text(tuneUi, { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 22), Size = UDim2.new(0, 420, 0, 34), Text = "SERVICE  ·  TUNE-UP", TextColor3 = Color3.fromRGB(170, 220, 255), StrokeThickness = 2.5 })
local tuneCar = text(tuneUi, { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 58), Size = UDim2.new(0, 520, 0, 28), Text = "" })
local tuneClose = button(tuneUi, { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -30, 0, 24), Size = UDim2.new(0, 56, 0, 52), Text = "X" }, BTN.Red)

-- the gauge
local gauge = Instance.new("Frame")
gauge.AnchorPoint = Vector2.new(0.5, 1)
gauge.Position = UDim2.new(0.5, 0, 1, -170)
gauge.Size = UDim2.new(0, 560, 0, 38)
gauge.BackgroundColor3 = Color3.fromRGB(30, 32, 40)
corner(gauge, 10)
stroke(gauge, Color3.fromRGB(12, 12, 16), 3)
gauge.Parent = tuneUi
local goodZone = Instance.new("Frame")
goodZone.AnchorPoint = Vector2.new(0.5, 0)
goodZone.BackgroundColor3 = Color3.fromRGB(70, 200, 110)
goodZone.Size = UDim2.new(0.2, 0, 1, 0)
corner(goodZone, 6)
goodZone.Parent = gauge
local perfectZone = Instance.new("Frame")
perfectZone.AnchorPoint = Vector2.new(0.5, 0)
perfectZone.BackgroundColor3 = Color3.fromRGB(255, 205, 60)
perfectZone.Size = UDim2.new(0.06, 0, 1, 0)
corner(perfectZone, 4)
perfectZone.Parent = gauge
local needle = Instance.new("Frame")
needle.AnchorPoint = Vector2.new(0.5, 0.5)
needle.Position = UDim2.new(0, 0, 0.5, 0)
needle.Size = UDim2.new(0, 8, 1, 22)
needle.BackgroundColor3 = WHITE
corner(needle, 4)
stroke(needle, Color3.fromRGB(20, 20, 26), 2)
needle.ZIndex = 3
needle.Parent = gauge
local tuneHint = text(tuneUi, { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -218), Size = UDim2.new(0, 560, 0, 26), Text = "Stop the needle in the green. Gold is perfect!", TextColor3 = Color3.fromRGB(220, 235, 255) })
local tuneVerdict = text(tuneUi, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.42, 0), Size = UDim2.new(0, 500, 0, 70), Text = "", StrokeThickness = 4 })
local dots = {}
for i = 1, Config.TuneRounds do
	local d = Instance.new("Frame")
	d.AnchorPoint = Vector2.new(0.5, 0.5)
	d.Position = UDim2.new(0.5, (i - 2) * 44, 1, -122)
	d.Size = UDim2.new(0, 30, 0, 30)
	d.BackgroundColor3 = Color3.fromRGB(60, 62, 72)
	corner(d, 15)
	stroke(d, WHITE, 2)
	d.Parent = tuneUi
	dots[i] = d
end
local tuneButton = button(tuneUi, { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -30), Size = UDim2.new(0, 280, 0, 72), Text = "      TUNE!" }, BTN.Orange)
keyBadge(tuneButton, "E")

-- the result card
local resultCard = panel(tuneUi, { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -24), Size = UDim2.new(0, 560, 0, 230), Visible = false })
local resultName = text(resultCard, { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 26), Size = UDim2.new(1, -60, 0, 44), Text = "", StrokeThickness = 3.5 })
local resultValue = inkText(resultCard, { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 78), Size = UDim2.new(1, -60, 0, 28), Text = "" })
local resultFinish = button(resultCard, { AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -28, 1, -26), Size = UDim2.new(0, 230, 0, 70), Text = "FINISH" }, BTN.Green)
local resultTurbo = button(resultCard, { AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 28, 1, -26), Size = UDim2.new(0, 250, 0, 70), Text = "TURBO +1" }, BTN.Orange)
local turboInfo = inkText(resultCard, { AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 34, 1, -100), Size = UDim2.new(0, 240, 0, 20), Text = "" })

local tune = nil -- { CarId, Round, Start, Speed, Center, Good, Perfect, Busy, Frozen, Done, Tune, Turbo }

local function setZones()
	goodZone.Position = UDim2.new(tune.Center, 0, 0, 0)
	goodZone.Size = UDim2.new(tune.Good * 2, 0, 1, 0)
	perfectZone.Position = UDim2.new(tune.Center, 0, 0, 0)
	perfectZone.Size = UDim2.new(tune.Perfect * 2, 0, 1, 0)
end

local function showResult()
	local t = Config.Tunes[tune.Tune or 1]
	local car = Config.CarsById[tune.CarId]
	gauge.Visible, tuneButton.Visible, tuneHint.Visible = false, false, false
	for _, d in ipairs(dots) do
		d.Visible = false
	end
	resultCard.Visible = true
	resultName.Text = t.Name .. "  x" .. t.Mult
	resultName.TextColor3 = t.Color:Lerp(WHITE, 0.25)
	resultValue.Text = car and ("Customers pay $" .. Config.FormatNumber(Config.GetCarIncome(tune.CarId, tune.Tune) * Config.ViewSeconds) .. " per view") or ""
	local canTurbo = not tune.Turbo and (tune.Tune or 1) < #Config.Tunes and (player:GetAttribute("Tokens") or 0) >= 1
	resultTurbo.Visible = canTurbo
	turboInfo.Visible = canTurbo
	turboInfo.Text = "1 token  ·  you have " .. (player:GetAttribute("Tokens") or 0)
	Juice.Pop(resultCard)
end

local function liftFocus()
	return player:GetAttribute("LiftFocus")
end
local function enterTuneView()
	local focus = liftFocus()
	if not focus then
		return
	end
	if currentView == "Wash" then
		washUi.Visible = false
	end
	if currentView ~= "Tune" then
		playSound(SOUND_SWOOSH, 0.5)
	end
	currentView = "Tune"
	hud.Visible = false
	tuneUi.Visible = true
	-- a three-quarter front view of the car on the lift
	setCamera(focus:PointToWorldSpace(Vector3.new(-9, 6, -12)), focus:PointToWorldSpace(Vector3.new(0, 0.6, -1)), false)
end
local function exitTuneView()
	tuneUi.Visible = false
	tune = nil
	if currentView == "Tune" then
		restoreCamera()
	end
end

local function applyRound(r)
	tune.Round, tune.Start, tune.Speed = r.Round, r.Start, r.Speed
	tune.Center, tune.Good, tune.Perfect = r.Center, r.Good, r.Perfect
	tune.Frozen = nil
	setZones()
end

OpenTuneEvent.OnClientEvent:Connect(function(carId, tunedEngine)
	tune = { CarId = carId }
	local car = Config.CarsById[carId]
	tuneCar.Text = car and (car.Name .. "  ·  " .. Config.Rarities[car.Rarity].Name) or ""
	tuneCar.TextColor3 = car and Config.Rarities[car.Rarity].Color or WHITE
	tuneVerdict.Text = ""
	resultCard.Visible = false
	gauge.Visible, tuneButton.Visible, tuneHint.Visible = true, true, true
	for _, d in ipairs(dots) do
		d.Visible = true
		d.BackgroundColor3 = Color3.fromRGB(60, 62, 72)
	end
	enterTuneView()
	if tunedEngine then
		tune.Done, tune.Tune = true, tunedEngine
		showResult()
		return
	end
	local r = TuneAction:InvokeServer("Start")
	if tune and r and r.Ok then
		applyRound(r)
	elseif r and r.Message then
		showNotification(r.Message, Color3.fromRGB(255, 130, 120))
	end
end)

local function verdict(textValue, color)
	tuneVerdict.Text = textValue
	tuneVerdict.TextColor3 = color
	tuneVerdict.TextTransparency = 0
	Juice.Pop(tuneVerdict, 1.4)
	task.delay(0.7, function()
		if tuneVerdict.Text == textValue then
			TweenService:Create(tuneVerdict, TweenInfo.new(0.3), { TextTransparency = 1 }):Play()
		end
	end)
end

local function hit()
	if not tune or tune.Busy or tune.Done or not tune.Start then
		return
	end
	local t = workspace:GetServerTimeNow()
	if t < tune.Start then
		return
	end
	tune.Busy = true
	tune.Frozen = Config.NeedleAt(t - tune.Start, tune.Speed)
	local round = tune.Round
	local r = TuneAction:InvokeServer("Hit", t)
	if not tune then
		return
	end
	tune.Busy = false
	if not r or not r.Ok then
		tune.Frozen = nil
		return
	end
	tune.Frozen = r.Pos
	local colors = { Perfect = Color3.fromRGB(255, 210, 70), Good = Color3.fromRGB(110, 230, 140), Miss = Color3.fromRGB(255, 110, 100) }
	verdict(string.upper(r.Result) .. (r.Result == "Perfect" and "!" or ""), colors[r.Result])
	if dots[round] then
		dots[round].BackgroundColor3 = colors[r.Result]
	end
	if r.Result ~= "Miss" then
		Juice.Feedback(r.Result == "Perfect" and "medium" or "small", tuneButton)
	end
	if r.Done then
		tune.Done, tune.Tune = true, r.Tune
		task.delay(0.8, function()
			if tune and tune.Done then
				showResult()
			end
		end)
	else
		task.delay(0.35, function()
			if tune then
				applyRound(r)
			end
		end)
	end
end
tuneButton.MouseButton1Click:Connect(hit)
tuneClose.MouseButton1Click:Connect(exitTuneView)
resultFinish.MouseButton1Click:Connect(function()
	local r = TuneAction:InvokeServer("Finish")
	if r and r.Ok then
		exitTuneView()
	elseif r and r.Message then
		showNotification(r.Message, Color3.fromRGB(255, 130, 120))
	end
end)
resultTurbo.MouseButton1Click:Connect(function()
	local r = TuneAction:InvokeServer("Turbo")
	if r and r.Ok and tune then
		tune.Tune, tune.Turbo = r.Tune, true
		showResult()
	elseif r and r.Message then
		showNotification(r.Message, Color3.fromRGB(255, 130, 120))
	end
end)

RunService.RenderStepped:Connect(function()
	if not tune or not tune.Start or tune.Done then
		return
	end
	local pos = tune.Frozen
	if not pos then
		local elapsed = workspace:GetServerTimeNow() - tune.Start
		pos = elapsed >= 0 and Config.NeedleAt(elapsed, tune.Speed) or 0
	end
	needle.Position = UDim2.new(pos, 0, 0.5, 0)
end)

UserInputService.InputBegan:Connect(function(input, processed)
	if processed then
		return
	end
	if currentView == "Tune" then
		if input.KeyCode == Enum.KeyCode.E or input.KeyCode == Enum.KeyCode.Space then
			hit()
		end
	elseif currentView == "Wash" and input.KeyCode == Enum.KeyCode.Q then
		exitWashView()
	end
end)

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
containerList.CanvasSize = UDim2.new(0, 0, 0, 0)
containerList.AutomaticCanvasSize = Enum.AutomaticSize.Y
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
-- AutomaticCanvasSize measures in unscaled units, so the UIScale on the index no longer cuts the last row off
grid.CanvasSize = UDim2.new(0, 0, 0, 0)
grid.AutomaticCanvasSize = Enum.AutomaticSize.Y
grid.ScrollingDirection = Enum.ScrollingDirection.Y
local gridPad = Instance.new("UIPadding")
gridPad.PaddingTop = UDim.new(0, 4)
gridPad.PaddingBottom = UDim.new(0, 24)
gridPad.Parent = grid

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
		b.Text = Config.Containers[c].Era .. "\n" .. n .. " / 12"
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
	b.Text = Config.Containers[c].Era
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
		tuneUi.Visible = false
	end
end)

---------------------------------------------------------------------
-- Toolbar: your finished cars. Click a card (or press 1-9, 0) to hold it as a toy car,
-- then walk to a glowing spot in your garage and place it.
---------------------------------------------------------------------
local hotbar = Instance.new("Frame")
hotbar.BackgroundTransparency = 1
hotbar.AnchorPoint = Vector2.new(0.5, 1)
hotbar.Position = UDim2.new(0.5, 0, 1, -10)
hotbar.Size = UDim2.new(0, 10 * 104, 0, 104)
hotbar.Parent = hud
local hl = Instance.new("UIListLayout")
hl.FillDirection = Enum.FillDirection.Horizontal
hl.HorizontalAlignment = Enum.HorizontalAlignment.Center
hl.VerticalAlignment = Enum.VerticalAlignment.Bottom
hl.Padding = UDim.new(0, 8)
hl.SortOrder = Enum.SortOrder.LayoutOrder
hl.Parent = hotbar

local inventory = {}
local cards = {} -- [uid] = card
local function holding()
	return player:GetAttribute("Holding")
end

-- a little 3D picture of the car on its card
local function carViewport(parent, carId)
	local vp = Instance.new("ViewportFrame")
	vp.BackgroundTransparency = 1
	vp.Size = UDim2.new(1, 0, 1, -22)
	vp.Ambient = Color3.fromRGB(170, 170, 180)
	vp.LightColor = Color3.fromRGB(255, 255, 255)
	vp.LightDirection = Vector3.new(-1, -1.4, -0.6)
	vp.ZIndex = 2
	vp.Parent = parent
	local ok, model = pcall(CarBuilder.BuildCar, carId)
	if ok and model then
		for _, d in ipairs(model:GetDescendants()) do
			if d:IsA("BillboardGui") or d:IsA("ProximityPrompt") then
				d:Destroy()
			end
		end
		model:PivotTo(CFrame.new())
		model.Parent = vp
		local cf, size = model:GetBoundingBox()
		local cam = Instance.new("Camera")
		local d = math.max(size.X, size.Z) * 0.95
		cam.CFrame = CFrame.lookAt(cf.Position + Vector3.new(-d * 0.75, d * 0.42, -d * 0.75), cf.Position)
		cam.FieldOfView = 40
		cam.Parent = vp
		vp.CurrentCamera = cam
	end
	return vp
end

local function cardFor(car, i)
	local def = Config.CarsById[car.Id]
	local rarity = def and Config.Rarities[def.Rarity]
	local b = Instance.new("TextButton")
	b.Size = UDim2.new(0, 96, 0, 96)
	b.AutoButtonColor = false
	b.Text = ""
	b.BackgroundColor3 = Color3.fromRGB(34, 37, 46)
	b.BackgroundTransparency = 0.1
	corner(b, 12)
	local st = stroke(b, rarity and rarity.Color or WHITE, 2)
	b:SetAttribute("Uid", car.Uid)
	carViewport(b, car.Id)
	local key = Instance.new("TextLabel")
	key.BackgroundTransparency = 1
	key.Position = UDim2.new(0, 6, 0, 3)
	key.Size = UDim2.new(0, 20, 0, 18)
	key.Font = Enum.Font.GothamBold
	key.TextScaled = true
	key.TextColor3 = Color3.fromRGB(200, 205, 215)
	key.ZIndex = 3
	key.Parent = b
	local tuneDef = Config.Tunes[car.Engine or 1]
	local price = text(b, { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -3), Size = UDim2.new(1, -8, 0, 18), Text = "$" .. Config.FormatNumber(Config.GetCarIncome(car.Id, car.Engine) * Config.ViewSeconds) .. "/view", TextColor3 = Color3.fromRGB(130, 245, 150), StrokeThickness = 1.2, ZIndex = 3 })
	price.Font = Enum.Font.GothamBold
	if (car.Engine or 1) > 1 then
		local tag = Instance.new("Frame")
		tag.Size = UDim2.new(0, 12, 0, 12)
		tag.Position = UDim2.new(1, -18, 0, 6)
		tag.BackgroundColor3 = tuneDef.Color
		tag.ZIndex = 3
		corner(tag, 6)
		tag.Parent = b
	end
	juicy(b)
	b.MouseButton1Click:Connect(function()
		EquipCar:FireServer(b:GetAttribute("Uid"))
	end)
	b.Parent = hotbar
	return { Button = b, Stroke = st, Key = key, Rarity = rarity }
end

local function refreshHotbar()
	local ok, list = pcall(HttpService.JSONDecode, HttpService, player:GetAttribute("Inventory") or "[]")
	inventory = ok and list or {}
	local seen = {}
	for i, car in ipairs(inventory) do
		seen[car.Uid] = true
		local c = cards[car.Uid] or cardFor(car, i)
		cards[car.Uid] = c
		c.Button.LayoutOrder = i
		c.Key.Text = i <= 10 and tostring(i % 10) or ""
	end
	for uid, c in pairs(cards) do
		if not seen[uid] then
			c.Button:Destroy()
			cards[uid] = nil
		end
	end
end
local function refreshHeld()
	local held = holding()
	for uid, c in pairs(cards) do
		local on = uid == held
		c.Stroke.Thickness = on and 4 or 2
		c.Stroke.Color = on and WHITE or (c.Rarity and c.Rarity.Color or WHITE)
		c.Button.BackgroundColor3 = on and Color3.fromRGB(60, 120, 200) or Color3.fromRGB(34, 37, 46)
	end
end
player:GetAttributeChangedSignal("Inventory"):Connect(function()
	refreshHotbar()
	refreshHeld()
end)
player:GetAttributeChangedSignal("Holding"):Connect(refreshHeld)
refreshHotbar()

local NUM_KEYS = { Enum.KeyCode.One, Enum.KeyCode.Two, Enum.KeyCode.Three, Enum.KeyCode.Four, Enum.KeyCode.Five, Enum.KeyCode.Six, Enum.KeyCode.Seven, Enum.KeyCode.Eight, Enum.KeyCode.Nine, Enum.KeyCode.Zero }
UserInputService.InputBegan:Connect(function(input, processed)
	if processed or currentView then
		return
	end
	for i, k in ipairs(NUM_KEYS) do
		if input.KeyCode == k and inventory[i] then
			EquipCar:FireServer(inventory[i].Uid)
			return
		end
	end
end)

-- display spots glow only while you hold a car, so it's obvious where it goes
local markerTime = 0
RunService.RenderStepped:Connect(function(dt)
	markerTime = markerTime + dt
	local held = holding() ~= nil
	local myPlot = player:GetAttribute("PlotIndex")
	local pulse = 0.68 + 0.12 * math.sin(markerTime * 4)
	for _, m in ipairs(CollectionService:GetTagged("SpotMarker")) do
		local mine = m:GetAttribute("PlotIndex") == myPlot
		local show = held and mine and not m:GetAttribute("Occupied")
		m.Transparency = show and pulse or 1
		local prompt = m:FindFirstChildOfClass("ProximityPrompt")
		if prompt then
			prompt.Enabled = show
		end
	end
	hotbar.Visible = currentView == nil
end)

---------------------------------------------------------------------
-- Sell Station and Storage Unit panels
---------------------------------------------------------------------
local function decode(attr)
	local ok, list = pcall(HttpService.JSONDecode, HttpService, player:GetAttribute(attr) or "[]")
	return ok and list or {}
end
local function carLine(car)
	local def = Config.CarsById[car.Id]
	local tuneDef = Config.Tunes[car.Engine or 1]
	return def and def.Name or car.Id, def and Config.Rarities[def.Rarity].Color or WHITE, tuneDef and tuneDef.Name or ""
end
local function listFrame(parent, props)
	local sf = Instance.new("ScrollingFrame")
	sf.BackgroundColor3 = CREAM_DARK
	sf.BackgroundTransparency = 0.2
	sf.BorderSizePixel = 0
	sf.ScrollBarThickness = 6
	sf.ScrollBarImageColor3 = BROWN
	sf.CanvasSize = UDim2.new(0, 0, 0, 0)
	sf.AutomaticCanvasSize = Enum.AutomaticSize.Y
	for k, v in pairs(props) do
		sf[k] = v
	end
	corner(sf, 12)
	local l = Instance.new("UIListLayout")
	l.Padding = UDim.new(0, 6)
	l.SortOrder = Enum.SortOrder.LayoutOrder
	l.Parent = sf
	local pad = Instance.new("UIPadding")
	pad.PaddingTop, pad.PaddingBottom = UDim.new(0, 8), UDim.new(0, 8)
	pad.PaddingLeft, pad.PaddingRight = UDim.new(0, 8), UDim.new(0, 8)
	pad.Parent = sf
	sf.Parent = parent
	return sf
end
local function row(list, order, car, rightText, buttonText, buttonColor, onClick)
	local r = Instance.new("Frame")
	r.Size = UDim2.new(1, 0, 0, 48)
	r.BackgroundColor3 = CREAM
	r.LayoutOrder = order
	corner(r, 10)
	r.Parent = list
	local name, color, tuneName = carLine(car)
	local n = inkText(r, { Position = UDim2.new(0, 12, 0, 4), Size = UDim2.new(0.55, 0, 0, 22), Text = name, TextXAlignment = Enum.TextXAlignment.Left })
	n.TextColor3 = color:Lerp(Color3.new(0, 0, 0), 0.35)
	inkText(r, { Position = UDim2.new(0, 12, 0, 26), Size = UDim2.new(0.55, 0, 0, 16), Text = tuneName, TextXAlignment = Enum.TextXAlignment.Left })
	if rightText then
		inkText(r, { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -128, 0.5, 0), Size = UDim2.new(0, 120, 0, 22), Text = rightText, TextXAlignment = Enum.TextXAlignment.Right })
	end
	local b = button(r, { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -6, 0.5, 0), Size = UDim2.new(0, 112, 0, 40), Text = buttonText }, buttonColor)
	b.MouseButton1Click:Connect(onClick)
	return r
end
local function emptyNote(list, textValue)
	local l = inkText(list, { Size = UDim2.new(1, 0, 0, 40), Text = textValue })
	l.LayoutOrder = 0
end

-- Sell Station
local sellFrame = panel(gui, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.5, 0), Size = UDim2.new(0, 560, 0, 520), Visible = false })
Icons.Make("Cash", { Position = UDim2.new(0, 18, 0, -4), Size = UDim2.new(0, 76, 0, 76) }).Parent = sellFrame
text(sellFrame, { Position = UDim2.new(0, 100, 0, 18), Size = UDim2.new(0, 300, 0, 44), Text = "SELL CARS", TextXAlignment = Enum.TextXAlignment.Left, StrokeThickness = 3.5 })
local sellClose = button(sellFrame, { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 16, 0, -16), Size = UDim2.new(0, 60, 0, 60), Text = "X" }, BTN.Red)
local sellList = listFrame(sellFrame, { Position = UDim2.new(0, 28, 0, 84), Size = UDim2.new(1, -56, 1, -184) })
local sellAll = button(sellFrame, { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -24), Size = UDim2.new(0, 330, 0, 64), Text = "SELL ALL" }, BTN.Orange)

local function refreshSell()
	for _, c in ipairs(sellList:GetChildren()) do
		if c:IsA("GuiObject") then
			c:Destroy()
		end
	end
	local inv = decode("Inventory")
	local total = 0
	for i, car in ipairs(inv) do
		local value = Config.GetCarIncome(car.Id, car.Engine) * Config.SellSeconds
		total = total + value
		row(sellList, i, car, "$" .. Config.FormatNumber(value), "SELL", BTN.Green, function()
			local r = SellAction:InvokeServer("Sell", car.Uid)
			if r and r.Message then
				showNotification(r.Message, Color3.fromRGB(255, 130, 120))
			end
		end)
	end
	if #inv == 0 then
		emptyNote(sellList, "Your toolbar is empty.")
	end
	sellAll.Visible = #inv > 0
	sellAll.Text = "SELL ALL  $" .. Config.FormatNumber(total)
end
sellAll.MouseButton1Click:Connect(function()
	local r = SellAction:InvokeServer("SellAll")
	if r and r.Message then
		showNotification(r.Message, Color3.fromRGB(255, 130, 120))
	end
end)
sellClose.MouseButton1Click:Connect(function()
	sellFrame.Visible = false
end)
OpenSellEvent.OnClientEvent:Connect(function()
	refreshSell()
	sellFrame.Visible = true
	Juice.Pop(sellFrame)
end)

-- Storage Unit
local storageFrame = panel(gui, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.5, 0), Size = UDim2.new(0, 860, 0, 540), Visible = false })
Icons.Make("Crate", { Position = UDim2.new(0, 18, 0, -4), Size = UDim2.new(0, 76, 0, 76) }).Parent = storageFrame
text(storageFrame, { Position = UDim2.new(0, 100, 0, 18), Size = UDim2.new(0, 300, 0, 44), Text = "STORAGE", TextXAlignment = Enum.TextXAlignment.Left, StrokeThickness = 3.5 })
local storageClose = button(storageFrame, { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 16, 0, -16), Size = UDim2.new(0, 60, 0, 60), Text = "X" }, BTN.Red)
local invTitle = inkText(storageFrame, { Position = UDim2.new(0, 30, 0, 78), Size = UDim2.new(0.5, -40, 0, 24), Text = "TOOLBAR", TextXAlignment = Enum.TextXAlignment.Left })
local storeTitle = inkText(storageFrame, { Position = UDim2.new(0.5, 10, 0, 78), Size = UDim2.new(0.5, -40, 0, 24), Text = "IN STORAGE", TextXAlignment = Enum.TextXAlignment.Left })
local invList = listFrame(storageFrame, { Position = UDim2.new(0, 28, 0, 108), Size = UDim2.new(0.5, -38, 1, -136) })
local storeList = listFrame(storageFrame, { Position = UDim2.new(0.5, 10, 0, 108), Size = UDim2.new(0.5, -38, 1, -136) })

local function refreshStorage()
	for _, list in ipairs({ invList, storeList }) do
		for _, c in ipairs(list:GetChildren()) do
			if c:IsA("GuiObject") then
				c:Destroy()
			end
		end
	end
	local inv, store = decode("Inventory"), decode("Storage")
	invTitle.Text = "TOOLBAR  " .. #inv .. "/" .. Config.InventorySize
	storeTitle.Text = "IN STORAGE  " .. #store .. "/" .. Config.StorageSize
	for i, car in ipairs(inv) do
		row(invList, i, car, nil, "STORE", BTN.Blue, function()
			local r = StorageAction:InvokeServer("Store", car.Uid)
			if r and r.Message then
				showNotification(r.Message, Color3.fromRGB(255, 130, 120))
			end
		end)
	end
	for i, car in ipairs(store) do
		row(storeList, i, car, nil, "TAKE", BTN.Green, function()
			local r = StorageAction:InvokeServer("Take", car.Slot)
			if r and r.Message then
				showNotification(r.Message, Color3.fromRGB(255, 130, 120))
			end
		end)
	end
	if #inv == 0 then
		emptyNote(invList, "Toolbar is empty.")
	end
	if #store == 0 then
		emptyNote(storeList, "Nothing stored yet.")
	end
end
storageClose.MouseButton1Click:Connect(function()
	storageFrame.Visible = false
end)
OpenStorageEvent.OnClientEvent:Connect(function()
	refreshStorage()
	storageFrame.Visible = true
	Juice.Pop(storageFrame)
end)
player:GetAttributeChangedSignal("Inventory"):Connect(function()
	if sellFrame.Visible then
		refreshSell()
	end
	if storageFrame.Visible then
		refreshStorage()
	end
end)
player:GetAttributeChangedSignal("Storage"):Connect(function()
	if storageFrame.Visible then
		refreshStorage()
	end
end)
-- walking away closes them
task.spawn(function()
	while true do
		task.wait(0.5)
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		if root and (sellFrame.Visible or storageFrame.Visible) then
			local idx = player:GetAttribute("PlotIndex")
			local plot = idx and workspace:FindFirstChild("Map") and workspace.Map:FindFirstChild("Plot" .. idx)
			local sellPart = plot and plot:FindFirstChild("SellCounter")
			local storagePart = plot and plot:FindFirstChild("StorageDoor")
			if sellFrame.Visible and sellPart and (sellPart.Position - root.Position).Magnitude > 24 then
				sellFrame.Visible = false
			end
			if storageFrame.Visible and storagePart and (storagePart.Position - root.Position).Magnitude > 24 then
				storageFrame.Visible = false
			end
		end
	end
end)

---------------------------------------------------------------------
-- Calm world: only the single closest label is shown (and only when you're near it), so the
-- screen never fills with floating text. Money pop-ups over customers always show.
---------------------------------------------------------------------
local worldLabels = {}
local function trackLabel(g)
	if g:IsA("BillboardGui") and g.Name ~= "PayPop" and g.Name ~= "IconBoard" and g.Enabled then
		worldLabels[g] = true
	end
end
task.spawn(function()
	local map = workspace:WaitForChild("Map", 30)
	if not map then
		return
	end
	for _, g in ipairs(map:GetDescendants()) do
		trackLabel(g)
	end
	map.DescendantAdded:Connect(trackLabel)
	map.DescendantRemoving:Connect(function(g)
		worldLabels[g] = nil
	end)
	while true do
		task.wait(0.15)
		if currentView == nil then
			local char = player.Character
			local root = char and char:FindFirstChild("HumanoidRootPart")
			-- labels are grouped by the part they hang on (a pad has a title and a level line)
			local bestParent, bestD = nil, 15
			if root then
				for g in pairs(worldLabels) do
					local parent = g.Adornee or g.Parent
					if parent and parent:IsA("BasePart") then
						local d = (parent.Position - root.Position).Magnitude
						if d < bestD then
							bestParent, bestD = parent, d
						end
					end
				end
			end
			for g in pairs(worldLabels) do
				if g.Parent then
					g.Enabled = (g.Adornee or g.Parent) == bestParent
				end
			end
		end
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

---------------------------------------------------------------------
-- Objective guide: one clear "next step" at the top + a glowing arrow over the target
---------------------------------------------------------------------
local goalPill = Instance.new("Frame")
goalPill.AnchorPoint = Vector2.new(0.5, 0)
goalPill.Position = UDim2.new(0.5, 0, 0, 82)
goalPill.Size = UDim2.new(0, 480, 0, 50)
goalPill.BackgroundTransparency = 1
goalPill.Parent = hud
slicedPill(goalPill, UI_ART.Bar).ZIndex = 0
local goalTag = Instance.new("TextLabel")
goalTag.BackgroundTransparency = 1
goalTag.Position = UDim2.new(0, 18, 0, 0)
goalTag.Size = UDim2.new(0, 80, 1, 0)
goalTag.Font = Enum.Font.FredokaOne
goalTag.TextSize = 20
goalTag.TextColor3 = GOLD
goalTag.Text = "NEXT"
goalTag.TextXAlignment = Enum.TextXAlignment.Left
goalTag.Parent = goalPill
local goalText = Instance.new("TextLabel")
goalText.BackgroundTransparency = 1
goalText.Position = UDim2.new(0, 78, 0, 0)
goalText.Size = UDim2.new(1, -96, 1, 0)
goalText.Font = Enum.Font.FredokaOne
goalText.TextSize = 22
goalText.TextColor3 = WHITE
goalText.TextXAlignment = Enum.TextXAlignment.Left
goalText.Text = ""
goalText.Parent = goalPill

-- the 3D arrow and the beam from the player to the target (only you see them)
local guide = Instance.new("Model")
guide.Name = "GuideArrow"
local function gpart(size, cf, shape)
	local q = Instance.new(shape and "Part" or "WedgePart")
	if shape then
		q.Shape = shape
	end
	q.Anchored = true
	q.CanCollide = false
	q.CanQuery = false
	q.CanTouch = false
	q.CastShadow = false
	q.Material = Enum.Material.Neon
	q.Color = Color3.fromRGB(255, 205, 60)
	q.Size = size
	q.CFrame = cf
	q.Parent = guide
	return q
end
local shaft = gpart(Vector3.new(0.9, 2.4, 0.9), CFrame.new(0, 2.2, 0), Enum.PartType.Block)
gpart(Vector3.new(0.9, 1.6, 1.4), CFrame.new(0, 0.2, 0.7) * CFrame.Angles(math.rad(180), 0, 0))
gpart(Vector3.new(0.9, 1.6, 1.4), CFrame.new(0, 0.2, -0.7) * CFrame.Angles(math.rad(180), math.rad(180), 0))
guide.PrimaryPart = shaft
local anchorPart = Instance.new("Part")
anchorPart.Anchored = true
anchorPart.CanCollide = false
anchorPart.CanQuery = false
anchorPart.Transparency = 1
anchorPart.Size = Vector3.new(0.2, 0.2, 0.2)
anchorPart.Parent = guide
local a1 = Instance.new("Attachment")
a1.Parent = anchorPart
local beam = Instance.new("Beam")
beam.Attachment1 = a1
beam.Width0 = 0.35
beam.Width1 = 0.35
beam.FaceCamera = true
beam.LightEmission = 1
beam.Color = ColorSequence.new(Color3.fromRGB(255, 215, 80))
beam.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.9), NumberSequenceKeypoint.new(0.3, 0.35), NumberSequenceKeypoint.new(1, 0.15) })
beam.Parent = anchorPart
local glow = Instance.new("PointLight")
glow.Color = Color3.fromRGB(255, 210, 80)
glow.Range = 10
glow.Parent = shaft

local function ownedModels(kind)
	local out = {}
	local folder = workspace:FindFirstChild("Map") and workspace.Map:FindFirstChild("Cars")
	if folder then
		for _, m in ipairs(folder:GetChildren()) do
			if m:GetAttribute("OwnerUserId") == player.UserId and m:GetAttribute("Kind") == kind then
				table.insert(out, m)
			end
		end
	end
	return out
end
local function nearest(list)
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	local best, bestD = nil, math.huge
	for _, m in ipairs(list) do
		local d = root and (m:GetPivot().Position - root.Position).Magnitude or 0
		if d < bestD then
			best, bestD = m, d
		end
	end
	return best
end

local function myPlot()
	local idx = player:GetAttribute("PlotIndex")
	local map = workspace:FindFirstChild("Map")
	return idx and map and map:FindFirstChild("Plot" .. idx)
end

-- the tutorial: one step at a time for the very first car. Afterwards there are no arrows at all.
local function currentGoal()
	local plot = myPlot()
	local showroom = plot and plot:FindFirstChild("Showroom")
	local door = showroom and showroom:FindFirstChild("DoorPrompt")
	if door and door:FindFirstChildOfClass("ProximityPrompt") then
		return "Open the garage door to make it yours", door.Position
	end
	if player:GetAttribute("WashProgress") ~= nil and currentView == "Wash" then
		return "Scrub the dust off, then press FINISH", nil
	end
	local lift = ownedModels("Lift")[1]
	if lift then
		return "Service your car in the Service bay", lift:GetPivot().Position
	end
	local washCar = ownedModels("WashCar")[1]
	if washCar then
		return "Walk to the wash spot and wash your car", washCar:GetPivot().Position
	end
	local car = nearest(ownedModels("Car"))
	if car then
		return "Send your car to the car wash", car:GetPivot().Position
	end
	if holding() then
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		local best, bestD = nil, math.huge
		for _, m in ipairs(CollectionService:GetTagged("SpotMarker")) do
			if m:GetAttribute("PlotIndex") == player:GetAttribute("PlotIndex") and not m:GetAttribute("Occupied") then
				local d = root and (m.Position - root.Position).Magnitude or 0
				if d < bestD then
					best, bestD = m, d
				end
			end
		end
		return "Put your car on the glowing spot in your garage", best and best.Position
	end
	if #inventory > 0 then
		return "Press 1 (or click your car below) to pick it up", nil
	end
	return "Wait for a customer to look at your car", nil
end

-- a bouncing arrow over the first toolbar card during that step of the tutorial
local cardArrow = text(hud, { AnchorPoint = Vector2.new(0.5, 1), Size = UDim2.new(0, 60, 0, 60), Text = "▼", TextColor3 = GOLD, StrokeThickness = 3, Visible = false })

RunService.RenderStepped:Connect(function()
	local tutorial = player:GetAttribute("Tutorial") == true
	local goal, target
	if tutorial then
		goal, target = currentGoal()
	end
	goalText.Text = goal or ""
	goalPill.Visible = tutorial and currentView == nil
	local firstCard = tutorial and not holding() and inventory[1] and cards[inventory[1].Uid]
	cardArrow.Visible = (firstCard and true or false) and currentView == nil
	if firstCard then
		local b = firstCard.Button
		local k = uiScale.Scale > 0 and uiScale.Scale or 1
		cardArrow.Position = UDim2.new(0, (b.AbsolutePosition.X - hud.AbsolutePosition.X + b.AbsoluteSize.X / 2) / k, 0, (b.AbsolutePosition.Y - hud.AbsolutePosition.Y) / k - 4 + math.sin(os.clock() * 6) * 6)
	end
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	local show = tutorial and target ~= nil and currentView == nil and root ~= nil and (target - root.Position).Magnitude > 9
	if show then
		local t = os.clock()
		guide.Parent = workspace
		guide:PivotTo(CFrame.new(target + Vector3.new(0, 9.5 + math.sin(t * 3) * 0.6, 0)) * CFrame.Angles(0, t * 1.5, 0))
		anchorPart.CFrame = CFrame.new(target + Vector3.new(0, 1, 0))
		local a0 = root:FindFirstChild("GuideA0")
		if not a0 then
			a0 = Instance.new("Attachment")
			a0.Name = "GuideA0"
			a0.Position = Vector3.new(0, -2.5, 0)
			a0.Parent = root
		end
		beam.Attachment0 = a0
	else
		guide.Parent = nil
	end
end)

task.delay(2, function()
	if player:GetAttribute("Tutorial") then
		showNotification("Welcome to D2D! Follow the golden arrow.", GOLD)
	end
end)

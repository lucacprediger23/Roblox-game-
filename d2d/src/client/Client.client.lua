-- D2D client: HUD, truck timer, scrubbing, engine screen, Index and messages.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local CollectionService = game:GetService("CollectionService")

local player = Players.LocalPlayer
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local CarBuilder = require(Shared:WaitForChild("CarBuilder"))
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local NotifyEvent = remotes:WaitForChild("Notify")
local ScrubEvent = remotes:WaitForChild("Scrub")
local RevealEvent = remotes:WaitForChild("Reveal")
local OpenEngineEvent = remotes:WaitForChild("OpenEngine")
local GoHomeEvent = remotes:WaitForChild("GoHome")
local EngineAction = remotes:WaitForChild("EngineAction")
local ClaimToken = remotes:WaitForChild("ClaimToken")

---------------------------------------------------------------------
-- UI helpers (comic-garage style: chunky, dark plates, bold outlines)
---------------------------------------------------------------------
local DARK = Color3.fromRGB(28, 30, 38)
local YELLOW = Color3.fromRGB(255, 205, 40)
local WHITE = Color3.new(1, 1, 1)

local function corner(p, r)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, r or 12)
	c.Parent = p
end
local function stroke(p, color, t)
	local s = Instance.new("UIStroke")
	s.Color = color or Color3.new(0, 0, 0)
	s.Thickness = t or 3
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.Parent = p
end
local function text(parent, props)
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Font = Enum.Font.FredokaOne
	l.TextColor3 = WHITE
	l.TextScaled = true
	l.TextStrokeTransparency = 0.3
	for k, v in pairs(props) do
		l[k] = v
	end
	l.Parent = parent
	return l
end
local SoundService = game:GetService("SoundService")
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
-- sound ids: fill these in with sounds from the Creator Store (Toolbox > Audio) that the game is allowed to use
local SOUND_CLICK = ""
local SOUND_PING = ""
local SOUND_SWOOSH = ""

-- glossy shine: lighter at the top, darker at the bottom
local function shine(p, amount)
	local g = Instance.new("UIGradient")
	local a = amount or 0.25
	g.Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.new(1 - a, 1 - a, 1 - a))
	g.Rotation = 90
	g.Parent = p
end

local function button(parent, props)
	local b = Instance.new("TextButton")
	b.Font = Enum.Font.FredokaOne
	b.TextColor3 = WHITE
	b.TextScaled = true
	b.TextStrokeTransparency = 0.4
	b.AutoButtonColor = true
	for k, v in pairs(props) do
		b[k] = v
	end
	corner(b, 12)
	stroke(b, Color3.new(0, 0, 0), 3)
	local pad = Instance.new("UIPadding")
	pad.PaddingTop = UDim.new(0, 5)
	pad.PaddingBottom = UDim.new(0, 5)
	pad.PaddingLeft = UDim.new(0, 8)
	pad.PaddingRight = UDim.new(0, 8)
	pad.Parent = b
	shine(b, 0.3)
	-- juicy feel: grow on hover, squish on press, click sound
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
	b.Parent = parent
	return b
end
local function panel(parent, props)
	local f = Instance.new("Frame")
	f.BackgroundColor3 = DARK
	f.BorderSizePixel = 0
	for k, v in pairs(props) do
		f[k] = v
	end
	corner(f, 16)
	stroke(f, YELLOW, 4)
	shine(f, 0.35)
	f.Parent = parent
	return f
end

local gui = Instance.new("ScreenGui")
gui.Name = "D2D"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = player:WaitForChild("PlayerGui")

---------------------------------------------------------------------
-- HUD
---------------------------------------------------------------------
local cashBox = panel(gui, { AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 12, 1, -62), Size = UDim2.new(0, 260, 0, 54) })
local cashLabel = text(cashBox, { Position = UDim2.new(0, 10, 0, 4), Size = UDim2.new(1, -20, 1, -8), Text = "$0", TextColor3 = Color3.fromRGB(120, 255, 130), TextXAlignment = Enum.TextXAlignment.Left })
local tokenBox = panel(gui, { AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 12, 1, -12), Size = UDim2.new(0, 170, 0, 40) })
local tokenLabel = text(tokenBox, { Position = UDim2.new(0, 10, 0, 4), Size = UDim2.new(1, -20, 1, -8), Text = "Tokens: 0", TextColor3 = YELLOW, TextXAlignment = Enum.TextXAlignment.Left })
local incomeLabel = text(gui, { Position = UDim2.new(0, 16, 1, -150), Size = UDim2.new(0, 220, 0, 24), Text = "$0/s", TextColor3 = Color3.fromRGB(180, 255, 180), TextXAlignment = Enum.TextXAlignment.Left })

local timerBox = panel(gui, { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 12), Size = UDim2.new(0, 300, 0, 64) })
text(timerBox, { Position = UDim2.new(0, 0, 0, 4), Size = UDim2.new(1, 0, 0.38, 0), Text = "TRUCK ARRIVING", TextColor3 = YELLOW })
local timerLabel = text(timerBox, { Position = UDim2.new(0, 0, 0.4, 0), Size = UDim2.new(1, 0, 0.55, 0), Text = "--:--" })

local leftColumn = Instance.new("Frame")
leftColumn.BackgroundTransparency = 1
leftColumn.Position = UDim2.new(0, 12, 0.5, -70)
leftColumn.Size = UDim2.new(0, 120, 0, 150)
leftColumn.Parent = gui
local list = Instance.new("UIListLayout")
list.Padding = UDim.new(0, 10)
list.Parent = leftColumn
local indexButton = button(leftColumn, { Size = UDim2.new(1, 0, 0, 64), Text = "INDEX", BackgroundColor3 = Color3.fromRGB(60, 120, 230) })
local homeButton = button(leftColumn, { Size = UDim2.new(1, 0, 0, 64), Text = "HOME", BackgroundColor3 = Color3.fromRGB(230, 120, 40) })
local indexDot = Instance.new("Frame")
indexDot.Size = UDim2.new(0, 18, 0, 18)
indexDot.Position = UDim2.new(1, -10, 0, -6)
indexDot.BackgroundColor3 = Color3.fromRGB(255, 50, 50)
indexDot.Visible = false
corner(indexDot, 9)
indexDot.Parent = indexButton

homeButton.MouseButton1Click:Connect(function()
	GoHomeEvent:FireServer()
end)

-- cash counter with a floating "+$X"
local lastCash = 0
local function floatGain(amount)
	local l = text(gui, { Position = UDim2.new(0, 280, 1, -110), Size = UDim2.new(0, 200, 0, 34), Text = "+$" .. Config.FormatNumber(amount), TextColor3 = Color3.fromRGB(120, 255, 130), TextXAlignment = Enum.TextXAlignment.Left })
	local tw = TweenService:Create(l, TweenInfo.new(1.2), { Position = UDim2.new(0, 280, 1, -150), TextTransparency = 1, TextStrokeTransparency = 1 })
	tw:Play()
	tw.Completed:Connect(function()
		l:Destroy()
	end)
end
task.spawn(function()
	local ls = player:WaitForChild("leaderstats")
	local cash = ls:WaitForChild("Cash")
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

local function unclaimedCount()
	local claimed = {}
	for id in string.gmatch(player:GetAttribute("Claimed") or "", "[^,]+") do
		claimed[id] = true
	end
	local n = 0
	for id in string.gmatch(player:GetAttribute("Discovered") or "", "[^,]+") do
		if not claimed[id] then
			n = n + 1
		end
	end
	return n
end

local function refreshTokens()
	tokenLabel.Text = "Tokens: " .. (player:GetAttribute("Tokens") or 0)
	indexDot.Visible = unclaimedCount() > 0
end
player:GetAttributeChangedSignal("Tokens"):Connect(refreshTokens)
player:GetAttributeChangedSignal("Claimed"):Connect(refreshTokens)
player:GetAttributeChangedSignal("Discovered"):Connect(refreshTokens)
refreshTokens()

RunService.Heartbeat:Connect(function()
	local nextAt = player:GetAttribute("NextDelivery")
	if player:GetAttribute("YardFull") then
		timerLabel.Text = "YARD FULL!"
	elseif nextAt then
		timerLabel.Text = Config.FormatTime(nextAt - workspace:GetServerTimeNow())
	end
	incomeLabel.Text = "$" .. Config.FormatNumber(player:GetAttribute("IncomeRate") or 0) .. "/s"
end)

---------------------------------------------------------------------
-- Messages
---------------------------------------------------------------------
local notifyList = Instance.new("Frame")
notifyList.BackgroundTransparency = 1
notifyList.AnchorPoint = Vector2.new(0.5, 0)
notifyList.Position = UDim2.new(0.5, 0, 0, 84)
notifyList.Size = UDim2.new(0, 620, 0, 200)
notifyList.Parent = gui
local nl = Instance.new("UIListLayout")
nl.Padding = UDim.new(0, 4)
nl.HorizontalAlignment = Enum.HorizontalAlignment.Center
nl.SortOrder = Enum.SortOrder.LayoutOrder
nl.Parent = notifyList
local notifyCount = 0
local function showNotification(message, color)
	notifyCount = notifyCount + 1
	local l = text(notifyList, { Size = UDim2.new(1, 0, 0, 30), Text = message, TextColor3 = color or WHITE, TextStrokeTransparency = 0, LayoutOrder = notifyCount })
	local labels = {}
	for _, c in ipairs(notifyList:GetChildren()) do
		if c:IsA("TextLabel") then
			table.insert(labels, c)
		end
	end
	if #labels > 5 then
		table.sort(labels, function(a, b)
			return a.LayoutOrder < b.LayoutOrder
		end)
		labels[1]:Destroy()
	end
	task.delay(4, function()
		if l.Parent then
			local tw = TweenService:Create(l, TweenInfo.new(0.5), { TextTransparency = 1, TextStrokeTransparency = 1 })
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
	f.Position = UDim2.new(0.5, 0, 0.42, 0)
	f.Size = UDim2.new(0, 640, 0, 190)
	f.Parent = gui
	text(f, { Size = UDim2.new(1, 0, 0.32, 0), Text = isNew and "NEW CAR!" or "YOU GOT", TextColor3 = YELLOW, TextStrokeTransparency = 0 })
	text(f, { Position = UDim2.new(0, 0, 0.32, 0), Size = UDim2.new(1, 0, 0.4, 0), Text = car.Name, TextColor3 = rarity.Color, TextStrokeTransparency = 0 })
	text(f, { Position = UDim2.new(0, 0, 0.72, 0), Size = UDim2.new(1, 0, 0.26, 0), Text = string.upper(rarity.Name) .. "  ·  " .. Config.GetOddsText(carId), TextStrokeTransparency = 0 })
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
-- Washing: progress bar and scrubbing
---------------------------------------------------------------------
local washBox = panel(gui, { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -24), Size = UDim2.new(0, 420, 0, 70), Visible = false })
local washFill = Instance.new("Frame")
washFill.BackgroundColor3 = Color3.fromRGB(70, 190, 255)
washFill.BorderSizePixel = 0
washFill.Position = UDim2.new(0, 8, 0, 8)
washFill.Size = UDim2.new(0, 0, 0, 30)
corner(washFill, 8)
washFill.Parent = washBox
local washText = text(washBox, { Position = UDim2.new(0, 8, 0, 8), Size = UDim2.new(1, -16, 0, 30), Text = "0% CLEAN", ZIndex = 2 })
text(washBox, { Position = UDim2.new(0, 8, 0, 42), Size = UDim2.new(1, -16, 0, 22), Text = "Hold the mouse over the dirt and drag", TextColor3 = Color3.fromRGB(200, 200, 210) })

local function refreshWash()
	local p = player:GetAttribute("WashProgress")
	washBox.Visible = p ~= nil
	if p then
		washFill.Size = UDim2.new(0, math.floor((420 - 16) * p), 0, 30)
		washText.Text = math.floor(p * 100) .. "% CLEAN"
	end
end
player:GetAttributeChangedSignal("WashProgress"):Connect(refreshWash)
refreshWash()

local GuiService = game:GetService("GuiService")
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

-- true when one of our solid panels or buttons is under this screen point
local function overOurGui(x, y)
	local inset = GuiService:GetGuiInset()
	for _, obj in ipairs(player.PlayerGui:GetGuiObjectsAtPosition(x, y - inset.Y)) do
		if obj:IsDescendantOf(gui) and obj.Visible and (obj:IsA("GuiButton") or obj.BackgroundTransparency < 1) then
			return true
		end
	end
	return false
end

-- returns the screen point (with the top bar inset included) being scrubbed, or nil
local function scrubPoint()
	if touchHolding then
		local inset = GuiService:GetGuiInset()
		return Vector2.new(touchPos.X, touchPos.Y + inset.Y)
	end
	if UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) then
		local m = UserInputService:GetMouseLocation()
		if not overOurGui(m.X, m.Y) then
			return m
		end
	end
	return nil
end

local function bubbles(position)
	for _ = 1, 3 do
		local b = Instance.new("Part")
		b.Shape = Enum.PartType.Ball
		b.Size = Vector3.new(0.5, 0.5, 0.5)
		b.Material = Enum.Material.Glass
		b.Transparency = 0.3
		b.Color = Color3.fromRGB(220, 240, 255)
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
	if player:GetAttribute("WashProgress") == nil then
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
	local camera = workspace.CurrentCamera
	local ray = camera:ViewportPointToRay(point.X, point.Y)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { dirt }
	local result = workspace:Raycast(ray.Origin, ray.Direction * 200, params)
	if result then
		lastSent = t
		ScrubEvent:FireServer(result.Position)
		bubbles(result.Position)
	end
end)

---------------------------------------------------------------------
-- Engine screen
---------------------------------------------------------------------
local engineFrame = panel(gui, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.5, 0), Size = UDim2.new(0, 640, 0, 420), Visible = false })
local engineTitle = text(engineFrame, { Position = UDim2.new(0, 16, 0, 10), Size = UDim2.new(1, -80, 0, 40), Text = "Choose your engine", TextColor3 = YELLOW })
local engineCar = text(engineFrame, { Position = UDim2.new(0, 16, 0, 52), Size = UDim2.new(0.5, -16, 0, 30), Text = "" })
local engineValue = text(engineFrame, { Position = UDim2.new(0, 16, 0, 86), Size = UDim2.new(0.5, -16, 0, 40), Text = "$0/s -> ?", TextColor3 = Color3.fromRGB(120, 255, 130) })
local engineCurrent = text(engineFrame, { Position = UDim2.new(0, 16, 0, 130), Size = UDim2.new(0.5, -16, 0, 34), Text = "No engine yet" })
text(engineFrame, { Position = UDim2.new(0.5, 10, 0, 52), Size = UDim2.new(0.5, -26, 0, 28), Text = "ENGINE CHANCES", TextColor3 = YELLOW })
local chanceRows = {}
for i, engine in ipairs(Config.Engines) do
	local row = text(engineFrame, { Position = UDim2.new(0.5, 10, 0, 84 + (i - 1) * 30), Size = UDim2.new(0.5, -26, 0, 26), Text = engine.Name, TextColor3 = engine.Color:Lerp(WHITE, 0.3), TextXAlignment = Enum.TextXAlignment.Left })
	chanceRows[i] = row
end
local rollButton = button(engineFrame, { Position = UDim2.new(0, 16, 1, -130), Size = UDim2.new(0.5, -24, 0, 54), Text = "ROLL ENGINE (E)", BackgroundColor3 = Color3.fromRGB(240, 140, 30) })
local luckyButton = button(engineFrame, { Position = UDim2.new(0.5, 8, 1, -130), Size = UDim2.new(0.5, -24, 0, 54), Text = "LUCKY ROLL (1 token)", BackgroundColor3 = Color3.fromRGB(170, 80, 230) })
local doneButton = button(engineFrame, { Position = UDim2.new(0, 16, 1, -68), Size = UDim2.new(0.5, -24, 0, 54), Text = "DONE - DISPLAY (Q)", BackgroundColor3 = Color3.fromRGB(60, 190, 90) })
local sellButton = button(engineFrame, { Position = UDim2.new(0.5, 8, 1, -68), Size = UDim2.new(0.5, -24, 0, 54), Text = "SELL", BackgroundColor3 = Color3.fromRGB(200, 60, 60) })
local closeButton = button(engineFrame, { Position = UDim2.new(1, -56, 0, 10), Size = UDim2.new(0, 44, 0, 44), Text = "X", BackgroundColor3 = Color3.fromRGB(200, 60, 60) })

local engineCarId, engineIndex = nil, nil
local busy = false

local function refreshEngineScreen()
	if not engineCarId then
		return
	end
	local car = Config.CarsById[engineCarId]
	local base = Config.GetCarIncome(engineCarId, 1)
	engineCar.Text = car.Name
	engineCar.TextColor3 = Config.Rarities[car.Rarity].Color
	if engineIndex then
		local e = Config.Engines[engineIndex]
		engineValue.Text = "$" .. Config.FormatNumber(base) .. "/s -> $" .. Config.FormatNumber(Config.GetCarIncome(engineCarId, engineIndex)) .. "/s"
		engineCurrent.Text = "Engine: " .. e.Name .. "  (x" .. e.Mult .. ")"
		engineCurrent.TextColor3 = e.Color:Lerp(WHITE, 0.3)
		sellButton.Text = "SELL $" .. Config.FormatNumber(Config.GetCarIncome(engineCarId, engineIndex) * Config.SellSeconds)
	else
		engineValue.Text = "$" .. Config.FormatNumber(base) .. "/s -> ?"
		engineCurrent.Text = "No engine yet - roll one!"
		engineCurrent.TextColor3 = WHITE
		sellButton.Text = "SELL $" .. Config.FormatNumber(base * Config.SellSeconds)
	end
	local chances = Config.GetEngineChances(player:GetAttribute("EngineLuck") or 0, false)
	for i, row in ipairs(chanceRows) do
		row.Text = string.format("%s   %.2f%%", Config.Engines[i].Name, chances[i])
	end
	luckyButton.Text = "LUCKY ROLL (1 of " .. (player:GetAttribute("Tokens") or 0) .. " tokens)"
end

OpenEngineEvent.OnClientEvent:Connect(function(carId, current)
	engineCarId, engineIndex = carId, current
	if not engineFrame.Visible then
		playSound(SOUND_SWOOSH, 0.5)
	end
	engineFrame.Visible = true
	refreshEngineScreen()
end)

local function doAction(action)
	if busy or not engineCarId then
		return
	end
	busy = true
	if action == "Roll" or action == "Lucky" then
		-- short spin through engine names while the server rolls
		for _ = 1, 8 do
			local i = math.random(1, #Config.Engines)
			engineCurrent.Text = Config.Engines[i].Name .. "..."
			engineCurrent.TextColor3 = Config.Engines[i].Color
			task.wait(0.07)
		end
	end
	local result = EngineAction:InvokeServer(action)
	if result and result.Ok then
		if result.Done then
			engineFrame.Visible = false
			engineCarId, engineIndex = nil, nil
		elseif result.Engine then
			engineIndex = result.Engine
			refreshEngineScreen()
			local e = Config.Engines[engineIndex]
			showNotification("You got: " .. e.Name .. "!", e.Color:Lerp(WHITE, 0.3))
		end
	elseif result and result.Message then
		showNotification(result.Message, Color3.fromRGB(255, 120, 120))
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
closeButton.MouseButton1Click:Connect(function()
	engineFrame.Visible = false
end)
UserInputService.InputBegan:Connect(function(input, processed)
	if processed or not engineFrame.Visible then
		return
	end
	if input.KeyCode == Enum.KeyCode.E then
		doAction("Roll")
	elseif input.KeyCode == Enum.KeyCode.Q then
		doAction("Done")
	end
end)
player:GetAttributeChangedSignal("Tokens"):Connect(refreshEngineScreen)

---------------------------------------------------------------------
-- Index (collection book)
---------------------------------------------------------------------
local indexFrame = panel(gui, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.5, 0), Size = UDim2.new(0, 860, 0, 540), Visible = false })
text(indexFrame, { Position = UDim2.new(0, 20, 0, 10), Size = UDim2.new(0, 300, 0, 50), Text = "CAR INDEX", TextColor3 = YELLOW, TextXAlignment = Enum.TextXAlignment.Left })
local indexTotal = text(indexFrame, { Position = UDim2.new(0, 330, 0, 18), Size = UDim2.new(0, 400, 0, 34), Text = "" })
local indexClose = button(indexFrame, { Position = UDim2.new(1, -60, 0, 12), Size = UDim2.new(0, 46, 0, 46), Text = "X", BackgroundColor3 = Color3.fromRGB(200, 60, 60) })
local containerList = Instance.new("ScrollingFrame")
containerList.BackgroundTransparency = 1
containerList.Position = UDim2.new(0, 16, 0, 70)
containerList.Size = UDim2.new(0, 200, 1, -86)
containerList.CanvasSize = UDim2.new(0, 0, 0, #Config.Containers * 52)
containerList.ScrollBarThickness = 6
containerList.Parent = indexFrame
local cl = Instance.new("UIListLayout")
cl.Padding = UDim.new(0, 6)
cl.Parent = containerList
local headerLabel = text(indexFrame, { Position = UDim2.new(0, 232, 0, 68), Size = UDim2.new(1, -250, 0, 30), Text = "", TextColor3 = YELLOW, TextXAlignment = Enum.TextXAlignment.Left })
local grid = Instance.new("Frame")
grid.BackgroundTransparency = 1
grid.Position = UDim2.new(0, 232, 0, 104)
grid.Size = UDim2.new(1, -250, 1, -120)
grid.Parent = indexFrame
local gl = Instance.new("UIGridLayout")
gl.CellSize = UDim2.new(0.25, -8, 0.333, -8)
gl.CellPadding = UDim2.new(0, 8, 0, 8)
gl.SortOrder = Enum.SortOrder.LayoutOrder
gl.Parent = grid

local selectedContainer = 1
local containerButtons = {}

local function discoveredSet()
	local d, c = {}, {}
	for id in string.gmatch(player:GetAttribute("Discovered") or "", "[^,]+") do
		d[id] = true
	end
	for id in string.gmatch(player:GetAttribute("Claimed") or "", "[^,]+") do
		c[id] = true
	end
	return d, c
end

local function makeCard(carId, discovered, claimed, order)
	local car = Config.CarsById[carId]
	local rarity = Config.Rarities[car.Rarity]
	local card = Instance.new("Frame")
	card.BackgroundColor3 = Color3.fromRGB(45, 48, 60)
	card.LayoutOrder = order
	corner(card, 10)
	stroke(card, discovered and rarity.Color or Color3.fromRGB(70, 70, 80), 3)
	card.Parent = grid
	local vp = Instance.new("ViewportFrame")
	vp.BackgroundTransparency = 1
	vp.Size = UDim2.new(1, 0, 0.55, 0)
	vp.Parent = card
	local model = CarBuilder.BuildCar(carId, { Silhouette = not discovered })
	model:PivotTo(CFrame.new(0, 0, 0) * CFrame.Angles(0, math.rad(35), 0))
	model.Parent = vp
	local cam = Instance.new("Camera")
	local _, size = model:GetBoundingBox()
	cam.FieldOfView = 30
	local dist = math.max(size.X, size.Z) * 1.55 + 2
	cam.CFrame = CFrame.lookAt(Vector3.new(dist * 0.55, dist * 0.4, -dist * 0.75), Vector3.new(0, size.Y * 0.4, 0))
	cam.Parent = vp
	vp.CurrentCamera = cam
	text(card, { Position = UDim2.new(0, 4, 0.55, 0), Size = UDim2.new(1, -8, 0.15, 0), Text = discovered and car.Name or "???", TextColor3 = discovered and rarity.Color or Color3.fromRGB(150, 150, 160) })
	text(card, { Position = UDim2.new(0, 4, 0.70, 0), Size = UDim2.new(1, -8, 0.12, 0), Text = rarity.Name .. " · " .. Config.GetOddsText(carId), TextColor3 = Color3.fromRGB(210, 210, 220) })
	if discovered and not claimed then
		local b = button(card, { Position = UDim2.new(0, 6, 0.83, 0), Size = UDim2.new(1, -12, 0.15, 0), Text = "COLLECT TOKEN", BackgroundColor3 = YELLOW, TextColor3 = Color3.new(0, 0, 0) })
		b.MouseButton1Click:Connect(function()
			b.Active = false
			if ClaimToken:InvokeServer(carId) then
				showNotification("+1 token!", YELLOW)
			end
		end)
	else
		text(card, { Position = UDim2.new(0, 4, 0.84, 0), Size = UDim2.new(1, -8, 0.13, 0), Text = "$" .. Config.FormatNumber(car.BaseIncome) .. "/s", TextColor3 = Color3.fromRGB(120, 255, 130) })
	end
end

local function refreshIndex()
	if not indexFrame.Visible then
		return
	end
	local discovered, claimed = discoveredSet()
	local total = 0
	for _ in pairs(discovered) do
		total = total + 1
	end
	indexTotal.Text = total .. " / " .. #Config.Cars .. " discovered · Tokens: " .. (player:GetAttribute("Tokens") or 0)
	for c, b in ipairs(containerButtons) do
		local n = 0
		for _, id in ipairs(Config.Containers[c].CarIds) do
			if discovered[id] then
				n = n + 1
			end
		end
		b.Text = "Container " .. c .. "  " .. n .. "/12"
		b.BackgroundColor3 = (c == selectedContainer) and Color3.fromRGB(90, 200, 100) or Color3.fromRGB(70, 74, 90)
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
	headerLabel.Text = "CONTAINER " .. selectedContainer .. ": " .. string.upper(container.Name) .. (found == 12 and "  ·  COMPLETE: +5% income" or "  ·  complete it for +5% income")
end

for c = 1, #Config.Containers do
	local b = button(containerList, { Size = UDim2.new(1, -10, 0, 46), Text = "Container " .. c, BackgroundColor3 = Color3.fromRGB(70, 74, 90), LayoutOrder = c })
	b.MouseButton1Click:Connect(function()
		selectedContainer = c
		refreshIndex()
	end)
	containerButtons[c] = b
end

indexButton.MouseButton1Click:Connect(function()
	indexFrame.Visible = not indexFrame.Visible
	playSound(SOUND_SWOOSH, 0.5)
	refreshIndex()
end)
indexClose.MouseButton1Click:Connect(function()
	indexFrame.Visible = false
end)
player:GetAttributeChangedSignal("Claimed"):Connect(refreshIndex)
player:GetAttributeChangedSignal("Discovered"):Connect(refreshIndex)

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

task.delay(2, function()
	showNotification("Welcome to D2D! Your first container is landing in your backyard.", YELLOW)
end)

-- HUD: the player's screen (coins, speed upgrade, base lock, messages)
-- plus little client-side effects: bouncing squishies and rainbow colours.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local CollectionService = game:GetService("CollectionService")

local player = Players.LocalPlayer
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local NotifyEvent = remotes:WaitForChild("Notify")
local BuySpeedFunction = remotes:WaitForChild("BuySpeed")
local LockBaseFunction = remotes:WaitForChild("LockBase")

---------------------------------------------------------------------
-- UI helpers
---------------------------------------------------------------------
local PINK = Color3.fromRGB(255, 120, 170)
local DARK = Color3.fromRGB(45, 30, 60)

local function corner(parent, radius)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius or 12)
	c.Parent = parent
	return c
end

local function stroke(parent, color, thickness)
	local s = Instance.new("UIStroke")
	s.Color = color or Color3.new(1, 1, 1)
	s.Thickness = thickness or 3
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.Parent = parent
	return s
end

local function label(parent, props)
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Font = Enum.Font.FredokaOne
	l.TextColor3 = Color3.new(1, 1, 1)
	l.TextScaled = true
	l.TextStrokeTransparency = 0.4
	for key, value in pairs(props) do
		l[key] = value
	end
	l.Parent = parent
	return l
end

local function button(parent, props)
	local b = Instance.new("TextButton")
	b.Font = Enum.Font.FredokaOne
	b.TextColor3 = Color3.new(1, 1, 1)
	b.TextScaled = true
	b.AutoButtonColor = true
	b.TextStrokeTransparency = 0.5
	for key, value in pairs(props) do
		b[key] = value
	end
	corner(b, 14)
	stroke(b, Color3.new(1, 1, 1), 3)
	local pad = Instance.new("UIPadding")
	pad.PaddingTop = UDim.new(0, 6)
	pad.PaddingBottom = UDim.new(0, 6)
	pad.PaddingLeft = UDim.new(0, 8)
	pad.PaddingRight = UDim.new(0, 8)
	pad.Parent = b
	b.Parent = parent
	return b
end

---------------------------------------------------------------------
-- Build the screen
---------------------------------------------------------------------
local gui = Instance.new("ScreenGui")
gui.Name = "HUD"
gui.ResetOnSpawn = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = player:WaitForChild("PlayerGui")

-- Coins (top centre)
local coinFrame = Instance.new("Frame")
coinFrame.AnchorPoint = Vector2.new(0.5, 0)
coinFrame.Position = UDim2.new(0.5, 0, 0, 8)
coinFrame.Size = UDim2.new(0, 220, 0, 52)
coinFrame.BackgroundColor3 = DARK
coinFrame.BackgroundTransparency = 0.15
coinFrame.Parent = gui
corner(coinFrame, 16)
stroke(coinFrame, Color3.fromRGB(255, 220, 90), 3)
local coinLabel = label(coinFrame, {
	Size = UDim2.new(1, -16, 1, -10),
	Position = UDim2.new(0, 8, 0, 5),
	Text = "$0",
	TextColor3 = Color3.fromRGB(255, 225, 90),
})

-- Carrying banner (under the coins)
local carryLabel = label(gui, {
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 66),
	Size = UDim2.new(0, 420, 0, 34),
	Text = "",
	Visible = false,
	TextColor3 = Color3.fromRGB(255, 240, 150),
	TextStrokeTransparency = 0,
})

-- Buttons (bottom left)
local buttonColumn = Instance.new("Frame")
buttonColumn.BackgroundTransparency = 1
buttonColumn.AnchorPoint = Vector2.new(0, 1)
buttonColumn.Position = UDim2.new(0, 12, 1, -12)
buttonColumn.Size = UDim2.new(0, 230, 0, 140)
buttonColumn.Parent = gui
local layout = Instance.new("UIListLayout")
layout.Padding = UDim.new(0, 10)
layout.VerticalAlignment = Enum.VerticalAlignment.Bottom
layout.Parent = buttonColumn

local speedButton = button(buttonColumn, {
	Size = UDim2.new(1, 0, 0, 60),
	BackgroundColor3 = Color3.fromRGB(80, 170, 255),
	Text = "Speed",
	LayoutOrder = 1,
})
local lockButton = button(buttonColumn, {
	Size = UDim2.new(1, 0, 0, 60),
	BackgroundColor3 = PINK,
	Text = "Lock Base",
	LayoutOrder = 2,
})

-- Notifications (stack under the carry banner)
local notifyList = Instance.new("Frame")
notifyList.BackgroundTransparency = 1
notifyList.AnchorPoint = Vector2.new(0.5, 0)
notifyList.Position = UDim2.new(0.5, 0, 0, 104)
notifyList.Size = UDim2.new(0, 520, 0, 200)
notifyList.Parent = gui
local notifyLayout = Instance.new("UIListLayout")
notifyLayout.Padding = UDim.new(0, 4)
notifyLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
notifyLayout.SortOrder = Enum.SortOrder.LayoutOrder
notifyLayout.Parent = notifyList

local notifyCount = 0
local function showNotification(text, color)
	notifyCount = notifyCount + 1
	local l = label(notifyList, {
		Size = UDim2.new(1, 0, 0, 30),
		Text = text,
		TextColor3 = color or Color3.new(1, 1, 1),
		TextStrokeTransparency = 0,
		LayoutOrder = notifyCount,
	})
	-- keep at most 5 messages
	local children = {}
	for _, child in ipairs(notifyList:GetChildren()) do
		if child:IsA("TextLabel") then
			table.insert(children, child)
		end
	end
	if #children > 5 then
		table.sort(children, function(a, b)
			return a.LayoutOrder < b.LayoutOrder
		end)
		children[1]:Destroy()
	end
	task.delay(3.5, function()
		if l.Parent then
			local tween = TweenService:Create(l, TweenInfo.new(0.5), { TextTransparency = 1, TextStrokeTransparency = 1 })
			tween:Play()
			tween.Completed:Wait()
			l:Destroy()
		end
	end)
end
NotifyEvent.OnClientEvent:Connect(showNotification)

-- How to play (shown once when you join)
local help = Instance.new("Frame")
help.AnchorPoint = Vector2.new(0.5, 0.5)
help.Position = UDim2.new(0.5, 0, 0.5, 0)
help.Size = UDim2.new(0, 420, 0, 300)
help.BackgroundColor3 = DARK
help.BackgroundTransparency = 0.05
help.Parent = gui
corner(help, 20)
stroke(help, PINK, 4)
label(help, {
	Size = UDim2.new(1, -20, 0, 44),
	Position = UDim2.new(0, 10, 0, 10),
	Text = Config.GameName,
	TextColor3 = PINK,
})
label(help, {
	Size = UDim2.new(1, -30, 0, 170),
	Position = UDim2.new(0, 15, 0, 60),
	TextScaled = false,
	TextSize = 18,
	TextWrapped = true,
	TextXAlignment = Enum.TextXAlignment.Left,
	TextYAlignment = Enum.TextYAlignment.Top,
	Font = Enum.Font.GothamBold,
	Text = "1. Run into the egg field and grab an egg.\n"
		.. "2. Bring it back to your base - watch out for the guardians!\n"
		.. "3. Eggs hatch into squishies that make money.\n"
		.. "4. Step on the green pad to collect your coins.\n"
		.. "5. Buy speed to reach the rare eggs far away.\n"
		.. "6. Steal squishies from other bases... and lock yours!",
})
local closeHelp = button(help, {
	AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.new(0.5, 0, 1, -14),
	Size = UDim2.new(0, 160, 0, 46),
	BackgroundColor3 = Color3.fromRGB(90, 210, 120),
	Text = "Let's go!",
})
closeHelp.MouseButton1Click:Connect(function()
	help.Visible = false
end)

---------------------------------------------------------------------
-- Live updates
---------------------------------------------------------------------
local function updateCoins()
	local leaderstats = player:FindFirstChild("leaderstats")
	local coins = leaderstats and leaderstats:FindFirstChild("Coins")
	if coins then
		coinLabel.Text = "$" .. Config.FormatNumber(coins.Value)
	end
end

local function updateSpeedButton()
	local level = player:GetAttribute("SpeedLevel") or 0
	if level >= Config.MaxSpeedLevel then
		speedButton.Text = "Speed MAX"
	else
		speedButton.Text = "Speed Lv " .. level .. "  ($" .. Config.FormatNumber(Config.GetSpeedCost(level)) .. ")"
	end
end

local function updateCarry()
	local carryingWhat = player:GetAttribute("Carrying")
	if carryingWhat then
		carryLabel.Text = "Carrying " .. carryingWhat .. "  - run home!"
		carryLabel.Visible = true
	else
		carryLabel.Visible = false
	end
end

task.spawn(function()
	local leaderstats = player:WaitForChild("leaderstats")
	local coins = leaderstats:WaitForChild("Coins")
	coins.Changed:Connect(updateCoins)
	updateCoins()
end)
player:GetAttributeChangedSignal("SpeedLevel"):Connect(updateSpeedButton)
player:GetAttributeChangedSignal("Carrying"):Connect(updateCarry)
updateSpeedButton()
updateCarry()

local busy = false
speedButton.MouseButton1Click:Connect(function()
	if busy then
		return
	end
	busy = true
	local ok, message = BuySpeedFunction:InvokeServer()
	showNotification(message, ok and Color3.fromRGB(120, 220, 255) or Color3.fromRGB(255, 140, 140))
	busy = false
end)

lockButton.MouseButton1Click:Connect(function()
	if busy then
		return
	end
	busy = true
	local ok, message = LockBaseFunction:InvokeServer()
	showNotification(message, ok and PINK or Color3.fromRGB(255, 140, 140))
	busy = false
end)

-- Lock button countdown
task.spawn(function()
	while true do
		local t = workspace:GetServerTimeNow()
		local lockedUntil = player:GetAttribute("LockedUntil") or 0
		local readyAt = player:GetAttribute("LockReadyAt") or 0
		if t < lockedUntil then
			lockButton.Text = "Locked! " .. math.ceil(lockedUntil - t) .. "s"
			lockButton.BackgroundColor3 = Color3.fromRGB(255, 70, 110)
		elseif t < readyAt then
			lockButton.Text = "Lock ready in " .. math.ceil(readyAt - t) .. "s"
			lockButton.BackgroundColor3 = Color3.fromRGB(150, 120, 150)
		else
			lockButton.Text = "Lock Base"
			lockButton.BackgroundColor3 = PINK
		end
		task.wait(0.25)
	end
end)

---------------------------------------------------------------------
-- Hide the "Steal" prompt on your own squishies
---------------------------------------------------------------------
local function checkPrompt(prompt)
	if prompt:GetAttribute("OwnerUserId") == player.UserId then
		prompt.Enabled = false
	end
end
for _, prompt in ipairs(CollectionService:GetTagged("StealPrompt")) do
	checkPrompt(prompt)
end
CollectionService:GetInstanceAddedSignal("StealPrompt"):Connect(checkPrompt)

---------------------------------------------------------------------
-- Squishy bounce + rainbow mutation
---------------------------------------------------------------------
local bouncing = {} -- [model] = phase offset
local function trackPet(model)
	bouncing[model] = math.random() * math.pi * 2
end
for _, model in ipairs(CollectionService:GetTagged("SquishyPet")) do
	trackPet(model)
end
CollectionService:GetInstanceAddedSignal("SquishyPet"):Connect(trackPet)
CollectionService:GetInstanceRemovedSignal("SquishyPet"):Connect(function(model)
	bouncing[model] = nil
end)

RunService.RenderStepped:Connect(function()
	local t = os.clock()
	for model, phase in pairs(bouncing) do
		if not model.Parent then
			bouncing[model] = nil
		else
			local rest = model:GetAttribute("RestPivot")
			if rest then
				local hop = math.abs(math.sin(t * 2.5 + phase)) * 0.5
				model:PivotTo(rest * CFrame.new(0, hop, 0))
			end
			if model:GetAttribute("Rainbow") and model.PrimaryPart then
				model.PrimaryPart.Color = Color3.fromHSV((t * 0.25 + phase) % 1, 0.6, 1)
			end
		end
	end
end)

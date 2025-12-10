-- Takbir's MVS Panel - Modern Simple GUI (Fixed Position)
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local localPlayer = Players.LocalPlayer

local DefaultHRPSize = Vector3.new(2,2,1)
local HeadSize = 10
local BoostSpeed = 18
local ESPEnabled = true
local HitboxEnabled = true
local SpeedEnabled = false
local ClickTeleportEnabled = false
local WallBreakEnabled = false
local HighlightColor = Color3.fromRGB(0,0,0)

local HighlightColors = {
    Black = Color3.fromRGB(0,0,0),
    Pink = Color3.fromRGB(255,105,180),
    Red = Color3.fromRGB(255,0,0),
    Blue = Color3.fromRGB(0,0,255),
    Yellow = Color3.fromRGB(255,255,0)
}

-- Show notification
pcall(function()
    game:GetService("StarterGui"):SetCore("SendNotification", {
        Title = "Takbir's MVS Script Loaded ✔",
        Text = "Modern Simple Panel v2.0 Loaded",
        Duration = 5
    })
end)

local OriginalCollides = {}
local noclipRunConn = nil
local charDescAddedConn = nil

-- Core Functions
local function safeSetCanCollide(part, val)
    if part and part:IsA("BasePart") then
        pcall(function() part.CanCollide = val end)
    end
end

local function storeOriginal(part)
    if part and part:IsA("BasePart") and OriginalCollides[part] == nil then
        OriginalCollides[part] = part.CanCollide
    end
end

local function enableNoclipForCharacter(char)
    if not char then return end
    for _, part in ipairs(char:GetDescendants()) do
        if part:IsA("BasePart") then
            storeOriginal(part)
            safeSetCanCollide(part, false)
        end
    end
    if charDescAddedConn then charDescAddedConn:Disconnect() charDescAddedConn = nil end
    charDescAddedConn = char.DescendantAdded:Connect(function(desc)
        if desc:IsA("BasePart") then
            storeOriginal(desc)
            safeSetCanCollide(desc, false)
        end
    end)
    if noclipRunConn then noclipRunConn:Disconnect() noclipRunConn = nil end
    noclipRunConn = RunService.Stepped:Connect(function()
        if WallBreakEnabled and localPlayer.Character then
            for _, part in ipairs(localPlayer.Character:GetDescendants()) do
                if part:IsA("BasePart") then
                    safeSetCanCollide(part, false)
                end
            end
        end
    end)
end

local function disableNoclipForCharacter()
    if noclipRunConn then noclipRunConn:Disconnect() noclipRunConn = nil end
    if charDescAddedConn then charDescAddedConn:Disconnect() charDescAddedConn = nil end
    for part, orig in pairs(OriginalCollides) do
        if part and part.Parent then
            safeSetCanCollide(part, orig)
        end
        OriginalCollides[part] = nil
    end
    OriginalCollides = {}
end

local function UpdateHighlight(player)
    local char = player.Character
    if not char then return end
    local existing = char:FindFirstChild("OutlineESP")
    if ESPEnabled then
        if existing then existing:Destroy() end
        local h = Instance.new("Highlight")
        h.Name = "OutlineESP"
        h.Adornee = char
        h.FillTransparency = 1
        h.OutlineTransparency = 0
        h.OutlineColor = HighlightColor
        h.Parent = char
    else
        if existing then existing:Destroy() end
    end
end

local function UpdateHitbox(player)
    local char = player.Character
    if char and char:FindFirstChild("HumanoidRootPart") then
        local hrp = char.HumanoidRootPart
        local box = hrp:FindFirstChild("HitboxOutline")
        if HitboxEnabled then
            if not box then
                box = Instance.new("SelectionBox")
                box.Name = "HitboxOutline"
                box.Adornee = hrp
                box.Parent = hrp
            end
            box.LineThickness = 0.1
            box.Color3 = Color3.fromRGB(0,120,255)
            box.Transparency = 0
            box.SurfaceTransparency = 1
            local tool = localPlayer.Character and localPlayer.Character:FindFirstChildWhichIsA("Tool")
            hrp.Size = tool and Vector3.new(HeadSize,HeadSize,HeadSize) or DefaultHRPSize
            hrp.CanCollide = false
            hrp.Transparency = 1
        else
            if box then box:Destroy() end
            hrp.Size = DefaultHRPSize
            hrp.CanCollide = false
            hrp.Transparency = 1
        end
    end
end

-- Modern GUI Creation (No External Library)
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "TakbirMVSPanel"
screenGui.ResetOnSpawn = false
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

if syn and syn.protect_gui then
    syn.protect_gui(screenGui)
end

screenGui.Parent = localPlayer:WaitForChild("PlayerGui")

-- Main Container with rounded corners
local mainContainer = Instance.new("Frame")
mainContainer.Name = "MainContainer"
mainContainer.Size = UDim2.new(0, 450, 0, 500)
mainContainer.Position = UDim2.new(0.5, -225, 0.5, -250) -- Center of screen
mainContainer.AnchorPoint = Vector2.new(0.5, 0.5)
mainContainer.BackgroundColor3 = Color3.fromRGB(25, 25, 30)
mainContainer.BorderSizePixel = 0
mainContainer.ClipsDescendants = true

local UICorner = Instance.new("UICorner")
UICorner.CornerRadius = UDim.new(0, 8)
UICorner.Parent = mainContainer

local UIStroke = Instance.new("UIStroke")
UIStroke.Color = Color3.fromRGB(60, 60, 70)
UIStroke.Thickness = 2
UIStroke.Parent = mainContainer

mainContainer.Parent = screenGui

-- Title Bar with gradient
local titleBar = Instance.new("Frame")
titleBar.Name = "TitleBar"
titleBar.Size = UDim2.new(1, 0, 0, 40)
titleBar.Position = UDim2.new(0, 0, 0, 0)
titleBar.BackgroundColor3 = Color3.fromRGB(35, 35, 45)
titleBar.BorderSizePixel = 0

local titleGradient = Instance.new("UIGradient")
titleGradient.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 105, 180)),
    ColorSequenceKeypoint.new(1, Color3.fromRGB(100, 100, 255))
})
titleGradient.Rotation = 90
titleGradient.Parent = titleBar

titleBar.Parent = mainContainer

-- Title Text
local titleText = Instance.new("TextLabel")
titleText.Name = "TitleText"
titleText.Size = UDim2.new(0.8, 0, 1, 0)
titleText.Position = UDim2.new(0.1, 0, 0, 0)
titleText.BackgroundTransparency = 1
titleText.Text = "Takbir's MVS Panel v2.0"
titleText.TextColor3 = Color3.fromRGB(255, 255, 255)
titleText.TextSize = 18
titleText.Font = Enum.Font.GothamBold
titleText.TextXAlignment = Enum.TextXAlignment.Left
titleText.Parent = titleBar

-- Close Button
local closeButton = Instance.new("TextButton")
closeButton.Name = "CloseButton"
closeButton.Size = UDim2.new(0, 30, 0, 30)
closeButton.Position = UDim2.new(1, -35, 0.5, -15)
closeButton.AnchorPoint = Vector2.new(0, 0.5)
closeButton.BackgroundColor3 = Color3.fromRGB(255, 60, 60)
closeButton.Text = "X"
closeButton.TextColor3 = Color3.fromRGB(255, 255, 255)
closeButton.TextSize = 16
closeButton.Font = Enum.Font.GothamBold

local closeCorner = Instance.new("UICorner")
closeCorner.CornerRadius = UDim.new(0, 6)
closeCorner.Parent = closeButton

closeButton.Parent = titleBar

closeButton.MouseButton1Click:Connect(function()
    screenGui:Destroy()
end)

-- Tab Container
local tabContainer = Instance.new("Frame")
tabContainer.Name = "TabContainer"
tabContainer.Size = UDim2.new(1, 0, 0, 40)
tabContainer.Position = UDim2.new(0, 0, 0, 40)
tabContainer.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
tabContainer.BorderSizePixel = 0
tabContainer.Parent = mainContainer

-- Tab Buttons
local tabs = {"ESP", "Movement", "Combat", "Players", "Settings"}
local currentTab = "ESP"
local tabButtons = {}

local function createTabButton(name, index)
    local tabButton = Instance.new("TextButton")
    tabButton.Name = name .. "Tab"
    tabButton.Size = UDim2.new(1 / #tabs, 0, 1, 0)
    tabButton.Position = UDim2.new((index-1) / #tabs, 0, 0, 0)
    tabButton.BackgroundColor3 = Color3.fromRGB(40, 40, 50)
    tabButton.Text = name
    tabButton.TextColor3 = Color3.fromRGB(200, 200, 200)
    tabButton.TextSize = 14
    tabButton.Font = Enum.Font.GothamBold
    tabButton.BorderSizePixel = 0
    
    local tabCorner = Instance.new("UICorner")
    tabCorner.CornerRadius = UDim.new(0, 6)
    tabCorner.Parent = tabButton
    
    tabButton.MouseButton1Click:Connect(function()
        currentTab = name
        for _, btn in pairs(tabButtons) do
            btn.BackgroundColor3 = Color3.fromRGB(40, 40, 50)
            btn.TextColor3 = Color3.fromRGB(200, 200, 200)
        end
        tabButton.BackgroundColor3 = Color3.fromRGB(255, 105, 180)
        tabButton.TextColor3 = Color3.fromRGB(255, 255, 255)
        
        -- Hide all content frames
        for _, frame in pairs(mainContainer:GetChildren()) do
            if frame.Name:find("Content") then
                frame.Visible = false
            end
        end
        
        -- Show selected content
        local contentFrame = mainContainer:FindFirstChild(name .. "Content")
        if contentFrame then
            contentFrame.Visible = true
        end
    end)
    
    if name == currentTab then
        tabButton.BackgroundColor3 = Color3.fromRGB(255, 105, 180)
        tabButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    end
    
    tabButton.Parent = tabContainer
    tabButtons[name] = tabButton
end

-- Create tab buttons
for i, name in ipairs(tabs) do
    createTabButton(name, i)
end

-- Content Container
local contentContainer = Instance.new("Frame")
contentContainer.Name = "ContentContainer"
contentContainer.Size = UDim2.new(1, -20, 1, -90)
contentContainer.Position = UDim2.new(0, 10, 0, 85)
contentContainer.BackgroundTransparency = 1
contentContainer.Parent = mainContainer

-- ESP Content
local espContent = Instance.new("ScrollingFrame")
espContent.Name = "ESPContent"
espContent.Size = UDim2.new(1, 0, 1, 0)
espContent.BackgroundTransparency = 1
espContent.BorderSizePixel = 0
espContent.ScrollBarThickness = 6
espContent.CanvasSize = UDim2.new(0, 0, 0, 600)
espContent.Visible = true
espContent.Parent = contentContainer

-- ESP Toggle
local espToggleBtn = Instance.new("TextButton")
espToggleBtn.Name = "ESPToggle"
espToggleBtn.Size = UDim2.new(1, -20, 0, 40)
espToggleBtn.Position = UDim2.new(0, 10, 0, 10)
espToggleBtn.BackgroundColor3 = ESPEnabled and Color3.fromRGB(0, 150, 80) or Color3.fromRGB(150, 0, 0)
espToggleBtn.Text = "ESP: " .. (ESPEnabled and "ON" or "OFF")
espToggleBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
espToggleBtn.TextSize = 16
espToggleBtn.Font = Enum.Font.GothamBold

local toggleCorner = Instance.new("UICorner")
toggleCorner.CornerRadius = UDim.new(0, 8)
toggleCorner.Parent = espToggleBtn

espToggleBtn.MouseButton1Click:Connect(function()
    ESPEnabled = not ESPEnabled
    espToggleBtn.BackgroundColor3 = ESPEnabled and Color3.fromRGB(0, 150, 80) or Color3.fromRGB(150, 0, 0)
    espToggleBtn.Text = "ESP: " .. (ESPEnabled and "ON" or "OFF")
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= localPlayer then UpdateHighlight(p) end
    end
end)

espToggleBtn.Parent = espContent

-- Color Selection
local colorLabel = Instance.new("TextLabel")
colorLabel.Name = "ColorLabel"
colorLabel.Size = UDim2.new(1, -20, 0, 30)
colorLabel.Position = UDim2.new(0, 10, 0, 60)
colorLabel.BackgroundTransparency = 1
colorLabel.Text = "ESP Color: Black"
colorLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
colorLabel.TextSize = 14
colorLabel.Font = Enum.Font.Gotham
colorLabel.TextXAlignment = Enum.TextXAlignment.Left
colorLabel.Parent = espContent

-- Color Dropdown
local colorDropdown = Instance.new("TextButton")
colorDropdown.Name = "ColorDropdown"
colorDropdown.Size = UDim2.new(1, -20, 0, 35)
colorDropdown.Position = UDim2.new(0, 10, 0, 95)
colorDropdown.BackgroundColor3 = Color3.fromRGB(50, 50, 60)
colorDropdown.Text = "Select Color"
colorDropdown.TextColor3 = Color3.fromRGB(255, 255, 255)
colorDropdown.TextSize = 14
colorDropdown.Font = Enum.Font.Gotham

local dropdownCorner = Instance.new("UICorner")
dropdownCorner.CornerRadius = UDim.new(0, 6)
dropdownCorner.Parent = colorDropdown

colorDropdown.Parent = espContent

-- Hitbox Toggle
local hitboxToggleBtn = Instance.new("TextButton")
hitboxToggleBtn.Name = "HitboxToggle"
hitboxToggleBtn.Size = UDim2.new(1, -20, 0, 40)
hitboxToggleBtn.Position = UDim2.new(0, 10, 0, 145)
hitboxToggleBtn.BackgroundColor3 = HitboxEnabled and Color3.fromRGB(0, 120, 255) or Color3.fromRGB(80, 80, 80)
hitboxToggleBtn.Text = "Hitbox: " .. (HitboxEnabled and "ON" or "OFF")
hitboxToggleBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
hitboxToggleBtn.TextSize = 16
hitboxToggleBtn.Font = Enum.Font.GothamBold

local hitboxCorner = Instance.new("UICorner")
hitboxCorner.CornerRadius = UDim.new(0, 8)
hitboxCorner.Parent = hitboxToggleBtn

hitboxToggleBtn.MouseButton1Click:Connect(function()
    HitboxEnabled = not HitboxEnabled
    hitboxToggleBtn.BackgroundColor3 = HitboxEnabled and Color3.fromRGB(0, 120, 255) or Color3.fromRGB(80, 80, 80)
    hitboxToggleBtn.Text = "Hitbox: " .. (HitboxEnabled and "ON" or "OFF")
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= localPlayer then UpdateHitbox(p) end
    end
end)

hitboxToggleBtn.Parent = espContent

-- Hitbox Size Slider
local hitboxSizeLabel = Instance.new("TextLabel")
hitboxSizeLabel.Name = "HitboxSizeLabel"
hitboxSizeLabel.Size = UDim2.new(1, -20, 0, 25)
hitboxSizeLabel.Position = UDim2.new(0, 10, 0, 195)
hitboxSizeLabel.BackgroundTransparency = 1
hitboxSizeLabel.Text = "Hitbox Size: " .. HeadSize
hitboxSizeLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
hitboxSizeLabel.TextSize = 14
hitboxSizeLabel.Font = Enum.Font.Gotham
hitboxSizeLabel.TextXAlignment = Enum.TextXAlignment.Left
hitboxSizeLabel.Parent = espContent

local hitboxSlider = Instance.new("TextBox")
hitboxSlider.Name = "HitboxSlider"
hitboxSlider.Size = UDim2.new(1, -20, 0, 35)
hitboxSlider.Position = UDim2.new(0, 10, 0, 225)
hitboxSlider.BackgroundColor3 = Color3.fromRGB(50, 50, 60)
hitboxSlider.TextColor3 = Color3.fromRGB(255, 255, 255)
hitboxSlider.Text = tostring(HeadSize)
hitboxSlider.TextSize = 14
hitboxSlider.Font = Enum.Font.Gotham
hitboxSlider.PlaceholderText = "Enter hitbox size..."

local sliderCorner = Instance.new("UICorner")
sliderCorner.CornerRadius = UDim.new(0, 6)
sliderCorner.Parent = hitboxSlider

hitboxSlider.FocusLost:Connect(function()
    local val = tonumber(hitboxSlider.Text)
    if val and val >= 5 and val <= 50 then
        HeadSize = val
        hitboxSizeLabel.Text = "Hitbox Size: " .. HeadSize
        if HitboxEnabled then
            for _, p in ipairs(Players:GetPlayers()) do
                if p ~= localPlayer then UpdateHitbox(p) end
            end
        end
    else
        hitboxSlider.Text = tostring(HeadSize)
    end
end)

hitboxSlider.Parent = espContent

-- Movement Content
local movementContent = Instance.new("ScrollingFrame")
movementContent.Name = "MovementContent"
movementContent.Size = UDim2.new(1, 0, 1, 0)
movementContent.BackgroundTransparency = 1
movementContent.BorderSizePixel = 0
movementContent.ScrollBarThickness = 6
movementContent.CanvasSize = UDim2.new(0, 0, 0, 400)
movementContent.Visible = false
movementContent.Parent = contentContainer

-- Speed Toggle
local speedToggleBtn = Instance.new("TextButton")
speedToggleBtn.Name = "SpeedToggle"
speedToggleBtn.Size = UDim2.new(1, -20, 0, 40)
speedToggleBtn.Position = UDim2.new(0, 10, 0, 10)
speedToggleBtn.BackgroundColor3 = SpeedEnabled and Color3.fromRGB(255, 100, 0) or Color3.fromRGB(150, 0, 0)
speedToggleBtn.Text = "Speed Hack: " .. (SpeedEnabled and "ON" or "OFF")
speedToggleBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
speedToggleBtn.TextSize = 16
speedToggleBtn.Font = Enum.Font.GothamBold

local speedCorner = Instance.new("UICorner")
speedCorner.CornerRadius = UDim.new(0, 8)
speedCorner.Parent = speedToggleBtn

speedToggleBtn.MouseButton1Click:Connect(function()
    SpeedEnabled = not SpeedEnabled
    speedToggleBtn.BackgroundColor3 = SpeedEnabled and Color3.fromRGB(255, 100, 0) or Color3.fromRGB(150, 0, 0)
    speedToggleBtn.Text = "Speed Hack: " .. (SpeedEnabled and "ON" or "OFF")
end)

speedToggleBtn.Parent = movementContent

-- Speed Value
local speedLabel = Instance.new("TextLabel")
speedLabel.Name = "SpeedLabel"
speedLabel.Size = UDim2.new(1, -20, 0, 25)
speedLabel.Position = UDim2.new(0, 10, 0, 60)
speedLabel.BackgroundTransparency = 1
speedLabel.Text = "Speed Value: " .. BoostSpeed
speedLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
speedLabel.TextSize = 14
speedLabel.Font = Enum.Font.Gotham
speedLabel.TextXAlignment = Enum.TextXAlignment.Left
speedLabel.Parent = movementContent

local speedSlider = Instance.new("TextBox")
speedSlider.Name = "SpeedSlider"
speedSlider.Size = UDim2.new(1, -20, 0, 35)
speedSlider.Position = UDim2.new(0, 10, 0, 90)
speedSlider.BackgroundColor3 = Color3.fromRGB(50, 50, 60)
speedSlider.TextColor3 = Color3.fromRGB(255, 255, 255)
speedSlider.Text = tostring(BoostSpeed)
speedSlider.TextSize = 14
speedSlider.Font = Enum.Font.Gotham
speedSlider.PlaceholderText = "Enter speed value..."

local speedSliderCorner = Instance.new("UICorner")
speedSliderCorner.CornerRadius = UDim.new(0, 6)
speedSliderCorner.Parent = speedSlider

speedSlider.FocusLost:Connect(function()
    local val = tonumber(speedSlider.Text)
    if val and val >= 16 and val <= 100 then
        BoostSpeed = val
        speedLabel.Text = "Speed Value: " .. BoostSpeed
    else
        speedSlider.Text = tostring(BoostSpeed)
    end
end)

speedSlider.Parent = movementContent

-- Click Teleport Toggle
local clickTPToggleBtn = Instance.new("TextButton")
clickTPToggleBtn.Name = "ClickTPToggle"
clickTPToggleBtn.Size = UDim2.new(1, -20, 0, 40)
clickTPToggleBtn.Position = UDim2.new(0, 10, 0, 140)
clickTPToggleBtn.BackgroundColor3 = ClickTeleportEnabled and Color3.fromRGB(0, 150, 150) or Color3.fromRGB(80, 80, 80)
clickTPToggleBtn.Text = "Click Teleport: " .. (ClickTeleportEnabled and "ON" or "OFF")
clickTPToggleBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
clickTPToggleBtn.TextSize = 16
clickTPToggleBtn.Font = Enum.Font.GothamBold

local clickTPCorner = Instance.new("UICorner")
clickTPCorner.CornerRadius = UDim.new(0, 8)
clickTPCorner.Parent = clickTPToggleBtn

clickTPToggleBtn.MouseButton1Click:Connect(function()
    ClickTeleportEnabled = not ClickTeleportEnabled
    clickTPToggleBtn.BackgroundColor3 = ClickTeleportEnabled and Color3.fromRGB(0, 150, 150) or Color3.fromRGB(80, 80, 80)
    clickTPToggleBtn.Text = "Click Teleport: " .. (ClickTeleportEnabled and "ON" or "OFF")
end)

clickTPToggleBtn.Parent = movementContent

-- Combat Content
local combatContent = Instance.new("ScrollingFrame")
combatContent.Name = "CombatContent"
combatContent.Size = UDim2.new(1, 0, 1, 0)
combatContent.BackgroundTransparency = 1
combatContent.BorderSizePixel = 0
combatContent.ScrollBarThickness = 6
combatContent.CanvasSize = UDim2.new(0, 0, 0, 200)
combatContent.Visible = false
combatContent.Parent = contentContainer

-- Wall Break Toggle
local wallBreakToggleBtn = Instance.new("TextButton")
wallBreakToggleBtn.Name = "WallBreakToggle"
wallBreakToggleBtn.Size = UDim2.new(1, -20, 0, 40)
wallBreakToggleBtn.Position = UDim2.new(0, 10, 0, 10)
wallBreakToggleBtn.BackgroundColor3 = WallBreakEnabled and Color3.fromRGB(200, 0, 50) or Color3.fromRGB(80, 80, 80)
wallBreakToggleBtn.Text = "Wall Break: " .. (WallBreakEnabled and "ON" or "OFF")
wallBreakToggleBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
wallBreakToggleBtn.TextSize = 16
wallBreakToggleBtn.Font = Enum.Font.GothamBold

local wallBreakCorner = Instance.new("UICorner")
wallBreakCorner.CornerRadius = UDim.new(0, 8)
wallBreakCorner.Parent = wallBreakToggleBtn

wallBreakToggleBtn.MouseButton1Click:Connect(function()
    WallBreakEnabled = not WallBreakEnabled
    wallBreakToggleBtn.BackgroundColor3 = WallBreakEnabled and Color3.fromRGB(200, 0, 50) or Color3.fromRGB(80, 80, 80)
    wallBreakToggleBtn.Text = "Wall Break: " .. (WallBreakEnabled and "ON" or "OFF")
    if WallBreakEnabled then
        enableNoclipForCharacter(localPlayer.Character)
    else
        disableNoclipForCharacter()
    end
end)

wallBreakToggleBtn.Parent = combatContent

-- Players Content
local playersContent = Instance.new("ScrollingFrame")
playersContent.Name = "PlayersContent"
playersContent.Size = UDim2.new(1, 0, 1, 0)
playersContent.BackgroundTransparency = 1
playersContent.BorderSizePixel = 0
playersContent.ScrollBarThickness = 6
playersContent.CanvasSize = UDim2.new(0, 0, 0, 0)
playersContent.Visible = false
playersContent.Parent = contentContainer

local function updatePlayerList()
    playersContent:ClearAllChildren()
    local yPos = 10
    
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= localPlayer then
            local playerBtn = Instance.new("TextButton")
            playerBtn.Name = player.Name .. "_Btn"
            playerBtn.Size = UDim2.new(1, -20, 0, 40)
            playerBtn.Position = UDim2.new(0, 10, 0, yPos)
            playerBtn.BackgroundColor3 = Color3.fromRGB(50, 50, 60)
            playerBtn.Text = "TP to " .. player.Name
            playerBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
            playerBtn.TextSize = 14
            playerBtn.Font = Enum.Font.GothamBold
            
            local playerCorner = Instance.new("UICorner")
            playerCorner.CornerRadius = UDim.new(0, 6)
            playerCorner.Parent = playerBtn
            
            playerBtn.MouseButton1Click:Connect(function()
                if localPlayer.Character and localPlayer.Character:FindFirstChild("HumanoidRootPart") and
                   player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
                    localPlayer.Character.HumanoidRootPart.CFrame = player.Character.HumanoidRootPart.CFrame
                end
            end)
            
            playerBtn.Parent = playersContent
            yPos = yPos + 45
        end
    end
    
    playersContent.CanvasSize = UDim2.new(0, 0, 0, yPos + 10)
end

-- Settings Content
local settingsContent = Instance.new("ScrollingFrame")
settingsContent.Name = "SettingsContent"
settingsContent.Size = UDim2.new(1, 0, 1, 0)
settingsContent.BackgroundTransparency = 1
settingsContent.BorderSizePixel = 0
settingsContent.ScrollBarThickness = 6
settingsContent.CanvasSize = UDim2.new(0, 0, 0, 200)
settingsContent.Visible = false
settingsContent.Parent = contentContainer

-- Hide UI Button
local hideUIButton = Instance.new("TextButton")
hideUIButton.Name = "HideUIButton"
hideUIButton.Size = UDim2.new(1, -20, 0, 40)
hideUIButton.Position = UDim2.new(0, 10, 0, 10)
hideUIButton.BackgroundColor3 = Color3.fromRGB(60, 60, 70)
hideUIButton.Text = "Hide UI"
hideUIButton.TextColor3 = Color3.fromRGB(255, 255, 255)
hideUIButton.TextSize = 16
hideUIButton.Font = Enum.Font.GothamBold

local hideCorner = Instance.new("UICorner")
hideCorner.CornerRadius = UDim.new(0, 8)
hideCorner.Parent = hideUIButton

hideUIButton.MouseButton1Click:Connect(function()
    screenGui.Enabled = not screenGui.Enabled
    hideUIButton.Text = screenGui.Enabled and "Hide UI" or "Show UI"
end)

hideUIButton.Parent = settingsContent

-- Credits
local creditsLabel = Instance.new("TextLabel")
creditsLabel.Name = "CreditsLabel"
creditsLabel.Size = UDim2.new(1, -20, 0, 60)
creditsLabel.Position = UDim2.new(0, 10, 0, 60)
creditsLabel.BackgroundTransparency = 1
creditsLabel.Text = "Takbir's MVS Panel v2.0\nModern Simple GUI\nMade with ❤️"
creditsLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
creditsLabel.TextSize = 14
creditsLabel.Font = Enum.Font.Gotham
creditsLabel.TextXAlignment = Enum.TextXAlignment.Left
creditsLabel.TextYAlignment = Enum.TextYAlignment.Top
creditsLabel.Parent = settingsContent

-- Drag System with Boundary Check
local dragging = false
local dragStart = nil
local startPos = nil

titleBar.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragging = true
        dragStart = input.Position
        startPos = mainContainer.Position
        
        local connection
        connection = input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then
                dragging = false
                if connection then
                    connection:Disconnect()
                end
            end
        end)
    end
end)

UserInputService.InputChanged:Connect(function(input)
    if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
        local delta = input.Position - dragStart
        local newX = startPos.X.Offset + delta.X
        local newY = startPos.Y.Offset + delta.Y
        
        -- Boundary check to keep GUI within screen
        local screenSize = workspace.CurrentCamera.ViewportSize
        local guiSize = mainContainer.AbsoluteSize
        
        newX = math.clamp(newX, 0, screenSize.X - guiSize.X)
        newY = math.clamp(newY, 0, screenSize.Y - guiSize.Y)
        
        mainContainer.Position = UDim2.new(startPos.X.Scale, newX, startPos.Y.Scale, newY)
    end
end)

-- Color dropdown functionality
colorDropdown.MouseButton1Click:Connect(function()
    local dropdownFrame = Instance.new("Frame")
    dropdownFrame.Name = "ColorDropdownFrame"
    dropdownFrame.Size = UDim2.new(1, 0, 0, 130)
    dropdownFrame.Position = UDim2.new(0, 0, 1, 5)
    dropdownFrame.BackgroundColor3 = Color3.fromRGB(40, 40, 50)
    dropdownFrame.BorderSizePixel = 0
    dropdownFrame.ZIndex = 100
    
    local dropdownCorner = Instance.new("UICorner")
    dropdownCorner.CornerRadius = UDim.new(0, 6)
    dropdownCorner.Parent = dropdownFrame
    
    local colorsList = {"Black", "Pink", "Red", "Blue", "Yellow"}
    local yPos = 5
    
    for _, colorName in ipairs(colorsList) do
        local colorBtn = Instance.new("TextButton")
        colorBtn.Name = colorName .. "Btn"
        colorBtn.Size = UDim2.new(1, -10, 0, 24)
        colorBtn.Position = UDim2.new(0, 5, 0, yPos)
        colorBtn.BackgroundColor3 = HighlightColors[colorName]
        colorBtn.Text = colorName
        colorBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
        colorBtn.TextSize = 12
        colorBtn.Font = Enum.Font.Gotham
        
        colorBtn.MouseButton1Click:Connect(function()
            HighlightColor = HighlightColors[colorName]
            colorLabel.Text = "ESP Color: " .. colorName
            for _, p in ipairs(Players:GetPlayers()) do
                if p ~= localPlayer then UpdateHighlight(p) end
            end
            dropdownFrame:Destroy()
        end)
        
        colorBtn.Parent = dropdownFrame
        yPos = yPos + 25
    end
    
    dropdownFrame.Parent = colorDropdown
    
    -- Close dropdown when clicking elsewhere
    local function closeDropdown(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            if not dropdownFrame:IsDescendantOf(colorDropdown) then return end
            local mousePos = game:GetService("UserInputService"):GetMouseLocation()
            local dropdownPos = dropdownFrame.AbsolutePosition
            local dropdownSize = dropdownFrame.AbsoluteSize
            
            if mousePos.X < dropdownPos.X or mousePos.X > dropdownPos.X + dropdownSize.X or
               mousePos.Y < dropdownPos.Y or mousePos.Y > dropdownPos.Y + dropdownSize.Y then
                dropdownFrame:Destroy()
            end
        end
    end
    
    game:GetService("UserInputService").InputBegan:Connect(closeDropdown)
end)

-- Initialize player list
updatePlayerList()

-- Refresh player list every 10 seconds
task.spawn(function()
    while true do
        task.wait(10)
        if currentTab == "Players" then
            updatePlayerList()
        end
    end
end)

-- Character added event
local function onCharacterAdded(char)
    OriginalCollides = {}
    if WallBreakEnabled then
        enableNoclipForCharacter(char)
    end
    wait(1)
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= localPlayer then
            UpdateHighlight(p)
            UpdateHitbox(p)
        end
    end
end

if localPlayer.Character then
    onCharacterAdded(localPlayer.Character)
end
localPlayer.CharacterAdded:Connect(onCharacterAdded)

-- Click teleport functionality
local mouse = localPlayer:GetMouse()
mouse.Button1Down:Connect(function()
    if ClickTeleportEnabled and localPlayer.Character then
        local hrp = localPlayer.Character:FindFirstChild("HumanoidRootPart")
        if hrp then
            hrp.CFrame = CFrame.new(mouse.Hit.Position + Vector3.new(0, 3, 0))
        end
    end
end)

-- Main render loop
RunService.RenderStepped:Connect(function()
    if localPlayer.Character then
        local hum = localPlayer.Character:FindFirstChildOfClass("Humanoid")
        if hum then
            local targetSpeed = SpeedEnabled and BoostSpeed or 16
            hum.WalkSpeed = targetSpeed
        end
    end
    if WallBreakEnabled and localPlayer.Character then
        for _, part in ipairs(localPlayer.Character:GetDescendants()) do
            if part:IsA("BasePart") then
                safeSetCanCollide(part, false)
            end
        end
    end
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= localPlayer then
            UpdateHighlight(player)
            UpdateHitbox(player)
        end
    end
end)

-- Add player join/leave events
Players.PlayerAdded:Connect(function(player)
    wait(1)
    if currentTab == "Players" then
        updatePlayerList()
    end
end)

Players.PlayerRemoving:Connect(function(player)
    if currentTab == "Players" then
        updatePlayerList()
    end
end)

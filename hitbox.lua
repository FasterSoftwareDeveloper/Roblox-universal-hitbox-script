local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local localPlayer = Players.LocalPlayer

-- Configuration
local DefaultHRPSize = Vector3.new(2,2,1)
local HeadSize = 10
local BoostSpeed = 18

-- Toggles
local ESPEnabled = true
local TeamCheckEnabled = false -- New Toggle
local HitboxEnabled = true
local SpeedEnabled = false
local ClickTeleportEnabled = false
local WallBreakEnabled = false

-- Visuals
local HighlightColor = Color3.fromRGB(0,0,0)
local HighlightColors = {
    Black = Color3.fromRGB(0,0,0),
    Pink = Color3.fromRGB(255,105,180),
    Red = Color3.fromRGB(255,0,0),
    Blue = Color3.fromRGB(0,0,255),
    Yellow = Color3.fromRGB(255,255,0),
    Green = Color3.fromRGB(0,255,0),
    White = Color3.fromRGB(255,255,255)
}

-- Notification
pcall(function()
    game:GetService("StarterGui"):SetCore("SendNotification", {
        Title = "Takbir's MVS Script",
        Text = "Team Check & Round UI Loaded!",
        Duration = 5
    })
end)

-- Physics / WallBreak Variables
local OriginalCollides = {}
local noclipRunConn = nil
local charDescAddedConn = nil

-- [[ UTILITY FUNCTIONS ]] --
local function addCorner(instance, radius)
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, radius or 6)
    corner.Parent = instance
    return corner
end

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

-- [[ WALL BREAK LOGIC ]] --
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

-- [[ HIGHLIGHT LOGIC (Fixed + Team Check) ]] --
local function UpdateHighlight(player)
    local char = player.Character
    if not char then return end
    
    local existing = char:FindFirstChild("OutlineESP")
    
    if ESPEnabled then
        -- Determine Color
        local useColor = HighlightColor
        if TeamCheckEnabled then
            if player.TeamColor then
                useColor = player.TeamColor.Color
            else
                useColor = Color3.fromRGB(255, 255, 255) -- Fallback if no team
            end
        end

        if not existing then
            local h = Instance.new("Highlight")
            h.Name = "OutlineESP"
            h.Adornee = char
            h.Parent = char
            h.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
            h.FillTransparency = 1
            h.OutlineTransparency = 0
            h.OutlineColor = useColor
        else
            existing.OutlineColor = useColor
            existing.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
            existing.Enabled = true
        end
    else
        if existing then existing:Destroy() end
    end
end

-- [[ HITBOX LOGIC ]] --
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

-- [[ GUI CREATION ]] --
local gui
local isMinimizing = false

-- Drag Variables
local dragToggle = false
local dragStart = nil
local startPos = nil
local dragObject = nil

local function updateDrag(input)
    if not dragToggle or not dragStart or not startPos or not dragObject then return end
    local delta = input.Position - dragStart
    local newPos = UDim2.new(
        startPos.X.Scale, startPos.X.Offset + delta.X,
        startPos.Y.Scale, startPos.Y.Offset + delta.Y
    )
    dragObject.Position = newPos
end

local function startDrag(input, obj)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragToggle = true
        dragStart = input.Position
        dragObject = obj
        startPos = obj.Position
        local connection
        connection = input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then
                dragToggle = false
                dragStart = nil
                startPos = nil
                dragObject = nil
                if connection then connection:Disconnect() end
            end
        end)
    end
end

local function CreateGUI()
    if gui then gui:Destroy() end
    gui = Instance.new("ScreenGui")
    gui.Name = "MVS_GUI_V2"
    gui.ResetOnSpawn = false
    gui.Parent = localPlayer:WaitForChild("PlayerGui")
    gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

    local MainContainer = Instance.new("Frame")
    MainContainer.Name = "MainContainer"
    MainContainer.Size = UDim2.new(0, 320, 0, 450) -- Taller for new button
    MainContainer.Position = UDim2.new(0, 10, 0, 50)
    MainContainer.BackgroundTransparency = 1
    MainContainer.Parent = gui

    local MinBtn = Instance.new("TextButton")
    MinBtn.Name = "MinimizeButton"
    MinBtn.Size = UDim2.new(0, 40, 0, 25)
    MinBtn.Position = UDim2.new(0, 0, 0, 0)
    MinBtn.BackgroundColor3 = Color3.fromRGB(255, 200, 0)
    MinBtn.Text = "-"
    MinBtn.TextColor3 = Color3.fromRGB(0, 0, 0)
    MinBtn.Font = Enum.Font.GothamBold
    MinBtn.TextScaled = true
    MinBtn.Parent = MainContainer
    MinBtn.ZIndex = 12
    addCorner(MinBtn, 6)

    local MainFrame = Instance.new("Frame")
    MainFrame.Name = "MainFrame"
    MainFrame.Size = UDim2.new(0, 280, 0, 410)
    MainFrame.Position = UDim2.new(0, 0, 0, 30) -- Spaced below min button
    MainFrame.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
    MainFrame.BorderSizePixel = 0
    MainFrame.Parent = MainContainer
    MainFrame.ClipsDescendants = true
    MainFrame.ZIndex = 10
    addCorner(MainFrame, 8)

    -- Drag Logic
    local dragArea = Instance.new("Frame")
    dragArea.Size = UDim2.new(1, 0, 0, 30)
    dragArea.BackgroundTransparency = 1
    dragArea.Parent = MainContainer
    dragArea.InputBegan:Connect(function(input) startDrag(input, MainContainer) end)
    dragArea.InputChanged:Connect(function(input) 
        if dragToggle and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then 
            updateDrag(input) 
        end 
    end)
    UserInputService.InputChanged:Connect(function(input)
        if dragToggle and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            updateDrag(input)
        end
    end)

    -- Title
    local Title = Instance.new("TextLabel")
    Title.Size = UDim2.new(1, 0, 0, 35)
    Title.Position = UDim2.new(0, 0, 0, 0)
    Title.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
    Title.Text = "  Takbir's MVS Panel v2.0"
    Title.TextColor3 = Color3.fromRGB(255, 255, 255)
    Title.TextXAlignment = Enum.TextXAlignment.Left
    Title.TextSize = 18
    Title.Font = Enum.Font.GothamBold
    Title.Parent = MainFrame
    Title.InputBegan:Connect(function(input) startDrag(input, MainContainer) end)
    
    -- Minimize Logic
    MinBtn.MouseButton1Click:Connect(function()
        isMinimizing = not isMinimizing
        MainFrame.Visible = not isMinimizing
        MinBtn.Text = isMinimizing and "+" or "-"
        MainContainer.Size = isMinimizing and UDim2.new(0, 40, 0, 25) or UDim2.new(0, 320, 0, 450)
    end)

    local ScrollFrame = Instance.new("ScrollingFrame")
    ScrollFrame.Size = UDim2.new(1, -10, 1, -45)
    ScrollFrame.Position = UDim2.new(0, 5, 0, 40)
    ScrollFrame.BackgroundTransparency = 1
    ScrollFrame.CanvasSize = UDim2.new(0, 0, 0, 600)
    ScrollFrame.ScrollBarThickness = 4
    ScrollFrame.Parent = MainFrame

    -- Helper for Buttons
    local function CreateButton(pos, text, color, onClick)
        local btn = Instance.new("TextButton")
        btn.Size = UDim2.new(0, 125, 0, 35)
        btn.Position = pos
        btn.BackgroundColor3 = color
        btn.Text = text
        btn.TextColor3 = Color3.fromRGB(255, 255, 255)
        btn.Font = Enum.Font.GothamBold
        btn.TextSize = 14
        btn.Parent = ScrollFrame
        addCorner(btn, 6)
        btn.MouseButton1Click:Connect(function() onClick(btn) end)
        return btn
    end

    -- Helper for Sliders
    local function CreateSlider(pos, labelText, default, callback)
        local frame = Instance.new("Frame")
        frame.Size = UDim2.new(0, 260, 0, 50)
        frame.Position = pos
        frame.BackgroundTransparency = 1
        frame.Parent = ScrollFrame

        local lbl = Instance.new("TextLabel")
        lbl.Size = UDim2.new(1, 0, 0, 20)
        lbl.BackgroundTransparency = 1
        lbl.Text = labelText .. ": " .. default
        lbl.TextColor3 = Color3.fromRGB(200, 200, 200)
        lbl.Font = Enum.Font.Gotham
        lbl.TextSize = 14
        lbl.TextXAlignment = Enum.TextXAlignment.Left
        lbl.Parent = frame

        local tb = Instance.new("TextBox")
        tb.Size = UDim2.new(1, 0, 0, 25)
        tb.Position = UDim2.new(0, 0, 0, 22)
        tb.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
        tb.TextColor3 = Color3.fromRGB(255, 255, 255)
        tb.Text = tostring(default)
        tb.Font = Enum.Font.Gotham
        tb.TextSize = 14
        tb.Parent = frame
        addCorner(tb, 6)

        tb.FocusLost:Connect(function()
            local val = tonumber(tb.Text)
            if val and val > 0 then
                callback(val)
                lbl.Text = labelText .. ": " .. val
            else
                tb.Text = tostring(default)
            end
        end)
    end

    -- [[ BUTTON LAYOUT ]] --
    -- Row 1
    local SpeedBtn = CreateButton(UDim2.new(0, 5, 0, 5), "Speed: OFF", Color3.fromRGB(180, 50, 50), function(b)
        SpeedEnabled = not SpeedEnabled
        b.Text = SpeedEnabled and "Speed: ON" or "Speed: OFF"
        b.BackgroundColor3 = SpeedEnabled and Color3.fromRGB(50, 180, 50) or Color3.fromRGB(180, 50, 50)
    end)
    local ESPBtn = CreateButton(UDim2.new(0, 140, 0, 5), "ESP: ON", Color3.fromRGB(50, 180, 50), function(b)
        ESPEnabled = not ESPEnabled
        b.Text = ESPEnabled and "ESP: ON" or "ESP: OFF"
        b.BackgroundColor3 = ESPEnabled and Color3.fromRGB(50, 180, 50) or Color3.fromRGB(180, 50, 50)
        for _, p in ipairs(Players:GetPlayers()) do if p ~= localPlayer then UpdateHighlight(p) end end
    end)

    -- Row 2
    local HitboxBtn = CreateButton(UDim2.new(0, 5, 0, 45), "Hitbox: ON", Color3.fromRGB(50, 180, 50), function(b)
        HitboxEnabled = not HitboxEnabled
        b.Text = HitboxEnabled and "Hitbox: ON" or "Hitbox: OFF"
        b.BackgroundColor3 = HitboxEnabled and Color3.fromRGB(50, 180, 50) or Color3.fromRGB(180, 50, 50)
        for _, p in ipairs(Players:GetPlayers()) do if p ~= localPlayer then UpdateHitbox(p) end end
    end)
    local ClickTPBtn = CreateButton(UDim2.new(0, 140, 0, 45), "Click TP: OFF", Color3.fromRGB(100, 100, 100), function(b)
        ClickTeleportEnabled = not ClickTeleportEnabled
        b.Text = ClickTeleportEnabled and "Click TP: ON" or "Click TP: OFF"
        b.BackgroundColor3 = ClickTeleportEnabled and Color3.fromRGB(50, 180, 50) or Color3.fromRGB(100, 100, 100)
    end)

    -- Row 3
    local WallBreakBtn = CreateButton(UDim2.new(0, 5, 0, 85), "WallBreak: OFF", Color3.fromRGB(180, 50, 50), function(b)
        WallBreakEnabled = not WallBreakEnabled
        b.Text = WallBreakEnabled and "WallBreak: ON" or "WallBreak: OFF"
        b.BackgroundColor3 = WallBreakEnabled and Color3.fromRGB(50, 180, 50) or Color3.fromRGB(180, 50, 50)
        if WallBreakEnabled then enableNoclipForCharacter(localPlayer.Character) else disableNoclipForCharacter() end
    end)

    -- NEW: Team Check Button
    local TeamCheckBtn = CreateButton(UDim2.new(0, 140, 0, 85), "Team Check: OFF", Color3.fromRGB(100, 100, 100), function(b)
        TeamCheckEnabled = not TeamCheckEnabled
        b.Text = TeamCheckEnabled and "Team Check: ON" or "Team Check: OFF"
        b.BackgroundColor3 = TeamCheckEnabled and Color3.fromRGB(0, 150, 255) or Color3.fromRGB(100, 100, 100)
        -- Update all highlights immediately
        for _, p in ipairs(Players:GetPlayers()) do 
            if p ~= localPlayer then UpdateHighlight(p) end 
        end
    end)

    -- Sliders
    CreateSlider(UDim2.new(0, 5, 0, 130), "Speed Amount", BoostSpeed, function(val) BoostSpeed = val end)
    CreateSlider(UDim2.new(0, 5, 0, 190), "Hitbox Size", HeadSize, function(val) HeadSize = val end)

    -- Color Selection Area
    local colorLabel = Instance.new("TextLabel")
    colorLabel.Size = UDim2.new(0, 260, 0, 20)
    colorLabel.Position = UDim2.new(0, 5, 0, 250)
    colorLabel.BackgroundTransparency = 1
    colorLabel.Text = "ESP Color (If Team Check OFF)"
    colorLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
    colorLabel.Font = Enum.Font.GothamBold
    colorLabel.TextSize = 14
    colorLabel.Parent = ScrollFrame

    local dropdown = Instance.new("TextButton")
    dropdown.Size = UDim2.new(0, 260, 0, 30)
    dropdown.Position = UDim2.new(0, 5, 0, 275)
    dropdown.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
    dropdown.Text = "Select Color..."
    dropdown.TextColor3 = Color3.fromRGB(255, 255, 255)
    dropdown.Font = Enum.Font.GothamBold
    dropdown.TextSize = 14
    dropdown.Parent = ScrollFrame
    addCorner(dropdown, 6)

    local listFrame = Instance.new("Frame")
    listFrame.Size = UDim2.new(0, 260, 0, 0)
    listFrame.Position = UDim2.new(0, 0, 1, 5)
    listFrame.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
    listFrame.Parent = dropdown
    listFrame.ClipsDescendants = true
    listFrame.ZIndex = 20
    addCorner(listFrame, 6)

    local open = false
    dropdown.MouseButton1Click:Connect(function()
        open = not open
        listFrame.Size = open and UDim2.new(0, 260, 0, 175) or UDim2.new(0, 260, 0, 0)
    end)

    local i = 0
    for name, color in pairs(HighlightColors) do
        local b = Instance.new("TextButton")
        b.Size = UDim2.new(1, -10, 0, 25)
        b.Position = UDim2.new(0, 5, 0, i * 25)
        b.BackgroundTransparency = 1
        b.Text = name
        b.TextColor3 = color
        b.Font = Enum.Font.GothamBold
        b.TextSize = 14
        b.Parent = listFrame
        b.ZIndex = 21
        b.MouseButton1Click:Connect(function()
            HighlightColor = color
            dropdown.Text = "Color: " .. name
            if not TeamCheckEnabled then
                for _, p in ipairs(Players:GetPlayers()) do
                    if p ~= localPlayer then UpdateHighlight(p) end
                end
            end
            open = false
            listFrame.Size = UDim2.new(0, 260, 0, 0)
        end)
        i = i + 1
    end
end

if not gui then CreateGUI() end

-- [[ CONNECTION LOGIC ]] --
local function onCharacterAdded(char)
    OriginalCollides = {}
    if WallBreakEnabled then enableNoclipForCharacter(char) end
    task.wait(1)
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= localPlayer then
            UpdateHighlight(p)
            UpdateHitbox(p)
        end
    end
end

if localPlayer.Character then onCharacterAdded(localPlayer.Character) end
localPlayer.CharacterAdded:Connect(onCharacterAdded)

local mouse = localPlayer:GetMouse()
mouse.Button1Down:Connect(function()
    if ClickTeleportEnabled and localPlayer.Character then
        local hrp = localPlayer.Character:FindFirstChild("HumanoidRootPart")
        if hrp then hrp.CFrame = CFrame.new(mouse.Hit.Position + Vector3.new(0, 3, 0)) end
    end
end)

RunService.RenderStepped:Connect(function()
    if localPlayer.Character then
        local hum = localPlayer.Character:FindFirstChildOfClass("Humanoid")
        if hum then hum.WalkSpeed = SpeedEnabled and BoostSpeed or 16 end
    end
    -- Keep highlights and hitboxes persistent
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= localPlayer then
            UpdateHighlight(player)
            UpdateHitbox(player)
        end
    end
end)

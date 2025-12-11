local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local localPlayer = Players.LocalPlayer

-- Configuration
local DefaultHRPSize = Vector3.new(2,2,1)
local HeadSize = 10
local BoostSpeed = 18
local DefaultJumpPower = 50 -- Standard Roblox Jump Power

-- Toggles
local ESPEnabled = true
local TeamCheckEnabled = false
local HitboxEnabled = true
local SpeedEnabled = false
local ClickTeleportEnabled = false
local WallBreakEnabled = false
local NameTagEnabled = false
local FlyJumpEnabled = false -- NEW FEATURE: FlyJump Mode

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
        Text = "Fly System replaced with FlyJump (JumpPower boost)!",
        Duration = 5
    })
end)

-- Physics / WallBreak Variables
local OriginalCollides = {}
local noclipRunConn = nil
local charDescAddedConn = nil

-- [[ UTILITY FUNCTIONS (omitted for brevity, unchanged) ]] --
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

-- [[ FLY JUMP LOGIC ]] --
local function SetFlyJump(char, enabled)
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hum then return end

    if enabled then
        -- Set jump power high for super jump
        hum.JumpPower = 150 
    else
        -- Reset to default
        hum.JumpPower = DefaultJumpPower
    end
end

-- [[ PARTIAL PLAYER FINDER (omitted for brevity, unchanged) ]] --
local function findPartialPlayer(partialName)
    local partialNameLower = partialName:lower()
    if #partialNameLower == 0 then return nil end

    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= localPlayer then
            if player.Name:lower():find(partialNameLower, 1, true) then 
                return player
            end
        end
    end
    return nil
end

-- [[ WALL BREAK LOGIC (omitted for brevity, unchanged) ]] --
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
        OriginalCollides = {}
    end
end

-- [[ VISUALS LOGIC (omitted for brevity, unchanged) ]] --
local function UpdateHighlight(player)
    local char = player.Character
    if not char then return end
    
    local existing = char:FindFirstChild("OutlineESP")
    
    if ESPEnabled then
        local useColor = HighlightColor
        if TeamCheckEnabled then
            useColor = player.TeamColor and player.TeamColor.Color or Color3.fromRGB(255, 255, 255)
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

local function UpdateNameTag(player)
    local char = player.Character
    if not char then return end
    local head = char:FindFirstChild("Head")
    if not head then return end

    local existingBillboard = head:FindFirstChild("NameTagESP")
    
    if NameTagEnabled then
        if not existingBillboard then
            local billboard = Instance.new("BillboardGui")
            billboard.Name = "NameTagESP"
            billboard.AlwaysOnTop = true
            billboard.ExtentsOffset = Vector3.new(0, 2, 0)
            billboard.Size = UDim2.new(0, 150, 0, 25)
            billboard.Adornee = head

            local label = Instance.new("TextLabel")
            label.Size = UDim2.new(1, 0, 1, 0)
            label.BackgroundTransparency = 1
            label.Text = player.Name
            label.TextColor3 = Color3.fromRGB(255, 255, 255)
            label.Font = Enum.Font.GothamBold
            label.TextSize = 16
            label.Parent = billboard
            billboard.Parent = head
        else
            existingBillboard.Enabled = true
        end
    else
        if existingBillboard then
            existingBillboard:Destroy()
        end
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

-- [[ GUI CREATION (omitted for brevity, unchanged) ]] --
local gui
local isMinimizing = false

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
    MainContainer.Size = UDim2.new(0, 320, 0, 450)
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
    MainFrame.Position = UDim2.new(0, 0, 0, 30)
    MainFrame.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
    MainFrame.BorderSizePixel = 0
    MainFrame.Parent = MainContainer
    MainFrame.ClipsDescendants = true
    MainFrame.ZIndex = 10
    addCorner(MainFrame, 8)

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

    local Title = Instance.new("TextLabel")
    Title.Size = UDim2.new(1, 0, 0, 35)
    Title.Position = UDim2.new(0, 0, 0, 0)
    Title.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
    Title.Text = "  Takbir's Panel v2.1 (FlyJump)"
    Title.TextColor3 = Color3.fromRGB(255, 255, 255)
    Title.TextXAlignment = Enum.TextXAlignment.Left
    Title.TextSize = 18
    Title.Font = Enum.Font.GothamBold
    Title.Parent = MainFrame
    Title.InputBegan:Connect(function(input) startDrag(input, MainContainer) end)
    
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
    ScrollFrame.CanvasSize = UDim2.new(0, 0, 0, 700)
    ScrollFrame.ScrollBarThickness = 4
    ScrollFrame.Parent = MainFrame

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
    -- Row 1 (Y=5)
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

    -- Row 2 (Y=45)
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

    -- Row 3 (Y=85)
    local WallBreakBtn = CreateButton(UDim2.new(0, 5, 0, 85), "WallBreak: OFF", Color3.fromRGB(180, 50, 50), function(b)
        WallBreakEnabled = not WallBreakEnabled
        b.Text = WallBreakEnabled and "WallBreak: ON" or "WallBreak: OFF"
        b.BackgroundColor3 = WallBreakEnabled and Color3.fromRGB(50, 180, 50) or Color3.fromRGB(180, 50, 50)
        if WallBreakEnabled then enableNoclipForCharacter(localPlayer.Character) else disableNoclipForCharacter() end
    end)
    local TeamCheckBtn = CreateButton(UDim2.new(0, 140, 0, 85), "Team Check: OFF", Color3.fromRGB(100, 100, 100), function(b)
        TeamCheckEnabled = not TeamCheckEnabled
        b.Text = TeamCheckEnabled and "Team Check: ON" or "Team Check: OFF"
        b.BackgroundColor3 = TeamCheckEnabled and Color3.fromRGB(0, 150, 255) or Color3.fromRGB(100, 100, 100)
        for _, p in ipairs(Players:GetPlayers()) do if p ~= localPlayer then UpdateHighlight(p) end end
    end)

    -- Row 4 (Y=125)
    local NameTagBtn = CreateButton(UDim2.new(0, 5, 0, 125), "Name Tag: OFF", Color3.fromRGB(100, 100, 100), function(b)
        NameTagEnabled = not NameTagEnabled
        b.Text = NameTagEnabled and "Name Tag: ON" or "Name Tag: OFF"
        b.BackgroundColor3 = NameTagEnabled and Color3.fromRGB(50, 180, 50) or Color3.fromRGB(100, 100, 100)
        for _, p in ipairs(Players:GetPlayers()) do if p ~= localPlayer then UpdateNameTag(p) end end
    end)
    
    local FlyJumpBtn = CreateButton(UDim2.new(0, 140, 0, 125), "FlyJump: OFF", Color3.fromRGB(180, 50, 50), function(b)
        FlyJumpEnabled = not FlyJumpEnabled
        b.Text = FlyJumpEnabled and "FlyJump: ON" or "FlyJump: OFF"
        b.BackgroundColor3 = FlyJumpEnabled and Color3.fromRGB(50, 180, 50) or Color3.fromRGB(180, 50, 50)
        if localPlayer.Character then
            SetFlyJump(localPlayer.Character, FlyJumpEnabled)
        end
    end)


    -- [[ PLAYER TELEPORT SECTION (omitted for brevity, unchanged) ]] -- 
    local TeleportLabel = Instance.new("TextLabel")
    TeleportLabel.Size = UDim2.new(0, 260, 0, 20)
    TeleportLabel.Position = UDim2.new(0, 5, 0, 170)
    TeleportLabel.BackgroundTransparency = 1
    TeleportLabel.Text = "Teleport to Partial Username"
    TeleportLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
    TeleportLabel.Font = Enum.Font.GothamBold
    TeleportLabel.TextSize = 14
    TeleportLabel.Parent = ScrollFrame

    local TeleportTextBox = Instance.new("TextBox")
    TeleportTextBox.Size = UDim2.new(0, 140, 0, 30)
    TeleportTextBox.Position = UDim2.new(0, 5, 0, 195)
    TeleportTextBox.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
    TeleportTextBox.Text = "Type Partial Username"
    TeleportTextBox.PlaceholderText = "Type Partial Username"
    TeleportTextBox.TextColor3 = Color3.fromRGB(255, 255, 255)
    TeleportTextBox.Font = Enum.Font.Gotham
    TeleportTextBox.TextSize = 14
    TeleportTextBox.Parent = ScrollFrame
    addCorner(TeleportTextBox, 6)

    local TeleportExecuteBtn = Instance.new("TextButton")
    TeleportExecuteBtn.Size = UDim2.new(0, 115, 0, 30)
    TeleportExecuteBtn.Position = UDim2.new(0, 150, 0, 195)
    TeleportExecuteBtn.BackgroundColor3 = Color3.fromRGB(0, 150, 255)
    TeleportExecuteBtn.Text = "Teleport"
    TeleportExecuteBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    TeleportExecuteBtn.Font = Enum.Font.GothamBold
    TeleportExecuteBtn.TextSize = 14
    TeleportExecuteBtn.Parent = ScrollFrame
    addCorner(TeleportExecuteBtn, 6)

    TeleportExecuteBtn.MouseButton1Click:Connect(function()
        local targetName = TeleportTextBox.Text
        
        local targetPlayer = findPartialPlayer(targetName)

        if targetPlayer and targetPlayer.Character and localPlayer.Character then
            local hrp = localPlayer.Character:FindFirstChild("HumanoidRootPart")
            local targetHRP = targetPlayer.Character:FindFirstChild("HumanoidRootPart")

            if hrp and targetHRP then
                hrp.CFrame = targetHRP.CFrame * CFrame.new(0, 3, 0) 
            end
            TeleportTextBox.Text = "TP to: " .. targetPlayer.Name 
            task.wait(2)
            TeleportTextBox.Text = targetName
        else
            TeleportTextBox.Text = "Match not found!"
            task.wait(2)
            TeleportTextBox.Text = targetName
        end
    end)
    

    -- Sliders
    CreateSlider(UDim2.new(0, 5, 0, 250), "Speed/Jump Amount", BoostSpeed, function(val) BoostSpeed = val end)
    CreateSlider(UDim2.new(0, 5, 0, 310), "Hitbox Size", HeadSize, function(val) HeadSize = val end)

    -- Color Selection Area
    local colorLabel = Instance.new("TextLabel")
    colorLabel.Size = UDim2.new(0, 260, 0, 20)
    colorLabel.Position = UDim2.new(0, 5, 0, 370)
    colorLabel.BackgroundTransparency = 1
    colorLabel.Text = "ESP Color (If Team Check OFF)"
    colorLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
    colorLabel.Font = Enum.Font.GothamBold
    colorLabel.TextSize = 14
    colorLabel.Parent = ScrollFrame

    local dropdownColor = Instance.new("TextButton")
    dropdownColor.Size = UDim2.new(0, 260, 0, 30)
    dropdownColor.Position = UDim2.new(0, 5, 0, 395)
    dropdownColor.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
    dropdownColor.Text = "Select Color..."
    dropdownColor.TextColor3 = Color3.fromRGB(255, 255, 255)
    dropdownColor.Font = Enum.Font.GothamBold
    dropdownColor.TextSize = 14
    dropdownColor.Parent = ScrollFrame
    addCorner(dropdownColor, 6)

    local listFrameColor = Instance.new("Frame")
    listFrameColor.Size = UDim2.new(0, 260, 0, 0)
    listFrameColor.Position = UDim2.new(0, 0, 1, 5)
    listFrameColor.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
    listFrameColor.Parent = dropdownColor
    listFrameColor.ClipsDescendants = true
    listFrameColor.ZIndex = 20
    addCorner(listFrameColor, 6)

    local open = false
    dropdownColor.MouseButton1Click:Connect(function()
        open = not open
        listFrameColor.Size = open and UDim2.new(0, 260, 0, 175) or UDim2.new(0, 260, 0, 0)
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
        b.Parent = listFrameColor
        b.ZIndex = 21
        b.MouseButton1Click:Connect(function()
            HighlightColor = color
            dropdownColor.Text = "Color: " .. name
            if not TeamCheckEnabled then
                for _, p in ipairs(Players:GetPlayers()) do
                    if p ~= localPlayer then UpdateHighlight(p) end
                end
            end
            open = false
            listFrameColor.Size = UDim2.new(0, 260, 0, 0)
        end)
        i = i + 1
    end
end

if not gui then CreateGUI() end

-- [[ CONNECTION LOGIC ]] --
local function onCharacterAdded(char)
    OriginalCollides = {}
    if WallBreakEnabled then enableNoclipForCharacter(char) end
    
    -- Reapply FlyJump status if enabled
    if FlyJumpEnabled then SetFlyJump(char, true) end
    
    task.wait(1)
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= localPlayer then
            UpdateHighlight(p)
            UpdateHitbox(p)
            UpdateNameTag(p)
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

-- Main loop for movement and feature enforcement
RunService.RenderStepped:Connect(function()
    local char = localPlayer.Character
    
    if char then
        local hum = char:FindFirstChildOfClass("Humanoid")
        
        if hum then 
            -- Speed Logic (Applies when FlyJump is ON or OFF)
            hum.WalkSpeed = SpeedEnabled and BoostSpeed or 16 
        end
        
        -- FlyJump enforcement (if the character dies and respawns while toggle is active)
        if hum and FlyJumpEnabled then
            hum.JumpPower = 150
        end
    end

    -- Keep features persistent on other players
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= localPlayer then
            UpdateHighlight(player)
            UpdateHitbox(player)
            UpdateNameTag(player)
        end
    end
end)

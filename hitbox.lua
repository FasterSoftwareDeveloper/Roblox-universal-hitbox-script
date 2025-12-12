local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local localPlayer = Players.LocalPlayer

-- Configuration
local DefaultHRPSize = Vector3.new(2,2,1)
local HeadSize = 10
local BoostSpeed = 18
local DefaultJumpPower = 50 

-- Toggles
local ESPEnabled = true
local TeamCheckEnabled = false
local HitboxEnabled = true
local SpeedEnabled = false
local ClickTeleportEnabled = false
local WallBreakEnabled = false
local NameTagEnabled = false
local FlyJumpEnabled = false 
local AimbotEnabled = false
local ShowFOVCircle = true

-- Aimbot Settings
local AimbotFOV = 80 -- Reduced for better accuracy
local AimbotTargetPart = "Head"
local AimbotUsePrediction = true
local AimbotPredictionAmount = 0.15
local AimbotSmoothness = 0.4 -- Increased for smoother aim
local MaxTargetDistance = 300 -- Maximum distance to target (studs)
local AimbotMode = "Closest to Crosshair" -- Options: "Closest to Crosshair", "Closest Player"

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

-- FOV Circle
local FOVCircle = nil
local mouse = localPlayer:GetMouse()

-- Notification Helper
local function Notify(title, text, duration)
    pcall(function()
        game:GetService("StarterGui"):SetCore("SendNotification", {
            Title = title,
            Text = text,
            Duration = duration or 3
        })
    end)
end

Notify("Takbir's Script V7.3", "Fixed Aimbot - Distance Limit Added!", 5)

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

-- [[ FLY JUMP LOGIC ]] --
local function SetFlyJump(char, enabled)
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hum then return end
    if enabled then
        hum.JumpPower = 150 
    else
        hum.JumpPower = DefaultJumpPower
    end
end

-- [[ RESPAWN LOGIC ]] --
local function InstantRespawn()
    if localPlayer.Character then
        local hum = localPlayer.Character:FindFirstChildOfClass("Humanoid")
        if hum then hum.Health = 0 end
    end
end

-- [[ SPECTATE LOGIC ]] --
local function SpectatePlayer(targetPlayer)
    local cam = Workspace.CurrentCamera
    if targetPlayer and targetPlayer.Character and targetPlayer.Character:FindFirstChildOfClass("Humanoid") then
        cam.CameraSubject = targetPlayer.Character:FindFirstChildOfClass("Humanoid")
        Notify("Spectating", "Now watching: " .. targetPlayer.Name)
    else
        Notify("Error", "Target character not found!")
    end
end

local function StopSpectate()
    local cam = Workspace.CurrentCamera
    if localPlayer.Character and localPlayer.Character:FindFirstChildOfClass("Humanoid") then
        cam.CameraSubject = localPlayer.Character:FindFirstChildOfClass("Humanoid")
        Notify("Spectate", "Returned to your character.")
    end
end

-- [[ PARTIAL PLAYER FINDER ]] --
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

-- [[ FOV CIRCLE FUNCTIONS ]] --
local function CreateFOVCircle()
    if FOVCircle then FOVCircle:Destroy() end
    
    FOVCircle = Instance.new("ScreenGui")
    FOVCircle.Name = "FOVCircle"
    FOVCircle.ResetOnSpawn = false
    FOVCircle.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    FOVCircle.Parent = localPlayer:WaitForChild("PlayerGui")
    
    local frame = Instance.new("Frame")
    frame.Name = "Circle"
    frame.Size = UDim2.new(0, AimbotFOV * 2, 0, AimbotFOV * 2)
    frame.Position = UDim2.new(0.5, -AimbotFOV, 0.5, -AimbotFOV)
    frame.BackgroundTransparency = 1
    frame.BorderSizePixel = 0
    frame.Parent = FOVCircle
    
    local circle = Instance.new("UICorner")
    circle.CornerRadius = UDim.new(1, 0)
    circle.Parent = frame
    
    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.fromRGB(255, 105, 180)
    stroke.Thickness = 2
    stroke.Transparency = 0.5
    stroke.Parent = frame
    
    FOVCircle.Enabled = ShowFOVCircle and AimbotEnabled
    return FOVCircle
end

local function UpdateFOVCircle()
    if not FOVCircle then return end
    FOVCircle.Enabled = ShowFOVCircle and AimbotEnabled
    
    if FOVCircle and FOVCircle:FindFirstChild("Circle") then
        local circle = FOVCircle.Circle
        local size = AimbotFOV * 2
        circle.Size = UDim2.new(0, size, 0, size)
        circle.Position = UDim2.new(0.5, -AimbotFOV, 0.5, -AimbotFOV)
    end
end

-- [[ IMPROVED AIMBOT LOGIC WITH DISTANCE LIMIT ]] --
local function GetTargetPlayer()
    local closestPlayer = nil
    local closestScore = math.huge
    local camera = Workspace.CurrentCamera
    local cameraPos = camera.CFrame.Position
    
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= localPlayer and player.Character then
            local character = player.Character
            local humanoid = character:FindFirstChildOfClass("Humanoid")
            local targetPart = character:FindFirstChild(AimbotTargetPart) or character:FindFirstChild("HumanoidRootPart")
            
            -- Check if player is alive and has required parts
            if humanoid and humanoid.Health > 0 and targetPart then
                -- Calculate distance to player
                local distance = (cameraPos - targetPart.Position).Magnitude
                
                -- Skip if player is too far
                if distance > MaxTargetDistance then
                    continue
                end
                
                -- Check if player is visible on screen
                local screenPoint, onScreen = camera:WorldToViewportPoint(targetPart.Position)
                
                if onScreen then
                    local mousePos = Vector2.new(mouse.X, mouse.Y)
                    local targetPos = Vector2.new(screenPoint.X, screenPoint.Y)
                    local screenDistance = (mousePos - targetPos).Magnitude
                    
                    -- Calculate score based on selected mode
                    local score
                    if AimbotMode == "Closest to Crosshair" then
                        score = screenDistance -- Prioritize closest to crosshair
                    else -- "Closest Player"
                        score = distance -- Prioritize closest player by distance
                    end
                    
                    -- Only consider players within FOV
                    if screenDistance <= AimbotFOV then
                        if score < closestScore then
                            closestScore = score
                            closestPlayer = player
                        end
                    end
                end
            end
        end
    end
    
    return closestPlayer
end

local function GetAimbotTarget()
    if not AimbotEnabled then return nil, nil end
    local targetPlayer = GetTargetPlayer()
    
    if targetPlayer and targetPlayer.Character then
        local character = targetPlayer.Character
        local targetPart = character:FindFirstChild(AimbotTargetPart) or character:FindFirstChild("HumanoidRootPart")
        
        if targetPart then
            local predictedPosition = targetPart.Position
            
            -- IMPROVED PREDICTION SYSTEM
            if AimbotUsePrediction and targetPart:IsA("BasePart") then
                -- Get target's velocity
                local velocity = targetPart.Velocity
                
                -- Get humanoid movement for better prediction
                local humanoid = character:FindFirstChildOfClass("Humanoid")
                local moveDirection = Vector3.new(0, 0, 0)
                
                if humanoid then
                    moveDirection = humanoid.MoveDirection
                    
                    -- Combine velocity and move direction for better prediction
                    if moveDirection.Magnitude > 0 then
                        -- When humanoid is moving, use move direction more
                        velocity = velocity + (moveDirection * 10)
                    end
                end
                
                -- Calculate time to target based on distance
                local camera = Workspace.CurrentCamera
                local distance = (camera.CFrame.Position - targetPart.Position).Magnitude
                
                -- Dynamic prediction time based on distance
                local predictionTime = AimbotPredictionAmount * (distance / 100)
                
                -- Apply prediction
                predictedPosition = targetPart.Position + (velocity * predictionTime)
            end
            
            return predictedPosition, targetPlayer
        end
    end
    
    return nil, nil
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
                if part:IsA("BasePart") then safeSetCanCollide(part, false) end
            end
        end
    end)
end

local function disableNoclipForCharacter()
    if noclipRunConn then noclipRunConn:Disconnect() noclipRunConn = nil end
    if charDescAddedConn then charDescAddedConn:Disconnect() charDescAddedConn = nil end
    for part, orig in pairs(OriginalCollides) do
        if part and part.Parent then safeSetCanCollide(part, orig) end
    end
    OriginalCollides = {}
end

-- [[ VISUALS LOGIC ]] --
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
        if existingBillboard then existingBillboard:Destroy() end
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

-- [[ GUI CREATION ]] --
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
    gui.Name = "MVS_GUI_V7"
    gui.ResetOnSpawn = false
    gui.Parent = localPlayer:WaitForChild("PlayerGui")
    gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

    local MainContainer = Instance.new("Frame")
    MainContainer.Name = "MainContainer"
    MainContainer.Size = UDim2.new(0, 320, 0, 650) -- Increased height
    MainContainer.Position = UDim2.new(0, 10, 0, 50)
    MainContainer.BackgroundTransparency = 1
    MainContainer.Parent = gui

    local MinBtn = Instance.new("TextButton")
    MinBtn.Name = "MinimizeButton"
    MinBtn.Size = UDim2.new(0, 40, 0, 25)
    MinBtn.BackgroundColor3 = Color3.fromRGB(255, 200, 0)
    MinBtn.Text = "-"
    MinBtn.Font = Enum.Font.GothamBold
    MinBtn.TextScaled = true
    MinBtn.Parent = MainContainer
    MinBtn.ZIndex = 12
    addCorner(MinBtn, 6)

    local MainFrame = Instance.new("Frame")
    MainFrame.Name = "MainFrame"
    MainFrame.Size = UDim2.new(0, 280, 0, 610) -- Increased height
    MainFrame.Position = UDim2.new(0, 0, 0, 30)
    MainFrame.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
    MainFrame.Parent = MainContainer
    MainFrame.ClipsDescendants = true
    MainFrame.ZIndex = 10
    addCorner(MainFrame, 8)

    local dragArea = Instance.new("Frame")
    dragArea.Size = UDim2.new(1, 0, 0, 30)
    dragArea.BackgroundTransparency = 1
    dragArea.Parent = MainContainer
    dragArea.InputBegan:Connect(function(input) startDrag(input, MainContainer) end)
    UserInputService.InputChanged:Connect(function(input)
        if dragToggle and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            updateDrag(input)
        end
    end)

    local Title = Instance.new("TextLabel")
    Title.Size = UDim2.new(1, 0, 0, 35)
    Title.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
    Title.Text = "  Takbir's Panel v7.3 (Smart Aimbot)"
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
        MainContainer.Size = isMinimizing and UDim2.new(0, 40, 0, 25) or UDim2.new(0, 320, 0, 650)
    end)

    local ScrollFrame = Instance.new("ScrollingFrame")
    ScrollFrame.Size = UDim2.new(1, -10, 1, -45)
    ScrollFrame.Position = UDim2.new(0, 5, 0, 40)
    ScrollFrame.BackgroundTransparency = 1
    ScrollFrame.CanvasSize = UDim2.new(0, 0, 0, 1150) -- Increased canvas size
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
        lbl.TextXAlignment = Enum.TextXAlignment.Left
        lbl.Parent = frame
        local tb = Instance.new("TextBox")
        tb.Size = UDim2.new(1, 0, 0, 25)
        tb.Position = UDim2.new(0, 0, 0, 22)
        tb.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
        tb.TextColor3 = Color3.fromRGB(255, 255, 255)
        tb.Text = tostring(default)
        tb.Font = Enum.Font.Gotham
        tb.Parent = frame
        addCorner(tb, 6)
        tb.FocusLost:Connect(function()
            local val = tonumber(tb.Text)
            if val and val > 0 then 
                callback(val) 
                lbl.Text = labelText .. ": " .. val 
                UpdateFOVCircle()
            else 
                tb.Text = tostring(default) 
            end
        end)
    end

    local function CreateToggle(pos, text, default, onClick)
        local frame = Instance.new("Frame")
        frame.Size = UDim2.new(0, 260, 0, 40)
        frame.Position = pos
        frame.BackgroundTransparency = 1
        frame.Parent = ScrollFrame
        
        local lbl = Instance.new("TextLabel")
        lbl.Size = UDim2.new(0.7, 0, 1, 0)
        lbl.BackgroundTransparency = 1
        lbl.Text = text
        lbl.TextColor3 = Color3.fromRGB(200, 200, 200)
        lbl.Font = Enum.Font.Gotham
        lbl.TextXAlignment = Enum.TextXAlignment.Left
        lbl.Parent = frame
        
        local btn = Instance.new("TextButton")
        btn.Size = UDim2.new(0.3, -10, 1, 0)
        btn.Position = UDim2.new(0.7, 10, 0, 0)
        btn.BackgroundColor3 = default and Color3.fromRGB(50, 180, 50) or Color3.fromRGB(180, 50, 50)
        btn.Text = default and "ON" or "OFF"
        btn.TextColor3 = Color3.fromRGB(255, 255, 255)
        btn.Font = Enum.Font.GothamBold
        btn.TextSize = 14
        btn.Parent = frame
        addCorner(btn, 6)
        
        btn.MouseButton1Click:Connect(function()
            local newState = not (btn.Text == "ON")
            btn.Text = newState and "ON" or "OFF"
            btn.BackgroundColor3 = newState and Color3.fromRGB(50, 180, 50) or Color3.fromRGB(180, 50, 50)
            onClick(newState)
        end)
        
        return btn
    end

    -- [[ BUTTONS ]] --
    CreateButton(UDim2.new(0, 5, 0, 5), "Speed: OFF", Color3.fromRGB(180, 50, 50), function(b)
        SpeedEnabled = not SpeedEnabled
        b.Text = SpeedEnabled and "Speed: ON" or "Speed: OFF"
        b.BackgroundColor3 = SpeedEnabled and Color3.fromRGB(50, 180, 50) or Color3.fromRGB(180, 50, 50)
    end)
    CreateButton(UDim2.new(0, 140, 0, 5), "ESP: ON", Color3.fromRGB(50, 180, 50), function(b)
        ESPEnabled = not ESPEnabled
        b.Text = ESPEnabled and "ESP: ON" or "ESP: OFF"
        b.BackgroundColor3 = ESPEnabled and Color3.fromRGB(50, 180, 50) or Color3.fromRGB(180, 50, 50)
        for _, p in ipairs(Players:GetPlayers()) do if p ~= localPlayer then UpdateHighlight(p) end end
    end)

    CreateButton(UDim2.new(0, 5, 0, 45), "Hitbox: ON", Color3.fromRGB(50, 180, 50), function(b)
        HitboxEnabled = not HitboxEnabled
        b.Text = HitboxEnabled and "Hitbox: ON" or "Hitbox: OFF"
        b.BackgroundColor3 = HitboxEnabled and Color3.fromRGB(50, 180, 50) or Color3.fromRGB(180, 50, 50)
        for _, p in ipairs(Players:GetPlayers()) do if p ~= localPlayer then UpdateHitbox(p) end end
    end)
    CreateButton(UDim2.new(0, 140, 0, 45), "Click TP: OFF", Color3.fromRGB(100, 100, 100), function(b)
        ClickTeleportEnabled = not ClickTeleportEnabled
        b.Text = ClickTeleportEnabled and "Click TP: ON" or "Click TP: OFF"
        b.BackgroundColor3 = ClickTeleportEnabled and Color3.fromRGB(50, 180, 50) or Color3.fromRGB(100, 100, 100)
    end)

    CreateButton(UDim2.new(0, 5, 0, 85), "WallBreak: OFF", Color3.fromRGB(180, 50, 50), function(b)
        WallBreakEnabled = not WallBreakEnabled
        b.Text = WallBreakEnabled and "WallBreak: ON" or "WallBreak: OFF"
        b.BackgroundColor3 = WallBreakEnabled and Color3.fromRGB(50, 180, 50) or Color3.fromRGB(180, 50, 50)
        if WallBreakEnabled then enableNoclipForCharacter(localPlayer.Character) else disableNoclipForCharacter() end
    end)
    CreateButton(UDim2.new(0, 140, 0, 85), "Team Check: OFF", Color3.fromRGB(100, 100, 100), function(b)
        TeamCheckEnabled = not TeamCheckEnabled
        b.Text = TeamCheckEnabled and "Team Check: ON" or "Team Check: OFF"
        b.BackgroundColor3 = TeamCheckEnabled and Color3.fromRGB(0, 150, 255) or Color3.fromRGB(100, 100, 100)
        for _, p in ipairs(Players:GetPlayers()) do if p ~= localPlayer then UpdateHighlight(p) end end
    end)

    CreateButton(UDim2.new(0, 5, 0, 125), "Name Tag: OFF", Color3.fromRGB(100, 100, 100), function(b)
        NameTagEnabled = not NameTagEnabled
        b.Text = NameTagEnabled and "Name Tag: ON" or "Name Tag: OFF"
        b.BackgroundColor3 = NameTagEnabled and Color3.fromRGB(50, 180, 50) or Color3.fromRGB(100, 100, 100)
        for _, p in ipairs(Players:GetPlayers()) do if p ~= localPlayer then UpdateNameTag(p) end end
    end)
    CreateButton(UDim2.new(0, 140, 0, 125), "FlyJump: OFF", Color3.fromRGB(180, 50, 50), function(b)
        FlyJumpEnabled = not FlyJumpEnabled
        b.Text = FlyJumpEnabled and "FlyJump: ON" or "FlyJump: OFF"
        b.BackgroundColor3 = FlyJumpEnabled and Color3.fromRGB(50, 180, 50) or Color3.fromRGB(180, 50, 50)
        if localPlayer.Character then SetFlyJump(localPlayer.Character, FlyJumpEnabled) end
    end)

    -- AIMBOT BUTTON
    CreateButton(UDim2.new(0, 5, 0, 165), "Aimbot: OFF", Color3.fromRGB(180, 50, 50), function(b)
        AimbotEnabled = not AimbotEnabled
        b.Text = AimbotEnabled and "Aimbot: ON" or "Aimbot: OFF"
        b.BackgroundColor3 = AimbotEnabled and Color3.fromRGB(50, 180, 50) or Color3.fromRGB(180, 50, 50)
        UpdateFOVCircle()
        Notify("Aimbot", AimbotEnabled and "Enabled - Max Distance: " .. MaxTargetDistance .. " studs" or "Disabled")
    end)
    local RespawnBtn = CreateButton(UDim2.new(0, 140, 0, 165), "Respawn Character", Color3.fromRGB(200, 30, 30), function(b)
        InstantRespawn()
    end)

    -- [[ AIMBOT SETTINGS SECTION ]] --
    local AimbotLabel = Instance.new("TextLabel")
    AimbotLabel.Size = UDim2.new(0, 260, 0, 20)
    AimbotLabel.Position = UDim2.new(0, 5, 0, 210)
    AimbotLabel.BackgroundTransparency = 1
    AimbotLabel.Text = "Aimbot Settings"
    AimbotLabel.TextColor3 = Color3.fromRGB(255, 105, 180)
    AimbotLabel.Font = Enum.Font.GothamBold
    AimbotLabel.TextSize = 14
    AimbotLabel.Parent = ScrollFrame

    CreateSlider(UDim2.new(0, 5, 0, 235), "FOV Radius", AimbotFOV, function(val) 
        AimbotFOV = val 
        UpdateFOVCircle()
        Notify("Aimbot", "FOV set to: " .. val)
    end)

    -- FOV Circle Toggle
    CreateToggle(UDim2.new(0, 5, 0, 295), "Show FOV Circle", ShowFOVCircle, function(state)
        ShowFOVCircle = state
        UpdateFOVCircle()
        Notify("Aimbot", "FOV Circle: " .. (state and "ON" or "OFF"))
    end)

    -- Aimbot Mode Selection
    local modeLabel = Instance.new("TextLabel")
    modeLabel.Size = UDim2.new(0, 260, 0, 20)
    modeLabel.Position = UDim2.new(0, 5, 0, 340)
    modeLabel.BackgroundTransparency = 1
    modeLabel.Text = "Mode: " .. AimbotMode
    modeLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
    modeLabel.Font = Enum.Font.Gotham
    modeLabel.Parent = ScrollFrame

    local modeBtn = CreateButton(UDim2.new(0, 5, 0, 365), "Crosshair", Color3.fromRGB(60, 60, 60), function(b)
        if AimbotMode == "Closest to Crosshair" then
            AimbotMode = "Closest Player"
            b.Text = "Closest"
        else
            AimbotMode = "Closest to Crosshair"
            b.Text = "Crosshair"
        end
        modeLabel.Text = "Mode: " .. AimbotMode
        Notify("Aimbot", "Mode: " .. AimbotMode)
    end)
    modeBtn.Size = UDim2.new(0, 125, 0, 30)

    -- Max Distance Setting
    CreateSlider(UDim2.new(0, 5, 0, 410), "Max Distance", MaxTargetDistance, function(val) 
        MaxTargetDistance = val
        Notify("Aimbot", "Max Distance: " .. val .. " studs")
    end)

    local targetPartLabel = Instance.new("TextLabel")
    targetPartLabel.Size = UDim2.new(0, 260, 0, 20)
    targetPartLabel.Position = UDim2.new(0, 5, 0, 470)
    targetPartLabel.BackgroundTransparency = 1
    targetPartLabel.Text = "Target Part: " .. AimbotTargetPart
    targetPartLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
    targetPartLabel.Font = Enum.Font.Gotham
    targetPartLabel.Parent = ScrollFrame

    local targetPartBtn = CreateButton(UDim2.new(0, 5, 0, 495), "Head", Color3.fromRGB(60, 60, 60), function(b)
        AimbotTargetPart = b.Text == "Head" and "HumanoidRootPart" or "Head"
        b.Text = AimbotTargetPart
        targetPartLabel.Text = "Target Part: " .. AimbotTargetPart
        Notify("Aimbot", "Target part: " .. AimbotTargetPart)
    end)
    targetPartBtn.Size = UDim2.new(0, 125, 0, 30)

    CreateToggle(UDim2.new(0, 5, 0, 535), "Use Prediction", AimbotUsePrediction, function(state)
        AimbotUsePrediction = state
        Notify("Aimbot", "Prediction: " .. (state and "ON" or "OFF"))
    end)

    CreateSlider(UDim2.new(0, 5, 0, 580), "Prediction Amount", AimbotPredictionAmount * 100, function(val) 
        AimbotPredictionAmount = val / 100
    end)

    CreateSlider(UDim2.new(0, 5, 0, 640), "Aim Smoothness", AimbotSmoothness * 100, function(val) 
        AimbotSmoothness = val / 100
    end)

    -- [[ TELEPORT SECTION ]] --
    local TeleportLabel = Instance.new("TextLabel")
    TeleportLabel.Size = UDim2.new(0, 260, 0, 20)
    TeleportLabel.Position = UDim2.new(0, 5, 0, 700)
    TeleportLabel.BackgroundTransparency = 1
    TeleportLabel.Text = "Teleport System"
    TeleportLabel.TextColor3 = Color3.fromRGB(0, 255, 255)
    TeleportLabel.Font = Enum.Font.GothamBold
    TeleportLabel.TextSize = 14
    TeleportLabel.Parent = ScrollFrame

    local TeleportTextBox = Instance.new("TextBox")
    TeleportTextBox.Size = UDim2.new(0, 140, 0, 30)
    TeleportTextBox.Position = UDim2.new(0, 5, 0, 725)
    TeleportTextBox.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
    TeleportTextBox.Text = ""
    TeleportTextBox.PlaceholderText = "Username"
    TeleportTextBox.TextColor3 = Color3.fromRGB(255, 255, 255)
    TeleportTextBox.Parent = ScrollFrame
    addCorner(TeleportTextBox, 6)

    local TeleportExecuteBtn = CreateButton(UDim2.new(0, 150, 0, 725), "Teleport", Color3.fromRGB(0, 150, 255), function(b)
        local target = findPartialPlayer(TeleportTextBox.Text)
        if target and target.Character and localPlayer.Character then
            local hrp = localPlayer.Character:FindFirstChild("HumanoidRootPart")
            local thrp = target.Character:FindFirstChild("HumanoidRootPart")
            if hrp and thrp then 
                hrp.CFrame = thrp.CFrame * CFrame.new(0, 3, 0) 
                Notify("Teleport Success", "Teleported to: " .. target.Name, 3) 
            else
                Notify("Teleport Failed", "Target player's character is not fully loaded/found.", 3)
            end
        else
            Notify("Teleport Failed", "Player '" .. TeleportTextBox.Text .. "' not found.", 3)
        end
    end)
    TeleportExecuteBtn.Size = UDim2.new(0, 115, 0, 30)

    -- [[ SPECTATE SECTION ]] --
    local SpecLabel = Instance.new("TextLabel")
    SpecLabel.Size = UDim2.new(0, 260, 0, 20)
    SpecLabel.Position = UDim2.new(0, 5, 0, 765)
    SpecLabel.BackgroundTransparency = 1
    SpecLabel.Text = "Spectate Player"
    SpecLabel.TextColor3 = Color3.fromRGB(255, 200, 0)
    SpecLabel.Font = Enum.Font.GothamBold
    SpecLabel.TextSize = 14
    SpecLabel.Parent = ScrollFrame

    local SpecTextBox = Instance.new("TextBox")
    SpecTextBox.Size = UDim2.new(0, 260, 0, 30)
    SpecTextBox.Position = UDim2.new(0, 5, 0, 790)
    SpecTextBox.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
    SpecTextBox.Text = ""
    SpecTextBox.PlaceholderText = "Type Partial Username..."
    SpecTextBox.TextColor3 = Color3.fromRGB(255, 255, 255)
    SpecTextBox.Parent = ScrollFrame
    addCorner(SpecTextBox, 6)

    local StartSpecBtn = CreateButton(UDim2.new(0, 5, 0, 825), "Spectate", Color3.fromRGB(50, 180, 50), function(b)
        local target = findPartialPlayer(SpecTextBox.Text)
        if target then SpectatePlayer(target) else Notify("Error", "Player not found.", 3) end
    end)
    local StopSpecBtn = CreateButton(UDim2.new(0, 140, 0, 825), "Stop Spectate", Color3.fromRGB(180, 50, 50), function(b)
        StopSpectate()
    end)

    -- [[ SLIDERS & COLORS ]] --
    CreateSlider(UDim2.new(0, 5, 0, 875), "Speed/Jump Amount", BoostSpeed, function(val) BoostSpeed = val end)
    CreateSlider(UDim2.new(0, 5, 0, 935), "Hitbox Size", HeadSize, function(val) HeadSize = val end)

    local colorLabel = Instance.new("TextLabel")
    colorLabel.Size = UDim2.new(0, 260, 0, 20)
    colorLabel.Position = UDim2.new(0, 5, 0, 995)
    colorLabel.BackgroundTransparency = 1
    colorLabel.Text = "ESP Color"
    colorLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
    colorLabel.Font = Enum.Font.GothamBold
    colorLabel.Parent = ScrollFrame

    local dropdownColor = Instance.new("TextButton")
    dropdownColor.Size = UDim2.new(0, 260, 0, 30)
    dropdownColor.Position = UDim2.new(0, 5, 0, 1020)
    dropdownColor.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
    dropdownColor.Text = "Select Color..."
    dropdownColor.TextColor3 = Color3.fromRGB(255, 255, 255)
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
        b.Parent = listFrameColor
        b.ZIndex = 21
        b.MouseButton1Click:Connect(function()
            HighlightColor = color
            dropdownColor.Text = "Color: " .. name
            if not TeamCheckEnabled then
                for _, p in ipairs(Players:GetPlayers()) do if p ~= localPlayer then UpdateHighlight(p) end end
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

mouse = localPlayer:GetMouse()
mouse.Button1Down:Connect(function()
    if ClickTeleportEnabled and localPlayer.Character then
        local hrp = localPlayer.Character:FindFirstChild("HumanoidRootPart")
        if hrp then hrp.CFrame = CFrame.new(mouse.Hit.Position + Vector3.new(0, 3, 0)) end
    end
end)

-- Create FOV Circle
task.spawn(function()
    task.wait(1)
    CreateFOVCircle()
end)

-- [[ SMART AIMBOT IMPLEMENTATION ]] --
local aimbotConnection = RunService.RenderStepped:Connect(function()
    -- Update character stats
    local char = localPlayer.Character
    if char then
        local hum = char:FindFirstChildOfClass("Humanoid")
        if hum then 
            hum.WalkSpeed = SpeedEnabled and BoostSpeed or 16 
        end
        if hum and FlyJumpEnabled then 
            hum.JumpPower = 150 
        end
    end
    
    -- Update visuals
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= localPlayer then
            UpdateHighlight(player)
            UpdateHitbox(player)
            UpdateNameTag(player)
        end
    end
    
    -- Smart Aimbot functionality
    if AimbotEnabled and localPlayer.Character then
        local targetPos, targetPlayer = GetAimbotTarget()
        if targetPos and targetPlayer then
            local camera = Workspace.CurrentCamera
            local currentCFrame = camera.CFrame
            
            -- Calculate direction to target
            local direction = (targetPos - currentCFrame.Position).Unit
            
            -- Create target CFrame
            local targetCFrame = CFrame.new(currentCFrame.Position, currentCFrame.Position + direction)
            
            -- Smooth aiming
            camera.CFrame = currentCFrame:Lerp(targetCFrame, AimbotSmoothness)
            
            -- Optional: Auto fire when target is locked
            if UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) then
                local character = localPlayer.Character
                if character then
                    local tool = character:FindFirstChildWhichIsA("Tool")
                    if tool then
                        pcall(function()
                            tool:Activate()
                        end)
                    end
                end
            end
        end
    end
    
    -- Update FOV Circle position
    if FOVCircle and FOVCircle:FindFirstChild("Circle") then
        local circle = FOVCircle.Circle
        circle.Position = UDim2.new(0.5, -AimbotFOV, 0.5, -AimbotFOV)
    end
end)

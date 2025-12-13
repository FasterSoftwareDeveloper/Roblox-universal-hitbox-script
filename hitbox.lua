local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local StarterGui = game:GetService("StarterGui")
local TweenService = game:GetService("TweenService")
local localPlayer = Players.LocalPlayer

-- Ban System (Backend Control)
local BannedUsers = {
    "rip_idar1493",
}

-- Check if player is banned
if table.find(BannedUsers, localPlayer.Name) then
    localPlayer:Kick("You are banned from using Takbir's Script.\nContact owner for appeal.")
    return
end

-- Configuration
local DefaultHRPSize = Vector3.new(2,2,1)
local HeadSize = 10
local BoostSpeed = 19
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
local XrayEnabled = false
local FollowingPlayer = false
local FollowTarget = nil
local FollowConnection = nil

-- Aimbot Settings (FIXED)
local AimbotFOV = 80
local AimbotTargetPart = "Head"
local AimbotUsePrediction = true
local AimbotPredictionAmount = 0.17
local AimbotSmoothness = 0.60
local MaxTargetDistance = 300
local AimbotMode = "Closest to Crosshair" -- Options: "Closest to Crosshair", "Closest Player", "Perfect Aim", "AI Power"
local AimbotAIPower = false
local PerfectAim = false
local PerfectMovement = false
local CurrentAimbotTarget = nil
local LastTargetUpdate = 0

-- FlyJump Settings
local FlyJumpPower = 150

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

-- Xray Variables
local OriginalTransparencies = {}
local XrayConnection = nil

-- Physics / WallBreak Variables
local OriginalCollides = {}
local noclipRunConn = nil
local charDescAddedConn = nil

-- Notification Helper
local function Notify(title, text, duration)
    pcall(function()
        StarterGui:SetCore("SendNotification", {
            Title = title,
            Text = text,
            Duration = duration or 3
        })
    end)
end

Notify("Takbir's Script V10.0", "Keyboard Controls:\nT = GUI | R = Aimbot | V = Unlock Mouse\nFixed Aimbot Features!", 5)

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

-- [[ FIXED X-RAY SYSTEM ]] --
local function enableXray()
    if XrayConnection then XrayConnection:Disconnect() end
    
    OriginalTransparencies = {}
    
    -- Store original transparencies and apply X-ray
    for _, part in ipairs(Workspace:GetDescendants()) do
        if part:IsA("BasePart") and part.Transparency < 0.95 then
            if not OriginalTransparencies[part] then
                OriginalTransparencies[part] = {
                    Transparency = part.Transparency,
                    LocalTransparencyModifier = part.LocalTransparencyModifier
                }
            end
            
            -- Make walls semi-transparent (only if they're not player parts)
            if not part:IsDescendantOf(localPlayer.Character) then
                local isPlayerPart = false
                for _, player in ipairs(Players:GetPlayers()) do
                    if player.Character and part:IsDescendantOf(player.Character) then
                        isPlayerPart = true
                        break
                    end
                end
                
                if not isPlayerPart then
                    part.LocalTransparencyModifier = 0.7
                end
            end
        end
    end
    
    -- Monitor for new parts
    XrayConnection = Workspace.DescendantAdded:Connect(function(descendant)
        if XrayEnabled and descendant:IsA("BasePart") and descendant.Transparency < 0.95 then
            if not OriginalTransparencies[descendant] then
                OriginalTransparencies[descendant] = {
                    Transparency = descendant.Transparency,
                    LocalTransparencyModifier = descendant.LocalTransparencyModifier
                }
            end
            
            local isPlayerPart = false
            for _, player in ipairs(Players:GetPlayers()) do
                if player.Character and descendant:IsDescendantOf(player.Character) then
                    isPlayerPart = true
                    break
                end
            end
            
            if not isPlayerPart then
                descendant.LocalTransparencyModifier = 0.7
            end
        end
    end)
end

local function disableXray()
    if XrayConnection then 
        XrayConnection:Disconnect() 
        XrayConnection = nil
    end
    
    -- Restore original transparency settings
    for part, origValues in pairs(OriginalTransparencies) do
        if part and part.Parent then
            pcall(function()
                part.LocalTransparencyModifier = origValues.LocalTransparencyModifier
            end)
        end
    end
    
    OriginalTransparencies = {}
end

local function UnlockMouse()
    if UserInputService.MouseBehavior == Enum.MouseBehavior.LockCenter or
       UserInputService.MouseBehavior == Enum.MouseBehavior.LockCurrentPosition then
        UserInputService.MouseBehavior = Enum.MouseBehavior.Default
        UserInputService.MouseIconEnabled = true
        Notify("Mouse", "Mouse Unlocked (V)", 2)
    end
end

-- [[ FOLLOW PLAYER FEATURE ]] --
local function StartFollowing(player)
    if FollowConnection then 
        FollowConnection:Disconnect()
        FollowConnection = nil
    end
    
    FollowingPlayer = true
    FollowTarget = player
    
    Notify("Follow", "Now following: " .. player.Name, 3)
    
    FollowConnection = RunService.Heartbeat:Connect(function()
        if not FollowingPlayer or not FollowTarget or not localPlayer.Character then 
            return 
        end
        
        local targetChar = FollowTarget.Character
        local localChar = localPlayer.Character
        
        if targetChar and localChar then
            local targetHRP = targetChar:FindFirstChild("HumanoidRootPart")
            local localHRP = localChar:FindFirstChild("HumanoidRootPart")
            local localHumanoid = localChar:FindFirstChildOfClass("Humanoid")
            
            if targetHRP and localHRP and localHumanoid and localHumanoid.Health > 0 then
                -- Calculate distance
                local distance = (targetHRP.Position - localHRP.Position).Magnitude
                
                -- If too far, teleport closer
                if distance > 50 then
                    localHRP.CFrame = CFrame.new(targetHRP.Position + Vector3.new(0, 5, 0))
                -- If within range, walk towards
                elseif distance > 5 then
                    localHumanoid:MoveTo(targetHRP.Position)
                end
            end
        end
    end)
end

local function StopFollowing()
    if FollowConnection then 
        FollowConnection:Disconnect()
        FollowConnection = nil
    end
    
    FollowingPlayer = false
    FollowTarget = nil
    
    Notify("Follow", "Stopped following", 3)
end

-- [[ FLY JUMP LOGIC ]] --
local function SetFlyJump(char, enabled)
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hum then return end
    if enabled then
        hum.JumpPower = FlyJumpPower
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
    FOVCircle.DisplayOrder = 99999
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

-- [[ FIXED AIMBOT SYSTEM - ALL MODES WORKING ]] --
local function IsValidTarget(player, camera, cameraPos)
    if player == localPlayer then return false end
    if not player.Character then return false end
    
    local character = player.Character
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if not humanoid or humanoid.Health <= 0 then return false end
    
    local targetPart = character:FindFirstChild(AimbotTargetPart) or character:FindFirstChild("HumanoidRootPart")
    if not targetPart then return false end
    
    local distance = (cameraPos - targetPart.Position).Magnitude
    if distance > MaxTargetDistance then return false end
    
    local screenPoint, onScreen = camera:WorldToViewportPoint(targetPart.Position)
    if not onScreen then return false end
    
    return true, targetPart, distance, screenPoint
end

local function GetClosestToCrosshair()
    local camera = Workspace.CurrentCamera
    local cameraPos = camera.CFrame.Position
    local mousePos = Vector2.new(mouse.X, mouse.Y)
    local bestPlayer = nil
    local bestScore = math.huge
    
    for _, player in ipairs(Players:GetPlayers()) do
        local valid, targetPart, distance, screenPoint = IsValidTarget(player, camera, cameraPos)
        if valid then
            local targetScreenPos = Vector2.new(screenPoint.X, screenPoint.Y)
            local screenDistance = (mousePos - targetScreenPos).Magnitude
            
            if screenDistance <= AimbotFOV then
                local score = screenDistance
                if score < bestScore then
                    bestScore = score
                    bestPlayer = player
                end
            end
        end
    end
    
    return bestPlayer
end

local function GetClosestPlayer()
    local camera = Workspace.CurrentCamera
    local cameraPos = camera.CFrame.Position
    local bestPlayer = nil
    local closestDistance = math.huge
    
    for _, player in ipairs(Players:GetPlayers()) do
        local valid, targetPart, distance, screenPoint = IsValidTarget(player, camera, cameraPos)
        if valid then
            local mousePos = Vector2.new(mouse.X, mouse.Y)
            local targetScreenPos = Vector2.new(screenPoint.X, screenPoint.Y)
            local screenDistance = (mousePos - targetScreenPos).Magnitude
            
            if screenDistance <= AimbotFOV then
                if distance < closestDistance then
                    closestDistance = distance
                    bestPlayer = player
                end
            end
        end
    end
    
    return bestPlayer
end

local function GetPerfectAimTarget()
    local camera = Workspace.CurrentCamera
    local cameraPos = camera.CFrame.Position
    local bestPlayer = nil
    local highestPriority = -math.huge
    
    for _, player in ipairs(Players:GetPlayers()) do
        local valid, targetPart, distance, screenPoint = IsValidTarget(player, camera, cameraPos)
        if valid then
            -- Perfect Aim: Always target regardless of FOV
            local mousePos = Vector2.new(mouse.X, mouse.Y)
            local targetScreenPos = Vector2.new(screenPoint.X, screenPoint.Y)
            local screenDistance = (mousePos - targetScreenPos).Magnitude
            
            -- Calculate priority based on multiple factors
            local priority = 0
            
            -- Distance priority (closer = higher priority)
            priority = priority + (MaxTargetDistance - distance) * 0.5
            
            -- Health priority (lower health = higher priority)
            local humanoid = player.Character:FindFirstChildOfClass("Humanoid")
            if humanoid then
                priority = priority + (100 - humanoid.Health) * 2
            end
            
            -- Screen position priority (closer to crosshair = higher priority)
            if screenDistance <= AimbotFOV then
                priority = priority + (AimbotFOV - screenDistance) * 3
            end
            
            if priority > highestPriority then
                highestPriority = priority
                bestPlayer = player
            end
        end
    end
    
    return bestPlayer
end

local function GetAIPowerTarget()
    local camera = Workspace.CurrentCamera
    local cameraPos = camera.CFrame.Position
    local mousePos = Vector2.new(mouse.X, mouse.Y)
    local bestPlayer = nil
    local highestAIScore = -math.huge
    
    for _, player in ipairs(Players:GetPlayers()) do
        local valid, targetPart, distance, screenPoint = IsValidTarget(player, camera, cameraPos)
        if valid then
            local targetScreenPos = Vector2.new(screenPoint.X, screenPoint.Y)
            local screenDistance = (mousePos - targetScreenPos).Magnitude
            
            -- AI Power Scoring System
            local aiScore = 0
            
            -- 1. Screen Distance Score (closer to crosshair = higher score)
            if screenDistance <= AimbotFOV then
                aiScore = aiScore + (AimbotFOV - screenDistance) * 5
            else
                aiScore = aiScore - 50  -- Penalty for being outside FOV
            end
            
            -- 2. Distance Score (closer = higher score)
            aiScore = aiScore + (MaxTargetDistance - distance) * 0.3
            
            -- 3. Health Score (lower health = higher score)
            local humanoid = player.Character:FindFirstChildOfClass("Humanoid")
            if humanoid then
                aiScore = aiScore + (100 - humanoid.Health) * 2
            end
            
            -- 4. Movement-based score (if target is moving predictably)
            if targetPart.Velocity.Magnitude > 5 then
                -- Bonus for moving targets (easier to predict)
                aiScore = aiScore + 15
            end
            
            -- 5. Headshot bonus if targeting head
            if AimbotTargetPart == "Head" and player.Character:FindFirstChild("Head") then
                aiScore = aiScore + 10
            end
            
            if aiScore > highestAIScore then
                highestAIScore = aiScore
                bestPlayer = player
            end
        end
    end
    
    return bestPlayer
end

local function GetTargetPlayer()
    local target = nil
    
    if AimbotMode == "Closest to Crosshair" then
        target = GetClosestToCrosshair()
    elseif AimbotMode == "Closest Player" then
        target = GetClosestPlayer()
    elseif AimbotMode == "Perfect Aim" then
        target = GetPerfectAimTarget()
    elseif AimbotMode == "AI Power" then
        target = GetAIPowerTarget()
    end
    
    -- If we have a target, store it
    if target and target ~= CurrentAimbotTarget then
        CurrentAimbotTarget = target
        LastTargetUpdate = tick()
    elseif not target then
        CurrentAimbotTarget = nil
    end
    
    return target
end

local function GetAimbotTarget()
    if not AimbotEnabled or not localPlayer.Character then return nil, nil end
    
    local targetPlayer = GetTargetPlayer()
    
    if targetPlayer and targetPlayer.Character then
        local character = targetPlayer.Character
        local targetPart = character:FindFirstChild(AimbotTargetPart) or character:FindFirstChild("HumanoidRootPart")
        
        if targetPart then
            local predictedPosition = targetPart.Position
            
            if AimbotUsePrediction and targetPart:IsA("BasePart") then
                local velocity = targetPart.Velocity
                local humanoid = character:FindFirstChildOfClass("Humanoid")
                
                if humanoid and humanoid.MoveDirection.Magnitude > 0 then
                    velocity = velocity + (humanoid.MoveDirection * 12)
                end
                
                local camera = Workspace.CurrentCamera
                local distance = (camera.CFrame.Position - targetPart.Position).Magnitude
                local predictionTime = AimbotPredictionAmount * (distance / 100)
                
                if PerfectMovement then
                    -- Enhanced prediction for Perfect Movement mode
                    predictionTime = predictionTime * 1.5
                end
                
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

-- [[ ESP/HITBOX SYSTEM ]] --
local function IsTeammate(player)
    if not TeamCheckEnabled then return false end
    if not localPlayer.Team or not player.Team then return false end
    return localPlayer.Team == player.Team
end

local function UpdateHighlight(player)
    local char = player.Character
    if not char then return end
    
    local existing = char:FindFirstChild("OutlineESP")
    
    if ESPEnabled then
        local useColor = HighlightColor
        
        if TeamCheckEnabled then
            if IsTeammate(player) then
                useColor = Color3.fromRGB(0, 255, 0) -- Green for teammates
            else
                useColor = Color3.fromRGB(255, 0, 0) -- Red for enemies
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
    -- Skip teammates when TeamCheck is enabled
    if TeamCheckEnabled and IsTeammate(player) then
        local char = player.Character
        if char and char:FindFirstChild("HumanoidRootPart") then
            local hrp = char.HumanoidRootPart
            local box = hrp:FindFirstChild("HitboxOutline")
            if box then box:Destroy() end
            hrp.Size = DefaultHRPSize
        end
        return
    end
    
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
                box.LineThickness = 0.1
                box.Color3 = Color3.fromRGB(0,120,255)
                box.Transparency = 0
                box.SurfaceTransparency = 1
            else
                box.LineThickness = 0.1
                box.Color3 = Color3.fromRGB(0,120,255)
                box.Transparency = 0
                box.SurfaceTransparency = 1
            end
            
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
    gui.Name = "MVS_GUI_V10"
    gui.ResetOnSpawn = false
    gui.Parent = localPlayer:WaitForChild("PlayerGui")
    gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

    local MainContainer = Instance.new("Frame")
    MainContainer.Name = "MainContainer"
    MainContainer.Size = UDim2.new(0, 350, 0, 650)
    MainContainer.Position = UDim2.new(0, 10, 0, 50)
    MainContainer.BackgroundTransparency = 1
    MainContainer.Parent = gui

    local MinBtn = Instance.new("TextButton")
    MinBtn.Name = "MinimizeButton"
    MinBtn.Size = UDim2.new(0, 40, 0, 30)
    MinBtn.BackgroundColor3 = Color3.fromRGB(255, 200, 0)
    MinBtn.Text = "-"
    MinBtn.Font = Enum.Font.GothamBold
    MinBtn.TextScaled = true
    MinBtn.TextSize = 18
    MinBtn.Parent = MainContainer
    MinBtn.ZIndex = 12
    addCorner(MinBtn, 6)

    local MainFrame = Instance.new("Frame")
    MainFrame.Name = "MainFrame"
    MainFrame.Size = UDim2.new(0, 310, 0, 610)
    MainFrame.Position = UDim2.new(0, 0, 0, 35)
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
    Title.Size = UDim2.new(1, 0, 0, 40)
    Title.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
    Title.Text = "  Takbir's Panel v10.0 (Ai Aimbot)"
    Title.TextColor3 = Color3.fromRGB(255, 255, 255)
    Title.TextXAlignment = Enum.TextXAlignment.Left
    Title.TextSize = 20
    Title.Font = Enum.Font.GothamBold
    Title.Parent = MainFrame
    Title.InputBegan:Connect(function(input) startDrag(input, MainContainer) end)
    
    MinBtn.MouseButton1Click:Connect(function()
        isMinimizing = not isMinimizing
        MainFrame.Visible = not isMinimizing
        MinBtn.Text = isMinimizing and "+" or "-"
        MainContainer.Size = isMinimizing and UDim2.new(0, 40, 0, 30) or UDim2.new(0, 350, 0, 650)
    end)

    -- SCROLLINGFRAME
    local ScrollFrame = Instance.new("ScrollingFrame")
    ScrollFrame.Size = UDim2.new(1, -10, 1, -50)
    ScrollFrame.Position = UDim2.new(0, 5, 0, 45)
    ScrollFrame.BackgroundTransparency = 1
    ScrollFrame.CanvasSize = UDim2.new(0, 0, 0, 2500)
    ScrollFrame.ScrollBarThickness = 8
    ScrollFrame.ScrollingEnabled = true
    ScrollFrame.VerticalScrollBarInset = Enum.ScrollBarInset.Always
    ScrollFrame.Parent = MainFrame

    -- [[ KEYBOARD CONTROLS INFO ]] --
    local ControlsInfo = Instance.new("TextLabel")
    ControlsInfo.Size = UDim2.new(0, 290, 0, 50)
    ControlsInfo.Position = UDim2.new(0, 5, 0, 5)
    ControlsInfo.BackgroundColor3 = Color3.fromRGB(30, 30, 50)
    ControlsInfo.Text = "🎮 KEYBOARD CONTROLS:\nT = GUI | R = Aimbot | V = Unlock Mouse"
    ControlsInfo.TextColor3 = Color3.fromRGB(0, 255, 255)
    ControlsInfo.Font = Enum.Font.GothamBold
    ControlsInfo.TextSize = 14
    ControlsInfo.TextWrapped = true
    ControlsInfo.Parent = ScrollFrame
    addCorner(ControlsInfo, 6)

    local function CreateButton(pos, text, color, onClick)
        local btn = Instance.new("TextButton")
        btn.Size = UDim2.new(0, 145, 0, 40)
        btn.Position = pos
        btn.BackgroundColor3 = color
        btn.Text = text
        btn.TextColor3 = Color3.fromRGB(255, 255, 255)
        btn.Font = Enum.Font.GothamBold
        btn.TextSize = 16
        btn.Parent = ScrollFrame
        addCorner(btn, 6)
        btn.MouseButton1Click:Connect(function() onClick(btn) end)
        return btn
    end

    local function CreateSlider(pos, labelText, default, callback)
        local frame = Instance.new("Frame")
        frame.Size = UDim2.new(0, 290, 0, 60)
        frame.Position = pos
        frame.BackgroundTransparency = 1
        frame.Parent = ScrollFrame
        
        local lbl = Instance.new("TextLabel")
        lbl.Size = UDim2.new(1, 0, 0, 25)
        lbl.BackgroundTransparency = 1
        lbl.Text = labelText .. ": " .. default
        lbl.TextColor3 = Color3.fromRGB(200, 200, 200)
        lbl.Font = Enum.Font.Gotham
        lbl.TextSize = 15
        lbl.TextXAlignment = Enum.TextXAlignment.Left
        lbl.Parent = frame
        
        local tb = Instance.new("TextBox")
        tb.Size = UDim2.new(1, 0, 0, 30)
        tb.Position = UDim2.new(0, 0, 0, 27)
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
                if labelText == "FOV Radius" then
                    UpdateFOVCircle()
                end
            else 
                tb.Text = tostring(default) 
            end
        end)
        return frame
    end

    local function CreateToggle(pos, text, default, onClick)
        local frame = Instance.new("Frame")
        frame.Size = UDim2.new(0, 290, 0, 45)
        frame.Position = pos
        frame.BackgroundTransparency = 1
        frame.Parent = ScrollFrame
        
        local lbl = Instance.new("TextLabel")
        lbl.Size = UDim2.new(0.7, 0, 1, 0)
        lbl.BackgroundTransparency = 1
        lbl.Text = text
        lbl.TextColor3 = Color3.fromRGB(200, 200, 200)
        lbl.Font = Enum.Font.Gotham
        lbl.TextSize = 15
        lbl.TextXAlignment = Enum.TextXAlignment.Left
        lbl.Parent = frame
        
        local btn = Instance.new("TextButton")
        btn.Size = UDim2.new(0.3, -10, 1, 0)
        btn.Position = UDim2.new(0.7, 10, 0, 0)
        btn.BackgroundColor3 = default and Color3.fromRGB(50, 180, 50) or Color3.fromRGB(180, 50, 50)
        btn.Text = default and "ON" or "OFF"
        btn.TextColor3 = Color3.fromRGB(255, 255, 255)
        btn.Font = Enum.Font.GothamBold
        btn.TextSize = 15
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

    -- [[ MAIN BUTTONS ]] --
    CreateButton(UDim2.new(0, 5, 0, 65), "Speed: OFF", Color3.fromRGB(180, 50, 50), function(b)
        SpeedEnabled = not SpeedEnabled
        b.Text = SpeedEnabled and "Speed: ON" or "Speed: OFF"
        b.BackgroundColor3 = SpeedEnabled and Color3.fromRGB(50, 180, 50) or Color3.fromRGB(180, 50, 50)
    end)
    
    CreateButton(UDim2.new(0, 155, 0, 65), "ESP: ON", Color3.fromRGB(50, 180, 50), function(b)
        ESPEnabled = not ESPEnabled
        b.Text = ESPEnabled and "ESP: ON" or "ESP: OFF"
        b.BackgroundColor3 = ESPEnabled and Color3.fromRGB(50, 180, 50) or Color3.fromRGB(180, 50, 50)
        for _, p in ipairs(Players:GetPlayers()) do if p ~= localPlayer then UpdateHighlight(p) end end
    end)

    CreateButton(UDim2.new(0, 5, 0, 110), "Hitbox: ON", Color3.fromRGB(50, 180, 50), function(b)
        HitboxEnabled = not HitboxEnabled
        b.Text = HitboxEnabled and "Hitbox: ON" or "Hitbox: OFF"
        b.BackgroundColor3 = HitboxEnabled and Color3.fromRGB(50, 180, 50) or Color3.fromRGB(180, 50, 50)
        for _, p in ipairs(Players:GetPlayers()) do if p ~= localPlayer then UpdateHitbox(p) end end
    end)
    CreateButton(UDim2.new(0, 155, 0, 110), "Click TP: OFF", Color3.fromRGB(100, 100, 100), function(b)
        ClickTeleportEnabled = not ClickTeleportEnabled
        b.Text = ClickTeleportEnabled and "Click TP: ON" or "Click TP: OFF"
        b.BackgroundColor3 = ClickTeleportEnabled and Color3.fromRGB(50, 180, 50) or Color3.fromRGB(100, 100, 100)
    end)

    CreateButton(UDim2.new(0, 5, 0, 155), "WallBreak: OFF", Color3.fromRGB(180, 50, 50), function(b)
        WallBreakEnabled = not WallBreakEnabled
        b.Text = WallBreakEnabled and "WallBreak: ON" or "WallBreak: OFF"
        b.BackgroundColor3 = WallBreakEnabled and Color3.fromRGB(50, 180, 50) or Color3.fromRGB(180, 50, 50)
        if WallBreakEnabled then enableNoclipForCharacter(localPlayer.Character) else disableNoclipForCharacter() end
    end)
    CreateButton(UDim2.new(0, 155, 0, 155), "Team Check: OFF", Color3.fromRGB(100, 100, 100), function(b)
        TeamCheckEnabled = not TeamCheckEnabled
        b.Text = TeamCheckEnabled and "Team Check: ON" or "Team Check: OFF"
        b.BackgroundColor3 = TeamCheckEnabled and Color3.fromRGB(0, 150, 255) or Color3.fromRGB(100, 100, 100)
        for _, p in ipairs(Players:GetPlayers()) do if p ~= localPlayer then UpdateHighlight(p); UpdateHitbox(p) end end
    end)

    CreateButton(UDim2.new(0, 5, 0, 200), "Name Tag: OFF", Color3.fromRGB(100, 100, 100), function(b)
        NameTagEnabled = not NameTagEnabled
        b.Text = NameTagEnabled and "Name Tag: ON" or "Name Tag: OFF"
        b.BackgroundColor3 = NameTagEnabled and Color3.fromRGB(50, 180, 50) or Color3.fromRGB(100, 100, 100)
        for _, p in ipairs(Players:GetPlayers()) do if p ~= localPlayer then UpdateNameTag(p) end end
    end)
    CreateButton(UDim2.new(0, 155, 0, 200), "FlyJump: OFF", Color3.fromRGB(180, 50, 50), function(b)
        FlyJumpEnabled = not FlyJumpEnabled
        b.Text = FlyJumpEnabled and "FlyJump: ON" or "FlyJump: OFF"
        b.BackgroundColor3 = FlyJumpEnabled and Color3.fromRGB(50, 180, 50) or Color3.fromRGB(180, 50, 50)
        if localPlayer.Character then SetFlyJump(localPlayer.Character, FlyJumpEnabled) end
    end)

    -- AIMBOT BUTTON
    CreateButton(UDim2.new(0, 5, 0, 245), "Aimbot: OFF", Color3.fromRGB(180, 50, 50), function(b)
        AimbotEnabled = not AimbotEnabled
        b.Text = AimbotEnabled and "Aimbot: ON" or "Aimbot: OFF"
        b.BackgroundColor3 = AimbotEnabled and Color3.fromRGB(50, 180, 50) or Color3.fromRGB(180, 50, 50)
        CurrentAimbotTarget = nil
        UpdateFOVCircle()
        Notify("Aimbot", AimbotEnabled and "Enabled (Press R)" or "Disabled")
    end)
    CreateButton(UDim2.new(0, 155, 0, 245), "Respawn Character", Color3.fromRGB(200, 30, 30), function(b)
        InstantRespawn()
    end)

    -- XRAY BUTTON
    CreateButton(UDim2.new(0, 5, 0, 290), "Xray: OFF", Color3.fromRGB(180, 50, 50), function(b)
        XrayEnabled = not XrayEnabled
        b.Text = XrayEnabled and "Xray: ON" or "Xray: OFF"
        b.BackgroundColor3 = XrayEnabled and Color3.fromRGB(50, 180, 50) or Color3.fromRGB(180, 50, 50)
        if XrayEnabled then
            enableXray()
        else
            disableXray()
        end
    end)

    -- [[ AIMBOT SETTINGS ]] --
    local AimbotLabel = Instance.new("TextLabel")
    AimbotLabel.Size = UDim2.new(0, 290, 0, 25)
    AimbotLabel.Position = UDim2.new(0, 5, 0, 340)
    AimbotLabel.BackgroundTransparency = 1
    AimbotLabel.Text = "AIMBOT SETTINGS"
    AimbotLabel.TextColor3 = Color3.fromRGB(255, 105, 180)
    AimbotLabel.Font = Enum.Font.GothamBold
    AimbotLabel.TextSize = 18
    AimbotLabel.Parent = ScrollFrame

    CreateSlider(UDim2.new(0, 5, 0, 370), "FOV Radius", AimbotFOV, function(val) 
        AimbotFOV = val 
        CurrentAimbotTarget = nil
        UpdateFOVCircle()
    end)

    -- FOV Circle Toggle
    CreateToggle(UDim2.new(0, 5, 0, 440), "Show FOV Circle", ShowFOVCircle, function(state)
        ShowFOVCircle = state
        UpdateFOVCircle()
    end)

    -- Aimbot Mode Selection
    local modeLabel = Instance.new("TextLabel")
    modeLabel.Size = UDim2.new(0, 290, 0, 25)
    modeLabel.Position = UDim2.new(0, 5, 0, 495)
    modeLabel.BackgroundTransparency = 1
    modeLabel.Text = "Mode: " .. AimbotMode
    modeLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
    modeLabel.Font = Enum.Font.Gotham
    modeLabel.TextSize = 16
    modeLabel.Parent = ScrollFrame

    CreateButton(UDim2.new(0, 5, 0, 525), "Change Mode", Color3.fromRGB(60, 60, 60), function(b)
        if AimbotMode == "Closest to Crosshair" then
            AimbotMode = "Closest Player"
            b.Text = "Closest Player"
        elseif AimbotMode == "Closest Player" then
            AimbotMode = "Perfect Aim"
            b.Text = "Perfect Aim"
        elseif AimbotMode == "Perfect Aim" then
            AimbotMode = "AI Power"
            b.Text = "AI Power"
        else
            AimbotMode = "Closest to Crosshair"
            b.Text = "Crosshair Mode"
        end
        CurrentAimbotTarget = nil
        modeLabel.Text = "Mode: " .. AimbotMode
        Notify("Aimbot", "Mode changed to: " .. AimbotMode)
    end)

    -- AI Power Toggle
    CreateToggle(UDim2.new(0, 5, 0, 575), "AI Power Mode", AimbotAIPower, function(state)
        AimbotAIPower = state
        if state then
            AimbotMode = "AI Power"
            modeLabel.Text = "Mode: " .. AimbotMode
            Notify("AI Power", "Advanced AI targeting enabled")
        end
    end)

    -- Perfect Aim Toggle
    CreateToggle(UDim2.new(0, 5, 0, 630), "Perfect Aim", PerfectAim, function(state)
        PerfectAim = state
        if state then
            AimbotSmoothness = 0.95
            Notify("Perfect Aim", "Instant aim enabled")
        else
            AimbotSmoothness = 0.60
        end
    end)

    -- Perfect Movement Toggle
    CreateToggle(UDim2.new(0, 5, 0, 685), "Perfect Movement", PerfectMovement, function(state)
        PerfectMovement = state
        if state then
            AimbotUsePrediction = true
            AimbotPredictionAmount = 0.25
            Notify("Perfect Movement", "Advanced prediction enabled")
        else
            AimbotPredictionAmount = 0.17
        end
    end)

    -- Max Distance Setting
    CreateSlider(UDim2.new(0, 5, 0, 740), "Max Distance", MaxTargetDistance, function(val) 
        MaxTargetDistance = val
        CurrentAimbotTarget = nil
    end)

    local targetPartLabel = Instance.new("TextLabel")
    targetPartLabel.Size = UDim2.new(0, 290, 0, 25)
    targetPartLabel.Position = UDim2.new(0, 5, 0, 810)
    targetPartLabel.BackgroundTransparency = 1
    targetPartLabel.Text = "Target Part: " .. AimbotTargetPart
    targetPartLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
    targetPartLabel.Font = Enum.Font.Gotham
    targetPartLabel.TextSize = 16
    targetPartLabel.Parent = ScrollFrame

    CreateButton(UDim2.new(0, 5, 0, 840), "Head Target", Color3.fromRGB(60, 60, 60), function(b)
        AimbotTargetPart = b.Text == "Head Target" and "HumanoidRootPart" or "Head"
        b.Text = AimbotTargetPart == "Head" and "Head Target" or "Body Target"
        CurrentAimbotTarget = nil
        targetPartLabel.Text = "Target Part: " .. AimbotTargetPart
    end)

    CreateToggle(UDim2.new(0, 5, 0, 890), "Use Prediction", AimbotUsePrediction, function(state)
        AimbotUsePrediction = state
        CurrentAimbotTarget = nil
    end)

    CreateSlider(UDim2.new(0, 5, 0, 945), "Prediction Amount", AimbotPredictionAmount * 100, function(val) 
        AimbotPredictionAmount = val / 100
        CurrentAimbotTarget = nil
    end)

    CreateSlider(UDim2.new(0, 5, 0, 1015), "Aim Smoothness", AimbotSmoothness * 100, function(val) 
        AimbotSmoothness = val / 100
        CurrentAimbotTarget = nil
    end)

    -- [[ FOLLOW PLAYER SECTION ]] --
    local FollowLabel = Instance.new("TextLabel")
    FollowLabel.Size = UDim2.new(0, 290, 0, 25)
    FollowLabel.Position = UDim2.new(0, 5, 0, 1085)
    FollowLabel.BackgroundTransparency = 1
    FollowLabel.Text = "FOLLOW PLAYER"
    FollowLabel.TextColor3 = Color3.fromRGB(255, 105, 180)
    FollowLabel.Font = Enum.Font.GothamBold
    FollowLabel.TextSize = 18
    FollowLabel.Parent = ScrollFrame

    local FollowTextBox = Instance.new("TextBox")
    FollowTextBox.Size = UDim2.new(0, 140, 0, 35)
    FollowTextBox.Position = UDim2.new(0, 5, 0, 1115)
    FollowTextBox.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
    FollowTextBox.Text = "Type Player Name"
    FollowTextBox.PlaceholderText = "Type Player Name"
    FollowTextBox.TextColor3 = Color3.fromRGB(255, 255, 255)
    FollowTextBox.Font = Enum.Font.Gotham
    FollowTextBox.TextSize = 14
    FollowTextBox.Parent = ScrollFrame
    addCorner(FollowTextBox, 6)

    local FollowBtn = CreateButton(UDim2.new(0, 150, 0, 1115), "Start Follow", Color3.fromRGB(0, 150, 255), function(b)
        if FollowingPlayer then
            StopFollowing()
            b.Text = "Start Follow"
            b.BackgroundColor3 = Color3.fromRGB(0, 150, 255)
        else
            local targetName = FollowTextBox.Text
            local targetPlayer = findPartialPlayer(targetName)
            if targetPlayer then
                StartFollowing(targetPlayer)
                b.Text = "Stop Follow"
                b.BackgroundColor3 = Color3.fromRGB(255, 50, 50)
            else
                Notify("Error", "Player not found!")
            end
        end
    end)

    -- [[ SPECTATE SECTION ]] --
    local SpectateLabel = Instance.new("TextLabel")
    SpectateLabel.Size = UDim2.new(0, 290, 0, 25)
    SpectateLabel.Position = UDim2.new(0, 5, 0, 1165)
    SpectateLabel.BackgroundTransparency = 1
    SpectateLabel.Text = "SPECTATE PLAYER"
    SpectateLabel.TextColor3 = Color3.fromRGB(255, 105, 180)
    SpectateLabel.Font = Enum.Font.GothamBold
    SpectateLabel.TextSize = 18
    SpectateLabel.Parent = ScrollFrame

    local SpectateTextBox = Instance.new("TextBox")
    SpectateTextBox.Size = UDim2.new(0, 140, 0, 35)
    SpectateTextBox.Position = UDim2.new(0, 5, 0, 1195)
    SpectateTextBox.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
    SpectateTextBox.Text = "Type Player Name"
    SpectateTextBox.PlaceholderText = "Type Player Name"
    SpectateTextBox.TextColor3 = Color3.fromRGB(255, 255, 255)
    SpectateTextBox.Font = Enum.Font.Gotham
    SpectateTextBox.TextSize = 14
    SpectateTextBox.Parent = ScrollFrame
    addCorner(SpectateTextBox, 6)

    CreateButton(UDim2.new(0, 150, 0, 1195), "Spectate", Color3.fromRGB(0, 150, 255), function(b)
        local targetName = SpectateTextBox.Text
        local targetPlayer = findPartialPlayer(targetName)
        if targetPlayer then
            SpectatePlayer(targetPlayer)
        else
            Notify("Error", "Player not found!")
        end
    end)

    CreateButton(UDim2.new(0, 5, 0, 1235), "Stop Spectate", Color3.fromRGB(200, 50, 50), function(b)
        StopSpectate()
    end)

    -- [[ TELEPORT SECTION ]] --
    local TeleportLabel = Instance.new("TextLabel")
    TeleportLabel.Size = UDim2.new(0, 290, 0, 25)
    TeleportLabel.Position = UDim2.new(0, 5, 0, 1285)
    TeleportLabel.BackgroundTransparency = 1
    TeleportLabel.Text = "TELEPORT TO PLAYER"
    TeleportLabel.TextColor3 = Color3.fromRGB(255, 105, 180)
    TeleportLabel.Font = Enum.Font.GothamBold
    TeleportLabel.TextSize = 18
    TeleportLabel.Parent = ScrollFrame

    local TeleportTextBox = Instance.new("TextBox")
    TeleportTextBox.Size = UDim2.new(0, 140, 0, 35)
    TeleportTextBox.Position = UDim2.new(0, 5, 0, 1315)
    TeleportTextBox.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
    TeleportTextBox.Text = "Type Partial Username"
    TeleportTextBox.PlaceholderText = "Type Partial Username"
    TeleportTextBox.TextColor3 = Color3.fromRGB(255, 255, 255)
    TeleportTextBox.Font = Enum.Font.Gotham
    TeleportTextBox.TextSize = 14
    TeleportTextBox.Parent = ScrollFrame
    addCorner(TeleportTextBox, 6)

    CreateButton(UDim2.new(0, 150, 0, 1315), "Teleport", Color3.fromRGB(0, 150, 255), function(b)
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
            TeleportTextBox.Text = "Player not found!"
            task.wait(2)
            TeleportTextBox.Text = "Type Partial Username"
        end
    end)

    -- [[ OTHER SETTINGS ]] --
    local SliderLabel = Instance.new("TextLabel")
    SliderLabel.Size = UDim2.new(0, 290, 0, 25)
    SliderLabel.Position = UDim2.new(0, 5, 0, 1365)
    SliderLabel.BackgroundTransparency = 1
    SliderLabel.Text = "OTHER SETTINGS"
    SliderLabel.TextColor3 = Color3.fromRGB(255, 105, 180)
    SliderLabel.Font = Enum.Font.GothamBold
    SliderLabel.TextSize = 18
    SliderLabel.Parent = ScrollFrame

    CreateSlider(UDim2.new(0, 5, 0, 1395), "Speed Amount", BoostSpeed, function(val) BoostSpeed = val end)
    CreateSlider(UDim2.new(0, 5, 0, 1465), "Hitbox Size", HeadSize, function(val) HeadSize = val end)
    CreateSlider(UDim2.new(0, 5, 0, 1535), "FlyJump Power", FlyJumpPower, function(val) FlyJumpPower = val end)

    -- [[ ESP COLOR SECTION ]] --
    local colorLabel = Instance.new("TextLabel")
    colorLabel.Size = UDim2.new(0, 290, 0, 25)
    colorLabel.Position = UDim2.new(0, 5, 0, 1605)
    colorLabel.BackgroundTransparency = 1
    colorLabel.Text = "ESP COLOR"
    colorLabel.TextColor3 = Color3.fromRGB(255, 105, 180)
    colorLabel.Font = Enum.Font.GothamBold
    colorLabel.TextSize = 18
    colorLabel.Parent = ScrollFrame

    local dropdownColor = Instance.new("TextButton")
    dropdownColor.Size = UDim2.new(0, 290, 0, 40)
    dropdownColor.Position = UDim2.new(0, 5, 0, 1635)
    dropdownColor.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
    dropdownColor.Text = "Color: Black"
    dropdownColor.TextColor3 = Color3.fromRGB(255, 255, 255)
    dropdownColor.Font = Enum.Font.GothamBold
    dropdownColor.TextSize = 16
    dropdownColor.Parent = ScrollFrame
    addCorner(dropdownColor, 6)

    local listFrameColor = Instance.new("Frame")
    listFrameColor.Size = UDim2.new(0, 290, 0, 0)
    listFrameColor.Position = UDim2.new(0, 0, 1, 5)
    listFrameColor.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
    listFrameColor.Parent = dropdownColor
    listFrameColor.ClipsDescendants = true
    listFrameColor.ZIndex = 20
    addCorner(listFrameColor, 6)

    local open = false
    dropdownColor.MouseButton1Click:Connect(function()
        open = not open
        listFrameColor.Size = open and UDim2.new(0, 290, 0, 180) or UDim2.new(0, 290, 0, 0)
    end)

    local i = 0
    for name, color in pairs(HighlightColors) do
        local b = Instance.new("TextButton")
        b.Size = UDim2.new(1, -10, 0, 30)
        b.Position = UDim2.new(0, 5, 0, i * 30)
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
            listFrameColor.Size = UDim2.new(0, 290, 0, 0)
            Notify("ESP Color", "Color changed to " .. name)
        end)
        i = i + 1
    end
end

if not gui then CreateGUI() end

-- [[ KEYBOARD SHORTCUTS ]] --
UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    
    -- T key to minimize GUI
    if input.KeyCode == Enum.KeyCode.T then
        if gui and gui:FindFirstChild("MainContainer") then
            local MainContainer = gui.MainContainer
            local MinBtn = MainContainer:FindFirstChild("MinimizeButton")
            local MainFrame = MainContainer:FindFirstChild("MainFrame")
            
            if MinBtn and MainFrame then
                isMinimizing = not isMinimizing
                MainFrame.Visible = not isMinimizing
                MinBtn.Text = isMinimizing and "+" or "-"
                MainContainer.Size = isMinimizing and UDim2.new(0, 40, 0, 30) or UDim2.new(0, 350, 0, 650)
            end
        end
    end
    
    -- R key to toggle aimbot
    if input.KeyCode == Enum.KeyCode.R then
        AimbotEnabled = not AimbotEnabled
        CurrentAimbotTarget = nil
        
        -- Update GUI button
        if gui and gui:FindFirstChild("MainContainer") then
            local MainContainer = gui.MainContainer
            local MainFrame = MainContainer:FindFirstChild("MainFrame")
            if MainFrame then
                local ScrollFrame = MainFrame:FindFirstChild("ScrollingFrame")
                if ScrollFrame then
                    for _, child in ipairs(ScrollFrame:GetChildren()) do
                        if child:IsA("TextButton") and child.Text:find("Aimbot:") then
                            child.Text = AimbotEnabled and "Aimbot: ON" or "Aimbot: OFF"
                            child.BackgroundColor3 = AimbotEnabled and Color3.fromRGB(50, 180, 50) or Color3.fromRGB(180, 50, 50)
                            break
                        end
                    end
                end
            end
        end
        
        UpdateFOVCircle()
        Notify("Aimbot", AimbotEnabled and "Enabled (R Key)\nMode: " .. AimbotMode or "Disabled (R Key)")
    end
    
    -- V key to unlock mouse (always works)
    if input.KeyCode == Enum.KeyCode.V then
        UnlockMouse()
    end
end)

-- [[ CONNECTION LOGIC ]] --
local function onCharacterAdded(char)
    OriginalCollides = {}
    if WallBreakEnabled then enableNoclipForCharacter(char) end
    if FlyJumpEnabled then SetFlyJump(char, true) end
end

if localPlayer.Character then onCharacterAdded(localPlayer.Character) end
localPlayer.CharacterAdded:Connect(onCharacterAdded)

-- Handle player joining/leaving
Players.PlayerAdded:Connect(function(player)
    player.CharacterAdded:Connect(function()
        task.wait(0.5)
        if ESPEnabled then UpdateHighlight(player) end
        if HitboxEnabled then UpdateHitbox(player) end
        if NameTagEnabled then UpdateNameTag(player) end
    end)
end)

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

-- [[ FIXED MAIN LOOP ]] --
local aimbotConnection = RunService.RenderStepped:Connect(function()
    -- Update character stats
    local char = localPlayer.Character
    if char then
        local hum = char:FindFirstChildOfClass("Humanoid")
        if hum then 
            hum.WalkSpeed = SpeedEnabled and BoostSpeed or 16 
        end
        if hum and FlyJumpEnabled then 
            hum.JumpPower = FlyJumpPower
        end
    end

    -- Update visuals for ALL players
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= localPlayer then
            if ESPEnabled then UpdateHighlight(player) end
            if HitboxEnabled then UpdateHitbox(player) end
            if NameTagEnabled then UpdateNameTag(player) end
        end
    end
    
    -- FIXED AIMBOT FUNCTIONALITY
    if AimbotEnabled and localPlayer.Character then
        local targetPos, targetPlayer = GetAimbotTarget()
        if targetPos and targetPlayer then
            local camera = Workspace.CurrentCamera
            local currentCFrame = camera.CFrame
            
            -- Calculate direction to target
            local direction = (targetPos - currentCFrame.Position).Unit
            
            -- Calculate new CFrame looking at target
            local lookCFrame = CFrame.new(currentCFrame.Position, currentCFrame.Position + direction)
            
            -- Apply smooth aiming (or instant if Perfect Aim)
            local smoothness = PerfectAim and 0.95 or AimbotSmoothness
            camera.CFrame = currentCFrame:Lerp(lookCFrame, smoothness)
            
            -- Auto fire when mouse button is held
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
    
    -- Update FOV Circle
    if FOVCircle and FOVCircle:FindFirstChild("Circle") then
        FOVCircle.Enabled = ShowFOVCircle and AimbotEnabled
    end
end)

-- Clean up on script termination
localPlayer.PlayerGui.DescendantRemoving:Connect(function(descendant)
    if descendant == gui then
        aimbotConnection:Disconnect()
        if FOVCircle then FOVCircle:Destroy() end
        if noclipRunConn then noclipRunConn:Disconnect() end
        if charDescAddedConn then charDescAddedConn:Disconnect() end
        disableXray()
        StopFollowing()
    end
end)

-- Also clean up when player leaves
game:GetService("Players").PlayerRemoving:Connect(function(player)
    if player == localPlayer then
        aimbotConnection:Disconnect()
        if FOVCircle then FOVCircle:Destroy() end
        if noclipRunConn then noclipRunConn:Disconnect() end
        if charDescAddedConn then charDescAddedConn:Disconnect() end
        disableXray()
        StopFollowing()
    end
end)

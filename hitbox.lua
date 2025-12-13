local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local StarterGui = game:GetService("StarterGui")
local localPlayer = Players.LocalPlayer

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
local FreeCameraEnabled = false
local FreeCameraConnection = nil

-- Aimbot Settings
local AimbotFOV = 80
local AimbotTargetPart = "Head"
local AimbotUsePrediction = true
local AimbotPredictionAmount = 0.17
local AimbotSmoothness = 0.60
local MaxTargetDistance = 300
local AimbotMode = "Closest to Crosshair"

-- FlyJump Settings
local FlyJumpPower = 150

-- Free Camera Settings (Improved - Fixed gray box issue)
local FreeCameraSpeed = 20  -- Changed to 20 as requested
local FreeCameraFastSpeed = 40
local FreeCameraSensitivity = 0.3
local FreeCameraAcceleration = 5
local FreeCameraDeceleration = 10
local FreeCameraVelocity = Vector3.new(0, 0, 0)
local FreeCameraAngles = Vector2.new(0, 0)
local FreeCameraShiftLocked = false

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

-- Free Camera Variables
local OriginalCameraType = nil
local OriginalCameraSubject = nil
local OriginalMouseIconEnabled = true
local OriginalMouseBehavior = Enum.MouseBehavior.Default
local FreeCameraKeys = {
    W = false,
    A = false,
    S = false,
    D = false,
    Q = false,
    E = false,
    LeftShift = false,
    Space = false
}
local FreeCameraCFrame = nil

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

Notify("Takbir's Script V9.0", "Shortcuts: T=GUI | R=Aimbot | Shift+P=FreeCam | V=Unlock Mouse", 5)

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

-- [[ IMPROVED FREE CAMERA SYSTEM - FIXED GRAY BOX ISSUE ]] --
local function IsMouseLocked()
    return UserInputService.MouseBehavior == Enum.MouseBehavior.LockCenter or
           UserInputService.MouseBehavior == Enum.MouseBehavior.LockCurrentPosition
end

local function UnlockMouse()
    if IsMouseLocked() then
        UserInputService.MouseBehavior = Enum.MouseBehavior.Default
        UserInputService.MouseIconEnabled = true
        Notify("Mouse", "Mouse Unlocked (V)", 2)
    end
end

local function EnableFreeCamera()
    if FreeCameraEnabled then return end
    
    local camera = Workspace.CurrentCamera
    OriginalCameraType = camera.CameraType
    OriginalCameraSubject = camera.CameraSubject
    OriginalMouseIconEnabled = UserInputService.MouseIconEnabled
    OriginalMouseBehavior = UserInputService.MouseBehavior
    
    FreeCameraEnabled = true
    FreeCameraCFrame = camera.CFrame
    FreeCameraAngles = Vector2.new(0, 0)
    FreeCameraVelocity = Vector3.new(0, 0, 0)
    FreeCameraShiftLocked = false
    
    -- Set camera to scriptable
    camera.CameraType = Enum.CameraType.Scriptable
    camera.CameraSubject = nil
    
    -- Capture mouse
    UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter
    UserInputService.MouseIconEnabled = false
    
    -- Disable character movement without making it transparent (fixes gray box issue)
    local char = localPlayer.Character
    if char then
        local hum = char:FindFirstChildOfClass("Humanoid")
        if hum then
            hum.WalkSpeed = 0
            hum.JumpPower = 0
            hum:ChangeState(Enum.HumanoidStateType.Physics)
        end
        
        -- Instead of making character transparent, teleport it far away temporarily
        -- This prevents the gray box visual glitch
        local hrp = char:FindFirstChild("HumanoidRootPart")
        if hrp then
            -- Store original position
            local originalPosition = hrp.CFrame
            -- Move character far below map (out of sight)
            hrp.CFrame = CFrame.new(0, -10000, 0)
            
            -- Store for restoration
            char:SetAttribute("OriginalPosition", originalPosition)
        end
    end
    
    -- Start camera loop
    if FreeCameraConnection then 
        FreeCameraConnection:Disconnect() 
    end
    
    FreeCameraConnection = RunService.RenderStepped:Connect(function(deltaTime)
        if not FreeCameraEnabled then return end
        
        local camera = Workspace.CurrentCamera
        
        -- Mouse look
        local lookX = 0
        local lookY = 0
        
        if UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2) or FreeCameraShiftLocked then
            local mouseDelta = UserInputService:GetMouseDelta()
            lookX = -mouseDelta.X * FreeCameraSensitivity * 0.05
            lookY = -mouseDelta.Y * FreeCameraSensitivity * 0.05
        end
        
        -- Update camera angles
        FreeCameraAngles = FreeCameraAngles + Vector2.new(lookY, lookX)
        
        -- Clamp vertical angle
        FreeCameraAngles = Vector2.new(
            math.clamp(FreeCameraAngles.X, math.rad(-85), math.rad(85)),
            FreeCameraAngles.Y
        )
        
        -- Calculate movement input
        local moveInput = Vector3.new(0, 0, 0)
        if FreeCameraKeys.W then moveInput = moveInput + Vector3.new(0, 0, -1) end
        if FreeCameraKeys.S then moveInput = moveInput + Vector3.new(0, 0, 1) end
        if FreeCameraKeys.A then moveInput = moveInput + Vector3.new(-1, 0, 0) end
        if FreeCameraKeys.D then moveInput = moveInput + Vector3.new(1, 0, 0) end
        if FreeCameraKeys.Q then moveInput = moveInput + Vector3.new(0, -1, 0) end
        if FreeCameraKeys.E then moveInput = moveInput + Vector3.new(0, 1, 0) end
        
        -- Calculate speed
        local speed = FreeCameraKeys.LeftShift and FreeCameraFastSpeed or FreeCameraSpeed
        local targetVelocity = moveInput * speed
        
        -- Smooth acceleration/deceleration
        FreeCameraVelocity = FreeCameraVelocity:Lerp(
            targetVelocity,
            (moveInput.Magnitude > 0 and FreeCameraAcceleration or FreeCameraDeceleration) * deltaTime
        )
        
        -- Apply movement
        if FreeCameraVelocity.Magnitude > 0.01 then
            local lookCFrame = CFrame.fromOrientation(FreeCameraAngles.X, FreeCameraAngles.Y, 0)
            local moveVector = lookCFrame:VectorToWorldSpace(FreeCameraVelocity * deltaTime)
            FreeCameraCFrame = FreeCameraCFrame + moveVector
        end
        
        -- Update camera
        camera.CFrame = CFrame.new(FreeCameraCFrame.Position) * CFrame.fromOrientation(FreeCameraAngles.X, FreeCameraAngles.Y, 0)
    end)
    
    Notify("Free Camera", "Enabled (Shift+P to disable)\nRight Click or Shift+Lock to look", 4)
end

local function DisableFreeCamera()
    if not FreeCameraEnabled then return end
    
    FreeCameraEnabled = false
    FreeCameraShiftLocked = false
    
    -- IMPORTANT: Reset all camera keys FIRST before anything else
    for key, _ in pairs(FreeCameraKeys) do
        FreeCameraKeys[key] = false
    end
    
    -- Restore camera
    local camera = Workspace.CurrentCamera
    camera.CameraType = OriginalCameraType or Enum.CameraType.Custom
    
    -- Restore character
    local char = localPlayer.Character
    if char then
        local hum = char:FindFirstChildOfClass("Humanoid")
        if hum then
            -- IMPORTANT: Reset character movement properties
            hum.WalkSpeed = SpeedEnabled and BoostSpeed or 16
            hum.JumpPower = FlyJumpEnabled and FlyJumpPower or DefaultJumpPower
            
            -- Force reset humanoid state
            hum:ChangeState(Enum.HumanoidStateType.Running)
            
            -- Also reset MoveDirection to prevent stuck movement
            hum.MoveDirection = Vector3.new(0, 0, 0)
        end
        
        -- Restore character position
        local hrp = char:FindFirstChild("HumanoidRootPart")
        if hrp then
            local originalPosition = char:GetAttribute("OriginalPosition")
            if originalPosition then
                hrp.CFrame = originalPosition
            end
            char:SetAttribute("OriginalPosition", nil)
        end
    end
    
    -- Set camera subject back to character
    if localPlayer.Character then
        local hum = localPlayer.Character:FindFirstChildOfClass("Humanoid")
        if hum then
            camera.CameraSubject = hum
        end
    else
        camera.CameraSubject = OriginalCameraSubject
    end
    
    -- Restore mouse
    UserInputService.MouseBehavior = OriginalMouseBehavior or Enum.MouseBehavior.Default
    UserInputService.MouseIconEnabled = OriginalMouseIconEnabled
    
    -- Disconnect loop
    if FreeCameraConnection then 
        FreeCameraConnection:Disconnect()
        FreeCameraConnection = nil
    end
    
    Notify("Free Camera", "Disabled", 3)
end

local function ToggleShiftLock()
    if FreeCameraEnabled then
        FreeCameraShiftLocked = not FreeCameraShiftLocked
        Notify("Free Camera", FreeCameraShiftLocked and "Shift Lock Enabled" or "Shift Lock Disabled", 2)
    end
end

-- Handle free camera keyboard input
local function HandleFreeCameraInput(input, state)
    if not FreeCameraEnabled then 
        -- If free camera is disabled, make sure keys are released
        if input.KeyCode == Enum.KeyCode.W then
            FreeCameraKeys.W = false
        elseif input.KeyCode == Enum.KeyCode.A then
            FreeCameraKeys.A = false
        elseif input.KeyCode == Enum.KeyCode.S then
            FreeCameraKeys.S = false
        elseif input.KeyCode == Enum.KeyCode.D then
            FreeCameraKeys.D = false
        elseif input.KeyCode == Enum.KeyCode.Q then
            FreeCameraKeys.Q = false
        elseif input.KeyCode == Enum.KeyCode.E then
            FreeCameraKeys.E = false
        elseif input.KeyCode == Enum.KeyCode.LeftShift then
            FreeCameraKeys.LeftShift = false
        elseif input.KeyCode == Enum.KeyCode.Space then
            FreeCameraKeys.E = false
        end
        return 
    end
    
    -- Only handle input if free camera is enabled
    if input.KeyCode == Enum.KeyCode.W then
        FreeCameraKeys.W = state
    elseif input.KeyCode == Enum.KeyCode.A then
        FreeCameraKeys.A = state
    elseif input.KeyCode == Enum.KeyCode.S then
        FreeCameraKeys.S = state
    elseif input.KeyCode == Enum.KeyCode.D then
        FreeCameraKeys.D = state
    elseif input.KeyCode == Enum.KeyCode.Q then
        FreeCameraKeys.Q = state
    elseif input.KeyCode == Enum.KeyCode.E then
        FreeCameraKeys.E = state
    elseif input.KeyCode == Enum.KeyCode.LeftShift then
        FreeCameraKeys.LeftShift = state
    elseif input.KeyCode == Enum.KeyCode.Space then
        FreeCameraKeys.E = state
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

-- [[ XRAY LOGIC ]] --
local function enableXray()
    if XrayConnection then XrayConnection:Disconnect() end
    OriginalTransparencies = {}
    
    XrayConnection = RunService.RenderStepped:Connect(function()
        if not XrayEnabled then return end
        
        for _, part in ipairs(Workspace:GetDescendants()) do
            if part:IsA("BasePart") and part.Transparency < 0.9 and part.Name ~= "HumanoidRootPart" then
                if not OriginalTransparencies[part] then
                    OriginalTransparencies[part] = part.Transparency
                end
                part.LocalTransparencyModifier = 0.5
            end
        end
    end)
end

local function disableXray()
    if XrayConnection then 
        XrayConnection:Disconnect() 
        XrayConnection = nil
    end
    
    for part, origTrans in pairs(OriginalTransparencies) do
        if part and part.Parent then
            pcall(function()
                part.LocalTransparencyModifier = 0
            end)
        end
    end
    OriginalTransparencies = {}
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

-- [[ IMPROVED AIMBOT LOGIC ]] --
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
            
            if humanoid and humanoid.Health > 0 and targetPart then
                local distance = (cameraPos - targetPart.Position).Magnitude
                
                if distance > MaxTargetDistance then
                    continue
                end
                
                local screenPoint, onScreen = camera:WorldToViewportPoint(targetPart.Position)
                
                if onScreen then
                    local mousePos = Vector2.new(mouse.X, mouse.Y)
                    local targetPos = Vector2.new(screenPoint.X, screenPoint.Y)
                    local screenDistance = (mousePos - targetPos).Magnitude
                    
                    local score
                    if AimbotMode == "Closest to Crosshair" then
                        score = screenDistance
                    else
                        score = distance
                    end
                    
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
            
            if AimbotUsePrediction and targetPart:IsA("BasePart") then
                local velocity = targetPart.Velocity
                local humanoid = character:FindFirstChildOfClass("Humanoid")
                local moveDirection = Vector3.new(0, 0, 0)
                
                if humanoid then
                    moveDirection = humanoid.MoveDirection
                    if moveDirection.Magnitude > 0 then
                        velocity = velocity + (moveDirection * 10)
                    end
                end
                
                local camera = Workspace.CurrentCamera
                local distance = (camera.CFrame.Position - targetPart.Position).Magnitude
                local predictionTime = AimbotPredictionAmount * (distance / 100)
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

-- [[ SIMPLE ESP/HITBOX SYSTEM ]] --
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
    gui.Name = "MVS_GUI_V9"
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
    Title.Text = "  Takbir's Panel v9.0 (Stable)"
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

    -- SCROLLINGFRAME WITH LARGE CANVAS
    local ScrollFrame = Instance.new("ScrollingFrame")
    ScrollFrame.Size = UDim2.new(1, -10, 1, -50)
    ScrollFrame.Position = UDim2.new(0, 5, 0, 45)
    ScrollFrame.BackgroundTransparency = 1
    ScrollFrame.CanvasSize = UDim2.new(0, 0, 0, 2700)
    ScrollFrame.ScrollBarThickness = 8
    ScrollFrame.ScrollingEnabled = true
    ScrollFrame.VerticalScrollBarInset = Enum.ScrollBarInset.Always
    ScrollFrame.Parent = MainFrame

    -- [[ AIMBOT INFO TEXT - AT THE VERY TOP ]] --
    local AimbotInfo = Instance.new("TextLabel")
    AimbotInfo.Size = UDim2.new(0, 290, 0, 40)
    AimbotInfo.Position = UDim2.new(0, 5, 0, 5)
    AimbotInfo.BackgroundColor3 = Color3.fromRGB(30, 30, 50)
    AimbotInfo.Text = "ℹ️ AIMBOT INFO: Works only with mouse on PC/Laptop"
    AimbotInfo.TextColor3 = Color3.fromRGB(0, 255, 255)
    AimbotInfo.Font = Enum.Font.GothamBold
    AimbotInfo.TextSize = 14
    AimbotInfo.TextWrapped = true
    AimbotInfo.Parent = ScrollFrame
    addCorner(AimbotInfo, 6)

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

    -- [[ MAIN BUTTONS - POSITIONS ADJUSTED ]] --
    CreateButton(UDim2.new(0, 5, 0, 50), "Speed: OFF", Color3.fromRGB(180, 50, 50), function(b)
        SpeedEnabled = not SpeedEnabled
        b.Text = SpeedEnabled and "Speed: ON" or "Speed: OFF"
        b.BackgroundColor3 = SpeedEnabled and Color3.fromRGB(50, 180, 50) or Color3.fromRGB(180, 50, 50)
    end)
    
    CreateButton(UDim2.new(0, 155, 0, 50), "ESP: ON", Color3.fromRGB(50, 180, 50), function(b)
        ESPEnabled = not ESPEnabled
        b.Text = ESPEnabled and "ESP: ON" or "ESP: OFF"
        b.BackgroundColor3 = ESPEnabled and Color3.fromRGB(50, 180, 50) or Color3.fromRGB(180, 50, 50)
        for _, p in ipairs(Players:GetPlayers()) do if p ~= localPlayer then UpdateHighlight(p) end end
    end)

    CreateButton(UDim2.new(0, 5, 0, 95), "Hitbox: ON", Color3.fromRGB(50, 180, 50), function(b)
        HitboxEnabled = not HitboxEnabled
        b.Text = HitboxEnabled and "Hitbox: ON" or "Hitbox: OFF"
        b.BackgroundColor3 = HitboxEnabled and Color3.fromRGB(50, 180, 50) or Color3.fromRGB(180, 50, 50)
        for _, p in ipairs(Players:GetPlayers()) do if p ~= localPlayer then UpdateHitbox(p) end end
    end)
    CreateButton(UDim2.new(0, 155, 0, 95), "Click TP: OFF", Color3.fromRGB(100, 100, 100), function(b)
        ClickTeleportEnabled = not ClickTeleportEnabled
        b.Text = ClickTeleportEnabled and "Click TP: ON" or "Click TP: OFF"
        b.BackgroundColor3 = ClickTeleportEnabled and Color3.fromRGB(50, 180, 50) or Color3.fromRGB(100, 100, 100)
    end)

    CreateButton(UDim2.new(0, 5, 0, 140), "WallBreak: OFF", Color3.fromRGB(180, 50, 50), function(b)
        WallBreakEnabled = not WallBreakEnabled
        b.Text = WallBreakEnabled and "WallBreak: ON" or "WallBreak: OFF"
        b.BackgroundColor3 = WallBreakEnabled and Color3.fromRGB(50, 180, 50) or Color3.fromRGB(180, 50, 50)
        if WallBreakEnabled then enableNoclipForCharacter(localPlayer.Character) else disableNoclipForCharacter() end
    end)
    CreateButton(UDim2.new(0, 155, 0, 140), "Team Check: OFF", Color3.fromRGB(100, 100, 100), function(b)
        TeamCheckEnabled = not TeamCheckEnabled
        b.Text = TeamCheckEnabled and "Team Check: ON" or "Team Check: OFF"
        b.BackgroundColor3 = TeamCheckEnabled and Color3.fromRGB(0, 150, 255) or Color3.fromRGB(100, 100, 100)
        for _, p in ipairs(Players:GetPlayers()) do if p ~= localPlayer then UpdateHighlight(p) end end
    end)

    CreateButton(UDim2.new(0, 5, 0, 185), "Name Tag: OFF", Color3.fromRGB(100, 100, 100), function(b)
        NameTagEnabled = not NameTagEnabled
        b.Text = NameTagEnabled and "Name Tag: ON" or "Name Tag: OFF"
        b.BackgroundColor3 = NameTagEnabled and Color3.fromRGB(50, 180, 50) or Color3.fromRGB(100, 100, 100)
        for _, p in ipairs(Players:GetPlayers()) do if p ~= localPlayer then UpdateNameTag(p) end end
    end)
    CreateButton(UDim2.new(0, 155, 0, 185), "FlyJump: OFF", Color3.fromRGB(180, 50, 50), function(b)
        FlyJumpEnabled = not FlyJumpEnabled
        b.Text = FlyJumpEnabled and "FlyJump: ON" or "FlyJump: OFF"
        b.BackgroundColor3 = FlyJumpEnabled and Color3.fromRGB(50, 180, 50) or Color3.fromRGB(180, 50, 50)
        if localPlayer.Character then SetFlyJump(localPlayer.Character, FlyJumpEnabled) end
    end)

    -- AIMBOT BUTTON
    CreateButton(UDim2.new(0, 5, 0, 230), "Aimbot: OFF", Color3.fromRGB(180, 50, 50), function(b)
        AimbotEnabled = not AimbotEnabled
        b.Text = AimbotEnabled and "Aimbot: ON" or "Aimbot: OFF"
        b.BackgroundColor3 = AimbotEnabled and Color3.fromRGB(50, 180, 50) or Color3.fromRGB(180, 50, 50)
        UpdateFOVCircle()
        Notify("Aimbot", AimbotEnabled and "Enabled" or "Disabled")
    end)
    CreateButton(UDim2.new(0, 155, 0, 230), "Respawn Character", Color3.fromRGB(200, 30, 30), function(b)
        InstantRespawn()
    end)

    -- XRAY BUTTON
    CreateButton(UDim2.new(0, 5, 0, 275), "Xray: OFF", Color3.fromRGB(180, 50, 50), function(b)
        XrayEnabled = not XrayEnabled
        b.Text = XrayEnabled and "Xray: ON" or "Xray: OFF"
        b.BackgroundColor3 = XrayEnabled and Color3.fromRGB(50, 180, 50) or Color3.fromRGB(180, 50, 50)
        if XrayEnabled then
            enableXray()
        else
            disableXray()
        end
    end)

    -- FREE CAMERA BUTTON (XRAY এর পাশে রাখা হয়েছে)
    CreateButton(UDim2.new(0, 155, 0, 275), "Free Cam: OFF", Color3.fromRGB(180, 50, 50), function(b)
        if FreeCameraEnabled then
            DisableFreeCamera()
            b.Text = "Free Cam: OFF"
            b.BackgroundColor3 = Color3.fromRGB(180, 50, 50)
        else
            EnableFreeCamera()
            b.Text = "Free Cam: ON"
            b.BackgroundColor3 = Color3.fromRGB(50, 180, 50)
        end
    end)

    -- [[ FREE CAMERA SETTINGS SECTION (XRAY এর পরে রাখা হয়েছে) ]] --
    local FreeCameraLabel = Instance.new("TextLabel")
    FreeCameraLabel.Size = UDim2.new(0, 290, 0, 25)
    FreeCameraLabel.Position = UDim2.new(0, 5, 0, 325)
    FreeCameraLabel.BackgroundTransparency = 1
    FreeCameraLabel.Text = "FREE CAMERA SETTINGS"
    FreeCameraLabel.TextColor3 = Color3.fromRGB(255, 105, 180)
    FreeCameraLabel.Font = Enum.Font.GothamBold
    FreeCameraLabel.TextSize = 18
    FreeCameraLabel.Parent = ScrollFrame

    CreateSlider(UDim2.new(0, 5, 0, 355), "Camera Speed", FreeCameraSpeed, function(val) 
        FreeCameraSpeed = val
    end)

    CreateSlider(UDim2.new(0, 5, 0, 425), "Fast Speed", FreeCameraFastSpeed, function(val) 
        FreeCameraFastSpeed = val
    end)

    CreateSlider(UDim2.new(0, 5, 0, 495), "Sensitivity", FreeCameraSensitivity * 100, function(val) 
        FreeCameraSensitivity = val / 100
    end)

    CreateSlider(UDim2.new(0, 5, 0, 565), "Acceleration", FreeCameraAcceleration, function(val) 
        FreeCameraAcceleration = val
    end)

    CreateSlider(UDim2.new(0, 5, 0, 635), "Deceleration", FreeCameraDeceleration, function(val) 
        FreeCameraDeceleration = val
    end)

    -- [[ FOLLOW PLAYER SECTION ]] --
    local FollowLabel = Instance.new("TextLabel")
    FollowLabel.Size = UDim2.new(0, 290, 0, 25)
    FollowLabel.Position = UDim2.new(0, 5, 0, 715)
    FollowLabel.BackgroundTransparency = 1
    FollowLabel.Text = "FOLLOW PLAYER"
    FollowLabel.TextColor3 = Color3.fromRGB(255, 105, 180)
    FollowLabel.Font = Enum.Font.GothamBold
    FollowLabel.TextSize = 18
    FollowLabel.Parent = ScrollFrame

    local FollowTextBox = Instance.new("TextBox")
    FollowTextBox.Size = UDim2.new(0, 140, 0, 35)
    FollowTextBox.Position = UDim2.new(0, 5, 0, 745)
    FollowTextBox.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
    FollowTextBox.Text = "Type Player Name"
    FollowTextBox.PlaceholderText = "Type Player Name"
    FollowTextBox.TextColor3 = Color3.fromRGB(255, 255, 255)
    FollowTextBox.Font = Enum.Font.Gotham
    FollowTextBox.TextSize = 14
    FollowTextBox.Parent = ScrollFrame
    addCorner(FollowTextBox, 6)

    local FollowBtn = CreateButton(UDim2.new(0, 150, 0, 745), "Start Follow", Color3.fromRGB(0, 150, 255), function(b)
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
    SpectateLabel.Position = UDim2.new(0, 5, 0, 795)
    SpectateLabel.BackgroundTransparency = 1
    SpectateLabel.Text = "SPECTATE PLAYER"
    SpectateLabel.TextColor3 = Color3.fromRGB(255, 105, 180)
    SpectateLabel.Font = Enum.Font.GothamBold
    SpectateLabel.TextSize = 18
    SpectateLabel.Parent = ScrollFrame

    local SpectateTextBox = Instance.new("TextBox")
    SpectateTextBox.Size = UDim2.new(0, 140, 0, 35)
    SpectateTextBox.Position = UDim2.new(0, 5, 0, 825)
    SpectateTextBox.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
    SpectateTextBox.Text = "Type Player Name"
    SpectateTextBox.PlaceholderText = "Type Player Name"
    SpectateTextBox.TextColor3 = Color3.fromRGB(255, 255, 255)
    SpectateTextBox.Font = Enum.Font.Gotham
    SpectateTextBox.TextSize = 14
    SpectateTextBox.Parent = ScrollFrame
    addCorner(SpectateTextBox, 6)

    CreateButton(UDim2.new(0, 150, 0, 825), "Spectate", Color3.fromRGB(0, 150, 255), function(b)
        local targetName = SpectateTextBox.Text
        local targetPlayer = findPartialPlayer(targetName)
        if targetPlayer then
            SpectatePlayer(targetPlayer)
        else
            Notify("Error", "Player not found!")
        end
    end)

    CreateButton(UDim2.new(0, 5, 0, 865), "Stop Spectate", Color3.fromRGB(200, 50, 50), function(b)
        StopSpectate()
    end)

    -- [[ AIMBOT SETTINGS SECTION ]] --
    local AimbotLabel = Instance.new("TextLabel")
    AimbotLabel.Size = UDim2.new(0, 290, 0, 25)
    AimbotLabel.Position = UDim2.new(0, 5, 0, 915)
    AimbotLabel.BackgroundTransparency = 1
    AimbotLabel.Text = "AIMBOT SETTINGS"
    AimbotLabel.TextColor3 = Color3.fromRGB(255, 105, 180)
    AimbotLabel.Font = Enum.Font.GothamBold
    AimbotLabel.TextSize = 18
    AimbotLabel.Parent = ScrollFrame

    CreateSlider(UDim2.new(0, 5, 0, 945), "FOV Radius", AimbotFOV, function(val) 
        AimbotFOV = val 
        UpdateFOVCircle()
    end)

    -- FOV Circle Toggle
    CreateToggle(UDim2.new(0, 5, 0, 1015), "Show FOV Circle", ShowFOVCircle, function(state)
        ShowFOVCircle = state
        UpdateFOVCircle()
    end)

    -- Aimbot Mode Selection
    local modeLabel = Instance.new("TextLabel")
    modeLabel.Size = UDim2.new(0, 290, 0, 25)
    modeLabel.Position = UDim2.new(0, 5, 0, 1070)
    modeLabel.BackgroundTransparency = 1
    modeLabel.Text = "Mode: " .. AimbotMode
    modeLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
    modeLabel.Font = Enum.Font.Gotham
    modeLabel.TextSize = 16
    modeLabel.Parent = ScrollFrame

    CreateButton(UDim2.new(0, 5, 0, 1100), "Crosshair Mode", Color3.fromRGB(60, 60, 60), function(b)
        if AimbotMode == "Closest to Crosshair" then
            AimbotMode = "Closest Player"
            b.Text = "Closest Player"
        else
            AimbotMode = "Closest to Crosshair"
            b.Text = "Crosshair Mode"
        end
        modeLabel.Text = "Mode: " .. AimbotMode
    end)

    -- Max Distance Setting
    CreateSlider(UDim2.new(0, 5, 0, 1150), "Max Distance", MaxTargetDistance, function(val) 
        MaxTargetDistance = val
    end)

    local targetPartLabel = Instance.new("TextLabel")
    targetPartLabel.Size = UDim2.new(0, 290, 0, 25)
    targetPartLabel.Position = UDim2.new(0, 5, 0, 1220)
    targetPartLabel.BackgroundTransparency = 1
    targetPartLabel.Text = "Target Part: " .. AimbotTargetPart
    targetPartLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
    targetPartLabel.Font = Enum.Font.Gotham
    targetPartLabel.TextSize = 16
    targetPartLabel.Parent = ScrollFrame

    CreateButton(UDim2.new(0, 5, 0, 1250), "Head Target", Color3.fromRGB(60, 60, 60), function(b)
        AimbotTargetPart = b.Text == "Head Target" and "HumanoidRootPart" or "Head"
        b.Text = AimbotTargetPart == "Head" and "Head Target" or "Body Target"
        targetPartLabel.Text = "Target Part: " .. AimbotTargetPart
    end)

    CreateToggle(UDim2.new(0, 5, 0, 1300), "Use Prediction", AimbotUsePrediction, function(state)
        AimbotUsePrediction = state
    end)

    CreateSlider(UDim2.new(0, 5, 0, 1355), "Prediction Amount", AimbotPredictionAmount * 100, function(val) 
        AimbotPredictionAmount = val / 100
    end)

    CreateSlider(UDim2.new(0, 5, 0, 1425), "Aim Smoothness", AimbotSmoothness * 100, function(val) 
        AimbotSmoothness = val / 100
    end)

    -- [[ TELEPORT SECTION ]] --
    local TeleportLabel = Instance.new("TextLabel")
    TeleportLabel.Size = UDim2.new(0, 290, 0, 25)
    TeleportLabel.Position = UDim2.new(0, 5, 0, 1495)
    TeleportLabel.BackgroundTransparency = 1
    TeleportLabel.Text = "TELEPORT TO PLAYER"
    TeleportLabel.TextColor3 = Color3.fromRGB(255, 105, 180)
    TeleportLabel.Font = Enum.Font.GothamBold
    TeleportLabel.TextSize = 18
    TeleportLabel.Parent = ScrollFrame

    local TeleportTextBox = Instance.new("TextBox")
    TeleportTextBox.Size = UDim2.new(0, 140, 0, 35)
    TeleportTextBox.Position = UDim2.new(0, 5, 0, 1525)
    TeleportTextBox.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
    TeleportTextBox.Text = "Type Partial Username"
    TeleportTextBox.PlaceholderText = "Type Partial Username"
    TeleportTextBox.TextColor3 = Color3.fromRGB(255, 255, 255)
    TeleportTextBox.Font = Enum.Font.Gotham
    TeleportTextBox.TextSize = 14
    TeleportTextBox.Parent = ScrollFrame
    addCorner(TeleportTextBox, 6)

    CreateButton(UDim2.new(0, 150, 0, 1525), "Teleport", Color3.fromRGB(0, 150, 255), function(b)
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
    SliderLabel.Position = UDim2.new(0, 5, 0, 1575)
    SliderLabel.BackgroundTransparency = 1
    SliderLabel.Text = "OTHER SETTINGS"
    SliderLabel.TextColor3 = Color3.fromRGB(255, 105, 180)
    SliderLabel.Font = Enum.Font.GothamBold
    SliderLabel.TextSize = 18
    SliderLabel.Parent = ScrollFrame

    CreateSlider(UDim2.new(0, 5, 0, 1605), "Speed Amount", BoostSpeed, function(val) BoostSpeed = val end)
    CreateSlider(UDim2.new(0, 5, 0, 1675), "Hitbox Size", HeadSize, function(val) HeadSize = val end)
    CreateSlider(UDim2.new(0, 5, 0, 1745), "FlyJump Power", FlyJumpPower, function(val) FlyJumpPower = val end)

    -- [[ ESP COLOR SECTION ]] --
    local colorLabel = Instance.new("TextLabel")
    colorLabel.Size = UDim2.new(0, 290, 0, 25)
    colorLabel.Position = UDim2.new(0, 5, 0, 1815)
    colorLabel.BackgroundTransparency = 1
    colorLabel.Text = "ESP COLOR"
    colorLabel.TextColor3 = Color3.fromRGB(255, 105, 180)
    colorLabel.Font = Enum.Font.GothamBold
    colorLabel.TextSize = 18
    colorLabel.Parent = ScrollFrame

    local dropdownColor = Instance.new("TextButton")
    dropdownColor.Size = UDim2.new(0, 290, 0, 40)
    dropdownColor.Position = UDim2.new(0, 5, 0, 1845)
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

-- [[ KEYBOARD SHORTCUTS - FIXED ]] --
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
        
        -- Find and update the aimbot button in GUI
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
        Notify("Aimbot", AimbotEnabled and "Enabled (R Key)" or "Disabled (R Key)")
    end
    
    -- Shift + P to toggle free camera
    if input.KeyCode == Enum.KeyCode.P and UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then
        if FreeCameraEnabled then
            DisableFreeCamera()
            -- Update GUI button
            if gui and gui:FindFirstChild("MainContainer") then
                local MainContainer = gui.MainContainer
                local MainFrame = MainContainer:FindFirstChild("MainFrame")
                if MainFrame then
                    local ScrollFrame = MainFrame:FindFirstChild("ScrollingFrame")
                    if ScrollFrame then
                        for _, child in ipairs(ScrollFrame:GetChildren()) do
                            if child:IsA("TextButton") and child.Text:find("Free Cam:") then
                                child.Text = "Free Cam: OFF"
                                child.BackgroundColor3 = Color3.fromRGB(180, 50, 50)
                                break
                            end
                        end
                    end
                end
            end
        else
            EnableFreeCamera()
            -- Update GUI button
            if gui and gui:FindFirstChild("MainContainer") then
                local MainContainer = gui.MainContainer
                local MainFrame = MainContainer:FindFirstChild("MainFrame")
                if MainFrame then
                    local ScrollFrame = MainFrame:FindFirstChild("ScrollingFrame")
                    if ScrollFrame then
                        for _, child in ipairs(ScrollFrame:GetChildren()) do
                            if child:IsA("TextButton") and child.Text:find("Free Cam:") then
                                child.Text = "Free Cam: ON"
                                child.BackgroundColor3 = Color3.fromRGB(50, 180, 50)
                                break
                            end
                        end
                    end
                end
            end
        end
    end
    
    -- V key to unlock mouse (always works)
    if input.KeyCode == Enum.KeyCode.V then
        UnlockMouse()
        if FreeCameraEnabled then
            DisableFreeCamera()
            -- Update GUI button
            if gui and gui:FindFirstChild("MainContainer") then
                local MainContainer = gui.MainContainer
                local MainFrame = MainContainer:FindFirstChild("MainFrame")
                if MainFrame then
                    local ScrollFrame = MainFrame:FindFirstChild("ScrollingFrame")
                    if ScrollFrame then
                        for _, child in ipairs(ScrollFrame:GetChildren()) do
                            if child:IsA("TextButton") and child.Text:find("Free Cam:") then
                                child.Text = "Free Cam: OFF"
                                child.BackgroundColor3 = Color3.fromRGB(180, 50, 50)
                                break
                            end
                        end
                    end
                end
            end
        end
    end
    
    -- Left Shift toggle for shift lock in free camera
    if input.KeyCode == Enum.KeyCode.LeftShift and FreeCameraEnabled then
        ToggleShiftLock()
    end
    
    -- Handle free camera input
    if FreeCameraEnabled then
        HandleFreeCameraInput(input, true)
    end
end)

-- Handle key releases for free camera
UserInputService.InputEnded:Connect(function(input)
    if FreeCameraEnabled then
        HandleFreeCameraInput(input, false)
    else
        -- Even if free camera is disabled, make sure keys are released
        HandleFreeCameraInput(input, false)
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

-- [[ MAIN LOOP ]] --
local aimbotConnection = RunService.RenderStepped:Connect(function()
    -- Update character stats (if free camera is not enabled)
    if not FreeCameraEnabled then
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
    end

    -- Update visuals for ALL players
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= localPlayer then
            if ESPEnabled then UpdateHighlight(player) end
            if HitboxEnabled then UpdateHitbox(player) end
            if NameTagEnabled then UpdateNameTag(player) end
        end
    end
    
    -- Smart Aimbot functionality (disabled in free camera mode)
    if AimbotEnabled and localPlayer.Character and not FreeCameraEnabled then
        local targetPos, targetPlayer = GetAimbotTarget()
        if targetPos and targetPlayer then
            local camera = Workspace.CurrentCamera
            local currentCFrame = camera.CFrame
            local direction = (targetPos - currentCFrame.Position).Unit
            local targetCFrame = CFrame.new(currentCFrame.Position, currentCFrame.Position + direction)
            camera.CFrame = currentCFrame:Lerp(targetCFrame, AimbotSmoothness)
            
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
    
    -- Update FOV Circle position (hide in free camera mode)
    if FOVCircle and FOVCircle:FindFirstChild("Circle") then
        FOVCircle.Enabled = ShowFOVCircle and AimbotEnabled and not FreeCameraEnabled
        if FOVCircle.Enabled then
            local circle = FOVCircle.Circle
            circle.Position = UDim2.new(0.5, -AimbotFOV, 0.5, -AimbotFOV)
        end
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
        DisableFreeCamera()
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
        DisableFreeCamera()
    end
end)

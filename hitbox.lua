local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
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

pcall(function()
    game:GetService("StarterGui"):SetCore("SendNotification", {
        Title = "Takbir's MVS Script Loaded ✔",
        Text = "Persistent Panel v1.2 Loaded (Speed OFF)",
        Duration = 5
    })
end)

local OriginalCollides = {}
local noclipRunConn = nil
local charDescAddedConn = nil
local Minimized = false

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

local gui, Frame, MinContainer, MinButton, MinTouchHit, ScrollFrame

local function setVisibility(visible)
    if Frame then
        for _, obj in ipairs(Frame:GetDescendants()) do
            if obj:IsA("GuiObject") then
                pcall(function() obj.Visible = visible end)
            end
        end
        pcall(function() Frame.Visible = visible end)
    end
    if MinContainer then
        pcall(function() MinContainer.Visible = not visible end)
    end
end

local dragging = false
local dragInput = nil
local dragStart = nil
local startPos = nil

local function updateGuiPosition(pos)
    if not Frame then return end
    local screenW = math.max(1, gui.AbsoluteSize.X)
    local screenH = math.max(1, gui.AbsoluteSize.Y)
    local w = Frame.AbsoluteSize.X
    local h = Frame.AbsoluteSize.Y
    local x = math.clamp(pos.X, 0, screenW - w)
    local y = math.clamp(pos.Y, 40, screenH - h) -- keep below topbar
    Frame.Position = UDim2.new(0, x, 0, y)
    if MinContainer then
        MinContainer.Position = UDim2.new(0, x + 8, 0, y - 28)
    end
end

local function beginDrag(input)
    dragging = true
    dragInput = input
    dragStart = input.Position
    startPos = Frame.Position
end

local function onDragChanged(input)
    if not dragging then return end
    local delta = input.Position - dragStart
    local newX = startPos.X.Offset + delta.X
    local newY = startPos.Y.Offset + delta.Y
    updateGuiPosition(Vector2.new(newX, newY))
end

local function endDrag()
    dragging = false
    dragInput = nil
    dragStart = nil
    startPos = nil
end

local function CreateGUI()
    if gui then gui:Destroy() end
    gui = Instance.new("ScreenGui")
    gui.Name = "MVS_GUI"
    gui.ResetOnSpawn = false
    gui.IgnoreGuiInset = false
    gui.DisplayOrder = 9999
    gui.Parent = localPlayer:WaitForChild("PlayerGui")
    gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

    Frame = Instance.new("Frame")
    Frame.Size = UDim2.new(0,300,0,420)
    Frame.Position = UDim2.new(0,10,0,60)
    Frame.BackgroundColor3 = Color3.fromRGB(30,30,30)
    Frame.BorderSizePixel = 0
    Frame.Parent = gui
    Frame.ClipsDescendants = true
    Frame.ZIndex = 50

    local function scaleGui()
        local screenW = math.max(1, gui.AbsoluteSize.X)
        local screenH = math.max(1, gui.AbsoluteSize.Y)
        local w = math.clamp(screenW * 0.34, 260, 380)
        local h = math.clamp(screenH * 0.55, 340, 560)
        Frame.Size = UDim2.new(0, w, 0, h)
        local fp = Frame.Position
        if fp.X.Offset < 0 or fp.Y.Offset < 0 then
            Frame.Position = UDim2.new(0,10,0,60)
        end
        if MinContainer then
            MinContainer.Position = UDim2.new(0, Frame.Position.X.Offset + 8, 0, Frame.Position.Y.Offset - 28)
        end
    end
    scaleGui()
    gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(scaleGui)

    MinContainer = Instance.new("Frame")
    MinContainer.Size = UDim2.new(0,48,0,28)
    MinContainer.Position = UDim2.new(0, Frame.Position.X.Offset + 8, 0, Frame.Position.Y.Offset - 28)
    MinContainer.BackgroundTransparency = 1
    MinContainer.Parent = gui
    MinContainer.ZIndex = 60
    MinContainer.Visible = Minimized

    MinButton = Instance.new("TextButton")
    MinButton.Size = UDim2.new(1,0,1,0)
    MinButton.BackgroundColor3 = Color3.fromRGB(200,200,0)
    MinButton.Text = "-"
    MinButton.TextColor3 = Color3.fromRGB(0,0,0)
    MinButton.Font = Enum.Font.GothamBold
    MinButton.TextScaled = true
    MinButton.Parent = MinContainer
    MinButton.ZIndex = 61
    MinButton.AutoButtonColor = true

    MinTouchHit = Instance.new("TextButton")
    MinTouchHit.Size = UDim2.new(0,80,0,44)
    MinTouchHit.Position = UDim2.new(0, Frame.Position.X.Offset - 2, 0, Frame.Position.Y.Offset - 32)
    MinTouchHit.BackgroundTransparency = 1
    MinTouchHit.Text = ""
    MinTouchHit.Parent = gui
    MinTouchHit.ZIndex = 49
    MinTouchHit.AutoButtonColor = false

    local Title = Instance.new("TextLabel")
    Title.Size = UDim2.new(1,0,0,34)
    Title.Position = UDim2.new(0,0,0,0)
    Title.BackgroundColor3 = Color3.fromRGB(40,40,40)
    Title.Text = "Takbir's MVS Panel v1.2"
    Title.TextColor3 = Color3.fromRGB(255,255,255)
    Title.TextScaled = true
    Title.Font = Enum.Font.GothamBold
    Title.Parent = Frame
    Title.ZIndex = 51

    ScrollFrame = Instance.new("ScrollingFrame")
    ScrollFrame.Size = UDim2.new(1,0,1,-34)
    ScrollFrame.Position = UDim2.new(0,0,0,34)
    ScrollFrame.BackgroundTransparency = 1
    ScrollFrame.CanvasSize = UDim2.new(0,0,0,900)
    ScrollFrame.ScrollBarThickness = 6
    ScrollFrame.Parent = Frame
    ScrollFrame.ZIndex = 51

    local function CreateButton(pos,defaultText,color,onClick)
        local btn = Instance.new("TextButton")
        btn.Size = UDim2.new(0,130,0,34)
        btn.Position = pos
        btn.BackgroundColor3 = color
        btn.Text = defaultText
        btn.TextColor3 = Color3.fromRGB(255,255,255)
        btn.Font = Enum.Font.GothamBold
        btn.TextScaled = true
        btn.Parent = ScrollFrame
        btn.MouseButton1Click:Connect(function()
            onClick(btn)
        end)
        btn.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.Touch then
                onClick(btn)
            end
        end)
        return btn
    end

    local function CreateSlider(pos,labelText,default,callback)
        local lbl = Instance.new("TextLabel")
        lbl.Size = UDim2.new(0,260,0,20)
        lbl.Position = pos - UDim2.new(0,0,0,18)
        lbl.BackgroundTransparency = 1
        lbl.Text = labelText.." "..default
        lbl.TextColor3 = Color3.fromRGB(255,255,255)
        lbl.TextScaled = true
        lbl.Font = Enum.Font.Gotham
        lbl.Parent = ScrollFrame

        local tb = Instance.new("TextBox")
        tb.Size = UDim2.new(0,260,0,30)
        tb.Position = pos
        tb.BackgroundColor3 = Color3.fromRGB(80,80,80)
        tb.TextColor3 = Color3.fromRGB(255,255,255)
        tb.Text = tostring(default)
        tb.ClearTextOnFocus = false
        tb.Font = Enum.Font.Gotham
        tb.TextScaled = true
        tb.Parent = ScrollFrame

        tb.FocusLost:Connect(function()
            local val = tonumber(tb.Text)
            if val and val>0 then
                callback(val)
                lbl.Text = labelText.." "..val
            else
                tb.Text = tostring(default)
            end
        end)
    end

    local SpeedBtn = CreateButton(UDim2.new(0,10,0,10),"Speed: OFF",Color3.fromRGB(150,0,0),function(btn)
        SpeedEnabled = not SpeedEnabled
        btn.Text = SpeedEnabled and "Speed: ON" or "Speed: OFF"
    end)
    local ESPBtn = CreateButton(UDim2.new(0,160,0,10),"ESP: ON",Color3.fromRGB(0,0,150),function(btn)
        ESPEnabled = not ESPEnabled
        btn.Text = ESPEnabled and "ESP: ON" or "ESP: OFF"
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= localPlayer then UpdateHighlight(p) end
        end
    end)
    local HitboxBtn = CreateButton(UDim2.new(0,10,0,74),"Hitbox: ON",Color3.fromRGB(120,0,120),function(btn)
        HitboxEnabled = not HitboxEnabled
        btn.Text = HitboxEnabled and "Hitbox: ON" or "Hitbox: OFF"
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= localPlayer then UpdateHitbox(p) end
        end
    end)
    local ClickTPBtn = CreateButton(UDim2.new(0,160,0,74),"Click TP: OFF",Color3.fromRGB(100,100,100),function(btn)
        ClickTeleportEnabled = not ClickTeleportEnabled
        btn.Text = ClickTeleportEnabled and "Click TP: ON" or "Click TP: OFF"
    end)
    local WallBreakBtn = CreateButton(UDim2.new(0,10,0,138),"Wall Break: OFF",Color3.fromRGB(200,0,50),function(btn)
        WallBreakEnabled = not WallBreakEnabled
        btn.Text = WallBreakEnabled and "Wall Break: ON" or "Wall Break: OFF"
        if WallBreakEnabled then
            enableNoclipForCharacter(localPlayer.Character)
        else
            disableNoclipForCharacter()
        end
    end)

    CreateSlider(UDim2.new(0,10,0,42),"Speed",BoostSpeed,function(val) BoostSpeed = val end)
    CreateSlider(UDim2.new(0,10,0,106),"Hitbox Size",HeadSize,function(val) HeadSize = val end)

    local colorLabel = Instance.new("TextLabel")
    colorLabel.Size = UDim2.new(0,260,0,28)
    colorLabel.Position = UDim2.new(0,10,0,182)
    colorLabel.BackgroundColor3 = Color3.fromRGB(50,50,50)
    colorLabel.Text = "Highlight Color: Black"
    colorLabel.TextColor3 = Color3.fromRGB(255,255,255)
    colorLabel.TextScaled = true
    colorLabel.Font = Enum.Font.GothamBold
    colorLabel.Parent = ScrollFrame

    local dropdown = Instance.new("TextButton")
    dropdown.Size = UDim2.new(0,260,0,28)
    dropdown.Position = UDim2.new(0,10,0,214)
    dropdown.BackgroundColor3 = Color3.fromRGB(70,70,70)
    dropdown.Text = "Select Color"
    dropdown.TextColor3 = Color3.fromRGB(255,255,255)
    dropdown.TextScaled = true
    dropdown.Font = Enum.Font.GothamBold
    dropdown.Parent = ScrollFrame

    local listFrame = Instance.new("Frame")
    listFrame.Size = UDim2.new(0,260,0,0)
    listFrame.Position = UDim2.new(0,0,0,28)
    listFrame.BackgroundTransparency = 0.5
    listFrame.BackgroundColor3 = Color3.fromRGB(60,60,60)
    listFrame.Parent = dropdown
    listFrame.ClipsDescendants = true

    local open = false
    dropdown.MouseButton1Click:Connect(function()
        open = not open
        listFrame.Size = open and UDim2.new(0,260,0,160) or UDim2.new(0,260,0,0)
    end)

    local i = 0
    for name,color in pairs(HighlightColors) do
        local b = Instance.new("TextButton")
        b.Size = UDim2.new(0,260,0,32)
        b.Position = UDim2.new(0,0,0,i*32)
        b.BackgroundColor3 = Color3.fromRGB(80,80,80)
        b.Text = name
        b.TextColor3 = Color3.fromRGB(255,255,255)
        b.TextScaled = true
        b.Font = Enum.Font.GothamBold
        b.Parent = listFrame
        b.MouseButton1Click:Connect(function()
            HighlightColor = color
            colorLabel.Text = "Highlight Color: "..name
            for _, p in ipairs(Players:GetPlayers()) do
                if p ~= localPlayer then UpdateHighlight(p) end
            end
        end)
        i = i + 1
    end

    local function toggleMinimize()
        Minimized = not Minimized
        setVisibility(not Minimized)
    end

    MinButton.MouseButton1Click:Connect(toggleMinimize)
    MinButton.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.Touch then toggleMinimize() end
    end)
    MinTouchHit.MouseButton1Click:Connect(toggleMinimize)
    MinTouchHit.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.Touch then toggleMinimize() end
    end)

    Title.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            beginDrag(input)
        end
    end)
    Title.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
            dragInput = input
        end
    end)

    UserInputService.InputChanged:Connect(function(input)
        if input == dragInput then
            onDragChanged(input)
        end
    end)
    UserInputService.InputEnded:Connect(function(input)
        if input == dragInput then endDrag() end
    end)
end

CreateGUI()

local function onCharacterAdded(char)
    OriginalCollides = {}
    if WallBreakEnabled then
        enableNoclipForCharacter(char)
    end
    wait(0.8)
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= localPlayer then
            UpdateHighlight(p)
            UpdateHitbox(p)
        end
    end
    setVisibility(not Minimized)
end

if localPlayer.Character then
    onCharacterAdded(localPlayer.Character)
end
localPlayer.CharacterAdded:Connect(onCharacterAdded)

local mouse = localPlayer:GetMouse()
mouse.Button1Down:Connect(function()
    if ClickTeleportEnabled and localPlayer.Character then
        local hrp = localPlayer.Character:FindFirstChild("HumanoidRootPart")
        if hrp then
            hrp.CFrame = CFrame.new(mouse.Hit.Position + Vector3.new(0,3,0))
        end
    end
end)

RunService.Heartbeat:Connect(function()
    if Frame then
        if Minimized then
            if Frame.Visible then
                pcall(function() Frame.Visible = false end)
            end
            if MinContainer and not MinContainer.Visible then
                pcall(function() MinContainer.Visible = true end)
            end
        else
            if not Frame.Visible then
                pcall(function() Frame.Visible = true end)
            end
            if MinContainer and MinContainer.Visible then
                pcall(function() MinContainer.Visible = false end)
            end
        end
    end
    if localPlayer.Character then
        local hum = localPlayer.Character:FindFirstChildOfClass("Humanoid")
        if hum then
            local targetSpeed = SpeedEnabled and BoostSpeed or 16
            hum.WalkSpeed = targetSpeed
        end
        if WallBreakEnabled then
            for _, part in ipairs(localPlayer.Character:GetDescendants()) do
                if part:IsA("BasePart") then
                    safeSetCanCollide(part, false)
                end
            end
        end
    end
    for _,player in ipairs(Players:GetPlayers()) do
        if player ~= localPlayer then
            UpdateHighlight(player)
            UpdateHitbox(player)
        end
    end
end)

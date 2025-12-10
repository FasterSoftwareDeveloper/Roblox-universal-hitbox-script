local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
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
        Text = "Persistent Panel v1.1 Loaded (Speed OFF)",
        Duration = 5
    })
end)

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

local function UpdateWallBreak()
    if localPlayer.Character then
        for _, part in ipairs(localPlayer.Character:GetDescendants()) do
            if part:IsA("BasePart") then
                part.CanCollide = not WallBreakEnabled and part.CanCollide or false
            end
        end
    end
end

local gui
local function CreateGUI()
    if gui then gui:Destroy() end
    gui = Instance.new("ScreenGui")
    gui.Name = "MVS_GUI"
    gui.Parent = localPlayer:WaitForChild("PlayerGui")

    local MinBtn = Instance.new("TextButton")
    MinBtn.Size = UDim2.new(0,40,0,25)
    MinBtn.Position = UDim2.new(0,10,0,70)
    MinBtn.BackgroundColor3 = Color3.fromRGB(200,200,0)
    MinBtn.Text = "-"
    MinBtn.TextColor3 = Color3.fromRGB(0,0,0)
    MinBtn.Font = Enum.Font.GothamBold
    MinBtn.TextScaled = true
    MinBtn.Parent = gui

    local Frame = Instance.new("Frame")
    Frame.Size = UDim2.new(0,280,0,360)
    Frame.Position = UDim2.new(0,10,0,100)
    Frame.BackgroundColor3 = Color3.fromRGB(30,30,30)
    Frame.BorderSizePixel = 0
    Frame.Parent = gui
    Frame.ClipsDescendants = true

    local Title = Instance.new("TextLabel")
    Title.Size = UDim2.new(1,0,0,30)
    Title.Position = UDim2.new(0,0,0,0)
    Title.BackgroundColor3 = Color3.fromRGB(40,40,40)
    Title.Text = "Takbir's MVS Panel v1.1"
    Title.TextColor3 = Color3.fromRGB(255,255,255)
    Title.TextScaled = true
    Title.Font = Enum.Font.GothamBold
    Title.Parent = Frame

    local ScrollFrame = Instance.new("ScrollingFrame")
    ScrollFrame.Size = UDim2.new(1,0,1,-30)
    ScrollFrame.Position = UDim2.new(0,0,0,30)
    ScrollFrame.BackgroundTransparency = 1
    ScrollFrame.CanvasSize = UDim2.new(0,0,0,700)
    ScrollFrame.ScrollBarThickness = 5
    ScrollFrame.Parent = Frame

    local function CreateButton(pos,defaultText,color,onClick)
        local btn = Instance.new("TextButton")
        btn.Size = UDim2.new(0,120,0,30)
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
        return btn
    end

    local function CreateSlider(pos,labelText,default,callback)
        local lbl = Instance.new("TextLabel")
        lbl.Size = UDim2.new(0,240,0,20)
        lbl.Position = pos - UDim2.new(0,0,0,20)
        lbl.BackgroundTransparency = 1
        lbl.Text = labelText.." "..default
        lbl.TextColor3 = Color3.fromRGB(255,255,255)
        lbl.TextScaled = true
        lbl.Font = Enum.Font.Gotham
        lbl.Parent = ScrollFrame

        local tb = Instance.new("TextBox")
        tb.Size = UDim2.new(0,240,0,25)
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
    local ESPBtn = CreateButton(UDim2.new(0,150,0,10),"ESP: ON",Color3.fromRGB(0,0,150),function(btn)
        ESPEnabled = not ESPEnabled
        btn.Text = ESPEnabled and "ESP: ON" or "ESP: OFF"
    end)
    local HitboxBtn = CreateButton(UDim2.new(0,10,0,120),"Hitbox: ON",Color3.fromRGB(120,0,120),function(btn)
        HitboxEnabled = not HitboxEnabled
        btn.Text = HitboxEnabled and "Hitbox: ON" or "Hitbox: OFF"
    end)
    local ClickTPBtn = CreateButton(UDim2.new(0,150,0,120),"Click TP: OFF",Color3.fromRGB(100,100,100),function(btn)
        ClickTeleportEnabled = not ClickTeleportEnabled
        btn.Text = ClickTeleportEnabled and "Click TP: ON" or "Click TP: OFF"
    end)
    local WallBreakBtn = CreateButton(UDim2.new(0,10,0,230),"Wall Break: OFF",Color3.fromRGB(200,0,50),function(btn)
        WallBreakEnabled = not WallBreakEnabled
        btn.Text = WallBreakEnabled and "Wall Break: ON" or "Wall Break: OFF"
        UpdateWallBreak()
    end)

    CreateSlider(UDim2.new(0,10,0,60),"Speed",BoostSpeed,function(val) BoostSpeed = val end)
    CreateSlider(UDim2.new(0,10,0,170),"Hitbox Size",HeadSize,function(val) HeadSize = val end)

    local colorLabel = Instance.new("TextLabel")
    colorLabel.Size = UDim2.new(0,240,0,25)
    colorLabel.Position = UDim2.new(0,10,0,280)
    colorLabel.BackgroundColor3 = Color3.fromRGB(50,50,50)
    colorLabel.Text = "Highlight Color: Black"
    colorLabel.TextColor3 = Color3.fromRGB(255,255,255)
    colorLabel.TextScaled = true
    colorLabel.Font = Enum.Font.GothamBold
    colorLabel.Parent = ScrollFrame

    local dropdown = Instance.new("TextButton")
    dropdown.Size = UDim2.new(0,240,0,25)
    dropdown.Position = UDim2.new(0,10,0,310)
    dropdown.BackgroundColor3 = Color3.fromRGB(70,70,70)
    dropdown.Text = "Select Color"
    dropdown.TextColor3 = Color3.fromRGB(255,255,255)
    dropdown.TextScaled = true
    dropdown.Font = Enum.Font.GothamBold
    dropdown.Parent = ScrollFrame

    local listFrame = Instance.new("Frame")
    listFrame.Size = UDim2.new(0,240,0,0)
    listFrame.Position = UDim2.new(0,0,0,25)
    listFrame.BackgroundTransparency = 0.5
    listFrame.BackgroundColor3 = Color3.fromRGB(60,60,60)
    listFrame.Parent = dropdown
    listFrame.ClipsDescendants = true

    local open = false
    dropdown.MouseButton1Click:Connect(function()
        open = not open
        listFrame.Size = open and UDim2.new(0,240,0,125) or UDim2.new(0,240,0,0)
    end)

    local i = 0
    for name,color in pairs(HighlightColors) do
        local b = Instance.new("TextButton")
        b.Size = UDim2.new(0,240,0,25)
        b.Position = UDim2.new(0,0,0,i*25)
        b.BackgroundColor3 = Color3.fromRGB(80,80,80)
        b.Text = name
        b.TextColor3 = Color3.fromRGB(255,255,255)
        b.TextScaled = true
        b.Font = Enum.Font.GothamBold
        b.Parent = listFrame
        b.MouseButton1Click:Connect(function()
            HighlightColor = color
            colorLabel.Text = "Highlight Color: "..name
        end)
        i = i + 1
    end

    MinBtn.MouseButton1Click:Connect(function()
        Frame.Visible = not Frame.Visible
    end)
end

if not gui then
    CreateGUI()
end

localPlayer.CharacterAdded:Connect(function()
    wait(1)
    CreateGUI()
end)

local mouse = localPlayer:GetMouse()
mouse.Button1Down:Connect(function()
    if ClickTeleportEnabled and localPlayer.Character then
        local hrp = localPlayer.Character:FindFirstChild("HumanoidRootPart")
        if hrp then
            local target = mouse.Hit.Position + Vector3.new(0,3,0)
            hrp.CFrame = CFrame.new(target)
        end
    end
end)

RunService.RenderStepped:Connect(function()
    if localPlayer.Character then
        local hum = localPlayer.Character:FindFirstChildOfClass("Humanoid")
        if hum then
            hum.WalkSpeed = SpeedEnabled and BoostSpeed or 16
        end
    end
    UpdateWallBreak()
    for _,player in ipairs(Players:GetPlayers()) do
        if player ~= localPlayer then
            UpdateHighlight(player)
            UpdateHitbox(player)
        end
    end
end)

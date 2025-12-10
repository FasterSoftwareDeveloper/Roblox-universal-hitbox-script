pcall(function()
    game:GetService("StarterGui"):SetCore("SendNotification", {
        Title = "Takbir's MVS Script Loaded ✔",
        Text = "Hitbox + Wall ESP Activated",
        Duration = 5
    })
end)


local HeadSize = 10
local IsTeamCheckEnabled = false
local DefaultHRPSize = Vector3.new(2, 2, 1)

game:GetService("RunService").RenderStepped:Connect(function()
    local players = game:GetService("Players")
    local localPlayer = players.LocalPlayer
    if not localPlayer or not localPlayer.Character then return end

    local tool = localPlayer.Character:FindFirstChildWhichIsA("Tool")
    local isArmed = (tool ~= nil)

    local localTeam = localPlayer.Team

    for _, player in ipairs(players:GetPlayers()) do
        if player ~= localPlayer and (not IsTeamCheckEnabled or player.Team ~= localTeam) then
            local char = player.Character
            if char then
                local hrp = char:FindFirstChild("HumanoidRootPart")
                if hrp then

                    local box = hrp:FindFirstChild("HitboxOutline")
                    if not box then
                        box = Instance.new("SelectionBox")
                        box.Name = "HitboxOutline"
                        box.Adornee = hrp
                        box.Parent = hrp
                    end

                    box.LineThickness = 0.05
                    box.Color3 = Color3.fromRGB(0, 120, 255)
                    box.Transparency = 0
                    box.SurfaceTransparency = 1

                    if isArmed then
                        hrp.Size = Vector3.new(HeadSize, HeadSize, HeadSize)
                        hrp.CanCollide = false
                        hrp.Transparency = 1 
                    else
                        hrp.Size = DefaultHRPSize
                        hrp.CanCollide = false
                        hrp.Transparency = 1
                    end


local function CreateThickHighlight(char, name)
    local h = Instance.new("Highlight")
    h.Name = name
    h.Adornee = char
    h.FillTransparency = 1
    h.OutlineTransparency = 0
    h.OutlineColor = Color3.fromRGB(0, 0, 0)
    h.Parent = char
    return h
end

if not char:FindFirstChild("ESP_Highlight_1") then
    CreateThickHighlight(char, "ESP_Highlight_1")
    CreateThickHighlight(char, "ESP_Highlight_2")
end


                end
            end
        end
    end
end)

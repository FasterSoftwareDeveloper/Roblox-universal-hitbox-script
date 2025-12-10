MinBtn.MouseButton1Click:Connect(function()
        Frame.Visible = not Frame.Visible
    end)
end

if not gui then
    CreateGUI()
end

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

local mouse = localPlayer:GetMouse()
mouse.Button1Down:Connect(function()
    if ClickTeleportEnabled and localPlayer.Character then
        local hrp = localPlayer.Character:FindFirstChild("HumanoidRootPart")
        if hrp then
            hrp.CFrame = CFrame.new(mouse.Hit.Position + Vector3.new(0,3,0))
        end
    end
end)

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
    for _,player in ipairs(Players:GetPlayers()) do
        if player ~= localPlayer then
            UpdateHighlight(player)
            UpdateHitbox(player)
        end
    end
end)

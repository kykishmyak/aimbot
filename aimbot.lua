
    updateTargetHUD()
-- Load necessary services
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Camera = workspace.CurrentCamera

-- Define colors
local Green = Color3.fromRGB(0, 255, 0)
local Red = Color3.fromRGB(255, 0, 0)
local Orange = Color3.fromRGB(255, 165, 0)

-- Aimbot settings
local player = Players.LocalPlayer
local aiming = false
local pcMod = false
local radius = 150
local useTeamCheck = true
local useWallCheck = true
local targetPart = "Head"
local lockOnTarget = false
local currentTarget = nil
local lastAttackedTarget = nil
local espEnabled = true
local teleportEnabled = false
local rotationSpeed = 10
local verticalSpeedMultiplier = 2
local rotationRadius = 5
local verticalAmplitude = 3
local isRotating = false
local teleportAimLock = false
local teleportAimLockTime = 0
local killAllEnabled = false
local killCooldowns = {}

-- ESP settings
local esp = {}

-- Target HUD settings
local hudVisible = false
local hudRect = nil
local hudHealthBar = nil
local hudName = nil

-- Function to create a new drawing object
local function NewDrawing(className, properties)
    local drawing = Drawing.new(className)
    for property, value in pairs(properties) do
        drawing[property] = value
    end
    return drawing
end

-- Aimbot circle drawing
local drawing = NewDrawing("Circle", {
    Color = Color3.new(1, 0, 0),
    Thickness = 2,
    Radius = radius,
    Filled = false,
    Visible = true
})

-- Function to update circle position
local function updateCirclePosition()
    local screenSize = Camera.ViewportSize
    drawing.Position = Vector2.new(screenSize.X / 2, screenSize.Y / 2)
end

updateCirclePosition()

-- Target HUD initialization
local function initTargetHUD()
    hudRect = NewDrawing("Square", {
        Size = Vector2.new(150, 50),
        Position = Vector2.new(Camera.ViewportSize.X / 2 + 100, Camera.ViewportSize.Y / 2 - 25),
        Color = Color3.fromRGB(30, 30, 30),
        Filled = true,
        Visible = false,
        Thickness = 1
    })
    hudHealthBar = NewDrawing("Square", {
        Size = Vector2.new(130, 10),
        Position = Vector2.new(Camera.ViewportSize.X / 2 + 110, Camera.ViewportSize.Y / 2 + 5),
        Color = Green,
        Filled = true,
        Visible = false
    })
    hudName = NewDrawing("Text", {
        Text = "",
        Size = 16,
        Center = true,
        Outline = true,
        Color = Color3.fromRGB(255, 255, 255),
        Position = Vector2.new(Camera.ViewportSize.X / 2 + 175, Camera.ViewportSize.Y / 2 - 10),
        Visible = false
    })
end

initTargetHUD()

-- Function to update Target HUD
local function updateTargetHUD()
    if currentTarget and currentTarget.Parent and currentTarget.Parent:FindFirstChild("Humanoid") and currentTarget.Parent.Humanoid.Health > 0 then
        local targetPlayer = Players:GetPlayerFromCharacter(currentTarget.Parent)
        local humanoid = currentTarget.Parent.Humanoid
        hudVisible = true
        hudRect.Visible = true
        hudHealthBar.Visible = true
        hudName.Visible = true

        local healthPercent = humanoid.Health / humanoid.MaxHealth
        hudHealthBar.Size = Vector2.new(130 * healthPercent, 10)
        hudHealthBar.Color = Color3.fromRGB(255 * (1 - healthPercent), 255 * healthPercent, 0)
        hudName.Text = targetPlayer and targetPlayer.Name or "Unknown"
        lastAttackedTarget = currentTarget.Parent
    else
        hudVisible = false
        hudRect.Visible = false
        hudHealthBar.Visible = false
        hudName.Visible = false
    end
end

-- Improved Wall Check function
local function isTargetVisible(targetPosition)
    if not useWallCheck then
        return true
    end
    local origin = Camera.CFrame.Position
    local direction = (targetPosition - origin).Unit * (targetPosition - origin).Magnitude
    local raycastParams = RaycastParams.new()
    raycastParams.FilterDescendantsInstances = {player.Character}
    raycastParams.FilterType = Enum.RaycastFilterType.Blacklist
    local raycastResult = workspace:Raycast(origin, direction, raycastParams)

    if raycastResult then
        local hitPart = raycastResult.Instance
        local hitCharacter = hitPart.Parent
        if hitCharacter and hitCharacter:FindFirstChild("Humanoid") then
            local targetPartInstance = hitCharacter:FindFirstChild(targetPart)
            return targetPartInstance and (targetPartInstance.Position - targetPosition).Magnitude < 0.1
        end
        return false
    end
    return true
end

-- Function to get the closest target in radius
local function getClosestTargetInRadius()
    local target = nil
    local shortestDistance = math.huge

    for _, playerModel in pairs(Players:GetPlayers()) do
        if playerModel ~= player and playerModel.Character then
            local character = playerModel.Character
            local humanoid = character:FindFirstChild("Humanoid")
            local targetPartInstance = character:FindFirstChild(targetPart)
            if humanoid and targetPartInstance and humanoid.Health > 0 then
                if not useTeamCheck or (player.Team and playerModel.Team ~= player.Team and player.TeamColor ~= playerModel.TeamColor) then
                    local screenPos, onScreen = Camera:WorldToViewportPoint(targetPartInstance.Position)
                    local distanceToCenter = (Vector2.new(screenPos.X, screenPos.Y) - drawing.Position).Magnitude
                    if onScreen and distanceToCenter <= radius and isTargetVisible(targetPartInstance.Position) then
                        local distance = (targetPartInstance.Position - Camera.CFrame.Position).Magnitude
                        if distance < shortestDistance then
                            shortestDistance = distance
                            target = targetPartInstance
                        end
                    end
                end
            end
        end
    end

    return target
end

-- Function to teleport and rotate around target
local function teleportToTarget(target)
    if target and target.Parent and target.Parent:FindFirstChild("Humanoid") and target.Parent.Humanoid.Health > 0 then
        local targetPosition = target.Position
        local directionToTarget = (targetPosition - Camera.CFrame.Position).Unit
        local behindTarget = targetPosition - directionToTarget * rotationRadius
        local character = player.Character or player.CharacterAdded:Wait()
        local humanoidRootPart = character:WaitForChild("HumanoidRootPart")
        humanoidRootPart.CFrame = CFrame.lookAt(behindTarget, targetPosition)
        isRotating = true
        return true
    end
    return false
end

-- Kill All function
local function killAll()
    if not killAllEnabled then return end

    local currentTime = tick()
    local allSameTeam = true
    local myTeam = player.Team

    -- Проверка, все ли игроки в одной команде
    for _, plr in pairs(Players:GetPlayers()) do
        if plr ~= player and plr.Team ~= myTeam then
            allSameTeam = false
            break
        end
    end

    -- Выбор следующей цели
    for _, playerModel in pairs(Players:GetPlayers()) do
        if playerModel ~= player and playerModel.Character then
            local character = playerModel.Character
            local humanoid = character:FindFirstChild("Humanoid")
            local targetPartInstance = character:FindFirstChild(targetPart)
            if humanoid and targetPartInstance and humanoid.Health > 0 then
                if allSameTeam or (not useTeamCheck or (player.Team and playerModel.Team ~= player.Team and player.TeamColor ~= playerModel.TeamColor)) then
                    local cooldown = killCooldowns[playerModel.UserId]
                    if not cooldown or currentTime >= cooldown then
                        currentTarget = targetPartInstance
                        if teleportToTarget(currentTarget) then
                            Camera.CFrame = CFrame.new(Camera.CFrame.Position, currentTarget.Position)
                            drawing.Color = Green
                            return
                        end
                    end
                end
            end
        end
    end

    -- Добавление кулдауна для умершей цели
    if currentTarget and currentTarget.Parent and currentTarget.Parent:FindFirstChild("Humanoid") and currentTarget.Parent.Humanoid.Health <= 0 then
        local targetPlayer = Players:GetPlayerFromCharacter(currentTarget.Parent)
        if targetPlayer then
            killCooldowns[targetPlayer.UserId] = currentTime + 5
        end
        currentTarget = nil
        isRotating = false
    end
end

-- Function to aim at the target
local function aimAtTarget()
    local currentTime = tick()

    if currentTarget and currentTarget.Parent and currentTarget.Parent:FindFirstChild("Humanoid") then
        if currentTarget.Parent.Humanoid.Health <= 0 then
            aiming = false
            currentTarget = nil
            isRotating = false
            teleportAimLock = false
            drawing.Color = Red
            return
        end
    end

    if teleportAimLock and currentTarget and currentTime < teleportAimLockTime then
        if currentTarget.Parent and currentTarget.Parent:FindFirstChild("Humanoid") and currentTarget.Parent.Humanoid.Health > 0 then
            Camera.CFrame = CFrame.new(Camera.CFrame.Position, currentTarget.Position)
            drawing.Color = Green
            return
        else
            teleportAimLock = false
            currentTarget = nil
            isRotating = false
            aiming = false
        end
    elseif teleportAimLock and currentTime >= teleportAimLockTime then
        teleportAimLock = false
    end

    if currentTarget and currentTarget.Parent and currentTarget.Parent:FindFirstChild("Humanoid") and currentTarget.Parent.Humanoid.Health > 0 then
        local screenPos, onScreen = Camera:WorldToViewportPoint(currentTarget.Position)
        local distanceToCenter = (Vector2.new(screenPos.X, screenPos.Y) - drawing.Position).Magnitude
        if onScreen and distanceToCenter <= radius and isTargetVisible(currentTarget.Position) then
            Camera.CFrame = CFrame.new(Camera.CFrame.Position, currentTarget.Position)
            drawing.Color = Green

            if teleportEnabled then
                teleportToTarget(currentTarget)
                teleportAimLock = true
                teleportAimLockTime = currentTime + 1
            end
            return
        else
            currentTarget = nil
            isRotating = false
        end
    end

    local target = getClosestTargetInRadius()
    if target then
        currentTarget = target
        Camera.CFrame = CFrame.new(Camera.CFrame.Position, target.Position)
        drawing.Color = Green

        if teleportEnabled then
            teleportToTarget(currentTarget)
            teleportAimLock = true
            teleportAimLockTime = currentTime + 1
        end
    else
        drawing.Color = Red
        currentTarget = nil
        isRotating = false
    end
end

-- Improved ESP function with always-visible lines
local function UpdateESP()
    if not espEnabled then
        for _, plr in pairs(esp) do
            if plr.box then plr.box.Visible = false end
            if plr.name then plr.name.Visible = false end
            if plr.line then plr.line.Visible = false end
        end
        return
    end

    local activePlayers = Players:GetPlayers()
    for _, plr in pairs(activePlayers) do
        if plr ~= player and plr.Character then
            local character = plr.Character
            local rootPart = character:FindFirstChild("HumanoidRootPart")
            local humanoid = character:FindFirstChild("Humanoid")
            if rootPart and humanoid and humanoid.Health > 0 then
                local isLastTarget = (lastAttackedTarget and lastAttackedTarget == character)
                local color = isLastTarget and Orange or ((player.Team and plr.Team == player.Team and player.TeamColor == plr.TeamColor) and Green or Red)

                if not esp[plr] then
                    esp[plr] = {
                        box = NewDrawing("Square", {
                            Thickness = 2,
                            Color = color,
                            Filled = false,
                            Transparency = 0.9
                        }),
                        name = NewDrawing("Text", {
                            Text = plr.Name,
                            Size = 16,
                            Center = true,
                            Outline = true,
                            Color = color,
                            Transparency = 0.9
                        }),
                        line = NewDrawing("Line", {
                            Thickness = 1,
                            Color = color,
                            Transparency = 0.7
                        })
                    }
                else
                    esp[plr].box.Color = color
                    esp[plr].name.Color = color
                    esp[plr].line.Color = color
                end

                local vector = Camera:WorldToViewportPoint(rootPart.Position)
                local screenCenter = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
                esp[plr].line.From = screenCenter
                esp[plr].line.To = Vector2.new(vector.X, vector.Y)
                esp[plr].line.Visible = true

                local _, onScreen = Camera:WorldToViewportPoint(rootPart.Position)
                if onScreen then
                    local size = 2000 / vector.Z
                    esp[plr].box.Size = Vector2.new(size, size * 1.5)
                    esp[plr].box.Position = Vector2.new(vector.X - size / 2, vector.Y - size * 0.75)
                    esp[plr].box.Visible = true
                    esp[plr].name.Position = Vector2.new(vector.X, vector.Y - size * 0.75 - 20)
                    esp[plr].name.Visible = true
                else
                    esp[plr].box.Visible = false
                    esp[plr].name.Visible = false
                end
            elseif esp[plr] then
                esp[plr].box.Visible = false
                esp[plr].name.Visible = false
                esp[plr].line.Visible = false
            end
        end
    end

    for plr, data in pairs(esp) do
        if not table.find(activePlayers, plr) or not plr.Character or not plr.Character:FindFirstChild("Humanoid") or plr.Character.Humanoid.Health <= 0 then
            if data.box then data.box:Remove() end
            if data.name then data.name:Remove() end
            if data.line then data.line:Remove() end
            esp[plr] = nil
        end
    end
end

-- Load Rayfield UI
local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()

local Window = Rayfield:CreateWindow({
    Name = "Aimbot Interface",
    LoadingTitle = "Loading Aimbot...",
    LoadingSubtitle = "by Sirius",
    ConfigurationSaving = {
        Enabled = true,
        FolderName = nil,
        FileName = "AimbotConfig"
    },
    Discord = {
        Enabled = false,
        Invite = "noinvitelink",
        RememberJoins = true
    },
    KeySystem = false
})

local AimbotTab = Window:CreateTab("Aimbot", 4483362458)

local aimbotToggle = AimbotTab:CreateToggle({
    Name = "Enable Aimbot",
    CurrentValue = false,
    Flag = "AimbotToggle",
    Callback = function(Value)
        aiming = Value
        if not Value then
            drawing.Color = Red
            currentTarget = nil
            isRotating = false
            teleportAimLock = false
        end
    end
})

local radiusSlider = AimbotTab:CreateSlider({
    Name = "Aimbot Radius",
    Range = {1, 500},
    Increment = 1,
    CurrentValue = radius,
    Flag = "AimbotRadius",
    Callback = function(Value)
        radius = Value
        drawing.Radius = radius
    end
})

local teamCheckToggle = AimbotTab:CreateToggle({
    Name = "Team Check",
    CurrentValue = useTeamCheck,
    Flag = "TeamCheckToggle",
    Callback = function(Value)
        useTeamCheck = Value
    end
})

local wallCheckToggle = AimbotTab:CreateToggle({
    Name = "Wall Check",
    CurrentValue = useWallCheck,
    Flag = "WallCheckToggle",
    Callback = function(Value)
        useWallCheck = Value
    end
})

local targetPartDropdown = AimbotTab:CreateDropdown({
    Name = "Target Part",
    Options = {"Head", "Torso"},
    CurrentOption = targetPart,
    Flag = "TargetPartDropdown",
    Callback = function(Option)
        targetPart = Option
        currentTarget = nil
    end
})

local lockOnToggle = AimbotTab:CreateToggle({
    Name = "Lock On Target",
    CurrentValue = lockOnTarget,
    Flag = "LockOnToggle",
    Callback = function(Value)
        lockOnTarget = Value
        if not Value then
            currentTarget = nil
            isRotating = false
        end
    end
})

local pcModToggle = AimbotTab:CreateToggle({
    Name = "PC Mod",
    CurrentValue = pcMod,
    Flag = "PcModToggle",
    Callback = function(Value)
        pcMod = Value
    end
})

local espToggle = AimbotTab:CreateToggle({
    Name = "Enable ESP",
    CurrentValue = espEnabled,
    Flag = "EspToggle",
    Callback = function(Value)
        espEnabled = Value
    end
})

local teleportToggle = AimbotTab:CreateToggle({
    Name = "Enable Teleport",
    CurrentValue = teleportEnabled,
    Flag = "TeleportToggle",
    Callback = function(Value)
        teleportEnabled = Value
        if not Value then
            isRotating = false
            teleportAimLock = false
        end
    end
})

local killAllToggle = AimbotTab:CreateToggle({
    Name = "Enable Kill All",
    CurrentValue = false,
    Flag = "KillAllToggle",
    Callback = function(Value)
        killAllEnabled = Value
        if not Value then
            currentTarget = nil
            isRotating = false
            killCooldowns = {}
        end
    end
})

-- Handle character respawn
player.CharacterAdded:Connect(function(character)
    currentTarget = nil
    isRotating = false
    teleportAimLock = false
end)

-- Очистка ESP и кулдаунов при выходе игрока
Players.PlayerRemoving:Connect(function(plr)
    if esp[plr] then
        esp[plr].box:Remove()
        esp[plr].name:Remove()
        esp[plr].line:Remove()
        esp[plr] = nil
    end
    killCooldowns[plr.UserId] = nil
end)

-- Main loop
RunService.RenderStepped:Connect(function(deltaTime)
    updateCirclePosition()

    if killAllEnabled then
        killAll()
    elseif pcMod then
        if UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2) then
            aiming = true
            aimAtTarget()
        else
            aiming = false
            drawing.Color = Red
            currentTarget = nil
            isRotating = false
            teleportAimLock = false
        end
    else
        if aiming then
            aimAtTarget()
        else
            drawing.Color = Red
            currentTarget = nil
            isRotating = false
            teleportAimLock = false
        end
    end

    if isRotating and currentTarget and (teleportEnabled or killAllEnabled) then
        local character = player.Character
        if character and character:FindFirstChild("HumanoidRootPart") then
            local humanoidRootPart = character.HumanoidRootPart
            local targetPosition = currentTarget.Position
            local angle = tick() * rotationSpeed
            local verticalAngle = tick() * rotationSpeed * verticalSpeedMultiplier
            local horizontalOffset = Vector3.new(math.sin(angle), 0, math.cos(angle)) * rotationRadius
            local verticalOffset = Vector3.new(0, math.abs(math.sin(verticalAngle)) * verticalAmplitude, 0)
            local newPosition = targetPosition + horizontalOffset + verticalOffset
            humanoidRootPart.CFrame =  = CFrame.lookAt(newPosition, targetPosition)
        end
    end

    UpdateESP()
    updateTargetHUD()
end)
